import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { StreamingHttpClient, StreamingHttpResponse } from '../network/StreamingHttpClient'
import { ReaderImageCacheSettings } from '../settings/ReaderImageCacheSettings'

const CACHE_DIR_NAME: string = 'nextn-reader-image-cache'
const CACHE_FILE_EXTENSION: string = 'img'
const CACHE_MAINTENANCE_WRITE_INTERVAL: number = 16
const CACHE_MAINTENANCE_BYTES_INTERVAL: number = 16 * 1024 * 1024
const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 30000
// StreamingHttpClient owns a fixed 512 MiB safety ceiling for one response.
// The user setting is the aggregate cache budget, not a per-request allowance.
const READER_IMAGE_STREAM_MAX_BYTES: number = 512 * 1024 * 1024
// Defensive file-count cap derived from the byte budget (assumes >=256KB per
// page). It keeps LRU scans bounded while the user-selected byte limit stays
// the real eviction budget, mirroring NextE's byte-only reader cache policy.
const CACHE_FILE_AVG_BYTES: number = 256 * 1024
const CACHE_LIMIT_FILES_MIN: number = 512

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
  /** Stable cache-family base for an immutable force-reload version; empty for ordinary assets. */
  familyPath: string = ''
  bytes: number = 0
  fromCache: boolean = false
}

/** One shared-reader ownership token for a resolved private cache file. */
export class ReaderImageCacheLease {
  result: ReaderImageCacheResult
  presented: boolean = false
  released: boolean = false

  constructor(result: ReaderImageCacheResult) { this.result = result }
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
  private static reloadEpoch: number = 0
  private static localLeases: Map<string, number> = new Map<string, number>()

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
      throw new Error('Reader image is unavailable')
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
    const latestPath: string = ReaderImageCacheService.latestPath(filePath)
    if (!forceReload) {
      const cached: ReaderImageCacheResult | null = ReaderImageCacheService.cached(latestPath)
      if (cached !== null) {
        console.info(`NextNReaderCache hit bytes=${cached.bytes}`)
        return cached
      }
    }

    // An explicit Retry is intentionally a fresh, user-triggered GET. It does
    // not inherit an earlier failed or stale reader source. Keep an existing
    // final file intact while its replacement streams into .part: the current
    // ArkUI Image can still own that file until the state emission is rendered.
    // downloadAndStore swaps the completed file only after the stream closes.
    const stageReload: boolean = forceReload && ReaderImageCacheService.fileSize(latestPath) > 0
    const storagePath: string = stageReload ? ReaderImageCacheService.reloadPath(filePath) : filePath
    const download: Promise<ReaderImageCacheResult> = ReaderImageCacheService.downloadAndStore(
      context,
      url,
      storagePath,
      !stageReload,
    )
    ReaderImageCacheService.inFlight.set(filePath, download)
    try {
      const result = await download
      if (stageReload && result.localPath.length > 0) result.familyPath = filePath
      return result
    } finally {
      const active: Promise<ReaderImageCacheResult> | undefined = ReaderImageCacheService.inFlight.get(filePath)
      if (active === download) {
        ReaderImageCacheService.inFlight.delete(filePath)
      }
    }
  }

  /**
   * Releases a provider result after reader-kit has retired its Image node.
   * Force-reload versions remain immutable after presentation. Normal loads
   * select the latest complete sibling instead of renaming a path that ArkUI
   * may still cache or decode.
   */
  static retain(result: ReaderImageCacheResult): ReaderImageCacheLease {
    const lease = new ReaderImageCacheLease(result)
    if (result.localPath.length > 0) {
      const count: number = ReaderImageCacheService.localLeases.get(result.localPath) ?? 0
      ReaderImageCacheService.localLeases.set(result.localPath, count + 1)
    }
    return lease
  }

  static markPresented(lease: ReaderImageCacheLease): void {
    if (!lease.released) lease.presented = true
  }

  static release(context: common.UIAbilityContext, lease: ReaderImageCacheLease): void {
    if (lease.released) return
    lease.released = true
    const result: ReaderImageCacheResult = lease.result
    ReaderImageCacheService.releaseLocalLease(result.localPath)
    const familyPath: string = result.familyPath
    if (familyPath.length === 0 || result.localPath.length === 0 || result.localPath === familyPath) return
    if (!lease.presented) {
      // A source that never reached native presentation is not a valid cache candidate.
      ReaderImageCacheService.removeIfExists(result.localPath)
      return
    }
    ReaderImageCacheService.maintainAfterStore(context, result.bytes)
  }

  private static releaseLocalLease(path: string): void {
    if (path.length === 0) return
    const count: number = ReaderImageCacheService.localLeases.get(path) ?? 0
    if (count <= 1) ReaderImageCacheService.localLeases.delete(path)
    else ReaderImageCacheService.localLeases.set(path, count - 1)
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
    maintain: boolean,
  ): Promise<ReaderImageCacheResult> {
    const tmpPath: string = `${filePath}.part`
    ReaderImageCacheService.removeIfExists(tmpPath)
    let file: fileIo.File | null = null
    let written: number = 0
    let writeFailureMessage: string = ''
    let bypassCache: boolean = false
    let completed: boolean = false
    const limitBytes: number = ReaderImageCacheSettings.limitBytes()
    const streamLimitBytes: number = Math.min(limitBytes, READER_IMAGE_STREAM_MAX_BYTES)
    try {
      ReaderImageCacheService.ensureDir(ReaderImageCacheService.cacheDir(context))
      file = fileIo.openSync(
        tmpPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      const headers: Record<string, string> = {}
      headers['Accept'] = 'image/*'
      headers['User-Agent'] = 'NextN/1.0.0'
      const response: StreamingHttpResponse = await StreamingHttpClient.get(
        url,
        headers,
        CONNECT_TIMEOUT_MS,
        READ_TIMEOUT_MS,
        streamLimitBytes,
        (data: ArrayBuffer): boolean => {
          if (file === null || writeFailureMessage.length > 0) {
            return false
          }
          try {
            const count: number = fileIo.writeSync(file.fd, data)
            if (count !== data.byteLength) {
              throw new Error('Unable to save Reader image')
            }
            written += count
            return true
          } catch (error) {
            const failure: Error = error as Error
            writeFailureMessage = failure.message.length > 0 ? failure.message : 'Unable to save Reader image'
            return false
          }
        },
      )
      bypassCache = response.limitExceeded
      if (bypassCache) {
        return ReaderImageCacheService.remoteResult(url)
      }
      if (writeFailureMessage.length > 0) {
        throw new Error(writeFailureMessage)
      }
      if (response.sinkRejected) {
        throw new Error('Unable to save Reader image')
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw new Error(`Reader image request failed (${response.statusCode}).`)
      }
      if (written <= 0) {
        throw new Error('Reader image response was empty')
      }
      // ArkUI can begin decoding immediately after this promise resolves. Make
      // every streamed byte visible to that independent native reader first;
      // close/rename alone is insufficient for consecutive extreme-long reloads.
      fileIo.fsyncSync(file.fd)
      fileIo.closeSync(file)
      file = null
      ReaderImageCacheService.removeIfExists(filePath)
      fileIo.renameSync(tmpPath, filePath)
      const bytes: number = ReaderImageCacheService.fileSize(filePath)
      if (bytes <= 0) {
        ReaderImageCacheService.removeIfExists(filePath)
        throw new Error('Reader image cache file was empty')
      }
      completed = true
      console.info(`NextNReaderCache stored bytes=${bytes}`)
      if (maintain) ReaderImageCacheService.maintainAfterStore(context, bytes)
      return ReaderImageCacheService.result(filePath, bytes, false)
    } catch (error) {
      // A single page larger than the private-cache budget remains readable:
      // discard its partial bytes and let ArkUI make the normal direct image
      // request rather than turning a cache policy into a reader failure.
      if (bypassCache) {
        console.info(`NextNReaderCache bypass limit=${limitBytes}`)
        return ReaderImageCacheService.remoteResult(url)
      }
      throw error as Error
    } finally {
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
    const limitBytes: number = ReaderImageCacheSettings.limitBytes()
    const limitFiles: number = Math.max(
      CACHE_LIMIT_FILES_MIN,
      Math.ceil(limitBytes / CACHE_FILE_AVG_BYTES),
    )
    let totalBytes: number = 0
    for (let i: number = 0; i < entries.length; i++) {
      totalBytes += entries[i].bytes
    }
    if (totalBytes <= limitBytes && entries.length <= limitFiles) {
      return
    }
    entries.sort((left: ReaderImageCacheEntry, right: ReaderImageCacheEntry): number => left.mtime - right.mtime)
    let remaining: number = entries.length
    for (let i: number = 0; i < entries.length; i++) {
      if ((totalBytes <= limitBytes && remaining <= limitFiles) || remaining <= 1) {
        break
      }
      if ((ReaderImageCacheService.localLeases.get(entries[i].path) ?? 0) > 0) continue
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

  private static reloadPath(filePath: string): string {
    // Keep the app-private file URI short. The native decoder accepts the same
    // bytes after promotion to the shorter stable path but can compose blank
    // pixels from a long timestamped reload URI on extreme-long pages.
    ReaderImageCacheService.reloadEpoch = Math.max(
      ReaderImageCacheService.reloadEpoch,
      ReaderImageCacheService.latestReloadEpoch(filePath),
    ) + 1
    const suffix: string = `-r${ReaderImageCacheService.reloadEpoch}.img`
    return filePath.endsWith(`.${CACHE_FILE_EXTENSION}`)
      ? `${filePath.substring(0, filePath.length - `.${CACHE_FILE_EXTENSION}`.length)}${suffix}`
      : `${filePath}${suffix}`
  }

  private static latestPath(filePath: string): string {
    const slash: number = filePath.lastIndexOf('/')
    const directory: string = slash >= 0 ? filePath.substring(0, slash) : ''
    const name: string = slash >= 0 ? filePath.substring(slash + 1) : filePath
    const extension: string = `.${CACHE_FILE_EXTENSION}`
    const stem: string = name.endsWith(extension) ? name.substring(0, name.length - extension.length) : name
    let selected: string = ReaderImageCacheService.fileSize(filePath) > 0 ? filePath : ''
    let selectedEpoch: number = 0
    try {
      const names: string[] = fileIo.listFileSync(directory)
      for (let index: number = 0; index < names.length; index++) {
        if (!names[index].startsWith(`${stem}-r`) || !names[index].endsWith(extension)) continue
        const raw: string = names[index].substring(stem.length + 2, names[index].length - extension.length)
        const epoch: number = Number(raw)
        const candidate: string = `${directory}/${names[index]}`
        if (Number.isSafeInteger(epoch) && epoch > selectedEpoch && ReaderImageCacheService.fileSize(candidate) > 0) {
          selected = candidate
          selectedEpoch = epoch
        }
      }
    } catch (_error) {}
    return selected.length > 0 ? selected : filePath
  }

  private static latestReloadEpoch(filePath: string): number {
    const selected: string = ReaderImageCacheService.latestPath(filePath)
    const extension: string = `.${CACHE_FILE_EXTENSION}`
    const marker: number = selected.lastIndexOf('-r')
    if (marker < 0 || !selected.endsWith(extension)) return 0
    const epoch: number = Number(selected.substring(marker + 2, selected.length - extension.length))
    return Number.isSafeInteger(epoch) && epoch > 0 ? epoch : 0
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
