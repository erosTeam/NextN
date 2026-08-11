import { common } from '@kit.AbilityKit'
import { zlib } from '@kit.BasicServicesKit'
import { fileIo } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import util from '@ohos.util'
import { NhTagTranslationEntry, NhTagTranslationStatus } from '../model/NhTagTranslation'
import { TagTranslationRepository } from '../storage/TagTranslationRepository'

const PUBLIC_DICTIONARY_URL: string =
  'https://github.com/EhTagTranslation/Database/releases/latest/download/db.raw.json.gz'
const PROVIDER_LABEL: string = 'EhTagTranslation/Database'
const CACHE_DIRECTORY_NAME: string = 'nextn-tag-translation'
const DOWNLOAD_PART_NAME: string = 'dictionary.gz.part'
const DOWNLOAD_NAME: string = 'dictionary.gz'
const DOWNLOAD_LIMIT_BYTES: number = 100 * 1024 * 1024
const UNCOMPRESSED_LIMIT_BYTES: number = 128 * 1024 * 1024
const READ_CHUNK_BYTES: number = 128 * 1024
const MAX_IMPORT_ROWS: number = 500000
const MAX_FIELD_LENGTH: number = 1024
const CONNECT_TIMEOUT_MS: number = 15000
const READ_TIMEOUT_MS: number = 30000

class DownloadArtifact {
  path: string = ''
  version: string = ''
}

/**
 * Downloads an optional, user-triggered public dictionary into the app-private
 * RDB. It never starts automatically, never uses cookies or credentials, and
 * leaves the existing dictionary untouched until strict parsing succeeds.
 */
export class TagTranslationUpdateService {
  private static updateTask: Promise<NhTagTranslationStatus> | null = null

  static async updateFromPublicRelease(
    context: common.UIAbilityContext,
    force: boolean = false,
  ): Promise<NhTagTranslationStatus> {
    if (TagTranslationUpdateService.updateTask !== null) {
      return await TagTranslationUpdateService.updateTask
    }
    const task: Promise<NhTagTranslationStatus> = TagTranslationUpdateService.updateInternal(context, force)
    TagTranslationUpdateService.updateTask = task
    try {
      return await task
    } finally {
      if (TagTranslationUpdateService.updateTask === task) {
        TagTranslationUpdateService.updateTask = null
      }
    }
  }

  private static async updateInternal(
    context: common.UIAbilityContext,
    force: boolean,
  ): Promise<NhTagTranslationStatus> {
    const previous: NhTagTranslationStatus = await TagTranslationRepository.status(context)
    let artifact: DownloadArtifact | null = null
    try {
      artifact = await TagTranslationUpdateService.downloadToPrivateFile(context, PUBLIC_DICTIONARY_URL)
      if (!force && previous.rowCount > 0 && previous.version === artifact.version) {
        return previous
      }
      const rawJson: string = await TagTranslationUpdateService.readGzipText(artifact.path)
      const entries: NhTagTranslationEntry[] = TagTranslationUpdateService.parseDictionary(rawJson)
      await TagTranslationRepository.replace(context, entries, artifact.version, PROVIDER_LABEL)
      return await TagTranslationRepository.status(context)
    } finally {
      if (artifact !== null && artifact.path.length > 0) {
        TagTranslationUpdateService.removeIfExists(artifact.path)
      }
      TagTranslationUpdateService.removeIfExists(TagTranslationUpdateService.downloadPartPath(context))
    }
  }

  private static async downloadToPrivateFile(
    context: common.UIAbilityContext,
    url: string,
  ): Promise<DownloadArtifact> {
    const directory: string = TagTranslationUpdateService.cacheDirectory(context)
    const partPath: string = TagTranslationUpdateService.downloadPartPath(context)
    const finalPath: string = `${directory}/${DOWNLOAD_NAME}`
    TagTranslationUpdateService.ensureDirectory(directory)
    TagTranslationUpdateService.removeIfExists(partPath)
    let file: fileIo.File | null = null
    let request: http.HttpRequest | null = null
    let written: number = 0
    let fingerprint: number = 2166136261
    let tooLarge: boolean = false
    let writeFailure: string = ''
    let completed: boolean = false
    try {
      file = fileIo.openSync(
        partPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      request = http.createHttp()
      request.on('dataReceiveProgress', (progress: http.DataReceiveProgressInfo): void => {
        if (progress.totalSize > DOWNLOAD_LIMIT_BYTES) {
          tooLarge = true
          request?.destroy()
        }
      })
      request.on('dataReceive', (data: ArrayBuffer): void => {
        if (file === null || tooLarge || writeFailure.length > 0) {
          return
        }
        try {
          if (written + data.byteLength > DOWNLOAD_LIMIT_BYTES) {
            tooLarge = true
            request?.destroy()
            return
          }
          // `offset` is relative to the current file pointer, not a cumulative
          // stream position. Each callback buffer is complete, so append from
          // the current pointer and retain the short-write rejection below.
          const count: number = fileIo.writeSync(file.fd, data)
          if (count !== data.byteLength) {
            throw new Error('Unable to save the tag dictionary download.')
          }
          fingerprint = TagTranslationUpdateService.fingerprintBytes(fingerprint, data)
          written += count
        } catch (error) {
          const failure: Error = error as Error
          writeFailure = failure.message.length > 0 ? failure.message : 'Unable to save the tag dictionary download.'
          request?.destroy()
        }
      })
      const status: number = await request.requestInStream(url, {
        method: http.RequestMethod.GET,
        usingCache: false,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        header: {
          Accept: 'application/gzip, application/octet-stream',
          'User-Agent': 'NextN/1.0.0',
        },
      })
      if (tooLarge) {
        throw new Error('The tag dictionary download exceeded its private-storage limit.')
      }
      if (writeFailure.length > 0) {
        throw new Error(writeFailure)
      }
      if (status < 200 || status >= 300) {
        throw new Error(`The tag dictionary download failed (${status}).`)
      }
      if (written <= 0) {
        throw new Error('The tag dictionary download was empty.')
      }
      request.destroy()
      request = null
      fileIo.closeSync(file)
      file = null
      TagTranslationUpdateService.removeIfExists(finalPath)
      fileIo.renameSync(partPath, finalPath)
      completed = true
      const artifact: DownloadArtifact = new DownloadArtifact()
      artifact.path = finalPath
      artifact.version = `bytes-${written}-fnv1a-${fingerprint.toString(16)}`
      return artifact
    } finally {
      if (request !== null) {
        request.destroy()
      }
      if (file !== null) {
        fileIo.closeSync(file)
      }
      if (!completed) {
        TagTranslationUpdateService.removeIfExists(partPath)
      }
    }
  }

  private static async readGzipText(path: string): Promise<string> {
    const gzip: zlib.GZip = zlib.createGZipSync()
    const decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true })
    let output: string = ''
    let decodedBytes: number = 0
    await gzip.gzopen(path, 'rb')
    try {
      while (true) {
        const buffer: ArrayBuffer = new ArrayBuffer(READ_CHUNK_BYTES)
        const count: number = await gzip.gzread(buffer)
        if (count <= 0) {
          break
        }
        decodedBytes += count
        if (decodedBytes > UNCOMPRESSED_LIMIT_BYTES) {
          throw new Error('The tag dictionary exceeded its decompression limit.')
        }
        output += decoder.decodeToString(new Uint8Array(buffer, 0, count), { stream: true })
      }
      output += decoder.decodeToString(new Uint8Array(new ArrayBuffer(0)), { stream: false })
    } finally {
      await gzip.gzclose()
    }
    return output
  }

  private static parseDictionary(rawJson: string): NhTagTranslationEntry[] {
    let parsed: Object
    try {
      parsed = JSON.parse(rawJson) as Object
    } catch (_error) {
      throw new Error('The tag dictionary was not valid JSON.')
    }
    const root: Record<string, Object> = TagTranslationUpdateService.asRecord(parsed)
    const groups: Object[] = TagTranslationUpdateService.asArray(root['data'])
    if (groups.length === 0) {
      throw new Error('The tag dictionary had an unsupported structure.')
    }
    const entries: NhTagTranslationEntry[] = []
    const seen: Set<string> = new Set<string>()
    for (let groupIndex: number = 0; groupIndex < groups.length; groupIndex++) {
      const group: Record<string, Object> = TagTranslationUpdateService.asRecord(groups[groupIndex])
      const namespace: string = TagTranslationUpdateService.normalizedNamespace(group['namespace'])
      const values: Record<string, Object> = TagTranslationUpdateService.asRecord(group['data'])
      if (namespace.length === 0 || Object.keys(values).length === 0) {
        continue
      }
      const rawNames: string[] = Object.keys(values)
      for (let nameIndex: number = 0; nameIndex < rawNames.length; nameIndex++) {
        const rawName: string = TagTranslationUpdateService.normalizedRawName(rawNames[nameIndex])
        const value: Record<string, Object> = TagTranslationUpdateService.asRecord(values[rawNames[nameIndex]])
        const displayName: string = TagTranslationUpdateService.cleanDisplayName(value['name'])
        const key: string = `${namespace}\u001f${rawName}`
        if (rawName.length === 0 || displayName.length === 0 || seen.has(key)) {
          continue
        }
        const entry: NhTagTranslationEntry = new NhTagTranslationEntry()
        entry.namespace = namespace
        entry.rawName = rawName
        entry.displayName = displayName
        entries.push(entry)
        seen.add(key)
        if (entries.length > MAX_IMPORT_ROWS) {
          throw new Error('The tag dictionary contained too many entries.')
        }
      }
    }
    if (entries.length === 0) {
      throw new Error('The tag dictionary contained no usable entries.')
    }
    return entries
  }

  private static normalizedNamespace(value: Object): string {
    const namespace: string = TagTranslationUpdateService.safeString(value).toLowerCase()
    switch (namespace) {
      case 'tags':
        return 'tag'
      case 'parodies':
        return 'parody'
      case 'characters':
        return 'character'
      case 'artists':
        return 'artist'
      case 'groups':
        return 'group'
      case 'languages':
        return 'language'
      case 'categories':
        return 'category'
      default:
        return namespace.length <= MAX_FIELD_LENGTH ? namespace : ''
    }
  }

  private static normalizedRawName(value: string): string {
    const rawName: string = value.trim().toLowerCase()
    return rawName.length <= MAX_FIELD_LENGTH ? rawName : ''
  }

  private static cleanDisplayName(value: Object): string {
    const withoutImageMarkdown: string = TagTranslationUpdateService.safeString(value)
      .replace(/!\[(\S+)?\]\(.+?\)(\s+)?(\S+)/g, '$3')
      .trim()
    return withoutImageMarkdown.length <= MAX_FIELD_LENGTH ? withoutImageMarkdown : ''
  }

  private static asArray(value: Object): Object[] {
    return Array.isArray(value) ? value as Object[] : []
  }

  private static asRecord(value: Object): Record<string, Object> {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
      return {}
    }
    return value as Record<string, Object>
  }

  private static safeString(value: Object): string {
    return typeof value === 'string' ? value.trim() : ''
  }

  private static fingerprintBytes(seed: number, data: ArrayBuffer): number {
    const bytes: Uint8Array = new Uint8Array(data)
    let value: number = seed
    for (let index: number = 0; index < bytes.length; index++) {
      value = (value ^ bytes[index]) >>> 0
      value = Math.imul(value, 16777619) >>> 0
    }
    return value
  }

  private static cacheDirectory(context: common.UIAbilityContext): string {
    return `${context.cacheDir}/${CACHE_DIRECTORY_NAME}`
  }

  private static downloadPartPath(context: common.UIAbilityContext): string {
    return `${TagTranslationUpdateService.cacheDirectory(context)}/${DOWNLOAD_PART_NAME}`
  }

  private static ensureDirectory(directory: string): void {
    try {
      fileIo.mkdirSync(directory, true)
    } catch (error) {
      if (!fileIo.accessSync(directory)) {
        throw error as Error
      }
    }
  }

  private static removeIfExists(path: string): void {
    try {
      fileIo.unlinkSync(path)
    } catch (_error) {}
  }
}
