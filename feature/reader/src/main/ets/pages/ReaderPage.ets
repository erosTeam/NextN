import { common } from '@kit.AbilityKit'
import { LengthMetrics, SymbolGlyphModifier, window } from '@kit.ArkUI'
import { fileUri } from '@kit.CoreFileKit'
import { KeyCode } from '@kit.InputKit'
import inputConsumer from '@ohos.multimodalInput.inputConsumer'
import { Action, KeyEvent as InputConsumerKeyEvent } from '@ohos.multimodalInput.keyEvent'
import {
  HistoryRepository,
  AppStrings,
  NhApiClient,
  NhGalleryExternalOpenService,
  NhGalleryDetail,
  NhGalleryPage,
  NhTag,
  NhGalleryShareService,
  NhReaderBackgroundMode,
  NhReaderImageScalingQuality,
  NhReaderMode,
  NhReaderSpreadLayout,
  NhReaderSuperResolutionModel,
  NhReaderTapZoneAction,
  NhReaderTapZoneInvert,
  NhReaderTapZoneLayout,
  NhReaderTapZoneRegion,
  NhReaderTapZoneResolver,
  DownloadQueueService,
  ReaderImageCacheResult,
  ReaderImageCacheService,
  ReaderSuperResolutionService,
  ComicTranslationReaderPageInput,
  ComicTranslationRuntimeService,
  ComicVisualTranslationRunResult,
  COMIC_VISUAL_ROUTE_LOCAL,
  COMIC_VISUAL_ROUTE_SELF_HOSTED,
  COMIC_VISUAL_ROUTE_TORII,
  ComicVisualProviderSettings,
  ComicVisualProviderSettingsSnapshot,
  ToriiFontCatalog,
  ToriiWholePageConfig,
  ToriiWholePageSecretStore,
  TORII_WHOLE_PAGE_SOURCE_REVISION,
  CommentTranslationService,
  ReaderPresentationService,
  ReaderPresentationState,
  ReaderOverlayNavigationState,
  LayoutSafeAreaState,
  LanguageState,
  LlmSourceProfilesState,
  MangaRenderingServiceState,
  ThemeDisplayState,
  ThemeTokens,
  connectThemeDisplay,
  connectLanguageState,
  connectLayoutSafeArea,
  connectLlmSourceProfiles,
  connectMangaRenderingService,
  connectReaderPresentation,
  connectReaderOverlayNavigation,
  supportsMangaTranslation,
} from 'shared'
import { appMenuOptions } from 'shared'
import { appSheetOptions } from 'shared'

// Reader chrome remains a dark overlay. Canvas-recovery colors resolve from
// the Reader's local background choice instead of changing chrome affordance.
const READER_CONTROL_TINT: ResourceColor = '#26FFFFFF'
const READER_BACKGROUND_BLACK: ResourceColor = '#FF000000'
const READER_BACKGROUND_GRAY: ResourceColor = '#FF303030'
const READER_BACKGROUND_WHITE: ResourceColor = '#FFFFFFFF'
const READER_FOREGROUND_DARK_CANVAS: ResourceColor = '#FFFFFFFF'
const READER_FOREGROUND_LIGHT_CANVAS: ResourceColor = '#FF000000'
const READER_SECONDARY_FOREGROUND_DARK_CANVAS: ResourceColor = '#CCFFFFFF'
const READER_SECONDARY_FOREGROUND_LIGHT_CANVAS: ResourceColor = '#B3000000'
const READER_CONTROL_TINT_DARK_CANVAS: ResourceColor = '#26FFFFFF'
const READER_CONTROL_TINT_LIGHT_CANVAS: ResourceColor = '#26000000'
const READER_ZOOM_EPSILON: number = 1.01
const READER_ZOOM_ANIMATION_MS: number = 180
const MIN_DYNAMIC_MAX_SCALE: number = 4
const MAX_DYNAMIC_MAX_SCALE: number = 12
const MAX_EFFECTIVE_MAX_SCALE: number = 48
const NATIVE_SCALE_HEADROOM: number = 2
const DOUBLE_TAP_PRIMARY_SCALE: number = 2
const DOUBLE_TAP_FALLBACK_SCALE: number = 2
const DOUBLE_TAP_SCALE_EPSILON: number = 0.02
const PINCH_ELASTIC_MIN_SCALE: number = 0.8
const PINCH_UNDER_SCALE_RESISTANCE: number = 0.35
// Keep the Reader-internal navigator at the same stable 140vp rhythm as the
// ErosN/NextE strip. It is an overlay, never a content inset, so opening it
// cannot reflow the currently visible page.
const READER_THUMB_STRIP_HEIGHT: number = 140
const READER_THUMB_IMAGE_HEIGHT: number = 100
const READER_THUMB_FALLBACK_ASPECT: number = 0.72
const READER_THUMB_MIN_WIDTH: number = 64
const READER_THUMB_MAX_WIDTH: number = 152
// The thumbnail strip is a scrollable rail inside the chrome, not a padded
// toolbar row. Keep its edge whitespace with the first/last tiles so a
// partially-scrolled tile can still reach the chrome edge.
const READER_THUMB_RAIL_HEAD_TAIL_INSET: number = ThemeTokens.SPACE_MD
// This is chrome, not page layout. Keep the page scrubber in the same
// bottom-overlay family as NextE so a visible control never introduces a
// permanent Reader viewport inset.
const READER_PROGRESS_OVERLAY_HEIGHT: number = 52
const READER_PROGRESS_NUMBER_MIN_WIDTH: number = 38
const READER_TAP_ZONE_SCROLL_RATIO: number = 0.75
const READER_BOTTOM_TOOLBAR_HEIGHT: number = 44
const READER_ENHANCEMENT_STATUS_SIZE: number = 24
const READER_ENHANCEMENT_STATUS_OPACITY: number = 0.72
const READER_ENHANCEMENT_STATUS_BACKGROUND: ResourceColor = '#26000000'
const READER_ENHANCEMENT_STATUS_BOTTOM_GAP: number = ThemeTokens.SPACE_MD
const READER_PAGE_NUMBER_TEXT: ResourceColor = '#99FFFFFF'
const READER_PAGE_NUMBER_OUTLINE: ResourceColor = '#80000000'
const READER_PAGE_NUMBER_STROKE_WIDTH: number = 2.5
const READER_ENHANCEMENT_INTERACTION_SETTLE_MS: number = 420
const READER_ENHANCEMENT_INTERACTION_FALLBACK_MS: number = 2500
const READER_VERTICAL_TAP_MAX_DISTANCE: number = 8
const READER_TOUCH_TAP_SUPPRESS_MS: number = 350
const READER_LOADING_PROGRESS_ANIM_DURATION: number = 220
const READER_LOADING_INDETERMINATE_ANIM_DURATION: number = 900
const READER_LOADING_BAR_HEIGHT: number = 4
const READER_LOADING_BAR_WIDTH_PERCENT: string = '80%'
const READER_LOADING_BAR_MAX_WIDTH: number = 180
const READER_LOADING_SLIDER_WIDTH_RATIO: number = 0.3
const READER_LOADING_BAR_RADIUS: number = 2
const READER_LOADING_BAR_BG: ResourceColor = '#33FFFFFF'
const READER_LOADING_BAR_LIGHT_BG: ResourceColor = '#33000000'
const READER_LOADING_BAR_FG: ResourceColor = Color.White

/** DownloadQueueService exposes verified private pages as display-only file URIs. */
function readerLocalFilePath(uri: string): string {
  return uri.startsWith('file://') ? uri.substring('file://'.length) : uri
}

// Structural subset of Image.onComplete (NextE parity). Intrinsic bitmap size
// arrives in px and is converted to vp so contain-fit pan bounds stay in the
// same coordinate space as gestures.
/** NextE ReaderLoadingBar port: indeterminate sliding or determinate progress bar. */
@ComponentV2
struct ReaderLoadingBar {
  @Param determinate: boolean = false
  @Param ratio: number = 0
  @Param barFillColor: ResourceColor = READER_LOADING_BAR_FG
  @Param barTrackColor: ResourceColor = READER_LOADING_BAR_BG
  @Local indeterminatePosition: number = 0
  @Local trackWidth: number = 0

  private indeterminateStartTimer: number = -1
  private indeterminateTimer: number = -1

  aboutToAppear(): void {
    this.syncIndeterminateAnimation()
  }

  aboutToDisappear(): void {
    this.stopIndeterminateAnimation()
  }

  @Monitor('determinate')
  private onDeterminateChanged(): void {
    this.syncIndeterminateAnimation()
  }

  private syncIndeterminateAnimation(): void {
    if (this.determinate) {
      this.stopIndeterminateAnimation()
      this.indeterminatePosition = 0
      return
    }
    this.startIndeterminateAnimation()
  }

  private startIndeterminateAnimation(): void {
    if (this.trackWidth <= 0 || this.indeterminateStartTimer >= 0 || this.indeterminateTimer >= 0) {
      return
    }
    this.indeterminatePosition = 0
    this.indeterminateStartTimer = setTimeout((): void => {
      this.indeterminateStartTimer = -1
      if (this.determinate) {
        return
      }
      this.moveIndeterminateSlider()
      this.indeterminateTimer = setInterval((): void => {
        this.moveIndeterminateSlider()
      }, READER_LOADING_INDETERMINATE_ANIM_DURATION)
    }, 0)
  }

  private stopIndeterminateAnimation(): void {
    if (this.indeterminateStartTimer >= 0) {
      clearTimeout(this.indeterminateStartTimer)
      this.indeterminateStartTimer = -1
    }
    if (this.indeterminateTimer >= 0) {
      clearInterval(this.indeterminateTimer)
      this.indeterminateTimer = -1
    }
  }

  private moveIndeterminateSlider(): void {
    this.indeterminatePosition = this.indeterminatePosition > 0 ? 0 : 1
  }

  private barWidth(): number {
    return this.trackWidth > 0 ? this.trackWidth : READER_LOADING_BAR_MAX_WIDTH
  }

  private sliderWidth(): number {
    return this.barWidth() * READER_LOADING_SLIDER_WIDTH_RATIO
  }

  private clampedRatio(): number {
    return Math.min(1, Math.max(0, this.ratio))
  }

  private fillWidth(): number {
    return this.determinate ? this.barWidth() * this.clampedRatio() : this.sliderWidth()
  }

  private sliderX(): number {
    return this.determinate ? 0 : (this.barWidth() - this.sliderWidth()) * this.indeterminatePosition
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      if (this.determinate) {
        Row()
          .width(this.fillWidth())
          .height(READER_LOADING_BAR_HEIGHT)
          .backgroundColor(this.barFillColor)
          .borderRadius(READER_LOADING_BAR_RADIUS)
          .animation({ duration: READER_LOADING_PROGRESS_ANIM_DURATION, curve: Curve.EaseOut })
      } else {
        Row()
          .width(this.sliderWidth())
          .height(READER_LOADING_BAR_HEIGHT)
          .backgroundColor(this.barFillColor)
          .borderRadius(READER_LOADING_BAR_RADIUS)
          .translate({ x: this.sliderX() })
          .animation({
            duration: READER_LOADING_INDETERMINATE_ANIM_DURATION,
            curve: Curve.EaseInOut,
          })
      }
    }
    .width(READER_LOADING_BAR_WIDTH_PERCENT)
    .constraintSize({ maxWidth: READER_LOADING_BAR_MAX_WIDTH })
    .height(READER_LOADING_BAR_HEIGHT)
    .backgroundColor(this.barTrackColor)
    .borderRadius(READER_LOADING_BAR_RADIUS)
    .clip(true)
    .onAreaChange((_oldArea: Area, area: Area): void => {
      this.trackWidth = area.width as number
      this.syncIndeterminateAnimation()
    })
  }
}

/** NextE ReaderLoadingStage port: staged loading with progress-aware bar and label. */
@ComponentV2
struct ReaderLoadingStage {
  @Param label: ResourceStr = ''
  @Param loaded: number = 0
  @Param total: number = 0
  @Param contentColor: ResourceColor = READER_FOREGROUND_DARK_CANVAS
  @Param secondaryColor: ResourceColor = READER_SECONDARY_FOREGROUND_DARK_CANVAS
  @Param trackColor: ResourceColor = READER_LOADING_BAR_BG

  private hasProgress(): boolean {
    return this.total > 0
  }

  private progressRatio(): number {
    return this.hasProgress() ? Math.min(1, Math.max(0, this.loaded / this.total)) : 0
  }

  private progressPercent(): string {
    return `${Math.round(this.progressRatio() * 100)}%`
  }

  build() {
    Column({ space: ThemeTokens.SPACE_SM }) {
      ReaderLoadingBar({
        determinate: this.hasProgress(),
        ratio: this.progressRatio(),
        barFillColor: this.contentColor,
        barTrackColor: this.trackColor,
      })
      Text(this.label)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(this.contentColor)
        .textAlign(TextAlign.Center)
      Text(this.hasProgress() ? this.progressPercent() : '0%')
        .fontSize(ThemeTokens.FONT_SIZE_META)
        .fontColor(this.secondaryColor)
        .textAlign(TextAlign.Center)
        .opacity(this.hasProgress() ? 1 : 0)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(ThemeTokens.SPACE_XL)
  }
}

interface ReaderImageLoadEvent {
  loadingStatus: number
  width?: number
  height?: number
  componentWidth?: number
  componentHeight?: number
}
/** Matches the three durable sampling choices without changing a source URI. */
function readerImageInterpolation(quality: NhReaderImageScalingQuality): ImageInterpolation {
  if (quality === NhReaderImageScalingQuality.LOW) {
    return ImageInterpolation.Low
  }
  if (quality === NhReaderImageScalingQuality.HIGH) {
    return ImageInterpolation.High
  }
  return ImageInterpolation.Medium
}

function readerBackgroundIsDark(mode: NhReaderBackgroundMode, effectiveDark: boolean): boolean {
  if (mode === NhReaderBackgroundMode.WHITE) {
    return false
  }
  if (mode === NhReaderBackgroundMode.AUTO) {
    return effectiveDark
  }
  return true
}

function readerBackgroundColor(mode: NhReaderBackgroundMode, effectiveDark: boolean): ResourceColor {
  if (mode === NhReaderBackgroundMode.GRAY) {
    return READER_BACKGROUND_GRAY
  }
  if (mode === NhReaderBackgroundMode.WHITE ||
    (mode === NhReaderBackgroundMode.AUTO && !effectiveDark)) {
    return READER_BACKGROUND_WHITE
  }
  return READER_BACKGROUND_BLACK
}

function resolveReaderCanvasForegroundColor(canvasDark: boolean): ResourceColor {
  return canvasDark ? READER_FOREGROUND_DARK_CANVAS : READER_FOREGROUND_LIGHT_CANVAS
}

function resolveReaderCanvasSecondaryForegroundColor(canvasDark: boolean): ResourceColor {
  return canvasDark ? READER_SECONDARY_FOREGROUND_DARK_CANVAS : READER_SECONDARY_FOREGROUND_LIGHT_CANVAS
}

function resolveReaderCanvasControlTint(canvasDark: boolean): ResourceColor {
  return canvasDark ? READER_CONTROL_TINT_DARK_CANVAS : READER_CONTROL_TINT_LIGHT_CANVAS
}

/** Small NextE-derived zoom boundary for one rendered Reader page. */
/** Full NextE ReaderZoomCoordinator port: dynamic max scale, elastic pinch, anchored double-tap cycle. */
class ReaderPageZoom {
  static isZoomed(scale: number): boolean {
    return scale > READER_ZOOM_EPSILON
  }

  static clampScale(value: number, maxScale: number = MIN_DYNAMIC_MAX_SCALE): number {
    if (!Number.isFinite(value) || value <= 1) {
      return 1
    }
    return Math.min(ReaderPageZoom.saneEffectiveMaxScale(maxScale), value)
  }

  static clampPinchScale(value: number, maxScale: number = MIN_DYNAMIC_MAX_SCALE): number {
    if (!Number.isFinite(value)) {
      return 1
    }
    if (value >= 1) {
      return ReaderPageZoom.clampScale(value, maxScale)
    }
    const resisted: number = 1 - (1 - value) * PINCH_UNDER_SCALE_RESISTANCE
    return Math.max(PINCH_ELASTIC_MIN_SCALE, resisted)
  }

  static saneMaxScale(value: number): number {
    if (!Number.isFinite(value) || value < MIN_DYNAMIC_MAX_SCALE) {
      return MIN_DYNAMIC_MAX_SCALE
    }
    return Math.min(MAX_DYNAMIC_MAX_SCALE, value)
  }

  static saneEffectiveMaxScale(value: number): number {
    if (!Number.isFinite(value) || value < MIN_DYNAMIC_MAX_SCALE) {
      return MIN_DYNAMIC_MAX_SCALE
    }
    return Math.min(MAX_EFFECTIVE_MAX_SCALE, value)
  }

  static fitScale(
    viewportW: number,
    viewportH: number,
    intrinsicW: number,
    intrinsicH: number,
  ): number {
    if (viewportW <= 0 || viewportH <= 0 || intrinsicW <= 0 || intrinsicH <= 0) {
      return 1
    }
    const fit: number = Math.min(viewportW / intrinsicW, viewportH / intrinsicH)
    return fit > 0 ? fit : 1
  }

  static displaySize(viewport: number, intrinsic: number, scale: number): number {
    if (intrinsic <= 0 || scale <= 0) {
      return viewport
    }
    return intrinsic * scale
  }

  static nativeScale(intrinsicW: number, intrinsicH: number, displayW: number, displayH: number): number {
    if (intrinsicW <= 0 || intrinsicH <= 0 || displayW <= 0 || displayH <= 0) {
      return DOUBLE_TAP_FALLBACK_SCALE
    }
    const scale: number = Math.min(intrinsicW / displayW, intrinsicH / displayH)
    return scale > 0 && Number.isFinite(scale) ? scale : DOUBLE_TAP_FALLBACK_SCALE
  }

  static dynamicMaxScale(intrinsicW: number, intrinsicH: number, displayW: number, displayH: number): number {
    const native: number = ReaderPageZoom.nativeScale(intrinsicW, intrinsicH, displayW, displayH)
    return ReaderPageZoom.saneMaxScale(native * NATIVE_SCALE_HEADROOM)
  }

  static nearScale(first: number, second: number): boolean {
    return Math.abs(first - second) <= DOUBLE_TAP_SCALE_EPSILON
  }

  static nextDoubleTapScale(
    currentScale: number,
    maxScale: number,
    primaryScale: number,
    nativeScale: number,
    pinchAdjusted: boolean,
  ): number {
    if (pinchAdjusted && ReaderPageZoom.isZoomed(currentScale)) {
      return 1
    }
    const primary: number = ReaderPageZoom.clampScale(primaryScale, maxScale)
    const native: number = ReaderPageZoom.clampScale(nativeScale, maxScale)
    if (!ReaderPageZoom.isZoomed(currentScale)) {
      return primary
    }
    if (ReaderPageZoom.nearScale(currentScale, primary) && native > 1 + DOUBLE_TAP_SCALE_EPSILON) {
      return native
    }
    return 1
  }

  static doubleTapTarget(
    currentScale: number,
    maxScale: number,
    nativeScale: number,
    pinchAdjusted: boolean = false,
  ): number {
    return ReaderPageZoom.nextDoubleTapScale(
      currentScale,
      maxScale,
      DOUBLE_TAP_PRIMARY_SCALE,
      nativeScale,
      pinchAdjusted,
    )
  }

  static pinchAnchor(
    center: number,
    viewport: number,
    displaySize: number,
    scale: number,
    offset: number,
  ): number {
    const displayed: number = displaySize * scale
    if (displayed <= 0) {
      return 0.5
    }
    const displayStart: number = (viewport - displayed) / 2 + offset
    return (center - displayStart) / displayed
  }

  static anchoredOffset(
    center: number,
    viewport: number,
    displaySize: number,
    scale: number,
    anchor: number,
  ): number {
    const displayed: number = displaySize * scale
    const point: number = (viewport - displayed) / 2 + displayed * anchor
    return center - point
  }

  /**
   * A contained portrait/landscape image can paint less than its paged
   * viewport. Use that fitted extent instead of the outer box so pan bounds
   * follow the visible image rather than its letterbox.
   */
  static fittedExtent(
    viewportWidth: number,
    viewportHeight: number,
    sourceWidth: number,
    sourceHeight: number,
    horizontal: boolean,
  ): number {
    if (viewportWidth <= 0 || viewportHeight <= 0 || sourceWidth <= 0 || sourceHeight <= 0) {
      return horizontal ? Math.max(0, viewportWidth) : Math.max(0, viewportHeight)
    }
    const fitScale: number = Math.min(viewportWidth / sourceWidth, viewportHeight / sourceHeight)
    if (!Number.isFinite(fitScale) || fitScale <= 0) {
      return horizontal ? Math.max(0, viewportWidth) : Math.max(0, viewportHeight)
    }
    return horizontal ? sourceWidth * fitScale : sourceHeight * fitScale
  }

  static clampOffset(value: number, viewport: number, fittedExtent: number, scale: number): number {
    const maximum: number = Math.max(0, (fittedExtent * scale - viewport) / 2)
    return Math.min(maximum, Math.max(-maximum, value))
  }
}

/**
 * The only owner of source-page/spread conversion.  All presentation paths
 * keep source indexes canonical; the pager is free to reverse visual order
 * for RTL without leaking a display index into progress or cache operations.
 */
class ReaderSpreadResolver {
  static supports(mode: NhReaderMode): boolean {
    return mode === NhReaderMode.PAGED || mode === NhReaderMode.PAGED_RTL
  }

  static isDoublePage(mode: NhReaderMode, requested: boolean): boolean {
    return requested && ReaderSpreadResolver.supports(mode)
  }

  static startForSourceIndex(sourceIndex: number, pageCount: number): number {
    const normalized: number = Math.min(Math.max(0, Math.floor(sourceIndex)), Math.max(0, pageCount - 1))
    return normalized - (normalized % 2)
  }

  static secondForStart(startIndex: number, pageCount: number): number {
    const candidate: number = startIndex + 1
    return candidate >= 0 && candidate < pageCount ? candidate : -1
  }

  static containsSourceIndex(startIndex: number, sourceIndex: number, pageCount: number): boolean {
    return sourceIndex === startIndex || sourceIndex === ReaderSpreadResolver.secondForStart(startIndex, pageCount)
  }

  static navigationStep(doublePage: boolean): number {
    return doublePage ? 2 : 1
  }

  static normalizedNavigationIndex(sourceIndex: number, pageCount: number, doublePage: boolean): number {
    const normalized: number = Math.min(Math.max(0, Math.floor(sourceIndex)), Math.max(0, pageCount - 1))
    return doublePage ? ReaderSpreadResolver.startForSourceIndex(normalized, pageCount) : normalized
  }
}

/**
 * Keeps recovery local to the page that failed.  Image has completion and
 * error callbacks, but no public reload API; a user retry therefore changes
 * the source once, rather than starting an automatic retry loop.
 */
@ComponentV2
struct ReaderImagePage {
  @Require @Param imageUrl: string
  @Require @Param cacheKey: string
  @Param localImageUri: string = ''
  /** A completed private translation artifact replaces only this image leaf. */
  @Param renderedImageUri: string = ''
  @Param enhancementEnabled: boolean = false
  @Param enhancementModel: NhReaderSuperResolutionModel = NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X
  @Param enhancementMaxHeight: number = 2000
  @Param imageScalingQuality: NhReaderImageScalingQuality = NhReaderImageScalingQuality.MEDIUM
  @Param canvasColor: ResourceColor = READER_BACKGROUND_BLACK
  @Param canvasContentColor: ResourceColor = READER_FOREGROUND_DARK_CANVAS
  @Param canvasSecondaryContentColor: ResourceColor = READER_SECONDARY_FOREGROUND_DARK_CANVAS
  @Param controlTint: ResourceColor = READER_CONTROL_TINT_DARK_CANVAS
  @Param fillViewport: boolean = false
  @Param imageWidth: number = 0
  @Param imageHeight: number = 0
  @Param pageIndex: number = -1
  @Param doubleTapSequence: number = 0
  @Param doubleTapTargetIndex: number = -1
  @Param doubleTapX: number = 0
  @Param doubleTapY: number = 0
  @Event onZoomChange?: (zoomed: boolean) => void
  @Event onImageLoadStateChanged?: (pageIndex: number, loaded: boolean) => void
  @Event onSourceFileReady?: (pageIndex: number, localPath: string) => void
  @Event onEnhancementStateChanged?: (pageIndex: number, processing: boolean, applied: boolean) => void
  @Local hasLoadError: boolean = false
  @Local isRetrying: boolean = false
  @Local isLoading: boolean = true
  @Local imageSource: string = ''
  @Local zoomScale: number = 1
  @Local zoomOffsetX: number = 0
  @Local zoomOffsetY: number = 0
  @Local zoomAnimating: boolean = false
  @Local viewportWidth: number = 0
  @Local viewportHeight: number = 0
  /** Measured intrinsic size from the decoded image (NextE onImageDecoded parity). */
  @Local intrinsicWidth: number = 0
  @Local intrinsicHeight: number = 0
  private loadGeneration: number = 0
  private pinchStartScale: number = 1
  private pinchAnchorX: number = 0.5
  private pinchAnchorY: number = 0.5
  private panStartOffsetX: number = 0
  private panStartOffsetY: number = 0
  private isPinching: boolean = false
  private pinchAdjustedSinceDoubleTap: boolean = false
  private ignorePanSequence: boolean = false
  private zoomAnimationTimer: number = 0
  private lastZoomed: boolean = false

  aboutToAppear(): void {
    this.loadImage()
  }

  aboutToDisappear(): void {
    this.loadGeneration += 1
    ReaderSuperResolutionService.releaseOwner(this.enhancementOwnerKey())
    this.resetZoom()
    this.notifyZoom()
    if (this.zoomAnimationTimer > 0) {
      clearTimeout(this.zoomAnimationTimer)
      this.zoomAnimationTimer = 0
    }
  }

  @Monitor('imageUrl')
  onImageUrlChanged(): void {
    this.loadImage()
  }

  @Monitor('cacheKey')
  onCacheKeyChanged(): void {
    this.loadImage()
  }

  @Monitor('localImageUri')
  onLocalImageUriChanged(): void {
    this.loadImage()
  }

  @Monitor('renderedImageUri')
  onRenderedImageUriChanged(): void {
    this.loadImage()
  }

  @Monitor('enhancementEnabled')
  onEnhancementEnabledChanged(): void {
    this.loadImage()
  }

  @Monitor('enhancementModel')
  onEnhancementModelChanged(): void {
    this.loadImage()
  }

  @Monitor('enhancementMaxHeight')
  onEnhancementMaxHeightChanged(): void {
    this.loadImage()
  }

  // NextE dispatches double taps from the Reader surface rather than asking a
  // scrolling List/Swiper child to win the recognizer race. Only the visible
  // target page consumes the sequence command.
  @Monitor('doubleTapSequence')
  onDoubleTapCommand(): void {
    if (this.doubleTapSequence > 0 && this.pageIndex === this.doubleTapTargetIndex) {
      this.toggleDoubleTapZoom(this.doubleTapX, this.doubleTapY)
    }
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private isCurrentLoad(generation: number): boolean {
    return generation === this.loadGeneration
  }

  private notifyImageLoadState(loaded: boolean): void {
    if (this.onImageLoadStateChanged && this.pageIndex >= 0) {
      this.onImageLoadStateChanged(this.pageIndex, loaded)
    }
  }

  private notifySourceFileReady(localPath: string): void {
    if (this.onSourceFileReady && this.pageIndex >= 0 && localPath.length > 0) {
      this.onSourceFileReady(this.pageIndex, localPath)
    }
  }

  private notifyEnhancementState(processing: boolean, applied: boolean): void {
    if (this.onEnhancementStateChanged && this.pageIndex >= 0) {
      this.onEnhancementStateChanged(this.pageIndex, processing, applied)
    }
  }

  private enhancementOwnerKey(): string {
    return `reader-image:${this.cacheKey}:${this.pageIndex}`
  }

  private async applyEnhancement(generation: number, localPath: string): Promise<void> {
    if (!this.enhancementEnabled || localPath.length === 0) {
      return
    }
    this.notifyEnhancementState(true, false)
    try {
      const result = await ReaderSuperResolutionService.process(
        this.context(),
        localPath,
        this.enhancementOwnerKey(),
        true,
        this.enhancementModel,
        this.enhancementMaxHeight,
      )
      if (!this.isCurrentLoad(generation)) {
        return
      }
      this.notifyEnhancementState(false, result.applied)
      if (result.applied) {
        this.imageSource = result.displayUri
      }
    } catch (_error) {
      if (this.isCurrentLoad(generation)) {
        this.notifyEnhancementState(false, false)
      }
    }
  }

  private async loadImage(forceReload: boolean = false): Promise<void> {
    const generation: number = this.loadGeneration + 1
    this.loadGeneration = generation
    this.hasLoadError = false
    this.isRetrying = forceReload
    this.isLoading = true
    this.imageSource = ''
    ReaderSuperResolutionService.clearOwnerOutcome(this.enhancementOwnerKey())
    this.notifyEnhancementState(false, false)
    this.notifyImageLoadState(false)
    this.resetZoom()
    this.notifyZoom()
    if (this.renderedImageUri.length > 0) {
      this.imageSource = this.renderedImageUri
      this.isLoading = false
      this.isRetrying = false
      return
    }
    if (this.localImageUri.length > 0) {
      this.imageSource = this.localImageUri
      const localPath: string = readerLocalFilePath(this.localImageUri)
      this.notifySourceFileReady(localPath)
      this.applyEnhancement(generation, localPath).catch((): void => {})
      this.isLoading = false
      this.isRetrying = false
      return
    }
    try {
      const result: ReaderImageCacheResult = await ReaderImageCacheService.load(
        this.context(),
        this.imageUrl,
        this.cacheKey,
        forceReload,
      )
      if (!this.isCurrentLoad(generation)) {
        return
      }
      this.imageSource = result.displayUri
      this.notifySourceFileReady(result.localPath)
      this.applyEnhancement(generation, result.localPath).catch((): void => {})
    } catch (_error) {
      if (!this.isCurrentLoad(generation)) {
        return
      }
      this.hasLoadError = true
    } finally {
      if (this.isCurrentLoad(generation)) {
        this.isLoading = false
        this.isRetrying = false
      }
    }
  }

  private retry(): void {
    // A verified private page is retried locally. Remote cache invalidation
    // remains an explicit user action only when no saved page is available.
    this.loadImage(this.localImageUri.length === 0)
  }

  private clampZoomOffset(): void {
    this.zoomOffsetX = this.clampZoomOffsetX(this.zoomOffsetX)
    this.zoomOffsetY = this.clampZoomOffsetY(this.zoomOffsetY)
  }

  private clampZoomOffsetX(value: number): number {
    return ReaderPageZoom.clampOffset(
      value,
      this.viewportWidth,
      ReaderPageZoom.fittedExtent(
        this.viewportWidth,
        this.viewportHeight,
        this.effectiveImageWidth(),
        this.effectiveImageHeight(),
        true,
      ),
      this.zoomScale,
    )
  }

  private clampZoomOffsetY(value: number): number {
    return ReaderPageZoom.clampOffset(
      value,
      this.viewportHeight,
      ReaderPageZoom.fittedExtent(
        this.viewportWidth,
        this.viewportHeight,
        this.effectiveImageWidth(),
        this.effectiveImageHeight(),
        false,
      ),
      this.zoomScale,
    )
  }

  private resetZoom(): void {
    this.zoomScale = 1
    this.zoomOffsetX = 0
    this.zoomOffsetY = 0
  }

  /** Reserve the fitted aspect ratio while loading so vertical lazy lists do not collapse into dozens of spinners. */
  private imageAspectRatio(): number {
    const width: number = this.effectiveImageWidth()
    const height: number = this.effectiveImageHeight()
    if (width > 0 && height > 0) {
      return width / height
    }
    return 1
  }

  private effectiveImageWidth(): number {
    return this.intrinsicWidth > 0 ? this.intrinsicWidth : this.imageWidth
  }

  private effectiveImageHeight(): number {
    return this.intrinsicHeight > 0 ? this.intrinsicHeight : this.imageHeight
  }

  private notifyZoom(): void {
    const zoomed: boolean = ReaderPageZoom.isZoomed(this.zoomScale)
    if (zoomed !== this.lastZoomed) {
      this.lastZoomed = zoomed
      if (this.onZoomChange) {
        this.onZoomChange(zoomed)
      }
    }
  }

  private panDistance(): number {
    return ReaderPageZoom.isZoomed(this.zoomScale)
      ? 1
      : Math.max(this.viewportWidth, this.viewportHeight, 10000)
  }

  private fittedDisplayWidth(): number {
    return ReaderPageZoom.fittedExtent(
      this.viewportWidth,
      this.viewportHeight,
      this.effectiveImageWidth(),
      this.effectiveImageHeight(),
      true,
    )
  }

  private fittedDisplayHeight(): number {
    return ReaderPageZoom.fittedExtent(
      this.viewportWidth,
      this.viewportHeight,
      this.effectiveImageWidth(),
      this.effectiveImageHeight(),
      false,
    )
  }

  private maxScale(): number {
    return ReaderPageZoom.dynamicMaxScale(
      this.effectiveImageWidth(),
      this.effectiveImageHeight(),
      this.fittedDisplayWidth(),
      this.fittedDisplayHeight(),
    )
  }

  private beginZoomAnimation(): void {
    if (this.zoomAnimationTimer > 0) {
      clearTimeout(this.zoomAnimationTimer)
      this.zoomAnimationTimer = 0
    }
    this.zoomAnimating = true
    this.zoomAnimationTimer = setTimeout((): void => {
      this.zoomAnimating = false
      this.zoomAnimationTimer = 0
    }, READER_ZOOM_ANIMATION_MS)
  }

  private toggleDoubleTapZoom(tapX: number = 0, tapY: number = 0): void {
    this.beginZoomAnimation()
    const target: number = ReaderPageZoom.doubleTapTarget(
      this.zoomScale,
      this.maxScale(),
      ReaderPageZoom.nativeScale(
        this.effectiveImageWidth(),
        this.effectiveImageHeight(),
        this.fittedDisplayWidth(),
        this.fittedDisplayHeight(),
      ),
      this.pinchAdjustedSinceDoubleTap,
    )
    this.pinchAdjustedSinceDoubleTap = false
    if (target === 1) {
      this.resetZoom()
    } else {
      const anchorX: number = ReaderPageZoom.pinchAnchor(
        tapX, this.viewportWidth, this.fittedDisplayWidth(), this.zoomScale, this.zoomOffsetX)
      const anchorY: number = ReaderPageZoom.pinchAnchor(
        tapY, this.viewportHeight, this.fittedDisplayHeight(), this.zoomScale, this.zoomOffsetY)
      this.zoomScale = target
      this.zoomOffsetX = this.clampZoomOffsetX(
        ReaderPageZoom.anchoredOffset(tapX, this.viewportWidth, this.fittedDisplayWidth(), target, anchorX))
      this.zoomOffsetY = this.clampZoomOffsetY(
        ReaderPageZoom.anchoredOffset(tapY, this.viewportHeight, this.fittedDisplayHeight(), target, anchorY))
    }
    this.notifyZoom()
  }

  @Builder
  private ImageRecovery() {
    if (this.hasLoadError || this.isRetrying || this.isLoading) {
      Column({ space: ThemeTokens.SPACE_SM }) {
        if (this.isRetrying || this.isLoading) {
          ReaderLoadingStage({
            label: AppStrings.get(this.isRetrying
              ? 'reader_status_retrying_image'
              : 'reader_loading_image'),
            contentColor: this.canvasContentColor,
            secondaryColor: this.canvasSecondaryContentColor,
            trackColor: READER_LOADING_BAR_BG,
          })
        } else {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
            .fontSize(32)
            .fontColor([this.canvasContentColor])
            .opacity(0.84)
          Text(AppStrings.get('reader_error_image_unavailable'))
            .fontSize(ThemeTokens.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.canvasContentColor)
          Text(AppStrings.get('reader_retry_connection'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(this.canvasSecondaryContentColor)
            .opacity(0.76)
            .textAlign(TextAlign.Center)
          Button(AppStrings.get('reader_action_retry'))
            .type(ButtonType.Capsule)
            .height(ThemeTokens.MIN_TOUCH_TARGET)
            .backgroundColor(this.controlTint)
            .fontColor(this.canvasContentColor)
            .onClick((): void => {
              this.retry()
            })
        }
      }
      .width('100%')
      .padding(ThemeTokens.SPACE_LG)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private ImageContent() {
    if (this.imageSource.length > 0) {
      Image(this.imageSource)
        .width('100%')
        .height(this.fillViewport ? '100%' : 'auto')
        .objectFit(ImageFit.Contain)
        .interpolation(readerImageInterpolation(this.imageScalingQuality))
        .backgroundColor(this.canvasColor)
        .onComplete((event?: ReaderImageLoadEvent): void => {
          // NextE onImageDecoded parity: measure the real bitmap instead of
          // trusting API metadata, which downloaded/local galleries lack.
          const bitmapWidth: number | undefined = event ? event.width : undefined
          const bitmapHeight: number | undefined = event ? event.height : undefined
          if (bitmapWidth !== undefined && bitmapHeight !== undefined &&
            bitmapWidth > 0 && bitmapHeight > 0) {
            this.intrinsicWidth = this.getUIContext().px2vp(bitmapWidth)
            this.intrinsicHeight = this.getUIContext().px2vp(bitmapHeight)
            this.clampZoomOffset()
          }
          this.hasLoadError = false
          this.notifyImageLoadState(true)
        })
        .onError((): void => {
          this.hasLoadError = true
          this.imageSource = ''
          this.notifyImageLoadState(false)
        })
        .scale({ x: this.zoomScale, y: this.zoomScale })
        .translate({ x: this.zoomOffsetX, y: this.zoomOffsetY })
        .animation({
          duration: this.zoomAnimating ? READER_ZOOM_ANIMATION_MS : 0,
          curve: Curve.FastOutSlowIn,
        })
    }
    this.ImageRecovery()
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      this.ImageContent()
    }
    .width('100%')
    .height(this.fillViewport ? '100%' : 'auto')
    .aspectRatio(this.imageAspectRatio())
    .backgroundColor(this.canvasColor)
    .clip(true)
    .onAreaChange((_previous: Area, current: Area): void => {
      this.viewportWidth = current.width as number
      this.viewportHeight = current.height as number
      this.clampZoomOffset()
    })
    // Mirrors NextE: pinch/double-tap live on the image itself, and the
    // one-finger pan intentionally activates only after the page is zoomed.
    .gesture(
      GestureGroup(
        GestureMode.Parallel,
        PinchGesture({ fingers: 2 })
          .onActionStart((event?: GestureEvent): void => {
            this.isPinching = true
            this.ignorePanSequence = true
            this.zoomAnimating = false
            this.pinchStartScale = this.zoomScale
            if (event) {
              this.pinchAnchorX = ReaderPageZoom.pinchAnchor(
                event.pinchCenterX as number,
                this.viewportWidth,
                this.fittedDisplayWidth(),
                this.zoomScale,
                this.zoomOffsetX,
              )
              this.pinchAnchorY = ReaderPageZoom.pinchAnchor(
                event.pinchCenterY as number,
                this.viewportHeight,
                this.fittedDisplayHeight(),
                this.zoomScale,
                this.zoomOffsetY,
              )
            }
          })
          .onActionUpdate((event?: GestureEvent): void => {
            if (!event) {
              return
            }
            const nextScale: number = ReaderPageZoom.clampPinchScale(
              this.pinchStartScale * (event.scale as number),
              this.maxScale(),
            )
            this.pinchAdjustedSinceDoubleTap = true
            this.zoomScale = nextScale
            this.zoomOffsetX = this.clampZoomOffsetX(ReaderPageZoom.anchoredOffset(
              event.pinchCenterX as number,
              this.viewportWidth,
              this.fittedDisplayWidth(),
              nextScale,
              this.pinchAnchorX,
            ))
            this.zoomOffsetY = this.clampZoomOffsetY(ReaderPageZoom.anchoredOffset(
              event.pinchCenterY as number,
              this.viewportHeight,
              this.fittedDisplayHeight(),
              nextScale,
              this.pinchAnchorY,
            ))
          })
          .onActionEnd((): void => {
            this.isPinching = false
            if (!ReaderPageZoom.isZoomed(this.zoomScale)) {
              this.resetZoom()
            }
            this.clampZoomOffset()
            this.notifyZoom()
          })
          .onActionCancel((): void => {
            this.isPinching = false
            if (!ReaderPageZoom.isZoomed(this.zoomScale)) {
              this.resetZoom()
            }
            this.clampZoomOffset()
            this.notifyZoom()
          }),
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: this.panDistance() })
          .onActionStart((): void => {
            this.ignorePanSequence = this.isPinching
            this.panStartOffsetX = this.zoomOffsetX
            this.panStartOffsetY = this.zoomOffsetY
          })
          .onActionUpdate((event?: GestureEvent): void => {
            if (!event || this.ignorePanSequence || this.isPinching || !ReaderPageZoom.isZoomed(this.zoomScale)) {
              return
            }
            this.zoomOffsetX = this.clampZoomOffsetX(this.panStartOffsetX + (event.offsetX as number))
            this.zoomOffsetY = this.clampZoomOffsetY(this.panStartOffsetY + (event.offsetY as number))
          })
          .onActionEnd((): void => {
            this.ignorePanSequence = false
          }),
      ),
    )
  }
}

/** One paged child keeps its canonical source index even when rendered RTL. */
class ReaderPagedItem {
  readonly page: NhGalleryPage
  readonly sourceIndex: number

  constructor(page: NhGalleryPage, sourceIndex: number) {
    this.page = page
    this.sourceIndex = sourceIndex
  }
}

/**
 * Passive image/loading layer for a spread.  It keeps the existing private
 * cache and retry boundary, but deliberately owns no transform or gesture:
 * the containing ReaderSpreadSurface is the one zoom/pan surface for both
 * pages.
 */
@ComponentV2
struct ReaderSpreadImageLayer {
  @Require @Param imageUrl: string
  @Require @Param cacheKey: string
  @Param localImageUri: string = ''
  @Param renderedImageUri: string = ''
  @Param enhancementEnabled: boolean = false
  @Param enhancementModel: NhReaderSuperResolutionModel = NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X
  @Param enhancementMaxHeight: number = 2000
  @Param imageScalingQuality: NhReaderImageScalingQuality = NhReaderImageScalingQuality.MEDIUM
  @Param canvasColor: ResourceColor = READER_BACKGROUND_BLACK
  @Param canvasContentColor: ResourceColor = READER_FOREGROUND_DARK_CANVAS
  @Param controlTint: ResourceColor = READER_CONTROL_TINT_DARK_CANVAS
  @Param pageIndex: number = -1
  @Event onImageLoadStateChanged?: (pageIndex: number, loaded: boolean) => void
  @Event onSourceFileReady?: (pageIndex: number, localPath: string) => void
  @Event onEnhancementStateChanged?: (pageIndex: number, processing: boolean, applied: boolean) => void
  @Local hasLoadError: boolean = false
  @Local isRetrying: boolean = false
  @Local isLoading: boolean = true
  @Local imageSource: string = ''
  private loadGeneration: number = 0

  aboutToAppear(): void {
    this.loadImage()
  }

  aboutToDisappear(): void {
    this.loadGeneration += 1
    ReaderSuperResolutionService.releaseOwner(this.enhancementOwnerKey())
  }

  @Monitor('imageUrl')
  onImageUrlChanged(): void {
    this.loadImage()
  }

  @Monitor('cacheKey')
  onCacheKeyChanged(): void {
    this.loadImage()
  }

  @Monitor('localImageUri')
  onLocalImageUriChanged(): void {
    this.loadImage()
  }

  @Monitor('renderedImageUri')
  onRenderedImageUriChanged(): void {
    this.loadImage()
  }

  @Monitor('enhancementEnabled')
  onEnhancementEnabledChanged(): void {
    this.loadImage()
  }

  @Monitor('enhancementModel')
  onEnhancementModelChanged(): void {
    this.loadImage()
  }

  @Monitor('enhancementMaxHeight')
  onEnhancementMaxHeightChanged(): void {
    this.loadImage()
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private notifyImageLoadState(loaded: boolean): void {
    if (this.onImageLoadStateChanged && this.pageIndex >= 0) {
      this.onImageLoadStateChanged(this.pageIndex, loaded)
    }
  }

  private notifySourceFileReady(localPath: string): void {
    if (this.onSourceFileReady && this.pageIndex >= 0 && localPath.length > 0) {
      this.onSourceFileReady(this.pageIndex, localPath)
    }
  }

  private notifyEnhancementState(processing: boolean, applied: boolean): void {
    if (this.onEnhancementStateChanged && this.pageIndex >= 0) {
      this.onEnhancementStateChanged(this.pageIndex, processing, applied)
    }
  }

  private enhancementOwnerKey(): string {
    return `reader-spread:${this.cacheKey}:${this.pageIndex}`
  }

  private async applyEnhancement(generation: number, localPath: string): Promise<void> {
    if (!this.enhancementEnabled || localPath.length === 0) {
      return
    }
    this.notifyEnhancementState(true, false)
    try {
      const result = await ReaderSuperResolutionService.process(
        this.context(),
        localPath,
        this.enhancementOwnerKey(),
        true,
        this.enhancementModel,
        this.enhancementMaxHeight,
      )
      if (generation !== this.loadGeneration) {
        return
      }
      this.notifyEnhancementState(false, result.applied)
      if (result.applied) {
        this.imageSource = result.displayUri
      }
    } catch (_error) {
      if (generation === this.loadGeneration) {
        this.notifyEnhancementState(false, false)
      }
    }
  }

  private async loadImage(forceReload: boolean = false): Promise<void> {
    const generation: number = this.loadGeneration + 1
    this.loadGeneration = generation
    this.hasLoadError = false
    this.isRetrying = forceReload
    this.isLoading = true
    this.imageSource = ''
    ReaderSuperResolutionService.clearOwnerOutcome(this.enhancementOwnerKey())
    this.notifyEnhancementState(false, false)
    this.notifyImageLoadState(false)
    if (this.renderedImageUri.length > 0) {
      this.imageSource = this.renderedImageUri
      this.isLoading = false
      this.isRetrying = false
      return
    }
    if (this.localImageUri.length > 0) {
      this.imageSource = this.localImageUri
      const localPath: string = readerLocalFilePath(this.localImageUri)
      this.notifySourceFileReady(localPath)
      this.applyEnhancement(generation, localPath).catch((): void => {})
      this.isLoading = false
      this.isRetrying = false
      return
    }
    try {
      const result: ReaderImageCacheResult = await ReaderImageCacheService.load(
        this.context(),
        this.imageUrl,
        this.cacheKey,
        forceReload,
      )
      if (generation !== this.loadGeneration) {
        return
      }
      this.imageSource = result.displayUri
      this.notifySourceFileReady(result.localPath)
      this.applyEnhancement(generation, result.localPath).catch((): void => {})
    } catch (_error) {
      if (generation !== this.loadGeneration) {
        return
      }
      this.hasLoadError = true
    } finally {
      if (generation === this.loadGeneration) {
        this.isLoading = false
        this.isRetrying = false
      }
    }
  }

  @Builder
  private ImageRecovery() {
    if (this.hasLoadError || this.isRetrying || this.isLoading) {
      Column({ space: ThemeTokens.SPACE_SM }) {
        if (this.isRetrying || this.isLoading) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(this.canvasContentColor)
        } else {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
            .fontSize(28)
            .fontColor([this.canvasContentColor])
            .opacity(0.84)
          Text(AppStrings.get('reader_error_image_unavailable'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(this.canvasContentColor)
            .textAlign(TextAlign.Center)
          Button(AppStrings.get('reader_action_retry'))
            .type(ButtonType.Capsule)
            .height(ThemeTokens.MIN_TOUCH_TARGET)
            .backgroundColor(this.controlTint)
            .fontColor(this.canvasContentColor)
            .onClick((): void => {
              this.loadImage(this.localImageUri.length === 0)
            })
        }
      }
      .width('100%')
      .padding(ThemeTokens.SPACE_MD)
      .alignItems(HorizontalAlign.Center)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.imageSource.length > 0) {
        Image(this.imageSource)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .interpolation(readerImageInterpolation(this.imageScalingQuality))
          .backgroundColor(this.canvasColor)
          .onComplete((): void => {
            this.hasLoadError = false
            this.notifyImageLoadState(true)
          })
          .onError((): void => {
            this.hasLoadError = true
            this.imageSource = ''
            this.notifyImageLoadState(false)
          })
      }
      this.ImageRecovery()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.canvasColor)
    .clip(true)
  }
}

/**
 * A spread is a single gesture/transform owner. It deliberately composes two
 * passive layers under one scale and pan state so no half can consume a
 * pinch, retain a divergent transform, or leave the Swiper enabled while the
 * adjacent page is zoomed.
 */
@ComponentV2
struct ReaderSpreadSurface {
  @Require @Param first: ReaderPagedItem
  @Param second: ReaderPagedItem | null = null
  @Require @Param galleryId: number
  @Require @Param mediaId: string
  @Param firstLocalImageUri: string = ''
  @Param secondLocalImageUri: string = ''
  @Param firstRenderedImageUri: string = ''
  @Param secondRenderedImageUri: string = ''
  @Param enhancementEnabled: boolean = false
  @Param enhancementModel: NhReaderSuperResolutionModel = NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X
  @Param enhancementMaxHeight: number = 2000
  @Param imageScalingQuality: NhReaderImageScalingQuality = NhReaderImageScalingQuality.MEDIUM
  @Param canvasColor: ResourceColor = READER_BACKGROUND_BLACK
  @Param canvasContentColor: ResourceColor = READER_FOREGROUND_DARK_CANVAS
  @Param controlTint: ResourceColor = READER_CONTROL_TINT_DARK_CANVAS
  @Param spreadLayoutMode: NhReaderSpreadLayout = NhReaderSpreadLayout.JOINED
  @Param rowReversed: boolean = false
  @Param doubleTapSequence: number = 0
  @Param doubleTapTargetIndex: number = -1
  @Param doubleTapX: number = 0
  @Param doubleTapY: number = 0
  @Event onZoomChange?: (sourceIndex: number, zoomed: boolean) => void
  @Event onImageLoadStateChanged?: (pageIndex: number, loaded: boolean) => void
  @Event onSourceFileReady?: (pageIndex: number, localPath: string) => void
  @Event onEnhancementStateChanged?: (pageIndex: number, processing: boolean, applied: boolean) => void
  @Local zoomScale: number = 1
  @Local zoomOffsetX: number = 0
  @Local zoomOffsetY: number = 0
  @Local zoomAnimating: boolean = false
  @Local viewportWidth: number = 0
  @Local viewportHeight: number = 0
  private pinchStartScale: number = 1
  private pinchAnchorX: number = 0.5
  private pinchAnchorY: number = 0.5
  private panStartOffsetX: number = 0
  private panStartOffsetY: number = 0
  private isPinching: boolean = false
  private pinchAdjustedSinceDoubleTap: boolean = false
  private ignorePanSequence: boolean = false
  private zoomAnimationTimer: number = 0
  private lastZoomed: boolean = false

  aboutToDisappear(): void {
    this.resetZoom()
    this.notifyZoom()
    if (this.zoomAnimationTimer > 0) {
      clearTimeout(this.zoomAnimationTimer)
      this.zoomAnimationTimer = 0
    }
  }

  @Monitor('doubleTapSequence')
  onDoubleTapCommand(): void {
    if (this.doubleTapSequence > 0 && this.containsSourceIndex(this.doubleTapTargetIndex)) {
      this.toggleDoubleTapZoom(this.doubleTapX, this.doubleTapY)
    }
  }

  @Monitor('galleryId')
  onSpreadGalleryChanged(): void {
    this.resetZoomForSpreadChange()
  }

  @Monitor('first')
  onSpreadFirstChanged(): void {
    this.resetZoomForSpreadChange()
  }

  @Monitor('second')
  onSpreadSecondChanged(): void {
    this.resetZoomForSpreadChange()
  }

  /** A different frame invalidates the local pan extent; do not retain a stale transform. */
  @Monitor('spreadLayoutMode')
  onSpreadLayoutChanged(): void {
    this.resetZoomForSpreadChange()
  }

  private resetZoomForSpreadChange(): void {
    if (this.zoomAnimationTimer > 0) {
      clearTimeout(this.zoomAnimationTimer)
      this.zoomAnimationTimer = 0
    }
    this.zoomAnimating = false
    this.resetZoom()
    this.notifyZoom()
  }

  private containsSourceIndex(sourceIndex: number): boolean {
    return sourceIndex === this.first.sourceIndex ||
      (this.second !== null && sourceIndex === this.second.sourceIndex)
  }

  /** Page DTO dimensions are already loaded by the Reader for joined geometry. */
  private pageAspect(item: ReaderPagedItem): number {
    if (item.page.width > 0 && item.page.height > 0) {
      const ratio: number = item.page.width / item.page.height
      if (Number.isFinite(ratio) && ratio > 0) {
        return ratio
      }
    }
    return ThemeTokens.GALLERY_GRID_COVER_RATIO
  }

  private joinedAspect(): number {
    return this.pageAspect(this.first) + (this.second === null ? 0 : this.pageAspect(this.second))
  }

  private usesJoinedLayout(): boolean {
    // A terminal singleton keeps its established one-page fit and pan extent.
    return this.second === null || this.spreadLayoutMode === NhReaderSpreadLayout.JOINED
  }

  private joinedFrameHeight(): number {
    if (this.viewportWidth <= 0 || this.viewportHeight <= 0) {
      return 0
    }
    const aspect: number = this.joinedAspect()
    if (aspect <= 0) {
      return this.viewportHeight
    }
    return Math.min(this.viewportHeight, this.viewportWidth / aspect)
  }

  private spreadFrameHeight(): number {
    return this.usesJoinedLayout() ? this.joinedFrameHeight() : this.viewportHeight
  }

  private joinedFrameWidth(): number {
    return this.joinedFrameHeight() * this.joinedAspect()
  }

  private spreadFrameWidth(): number {
    return this.usesJoinedLayout() ? this.joinedFrameWidth() : this.viewportWidth
  }

  private paneWidthFor(item: ReaderPagedItem): number {
    if (this.usesJoinedLayout()) {
      return this.joinedFrameHeight() * this.pageAspect(item)
    }
    return this.second === null ? this.viewportWidth : this.viewportWidth / 2
  }

  /**
   * Split panes retain their equal layout slots, but pan bounds must follow
   * the contained images rather than the blank letterbox around them.
   */
  private splitContainedWidth(item: ReaderPagedItem): number {
    const paneWidth: number = this.viewportWidth / 2
    const paneHeight: number = this.viewportHeight
    const aspect: number = this.pageAspect(item)
    if (paneWidth <= 0 || paneHeight <= 0 || aspect <= 0) {
      return 0
    }
    return Math.min(paneWidth, paneHeight * aspect)
  }

  private splitContainedHeight(item: ReaderPagedItem): number {
    const paneWidth: number = this.viewportWidth / 2
    const paneHeight: number = this.viewportHeight
    const aspect: number = this.pageAspect(item)
    if (paneWidth <= 0 || paneHeight <= 0 || aspect <= 0) {
      return 0
    }
    return Math.min(paneHeight, paneWidth / aspect)
  }

  private fittedSpreadWidth(): number {
    if (this.usesJoinedLayout()) {
      return this.joinedFrameWidth()
    }
    const firstWidth: number = this.splitContainedWidth(this.first)
    const secondWidth: number = this.second === null ? 0 : this.splitContainedWidth(this.second)
    const total: number = firstWidth + secondWidth
    return total > 0 ? total : this.viewportWidth
  }

  private fittedSpreadHeight(): number {
    if (this.usesJoinedLayout()) {
      return this.joinedFrameHeight()
    }
    const firstHeight: number = this.splitContainedHeight(this.first)
    const secondHeight: number = this.second === null ? 0 : this.splitContainedHeight(this.second)
    const maximum: number = Math.max(firstHeight, secondHeight)
    return maximum > 0 ? maximum : this.viewportHeight
  }

  private clampZoomOffsetX(value: number): number {
    return ReaderPageZoom.clampOffset(value, this.viewportWidth, this.fittedSpreadWidth(), this.zoomScale)
  }

  private clampZoomOffsetY(value: number): number {
    return ReaderPageZoom.clampOffset(value, this.viewportHeight, this.fittedSpreadHeight(), this.zoomScale)
  }

  private clampZoomOffset(): void {
    this.zoomOffsetX = this.clampZoomOffsetX(this.zoomOffsetX)
    this.zoomOffsetY = this.clampZoomOffsetY(this.zoomOffsetY)
  }

  private resetZoom(): void {
    this.zoomScale = 1
    this.zoomOffsetX = 0
    this.zoomOffsetY = 0
  }

  private notifyZoom(): void {
    const zoomed: boolean = ReaderPageZoom.isZoomed(this.zoomScale)
    if (zoomed !== this.lastZoomed) {
      this.lastZoomed = zoomed
      if (this.onZoomChange) {
        this.onZoomChange(this.first.sourceIndex, zoomed)
      }
    }
  }

  private panDistance(): number {
    return ReaderPageZoom.isZoomed(this.zoomScale)
      ? 1
      : Math.max(this.viewportWidth, this.viewportHeight, 10000)
  }

  private maxScale(): number {
    const intrinsicW: number = this.fittedSpreadWidth()
    const intrinsicH: number = this.fittedSpreadHeight()
    return ReaderPageZoom.dynamicMaxScale(intrinsicW, intrinsicH, intrinsicW, intrinsicH)
  }

  private beginZoomAnimation(): void {
    if (this.zoomAnimationTimer > 0) {
      clearTimeout(this.zoomAnimationTimer)
      this.zoomAnimationTimer = 0
    }
    this.zoomAnimating = true
    this.zoomAnimationTimer = setTimeout((): void => {
      this.zoomAnimating = false
      this.zoomAnimationTimer = 0
    }, READER_ZOOM_ANIMATION_MS)
  }

  private toggleDoubleTapZoom(tapX: number = 0, tapY: number = 0): void {
    this.beginZoomAnimation()
    const fittedW: number = this.fittedSpreadWidth()
    const fittedH: number = this.fittedSpreadHeight()
    const target: number = ReaderPageZoom.doubleTapTarget(
      this.zoomScale,
      this.maxScale(),
      ReaderPageZoom.nativeScale(fittedW, fittedH, fittedW, fittedH),
      this.pinchAdjustedSinceDoubleTap,
    )
    this.pinchAdjustedSinceDoubleTap = false
    if (target === 1) {
      this.resetZoom()
    } else {
      const anchorX: number = ReaderPageZoom.pinchAnchor(tapX, this.viewportWidth, fittedW, this.zoomScale, this.zoomOffsetX)
      const anchorY: number = ReaderPageZoom.pinchAnchor(tapY, this.viewportHeight, fittedH, this.zoomScale, this.zoomOffsetY)
      this.zoomScale = target
      this.zoomOffsetX = this.clampZoomOffsetX(
        ReaderPageZoom.anchoredOffset(tapX, this.viewportWidth, fittedW, target, anchorX))
      this.zoomOffsetY = this.clampZoomOffsetY(
        ReaderPageZoom.anchoredOffset(tapY, this.viewportHeight, fittedH, target, anchorY))
    }
    this.notifyZoom()
  }

  @Builder
  private SpreadImage(item: ReaderPagedItem, localImageUri: string, renderedImageUri: string) {
    ReaderSpreadImageLayer({
      imageUrl: NhApiClient.imageUrl(this.mediaId, item.sourceIndex, item.page.extension),
      localImageUri,
      renderedImageUri,
      enhancementEnabled: this.enhancementEnabled,
      enhancementModel: this.enhancementModel,
      enhancementMaxHeight: this.enhancementMaxHeight,
      imageScalingQuality: this.imageScalingQuality,
      canvasColor: this.canvasColor,
      canvasContentColor: this.canvasContentColor,
      controlTint: this.controlTint,
      pageIndex: item.sourceIndex,
      cacheKey: ReaderImageCacheService.cacheKey(
        this.galleryId,
        this.mediaId,
        item.page.number,
        item.page.extension,
      ),
      onImageLoadStateChanged: (pageIndex: number, loaded: boolean): void => {
        if (this.onImageLoadStateChanged) {
          this.onImageLoadStateChanged(pageIndex, loaded)
        }
      },
      onSourceFileReady: (pageIndex: number, localPath: string): void => {
        if (this.onSourceFileReady) {
          this.onSourceFileReady(pageIndex, localPath)
        }
      },
      onEnhancementStateChanged: (pageIndex: number, processing: boolean, applied: boolean): void => {
        if (this.onEnhancementStateChanged) {
          this.onEnhancementStateChanged(pageIndex, processing, applied)
        }
      },
    })
  }

  @Builder
  private SpreadPane(item: ReaderPagedItem, localImageUri: string, renderedImageUri: string) {
    Column() {
      this.SpreadImage(item, localImageUri, renderedImageUri)
    }
    .width(this.paneWidthFor(item))
    .height(this.spreadFrameHeight())
  }

  @Builder
  private SpreadImages() {
    Row() {
      if (this.rowReversed && this.second !== null) {
        this.SpreadPane(this.second, this.secondLocalImageUri, this.secondRenderedImageUri)
      }
      this.SpreadPane(this.first, this.firstLocalImageUri, this.firstRenderedImageUri)
      if (!this.rowReversed && this.second !== null) {
        this.SpreadPane(this.second, this.secondLocalImageUri, this.secondRenderedImageUri)
      }
    }
    .width(this.spreadFrameWidth())
    .height(this.spreadFrameHeight())
    .scale({ x: this.zoomScale, y: this.zoomScale })
    .translate({ x: this.zoomOffsetX, y: this.zoomOffsetY })
    .animation({
      duration: this.zoomAnimating ? READER_ZOOM_ANIMATION_MS : 0,
      curve: Curve.FastOutSlowIn,
    })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      this.SpreadImages()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.canvasColor)
    .clip(true)
    .onAreaChange((_previous: Area, current: Area): void => {
      this.viewportWidth = current.width as number
      this.viewportHeight = current.height as number
      this.clampZoomOffset()
    })
    .gesture(
      GestureGroup(
        GestureMode.Parallel,
        PinchGesture({ fingers: 2 })
          .onActionStart((event?: GestureEvent): void => {
            this.isPinching = true
            this.ignorePanSequence = true
            this.zoomAnimating = false
            this.pinchStartScale = this.zoomScale
            if (event) {
              this.pinchAnchorX = ReaderPageZoom.pinchAnchor(
                event.pinchCenterX as number,
                this.viewportWidth,
                this.fittedSpreadWidth(),
                this.zoomScale,
                this.zoomOffsetX,
              )
              this.pinchAnchorY = ReaderPageZoom.pinchAnchor(
                event.pinchCenterY as number,
                this.viewportHeight,
                this.fittedSpreadHeight(),
                this.zoomScale,
                this.zoomOffsetY,
              )
            }
          })
          .onActionUpdate((event?: GestureEvent): void => {
            if (!event) {
              return
            }
            const nextScale: number = ReaderPageZoom.clampPinchScale(
              this.pinchStartScale * (event.scale as number),
              this.maxScale(),
            )
            this.pinchAdjustedSinceDoubleTap = true
            this.zoomScale = nextScale
            this.zoomOffsetX = this.clampZoomOffsetX(ReaderPageZoom.anchoredOffset(
              event.pinchCenterX as number,
              this.viewportWidth,
              this.fittedSpreadWidth(),
              nextScale,
              this.pinchAnchorX,
            ))
            this.zoomOffsetY = this.clampZoomOffsetY(ReaderPageZoom.anchoredOffset(
              event.pinchCenterY as number,
              this.viewportHeight,
              this.fittedSpreadHeight(),
              nextScale,
              this.pinchAnchorY,
            ))
          })
          .onActionEnd((): void => {
            this.isPinching = false
            if (!ReaderPageZoom.isZoomed(this.zoomScale)) {
              this.resetZoom()
            }
            this.clampZoomOffset()
            this.notifyZoom()
          })
          .onActionCancel((): void => {
            this.isPinching = false
            if (!ReaderPageZoom.isZoomed(this.zoomScale)) {
              this.resetZoom()
            }
            this.clampZoomOffset()
            this.notifyZoom()
          }),
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: this.panDistance() })
          .onActionStart((): void => {
            this.ignorePanSequence = this.isPinching
            this.panStartOffsetX = this.zoomOffsetX
            this.panStartOffsetY = this.zoomOffsetY
          })
          .onActionUpdate((event?: GestureEvent): void => {
            if (!event || this.ignorePanSequence || this.isPinching || !ReaderPageZoom.isZoomed(this.zoomScale)) {
              return
            }
            this.zoomOffsetX = this.clampZoomOffsetX(this.panStartOffsetX + (event.offsetX as number))
            this.zoomOffsetY = this.clampZoomOffsetY(this.panStartOffsetY + (event.offsetY as number))
          })
          .onActionEnd((): void => {
            this.ignorePanSequence = false
          }),
      ),
    )
  }
}

/** Virtualized source shared by all page-rendering Reader flows. */
class ReaderPageDataSource implements IDataSource {
  private items: ReaderPagedItem[] = []
  private listeners: DataChangeListener[] = []

  setData(pages: NhGalleryPage[], reverse: boolean): void {
    this.items = pages.map((page: NhGalleryPage, sourceIndex: number): ReaderPagedItem => {
      return new ReaderPagedItem(page, sourceIndex)
    })
    if (reverse) {
      this.items.reverse()
    }
    this.listeners.forEach((listener: DataChangeListener): void => {
      listener.onDatasetChange([{ type: DataOperationType.RELOAD }])
    })
  }

  totalCount(): number {
    return this.items.length
  }

  getData(index: number): ReaderPagedItem {
    return this.items[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }
}

/**
 * One visual destination in double-page mode. Its `sourceIndex` is always
 * the canonical leading source page of `[0,1]`, `[2,3]`, and so on; a final
 * odd page deliberately stays as a singleton spread.
 */
class ReaderSpreadItem {
  readonly first: ReaderPagedItem
  readonly second: ReaderPagedItem | null
  readonly sourceIndex: number

  constructor(first: ReaderPagedItem, second: ReaderPagedItem | null) {
    this.first = first
    this.second = second
    this.sourceIndex = first.sourceIndex
  }

  containsSourceIndex(sourceIndex: number): boolean {
    return sourceIndex === this.first.sourceIndex ||
      (this.second !== null && sourceIndex === this.second.sourceIndex)
  }
}

/**
 * Keeps visual RTL reversal at the spread level while every dependent path
 * resolves back to ReaderSpreadItem.sourceIndex before touching progress,
 * cache, thumbnails, or page requests.
 */
class ReaderSpreadDataSource implements IDataSource {
  private items: ReaderSpreadItem[] = []
  private listeners: DataChangeListener[] = []

  setData(pages: NhGalleryPage[], reverse: boolean): void {
    const canonical: ReaderSpreadItem[] = []
    for (let sourceIndex: number = 0; sourceIndex < pages.length; sourceIndex += 2) {
      const first: ReaderPagedItem = new ReaderPagedItem(pages[sourceIndex], sourceIndex)
      const secondIndex: number = sourceIndex + 1
      const second: ReaderPagedItem | null = secondIndex < pages.length
        ? new ReaderPagedItem(pages[secondIndex], secondIndex)
        : null
      canonical.push(new ReaderSpreadItem(first, second))
    }
    this.items = reverse ? canonical.reverse() : canonical
    this.listeners.forEach((listener: DataChangeListener): void => {
      listener.onDatasetChange([{ type: DataOperationType.RELOAD }])
    })
  }

  totalCount(): number {
    return this.items.length
  }

  getData(index: number): ReaderSpreadItem {
    return this.items[index]
  }

  displayIndexForSourceIndex(sourceIndex: number): number {
    for (let displayIndex: number = 0; displayIndex < this.items.length; displayIndex += 1) {
      if (this.items[displayIndex].containsSourceIndex(sourceIndex)) {
        return displayIndex
      }
    }
    return 0
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }
}

/** One canonical source page, retained even while the paged Reader is RTL. */
class ReaderThumbnailItem {
  readonly page: NhGalleryPage
  readonly sourceIndex: number

  constructor(page: NhGalleryPage, sourceIndex: number) {
    this.page = page
    this.sourceIndex = sourceIndex
  }
}

/**
 * The strip is a navigation control rather than a second page source. Keeping
 * canonical source indexes here means a thumbnail always enters the existing
 * vertical/paged/RTL turn path instead of creating an alternate Reader state.
 */
class ReaderThumbnailDataSource implements IDataSource {
  private items: ReaderThumbnailItem[] = []
  private listeners: DataChangeListener[] = []

  setData(pages: NhGalleryPage[]): void {
    this.items = pages.map((page: NhGalleryPage, sourceIndex: number): ReaderThumbnailItem => {
      return new ReaderThumbnailItem(page, sourceIndex)
    })
    this.listeners.forEach((listener: DataChangeListener): void => {
      listener.onDatasetChange([{ type: DataOperationType.RELOAD }])
    })
  }

  totalCount(): number {
    return this.items.length
  }

  getData(index: number): ReaderThumbnailItem {
    return this.items[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }
}

/** One page's actual enhancement result, retained only while Reader stays mounted. */
class ReaderEnhancementPageState {
  pageIndex: number = -1
  processing: boolean = false
  applied: boolean = false
  reason: string = 'queued'
}

/** NextE's compact over-image status leaf. It never reserves Reader canvas space. */
@ComponentV2
struct ReaderEnhancementStatusIcon {
  @Param processing: boolean = false
  @Param applied: boolean = false

  private label(): string {
    if (this.processing) {
      return AppStrings.get('reader_enhancement_processing')
    }
    return this.applied
      ? AppStrings.get('reader_enhancement_applied')
      : AppStrings.get('reader_enhancement_not_applied')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.processing) {
        LoadingProgress()
          .width(ThemeTokens.FONT_SIZE_CAPTION)
          .height(ThemeTokens.FONT_SIZE_CAPTION)
          .color(ThemeTokens.TEXT_ON_BRAND)
          .opacity(READER_ENHANCEMENT_STATUS_OPACITY)
      } else {
        SymbolGlyph($r('sys.symbol.AI_hd_rectangle'))
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor([this.applied ? ThemeTokens.BRAND : ThemeTokens.TEXT_ON_BRAND])
          .opacity(READER_ENHANCEMENT_STATUS_OPACITY)
      }
    }
    .width(READER_ENHANCEMENT_STATUS_SIZE)
    .height(READER_ENHANCEMENT_STATUS_SIZE)
    .borderRadius(READER_ENHANCEMENT_STATUS_SIZE / 2)
    .backgroundColor(READER_ENHANCEMENT_STATUS_BACKGROUND)
    .accessibilityText(this.label())
  }
}

/** Readable page range that overlays the image without taking Reader tap ownership. */
@ComponentV2
struct ReaderPageNumberStatus {
  @Require @Param value: string
  private controller: TextController = new TextController()

  @Monitor('value')
  onValueChanged(): void {
    this.updateStyledText()
  }

  private styledText(): MutableStyledString {
    const styled: MutableStyledString = new MutableStyledString(this.value, [])
    styled.setStyle({
      start: 0,
      length: this.value.length,
      styledKey: StyledStringKey.FONT,
      styledValue: new TextStyle({
        fontColor: READER_PAGE_NUMBER_TEXT,
        fontSize: LengthMetrics.vp(ThemeTokens.FONT_SIZE_BODY),
        fontWeight: FontWeight.Medium,
        strokeWidth: LengthMetrics.vp(-READER_PAGE_NUMBER_STROKE_WIDTH),
        strokeColor: READER_PAGE_NUMBER_OUTLINE,
      }),
    })
    return styled
  }

  private updateStyledText(): void {
    this.controller.setStyledString(this.styledText())
  }

  build() {
    Text(undefined, { controller: this.controller })
      .textAlign(TextAlign.Center)
      .maxLines(1)
      .onAppear((): void => {
        this.updateStyledText()
      })
  }
}

/** Native Reader with ErosN-derived vertical and page-at-a-time modes. */
@ComponentV2
export struct ReaderPage {
  @Require @Param galleryId: number
  /** Entry injects the shared Reader settings surface without crossing feature HAR boundaries. */
  @BuilderParam settingsSheetContent: (dismiss: () => void) => void
  /** A non-negative route index is an explicit user page choice and wins over local resume. */
  @Param initialPageIndex: number = -1
  /** Assigned by the overlay route; direct/offline Reader intents keep zero. */
  @Param readerRouteEpoch: number = 0
  @Local detail: NhGalleryDetail = new NhGalleryDetail()
  @Local isLoading: boolean = true
  @Local errorMessage: string = ''
  @Local resumeIndex: number = 0
  @Local visiblePageIndex: number = 0
  @Local isReaderReadyForCurrentGallery: boolean = false
  // NextE opens the canvas clean; a single tap restores the native Reader chrome.
  @Local readerChromeVisible: boolean = false
  @Local readerModeMenuShown: boolean = false
  @Local readerOverflowMenuShown: boolean = false
  @Local readerSettingsSheetShown: boolean = false
  // A slider drag previews a one-based source-page number. It must not move
  // the Reader or write history until the Slider's End event commits it.
  @Local readerSliderValue: number = 1
  @Local readerSliderPreview: number = -1
  @Local autoReadActive: boolean = false
  @Local showThumbnailStrip: boolean = false
  /** Shows the tap-zone layout overlay after a settings change (NextE parity). */
  @Local tapZonePreviewVisible: boolean = false
  @Local zoomedPageIndex: number = -1
  @Local doubleTapSequence: number = 0
  @Local doubleTapTargetIndex: number = -1
  @Local readerViewportWidth: number = 0
  @Local readerViewportHeight: number = 0
  @Event onBack?: () => void
  @Event onReaderPresentationChanged?: (chromeVisible: boolean, fullscreen: boolean, canvasDark: boolean) => void
  @Local readerPresentation: ReaderPresentationState = connectReaderPresentation()
  @Local themeDisplay: ThemeDisplayState = connectThemeDisplay()
  // A primitive render projection keeps nested AppStorage changes observable
  // for the canvas and its lazy page children.
  @Local readerEnhancementEnabled: boolean = false
  @Local readerEnhancementStates: ReaderEnhancementPageState[] = []
  // Private local source/rendered paths are retained only for this mounted Reader route.
  @Local readerSourcePageIndexes: number[] = []
  @Local readerSourcePagePaths: string[] = []
  @Local readerTranslatedPageIndexes: number[] = []
  @Local readerTranslatedPageUris: string[] = []
  /** Runtime identity beside every mounted rendered URI; private artifacts stay in their cache. */
  @Local readerTranslatedPageRuntimeKeys: string[] = []
  @Local readerTranslationHiddenPages: number[] = []
  @Local readerTranslationRunning: boolean = false
  @Local readerTranslationPageIndex: number = -1
  /** The active request is hidden as soon as its language/source snapshot is no longer current. */
  @Local readerTranslationRunRuntimeKey: string = ''
  @Local readerTranslationErrorCode: string = ''
  /** Explicit, route-scoped opt-in; it never becomes a persistent Reader setting. */
  @Local readerTranslationAutoEnabled: boolean = false
  /** Comic visual route snapshot loaded at Reader start (NextE settingsRevision parity). */
  @Local comicVisualRoute: string = COMIC_VISUAL_ROUTE_LOCAL
  /** Torii route identity resolved from the persisted key/model/font at Reader start. */
  @Local toriiRuntimeProfileId: string = ''
  @Local toriiRuntimeModelId: string = ''
  private readerTapStartX: number = 0
  private readerTapStartY: number = 0
  private readerTapSuppressUntilMs: number = 0
  @Local language: LanguageState = connectLanguageState()
  @Local llmSources: LlmSourceProfilesState = connectLlmSourceProfiles()
  @Local mangaRenderingService: MangaRenderingServiceState = connectMangaRenderingService()
  private layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  private readerOverlay: ReaderOverlayNavigationState = connectReaderOverlayNavigation()
  private lastPersistedIndex: number = -1
  private requestGeneration: number = 0
  /** Prevent an async settings restore from publishing window policy after this route leaves. */
  private readerLifecycleGeneration: number = 0
  private windowPolicyGeneration: number = 0
  private verticalReaderScroller: Scroller = new Scroller()
  private pagedReaderController: SwiperController = new SwiperController()
  private thumbnailScroller: Scroller = new Scroller()
  private autoReadTimerId: number = -1
  private autoReadWaitingIndex: number = -1
  private loadedImageIndexes: number[] = []
  private volumeDownConsumer: ((event: InputConsumerKeyEvent) => void) | null = null
  private volumeUpConsumer: ((event: InputConsumerKeyEvent) => void) | null = null
  private pageDataSource: ReaderPageDataSource = new ReaderPageDataSource()
  private spreadDataSource: ReaderSpreadDataSource = new ReaderSpreadDataSource()
  private thumbnailDataSource: ReaderThumbnailDataSource = new ReaderThumbnailDataSource()
  private readerTapViewportWidth: number = 0
  private readerTapViewportHeight: number = 0
  private readerPresentationReady: boolean = false
  private readerDoubleTapX: number = 0
  private readerDoubleTapY: number = 0
  private readerTranslationEpoch: number = 0
  private readerTranslationAutoScheduleToken: number = 0
  private readerTranslationAutoFailedPageIndexes: number[] = []
  private readerTranslationAutoFailedRuntimeKeys: string[] = []
  private readerEnhancementInteractionTimer: number = -1
  private readerEnhancementInteractionActive: boolean = false

  aboutToAppear(): void {
    const generation: number = this.readerLifecycleGeneration + 1
    this.readerLifecycleGeneration = generation
    this.readerPresentationReady = false
    this.loadReaderSettings(generation)
  }

  aboutToDisappear(): void {
    this.readerLifecycleGeneration += 1
    this.readerPresentationReady = false
    this.resetReaderEnhancementInteractionPause()
    this.resetReaderTranslationAutoSession()
    this.stopAutoRead()
    this.unregisterVolumeKeyConsumer()
    this.invalidateReaderRequest()
    this.restoreWindowPolicy()
  }

  @Monitor('galleryId')
  onGalleryChanged(): void {
    this.loadReader()
  }

  @Monitor('initialPageIndex')
  onInitialPageChanged(): void {
    this.loadReader()
  }

  /** A sheet edit updates this already-mounted Reader without replacing its route or page. */
  @Monitor('readerPresentation.mode')
  onReaderModePresentationChanged(): void {
    if (this.readerPresentationReady) {
      this.applyReaderMode(this.readerPresentation.mode)
    }
  }

  @Monitor('readerPresentation.keepScreenOn')
  onReaderKeepScreenOnPresentationChanged(): void {
    if (this.readerPresentationReady) {
      this.applyWindowPolicy()
    }
  }

  @Monitor('readerPresentation.preloadPages')
  onReaderPreloadPresentationChanged(): void {
    if (this.readerPresentationReady) {
      this.scheduleReaderPreload(this.visiblePageIndex)
    }
  }

  @Monitor('readerPresentation.fullscreen')
  onReaderFullscreenPresentationChanged(): void {
    if (this.readerPresentationReady) {
      this.notifyReaderPresentation()
    }
  }

  @Monitor('readerPresentation.backgroundMode')
  onReaderBackgroundModePresentationChanged(): void {
    if (this.readerPresentationReady) {
      this.notifyReaderPresentation()
    }
  }

  @Monitor('themeDisplay.effectiveDark')
  onReaderBackgroundThemeChanged(): void {
    if (this.readerPresentationReady) {
      this.notifyReaderPresentation()
    }
  }

  @Monitor('readerPresentation.autoPageSeconds')
  onReaderAutoPagePresentationChanged(): void {
    if (this.readerPresentationReady && this.autoReadActive) {
      this.awaitAutoReadForVisiblePage()
    }
  }

  @Monitor('readerPresentation.volumeKeyTurn')
  onReaderVolumeKeyPresentationChanged(): void {
    if (this.readerPresentationReady) {
      this.syncVolumeKeyConsumer()
    }
  }

  /** The requested setting stays stored even while a narrow canvas falls back to one page. */
  @Monitor('readerPresentation.doublePageEnabled')
  onReaderDoublePagePresentationChanged(): void {
    if (this.readerPresentationReady) {
      this.applyReaderSpreadPresentation()
    }
  }

  @Monitor('readerPresentation.superResolutionEnabled')
  onReaderEnhancementPresentationChanged(): void {
    this.readerEnhancementEnabled = this.readerPresentation.superResolutionEnabled
    if (!this.readerEnhancementEnabled) {
      this.resetReaderEnhancementInteractionPause()
      this.readerEnhancementStates = []
    }
  }

  /** A source/language change hides stale results; auto mode then schedules only the new identity. */
  @Monitor(
    'language.effectiveLocale',
    'llmSources.mangaBinding',
    'llmSources.profiles',
    'mangaRenderingService.selectionEpoch',
  )
  onReaderTranslationRuntimeChanged(): void {
    if (this.readerTranslationAutoEnabled) {
      this.scheduleReaderTranslationAuto()
    }
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private isCurrentRequest(generation: number): boolean {
    return generation === this.requestGeneration
  }

  private invalidateReaderRequest(): void {
    this.requestGeneration += 1
    this.isReaderReadyForCurrentGallery = false
    this.zoomedPageIndex = -1
    this.doubleTapTargetIndex = -1
    this.showThumbnailStrip = false
  }

  private clampPageIndex(pageIndex: number, pageCount: number): number {
    return Math.min(Math.max(0, Math.floor(pageIndex)), Math.max(0, pageCount - 1))
  }

  /** Effective spread mode mirrors NextE: horizontal paged mode plus the persisted switch. */
  private isDoublePageActive(): boolean {
    return ReaderSpreadResolver.isDoublePage(
      this.readerPresentation.mode,
      this.readerPresentation.doublePageEnabled,
    )
  }

  private readerNavigationIndex(sourceIndex: number): number {
    return ReaderSpreadResolver.normalizedNavigationIndex(
      sourceIndex,
      this.detail.pages.length,
      this.isDoublePageActive(),
    )
  }

  private readerNavigationStep(): number {
    return ReaderSpreadResolver.navigationStep(this.isDoublePageActive())
  }

  private readerProgressStep(): number {
    return this.isDoublePageActive() && this.detail.pages.length > 2 ? 2 : 1
  }

  private readerSpreadSecondIndex(startIndex: number): number {
    if (!this.isDoublePageActive()) {
      return -1
    }
    return ReaderSpreadResolver.secondForStart(startIndex, this.detail.pages.length)
  }

  private isSourceIndexInCurrentSpread(sourceIndex: number): boolean {
    const currentStart: number = this.readerNavigationIndex(this.visiblePageIndex)
    if (!this.isDoublePageActive()) {
      return sourceIndex === currentStart
    }
    return ReaderSpreadResolver.containsSourceIndex(currentStart, sourceIndex, this.detail.pages.length)
  }

  /**
   * ReaderPage owns all source/display data sources together.  This prevents
   * a viewport or settings change from leaving a pager in spread display
   * order while slider/progress still interpret single-page display indexes.
   */
  private rebuildReaderPageDataSources(sourceIndex: number): void {
    const currentIndex: number = this.readerNavigationIndex(sourceIndex)
    this.pageDataSource.setData(this.detail.pages, this.isRightToLeftPagedMode())
    this.spreadDataSource.setData(this.detail.pages, this.isRightToLeftPagedMode())
    this.resumeIndex = currentIndex
    this.visiblePageIndex = currentIndex
    this.readerSliderPreview = -1
    this.readerSliderValue = currentIndex + 1
  }

  /** Keep an active auto-read session coherent across a spread topology change. */
  private applyReaderSpreadPresentation(): void {
    const wasAutoReadActive: boolean = this.autoReadActive
    const previousIndex: number = this.clampPageIndex(this.visiblePageIndex, this.detail.pages.length)
    const currentIndex: number = this.readerNavigationIndex(this.visiblePageIndex)
    this.clearAutoReadTimer()
    this.clearZoomForNavigation()
    this.rebuildReaderPageDataSources(currentIndex)
    this.scrollThumbnailStripTo(this.visiblePageIndex, false)
    this.scheduleReaderPreload(this.visiblePageIndex)
    if (currentIndex !== previousIndex) {
      this.persistProgress(currentIndex)
    }
    if (wasAutoReadActive) {
      this.awaitAutoReadForVisiblePage()
    }
  }

  /** The canvas geometry feeds joined-frame fitting; spread mode itself only follows mode + switch. */
  private onReaderViewportChanged(width: number, height: number): void {
    this.readerViewportWidth = Math.max(0, width)
    this.readerViewportHeight = Math.max(0, height)
  }

  private async loadReaderSettings(generation: number): Promise<void> {
    try {
      await ReaderPresentationService.restore(this.context())
    } catch (_error) {
      // The shared state deliberately retains its local defaults if durable
      // restoration is temporarily unavailable; Reader remains usable.
    }
    if (generation !== this.readerLifecycleGeneration) {
      return
    }
    this.readerEnhancementEnabled = this.readerPresentation.superResolutionEnabled
    this.readerPresentationReady = true
    this.syncVolumeKeyConsumer()
    this.notifyReaderPresentation()
    this.applyWindowPolicy()
    this.loadReader()
  }

  private notifyReaderPresentation(): void {
    if (this.onReaderPresentationChanged) {
      this.onReaderPresentationChanged(
        this.readerChromeVisible,
        this.readerPresentation.fullscreen,
        this.readerCanvasIsDark(),
      )
    }
  }

  private readerCanvasIsDark(): boolean {
    return readerBackgroundIsDark(this.readerPresentation.backgroundMode, this.themeDisplay.effectiveDark)
  }

  private readerCanvasColor(): ResourceColor {
    return readerBackgroundColor(this.readerPresentation.backgroundMode, this.themeDisplay.effectiveDark)
  }

  private readerCanvasForegroundColor(): ResourceColor {
    return resolveReaderCanvasForegroundColor(this.readerCanvasIsDark())
  }

  private readerCanvasSecondaryForegroundColor(): ResourceColor {
    return resolveReaderCanvasSecondaryForegroundColor(this.readerCanvasIsDark())
  }

  private readerCanvasControlTint(): ResourceColor {
    return resolveReaderCanvasControlTint(this.readerCanvasIsDark())
  }

  /**
   * HarmonyOS requires keep-screen-on to be scoped to an interactive
   * foreground scenario. The generation check prevents a delayed enable from
   * running after the reader route has already been dismissed.
   */
  private applyWindowPolicy(): void {
    const generation: number = this.windowPolicyGeneration + 1
    this.windowPolicyGeneration = generation
    this.setWindowKeepScreenOn(this.readerPresentation.keepScreenOn, generation)
  }

  private restoreWindowPolicy(): void {
    const generation: number = this.windowPolicyGeneration + 1
    this.windowPolicyGeneration = generation
    this.setWindowKeepScreenOn(false, generation)
  }

  /**
   * The native enhancer already supports cooperative pausing. Keep it behind
   * the Reader owner so a foreground drag, pinch, or settings interaction
   * never competes with image conversion.
   */
  private pauseReaderEnhancementForForegroundInteraction(): void {
    if (!this.readerEnhancementEnabled) {
      return
    }
    if (!this.readerEnhancementInteractionActive) {
      this.readerEnhancementInteractionActive = true
      ReaderSuperResolutionService.setInteractionPaused(true)
    }
    if (this.readerEnhancementInteractionTimer >= 0) {
      clearTimeout(this.readerEnhancementInteractionTimer)
    }
    this.readerEnhancementInteractionTimer = setTimeout((): void => {
      this.resumeReaderEnhancementAfterForegroundInteraction()
    }, READER_ENHANCEMENT_INTERACTION_FALLBACK_MS)
  }

  private scheduleReaderEnhancementInteractionResume(delayMs: number): void {
    if (!this.readerEnhancementInteractionActive) {
      return
    }
    if (this.readerEnhancementInteractionTimer >= 0) {
      clearTimeout(this.readerEnhancementInteractionTimer)
    }
    this.readerEnhancementInteractionTimer = setTimeout((): void => {
      this.resumeReaderEnhancementAfterForegroundInteraction()
    }, delayMs)
  }

  private resumeReaderEnhancementAfterForegroundInteraction(): void {
    if (this.readerEnhancementInteractionTimer >= 0) {
      clearTimeout(this.readerEnhancementInteractionTimer)
      this.readerEnhancementInteractionTimer = -1
    }
    if (!this.readerEnhancementInteractionActive) {
      return
    }
    this.readerEnhancementInteractionActive = false
    if (!this.readerSettingsSheetShown && this.isReaderReadyForCurrentGallery &&
      this.readerEnhancementEnabled) {
      ReaderSuperResolutionService.setInteractionPaused(false)
    }
  }

  private resetReaderEnhancementInteractionPause(): void {
    if (this.readerEnhancementInteractionTimer >= 0) {
      clearTimeout(this.readerEnhancementInteractionTimer)
      this.readerEnhancementInteractionTimer = -1
    }
    this.readerEnhancementInteractionActive = false
    ReaderSuperResolutionService.setInteractionPaused(false)
  }

  private onReaderSurfaceTouch(event: TouchEvent): void {
    const touch: TouchObject | null = event.changedTouches.length > 0
      ? event.changedTouches[0]
      : null
    if (touch !== null) {
      if (event.touches.length > 1 || event.changedTouches.length > 1) {
        this.suppressReaderTapGesture()
      } else if (event.type === TouchType.Down) {
        this.readerTapStartX = touch.x
        this.readerTapStartY = touch.y
      } else if (event.type === TouchType.Move) {
        const dx: number = touch.x - this.readerTapStartX
        const dy: number = touch.y - this.readerTapStartY
        if ((dx * dx + dy * dy) > (READER_VERTICAL_TAP_MAX_DISTANCE * READER_VERTICAL_TAP_MAX_DISTANCE)) {
          this.suppressReaderTapGesture()
        }
      } else if (event.type === TouchType.Cancel) {
        this.suppressReaderTapGesture()
      }
    }
    if (event.type === TouchType.Down || event.type === TouchType.Move) {
      this.pauseReaderEnhancementForForegroundInteraction()
      return
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.scheduleReaderEnhancementInteractionResume(READER_ENHANCEMENT_INTERACTION_SETTLE_MS)
    }
  }

  private suppressReaderTapGesture(): void {
    this.readerTapSuppressUntilMs = Date.now() + READER_TOUCH_TAP_SUPPRESS_MS
  }

  private consumeReaderTapSuppressed(): boolean {
    return Date.now() <= this.readerTapSuppressUntilMs
  }

  private async setWindowKeepScreenOn(enabled: boolean, generation: number): Promise<void> {
    try {
      const appWindow: window.Window = await window.getLastWindow(this.context())
      if (generation !== this.windowPolicyGeneration) {
        return
      }
      await appWindow.setWindowKeepScreenOn(enabled)
    } catch (error) {
      if (generation === this.windowPolicyGeneration) {
        console.warn(`Unable to update Reader keep-screen-on policy: ${(error as Error).message}`)
      }
    }
  }

  private async loadReader(): Promise<void> {
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    this.isLoading = true
    this.stopAutoRead()
    this.isReaderReadyForCurrentGallery = false
    this.errorMessage = ''
    this.resumeIndex = 0
    this.visiblePageIndex = 0
    this.zoomedPageIndex = -1
    this.doubleTapTargetIndex = -1
    this.showThumbnailStrip = false
    this.readerSliderValue = 1
    this.readerSliderPreview = -1
    this.lastPersistedIndex = -1
    this.loadedImageIndexes = []
    this.readerSourcePageIndexes = []
    this.readerSourcePagePaths = []
    this.readerTranslatedPageIndexes = []
    this.readerTranslatedPageUris = []
    this.readerTranslatedPageRuntimeKeys = []
    this.readerTranslationHiddenPages = []
    this.readerTranslationRunning = false
    this.readerTranslationPageIndex = -1
    this.readerTranslationRunRuntimeKey = ''
    this.readerTranslationErrorCode = ''
    this.resetReaderTranslationAutoSession()
    this.readerTranslationEpoch += 1
    this.restoreComicVisualRouteIdentity()
    this.detail = new NhGalleryDetail()
    this.pageDataSource.setData([], false)
    this.spreadDataSource.setData([], false)
    this.thumbnailDataSource.setData([])
    try {
      const savedDetail: NhGalleryDetail | null = await DownloadQueueService.localReaderDetail(
        this.context(),
        this.galleryId,
      )
      if (!this.isCurrentRequest(generation)) {
        return
      }
      // A verified completed download remains the Reader's first priority.
      // Gallery may provide one matching, route-scoped public snapshot while
      // its retained page is still live; that avoids a duplicate detail
      // request without persisting or widening the DTO cache.
      const seededDetail: NhGalleryDetail | null = this.readerOverlay.consumeDetailSeed(
        this.galleryId,
        this.readerRouteEpoch,
      )
      const detail: NhGalleryDetail = savedDetail ?? seededDetail ?? await NhApiClient.detail(this.galleryId)
      if (!this.isCurrentRequest(generation)) {
        return
      }
      if (detail.id <= 0 || detail.id !== this.galleryId) {
        throw new Error('Reader response did not match the requested gallery')
      }
      let restoredIndex: number = 0
      let persistedResume: boolean = false
      try {
        if (this.initialPageIndex >= 0) {
          // A thumbnail activation is a deliberate page choice. It must not be
          // overwritten by the previous local resume position.
          restoredIndex = this.clampPageIndex(this.initialPageIndex, detail.pages.length)
        } else {
          restoredIndex = await HistoryRepository.progress(this.context(), detail.id)
          if (!this.isCurrentRequest(generation)) {
            return
          }
          restoredIndex = this.clampPageIndex(restoredIndex, detail.pages.length)
        }
        // A persisted progress value remains a canonical source index. When
        // the current local canvas renders spreads, normalize it once to the
        // leading source page before the normal progress write; no display
        // index or RTL reversal ever reaches history.
        restoredIndex = ReaderSpreadResolver.normalizedNavigationIndex(
          restoredIndex,
          detail.pages.length,
          this.isDoublePageActive(),
        )
        await HistoryRepository.saveProgress(this.context(), detail, restoredIndex)
        if (!this.isCurrentRequest(generation)) {
          return
        }
        persistedResume = true
      } catch (error) {
        if (!this.isCurrentRequest(generation)) {
          return
        }
        console.warn(`Unable to restore local reading progress: ${(error as Error).message}`)
      }
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.detail = detail
      this.rebuildReaderPageDataSources(restoredIndex)
      this.lastPersistedIndex = persistedResume ? this.visiblePageIndex : -1
      this.thumbnailDataSource.setData(detail.pages)
      this.isReaderReadyForCurrentGallery = true
      this.scheduleReaderPreload(this.visiblePageIndex)
    } catch (error) {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.errorMessage = AppStrings.get('reader_error_load_pages')
      // A failed first load must still expose the native back affordance.
      this.readerChromeVisible = true
      this.notifyReaderPresentation()
    } finally {
      if (this.isCurrentRequest(generation)) {
        this.isLoading = false
      }
    }
  }

  private visiblePageText(): string {
    if (this.detail.pages.length === 0) {
      return AppStrings.get('reader_status_preparing_pages')
    }
    const maxIndex: number = this.detail.pages.length - 1
    const pageIndex: number = this.readerNavigationIndex(Math.min(Math.max(0, this.visiblePageIndex), maxIndex))
    const secondIndex: number = this.readerSpreadSecondIndex(pageIndex)
    if (secondIndex >= 0) {
      return `${pageIndex + 1}–${secondIndex + 1} / ${this.detail.pages.length}`
    }
    return `${pageIndex + 1} / ${this.detail.pages.length}`
  }

  /** The Slider always works in canonical, one-based source page numbers. */
  private readerSliderTargetIndex(page: number): number {
    const sourceIndex: number = this.clampPageIndex(Math.round(page) - 1, this.detail.pages.length)
    return this.readerNavigationIndex(sourceIndex)
  }

  private readerSliderCurrentPage(): number {
    if (this.detail.pages.length === 0) {
      return 1
    }
    return this.readerNavigationIndex(this.visiblePageIndex) + 1
  }

  private readerSliderPreviewPage(): number {
    return this.readerSliderPreview > 0 ? this.readerSliderPreview : this.readerSliderCurrentPage()
  }

  private readerSliderLeadingLabel(): string {
    return `${this.isRightToLeftPagedMode() ? this.detail.pages.length : this.readerSliderPreviewPage()}`
  }

  private readerSliderTrailingLabel(): string {
    return `${this.isRightToLeftPagedMode() ? this.readerSliderPreviewPage() : this.detail.pages.length}`
  }

  /**
   * Slider Begin/Moving/Click are preview-only. The official Slider contract
   * emits End after a touch interaction, so page movement and persistence stay
   * behind one deliberate End commit rather than following a drag frame.
   */
  private previewReaderSliderPage(page: number): void {
    if (!this.isReaderReadyForCurrentGallery || this.detail.pages.length === 0) {
      return
    }
    const targetPage: number = this.readerSliderTargetIndex(page) + 1
    if (this.readerSliderPreview < 0) {
      // Do not let a prior decoded-image dwell timer turn the page while the
      // user is selecting a different target.
      this.clearAutoReadTimer()
    }
    this.readerSliderPreview = targetPage
    this.readerSliderValue = targetPage
  }

  /** A page move shares the existing controller and its RTL display mapping. */
  private commitReaderSliderPage(page: number): void {
    if (!this.isReaderReadyForCurrentGallery || this.detail.pages.length === 0) {
      return
    }
    const target: number = this.readerSliderTargetIndex(page)
    this.readerSliderPreview = -1
    this.readerSliderValue = target + 1
    if (target === this.visiblePageIndex) {
      this.awaitAutoReadForVisiblePage()
      return
    }
    this.clearZoomForNavigation()
    this.clearAutoReadTimer()
    if (this.autoReadActive) {
      this.autoReadWaitingIndex = target
    }
    // Do not assign visiblePageIndex or call persistProgress here. Paged and
    // vertical flows both confirm the physical transition through their
    // existing source-index callback, which is the one persistence boundary.
    this.turnToReaderPage(target, false)
    this.scrollThumbnailStripTo(target, true)
  }

  private onReaderSliderChanged(value: number, mode: SliderChangeMode): void {
    const page: number = this.readerSliderTargetIndex(value) + 1
    if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving || mode === SliderChangeMode.Click) {
      this.previewReaderSliderPage(page)
      return
    }
    if (mode === SliderChangeMode.End) {
      this.commitReaderSliderPage(page)
    }
  }

  private isPagedMode(): boolean {
    return this.readerPresentation.mode === NhReaderMode.PAGED ||
      this.readerPresentation.mode === NhReaderMode.PAGED_RTL ||
      this.readerPresentation.mode === NhReaderMode.PAGED_VERTICAL
  }

  private isRightToLeftPagedMode(): boolean {
    return this.readerPresentation.mode === NhReaderMode.PAGED_RTL
  }

  private isVerticallyPagedMode(): boolean {
    return this.readerPresentation.mode === NhReaderMode.PAGED_VERTICAL
  }

  /**
   * One resolver governs every Reader mode. Continuous vertical mode maps
   * navigation zones to a bounded viewport scroll; only its menu zone opens
   * or closes chrome.
   */
  private onReaderSingleTap(event?: GestureEvent): void {
    if (this.consumeReaderTapSuppressed()) {
      return
    }
    if (this.tapZonePreviewVisible) {
      this.tapZonePreviewVisible = false
      return
    }
    const location = event ? event.tapLocation : undefined
    const tapX: number = location ? (location.x as number) : this.readerTapViewportWidth / 2
    const tapY: number = location ? (location.y as number) : this.readerTapViewportHeight / 2
    const action: NhReaderTapZoneAction = NhReaderTapZoneResolver.resolve(
      this.readerPresentation.tapZoneLayout,
      this.readerPresentation.tapZoneInvert,
      tapX,
      tapY,
      this.readerTapViewportWidth,
      this.readerTapViewportHeight,
    )
    if (!this.isPagedMode()) {
      this.performVerticalReaderTapZoneAction(action)
      return
    }
    this.performReaderTapZoneAction(action)
  }

  @Monitor('readerPresentation.tapZoneLayout', 'readerPresentation.tapZoneInvert')
  onTapZoneSettingsChanged(): void {
    if (this.isReaderReadyForCurrentGallery) {
      this.tapZonePreviewVisible = true
    }
  }

  private performVerticalReaderTapZoneAction(action: NhReaderTapZoneAction): void {
    const distance: number = Math.max(0, this.readerTapViewportHeight) * READER_TAP_ZONE_SCROLL_RATIO
    if (distance <= 0) {
      this.toggleReaderChrome()
      return
    }
    if (action === NhReaderTapZoneAction.PREVIOUS || action === NhReaderTapZoneAction.LEFT) {
      this.verticalReaderScroller.scrollBy(0, -distance)
      return
    }
    if (action === NhReaderTapZoneAction.NEXT || action === NhReaderTapZoneAction.RIGHT) {
      this.verticalReaderScroller.scrollBy(0, distance)
      return
    }
    this.toggleReaderChrome()
  }

  /** Resolves a zone action through canonical source-page navigation. */
  private performReaderTapZoneAction(action: NhReaderTapZoneAction): void {
    if (action === NhReaderTapZoneAction.PREVIOUS) {
      this.turnReaderBySourceOffset(-1)
      return
    }
    if (action === NhReaderTapZoneAction.NEXT) {
      this.turnReaderBySourceOffset(1)
      return
    }
    if (action === NhReaderTapZoneAction.LEFT) {
      this.turnReaderByHorizontalTap(true)
      return
    }
    if (action === NhReaderTapZoneAction.RIGHT) {
      this.turnReaderByHorizontalTap(false)
      return
    }
    this.toggleReaderChrome()
  }

  /**
   * A tap request never writes progress itself. The existing Swiper callback
   * maps physical display index back to its canonical source index, then is
   * the only path that persists confirmed page progress.
   */
  private turnReaderBySourceOffset(offset: number): void {
    if (!this.isReaderReadyForCurrentGallery || this.zoomedPageIndex >= 0 || offset === 0) {
      return
    }
    const currentIndex: number = this.readerNavigationIndex(this.visiblePageIndex)
    const target: number = currentIndex + (offset < 0 ? -this.readerNavigationStep() : this.readerNavigationStep())
    if (target < 0 || target >= this.detail.pages.length) {
      return
    }
    this.clearAutoReadTimer()
    if (this.autoReadActive) {
      this.autoReadWaitingIndex = target
    }
    this.turnToReaderPage(target, true)
    this.scrollThumbnailStripTo(target, true)
  }

  /**
   * LEFT and RIGHT express physical display space. RTL changes only which
   * source-page offset that space represents; zone inversion stays a pure
   * geometry transform inside NhReaderTapZoneResolver.
   */
  private turnReaderByHorizontalTap(left: boolean): void {
    const sourceOffset: number = this.isRightToLeftPagedMode()
      ? (left ? 1 : -1)
      : (left ? -1 : 1)
    this.turnReaderBySourceOffset(sourceOffset)
  }

  private readerModeLabel(mode: NhReaderMode = this.readerPresentation.mode): string {
    if (mode === NhReaderMode.PAGED_RTL) {
      return AppStrings.get('settings_reader_mode_paged_rtl')
    }
    if (mode === NhReaderMode.PAGED_VERTICAL) {
      return AppStrings.get('settings_reader_mode_paged_vertical')
    }
    if (mode === NhReaderMode.PAGED) {
      return AppStrings.get('settings_reader_mode_paged')
    }
    return AppStrings.get('settings_reader_mode_vertical')
  }

  private readerModeIcon(mode: NhReaderMode): Resource {
    if (mode === NhReaderMode.PAGED_RTL) {
      return $r('sys.symbol.arrow_left_and_square')
    }
    if (mode === NhReaderMode.PAGED_VERTICAL) {
      return $r('sys.symbol.single_page_flipping')
    }
    if (mode === NhReaderMode.PAGED) {
      return $r('sys.symbol.arrow_right_and_square')
    }
    return $r('sys.symbol.scroll_vertical')
  }

  /** Publishes one local choice; the monitor below preserves the current route and page. */
  private setReaderMode(mode: NhReaderMode): void {
    this.readerModeMenuShown = false
    if (mode === this.readerPresentation.mode) {
      return
    }
    ReaderPresentationService.setMode(this.context(), mode).catch((): void => {
      this.showReaderOverflowToast('settings_reader_layout_save_failed')
    })
  }

  /** Changes only the renderer; it preserves the same source page and cache. */
  private applyReaderMode(mode: NhReaderMode): void {
    const currentIndex: number = this.readerNavigationIndex(this.visiblePageIndex)
    this.stopAutoRead()
    this.clearZoomForNavigation()
    this.rebuildReaderPageDataSources(currentIndex)
    this.scrollThumbnailStripTo(this.visiblePageIndex, false)
    this.scheduleReaderPreload(this.visiblePageIndex)
  }

  /**
   * The Reader is already on a canonical gallery route. Reuse the exact
   * gallery-level share boundary instead of resolving an image or issuing a
   * new request just for the overflow action.
   */
  private async shareCurrentGallery(): Promise<void> {
    if (this.galleryId <= 0) {
      return
    }
    const shared: boolean = await NhGalleryShareService.shareCanonicalGallery(this.context(), this.galleryId)
    if (!shared) {
      this.showReaderOverflowToast('gallery_error_share_unavailable')
    }
  }

  /** Opens the same canonical gallery URL as the Gallery destination. */
  private async openCurrentGalleryExternally(): Promise<void> {
    if (this.galleryId <= 0) {
      return
    }
    const opened: boolean = await NhGalleryExternalOpenService.openCanonicalGallery(this.context(), this.galleryId)
    if (!opened) {
      this.showReaderOverflowToast('gallery_error_external_open_unavailable')
    }
  }

  private openReaderSettings(): void {
    this.readerOverflowMenuShown = false
    this.readerSettingsSheetShown = true
    this.pauseReaderEnhancementForForegroundInteraction()
  }

  private closeReaderSettings(): void {
    this.readerSettingsSheetShown = false
    this.pauseReaderEnhancementForForegroundInteraction()
    this.scheduleReaderEnhancementInteractionResume(READER_ENHANCEMENT_INTERACTION_SETTLE_MS)
  }

  private showReaderOverflowToast(messageKey: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: AppStrings.get(messageKey) })
    } catch (_error) {
      // A platform-share failure must not alter Reader state or page progress.
    }
  }

  @Builder
  private ReaderModeMenu() {
    Menu() {
      MenuItem({
        content: this.readerModeLabel(NhReaderMode.PAGED),
        symbolStartIcon: new SymbolGlyphModifier(this.readerModeIcon(NhReaderMode.PAGED)),
        symbolEndIcon: this.readerPresentation.mode === NhReaderMode.PAGED
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setReaderMode(NhReaderMode.PAGED)
      })
      MenuItem({
        content: this.readerModeLabel(NhReaderMode.PAGED_RTL),
        symbolStartIcon: new SymbolGlyphModifier(this.readerModeIcon(NhReaderMode.PAGED_RTL)),
        symbolEndIcon: this.readerPresentation.mode === NhReaderMode.PAGED_RTL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setReaderMode(NhReaderMode.PAGED_RTL)
      })
      MenuItem({
        content: this.readerModeLabel(NhReaderMode.PAGED_VERTICAL),
        symbolStartIcon: new SymbolGlyphModifier(this.readerModeIcon(NhReaderMode.PAGED_VERTICAL)),
        symbolEndIcon: this.readerPresentation.mode === NhReaderMode.PAGED_VERTICAL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setReaderMode(NhReaderMode.PAGED_VERTICAL)
      })
      MenuItem({
        content: this.readerModeLabel(NhReaderMode.VERTICAL),
        symbolStartIcon: new SymbolGlyphModifier(this.readerModeIcon(NhReaderMode.VERTICAL)),
        symbolEndIcon: this.readerPresentation.mode === NhReaderMode.VERTICAL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setReaderMode(NhReaderMode.VERTICAL)
      })
    }
  }

  /**
   * Keep route-level and system actions out of the compact Reader toolbar.
   * The menu uses only existing local routing and canonical gallery services.
   */
  @Builder
  private ReaderOverflowMenu() {
    Menu() {
      MenuItem({
        content: AppStrings.get('action_share'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.share')),
      }).onClick((): void => {
        this.readerOverflowMenuShown = false
        this.shareCurrentGallery()
      })
      MenuItem({
        content: AppStrings.get('action_open_externally'),
      }).onClick((): void => {
        this.readerOverflowMenuShown = false
        this.openCurrentGalleryExternally()
      })
      MenuItem({ content: this.readerTranslationActionLabel() })
        .enabled(!this.readerTranslationRunning)
        .onClick((): void => {
          this.toggleOrStartCurrentReaderTranslation()
        })
      MenuItem({
        content: AppStrings.get('reader_comic_translation_auto'),
        symbolEndIcon: this.readerTranslationAutoEnabled
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      })
        .enabled(true)
        .onClick((): void => {
          this.toggleReaderTranslationAuto()
        })
    }
  }

  private localImageUri(page: NhGalleryPage, index: number): string {
    return DownloadQueueService.localPageUri(this.context(), this.detail.id, index, page.extension)
  }

  private localSpreadSecondImageUri(item: ReaderSpreadItem): string {
    if (item.second === null) {
      return ''
    }
    return this.localImageUri(item.second.page, item.second.sourceIndex)
  }

  private readerSourceRecordIndex(pageIndex: number): number {
    return this.readerSourcePageIndexes.indexOf(pageIndex)
  }

  private readerSourceFilePath(pageIndex: number): string {
    const index: number = this.readerSourceRecordIndex(pageIndex)
    return index < 0 ? '' : this.readerSourcePagePaths[index]
  }

  private rememberReaderSourceFile(pageIndex: number, localPath: string): void {
    if (pageIndex < 0 || pageIndex >= this.detail.pages.length || localPath.length === 0) {
      return
    }
    const indexes: number[] = this.readerSourcePageIndexes.slice()
    const paths: string[] = this.readerSourcePagePaths.slice()
    const existing: number = indexes.indexOf(pageIndex)
    if (existing >= 0) {
      if (paths[existing] === localPath) {
        return
      }
      paths[existing] = localPath
    } else {
      indexes.push(pageIndex)
      paths.push(localPath)
    }
    this.readerSourcePageIndexes = indexes
    this.readerSourcePagePaths = paths
    this.scheduleReaderTranslationAuto()
  }

  private readerTranslatedRecordIndex(pageIndex: number): number {
    return this.readerTranslatedPageIndexes.indexOf(pageIndex)
  }

  /** This contains only non-secret runtime metadata, never a credential or endpoint. */
  private readerTranslationRuntimeKey(
    targetLanguage: string,
    sourceProfileId: string,
    sourceRevision: number,
    modelId: string,
    sidecarSelectionEpoch: number,
  ): string {
    if (targetLanguage.length === 0 || sourceProfileId.length === 0 || modelId.length === 0 ||
      !Number.isFinite(sourceRevision) || sourceRevision <= 0 || Math.floor(sourceRevision) !== sourceRevision ||
      !Number.isFinite(sidecarSelectionEpoch) || sidecarSelectionEpoch < 0 ||
      Math.floor(sidecarSelectionEpoch) !== sidecarSelectionEpoch) {
      return ''
    }
    return JSON.stringify([
      targetLanguage,
      sourceProfileId,
      sourceRevision,
      modelId,
      sidecarSelectionEpoch,
    ])
  }

  /** Disabled sidecar drafts do not invalidate an active local-render result. */
  private readerTranslationSidecarSelectionEpoch(): number {
    return this.mangaRenderingService.enabled
      ? this.mangaRenderingService.selectionEpoch
      : 0
  }

  /** Read the local state here so image-leaf projection rerenders when language changes. */
  private readerTranslationTargetLanguage(): string {
    const locale: string = this.language.effectiveLocale
    if (locale.length < 0) {
      return 'zh-CN'
    }
    return CommentTranslationService.targetLanguage()
  }

  /**
   * Detail tags are the public NH authority for the source work's language.
   * Keep their raw canonical value for the pipeline; a translated display
   * label is only a UI projection and must never select an OCR profile.
   */
  private readerTranslationSourceLanguage(): string {
    for (let index: number = 0; index < this.detail.tags.length; index++) {
      const tag: NhTag = this.detail.tags[index]
      const namespace: string = tag.type.trim().toLowerCase()
      const language: string = tag.name.trim()
      if ((namespace === 'language' || namespace === 'languages') &&
        language.length > 0 && language.toLowerCase() !== 'translated') {
        return language
      }
    }
    return 'auto'
  }

  /** Matches the identity that the runtime writes into ComicRenderedPage.identity. */
  private readerTranslationCurrentRuntimeKey(): string {
    const targetLanguage: string = this.readerTranslationTargetLanguage()
    if (targetLanguage.length === 0) {
      return ''
    }
    if (this.comicVisualRoute === COMIC_VISUAL_ROUTE_TORII) {
      if (this.toriiRuntimeProfileId.length === 0 || this.toriiRuntimeModelId.length === 0) {
        return ''
      }
      return this.readerTranslationRuntimeKey(
        targetLanguage,
        this.toriiRuntimeProfileId,
        TORII_WHOLE_PAGE_SOURCE_REVISION,
        this.toriiRuntimeModelId,
        0,
      )
    }
    const binding = this.llmSources.mangaBinding
    if (!binding.configured()) {
      return ''
    }
    const profile = this.llmSources.findById(binding.sourceProfileId)
    if (profile === null || !supportsMangaTranslation(profile)) {
      return ''
    }
    return this.readerTranslationRuntimeKey(
      this.readerTranslationTargetLanguage(),
      `llm-source:${profile.sourceProfileId}:r${profile.sourceRevision}`,
      profile.sourceRevision,
      binding.modelId,
      this.readerTranslationSidecarSelectionEpoch(),
    )
  }

  private readerTranslationResultRuntimeKey(result: ComicVisualTranslationRunResult): string {
    const identity = result.renderedPage.identity
    return this.readerTranslationRuntimeKey(
      identity.targetLanguage,
      identity.translationSourceProfileId,
      identity.translationSourceRevision,
      identity.translationModelId,
      this.readerTranslationSidecarSelectionEpoch(),
    )
  }

  private readerTranslatedRuntimeKey(pageIndex: number): string {
    const index: number = this.readerTranslatedRecordIndex(pageIndex)
    return index < 0 ? '' : this.readerTranslatedPageRuntimeKeys[index]
  }

  private readerTranslationHasCurrentResult(pageIndex: number): boolean {
    const index: number = this.readerTranslatedRecordIndex(pageIndex)
    const currentKey: string = this.readerTranslationCurrentRuntimeKey()
    return index >= 0 && currentKey.length > 0 &&
      this.readerTranslatedPageUris[index].length > 0 &&
      this.readerTranslatedRuntimeKey(pageIndex) === currentKey
  }

  private readerTranslatedImageUri(pageIndex: number): string {
    if (!this.readerTranslationHasCurrentResult(pageIndex) ||
      this.readerTranslationHiddenPages.includes(pageIndex)) {
      return ''
    }
    const index: number = this.readerTranslatedRecordIndex(pageIndex)
    return index < 0 ? '' : this.readerTranslatedPageUris[index]
  }

  private rememberReaderTranslatedPage(
    pageIndex: number,
    renderedUri: string,
    runtimeKey: string,
  ): void {
    if (pageIndex < 0 || renderedUri.length === 0 || runtimeKey.length === 0) {
      return
    }
    const indexes: number[] = this.readerTranslatedPageIndexes.slice()
    const uris: string[] = this.readerTranslatedPageUris.slice()
    const runtimeKeys: string[] = this.readerTranslatedPageRuntimeKeys.slice()
    const existing: number = indexes.indexOf(pageIndex)
    if (existing >= 0) {
      uris[existing] = renderedUri
      runtimeKeys[existing] = runtimeKey
    } else {
      indexes.push(pageIndex)
      uris.push(renderedUri)
      runtimeKeys.push(runtimeKey)
    }
    const hidden: number[] = this.readerTranslationHiddenPages.filter(
      (candidate: number): boolean => candidate !== pageIndex,
    )
    this.readerTranslatedPageIndexes = indexes
    this.readerTranslatedPageUris = uris
    this.readerTranslatedPageRuntimeKeys = runtimeKeys
    this.readerTranslationHiddenPages = hidden
  }

  private setReaderTranslationVisible(pageIndex: number, visible: boolean): void {
    const hidden: number[] = this.readerTranslationHiddenPages.filter(
      (candidate: number): boolean => candidate !== pageIndex,
    )
    if (!visible) {
      hidden.push(pageIndex)
    }
    this.readerTranslationHiddenPages = hidden
  }

  private currentReaderTranslationPageIndex(): number {
    return this.readerNavigationIndex(this.visiblePageIndex)
  }

  private readerTranslationActionLabel(): string {
    const pageIndex: number = this.currentReaderTranslationPageIndex()
    if (!this.readerTranslationHasCurrentResult(pageIndex)) {
      return AppStrings.get('reader_comic_translation_action')
    }
    return this.readerTranslatedImageUri(pageIndex).length > 0
      ? AppStrings.get('reader_comic_translation_show_original')
      : AppStrings.get('reader_comic_translation_show_result')
  }

  private readerTranslationActionEnabled(): boolean {
    const pageIndex: number = this.currentReaderTranslationPageIndex()
    return this.readerTranslationHasCurrentResult(pageIndex) ||
      (this.readerSourceFilePath(pageIndex).length > 0 && this.readerTranslationSourceConfigured())
  }

  /** Match the Reader action's availability to the persisted manga-source binding. */
  private readerTranslationSourceConfigured(): boolean {
    if (this.comicVisualRoute === COMIC_VISUAL_ROUTE_TORII) {
      return this.toriiRuntimeProfileId.length > 0
    }
    if (this.comicVisualRoute === COMIC_VISUAL_ROUTE_SELF_HOSTED) {
      return this.mangaRenderingService.initialized &&
        this.mangaRenderingService.enabled
    }
    return this.readerTranslationCurrentRuntimeKey().length > 0
  }

  /**
   * Loads the persisted visual route and its Torii identity once per Reader
   * route. The runtime backend (ComicTranslationRuntimeService.runReaderPage)
   * switches on ComicVisualProviderSettings.route, so availability must
   * follow the same route instead of only the LLM manga binding.
   */
  private restoreComicVisualRouteIdentity(): void {
    ComicVisualProviderSettings.load(this.context())
      .then((snapshot: ComicVisualProviderSettingsSnapshot): void => {
        if (this.requestGeneration <= 0) {
          return
        }
        this.comicVisualRoute = snapshot.route
        if (snapshot.route !== COMIC_VISUAL_ROUTE_TORII) {
          this.toriiRuntimeProfileId = ''
          this.toriiRuntimeModelId = ''
          return
        }
        const credential = ToriiWholePageSecretStore.readSync(this.context())
        const config: ToriiWholePageConfig = new ToriiWholePageConfig()
        config.toriiApiKey = credential.toriiApiKey
        config.modelId = snapshot.toriiModelId
        config.fontId = ToriiFontCatalog.effectiveFontId(
          snapshot.toriiFontId,
          this.readerTranslationTargetLanguage(),
        )
        try {
          config.assertValid()
          this.toriiRuntimeProfileId = config.sourceProfileId()
          this.toriiRuntimeModelId = config.modelId
        } catch (_error) {
          this.toriiRuntimeProfileId = ''
          this.toriiRuntimeModelId = ''
        }
      })
      .catch((): void => {})
  }

  /** Auto mode follows NextE's one-session, one-translation-at-a-time policy. */
  private resetReaderTranslationAutoSession(): void {
    this.readerTranslationAutoScheduleToken += 1
    this.readerTranslationAutoEnabled = false
    this.readerTranslationAutoFailedPageIndexes = []
    this.readerTranslationAutoFailedRuntimeKeys = []
  }

  private readerTranslationAutoFailedForPage(pageIndex: number): boolean {
    const runtimeKey: string = this.readerTranslationCurrentRuntimeKey()
    return this.readerTranslationAutoFailedRecordIndex(pageIndex, runtimeKey) >= 0
  }

  private readerTranslationAutoFailedRecordIndex(pageIndex: number, runtimeKey: string): number {
    if (runtimeKey.length === 0) {
      return -1
    }
    for (let index: number = 0; index < this.readerTranslationAutoFailedPageIndexes.length; index++) {
      if (this.readerTranslationAutoFailedPageIndexes[index] === pageIndex &&
        this.readerTranslationAutoFailedRuntimeKeys[index] === runtimeKey) {
        return index
      }
    }
    return -1
  }

  private setReaderTranslationAutoFailedForPage(
    pageIndex: number,
    runtimeKey: string,
    failed: boolean,
  ): void {
    if (pageIndex < 0 || runtimeKey.length === 0) {
      return
    }
    const indexes: number[] = this.readerTranslationAutoFailedPageIndexes.slice()
    const runtimeKeys: string[] = this.readerTranslationAutoFailedRuntimeKeys.slice()
    const existing: number = this.readerTranslationAutoFailedRecordIndex(pageIndex, runtimeKey)
    if (failed && existing < 0) {
      indexes.push(pageIndex)
      runtimeKeys.push(runtimeKey)
    } else if (!failed && existing >= 0) {
      indexes.splice(existing, 1)
      runtimeKeys.splice(existing, 1)
    } else {
      return
    }
    this.readerTranslationAutoFailedPageIndexes = indexes
    this.readerTranslationAutoFailedRuntimeKeys = runtimeKeys
  }

  private readerTranslationAutoPageReady(pageIndex: number): boolean {
    return pageIndex >= 0 && pageIndex < this.detail.pages.length &&
      this.readerSourceFilePath(pageIndex).length > 0
  }

  private readerTranslationNeedsAutoWork(pageIndex: number): boolean {
    return this.readerTranslationAutoPageReady(pageIndex) &&
      !this.readerTranslationAutoFailedForPage(pageIndex) &&
      !this.readerTranslationHasCurrentResult(pageIndex)
  }

  /** Current page wins; only after it settles may the next ready page start. */
  private readerTranslationAutoTargetPageIndex(): number {
    const current: number = this.currentReaderTranslationPageIndex()
    if (this.readerTranslationNeedsAutoWork(current)) {
      return current
    }
    const currentSettled: boolean = this.readerTranslationAutoPageReady(current) &&
      (this.readerTranslationAutoFailedForPage(current) || this.readerTranslationHasCurrentResult(current))
    const next: number = current + 1
    return currentSettled && this.readerTranslationNeedsAutoWork(next) ? next : -1
  }

  private scheduleReaderTranslationAuto(): void {
    if (!this.readerTranslationAutoEnabled) {
      return
    }
    const token: number = this.readerTranslationAutoScheduleToken + 1
    this.readerTranslationAutoScheduleToken = token
    setTimeout((): void => {
      if (token === this.readerTranslationAutoScheduleToken) {
        this.runReaderTranslationAuto()
      }
    }, 0)
  }

  private runReaderTranslationAuto(): void {
    if (!this.readerTranslationAutoEnabled || this.readerTranslationRunning ||
      !this.isReaderReadyForCurrentGallery) {
      return
    }
    if (!this.readerTranslationSourceConfigured()) {
      this.resetReaderTranslationAutoSession()
      return
    }
    const pageIndex: number = this.readerTranslationAutoTargetPageIndex()
    if (pageIndex >= 0) {
      this.startReaderTranslationForPage(pageIndex, true)
    }
  }

  private toggleReaderTranslationAuto(): void {
    this.readerOverflowMenuShown = false
    if (this.readerTranslationAutoEnabled) {
      this.resetReaderTranslationAutoSession()
      return
    }
    if (!this.readerTranslationSourceConfigured()) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('reader_comic_translation_auto'),
      message: AppStrings.get('reader_comic_translation_auto_confirm'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('common_on'),
        action: (): void => {
          this.readerTranslationAutoFailedPageIndexes = []
          this.readerTranslationAutoFailedRuntimeKeys = []
          this.readerTranslationAutoEnabled = true
          this.scheduleReaderPreload(this.visiblePageIndex)
          this.scheduleReaderTranslationAuto()
        },
      },
    })
  }

  private readerTranslationStatusVisible(): boolean {
    return this.readerTranslationRunRuntimeKey.length > 0 &&
      this.readerTranslationRunRuntimeKey === this.readerTranslationCurrentRuntimeKey() &&
      this.readerTranslationPageIndex === this.currentReaderTranslationPageIndex() &&
      (this.readerTranslationRunning || this.readerTranslationErrorCode.length > 0)
  }

  private readerTranslationStatusText(): string {
    if (this.readerTranslationRunning) {
      return AppStrings.get('reader_comic_translation_running')
    }
    return this.readerTranslationErrorCode === 'image_unavailable'
      ? AppStrings.get('reader_comic_translation_image_unavailable')
      : AppStrings.get('reader_comic_translation_failed')
  }

  private toggleOrStartCurrentReaderTranslation(): void {
    const pageIndex: number = this.currentReaderTranslationPageIndex()
    if (this.readerTranslationRunning) {
      return
    }
    if (this.readerTranslationHasCurrentResult(pageIndex)) {
      this.setReaderTranslationVisible(pageIndex, this.readerTranslatedImageUri(pageIndex).length === 0)
      return
    }
    if (!this.readerTranslationSourceConfigured()) {
      this.showReaderOverflowToast('reader_comic_translation_provider_unavailable')
      return
    }
    this.startReaderTranslationForPage(pageIndex, false)
  }

  /** Both explicit and automatic work preserve the same leaf-only render path. */
  private startReaderTranslationForPage(pageIndex: number, automatic: boolean): void {
    const targetLanguage: string = this.readerTranslationTargetLanguage()
    const runtimeKey: string = this.readerTranslationCurrentRuntimeKey()
    if (this.readerTranslationRunning || targetLanguage.length === 0 || runtimeKey.length === 0) {
      return
    }
    const sourcePath: string = this.readerSourceFilePath(pageIndex)
    if (sourcePath.length === 0 || pageIndex < 0 || pageIndex >= this.detail.pages.length) {
      this.readerTranslationPageIndex = pageIndex
      this.readerTranslationRunRuntimeKey = runtimeKey
      this.readerTranslationErrorCode = 'image_unavailable'
      if (automatic) {
        this.setReaderTranslationAutoFailedForPage(pageIndex, runtimeKey, true)
        this.scheduleReaderTranslationAuto()
      }
      return
    }
    const page: NhGalleryPage = this.detail.pages[pageIndex]
    const epoch: number = this.readerTranslationEpoch + 1
    this.readerTranslationEpoch = epoch
    const requestGeneration: number = this.requestGeneration
    const input: ComicTranslationReaderPageInput = new ComicTranslationReaderPageInput()
    input.projectId = `nh-reader-${this.detail.id}-${targetLanguage}`
    input.pageIndex = pageIndex
    input.imageFilePath = sourcePath
    input.imageWidth = page.width
    input.imageHeight = page.height
    input.sourceLanguage = this.readerTranslationSourceLanguage()
    input.targetLanguage = targetLanguage
    this.readerTranslationRunning = true
    this.readerTranslationPageIndex = pageIndex
    this.readerTranslationRunRuntimeKey = runtimeKey
    this.readerTranslationErrorCode = ''
    this.readerOverflowMenuShown = false
    ComicTranslationRuntimeService.runReaderPage(this.context(), input)
      .then((result: ComicVisualTranslationRunResult): void => {
        if (epoch !== this.readerTranslationEpoch || requestGeneration !== this.requestGeneration) {
          return
        }
        const pageStillVisible: boolean = pageIndex === this.currentReaderTranslationPageIndex()
        this.readerTranslationRunning = false
        const resultRuntimeKey: string = this.readerTranslationResultRuntimeKey(result)
        const resultStillCurrent: boolean = result.renderedPage.localFilePath.length > 0 &&
          resultRuntimeKey.length > 0 && resultRuntimeKey === runtimeKey &&
          runtimeKey === this.readerTranslationCurrentRuntimeKey()
        if (!resultStillCurrent) {
          const runtimeStillCurrent: boolean = runtimeKey === this.readerTranslationCurrentRuntimeKey()
          this.readerTranslationRunRuntimeKey = runtimeStillCurrent ? runtimeKey : ''
          if (runtimeStillCurrent && (automatic || this.readerTranslationAutoEnabled)) {
            this.setReaderTranslationAutoFailedForPage(pageIndex, runtimeKey, true)
          }
          this.readerTranslationErrorCode = runtimeStillCurrent && (automatic || pageStillVisible)
            ? 'failed'
            : ''
          if (automatic && !pageStillVisible) {
            this.readerTranslationPageIndex = -1
          }
          this.scheduleReaderTranslationAuto()
          return
        }
        this.readerTranslationRunRuntimeKey = ''
        this.readerTranslationErrorCode = ''
        this.rememberReaderTranslatedPage(
          pageIndex,
          fileUri.getUriFromPath(result.renderedPage.localFilePath),
          resultRuntimeKey,
        )
        this.setReaderTranslationAutoFailedForPage(pageIndex, runtimeKey, false)
        if (automatic && !pageStillVisible) {
          this.readerTranslationPageIndex = -1
        }
        this.scheduleReaderTranslationAuto()
      })
      .catch((): void => {
        if (epoch !== this.readerTranslationEpoch || requestGeneration !== this.requestGeneration) {
          return
        }
        const pageStillVisible: boolean = pageIndex === this.currentReaderTranslationPageIndex()
        this.readerTranslationRunning = false
        if (runtimeKey !== this.readerTranslationCurrentRuntimeKey()) {
          this.readerTranslationRunRuntimeKey = ''
          this.readerTranslationErrorCode = ''
          if (automatic && !pageStillVisible) {
            this.readerTranslationPageIndex = -1
          }
          this.scheduleReaderTranslationAuto()
          return
        }
        this.readerTranslationRunRuntimeKey = runtimeKey
        if (automatic || this.readerTranslationAutoEnabled) {
          this.setReaderTranslationAutoFailedForPage(pageIndex, runtimeKey, true)
        }
        this.readerTranslationErrorCode = automatic && !pageStillVisible ? '' : 'failed'
        if (automatic && !pageStillVisible) {
          this.readerTranslationPageIndex = -1
        }
        this.scheduleReaderTranslationAuto()
      })
  }

  private onReaderImageZoomChanged(sourceIndex: number, zoomed: boolean): void {
    if (zoomed) {
      this.zoomedPageIndex = sourceIndex
    } else if (this.zoomedPageIndex === sourceIndex) {
      this.zoomedPageIndex = -1
    }
  }

  private autoReadIntervalMs(): number {
    return Math.max(1, this.readerPresentation.autoPageSeconds) * 1000
  }

  private isReaderImageLoaded(index: number): boolean {
    return this.loadedImageIndexes.indexOf(index) >= 0
  }

  /** In spread mode, one decoded half is not a ready visual destination. */
  private isReaderPresentationLoaded(sourceIndex: number): boolean {
    const startIndex: number = this.readerNavigationIndex(sourceIndex)
    if (!this.isReaderImageLoaded(startIndex)) {
      return false
    }
    const secondIndex: number = this.readerSpreadSecondIndex(startIndex)
    return secondIndex < 0 || this.isReaderImageLoaded(secondIndex)
  }

  /**
   * Image completion is the only readiness signal that can restart auto
   * advance. Cache/file availability alone is insufficient because ArkUI may
   * still be decoding the visible image.
   */
  private onReaderImageLoadStateChanged(index: number, loaded: boolean): void {
    if (index < 0) {
      return
    }
    const existing: number = this.loadedImageIndexes.indexOf(index)
    if (loaded && existing < 0) {
      this.loadedImageIndexes.push(index)
    } else if (!loaded && existing >= 0) {
      this.loadedImageIndexes.splice(existing, 1)
    }
    if (loaded && this.autoReadActive && this.autoReadWaitingIndex >= 0 &&
      this.isReaderPresentationLoaded(this.autoReadWaitingIndex)) {
      this.autoReadWaitingIndex = -1
      this.startAutoReadTimer()
    }
  }

  private onReaderEnhancementStateChanged(
    pageIndex: number,
    processing: boolean,
    applied: boolean,
  ): void {
    if (pageIndex < 0) {
      return
    }
    const next: ReaderEnhancementPageState[] = this.readerEnhancementStates.slice()
    let state: ReaderEnhancementPageState | undefined = undefined
    for (let index: number = 0; index < next.length; index++) {
      if (next[index].pageIndex === pageIndex) {
        state = next[index]
        break
      }
    }
    if (state === undefined) {
      state = new ReaderEnhancementPageState()
      state.pageIndex = pageIndex
      next.push(state)
    }
    state.processing = processing
    state.applied = applied
    state.reason = processing ? 'processing' : this.readerEnhancementOutcomeReason(pageIndex)
    this.readerEnhancementStates = next
  }

  private enhancementStateForPage(pageIndex: number): ReaderEnhancementPageState | undefined {
    for (let index: number = 0; index < this.readerEnhancementStates.length; index++) {
      if (this.readerEnhancementStates[index].pageIndex === pageIndex) {
        return this.readerEnhancementStates[index]
      }
    }
    return undefined
  }

  private currentReaderEnhancementProcessing(): boolean {
    const startIndex: number = this.readerNavigationIndex(this.visiblePageIndex)
    const first: ReaderEnhancementPageState | undefined = this.enhancementStateForPage(startIndex)
    const secondIndex: number = this.readerSpreadSecondIndex(startIndex)
    const second: ReaderEnhancementPageState | undefined = secondIndex < 0
      ? undefined
      : this.enhancementStateForPage(secondIndex)
    return (first !== undefined && first.processing) || (second !== undefined && second.processing)
  }

  private currentReaderEnhancementApplied(): boolean {
    const startIndex: number = this.readerNavigationIndex(this.visiblePageIndex)
    const first: ReaderEnhancementPageState | undefined = this.enhancementStateForPage(startIndex)
    if (first === undefined || !first.applied) {
      return false
    }
    const secondIndex: number = this.readerSpreadSecondIndex(startIndex)
    if (secondIndex < 0) {
      return true
    }
    const second: ReaderEnhancementPageState | undefined = this.enhancementStateForPage(secondIndex)
    return second !== undefined && second.applied
  }

  private readerEnhancementOutcomeReason(pageIndex: number): string {
    if (pageIndex < 0 || pageIndex >= this.detail.pages.length) {
      return 'queued'
    }
    const page: NhGalleryPage = this.detail.pages[pageIndex]
    const cacheKey: string = ReaderImageCacheService.cacheKey(
      this.detail.id,
      this.detail.mediaId,
      page.number,
      page.extension,
    )
    const imageReason: string = ReaderSuperResolutionService.ownerOutcomeReason(
      `reader-image:${cacheKey}:${pageIndex}`,
    )
    const spreadReason: string = ReaderSuperResolutionService.ownerOutcomeReason(
      `reader-spread:${cacheKey}:${pageIndex}`,
    )
    if (this.isDoublePageActive() && spreadReason.length > 0) {
      return spreadReason
    }
    return imageReason.length > 0 ? imageReason : (spreadReason.length > 0 ? spreadReason : 'queued')
  }

  /**
   * An auto-read interval belongs to a rendered page, not to a prior page's
   * timer. This keeps a slow next image from consuming part of its own dwell
   * interval while it is still decoding.
   */
  private awaitAutoReadForVisiblePage(): void {
    if (!this.autoReadActive || !this.isReaderReadyForCurrentGallery) {
      return
    }
    this.clearAutoReadTimer()
    const visibleStartIndex: number = this.readerNavigationIndex(this.visiblePageIndex)
    if (this.isReaderImageLoaded(this.visiblePageIndex) && this.isReaderPresentationLoaded(visibleStartIndex)) {
      this.autoReadWaitingIndex = -1
      this.startAutoReadTimer()
      return
    }
    this.autoReadWaitingIndex = visibleStartIndex
    this.scheduleReaderPreload(visibleStartIndex)
  }

  private nextAutoReadIndex(): number {
    return this.readerNavigationIndex(this.visiblePageIndex) + this.readerNavigationStep()
  }

  /**
   * Only a requested, adjacent Pager move receives the local animation. This
   * preserves direct Slider/thumbnail jumps and keeps continuous List scrolling
   * on its existing owner.
   */
  private shouldAnimateReaderPageTurn(target: number, requested: boolean): boolean {
    if (!requested || !this.readerPresentation.pageTurnAnimation || !this.isPagedMode()) {
      return false
    }
    const current: number = this.readerNavigationIndex(this.visiblePageIndex)
    const currentDisplayIndex: number = this.pagedDisplayIndexForSourceIndex(current)
    const targetDisplayIndex: number = this.pagedDisplayIndexForSourceIndex(target)
    return Math.abs(targetDisplayIndex - currentDisplayIndex) === 1
  }

  private turnToReaderPage(index: number, requestAnimation: boolean = false): void {
    const target: number = this.readerNavigationIndex(index)
    if (this.isPagedMode()) {
      try {
        this.pagedReaderController.changeIndex(
          this.pagedDisplayIndexForSourceIndex(target),
          this.shouldAnimateReaderPageTurn(target, requestAnimation),
        )
      } catch (error) {
        console.warn(`Unable to advance Reader page: ${(error as Error).message}`)
      }
      return
    }
    this.verticalReaderScroller.scrollToIndex(target)
  }

  /**
   * A thumbnail is a direct user navigation request. It shares the existing
   * Reader turn controller so paged, RTL, vertically paged, and continuous
   * modes all retain their current page/progress/preload behavior.
   */
  private selectThumbnail(index: number): void {
    if (!this.isReaderReadyForCurrentGallery || index < 0 || index >= this.detail.pages.length) {
      return
    }
    const target: number = this.readerNavigationIndex(index)
    if (target === this.visiblePageIndex) {
      this.scrollThumbnailStripTo(target, true)
      this.awaitAutoReadForVisiblePage()
      return
    }
    this.clearZoomForNavigation()
    // A prior page's dwell timer must never turn another page while a manual
    // thumbnail transition is still settling. The normal index callback
    // restarts the existing decoded-image gate for the selected page.
    this.clearAutoReadTimer()
    if (this.autoReadActive) {
      this.autoReadWaitingIndex = target
    }
    this.turnToReaderPage(target, false)
    this.scrollThumbnailStripTo(target, true)
  }

  /** Reset only the active page zoom before a controller-driven page move. */
  private clearZoomForNavigation(): void {
    if (this.zoomedPageIndex < 0) {
      return
    }
    this.doubleTapTargetIndex = this.zoomedPageIndex
    this.doubleTapSequence += 1
    this.zoomedPageIndex = -1
  }

  private toggleThumbnailStrip(): void {
    if (!this.isReaderReadyForCurrentGallery || this.detail.pages.length === 0) {
      return
    }
    const nextVisible: boolean = !this.showThumbnailStrip
    this.getUIContext().animateTo({ duration: 180, curve: Curve.FastOutSlowIn }, (): void => {
      this.showThumbnailStrip = nextVisible
    })
    if (nextVisible) {
      setTimeout((): void => {
        this.scrollThumbnailStripTo(this.visiblePageIndex, false)
      }, 0)
    }
  }

  private scrollThumbnailStripTo(index: number, animated: boolean): void {
    if (!this.showThumbnailStrip || index < 0 || index >= this.detail.pages.length) {
      return
    }
    try {
      this.thumbnailScroller.scrollToIndex(index, animated)
    } catch (error) {
      console.warn(`Unable to follow Reader thumbnail selection: ${(error as Error).message}`)
    }
  }

  /** ErosN parity: volume down advances and volume up returns, only while this route is foreground. */
  private turnByVolumeKeyCode(keyCode: number): void {
    if (!this.readerPresentation.volumeKeyTurn || !this.isReaderReadyForCurrentGallery || this.zoomedPageIndex >= 0) {
      return
    }
    const offset: number = keyCode === KeyCode.KEYCODE_VOLUME_DOWN ? 1 :
      keyCode === KeyCode.KEYCODE_VOLUME_UP ? -1 : 0
    const target: number = this.readerNavigationIndex(this.visiblePageIndex) +
      (offset < 0 ? -this.readerNavigationStep() : this.readerNavigationStep())
    if (offset === 0 || target < 0 || target >= this.detail.pages.length) {
      return
    }
    this.clearAutoReadTimer()
    if (this.autoReadActive) {
      this.autoReadWaitingIndex = target
    }
    this.turnToReaderPage(target, true)
    this.scrollThumbnailStripTo(target, true)
  }

  private syncVolumeKeyConsumer(): void {
    if (!this.readerPresentation.volumeKeyTurn) {
      this.unregisterVolumeKeyConsumer()
      return
    }
    this.registerVolumeKeyConsumer()
  }

  private registerVolumeKeyConsumer(): void {
    if (this.volumeDownConsumer !== null || this.volumeUpConsumer !== null) {
      return
    }
    const downCallback: (event: InputConsumerKeyEvent) => void = (event: InputConsumerKeyEvent): void => {
      if (event.action === Action.DOWN) {
        this.turnByVolumeKeyCode(KeyCode.KEYCODE_VOLUME_DOWN)
      }
    }
    const upCallback: (event: InputConsumerKeyEvent) => void = (event: InputConsumerKeyEvent): void => {
      if (event.action === Action.DOWN) {
        this.turnByVolumeKeyCode(KeyCode.KEYCODE_VOLUME_UP)
      }
    }
    this.volumeDownConsumer = downCallback
    this.volumeUpConsumer = upCallback
    try {
      inputConsumer.on('keyPressed', {
        key: KeyCode.KEYCODE_VOLUME_DOWN,
        action: Action.DOWN,
        isRepeat: false,
      }, downCallback)
      inputConsumer.on('keyPressed', {
        key: KeyCode.KEYCODE_VOLUME_UP,
        action: Action.DOWN,
        isRepeat: false,
      }, upCallback)
    } catch (error) {
      console.warn(`Unable to register Reader volume keys: ${(error as Error).message}`)
      this.unregisterVolumeKeyConsumer()
    }
  }

  private unregisterVolumeKeyConsumer(): void {
    try {
      if (this.volumeDownConsumer !== null) {
        inputConsumer.off('keyPressed', this.volumeDownConsumer)
      }
      if (this.volumeUpConsumer !== null) {
        inputConsumer.off('keyPressed', this.volumeUpConsumer)
      }
    } catch (error) {
      console.warn(`Unable to unregister Reader volume keys: ${(error as Error).message}`)
    }
    this.volumeDownConsumer = null
    this.volumeUpConsumer = null
  }

  private toggleAutoRead(): void {
    if (this.autoReadActive) {
      this.stopAutoRead()
      return
    }
    if (!this.isReaderReadyForCurrentGallery || this.detail.pages.length <= 1) {
      return
    }
    this.autoReadActive = true
    this.awaitAutoReadForVisiblePage()
  }

  private startAutoReadTimer(): void {
    if (!this.autoReadActive) {
      return
    }
    this.clearAutoReadTimer()
    this.autoReadTimerId = setInterval((): void => {
      this.advanceAutoRead()
    }, this.autoReadIntervalMs())
  }

  private clearAutoReadTimer(): void {
    if (this.autoReadTimerId >= 0) {
      clearInterval(this.autoReadTimerId)
      this.autoReadTimerId = -1
    }
  }

  private stopAutoRead(): void {
    this.clearAutoReadTimer()
    this.autoReadActive = false
    this.autoReadWaitingIndex = -1
  }

  private advanceAutoRead(): void {
    if (!this.autoReadActive || this.zoomedPageIndex >= 0) {
      return
    }
    const visibleStartIndex: number = this.readerNavigationIndex(this.visiblePageIndex)
    if (!this.isReaderImageLoaded(this.visiblePageIndex) || !this.isReaderPresentationLoaded(visibleStartIndex)) {
      this.autoReadWaitingIndex = visibleStartIndex
      this.clearAutoReadTimer()
      this.scheduleReaderPreload(visibleStartIndex)
      return
    }
    const target: number = this.nextAutoReadIndex()
    if (target >= this.detail.pages.length) {
      this.stopAutoRead()
      return
    }
    this.autoReadWaitingIndex = target
    this.clearAutoReadTimer()
    this.turnToReaderPage(target, true)
  }

  private onReaderDoubleTap(): void {
    if (!this.isReaderReadyForCurrentGallery || this.visiblePageIndex < 0 ||
      this.visiblePageIndex >= this.detail.pages.length) {
      return
    }
    const startIndex: number = this.readerNavigationIndex(this.visiblePageIndex)
    const secondIndex: number = this.readerSpreadSecondIndex(startIndex)
    if (secondIndex < 0) {
      this.doubleTapTargetIndex = startIndex
    } else {
      const tapLeft: boolean = this.readerDoubleTapX < this.readerTapViewportWidth / 2
      this.doubleTapTargetIndex = this.isRightToLeftPagedMode()
        ? (tapLeft ? secondIndex : startIndex)
        : (tapLeft ? startIndex : secondIndex)
    }
    this.doubleTapSequence += 1
  }

  private pagedDisplayIndexForSourceIndex(sourceIndex: number): number {
    const normalized: number = this.clampPageIndex(sourceIndex, this.detail.pages.length)
    if (this.isDoublePageActive()) {
      return this.spreadDataSource.displayIndexForSourceIndex(normalized)
    }
    if (this.isRightToLeftPagedMode()) {
      return this.detail.pages.length - 1 - normalized
    }
    return normalized
  }

  private sourceIndexForPagedDisplayIndex(displayIndex: number): number {
    if (this.isDoublePageActive()) {
      if (this.spreadDataSource.totalCount() === 0) {
        return 0
      }
      const normalizedSpreadIndex: number = Math.min(
        Math.max(0, displayIndex),
        this.spreadDataSource.totalCount() - 1,
      )
      return this.spreadDataSource.getData(normalizedSpreadIndex).sourceIndex
    }
    const normalized: number = this.clampPageIndex(displayIndex, this.detail.pages.length)
    if (this.isRightToLeftPagedMode()) {
      return this.detail.pages.length - 1 - normalized
    }
    return normalized
  }

  /**
   * Vertical mode is source-ordered today, but it still resolves through the
   * shared data source so a future display-order change cannot silently write
   * progress for a List display index instead of the canonical page index.
   */
  private sourceIndexForVerticalDisplayIndex(displayIndex: number): number {
    if (this.detail.pages.length === 0) {
      return 0
    }
    const normalized: number = Math.min(
      Math.max(0, displayIndex),
      this.detail.pages.length - 1,
    )
    return this.pageDataSource.getData(normalized).sourceIndex
  }

  @Builder
  private ReaderPersistentPageStatus() {
    if (this.readerPresentation.showPageNumber || this.readerEnhancementEnabled) {
      Stack({ alignContent: Alignment.Bottom }) {
        Row({ space: ThemeTokens.SPACE_XS }) {
          if (this.readerPresentation.showPageNumber) {
            ReaderPageNumberStatus({
              value: this.visiblePageText(),
            })
          }
          if (this.readerEnhancementEnabled) {
            ReaderEnhancementStatusIcon({
              processing: this.currentReaderEnhancementProcessing(),
              applied: this.currentReaderEnhancementApplied(),
            })
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: this.layoutSafeArea.bottomAvoidHeight + READER_ENHANCEMENT_STATUS_BOTTOM_GAP })
        .hitTestBehavior(HitTestMode.None)
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
    }
  }

  /** Reference-owned transient status: overlay-only, never a Reader canvas inset. */
  @Builder
  private ReaderTranslationStatusOverlay() {
    if (this.readerTranslationStatusVisible()) {
      Row({ space: ThemeTokens.SPACE_SM }) {
        if (this.readerTranslationRunning) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(ThemeTokens.TEXT_ON_BRAND)
        } else {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
            .fontSize(18)
            .fontColor([ThemeTokens.TEXT_ON_BRAND])
        }
        Text(this.readerTranslationStatusText())
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_ON_BRAND)
          .maxLines(2)
      }
      .padding({
        left: ThemeTokens.SPACE_MD,
        right: ThemeTokens.SPACE_MD,
        top: ThemeTokens.SPACE_SM,
        bottom: ThemeTokens.SPACE_SM,
      })
      .backgroundColor(ThemeTokens.OVERLAY_SCRIM)
      .borderRadius(ThemeTokens.RADIUS_ROUND)
      .position({
        x: ThemeTokens.SPACE_MD,
        y: this.layoutSafeArea.topAvoidHeight + ThemeTokens.TITLE_BAR_HEIGHT + ThemeTokens.SPACE_MD,
      })
      .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  private ReaderHeader() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([ThemeTokens.TEXT_ON_BRAND])
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .onClick((): void => {
          this.invalidateReaderRequest()
          if (this.onBack) {
            this.onBack()
          }
        })
        Blank()
        // NextE puts Reader settings behind a direct top-bar gear button,
        // not inside the overflow menu as a text item.
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.gearshape'))
            .fontSize(22)
            .fontColor([ThemeTokens.TEXT_ON_BRAND])
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .accessibilityText(AppStrings.get('settings_reader'))
        .onClick((): void => {
          this.openReaderSettings()
        })
        // Route-level actions remain in the top chrome. Per-page reading
        // controls intentionally live in ReaderBottomBar with the scrubber.
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
            .fontSize(22)
            .fontColor([ThemeTokens.TEXT_ON_BRAND])
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .accessibilityText(AppStrings.get('reader_action_more'))
        .onClick((): void => {
          this.readerOverflowMenuShown = true
        })
        .bindMenu(this.readerOverflowMenuShown, this.ReaderOverflowMenu, appMenuOptions({
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.readerOverflowMenuShown = false
          },
        }))
      }
      .width('100%')
      .height(ThemeTokens.TITLE_BAR_HEIGHT)
      .alignItems(VerticalAlign.Center)
      Text(this.visiblePageText())
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_ON_BRAND)
        .opacity(0.9)
        .maxLines(1)
    }
    .width('100%')
    .height(this.layoutSafeArea.topAvoidHeight + ThemeTokens.TITLE_BAR_HEIGHT)
    .padding({
      top: this.layoutSafeArea.topAvoidHeight,
      left: ThemeTokens.SPACE_SM,
      right: ThemeTokens.SPACE_SM,
    })
    .backgroundColor(ThemeTokens.OVERLAY_SCRIM)
    // Use the same explicit viewport origin as NextE. `align` on a Builder
    // root does not reliably override this parent Stack's center alignment.
    .position({ x: 0, y: 0 })
  }

  @Builder
  private ReaderLoadingState() {
    Column({ space: ThemeTokens.SPACE_MD }) {
      LoadingProgress()
        .width(28)
        .height(28)
        .color(this.readerCanvasForegroundColor())
      Text(AppStrings.get('reader_status_preparing_reader'))
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(this.readerCanvasForegroundColor())
        .opacity(0.72)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private ReaderFailureState() {
    Column({ space: ThemeTokens.SPACE_MD }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
        .fontSize(36)
        .fontColor([this.readerCanvasForegroundColor()])
        .opacity(0.84)
      Text(this.errorMessage)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(this.readerCanvasForegroundColor())
        .opacity(0.78)
        .textAlign(TextAlign.Center)
        .maxLines(3)
      Button(AppStrings.get('reader_action_retry'))
        .type(ButtonType.Capsule)
        .height(ThemeTokens.ACTION_HEIGHT)
        .backgroundColor(this.readerCanvasControlTint())
        .fontColor(this.readerCanvasForegroundColor())
        .onClick((): void => {
          this.loadReader()
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(ThemeTokens.SPACE_XL)
  }

  @Builder
  private ReaderInlineError() {
    if (this.errorMessage.length > 0) {
      Row({ space: ThemeTokens.SPACE_SM }) {
        Text(this.errorMessage)
          .layoutWeight(1)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(this.readerCanvasForegroundColor())
          .opacity(0.74)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Button(AppStrings.get('reader_action_retry'))
          .type(ButtonType.Capsule)
          .height(32)
          .backgroundColor(this.readerCanvasControlTint())
          .fontColor(this.readerCanvasForegroundColor())
          .onClick((): void => {
            this.loadReader()
          })
      }
      .width('100%')
      .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD, bottom: ThemeTokens.SPACE_MD })
      .backgroundColor(this.readerCanvasColor())
      .alignItems(VerticalAlign.Center)
      .align(Alignment.Bottom)
    }
  }

  @Builder
  private ReaderVerticalFlow() {
    List({ initialIndex: this.resumeIndex, scroller: this.verticalReaderScroller }) {
      LazyForEach(
        this.pageDataSource,
        (item: ReaderPagedItem, _displayIndex: number): void => {
        ListItem() {
          ReaderImagePage({
            imageUrl: NhApiClient.imageUrl(this.detail.mediaId, item.sourceIndex, item.page.extension),
            localImageUri: this.localImageUri(item.page, item.sourceIndex),
            renderedImageUri: this.readerTranslatedImageUri(item.sourceIndex),
            enhancementEnabled: this.readerEnhancementEnabled,
            enhancementModel: this.readerPresentation.superResolutionModel,
            enhancementMaxHeight: this.readerPresentation.superResolutionMaxHeight,
            imageScalingQuality: this.readerPresentation.imageScalingQuality,
            canvasColor: this.readerCanvasColor(),
            canvasContentColor: this.readerCanvasForegroundColor(),
            canvasSecondaryContentColor: this.readerCanvasSecondaryForegroundColor(),
            controlTint: this.readerCanvasControlTint(),
            imageWidth: item.page.width,
            imageHeight: item.page.height,
            pageIndex: item.sourceIndex,
            doubleTapSequence: this.doubleTapSequence,
            doubleTapTargetIndex: this.doubleTapTargetIndex,
            doubleTapX: this.readerDoubleTapX,
            doubleTapY: this.readerDoubleTapY,
            onZoomChange: (zoomed: boolean): void => {
              this.onReaderImageZoomChanged(item.sourceIndex, zoomed)
            },
            onImageLoadStateChanged: (pageIndex: number, loaded: boolean): void => {
              this.onReaderImageLoadStateChanged(pageIndex, loaded)
            },
            onSourceFileReady: (pageIndex: number, localPath: string): void => {
              this.rememberReaderSourceFile(pageIndex, localPath)
            },
            onEnhancementStateChanged: (pageIndex: number, processing: boolean, applied: boolean): void => {
              this.onReaderEnhancementStateChanged(pageIndex, processing, applied)
            },
            cacheKey: ReaderImageCacheService.cacheKey(
              this.detail.id,
              this.detail.mediaId,
              item.page.number,
              item.page.extension,
            ),
          })
        }
        },
        (item: ReaderPagedItem): string => `reader_vertical_${item.sourceIndex}_${item.page.number}`,
      )
    }
    .height('100%')
    .width('100%')
    .backgroundColor(this.readerCanvasColor())
    .cachedCount(3)
    .enableScrollInteraction(this.zoomedPageIndex < 0)
    .onScrollIndex((start: number, _end: number): void => {
      this.onReaderSourceIndexChanged(this.sourceIndexForVerticalDisplayIndex(start))
    })
  }

  @Builder
  private ReaderPagedFlow() {
    Swiper(this.pagedReaderController) {
      LazyForEach(
        this.pageDataSource,
        (item: ReaderPagedItem, _displayIndex: number): void => {
          Stack({ alignContent: Alignment.Center }) {
            ReaderImagePage({
              imageUrl: NhApiClient.imageUrl(this.detail.mediaId, item.sourceIndex, item.page.extension),
              localImageUri: this.localImageUri(item.page, item.sourceIndex),
              renderedImageUri: this.readerTranslatedImageUri(item.sourceIndex),
              enhancementEnabled: this.readerEnhancementEnabled,
              enhancementModel: this.readerPresentation.superResolutionModel,
              enhancementMaxHeight: this.readerPresentation.superResolutionMaxHeight,
              imageScalingQuality: this.readerPresentation.imageScalingQuality,
              canvasColor: this.readerCanvasColor(),
              canvasContentColor: this.readerCanvasForegroundColor(),
              canvasSecondaryContentColor: this.readerCanvasSecondaryForegroundColor(),
              controlTint: this.readerCanvasControlTint(),
              imageWidth: item.page.width,
              imageHeight: item.page.height,
              pageIndex: item.sourceIndex,
              doubleTapSequence: this.doubleTapSequence,
              doubleTapTargetIndex: this.doubleTapTargetIndex,
              doubleTapX: this.readerDoubleTapX,
              doubleTapY: this.readerDoubleTapY,
              onZoomChange: (zoomed: boolean): void => {
                this.onReaderImageZoomChanged(item.sourceIndex, zoomed)
              },
              onImageLoadStateChanged: (pageIndex: number, loaded: boolean): void => {
                this.onReaderImageLoadStateChanged(pageIndex, loaded)
              },
              onSourceFileReady: (pageIndex: number, localPath: string): void => {
                this.rememberReaderSourceFile(pageIndex, localPath)
              },
              onEnhancementStateChanged: (pageIndex: number, processing: boolean, applied: boolean): void => {
                this.onReaderEnhancementStateChanged(pageIndex, processing, applied)
              },
              cacheKey: ReaderImageCacheService.cacheKey(
                this.detail.id,
                this.detail.mediaId,
                item.page.number,
                item.page.extension,
              ),
              fillViewport: true,
            })
          }
          .width('100%')
          .height('100%')
        },
        (item: ReaderPagedItem): string => `reader_page_${item.sourceIndex}_${item.page.number}`,
      )
    }
    .height('100%')
    .width('100%')
    .index(this.pagedDisplayIndexForSourceIndex(this.resumeIndex))
    .loop(false)
    .autoPlay(false)
    .indicator(false)
    .cachedCount(1)
    .vertical(this.isVerticallyPagedMode())
    .disableSwipe(this.zoomedPageIndex >= 0)
    .backgroundColor(this.readerCanvasColor())
    .onChange((index: number): void => {
      this.zoomedPageIndex = -1
      this.onReaderPagedIndexChanged(index)
    })
  }

  /**
   * The spread pager uses a spread data source, never two adjacent pager
   * items. That lets every pager change map once to a canonical spread start
   * before progress, preload, thumbnail selection, or auto-read runs.
   */
  @Builder
  private ReaderDoublePagedFlow() {
    Swiper(this.pagedReaderController) {
      LazyForEach(
        this.spreadDataSource,
        (item: ReaderSpreadItem, _displayIndex: number): void => {
          ReaderSpreadSurface({
            first: item.first,
            second: item.second,
            galleryId: this.detail.id,
            mediaId: this.detail.mediaId,
            firstLocalImageUri: this.localImageUri(item.first.page, item.first.sourceIndex),
            secondLocalImageUri: this.localSpreadSecondImageUri(item),
            firstRenderedImageUri: this.readerTranslatedImageUri(item.first.sourceIndex),
            secondRenderedImageUri: item.second === null ? '' : this.readerTranslatedImageUri(item.second.sourceIndex),
            enhancementEnabled: this.readerEnhancementEnabled,
            enhancementModel: this.readerPresentation.superResolutionModel,
            enhancementMaxHeight: this.readerPresentation.superResolutionMaxHeight,
            imageScalingQuality: this.readerPresentation.imageScalingQuality,
            canvasColor: this.readerCanvasColor(),
            canvasContentColor: this.readerCanvasForegroundColor(),
            controlTint: this.readerCanvasControlTint(),
            spreadLayoutMode: this.readerPresentation.spreadLayoutMode,
            rowReversed: this.isRightToLeftPagedMode(),
            doubleTapSequence: this.doubleTapSequence,
            doubleTapTargetIndex: this.doubleTapTargetIndex,
            doubleTapX: this.readerDoubleTapX,
            doubleTapY: this.readerDoubleTapY,
            onZoomChange: (sourceIndex: number, zoomed: boolean): void => {
              this.onReaderImageZoomChanged(sourceIndex, zoomed)
            },
            onImageLoadStateChanged: (pageIndex: number, loaded: boolean): void => {
              this.onReaderImageLoadStateChanged(pageIndex, loaded)
            },
            onSourceFileReady: (pageIndex: number, localPath: string): void => {
              this.rememberReaderSourceFile(pageIndex, localPath)
            },
            onEnhancementStateChanged: (pageIndex: number, processing: boolean, applied: boolean): void => {
              this.onReaderEnhancementStateChanged(pageIndex, processing, applied)
            },
          })
        },
        (item: ReaderSpreadItem): string => `reader_spread_${item.sourceIndex}_${item.first.page.number}`,
      )
    }
    .height('100%')
    .width('100%')
    .index(this.pagedDisplayIndexForSourceIndex(this.resumeIndex))
    .loop(false)
    .autoPlay(false)
    .indicator(false)
    .cachedCount(1)
    .vertical(false)
    .disableSwipe(this.zoomedPageIndex >= 0)
    .backgroundColor(this.readerCanvasColor())
    .onChange((index: number): void => {
      this.zoomedPageIndex = -1
      this.onReaderPagedIndexChanged(index)
    })
  }

  @Builder
  private ReaderContent() {
    if (this.isPagedMode()) {
      if (this.isDoublePageActive()) {
        this.ReaderDoublePagedFlow()
      } else {
        this.ReaderPagedFlow()
      }
    } else {
      this.ReaderVerticalFlow()
    }
  }

  /** Bottom-stack thumbnail rail. ReaderBottomBar owns the shared chrome surface. */
  @Builder
  private ReaderThumbnailStrip() {
    List({
      space: ThemeTokens.SPACE_SM,
      initialIndex: this.visiblePageIndex,
      scroller: this.thumbnailScroller,
    }) {
      LazyForEach(
        this.thumbnailDataSource,
        (item: ReaderThumbnailItem, _listIndex: number): void => {
          ListItem() {
            ReaderThumbnailTile({
              page: item.page,
              sourceIndex: item.sourceIndex,
              currentIndex: this.visiblePageIndex,
              selected: this.isSourceIndexInCurrentSpread(item.sourceIndex),
              onSelect: (index: number): void => {
                this.selectThumbnail(index)
              },
            })
          }
          .margin({
            left: (this.isRightToLeftPagedMode()
              ? item.sourceIndex === this.detail.pages.length - 1
              : item.sourceIndex === 0) ? READER_THUMB_RAIL_HEAD_TAIL_INSET : 0,
            right: (this.isRightToLeftPagedMode()
              ? item.sourceIndex === 0
              : item.sourceIndex === this.detail.pages.length - 1) ? READER_THUMB_RAIL_HEAD_TAIL_INSET : 0,
          })
        },
        (item: ReaderThumbnailItem): string => `reader_thumbnail_${item.sourceIndex}_${item.page.number}`,
      )
    }
    .listDirection(Axis.Horizontal)
    .direction(this.isRightToLeftPagedMode() ? Direction.Rtl : Direction.Ltr)
    .scrollBar(BarState.Off)
    .width(this.readerThumbnailRailViewportWidth())
    .height(READER_THUMB_STRIP_HEIGHT)
    .translate({ x: -READER_THUMB_RAIL_HEAD_TAIL_INSET })
  }

  private readerThumbnailRailViewportWidth(): string {
    return `calc(100% + ${READER_THUMB_RAIL_HEAD_TAIL_INSET * 2}vp)`
  }

  /** The scrubber stays visible beneath an optional thumbnail rail. */
  @Builder
  private ReaderProgressRow() {
    Row({ space: ThemeTokens.SPACE_SM }) {
      Text(this.readerSliderLeadingLabel())
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_ON_BRAND)
        .constraintSize({ minWidth: READER_PROGRESS_NUMBER_MIN_WIDTH })
        .textAlign(TextAlign.Start)
        .maxLines(1)
      Slider({
        value: this.readerSliderValue,
        min: 1,
        max: Math.max(1, this.detail.pages.length),
        step: this.readerProgressStep(),
        style: SliderStyle.InSet,
        reverse: this.isRightToLeftPagedMode(),
      })
        .layoutWeight(1)
        .trackColor(READER_CONTROL_TINT)
        .selectedColor(ThemeTokens.BRAND)
        .onChange((value: number, mode: SliderChangeMode): void => {
          this.onReaderSliderChanged(value, mode)
        })
      Text(this.readerSliderTrailingLabel())
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_ON_BRAND)
        .constraintSize({ minWidth: READER_PROGRESS_NUMBER_MIN_WIDTH })
        .textAlign(TextAlign.End)
        .maxLines(1)
    }
    .width('100%')
    .height(READER_PROGRESS_OVERLAY_HEIGHT)
    .padding({
      left: ThemeTokens.SPACE_MD,
      right: ThemeTokens.SPACE_MD,
      top: ThemeTokens.SPACE_XS,
      bottom: ThemeTokens.SPACE_XS,
    })
  }

  @Builder
  private ReaderBottomToolbar() {
    Row({ space: ThemeTokens.SPACE_SM }) {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph(this.readerModeIcon(this.readerPresentation.mode))
          .fontSize(22)
          .fontColor([ThemeTokens.TEXT_ON_BRAND])
      }
      .width(READER_BOTTOM_TOOLBAR_HEIGHT)
      .height(READER_BOTTOM_TOOLBAR_HEIGHT)
      .backgroundColor(Color.Transparent)
      .accessibilityText(AppStrings.format('settings_reader_layout_a11y', [this.readerModeLabel()]))
      .onClick((): void => {
        this.readerModeMenuShown = true
      })
      .bindMenu(this.readerModeMenuShown, this.ReaderModeMenu, appMenuOptions({
        placement: Placement.TopRight,
        onDisappear: (): void => {
          this.readerModeMenuShown = false
        },
      }))
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.rectangle_grid_2x1'))
          .fontSize(22)
          .fontColor([this.showThumbnailStrip ? ThemeTokens.BRAND : ThemeTokens.TEXT_ON_BRAND])
      }
      .width(READER_BOTTOM_TOOLBAR_HEIGHT)
      .height(READER_BOTTOM_TOOLBAR_HEIGHT)
      .backgroundColor(Color.Transparent)
      .accessibilityText(this.showThumbnailStrip
        ? AppStrings.get('reader_action_hide_thumbnails')
        : AppStrings.get('reader_action_show_thumbnails'))
      .onClick((): void => {
        this.toggleThumbnailStrip()
      })
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.clock'))
          .fontSize(22)
          .fontColor([this.autoReadActive ? ThemeTokens.BRAND : ThemeTokens.TEXT_ON_BRAND])
      }
      .width(READER_BOTTOM_TOOLBAR_HEIGHT)
      .height(READER_BOTTOM_TOOLBAR_HEIGHT)
      .backgroundColor(Color.Transparent)
      .accessibilityText(this.autoReadActive
        ? AppStrings.get('reader_action_stop_auto_advance')
        : AppStrings.get('reader_action_start_auto_advance'))
      .onClick((): void => {
        this.toggleAutoRead()
      })
      Blank()
    }
    .width('100%')
    .height(READER_BOTTOM_TOOLBAR_HEIGHT)
    .alignItems(VerticalAlign.Center)
  }

  private readerBottomBarHeight(): number {
    const stripHeight: number = this.showThumbnailStrip
      ? READER_THUMB_STRIP_HEIGHT + ThemeTokens.SPACE_SM * 2
      : 0
    return this.readerBottomControlsHeight() + stripHeight
  }

  /** Fixed bottom chrome: progress + toolbar stay anchored while the strip overlays above. */
  private readerBottomControlsHeight(): number {
    return READER_PROGRESS_OVERLAY_HEIGHT + READER_BOTTOM_TOOLBAR_HEIGHT +
      this.layoutSafeArea.bottomAvoidHeight + ThemeTokens.SPACE_SM * 2 + ThemeTokens.SPACE_XS
  }

  /** NextE-shaped bottom chrome: the strip is an overlay layer above a fixed progress/toolbar stack. */
  @Builder
  private ReaderBottomBar() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.ReaderThumbnailStrip()
      }
      .width('100%')
      .height(this.showThumbnailStrip ? READER_THUMB_STRIP_HEIGHT + ThemeTokens.SPACE_SM * 2 : 0)
      .padding({
        top: this.showThumbnailStrip ? ThemeTokens.SPACE_SM : 0,
        bottom: this.showThumbnailStrip ? ThemeTokens.SPACE_SM : 0,
      })
      .margin({
        bottom: this.readerBottomControlsHeight(),
      })
      .backgroundColor(ThemeTokens.OVERLAY_SCRIM)
      .clip(true)
      .hitTestBehavior(this.showThumbnailStrip ? HitTestMode.Default : HitTestMode.None)

      Column({ space: ThemeTokens.SPACE_XS }) {
        this.ReaderProgressRow()
        this.ReaderBottomToolbar()
      }
      .width('100%')
      .height(this.readerBottomControlsHeight())
      .padding({
        left: ThemeTokens.SPACE_MD,
        right: ThemeTokens.SPACE_MD,
        top: ThemeTokens.SPACE_SM,
        bottom: this.layoutSafeArea.bottomAvoidHeight + ThemeTokens.SPACE_SM,
      })
      .backgroundColor(ThemeTokens.OVERLAY_SCRIM)
    }
    .width('100%')
    .height(this.readerBottomBarHeight())
    .layoutGravity(LocalizedAlignment.BOTTOM)
    .hitTestBehavior(HitTestMode.Default)
  }

  @Builder
  private ReaderTapOverlay() {
    Blank()
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
      .onAreaChange((_old: Area, next: Area): void => {
        this.readerTapViewportWidth = next.width as number
        this.readerTapViewportHeight = next.height as number
      })
      .gesture(
        GestureGroup(
          GestureMode.Exclusive,
          TapGesture({ count: 2, distanceThreshold: 8 })
            .onAction((event?: GestureEvent): void => {
              const location = event ? event.tapLocation : undefined
              this.readerDoubleTapX = location
                ? (location.x as number)
                : this.readerTapViewportWidth / 2
              this.readerDoubleTapY = location
                ? (location.y as number)
                : this.readerTapViewportHeight / 2
              this.onReaderDoubleTap()
            }),
          TapGesture({ count: 1 })
            .onAction((event?: GestureEvent): void => {
              this.onReaderSingleTap(event)
            }),
        ),
      )
  }

  private tapZonePreviewRegions(): NhReaderTapZoneRegion[] {
    return NhReaderTapZoneResolver.regions(
      this.readerPresentation.tapZoneLayout,
      this.readerPresentation.tapZoneInvert,
    )
  }

  private tapZonePercent(value: number): string {
    return `${value * 100}%`
  }

  private tapZoneActionColor(action: NhReaderTapZoneAction): ResourceColor {
    if (action === NhReaderTapZoneAction.PREVIOUS) {
      return $r('app.color.reader_tap_zone_previous')
    }
    if (action === NhReaderTapZoneAction.NEXT) {
      return $r('app.color.reader_tap_zone_next')
    }
    if (action === NhReaderTapZoneAction.LEFT) {
      return $r('app.color.reader_tap_zone_left')
    }
    if (action === NhReaderTapZoneAction.RIGHT) {
      return $r('app.color.reader_tap_zone_right')
    }
    return $r('app.color.reader_tap_zone_menu')
  }

  private tapZoneActionLabel(action: NhReaderTapZoneAction): ResourceStr {
    if (action === NhReaderTapZoneAction.PREVIOUS) {
      return AppStrings.get('reader_tap_zone_action_previous')
    }
    if (action === NhReaderTapZoneAction.NEXT) {
      return AppStrings.get('reader_tap_zone_action_next')
    }
    if (action === NhReaderTapZoneAction.LEFT) {
      return AppStrings.get('reader_tap_zone_action_left')
    }
    if (action === NhReaderTapZoneAction.RIGHT) {
      return AppStrings.get('reader_tap_zone_action_right')
    }
    return AppStrings.get('reader_tap_zone_action_menu')
  }

  @Builder
  private ReaderTapZonePreview() {
    Stack() {
      ForEach(
        this.tapZonePreviewRegions(),
        (region: NhReaderTapZoneRegion): void => {
          Stack({ alignContent: Alignment.Center }) {
            Text(this.tapZoneActionLabel(region.action))
              .fontSize(ThemeTokens.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .padding({
                left: ThemeTokens.SPACE_MD,
                right: ThemeTokens.SPACE_MD,
                top: ThemeTokens.SPACE_XS,
                bottom: ThemeTokens.SPACE_XS,
              })
              .backgroundColor(ThemeTokens.OVERLAY_SCRIM)
              .borderRadius(ThemeTokens.RADIUS_ROUND)
          }
          .width(this.tapZonePercent(region.right - region.left))
          .height(this.tapZonePercent(region.bottom - region.top))
          .position({
            x: this.tapZonePercent(region.left),
            y: this.tapZonePercent(region.top),
          })
          .backgroundColor(this.tapZoneActionColor(region.action))
        },
        (region: NhReaderTapZoneRegion): string => region.key,
      )
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Block)
    .onClick((): void => {
      this.tapZonePreviewVisible = false
    })
  }

  /** Uses NextE's exclusive single/double-tap arbitration on one Reader surface. */
  private toggleReaderChrome(): void {
    const nextVisible: boolean = !this.readerChromeVisible
    this.notifyReaderPresentationFor(nextVisible)
    this.getUIContext().animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, (): void => {
      this.readerChromeVisible = nextVisible
      if (!nextVisible) {
        this.showThumbnailStrip = false
        this.readerSliderPreview = -1
        this.readerSliderValue = this.readerSliderCurrentPage()
      }
    })
  }

  private notifyReaderPresentationFor(chromeVisible: boolean): void {
    if (this.onReaderPresentationChanged) {
      this.onReaderPresentationChanged(chromeVisible, this.readerPresentation.fullscreen, this.readerCanvasIsDark())
    }
  }

  private onReaderPagedIndexChanged(displayIndex: number): void {
    this.resumeIndex = this.readerNavigationIndex(this.sourceIndexForPagedDisplayIndex(displayIndex))
    this.onReaderSourceIndexChanged(this.sourceIndexForPagedDisplayIndex(displayIndex))
  }

  private onReaderSourceIndexChanged(index: number): void {
    this.visiblePageIndex = this.readerNavigationIndex(index)
    if (this.readerSliderPreview < 0) {
      this.readerSliderValue = this.visiblePageIndex + 1
    }
    this.scrollThumbnailStripTo(this.visiblePageIndex, true)
    this.persistProgress(this.visiblePageIndex)
    this.scheduleReaderPreload(this.visiblePageIndex)
    this.scheduleReaderTranslationAuto()
    this.awaitAutoReadForVisiblePage()
  }

  /**
   * The ErosN/NextE reader warms a bounded run of upcoming pages. Reuse the
   * existing private cache boundary so preloading shares its in-flight work,
   * byte limits, and atomic file promotion with visible images.
   */
  private scheduleReaderPreload(sourceIndex: number): void {
    const preloadPages: number = this.readerTranslationAutoEnabled
      ? Math.max(1, this.readerPresentation.preloadPages)
      : this.readerPresentation.preloadPages
    if (!this.isReaderReadyForCurrentGallery || preloadPages <= 0 ||
      this.detail.id !== this.galleryId || this.detail.pages.length === 0) {
      return
    }
    const generation: number = this.requestGeneration
    const currentStart: number = this.readerNavigationIndex(sourceIndex)
    const spreadStep: number = this.readerNavigationStep()
    // In double-page mode this setting warms complete upcoming visual
    // destinations. It never preloads just one half of a spread.
    for (let destination: number = 1; destination <= preloadPages; destination += 1) {
      const start: number = currentStart + destination * spreadStep
      if (start >= this.detail.pages.length) {
        break
      }
      const end: number = Math.min(this.detail.pages.length, start + spreadStep)
      for (let index: number = start; index < end; index += 1) {
        const page: NhGalleryPage = this.detail.pages[index]
        if (this.localImageUri(page, index).length > 0) {
          continue
        }
        ReaderImageCacheService.load(
          this.context(),
          NhApiClient.imageUrl(this.detail.mediaId, index, page.extension),
          ReaderImageCacheService.cacheKey(this.detail.id, this.detail.mediaId, page.number, page.extension),
        ).then((result: ReaderImageCacheResult): void => {
          if (this.isCurrentRequest(generation) && this.readerTranslationAutoEnabled &&
            result.localPath.length > 0) {
            this.rememberReaderSourceFile(index, result.localPath)
          }
        }).catch((): void => {
          // Preloading is opportunistic; the visible page retains its own retry affordance.
          if (!this.isCurrentRequest(generation)) {
            return
          }
        })
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.isLoading && this.detail.id === 0) {
        this.ReaderLoadingState()
      } else if (this.errorMessage.length > 0 && this.detail.id === 0) {
        this.ReaderFailureState()
      } else {
        this.ReaderContent()
        this.ReaderTapOverlay()
        if (this.isReaderReadyForCurrentGallery && this.tapZonePreviewVisible) {
          this.ReaderTapZonePreview()
        }
        this.ReaderInlineError()
        this.ReaderTranslationStatusOverlay()
      }
      if (!this.readerChromeVisible && this.isReaderReadyForCurrentGallery) {
        this.ReaderPersistentPageStatus()
      }
      // The top bar overlays the canvas. It must not permanently subtract from
      // the page viewport, which is the source of the old NextN top gutter.
      if (this.readerChromeVisible) {
        this.ReaderHeader()
        if (this.isReaderReadyForCurrentGallery && this.detail.pages.length > 0) {
          this.ReaderBottomBar()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.readerCanvasColor())
    .onAreaChange((_old: Area, next: Area): void => {
      this.onReaderViewportChanged(next.width as number, next.height as number)
    })
    .onTouch((event: TouchEvent): void => {
      this.onReaderSurfaceTouch(event)
    })
    .bindSheet(
      $$this.readerSettingsSheetShown,
      this.settingsSheetContent((): void => {
        this.closeReaderSettings()
      }),
      appSheetOptions({
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        showClose: false,
        onDisappear: (): void => {
          this.closeReaderSettings()
        },
      }),
    )
  }

  private persistProgress(pageIndex: number): void {
    if (!this.isReaderReadyForCurrentGallery || this.detail.id !== this.galleryId || pageIndex === this.lastPersistedIndex) {
      return
    }
    const generation: number = this.requestGeneration
    this.lastPersistedIndex = pageIndex
    // HistoryRepository publishes the clamped index to the retained Detail
    // before serializing the same mutation to RDB.
    HistoryRepository.saveProgress(this.context(), this.detail, pageIndex).catch((error: Error): void => {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      console.warn(`Unable to save local reading progress: ${error.message}`)
      if (this.lastPersistedIndex === pageIndex) {
        this.lastPersistedIndex = -1
      }
    })
  }
}

/**
 * A fixed-height, aspect-aware Reader navigator tile. It uses only page DTO
 * fields already loaded by the Reader and has no independent image request or
 * account behavior.
 */
@ComponentV2
struct ReaderThumbnailTile {
  @Require @Param page: NhGalleryPage
  @Require @Param sourceIndex: number
  @Require @Param currentIndex: number
  @Param selected: boolean = false
  @Event onSelect?: (sourceIndex: number) => void
  @Local isThumbnailLoading: boolean = true
  @Local hasThumbnailError: boolean = false

  aboutToAppear(): void {
    this.resetThumbnailState()
  }

  @Monitor('page')
  onPageChanged(): void {
    this.resetThumbnailState()
  }

  private resetThumbnailState(): void {
    this.isThumbnailLoading = this.page.thumbnailUrl.length > 0
    this.hasThumbnailError = false
  }

  private thumbnailWidth(): number {
    const aspect: number = this.page.width > 0 && this.page.height > 0
      ? this.page.width / this.page.height
      : READER_THUMB_FALLBACK_ASPECT
    const boundedAspect: number = Number.isFinite(aspect)
      ? Math.min(1.4, Math.max(0.45, aspect))
      : READER_THUMB_FALLBACK_ASPECT
    return Math.round(Math.min(
      READER_THUMB_MAX_WIDTH,
      Math.max(READER_THUMB_MIN_WIDTH, READER_THUMB_IMAGE_HEIGHT * boundedAspect),
    ))
  }

  private pageLabel(): string {
    return AppStrings.format('thumbnails_page_label', [(this.sourceIndex + 1).toString()])
  }

  @Builder
  private ThumbnailFallback() {
    if (this.page.thumbnailUrl.length === 0 || this.hasThumbnailError) {
      SymbolGlyph($r('sys.symbol.picture'))
        .fontSize(24)
        .fontColor([ThemeTokens.TEXT_ON_BRAND])
        .opacity(0.62)
    } else if (this.isThumbnailLoading) {
      LoadingProgress()
        .width(20)
        .height(20)
        .color(ThemeTokens.TEXT_ON_BRAND)
    }
  }

  build() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.page.thumbnailUrl.length > 0 && !this.hasThumbnailError) {
          Image(this.page.thumbnailUrl)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .onComplete((): void => {
              this.isThumbnailLoading = false
            })
            .onError((): void => {
              this.isThumbnailLoading = false
              this.hasThumbnailError = true
            })
        }
        this.ThumbnailFallback()
      }
      .width(this.thumbnailWidth())
      .height(READER_THUMB_IMAGE_HEIGHT)
      .backgroundColor(READER_CONTROL_TINT)
      .border({
        width: this.selected ? 2 : 0,
        color: this.selected ? ThemeTokens.BRAND : Color.Transparent,
      })
      .borderRadius(ThemeTokens.THUMB_RADIUS)
      .clip(true)
      Text(this.pageLabel())
        .fontSize(ThemeTokens.FONT_SIZE_META)
        .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.selected ? ThemeTokens.BRAND : ThemeTokens.TEXT_ON_BRAND)
        .opacity(this.selected ? 1 : 0.82)
        .maxLines(1)
        .width(this.thumbnailWidth())
        .textAlign(TextAlign.Center)
    }
    .width(this.thumbnailWidth())
    .height(READER_THUMB_STRIP_HEIGHT)
    .padding({ top: ThemeTokens.SPACE_XS, bottom: ThemeTokens.SPACE_XS })
    .alignItems(HorizontalAlign.Center)
    .accessibilityText(AppStrings.format('reader_thumbnails_open_page_a11y', [(this.sourceIndex + 1).toString()]))
    .onClick((): void => {
      if (this.onSelect) {
        this.onSelect(this.sourceIndex)
      }
    })
}
}
