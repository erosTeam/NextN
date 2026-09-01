import {
  AppStrings,
  EhImageKnifeImage,
  GalleryDetailTransitionCoordinator,
  GalleryDetailTransitionState,
  GalleryThumbnail,
  NhComment,
  NhGallerySummary,
  ThemeTokens,
  EH_IMAGE_PRIORITY_LOW,
  connectGalleryDetailTransition,
} from 'shared'

// Related uses the same cover-height tier as the Detail hero; its separate
// title leaf remains below the cover and is not part of that image slot.
const RELATED_COVER_HEIGHT: number = ThemeTokens.DETAIL_COVER_HEIGHT
const RELATED_TITLE_HEIGHT: number = 80
const RELATED_CAROUSEL_HEIGHT: number = RELATED_COVER_HEIGHT + RELATED_TITLE_HEIGHT
const RELATED_FALLBACK_ASPECT_RATIO: number = 3 / 4
const HORIZONTAL_RAIL_EDGE_INSET: number = ThemeTokens.SPACE_MD
const COMMENT_CARD_WIDTH: number = 280
// Same identity mark as GalleryCommentCard (Next2V reply avatar diameter).
const COMMENT_AVATAR_SIZE: number = 32
const COMMENT_PREVIEW_MAX_LINES: number = 2
const COMMENT_PREVIEW_HEADER_LINE_HEIGHT: number = 18
const COMMENT_PREVIEW_LINE_HEIGHT: number = 18
const COMMENT_CAROUSEL_HEIGHT: number = 190

function horizontalRailViewportWidth(): string {
  return `calc(100% + ${HORIZONTAL_RAIL_EDGE_INSET * 2}vp)`
}

/**
 * The stable NH summary DTO renders as a section heading followed by one
 * fixed-height horizontal portrait carousel. It does not own requests,
 * filtering, or navigation state.
 */
@ComponentV2
export struct GalleryRelatedCarousel {
  @Require @Param galleries: NhGallerySummary[]
  /** Reserve the rail height with a centered indicator until rows settle. */
  @Param loading: boolean = false
  @Event onOpen?: (galleryId: number) => void
  @Local galleryDetailTransition: GalleryDetailTransitionState = connectGalleryDetailTransition()
  private transitionScope: string = GalleryDetailTransitionCoordinator.allocateScope('related')

  private relatedSourceId(gallery: NhGallerySummary): string {
    return GalleryDetailTransitionCoordinator.sourceId(
      this.transitionScope,
      'related',
      gallery.id.toString(),
    )
  }

  private relatedSourceCoverId(gallery: NhGallerySummary): string {
    return GalleryDetailTransitionCoordinator.sourceCoverId(
      this.transitionScope,
      'related',
      gallery.id.toString(),
    )
  }

  private relatedSourceSurfaceId(): string {
    return GalleryDetailTransitionCoordinator.sourceSurfaceId(this.transitionScope, 'related')
  }

  private openRelatedGallery(gallery: NhGallerySummary): void {
    if (!this.onOpen) {
      return
    }
    GalleryDetailTransitionCoordinator.open(
      this.getUIContext(),
      this.relatedSourceId(gallery),
      gallery.id.toString(),
      (): void => {
        if (this.onOpen) {
          this.onOpen(gallery.id)
        }
      },
      this.relatedSourceCoverId(gallery),
      gallery.thumbnailUrl,
      ThemeTokens.RADIUS_MD,
      0,
      this.relatedSourceSurfaceId(),
    )
  }

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
      GalleryThumbnail({
        src: gallery.thumbnailUrl,
        objectFit: ImageFit.Cover,
        widthValue: '100%',
        heightValue: '100%',
        surfaceId: this.relatedSourceCoverId(gallery),
      })
    }
    .width(this.relatedCardWidth(gallery))
    .height(RELATED_COVER_HEIGHT)
    .backgroundColor(ThemeTokens.COVER_PLACEHOLDER_STRONG)
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
        .padding({
          left: ThemeTokens.SPACE_SM,
          top: ThemeTokens.SPACE_XS,
          right: ThemeTokens.SPACE_SM,
          bottom: ThemeTokens.SPACE_XS,
        })
    }
    .width(this.relatedCardWidth(gallery))
    .height(RELATED_CAROUSEL_HEIGHT)
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeTokens.RADIUS_MD)
    .clip(true)
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
    .id(this.relatedSourceId(gallery))
    .visibility(
      this.galleryDetailTransition.sourceComponentId === this.relatedSourceId(gallery)
        ? Visibility.Hidden
        : Visibility.Visible,
    )
    .accessibilityText(this.relatedCardAccessibility(gallery))
    .onClick((): void => {
      this.openRelatedGallery(gallery)
    })
  }

  build() {
    Column({ space: ThemeTokens.SPACE_SM }) {
      Text(AppStrings.get('gallery_section_related'))
        .fontSize(ThemeTokens.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
        // The heading is not part of the horizontal viewport. It aligns with
        // content inside the neighbouring detail cards, while the List below
        // remains free to extend through the page gutter when scrolled.
        .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(ThemeTokens.BRAND)
        }
        .width('100%')
        .height(RELATED_CAROUSEL_HEIGHT)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List({ space: ThemeTokens.SPACE_SM }) {
        ForEach(this.galleries, (gallery: NhGallerySummary, index: number): void => {
          ListItem() {
            this.RelatedCard(gallery)
          }
          .margin({
            left: index === 0 ? HORIZONTAL_RAIL_EDGE_INSET : 0,
            right: index === this.galleries.length - 1 ? HORIZONTAL_RAIL_EDGE_INSET : 0,
          })
        }, (gallery: NhGallerySummary): string => `related_${gallery.id}`)
      }
      .width(horizontalRailViewportWidth())
      .height(RELATED_CAROUSEL_HEIGHT)
      .id(this.relatedSourceSurfaceId())
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .margin({
        left: -HORIZONTAL_RAIL_EDGE_INSET,
        right: -HORIZONTAL_RAIL_EDGE_INSET,
      })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * A compact peek of the discussion on the Detail page. It mirrors the full
 * comments route's avatar identity mark while the full route remains the sole
 * action target.
 */
@ComponentV2
export struct GalleryCommentPreviewCarousel {
  @Require @Param comments: NhComment[]
  /** Reserve the rail height with a centered indicator until the peek settles. */
  @Param loading: boolean = false
  /** Loaded-empty copy rendered inside the same fixed rail height. */
  @Param emptyText: string = ''
  @Event onOpen?: () => void

  private commentAuthor(comment: NhComment): string {
    return comment.posterName.length > 0
      ? comment.posterName
      : AppStrings.get('comments_author_anonymous')
  }

  private commentAvatarInitial(comment: NhComment): string {
    const name: string = comment.posterName.trim()
    if (name.length === 0) {
      return '•'
    }
    return name.substring(0, 1).toUpperCase()
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
    const hour: string = `${date.getHours()}`.padStart(2, '0')
    const minute: string = `${date.getMinutes()}`.padStart(2, '0')
    return `${date.getFullYear()}-${month}-${day} ${hour}:${minute}`
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
      if (this.loading) {
        LoadingProgress()
          .width(ThemeTokens.FONT_SIZE_CAPTION)
          .height(ThemeTokens.FONT_SIZE_CAPTION)
          .color(ThemeTokens.BRAND)
      } else {
        Text(this.commentCountText())
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_TERTIARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
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
    .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
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
        Stack({ alignContent: Alignment.Center }) {
          if (comment.posterAvatarUrl.length > 0) {
            EhImageKnifeImage({
              src: comment.posterAvatarUrl,
              objectFit: ImageFit.Cover,
              radius: COMMENT_AVATAR_SIZE / 2,
              widthValue: COMMENT_AVATAR_SIZE,
              heightValue: COMMENT_AVATAR_SIZE,
              priority: EH_IMAGE_PRIORITY_LOW,
            })
          } else {
            Text(this.commentAvatarInitial(comment))
              .fontSize(Math.max(11, COMMENT_AVATAR_SIZE / 3))
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
          }
        }
        .width(COMMENT_AVATAR_SIZE)
        .height(COMMENT_AVATAR_SIZE)
        .borderRadius(COMMENT_AVATAR_SIZE / 2)
        .backgroundColor(ThemeTokens.SURFACE_SUB)
        Text(this.commentAuthor(comment))
          .layoutWeight(1)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .lineHeight(COMMENT_PREVIEW_HEADER_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.commentPostedLabel(comment).length > 0) {
          Text(this.commentPostedLabel(comment))
            .fontSize(ThemeTokens.FONT_SIZE_TINY)
            .lineHeight(COMMENT_PREVIEW_HEADER_LINE_HEIGHT)
            .fontColor(ThemeTokens.TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(comment.body.length > 0 ? comment.body : AppStrings.get('comments_empty_body'))
        .width('100%')
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .lineHeight(COMMENT_PREVIEW_LINE_HEIGHT)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .maxLines(COMMENT_PREVIEW_MAX_LINES)
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
      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(ThemeTokens.BRAND)
        }
        .width('100%')
        .height(COMMENT_CAROUSEL_HEIGHT)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.comments.length === 0 && this.emptyText.length > 0) {
        Column() {
          Text(this.emptyText)
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
        }
        .width('100%')
        .height(COMMENT_CAROUSEL_HEIGHT)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.comments.length > 0) {
        List({ space: ThemeTokens.SPACE_SM }) {
          ForEach(this.comments, (comment: NhComment, index: number): void => {
            ListItem() {
              this.CommentCard(comment)
            }
            .margin({
              left: index === 0 ? HORIZONTAL_RAIL_EDGE_INSET : 0,
              right: index === this.comments.length - 1 ? HORIZONTAL_RAIL_EDGE_INSET : 0,
            })
          }, (comment: NhComment, index: number): string => this.commentKey(comment, index))
        }
        .width(horizontalRailViewportWidth())
        .height(COMMENT_CAROUSEL_HEIGHT)
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
        .translate({ x: -HORIZONTAL_RAIL_EDGE_INSET })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
