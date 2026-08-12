import {
  ContentFilterService,
  ContentFilterState,
  AppStrings,
  CommentTranslationService,
  InlineRetryNotice,
  LayoutSafeAreaState,
  NhApiClient,
  AccountSessionState,
  NhComment,
  LlmSourceProfilesState,
  NextNPullRefreshController,
  PageEmptyState,
  PageErrorState,
  PageLoadingState,
  PullRefreshListScaffold,
  ThemeTokens,
  connectAccountSession,
  connectContentFilters,
  connectLayoutSafeArea,
  connectLlmSourceProfiles,
  nextNHdsTitle,
  supportsCommentTranslation,
} from 'shared'
import { common } from '@kit.AbilityKit'
import { KeyboardAvoidMode, uiMaterial } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'
import { HdsNavDestination } from '@kit.UIDesignKit'

const COMMENT_COMPOSER_FIELD_ID: string = 'nextn-gallery-comments-composer-field'
const COMMENT_COMPOSER_BOTTOM_RESERVE: number = 136
const COMMENT_COMPOSER_OUTER_GAP: number = ThemeTokens.SPACE_SM
const COMMENT_COMPOSER_INNER_GAP: number = ThemeTokens.SPACE_XS
const COMMENT_COMPOSER_SEND_SIZE: number = 36
const COMMENT_COMPOSER_CLOSE_ICON_SIZE: number =
  COMMENT_COMPOSER_SEND_SIZE - COMMENT_COMPOSER_INNER_GAP * 2
const COMMENT_COMPOSER_RADIUS: number = COMMENT_COMPOSER_SEND_SIZE / 2 + COMMENT_COMPOSER_INNER_GAP
const COMMENT_COMPOSER_INPUT_MAX_H: number = 148
const COMMENT_COMPOSER_QUOTE_LINE_WIDTH: number = 4
const COMMENT_COMPOSER_QUOTE_LINE_HEIGHT: number = 48
const COMMENT_CARD_CONTENT_INSET: number = ThemeTokens.SPACE_MD
const COMMENT_CARD_TOP_INSET: number = ThemeTokens.SPACE_MD
const COMMENT_CARD_BOTTOM_INSET: number = ThemeTokens.SPACE_SM
const COMMENT_ACTION_SIZE: number = 30
const COMMENT_ACTION_ICON_SIZE: number = 16
const COMMENT_QUOTE_RADIUS: number = ThemeTokens.RADIUS_SM + ThemeTokens.SPACE_XS

class CommentTranslationCardState {
  commentId: number = 0
  translated: string = ''
  shown: boolean = false
  loading: boolean = false
}

/**
 * A separate destination keeps comments from competing with the Gallery hero
 * and Read action. The HDS owns the destination title while this page owns
 * one pull-to-refresh list and its persistent bottom composer.
 */
@ComponentV2
export struct GalleryCommentsPage {
  @Require @Param galleryId: number
  @Local comments: NhComment[] = []
  /** Retain the returned discussion so local rules reapply without a request. */
  @Local rawComments: NhComment[] = []
  @Local contentFilters: ContentFilterState = connectContentFilters()
  @Local accountSession: AccountSessionState = connectAccountSession()
  @Local sources: LlmSourceProfilesState = connectLlmSourceProfiles()
  @Local loadedGalleryId: number = 0
  @Local isLoading: boolean = false
  @Local errorMessage: string = ''
  @Local commentText: string = ''
  @Local replyTargetId: number = 0
  @Local replyTargetAuthor: string = ''
  @Local replyTargetPreview: string = ''
  @Local isCommentSubmitting: boolean = false
  @Local commentSubmitError: string = ''
  @Local translations: CommentTranslationCardState[] = []
  @Param scroller: Scroller = new Scroller()
  /** A Detail-owned response seeds this route only after it was successfully fetched. */
  @Param commentSnapshot: NhComment[] = []
  @Param commentSnapshotAvailable: boolean = false
  private layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  private requestGeneration: number = 0
  private commentSubmitGeneration: number = 0
  private refreshController: NextNPullRefreshController = new NextNPullRefreshController()

  aboutToAppear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
    if (this.hydrateDetailSnapshot()) {
      return
    }
    if (!this.isLoading && this.loadedGalleryId !== this.galleryId) {
      this.loadComments()
    }
  }

  aboutToDisappear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
  }

  @Monitor('galleryId')
  onGalleryChanged(): void {
    if (this.hydrateDetailSnapshot()) {
      return
    }
    if (!this.isLoading && this.loadedGalleryId !== this.galleryId) {
      this.loadComments()
    }
  }

  @Monitor('contentFilters.revision')
  onContentFiltersChanged(): void {
    this.applyContentFilters()
  }

  private applyContentFilters(): void {
    this.comments = ContentFilterService.filterComments(this.rawComments)
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  /**
   * A Detail-owned snapshot is authoritative for this initial route only. It
   * is allowed to be empty: availability distinguishes an empty successful
   * response from a request that has not completed. Subsequent explicit
   * refreshes still use the full route request path.
   */
  private hydrateDetailSnapshot(): boolean {
    if (!this.commentSnapshotAvailable || this.loadedGalleryId === this.galleryId) {
      return false
    }
    this.requestGeneration += 1
    this.translations = []
    this.rawComments = this.commentSnapshot.slice()
    this.applyContentFilters()
    this.loadedGalleryId = this.galleryId
    this.errorMessage = ''
    this.isLoading = false
    return true
  }

  private hasPublishedAccountSession(): boolean {
    return this.accountSession.initialized && this.accountSession.signedIn &&
      !this.accountSession.verificationRequired
  }

  private commentTranslationConfigured(): boolean {
    const binding = this.sources.commentBinding
    if (!binding.configured()) {
      return false
    }
    const profile = this.sources.findById(binding.sourceProfileId)
    return profile !== null && supportsCommentTranslation(profile)
  }

  private translationState(commentId: number): CommentTranslationCardState | null {
    for (let index: number = 0; index < this.translations.length; index++) {
      if (this.translations[index].commentId === commentId) {
        return this.translations[index]
      }
    }
    return null
  }

  private ensureTranslationState(commentId: number): CommentTranslationCardState {
    const existing: CommentTranslationCardState | null = this.translationState(commentId)
    if (existing !== null) {
      return existing
    }
    const state: CommentTranslationCardState = new CommentTranslationCardState()
    state.commentId = commentId
    this.translations = this.translations.concat([state])
    return state
  }

  private publishTranslations(): void {
    this.translations = this.translations.slice()
  }

  private canTranslate(comment: NhComment): boolean {
    return this.commentTranslationConfigured() && this.replyBody(comment).trim().length > 0
  }

  private displayedCommentBody(comment: NhComment): string {
    const state: CommentTranslationCardState | null = this.translationState(comment.commentId)
    if (state !== null && state.shown && state.translated.length > 0) {
      return state.translated
    }
    const body: string = this.replyBody(comment)
    return body.length > 0 ? body : AppStrings.get('comments_empty_body')
  }

  private isTranslationLoading(comment: NhComment): boolean {
    const state: CommentTranslationCardState | null = this.translationState(comment.commentId)
    return state !== null && state.loading
  }

  private isTranslationShown(comment: NhComment): boolean {
    const state: CommentTranslationCardState | null = this.translationState(comment.commentId)
    return state !== null && state.shown && state.translated.length > 0
  }

  private translationActionLabel(comment: NhComment): string {
    return this.isTranslationShown(comment)
      ? AppStrings.get('comments_translation_show_original')
      : AppStrings.get('comments_translation_action')
  }

  private async toggleOrTranslate(comment: NhComment): Promise<void> {
    if (!this.canTranslate(comment)) {
      return
    }
    const state: CommentTranslationCardState = this.ensureTranslationState(comment.commentId)
    if (state.loading) {
      return
    }
    if (state.translated.length > 0) {
      state.shown = !state.shown
      this.publishTranslations()
      return
    }
    const galleryId: number = this.galleryId
    state.loading = true
    this.publishTranslations()
    try {
      const translated: string = await CommentTranslationService.translate(this.context(), this.replyBody(comment))
      if (this.galleryId === galleryId && this.loadedGalleryId === galleryId) {
        state.translated = translated
        state.shown = translated.length > 0
      }
    } catch (_error) {
      if (this.galleryId === galleryId) {
        this.showCommentToast(AppStrings.get('comments_translation_failed'))
      }
    } finally {
      state.loading = false
      this.publishTranslations()
    }
  }

  private isCurrentRequest(generation: number): boolean {
    return generation === this.requestGeneration
  }

  private async loadComments(): Promise<void> {
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    if (this.loadedGalleryId !== this.galleryId) {
      this.translations = []
      this.rawComments = []
      this.applyContentFilters()
      this.loadedGalleryId = 0
    }
    this.isLoading = true
    this.errorMessage = ''
    try {
      const comments: NhComment[] = await NhApiClient.comments(this.galleryId)
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.rawComments = comments
      this.applyContentFilters()
      this.loadedGalleryId = this.galleryId
    } catch (error) {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.errorMessage = (error as Error).message || AppStrings.get('comments_error_load')
    } finally {
      if (this.isCurrentRequest(generation)) {
        this.isLoading = false
      }
    }
  }

  private authorLabel(comment: NhComment): string {
    return comment.posterName.length > 0 ? comment.posterName : AppStrings.get('comments_author_anonymous')
  }

  private twoDigits(value: number): string {
    return value < 10 ? `0${value}` : value.toString()
  }

  private postedLabel(comment: NhComment): string {
    if (comment.postDate <= 0) {
      return ''
    }
    const date: Date = new Date(comment.postDate * 1000)
    if (isNaN(date.getTime())) {
      return ''
    }
    return `${date.getFullYear()}-${this.twoDigits(date.getMonth() + 1)}-${this.twoDigits(date.getDate())} ` +
      `${this.twoDigits(date.getHours())}:${this.twoDigits(date.getMinutes())}`
  }

  private replyCodeForDigit(digit: string): string {
    if (digit === '0') return '····'
    if (digit === '1') return '···-'
    if (digit === '2') return '··-·'
    if (digit === '3') return '··--'
    if (digit === '4') return '·-··'
    if (digit === '5') return '·-·-'
    if (digit === '6') return '·--·'
    if (digit === '7') return '·---'
    if (digit === '8') return '-···'
    if (digit === '9') return '-··-'
    return ''
  }

  private replyDigitForCode(code: string): string {
    if (code === '····') return '0'
    if (code === '···-') return '1'
    if (code === '··-·') return '2'
    if (code === '··--') return '3'
    if (code === '·-··') return '4'
    if (code === '·-·-') return '5'
    if (code === '·--·') return '6'
    if (code === '·---') return '7'
    if (code === '-···') return '8'
    if (code === '-··-') return '9'
    return ''
  }

  private encodeReplyId(commentId: number): string {
    const id: string = commentId.toString()
    let encoded: string = ''
    for (let index: number = 0; index < id.length; index += 1) {
      const code: string = this.replyCodeForDigit(id.charAt(index))
      if (code.length === 0) {
        return ''
      }
      encoded += code
    }
    return encoded
  }

  private decodeReplyId(line: string): number {
    let normalized: string = ''
    for (let index: number = 0; index < line.length; index += 1) {
      const character: string = line.charAt(index)
      if (character === '·' || character === '.') {
        normalized += '·'
      } else if (character === '-') {
        normalized += '-'
      }
    }
    if (normalized.length === 0 || normalized.length % 4 !== 0) {
      return 0
    }
    let decoded: string = ''
    for (let index: number = 0; index < normalized.length; index += 4) {
      const digit: string = this.replyDigitForCode(normalized.substring(index, index + 4))
      if (digit.length === 0) {
        return 0
      }
      decoded += digit
    }
    const value: number = Number.parseInt(decoded, 10)
    return Number.isNaN(value) || value <= 0 ? 0 : value
  }

  private replyTarget(comment: NhComment): NhComment | null {
    const lines: string[] = comment.body.split('\n')
    if (lines.length < 2 || !lines[0].trim().startsWith('@')) {
      return null
    }
    const targetId: number = this.decodeReplyId(lines[1])
    if (targetId <= 0 || targetId === comment.commentId) {
      return null
    }
    for (let index: number = 0; index < this.rawComments.length; index += 1) {
      const candidate: NhComment = this.rawComments[index]
      if (candidate.commentId === targetId) {
        return candidate
      }
    }
    return null
  }

  private replyBody(comment: NhComment): string {
    if (this.replyTarget(comment) === null) {
      return comment.body
    }
    return comment.body.split('\n').slice(2).join('\n').trim()
  }

  private hasReplyReference(comment: NhComment): boolean {
    return this.replyTarget(comment) !== null
  }

  private replyReferenceOrFallback(comment: NhComment): NhComment {
    const target: NhComment | null = this.replyTarget(comment)
    return target !== null ? target : comment
  }

  private replyPlaceholder(): string {
    return this.replyTargetId > 0
      ? AppStrings.get('comments_reply_placeholder')
      : AppStrings.get('comments_placeholder')
  }

  private hasReplyContext(): boolean {
    return this.replyTargetId > 0 && this.replyTargetAuthor.length > 0
  }

  private replyContextTitle(): string {
    return AppStrings.format('comments_replying_to', [this.replyTargetAuthor])
  }

  private openReply(comment: NhComment): void {
    if (this.isCommentSubmitting) {
      return
    }
    if (!this.hasPublishedAccountSession()) {
      this.showCommentToast(AppStrings.get('comments_error_signin_post'))
      return
    }
    const prefix: string = this.encodeReplyId(comment.commentId)
    if (prefix.length === 0) {
      return
    }
    this.replyTargetId = comment.commentId
    this.replyTargetAuthor = this.authorLabel(comment)
    this.replyTargetPreview = this.replyBody(comment)
    this.commentText = `@${this.replyTargetAuthor}\n${prefix}\n`
    this.commentSubmitError = ''
    this.requestComposerFocus()
  }

  private clearReplyContext(): void {
    this.replyTargetId = 0
    this.replyTargetAuthor = ''
    this.replyTargetPreview = ''
    this.commentText = ''
    this.commentSubmitError = ''
  }

  private canSubmitComment(): boolean {
    return this.hasPublishedAccountSession() && this.hasCommentMessage() && !this.isCommentSubmitting
  }

  private hasCommentMessage(): boolean {
    if (!this.hasReplyContext()) {
      return this.commentText.trim().length > 0
    }
    return this.commentText.split('\n').slice(2).join('\n').trim().length > 0
  }

  private composerAvailable(): boolean {
    return this.hasPublishedAccountSession() && !this.isLoading && this.loadedGalleryId === this.galleryId
  }

  private requestComposerFocus(): void {
    if (this.isCommentSubmitting) {
      return
    }
    if (!this.hasPublishedAccountSession()) {
      this.showCommentToast(AppStrings.get('comments_error_signin_post'))
      return
    }
    this.commentSubmitError = ''
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus(COMMENT_COMPOSER_FIELD_ID)
    }, 80)
  }

  private async submitComment(): Promise<void> {
    if (!this.canSubmitComment()) {
      return
    }
    const generation: number = this.commentSubmitGeneration + 1
    const galleryId: number = this.galleryId
    this.commentSubmitGeneration = generation
    this.isCommentSubmitting = true
    this.commentSubmitError = ''
    try {
      const comment: NhComment | null = await NhApiClient.postComment(galleryId, this.commentText)
      if (generation !== this.commentSubmitGeneration || galleryId !== this.galleryId) {
        return
      }
      if (comment !== null) {
        this.rawComments = [comment, ...this.rawComments.filter((item: NhComment): boolean => item.commentId !== comment.commentId)]
        this.applyContentFilters()
      } else {
        // The remote mutation is already confirmed. A normal GET refresh is
        // safe here and avoids guessing the created record or replaying POST.
        this.loadComments()
      }
      this.clearReplyContext()
      this.showCommentToast(AppStrings.get('comments_toast_posted'))
    } catch (_error) {
      if (generation === this.commentSubmitGeneration && galleryId === this.galleryId) {
        this.commentSubmitError = AppStrings.get('comments_error_post')
      }
    } finally {
      if (generation === this.commentSubmitGeneration && galleryId === this.galleryId) {
        this.isCommentSubmitting = false
      }
    }
  }

  private showCommentToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_error) {}
  }

  private composerBottomPadding(): number {
    if (this.layoutSafeArea.keyboardHeight > 0) {
      return ThemeTokens.SPACE_SM
    }
    return this.layoutSafeArea.bottomAvoidHeight
  }

  @Builder
  private CommentComposerFields() {
    Column({ space: COMMENT_COMPOSER_INNER_GAP }) {
      if (this.hasReplyContext()) {
        Row({ space: ThemeTokens.SPACE_SM }) {
          Blank()
            .width(COMMENT_COMPOSER_QUOTE_LINE_WIDTH)
            .height(COMMENT_COMPOSER_QUOTE_LINE_HEIGHT)
            .backgroundColor(ThemeTokens.BRAND)
            .borderRadius(COMMENT_COMPOSER_QUOTE_LINE_WIDTH / 2)
          Column({ space: ThemeTokens.SPACE_XS }) {
            Text(this.replyContextTitle())
              .width('100%')
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeTokens.TEXT_LINK)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.replyTargetPreview)
              .width('100%')
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(COMMENT_COMPOSER_CLOSE_ICON_SIZE)
              .fontColor([ThemeTokens.TEXT_SECONDARY])
          }
          .width(COMMENT_COMPOSER_SEND_SIZE)
          .height(COMMENT_COMPOSER_SEND_SIZE)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .backgroundColor(Color.Transparent)
          .accessibilityText(AppStrings.get('common_cancel'))
          .onClick((): void => {
            this.clearReplyContext()
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({
          left: COMMENT_COMPOSER_RADIUS - COMMENT_COMPOSER_INNER_GAP - COMMENT_COMPOSER_QUOTE_LINE_WIDTH / 2,
          right: COMMENT_COMPOSER_INNER_GAP,
          top: COMMENT_COMPOSER_INNER_GAP,
        })
      }
      Row({ space: ThemeTokens.SPACE_SM }) {
        TextArea({ text: this.commentText, placeholder: this.replyPlaceholder() })
          .id(COMMENT_COMPOSER_FIELD_ID)
          .constraintSize({ maxHeight: COMMENT_COMPOSER_INPUT_MAX_H })
          .maxLines(8)
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .enabled(!this.isCommentSubmitting && this.hasPublishedAccountSession())
          .onChange((value: string): void => {
            this.commentText = value
            this.commentSubmitError = ''
          })
        SymbolGlyph($r('sys.symbol.location_north_up_right_circle_fill'))
          .fontSize(COMMENT_COMPOSER_SEND_SIZE)
          .fontColor([
            this.canSubmitComment() ? ThemeTokens.BRAND : ThemeTokens.TEXT_TERTIARY,
          ])
          .opacity(this.canSubmitComment() ? 1 : 0.45)
          .onClick((): void => {
            this.submitComment()
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      if (this.commentSubmitError.length > 0) {
        Text(this.commentSubmitError)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
          .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private MaterialCommentComposerSurface() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      Column({ space: COMMENT_COMPOSER_INNER_GAP }) {
        this.CommentComposerFields()
      }
      .width('100%')
      .padding({
        left: COMMENT_COMPOSER_INNER_GAP,
        right: COMMENT_COMPOSER_INNER_GAP,
        top: COMMENT_COMPOSER_INNER_GAP,
        bottom: COMMENT_COMPOSER_INNER_GAP,
      })
      .backgroundColor(Color.Transparent)
      .systemMaterial(this.composerSystemMaterial())
      .borderRadius(COMMENT_COMPOSER_RADIUS)
    } else {
      this.FallbackCommentComposerSurface()
    }
  }

  @Builder
  private FallbackCommentComposerSurface() {
    Column({ space: COMMENT_COMPOSER_INNER_GAP }) {
      this.CommentComposerFields()
    }
    .width('100%')
    .padding({
      left: COMMENT_COMPOSER_INNER_GAP,
      right: COMMENT_COMPOSER_INNER_GAP,
      top: COMMENT_COMPOSER_INNER_GAP,
      bottom: COMMENT_COMPOSER_INNER_GAP,
    })
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
    .borderRadius(COMMENT_COMPOSER_RADIUS)
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
  }

  private composerSystemMaterial() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THICK,
        colorInvert: true,
        applyShadow: true,
        interactive: true,
      })
    }
    return undefined
  }

  @Builder
  private CommentComposer() {
    Column() {
      if (deviceInfo.apiAvailable('26.0.0')) {
        this.MaterialCommentComposerSurface()
      } else {
        this.FallbackCommentComposerSurface()
      }
    }
    .width('100%')
    .padding({
      left: COMMENT_COMPOSER_OUTER_GAP,
      right: COMMENT_COMPOSER_OUTER_GAP,
      bottom: this.composerBottomPadding(),
    })
  }

  @Builder
  private RefreshFailureNotice() {
    Column() {
      InlineRetryNotice({
        message: this.errorMessage,
        onRetry: (): void => {
          this.loadComments()
        },
      })
    }
    .width('100%')
    .padding({
      bottom: ThemeTokens.SPACE_SM,
    })
  }

  @Builder
  private ReplyQuote(comment: NhComment) {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Text(this.authorLabel(comment))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_LINK)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.replyBody(comment).length > 0 ? this.replyBody(comment) : AppStrings.get('comments_empty_body'))
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

  @Builder
  private CommentFooterAction(
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
  private ReplyReferences(comment: NhComment) {
    if (this.hasReplyReference(comment)) {
      this.ReplyQuote(this.replyReferenceOrFallback(comment))
    }
  }

  @Builder
  private CommentCard(comment: NhComment) {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Row() {
        Text(this.authorLabel(comment))
          .layoutWeight(1)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_LINK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.canTranslate(comment)) {
          this.CommentFooterAction(
            $r('sys.symbol.translate'),
            this.translationActionLabel(comment),
            this.isTranslationLoading(comment),
            this.isTranslationShown(comment),
            (): void => {
              this.toggleOrTranslate(comment)
            },
          )
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      this.ReplyReferences(comment)
      Text(this.displayedCommentBody(comment))
        .width('100%')
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
      Row() {
        if (this.postedLabel(comment).length > 0) {
          Text(this.postedLabel(comment))
            .layoutWeight(1)
            .fontSize(ThemeTokens.FONT_SIZE_TINY)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          Blank().layoutWeight(1)
        }
        this.CommentFooterAction(
          $r('sys.symbol.ellipsis_message'),
          AppStrings.get('comments_action_reply'),
          false,
          false,
          (): void => {
            this.openReply(comment)
          },
        )
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: COMMENT_CARD_CONTENT_INSET,
      right: COMMENT_CARD_CONTENT_INSET,
      top: COMMENT_CARD_TOP_INSET,
      bottom: COMMENT_CARD_BOTTOM_INSET,
    })
    .borderRadius(ThemeTokens.RADIUS_CARD)
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
  }

  @Builder
  private SettledCommentsContent() {
    if (this.errorMessage.length > 0) {
      ListItem() {
        this.RefreshFailureNotice()
      }
    }
    if (this.comments.length === 0) {
      ListItem() {
        PageEmptyState({
          message: this.rawComments.length > 0
            ? AppStrings.get('comments_status_filtered_empty')
            : AppStrings.get('comments_status_empty'),
        })
      }
    } else {
      ForEach(this.comments, (comment: NhComment): void => {
        ListItem() {
          this.CommentCard(comment)
        }
      }, (comment: NhComment): string => comment.commentId.toString())
    }
  }

  @Builder
  private SettledCommentsPage() {
    Stack({ alignContent: Alignment.Bottom }) {
      PullRefreshListScaffold({
        scroller: this.scroller,
        listSpace: ThemeTokens.SPACE_SM - 2,
        bottomPadding: COMMENT_COMPOSER_BOTTOM_RESERVE,
        controller: this.refreshController,
        onRefresh: async (): Promise<void> => {
          await this.loadComments()
        },
      }) {
        this.SettledCommentsContent()
      }
      if (this.composerAvailable()) {
        this.CommentComposer()
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    HdsNavDestination() {
      if (this.isLoading && this.comments.length === 0) {
        PageLoadingState({ text: AppStrings.get('comments_status_loading') })
      } else if (this.errorMessage.length > 0 && this.comments.length === 0) {
        PageErrorState({
          message: this.errorMessage,
          onRetry: (): void => {
            this.loadComments()
          },
        })
      } else {
        this.SettledCommentsPage()
      }
    }
    .titleBar(nextNHdsTitle(AppStrings.get('title_comments')))
    .hideBackButton(false)
    .bindToScrollable([this.scroller])
    .backgroundColor(ThemeTokens.SURFACE)
  }
}
