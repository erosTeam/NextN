import {
  ContentFilterService,
  ContentFilterState,
  AppStrings,
  InlineRetryNotice,
  LayoutSafeAreaState,
  NhApiClient,
  AccountSessionState,
  NhComment,
  NextNPullRefreshController,
  PageEmptyState,
  PageErrorState,
  PageLoadingState,
  PullRefreshListScaffold,
  ThemeTokens,
  connectAccountSession,
  connectContentFilters,
  connectLayoutSafeArea,
} from 'shared'
import { KeyboardAvoidMode, uiMaterial } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'

const COMMENT_COMPOSER_BOTTOM_RESERVE: number = 136
const COMMENT_COMPOSER_FIELD_ID: string = 'nextn-gallery-comments-composer-field'
const COMMENT_COMPOSER_OUTER_GAP: number = ThemeTokens.SPACE_SM
const COMMENT_COMPOSER_INNER_GAP: number = ThemeTokens.SPACE_XS
const COMMENT_COMPOSER_SEND_SIZE: number = 36
const COMMENT_COMPOSER_RADIUS: number =
  COMMENT_COMPOSER_SEND_SIZE / 2 + COMMENT_COMPOSER_INNER_GAP
const COMMENT_COMPOSER_INPUT_MAX_H: number = 148

/**
 * A separate destination keeps comments from competing with the Gallery hero
 * and Read action. The HDS compose action focuses the page-owned bottom
 * composer; it does not open a second full-height navigation surface.
 */
@ComponentV2
export struct GalleryCommentsPage {
  @Require @Param galleryId: number
  @Local comments: NhComment[] = []
  /** Retain the returned discussion so local rules reapply without a request. */
  @Local rawComments: NhComment[] = []
  @Local contentFilters: ContentFilterState = connectContentFilters()
  @Local accountSession: AccountSessionState = connectAccountSession()
  @Local loadedGalleryId: number = 0
  @Local isLoading: boolean = false
  @Local errorMessage: string = ''
  @Local commentText: string = ''
  @Local isCommentSubmitting: boolean = false
  @Local commentSubmitError: string = ''
  @Param scroller: Scroller = new Scroller()
  /** A Detail-owned response seeds this route only after it was successfully fetched. */
  @Param commentSnapshot: NhComment[] = []
  @Param commentSnapshotAvailable: boolean = false
  @Param reloadVersion: number = 0
  @Param composeVersion: number = 0
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

  @Monitor('reloadVersion')
  onReloadRequested(): void {
    if (this.reloadVersion > 0) {
      this.loadComments()
    }
  }

  @Monitor('composeVersion')
  onComposeRequested(): void {
    if (this.composeVersion > 0) {
      this.requestComposerFocus()
    }
  }

  @Monitor('contentFilters.revision')
  onContentFiltersChanged(): void {
    this.applyContentFilters()
  }

  private applyContentFilters(): void {
    this.comments = ContentFilterService.filterComments(this.rawComments)
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

  private isCurrentRequest(generation: number): boolean {
    return generation === this.requestGeneration
  }

  private async loadComments(): Promise<void> {
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    if (this.loadedGalleryId !== this.galleryId) {
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

  private canSubmitComment(): boolean {
    return this.hasPublishedAccountSession() && this.commentText.trim().length > 0 && !this.isCommentSubmitting
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
      this.commentText = ''
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
      return COMMENT_COMPOSER_OUTER_GAP
    }
    return this.layoutSafeArea.bottomAvoidHeight + COMMENT_COMPOSER_OUTER_GAP
  }

  @Builder
  private CommentComposerFields() {
    Column({ space: COMMENT_COMPOSER_INNER_GAP }) {
      Row({ space: ThemeTokens.SPACE_SM }) {
        TextArea({ text: this.commentText, placeholder: AppStrings.get('comments_placeholder') })
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
  private CommentComposerSurface() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      Column() {
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
      Column() {
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
    }
  }

  @Builder
  private CommentComposer() {
    Column() {
      this.CommentComposerSurface()
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
  private CommentCard(comment: NhComment) {
    // Keep the NextE full-comment hierarchy: a compact head row, the body,
    // then a separate metadata footer.  NH exposes no avatar, score, vote,
    // reply, edit, or translation leaves, so those leaves are omitted rather
    // than replaced by a new card design.
    Column({ space: ThemeTokens.SPACE_XS }) {
      Row({ space: ThemeTokens.SPACE_SM }) {
        Text(this.authorLabel(comment))
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_LINK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      Text(comment.body.length > 0 ? comment.body : AppStrings.get('comments_empty_body'))
        .width('100%')
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
      if (this.postedLabel(comment).length > 0) {
        Row() {
          Text(this.postedLabel(comment))
            .fontSize(ThemeTokens.FONT_SIZE_TINY)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
          .width('100%')
          .alignItems(VerticalAlign.Center)
      }
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

  @Builder
  private LoadedCommentsContent() {
    if (this.errorMessage.length > 0) {
      ListItem() {
        this.RefreshFailureNotice()
      }
    }
    ForEach(this.comments, (comment: NhComment): void => {
      ListItem() {
        this.CommentCard(comment)
      }
    }, (comment: NhComment): string => comment.commentId.toString())
  }

  build() {
    Column() {
      if (this.isLoading && this.comments.length === 0) {
        PageLoadingState({ text: AppStrings.get('comments_status_loading') })
      } else if (this.errorMessage.length > 0 && this.comments.length === 0) {
        PageErrorState({
          message: this.errorMessage,
          onRetry: (): void => {
            this.loadComments()
          },
        })
      } else if (this.comments.length === 0) {
        PageEmptyState({
          message: this.rawComments.length > 0
            ? AppStrings.get('comments_status_filtered_empty')
            : AppStrings.get('comments_status_empty'),
        })
      } else {
        Stack({ alignContent: Alignment.Bottom }) {
          PullRefreshListScaffold({
            scroller: this.scroller,
            listSpace: ThemeTokens.SPACE_SM,
            bottomPadding: this.composerAvailable()
              ? COMMENT_COMPOSER_BOTTOM_RESERVE
              : ThemeTokens.LIST_BOTTOM_PADDING,
            controller: this.refreshController,
            onRefresh: async (): Promise<void> => {
              await this.loadComments()
            },
          }) {
            this.LoadedCommentsContent()
          }
          if (this.composerAvailable()) {
            this.CommentComposer()
          }
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE)
  }
}
