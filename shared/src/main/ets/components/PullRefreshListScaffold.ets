import { ThemeTokens } from '../theme/ThemeTokens'
import { NextNPullRefresh, NextNPullRefreshController } from './PullRefresh'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { currentScrollOffsetY, isUserScrollSource } from '../utils/ScrollUserInput'

/**
 * Interactive-refresh List host derived from NextE's PullRefreshListScaffold.
 *
 * Its caller retains ownership of initial loading, empty/error content and
 * pagination. `onRefresh` is invoked only by a deliberate edge pull or this
 * component's controller; it is never an appear-time load signal.
 */
@ComponentV2
export struct PullRefreshListScaffold {
  @BuilderParam content: () => void
  layout: LayoutSafeAreaState = connectLayoutSafeArea()
  @Param scroller: Scroller = new Scroller()
  @Param listSpace: number = ThemeTokens.SPACE_SM - 2
  @Param horizontalPadding: number = ThemeTokens.LIST_HORIZONTAL_PADDING
  @Param topPadding: number = 0
  @Param bottomPadding: number = ThemeTokens.LIST_BOTTOM_PADDING
  @Param stickyHeaders: boolean = false
  /** Kept compatible with SecondaryListScaffold; active pull uses a single edge owner. */
  @Param alwaysEnableEdgeSpring: boolean = false
  @Param backToTop: boolean = true
  /** Shared controller for a root re-tap or another programmatic refresh. */
  @Param controller: NextNPullRefreshController = new NextNPullRefreshController()
  /** Does not govern caller-owned initial loading or page state. */
  @Param refreshEnabled: boolean = true
  /** Number of real rows, excluding this host's immersive top/bottom reserves. */
  @Param itemCount: number = 0
  /** Lets gallery-list callers receive indexes without the two shared reserves. */
  @Param normalizeContentIndexes: boolean = false
  @Param indicatorTop: number = -1
  @Local scrollEnabled: boolean = true
  @Local measuredWidth: number = 0
  @Event onRefresh?: () => Promise<void>
  @Event onBottomRefresh?: () => Promise<void>
  @Event canStartBottomRefresh?: () => boolean
  @Event onScrollEnableChange?: (enabled: boolean) => void
  @Event onReachEnd?: () => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  @Event onUserScroll?: () => void
  @Event onListAreaChange?: (area: Area) => void
  @Event onContentWidth?: (contentWidth: number) => void
  @Event onScrollIndex?: (start: number, end: number, center: number) => void
  /** Optional observational hook for a caller that owns a scroll-derived action. */
  @Event onScrollTouch?: (event: TouchEvent) => void

  build() {
    NextNPullRefresh({
      scroller: this.scroller,
      controller: this.controller,
      refreshEnabled: this.refreshEnabled,
      indicatorTop: this.resolvedIndicatorTop(),
      bottomIndicatorBottom: this.layout.bottomAvoidHeight + this.bottomPadding,
      onRefresh: async (): Promise<void> => {
        if (this.onRefresh) {
          await this.onRefresh()
        }
      },
      onBottomRefresh: async (): Promise<void> => {
        if (this.onBottomRefresh) {
          await this.onBottomRefresh()
        }
      },
      canStartBottomRefresh: (): boolean => {
        if (this.canStartBottomRefresh) {
          return this.canStartBottomRefresh()
        }
        return false
      },
      onScrollEnableChange: (enabled: boolean): void => {
        this.scrollEnabled = enabled
        if (this.onScrollEnableChange) {
          this.onScrollEnableChange(enabled)
        }
      },
    }) {
      List({ space: this.listSpace, scroller: this.scroller }) {
        ListItem() {
          Column() {
            Blank().height(this.layout.topAvoidHeight + ThemeTokens.TITLE_BAR_HEIGHT + this.topPadding)
          }
          .width('100%')
        }
        .clip(false)

        this.content()

        ListItem() {
          Column() {
            Blank().height(this.layout.bottomAvoidHeight + this.bottomPadding)
          }
          .width('100%')
        }
        .onAppear((): void => {
          this.maybeNotifyReachEnd()
        })
      }
      .enableScrollInteraction(this.scrollEnabled)
      .maintainVisibleContentPosition(true)
      .backToTop(this.backToTop)
      .sticky(this.stickyHeaders ? StickyStyle.Header : StickyStyle.None)
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
      // Active pull owns the physical edge offset. When disabled, retain the
      // SecondaryListScaffold spring contract for callers that opt into it.
      .edgeEffect(
        this.refreshEnabled
          ? EdgeEffect.None
          : (this.alwaysEnableEdgeSpring ? EdgeEffect.Spring : EdgeEffect.None),
        { alwaysEnabled: !this.refreshEnabled && this.alwaysEnableEdgeSpring },
      )
      .clip(false)
      .onWillScroll((_scrollOffset: number, _scrollState: ScrollState, source: ScrollSource): void => {
        if (this.onUserScroll && isUserScrollSource(source)) {
          this.onUserScroll()
        }
      })
      .onDidScroll((_scrollOffset: number, scrollState: ScrollState): void => {
        if (this.onDidScroll) {
          this.onDidScroll(currentScrollOffsetY(this.scroller), scrollState)
        }
      })
      .onScrollIndex((start: number, end: number, center: number): void => {
        const adjustedStart: number = this.normalizeContentIndexes ? this.contentIndex(start) : start
        const adjustedEnd: number = this.normalizeContentIndexes ? this.contentIndex(end) : end
        const adjustedCenter: number = this.normalizeContentIndexes ? this.contentIndex(center) : center
        if (this.onScrollIndex) {
          this.onScrollIndex(adjustedStart, adjustedEnd, adjustedCenter)
        }
        if (this.onDidScroll) {
          this.onDidScroll(currentScrollOffsetY(this.scroller), ScrollState.Scroll)
        }
      })
      .onReachEnd((): void => {
        this.notifyReachEnd()
      })
      .onTouch((event: TouchEvent): void => {
        if (this.onScrollTouch) {
          this.onScrollTouch(event)
        }
      })
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        this.measuredWidth = Number.parseFloat(`${newValue.width}`)
        if (this.onListAreaChange) {
          this.onListAreaChange(newValue)
        }
        if (this.onContentWidth) {
          const contentWidth: number = this.measuredWidth - 2 * this.horizontalPadding
          this.onContentWidth(contentWidth > 0 ? contentWidth : 0)
        }
      })
    }
  }

  private resolvedIndicatorTop(): number {
    if (this.indicatorTop >= 0) {
      return this.indicatorTop
    }
    return this.layout.topAvoidHeight + ThemeTokens.TITLE_BAR_HEIGHT / 2 + this.topPadding
  }

  /** Native indexes include the scaffold's top reserve at index zero. */
  private contentIndex(rawIndex: number): number {
    const index: number = rawIndex - 1
    if (index < 0) {
      return 0
    }
    if (this.itemCount > 0 && index >= this.itemCount) {
      return this.itemCount - 1
    }
    return index
  }

  private maybeNotifyReachEnd(): void {
    if (this.canStartBottomRefresh && !this.canStartBottomRefresh()) {
      return
    }
    this.notifyReachEnd()
  }

  private notifyReachEnd(): void {
    if (this.onReachEnd) {
      this.onReachEnd()
    }
  }
}
