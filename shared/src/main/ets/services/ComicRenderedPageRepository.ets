import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileIo } from '@kit.CoreFileKit'
import {
  ComicRenderedPage,
  ComicRenderedPageIdentity,
} from '../model/ComicVisualTranslation'
import { CacheStat } from './CacheStat'
import { ComicVisualPageSource } from './ComicVisualTranslationBackend'
import { ComicVisualTranslationContract } from './ComicVisualTranslationContract'

const RECORD_VERSION: number = 1
const CACHE_DIR: string = 'comic-translated-pages'
const MAX_METADATA_CHARS: number = 128 * 1024
const MAX_RECORDS: number = 64
const MAX_CACHE_BYTES: number = 512 * 1024 * 1024
const HASH_CHUNK_BYTES: number = 256 * 1024

class ComicRenderedPageCacheRecord {
  version: number = RECORD_VERSION
  lookupKey: string = ''
  page: ComicRenderedPage = new ComicRenderedPage()
}

class ComicRenderedPageDiskRecord {
  metadataPath: string = ''
  page: ComicRenderedPage = new ComicRenderedPage()
}

export interface ComicRenderedPageRepository {
  load(lookupKey: string): Promise<ComicRenderedPage | null>

  loadLatest(source: ComicVisualPageSource, targetLanguage: string): Promise<ComicRenderedPage | null>

  save(lookupKey: string, page: ComicRenderedPage): Promise<void>

  discardArtifact(page: ComicRenderedPage): Promise<void>

  stat(): Promise<CacheStat>

  clear(): Promise<void>
}

export class ComicRenderedPageRepositoryContract {
  static validateLookupKey(lookupKey: string): void {
    if (!/^[a-f0-9]{64}$/.test(lookupKey)) {
      throw new Error('Comic rendered page lookup key is invalid')
    }
  }

  static matchesScope(
    page: ComicRenderedPage,
    source: ComicVisualPageSource,
    targetLanguage: string,
  ): boolean {
    try {
      ComicVisualTranslationContract.validateRenderedPage(page.identity, page)
      return page.identity.projectId === source.projectId &&
        page.identity.pageIndex === source.pageIndex &&
        page.identity.sourceImageHash === source.imageHash &&
        page.identity.sourceWidth === source.imageWidth &&
        page.identity.sourceHeight === source.imageHeight &&
        page.identity.targetLanguage === targetLanguage
    } catch (_error) {
      return false
    }
  }
}

/** Process-local repository useful when a caller deliberately disables durable cache. */
export class InMemoryComicRenderedPageRepository implements ComicRenderedPageRepository {
  private records: Map<string, ComicRenderedPage> = new Map<string, ComicRenderedPage>()

  async load(lookupKey: string): Promise<ComicRenderedPage | null> {
    ComicRenderedPageRepositoryContract.validateLookupKey(lookupKey)
    const stored: ComicRenderedPage | undefined = this.records.get(lookupKey)
    if (stored === undefined) {
      return null
    }
    const page: ComicRenderedPage = stored.copy()
    page.lastAccessAt = Math.max(page.createdAt, Date.now())
    this.records.delete(lookupKey)
    this.records.set(lookupKey, page.copy())
    return page
  }

  async loadLatest(
    source: ComicVisualPageSource,
    targetLanguage: string,
  ): Promise<ComicRenderedPage | null> {
    ComicVisualTranslationContract.validateSource(source)
    let latest: ComicRenderedPage | null = null
    this.records.forEach((page: ComicRenderedPage): void => {
      if (ComicRenderedPageRepositoryContract.matchesScope(page, source, targetLanguage) &&
        (latest === null || page.createdAt > latest.createdAt)) {
        latest = page.copy()
      }
    })
    return latest
  }

  async save(lookupKey: string, page: ComicRenderedPage): Promise<void> {
    ComicRenderedPageRepositoryContract.validateLookupKey(lookupKey)
    ComicVisualTranslationContract.validateRenderedPage(page.identity, page)
    this.records.delete(lookupKey)
    this.records.set(lookupKey, page.copy())
    while (this.records.size > MAX_RECORDS) {
      const oldest: string | undefined = this.records.keys().next().value
      if (oldest === undefined) {
        break
      }
      this.records.delete(oldest)
    }
  }

  async discardArtifact(_page: ComicRenderedPage): Promise<void> {}

  async stat(): Promise<CacheStat> {
    const result: CacheStat = new CacheStat()
    result.count = this.records.size
    this.records.forEach((page: ComicRenderedPage): void => {
      result.bytes += page.byteLength
    })
    return result
  }

  async clear(): Promise<void> {
    this.records.clear()
  }
}

/** Bounded private filesystem index for derived Reader translation images. */
export class PersistentComicRenderedPageRepository implements ComicRenderedPageRepository {
  private readonly context: common.UIAbilityContext
  private readonly directoryName: string
  private mutationTail: Promise<void> = Promise.resolve()
  private epoch: number = 0
  private clearing: boolean = false

  constructor(context: common.UIAbilityContext, directoryName: string = CACHE_DIR) {
    if (!/^[a-z0-9-]{1,80}$/.test(directoryName)) {
      throw new Error('Comic rendered page cache directory is invalid')
    }
    this.context = context
    this.directoryName = directoryName
  }

  async load(lookupKey: string): Promise<ComicRenderedPage | null> {
    ComicRenderedPageRepositoryContract.validateLookupKey(lookupKey)
    const epoch: number = this.epoch
    let output: ComicRenderedPage | null = null
    await this.enqueue(async (): Promise<void> => {
      if (this.clearing || epoch !== this.epoch) {
        return
      }
      output = this.loadRecord(this.metadataPath(lookupKey), lookupKey, true)
    })
    return this.clearing || epoch !== this.epoch ? null : output
  }

  async loadLatest(
    source: ComicVisualPageSource,
    targetLanguage: string,
  ): Promise<ComicRenderedPage | null> {
    ComicVisualTranslationContract.validateSource(source)
    const epoch: number = this.epoch
    let output: ComicRenderedPage | null = null
    await this.enqueue(async (): Promise<void> => {
      if (this.clearing || epoch !== this.epoch) {
        return
      }
      const records: ComicRenderedPageDiskRecord[] = this.records(true)
      for (let index: number = 0; index < records.length; index++) {
        const page: ComicRenderedPage = records[index].page
        if (ComicRenderedPageRepositoryContract.matchesScope(page, source, targetLanguage) &&
          (output === null || page.createdAt > output.createdAt)) {
          output = page.copy()
        }
      }
    })
    return this.clearing || epoch !== this.epoch ? null : output
  }

  async save(lookupKey: string, page: ComicRenderedPage): Promise<void> {
    ComicRenderedPageRepositoryContract.validateLookupKey(lookupKey)
    ComicVisualTranslationContract.validateRenderedPage(page.identity, page)
    this.validateArtifact(page)
    const copy: ComicRenderedPage = page.copy()
    const epoch: number = this.epoch
    await this.enqueue(async (): Promise<void> => {
      if (this.clearing || epoch !== this.epoch) {
        return
      }
      const path: string = this.metadataPath(lookupKey)
      this.writeRecord(path, lookupKey, copy)
      this.prune(path)
    })
  }

  async discardArtifact(page: ComicRenderedPage): Promise<void> {
    ComicVisualTranslationContract.validateRenderedPage(page.identity, page)
    const path: string = page.localFilePath
    await this.enqueue(async (): Promise<void> => {
      const records: ComicRenderedPageDiskRecord[] = this.records(false)
      for (let index: number = 0; index < records.length; index++) {
        if (records[index].page.localFilePath === path) {
          return
        }
      }
      this.removeSafeArtifact(path)
    })
  }

  async stat(): Promise<CacheStat> {
    const output: CacheStat = new CacheStat()
    await this.enqueue(async (): Promise<void> => {
      const records: ComicRenderedPageDiskRecord[] = this.records(false)
      output.count = records.length
      for (let index: number = 0; index < records.length; index++) {
        output.bytes += records[index].page.byteLength
      }
    })
    return output
  }

  async clear(): Promise<void> {
    this.epoch++
    const clearEpoch: number = this.epoch
    this.clearing = true
    try {
      await this.enqueue(async (): Promise<void> => {
        const dir: string = this.cacheDir()
        if (!fileIo.accessSync(dir)) {
          return
        }
        const names: string[] = fileIo.listFileSync(dir)
        for (let index: number = 0; index < names.length; index++) {
          if (/^[a-f0-9]{64}\.json$/.test(names[index]) ||
            /^[a-f0-9]{64}-[a-f0-9]{64}\.png$/.test(names[index]) ||
            names[index].includes('.part-')) {
            this.removeFile(dir + '/' + names[index])
          }
        }
      })
    } finally {
      if (this.epoch === clearEpoch) {
        this.clearing = false
      }
    }
  }

  private loadRecord(
    metadataPath: string,
    expectedLookupKey: string,
    updateAccess: boolean,
  ): ComicRenderedPage | null {
    if (!fileIo.accessSync(metadataPath)) {
      return null
    }
    try {
      const record: ComicRenderedPageCacheRecord =
        JSON.parse(this.readText(metadataPath)) as ComicRenderedPageCacheRecord
      if (record.version !== RECORD_VERSION || record.lookupKey !== expectedLookupKey) {
        throw new Error('Comic rendered page metadata identity mismatch')
      }
      const page: ComicRenderedPage = this.copyRawPage(record.page)
      this.validateArtifact(page)
      if (updateAccess) {
        page.lastAccessAt = Math.max(page.createdAt, Date.now())
        this.writeRecord(metadataPath, expectedLookupKey, page)
      }
      return page
    } catch (_error) {
      this.removeFile(metadataPath)
      return null
    }
  }

  private records(verifyArtifact: boolean): ComicRenderedPageDiskRecord[] {
    const output: ComicRenderedPageDiskRecord[] = []
    const dir: string = this.cacheDir()
    if (!fileIo.accessSync(dir)) {
      return output
    }
    const names: string[] = fileIo.listFileSync(dir)
    for (let index: number = 0; index < names.length; index++) {
      if (!/^[a-f0-9]{64}\.json$/.test(names[index])) {
        continue
      }
      const metadataPath: string = dir + '/' + names[index]
      try {
        const record: ComicRenderedPageCacheRecord =
          JSON.parse(this.readText(metadataPath)) as ComicRenderedPageCacheRecord
        ComicRenderedPageRepositoryContract.validateLookupKey(record.lookupKey)
        if (record.version !== RECORD_VERSION || this.metadataPath(record.lookupKey) !== metadataPath) {
          throw new Error('Comic rendered page metadata is invalid')
        }
        const page: ComicRenderedPage = this.copyRawPage(record.page)
        if (verifyArtifact) {
          this.validateArtifact(page)
        } else {
          this.validateArtifactStat(page)
        }
        const disk: ComicRenderedPageDiskRecord = new ComicRenderedPageDiskRecord()
        disk.metadataPath = metadataPath
        disk.page = page
        output.push(disk)
      } catch (_error) {
        this.removeFile(metadataPath)
      }
    }
    return output
  }

  private writeRecord(metadataPath: string, lookupKey: string, page: ComicRenderedPage): void {
    const record: ComicRenderedPageCacheRecord = new ComicRenderedPageCacheRecord()
    record.lookupKey = lookupKey
    record.page = page.copy()
    const text: string = JSON.stringify(record)
    if (text.length <= 0 || text.length > MAX_METADATA_CHARS) {
      throw new Error('Comic rendered page metadata size is invalid')
    }
    this.ensureDir(this.cacheDir())
    const partial: string = metadataPath + '.part-' + util.generateRandomUUID(true)
    try {
      this.writeText(partial, text)
      fileIo.renameSync(partial, metadataPath)
    } catch (error) {
      this.removeFile(partial)
      throw error as Error
    }
  }

  private prune(protectedPath: string): void {
    const records: ComicRenderedPageDiskRecord[] = this.records(false)
    records.sort((left: ComicRenderedPageDiskRecord, right: ComicRenderedPageDiskRecord): number =>
      left.page.lastAccessAt - right.page.lastAccessAt)
    let bytes: number = 0
    for (let index: number = 0; index < records.length; index++) {
      bytes += records[index].page.byteLength
    }
    let count: number = records.length
    for (let index: number = 0; index < records.length; index++) {
      if ((count <= MAX_RECORDS && bytes <= MAX_CACHE_BYTES) || count <= 1) {
        break
      }
      if (records[index].metadataPath === protectedPath) {
        continue
      }
      this.removeSafeArtifact(records[index].page.localFilePath)
      this.removeFile(records[index].metadataPath)
      bytes -= records[index].page.byteLength
      count--
    }
  }

  private validateArtifact(page: ComicRenderedPage): void {
    this.validateArtifactStat(page)
    if (this.hashFile(page.localFilePath, page.byteLength) !== page.artifactHash) {
      throw new Error('Comic rendered page artifact hash is invalid')
    }
  }

  private validateArtifactStat(page: ComicRenderedPage): void {
    ComicVisualTranslationContract.validateRenderedPage(page.identity, page)
    if (!this.isSafeArtifactPath(page.localFilePath) || !fileIo.accessSync(page.localFilePath)) {
      throw new Error('Comic rendered page artifact path is invalid')
    }
    const stat: fileIo.Stat = fileIo.statSync(page.localFilePath)
    if (!stat.isFile() || Math.floor(stat.size) !== page.byteLength) {
      throw new Error('Comic rendered page artifact size is invalid')
    }
  }

  private copyRawPage(raw: ComicRenderedPage): ComicRenderedPage {
    if (raw === null || typeof raw !== 'object' || raw.identity === null ||
      typeof raw.identity !== 'object') {
      throw new Error('Comic rendered page metadata payload is invalid')
    }
    const page: ComicRenderedPage = new ComicRenderedPage()
    page.identity = this.copyRawIdentity(raw.identity)
    page.artifactHash = raw.artifactHash
    page.mimeType = raw.mimeType
    page.width = raw.width
    page.height = raw.height
    page.byteLength = raw.byteLength
    page.localFilePath = raw.localFilePath
    page.createdAt = raw.createdAt
    page.lastAccessAt = raw.lastAccessAt
    return page
  }

  private copyRawIdentity(raw: ComicRenderedPageIdentity): ComicRenderedPageIdentity {
    const value: ComicRenderedPageIdentity = new ComicRenderedPageIdentity()
    value.schemaVersion = raw.schemaVersion
    value.route = raw.route
    value.projectId = raw.projectId
    value.pageIndex = raw.pageIndex
    value.sourceImageHash = raw.sourceImageHash
    value.sourceWidth = raw.sourceWidth
    value.sourceHeight = raw.sourceHeight
    value.targetLanguage = raw.targetLanguage
    value.regionBackendId = raw.regionBackendId
    value.regionProfileId = raw.regionProfileId
    value.regionRevision = raw.regionRevision
    value.documentRevision = raw.documentRevision
    value.translationSourceProfileId = raw.translationSourceProfileId
    value.translationSourceRevision = raw.translationSourceRevision
    value.translationModelId = raw.translationModelId
    value.translationPromptVersion = raw.translationPromptVersion
    value.translationContextFingerprint = raw.translationContextFingerprint
    value.glossaryRevision = raw.glossaryRevision
    value.translationRevision = raw.translationRevision
    value.sourceTreatmentProfileId = raw.sourceTreatmentProfileId
    value.layoutProfileId = raw.layoutProfileId
    value.renderBackendId = raw.renderBackendId
    value.renderProfileId = raw.renderProfileId
    value.renderTargetMimeType = raw.renderTargetMimeType
    value.renderRevision = raw.renderRevision
    return value
  }

  private metadataPath(lookupKey: string): string {
    return this.cacheDir() + '/' + PersistentComicRenderedPageRepository.sha256Text(lookupKey) + '.json'
  }

  private cacheDir(): string {
    return this.context.cacheDir + '/' + this.directoryName
  }

  private isSafeArtifactPath(path: string): boolean {
    const prefix: string = this.cacheDir() + '/'
    if (!path.startsWith(prefix)) {
      return false
    }
    return /^[a-f0-9]{64}-[a-f0-9]{64}\.png$/.test(path.substring(prefix.length))
  }

  private removeSafeArtifact(path: string): void {
    if (this.isSafeArtifactPath(path)) {
      this.removeFile(path)
    }
  }

  private readText(path: string): string {
    const stat: fileIo.Stat = fileIo.statSync(path)
    const length: number = Math.floor(stat.size)
    if (!stat.isFile() || length <= 0 || length > MAX_METADATA_CHARS) {
      throw new Error('Comic rendered page metadata file size is invalid')
    }
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
      const buffer: ArrayBuffer = new ArrayBuffer(length)
      const read: number = fileIo.readSync(file.fd, buffer, { length: length })
      if (read !== length) {
        throw new Error('Comic rendered page metadata read is incomplete')
      }
      return new util.TextDecoder().decodeToString(new Uint8Array(buffer))
    } finally {
      if (file !== null) {
        fileIo.closeSync(file)
      }
    }
  }

  private writeText(path: string, text: string): void {
    const bytes: Uint8Array = new util.TextEncoder().encodeInto(text)
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(
        path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      const written: number = fileIo.writeSync(file.fd, bytes.buffer, { length: bytes.length })
      if (written !== bytes.length) {
        throw new Error('Comic rendered page metadata write is incomplete')
      }
    } finally {
      if (file !== null) {
        fileIo.closeSync(file)
      }
    }
  }

  private hashFile(path: string, expectedLength: number): string {
    const md = cryptoFramework.createMd('SHA256')
    let file: fileIo.File | null = null
    let total: number = 0
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
      while (total < expectedLength) {
        const length: number = Math.min(HASH_CHUNK_BYTES, expectedLength - total)
        const buffer: ArrayBuffer = new ArrayBuffer(length)
        const read: number = fileIo.readSync(file.fd, buffer, { length: length })
        if (read <= 0) {
          throw new Error('Comic rendered page artifact read is incomplete')
        }
        md.updateSync({ data: new Uint8Array(buffer, 0, read) })
        total += read
      }
      return PersistentComicRenderedPageRepository.toHex(md.digestSync().data)
    } finally {
      if (file !== null) {
        fileIo.closeSync(file)
      }
    }
  }

  private ensureDir(path: string): void {
    try {
      fileIo.mkdirSync(path, true)
    } catch (error) {
      if (!fileIo.accessSync(path)) {
        throw error as Error
      }
    }
  }

  private removeFile(path: string): void {
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path)
      }
    } catch (_error) {}
  }

  private enqueue(work: () => Promise<void>): Promise<void> {
    const task: Promise<void> = this.mutationTail.then(
      (): Promise<void> => work(),
      (): Promise<void> => work(),
    )
    this.mutationTail = task.catch((): void => {})
    return task
  }

  private static sha256Text(value: string): string {
    const md = cryptoFramework.createMd('SHA256')
    md.updateSync({ data: new util.TextEncoder().encodeInto(value) })
    return PersistentComicRenderedPageRepository.toHex(md.digestSync().data)
  }

  private static toHex(bytes: Uint8Array): string {
    const output: string[] = []
    for (let index: number = 0; index < bytes.length; index++) {
      output.push(bytes[index].toString(16).padStart(2, '0'))
    }
    return output.join('')
  }
}
