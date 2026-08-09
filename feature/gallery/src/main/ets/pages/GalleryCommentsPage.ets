import {
  ContentFilterService,
  ContentFilterState,
  AppStrings,
  InlineRetryNotice,
  NhApiClient,
  AccountSessionState,
  NhComment,
  NextNModalScaffold,
  PageEmptyState,
  PageErrorState,
  PageLoadingState,
  SecondaryListScaffold,
  ThemeTokens,
  connectAccountSession,
  connectContentFilters,
} from 'shared'

/**
 * A separate destination keeps public discussion from competing with the
 * Gallery hero and Read action. Posting is constrained to the existing HDS
 * modal-title action; comments never gain an in-list Material-style toolbar.
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
  @Local isLoading: boolean = true
  @Local errorMessage: string = ''
  @Local composerShown: boolean = false
  @Local commentText: string = ''
  @Local isCommentSubmitting: boolean = false
  @Local commentSubmitError: string = ''
  @Param scroller: Scroller = new Scroller()
  @Param reloadVersion: number = 0
  @Param composeVersion: number = 0
  private requestGeneration: number = 0
  private commentSubmitGeneration: number = 0

  aboutToAppear(): void {
    this.loadComments()
  }

  aboutToDisappear(): void {
    this.requestGeneration += 1
    this.commentSubmitGeneration += 1
  }

  @Monitor('galleryId')
  onGalleryChanged(): void {
    this.loadComments()
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

  private summaryText(): string {
    if (this.isLoading) {
      return AppStrings.get('comments_status_loading_discussion')
    }
    if (this.comments.length === 0 && this.rawComments.length > 0) {
      return AppStrings.get('comments_status_filtered_empty')
    }
    if (this.comments.length === 0) {
      return AppStrings.get('comments_status_empty')
    }
    return AppStrings.format(
      this.comments.length === 1 ? 'comments_count_singular' : 'comments_count_plural',
      [this.comments.length.toString()],
    )
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
  private CommentsSummary() {
    Row({ space: ThemeTokens.SPACE_XS }) {
      Text(AppStrings.get('comments_title_public_discussion'))
        .fontSize(ThemeTokens.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
      Text(this.summaryText())
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_TERTIARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({
      left: ThemeTokens.LIST_HORIZONTAL_PADDING,
      right: ThemeTokens.LIST_HORIZONTAL_PADDING,
      top: ThemeTokens.SPACE_MD,
      bottom: ThemeTokens.SPACE_SM,
    })
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
      left: ThemeTokens.LIST_HORIZONTAL_PADDING,
      right: ThemeTokens.LIST_HORIZONTAL_PADDING,
      bottom: ThemeTokens.SPACE_SM,
    })
  }

  @Builder
  private CommentCard(comment: NhComment) {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Row({ space: ThemeTokens.SPACE_SM }) {
        Text(this.authorLabel(comment))
          .layoutWeight(1)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.postedLabel(comment).length > 0) {
          Text(this.postedLabel(comment))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_TERTIARY)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(comment.body.length > 0 ? comment.body : AppStrings.get('comments_empty_body'))
        .width('100%')
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
      Divider()
        .strokeWidth(1)
        .color(ThemeTokens.DIVIDER)
        .margin({ top: ThemeTokens.SPACE_SM })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: ThemeTokens.SPACE_MD,
      right: ThemeTokens.SPACE_MD,
      top: ThemeTokens.SPACE_MD,
      bottom: ThemeTokens.SPACE_XS,
    })
  }

  /**
   * Keep every discussion state in the destination's scroll surface.  HDS
   * titles are immersive, so a direct Column would start beneath the title
   * and let the summary/first comment render behind it on a real device.
   */
  @Builder
  private DiscussionContent() {
    ListItem() {
      this.CommentsSummary()
    }
    if (this.isLoading && this.comments.length === 0) {
      ListItem() {
        PageLoadingState({ text: AppStrings.get('comments_status_loading') })
      }
    } else if (this.errorMessage.length > 0 && this.comments.length === 0) {
      ListItem() {
        PageErrorState({
          message: this.errorMessage,
          onRetry: (): void => {
            this.loadComments()
          },
        })
      }
    } else if (this.comments.length === 0) {
      ListItem() {
        PageEmptyState({
          message: this.rawComments.length > 0
            ? AppStrings.get('comments_status_filtered_empty')
            : AppStrings.get('comments_status_empty'),
        })
      }
    } else {
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
  }

  build() {
    Column() {
      Refresh({ refreshing: $$this.isLoading }) {
        SecondaryListScaffold({
          scroller: this.scroller,
          listSpace: 0,
          horizontalPadding: 0,
          bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
          alwaysEnableEdgeSpring: true,
        }) {
          this.DiscussionContent()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .pullToRefresh(true)
      .onRefreshing((): void => {
        this.loadComments()
      })
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
