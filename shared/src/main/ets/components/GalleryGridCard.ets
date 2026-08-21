import { NhGallerySummary } from '../model/NhGallery'
import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'
import { CoverColorService } from '../services/CoverColorService'
import { CoverBackgroundState, connectCoverBackground } from '../state/CoverBackgroundState'
import { EhImageKnifeImage } from './EhImageKnifeImage'
import { GalleryThumbnail } from './GalleryThumbnail'
import {
  EH_IMAGE_PRIORITY_LOW,
  EH_THUMBNAIL_CONNECT_TIMEOUT_MS,
  EH_THUMBNAIL_READ_TIMEOUT_MS,
} from '../services/ImagePipelineTypes'
import {
  GalleryLanguageCornerBadge,
  LANGUAGE_BADGE_COMPACT_TEXT_CENTER_X_RATIO,
  LANGUAGE_BADGE_COMPACT_TEXT_CENTER_Y_RATIO,
} from './GalleryLanguageCornerBadge'

const COVER_META_PAD_X: number = 7
const COVER_META_PAD_Y: number = 3
// Keep this classification aligned with NextE's `EhThumbnail.coverObjectFit()`.
// It measures h / w because the fixed grid slot is expressed as width / height.
const GRID_MIN_CONTAIN_SOURCE_RATIO: number = 0.8
const GRID_MAX_CONTAIN_SOURCE_RATIO: number = 2.2

/**
 * The default NextE browse card, adapted only at the data boundary for the
 * read-only NextN gallery DTO. It deliberately keeps a compact, cover-first
 * rhythm: metadata overlays the cover, while title and page count remain in a
 * fixed information block below it.
 */
@ComponentV2
export struct GalleryGridCard {
  @Require @Param gallery: NhGallerySummary
  @Param selected: boolean = false
  @Local hasThumbnailError: boolean = false
  @Local coverBackground: CoverBackgroundState = connectCoverBackground()
  @Local coverBackgroundColor: number = 0
  @Event onOpen?: (galleryId: number) => void

  aboutToAppear(): void {
    this.resolveLetterboxColor()
  }

  @Monitor('gallery')
  onGalleryChanged(): void {
    this.hasThumbnailError = false
    this.coverBackgroundColor = 0
    this.resolveLetterboxColor()
  }

  @Monitor('coverBackground.blurLetterboxBackground')
  onLetterboxBackgroundPreferenceChanged(): void {
    this.resolveLetterboxColor()
  }

  /**
   * NextE keeps the fixed cover-grid frame, but only center-crops source
   * ratios inside its normal h/w band. Extremely wide or tall covers retain
   * their full content in the same frame instead of becoming a crop strip.
   */
  private useContainFit(): boolean {
    if (this.gallery.thumbnailWidth <= 0 || this.gallery.thumbnailHeight <= 0) {
      return false
    }
    const sourceRatio: number = this.gallery.thumbnailHeight / this.gallery.thumbnailWidth
    return sourceRatio <= GRID_MIN_CONTAIN_SOURCE_RATIO ||
      sourceRatio >= GRID_MAX_CONTAIN_SOURCE_RATIO
  }

  private shouldBlurLetterboxBackground(): boolean {
    return this.coverBackground.blurLetterboxBackground &&
      this.gallery.thumbnailUrl.length > 0 &&
      !this.hasThumbnailError &&
      this.useContainFit()
  }

  private shouldUseGradientLetterboxBackground(): boolean {
    return !this.coverBackground.blurLetterboxBackground &&
      this.gallery.thumbnailUrl.length > 0 &&
      !this.hasThumbnailError &&
      this.useContainFit()
  }

  private resolveLetterboxColor(): void {
    if (!this.shouldUseGradientLetterboxBackground()) {
      return
    }
    const url: string = this.gallery.thumbnailUrl
    const cached: number = CoverColorService.getInstance().cached(url)
    if (cached !== 0) {
      this.coverBackgroundColor = cached
      return
    }
    CoverColorService.getInstance().resolve(url).then((color: number): void => {
      if (this.gallery.thumbnailUrl === url) {
        this.coverBackgroundColor = color
      }
    })
  }

  private fadedLetterboxColor(): string {
    const rgb: number = this.coverBackgroundColor & 0x00ffffff
    return '#00' + rgb.toString(16).padStart(6, '0')
  }

  private accessibilityLabel(): string {
    return AppStrings.format('gallery_card_a11y', [
      this.gallery.displayTitle(),
      AppStrings.format('gallery_meta_pages', [this.gallery.pageCount.toString()]),
    ])
  }

  private static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }

  private static formatDate(value: number): string {
    const date: Date = new Date(value * 1000)
    const month: number = date.getMonth() + 1
    return `${date.getFullYear()}-${GalleryGridCard.pad2(month)}-${GalleryGridCard.pad2(date.getDate())}`
  }

  /**
   * Mirrors NextE GalleryGridCard.metaText(): upload date first. The
   * page count already lives in the cover overlay, so it is never
   * repeated here; the favourite count is the list's other real metadata.
   */
  private metaText(): string {
    if (this.gallery.uploadDate > 0) {
      return GalleryGridCard.formatDate(this.gallery.uploadDate)
    }
    if (this.gallery.favoriteCount > 0) {
      return `${this.gallery.favoriteCount}`
    }
    return ''
  }

  private hasFavoriteMeta(): boolean {
    return this.gallery.uploadDate <= 0 && this.gallery.favoriteCount > 0
  }

  @Builder
  private CoverMeta() {
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

  @Builder
  private Cover() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Stack({ alignContent: Alignment.Center }) {
        // NextE always fills an extreme-ratio contain gap: the default is a
        // dominant-color fade, while this existing preference selects blur.
        if (this.shouldBlurLetterboxBackground()) {
          EhImageKnifeImage({
            src: this.gallery.thumbnailUrl,
            widthValue: '100%',
            heightValue: '100%',
            objectFit: ImageFit.Cover,
            priority: EH_IMAGE_PRIORITY_LOW,
            connectTimeoutMs: EH_THUMBNAIL_CONNECT_TIMEOUT_MS,
            readTimeoutMs: EH_THUMBNAIL_READ_TIMEOUT_MS,
          })
            .blur(ThemeTokens.COVER_BG_BLUR_RADIUS)
            .renderGroup(true)
        } else if (this.shouldUseGradientLetterboxBackground() && this.coverBackgroundColor !== 0) {
          Column()
            .width('100%')
            .height('100%')
            .borderRadius(ThemeTokens.THUMB_RADIUS)
            .clip(true)
            .linearGradient({
              direction: GradientDirection.Bottom,
              colors: [
                [this.coverBackgroundColor, 0.0],
                [this.fadedLetterboxColor(), 1.0],
              ],
            })
        }
        GalleryThumbnail({
          src: this.gallery.thumbnailUrl,
          widthValue: '100%',
          heightValue: '100%',
          objectFit: this.useContainFit() ? ImageFit.Contain : ImageFit.Cover,
          radius: ThemeTokens.THUMB_RADIUS,
          onErrorStateChange: (failed: boolean): void => {
            this.hasThumbnailError = failed
          },
        })
      }
      .width('100%')
      .height('100%')
      GalleryLanguageCornerBadge({
        languageCode: this.gallery.languageCode(),
        textCenterXRatio: LANGUAGE_BADGE_COMPACT_TEXT_CENTER_X_RATIO,
        textCenterYRatio: LANGUAGE_BADGE_COMPACT_TEXT_CENTER_Y_RATIO,
      })
      this.CoverMeta()
    }
    .width('100%')
    .aspectRatio(ThemeTokens.GALLERY_GRID_COVER_RATIO)
    .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
    .borderRadius(ThemeTokens.THUMB_RADIUS)
    .clip(true)
  }

  @Builder
  private Info() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Text(this.gallery.displayTitle())
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .height(ThemeTokens.GALLERY_GRID_TITLE_HEIGHT)
        .width('100%')
      Row({ space: 2 }) {
        if (this.hasFavoriteMeta()) {
          SymbolGlyph($r('sys.symbol.heart'))
            .fontSize(12)
            .fontColor([ThemeTokens.TEXT_SECONDARY])
        }
        Text(this.metaText())
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .height(ThemeTokens.GALLERY_GRID_META_HEIGHT)
      .width('100%')
    }
    .width('100%')
    .height(ThemeTokens.GALLERY_GRID_INFO_HEIGHT)
    .justifyContent(FlexAlign.Start)
    .padding({ left: ThemeTokens.SPACE_XS, right: ThemeTokens.SPACE_XS })
  }

  build() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      this.Cover()
      this.Info()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(ThemeTokens.GALLERY_GRID_CARD_RADIUS)
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
