import { common } from '@kit.AbilityKit'
import { ThemeTokens } from '../theme/ThemeTokens'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { BrowsePresentationState, connectBrowsePresentation } from '../state/BrowsePresentationState'
import { NhBrowsePresentation } from '../model/NhBrowsePresentation'
import { BrowsePresentationService } from '../services/BrowsePresentationService'
import {
  clampGalleryColumnWidth,
  constrainGalleryColumnWidthToOneStep,
  galleryColumnCount,
  supportsGalleryColumnDensity,
} from '../utils/GalleryColumns'
import { isUserScrollSource } from '../utils/ScrollUserInput'

/**
 * Grid counterpart to SecondaryListScaffold.
 *
 * It keeps the HDS title and bottom-safe-area reserves in the scrolling
 * content itself, matching NextE's Grid scaffold instead of pushing the
 * gallery wall inward with static page padding. Content must emit exactly
 * `contentItemCount` GridItems; indexes named by fullRowContentIndexes span
 * the responsive row (for inline notices and a caller-owned tail footer).
 */
@ComponentV2
export struct SecondaryGridScaffold {
  @BuilderParam content: () => void
  layout: LayoutSafeAreaState = connectLayoutSafeArea()
  @Param scroller: Scroller = new Scroller()
  @Param minColumnWidth: number = ThemeTokens.GALLERY_GRID_MIN_WIDTH
  /** Active grid-like presentation whose local min-width override is read. */
  @Param densityMode: NhBrowsePresentation = NhBrowsePresentation.SIMPLE_LIST
  /** Enables the shared two-finger density gesture for an eligible mode. */
  @Param densityEnabled: boolean = false
  browsePresentation: BrowsePresentationState = connectBrowsePresentation()
  private pinchStartWidth: number = 0
  private pinchStartOverrideWidth: number = 0
  private pinchStartColumns: number = 0
  private pinchBoundaryLocked: boolean = false
  private pinchChanged: boolean = false
  @Local measuredWidth: number = 0
  @Param gap: number = ThemeTokens.GALLERY_GRID_GAP
  @Param horizontalPadding: number = ThemeTokens.GALLERY_GRID_GAP
  @Param topPadding: number = 0
  @Param bottomPadding: number = ThemeTokens.LIST_BOTTOM_PADDING
  /** Number of child GridItems provided by content, excluding the two reserves. */
  @Param contentItemCount: number = 0
  /** Zero-based indexes among content items which need one complete grid row. */
  @Param fullRowContentIndexes: number[] = []
  /** The caller has placed its own final full-row footer plus bottom reserve in content. */
  @Param tailReserveInContent: boolean = false
  @Param backToTop: boolean = true
  @Event onReachEnd?: () => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  @Event onUserScroll?: () => void
  @Event onScrollIndex?: (start: number, end: number) => void

  build() {
    Grid(this.scroller, this.gridLayoutOptions()) {
      this.TopSpacer()
      this.content()
      if (!this.tailReserveInContent) {
        this.BottomSpacer()
      }
    }
    .columnsTemplate(this.columnsTemplate())
    .columnsGap(this.gap)
    .rowsGap(this.gap)
    .scrollBar(BarState.Off)
    .backToTop(this.backToTop)
    .width('100%')
    .height('100%')
    .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
    .edgeEffect(EdgeEffect.None)
    .clip(false)
    .gesture(
      PinchGesture({ fingers: 2 })
        .onActionStart((): void => {
          this.beginPinch()
        })
        .onActionUpdate((event: GestureEvent): void => {
          this.applyPinch(event.scale)
        })
        .onActionEnd((): void => {
          this.persistPinch()
        })
        .onActionCancel((): void => {
          this.cancelPinch()
        }),
    )
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      const width: number = Number.parseFloat(`${newValue.width}`)
      if (width > 0 && Math.abs(width - this.measuredWidth) > 0.5) {
        this.measuredWidth = width
      }
    })
    .onDidScroll((_scrollOffset: number, scrollState: ScrollState): void => {
      if (this.onDidScroll) {
        this.onDidScroll(this.scroller.currentOffset().yOffset, scrollState)
      }
    })
    .onWillScroll((_scrollOffset: number, _scrollState: ScrollState, source: ScrollSource): void => {
      if (this.onUserScroll && isUserScrollSource(source)) {
        this.onUserScroll()
      }
    })
    .onScrollIndex((start: number, end: number): void => {
      if (this.onScrollIndex) {
        this.onScrollIndex(start, end)
      }
      if (this.onDidScroll) {
        this.onDidScroll(this.scroller.currentOffset().yOffset, ScrollState.Scroll)
      }
    })
    .onReachEnd((): void => {
      if (this.onReachEnd) {
        this.onReachEnd()
      }
    })
  }

  private columnsTemplate(): string {
    // Keep the untouched NextE auto-fit template for all non-density callers;
    // eligible Browse surfaces resolve their persisted width below.
    if (!this.densityEnabled || !supportsGalleryColumnDensity(this.densityMode)) {
      return `repeat(auto-fit, ${this.minColumnWidth}vp)`
    }
    return `repeat(auto-fit, ${this.effectiveMinColumnWidth()}vp)`
  }

  private effectiveMinColumnWidth(): number {
    if (this.densityEnabled && supportsGalleryColumnDensity(this.densityMode)) {
      const override: number = this.browsePresentation.columnWidthFor(this.densityMode)
      if (override > 0) {
        return override
      }
    }
    return this.minColumnWidth
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private currentColumnCount(): number {
    return galleryColumnCount(
      this.measuredWidth,
      this.effectiveMinColumnWidth(),
      this.gap,
      this.horizontalPadding,
    )
  }

  private beginPinch(): void {
    if (!this.densityEnabled || !supportsGalleryColumnDensity(this.densityMode)) {
      return
    }
    this.pinchStartWidth = this.effectiveMinColumnWidth()
    this.pinchStartOverrideWidth = this.browsePresentation.columnWidthFor(this.densityMode)
    this.pinchStartColumns = this.currentColumnCount()
    this.pinchBoundaryLocked = false
    this.pinchChanged = false
  }

  private applyPinch(scale: number): void {
    if (!this.densityEnabled || !supportsGalleryColumnDensity(this.densityMode) ||
      this.pinchBoundaryLocked || this.measuredWidth <= 0) {
      return
    }
    const desired: number = clampGalleryColumnWidth(this.pinchStartWidth * scale)
    const next: number = constrainGalleryColumnWidthToOneStep(
      this.measuredWidth,
      this.pinchStartColumns,
      desired,
      this.gap,
      this.horizontalPadding,
    )
    if (next === this.effectiveMinColumnWidth()) {
      return
    }
    BrowsePresentationService.setLiveColumnWidth(this.densityMode, next)
    this.pinchChanged = true
    if (this.currentColumnCount() !== this.pinchStartColumns) {
      this.pinchBoundaryLocked = true
    }
  }

  private persistPinch(): void {
    if (this.densityEnabled && supportsGalleryColumnDensity(this.densityMode) && this.pinchChanged) {
      BrowsePresentationService.setColumnWidth(
        this.context(),
        this.densityMode,
        this.effectiveMinColumnWidth(),
      ).catch((): void => {})
    }
    this.resetPinch()
  }

  private resetPinch(): void {
    this.pinchStartOverrideWidth = 0
    this.pinchBoundaryLocked = false
    this.pinchChanged = false
  }

  private cancelPinch(): void {
    if (this.densityEnabled && supportsGalleryColumnDensity(this.densityMode) && this.pinchChanged) {
      // A cancelled gesture must not leave an unpersisted density in AppStorage.
      // Preserve a zero override so the original per-mode base token remains live.
      this.browsePresentation.setColumnWidthFor(this.densityMode, this.pinchStartOverrideWidth)
    }
    this.resetPinch()
  }

  private gridLayoutOptions(): GridLayoutOptions {
    const contentCount: number = Math.max(0, this.contentItemCount)
    const irregularIndexes: number[] = [0]
    this.fullRowContentIndexes.forEach((index: number): void => {
      if (index >= 0 && index < contentCount && !irregularIndexes.includes(index + 1)) {
        irregularIndexes.push(index + 1)
      }
    })
    if (!this.tailReserveInContent) {
      irregularIndexes.push(contentCount + 1)
    }
    return {
      regularSize: [1, 1],
      irregularIndexes: irregularIndexes,
    }
  }

  @Builder
  private TopSpacer() {
    GridItem() {
      Column() {
        Blank().height(this.layout.topAvoidHeight + ThemeTokens.TITLE_BAR_HEIGHT + this.topPadding)
      }
      .width('100%')
    }
    .clip(false)
  }

  @Builder
  private BottomSpacer() {
    GridItem() {
      Column() {
        Blank().height(this.layout.bottomAvoidHeight + this.bottomPadding)
      }
      .width('100%')
    }
    .clip(false)
  }
}
