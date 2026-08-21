import {
  ContentFilterService,
  ContentFilterState,
  AppStrings,
  BasicDataSource,
  COMMENT_TRANSLATION_DISPLAY_BILINGUAL,
  COMMENT_TRANSLATION_PRIORITY_AUTO,
  COMMENT_TRANSLATION_PRIORITY_INTERACTIVE,
  CommentTranslationService,
  CommentTranslationSettingsState,
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
  connectCommentTranslationSettings,
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
import { GalleryCommentCard } from '../components/GalleryCommentCard'

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

/**
 * The single source of truth for one comment's reactive translation fields
 * (NextE GalleryCommentRenderState parity, NH field subset): a @Trace write
 * re-renders exactly the one card holding this state. The page never
 * publishes array snapshots — the @ObservedV2 object IS the update channel.
 */
@ObservedV2
export class CommentTranslationRenderState {
  @Trace commentId: number = 0
  @Trace translated: string = ''
  @Trace shown: boolean = false
  @Trace loading: boolean = false
  @Trace autoStarted: boolean = false
  @Trace failed: boolean = false
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
  @Local commentTranslationSettings: CommentTranslationSettingsState = connectCommentTranslationSettings()
  @Local loadedGalleryId: number = 0
  @Local isLoading: boolean = false
  @Local errorMessage: string = ''
  @Local commentText: string = ''
  @Local replyTargetId: number = 0
  @Local replyTargetAuthor: string = ''
  @Local replyTargetPreview: string = ''
  @Local isCommentSubmitting: boolean = false
  @Local commentSubmitError: string = ''
  /** Per-comment render states (NextE renderStateMap parity). */
  private renderStateMap: Map<number, CommentTranslationRenderState> = new Map()
  /** Stable LazyForEach owner; only mounted comment cards may start automatic work. */
  private commentDataSource: BasicDataSource<NhComment> = new BasicDataSource<NhComment>(
    (comment: NhComment): string => comment.commentId.toString(),
  )
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
    this.commentDataSource.setData(this.comments)
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
    this.rawComments = this.commentSnapshot.slice()
    this.rebuildRenderStates(true)
    this.applyContentFilters()
    this.loadedGalleryId = this.galleryId
    this.errorMessage = ''
    this.isLoading = false
    return true
  }

  private hasPublishedAccountSession(): boolean {
    return this.accountSession.initialized && this.accountSession.signedIn
  }

  private commentTranslationConfigured(): boolean {
    const binding = this.sources.commentBinding
    if (!binding.configured()) {
      return false
    }
    const profile = this.sources.findById(binding.sourceProfileId)
    return profile !== null && supportsCommentTranslation(profile)
  }

  /**
   * Rebuilds render states from the current raw comments (NextE
   * rebuildCommentList parity): resetStates keeps nothing (fresh route /
   * refresh); otherwise existing states survive so in-flight translations and
   * shown-toggles are never discarded by a filter change.
   */
  private rebuildRenderStates(resetStates: boolean): void {
    const next: Map<number, CommentTranslationRenderState> = new Map()
    for (let index: number = 0; index < this.rawComments.length; index++) {
      const comment: NhComment = this.rawComments[index]
      const existing: CommentTranslationRenderState | undefined = resetStates
        ? undefined
        : this.renderStateMap.get(comment.commentId)
      if (existing !== undefined) {
        next.set(comment.commentId, existing)
      } else {
        const state: CommentTranslationRenderState = new CommentTranslationRenderState()
        state.commentId = comment.commentId
        next.set(comment.commentId, state)
      }
    }
    this.renderStateMap = next
  }

  /** List builder lookup; the map is rebuilt before the list renders. */
  private renderStateFor(comment: NhComment): CommentTranslationRenderState {
    const existing: CommentTranslationRenderState | undefined = this.renderStateMap.get(comment.commentId)
    if (existing !== undefined) {
      return existing
    }
    const state: CommentTranslationRenderState = new CommentTranslationRenderState()
    state.commentId = comment.commentId
    this.renderStateMap.set(comment.commentId, state)
    return state
  }

  /**
   * All reactive translation mutations go through this one writer (NextE
   * applyCommentTranslationState parity): fields are written SYNCHRONOUSLY
   * onto the per-comment @ObservedV2 state; the @Trace write re-renders that
   * one card. No array slice, no global version bump.
   */
  private applyCommentTranslationState(
    commentId: number,
    translated: string | undefined,
    shown: boolean | undefined,
    loading: boolean | undefined,
    autoStarted: boolean | undefined = undefined,
    failed: boolean | undefined = undefined,
  ): void {
    const state: CommentTranslationRenderState | undefined = this.renderStateMap.get(commentId)
    if (state === undefined) {
      return
    }
    if (translated !== undefined) {
      state.translated = translated
    }
    if (shown !== undefined) {
      state.shown = shown
    }
    if (loading !== undefined) {
      state.loading = loading
    }
    if (autoStarted !== undefined) {
      state.autoStarted = autoStarted
    }
    if (failed !== undefined) {
      state.failed = failed
    }
  }

  private canTranslate(comment: NhComment): boolean {
    return this.commentTranslationSettings.enabled &&
      this.commentTranslationConfigured() &&
      this.replyBody(comment).trim().length > 0
  }

  private replyQuoteBodyFor(comment: NhComment): string {
    const reference: NhComment = this.replyReferenceOrFallback(comment)
    const body: string = this.replyBody(reference)
    return body.length > 0 ? body : AppStrings.get('comments_empty_body')
  }

  private isTranslationShown(comment: NhComment): boolean {
    const state: CommentTranslationRenderState | undefined = this.renderStateMap.get(comment.commentId)
    return state !== undefined && state.shown && this.commentTranslationSettings.enabled &&
      state.translated.length > 0
  }

  private isTranslationLoading(comment: NhComment): boolean {
    const state: CommentTranslationRenderState | undefined = this.renderStateMap.get(comment.commentId)
    return state !== undefined && state.loading
  }

  /** NextE parity: one mounted LazyForEach card owns one automatic attempt. */
  private autoTranslateComment(comment: NhComment): void {
    if (!this.commentTranslationSettings.enabled || !this.commentTranslationSettings.autoTranslate ||
      !this.canTranslate(comment)) {
      return
    }
    const state: CommentTranslationRenderState = this.renderStateFor(comment)
    if (state.autoStarted || state.loading || state.translated.length > 0) {
      return
    }
    const source: string = this.replyBody(comment)
    if (source.trim().length === 0 || !CommentTranslationService.needsTranslation(source)) {
      return
    }
    this.applyCommentTranslationState(comment.commentId, undefined, undefined, undefined, true, false)
    this.toggleOrTranslate(comment, COMMENT_TRANSLATION_PRIORITY_AUTO)
  }

  private translationActionLabel(comment: NhComment): string {
    return this.isTranslationShown(comment)
      ? AppStrings.get('comments_translation_show_original')
      : AppStrings.get('comments_translation_action')
  }

  private async toggleOrTranslate(
    comment: NhComment,
    priority: number = COMMENT_TRANSLATION_PRIORITY_INTERACTIVE,
  ): Promise<void> {
    if (!this.canTranslate(comment)) {
      return
    }
    const state: CommentTranslationRenderState = this.renderStateFor(comment)
    if (state.loading) {
      return
    }
    if (state.translated.length > 0) {
      this.applyCommentTranslationState(comment.commentId, undefined, !state.shown, undefined)
      return
    }
    const galleryId: number = this.galleryId
    this.applyCommentTranslationState(comment.commentId, undefined, undefined, true, undefined, false)
    try {
      const translated: string = await CommentTranslationService.translate(
        this.context(),
        this.replyBody(comment),
        priority,
      )
      if (this.galleryId === galleryId && this.loadedGalleryId === galleryId) {
        this.applyCommentTranslationState(
          comment.commentId,
          translated,
          translated.length > 0,
          false,
          undefined,
          false,
        )
      } else {
        this.applyCommentTranslationState(comment.commentId, undefined, undefined, false)
      }
    } catch (_error) {
      const error: Error = _error as Error
      if (priority === COMMENT_TRANSLATION_PRIORITY_AUTO && CommentTranslationService.isQueueCapacityError(error)) {
        // Queue-evicted background work stays untranslated without a toast (NextE parity).
        this.applyCommentTranslationState(comment.commentId, undefined, undefined, false, undefined, false)
        return
      }
      if (this.galleryId === galleryId) {
        this.showCommentToast(AppStrings.get('comments_translation_failed'))
      }
      this.applyCommentTranslationState(comment.commentId, undefined, undefined, false, undefined, true)
    }
  }

  private isCurrentRequest(generation: number): boolean {
    return generation === this.requestGeneration
  }

  private async loadComments(): Promise<void> {
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    if (this.loadedGalleryId !== this.galleryId) {
      this.rawComments = []
      this.rebuildRenderStates(true)
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
    return this.composerInteractionAvailable() && this.hasCommentMessage() && !this.isCommentSubmitting
  }

  private hasCommentMessage(): boolean {
    if (!this.hasReplyContext()) {
      return this.commentText.trim().length > 0
    }
    return this.commentText.split('\n').slice(2).join('\n').trim().length > 0
  }

  /** The composer stays mounted; this gate controls only mutation interaction. */
  private composerInteractionAvailable(): boolean {
    return this.hasPublishedAccountSession() && !this.isLoading && this.loadedGalleryId === this.galleryId
  }

  /** A successful empty snapshot is resolved; only a missing route result is initial. */
  private initialCommentsResolutionPending(): boolean {
    return this.loadedGalleryId !== this.galleryId
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
          .enabled(!this.isCommentSubmitting && this.composerInteractionAvailable())
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
  private SettledCommentsContent() {
    if (this.initialCommentsResolutionPending()) {
      if (this.errorMessage.length > 0) {
        ListItem() {
          Column() {
            PageErrorState({
              message: this.errorMessage,
              onRetry: (): void => {
                this.loadComments()
              },
            })
          }
          .width('100%')
          .height(240)
          .justifyContent(FlexAlign.Center)
        }
      } else {
        ListItem() {
          Column() {
            PageLoadingState({ text: AppStrings.get('comments_status_loading') })
          }
          .width('100%')
          .height(240)
          .justifyContent(FlexAlign.Center)
        }
      }
    } else {
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
        LazyForEach(this.commentDataSource, (comment: NhComment): void => {
          ListItem() {
            GalleryCommentCard({
              comment: comment,
              body: this.replyBody(comment),
              renderState: this.renderStateFor(comment),
              canTranslate: this.canTranslate(comment),
              autoTranslate: this.commentTranslationSettings.autoTranslate,
              bilingual: this.commentTranslationSettings.displayMode ===
                COMMENT_TRANSLATION_DISPLAY_BILINGUAL,
              replyQuoteBody: this.hasReplyReference(comment)
                ? this.replyQuoteBodyFor(comment)
                : '',
              replyQuoteAuthor: this.hasReplyReference(comment)
                ? this.authorLabel(this.replyReferenceOrFallback(comment))
                : '',
              onToggleTranslate: (): void => {
                this.toggleOrTranslate(comment)
              },
              onAutoTranslate: (): void => {
                this.autoTranslateComment(comment)
              },
              onReply: (): void => {
                this.openReply(comment)
              },
            })
          }
        }, (comment: NhComment): string => comment.commentId.toString())
      }
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
        refreshEnabled: !this.initialCommentsResolutionPending() && !this.isLoading,
        onRefresh: async (): Promise<void> => {
          await this.loadComments()
        },
      }) {
        this.SettledCommentsContent()
      }
      this.CommentComposer()
    }
    .width('100%')
    .height('100%')
  }

  build() {
    HdsNavDestination() {
      this.SettledCommentsPage()
    }
    .titleBar(nextNHdsTitle(AppStrings.get('title_comments')))
    .hideBackButton(false)
    .bindToScrollable([this.scroller])
    .backgroundColor(ThemeTokens.SURFACE)
  }
}
