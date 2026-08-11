import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import {
  ComicAnalysisState,
  ComicPageDocument,
  ComicPoint,
  ComicSourceOrigin,
  ComicTextBlock,
  ComicTextKind,
  ComicTranslationState,
} from '../model/ComicTranslation'
import {
  ComicBackendTemplate,
  ComicRegionAnalysisResult,
  ComicTranslationBatch,
} from '../model/ComicVisualTranslation'
import { ComicRegionAnalysisRequest } from './ComicVisualTranslationBackend'
import { ComicVisualTranslationContract } from './ComicVisualTranslationContract'
import {
  MANGA_RENDERING_SERVICE_BACKEND_ID,
  MANGA_RENDERING_SERVICE_PROTOCOL_REVISION,
  MangaRenderingServiceProfileCatalog,
} from './MangaRenderingServiceProfileCatalog'

const TEMPLATE_MIME: string = 'application/vnd.manga-translator-ui.translation+json'
const MAX_EXPORT_JSON_BYTES: number = 4 * 1024 * 1024
const MAX_EXPORT_TEXT_BYTES: number = 1024 * 1024
const MAX_REGIONS: number = 512
const MAX_LINES_PER_REGION: number = 64
const MAX_SOURCE_TEXT_CHARS: number = 8192
const COORDINATE_TOLERANCE: number = 1
const LOW_SIGNAL_ASCII_CONFIDENCE_CEILING: number = 0.5
const LOW_SIGNAL_ASCII_MAX_AREA_RATIO: number = 0.0005

class RawMangaRenderingRegion {
  lines: number[][][] = []
  text: string = ''
  translation: string = ''
  angle: number = 0
  font_size: number = 0
  fg_colors: number[] = []
  bg_colors: number[] = []
  direction: string = ''
  alignment: string = ''
  target_lang: string = ''
  source_lang: string = ''
  line_spacing: number = 0
  default_stroke_width: number = 0
  adjust_bg_color: boolean = false
  prob: number = 0
}

class RawMangaRenderingPage {
  regions: RawMangaRenderingRegion[] = []
  original_width: number = 0
  original_height: number = 0
  mask_raw: string | null = null
  mask_is_refined: boolean = false
}

class RawMangaRenderingEnvelope {
  temp_image: RawMangaRenderingPage | null = null
}

/** Pinned manga-translator-ui v1.9.9 export/import template adapter. */
export class MangaRenderingServiceProtocol {
  static parseExport(
    request: ComicRegionAnalysisRequest,
    translationJson: Uint8Array,
    originalText: Uint8Array,
    profileId: string,
  ): ComicRegionAnalysisResult {
    ComicVisualTranslationContract.validateRegionAnalysisRequest(request)
    MangaRenderingServiceProtocol.validateProfileId(profileId)
    MangaRenderingServiceProtocol.validateExportSizes(translationJson, originalText)
    const envelope: RawMangaRenderingEnvelope = JSON.parse(
      MangaRenderingServiceProtocol.decode(translationJson),
    ) as RawMangaRenderingEnvelope
    const page: RawMangaRenderingPage = MangaRenderingServiceProtocol.requirePage(envelope, request)
    MangaRenderingServiceProtocol.validateOriginalText(originalText, page.regions.length)
    const filtered: boolean = MangaRenderingServiceProtocol.filterLowSignalRegions(
      page,
      request.source.imageWidth,
      request.source.imageHeight,
    )

    const document: ComicPageDocument = new ComicPageDocument()
    document.projectId = request.source.projectId
    document.pageIndex = request.source.pageIndex
    document.imageHash = request.source.imageHash
    document.imageWidth = request.source.imageWidth
    document.imageHeight = request.source.imageHeight
    document.imagePreparationProfile.profileId = profileId + ':source-original'
    document.imagePreparationProfile.preparedWidth = request.source.imageWidth
    document.imagePreparationProfile.preparedHeight = request.source.imageHeight
    document.imagePreparationProfile.tileCount = 1
    document.analysisRevision = request.requestedDocumentRevision
    document.analysisState = ComicAnalysisState.READY
    document.translationState = ComicTranslationState.MISSING
    document.hasText = page.regions.length > 0
    for (let index: number = 0; index < page.regions.length; index++) {
      document.blocks.push(MangaRenderingServiceProtocol.normalizeRegion(
        page.regions[index],
        request.source.pageIndex,
        index,
        request.source.imageWidth,
        request.source.imageHeight,
        request.requestedDocumentRevision,
      ))
    }

    const templatePayload: Uint8Array = filtered
      ? new util.TextEncoder().encodeInto(JSON.stringify(envelope))
      : new Uint8Array(translationJson)
    if (templatePayload.length <= 0 || templatePayload.length > MAX_EXPORT_JSON_BYTES) {
      throw new Error('Manga rendering service filtered template size is invalid')
    }
    const template: ComicBackendTemplate = new ComicBackendTemplate()
    template.backendId = MANGA_RENDERING_SERVICE_BACKEND_ID
    template.profileId = profileId
    template.protocolRevision = MANGA_RENDERING_SERVICE_PROTOCOL_REVISION
    template.contentHash = MangaRenderingServiceProtocol.sha256(templatePayload)
    template.mimeType = TEMPLATE_MIME
    template.payload = templatePayload

    const result: ComicRegionAnalysisResult = new ComicRegionAnalysisResult()
    result.backendId = MANGA_RENDERING_SERVICE_BACKEND_ID
    result.profileId = profileId
    result.regionRevision = request.requestedRegionRevision
    result.document = document
    result.adapterTemplate = template
    ComicVisualTranslationContract.validateRegionAnalysisResult(
      request,
      result.backendId,
      result.profileId,
      result.regionRevision,
      result.document,
      result.adapterTemplate,
    )
    return result
  }

  static buildImportJson(
    document: ComicPageDocument,
    translations: ComicTranslationBatch,
    template: ComicBackendTemplate,
  ): Uint8Array {
    ComicVisualTranslationContract.validateTranslationBatch(document, translations)
    MangaRenderingServiceProtocol.validateTemplate(template)
    const envelope: RawMangaRenderingEnvelope = JSON.parse(
      MangaRenderingServiceProtocol.decode(template.payload),
    ) as RawMangaRenderingEnvelope
    const page: RawMangaRenderingPage = MangaRenderingServiceProtocol.requireTemplatePage(envelope, document)
    const translated: Map<string, string> = new Map<string, string>()
    for (let index: number = 0; index < translations.blocks.length; index++) {
      translated.set(translations.blocks[index].blockId, translations.blocks[index].translatedText)
    }
    for (let index: number = 0; index < page.regions.length; index++) {
      const expectedBlockId: string = MangaRenderingServiceProtocol.blockId(document.pageIndex, index)
      const block: ComicTextBlock = document.blocks[index]
      const translatedText: string | undefined = translated.get(expectedBlockId)
      if (block.blockId !== expectedBlockId || block.readingOrder !== index ||
        block.sourceText !== page.regions[index].text || translatedText === undefined) {
        throw new Error('Manga rendering service template no longer matches the page document')
      }
      page.regions[index].translation = translatedText
    }
    const output: Uint8Array = new util.TextEncoder().encodeInto(JSON.stringify(envelope))
    if (output.length <= 0 || output.length > MAX_EXPORT_JSON_BYTES) {
      throw new Error('Manga rendering service import JSON size is invalid')
    }
    return output
  }

  private static validateExportSizes(translationJson: Uint8Array, originalText: Uint8Array): void {
    if (translationJson.length <= 0 || translationJson.length > MAX_EXPORT_JSON_BYTES ||
      originalText.length > MAX_EXPORT_TEXT_BYTES) {
      throw new Error('Manga rendering service export size is invalid')
    }
  }

  private static validateOriginalText(originalText: Uint8Array, regionCount: number): void {
    const value: string = MangaRenderingServiceProtocol.decode(originalText)
    if (regionCount > 0 && value.trim().length === 0) {
      throw new Error('Manga rendering service export is missing original text')
    }
  }

  private static requirePage(
    envelope: RawMangaRenderingEnvelope,
    request: ComicRegionAnalysisRequest,
  ): RawMangaRenderingPage {
    if (envelope === null || envelope.temp_image === null || typeof envelope.temp_image !== 'object') {
      throw new Error('Manga rendering service export envelope is invalid')
    }
    const page: RawMangaRenderingPage = envelope.temp_image
    if (page.original_width !== request.source.imageWidth ||
      page.original_height !== request.source.imageHeight ||
      !Array.isArray(page.regions) || page.regions.length > MAX_REGIONS) {
      throw new Error('Manga rendering service export page identity is invalid')
    }
    return page
  }

  private static requireTemplatePage(
    envelope: RawMangaRenderingEnvelope,
    document: ComicPageDocument,
  ): RawMangaRenderingPage {
    if (envelope === null || envelope.temp_image === null || typeof envelope.temp_image !== 'object') {
      throw new Error('Manga rendering service template envelope is invalid')
    }
    const page: RawMangaRenderingPage = envelope.temp_image
    if (page.original_width !== document.imageWidth || page.original_height !== document.imageHeight ||
      !Array.isArray(page.regions) || page.regions.length !== document.blocks.length ||
      page.regions.length > MAX_REGIONS) {
      throw new Error('Manga rendering service template page identity is invalid')
    }
    for (let index: number = 0; index < page.regions.length; index++) {
      MangaRenderingServiceProtocol.validatePinnedRegion(page.regions[index])
    }
    return page
  }

  private static normalizeRegion(
    region: RawMangaRenderingRegion,
    pageIndex: number,
    regionIndex: number,
    width: number,
    height: number,
    documentRevision: number,
  ): ComicTextBlock {
    MangaRenderingServiceProtocol.validatePinnedRegion(region)
    const block: ComicTextBlock = new ComicTextBlock()
    block.blockId = MangaRenderingServiceProtocol.blockId(pageIndex, regionIndex)
    block.readingOrder = regionIndex
    block.kind = ComicTextKind.OTHER
    block.sourceText = region.text
    block.normalizedSourceText = region.text.trim()
    block.styleHint = region.direction
    block.sourceOrigin = ComicSourceOrigin.OCR
    block.providerConfidence = region.prob >= 0 && region.prob <= 1 ? region.prob : null
    block.sourceRevision = documentRevision
    const polygon: ComicPoint[] = MangaRenderingServiceProtocol.regionPolygon(
      region,
      regionIndex,
      width,
      height,
    )
    for (let index: number = 0; index < polygon.length; index++) {
      block.polygon.push(polygon[index])
    }
    return block
  }

  private static filterLowSignalRegions(
    page: RawMangaRenderingPage,
    width: number,
    height: number,
  ): boolean {
    const retained: RawMangaRenderingRegion[] = []
    let filtered: boolean = false
    for (let index: number = 0; index < page.regions.length; index++) {
      const region: RawMangaRenderingRegion = page.regions[index]
      MangaRenderingServiceProtocol.validatePinnedRegion(region)
      if (MangaRenderingServiceProtocol.isLowSignalAsciiRegion(region, width, height)) {
        filtered = true
      } else {
        retained.push(region)
      }
    }
    if (filtered) {
      page.regions = retained
      page.mask_raw = null
      page.mask_is_refined = false
    }
    return filtered
  }

  private static isLowSignalAsciiRegion(
    region: RawMangaRenderingRegion,
    width: number,
    height: number,
  ): boolean {
    if (!/^[A-Za-z]$/.test(region.text.trim()) || region.prob >= LOW_SIGNAL_ASCII_CONFIDENCE_CEILING) {
      return false
    }
    let minX: number = Number.POSITIVE_INFINITY
    let minY: number = Number.POSITIVE_INFINITY
    let maxX: number = Number.NEGATIVE_INFINITY
    let maxY: number = Number.NEGATIVE_INFINITY
    for (let lineIndex: number = 0; lineIndex < region.lines.length; lineIndex++) {
      const line: number[][] = region.lines[lineIndex]
      for (let pointIndex: number = 0; pointIndex < line.length; pointIndex++) {
        minX = Math.min(minX, line[pointIndex][0])
        minY = Math.min(minY, line[pointIndex][1])
        maxX = Math.max(maxX, line[pointIndex][0])
        maxY = Math.max(maxY, line[pointIndex][1])
      }
    }
    return ((maxX - minX) * (maxY - minY)) / (width * height) <= LOW_SIGNAL_ASCII_MAX_AREA_RATIO
  }

  private static validatePinnedRegion(region: RawMangaRenderingRegion): void {
    if (region === null || typeof region !== 'object' || !Array.isArray(region.lines) ||
      region.lines.length <= 0 || region.lines.length > MAX_LINES_PER_REGION ||
      typeof region.text !== 'string' || region.text.trim().length === 0 ||
      region.text.length > MAX_SOURCE_TEXT_CHARS || typeof region.translation !== 'string' ||
      !Number.isFinite(region.angle) || !Number.isFinite(region.font_size) ||
      !Array.isArray(region.fg_colors) || !Array.isArray(region.bg_colors) ||
      typeof region.direction !== 'string' || typeof region.alignment !== 'string' ||
      typeof region.target_lang !== 'string' || typeof region.source_lang !== 'string' ||
      !Number.isFinite(region.line_spacing) || !Number.isFinite(region.default_stroke_width) ||
      typeof region.adjust_bg_color !== 'boolean' || !Number.isFinite(region.prob)) {
      throw new Error('Manga rendering service region does not match the pinned v1.9.9 profile')
    }
    MangaRenderingServiceProtocol.validateColor(region.fg_colors)
    MangaRenderingServiceProtocol.validateColor(region.bg_colors)
    for (let lineIndex: number = 0; lineIndex < region.lines.length; lineIndex++) {
      const line: number[][] = region.lines[lineIndex]
      if (!Array.isArray(line) || line.length !== 4) {
        throw new Error('Manga rendering service region line is invalid')
      }
      for (let pointIndex: number = 0; pointIndex < line.length; pointIndex++) {
        if (!Array.isArray(line[pointIndex]) || line[pointIndex].length !== 2 ||
          !Number.isFinite(line[pointIndex][0]) || !Number.isFinite(line[pointIndex][1])) {
          throw new Error('Manga rendering service region point is invalid')
        }
      }
    }
  }

  private static validateColor(value: number[]): void {
    if (value.length !== 3) {
      throw new Error('Manga rendering service region color is invalid')
    }
    for (let index: number = 0; index < value.length; index++) {
      if (!Number.isFinite(value[index]) || value[index] < 0 || value[index] > 255) {
        throw new Error('Manga rendering service region color is invalid')
      }
    }
  }

  private static regionPolygon(
    region: RawMangaRenderingRegion,
    regionIndex: number,
    width: number,
    height: number,
  ): ComicPoint[] {
    let sumX: number = 0
    let sumY: number = 0
    let pointCount: number = 0
    for (let lineIndex: number = 0; lineIndex < region.lines.length; lineIndex++) {
      const line: number[][] = region.lines[lineIndex]
      for (let pointIndex: number = 0; pointIndex < line.length; pointIndex++) {
        sumX += line[pointIndex][0]
        sumY += line[pointIndex][1]
        pointCount++
      }
    }
    if (pointCount <= 0) {
      throw new Error('Manga rendering service region bounds are invalid')
    }
    const centerX: number = sumX / pointCount
    const centerY: number = sumY / pointCount
    const radians: number = region.angle * Math.PI / 180
    const cosine: number = Math.cos(radians)
    const sine: number = Math.sin(radians)
    let minX: number = Number.POSITIVE_INFINITY
    let minY: number = Number.POSITIVE_INFINITY
    let maxX: number = Number.NEGATIVE_INFINITY
    let maxY: number = Number.NEGATIVE_INFINITY
    for (let lineIndex: number = 0; lineIndex < region.lines.length; lineIndex++) {
      const line: number[][] = region.lines[lineIndex]
      for (let pointIndex: number = 0; pointIndex < line.length; pointIndex++) {
        const dx: number = line[pointIndex][0] - centerX
        const dy: number = line[pointIndex][1] - centerY
        const x: number = centerX + dx * cosine - dy * sine
        const y: number = centerY + dx * sine + dy * cosine
        minX = Math.min(minX, x)
        minY = Math.min(minY, y)
        maxX = Math.max(maxX, x)
        maxY = Math.max(maxY, y)
      }
    }
    if (!(maxX > minX) || !(maxY > minY)) {
      throw new Error('Manga rendering service restored region bounds are invalid')
    }
    const left: number = MangaRenderingServiceProtocol.boundedCoordinate(minX, width, regionIndex, 'x')
    const top: number = MangaRenderingServiceProtocol.boundedCoordinate(minY, height, regionIndex, 'y')
    const right: number = MangaRenderingServiceProtocol.boundedCoordinate(maxX, width, regionIndex, 'x')
    const bottom: number = MangaRenderingServiceProtocol.boundedCoordinate(maxY, height, regionIndex, 'y')
    return [
      new ComicPoint(left, top),
      new ComicPoint(right, top),
      new ComicPoint(right, bottom),
      new ComicPoint(left, bottom),
    ]
  }

  private static boundedCoordinate(value: number, edge: number, regionIndex: number, axis: string): number {
    if (!Number.isFinite(value) || value < -COORDINATE_TOLERANCE ||
      value > edge + COORDINATE_TOLERANCE) {
      throw new Error('Manga rendering service region is outside the source image ' +
        `(region=${regionIndex},axis=${axis})`)
    }
    return Math.min(edge, Math.max(0, value))
  }

  private static validateTemplate(template: ComicBackendTemplate): void {
    if (template.backendId !== MANGA_RENDERING_SERVICE_BACKEND_ID ||
      !MangaRenderingServiceProfileCatalog.supportsProfileId(template.profileId) ||
      template.protocolRevision !== MANGA_RENDERING_SERVICE_PROTOCOL_REVISION ||
      template.mimeType !== TEMPLATE_MIME || template.payload.length <= 0 ||
      template.payload.length > MAX_EXPORT_JSON_BYTES ||
      template.contentHash !== MangaRenderingServiceProtocol.sha256(template.payload)) {
      throw new Error('Manga rendering service adapter template is invalid')
    }
  }

  private static validateProfileId(profileId: string): void {
    if (!MangaRenderingServiceProfileCatalog.supportsProfileId(profileId)) {
      throw new Error('Manga rendering service profile identity is invalid')
    }
  }

  private static blockId(pageIndex: number, regionIndex: number): string {
    return 'p' + pageIndex + '-r' + regionIndex
  }

  private static decode(value: Uint8Array): string {
    return util.TextDecoder.create('utf-8', { ignoreBOM: true }).decodeToString(value)
  }

  private static sha256(value: Uint8Array): string {
    const md = cryptoFramework.createMd('SHA256')
    md.updateSync({ data: value })
    const digest: Uint8Array = md.digestSync().data
    const parts: string[] = []
    for (let index: number = 0; index < digest.length; index++) {
      parts.push(digest[index].toString(16).padStart(2, '0'))
    }
    return parts.join('')
  }
}
