import {
  ActionHandEdgeState,
  connectActionHandEdge,
  ThemeTokens,
} from 'shared'

/** Owns FAB measurements and motion without invalidating the gallery detail body. */
@ComponentV2
export struct GalleryActionFabRail {
  @Param hasReadAction: boolean = true;
  @Param availableWidth: number = 0;
  @Param usesHdsMaterial: boolean = true;
  @BuilderParam readButtonContent: () => void
  @BuilderParam favoriteButtonContent: () => void
  @Local actionEdge: ActionHandEdgeState = connectActionHandEdge();
  @Local edgeProgress: number = connectActionHandEdge().edge === 'left' ? 1 : 0;
  @Local readWidth: number = 0;
  @Local favoriteWidth: number = 0;
  @Local layoutReady: boolean = false;
  @Local shouldAnimate: boolean = false;
  @Local moving: boolean = false;
  private movementRevision: number = 0;

  @Monitor('actionEdge.edge')
  private moveToEdge(): void {
    const target: number = this.actionEdge.edge === 'left' ? 1 : 0
    this.shouldAnimate = this.layoutReady
    this.movementRevision++
    this.moving = this.shouldAnimate
    this.edgeProgress = target
  }

  @Monitor('usesHdsMaterial')
  private resetMeasurements(): void {
    this.edgeProgress = this.actionEdge.edge === 'left' ? 1 : 0
    this.readWidth = 0
    this.favoriteWidth = 0
    this.layoutReady = false
    this.shouldAnimate = false
    this.movementRevision++
    this.moving = false
  }

  @Monitor('hasReadAction')
  private onReadActionChanged(): void {
    if (!this.hasReadAction) {
      this.readWidth = 0
    }
    this.updateLayoutReady()
  }

  @Monitor('availableWidth')
  private updateLayoutReady(): void {
    this.layoutReady = this.availableWidth > 0 && this.favoriteWidth > 0 && (!this.hasReadAction || this.readWidth > 0)
  }

  private activityInset(): number {
    return this.usesHdsMaterial ? ThemeTokens.SPACE_LG : 0
  }

  private railInset(): number {
    return this.usesHdsMaterial ? 0 : ThemeTokens.SPACE_LG
  }

  private outerHeight(): number {
    return ThemeTokens.ACTION_HEIGHT + this.activityInset() * 2
  }

  private groupX(): number {
    const inner: number = this.availableWidth - this.railInset() * 2
    const width: number = this.favoriteWidth + (this.hasReadAction
      ? this.readWidth + ThemeTokens.SPACE_SM - this.activityInset() * 2 : 0)
    return Math.max(0, inner - width) * (1 - this.edgeProgress)
  }

  private readX(): number {
    return this.groupX() +
      (this.favoriteWidth - this.activityInset() * 2 + ThemeTokens.SPACE_SM) *
      (1 - this.edgeProgress)
  }

  private favoriteX(): number {
    return this.groupX() +
      (this.hasReadAction ? this.readWidth - this.activityInset() * 2 + ThemeTokens.SPACE_SM : 0) * this.edgeProgress
  }

  private movementAnimation(): AnimateParam {
    const revision: number = this.movementRevision
    return {
      duration: this.shouldAnimate ? ThemeTokens.REFRESH_ANIMATION_DURATION : 0,
      curve: Curve.EaseOut,
      expectedFrameRateRange: { min: 60, max: 120, expected: 120 },
      onFinish: () => {
        if (this.movementRevision === revision) {
          this.moving = false
        }
      },
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      if (this.hasReadAction) {
        Row() { this.readButtonContent() }
        .height(this.outerHeight())
        .id('gallery-detail-read-action')
        .hitTestBehavior(HitTestMode.Default)
        // Read covers Favorite only during the swap. At rest, its HDS activity
        // padding must not swallow the neighboring circle's edge taps.
        .zIndex(this.moving ? 1 : 0)
        .translate({ x: this.readX() })
        .animation(this.movementAnimation())
        .opacity(this.layoutReady ? 1 : 0)
        .onAreaChange((_oldArea: Area, area: Area) => {
          this.readWidth = area.width as number
          this.updateLayoutReady()
        })
      }
      Row() { this.favoriteButtonContent() }
        .id('gallery-detail-favorite-action')
        .height(this.outerHeight())
        .hitTestBehavior(HitTestMode.Default)
        .translate({ x: this.favoriteX() })
        .animation(this.movementAnimation())
        .opacity(this.layoutReady ? 1 : 0)
        .onAreaChange((_oldArea: Area, area: Area) => {
          this.favoriteWidth = area.width as number
          this.updateLayoutReady()
        })
    }
    .width('100%')
    .height(this.outerHeight())
    .padding({ left: this.railInset(), right: this.railInset() })
    .hitTestBehavior(HitTestMode.Transparent)
    .clip(false)
    .position({ left: 0, bottom: this.railInset() })
  }
}

