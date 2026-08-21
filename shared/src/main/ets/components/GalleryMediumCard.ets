import { NhGallerySummary } from '../model/NhGallery'
import { LengthMetrics } from '@kit.ArkUI'
import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'
import { CoverColorService } from '../services/CoverColorService'
import { CoverBackgroundState, connectCoverBackground } from '../state/CoverBackgroundState'
import { BrowsePresentationState, connectBrowsePresentation } from '../state/BrowsePresentationState'
import { EhImageKnifeImage } from './EhImageKnifeImage'
import { GalleryThumbnail } from './GalleryThumbnail'
import { GalleryTagStrip } from './GalleryTagStrip'
import {
  EH_IMAGE_PRIORITY_LOW,
  EH_THUMBNAIL_CONNECT_TIMEOUT_MS,
  EH_THUMBNAIL_READ_TIMEOUT_MS,
} from '../services/ImagePipelineTypes'

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
  @Local hasThumbnailError: boolean = false
  @Local coverBackground: CoverBackgroundState = connectCoverBackground()
  @Local coverBackgroundColor: number = 0
  @Local browsePresentation: BrowsePresentationState = connectBrowsePresentation()
  /** The content-measured adaptive cover slot; zero retains the ratio-based initial floor. */
  @Local adaptiveCoverSlotHeight: number = 0
  @Event onOpen?: (galleryId: number) => void

  aboutToAppear(): void {
    this.resolveLetterboxColor()
  }

  @Monitor('gallery')
  onGalleryChanged(): void {
    this.hasThumbnailError = false
    this.adaptiveCoverSlotHeight = 0
    this.coverBackgroundColor = 0
    this.resolveLetterboxColor()
  }

  @Monitor('coverBackground.blurLetterboxBackground')
  onLetterboxBackgroundPreferenceChanged(): void {
    this.resolveLetterboxColor()
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

  /**
   * The cover slot's own height (NextE parity): fixed rows pin 204; adaptive
   * rows use the measured stretch height, floored by the responsive minimum.
   * NextE never compresses a card below that floor for a short cover — an
   * off-ratio cover letterboxes inside the slot with the gradient/blur fill.
   */
  private coverSlotHeight(): number {
    return this.activeCoverHeight()
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

  private favoriteLabel(): string {
    if (this.gallery.favoriteCount <= 0) {
      return ''
    }
    return this.gallery.favoriteCount.toString()
  }

  @Builder
  private CoverContents() {
    // NextE letterbox fill: dominant-color gradient by default, blurred cover
    // copy when the preference is enabled. Scoped to contained extreme ratios.
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
      // NextE list covers carry no radius (EhThumbnail radius: 0): the
      // image itself is the visible surface in adaptive/contain rows.
      radius: 0,
      onErrorStateChange: (failed: boolean): void => {
        this.hasThumbnailError = failed
      },
    })
  }

  build() {
    // Flex with ItemAlign.Stretch (NextE parity): the text column defines the
    // row height in adaptive mode and the cover slot stretches to it; in fixed
    // mode the pinned 204vp constraint defines it. An explicit cover height
    // would feed back into the row and lock every card to the cover estimate.
    Flex({
      direction: FlexDirection.Row,
      space: { main: LengthMetrics.vp(ThemeTokens.SPACE_SM) },
      alignItems: ItemAlign.Stretch,
    }) {
      Stack({ alignContent: Alignment.Center }) {
        this.CoverContents()
      }
      .width(this.coverWidth())
      .height(this.coverSlotHeight())
      .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
      .onAreaChange((_oldArea: Area, area: Area): void => {
        if (this.usesFixedHeight()) {
          return
        }
        const height: number = Number.parseFloat(`${area.height}`)
        if (height > 0 && Math.abs(height - this.adaptiveCoverSlotHeight) > 0.5) {
          this.adaptiveCoverSlotHeight = height
        }
      })

      Column({ space: ThemeTokens.SPACE_XS }) {
        Text(this.gallery.displayTitle())
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .lineHeight(ThemeTokens.LINE_HEIGHT_TITLE)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.gallery.japaneseTitle.length > 0 && this.gallery.japaneseTitle !== this.gallery.displayTitle()) {
          Text(this.gallery.japaneseTitle)
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }

        if (this.usesFixedHeight()) {
          // The fixed 204vp card needs a bounded middle region: tags may
          // wrap, but they must never displace the foot-anchored metadata or
          // escape the clipped card on a narrow pane.
          Column() {
            GalleryTagStrip({ tags: this.gallery.tags, maxTags: 8 })
          }
          .width('100%')
          .layoutWeight(1)
          .clip(true)
          .alignItems(HorizontalAlign.Start)
        } else {
          // NextE adaptive flow: the tags float centered between two springs
          // and the card grows to fit every wrapped row.
          Blank()
          GalleryTagStrip({ tags: this.gallery.tags, maxTags: 8 })
          Blank()
        }
        Row({ space: ThemeTokens.SPACE_XS }) {
          if (this.gallery.languageCode().length > 0) {
            Text(this.gallery.languageCode())
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontColor(ThemeTokens.TEXT_TERTIARY)
          }
          Blank()
          if (this.favoriteLabel().length > 0) {
            Row({ space: 2 }) {
              SymbolGlyph($r('sys.symbol.heart_fill'))
                .fontSize(ThemeTokens.FONT_SIZE_TINY)
                .fontColor([ThemeTokens.BRAND])
              Text(this.favoriteLabel())
                .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                .fontColor(ThemeTokens.TEXT_TERTIARY)
            }
            .alignItems(VerticalAlign.Center)
          }
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
