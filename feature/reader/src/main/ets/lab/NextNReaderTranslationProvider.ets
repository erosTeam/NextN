import { common } from '@kit.AbilityKit'
import { fileUri } from '@kit.CoreFileKit'
import {
  ReaderAsset, ReaderAssetKind, ReaderAssetProvider, ReaderCancellation, ReaderImageInformation,
  ReaderImageCropBounds, ReaderImageCropSource, ReaderOriginalAssetPlan, ReaderPage,
  ReaderProcessedAssetVariant, ReaderVariantAssetPlan,
} from '@reader-kit/core'
import { ReaderFileInformation } from '@reader-kit/ui'
import {
  ComicTranslationReaderPageInput, ComicTranslationRuntimeService, ComicVisualTranslationRunResult,
  ReaderPageCropService,
} from 'shared'
import { connectNextNReaderTranslationProbe } from './NextNReaderTranslationProbe'

class NextNReaderTranslationCropSource implements ReaderImageCropSource {
  private static sequence: number = 0
  private path: string
  private identity: string

  constructor(path: string) {
    this.path = path
    this.identity = `reader-shared-translation:${++NextNReaderTranslationCropSource.sequence}`
  }

  async read(): Promise<ReaderImageCropBounds> {
    const bounds = await ReaderPageCropService.detect(this.path, this.identity)
    return new ReaderImageCropBounds(bounds.left, bounds.top, bounds.right, bounds.bottom)
  }
}

export class NextNReaderTranslationConfiguration {
  enabled: boolean
  projectId: string
  targetLanguage: string
  sourceLanguage: string
  sourceProfileId: string
  sourceRevision: number
  modelId: string
  sidecarSelectionEpoch: number

  constructor(enabled: boolean, projectId: string, targetLanguage: string, sourceLanguage: string,
    sourceProfileId: string, sourceRevision: number, modelId: string, sidecarSelectionEpoch: number) {
    this.enabled = enabled
    this.projectId = projectId
    this.targetLanguage = targetLanguage
    this.sourceLanguage = sourceLanguage
    this.sourceProfileId = sourceProfileId
    this.sourceRevision = sourceRevision
    this.modelId = modelId
    this.sidecarSelectionEpoch = sidecarSelectionEpoch
  }

  identity(): string {
    if (!this.enabled || this.projectId.length === 0 || this.targetLanguage.length === 0 ||
      this.sourceProfileId.length === 0 || this.modelId.length === 0 ||
      !Number.isSafeInteger(this.sourceRevision) || this.sourceRevision <= 0 ||
      !Number.isSafeInteger(this.sidecarSelectionEpoch) || this.sidecarSelectionEpoch < 0) return ''
    return JSON.stringify([this.targetLanguage, this.sourceProfileId, this.sourceRevision,
      this.modelId, this.sidecarSelectionEpoch])
  }

  resultIdentity(result: ComicVisualTranslationRunResult): string {
    const value = result.renderedPage.identity
    return JSON.stringify([value.targetLanguage, value.translationSourceProfileId,
      value.translationSourceRevision, value.translationModelId, this.sidecarSelectionEpoch])
  }
}

class NextNReaderTranslationPlan implements ReaderVariantAssetPlan {
  page: ReaderPage
  variant: ReaderProcessedAssetVariant = 'translated'
  identity: string
  private path: string
  private originalAvailable: boolean

  constructor(page: ReaderPage, identity: string, path: string, originalAvailable: boolean) {
    this.page = page.copy()
    this.identity = identity
    this.path = path
    this.originalAvailable = originalAvailable
  }

  async load(cancellation: ReaderCancellation, _forceReload: boolean): Promise<ReaderAsset> {
    cancellation.check()
    const facts = new ReaderImageInformation()
    facts.variant = 'translated'
    const asset = new ReaderAsset(fileUri.getUriFromPath(this.path), () => {},
      new ReaderFileInformation(this.path, facts))
    asset.crop = new NextNReaderTranslationCropSource(this.path)
    asset.originalAvailable = this.originalAvailable
    return asset
  }
}

/** NextN owns translation identity, runtime invocation and generated-file lifetime. */
export class NextNReaderTranslationProvider implements ReaderAssetProvider {
  cancellationMode: 'consumer-only' | 'transport'
  informationSupported: boolean
  prepareOriginal?: (page: ReaderPage, cancellation: ReaderCancellation) => Promise<ReaderOriginalAssetPlan>
  private provider: ReaderAssetProvider
  private context: common.UIAbilityContext
  private configuration: (page: ReaderPage) => NextNReaderTranslationConfiguration
  private sourcePaths: Map<string, string> = new Map<string, string>()

  constructor(context: common.UIAbilityContext, provider: ReaderAssetProvider,
    configuration: (page: ReaderPage) => NextNReaderTranslationConfiguration) {
    this.context = context
    this.provider = provider
    this.configuration = configuration
    this.cancellationMode = provider.cancellationMode
    this.informationSupported = provider.informationSupported === true
    if (provider.prepareOriginal !== undefined) {
      this.prepareOriginal = (page: ReaderPage, cancellation: ReaderCancellation): Promise<ReaderOriginalAssetPlan> => {
        cancellation.check()
        if (this.provider.prepareOriginal === undefined) throw new Error('reader_original_unavailable')
        return this.provider.prepareOriginal(page, cancellation)
      }
    }
  }

  async load(page: ReaderPage, kind: ReaderAssetKind, cancellation: ReaderCancellation,
    forceReload: boolean): Promise<ReaderAsset> {
    const asset = await this.provider.load(page, kind, cancellation, forceReload)
    if (kind === 'original') {
      const path = NextNReaderTranslationProvider.localPath(asset.uri)
      if (path.length > 0) this.sourcePaths.set(this.pageIdentity(page), path)
      else this.sourcePaths.delete(this.pageIdentity(page))
    }
    return asset
  }

  async prepareVariant(page: ReaderPage, variant: ReaderProcessedAssetVariant, identity: string,
    cancellation: ReaderCancellation): Promise<ReaderVariantAssetPlan> {
    if (variant !== 'translated') {
      if (this.provider.prepareVariant === undefined) throw new Error('reader_variant_unavailable')
      return this.provider.prepareVariant(page, variant, identity, cancellation)
    }
    cancellation.check()
    const configuration = this.configuration(page)
    if (configuration.identity().length === 0 || configuration.identity() !== identity) {
      throw new Error('reader_translation_configuration_unavailable')
    }
    const sourcePath = this.sourcePaths.get(this.pageIdentity(page)) ?? ''
    if (sourcePath.length === 0) throw new Error('reader_translation_source_unavailable')
    const detach = cancellation.onCancel((): void => {
      console.info(`[NextNSharedTranslation] cancelled source=${page.sourceIndex} identity=${identity}`)
      connectNextNReaderTranslationProbe().deliver(
        this.context, page.unit.work, page.sourceIndex, 'cancelled', identity)
    })
    try {
      const probe = connectNextNReaderTranslationProbe()
      const localResultPath = probe.result(this.context, page.unit.work)
      if (localResultPath.length > 0) {
        console.info(`[NextNSharedTranslation] prepare source=${page.sourceIndex} identity=${identity} runtime=local-probe`)
        probe.deliver(this.context, page.unit.work, page.sourceIndex, 'prepare', identity)
        cancellation.check()
        if (probe.unavailable(this.context, page.unit.work, page.sourceIndex)) {
          throw new Error('reader_translation_probe_unavailable')
        }
        console.info(`[NextNSharedTranslation] applied source=${page.sourceIndex} identity=${identity} runtime=local-probe`)
        probe.deliver(this.context, page.unit.work, page.sourceIndex, 'applied', identity)
        return new NextNReaderTranslationPlan(page, identity, localResultPath,
          this.provider.prepareOriginal !== undefined)
      }
      const input = new ComicTranslationReaderPageInput()
      input.projectId = configuration.projectId
      input.pageIndex = page.sourceIndex
      input.imageFilePath = sourcePath
      input.imageWidth = page.width
      input.imageHeight = page.height
      input.sourceLanguage = configuration.sourceLanguage
      input.targetLanguage = configuration.targetLanguage
      console.info(`[NextNSharedTranslation] prepare source=${page.sourceIndex} identity=${identity}`)
      const result = await ComicTranslationRuntimeService.runReaderPage(this.context, input)
      cancellation.check()
      if (this.configuration(page).identity() !== identity || configuration.resultIdentity(result) !== identity ||
        result.renderedPage.localFilePath.length === 0) throw new Error('reader_translation_result_stale')
      console.info(`[NextNSharedTranslation] applied source=${page.sourceIndex} identity=${identity}`)
      probe.deliver(this.context, page.unit.work, page.sourceIndex, 'applied', identity)
      return new NextNReaderTranslationPlan(page, identity, result.renderedPage.localFilePath,
        this.provider.prepareOriginal !== undefined)
    } catch (error) {
      console.warn(`[NextNSharedTranslation] unavailable source=${page.sourceIndex} identity=${identity} error=${String(error)}`)
      connectNextNReaderTranslationProbe().deliver(
        this.context, page.unit.work, page.sourceIndex, 'unavailable', identity)
      throw error as Error
    } finally {
      detach()
    }
  }

  private pageIdentity(page: ReaderPage): string {
    return JSON.stringify([page.unit.scope, page.unit.work, page.unit.unit, page.key, page.sourceIndex])
  }

  private static localPath(uri: string): string {
    return uri.startsWith('file://') ? uri.substring('file://'.length) : ''
  }
}
