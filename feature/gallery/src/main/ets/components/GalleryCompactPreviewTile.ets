import {
  AppStrings,
  NhGalleryPage,
  ThemeTokens,
} from 'shared'

// This is deliberately separate from GalleryVirtualPageThumbnailTile: the
// full Pages destination is a stable Grid, while the compact detail rail must
// retain each source page's aspect at one shared rail height.
const COMPACT_PREVIEW_IMAGE_HEIGHT: number = 132
// Exact ErosN ThumbListView sanitisation: malformed or extreme source metadata
// does not stretch the rail; normal page dimensions keep their true aspect.
const COMPACT_PREVIEW_MIN_ASPECT: number = 0.3
const COMPACT_PREVIEW_MAX_ASPECT: number = 2.0
const COMPACT_PREVIEW_FALLBACK_ASPECT: number = 0.65

/**
 * One compact-detail page preview. Its fixed image height follows the
 * ErosN/NextE horizontal rail; only its width varies with the known NH page
 * dimensions. The virtualised full-thumbnail Grid is intentionally separate.
 */
@ComponentV2
export struct GalleryCompactPreviewTile {
  @Require @Param page: NhGalleryPage
  @Require @Param pageIndex: number
  @Event onOpen?: (pageIndex: number) => void
  @Local isThumbnailLoading: boolean = true
  @Local hasThumbnailError: boolean = false

  aboutToAppear(): void {
    this.resetThumbnailState()
  }

  @Monitor('page')
  onPageChanged(): void {
    this.resetThumbnailState()
  }

  private resetThumbnailState(): void {
    this.isThumbnailLoading = this.page.thumbnailUrl.length > 0
    this.hasThumbnailError = false
  }

  private pageAspect(): number {
    if (this.page.width > 0 && this.page.height > 0) {
      const sourceAspect: number = this.page.width / this.page.height
      if (sourceAspect >= COMPACT_PREVIEW_MIN_ASPECT && sourceAspect <= COMPACT_PREVIEW_MAX_ASPECT) {
        return sourceAspect
      }
    }
    return COMPACT_PREVIEW_FALLBACK_ASPECT
  }

  private imageWidth(): number {
    return COMPACT_PREVIEW_IMAGE_HEIGHT * this.pageAspect()
  }

  private pageLabel(): string {
    return AppStrings.format('thumbnails_page_label', [(this.pageIndex + 1).toString()])
  }

  @Builder
  private ThumbnailFallback() {
    if (this.page.thumbnailUrl.length === 0 || this.hasThumbnailError) {
      SymbolGlyph($r('sys.symbol.picture'))
        .fontSize(26)
        .fontColor([ThemeTokens.TEXT_TERTIARY])
    } else if (this.isThumbnailLoading) {
      LoadingProgress()
        .width(20)
        .height(20)
        .color(ThemeTokens.TEXT_TERTIARY)
    }
  }

  build() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.page.thumbnailUrl.length > 0 && !this.hasThumbnailError) {
          Image(this.page.thumbnailUrl)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .onComplete((): void => {
              this.isThumbnailLoading = false
            })
            .onError((): void => {
              this.isThumbnailLoading = false
              this.hasThumbnailError = true
            })
        }
        this.ThumbnailFallback()
      }
      .width(this.imageWidth())
      .height(COMPACT_PREVIEW_IMAGE_HEIGHT)
      .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
      .borderRadius(ThemeTokens.THUMB_RADIUS)
      .clip(true)
      Text(`${this.pageIndex + 1}`)
        .fontSize(ThemeTokens.FONT_SIZE_TINY)
        .fontColor(ThemeTokens.TEXT_TERTIARY)
        .maxLines(1)
    }
    .width(this.imageWidth())
    .alignItems(HorizontalAlign.Center)
    .accessibilityText(AppStrings.format('thumbnails_open_reader_a11y', [this.pageLabel()]))
    .onClick((): void => {
      if (this.onOpen) {
        this.onOpen(this.pageIndex)
      }
    })
  }
}
