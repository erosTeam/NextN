import { NhGallerySummary, NhTag } from '../model/NhGallery'
import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'
import { CoverColorService } from '../services/CoverColorService'
import { CoverBackgroundState, connectCoverBackground } from '../state/CoverBackgroundState'
import { BrowsePresentationState, connectBrowsePresentation } from '../state/BrowsePresentationState'
import { EhImageKnifeImage } from './EhImageKnifeImage'
import {
  EH_IMAGE_PRIORITY_LOW,
  EH_THUMBNAIL_CONNECT_TIMEOUT_MS,
  EH_THUMBNAIL_READ_TIMEOUT_MS,
} from '../services/ImagePipelineTypes'
import {
  GalleryLanguageCornerBadge,
  galleryLanguageCornerBadgeText,
} from './GalleryLanguageCornerBadge'

const WATERFALL_MIN_COVER_RATIO: number = 0.5
const WATERFALL_MAX_COVER_RATIO: number = 1.35
const WATERFALL_TAG_LIMIT: number = 8
const WATERFALL_TAG_STRIP_HEIGHT: number = 48
const COVER_META_PAD_X: number = 7
const COVER_META_PAD_Y: number = 3

/**
 * Reuse only cards with the same conditional presentation structure.  The
 * regular waterfall keeps its metadata below the cover, unlike the compact
 * variant's image-overlay subtree.
 */
export function galleryWaterfallReuseId(gallery: NhGallerySummary): string {
  const imageShape: string = gallery.thumbnailUrl.length > 0 ? 'image' : 'no_image'
  const japaneseShape: string = gallery.japaneseTitle.length > 0 &&
    gallery.japaneseTitle !== gallery.displayTitle()
    ? 'japanese'
    : 'plain'
  const languageShape: string = galleryLanguageCornerBadgeText(gallery.languageCode()).length > 0
    ? 'language'
    : 'no_language'
  const pageShape: string = gallery.pageCount > 0 ? 'pages' : 'no_pages'
  const tagShape: string = gallery.tags.length > 0 ? 'tags' : 'no_tags'
  return `waterfall_${imageShape}_${japaneseShape}_${languageShape}_${pageShape}_${tagShape}`
}

/**
 * Reduced-data counterpart of NextE's regular `GalleryWaterfallCard`.
 *
 * The v2 summary lacks uploader, rating, favourite and category metadata, but
 * already owns resolved public tags. This card retains NextE's regular
 * waterfall structure: bounded variable-height cover, metadata block, and a
 * fixed two-row horizontal tag strip independent from the compact overlay.
 */
@ReusableV2
@ComponentV2
export struct GalleryWaterfallCard {
  @Require @Param gallery: NhGallerySummary
  @Param selected: boolean = false
  @Local isThumbnailLoading: boolean = true
  @Local hasThumbnailError: boolean = false
  @Local coverBackground: CoverBackgroundState = connectCoverBackground()
  @Local coverBackgroundColor: number = 0
  @Local browsePresentation: BrowsePresentationState = connectBrowsePresentation()
  private tagScroller: Scroller = new Scroller()
  @Event onOpen?: (galleryId: number) => void

  aboutToAppear(): void {
    this.resolveLetterboxColor()
  }

  @Monitor('gallery')
  onGalleryChanged(): void {
    this.isThumbnailLoading = this.gallery.thumbnailUrl.length > 0
    this.hasThumbnailError = false
    // Reusable WaterFlow slots retain their Scroller. A rebinding card must
    // never inherit another gallery's horizontally-scrolled tag position.
    try {
      this.tagScroller.scrollTo({ xOffset: 0, yOffset: 0 })
    } catch (_error) {
    }
    this.coverBackgroundColor = 0
    this.resolveLetterboxColor()
  }

  @Monitor('coverBackground.blurLetterboxBackground')
  onLetterboxBackgroundPreferenceChanged(): void {
    this.resolveLetterboxColor()
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

  private shouldUseGradientLetterboxBackground(): boolean {
    return !this.coverBackground.blurLetterboxBackground &&
      this.gallery.thumbnailUrl.length > 0 &&
      !this.hasThumbnailError &&
      this.imageFit() === ImageFit.Contain
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

  private displayLabel(tag: NhTag): string {
    const translated: string = tag.displayName.trim()
    return this.browsePresentation.showTranslatedTagLabels && translated.length > 0
      ? translated
      : tag.name
  }

  private tagAt(index: number): NhTag | undefined {
    if (
      !this.browsePresentation.showGalleryTags ||
      index < 0 ||
      index >= WATERFALL_TAG_LIMIT ||
      index >= this.gallery.tags.length
    ) {
      return undefined
    }
    const tag: NhTag = this.gallery.tags[index]
    return this.displayLabel(tag).trim().length > 0 ? tag : undefined
  }

  private tagLabelAt(index: number): string {
    const tag: NhTag | undefined = this.tagAt(index)
    return tag === undefined ? '' : this.displayLabel(tag)
  }

  @Builder
  private TagChipAt(index: number) {
    if (this.tagAt(index) !== undefined) {
      Text(this.tagLabelAt(index))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .backgroundColor(ThemeTokens.BRAND_CONTAINER)
        .borderRadius(ThemeTokens.LIST_TAG_RADIUS)
        .padding({ left: 6, right: 6, top: ThemeTokens.LIST_TAG_PADDING_VERTICAL, bottom: ThemeTokens.LIST_TAG_PADDING_VERTICAL })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 150 })
    }
  }

  @Builder
  private TagRow(remainder: number) {
    Row({ space: ThemeTokens.SPACE_XS }) {
      this.TagChipAt(remainder)
      this.TagChipAt(remainder + 2)
      this.TagChipAt(remainder + 4)
      this.TagChipAt(remainder + 6)
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private Tags() {
    if (this.browsePresentation.showGalleryTags && this.gallery.tags.length > 0) {
      Scroll(this.tagScroller) {
        Column({ space: ThemeTokens.SPACE_XS }) {
          this.TagRow(0)
          this.TagRow(1)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .scrollable(ScrollDirection.Horizontal)
      .nestedScroll({
        scrollForward: NestedScrollMode.SELF_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST,
      })
      .scrollBar(BarState.Off)
      .align(Alignment.Start)
      .width('100%')
      .height(WATERFALL_TAG_STRIP_HEIGHT)
      .renderGroup(true)
    }
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
        if (this.gallery.thumbnailUrl.length > 0 && !this.hasThumbnailError) {
          EhImageKnifeImage({
            src: this.gallery.thumbnailUrl,
            widthValue: '100%',
            heightValue: '100%',
            objectFit: this.imageFit(),
            priority: EH_IMAGE_PRIORITY_LOW,
            connectTimeoutMs: EH_THUMBNAIL_CONNECT_TIMEOUT_MS,
            readTimeoutMs: EH_THUMBNAIL_READ_TIMEOUT_MS,
            onComplete: (): void => {
              this.isThumbnailLoading = false
              this.hasThumbnailError = false
            },
            onError: (): void => {
              this.isThumbnailLoading = false
              this.hasThumbnailError = true
            },
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
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      if (this.gallery.japaneseTitle.length > 0 && this.gallery.japaneseTitle !== this.gallery.displayTitle()) {
        Text(this.gallery.japaneseTitle)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      this.Tags()
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
