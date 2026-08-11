import { AppStrings, NhReadingHistoryItem, ThemeTokens } from 'shared'

/**
 * The History leaf intentionally follows NextE's GallerySimpleCard grammar.
 * Day grouping, removal, paging, and navigation ownership remain in
 * HistoryPage; this component presents one local record as one row action.
 */
@ComponentV2
export struct HistoryListRow {
  @Require @Param item: NhReadingHistoryItem
  @Local isThumbnailLoading: boolean = true
  @Local hasThumbnailError: boolean = false
  @Event onOpenGallery?: (galleryId: number) => void

  @Monitor('item')
  onItemChanged(): void {
    this.isThumbnailLoading = this.item.thumbnailUrl.length > 0
    this.hasThumbnailError = false
  }

  private title(): string {
    return this.item.toSummary().displayTitle()
  }

  private viewedTime(): string {
    if (this.item.lastOpenedAt <= 0) {
      return ''
    }
    const date: Date = new Date(this.item.lastOpenedAt)
    return `${date.getHours()}`.padStart(2, '0') + ':' + `${date.getMinutes()}`.padStart(2, '0')
  }

  private progressLabel(): string {
    const pageCount: number = Math.max(1, this.item.pageCount)
    const savedIndex: number = this.item.hasReadProgress ? this.item.lastReadIndex : 0
    const pageIndex: number = Math.min(Math.max(0, savedIndex), pageCount - 1)
    return AppStrings.get('history_page_progress')
      .replace('%1$d', `${pageIndex + 1}`)
      .replace('%2$d', `${pageCount}`)
  }

  private accessibilityLabel(): string {
    const time: string = this.viewedTime()
    return time.length > 0
      ? `${this.title()}, ${this.progressLabel()}, ${time}`
      : `${this.title()}, ${this.progressLabel()}`
  }

  @Builder
  private ThumbnailState() {
    if (this.isThumbnailLoading || this.hasThumbnailError || this.item.thumbnailUrl.length === 0) {
      Column({ space: ThemeTokens.SPACE_XS }) {
        if (this.hasThumbnailError || this.item.thumbnailUrl.length === 0) {
          SymbolGlyph($r('sys.symbol.picture'))
            .fontSize(24)
            .fontColor([ThemeTokens.TEXT_TERTIARY])
          Text(AppStrings.get('gallery_no_cover'))
            .fontSize(ThemeTokens.FONT_SIZE_TINY)
            .fontColor(ThemeTokens.TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(ThemeTokens.TEXT_TERTIARY)
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  build() {
    Row({ space: ThemeTokens.SPACE_SM }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.item.thumbnailUrl.length > 0 && !this.hasThumbnailError) {
          Image(this.item.thumbnailUrl)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .borderRadius(ThemeTokens.THUMB_RADIUS)
            .onComplete((): void => {
              this.isThumbnailLoading = false
              this.hasThumbnailError = false
            })
            .onError((): void => {
              this.isThumbnailLoading = false
              this.hasThumbnailError = true
            })
        }
        this.ThumbnailState()
      }
      .width(ThemeTokens.COVER_WIDTH)
      .height(ThemeTokens.COVER_HEIGHT)
      .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
      .borderRadius(ThemeTokens.THUMB_RADIUS)
      .clip(true)

      Column({ space: ThemeTokens.SPACE_XS }) {
        Text(this.title())
          .fontSize(ThemeTokens.FONT_SIZE_META)
          .fontWeight(FontWeight.Regular)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Blank()

        Row({ space: ThemeTokens.SPACE_XS }) {
          Text(this.progressLabel())
            .fontSize(ThemeTokens.FONT_SIZE_TINY)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
          Blank()
          if (this.viewedTime().length > 0) {
            Row({ space: 2 }) {
              SymbolGlyph($r('sys.symbol.clock'))
                .fontSize(ThemeTokens.FONT_SIZE_TINY)
                .fontColor([ThemeTokens.TEXT_TERTIARY])
              Text(this.viewedTime())
                .fontSize(ThemeTokens.FONT_SIZE_TINY)
                .fontColor(ThemeTokens.TEXT_TERTIARY)
            }
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .height(ThemeTokens.COVER_HEIGHT)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: ThemeTokens.SPACE_MD,
      right: ThemeTokens.SPACE_MD,
      top: ThemeTokens.SPACE_SM,
      bottom: ThemeTokens.SPACE_SM,
    })
    .alignItems(VerticalAlign.Top)
    .border({ width: { bottom: 0.5 }, color: ThemeTokens.DIVIDER })
    .backgroundColor(Color.Transparent)
    .accessibilityText(this.accessibilityLabel())
    .onClick((): void => {
      if (this.onOpenGallery) {
        this.onOpenGallery(this.item.galleryId)
      }
    })
  }
}
