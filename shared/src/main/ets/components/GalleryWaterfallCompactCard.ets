import { NhGallerySummary } from '../model/NhGallery'
import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'
import { CoverBackgroundState, connectCoverBackground } from '../state/CoverBackgroundState'
import {
  GalleryLanguageCornerBadge,
  galleryLanguageCornerBadgeText,
} from './GalleryLanguageCornerBadge'
import { GalleryTagStrip, GalleryTagStripLayout } from './GalleryTagStrip'

/**
 * Compact WaterFlow cards keep a different overlay subtree from CoverWall and
 * must not reuse each other's cached component instances.
 *
 * The current v2 summary can prove a thumbnail, title, page count and the
 * three derived language signals.  It intentionally does not turn tag ids
 * into a per-card network request merely to imitate NextE's rich tag strip.
 */
export function galleryWaterfallCompactReuseId(gallery: NhGallerySummary): string {
  const imageShape: string = gallery.thumbnailUrl.length > 0 ? 'image' : 'no_image'
  const languageShape: string = galleryLanguageCornerBadgeText(gallery.languageCode()).length > 0
    ? 'language'
    : 'plain'
  const pageShape: string = gallery.pageCount > 0 ? 'pages' : 'no_pages'
  return `waterfall_compact_${imageShape}_${languageShape}_${pageShape}`
}

/**
 * Reduced-data counterpart of NextE's `GalleryWaterfallCard(compact: true)`.
 *
 * Like NextE, the card uses the source cover ratio as its WaterFlow height and
 * keeps title metadata directly on an image-gradient overlay.  Missing
 * summary fields (tag names/colours, category, rating and user metadata) are
 * deliberately absent instead of being guessed or fetched from a card.
 */
@ReusableV2
@ComponentV2
export struct GalleryWaterfallCompactCard {
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

  private coverRatio(): number {
    if (this.gallery.thumbnailWidth <= 0 || this.gallery.thumbnailHeight <= 0) {
      return ThemeTokens.GALLERY_GRID_COVER_RATIO
    }
    // Compact Waterfall intentionally preserves the source ratio rather than
    // clamping it like CoverWall. That is the source of its masonry rhythm.
    return this.gallery.thumbnailWidth / this.gallery.thumbnailHeight
  }

  private accessibilityLabel(): string {
    return AppStrings.format('gallery_card_a11y', [
      this.gallery.displayTitle(),
      AppStrings.format('gallery_meta_pages', [this.gallery.pageCount.toString()]),
    ])
  }

  private shouldBlurLetterboxBackground(): boolean {
    return this.coverBackground.blurLetterboxBackground &&
      this.gallery.thumbnailUrl.length > 0 &&
      !this.hasThumbnailError
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
  private Cover() {
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
          .objectFit(ImageFit.Contain)
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
    .brightness(this.selected ? 0.86 : 1)
  }

  @Builder
  private BottomOverlay() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      GalleryTagStrip({
        tags: this.gallery.tags,
        layout: GalleryTagStripLayout.SINGLE_LINE,
        onDarkSurface: true,
      })
      if (this.gallery.pageCount > 0) {
        Text(`${this.gallery.pageCount}P`)
          .fontSize(ThemeTokens.FONT_SIZE_TINY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_ON_BRAND)
          .maxLines(1)
      }
      Text(this.gallery.displayTitle())
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_ON_BRAND)
        .fontWeight(FontWeight.Medium)
        .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: ThemeTokens.SPACE_SM,
      right: ThemeTokens.SPACE_SM,
      top: ThemeTokens.SPACE_XL,
      bottom: ThemeTokens.SPACE_SM,
    })
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [
        [Color.Transparent, 0.0],
        [ThemeTokens.OVERLAY_SCRIM, 1.0],
      ],
    })
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      this.Cover()
      this.BottomOverlay()
      GalleryLanguageCornerBadge({ languageCode: this.gallery.languageCode() })
        .position({ right: 0, top: 0 })
    }
    .width('100%')
    .aspectRatio(this.coverRatio())
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
