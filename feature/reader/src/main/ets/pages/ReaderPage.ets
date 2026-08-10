import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier, window } from '@kit.ArkUI'
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
  NhGalleryShareService,
  NhReaderMode,
  NhReaderTapZoneAction,
  NhReaderTapZoneInvert,
  NhReaderTapZoneLayout,
  NhReaderTapZoneResolver,
  DownloadQueueService,
  ReaderImageCacheResult,
  ReaderImageCacheService,
  ReaderSuperResolutionService,
  ReaderPresentationService,
  ReaderPresentationState,
  ReaderOverlayNavigationState,
  LayoutSafeAreaState,
  ThemeTokens,
  connectLayoutSafeArea,
  connectReaderPresentation,
  connectReaderOverlayNavigation,
} from 'shared'

// Reader controls are drawn over a dark canvas. Keep their affordance neutral
// so a recovery action does not read like a primary app-level CTA.
const READER_CONTROL_TINT: ResourceColor = '#26FFFFFF'
const READER_MAX_ZOOM_SCALE: number = 4
const READER_ZOOM_EPSILON: number = 1.01
const READER_ZOOM_ANIMATION_MS: number = 180
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
// Keep the decision local to the Reader canvas. This is deliberately not a
// device-class or global-layout check: split windows and rotation can change
// the same route between a single page and a spread without changing the
// persisted user request.
const READER_DOUBLE_PAGE_MIN_VIEWPORT_WIDTH: number = 720
const READER_DOUBLE_PAGE_MIN_WIDE_ASPECT: number = 1.15

/** Small NextE-derived zoom boundary for one rendered Reader page. */
class ReaderPageZoom {
  static isZoomed(scale: number): boolean {
    return scale > READER_ZOOM_EPSILON
  }

  static clampScale(value: number): number {
    if (!Number.isFinite(value) || value <= 1) {
      return 1
    }
    return Math.min(READER_MAX_ZOOM_SCALE, value)
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

  static isWideViewport(width: number, height: number): boolean {
    return Number.isFinite(width) && Number.isFinite(height) &&
      width >= READER_DOUBLE_PAGE_MIN_VIEWPORT_WIDTH &&
      width >= height * READER_DOUBLE_PAGE_MIN_WIDE_ASPECT
  }

  static isDoublePage(
    mode: NhReaderMode,
    requested: boolean,
    viewportWidth: number,
    viewportHeight: number,
  ): boolean {
    return requested && ReaderSpreadResolver.supports(mode) &&
      ReaderSpreadResolver.isWideViewport(viewportWidth, viewportHeight)
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
  @Param enhancementEnabled: boolean = false
  @Param fillViewport: boolean = false
  @Param imageWidth: number = 0
  @Param imageHeight: number = 0
  @Param pageIndex: number = -1
  @Param doubleTapSequence: number = 0
  @Param doubleTapTargetIndex: number = -1
  @Event onZoomChange?: (zoomed: boolean) => void
  @Event onImageLoadStateChanged?: (pageIndex: number, loaded: boolean) => void
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
  private loadGeneration: number = 0
  private pinchStartScale: number = 1
  private panStartOffsetX: number = 0
  private panStartOffsetY: number = 0
  private isPinching: boolean = false
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

  @Monitor('enhancementEnabled')
  onEnhancementEnabledChanged(): void {
    this.loadImage()
  }

  // NextE dispatches double taps from the Reader surface rather than asking a
  // scrolling List/Swiper child to win the recognizer race. Only the visible
  // target page consumes the sequence command.
  @Monitor('doubleTapSequence')
  onDoubleTapCommand(): void {
    if (this.doubleTapSequence > 0 && this.pageIndex === this.doubleTapTargetIndex) {
      this.toggleDoubleTapZoom()
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

  private enhancementOwnerKey(): string {
    return `reader-image:${this.cacheKey}:${this.pageIndex}`
  }

  private async applyEnhancement(generation: number, localPath: string): Promise<void> {
    if (!this.enhancementEnabled || localPath.length === 0) {
      return
    }
    const result = await ReaderSuperResolutionService.process(
      this.context(),
      localPath,
      this.enhancementOwnerKey(),
      true,
    )
    if (this.isCurrentLoad(generation) && result.applied) {
      this.imageSource = result.displayUri
    }
  }

  private async loadImage(forceReload: boolean = false): Promise<void> {
    const generation: number = this.loadGeneration + 1
    this.loadGeneration = generation
    this.hasLoadError = false
    this.isRetrying = forceReload
    this.isLoading = true
    this.imageSource = ''
    this.notifyImageLoadState(false)
    this.resetZoom()
    this.notifyZoom()
    if (this.localImageUri.length > 0) {
      this.imageSource = this.localImageUri
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
        this.imageWidth,
        this.imageHeight,
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
        this.imageWidth,
        this.imageHeight,
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

  private toggleDoubleTapZoom(): void {
    this.beginZoomAnimation()
    if (ReaderPageZoom.isZoomed(this.zoomScale)) {
      this.resetZoom()
    } else {
      this.zoomScale = 2
      this.zoomOffsetX = 0
      this.zoomOffsetY = 0
    }
    this.notifyZoom()
  }

  @Builder
  private ImageRecovery() {
    if (this.hasLoadError || this.isRetrying || this.isLoading) {
      Column({ space: ThemeTokens.SPACE_SM }) {
        if (this.isRetrying || this.isLoading) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(ThemeTokens.TEXT_ON_BRAND)
          Text(this.isRetrying
            ? AppStrings.get('reader_status_retrying_image')
            : AppStrings.get('reader_status_loading_image'))
            .fontSize(ThemeTokens.FONT_SIZE_META)
            .fontColor(ThemeTokens.TEXT_ON_BRAND)
            .opacity(0.82)
        } else {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
            .fontSize(32)
            .fontColor([ThemeTokens.TEXT_ON_BRAND])
            .opacity(0.84)
          Text(AppStrings.get('reader_error_image_unavailable'))
            .fontSize(ThemeTokens.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.TEXT_ON_BRAND)
          Text(AppStrings.get('reader_retry_connection'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_ON_BRAND)
            .opacity(0.76)
            .textAlign(TextAlign.Center)
          Button(AppStrings.get('reader_action_retry'))
            .type(ButtonType.Capsule)
            .height(ThemeTokens.MIN_TOUCH_TARGET)
            .backgroundColor(READER_CONTROL_TINT)
            .fontColor(ThemeTokens.TEXT_ON_BRAND)
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
        .backgroundColor(ThemeTokens.READER_BACKGROUND)
        .onComplete((): void => {
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
    .backgroundColor(ThemeTokens.READER_BACKGROUND)
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
          .onActionStart((): void => {
            this.isPinching = true
            this.ignorePanSequence = true
            this.zoomAnimating = false
            this.pinchStartScale = this.zoomScale
          })
          .onActionUpdate((event?: GestureEvent): void => {
            if (!event) {
              return
            }
            this.zoomScale = ReaderPageZoom.clampScale(this.pinchStartScale * (event.scale as number))
            this.clampZoomOffset()
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
  @Param enhancementEnabled: boolean = false
  @Param pageIndex: number = -1
  @Event onImageLoadStateChanged?: (pageIndex: number, loaded: boolean) => void
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

  @Monitor('enhancementEnabled')
  onEnhancementEnabledChanged(): void {
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

  private enhancementOwnerKey(): string {
    return `reader-spread:${this.cacheKey}:${this.pageIndex}`
  }

  private async applyEnhancement(generation: number, localPath: string): Promise<void> {
    if (!this.enhancementEnabled || localPath.length === 0) {
      return
    }
    const result = await ReaderSuperResolutionService.process(
      this.context(),
      localPath,
      this.enhancementOwnerKey(),
      true,
    )
    if (generation === this.loadGeneration && result.applied) {
      this.imageSource = result.displayUri
    }
  }

  private async loadImage(forceReload: boolean = false): Promise<void> {
    const generation: number = this.loadGeneration + 1
    this.loadGeneration = generation
    this.hasLoadError = false
    this.isRetrying = forceReload
    this.isLoading = true
    this.imageSource = ''
    this.notifyImageLoadState(false)
    if (this.localImageUri.length > 0) {
      this.imageSource = this.localImageUri
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
            .color(ThemeTokens.TEXT_ON_BRAND)
        } else {
          SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
            .fontSize(28)
            .fontColor([ThemeTokens.TEXT_ON_BRAND])
            .opacity(0.84)
          Text(AppStrings.get('reader_error_image_unavailable'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_ON_BRAND)
            .textAlign(TextAlign.Center)
          Button(AppStrings.get('reader_action_retry'))
            .type(ButtonType.Capsule)
            .height(ThemeTokens.MIN_TOUCH_TARGET)
            .backgroundColor(READER_CONTROL_TINT)
            .fontColor(ThemeTokens.TEXT_ON_BRAND)
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
          .backgroundColor(ThemeTokens.READER_BACKGROUND)
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
    .backgroundColor(ThemeTokens.READER_BACKGROUND)
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
  @Param enhancementEnabled: boolean = false
  @Param rowReversed: boolean = false
  @Param doubleTapSequence: number = 0
  @Param doubleTapTargetIndex: number = -1
  @Event onZoomChange?: (sourceIndex: number, zoomed: boolean) => void
  @Event onImageLoadStateChanged?: (pageIndex: number, loaded: boolean) => void
  @Local zoomScale: number = 1
  @Local zoomOffsetX: number = 0
  @Local zoomOffsetY: number = 0
  @Local zoomAnimating: boolean = false
  @Local viewportWidth: number = 0
  @Local viewportHeight: number = 0
  private pinchStartScale: number = 1
  private panStartOffsetX: number = 0
  private panStartOffsetY: number = 0
  private isPinching: boolean = false
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
      this.toggleDoubleTapZoom()
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

  /**
   * A two-page spread is one joined frame, not two equal half viewports.
   * Page DTO dimensions are already loaded by the Reader; use their ratio to
   * fit both leaves together inside the actual canvas.
   */
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

  private joinedFrameWidth(): number {
    return this.joinedFrameHeight() * this.joinedAspect()
  }

  private paneWidthFor(item: ReaderPagedItem): number {
    return this.joinedFrameHeight() * this.pageAspect(item)
  }

  private fittedSpreadWidth(): number {
    return this.joinedFrameWidth()
  }

  private fittedSpreadHeight(): number {
    return this.joinedFrameHeight()
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

  private toggleDoubleTapZoom(): void {
    this.beginZoomAnimation()
    if (ReaderPageZoom.isZoomed(this.zoomScale)) {
      this.resetZoom()
    } else {
      this.zoomScale = 2
      this.zoomOffsetX = 0
      this.zoomOffsetY = 0
    }
    this.notifyZoom()
  }

  @Builder
  private SpreadImage(item: ReaderPagedItem, localImageUri: string) {
    ReaderSpreadImageLayer({
      imageUrl: NhApiClient.imageUrl(this.mediaId, item.sourceIndex, item.page.extension),
      localImageUri,
      enhancementEnabled: this.enhancementEnabled,
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
    })
  }

  @Builder
  private SpreadPane(item: ReaderPagedItem, localImageUri: string) {
    Column() {
      this.SpreadImage(item, localImageUri)
    }
    .width(this.paneWidthFor(item))
    .height(this.joinedFrameHeight())
  }

  @Builder
  private SpreadImages() {
    Row() {
      if (this.rowReversed && this.second !== null) {
        this.SpreadPane(this.second, this.secondLocalImageUri)
      }
      this.SpreadPane(this.first, this.firstLocalImageUri)
      if (!this.rowReversed && this.second !== null) {
        this.SpreadPane(this.second, this.secondLocalImageUri)
      }
    }
    .width(this.joinedFrameWidth())
    .height(this.joinedFrameHeight())
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
    .backgroundColor(ThemeTokens.READER_BACKGROUND)
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
          .onActionStart((): void => {
            this.isPinching = true
            this.ignorePanSequence = true
            this.zoomAnimating = false
            this.pinchStartScale = this.zoomScale
          })
          .onActionUpdate((event?: GestureEvent): void => {
            if (!event) {
              return
            }
            this.zoomScale = ReaderPageZoom.clampScale(this.pinchStartScale * (event.scale as number))
            this.clampZoomOffset()
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
  @Local zoomedPageIndex: number = -1
  @Local doubleTapSequence: number = 0
  @Local doubleTapTargetIndex: number = -1
  @Local readerViewportWidth: number = 0
  @Local readerViewportHeight: number = 0
  @Event onBack?: () => void
  @Event onReaderPresentationChanged?: (chromeVisible: boolean, fullscreen: boolean) => void
  @Local readerPresentation: ReaderPresentationState = connectReaderPresentation()
  private layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  private readerOverlay: ReaderOverlayNavigationState = connectReaderOverlayNavigation()
  private lastPersistedIndex: number = -1
  private requestGeneration: number = 0
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
  private lastDoublePageActive: boolean = false
  private readerDoubleTapX: number = 0

  aboutToAppear(): void {
    this.loadReaderSettings()
  }

  aboutToDisappear(): void {
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

  /** Effective spread mode is a live Reader-canvas decision, never a global device flag. */
  private isDoublePageActive(): boolean {
    return ReaderSpreadResolver.isDoublePage(
      this.readerPresentation.mode,
      this.readerPresentation.doublePageEnabled,
      this.readerViewportWidth,
      this.readerViewportHeight,
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
    this.lastDoublePageActive = this.isDoublePageActive()
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

  /**
   * A narrow fallback changes only the current renderer. The persisted switch
   * is intentionally untouched, so returning to a wide local canvas restores
   * the exact paired spread model without another user action.
   */
  private onReaderViewportChanged(width: number, height: number): void {
    this.readerViewportWidth = Math.max(0, width)
    this.readerViewportHeight = Math.max(0, height)
    const nextDoublePageActive: boolean = this.isDoublePageActive()
    if (nextDoublePageActive === this.lastDoublePageActive) {
      return
    }
    if (!this.isReaderReadyForCurrentGallery) {
      this.lastDoublePageActive = nextDoublePageActive
      return
    }
    this.applyReaderSpreadPresentation()
  }

  private async loadReaderSettings(): Promise<void> {
    try {
      await ReaderPresentationService.restore(this.context())
    } catch (_error) {
      // The shared state deliberately retains its local defaults if durable
      // restoration is temporarily unavailable; Reader remains usable.
    }
    this.readerPresentationReady = true
    this.syncVolumeKeyConsumer()
    this.notifyReaderPresentation()
    this.applyWindowPolicy()
    this.loadReader()
  }

  private notifyReaderPresentation(): void {
    if (this.onReaderPresentationChanged) {
      this.onReaderPresentationChanged(this.readerChromeVisible, this.readerPresentation.fullscreen)
    }
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
        throw new Error('Reader response did not match the requested gallery.')
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
      this.errorMessage = (error as Error).message || AppStrings.get('reader_error_load_pages')
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
    this.turnToReaderPage(target)
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
    this.turnToReaderPage(target)
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
  }

  private closeReaderSettings(): void {
    this.readerSettingsSheetShown = false
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
      MenuItem({
        content: AppStrings.get('settings_reader'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.gearshape')),
      }).onClick((): void => {
        this.openReaderSettings()
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

  private turnToReaderPage(index: number): void {
    const target: number = this.readerNavigationIndex(index)
    if (this.isPagedMode()) {
      try {
        this.pagedReaderController.changeIndex(this.pagedDisplayIndexForSourceIndex(target), true)
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
    this.turnToReaderPage(target)
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
    this.turnToReaderPage(target)
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
    this.turnToReaderPage(target)
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
        .bindMenu(this.readerOverflowMenuShown, this.ReaderOverflowMenu, {
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.readerOverflowMenuShown = false
          },
        })
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
        .color(ThemeTokens.TEXT_ON_BRAND)
      Text(AppStrings.get('reader_status_preparing_reader'))
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_ON_BRAND)
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
        .fontColor([ThemeTokens.TEXT_ON_BRAND])
        .opacity(0.84)
      Text(this.errorMessage)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_ON_BRAND)
        .opacity(0.78)
        .textAlign(TextAlign.Center)
        .maxLines(3)
      Button(AppStrings.get('reader_action_retry'))
        .type(ButtonType.Capsule)
        .height(ThemeTokens.ACTION_HEIGHT)
        .backgroundColor(READER_CONTROL_TINT)
        .fontColor(ThemeTokens.TEXT_ON_BRAND)
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
          .fontColor(ThemeTokens.TEXT_ON_BRAND)
          .opacity(0.74)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Button(AppStrings.get('reader_action_retry'))
          .type(ButtonType.Capsule)
          .height(32)
          .backgroundColor(READER_CONTROL_TINT)
          .fontColor(ThemeTokens.TEXT_ON_BRAND)
          .onClick((): void => {
            this.loadReader()
          })
      }
      .width('100%')
      .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD, bottom: ThemeTokens.SPACE_MD })
      .backgroundColor(ThemeTokens.READER_BACKGROUND)
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
            enhancementEnabled: this.readerPresentation.superResolutionEnabled,
            imageWidth: item.page.width,
            imageHeight: item.page.height,
            pageIndex: item.sourceIndex,
            doubleTapSequence: this.doubleTapSequence,
            doubleTapTargetIndex: this.doubleTapTargetIndex,
            onZoomChange: (zoomed: boolean): void => {
              this.onReaderImageZoomChanged(item.sourceIndex, zoomed)
            },
            onImageLoadStateChanged: (pageIndex: number, loaded: boolean): void => {
              this.onReaderImageLoadStateChanged(pageIndex, loaded)
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
    .backgroundColor(ThemeTokens.READER_BACKGROUND)
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
              enhancementEnabled: this.readerPresentation.superResolutionEnabled,
              imageWidth: item.page.width,
              imageHeight: item.page.height,
              pageIndex: item.sourceIndex,
              doubleTapSequence: this.doubleTapSequence,
              doubleTapTargetIndex: this.doubleTapTargetIndex,
              onZoomChange: (zoomed: boolean): void => {
                this.onReaderImageZoomChanged(item.sourceIndex, zoomed)
              },
              onImageLoadStateChanged: (pageIndex: number, loaded: boolean): void => {
                this.onReaderImageLoadStateChanged(pageIndex, loaded)
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
    .backgroundColor(ThemeTokens.READER_BACKGROUND)
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
            enhancementEnabled: this.readerPresentation.superResolutionEnabled,
            rowReversed: this.isRightToLeftPagedMode(),
            doubleTapSequence: this.doubleTapSequence,
            doubleTapTargetIndex: this.doubleTapTargetIndex,
            onZoomChange: (sourceIndex: number, zoomed: boolean): void => {
              this.onReaderImageZoomChanged(sourceIndex, zoomed)
            },
            onImageLoadStateChanged: (pageIndex: number, loaded: boolean): void => {
              this.onReaderImageLoadStateChanged(pageIndex, loaded)
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
    .backgroundColor(ThemeTokens.READER_BACKGROUND)
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
      .bindMenu(this.readerModeMenuShown, this.ReaderModeMenu, {
        placement: Placement.TopRight,
        onDisappear: (): void => {
          this.readerModeMenuShown = false
        },
      })
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
    const thumbnailHeight: number = this.showThumbnailStrip
      ? READER_THUMB_STRIP_HEIGHT + ThemeTokens.SPACE_SM
      : 0
    return thumbnailHeight + READER_PROGRESS_OVERLAY_HEIGHT + READER_BOTTOM_TOOLBAR_HEIGHT +
      this.layoutSafeArea.bottomAvoidHeight + ThemeTokens.SPACE_SM * 2 + ThemeTokens.SPACE_XS
  }

  /** One NextE-shaped bottom chrome: optional strip, scrubber, then controls. */
  @Builder
  private ReaderBottomBar() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      if (this.showThumbnailStrip) {
        this.ReaderThumbnailStrip()
      }
      this.ReaderProgressRow()
      this.ReaderBottomToolbar()
    }
    .width('100%')
    .height(this.readerBottomBarHeight())
    .padding({
      left: ThemeTokens.SPACE_MD,
      right: ThemeTokens.SPACE_MD,
      top: ThemeTokens.SPACE_SM,
      bottom: this.layoutSafeArea.bottomAvoidHeight + ThemeTokens.SPACE_SM,
    })
    .backgroundColor(ThemeTokens.OVERLAY_SCRIM)
    .clip(true)
    .layoutGravity(LocalizedAlignment.BOTTOM)
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
              this.onReaderDoubleTap()
            }),
          TapGesture({ count: 1 })
            .onAction((event?: GestureEvent): void => {
              this.onReaderSingleTap(event)
            }),
        ),
      )
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
      this.onReaderPresentationChanged(chromeVisible, this.readerPresentation.fullscreen)
    }
  }

  private onReaderPagedIndexChanged(displayIndex: number): void {
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
    this.awaitAutoReadForVisiblePage()
  }

  /**
   * The ErosN/NextE reader warms a bounded run of upcoming pages. Reuse the
   * existing private cache boundary so preloading shares its in-flight work,
   * byte limits, and atomic file promotion with visible images.
   */
  private scheduleReaderPreload(sourceIndex: number): void {
    if (!this.isReaderReadyForCurrentGallery || this.readerPresentation.preloadPages <= 0 ||
      this.detail.id !== this.galleryId || this.detail.pages.length === 0) {
      return
    }
    const generation: number = this.requestGeneration
    const currentStart: number = this.readerNavigationIndex(sourceIndex)
    const spreadStep: number = this.readerNavigationStep()
    // In double-page mode this setting warms complete upcoming visual
    // destinations. It never preloads just one half of a spread.
    for (let destination: number = 1; destination <= this.readerPresentation.preloadPages; destination += 1) {
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
        ).then((): void => {
          // Completed requests are already atomically stored by ReaderImageCacheService.
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
        this.ReaderInlineError()
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
    .backgroundColor(ThemeTokens.READER_BACKGROUND)
    .onAreaChange((_old: Area, next: Area): void => {
      this.onReaderViewportChanged(next.width as number, next.height as number)
    })
    .bindSheet(
      $$this.readerSettingsSheetShown,
      this.settingsSheetContent((): void => {
        this.closeReaderSettings()
      }),
      {
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        showClose: false,
        onDisappear: (): void => {
          this.closeReaderSettings()
        },
      },
    )
  }

  private persistProgress(pageIndex: number): void {
    if (!this.isReaderReadyForCurrentGallery || this.detail.id !== this.galleryId || pageIndex === this.lastPersistedIndex) {
      return
    }
    const generation: number = this.requestGeneration
    this.lastPersistedIndex = pageIndex
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
