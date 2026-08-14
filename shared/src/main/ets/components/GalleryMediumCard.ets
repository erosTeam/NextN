import { NhGallerySummary } from '../model/NhGallery'
import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'
import { CoverBackgroundState, connectCoverBackground } from '../state/CoverBackgroundState'
import { BrowsePresentationState, connectBrowsePresentation } from '../state/BrowsePresentationState'
import { GalleryTagStrip } from './GalleryTagStrip'

// Fixed mode preserves the existing portrait-cover rhythm. Adaptive mode keeps
// that cover ratio as its floor, then lets the title/tag column grow.
const MEDIUM_COVER_WIDTH: number = 143
const MEDIUM_COVER_HEIGHT: number = 204
const MEDIUM_COVER_ASPECT: number = MEDIUM_COVER_WIDTH / MEDIUM_COVER_HEIGHT
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
  /** Measured by the shared List host; used only by adaptive LIST rows. */
  @Param listContentWidth: number = 0
  @Local isThumbnailLoading: boolean = true
  @Local hasThumbnailError: boolean = false
  @Local coverBackground: CoverBackgroundState = connectCoverBackground()
  @Local browsePresentation: BrowsePresentationState = connectBrowsePresentation()
  /** The content-measured adaptive cover slot; zero retains the ratio-based initial floor. */
  @Local adaptiveCoverSlotHeight: number = 0
  @Event onOpen?: (galleryId: number) => void

  @Monitor('gallery')
  onGalleryChanged(): void {
    this.isThumbnailLoading = this.gallery.thumbnailUrl.length > 0
    this.hasThumbnailError = false
    this.adaptiveCoverSlotHeight = 0
  }

  @Monitor('browsePresentation.listCardFixedHeight')
  onListCardFixedHeightChanged(): void {
    // A reused card must not briefly apply the previous adaptive row height
    // after the user returns from fixed mode.
    this.adaptiveCoverSlotHeight = 0
  }

  private usesFixedHeight(): boolean {
    return this.browsePresentation.listCardFixedHeight
  }

  /** Keep the established 143vp cover in fixed mode; adaptive rows narrow safely in a narrow List. */
  private coverWidth(): number {
    if (this.usesFixedHeight()) {
      return MEDIUM_COVER_WIDTH
    }
    const availableWidth: number = this.listContentWidth > 0
      ? this.listContentWidth
      : MEDIUM_COVER_WIDTH * 3
    const thirdWidth: number = availableWidth / 3
    return thirdWidth > 0 && thirdWidth < MEDIUM_COVER_WIDTH ? thirdWidth : MEDIUM_COVER_WIDTH
  }

  private minimumAdaptiveHeight(): number {
    return this.coverWidth() / MEDIUM_COVER_ASPECT
  }

  private activeCoverHeight(): number {
    if (!this.usesFixedHeight() && this.adaptiveCoverSlotHeight > 0) {
      return this.adaptiveCoverSlotHeight
    }
    return this.usesFixedHeight() ? MEDIUM_COVER_HEIGHT : this.minimumAdaptiveHeight()
  }

  /** Close source/frame ratios receive a light crop; far ratios keep the whole cover visible. */
  private coverFillsSlot(): boolean {
    if (this.gallery.thumbnailWidth <= 0 || this.gallery.thumbnailHeight <= 0) {
      return false
    }
    const imageRatio: number = this.gallery.thumbnailWidth / this.gallery.thumbnailHeight
    const slotRatio: number = this.coverWidth() / this.activeCoverHeight()
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

  @Builder
  private CoverContents() {
    // Existing NextN cover-background preference stays scoped to contained
    // extreme ratios; only the containing slot becomes adaptive.
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

  build() {
    Row({ space: ThemeTokens.SPACE_SM }) {
      Stack({ alignContent: Alignment.Center }) {
        this.CoverContents()
      }
      .width(this.coverWidth())
      .height(this.activeCoverHeight())
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

        if (this.usesFixedHeight()) {
          GalleryTagStrip({ tags: this.gallery.tags, maxTags: 6 })
          // Fixed rows retain the existing foot-anchored metadata rhythm.
          Blank()
        } else {
          // Adaptive rows follow the title → tags → metadata content flow.
          // `Blank()` would consume a List's unconstrained vertical offer.
          GalleryTagStrip({ tags: this.gallery.tags, maxTags: 6 })
        }
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
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: ThemeTokens.SPACE_SM,
        right: ThemeTokens.SPACE_MD,
        top: ThemeTokens.SPACE_SM,
        bottom: ThemeTokens.SPACE_SM,
      })
      .constraintSize(
        this.usesFixedHeight()
          ? { minHeight: MEDIUM_COVER_HEIGHT, maxHeight: MEDIUM_COVER_HEIGHT }
          : { minHeight: this.minimumAdaptiveHeight() },
      )
      .onAreaChange((_oldArea: Area, area: Area): void => {
        if (this.usesFixedHeight()) {
          return
        }
        const nextHeight: number = Number.parseFloat(`${area.height}`)
        if (nextHeight > 0 && Math.abs(nextHeight - this.adaptiveCoverSlotHeight) > 0.5) {
          this.adaptiveCoverSlotHeight = nextHeight
        }
      })
    }
    .width('100%')
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
