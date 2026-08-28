import { common } from '@kit.AbilityKit'
import { zlib } from '@kit.BasicServicesKit'
import { fileIo } from '@kit.CoreFileKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import util from '@ohos.util'
import { NhTagTranslationEntry, NhTagTranslationStatus } from '../model/NhTagTranslation'
import { AxiosHttpClient, AxiosTextResponse } from '../network/AxiosHttpClient'
import { StreamingHttpClient, StreamingHttpResponse } from '../network/StreamingHttpClient'
import { TagTranslationRepository } from '../storage/TagTranslationRepository'

class PublicDictionarySource {
  label: string = ''
  url: string = ''

  constructor(label: string, url: string) {
    this.label = label
    this.url = url
  }
}

export class TagDictionaryUpdateAttempt {
  phase: string = ''
  source: string = ''
  outcome: string = ''
  httpStatus: number = 0
}

export class TagDictionaryUpdateFailure extends Error {
  readonly phase: string
  readonly attempts: TagDictionaryUpdateAttempt[]
  readonly dictionaryRetained: boolean

  constructor(phase: string, attempts: TagDictionaryUpdateAttempt[], dictionaryRetained: boolean) {
    super(`Tag dictionary ${phase} update failed.`)
    this.phase = phase
    this.attempts = attempts
    this.dictionaryRetained = dictionaryRetained
  }
}

const PUBLIC_DICTIONARY_DIRECT_URL: string =
  'https://github.com/EhTagTranslation/Database/releases/latest/download/db.raw.json.gz'
const PUBLIC_DICTIONARY_MIRROR_URL: string =
  'https://ghproxy.homeboyc.cn/https://github.com/EhTagTranslation/Database/releases/latest/download/db.raw.json.gz'
const PUBLIC_DICTIONARY_SOURCES: PublicDictionarySource[] = [
  new PublicDictionarySource('direct', PUBLIC_DICTIONARY_DIRECT_URL),
  new PublicDictionarySource('mirror', PUBLIC_DICTIONARY_MIRROR_URL),
]
const PUBLIC_RELEASE_DIRECT_URL: string =
  'https://api.github.com/repos/EhTagTranslation/Database/releases/latest'
const PUBLIC_RELEASE_MIRROR_URL: string =
  'https://ghproxy.homeboyc.cn/https://api.github.com/repos/EhTagTranslation/Database/releases/latest'
const PUBLIC_RELEASE_SOURCES: PublicDictionarySource[] = [
  new PublicDictionarySource('direct', PUBLIC_RELEASE_DIRECT_URL),
  new PublicDictionarySource('mirror', PUBLIC_RELEASE_MIRROR_URL),
]
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
const RELEASE_METADATA_CONNECT_TIMEOUT_MS: number = 5000
const RELEASE_METADATA_READ_TIMEOUT_MS: number = 5000
const MAX_RELEASE_METADATA_CHARS: number = 64 * 1024
const MAX_RELEASE_METADATA_FIELD_LENGTH: number = 256
const RELEASE_ASSET_NAME: string = 'db.raw.json.gz'
const UPDATE_PHASE_DICTIONARY_ASSET: string = 'dictionary_asset'
const UPDATE_PHASE_CONTENT_VALIDATION: string = 'content_validation'
const UPDATE_PHASE_LOCAL_STORAGE: string = 'local_storage'
const UPDATE_OUTCOME_HTTP: string = 'http'
const UPDATE_OUTCOME_TRANSPORT: string = 'transport'
const UPDATE_OUTCOME_INVALID: string = 'invalid'

class DownloadArtifact {
  path: string = ''
  version: string = ''
}

class ReleaseDescriptor {
  version: string = ''
  publishedAt: string = ''
  bytes: number = 0
  sha256: string = ''
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
    preferMirror: boolean = false,
  ): Promise<NhTagTranslationStatus> {
    if (TagTranslationUpdateService.updateTask !== null) {
      return await TagTranslationUpdateService.updateTask
    }
    const task: Promise<NhTagTranslationStatus> =
      TagTranslationUpdateService.updateInternal(context, force, preferMirror)
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
    preferMirror: boolean,
  ): Promise<NhTagTranslationStatus> {
    let previous: NhTagTranslationStatus
    try {
      previous = await TagTranslationRepository.status(context)
    } catch (_error) {
      throw new TagDictionaryUpdateFailure(UPDATE_PHASE_LOCAL_STORAGE, [], false)
    }
    const dictionaryRetained: boolean = previous.rowCount > 0
    const previousRelease: ReleaseDescriptor | null =
      TagTranslationUpdateService.storedReleaseDescriptor(previous.version)
    const release: ReleaseDescriptor | null =
      await TagTranslationUpdateService.tryFetchReleaseDescriptor(preferMirror)
    if (!force && previous.rowCount > 0 && release !== null && previous.version === release.version) {
      return previous
    }
    if (previous.rowCount > 0 && release !== null && previousRelease !== null && release.version !== previous.version &&
      release.publishedAt <= previousRelease.publishedAt) {
      return previous
    }
    let artifact: DownloadArtifact | null = null
    try {
      artifact = await TagTranslationUpdateService.downloadFromPublicSources(
        context,
        release,
        release === null && previous.rowCount > 0 && previousRelease !== null ? previousRelease.sha256 : '',
        dictionaryRetained,
        preferMirror,
      )
      let storedVersion: string = artifact.version
      if (release !== null) {
        storedVersion = release.version
      } else if (previous.rowCount > 0 && previousRelease !== null) {
        storedVersion = previous.version
        if (!force && previous.rowCount > 0) {
          return previous
        }
      }
      if (!force && previous.rowCount > 0 && previous.version === storedVersion) {
        return previous
      }
      let entries: NhTagTranslationEntry[]
      try {
        const rawJson: string = await TagTranslationUpdateService.readGzipText(artifact.path)
        entries = TagTranslationUpdateService.parseDictionary(rawJson)
      } catch (error) {
        throw TagTranslationUpdateService.updateFailure(
          error as Error,
          UPDATE_PHASE_CONTENT_VALIDATION,
          '',
          dictionaryRetained,
        )
      }
      try {
        await TagTranslationRepository.replace(context, entries, storedVersion, PROVIDER_LABEL)
        return TagTranslationUpdateService.updatedDictionaryStatus(entries.length, storedVersion)
      } catch (error) {
        throw TagTranslationUpdateService.updateFailure(
          error as Error,
          UPDATE_PHASE_LOCAL_STORAGE,
          '',
          dictionaryRetained,
        )
      }
    } finally {
      if (artifact !== null && artifact.path.length > 0) {
        TagTranslationUpdateService.removeIfExists(artifact.path)
      }
      TagTranslationUpdateService.removeIfExists(TagTranslationUpdateService.downloadPartPath(context))
    }
  }

  /**
   * Metadata describes the fixed asset's expected identity; it never supplies a
   * download URL. If it is unavailable, legacy imports retain the fixed-asset
   * path while an existing verified Release accepts only its known SHA-256.
   */
  private static async tryFetchReleaseDescriptor(
    preferMirror: boolean,
  ): Promise<ReleaseDescriptor | null> {
    const sources: PublicDictionarySource[] =
      TagTranslationUpdateService.orderedSources(PUBLIC_RELEASE_SOURCES, preferMirror)
    for (let index: number = 0; index < sources.length; index++) {
      const source: PublicDictionarySource = sources[index]
      const descriptor: ReleaseDescriptor | null = await TagTranslationUpdateService.fetchReleaseDescriptor(source)
      if (descriptor !== null) {
        return descriptor
      }
    }
    return null
  }

  private static async fetchReleaseDescriptor(
    source: PublicDictionarySource,
  ): Promise<ReleaseDescriptor | null> {
    try {
      const headers: Record<string, string> = {}
      headers['Accept'] = 'application/vnd.github+json, application/json'
      headers['User-Agent'] = 'NextN/1.0.0'
      const response: AxiosTextResponse = await AxiosHttpClient.requestText(
        source.url,
        'GET',
        headers,
        '',
        RELEASE_METADATA_CONNECT_TIMEOUT_MS,
        RELEASE_METADATA_READ_TIMEOUT_MS,
        MAX_RELEASE_METADATA_CHARS,
      )
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null
      }
      const rawMetadata: string = response.body
      if (rawMetadata.length === 0 || rawMetadata.length > MAX_RELEASE_METADATA_CHARS) {
        return null
      }
      const descriptor: ReleaseDescriptor | null = TagTranslationUpdateService.releaseDescriptorFromMetadata(rawMetadata)
      return descriptor
    } catch (_error) {
      return null
    }
  }

  private static releaseDescriptorFromMetadata(rawMetadata: string): ReleaseDescriptor | null {
    let parsed: Object
    try {
      parsed = JSON.parse(rawMetadata) as Object
    } catch (_error) {
      return null
    }
    const metadata: Record<string, Object> = TagTranslationUpdateService.asRecord(parsed)
    const tagName: string = TagTranslationUpdateService.releaseMetadataField(metadata['tag_name'])
    const publishedAt: string = TagTranslationUpdateService.releaseMetadataField(metadata['published_at'])
    if (tagName.length === 0 || !TagTranslationUpdateService.isGithubReleaseTimestamp(publishedAt)) {
      return null
    }
    const assets: Object[] = TagTranslationUpdateService.asArray(metadata['assets'])
    for (let index: number = 0; index < assets.length; index++) {
      const asset: Record<string, Object> = TagTranslationUpdateService.asRecord(assets[index])
      if (TagTranslationUpdateService.safeString(asset['name']) !== RELEASE_ASSET_NAME) {
        continue
      }
      const bytes: number = TagTranslationUpdateService.releaseAssetBytes(asset['size'])
      const sha256: string = TagTranslationUpdateService.releaseAssetSha256(asset['digest'])
      if (bytes <= 0 || sha256.length === 0) {
        continue
      }
      const descriptor: ReleaseDescriptor = new ReleaseDescriptor()
      descriptor.version = `release:${tagName}\u001f${publishedAt}\u001f${sha256}`
      descriptor.publishedAt = publishedAt
      descriptor.bytes = bytes
      descriptor.sha256 = sha256
      return descriptor
    }
    return null
  }

  private static releaseMetadataField(value: Object): string {
    const field: string = TagTranslationUpdateService.safeString(value)
    return field.length <= MAX_RELEASE_METADATA_FIELD_LENGTH && field.indexOf('\u001f') < 0 ? field : ''
  }

  private static releaseAssetBytes(value: Object): number {
    if (typeof value !== 'number' || !Number.isSafeInteger(value) || value <= 0 || value > DOWNLOAD_LIMIT_BYTES) {
      return 0
    }
    return value
  }

  private static releaseAssetSha256(value: Object): string {
    const digest: string = TagTranslationUpdateService.safeString(value).toLowerCase()
    if (!digest.startsWith('sha256:')) {
      return ''
    }
    const hash: string = digest.slice('sha256:'.length)
    return hash.length === 64 && /^[0-9a-f]+$/.test(hash) ? hash : ''
  }

  /**
   * The optional update keeps its current direct GitHub path first, then retries
   * the same public release through the reference app's configured mirror. Each
   * source attempt keeps its existing best-effort temporary-file cleanup; the
   * committed dictionary remains untouched until parsing and replacement commit.
   */
  private static async downloadFromPublicSources(
    context: common.UIAbilityContext,
    expectedRelease: ReleaseDescriptor | null,
    requiredExistingSha256: string,
    dictionaryRetained: boolean,
    preferMirror: boolean,
  ): Promise<DownloadArtifact> {
    const attempts: TagDictionaryUpdateAttempt[] = []
    const sources: PublicDictionarySource[] =
      TagTranslationUpdateService.orderedSources(PUBLIC_DICTIONARY_SOURCES, preferMirror)
    for (let index: number = 0; index < sources.length; index++) {
      const source: PublicDictionarySource = sources[index]
      try {
        return await TagTranslationUpdateService.downloadToPrivateFile(
          context,
          source.url,
          expectedRelease,
          requiredExistingSha256,
        )
      } catch (error) {
        if (error instanceof TagDictionaryUpdateFailure &&
          (error as TagDictionaryUpdateFailure).phase === UPDATE_PHASE_LOCAL_STORAGE) {
          throw new TagDictionaryUpdateFailure(UPDATE_PHASE_LOCAL_STORAGE, [], dictionaryRetained)
        }
        attempts.push(TagTranslationUpdateService.dictionaryAttempt(source.label, error as Error))
      }
    }
    throw new TagDictionaryUpdateFailure(
      TagTranslationUpdateService.failurePhase(attempts),
      attempts,
      dictionaryRetained,
    )
  }

  /** Mirror-first when the user enables the mirror preference; otherwise direct-first. */
  private static orderedSources(
    sources: PublicDictionarySource[],
    preferMirror: boolean,
  ): PublicDictionarySource[] {
    if (!preferMirror || sources.length < 2) {
      return sources
    }
    const ordered: PublicDictionarySource[] = []
    for (let index: number = 0; index < sources.length; index++) {
      if (sources[index].label === 'mirror') {
        ordered.push(sources[index])
      }
    }
    for (let index: number = 0; index < sources.length; index++) {
      if (sources[index].label !== 'mirror') {
        ordered.push(sources[index])
      }
    }
    return ordered
  }

  private static async downloadToPrivateFile(
    context: common.UIAbilityContext,
    url: string,
    expectedRelease: ReleaseDescriptor | null,
    requiredExistingSha256: string,
  ): Promise<DownloadArtifact> {
    const directory: string = TagTranslationUpdateService.cacheDirectory(context)
    const partPath: string = TagTranslationUpdateService.downloadPartPath(context)
    const finalPath: string = `${directory}/${DOWNLOAD_NAME}`
    try {
      TagTranslationUpdateService.ensureDirectory(directory)
      TagTranslationUpdateService.removeIfExists(partPath)
    } catch (_error) {
      throw TagTranslationUpdateService.localStorageFailure()
    }
    let file: fileIo.File | null = null
    let written: number = 0
    let fingerprint: number = 2166136261
    let tooLarge: boolean = false
    let localWriteFailure: boolean = false
    let completed: boolean = false
    const sha256 = cryptoFramework.createMd('SHA256')
    try {
      try {
        file = fileIo.openSync(
          partPath,
          fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
        )
      } catch (_error) {
        throw TagTranslationUpdateService.localStorageFailure()
      }
      const headers: Record<string, string> = {}
      headers['Accept'] = 'application/gzip, application/octet-stream'
      headers['User-Agent'] = 'NextN/1.0.0'
      const response: StreamingHttpResponse = await StreamingHttpClient.get(
        url,
        headers,
        CONNECT_TIMEOUT_MS,
        READ_TIMEOUT_MS,
        DOWNLOAD_LIMIT_BYTES,
        (data: ArrayBuffer): boolean => {
          if (file === null || localWriteFailure) {
            return false
          }
          try {
            const count: number = fileIo.writeSync(file.fd, data)
            if (count !== data.byteLength) {
              throw new Error('Unable to save the tag dictionary download')
            }
            fingerprint = TagTranslationUpdateService.fingerprintBytes(fingerprint, data)
            sha256.updateSync({ data: new Uint8Array(data) })
            written += count
            return true
          } catch (_error) {
            localWriteFailure = true
            return false
          }
        },
      )
      tooLarge = response.limitExceeded
      if (tooLarge) {
        throw TagTranslationUpdateService.contentValidationFailure()
      }
      if (localWriteFailure || response.sinkRejected) {
        throw TagTranslationUpdateService.localStorageFailure()
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw new TagDictionaryUpdateFailure(
          UPDATE_PHASE_DICTIONARY_ASSET,
          [TagTranslationUpdateService.updateAttempt(
            UPDATE_PHASE_DICTIONARY_ASSET,
            '',
            UPDATE_OUTCOME_HTTP,
            response.statusCode,
          )],
          false,
        )
      }
      if (written <= 0) {
        throw TagTranslationUpdateService.contentValidationFailure()
      }
      let actualSha256: string
      try {
        actualSha256 = TagTranslationUpdateService.toHex(sha256.digestSync().data)
      } catch (_error) {
        throw TagTranslationUpdateService.localStorageFailure()
      }
      const matchesExpectedRelease: boolean = expectedRelease !== null &&
        written === expectedRelease.bytes && actualSha256 === expectedRelease.sha256
      if (expectedRelease !== null && !matchesExpectedRelease) {
        throw TagTranslationUpdateService.contentValidationFailure()
      }
      if (expectedRelease === null && requiredExistingSha256.length > 0 &&
        actualSha256 !== requiredExistingSha256) {
        throw TagTranslationUpdateService.contentValidationFailure()
      }
      try {
        fileIo.closeSync(file)
        file = null
        TagTranslationUpdateService.removeIfExists(finalPath)
        fileIo.renameSync(partPath, finalPath)
      } catch (_error) {
        throw TagTranslationUpdateService.localStorageFailure()
      }
      completed = true
      const artifact: DownloadArtifact = new DownloadArtifact()
      artifact.path = finalPath
      artifact.version = `bytes-${written}-fnv1a-${fingerprint.toString(16)}`
      return artifact
    } finally {
      if (file !== null) {
        TagTranslationUpdateService.closeFileQuietly(file)
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
          throw new Error('The tag dictionary exceeded its decompression limit')
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
      throw new Error('The tag dictionary was not valid JSON')
    }
    const root: Record<string, Object> = TagTranslationUpdateService.asRecord(parsed)
    const groups: Object[] = TagTranslationUpdateService.asArray(root['data'])
    if (groups.length === 0) {
      throw new Error('The tag dictionary had an unsupported structure')
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
          throw new Error('The tag dictionary contained too many entries')
        }
      }
    }
    if (entries.length === 0) {
      throw new Error('The tag dictionary contained no usable entries')
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

  private static toHex(bytes: Uint8Array): string {
    const parts: string[] = []
    for (let index: number = 0; index < bytes.length; index++) {
      parts.push(bytes[index].toString(16).padStart(2, '0'))
    }
    return parts.join('')
  }

  private static updateAttempt(
    phase: string,
    source: string,
    outcome: string,
    httpStatus: number = 0,
  ): TagDictionaryUpdateAttempt {
    const attempt: TagDictionaryUpdateAttempt = new TagDictionaryUpdateAttempt()
    attempt.phase = phase
    attempt.source = source
    attempt.outcome = outcome
    attempt.httpStatus = httpStatus
    return attempt
  }

  private static localStorageFailure(): TagDictionaryUpdateFailure {
    return new TagDictionaryUpdateFailure(UPDATE_PHASE_LOCAL_STORAGE, [], false)
  }

  private static contentValidationFailure(): TagDictionaryUpdateFailure {
    return new TagDictionaryUpdateFailure(UPDATE_PHASE_CONTENT_VALIDATION, [], false)
  }

  private static dictionaryAttempt(source: string, error: Error): TagDictionaryUpdateAttempt {
    if (error instanceof TagDictionaryUpdateFailure) {
      const failure: TagDictionaryUpdateFailure = error as TagDictionaryUpdateFailure
      if (failure.attempts.length > 0) {
        const original: TagDictionaryUpdateAttempt = failure.attempts[0]
        return TagTranslationUpdateService.updateAttempt(
          original.phase,
          source,
          original.outcome,
          original.httpStatus,
        )
      }
      return TagTranslationUpdateService.updateAttempt(failure.phase, source, UPDATE_OUTCOME_INVALID)
    }
    return TagTranslationUpdateService.updateAttempt(
      UPDATE_PHASE_DICTIONARY_ASSET,
      source,
      UPDATE_OUTCOME_TRANSPORT,
    )
  }

  private static updateFailure(
    error: Error,
    fallbackPhase: string,
    source: string,
    dictionaryRetained: boolean,
  ): TagDictionaryUpdateFailure {
    if (error instanceof TagDictionaryUpdateFailure) {
      const failure: TagDictionaryUpdateFailure = error as TagDictionaryUpdateFailure
      return new TagDictionaryUpdateFailure(
        failure.phase,
        failure.attempts,
        dictionaryRetained,
      )
    }
    if (source.length === 0) {
      return new TagDictionaryUpdateFailure(fallbackPhase, [], dictionaryRetained)
    }
    return new TagDictionaryUpdateFailure(
      fallbackPhase,
      [
        TagTranslationUpdateService.dictionaryAttempt(source, error),
      ],
      dictionaryRetained,
    )
  }

  private static failurePhase(attempts: TagDictionaryUpdateAttempt[]): string {
    for (let index: number = 0; index < attempts.length; index++) {
      if (attempts[index].phase === UPDATE_PHASE_CONTENT_VALIDATION) {
        return UPDATE_PHASE_CONTENT_VALIDATION
      }
    }
    return UPDATE_PHASE_DICTIONARY_ASSET
  }

  private static storedReleaseDescriptor(value: string): ReleaseDescriptor | null {
    const parts: string[] = value.split('\u001f')
    const tagName: string = parts.length > 0 && parts[0].startsWith('release:')
      ? parts[0].slice('release:'.length)
      : ''
    if (parts.length !== 3 || tagName.length === 0 || tagName.length > MAX_RELEASE_METADATA_FIELD_LENGTH ||
      tagName.indexOf('\u001f') >= 0) {
      return null
    }
    if (!TagTranslationUpdateService.isGithubReleaseTimestamp(parts[1]) ||
      !/^[0-9a-f]{64}$/.test(parts[2])) {
      return null
    }
    const descriptor: ReleaseDescriptor = new ReleaseDescriptor()
    descriptor.version = value
    descriptor.publishedAt = parts[1]
    descriptor.sha256 = parts[2]
    return descriptor
  }

  private static isGithubReleaseTimestamp(value: string): boolean {
    return /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(value)
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

  private static updatedDictionaryStatus(rowCount: number, version: string): NhTagTranslationStatus {
    const status: NhTagTranslationStatus = new NhTagTranslationStatus()
    status.rowCount = rowCount
    status.version = version
    status.source = PROVIDER_LABEL
    status.updatedAt = Date.now()
    return status
  }

  private static closeFileQuietly(file: fileIo.File): void {
    try {
      fileIo.closeSync(file)
    } catch (_error) {}
  }
}
