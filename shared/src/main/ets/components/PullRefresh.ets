import { ThemeTokens } from '../theme/ThemeTokens'
import { RefreshFeedback } from '../utils/RefreshFeedback'

const PULL_START_DRAG_VP: number = 4
const PULL_ARM_VP: number = 10
const PULL_RESISTANCE_FACTOR: number = 0.8
const DEFAULT_PULL_REFRESH_THRESHOLD: number = 80
const REFRESH_HOLD_OFFSET: number = 56
const DIRECTION_LOCK_VP: number = 6
const PROGRAMMATIC_PULL_ANIM_DURATION: number = 300

/**
 * A route retains this controller beside its Scroller and may register
 * `requestRefresh` with RootRefreshRegistry. It controls only an interactive
 * refresh: initial loading stays entirely in the page's own state machine.
 */
export class NextNPullRefreshController {
  private programmaticTopRefreshAction: (() => void) | null = null

  setProgrammaticTopRefreshAction(action: () => void): void {
    this.programmaticTopRefreshAction = action
  }

  clearProgrammaticTopRefreshAction(action: () => void): void {
    if (this.programmaticTopRefreshAction === action) {
      this.programmaticTopRefreshAction = null
    }
  }

  /** Compatibility name for a root-tab re-tap action. */
  triggerTopRefresh(): void {
    if (this.programmaticTopRefreshAction !== null) {
      this.programmaticTopRefreshAction()
    }
  }

  /** Explicit caller API for a root re-tap or another programmatic refresh. */
  requestRefresh(): void {
    this.triggerTopRefresh()
  }
}

/**
 * Shared NextE-derived top edge-pull host.
 *
 * It owns visual feedback, haptics, duplicate guards and temporary child
 * scroll locking. It deliberately exposes no initial-load or bottom-paging
 * state: callers retain those separate page and pagination lifecycles.
 */
@ComponentV2
export struct NextNPullRefresh {
  @BuilderParam content: () => void
  @Param scroller: Scroller = new Scroller()
  @Param controller: NextNPullRefreshController = new NextNPullRefreshController()
  /** Disabling interaction never changes caller-owned initial-load state. */
  @Param refreshEnabled: boolean = true
  @Event onRefresh: () => Promise<void> = async (): Promise<void> => {}
  @Event onScrollEnableChange: (enabled: boolean) => void = (_enabled: boolean): void => {}
  @Param indicatorTop: number = 0
  @Param threshold: number = DEFAULT_PULL_REFRESH_THRESHOLD

  @Local pullOffset: number = 0
  @Local refreshState: number = 0
  @Local topIndicatorMounted: boolean = false
  private touchStartX: number = 0
  private touchStartY: number = 0
  private touchStartPullOffset: number = 0
  private topEdgeDragStartY: number = 0
  private isTracking: boolean = false
  private isHorizontalGesture: boolean = false
  private controllerAction: (() => void) | null = null

  aboutToAppear(): void {
    const action: () => void = (): void => {
      this.triggerProgrammaticTopRefresh()
    }
    this.controllerAction = action
    this.controller.setProgrammaticTopRefreshAction(action)
  }

  aboutToDisappear(): void {
    if (this.controllerAction !== null) {
      this.controller.clearProgrammaticTopRefreshAction(this.controllerAction)
    }
    this.controllerAction = null
  }

  private isListAtTop(): boolean {
    return this.scroller.currentOffset().yOffset <= 0
  }

  private bounceBack(target: number = 0): void {
    this.onScrollEnableChange(true)
    this.getUIContext().animateTo(
      { duration: ThemeTokens.REFRESH_ANIMATION_DURATION, curve: Curve.EaseOut },
      (): void => {
        this.pullOffset = target
      },
    )
    if (target === 0) {
      setTimeout((): void => {
        if (this.pullOffset <= 0) {
          this.refreshState = 0
          this.topIndicatorMounted = false
        }
      }, ThemeTokens.REFRESH_STATE_RESET_MS)
    }
  }

  private onPullEnd(): void {
    if (this.pullOffset >= this.threshold && this.refreshState !== 2) {
      this.onScrollEnableChange(true)
      this.getUIContext().animateTo(
        { duration: ThemeTokens.REFRESH_ANIMATION_DURATION, curve: Curve.EaseOut },
        (): void => {
          this.pullOffset = REFRESH_HOLD_OFFSET
        },
      )
      this.refreshState = 2
      this.doRefresh()
    } else if (this.pullOffset > 0) {
      this.bounceBack(0)
    }
  }

  private triggerProgrammaticTopRefresh(): void {
    if (!this.refreshEnabled || this.refreshState >= 2 || this.topIndicatorMounted || this.pullOffset > 0) {
      return
    }
    try {
      if (!this.isListAtTop()) {
        this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
      }
    } catch (_error) {}
    this.onScrollEnableChange(false)
    this.topIndicatorMounted = true
    this.getUIContext().animateTo(
      { duration: PROGRAMMATIC_PULL_ANIM_DURATION, curve: Curve.EaseOut },
      (): void => {
        this.pullOffset = this.threshold
      },
    )
    setTimeout((): void => {
      this.refreshState = 1
      this.onPullEnd()
    }, PROGRAMMATIC_PULL_ANIM_DURATION)
  }

  private async doRefresh(): Promise<void> {
    try {
      await this.onRefresh()
    } catch (_error) {
      try {
        RefreshFeedback.notifyRefreshFailed()
      } catch (_feedbackError) {}
    } finally {
      this.refreshState = 3
      setTimeout((): void => this.bounceBack(0), ThemeTokens.REFRESH_DONE_DELAY_MS)
    }
  }

  private resetTouchState(): void {
    this.isTracking = false
    this.isHorizontalGesture = false
    this.topEdgeDragStartY = 0
  }

  private indicatorOpacity(gap: number): number {
    const range: number = REFRESH_HOLD_OFFSET - ThemeTokens.REFRESH_INDICATOR_SIZE
    if (range <= 0) {
      return gap >= ThemeTokens.REFRESH_INDICATOR_SIZE ? 1 : 0
    }
    return Math.min(Math.max((gap - ThemeTokens.REFRESH_INDICATOR_SIZE) / range, 0), 1)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        this.content()
      }
      .offset({ y: this.pullOffset })
      .onTouch((event: TouchEvent): void => {
        this.handleTouch(event)
      })

      if (this.topIndicatorMounted) {
        Column() {
          Row() {
            LoadingProgress()
              .width(ThemeTokens.REFRESH_INDICATOR_SIZE)
              .height(ThemeTokens.REFRESH_INDICATOR_SIZE)
          }
          .width('100%')
          .height(REFRESH_HOLD_OFFSET)
          .justifyContent(FlexAlign.Center)
          .opacity(this.indicatorOpacity(this.pullOffset))
        }
        .position({ y: this.indicatorTop + this.pullOffset / 2 })
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .clip(false)
  }

  private handleTouch(event: TouchEvent): void {
    if (!this.refreshEnabled) {
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.onScrollEnableChange(true)
        this.resetTouchState()
        this.topIndicatorMounted = false
      }
      return
    }
    if (this.refreshState >= 2) {
      return
    }

    if (event.type === TouchType.Down) {
      this.touchStartX = event.touches[0].x
      this.touchStartY = event.touches[0].y
      this.touchStartPullOffset = this.pullOffset
      this.resetTouchState()
      return
    }

    if (event.type === TouchType.Move) {
      this.handleTouchMove(event)
      return
    }

    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      if (this.isTracking && this.pullOffset > 0) {
        this.onPullEnd()
      } else {
        this.topIndicatorMounted = false
      }
      this.onScrollEnableChange(true)
      this.resetTouchState()
    }
  }

  private handleTouchMove(event: TouchEvent): void {
    const deltaX: number = event.touches[0].x - this.touchStartX
    const deltaY: number = event.touches[0].y - this.touchStartY
    if (this.isHorizontalGesture) {
      return
    }
    if (!this.isTracking) {
      if (Math.abs(deltaX) > DIRECTION_LOCK_VP && Math.abs(deltaX) > Math.abs(deltaY)) {
        this.isHorizontalGesture = true
        return
      }
      const verticalDominant: boolean = Math.abs(deltaY) > Math.abs(deltaX) * 1.5
      if (!verticalDominant || deltaY <= PULL_ARM_VP || !this.isListAtTop()) {
        return
      }
      this.isTracking = true
      this.topEdgeDragStartY = event.touches[0].y - PULL_START_DRAG_VP
      this.touchStartPullOffset = 0
      this.onScrollEnableChange(false)
    }

    const pullDelta: number = event.touches[0].y - this.topEdgeDragStartY
    this.pullOffset = Math.max(0, this.touchStartPullOffset + pullDelta * PULL_RESISTANCE_FACTOR)
    if (this.pullOffset > 0) {
      this.topIndicatorMounted = true
    }
    if (this.pullOffset >= this.threshold) {
      this.refreshState = 1
    } else {
      this.refreshState = 0
    }
  }
}
