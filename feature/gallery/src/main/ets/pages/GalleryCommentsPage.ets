import {
  ContentFilterService,
  ContentFilterState,
  AppStrings,
  InlineRetryNotice,
  NhApiClient,
  AccountSessionState,
  NhComment,
  NextNModalScaffold,
  NextNPullRefreshController,
  PageEmptyState,
  PageErrorState,
  PageLoadingState,
  PullRefreshListScaffold,
  ThemeTokens,
  connectAccountSession,
  connectContentFilters,
} from 'shared'

/**
 * A separate destination keeps comments from competing with the Gallery hero
 * and Read action. Posting remains constrained to the existing HDS modal-title
 * action; comments never gain an in-list Material-style toolbar.
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
  @Local composerShown: boolean = false
  @Local commentText: string = ''
  @Local isCommentSubmitting: boolean = false
  @Local commentSubmitError: string = ''
  @Param scroller: Scroller = new Scroller()
  /** A Detail-owned response seeds this route only after it was successfully fetched. */
  @Param commentSnapshot: NhComment[] = []
  @Param commentSnapshotAvailable: boolean = false
  @Param reloadVersion: number = 0
  @Param composeVersion: number = 0
  private requestGeneration: number = 0
  private commentSubmitGeneration: number = 0
  private refreshController: NextNPullRefreshController = new NextNPullRefreshController()

  aboutToAppear(): void {
    if (this.hydrateDetailSnapshot()) {
      return
    }
    if (!this.isLoading && this.loadedGalleryId !== this.galleryId) {
      this.loadComments()
    }
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
      this.openComposer()
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
    return `${date.getFullYear()}-${this.twoDigits(date.getMonth() + 1)}-${this.twoDigits(date.getDate())}`
  }

  private canSubmitComment(): boolean {
    return this.hasPublishedAccountSession() && this.commentText.trim().length > 0 && !this.isCommentSubmitting
  }

  private openComposer(): void {
    if (this.isCommentSubmitting) {
      return
    }
    if (!this.hasPublishedAccountSession()) {
      this.showCommentToast(AppStrings.get('comments_error_signin_post'))
      return
    }
    this.commentText = ''
    this.commentSubmitError = ''
    this.composerShown = true
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
      this.composerShown = false
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

  @Builder
  private CommentComposerSheet() {
    NextNModalScaffold({
      title: AppStrings.get('comments_dialog_post_title'),
      showConfirmAction: true,
      confirmText: this.isCommentSubmitting
        ? AppStrings.get('comments_action_posting')
        : AppStrings.get('comments_action_post'),
      confirmEnabled: this.canSubmitComment(),
      confirmLoading: this.isCommentSubmitting,
      onClose: (): void => {
        if (!this.isCommentSubmitting) {
          this.composerShown = false
          this.commentSubmitError = ''
        }
      },
      onConfirm: (): void => {
        this.submitComment()
      },
    }) {
      ListItem() {
        Column({ space: ThemeTokens.SPACE_SM }) {
          Text(AppStrings.get('comments_dialog_hint'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .maxLines(3)
          TextArea({ text: this.commentText, placeholder: AppStrings.get('comments_placeholder') })
            .width('100%')
            .minFontSize(ThemeTokens.FONT_SIZE_BODY)
            .backgroundColor(ThemeTokens.CARD_BACKGROUND)
            .borderRadius(ThemeTokens.RADIUS_MD)
            .onChange((value: string): void => {
              this.commentText = value
              this.commentSubmitError = ''
            })
          if (this.commentSubmitError.length > 0) {
            Text(this.commentSubmitError)
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontColor(Color.Red)
          }
        }
        .width('100%')
        .padding({
          left: ThemeTokens.SPACE_SM,
          right: ThemeTokens.SPACE_SM,
          top: ThemeTokens.SPACE_SM,
          bottom: ThemeTokens.SPACE_SM,
        })
      }
    }
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
    Column({ space: ThemeTokens.SPACE_XS }) {
      Text(this.authorLabel(comment))
        .width('100%')
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_LINK)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(comment.body.length > 0 ? comment.body : AppStrings.get('comments_empty_body'))
        .width('100%')
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
      if (this.postedLabel(comment).length > 0) {
        Text(this.postedLabel(comment))
          .width('100%')
          .fontSize(ThemeTokens.FONT_SIZE_TINY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_TERTIARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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
        PullRefreshListScaffold({
          scroller: this.scroller,
          listSpace: ThemeTokens.SPACE_SM,
          bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
          controller: this.refreshController,
          onRefresh: async (): Promise<void> => {
            await this.loadComments()
          },
        }) {
          this.LoadedCommentsContent()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE)
    .bindSheet($$this.composerShown, this.CommentComposerSheet(), {
      detents: [SheetSize.LARGE],
      showClose: false,
    })
  }
}
