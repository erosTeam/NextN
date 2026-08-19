import { ThemeTokens } from '../theme/ThemeTokens'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { currentScrollOffsetY, isUserScrollSource } from '../utils/ScrollUserInput'

/**
 * Shared routed/root list host, kept structurally aligned with NextE.
 *
 * The title bar is immersive, so the first list item reserves its space while
 * remaining part of the scroll surface. Root pages pass the floating tab
 * reserve as `bottomPadding`; destinations use the normal page tail.
 */
@ComponentV2
export struct SecondaryListScaffold {
  @BuilderParam content: () => void
  layout: LayoutSafeAreaState = connectLayoutSafeArea()
  @Param scroller: Scroller = new Scroller()
  @Param listSpace: number = ThemeTokens.SPACE_SM - 2
  @Param horizontalPadding: number = ThemeTokens.LIST_HORIZONTAL_PADDING
  @Param topPadding: number = 0
  @Param bottomPadding: number = ThemeTokens.LIST_BOTTOM_PADDING
  @Param stickyHeaders: boolean = false
  @Param alwaysEnableEdgeSpring: boolean = false
  @Param backToTop: boolean = true
  @Event onReachEnd?: () => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  @Event onUserScroll?: () => void
  @Event onListAreaChange?: (area: Area) => void
  @Event onScrollIndex?: (start: number, end: number, center: number) => void

  build() {
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
    .scrollBar(BarState.Off)
    .backToTop(this.backToTop)
    .sticky(this.stickyHeaders ? StickyStyle.Header : StickyStyle.None)
    .width('100%')
    .height('100%')
    .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
    .clip(false)
    .edgeEffect(this.alwaysEnableEdgeSpring ? EdgeEffect.Spring : EdgeEffect.None, {
      alwaysEnabled: this.alwaysEnableEdgeSpring,
    })
    .onDidScroll((_scrollOffset: number, scrollState: ScrollState): void => {
      if (this.onDidScroll) {
        this.onDidScroll(currentScrollOffsetY(this.scroller), scrollState)
      }
    })
    .onWillScroll((_scrollOffset: number, _scrollState: ScrollState, source: ScrollSource): void => {
      if (this.onUserScroll && isUserScrollSource(source)) {
        this.onUserScroll()
      }
    })
    .onScrollIndex((start: number, end: number, center: number): void => {
      if (this.onScrollIndex) {
        this.onScrollIndex(start, end, center)
      }
      if (this.onDidScroll) {
        this.onDidScroll(currentScrollOffsetY(this.scroller), ScrollState.Scroll)
      }
    })
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      if (this.onListAreaChange) {
        this.onListAreaChange(newValue)
      }
    })
    .onReachEnd((): void => {
      if (this.onReachEnd) {
        this.onReachEnd()
      }
    })
  }

  private maybeNotifyReachEnd(): void {
    if (this.onReachEnd) {
      this.onReachEnd()
    }
  }
}
