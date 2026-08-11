import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'

const CACHE_DIR_NAME: string = 'nextn-reader-image-cache'
const CACHE_FILE_EXTENSION: string = 'img'
const CACHE_LIMIT_BYTES: number = 128 * 1024 * 1024
const CACHE_LIMIT_FILES: number = 512
const CACHE_MAINTENANCE_WRITE_INTERVAL: number = 16
const CACHE_MAINTENANCE_BYTES_INTERVAL: number = 16 * 1024 * 1024
const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 30000

class ReaderImageCacheEntry {
  path: string = ''
  bytes: number = 0
  mtime: number = 0

  constructor(path: string, bytes: number, mtime: number) {
    this.path = path
    this.bytes = bytes
    this.mtime = mtime
  }
}

/** A locally-resolved image source for the native Reader. */
export class ReaderImageCacheResult {
  displayUri: string = ''
  /** Private local source when caching succeeded; never populated for a remote fallback. */
  localPath: string = ''
  bytes: number = 0
  fromCache: boolean = false
}

/** Aggregate-only view of the private Reader cache; it never exposes page paths or URLs. */
export class ReaderImageCacheStatus {
  bytes: number = 0
  fileCount: number = 0
}

/**
 * Small app-private byte cache for pages the user actually opens in Reader.
 *
 * This deliberately is not a download manager: it does not prefetch, create
 * a queue, use public storage, or make any non-GET request. A miss writes a
 * single temporary file and atomically promotes it only after a successful
 * stream. Image decoding remains owned by ArkUI's Image component.
 */
export class ReaderImageCacheService {
  private static inFlight: Map<string, Promise<ReaderImageCacheResult>> = new Map<
    string,
    Promise<ReaderImageCacheResult>
  >()
  // The first store in a process clears safely orphaned partial files. Later
  // stores amortise directory scans so Reader completion stays off the hot
  // scroll path.
  private static maintenanceWritesSincePrune: number = -1
  private static maintenanceBytesSincePrune: number = 0

  static cacheKey(galleryId: number, mediaId: string, pageNumber: number, extension: string): string {
    return `reader:v2:${galleryId}:${mediaId}:${pageNumber}:${ReaderImageCacheService.normalizedExtension(extension)}`
  }

  static async load(
    context: common.UIAbilityContext,
    url: string,
    cacheKey: string,
    forceReload: boolean = false,
  ): Promise<ReaderImageCacheResult> {
    if (url.length === 0 || cacheKey.length === 0) {
      throw new Error('Reader image is unavailable.')
    }

    const filePath: string = ReaderImageCacheService.filePath(context, cacheKey)
    const running: Promise<ReaderImageCacheResult> | undefined = ReaderImageCacheService.inFlight.get(filePath)
    if (running !== undefined) {
      if (!forceReload) {
        return await running
      }
      // Do not let a user Retry race a stream that owns the same .part path.
      // Once it settles, recurse to create exactly one new, explicit GET.
      try {
        await running
      } catch (_error) {}
      return await ReaderImageCacheService.load(context, url, cacheKey, true)
    }
    if (forceReload) {
      ReaderImageCacheService.removeIfExists(filePath)
    } else {
      const cached: ReaderImageCacheResult | null = ReaderImageCacheService.cached(filePath)
      if (cached !== null) {
        console.info(`NextNReaderCache hit bytes=${cached.bytes}`)
        return cached
      }
    }

    // An explicit Retry is intentionally a fresh, user-triggered GET. It does
    // not inherit an earlier failed or stale reader source.
    const download: Promise<ReaderImageCacheResult> = ReaderImageCacheService.downloadAndStore(
      context,
      url,
      filePath,
    )
    ReaderImageCacheService.inFlight.set(filePath, download)
    try {
      return await download
    } finally {
      const active: Promise<ReaderImageCacheResult> | undefined = ReaderImageCacheService.inFlight.get(filePath)
      if (active === download) {
        ReaderImageCacheService.inFlight.delete(filePath)
      }
    }
  }

  /** Counts only completed private files. Active streams and remote URLs are never included. */
  static status(context: common.UIAbilityContext): ReaderImageCacheStatus {
    const status: ReaderImageCacheStatus = new ReaderImageCacheStatus()
    const entries: ReaderImageCacheEntry[] = ReaderImageCacheService.entries(context)
    for (let index: number = 0; index < entries.length; index++) {
      status.bytes += entries[index].bytes
    }
    status.fileCount = entries.length
    return status
  }

  /**
   * User-triggered cache eviction. Wait for existing page streams before
   * deleting their private files so a Settings action cannot race a .part
   * promotion. This leaves history, tag data, and all remote state untouched.
   */
  static async clear(context: common.UIAbilityContext): Promise<ReaderImageCacheStatus> {
    await ReaderImageCacheService.waitForInFlightDownloads()
    const directory: string = ReaderImageCacheService.cacheDir(context)
    try {
      if (!fileIo.accessSync(directory)) {
        return new ReaderImageCacheStatus()
      }
      const names: string[] = fileIo.listFileSync(directory)
      for (let index: number = 0; index < names.length; index++) {
        const path: string = `${directory}/${names[index]}`
        const finalPath: string = names[index].endsWith('.part')
          ? path.substring(0, path.length - '.part'.length)
          : path
        // A new reader request cannot normally start while Settings is the
        // visible root, but keep this guard for a route-transition race.
        if (!ReaderImageCacheService.inFlight.has(finalPath)) {
          ReaderImageCacheService.removeIfExists(path)
        }
      }
      ReaderImageCacheService.maintenanceWritesSincePrune = -1
      ReaderImageCacheService.maintenanceBytesSincePrune = 0
    } catch (error) {
      throw error as Error
    }
    return ReaderImageCacheService.status(context)
  }

  private static async downloadAndStore(
    context: common.UIAbilityContext,
    url: string,
    filePath: string,
  ): Promise<ReaderImageCacheResult> {
    const tmpPath: string = `${filePath}.part`
    ReaderImageCacheService.removeIfExists(tmpPath)
    let file: fileIo.File | null = null
    let request: http.HttpRequest | null = null
    let written: number = 0
    let writeFailureMessage: string = ''
    let bypassCache: boolean = false
    let completed: boolean = false
    try {
      ReaderImageCacheService.ensureDir(ReaderImageCacheService.cacheDir(context))
      file = fileIo.openSync(
        tmpPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      request = http.createHttp()
      request.on('dataReceiveProgress', (info: http.DataReceiveProgressInfo): void => {
        if (info.totalSize > CACHE_LIMIT_BYTES) {
          bypassCache = true
          request?.destroy()
        }
      })
      request.on('dataReceive', (data: ArrayBuffer): void => {
        if (file === null || writeFailureMessage.length > 0 || bypassCache) {
          return
        }
        try {
          if (written + data.byteLength > CACHE_LIMIT_BYTES) {
            bypassCache = true
            request?.destroy()
            return
          }
          const count: number = fileIo.writeSync(file.fd, data)
          if (count !== data.byteLength) {
            throw new Error('Unable to save Reader image.')
          }
          written += count
        } catch (error) {
          const failure: Error = error as Error
          writeFailureMessage = failure.message.length > 0 ? failure.message : 'Unable to save Reader image.'
          request?.destroy()
        }
      })
      const status: number = await request.requestInStream(url, {
        method: http.RequestMethod.GET,
        header: {
          Accept: 'image/*',
          'User-Agent': 'NextN/1.0.0',
        },
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: false,
      })
      if (bypassCache) {
        return ReaderImageCacheService.remoteResult(url)
      }
      if (writeFailureMessage.length > 0) {
        throw new Error(writeFailureMessage)
      }
      if (status < 200 || status >= 300) {
        throw new Error(`Reader image request failed (${status}).`)
      }
      if (written <= 0) {
        throw new Error('Reader image response was empty.')
      }
      request.destroy()
      request = null
      fileIo.closeSync(file)
      file = null
      ReaderImageCacheService.removeIfExists(filePath)
      fileIo.renameSync(tmpPath, filePath)
      const bytes: number = ReaderImageCacheService.fileSize(filePath)
      if (bytes <= 0) {
        ReaderImageCacheService.removeIfExists(filePath)
        throw new Error('Reader image cache file was empty.')
      }
      completed = true
      console.info(`NextNReaderCache stored bytes=${bytes}`)
      ReaderImageCacheService.maintainAfterStore(context, bytes)
      return ReaderImageCacheService.result(filePath, bytes, false)
    } catch (error) {
      // A single page larger than the private-cache budget remains readable:
      // discard its partial bytes and let ArkUI make the normal direct image
      // request rather than turning a cache policy into a reader failure.
      if (bypassCache) {
        console.info(`NextNReaderCache bypass limit=${CACHE_LIMIT_BYTES}`)
        return ReaderImageCacheService.remoteResult(url)
      }
      throw error as Error
    } finally {
      if (request !== null) {
        request.destroy()
      }
      if (file !== null) {
        fileIo.closeSync(file)
      }
      if (!completed) {
        ReaderImageCacheService.removeIfExists(tmpPath)
      }
    }
  }

  private static async waitForInFlightDownloads(): Promise<void> {
    const active: Promise<ReaderImageCacheResult>[] = Array.from(ReaderImageCacheService.inFlight.values())
    for (let index: number = 0; index < active.length; index++) {
      try {
        await active[index]
      } catch (_error) {
        // A failed stream still settles and cleans its own .part file. The
        // explicit clear proceeds to remove any completed siblings.
      }
    }
  }

  private static cached(filePath: string): ReaderImageCacheResult | null {
    const bytes: number = ReaderImageCacheService.fileSize(filePath)
    if (bytes <= 0) {
      ReaderImageCacheService.removeIfExists(filePath)
      return null
    }
    try {
      fileIo.utimes(filePath, Date.now())
    } catch (_error) {}
    return ReaderImageCacheService.result(filePath, bytes, true)
  }

  private static result(filePath: string, bytes: number, fromCache: boolean): ReaderImageCacheResult {
    const out: ReaderImageCacheResult = new ReaderImageCacheResult()
    out.displayUri = ReaderImageCacheService.displayUri(filePath)
    out.localPath = filePath
    out.bytes = bytes
    out.fromCache = fromCache
    return out
  }

  private static remoteResult(url: string): ReaderImageCacheResult {
    const out: ReaderImageCacheResult = new ReaderImageCacheResult()
    out.displayUri = url
    return out
  }

  private static maintainAfterStore(context: common.UIAbilityContext, storedBytes: number): void {
    const bytes: number = storedBytes > 0 ? storedBytes : 0
    const maintenanceDue: boolean =
      ReaderImageCacheService.maintenanceWritesSincePrune < 0 ||
      ReaderImageCacheService.maintenanceWritesSincePrune >= CACHE_MAINTENANCE_WRITE_INTERVAL - 1 ||
      ReaderImageCacheService.maintenanceBytesSincePrune + bytes >= CACHE_MAINTENANCE_BYTES_INTERVAL
    if (!maintenanceDue) {
      ReaderImageCacheService.maintenanceWritesSincePrune += 1
      ReaderImageCacheService.maintenanceBytesSincePrune += bytes
      return
    }
    ReaderImageCacheService.maintenanceWritesSincePrune = 0
    ReaderImageCacheService.maintenanceBytesSincePrune = 0
    try {
      ReaderImageCacheService.pruneNow(context)
    } catch (_error) {
      // The image has already been atomically promoted; defer maintenance
      // rather than converting a successful page render into a cache error.
      ReaderImageCacheService.maintenanceWritesSincePrune = -1
      console.warn('NextNReaderCache maintenance deferred')
    }
  }

  private static pruneNow(context: common.UIAbilityContext): void {
    const entries: ReaderImageCacheEntry[] = ReaderImageCacheService.entries(context)
    let totalBytes: number = 0
    for (let i: number = 0; i < entries.length; i++) {
      totalBytes += entries[i].bytes
    }
    if (totalBytes <= CACHE_LIMIT_BYTES && entries.length <= CACHE_LIMIT_FILES) {
      return
    }
    entries.sort((left: ReaderImageCacheEntry, right: ReaderImageCacheEntry): number => left.mtime - right.mtime)
    let remaining: number = entries.length
    for (let i: number = 0; i < entries.length; i++) {
      if ((totalBytes <= CACHE_LIMIT_BYTES && remaining <= CACHE_LIMIT_FILES) || remaining <= 1) {
        break
      }
      ReaderImageCacheService.removeIfExists(entries[i].path)
      totalBytes -= entries[i].bytes
      remaining -= 1
    }
  }

  private static entries(context: common.UIAbilityContext): ReaderImageCacheEntry[] {
    const out: ReaderImageCacheEntry[] = []
    const directory: string = ReaderImageCacheService.cacheDir(context)
    try {
      if (!fileIo.accessSync(directory)) {
        return out
      }
      const names: string[] = fileIo.listFileSync(directory)
      for (let i: number = 0; i < names.length; i++) {
        if (names[i].endsWith('.part')) {
          // A visible Reader range can stream multiple pages concurrently.
          // Never let the LRU scan remove a different request's active
          // temporary file; its owner cleans it in downloadAndStore's finally.
          // If the owner is absent, it is an orphan from an interrupted prior
          // process and is safe to remove on this maintenance pass.
          const temporaryPath: string = `${directory}/${names[i]}`
          const finalPath: string = temporaryPath.substring(0, temporaryPath.length - '.part'.length)
          if (!ReaderImageCacheService.inFlight.has(finalPath)) {
            ReaderImageCacheService.removeIfExists(temporaryPath)
          }
          continue
        }
        const path: string = `${directory}/${names[i]}`
        try {
          const stat = fileIo.statSync(path)
          if (stat.size > 0) {
            out.push(new ReaderImageCacheEntry(path, stat.size, stat.mtime))
          } else {
            ReaderImageCacheService.removeIfExists(path)
          }
        } catch (_error) {}
      }
    } catch (_error) {}
    return out
  }

  private static filePath(context: common.UIAbilityContext, cacheKey: string): string {
    const directory: string = ReaderImageCacheService.cacheDir(context)
    ReaderImageCacheService.ensureDir(directory)
    return `${directory}/${ReaderImageCacheService.hash(cacheKey)}.${CACHE_FILE_EXTENSION}`
  }

  private static cacheDir(context: common.UIAbilityContext): string {
    return `${context.cacheDir}/${CACHE_DIR_NAME}`
  }

  private static displayUri(path: string): string {
    return path.startsWith('/') ? `file://${path}` : `file:///${path}`
  }

  private static ensureDir(directory: string): void {
    try {
      fileIo.mkdirSync(directory, true)
    } catch (error) {
      if (!fileIo.accessSync(directory)) {
        throw error as Error
      }
    }
  }

  private static fileSize(path: string): number {
    try {
      return fileIo.statSync(path).size
    } catch (_error) {
      return 0
    }
  }

  private static removeIfExists(path: string): void {
    try {
      fileIo.unlinkSync(path)
    } catch (_error) {}
  }

  private static normalizedExtension(extension: string): string {
    const normalized: string = extension.toLowerCase().replace('.', '')
    return normalized.length > 0 ? normalized : CACHE_FILE_EXTENSION
  }

  private static hash(value: string): string {
    let first: number = 5381
    let second: number = 2166136261
    for (let i: number = 0; i < value.length; i++) {
      const code: number = value.charCodeAt(i)
      first = ((first << 5) + first + code) >>> 0
      second = (code + (second << 6) + (second << 16) - second) >>> 0
    }
    return `${first.toString(16)}-${second.toString(16)}`
  }
}
