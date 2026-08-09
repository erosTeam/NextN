import { SubtabTransitionState } from '../state/SubtabTransitionState'

// Kept equal to NextE's retained-source settle duration. It is intentionally
// local to this component rather than importing a second theme-constant tree.
const SUBTAB_ANIMATION_DURATION: number = 400

/**
 * Shared observable activation signal. Cached Swiper pages must observe this
 * object instead of receiving a one-shot boolean, otherwise an unvisited page
 * misses its first activation after the builder has been cached.
 */
@ObservedV2
export class ActiveKeyState {
  @Trace activeKey: string = ''
}

/**
 * NextE-style retained source host. It owns only transition mechanics and one
 * stable Scroller per key; each pageBuilder invocation owns its own data,
 * pagination and local request generation.
 */
@ComponentV2
export struct RetainedSubtabHost {
  @Param keys: string[] = []
  @Param selectedKey: string = ''
  @Param subtabTransition: SubtabTransitionState = new SubtabTransitionState()
  @Param transitionScope: string = ''
  @BuilderParam pageBuilder:
    (key: string, active: ActiveKeyState, scroller: Scroller, onDidScroll: (offset: number, state: ScrollState) => void,
      onOpenGallery: (galleryId: number) => void) => void
  @Event onSelectKey: (key: string) => void = (_key: string): void => {}
  @Event onVisualIndex: (value: number) => void = (_value: number): void => {}
  /** Explicit page-to-shell navigation handoff; the global page builder has no component `this`. */
  @Event onOpenGallery: (galleryId: number) => void = (_galleryId: number): void => {}
  @Event onScrollerReady?: (scroller: Scroller) => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  @Local swiperIndex: number = 0
  private swiperController: SwiperController = new SwiperController()
  private scrollers: Map<string, Scroller> = new Map<string, Scroller>()
  private swiperWidth: number = 0
  private visualPosition: number = 0
  private visualSettleTarget: number = -1
  private pendingTransitionIndex: number = -1
  private active: ActiveKeyState = new ActiveKeyState()

  private scrollerForKey(key: string): Scroller {
    const current: Scroller | undefined = this.scrollers.get(key)
    if (current !== undefined) {
      return current
    }
    const created: Scroller = new Scroller()
    this.scrollers.set(key, created)
    return created
  }

  private activeIndex(): number {
    const index: number = this.keys.indexOf(this.selectedKey)
    return index < 0 ? 0 : index
  }

  private effectiveActiveKey(): string {
    return this.keys.length > 0 ? this.keys[this.activeIndex()] : ''
  }

  private clampedVisualIndex(value: number): number {
    const last: number = this.keys.length - 1
    if (last <= 0) {
      return 0
    }
    const candidate: number = Number.isNaN(value) ? this.activeIndex() : value
    return Math.max(0, Math.min(last, candidate))
  }

  private visualFromOffset(index: number, extraInfo: SwiperAnimationEvent): number {
    return this.swiperWidth > 0 ? index + -extraInfo.currentOffset / this.swiperWidth : index
  }

  private publishVisualIndex(value: number): void {
    const next: number = this.clampedVisualIndex(value)
    this.visualPosition = next
    this.onVisualIndex(next)
  }

  private commitVisualIndex(value: number): void {
    const wasSettling: boolean = this.visualSettleTarget >= 0
    this.visualSettleTarget = -1
    if (wasSettling) {
      this.getUIContext().animateTo({ duration: 0 }, (): void => {
        this.publishVisualIndex(value)
      })
      return
    }
    this.publishVisualIndex(value)
  }

  private publishGestureVisualIndex(value: number): void {
    const next: number = this.clampedVisualIndex(value)
    const wasSettling: boolean = this.visualSettleTarget >= 0
    this.visualSettleTarget = -1
    if (wasSettling) {
      this.getUIContext().animateTo({ duration: 0 }, (): void => {
        this.publishVisualIndex(next)
      })
      return
    }
    this.publishVisualIndex(next)
  }

  private settleVisualIndex(targetIndex: number): void {
    const target: number = this.clampedVisualIndex(targetIndex)
    if (this.visualSettleTarget === target) {
      return
    }
    this.visualSettleTarget = target
    if (this.visualPosition === target) {
      return
    }
    this.getUIContext().animateTo({ duration: SUBTAB_ANIMATION_DURATION, curve: Curve.EaseOut }, (): void => {
      this.publishVisualIndex(target)
    })
  }

  private notifyActiveScroller(key: string = this.selectedKey): void {
    if (this.onScrollerReady && key.length > 0) {
      this.onScrollerReady(this.scrollerForKey(key))
    }
  }

  private syncSelectedIndex(animated: boolean): void {
    if (this.keys.length === 0) {
      this.swiperIndex = 0
      this.active.activeKey = ''
      this.commitVisualIndex(0)
      return
    }
    const from: number = Math.max(0, Math.min(this.keys.length - 1, this.swiperIndex))
    const target: number = this.activeIndex()
    const activeKey: string = this.effectiveActiveKey()
    if (from === target) {
      this.swiperIndex = target
      this.active.activeKey = activeKey
      this.commitVisualIndex(target)
      this.notifyActiveScroller(activeKey)
      return
    }
    this.swiperIndex = from
    this.active.activeKey = activeKey
    if (animated) {
      this.swiperController.changeIndex(target, true)
    } else {
      this.swiperIndex = target
      this.swiperController.changeIndex(target, false)
      this.commitVisualIndex(target)
    }
    this.notifyActiveScroller(activeKey)
  }

  aboutToAppear(): void {
    this.active.activeKey = this.effectiveActiveKey()
    const restoredIndex: number = this.activeIndex()
    this.swiperIndex = restoredIndex
    this.commitVisualIndex(restoredIndex)
    this.notifyActiveScroller(this.active.activeKey)
  }

  @Monitor('selectedKey')
  onSelectedKeyChange(): void {
    this.syncSelectedIndex(true)
  }

  @Monitor('subtabTransition.requestSeq')
  onTransitionRequest(): void {
    if (this.subtabTransition.scope !== this.transitionScope) {
      return
    }
    const target: number = this.keys.indexOf(this.subtabTransition.targetKey)
    if (target < 0 || target === this.swiperIndex) {
      return
    }
    this.pendingTransitionIndex = target
    this.swiperController.changeIndex(target, true)
  }

  @Monitor('keys')
  onKeysChange(): void {
    this.syncSelectedIndex(false)
  }

  build() {
    Swiper(this.swiperController) {
      ForEach(this.keys, (key: string): void => {
        this.pageBuilder(key, this.active, this.scrollerForKey(key), (offset: number, state: ScrollState): void => {
          if (key === this.selectedKey && this.onDidScroll) {
            this.onDidScroll(offset, state)
          }
        }, this.onOpenGallery)
      }, (key: string): string => key)
    }
    .index(this.swiperIndex)
    .cachedCount(this.keys.length)
    .nestedScroll(SwiperNestedScrollMode.SELF_ONLY)
    .indicator(false)
    .loop(false)
    .duration(SUBTAB_ANIMATION_DURATION)
    .curve(Curve.EaseOut)
    .onGestureSwipe((index: number, extraInfo: SwiperAnimationEvent): void => {
      this.publishGestureVisualIndex(this.visualFromOffset(index, extraInfo))
    })
    .onAnimationStart((_index: number, targetIndex: number, _extraInfo: SwiperAnimationEvent): void => {
      if (this.pendingTransitionIndex === targetIndex && targetIndex >= 0 && targetIndex < this.keys.length) {
        this.active.activeKey = this.keys[targetIndex]
      }
      this.settleVisualIndex(targetIndex)
    })
    .onAnimationEnd((index: number, _extraInfo: SwiperAnimationEvent): void => {
      this.pendingTransitionIndex = -1
      this.swiperIndex = index
      this.commitVisualIndex(index)
      const key: string = this.keys[index]
      this.active.activeKey = key
      if (key !== this.selectedKey) {
        this.onSelectKey(key)
      }
      // Use the settled key explicitly: the parent parameter can update one
      // render later, and binding the prior source here would misroute HDS
      // title hiding and root re-tap refresh.
      this.notifyActiveScroller(key)
    })
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      this.swiperWidth = newValue.width as number
    })
    .width('100%')
    .height('100%')
  }
}
