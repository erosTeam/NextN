import { NhGallerySummary } from '../model/NhGallery'
import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'
import { CoverBackgroundState, connectCoverBackground } from '../state/CoverBackgroundState'
import {
  GalleryLanguageCornerBadge,
  galleryLanguageCornerBadgeText,
} from './GalleryLanguageCornerBadge'
import { GalleryTagStrip } from './GalleryTagStrip'

const WATERFALL_MIN_COVER_RATIO: number = 0.5
const WATERFALL_MAX_COVER_RATIO: number = 1.35
const COVER_META_PAD_X: number = 7
const COVER_META_PAD_Y: number = 3

/**
 * Reuse only cards with the same conditional presentation structure.  The
 * regular waterfall keeps its metadata below the cover, unlike the compact
 * variant's image-overlay subtree.
 */
export function galleryWaterfallReuseId(gallery: NhGallerySummary): string {
  const imageShape: string = gallery.thumbnailUrl.length > 0 ? 'image' : 'no_image'
  const japaneseShape: string = gallery.japaneseTitle.length > 0 ? 'japanese' : 'plain'
  const languageShape: string = galleryLanguageCornerBadgeText(gallery.languageCode()).length > 0
    ? 'language'
    : 'no_language'
  const pageShape: string = gallery.pageCount > 0 ? 'pages' : 'no_pages'
  return `waterfall_${imageShape}_${japaneseShape}_${languageShape}_${pageShape}`
}

/**
 * Reduced-data counterpart of NextE's regular `GalleryWaterfallCard`.
 *
 * The v2 summary has no safe uploader, rating, favourite, category or tag
 * display data, so this card deliberately keeps only the fields already
 * available in the loaded snapshot.  It preserves the regular waterfall's
 * defining structure: a bounded variable-height cover followed by a readable
 * metadata block, separate from the compact image-overlay mode.
 */
@ReusableV2
@ComponentV2
export struct GalleryWaterfallCard {
  @Require @Param gallery: NhGallerySummary
  @Param selected: boolean = false
  @Local isThumbnailLoading: boolean = true
  @Local hasThumbnailError: boolean = false
  @Local coverBackground: CoverBackgroundState = connectCoverBackground()
  @Event onOpen?: (galleryId: number) => void

  @Monitor('gallery')
  onGalleryChanged(): void {
    this.isThumbnailLoading = this.gallery.thumbnailUrl.length > 0
    this.hasThumbnailError = false
  }

  private sourceCoverRatio(): number {
    if (this.gallery.thumbnailWidth <= 0 || this.gallery.thumbnailHeight <= 0) {
      return ThemeTokens.GALLERY_GRID_COVER_RATIO
    }
    return this.gallery.thumbnailWidth / this.gallery.thumbnailHeight
  }

  private coverRatio(): number {
    const source: number = this.sourceCoverRatio()
    return Math.max(WATERFALL_MIN_COVER_RATIO, Math.min(WATERFALL_MAX_COVER_RATIO, source))
  }

  private imageFit(): ImageFit {
    return this.sourceCoverRatio() < WATERFALL_MIN_COVER_RATIO ? ImageFit.Contain : ImageFit.Cover
  }

  private shouldBlurLetterboxBackground(): boolean {
    return this.coverBackground.blurLetterboxBackground &&
      this.gallery.thumbnailUrl.length > 0 &&
      !this.hasThumbnailError &&
      this.imageFit() === ImageFit.Contain
  }

  private accessibilityLabel(): string {
    return AppStrings.format('gallery_card_a11y', [
      this.gallery.displayTitle(),
      AppStrings.format('gallery_meta_pages', [this.gallery.pageCount.toString()]),
    ])
  }

  @Builder
  private CoverState() {
    if (this.isThumbnailLoading || this.hasThumbnailError || this.gallery.thumbnailUrl.length === 0) {
      Column({ space: ThemeTokens.SPACE_XS }) {
        if (this.hasThumbnailError || this.gallery.thumbnailUrl.length === 0) {
          SymbolGlyph($r('sys.symbol.picture'))
            .fontSize(24)
            .fontColor([ThemeTokens.TEXT_TERTIARY])
        } else {
          LoadingProgress()
            .width(22)
            .height(22)
            .color(ThemeTokens.TEXT_TERTIARY)
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private CoverMeta() {
    if (this.gallery.pageCount > 0) {
      Text(`${this.gallery.pageCount}P`)
        .fontSize(ThemeTokens.FONT_SIZE_TINY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_ON_BRAND)
        .backgroundColor('rgba(0, 0, 0, 0.48)')
        .borderRadius(ThemeTokens.RADIUS_MD)
        .padding({
          left: COVER_META_PAD_X,
          right: COVER_META_PAD_X,
          top: COVER_META_PAD_Y,
          bottom: COVER_META_PAD_Y,
        })
        .position({ right: ThemeTokens.SPACE_XS, bottom: ThemeTokens.SPACE_XS })
    }
  }

  @Builder
  private Cover() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.shouldBlurLetterboxBackground()) {
          Image(this.gallery.thumbnailUrl)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .scale({ x: 1.08, y: 1.08 })
            .blur(20)
            .opacity(0.72)
            .renderGroup(true)
        }
        if (this.gallery.thumbnailUrl.length > 0 && !this.hasThumbnailError) {
          Image(this.gallery.thumbnailUrl)
            .width('100%')
            .height('100%')
            .objectFit(this.imageFit())
            .onComplete((): void => {
              this.isThumbnailLoading = false
              this.hasThumbnailError = false
            })
            .onError((): void => {
              this.isThumbnailLoading = false
              this.hasThumbnailError = true
            })
        }
        this.CoverState()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
      GalleryLanguageCornerBadge({ languageCode: this.gallery.languageCode() })
      this.CoverMeta()
    }
    .width('100%')
    .aspectRatio(this.coverRatio())
    .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
  }

  @Builder
  private Metadata() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Text(this.gallery.displayTitle())
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
        .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      if (this.gallery.japaneseTitle.length > 0) {
        Text(this.gallery.japaneseTitle)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      GalleryTagStrip({ tags: this.gallery.tags })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(ThemeTokens.SPACE_SM)
  }

  build() {
    Column() {
      this.Cover()
      this.Metadata()
    }
    .width('100%')
    .borderRadius(ThemeTokens.RADIUS_CARD)
    .backgroundColor(this.selected ? $r('app.color.navigation_item_selected') : ThemeTokens.CARD_BACKGROUND)
    .clip(true)
    .accessibilityText(this.accessibilityLabel())
    .onClick((): void => {
      if (this.onOpen) {
        this.onOpen(this.gallery.id)
      }
    })
  }
}
