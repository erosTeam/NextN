import { AppStrings, GalleryThumbnail, NhReadingHistoryItem, ThemeTokens } from 'shared'

const HISTORY_THUMB_WIDTH: number = 60
const HISTORY_THUMB_HEIGHT: number = 84

/**
 * The page keeps NextE's grouped simple-list ownership. This local-data leaf
 * keeps ErosN's 60×84 cover frame, but its progress/time footer is anchored
 * to the frame bottom so short titles do not leave a detached empty tail.
 */
@ComponentV2
export struct HistoryListRow {
  @Require @Param item: NhReadingHistoryItem
  @Param transitionCoverId: string = ''
  @Event onOpenGallery?: (galleryId: number) => void

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

  build() {
    Row({ space: ThemeTokens.SPACE_SM }) {
      GalleryThumbnail({
        src: this.item.thumbnailUrl,
        widthValue: HISTORY_THUMB_WIDTH,
        heightValue: HISTORY_THUMB_HEIGHT,
        objectFit: ImageFit.Cover,
        radius: ThemeTokens.THUMB_RADIUS,
      })
        .id(this.transitionCoverId)
        .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
        .borderRadius(ThemeTokens.THUMB_RADIUS)
        .clip(true)

      // The title can legitimately occupy one to three lines. Keep the local
      // progress/time pair on the same fixed baseline in every case, matching
      // the simple-list information-column rhythm rather than stacking it
      // immediately below a short title.
      Column({ space: ThemeTokens.SPACE_XS }) {
        Text(this.title())
          .fontSize(ThemeTokens.FONT_SIZE_META)
          .fontWeight(FontWeight.Regular)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
          .maxLines(3)
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
      .height(HISTORY_THUMB_HEIGHT)
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
