import { NhGallerySummary } from '../model/NhGallery'
import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'
import { CoverBackgroundState, connectCoverBackground } from '../state/CoverBackgroundState'
import { GalleryTagStrip } from './GalleryTagStrip'

// NextE's medium list card keeps a fixed portrait-cover rhythm so a long title
// cannot make adjacent rows jump. The available NextN summary has no uploader,
// tags, rating, category, or post-time fields, so the card renders only the
// stable title/language/page metadata that can be proved locally.
const MEDIUM_COVER_WIDTH: number = 143
const MEDIUM_COVER_HEIGHT: number = 204
const MEDIUM_COVER_MAX_FILL_DELTA: number = 0.28
const MEDIUM_COVER_MIN_FILL_DELTA: number = 0.2

/**
 * Reduced NextE medium-list gallery card for the read-only NhGallerySummary.
 *
 * The card owns only presentation state (thumbnail loading/error) and an
 * optional navigation callback; it never fetches or enriches a gallery.
 */
@ComponentV2
export struct GalleryMediumCard {
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

  /**
   * Direct port of NextE GalleryCard's cover-slot comparison for this fixed
   * medium-card slot. Close source/frame ratios receive a light crop; a far
   * ratio is contained so the full cover stays visible in its fixed row.
   */
  private coverFillsSlot(): boolean {
    if (this.gallery.thumbnailWidth <= 0 || this.gallery.thumbnailHeight <= 0) {
      return false
    }
    const imageRatio: number = this.gallery.thumbnailWidth / this.gallery.thumbnailHeight
    const slotRatio: number = MEDIUM_COVER_WIDTH / MEDIUM_COVER_HEIGHT
    return imageRatio - slotRatio <= MEDIUM_COVER_MAX_FILL_DELTA &&
      slotRatio - imageRatio <= MEDIUM_COVER_MIN_FILL_DELTA
  }

  private useContainFit(): boolean {
    return !this.coverFillsSlot()
  }

  private shouldBlurLetterboxBackground(): boolean {
    return this.coverBackground.blurLetterboxBackground &&
      this.gallery.thumbnailUrl.length > 0 &&
      !this.hasThumbnailError &&
      this.useContainFit()
  }

  private accessibilityLabel(): string {
    return AppStrings.format('gallery_card_a11y', [
      this.gallery.displayTitle(),
      AppStrings.format('gallery_meta_pages', [this.gallery.pageCount.toString()]),
    ])
  }

  @Builder
  private ThumbnailState() {
    if (this.isThumbnailLoading || this.hasThumbnailError || this.gallery.thumbnailUrl.length === 0) {
      Column({ space: ThemeTokens.SPACE_XS }) {
        SymbolGlyph($r('sys.symbol.picture'))
          .fontSize(28)
          .fontColor([ThemeTokens.TEXT_TERTIARY])
        if (this.hasThumbnailError || this.gallery.thumbnailUrl.length === 0) {
          Text(AppStrings.get('gallery_no_cover'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
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
    Row({ space: ThemeTokens.SPACE_SM }) {
      Stack({ alignContent: Alignment.Center }) {
        // Existing NextN cover-background preference is intentionally scoped
        // to contained extreme ratios; ordinary covers retain the old direct
        // cover path and this row's geometry remains unchanged.
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
      .width(MEDIUM_COVER_WIDTH)
      .height(MEDIUM_COVER_HEIGHT)
      .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
      .borderRadius(ThemeTokens.THUMB_RADIUS)
      .clip(true)

      Column({ space: ThemeTokens.SPACE_XS }) {
        Text(this.gallery.displayTitle())
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .lineHeight(ThemeTokens.LINE_HEIGHT_TITLE)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.gallery.japaneseTitle.length > 0 && this.gallery.japaneseTitle !== this.gallery.englishTitle) {
          Text(this.gallery.japaneseTitle)
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }

        GalleryTagStrip({ tags: this.gallery.tags, maxTags: 6 })

        // The medium card keeps metadata at the foot of the fixed-height
        // column, matching NextE's title/content/meta hierarchy.
        Blank()
        Row({ space: ThemeTokens.SPACE_XS }) {
          if (this.gallery.languageCode().length > 0) {
            Text(this.gallery.languageCode())
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontColor(ThemeTokens.TEXT_TERTIARY)
          }
          Blank()
          Text(`${this.gallery.pageCount}P`)
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .height(MEDIUM_COVER_HEIGHT)
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: ThemeTokens.SPACE_SM,
        right: ThemeTokens.SPACE_MD,
        top: ThemeTokens.SPACE_SM,
        bottom: ThemeTokens.SPACE_SM,
      })
    }
    .width('100%')
    .height(MEDIUM_COVER_HEIGHT)
    .borderRadius(ThemeTokens.RADIUS_MD)
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
