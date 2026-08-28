import { NhGallerySummary } from '../model/NhGallery'
import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'
import { CoverColorService } from '../services/CoverColorService'
import {
  EH_IMAGE_PRIORITY_LOW,
  EH_THUMBNAIL_CONNECT_TIMEOUT_MS,
  EH_THUMBNAIL_READ_TIMEOUT_MS,
} from '../services/ImagePipelineTypes'
import { CoverBackgroundState, connectCoverBackground } from '../state/CoverBackgroundState'
import { EhImageKnifeImage } from './EhImageKnifeImage'
import { GalleryThumbnail } from './GalleryThumbnail'

// Keep this classification aligned with GalleryGridCard and NextE's fixed-ratio thumbnail path.
const SIMPLE_MIN_CONTAIN_SOURCE_RATIO: number = 0.8
const SIMPLE_MAX_CONTAIN_SOURCE_RATIO: number = 2.2

// Reuse only rows with the same optional Japanese-title and language nodes.
export function galleryListItemReuseId(gallery: NhGallerySummary): string {
  const japaneseShape: string = gallery.japaneseTitle.length > 0 &&
    gallery.japaneseTitle !== gallery.displayTitle()
    ? 'japanese'
    : 'plain'
  const languageShape: string = gallery.languageCode().length > 0 ? 'language' : 'no_language'
  return `simple_${japaneseShape}_${languageShape}`
}

@ReusableV2
@ComponentV2
export struct GalleryListItem {
  @Require @Param gallery: NhGallerySummary
  @Param selected: boolean = false
  @Param transitionCoverId: string = ''
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

  private useContainFit(): boolean {
    if (this.gallery.thumbnailWidth <= 0 || this.gallery.thumbnailHeight <= 0) {
      return false
    }
    const sourceRatio: number = this.gallery.thumbnailHeight / this.gallery.thumbnailWidth
    return sourceRatio <= SIMPLE_MIN_CONTAIN_SOURCE_RATIO ||
      sourceRatio >= SIMPLE_MAX_CONTAIN_SOURCE_RATIO
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

  private sourceCoverAspectRatio(): number {
    if (this.gallery.thumbnailWidth <= 0 || this.gallery.thumbnailHeight <= 0) {
      return ThemeTokens.COVER_WIDTH / ThemeTokens.COVER_HEIGHT
    }
    return this.gallery.thumbnailWidth / this.gallery.thumbnailHeight
  }

  private foregroundCoverWidth(): Length {
    if (!this.useContainFit()) {
      return '100%'
    }
    const sourceRatio: number = this.sourceCoverAspectRatio()
    const slotRatio: number = ThemeTokens.COVER_WIDTH / ThemeTokens.COVER_HEIGHT
    if (sourceRatio >= slotRatio) {
      return '100%'
    }
    return `${Math.max(0, Math.min(100, sourceRatio / slotRatio * 100))}%`
  }

  private foregroundCoverHeight(): Length {
    if (!this.useContainFit()) {
      return '100%'
    }
    const sourceRatio: number = this.sourceCoverAspectRatio()
    const slotRatio: number = ThemeTokens.COVER_WIDTH / ThemeTokens.COVER_HEIGHT
    if (sourceRatio <= slotRatio) {
      return '100%'
    }
    return `${Math.max(0, Math.min(100, slotRatio / sourceRatio * 100))}%`
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

  private transitionCoverBackgroundId(): string {
    return this.transitionCoverId.length > 0 ? `${this.transitionCoverId}-background` : ''
  }

  private accessibilityLabel(): string {
    return AppStrings.format('gallery_card_a11y', [
      this.gallery.displayTitle(),
      AppStrings.format('gallery_meta_pages', [this.gallery.pageCount.toString()]),
    ])
  }

  @Builder
  private Cover() {
    Stack({ alignContent: Alignment.Center }) {
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
          .id(this.transitionCoverBackgroundId())
          .blur(ThemeTokens.COVER_BG_BLUR_RADIUS)
          .renderGroup(true)
      } else if (this.shouldUseGradientLetterboxBackground() && this.coverBackgroundColor !== 0) {
        Column()
          .id(this.transitionCoverBackgroundId())
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
        surfaceWidthValue: this.foregroundCoverWidth(),
        surfaceHeightValue: this.foregroundCoverHeight(),
        objectFit: this.useContainFit() ? ImageFit.Fill : ImageFit.Cover,
        radius: ThemeTokens.THUMB_RADIUS,
        surfaceId: this.transitionCoverId,
        onErrorStateChange: (failed: boolean): void => {
          this.hasThumbnailError = failed
        },
      })
    }
    .width(ThemeTokens.COVER_WIDTH)
    .height(ThemeTokens.COVER_HEIGHT)
    .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
    .borderRadius(ThemeTokens.THUMB_RADIUS)
    .clip(true)
  }

  build() {
    // Keep NextE's compact simple-row grammar fixed at 72×102: tags belong to
    // the distinct LIST and Waterfall contracts, not this metadata row.
    Row({ space: ThemeTokens.SPACE_SM }) {
      this.Cover()
      Column({ space: ThemeTokens.SPACE_XS }) {
        Text(this.gallery.displayTitle())
          .fontSize(ThemeTokens.FONT_SIZE_META)
          .fontWeight(FontWeight.Regular)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
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
        Blank()
        // Keep the final metadata row in the same simple-list grammar as
        // NextE: optional language at the leading edge, pages at the end.
        // The language comes from ErosN's stable v2 tag-id mapping, so this
        // does not trigger an extra catalog request for every rendered row.
        Row({ space: ThemeTokens.SPACE_XS }) {
          if (this.gallery.languageCode().length > 0) {
            Text(this.gallery.languageCode())
              .fontSize(ThemeTokens.FONT_SIZE_TINY)
              .fontColor(ThemeTokens.TEXT_TERTIARY)
              .margin({ right: ThemeTokens.SPACE_XS })
          }
          Blank()
          Text(`${this.gallery.pageCount}P`)
            .fontSize(ThemeTokens.FONT_SIZE_TINY)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
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
    .backgroundColor(this.selected ? $r('app.color.navigation_item_selected') : Color.Transparent)
    .accessibilityText(this.accessibilityLabel())
    .onClick((): void => {
      if (this.onOpen) {
        this.onOpen(this.gallery.id)
      }
    })
  }
}
