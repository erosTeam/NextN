import { NhGallerySummary } from '../model/NhGallery'
import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'
import { CoverBackgroundState, connectCoverBackground } from '../state/CoverBackgroundState'
import {
  GalleryLanguageCornerBadge,
  galleryLanguageCornerBadgeText,
  LANGUAGE_BADGE_COMPACT_TEXT_CENTER_X_RATIO,
  LANGUAGE_BADGE_COMPACT_TEXT_CENTER_Y_RATIO,
} from './GalleryLanguageCornerBadge'

const COVER_WALL_MIN_RATIO: number = 0.5
const COVER_WALL_MAX_RATIO: number = 1.35

/** Reuse only the cover-fit and optional language-badge subtree shapes. */
export function galleryCoverWallReuseId(gallery: NhGallerySummary): string {
  const sourceRatio: number = gallery.thumbnailWidth > 0 && gallery.thumbnailHeight > 0
    ? gallery.thumbnailWidth / gallery.thumbnailHeight
    : ThemeTokens.GALLERY_GRID_COVER_RATIO
  const imageShape: string = gallery.thumbnailUrl.length > 0 ? 'image' : 'no_image'
  const coverShape: string = sourceRatio < COVER_WALL_MIN_RATIO ? 'contain' : 'cover'
  const languageShape: string = galleryLanguageCornerBadgeText(gallery.languageCode()).length > 0
    ? 'language'
    : 'plain'
  return `coverwall_${imageShape}_${coverShape}_${languageShape}`
}

/**
 * Reduced NextE CoverWall card. It intentionally contains no title or tag
 * subtree: CoverWall is a cover-first WaterFlow surface and NhGallerySummary
 * only proves the thumbnail, source dimensions, and language badge.
 */
@ReusableV2
@ComponentV2
export struct GalleryCoverWallCard {
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

  private sourceRatio(): number {
    if (this.gallery.thumbnailWidth <= 0 || this.gallery.thumbnailHeight <= 0) {
      return ThemeTokens.GALLERY_GRID_COVER_RATIO
    }
    return this.gallery.thumbnailWidth / this.gallery.thumbnailHeight
  }

  private coverRatio(): number {
    const ratio: number = this.sourceRatio()
    if (ratio < COVER_WALL_MIN_RATIO) {
      return COVER_WALL_MIN_RATIO
    }
    if (ratio > COVER_WALL_MAX_RATIO) {
      return COVER_WALL_MAX_RATIO
    }
    return ratio
  }

  private useContainFit(): boolean {
    return this.sourceRatio() < COVER_WALL_MIN_RATIO
  }

  private shouldBlurLetterboxBackground(): boolean {
    return this.coverBackground.blurLetterboxBackground &&
      this.gallery.thumbnailUrl.length > 0 &&
      !this.hasThumbnailError &&
      this.useContainFit()
  }

  private accessibilityLabel(): string {
    return AppStrings.format('gallery_cover_wall_card_a11y', [
      this.gallery.displayTitle(),
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

  build() {
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
            .objectFit(this.useContainFit() ? ImageFit.Contain : ImageFit.Cover)
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
      .borderRadius(ThemeTokens.THUMB_RADIUS)
      .clip(true)
      .brightness(this.selected ? 0.86 : 1)
      GalleryLanguageCornerBadge({
        languageCode: this.gallery.languageCode(),
        textCenterXRatio: LANGUAGE_BADGE_COMPACT_TEXT_CENTER_X_RATIO,
        textCenterYRatio: LANGUAGE_BADGE_COMPACT_TEXT_CENTER_Y_RATIO,
      })
    }
    .width('100%')
    .aspectRatio(this.coverRatio())
    .borderRadius(ThemeTokens.GALLERY_GRID_CARD_RADIUS)
    .clip(true)
    .accessibilityText(this.accessibilityLabel())
    .onClick((): void => {
      if (this.onOpen) {
        this.onOpen(this.gallery.id)
      }
    })
  }
}
