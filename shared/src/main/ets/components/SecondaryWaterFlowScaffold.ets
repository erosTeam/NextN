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

const WATER_FLOW_CACHE_ROWS: number = 2
const WATER_FLOW_MAX_CACHE_ITEMS: number = 8

/**
 * Shared WaterFlow host for cover-wall/masonry destinations.
 *
 * The scaffold deliberately owns only presentation geometry and scroll
 * signals. Callers emit one FlowItem per content item and provide the item
 * count so the native WaterFlow section model can reserve a full-width top and
 * tail item without changing the caller's data or pagination state.
 */
@ComponentV2
export struct SecondaryWaterFlowScaffold {
  @BuilderParam content: () => void
  layout: LayoutSafeAreaState = connectLayoutSafeArea()
  @Param scroller: Scroller = new Scroller()
  @Param minColumnWidth: number = ThemeTokens.GALLERY_GRID_MIN_WIDTH
  /** Active WaterFlow presentation whose local min-width override is read. */
  @Param densityMode: NhBrowsePresentation = NhBrowsePresentation.SIMPLE_LIST
  /** Enables the shared two-finger density gesture for an eligible mode. */
  @Param densityEnabled: boolean = false
  browsePresentation: BrowsePresentationState = connectBrowsePresentation()
  private pinchStartWidth: number = 0
  private pinchStartOverrideWidth: number = 0
  private pinchStartColumns: number = 0
  private pinchBoundaryLocked: boolean = false
  private pinchChanged: boolean = false
  @Param gap: number = ThemeTokens.GALLERY_GRID_GAP
  @Param horizontalPadding: number = ThemeTokens.GALLERY_GRID_GAP
  @Param topPadding: number = 0
  @Param bottomPadding: number = ThemeTokens.LIST_BOTTOM_PADDING
  /** Number of FlowItems emitted by content, including any caller-owned tail item. */
  @Param contentItemCount: number = 0
  /** Zero-based content indexes that need a complete WaterFlow row. */
  @Param fullRowContentIndexes: number[] = []
  /** If true, content emits its own final full-width tail reserve. */
  @Param tailReserveInContent: boolean = false
  @Param cachedCount: number = 0
  @Param nearEndThreshold: number = 0
  @Param backToTop: boolean = true
  @Local measuredWidth: number = 0
  @Event onReachEnd?: () => void
  @Event onNearEnd?: () => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  @Event onUserScroll?: () => void
  @Event onScrollIndex?: (start: number, end: number) => void
  @Event onListAreaChange?: (area: Area) => void

  build() {
    WaterFlow({
      scroller: this.scroller,
      sections: this.waterFlowSections(),
      layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW,
    }) {
      this.TopSpacer()
      this.content()
      if (!this.tailReserveInContent) {
        this.BottomSpacer()
      }
    }
    .columnsGap(this.gap)
    .rowsGap(this.gap)
    .cachedCount(this.effectiveCachedCount(), false)
    .backToTop(this.backToTop)
    .scrollBar(BarState.Off)
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
      if (this.onListAreaChange) {
        this.onListAreaChange(newValue)
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
      this.maybeNotifyNearEnd(end)
    })
    .onReachEnd((): void => {
      this.notifyReachEnd()
    })
  }

  private waterFlowSections(): WaterFlowSections {
    const sections: WaterFlowSections = new WaterFlowSections()
    const options: SectionOptions[] = []
    options.push({
      itemsCount: 1,
      crossCount: 1,
      rowsGap: 0,
      columnsGap: 0,
    })
    const itemCount: number = Math.max(0, this.contentItemCount)
    const fullRows: number[] = this.normalizedFullRowIndexes(itemCount)
    let cursor: number = 0
    fullRows.forEach((index: number): void => {
      if (index > cursor) {
        options.push(this.contentSection(index - cursor))
      }
      options.push(this.fullRowSection())
      cursor = index + 1
    })
    if (cursor < itemCount) {
      options.push(this.contentSection(itemCount - cursor))
    }
    if (!this.tailReserveInContent) {
      options.push({
        itemsCount: 1,
        crossCount: 1,
        rowsGap: 0,
        columnsGap: 0,
      })
    }
    sections.splice(0, 0, options)
    return sections
  }

  private normalizedFullRowIndexes(itemCount: number): number[] {
    const indexes: number[] = []
    this.fullRowContentIndexes.forEach((index: number): void => {
      if (index >= 0 && index < itemCount && !indexes.includes(index)) {
        indexes.push(index)
      }
    })
    indexes.sort((left: number, right: number): number => left - right)
    if (this.tailReserveInContent && itemCount > 0 && !indexes.includes(itemCount - 1)) {
      indexes.push(itemCount - 1)
    }
    return indexes
  }

  private contentSection(itemCount: number): SectionOptions {
    return {
      itemsCount: itemCount,
      crossCount: this.contentColumnCount(),
      rowsGap: this.gap,
      columnsGap: this.gap,
    }
  }

  private fullRowSection(): SectionOptions {
    return {
      itemsCount: 1,
      crossCount: 1,
      rowsGap: 0,
      columnsGap: 0,
    }
  }

  private contentColumnCount(): number {
    return galleryColumnCount(
      this.measuredWidthFallback(),
      this.effectiveMinColumnWidth(),
      this.gap,
      this.horizontalPadding,
    )
  }

  private measuredWidthFallback(): number {
    // WaterFlow sections are created before the first area callback. Two
    // columns is the same conservative first-frame fallback used by NextE;
    // the area callback then rebuilds sections for the measured width.
    if (this.measuredWidth > 0) {
      return this.measuredWidth
    }
    return this.effectiveMinColumnWidth() * 2 + this.horizontalPadding * 2 + this.gap
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

  private effectiveCachedCount(): number {
    if (this.cachedCount > 0) {
      return this.cachedCount
    }
    return Math.min(
      WATER_FLOW_MAX_CACHE_ITEMS,
      Math.max(1, this.contentColumnCount() * WATER_FLOW_CACHE_ROWS),
    )
  }

  private maybeNotifyNearEnd(end: number): void {
    const itemCount: number = Math.max(0, this.contentItemCount)
    const threshold: number = Math.max(0, Math.floor(this.nearEndThreshold))
    if (itemCount <= 0 || threshold <= 0 || end < itemCount - 1 - threshold) {
      return
    }
    if (this.onNearEnd) {
      this.onNearEnd()
    }
  }

  private notifyReachEnd(): void {
    if (this.onReachEnd) {
      this.onReachEnd()
    }
  }

  @Builder
  private TopSpacer() {
    FlowItem() {
      Column() {
        Blank().height(this.layout.topAvoidHeight + ThemeTokens.TITLE_BAR_HEIGHT + this.topPadding)
      }
      .width('100%')
    }
    .width('100%')
    .clip(false)
  }

  @Builder
  private BottomSpacer() {
    FlowItem() {
      Column() {
        Blank().height(this.layout.bottomAvoidHeight + this.bottomPadding)
      }
      .width('100%')
    }
    .width('100%')
    .clip(false)
    .onAppear((): void => {
      // Native WaterFlow may not deliver onReachEnd when the tail is already
      // visible; the tail reserve is therefore a safe bounded fallback.
      if (this.contentItemCount > 0) {
        this.notifyReachEnd()
      }
    })
  }
}
