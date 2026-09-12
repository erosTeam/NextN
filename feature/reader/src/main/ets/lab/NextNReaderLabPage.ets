import { ReaderTrialLayoutCommit, ReaderKeepScreenOn, ReaderTapAction } from '@reader-kit/ui'
import { common } from '@kit.AbilityKit'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { ReaderPagedSession, ReaderPagedFrame, ReaderUnitKey, ReaderInputPort, ReaderImageShareHost, ReaderLayout,
  ReaderReadingAnchor } from '@reader-kit/core'
import { ReaderEntryTransition, ReaderEntryPreviewSource } from '@reader-kit/ui'
import { ReaderLabSurface, ReaderSurface, ReaderTrialWindow, ReaderLabVisibilityState, connectReaderLabVisibility, ReaderLabAssetProbe, ReaderVolumeKeys } from '@reader-kit/ui'
import { NextNReaderLabAdapter } from './NextNReaderLabAdapter'
import { ReaderLabShareProbe } from '@reader-kit/ui'
import { connectReaderPresentation, ReaderPresentationService, ReaderPresentationState, connectLayoutSafeArea, LayoutSafeAreaState, ThemeDisplayState, ThemeTokens, nextNHdsTitle,
  ReaderTrialOriginalProbe, ReaderTrialOriginalFacts } from 'shared'
import { NextNReaderOriginalProbeProvider } from './NextNReaderOriginalProbeProvider'
import { NextNReaderOriginalProbeCatalog } from './NextNReaderOriginalProbeCatalog'
import { ReaderSystemImageSaveHost } from '@reader-kit/ui'
import { ReaderImageSaveHost } from '@reader-kit/core'
import { NextNReaderImageSaveDownload } from './NextNReaderImageSaveDownload'
import { connectThemeDisplay, NhReaderBackgroundMode, ReaderSettingsRepository, NhReaderTapZoneResolver } from 'shared'
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

@ComponentV2
export struct NextNReaderLabPage {
  @Require @Param request: NextNReaderHostRequest
  @Param entryTransition: ReaderEntryTransition | null = null
  @Param entryPhase: string = 'finished'
  @Param entryPreview: ReaderEntryPreviewSource | null = null
  @Param managesTrialWindow: boolean = true
  /** The production overlay already owns HdsNavDestination and its lifecycle. */
  @Param embedded: boolean = false
  @Param externalRouteActive: boolean = false
  @Param hostClosing: boolean = false
  @Param prepareChrome: ((isCurrent: () => boolean) => Promise<boolean>) | null = null
  @Event onClose: () => void = () => {}
  @Event onShown: () => void = () => {}
  @Event onStatusBarVisible: (visible: boolean) => void = () => {}
  @Event onReaderPresentationChanged: (chromeVisible: boolean, fullscreen: boolean, canvasDark: boolean) => void =
    () => {}
  @Event onRegisterBackRequest: (request: (() => boolean) | null) => void = () => {}
  @Event onPrepareClose: () => Promise<boolean> = (): Promise<boolean> => Promise.resolve(true)
  @Event onPreparedClose: (animated: boolean) => void = () => {}
  /** Host-neutral lifecycle notification; the embedding shell owns preview disposal. */
  @Event onEntrySettled: () => void = () => {}
  @Local private session: ReaderPagedSession | null = null
  private imageShare: ReaderImageShareHost | null = null
  private imageSave: ReaderImageSaveHost | null = null
  @Local private labVisibility: ReaderLabVisibilityState = connectReaderLabVisibility()
  @Local private readerPresentation: ReaderPresentationState = connectReaderPresentation()
  @Local private themeDisplay: ThemeDisplayState = connectThemeDisplay()
  @Local private routeActive: boolean = false
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  private unitKey: ReaderUnitKey = new ReaderUnitKey('', '', '')
  private trialWindow: ReaderTrialWindow = new ReaderTrialWindow(null, true)
  private keepScreenOn: ReaderKeepScreenOn | null = null
  @Local private closeRequested: boolean = false
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

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!context.applicationInfo.debug) return
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
    this.imageShare = new ReaderLabShareProbe(adapter, this.request.shareProbe)
    this.imageSave = new ReaderSystemImageSaveHost(context,
      (uri: string, path: string): Promise<void> => NextNReaderImageSaveDownload.download(uri, path))
    this.unitKey = new ReaderUnitKey('nh', this.request.work, this.request.work)
    this.originalProbeEpoch = this.request.thumbnailEntry ?
      ReaderTrialOriginalProbe.consume(this.request.work, this.request.pageIndex) : 0
    if (this.originalProbeEpoch !== 0) {
      this.originalProbe = new NextNReaderOriginalProbeProvider(adapter, this.originalProbeEpoch,
        this.request.work, this.request.pageIndex)
      ReaderTrialOriginalProbe.bindFacts(this.originalProbeEpoch, (): ReaderTrialOriginalFacts => this.originalProbeFacts())
    }
    const catalog = this.originalProbeEpoch !== 0 && ReaderTrialOriginalProbe.read().unknownMetrics ?
      new NextNReaderOriginalProbeCatalog(adapter, this.request.work, this.request.pageIndex) : adapter
    const session = new ReaderPagedSession(catalog, new ReaderLabAssetProbe(this.originalProbe ?? productionProvider, this.request.thumbnailFailurePage,
      this.request.informationProbe, this.request.thumbnailEntry ? this.request.failurePage : -1))
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
        this.request.restoreSavedProgress ?? !this.request.thumbnailEntry,
        this.request.progressReadWrite,
      ) ?? Promise.resolve(this.request.pageIndex))
      if (this.volumeDisposed || this.closeRequested || this.hostClosing) return
      const column = await ReaderSettingsRepository.columnMode(context,
        Number.isSafeInteger(galleryId) && galleryId > 0 ? galleryId : 0)
      if (this.volumeDisposed || this.closeRequested || this.hostClosing) return
      const policy = NextNReaderInitialPolicy.resolve(
        ReaderPresentationService.snapshot(),
        column,
        this.request.entryLayoutOverride,
        this.request.entryDirectionOverride,
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

  private closeTrial(initializationFailed: boolean = false): void {
    if (this.closeRequested) return
    this.closeRequested = true
    const progressFlush = this.finishProgressWrites()
    if (this.embedded) {
      void this.onPrepareClose().then(async (animated: boolean): Promise<void> => {
        const saved = await progressFlush
        if (!saved) console.warn(`[NextNReaderLab] progress_flush_failed gallery=${this.request.work}`)
        if (this.hostRouteActive() || (initializationFailed && !this.volumeDisposed)) {
          this.onPreparedClose(animated)
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

  private observeReaderPosition(anchor: ReaderReadingAnchor): void {
    const pageCount = this.session?.snapshot().unit?.pageCount ?? 0
    const pageIndex = this.observedProgress.observe(this.request.work, pageCount, anchor)
    if (pageIndex < 0) return
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
    'presentationReady', 'closeRequested', 'hostClosing', 'session')
  syncReaderActivity(): void {
    this.syncKeepScreenOn()
    const enabled = this.request.volumeKeysOverride ?? (this.presentationReady && this.readerPresentation.volumeKeyTurn)
    this.volumeKeys.setActive(!this.volumeDisposed && !this.closeRequested && !this.hostClosing &&
      this.session !== null && this.request.readingChrome && enabled &&
      this.hostRouteActive() && this.labVisibility.foreground && this.entryPhase !== 'layout')
  }

  private hostRouteActive(): boolean {
    return this.embedded ? this.externalRouteActive : this.routeActive
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
              input: this.input, imageShare: this.imageShare, imageSave: this.imageSave,
              tapZoneResolver: (x: number, y: number, layout: ReaderLayout): ReaderTapAction => this.resolveTapZone(x, y, layout),
              autoReadAvailable: true, autoReadSeconds: this.readerPresentation.autoPageSeconds,
              showPageNumber: this.readerPresentation.showPageNumber,
              cropBorders: this.request.cropBorders && !this.request.thumbnailEntry,
              cropAvailable: !this.request.thumbnailEntry,
              entryTransition: this.entryTransition, entryPreview: this.entryPreview,
              active: this.hostRouteActive() && this.labVisibility.foreground,
              closing: this.closeRequested || this.hostClosing,
              beforeShowChrome: (isCurrent: () => boolean): Promise<boolean> => this.prepareChromeShow(isCurrent),
              topInset: this.safeArea.topAvoidHeight, bottomInset: this.safeArea.bottomAvoidHeight,
              accent: ThemeTokens.BRAND, onClose: (): void => this.closeTrial(),
              onObserved: (anchor: ReaderReadingAnchor): void => this.observeReaderPosition(anchor),
              onChromeVisible: (visible: boolean): void => this.syncChromeVisible(visible) })
          } else {
          ReaderLabSurface({ session: this.session, initialUnit: this.unitKey, initialIndex: this.request.pageIndex,
            failurePage: this.request.failurePage,
            failureLayout: this.request.failureLayout,
            delayedMetricsPage: this.request.delayedMetricsPage,
            active: this.hostRouteActive() && this.labVisibility.foreground })
          }
        }
    }
    .width('100%').height('100%')
    .padding({ top: this.request.readingChrome ? 0 : this.safeArea.topAvoidHeight + ThemeTokens.TITLE_BAR_HEIGHT,
      bottom: this.request.readingChrome ? 0 : this.safeArea.bottomAvoidHeight })
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
