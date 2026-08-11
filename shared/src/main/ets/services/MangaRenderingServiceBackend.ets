import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileIo } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { ComicPageDocument } from '../model/ComicTranslation'
import { ComicRenderedPage, ComicRegionAnalysisResult } from '../model/ComicVisualTranslation'
import {
  ComicRegionAnalysisRequest,
  ComicRegionRenderBackend,
  ComicRegionRenderRequest,
  ComicVisualPageSource,
} from './ComicVisualTranslationBackend'
import { ComicVisualTranslationContract } from './ComicVisualTranslationContract'
import { MangaRenderingServiceArchive, MangaRenderingServiceExportFiles } from './MangaRenderingServiceArchive'
import { MangaRenderingServiceBinaryResponse, MangaRenderingServiceBinaryTransport } from './MangaRenderingServiceBinaryTransport'
import { MangaRenderingServiceConfig } from './MangaRenderingServiceConfig'
import {
  MANGA_RENDERING_SERVICE_BACKEND_ID,
  MANGA_RENDERING_SERVICE_PROTOCOL_REVISION,
  MangaRenderingServiceProfileCatalog,
} from './MangaRenderingServiceProfileCatalog'
import { MangaRenderingServiceProtocol } from './MangaRenderingServiceProtocol'
import { MangaRenderingServiceCredential } from './MangaRenderingServiceSecretStore'
import { MangaRenderingServiceSession } from './MangaRenderingServiceSession'

const EXPORT_PATH: string = '/translate/export/original'
const IMPORT_PATH: string = '/translate/import/json/nexte-load-text-v2'
const MAX_SOURCE_IMAGE_BYTES: number = 40 * 1024 * 1024
const MAX_MULTIPART_BODY_BYTES: number = 48 * 1024 * 1024
const MAX_EXPORT_RESPONSE_BYTES: number = 6 * 1024 * 1024
const MAX_RENDER_RESPONSE_BYTES: number = 80 * 1024 * 1024
const CONNECT_TIMEOUT_MS: number = 15000
const READ_TIMEOUT_MS: number = 5 * 60 * 1000
const RENDER_CACHE_DIR: string = 'comic-translated-pages'

class MultipartPart {
  name: string = ''
  fileName: string = ''
  contentType: string = ''
  bytes: Uint8Array = new Uint8Array(0)
}

class SourceImage {
  bytes: Uint8Array = new Uint8Array(0)
  mimeType: string = ''
  fileName: string = ''
}

/** Self-hosted manga-translator-ui adapter for the existing staged Reader pipeline. */
export class MangaRenderingServiceBackend implements ComicRegionRenderBackend {
  private readonly context: common.UIAbilityContext
  private readonly baseUrl: string
  private readonly credential: MangaRenderingServiceCredential
  private readonly sourceLanguage: string
  private readonly detectionProfile: string
  private readonly inpaintingProfile: string

  constructor(
    context: common.UIAbilityContext,
    baseUrl: string,
    credential: MangaRenderingServiceCredential,
    sourceLanguage: string,
    detectionProfile: string,
    inpaintingProfile: string,
  ) {
    this.context = context
    this.baseUrl = MangaRenderingServiceConfig.validatedBaseUrl(baseUrl)
    this.credential = credential.copy()
    this.sourceLanguage = sourceLanguage
    MangaRenderingServiceProfileCatalog.assertOptions(detectionProfile, inpaintingProfile)
    this.detectionProfile = detectionProfile
    this.inpaintingProfile = inpaintingProfile
  }

  backendId(): string {
    return MANGA_RENDERING_SERVICE_BACKEND_ID
  }

  profileId(): string {
    return MangaRenderingServiceProfileCatalog.profileId(
      this.sourceLanguage,
      this.detectionProfile,
      this.inpaintingProfile,
    )
  }

  protocolRevision(): number {
    return MANGA_RENDERING_SERVICE_PROTOCOL_REVISION
  }

  hasReplacementCandidates(document: ComicPageDocument): boolean {
    return document.hasText && document.blocks.length > 0
  }

  async analyze(request: ComicRegionAnalysisRequest): Promise<ComicRegionAnalysisResult> {
    ComicVisualTranslationContract.validateRegionAnalysisRequest(request)
    const source: SourceImage = MangaRenderingServiceBackend.readSourceImage(request.source)
    const response: MangaRenderingServiceBinaryResponse = await this.post(
      EXPORT_PATH,
      MangaRenderingServiceBackend.exportParts(this.configJson(), source),
      MAX_EXPORT_RESPONSE_BYTES,
    )
    MangaRenderingServiceBackend.requireSuccess(response, MAX_EXPORT_RESPONSE_BYTES, 'export')
    const files: MangaRenderingServiceExportFiles = await MangaRenderingServiceArchive.extract(
      this.context,
      response.body,
    )
    return MangaRenderingServiceProtocol.parseExport(
      request,
      files.translationJson,
      files.originalText,
      this.profileId(),
    )
  }

  async render(request: ComicRegionRenderRequest): Promise<ComicRenderedPage> {
    ComicVisualTranslationContract.validateStagedRenderRequest(request)
    if (request.identity.renderBackendId !== this.backendId() ||
      request.identity.regionBackendId !== this.backendId() ||
      request.identity.regionProfileId !== this.profileId() ||
      request.adapterTemplate.protocolRevision !== this.protocolRevision()) {
      throw new Error('Manga rendering service render profile identity is invalid')
    }
    const source: SourceImage = MangaRenderingServiceBackend.readSourceImage(request.source)
    const importJson: Uint8Array = MangaRenderingServiceProtocol.buildImportJson(
      request.document,
      request.translations,
      request.adapterTemplate,
    )
    const response: MangaRenderingServiceBinaryResponse = await this.post(
      IMPORT_PATH,
      MangaRenderingServiceBackend.importParts(this.configJson(), source, importJson),
      MAX_RENDER_RESPONSE_BYTES,
    )
    MangaRenderingServiceBackend.requireSuccess(response, MAX_RENDER_RESPONSE_BYTES, 'render')
    await MangaRenderingServiceBackend.validatePng(
      response.body,
      request.source.imageWidth,
      request.source.imageHeight,
    )
    const artifactHash: string = MangaRenderingServiceBackend.sha256(response.body)
    const path: string = MangaRenderingServiceBackend.persist(
      this.context,
      request.identity.cacheKey(),
      artifactHash,
      response.body,
    )
    const now: number = Date.now()
    const page: ComicRenderedPage = new ComicRenderedPage()
    page.identity = request.identity.copy()
    page.artifactHash = artifactHash
    page.mimeType = 'image/png'
    page.width = request.source.imageWidth
    page.height = request.source.imageHeight
    page.byteLength = response.body.length
    page.localFilePath = path
    page.createdAt = now
    page.lastAccessAt = now
    ComicVisualTranslationContract.validateRenderedPage(request.identity, page)
    return page
  }

  private configJson(): string {
    return MangaRenderingServiceProfileCatalog.configJson(
      this.sourceLanguage,
      this.detectionProfile,
      this.inpaintingProfile,
    )
  }

  private async post(path: string, parts: MultipartPart[], maxResponseBytes: number): Promise<MangaRenderingServiceBinaryResponse> {
    const boundary: string = 'NextN' + util.generateRandomUUID(true).replace(/-/g, '')
    const body: Uint8Array = MangaRenderingServiceBackend.multipart(boundary, parts)
    let token: string = await MangaRenderingServiceSession.acquire(this.baseUrl, this.credential)
    let response: MangaRenderingServiceBinaryResponse = await MangaRenderingServiceBinaryTransport.post(
      this.baseUrl + path,
      MangaRenderingServiceBackend.headers(boundary, body.length, token),
      body,
      maxResponseBytes,
      CONNECT_TIMEOUT_MS,
      READ_TIMEOUT_MS,
    )
    if (response.statusCode === 401) {
      MangaRenderingServiceSession.invalidate(this.baseUrl, this.credential, token)
      token = await MangaRenderingServiceSession.acquire(this.baseUrl, this.credential)
      response = await MangaRenderingServiceBinaryTransport.post(
        this.baseUrl + path,
        MangaRenderingServiceBackend.headers(boundary, body.length, token),
        body,
        maxResponseBytes,
        CONNECT_TIMEOUT_MS,
        READ_TIMEOUT_MS,
      )
    }
    return response
  }

  private static headers(boundary: string, length: number, token: string): Record<string, string> {
    return {
      'Accept': 'application/octet-stream, application/zip, image/png',
      'Content-Type': `multipart/form-data; boundary=${boundary}`,
      'Content-Length': `${length}`,
      'X-Session-Token': token,
    }
  }

  private static exportParts(configJson: string, source: SourceImage): MultipartPart[] {
    return [
      MangaRenderingServiceBackend.filePart('image', source.fileName, source.mimeType, source.bytes),
      MangaRenderingServiceBackend.textPart('config', configJson),
    ]
  }

  private static importParts(configJson: string, source: SourceImage, importJson: Uint8Array): MultipartPart[] {
    return [
      MangaRenderingServiceBackend.filePart('image', source.fileName, source.mimeType, source.bytes),
      MangaRenderingServiceBackend.filePart('json_file', 'translation.json', 'application/json', importJson),
      MangaRenderingServiceBackend.textPart('config', configJson),
    ]
  }

  private static textPart(name: string, value: string): MultipartPart {
    const part: MultipartPart = new MultipartPart()
    part.name = name
    part.bytes = new util.TextEncoder().encodeInto(value)
    return part
  }

  private static filePart(name: string, fileName: string, contentType: string, bytes: Uint8Array): MultipartPart {
    const part: MultipartPart = new MultipartPart()
    part.name = name
    part.fileName = fileName
    part.contentType = contentType
    part.bytes = bytes
    return part
  }

  private static multipart(boundary: string, parts: MultipartPart[]): Uint8Array {
    if (!/^[A-Za-z0-9]+$/.test(boundary) || parts.length <= 0 || parts.length > 4) {
      throw new Error('Manga rendering service multipart boundary is invalid')
    }
    const encoder: util.TextEncoder = new util.TextEncoder()
    const chunks: Uint8Array[] = []
    let total: number = 0
    for (let index: number = 0; index < parts.length; index++) {
      const part: MultipartPart = parts[index]
      if (!/^[a-z_]+$/.test(part.name) || /[\r\n"]/.test(part.fileName) ||
        /[\r\n]/.test(part.contentType)) {
        throw new Error('Manga rendering service multipart part is invalid')
      }
      let header: string = `--${boundary}\r\nContent-Disposition: form-data; name="${part.name}"`
      if (part.fileName.length > 0) header += `; filename="${part.fileName}"`
      header += '\r\n'
      if (part.contentType.length > 0) header += `Content-Type: ${part.contentType}\r\n`
      header += '\r\n'
      const headerBytes: Uint8Array = encoder.encodeInto(header)
      const tail: Uint8Array = encoder.encodeInto('\r\n')
      chunks.push(headerBytes, part.bytes, tail)
      total += headerBytes.length + part.bytes.length + tail.length
    }
    const closing: Uint8Array = encoder.encodeInto(`--${boundary}--\r\n`)
    total += closing.length
    if (total <= 0 || total > MAX_MULTIPART_BODY_BYTES) {
      throw new Error('Manga rendering service multipart body is too large')
    }
    const output: Uint8Array = new Uint8Array(total)
    let offset: number = 0
    for (let index: number = 0; index < chunks.length; index++) {
      output.set(chunks[index], offset)
      offset += chunks[index].length
    }
    output.set(closing, offset)
    return output
  }

  private static readSourceImage(source: ComicVisualPageSource): SourceImage {
    ComicVisualTranslationContract.validateSource(source)
    const stat: fileIo.Stat = fileIo.statSync(source.imageFilePath)
    const length: number = Math.floor(stat.size)
    if (!stat.isFile() || length <= 0 || length > MAX_SOURCE_IMAGE_BYTES) {
      throw new Error('Manga rendering service source image size is invalid')
    }
    const bytes: Uint8Array = MangaRenderingServiceBackend.readExact(source.imageFilePath, length)
    if (MangaRenderingServiceBackend.sha256(bytes) !== source.imageHash) {
      throw new Error('Manga rendering service source image hash changed')
    }
    const result: SourceImage = new SourceImage()
    result.bytes = bytes
    if (MangaRenderingServiceBackend.isPng(bytes)) {
      result.mimeType = 'image/png'; result.fileName = 'source.png'
    } else if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
      result.mimeType = 'image/jpeg'; result.fileName = 'source.jpg'
    } else if (bytes.length >= 12 && MangaRenderingServiceBackend.asciiAt(bytes, 0, 'RIFF') && MangaRenderingServiceBackend.asciiAt(bytes, 8, 'WEBP')) {
      result.mimeType = 'image/webp'; result.fileName = 'source.webp'
    } else {
      throw new Error('Manga rendering service source image format is unsupported')
    }
    return result
  }

  private static async validatePng(bytes: Uint8Array, width: number, height: number): Promise<void> {
    if (!MangaRenderingServiceBackend.isPng(bytes) || !MangaRenderingServiceBackend.asciiAt(bytes, 12, 'IHDR') ||
      MangaRenderingServiceBackend.u32be(bytes, 16) !== width || MangaRenderingServiceBackend.u32be(bytes, 20) !== height) {
      throw new Error('Manga rendering service render response is not the expected PNG')
    }
    let source: image.ImageSource | undefined = undefined
    let pixelMap: image.PixelMap | undefined = undefined
    try {
      source = image.createImageSource(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength))
      pixelMap = await source.createPixelMap({ editable: false, desiredSize: { width: 1, height: 1 }, desiredPixelFormat: image.PixelMapFormat.RGBA_8888 })
      const info: image.ImageInfo = await pixelMap.getImageInfo()
      if (info.size.width <= 0 || info.size.height <= 0) throw new Error('decoded PNG is invalid')
    } finally {
      if (pixelMap !== undefined) await pixelMap.release()
      if (source !== undefined) await source.release()
    }
  }

  private static persist(context: common.UIAbilityContext, identityKey: string, artifactHash: string, bytes: Uint8Array): string {
    const dir: string = `${context.cacheDir}/${RENDER_CACHE_DIR}`
    MangaRenderingServiceBackend.ensureDir(dir)
    const identityHash: string = MangaRenderingServiceBackend.sha256(new util.TextEncoder().encodeInto(identityKey))
    const path: string = `${dir}/${identityHash}-${artifactHash}.png`
    if (fileIo.accessSync(path)) return path
    const partial: string = `${path}.part-${util.generateRandomUUID(true)}`
    try { MangaRenderingServiceBackend.writeExact(partial, bytes); fileIo.renameSync(partial, path); return path } catch (error) { MangaRenderingServiceBackend.removeFile(partial); throw error as Error }
  }

  private static requireSuccess(response: MangaRenderingServiceBinaryResponse, maxBytes: number, operation: string): void {
    if (response.statusCode < 200 || response.statusCode > 299 || response.body.length <= 0 || response.body.length > maxBytes) {
      throw new Error(`Manga rendering service ${operation} failed`)
    }
  }

  private static readExact(path: string, length: number): Uint8Array { const result = new Uint8Array(length); let file: fileIo.File | null = null; let offset = 0; try { file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY); while (offset < length) { const buffer = new ArrayBuffer(length - offset); const read = fileIo.readSync(file.fd, buffer, { length: buffer.byteLength }); if (read <= 0) throw new Error('Manga rendering service source image is truncated'); result.set(new Uint8Array(buffer, 0, read), offset); offset += read } return result } finally { if (file !== null) fileIo.closeSync(file) } }
  private static writeExact(path: string, bytes: Uint8Array): void { let file: fileIo.File | null = null; let offset = 0; try { file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC); while (offset < bytes.length) { const chunk = bytes.buffer.slice(bytes.byteOffset + offset, bytes.byteOffset + bytes.byteLength); const written = fileIo.writeSync(file.fd, chunk, { length: chunk.byteLength }); if (written <= 0) throw new Error('Manga rendering service rendered image write failed'); offset += written } } finally { if (file !== null) fileIo.closeSync(file) } }
  private static ensureDir(path: string): void { try { fileIo.mkdirSync(path, true) } catch (error) { if (!fileIo.accessSync(path)) throw error as Error } }
  private static removeFile(path: string): void { try { if (fileIo.accessSync(path)) fileIo.unlinkSync(path) } catch (_error) {} }
  private static sha256(bytes: Uint8Array): string { const md = cryptoFramework.createMd('SHA256'); md.updateSync({ data: bytes }); const digest = md.digestSync().data; let result = ''; for (let index = 0; index < digest.length; index++) result += digest[index].toString(16).padStart(2, '0'); return result }
  private static isPng(bytes: Uint8Array): boolean { const signature: number[] = [137, 80, 78, 71, 13, 10, 26, 10]; if (bytes.length < 24) return false; for (let index = 0; index < signature.length; index++) if (bytes[index] !== signature[index]) return false; return true }
  private static asciiAt(bytes: Uint8Array, offset: number, expected: string): boolean { if (offset < 0 || offset + expected.length > bytes.length) return false; for (let index = 0; index < expected.length; index++) if (bytes[offset + index] !== expected.charCodeAt(index)) return false; return true }
  private static u32be(bytes: Uint8Array, offset: number): number { if (offset < 0 || offset + 4 > bytes.length) throw new Error('Manga rendering service PNG header is truncated'); return ((bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3]) >>> 0 }
}
