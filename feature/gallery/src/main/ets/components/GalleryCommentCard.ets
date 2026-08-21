import {
  AppStrings,
  EH_IMAGE_PRIORITY_LOW,
  EhImageKnifeImage,
  NhComment,
  ThemeTokens,
} from 'shared'
import {
  CommentTranslationRenderState,
  GalleryCommentReplyReference,
} from '../pages/GalleryCommentsPage'

const COMMENT_ACTION_SIZE: number = 30
const COMMENT_ACTION_ICON_SIZE: number = 16
// Next2V ReplyCardHeader avatar diameter (AVATAR_SIZE_REPLY).
const COMMENT_AVATAR_SIZE: number = 32
const COMMENT_QUOTE_AVATAR_SIZE: number = 20
const COMMENT_ANIM_DONE_DELAY_MS: number = 200
const COMMENT_QUOTE_RADIUS: number = ThemeTokens.RADIUS_SM + ThemeTokens.SPACE_XS

class GalleryCommentTextSegment {
  key: string = ''
  text: string = ''
  emphasized: boolean = false

  constructor(key: string, text: string, emphasized: boolean) {
    this.key = key
    this.text = text
    this.emphasized = emphasized
  }
}

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
  /** Live page-managed translation state (NextE renderState parity). */
  @Require @Param renderState: CommentTranslationRenderState
  @Param canTranslate: boolean = false
  @Param autoTranslate: boolean = false
  @Param bilingual: boolean = false
  @Param replyReferences: GalleryCommentReplyReference[] = []
  @Param referenceRenderStates: CommentTranslationRenderState[] = []
  @Param translationEnabled: boolean = false
  @Param emphasizedMentions: string[] = []
  @Event onToggleTranslate: () => void = () => {}
  @Event onAutoTranslate: () => void = () => {}
  @Event onAutoTranslateReferences: () => void = () => {}
  @Event onReply: () => void = () => {}

  // Card-local mirrors of the page-held params. The body/icon read THESE and
  // they are synced inside the card's OWN animateTo (see onParamsChanged), so
  // the height/content change is captured and animated.
  @Local localTranslated: string = ''
  @Local localShown: boolean = false
  @Local localLoading: boolean = false
  @Local localFailed: boolean = false
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
    this.localTranslated = this.renderState.translated
    this.localShown = this.renderState.shown
    this.localLoading = this.renderState.loading
    this.localFailed = this.renderState.failed
    this.requestAutoTranslate()
  }

  @Monitor('renderState.translated', 'renderState.shown', 'renderState.loading', 'renderState.failed')
  onParamsChanged(): void {
    // NextE parity: the spinner flag always follows the render state
    // immediately — no manual-arm gating on the loading mirror.
    this.localLoading = this.renderState.loading
    this.localFailed = this.renderState.failed
    const wantTranslation: boolean = this.renderState.shown && this.renderState.translated.length > 0
    const hasNewText: boolean = this.renderState.translated.length > 0 &&
      this.localTranslated !== this.renderState.translated
    const needShow: boolean = wantTranslation && (!this.localShown || hasNewText)
    const needHide: boolean = !wantTranslation && this.localShown
    if (!needShow && !needHide) {
      return
    }
    // Keep the latest translated text available for the offscreen measure and
    // the final render; the visible body still shows the original until the
    // animation flips it.
    if (hasNewText) {
      this.localTranslated = this.renderState.translated
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

  @Monitor('canTranslate', 'autoTranslate')
  onAutoTranslateInputsChanged(): void {
    this.requestAutoTranslate()
  }

  private requestAutoTranslate(): void {
    if (!this.canTranslate || !this.autoTranslate) {
      return
    }
    this.onAutoTranslateReferences()
    if (this.renderState.autoStarted || this.renderState.loading || this.renderState.translated.length > 0) {
      return
    }
    this.onAutoTranslate()
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
    if (this.localFailed) {
      return AppStrings.get('comments_translation_failed')
    }
    return this.localShown
      ? AppStrings.get('comments_translation_show_original')
      : AppStrings.get('comments_translation_action')
  }

  private authorLabel(): string {
    return this.comment.posterName.length > 0
      ? this.comment.posterName
      : AppStrings.get('comments_author_anonymous')
  }

  private avatarPlaceholderInitial(): string {
    const name: string = this.comment.posterName.trim()
    if (name.length === 0) {
      return '•'
    }
    return name.substring(0, 1).toUpperCase()
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

  /** NextE TranslationAction parity: three explicit branches over mirror state. */
  @Builder
  private TranslationAction() {
    if (this.localLoading) {
      this.FooterAction($r('sys.symbol.translate'), ThemeTokens.TEXT_TERTIARY, true, this.translationActionLabel(), (): void => {
        this.manualTranslateArmed = true
        this.onToggleTranslate()
      })
    } else if (this.localShown && this.localTranslated.length > 0) {
      this.FooterAction($r('sys.symbol.translate'), ThemeTokens.BRAND, false, this.translationActionLabel(), (): void => {
        this.manualTranslateArmed = true
        this.onToggleTranslate()
      })
    } else if (this.localFailed) {
      this.FooterAction($r('sys.symbol.exclamationmark_triangle'), Color.Red, false,
        this.translationActionLabel(), (): void => {
        this.manualTranslateArmed = true
        this.onToggleTranslate()
      })
    } else {
      this.FooterAction($r('sys.symbol.translate'), ThemeTokens.TEXT_TERTIARY, false, this.translationActionLabel(), (): void => {
        this.manualTranslateArmed = true
        this.onToggleTranslate()
      })
    }
  }

  @Builder
  private FooterAction(
    icon: Resource,
    color: ResourceColor,
    disabled: boolean,
    label: string,
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
          .fontColor([color])
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
  private ReplyReferences() {
    ForEach(this.replyReferences, (reference: GalleryCommentReplyReference): void => {
      Column({ space: ThemeTokens.SPACE_XS }) {
        Row({ space: ThemeTokens.SPACE_XS }) {
          this.ReplyAvatar(reference)
          if (this.replyAuthor(reference).length > 0) {
            Text(this.replyAuthor(reference))
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeTokens.TEXT_LINK)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        Text() {
          ForEach(this.textSegments(this.replyQuoteBody(reference), reference.emphasizedMentions),
            (segment: GalleryCommentTextSegment): void => {
              Span(segment.text)
                .fontColor(segment.emphasized ? ThemeTokens.TEXT_LINK : ThemeTokens.TEXT_SECONDARY)
            },
            (segment: GalleryCommentTextSegment): string => segment.key)
        }
          .width('100%')
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(ThemeTokens.SPACE_SM)
      .borderRadius(COMMENT_QUOTE_RADIUS)
      .backgroundColor(ThemeTokens.SURFACE_SUB)
    }, (reference: GalleryCommentReplyReference): string => reference.comment.commentId.toString())
  }

  private replyAuthor(reference: GalleryCommentReplyReference): string {
    return reference.comment.posterName.length > 0
      ? reference.comment.posterName
      : AppStrings.get('comments_author_anonymous')
  }

  private referenceRenderState(reference: GalleryCommentReplyReference): CommentTranslationRenderState | undefined {
    const commentId: number = reference.comment.commentId
    for (let index: number = 0; index < this.referenceRenderStates.length; index += 1) {
      const state: CommentTranslationRenderState = this.referenceRenderStates[index]
      if (state.commentId === commentId) {
        return state
      }
    }
    return undefined
  }

  private replyQuoteBody(reference: GalleryCommentReplyReference): string {
    const state: CommentTranslationRenderState | undefined = this.referenceRenderState(reference)
    if (this.translationEnabled && state !== undefined && state.shown && state.translated.length > 0) {
      return state.translated
    }
    return reference.body
  }

  private replyAvatarInitial(reference: GalleryCommentReplyReference): string {
    const name: string = this.replyAuthor(reference).trim()
    return name.length > 0 ? name.substring(0, 1).toUpperCase() : '•'
  }

  @Builder
  private ReplyAvatar(reference: GalleryCommentReplyReference) {
    Stack({ alignContent: Alignment.Center }) {
      if (reference.comment.posterAvatarUrl.length > 0) {
        EhImageKnifeImage({
          src: reference.comment.posterAvatarUrl,
          objectFit: ImageFit.Cover,
          radius: COMMENT_QUOTE_AVATAR_SIZE / 2,
          widthValue: COMMENT_QUOTE_AVATAR_SIZE,
          heightValue: COMMENT_QUOTE_AVATAR_SIZE,
          priority: EH_IMAGE_PRIORITY_LOW,
        })
      } else {
        Text(this.replyAvatarInitial(reference))
          .fontSize(Math.max(11, COMMENT_QUOTE_AVATAR_SIZE / 3))
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
      }
    }
    .width(COMMENT_QUOTE_AVATAR_SIZE)
    .height(COMMENT_QUOTE_AVATAR_SIZE)
    .borderRadius(COMMENT_QUOTE_AVATAR_SIZE / 2)
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
  }

  private textSegments(value: string, mentions: string[]): GalleryCommentTextSegment[] {
    const result: GalleryCommentTextSegment[] = []
    // ForEach retains an existing child when its key is unchanged. A key made
    // only from the segment position (for example `text_0`) therefore leaves a
    // reply quote showing its original text after the referenced @Trace state
    // switches to a translation. Include a bounded fingerprint of the actual
    // rendered value so the translated segment subtree is rebuilt, while the
    // same text still keeps stable keys across unrelated card renders.
    const valueKey: string = this.textValueKey(value)
    let cursor: number = 0
    let sequence: number = 0
    while (cursor < value.length) {
      let nextStart: number = -1
      let nextMention: string = ''
      for (let index: number = 0; index < mentions.length; index += 1) {
        const mention: string = mentions[index]
        if (mention.length <= 1) {
          continue
        }
        const start: number = value.indexOf(mention, cursor)
        if (start >= 0 && (nextStart < 0 || start < nextStart ||
          (start === nextStart && mention.length > nextMention.length))) {
          nextStart = start
          nextMention = mention
        }
      }
      if (nextStart < 0) {
        result.push(new GalleryCommentTextSegment(
          `text_${valueKey}_${sequence}`,
          value.substring(cursor),
          false,
        ))
        break
      }
      if (nextStart > cursor) {
        result.push(new GalleryCommentTextSegment(
          `text_${valueKey}_${sequence++}`,
          value.substring(cursor, nextStart),
          false,
        ))
      }
      result.push(new GalleryCommentTextSegment(
        `mention_${valueKey}_${sequence++}`,
        nextMention,
        true,
      ))
      cursor = nextStart + nextMention.length
    }
    if (result.length === 0) {
      result.push(new GalleryCommentTextSegment(`text_${valueKey}_0`, value, false))
    }
    return result
  }

  private textValueKey(value: string): string {
    let hash: number = 0
    for (let index: number = 0; index < value.length; index += 1) {
      hash = (hash * 31 + value.charCodeAt(index)) % 2147483647
    }
    return `${value.length}_${hash}`
  }

  /**
   * Next2V Avatar parity: a circular identity mark beside the author name.
   * The avatar URL is resolved from the API poster.avatar_url at parse time;
   * without a URL the card keeps the same diameter with the author's initial
   * on the sub-surface background instead of collapsing the row.
   */
  @Builder
  private CommentAvatar() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.comment.posterAvatarUrl.length > 0) {
        EhImageKnifeImage({
          src: this.comment.posterAvatarUrl,
          objectFit: ImageFit.Cover,
          radius: COMMENT_AVATAR_SIZE / 2,
          widthValue: COMMENT_AVATAR_SIZE,
          heightValue: COMMENT_AVATAR_SIZE,
          priority: EH_IMAGE_PRIORITY_LOW,
        })
      } else {
        Text(this.avatarPlaceholderInitial())
          .fontSize(Math.max(11, COMMENT_AVATAR_SIZE / 3))
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
      }
    }
    .width(COMMENT_AVATAR_SIZE)
    .height(COMMENT_AVATAR_SIZE)
    .borderRadius(COMMENT_AVATAR_SIZE / 2)
    .backgroundColor(ThemeTokens.SURFACE_SUB)
  }

  @Builder
  private BodyText(value: string, color: ResourceColor) {
    Text() {
      ForEach(this.textSegments(value, this.emphasizedMentions),
        (segment: GalleryCommentTextSegment): void => {
          Span(segment.text)
            .fontColor(segment.emphasized ? ThemeTokens.TEXT_LINK : color)
        },
        (segment: GalleryCommentTextSegment): string => segment.key)
    }
      .width('100%')
      .fontSize(ThemeTokens.FONT_SIZE_BODY)
      .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
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
      Row({ space: ThemeTokens.SPACE_SM }) {
        this.CommentAvatar()
        Text(this.authorLabel())
          .layoutWeight(1)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_LINK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.canTranslate) {
          this.TranslationAction()
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      this.ReplyReferences()
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
          ThemeTokens.TEXT_TERTIARY,
          false,
          AppStrings.get('comments_action_reply'),
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
