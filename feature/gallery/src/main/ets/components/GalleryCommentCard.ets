import { AppStrings, NhComment, ThemeTokens } from 'shared'

const COMMENT_ACTION_SIZE: number = 30
const COMMENT_ACTION_ICON_SIZE: number = 16
const COMMENT_ANIM_DONE_DELAY_MS: number = 200
const COMMENT_QUOTE_RADIUS: number = ThemeTokens.RADIUS_SM + ThemeTokens.SPACE_XS

/**
 * Height-measure animation machinery (ported from NextE GalleryCommentsCard):
 * when a translation appears, the target body renders offscreen to MEASURE its
 * height, then the visible body locks to the start height and animateTo grows
 * it to the target while the content swaps - giving BOTH a height animation and
 * a content transition. animateTo alone can't do the first appearance because
 * it has no prior height to interpolate from.
 *
 * The card must own this animation: a cross-component animateTo cannot capture
 * the card's layout change, so the page only writes the translation params and
 * this component mirrors them inside its OWN animateTo.
 */
@ComponentV2
export struct GalleryCommentCard {
  @Require @Param comment: NhComment
  /** Pre-processed reply body (reply prefix already stripped by the page). */
  @Require @Param body: string
  /** Page-managed translation result for this comment. */
  @Param translated: string = ''
  /** Page-managed show-translation state. */
  @Param shown: boolean = false
  /** Page-managed in-flight translation state. */
  @Param loading: boolean = false
  @Param canTranslate: boolean = false
  @Param bilingual: boolean = false
  @Param replyQuoteBody: string = ''
  @Param replyQuoteAuthor: string = ''
  @Event onToggleTranslate: () => void = () => {}
  @Event onReply: () => void = () => {}

  // Card-local mirrors of the page-held params. The body/icon read THESE and
  // they are synced inside the card's OWN animateTo (see onParamsChanged), so
  // the height/content change is captured and animated.
  @Local localTranslated: string = ''
  @Local localShown: boolean = false
  @Local localLoading: boolean = false
  // Height-measure animation state, restored from NextE verbatim.
  @Local commentBodyMeasuredHeight: number = 0
  @Local commentBodyAnimatedHeight: number = 0
  @Local commentBodyHeightLocked: boolean = false
  @Local pendingTranslationMeasure: boolean = false
  // Direction of the pending measure-animate: true = animating TO the
  // translation, false = back to the original.
  @Local pendingShowTranslation: boolean = false
  // Only a user-initiated translate/toggle animates; auto-translate and
  // cached results sync instantly so opening a page never animates every
  // visible card at once.
  private manualTranslateArmed: boolean = false

  aboutToAppear(): void {
    // Seed the mirror without animation: the page state may already carry a
    // cached translation, which must appear instantly, not animate in.
    this.localTranslated = this.translated
    this.localShown = this.shown
    this.localLoading = this.loading
  }

  @Monitor('translated', 'shown', 'loading')
  onParamsChanged(): void {
    this.localLoading = this.loading
    const wantTranslation: boolean = this.shown && this.translated.length > 0
    const hasNewText: boolean = this.translated.length > 0 && this.localTranslated !== this.translated
    const needShow: boolean = wantTranslation && (!this.localShown || hasNewText)
    const needHide: boolean = !wantTranslation && this.localShown
    if (!needShow && !needHide) {
      return
    }
    // Keep the latest translated text available for the offscreen measure and
    // the final render; the visible body still shows the original until the
    // animation flips it.
    if (hasNewText) {
      this.localTranslated = this.translated
    }
    if (this.manualTranslateArmed) {
      this.manualTranslateArmed = false
      this.pendingShowTranslation = needShow
      this.pendingTranslationMeasure = true
    } else {
      // Auto/cached - apply instantly.
      this.localShown = needShow
    }
  }

  private updateCommentBodyHeight(area: Area): void {
    if (this.commentBodyHeightLocked) {
      return
    }
    const height: number = area.height as number
    if (height > 0) {
      this.commentBodyMeasuredHeight = height
    }
  }

  private handlePendingTranslationArea(area: Area): void {
    if (!this.pendingTranslationMeasure) {
      return
    }
    const nextHeight: number = area.height as number
    if (nextHeight <= 0) {
      return
    }
    const showTranslation: boolean = this.pendingShowTranslation
    const startHeight: number =
      this.commentBodyMeasuredHeight > 0 ? this.commentBodyMeasuredHeight : nextHeight
    this.pendingTranslationMeasure = false
    this.commentBodyAnimatedHeight = startHeight
    this.commentBodyHeightLocked = true
    setTimeout((): void => {
      this.getUIContext().animateTo(
        { duration: ThemeTokens.ANIM_DURATION, curve: Curve.EaseOut },
        () => {
          // Flip the visible body to the target and grow/shrink to its height.
          this.localShown = showTranslation
          this.localLoading = false
          this.commentBodyAnimatedHeight = nextHeight
        },
      )
      setTimeout((): void => {
        this.commentBodyHeightLocked = false
        this.commentBodyAnimatedHeight = 0
        this.commentBodyMeasuredHeight = nextHeight
      }, ThemeTokens.ANIM_DURATION + COMMENT_ANIM_DONE_DELAY_MS)
    }, 0)
  }

  private displayedBody(): string {
    if (this.localShown && this.localTranslated.length > 0) {
      return this.localTranslated
    }
    return this.body.length > 0 ? this.body : AppStrings.get('comments_empty_body')
  }

  private translationActionLabel(): string {
    return this.localShown
      ? AppStrings.get('comments_translation_show_original')
      : AppStrings.get('comments_translation_action')
  }

  private authorLabel(): string {
    return this.comment.posterName.length > 0
      ? this.comment.posterName
      : AppStrings.get('comments_author_anonymous')
  }

  private twoDigits(value: number): string {
    return value < 10 ? `0${value}` : value.toString()
  }

  private postedLabel(): string {
    if (this.comment.postDate <= 0) {
      return ''
    }
    const date: Date = new Date(this.comment.postDate * 1000)
    if (isNaN(date.getTime())) {
      return ''
    }
    return `${date.getFullYear()}-${this.twoDigits(date.getMonth() + 1)}-${this.twoDigits(date.getDate())} ` +
      `${this.twoDigits(date.getHours())}:${this.twoDigits(date.getMinutes())}`
  }

  @Builder
  private FooterAction(
    icon: Resource,
    label: string,
    disabled: boolean,
    active: boolean,
    action: () => void,
  ) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      if (disabled) {
        LoadingProgress()
          .width(COMMENT_ACTION_ICON_SIZE)
          .height(COMMENT_ACTION_ICON_SIZE)
          .color(ThemeTokens.TEXT_TERTIARY)
      } else {
        SymbolGlyph(icon)
          .fontSize(COMMENT_ACTION_ICON_SIZE)
          .fontColor([active ? ThemeTokens.BRAND : ThemeTokens.TEXT_TERTIARY])
      }
    }
    .width(COMMENT_ACTION_SIZE)
    .height(COMMENT_ACTION_SIZE)
    .buttonStyle(ButtonStyleMode.NORMAL)
    .backgroundColor(Color.Transparent)
    .accessibilityText(label)
    .enabled(!disabled)
    .onClick(action)
  }

  @Builder
  private ReplyQuote() {
    if (this.replyQuoteBody.length > 0) {
      Column({ space: ThemeTokens.SPACE_XS }) {
        if (this.replyQuoteAuthor.length > 0) {
          Text(this.replyQuoteAuthor)
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.TEXT_LINK)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Text(this.replyQuoteBody)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(ThemeTokens.SPACE_SM)
      .borderRadius(COMMENT_QUOTE_RADIUS)
      .backgroundColor(ThemeTokens.SURFACE_SUB)
    }
  }

  @Builder
  private BodyText(value: string, color: ResourceColor) {
    Text(value)
      .width('100%')
      .fontSize(ThemeTokens.FONT_SIZE_BODY)
      .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
      .fontColor(color)
  }

  @Builder
  private VisibleBodyContent() {
    if (this.localShown && this.localTranslated.length > 0 && this.bilingual) {
      // NextE bilingual visual: original de-emphasized, thin divider,
      // translation as the primary text.
      this.BodyText(this.body, ThemeTokens.TEXT_SECONDARY)
      Divider().strokeWidth(0.5).color(ThemeTokens.DIVIDER)
      this.BodyText(this.localTranslated, ThemeTokens.TEXT_PRIMARY)
    } else if (this.localShown && this.localTranslated.length > 0) {
      this.BodyText(this.localTranslated, ThemeTokens.TEXT_PRIMARY)
    } else {
      this.BodyText(this.displayedBody(), ThemeTokens.TEXT_PRIMARY)
    }
  }

  @Builder
  private PendingBodyContent() {
    // Offscreen copy of the TARGET body (translation when showing, original
    // when hiding) - measured via onAreaChange to get the target height
    // before the visible body animates to it.
    if (!this.pendingShowTranslation) {
      this.BodyText(this.displayedBody(), ThemeTokens.TEXT_PRIMARY)
    } else if (this.bilingual) {
      this.BodyText(this.body, ThemeTokens.TEXT_SECONDARY)
      Divider().strokeWidth(0.5).color(ThemeTokens.DIVIDER)
      this.BodyText(this.localTranslated, ThemeTokens.TEXT_PRIMARY)
    } else {
      this.BodyText(this.localTranslated, ThemeTokens.TEXT_PRIMARY)
    }
  }

  @Builder
  private CommentBody() {
    if (this.commentBodyHeightLocked) {
      // During the animation the height is driven from measured start to
      // target and clipped.
      Stack({ alignContent: Alignment.TopStart }) {
        this.CommentBodyStackContent()
      }
      .width('100%')
      .height(this.commentBodyAnimatedHeight)
      .clip(true)
    } else {
      Stack({ alignContent: Alignment.TopStart }) {
        this.CommentBodyStackContent()
      }.width('100%')
    }
  }

  @Builder
  private CommentBodyStackContent() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      this.VisibleBodyContent()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onAreaChange((_oldArea: Area, area: Area): void => {
      this.updateCommentBodyHeight(area)
    })
    if (this.pendingTranslationMeasure) {
      Column({ space: ThemeTokens.SPACE_XS }) {
        this.PendingBodyContent()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .opacity(0)
      .hitTestBehavior(HitTestMode.None)
      .position({ x: 0, y: 0 })
      .onAreaChange((_oldArea: Area, area: Area): void => {
        this.handlePendingTranslationArea(area)
      })
    }
  }

  build() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Row() {
        Text(this.authorLabel())
          .layoutWeight(1)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_LINK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.canTranslate) {
          this.FooterAction(
            $r('sys.symbol.translate'),
            this.translationActionLabel(),
            this.localLoading,
            this.localShown,
            (): void => {
              this.manualTranslateArmed = true
              this.onToggleTranslate()
            },
          )
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      this.ReplyQuote()
      this.CommentBody()
      Row() {
        if (this.postedLabel().length > 0) {
          Text(this.postedLabel())
            .layoutWeight(1)
            .fontSize(ThemeTokens.FONT_SIZE_TINY)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          Blank().layoutWeight(1)
        }
        this.FooterAction(
          $r('sys.symbol.ellipsis_message'),
          AppStrings.get('comments_action_reply'),
          false,
          false,
          (): void => {
            this.onReply()
          },
        )
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: ThemeTokens.SPACE_MD,
      right: ThemeTokens.SPACE_MD,
      top: ThemeTokens.SPACE_MD,
      bottom: ThemeTokens.SPACE_SM,
    })
    .borderRadius(ThemeTokens.RADIUS_CARD)
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
  }
}
