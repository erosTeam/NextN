import { ReaderTrialLayoutCommit, ReaderKeepScreenOn, ReaderTapAction, ReaderRuntimePolicyIntent,
  ReaderCloseContext } from '@reader-kit/ui'
import { common } from '@kit.AbilityKit'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { ReaderPagedSession, ReaderPagedFrame, ReaderUnitKey, ReaderInputPort, ReaderImageShareHost, ReaderLayout,
  ReaderReadingAnchor, ReaderDisplayPolicy, ReaderPage, ReaderVariantPreference, ReaderAssetProvider } from '@reader-kit/core'
import { ReaderEntryTransition, ReaderEntryPreviewSource } from '@reader-kit/ui'
import { ReaderLabSurface, ReaderSurface, ReaderTrialWindow, ReaderLabVisibilityState, connectReaderLabVisibility,
  ReaderLabAssetProbe, ReaderLabRequest, ReaderVolumeKeys, ReaderHostAction, ReaderMediaActions,
  ReaderHostStatus, ReaderObservationSink } from '@reader-kit/ui'
import { NextNReaderLabAdapter } from './NextNReaderLabAdapter'
import { ReaderLabShareProbe } from '@reader-kit/ui'
import { connectReaderPresentation, ReaderPresentationService, ReaderPresentationState, connectLayoutSafeArea,
  LayoutSafeAreaState, ThemeDisplayState, ThemeTokens, nextNHdsTitle, ReaderTrialOriginalProbe,
  ReaderTrialOriginalFacts, appSheetOptions, AppStrings, NhGalleryExternalOpenService,
  ReaderSuperResolutionService, CommentTranslationService, ComicVisualProviderSettings,
  ComicVisualProviderSettingsSnapshot, COMIC_VISUAL_ROUTE_LOCAL, COMIC_VISUAL_ROUTE_SELF_HOSTED,
  COMIC_VISUAL_ROUTE_TORII, connectLanguageState, LanguageState, connectLlmSourceProfiles,
  LlmSourceProfilesState, connectMangaRenderingService, MangaRenderingServiceState,
  supportsMangaTranslation, ToriiFontCatalog, ToriiWholePageConfig, ToriiWholePageSecretStore,
  TORII_WHOLE_PAGE_SOURCE_REVISION, NhGalleryDetail, NhGalleryPage, NhTag } from 'shared'
import { NextNReaderOriginalProbeProvider } from './NextNReaderOriginalProbeProvider'
import { NextNReaderOriginalProbeCatalog } from './NextNReaderOriginalProbeCatalog'
import { ReaderSystemImageSaveHost } from '@reader-kit/ui'
import { NextNReaderImageSaveDownload } from './NextNReaderImageSaveDownload'
import { connectThemeDisplay, NhReaderBackgroundMode, NhReaderMode, ReaderSettingsRepository,
  NhReaderTapZoneResolver } from 'shared'
import { NextNReaderInitialPolicy } from './NextNReaderInitialPolicy'
import { connectNextNReaderLabContextProbe } from './NextNReaderLabContextProbe'
import { NextNReaderObservedProgress } from './NextNReaderObservedProgress'
import { connectNextNReaderObservedProgressProbe } from './NextNReaderObservedProgressProbe'
import { NextNReaderProgressWriteGate } from './NextNReaderProgressWriteGate'
import { NextNReaderProgressPersistence } from './NextNReaderProgressPersistence'
import { NextNReaderHostRequest } from './NextNReaderHostRequest'
import { NextNProductionReaderDataSource } from './NextNReaderDataSource'
import { connectReaderOverlayNavigation } from 'shared'
import {
  NextNReaderProductionFailureProbe,
  NextNReaderProductionFailureProbeProvider,
} from './NextNReaderProductionFailureProbe'
import { NextNReaderImageShareHost } from './NextNReaderImageShareHost'
import { NextNReaderRuntimePreferences } from './NextNReaderRuntimePreferences'
import {
  NextNReaderSuperResolutionConfiguration,
  NextNReaderSuperResolutionProvider,
} from './NextNReaderSuperResolutionProvider'
import {
  NextNReaderTranslationConfiguration,
  NextNReaderTranslationProvider,
} from './NextNReaderTranslationProvider'
import { connectNextNReaderTranslationProbe } from './NextNReaderTranslationProbe'

@ComponentV2
export struct NextNReaderLabPage {
  @Require @Param request: NextNReaderHostRequest
  /** Present only for an explicit Debug Lab route; production requests never carry probe fields. */
  @Param labRequest: ReaderLabRequest | null = null
  @Param entryTransition: ReaderEntryTransition | null = null
  @Param entryPhase: string = 'finished'
  @Param entryPreview: ReaderEntryPreviewSource | null = null
  @Param managesTrialWindow: boolean = true
  /** The production overlay already owns HdsNavDestination and its lifecycle. */
  @Param embedded: boolean = false
  @Param externalRouteActive: boolean = false
  @Param hostClosing: boolean = false
  @Param prepareChrome: ((isCurrent: () => boolean) => Promise<boolean>) | null = null
  @Param hostSettingsAvailable: boolean = false
  @BuilderParam settingsSheetContent: (dismiss: () => void) => void = this.EmptySettingsSheetContent
  @Event onClose: () => void = () => {}
  @Event onShown: () => void = () => {}
  @Event onStatusBarVisible: (visible: boolean) => void = () => {}
  @Event onReaderPresentationChanged: (chromeVisible: boolean, fullscreen: boolean, canvasDark: boolean) => void =
    () => {}
  @Event onRegisterBackRequest: (request: (() => boolean) | null) => void = () => {}
  @Event onPrepareClose: (context: ReaderCloseContext | null, image: NhGalleryPage | null) => Promise<boolean> =
    (): Promise<boolean> => Promise.resolve(true)
  @Event onPreparedClose: (context: ReaderCloseContext | null, image: NhGalleryPage | null,
    targetReady: boolean) => void = () => {}
  /** Host-neutral lifecycle notification; the embedding shell owns preview disposal. */
  @Event onEntrySettled: () => void = () => {}
  @Local private session: ReaderPagedSession | null = null
  private mediaActions: ReaderMediaActions = new ReaderMediaActions()
  @Local private labVisibility: ReaderLabVisibilityState = connectReaderLabVisibility()
  @Local private readerPresentation: ReaderPresentationState = connectReaderPresentation()
  @Local private themeDisplay: ThemeDisplayState = connectThemeDisplay()
  @Local private routeActive: boolean = false
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  private unitKey: ReaderUnitKey = new ReaderUnitKey('', '', '')
  private trialWindow: ReaderTrialWindow = new ReaderTrialWindow(null, true)
  private keepScreenOn: ReaderKeepScreenOn | null = null
  @Local private closeRequested: boolean = false
  @Local private readerSettingsSheetShown: boolean = false
  @Local private presentationReady: boolean = false
  private volumeDisposed: boolean = false
  private input: ReaderInputPort = new ReaderInputPort()
  private volumeKeys: ReaderVolumeKeys = new ReaderVolumeKeys(this.input)
  private originalProbeEpoch: number = 0
  private originalProbe: NextNReaderOriginalProbeProvider | null = null
  private originalProbeHostClosed: boolean = false
  private observedProgress: NextNReaderObservedProgress = new NextNReaderObservedProgress()
  private progressWrites: NextNReaderProgressWriteGate = new NextNReaderProgressWriteGate()
  private progressEpoch: number = 0
  private progressPersistence: NextNReaderProgressPersistence | null = null
  private progressFlush: Promise<boolean> | null = null
  private entrySettledNotified: boolean = false
  private enhancementInteractionTimer: number = -1
  private adapter: NextNReaderLabAdapter | null = null
  @Local private currentSourceIndex: number = -1
  @Local private translationRequestedPages: number[] = []
  @Local private translationAppliedPages: number[] = []
  @Local private translationHiddenPages: number[] = []
  @Local private translationAutoFailedPages: number[] = []
  @Local private translationAutoEnabled: boolean = false
  @Local private translationBusyPage: number = -1
  @Local private translationErrorPage: number = -1
  @Local private translationPreferenceRevision: number = 0
  private translationAutoScheduleEpoch: number = 0
  @Local private comicVisualRoute: string = COMIC_VISUAL_ROUTE_LOCAL
  @Local private toriiRuntimeProfileId: string = ''
  @Local private toriiRuntimeModelId: string = ''
  @Local private language: LanguageState = connectLanguageState()
  @Local private llmSources: LlmSourceProfilesState = connectLlmSourceProfiles()
  @Local private mangaRenderingService: MangaRenderingServiceState = connectMangaRenderingService()

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const production = this.request.productionSources === true
    const lab = this.labRequest
    if (!context.applicationInfo.debug || (!production && lab === null)) return
    this.notifyEntrySettled()
    if (this.embedded) {
      this.onRegisterBackRequest((): boolean => {
        this.closeTrial()
        return true
      })
    }
    connectNextNReaderLabContextProbe().deliver(this.request.work, context)
    this.volumeDisposed = false
    if (!this.request.readingChrome) void this.restorePresentation(context)
    this.keepScreenOn = new ReaderKeepScreenOn(context)
    if (this.request.readingChrome && this.managesTrialWindow) this.trialWindow.open(context)
    const adapter = this.request.productionSources === true
      ? new NextNReaderLabAdapter(context, new NextNProductionReaderDataSource(
        context,
        connectReaderOverlayNavigation().consumeDetailSeed(
          Number(this.request.work),
          this.request.routeEpoch ?? 0,
        ),
      ))
      : new NextNReaderLabAdapter(context)
    this.adapter = adapter
    if (this.request.productionSources === true) this.restoreComicVisualRouteIdentity()
    const productionFailurePage: number = this.request.productionSources === true && context.applicationInfo.debug
      ? NextNReaderProductionFailureProbe.consume(this.request.work)
      : -1
    const productionProvider = productionFailurePage >= 0
      ? new NextNReaderProductionFailureProbeProvider(adapter, this.request.work, productionFailurePage)
      : adapter
    this.progressPersistence = new NextNReaderProgressPersistence(context, adapter)
    this.progressFlush = null
    this.progressEpoch = this.progressWrites.open(this.request.work, (pageIndex: number): Promise<void> => {
      const operation = this.progressPersistence?.save(
        this.request.work,
        this.request.progressReadWrite,
        pageIndex,
      ) ?? Promise.resolve()
      connectNextNReaderObservedProgressProbe().deliver(this.request.work, pageIndex)
      return operation
    })
    const imageShare = new NextNReaderImageShareHost(context, adapter)
    this.mediaActions = new ReaderMediaActions(
      lab === null ? imageShare : new ReaderLabShareProbe(imageShare, lab.shareProbe),
      new ReaderSystemImageSaveHost(context,
        (uri: string, path: string): Promise<void> => NextNReaderImageSaveDownload.download(uri, path)),
    )
    this.unitKey = new ReaderUnitKey('nh', this.request.work, this.request.work)
    // The probe observes the actual optional entry lifecycle, whether the host
    // labels the request as a Lab thumbnail trial or supplies a production entry.
    this.originalProbeEpoch = this.entryTransition !== null ?
      ReaderTrialOriginalProbe.consume(this.request.work, this.request.pageIndex) : 0
    if (this.originalProbeEpoch !== 0) {
      this.originalProbe = new NextNReaderOriginalProbeProvider(adapter, this.originalProbeEpoch,
        this.request.work, this.request.pageIndex)
      ReaderTrialOriginalProbe.bindFacts(this.originalProbeEpoch, (): ReaderTrialOriginalFacts => this.originalProbeFacts())
    }
    const catalog = this.originalProbeEpoch !== 0 && ReaderTrialOriginalProbe.read().unknownMetrics ?
      new NextNReaderOriginalProbeCatalog(adapter, this.request.work, this.request.pageIndex) : adapter
    const variantProvider = new NextNReaderSuperResolutionProvider(context, this.originalProbe ?? productionProvider,
      (): NextNReaderSuperResolutionConfiguration => this.superResolutionConfiguration())
    const translationProvider = new NextNReaderTranslationProvider(context, variantProvider,
      (page: ReaderPage): NextNReaderTranslationConfiguration => this.translationConfiguration(page))
    const assetProvider: ReaderAssetProvider = lab === null ? translationProvider :
      new ReaderLabAssetProbe(translationProvider, lab.thumbnailFailurePage,
        lab.informationProbe, lab.thumbnailEntry ? lab.failurePage : -1)
    const session = new ReaderPagedSession(catalog, assetProvider, adapter)
    connectNextNReaderTranslationProbe().bindAction(context, this.request.work, (id: string): boolean => {
      const state = this.session?.snapshot()
      const source = state?.unit?.key
      const sourceIndex = state?.anchor?.sourceIndexHint ?? -1
      if (source === null || source === undefined || sourceIndex < 0) return false
      const revision = this.translationPreferenceRevision
      this.handleTranslationAction(id, source, state?.navigationRevision ?? -1, sourceIndex)
      return this.translationPreferenceRevision !== revision
    })
    if (this.request.readingChrome) void this.initializeSession(context, session)
    else this.session = session
  }

  private async initializeSession(context: common.UIAbilityContext, session: ReaderPagedSession): Promise<void> {
    try {
      await ReaderPresentationService.restore(context)
      if (this.volumeDisposed || this.closeRequested || this.hostClosing) return
      const galleryId = Number(this.request.work)
      const initialPageIndex = await (this.progressPersistence?.restore(
        this.request.work,
        this.request.pageIndex,
        this.request.restoreSavedProgress ?? !(this.labRequest?.thumbnailEntry ?? false),
        this.request.progressReadWrite,
      ) ?? Promise.resolve(this.request.pageIndex))
      if (this.volumeDisposed || this.closeRequested || this.hostClosing) return
      const column = await ReaderSettingsRepository.columnMode(context,
        Number.isSafeInteger(galleryId) && galleryId > 0 ? galleryId : 0)
      if (this.volumeDisposed || this.closeRequested || this.hostClosing) return
      const policy = NextNReaderInitialPolicy.resolve(
        ReaderPresentationService.snapshot(),
        column,
        this.labRequest?.entryLayoutOverride ?? null,
        this.labRequest?.entryDirectionOverride ?? null,
      )
      session.setPolicy(policy)
      this.request.pageIndex = initialPageIndex
      console.info(`[NextNReaderLab] initial_policy gallery=${galleryId} database=${context.databaseDir} column=${column} cover=${policy.firstPageAlone} layout=${policy.layout} axis=${policy.pagingAxis} direction=${policy.direction} spread=${policy.spreadLayout}`)
      this.presentationReady = true
      if (this.embedded) {
        this.onReaderPresentationChanged(true, this.readerPresentation.fullscreen, this.readerCanvasDark())
      }
      // ReaderSurface opens on mount: never publish a default session and change it after first open.
      this.session = session
      this.syncReaderActivity()
    } catch (_error) {
      console.warn('[NextNReaderLab] initial_reader_policy_unavailable')
      if (!this.volumeDisposed && !this.closeRequested && !this.hostClosing) this.closeTrial(true)
    }
  }

  private resolveTapZone(x: number, y: number, layout: ReaderLayout): ReaderTapAction {
    if (!this.presentationReady || this.volumeDisposed || this.closeRequested || this.hostClosing ||
      !this.hostRouteActive() || !this.labVisibility.foreground || this.session === null) return 'none'
    // The trial can change layout without changing the saved production mode.
    const continuous = layout === 'continuous'
    return NhReaderTapZoneResolver.resolve(
      continuous ? this.readerPresentation.tapZoneLayoutContinuous : this.readerPresentation.tapZoneLayoutPaged,
      continuous ? this.readerPresentation.tapZoneInvertContinuous : this.readerPresentation.tapZoneInvertPaged,
      x, y, 1, 1)
  }

  @Monitor('entryPhase')
  private notifyEntrySettled(): void {
    if (this.entrySettledNotified || (this.entryPhase !== 'finished' && this.entryPhase !== 'cancelled')) return
    this.entrySettledNotified = true
    this.onEntrySettled()
  }

  aboutToDisappear(): void {
    this.volumeDisposed = true
    this.translationAutoScheduleEpoch += 1
    this.translationPreferenceRevision += 1
    this.translationBusyPage = -1
    this.adapter = null
    if (this.enhancementInteractionTimer >= 0) clearTimeout(this.enhancementInteractionTimer)
    this.enhancementInteractionTimer = -1
    ReaderSuperResolutionService.setInteractionPaused(false)
    if (this.embedded) this.onRegisterBackRequest(null)
    void this.finishProgressWrites()
    this.keepScreenOn?.close()
    this.entryTransition?.cancel(); this.entryPreview?.release()
    this.originalProbeHostClosed = true
    this.originalProbe?.close()
    if (this.originalProbeEpoch !== 0) ReaderTrialOriginalProbe.detachFacts(this.originalProbeEpoch)
    this.volumeKeys.close()
    if (this.managesTrialWindow) this.trialWindow.close()
  }

  private syncChromeVisible(visible: boolean): void {
    if (this.embedded) {
      this.onReaderPresentationChanged(visible, this.readerPresentation.fullscreen, this.readerCanvasDark())
      return
    }
    if (visible) return // The before-show gate already applied host visibility.
    const statusVisible = !connectReaderPresentation().fullscreen || visible
    if (this.managesTrialWindow) this.trialWindow.setStatusBarVisible(statusVisible)
    else this.onStatusBarVisible(statusVisible)
  }

  private async prepareChromeShow(isCurrent: () => boolean): Promise<boolean> {
    const current = (): boolean => isCurrent() && !this.closeRequested && !this.hostClosing &&
      this.hostRouteActive() && this.labVisibility.foreground
    if (!current()) return false
    if (!this.managesTrialWindow) return this.prepareChrome === null ? false : this.prepareChrome(current)
    if (!await this.trialWindow.prepareStatusBarVisible() || !current()) return false
    return ReaderTrialLayoutCommit.wait(this.getUIContext(), (): string =>
      this.safeArea.topAvoidHeight > 0 ? `${this.safeArea.topAvoidHeight}:${this.safeArea.bottomAvoidHeight}` : '', current)
  }

  private closeTrial(initializationFailed: boolean = false, suppliedContext: ReaderCloseContext | null = null): void {
    if (this.closeRequested) return
    this.closeRequested = true
    const context: ReaderCloseContext | null = suppliedContext ?? (initializationFailed || this.session === null
      ? null : ReaderCloseContext.from(this.session.snapshot()))
    const image: NhGalleryPage | null = context === null ? null : this.adapter?.transitionPage(this.request.work,
      context.part.sourceIndex) ?? null
    const progressFlush = this.finishProgressWrites()
    if (this.embedded) {
      void this.onPrepareClose(context, image).then(async (targetReady: boolean): Promise<void> => {
        const saved = await progressFlush
        if (!saved) console.warn(`[NextNReaderLab] progress_flush_failed gallery=${this.request.work}`)
        if (this.hostRouteActive() || (initializationFailed && !this.volumeDisposed)) {
          this.onPreparedClose(context, image, targetReady)
        }
      })
      return
    }
    if (this.managesTrialWindow) this.trialWindow.close(async (): Promise<boolean> => {
      if (this.trialWindow.getCloseSystemAvoidAreaResult() === 'ready') {
        const ready = await ReaderTrialLayoutCommit.wait(this.getUIContext(), (): string =>
          this.safeArea.topAvoidHeight > 0 ? `${this.safeArea.topAvoidHeight}:${this.safeArea.bottomAvoidHeight}` : '',
          (): boolean => this.hostRouteActive() && this.labVisibility.foreground)
        console.info(`[ReaderTrialHost] standalone_close_layout_ready=${ready}`)
        return ready
      }
      return true
    }).then(async (): Promise<void> => {
      const saved = await progressFlush
      if (!saved) console.warn(`[NextNReaderLab] progress_flush_failed gallery=${this.request.work}`)
      if (this.hostRouteActive() || (initializationFailed && !this.volumeDisposed)) this.onClose()
    })
    else void progressFlush.then((saved: boolean): void => {
      if (!saved) console.warn(`[NextNReaderLab] progress_flush_failed gallery=${this.request.work}`)
      this.onClose()
    })
  }

  private finishProgressWrites(): Promise<boolean> {
    if (this.progressFlush !== null) return this.progressFlush
    this.progressWrites.seal(this.progressEpoch)
    this.progressFlush = this.progressWrites.flush(this.progressEpoch)
    return this.progressFlush
  }

  private originalProbeFacts(): ReaderTrialOriginalFacts {
    const facts = new ReaderTrialOriginalFacts()
    const entry = this.entryTransition
    facts.entryId = entry?.entryId ?? 0
    facts.entryPhase = entry?.phase ?? 'none'
    facts.layoutReady = entry?.target?.geometryReady ?? false
    facts.decodedReady = entry?.target?.decodedReady ?? false
    facts.hostActive = !this.originalProbeHostClosed && this.routeActive && this.labVisibility.foreground
    const state = this.session?.snapshot()
    if (state !== undefined) {
      facts.sessionPhase = state.phase
      facts.anchor = state.anchor?.sourceIndexHint ?? -1
      facts.navigationRevision = state.navigationRevision
      facts.selectionId = state.selectionId
      const frame = state.frames.find((value: ReaderPagedFrame): boolean => value.part.sourceIndex === facts.anchor)
      facts.slotId = frame?.slotId ?? 0
      facts.assetRequestId = frame?.asset.assetRequestId ?? 0
      facts.assetPhase = frame?.asset.phase ?? 'idle'
      facts.originalWidth = frame?.asset.page?.width ?? 0
      facts.originalHeight = frame?.asset.page?.height ?? 0
    }
    // layout/target facts do not assert that Index has revealed its trial overlay to the user.
    return facts
  }

  private readerCanvasDark(): boolean {
    if (this.readerPresentation.backgroundMode === NhReaderBackgroundMode.WHITE) return false
    if (this.readerPresentation.backgroundMode === NhReaderBackgroundMode.AUTO) return this.themeDisplay.effectiveDark
    return true
  }

  private readerCanvasBackground(): ResourceColor {
    if (this.readerPresentation.backgroundMode === NhReaderBackgroundMode.GRAY) return '#FF303030'
    if (this.readerPresentation.backgroundMode === NhReaderBackgroundMode.WHITE ||
      (this.readerPresentation.backgroundMode === NhReaderBackgroundMode.AUTO && !this.themeDisplay.effectiveDark)) {
      return '#FFFFFFFF'
    }
    return '#FF000000'
  }

  private readerCanvasForeground(): ResourceColor {
    return this.readerCanvasDark() ? '#FFFFFFFF' : '#FF000000'
  }

  private superResolutionConfiguration(): NextNReaderSuperResolutionConfiguration {
    return new NextNReaderSuperResolutionConfiguration(
      this.presentationReady && this.readerPresentation.superResolutionEnabled,
      this.readerPresentation.superResolutionModel,
      this.readerPresentation.superResolutionMaxHeight,
    )
  }

  private superResolutionIdentity(): string {
    return this.superResolutionConfiguration().identity()
  }

  private translationSourceLanguage(): string {
    const detail: NhGalleryDetail | null = this.adapter?.progressDetail(this.request.work) ?? null
    if (detail === null) return 'auto'
    for (let index: number = 0; index < detail.tags.length; index++) {
      const tag: NhTag = detail.tags[index]
      const namespace = tag.type.trim().toLowerCase()
      const language = tag.name.trim()
      if ((namespace === 'language' || namespace === 'languages') && language.length > 0 &&
        language.toLowerCase() !== 'translated') return language
    }
    return 'auto'
  }

  private translationConfiguration(_page: ReaderPage): NextNReaderTranslationConfiguration {
    const targetLanguage = CommentTranslationService.targetLanguage()
    const projectId = `nh-reader-${this.request.work}-${targetLanguage}`
    if (!this.request.productionSources || targetLanguage.length === 0) {
      return new NextNReaderTranslationConfiguration(false, '', '', 'auto', '', 0, '', 0)
    }
    if (this.comicVisualRoute === COMIC_VISUAL_ROUTE_TORII) {
      return new NextNReaderTranslationConfiguration(
        this.toriiRuntimeProfileId.length > 0 && this.toriiRuntimeModelId.length > 0,
        projectId, targetLanguage, this.translationSourceLanguage(), this.toriiRuntimeProfileId,
        TORII_WHOLE_PAGE_SOURCE_REVISION, this.toriiRuntimeModelId, 0)
    }
    const binding = this.llmSources.mangaBinding
    const profile = binding.configured() ? this.llmSources.findById(binding.sourceProfileId) : null
    const rendererReady = this.comicVisualRoute !== COMIC_VISUAL_ROUTE_SELF_HOSTED ||
      (this.mangaRenderingService.initialized && this.mangaRenderingService.enabled)
    const enabled = profile !== null && supportsMangaTranslation(profile) && rendererReady
    return new NextNReaderTranslationConfiguration(enabled, projectId, targetLanguage,
      this.translationSourceLanguage(), profile?.sourceProfileId ?? '', profile?.sourceRevision ?? 0,
      binding.modelId, this.mangaRenderingService.enabled ? this.mangaRenderingService.selectionEpoch : 0)
  }

  private translationFrame(sourceIndex: number): ReaderPagedFrame | null {
    return this.session?.snapshot().frames.find(
      (frame: ReaderPagedFrame): boolean => frame.part.sourceIndex === sourceIndex,
    ) ?? null
  }

  private translationWindowFrame(sourceIndex: number): ReaderPagedFrame | null {
    const state = this.session?.snapshot()
    if (state === null || state === undefined) return null
    for (const item of state.window) {
      const frame = item.frames.find(
        (candidate: ReaderPagedFrame): boolean => candidate.part.sourceIndex === sourceIndex,
      )
      if (frame !== undefined) return frame
    }
    return null
  }

  private translationPage(sourceIndex: number): ReaderPage | null {
    const framePage = this.translationWindowFrame(sourceIndex)?.asset.page
    if (framePage !== null && framePage !== undefined) return framePage
    return this.session?.snapshot().pageMetadata.find(
      (page: ReaderPage): boolean => page.sourceIndex === sourceIndex,
    ) ?? null
  }

  private translationIdentity(sourceIndex: number): string {
    const page = this.translationPage(sourceIndex)
    return page === null || page === undefined ? '' : this.translationConfiguration(page).identity()
  }

  private scheduleNextAutoTranslation(sourceIndex: number): void {
    const epoch = ++this.translationAutoScheduleEpoch
    const prepare = (attempt: number): void => {
      if (epoch !== this.translationAutoScheduleEpoch || !this.translationAutoEnabled ||
        this.currentSourceIndex !== sourceIndex || this.volumeDisposed || this.closeRequested || this.hostClosing) return
      const state = this.session?.snapshot()
      const session = this.session
      const next = sourceIndex + 1
      if (session === null || state?.phase !== 'ready' || state.unit === null || next >= state.unit.pageCount ||
        this.pageIncluded(this.translationAppliedPages, next) ||
        this.pageIncluded(this.translationAutoFailedPages, next) ||
        this.pageIncluded(this.translationHiddenPages, next)) return
      const frame = this.translationWindowFrame(next)
      if (frame?.asset.phase !== 'displayed') {
        if (attempt < 20) setTimeout((): void => prepare(attempt + 1), 100)
        return
      }
      const identity = this.translationIdentity(next)
      if (identity.length === 0) {
        if (attempt < 20) setTimeout((): void => prepare(attempt + 1), 100)
        return
      }
      this.translationBusyPage = next
      this.translationPreferenceRevision += 1
      const preference = new ReaderVariantPreference('translated', identity)
      void session.prepareVariantForSource(next, state.unit.key.copy(), state.navigationRevision,
        'translated', identity).then((result: 'changed' | 'unchanged' | 'unavailable' | 'stale'): void => {
          if (result === 'stale' && this.currentSourceIndex === next) return
          this.handleVariantSelection(next, preference, result)
        })
    }
    setTimeout((): void => prepare(0), 0)
  }

  private pageIncluded(values: number[], sourceIndex: number): boolean {
    return values.includes(sourceIndex)
  }

  private includePage(values: number[], sourceIndex: number): number[] {
    return values.includes(sourceIndex) ? values : values.concat([sourceIndex])
  }

  private excludePage(values: number[], sourceIndex: number): number[] {
    return values.filter((value: number): boolean => value !== sourceIndex)
  }

  private variantPreference(sourceIndex: number): ReaderVariantPreference {
    const translationRequested = this.pageIncluded(this.translationRequestedPages, sourceIndex) ||
      (this.translationAutoEnabled && sourceIndex === this.currentSourceIndex &&
        !this.pageIncluded(this.translationAutoFailedPages, sourceIndex))
    const identity = this.translationIdentity(sourceIndex)
    if (translationRequested && !this.pageIncluded(this.translationHiddenPages, sourceIndex) && identity.length > 0) {
      return new ReaderVariantPreference('translated', identity)
    }
    const enhancement = this.superResolutionConfiguration()
    return enhancement.enabled
      ? new ReaderVariantPreference('enhanced', enhancement.identity())
      : new ReaderVariantPreference()
  }

  private translationActions(): ReaderHostAction[] {
    if (!this.request.productionSources || this.currentSourceIndex < 0) return []
    const translated = this.translationFrame(this.currentSourceIndex)?.asset.variant === 'translated' ||
      (this.pageIncluded(this.translationAppliedPages, this.currentSourceIndex) &&
        !this.pageIncluded(this.translationHiddenPages, this.currentSourceIndex))
    const hidden = this.pageIncluded(this.translationHiddenPages, this.currentSourceIndex)
    const label = translated ? AppStrings.get('reader_comic_translation_show_original') :
      hidden ? AppStrings.get('reader_comic_translation_show_result') :
        AppStrings.get('reader_comic_translation_action')
    const configured = this.translationIdentity(this.currentSourceIndex).length > 0
    return [
      new ReaderHostAction('translate-page', label, configured || translated || hidden,
        translated, this.translationBusyPage >= 0),
      new ReaderHostAction('translate-auto', AppStrings.get('reader_comic_translation_auto'), configured,
        this.translationAutoEnabled, this.translationBusyPage >= 0),
    ]
  }

  private currentTranslationTarget(source: ReaderUnitKey, navigation: number, sourceIndex: number): boolean {
    const state = this.session?.snapshot()
    return state?.phase === 'ready' && state.unit?.key.equals(source) === true &&
      state.navigationRevision === navigation && state.anchor?.sourceIndexHint === sourceIndex
  }

  private handleTranslationAction(id: string, source: ReaderUnitKey, navigation: number, sourceIndex: number): void {
    if (!this.currentTranslationTarget(source, navigation, sourceIndex)) return
    if (id === 'translate-auto') {
      this.toggleTranslationAuto(sourceIndex)
      return
    }
    if (id !== 'translate-page' || this.translationBusyPage >= 0) return
    const translated = this.translationFrame(sourceIndex)?.asset.variant === 'translated' ||
      (this.pageIncluded(this.translationAppliedPages, sourceIndex) &&
        !this.pageIncluded(this.translationHiddenPages, sourceIndex))
    const hidden = this.pageIncluded(this.translationHiddenPages, sourceIndex)
    if (translated) {
      this.translationHiddenPages = this.includePage(this.translationHiddenPages, sourceIndex)
      this.translationRequestedPages = this.excludePage(this.translationRequestedPages, sourceIndex)
    } else {
      this.translationHiddenPages = this.excludePage(this.translationHiddenPages, sourceIndex)
      this.translationAutoFailedPages = this.excludePage(this.translationAutoFailedPages, sourceIndex)
      this.translationRequestedPages = this.includePage(this.translationRequestedPages, sourceIndex)
      this.translationBusyPage = sourceIndex
      this.translationErrorPage = -1
    }
    if (hidden) this.translationRequestedPages = this.includePage(this.translationRequestedPages, sourceIndex)
    this.translationPreferenceRevision += 1
  }

  private toggleTranslationAuto(sourceIndex: number): void {
    if (this.translationBusyPage >= 0) return
    if (this.translationAutoEnabled) {
      this.translationAutoEnabled = false
      this.translationAutoScheduleEpoch += 1
      this.translationPreferenceRevision += 1
      return
    }
    if (this.translationIdentity(sourceIndex).length === 0) return
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('reader_comic_translation_auto'),
      message: AppStrings.get('reader_comic_translation_auto_confirm'),
      primaryButton: { value: AppStrings.get('common_cancel'), action: (): void => {} },
      secondaryButton: {
        value: AppStrings.get('common_on'),
        action: (): void => {
          this.translationAutoFailedPages = []
          this.translationHiddenPages = this.excludePage(this.translationHiddenPages, sourceIndex)
          this.translationAutoEnabled = true
          if (this.translationFrame(sourceIndex)?.asset.variant !== 'translated') this.translationBusyPage = sourceIndex
          else this.scheduleNextAutoTranslation(sourceIndex)
          this.translationPreferenceRevision += 1
        },
      },
    })
  }

  private handleVariantSelection(sourceIndex: number, preference: ReaderVariantPreference,
    result: 'changed' | 'unchanged' | 'unavailable' | 'stale'): void {
    if (preference.variant !== 'translated') return
    if (this.translationBusyPage === sourceIndex) this.translationBusyPage = -1
    if (result === 'changed' || result === 'unchanged') {
      this.translationRequestedPages = this.includePage(this.translationRequestedPages, sourceIndex)
      this.translationAppliedPages = this.includePage(this.translationAppliedPages, sourceIndex)
      this.translationAutoFailedPages = this.excludePage(this.translationAutoFailedPages, sourceIndex)
      if (this.translationErrorPage === sourceIndex) this.translationErrorPage = -1
      if (this.translationAutoEnabled && sourceIndex === this.currentSourceIndex) {
        this.scheduleNextAutoTranslation(sourceIndex)
      }
      return
    }
    if (result === 'unavailable') {
      this.translationRequestedPages = this.excludePage(this.translationRequestedPages, sourceIndex)
      if (this.translationAutoEnabled) {
        this.translationAutoFailedPages = this.includePage(this.translationAutoFailedPages, sourceIndex)
      }
      if (sourceIndex === this.currentSourceIndex) {
        this.translationErrorPage = sourceIndex
        this.scheduleNextAutoTranslation(sourceIndex)
      }
      this.translationPreferenceRevision += 1
    }
  }

  private restoreComicVisualRouteIdentity(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ComicVisualProviderSettings.load(context).then((snapshot: ComicVisualProviderSettingsSnapshot): void => {
      if (this.volumeDisposed || this.closeRequested || this.hostClosing) return
      this.comicVisualRoute = snapshot.route
      this.toriiRuntimeProfileId = ''
      this.toriiRuntimeModelId = ''
      if (snapshot.route === COMIC_VISUAL_ROUTE_TORII) {
        const credential = ToriiWholePageSecretStore.readSync(context)
        const config = new ToriiWholePageConfig()
        config.toriiApiKey = credential.toriiApiKey
        config.modelId = snapshot.toriiModelId
        config.fontId = ToriiFontCatalog.effectiveFontId(snapshot.toriiFontId,
          CommentTranslationService.targetLanguage())
        try {
          config.assertValid()
          this.toriiRuntimeProfileId = config.sourceProfileId()
          this.toriiRuntimeModelId = config.modelId
        } catch (_error) {}
      }
      this.translationPreferenceRevision += 1
    }).catch((): void => {})
  }

  @Monitor('language.effectiveLocale', 'llmSources.mangaBinding', 'llmSources.profiles',
    'mangaRenderingService.selectionEpoch', 'comicVisualRoute', 'toriiRuntimeProfileId', 'toriiRuntimeModelId')
  private onTranslationRuntimeChanged(): void {
    this.translationAutoFailedPages = []
    this.translationAppliedPages = []
    this.translationErrorPage = -1
    this.translationAutoScheduleEpoch += 1
    if (this.translationAutoEnabled && this.translationIdentity(this.currentSourceIndex).length === 0) {
      this.translationAutoEnabled = false
      this.translationBusyPage = -1
    }
    this.translationPreferenceRevision += 1
  }

  private setEnhancementInteractionBusy(busy: boolean): void {
    if (this.enhancementInteractionTimer >= 0) {
      clearTimeout(this.enhancementInteractionTimer)
      this.enhancementInteractionTimer = -1
    }
    if (busy) {
      ReaderSuperResolutionService.setInteractionPaused(true)
      return
    }
    this.enhancementInteractionTimer = setTimeout((): void => {
      this.enhancementInteractionTimer = -1
      ReaderSuperResolutionService.setInteractionPaused(false)
    }, 420)
  }

  private observeReaderPosition(anchor: ReaderReadingAnchor): void {
    const pageCount = this.session?.snapshot().unit?.pageCount ?? 0
    const pageIndex = this.observedProgress.observe(this.request.work, pageCount, anchor)
    if (pageIndex < 0) return
    if (this.currentSourceIndex !== pageIndex) {
      this.currentSourceIndex = pageIndex
      if (this.translationAutoEnabled && !this.pageIncluded(this.translationAutoFailedPages, pageIndex) &&
        !this.pageIncluded(this.translationHiddenPages, pageIndex) &&
        this.translationFrame(pageIndex)?.asset.variant !== 'translated') this.translationBusyPage = pageIndex
      else if (this.translationAutoEnabled && this.translationFrame(pageIndex)?.asset.variant === 'translated') {
        this.scheduleNextAutoTranslation(pageIndex)
      }
      this.translationPreferenceRevision += 1
    }
    this.progressWrites.save(this.progressEpoch, this.request.work, pageIndex)
    console.info(`[NextNReaderLab] observed_progress gallery=${this.request.work} page=${pageIndex}`)
  }

  syncKeepScreenOn(): void {
    this.keepScreenOn?.setActive(this.request.readingChrome && this.hostRouteActive() && this.labVisibility.foreground &&
      this.entryPhase !== 'layout' && !this.closeRequested && !this.hostClosing && this.readerPresentation.keepScreenOn)
  }

  @Monitor('readerPresentation.keepScreenOn', 'closeRequested', 'hostClosing')
  syncKeepScreenOnPolicy(): void { this.syncKeepScreenOn() }

  private async restorePresentation(context: common.UIAbilityContext): Promise<void> {
    try {
      await ReaderPresentationService.restore(context)
      if (this.volumeDisposed) return
      this.presentationReady = true
      this.syncReaderActivity()
    } catch (_error) {
      console.warn('[NextNReaderLab] reader_preferences_unavailable')
    }
  }

  @Monitor('routeActive', 'labVisibility.foreground', 'entryPhase', 'readerPresentation.volumeKeyTurn',
    'presentationReady', 'closeRequested', 'hostClosing', 'readerSettingsSheetShown', 'session')
  syncReaderActivity(): void {
    this.syncKeepScreenOn()
    const enabled = this.labRequest?.volumeKeysOverride ??
      (this.presentationReady && this.readerPresentation.volumeKeyTurn)
    this.volumeKeys.setActive(!this.volumeDisposed && !this.closeRequested && !this.hostClosing &&
      this.session !== null && this.request.readingChrome && enabled &&
      this.hostRouteActive() && this.labVisibility.foreground && !this.readerSettingsSheetShown &&
      this.entryPhase !== 'layout')
  }

  private hostRouteActive(): boolean {
    return this.embedded ? this.externalRouteActive : this.routeActive
  }

  @Builder
  private EmptySettingsSheetContent(_dismiss: () => void) {
    Column() {}
  }

  private openHostSettings(): void {
    if (!this.hostSettingsAvailable || !this.request.productionSources || this.closeRequested || this.hostClosing) return
    this.readerSettingsSheetShown = true
  }

  private closeHostSettings(): void {
    this.readerSettingsSheetShown = false
  }

  private showHostActionUnavailable(key: string): void {
    try { this.getUIContext().getPromptAction().showToast({ message: AppStrings.get(key) }) } catch (_) {}
  }

  private async openCurrentGalleryExternally(source: ReaderUnitKey): Promise<void> {
    const galleryId = Number(source.work)
    if (!this.request.productionSources || !Number.isSafeInteger(galleryId) || galleryId <= 0 ||
      source.work !== this.request.work ||
      !await NhGalleryExternalOpenService.openCanonicalGallery(
        this.getUIContext().getHostContext() as common.UIAbilityContext,
        galleryId,
      )) this.showHostActionUnavailable('gallery_error_external_open_unavailable')
  }

  private persistRuntimePolicy(policy: ReaderDisplayPolicy, intent: ReaderRuntimePolicyIntent): void {
    if (!this.request.productionSources) return
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (intent === 'layout') void NextNReaderRuntimePreferences.applyLayout(context, policy)
    else if (intent === 'direction') void NextNReaderRuntimePreferences.applyDirection(context, policy)
    else if (intent === 'spread_layout') void NextNReaderRuntimePreferences.applySpreadLayout(context, policy)
    else if (intent === 'first_page_alone') {
      const galleryId = Number(this.request.work)
      if (Number.isSafeInteger(galleryId) && galleryId > 0) {
        void NextNReaderRuntimePreferences.applyFirstPageAlone(context, galleryId, policy)
      }
    }
  }

  private persistCrop(enabled: boolean, policy: ReaderDisplayPolicy): void {
    if (!this.request.productionSources) return
    void NextNReaderRuntimePreferences.applyCrop(
      this.getUIContext().getHostContext() as common.UIAbilityContext,
      policy,
      enabled,
    )
  }

  /** Production inherits the canonical mode-specific choice; debug trials keep their explicit request contract. */
  private initialCropBorders(): boolean {
    if (this.labRequest?.cropBorders === true) return true
    if (this.request.productionSources !== true) return false
    return this.readerPresentation.mode === NhReaderMode.VERTICAL
      ? this.readerPresentation.cropBordersContinuous
      : this.readerPresentation.cropBordersPaged
  }

  @Builder
  private readerContent() {
    Column() {
        if (this.session !== null) {
          if (this.request.readingChrome) {
            ReaderSurface({ session: this.session, initialUnit: this.unitKey, initialIndex: this.request.pageIndex,
              imageInterpolation: this.readerPresentation.imageScalingQuality === 'low' ? ImageInterpolation.Low :
                this.readerPresentation.imageScalingQuality === 'high' ? ImageInterpolation.High : ImageInterpolation.Medium,
              canvasBackground: this.readerCanvasBackground(), canvasForeground: this.readerCanvasForeground(),
              input: this.input, mediaActions: this.mediaActions,
              tapZoneResolver: (x: number, y: number, layout: ReaderLayout): ReaderTapAction => this.resolveTapZone(x, y, layout),
              autoReadAvailable: true, autoReadSeconds: this.readerPresentation.autoPageSeconds,
              pageTurnAnimation: this.labRequest?.pageTurnAnimationOverride ?? this.readerPresentation.pageTurnAnimation,
              preloadDepth: this.readerPresentation.preloadPages,
              preferredVariant: this.presentationReady && this.readerPresentation.superResolutionEnabled ? 'enhanced' : 'default',
              preferredVariantIdentity: this.superResolutionIdentity(),
              variantPreferenceResolver: (sourceIndex: number): ReaderVariantPreference =>
                this.variantPreference(sourceIndex),
              variantPreferenceRevision: this.translationPreferenceRevision,
              onVariantSelection: (sourceIndex: number, preference: ReaderVariantPreference,
                result: 'changed' | 'unchanged' | 'unavailable' | 'stale'): void => {
                this.handleVariantSelection(sourceIndex, preference, result)
              },
              showPageNumber: this.readerPresentation.showPageNumber,
              cropBorders: this.initialCropBorders(),
              // Entry animation is optional; an incompatible cropped target cancels the flight.
              // Never remove a production reading feature merely because the source was a thumbnail.
              cropAvailable: this.request.productionSources === true || this.labRequest?.cropBorders === true,
              hostSettingsAvailable: this.hostSettingsAvailable,
              onHostSettings: (): void => { this.openHostSettings() },
              externalOpenAvailable: this.request.productionSources === true,
              onExternalOpen: (source: ReaderUnitKey): void => { void this.openCurrentGalleryExternally(source) },
              hostActions: this.translationActions(),
              onHostAction: (id: string, source: ReaderUnitKey, navigation: number, sourceIndex: number): void => {
                this.handleTranslationAction(id, source, navigation, sourceIndex)
              },
              hostStatus: this.currentSourceIndex >= 0 &&
                (this.translationBusyPage === this.currentSourceIndex || this.translationErrorPage === this.currentSourceIndex)
                ? new ReaderHostStatus(this.translationBusyPage === this.currentSourceIndex
                  ? AppStrings.get('reader_comic_translation_running')
                  : AppStrings.get('reader_comic_translation_failed'),
                this.translationBusyPage === this.currentSourceIndex) : null,
              onPolicyChanged: (policy, intent): void => { this.persistRuntimePolicy(policy, intent) },
              onCropChanged: (enabled, policy): void => { this.persistCrop(enabled, policy) },
              entryTransition: this.entryTransition, entryPreview: this.entryPreview,
              active: this.hostRouteActive() && this.labVisibility.foreground && !this.readerSettingsSheetShown,
              closing: this.closeRequested || this.hostClosing,
              beforeShowChrome: (isCurrent: () => boolean): Promise<boolean> => this.prepareChromeShow(isCurrent),
              topInset: this.safeArea.topAvoidHeight, bottomInset: this.safeArea.bottomAvoidHeight,
              accent: ThemeTokens.BRAND,
              onClose: (context: ReaderCloseContext | null): void => this.closeTrial(false, context),
              observation: new ReaderObservationSink(
                (anchor: ReaderReadingAnchor): void => this.observeReaderPosition(anchor)),
              onInteractionBusy: (busy: boolean): void => { this.setEnhancementInteractionBusy(busy) },
              onChromeVisible: (visible: boolean): void => this.syncChromeVisible(visible) })
          } else {
          ReaderLabSurface({ session: this.session, initialUnit: this.unitKey, initialIndex: this.request.pageIndex,
            preloadDepth: this.readerPresentation.preloadPages,
            failurePage: this.labRequest?.failurePage ?? -1,
            failureLayout: this.labRequest?.failureLayout ?? 'continuous',
            delayedMetricsPage: this.labRequest?.delayedMetricsPage ?? -1,
            active: this.hostRouteActive() && this.labVisibility.foreground })
          }
        }
    }
    .width('100%').height('100%')
    .padding({ top: this.request.readingChrome ? 0 : this.safeArea.topAvoidHeight + ThemeTokens.TITLE_BAR_HEIGHT,
      bottom: this.request.readingChrome ? 0 : this.safeArea.bottomAvoidHeight })
    .bindSheet(
      $$this.readerSettingsSheetShown,
      this.settingsSheetContent((): void => { this.closeHostSettings() }),
      appSheetOptions({
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        showClose: false,
        onDisappear: (): void => { this.closeHostSettings() },
      }),
    )
  }

  build() {
    if (this.embedded) {
      this.readerContent()
    } else {
      HdsNavDestination() {
        this.readerContent()
      }.titleBar(nextNHdsTitle($r('app.string.rkit_lab_title')))
      .hideTitleBar(this.request.readingChrome)
      .onBackPressed((): boolean => {
        if (!this.request.readingChrome) return false
        this.closeTrial()
        return true
      })
      .onShown((): void => { this.routeActive = true; this.onShown() })
      .onHidden((): void => { this.routeActive = false })
    }
  }
}
