import {
  AppStrings,
  NhComment,
  NhGallerySummary,
  ThemeTokens,
} from 'shared'

// These are the existing detail-rail dimensions: Related uses a 280vp strip
// with 200vp covers and 80vp titles; Comments uses a 190vp strip of 280vp
// preview cards.
const RELATED_CAROUSEL_HEIGHT: number = 280
const RELATED_COVER_HEIGHT: number = 200
const RELATED_TITLE_HEIGHT: number = 80
/**
 * Keep the existing fixed-height Related rail, but derive each card's width
 * from the thumbnail dimensions when the related endpoint supplies them.
 * Invalid or absent dimensions use the established 3:4 fallback; valid source
 * dimensions remain unmodified instead of being forced into a portrait slot.
 */
const RELATED_FALLBACK_ASPECT_RATIO: number = 3 / 4
const COMMENT_CAROUSEL_HEIGHT: number = 190
const COMMENT_CARD_WIDTH: number = 280

/**
 * The stable NH summary DTO renders as a section heading followed by one
 * fixed-height horizontal portrait carousel. It does not own requests,
 * filtering, or navigation state.
 */
@ComponentV2
export struct GalleryRelatedCarousel {
  @Require @Param galleries: NhGallerySummary[]
  @Event onOpen?: (galleryId: number) => void

  private relatedCardAccessibility(gallery: NhGallerySummary): string {
    return AppStrings.format('gallery_card_a11y', [
      gallery.displayTitle(),
      AppStrings.format('gallery_meta_pages', [gallery.pageCount.toString()]),
    ])
  }

  private relatedAspectRatio(gallery: NhGallerySummary): number {
    if (gallery.thumbnailWidth <= 0 || gallery.thumbnailHeight <= 0) {
      return RELATED_FALLBACK_ASPECT_RATIO
    }
    return gallery.thumbnailWidth / gallery.thumbnailHeight
  }

  private relatedCardWidth(gallery: NhGallerySummary): number {
    return RELATED_COVER_HEIGHT * this.relatedAspectRatio(gallery)
  }

  @Builder
  private RelatedCover(gallery: NhGallerySummary) {
    Stack({ alignContent: Alignment.Center }) {
      if (gallery.thumbnailUrl.length > 0) {
        Image(gallery.thumbnailUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        SymbolGlyph($r('sys.symbol.picture'))
          .fontSize(28)
          .fontColor([ThemeTokens.TEXT_TERTIARY])
      }
    }
    .width(this.relatedCardWidth(gallery))
    .height(RELATED_COVER_HEIGHT)
    .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
    .borderRadius(ThemeTokens.THUMB_RADIUS)
    .clip(true)
  }

  @Builder
  private RelatedCard(gallery: NhGallerySummary) {
    Column({ space: 0 }) {
      this.RelatedCover(gallery)
      Text(gallery.displayTitle())
        .width(this.relatedCardWidth(gallery))
        .height(RELATED_TITLE_HEIGHT)
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
        .maxLines(5)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Start)
        .padding({ top: ThemeTokens.SPACE_XS })
    }
    .width(this.relatedCardWidth(gallery))
    .height(RELATED_CAROUSEL_HEIGHT)
    .alignItems(HorizontalAlign.Start)
    .accessibilityText(this.relatedCardAccessibility(gallery))
    .onClick((): void => {
      if (this.onOpen) {
        this.onOpen(gallery.id)
      }
    })
  }

  build() {
    Column({ space: ThemeTokens.SPACE_SM }) {
      Text(AppStrings.get('gallery_section_related'))
        .fontSize(ThemeTokens.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
      List({ space: ThemeTokens.SPACE_SM }) {
        ForEach(this.galleries, (gallery: NhGallerySummary): void => {
          ListItem() {
            this.RelatedCard(gallery)
          }
        }, (gallery: NhGallerySummary): string => `related_${gallery.id}`)
      }
      .width('100%')
      .height(RELATED_CAROUSEL_HEIGHT)
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * The public NH DTO contains only author, body, and post-date leaves, so this
 * preview intentionally keeps a compact text header instead of inventing an
 * avatar request; the existing full comments route remains the sole action
 * target.
 */
@ComponentV2
export struct GalleryCommentPreviewCarousel {
  @Require @Param comments: NhComment[]
  @Event onOpen?: () => void

  private commentAuthor(comment: NhComment): string {
    return comment.posterName.length > 0
      ? comment.posterName
      : AppStrings.get('comments_author_anonymous')
  }

  private commentPostedLabel(comment: NhComment): string {
    if (comment.postDate <= 0) {
      return ''
    }
    const date: Date = new Date(comment.postDate * 1000)
    if (isNaN(date.getTime())) {
      return ''
    }
    const month: string = `${date.getMonth() + 1}`.padStart(2, '0')
    const day: string = `${date.getDate()}`.padStart(2, '0')
    return `${date.getFullYear()}-${month}-${day}`
  }

  private commentCountText(): string {
    const total: number = this.comments.length
    return AppStrings.format(
      total === 1 ? 'comments_count_singular' : 'comments_count_plural',
      [total.toString()],
    )
  }

  private commentKey(comment: NhComment, index: number): string {
    return `comment_preview_${index}_${comment.commentId}`
  }

  @Builder
  private CommentsHeader() {
    Row({ space: ThemeTokens.SPACE_XS }) {
      SymbolGlyph($r('sys.symbol.doc_plaintext'))
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor([ThemeTokens.TEXT_SECONDARY])
      Text(AppStrings.get('gallery_action_comments'))
        .fontSize(ThemeTokens.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
      Text(this.commentCountText())
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_TERTIARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
      Text(AppStrings.get('detail_view_all'))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_LINK)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor([ThemeTokens.TEXT_TERTIARY])
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .accessibilityText(AppStrings.get('gallery_comments_a11y'))
    .onClick((): void => {
      if (this.onOpen) {
        this.onOpen()
      }
    })
  }

  @Builder
  private CommentCard(comment: NhComment) {
    // Keep the supported author/date leaves together at the top.  Giving the
    // body layout weight in this fixed-height rail made a short body occupy
    // the remaining card height and visually sink below a large inner void.
    Column({ space: ThemeTokens.SPACE_XS }) {
      Row({ space: ThemeTokens.SPACE_SM }) {
        Text(this.commentAuthor(comment))
          .layoutWeight(1)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.commentPostedLabel(comment).length > 0) {
          Text(this.commentPostedLabel(comment))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(comment.body.length > 0 ? comment.body : AppStrings.get('comments_empty_body'))
        .width('100%')
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(COMMENT_CARD_WIDTH)
    .height(COMMENT_CAROUSEL_HEIGHT)
    .alignItems(HorizontalAlign.Start)
    .padding(ThemeTokens.SPACE_MD)
    .borderRadius(ThemeTokens.RADIUS_CARD)
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
    .clip(true)
    .onClick((): void => {
      if (this.onOpen) {
        this.onOpen()
      }
    })
  }

  build() {
    Column({ space: ThemeTokens.SPACE_SM }) {
      this.CommentsHeader()
      if (this.comments.length > 0) {
        List({ space: ThemeTokens.SPACE_SM }) {
          ForEach(this.comments, (comment: NhComment, index: number): void => {
            ListItem() {
              this.CommentCard(comment)
            }
          }, (comment: NhComment, index: number): string => this.commentKey(comment, index))
        }
        .width('100%')
        .height(COMMENT_CAROUSEL_HEIGHT)
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
