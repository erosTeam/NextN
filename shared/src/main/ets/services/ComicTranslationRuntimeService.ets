import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileIo } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { ComicRenderProfile } from '../model/ComicVisualTranslation'
import { CacheStat } from './CacheStat'
import {
  PersistentComicRenderedPageRepository,
} from './ComicRenderedPageRepository'
import { ComicLocalVisualBackend } from './ComicLocalVisualBackend'
import { HarmonyComicLocalOcrEngine } from './ComicHarmonyOcrService'
import { ComicNcnnLocalRegionDetector } from './ComicNativeRegionDetector'
import { ComicNcnnLocalSourceInpainter } from './ComicNativeSourceInpainter'
import { ComicNcnnLocalTextMasker } from './ComicNativeTextMasker'
import { ComicNcnnLocalTextRecognizer } from './ComicNativeTextRecognizer'
import {
  ComicSourceInpaintingModelPaths,
  ComicTextMaskModelPaths,
  ComicTextRecognitionModelPaths,
  ComicTranslationModelPaths,
  ComicTranslationModelService,
} from './ComicTranslationModelService'
import { ComicTextTranslatorFactory } from './ComicResponsesTextTranslator'
import { MangaRenderingServiceBackend } from './MangaRenderingServiceBackend'
import { MangaRenderingServiceCredential, MangaRenderingServiceSecretStore } from './MangaRenderingServiceSecretStore'
import {
  MangaRenderingServiceSettings,
  MangaRenderingServiceSettingsSnapshot,
} from '../settings/MangaRenderingServiceSettings'
import { MangaRenderingServiceState, connectMangaRenderingService } from '../state/MangaRenderingServiceState'
import {
  ComicTranslationRepository,
} from './ComicTranslationRepository'
import { RdbComicTranslationRepository } from './ComicTranslationPersistentRepository'
import {
  ComicRegionRenderBackend,
  ComicTextTranslator,
  ComicVisualPageSource,
} from './ComicVisualTranslationBackend'
import {
  ComicVisualTranslationOrchestrator,
  ComicVisualTranslationRequest,
  ComicVisualTranslationRunResult,
} from './ComicVisualTranslationOrchestrator'

const COMIC_READER_MAX_IMAGE_BYTES: number = 20 * 1024 * 1024
const COMIC_READER_HASH_CHUNK_BYTES: number = 256 * 1024
const COMIC_READER_RENDER_PROFILE_ID: string = 'reader-local-bubble-layout-v45'
const COMIC_READER_SOURCE_TREATMENT_PROFILE_ID: string = 'local-ctd-aot-inpaint-v30'
const COMIC_READER_LAYOUT_PROFILE_ID: string = 'local-bubble-typography-v39'
const COMIC_READER_SELF_HOSTED_RENDER_PROFILE_ID: string =
  'reader-manga-rendering-service-render-v1'
const COMIC_READER_SELF_HOSTED_SOURCE_TREATMENT_PROFILE_ID: string =
  'manga-rendering-service-v1.9.9-source-treatment-v1'
const COMIC_READER_SELF_HOSTED_LAYOUT_PROFILE_ID: string =
  'manga-rendering-service-v1.9.9-layout-v1'
const MAX_RUNTIME_ORCHESTRATORS: number = 4
const MAX_COMIC_READER_IDENTIFIER_CHARS: number = 160
const MAX_COMIC_READER_IMAGE_PATH_CHARS: number = 4096
const MAX_COMIC_READER_IMAGE_EDGE: number = 100000

class ComicTranslationReaderFileMetadata {
  imageHash: string = ''
  imageWidth: number = 0
  imageHeight: number = 0
}

/**
 * Carries route-private runtime identity separately from durable render
 * identity. Credential material never leaves the process-local map key.
 */
class ComicTranslationRuntimeBackend {
  backend: ComicRegionRenderBackend
  regionRevision: number
  renderProfile: ComicRenderProfile
  runtimeFingerprint: string

  constructor(
    backend: ComicRegionRenderBackend,
    regionRevision: number,
    renderProfile: ComicRenderProfile,
    runtimeFingerprint: string = '',
  ) {
    this.backend = backend
    this.regionRevision = regionRevision
    this.renderProfile = renderProfile
    this.runtimeFingerprint = runtimeFingerprint
  }
}

/** Immutable per-page reader input. The image path must resolve to an app-private cached page. */
export class ComicTranslationReaderPageInput {
  projectId: string = ''
  pageIndex: number = -1
  imageFilePath: string = ''
  imageWidth: number = 0
  imageHeight: number = 0
  sourceLanguage: string = 'auto'
  targetLanguage: string = 'zh-CN'
}

/**
 * The sole non-UI entry for visual translation. It creates no network request until the source
 * binding is valid and `runReaderPage` is explicitly called by a future Reader action.
 */
export class ComicTranslationRuntimeService {
  private static documentRepository: ComicTranslationRepository | null = null
  private static renderedRepository: PersistentComicRenderedPageRepository | null = null
  private static orchestrators: Map<string, ComicVisualTranslationOrchestrator> = new Map()

  static async runReaderPage(
    context: common.UIAbilityContext,
    input: ComicTranslationReaderPageInput,
    forceRefresh: boolean = false,
  ): Promise<ComicVisualTranslationRunResult> {
    ComicTranslationRuntimeService.validateInput(input)
    const metadata: ComicTranslationReaderFileMetadata =
      await ComicTranslationRuntimeService.fileMetadata(input.imageFilePath)
    const runtimeBackend: ComicTranslationRuntimeBackend =
      await ComicTranslationRuntimeService.backendFor(context, input)
    const backend: ComicRegionRenderBackend = runtimeBackend.backend
    const translator: ComicTextTranslator = await ComicTextTranslatorFactory.create(context)
    const request: ComicVisualTranslationRequest = new ComicVisualTranslationRequest()
    request.source = ComicTranslationRuntimeService.visualSource(input, metadata)
    request.context.sourceLanguage = input.sourceLanguage
    request.context.targetLanguage = input.targetLanguage
    request.context.styleGuide =
      'Use concise natural phrasing in the requested target language. Keep names, forms of address, tone, and references consistent across pages.'
    request.context.glossaryRevision = 0
    request.context.styleGuideRevision = 2
    request.context.contextRevision = 1
    request.renderProfile = runtimeBackend.renderProfile.copy()
    request.requestedRegionRevision = runtimeBackend.regionRevision
    request.requestedDocumentRevision = 1
    request.requestedTranslationRevision = 1
    return ComicTranslationRuntimeService.orchestrator(
      context,
      backend,
      translator,
      runtimeBackend.regionRevision,
      runtimeBackend.runtimeFingerprint,
    ).run(
      request,
      forceRefresh,
    )
  }

  static async clearGeneratedCache(context: common.UIAbilityContext): Promise<void> {
    ComicTranslationRuntimeService.orchestrators.forEach(
      (orchestrator: ComicVisualTranslationOrchestrator): void => {
        orchestrator.invalidateCacheWrites()
      },
    )
    ComicTranslationRuntimeService.orchestrators.clear()
    await Promise.all([
      ComicTranslationRuntimeService.documentRepositoryFor(context).clear(),
      ComicTranslationRuntimeService.renderedRepositoryFor(context).clear(),
    ])
  }

  static async statGeneratedCache(context: common.UIAbilityContext): Promise<CacheStat> {
    const stats: CacheStat[] = await Promise.all([
      ComicTranslationRuntimeService.documentRepositoryFor(context).stat(),
      ComicTranslationRuntimeService.renderedRepositoryFor(context).stat(),
    ])
    const result: CacheStat = new CacheStat()
    for (let index: number = 0; index < stats.length; index++) {
      result.count += stats[index].count
      result.bytes += stats[index].bytes
    }
    return result
  }

  private static orchestrator(
    context: common.UIAbilityContext,
    backend: ComicRegionRenderBackend,
    translator: ComicTextTranslator,
    regionRevision: number,
    runtimeFingerprint: string,
  ): ComicVisualTranslationOrchestrator {
    const runtimeKey: string = ComicTranslationRuntimeService.digest(JSON.stringify([
      backend.backendId(),
      backend.profileId(),
      `${backend.protocolRevision()}`,
      `${regionRevision}`,
      runtimeFingerprint,
      translator.sourceProfileId(),
      `${translator.sourceRevision()}`,
      translator.modelId(),
      translator.promptVersion(),
    ]))
    const existing: ComicVisualTranslationOrchestrator | undefined =
      ComicTranslationRuntimeService.orchestrators.get(runtimeKey)
    if (existing !== undefined) {
      return existing
    }
    if (ComicTranslationRuntimeService.orchestrators.size >= MAX_RUNTIME_ORCHESTRATORS) {
      ComicTranslationRuntimeService.orchestrators.clear()
    }
    const created: ComicVisualTranslationOrchestrator = new ComicVisualTranslationOrchestrator(
      backend,
      translator,
      ComicTranslationRuntimeService.documentRepositoryFor(context),
      ComicTranslationRuntimeService.renderedRepositoryFor(context),
    )
    ComicTranslationRuntimeService.orchestrators.set(runtimeKey, created)
    return created
  }

  private static localBackendFor(context: common.UIAbilityContext): ComicRegionRenderBackend {
    const detectorPaths: ComicTranslationModelPaths | null =
      ComicTranslationModelService.pathsIfReady(context)
    if (detectorPaths === null) {
      return new ComicLocalVisualBackend(context)
    }
    const recognizerPaths: ComicTextRecognitionModelPaths | null =
      ComicTranslationModelService.ocrPathsIfReady(context)
    const inpaintingPaths: ComicSourceInpaintingModelPaths | null =
      ComicTranslationModelService.inpaintingPathsIfReady(context)
    const textMaskPaths: ComicTextMaskModelPaths | null =
      ComicTranslationModelService.textMaskPathsIfReady(context)
    const sourceTreatmentReady: boolean = inpaintingPaths !== null && textMaskPaths !== null
    return new ComicLocalVisualBackend(
      context,
      new HarmonyComicLocalOcrEngine(),
      new ComicNcnnLocalRegionDetector(detectorPaths.paramPath, detectorPaths.modelPath),
      recognizerPaths === null ? null : new ComicNcnnLocalTextRecognizer(
        recognizerPaths.paramPath,
        recognizerPaths.modelPath,
        recognizerPaths.dictionaryPath,
      ),
      sourceTreatmentReady ? new ComicNcnnLocalSourceInpainter(
        (inpaintingPaths as ComicSourceInpaintingModelPaths).paramPath,
        (inpaintingPaths as ComicSourceInpaintingModelPaths).modelPath,
        4,
      ) : null,
      sourceTreatmentReady ? new ComicNcnnLocalTextMasker(
        (textMaskPaths as ComicTextMaskModelPaths).paramPath,
        (textMaskPaths as ComicTextMaskModelPaths).modelPath,
        0.3,
        4,
      ) : null,
      sourceTreatmentReady ? new ComicNcnnLocalTextMasker(
        (textMaskPaths as ComicTextMaskModelPaths).paramPath,
        (textMaskPaths as ComicTextMaskModelPaths).modelPath,
        0.15,
        4,
        0.3,
      ) : null,
    )
  }

  private static async backendFor(
    context: common.UIAbilityContext,
    input: ComicTranslationReaderPageInput,
  ): Promise<ComicTranslationRuntimeBackend> {
    const selection: MangaRenderingServiceState = connectMangaRenderingService()
    const selectionEpoch: number = selection.selectionEpoch
    if (!selection.initialized || !selection.enabled) {
      return ComicTranslationRuntimeService.localRuntimeBackendFor(context)
    }
    const settings: MangaRenderingServiceSettingsSnapshot =
      await MangaRenderingServiceSettings.load(context)
    if (!settings.enabled) {
      throw new Error('Self-hosted manga translation service selection changed')
    }
    const credential: MangaRenderingServiceCredential =
      await MangaRenderingServiceSecretStore.read(context)
    const currentSelection: MangaRenderingServiceState = connectMangaRenderingService()
    if (!currentSelection.initialized || !currentSelection.enabled ||
      currentSelection.selectionEpoch !== selectionEpoch || !settings.configured() || !credential.configured() ||
      credential.revision !== selection.credentialRevision) {
      throw new Error('Self-hosted manga translation service selection changed')
    }
    const backend: MangaRenderingServiceBackend = new MangaRenderingServiceBackend(
      context,
      settings.baseUrl,
      credential,
      input.sourceLanguage,
      settings.detectionProfile,
      settings.inpaintingProfile,
      credential.revision,
    )
    return new ComicTranslationRuntimeBackend(
      backend,
      credential.revision,
      ComicTranslationRuntimeService.selfHostedRenderProfile(),
      ComicTranslationRuntimeService.credentialRuntimeFingerprint(credential),
    )
  }

  private static localRuntimeBackendFor(
    context: common.UIAbilityContext,
  ): ComicTranslationRuntimeBackend {
    const backend: ComicRegionRenderBackend = ComicTranslationRuntimeService.localBackendFor(context)
    return new ComicTranslationRuntimeBackend(
      backend,
      backend.protocolRevision(),
      ComicTranslationRuntimeService.renderProfile(),
    )
  }

  private static documentRepositoryFor(context: common.UIAbilityContext): ComicTranslationRepository {
    const existing: ComicTranslationRepository | null =
      ComicTranslationRuntimeService.documentRepository
    if (existing !== null) {
      return existing
    }
    const created: ComicTranslationRepository = new RdbComicTranslationRepository(context)
    ComicTranslationRuntimeService.documentRepository = created
    return created
  }

  private static renderedRepositoryFor(
    context: common.UIAbilityContext,
  ): PersistentComicRenderedPageRepository {
    const existing: PersistentComicRenderedPageRepository | null =
      ComicTranslationRuntimeService.renderedRepository
    if (existing !== null) {
      return existing
    }
    const created: PersistentComicRenderedPageRepository =
      new PersistentComicRenderedPageRepository(context)
    ComicTranslationRuntimeService.renderedRepository = created
    return created
  }

  private static renderProfile(): ComicRenderProfile {
    const profile: ComicRenderProfile = new ComicRenderProfile()
    profile.profileId = COMIC_READER_RENDER_PROFILE_ID
    profile.sourceTreatmentProfileId = COMIC_READER_SOURCE_TREATMENT_PROFILE_ID
    profile.layoutProfileId = COMIC_READER_LAYOUT_PROFILE_ID
    profile.targetMimeType = 'image/png'
    profile.revision = 37
    return profile
  }

  private static selfHostedRenderProfile(): ComicRenderProfile {
    const profile: ComicRenderProfile = new ComicRenderProfile()
    profile.profileId = COMIC_READER_SELF_HOSTED_RENDER_PROFILE_ID
    profile.sourceTreatmentProfileId = COMIC_READER_SELF_HOSTED_SOURCE_TREATMENT_PROFILE_ID
    profile.layoutProfileId = COMIC_READER_SELF_HOSTED_LAYOUT_PROFILE_ID
    profile.targetMimeType = 'image/png'
    profile.revision = 1
    return profile
  }

  private static credentialRuntimeFingerprint(
    credential: MangaRenderingServiceCredential,
  ): string {
    return ComicTranslationRuntimeService.digest(JSON.stringify([
      credential.username,
      credential.password,
    ]))
  }

  private static visualSource(
    input: ComicTranslationReaderPageInput,
    metadata: ComicTranslationReaderFileMetadata,
  ): ComicVisualPageSource {
    const source: ComicVisualPageSource = new ComicVisualPageSource()
    source.projectId = input.projectId
    source.pageIndex = input.pageIndex
    source.imageFilePath = input.imageFilePath
    source.imageHash = metadata.imageHash
    source.imageWidth = metadata.imageWidth
    source.imageHeight = metadata.imageHeight
    return source
  }

  private static validateInput(input: ComicTranslationReaderPageInput): void {
    if (!ComicTranslationRuntimeService.boundedExactIdentifier(
      input.projectId,
      MAX_COMIC_READER_IDENTIFIER_CHARS,
    ) || !ComicTranslationRuntimeService.nonNegativeSafeInteger(input.pageIndex) ||
      !ComicTranslationRuntimeService.boundedRequired(
        input.imageFilePath,
        MAX_COMIC_READER_IMAGE_PATH_CHARS,
      ) || !ComicTranslationRuntimeService.positiveImageEdge(input.imageWidth) ||
      !ComicTranslationRuntimeService.positiveImageEdge(input.imageHeight) ||
      !ComicTranslationRuntimeService.boundedExactIdentifier(
        input.sourceLanguage,
        MAX_COMIC_READER_IDENTIFIER_CHARS,
      ) || !ComicTranslationRuntimeService.boundedExactIdentifier(
        input.targetLanguage,
        MAX_COMIC_READER_IDENTIFIER_CHARS,
      )) {
      throw new Error('Comic reader image source is invalid')
    }
  }

  private static async fileMetadata(path: string): Promise<ComicTranslationReaderFileMetadata> {
    const stat: fileIo.Stat = fileIo.statSync(path)
    if (stat.size <= 0 || stat.size > COMIC_READER_MAX_IMAGE_BYTES) {
      throw new Error('Comic translation page size is invalid')
    }
    const metadata: ComicTranslationReaderFileMetadata = new ComicTranslationReaderFileMetadata()
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
      const digest = cryptoFramework.createMd('SHA256')
      while (true) {
        const buffer: ArrayBuffer = new ArrayBuffer(COMIC_READER_HASH_CHUNK_BYTES)
        const read: number = fileIo.readSync(file.fd, buffer, { length: COMIC_READER_HASH_CHUNK_BYTES })
        if (read <= 0) {
          break
        }
        digest.updateSync({ data: new Uint8Array(buffer, 0, read) })
      }
      metadata.imageHash = ComicTranslationRuntimeService.toHex(digest.digestSync().data)
    } finally {
      if (file !== null) {
        fileIo.closeSync(file)
      }
    }
    let source: image.ImageSource | undefined = undefined
    try {
      source = image.createImageSource(path)
      const info: image.ImageInfo = await source.getImageInfo()
      metadata.imageWidth = Math.floor(info.size.width)
      metadata.imageHeight = Math.floor(info.size.height)
      if (!ComicTranslationRuntimeService.positiveImageEdge(metadata.imageWidth) ||
        !ComicTranslationRuntimeService.positiveImageEdge(metadata.imageHeight)) {
        throw new Error('Comic translation page dimensions are invalid')
      }
      return metadata
    } finally {
      if (source !== undefined) {
        await source.release()
      }
    }
  }

  private static boundedRequired(value: string, maxChars: number): boolean {
    const normalized: string = value.trim()
    return normalized.length > 0 && value.length <= maxChars
  }

  private static boundedExactIdentifier(value: string, maxChars: number): boolean {
    return value.length > 0 && value.length <= maxChars && value === value.trim()
  }

  private static nonNegativeSafeInteger(value: number): boolean {
    return Number.isFinite(value) && value >= 0 && Math.floor(value) === value &&
      value <= Number.MAX_SAFE_INTEGER
  }

  private static positiveImageEdge(value: number): boolean {
    return value > 0 && value <= MAX_COMIC_READER_IMAGE_EDGE &&
      ComicTranslationRuntimeService.nonNegativeSafeInteger(value)
  }

  private static digest(value: string): string {
    const md = cryptoFramework.createMd('SHA256')
    md.updateSync({ data: new util.TextEncoder().encodeInto(value) })
    return ComicTranslationRuntimeService.toHex(md.digestSync().data)
  }

  private static toHex(bytes: Uint8Array): string {
    const parts: string[] = []
    for (let index: number = 0; index < bytes.length; index++) {
      parts.push(bytes[index].toString(16).padStart(2, '0'))
    }
    return parts.join('')
  }
}
