import { AppStrings, NhReadingHistoryItem, ThemeTokens } from 'shared'

/**
 * A compact, local-only history row in the same cover-first grammar as
 * NextE's GallerySimpleCard.  It deliberately renders only fields that the
 * persisted NextN history record can prove: cover, title, resume position,
 * and the last local open time.
 */
@ComponentV2
export struct HistoryGalleryCard {
  @Require @Param item: NhReadingHistoryItem
  @Local isThumbnailLoading: boolean = true
  @Local hasThumbnailError: boolean = false
  @Event onOpenGallery?: (galleryId: number) => void
  @Event onResume?: (galleryId: number, initialPageIndex: number) => void

  @Monitor('item')
  onItemChanged(): void {
    this.isThumbnailLoading = this.item.thumbnailUrl.length > 0
    this.hasThumbnailError = false
  }

  private title(): string {
    return this.item.toSummary().displayTitle()
  }

  private timeLabel(): string {
    if (this.item.lastOpenedAt <= 0) {
      return ''
    }
    const date: Date = new Date(this.item.lastOpenedAt)
    const hour: string = `${date.getHours()}`.padStart(2, '0')
    const minute: string = `${date.getMinutes()}`.padStart(2, '0')
    return `${hour}:${minute}`
  }

  private progressLabel(): string {
    const pageCount: number = Math.max(1, this.item.pageCount)
    // Existing records from before the explicit marker are migrated as false.
    // Do not turn their ambiguous stored zero/non-zero index into a visible
    // claim that reading has actually started.
    const savedIndex: number = this.item.hasReadProgress ? this.item.lastReadIndex : 0
    const pageIndex: number = Math.min(Math.max(0, savedIndex), pageCount - 1)
    return AppStrings.get('history_page_progress')
      .replace('%1$d', `${pageIndex + 1}`)
      .replace('%2$d', `${pageCount}`)
  }

  private actionLabel(): string {
    return this.item.hasReadProgress
      ? AppStrings.get('history_resume')
      : AppStrings.get('gallery_action_read')
  }

  private galleryAccessibilityLabel(): string {
    const removeHint: string = AppStrings.get('history_remove_discovery_accessibility')
    return `${this.title()}, ${this.progressLabel()}. ${removeHint}`
  }

  private readerAccessibilityLabel(): string {
    return this.item.hasReadProgress
      ? AppStrings.get('history_continue_accessibility')
        .replace('%1$s', this.title())
        .replace('%2$s', this.progressLabel())
      : `${this.actionLabel()} ${this.title()}, ${this.progressLabel()}.`
  }

  private openGallery(): void {
    if (this.onOpenGallery) {
      this.onOpenGallery(this.item.galleryId)
    }
  }

  private resumeReader(): void {
    if (this.onResume) {
      // Preserve the Reader's original exact-index handoff. New records
      // with no progress carry zero; migrated records remain non-destructive.
      this.onResume(this.item.galleryId, Math.max(0, this.item.lastReadIndex))
    }
  }

  @Builder
  private ThumbnailFallback() {
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
        this.ThumbnailFallback()
      }
      .width(ThemeTokens.COVER_WIDTH)
      .height(ThemeTokens.COVER_HEIGHT)
      .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
      .borderRadius(ThemeTokens.THUMB_RADIUS)
      .clip(true)
      .accessibilityText(this.galleryAccessibilityLabel())
      .onClick((): void => {
        this.openGallery()
      })

      Column({ space: ThemeTokens.SPACE_XS }) {
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
            if (this.timeLabel().length > 0) {
              SymbolGlyph($r('sys.symbol.clock'))
                .fontSize(ThemeTokens.FONT_SIZE_TINY)
                .fontColor([ThemeTokens.TEXT_TERTIARY])
              Text(this.timeLabel())
                .fontSize(ThemeTokens.FONT_SIZE_TINY)
                .fontColor(ThemeTokens.TEXT_TERTIARY)
            }
            Blank()
            Text(this.progressLabel())
              .fontSize(ThemeTokens.FONT_SIZE_TINY)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .accessibilityText(this.galleryAccessibilityLabel())
        .onClick((): void => {
          this.openGallery()
        })

        Row({ space: ThemeTokens.SPACE_XS }) {
          Text(this.actionLabel())
            .fontSize(ThemeTokens.FONT_SIZE_TINY)
            .fontColor(ThemeTokens.TEXT_LINK)
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(ThemeTokens.FONT_SIZE_TINY)
            .fontColor([ThemeTokens.TEXT_LINK])
        }
        .width('100%')
        .height(ThemeTokens.MIN_TOUCH_TARGET)
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)
        .accessibilityText(this.readerAccessibilityLabel())
        .onClick((): void => {
          this.resumeReader()
        })
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
  }
}
