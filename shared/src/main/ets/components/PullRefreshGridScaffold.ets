import { common } from '@kit.AbilityKit'
import { ThemeTokens } from '../theme/ThemeTokens'
import { NextNPullRefresh, NextNPullRefreshController } from './PullRefresh'
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
 * NextE-derived interactive-refresh Grid host.
 *
 * This intentionally retains NextN's caller-owned tail and BrowsePresentation
 * density contracts: content emits exactly `contentItemCount` items, and an
 * optional tail stays in content rather than being replaced by a generic
 * footer. Only top interactive refresh is added around the existing parent
 * tree; initial load and paging remain caller state.
 */
@ComponentV2
export struct PullRefreshGridScaffold {
  @BuilderParam content: () => void
  layout: LayoutSafeAreaState = connectLayoutSafeArea()
  @Param scroller: Scroller = new Scroller()
  @Param minColumnWidth: number = ThemeTokens.GALLERY_GRID_MIN_WIDTH
  @Param densityMode: NhBrowsePresentation = NhBrowsePresentation.SIMPLE_LIST
  @Param densityEnabled: boolean = false
  browsePresentation: BrowsePresentationState = connectBrowsePresentation()
  private pinchStartWidth: number = 0
  private pinchStartOverrideWidth: number = 0
  private pinchStartColumns: number = 0
  private pinchBoundaryLocked: boolean = false
  private pinchChanged: boolean = false
  @Local measuredWidth: number = 0
  @Param gap: number = ThemeTokens.GALLERY_GRID_GAP
  /** Some established Grid leaves use a looser vertical rhythm than columns. */
  @Param rowGap: number = ThemeTokens.GALLERY_GRID_GAP
  @Param horizontalPadding: number = ThemeTokens.GALLERY_GRID_GAP
  @Param topPadding: number = 0
  @Param bottomPadding: number = ThemeTokens.LIST_BOTTOM_PADDING
  /** Number of child GridItems emitted by content, excluding shared reserves. */
  @Param contentItemCount: number = 0
  /** Zero-based content indexes which span one complete grid row. */
  @Param fullRowContentIndexes: number[] = []
  /** A caller-owned full-width tail is already emitted by content. */
  @Param tailReserveInContent: boolean = false
  @Param backToTop: boolean = true
  @Param controller: NextNPullRefreshController = new NextNPullRefreshController()
  @Param refreshEnabled: boolean = true
  @Local scrollEnabled: boolean = true
  @Event onRefresh?: () => Promise<void>
  @Event onReachEnd?: () => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  @Event onUserScroll?: () => void
  @Event onScrollIndex?: (start: number, end: number) => void

  build() {
    NextNPullRefresh({
      scroller: this.scroller,
      controller: this.controller,
      refreshEnabled: this.refreshEnabled,
      indicatorTop:
        this.layout.topAvoidHeight + ThemeTokens.TITLE_BAR_HEIGHT / 2 + this.topPadding,
      onRefresh: async (): Promise<void> => {
        if (this.onRefresh) {
          await this.onRefresh()
        }
      },
      onScrollEnableChange: (enabled: boolean): void => {
        this.scrollEnabled = enabled
      },
    }) {
      Grid(this.scroller, this.gridLayoutOptions()) {
        this.TopSpacer()
        this.content()
        if (!this.tailReserveInContent) {
          this.BottomSpacer()
        }
      }
      .columnsTemplate(this.columnsTemplate())
      .columnsGap(this.gap)
      .rowsGap(this.rowGap)
      .scrollBar(BarState.Off)
      .backToTop(this.backToTop)
      .enableScrollInteraction(this.scrollEnabled)
      .width('100%')
      .height('100%')
      .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
      // The outer PullRefresh state machine owns edge feedback.
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
        this.notifyReachEnd()
      })
    }
  }

  private columnsTemplate(): string {
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

  private notifyReachEnd(): void {
    if (this.onReachEnd) {
      this.onReachEnd()
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
