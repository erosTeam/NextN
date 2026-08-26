import { NhGallerySummary, NhTag } from '../model/NhGallery'
import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'
import { CoverBackgroundState, connectCoverBackground } from '../state/CoverBackgroundState'
import { BrowsePresentationState, connectBrowsePresentation } from '../state/BrowsePresentationState'
import {
  TagTranslationSettingsState,
  connectTagTranslationSettings,
} from '../state/TagTranslationSettingsState'
import { EhImageKnifeImage } from './EhImageKnifeImage'
import { GalleryThumbnail } from './GalleryThumbnail'
import {
  EH_IMAGE_PRIORITY_LOW,
  EH_THUMBNAIL_CONNECT_TIMEOUT_MS,
  EH_THUMBNAIL_READ_TIMEOUT_MS,
} from '../services/ImagePipelineTypes'
import {
  GalleryLanguageCornerBadge,
  galleryLanguageCornerBadgeText,
} from './GalleryLanguageCornerBadge'
const WATERFALL_TAG_LIMIT: number = 8
const WATERFALL_COMPACT_TAG_STRIP_HEIGHT: number = 24

/**
 * Compact WaterFlow cards keep a different overlay subtree from CoverWall and
 * must not reuse each other's cached component instances.
 *
 * The current v2 summary already carries names resolved by the collection
 * catalog. This component renders them only in its compact, one-line overlay
 * grammar; it never issues per-card tag requests.
 */
export function galleryWaterfallCompactReuseId(gallery: NhGallerySummary): string {
  const imageShape: string = gallery.thumbnailUrl.length > 0 ? 'image' : 'no_image'
  const tagShape: string = gallery.tags.length > 0 ? 'tags' : 'no_tags'
  const languageShape: string = galleryLanguageCornerBadgeText(gallery.languageCode()).length > 0
    ? 'language'
    : 'plain'
  return `waterfall_compact_${imageShape}_${tagShape}_${languageShape}`
}

/**
 * Reduced-data counterpart of NextE's `GalleryWaterfallCard(compact: true)`.
 *
 * Like NextE, the card uses the source cover ratio as its WaterFlow height and
 * keeps title metadata directly on an image-gradient overlay. Missing summary
 * fields (tag colours, category, rating and user metadata) remain absent
 * instead of being guessed or fetched from a card.
 */
@ReusableV2
@ComponentV2
export struct GalleryWaterfallCompactCard {
  @Require @Param gallery: NhGallerySummary
  @Param selected: boolean = false
  @Param transitionCoverId: string = ''
  @Local hasThumbnailError: boolean = false
  @Local coverBackground: CoverBackgroundState = connectCoverBackground()
  @Local browsePresentation: BrowsePresentationState = connectBrowsePresentation()
  @Local tagTranslationSettings: TagTranslationSettingsState = connectTagTranslationSettings()
  private tagScroller: Scroller = new Scroller()
  @Event onOpen?: (galleryId: number) => void

  @Monitor('gallery')
  onGalleryChanged(): void {
    this.hasThumbnailError = false
    try {
      this.tagScroller.scrollTo({ xOffset: 0, yOffset: 0 })
    } catch (_error) {
    }
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


  private displayLabel(tag: NhTag): string {
    const translated: string = tag.displayName.trim()
    return this.tagTranslationSettings.enabled &&
      this.browsePresentation.showTranslatedTagLabels && translated.length > 0
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
  private CompactTagTextAt(index: number) {
    if (this.tagAt(index) !== undefined) {
      Column() {
        Text(this.tagLabelAt(index))
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_ON_BRAND)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(ThemeTokens.TAG_LINE_HEIGHT)
      }
      .height(ThemeTokens.TAG_LINE_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .clip(true)
    }
  }

  @Builder
  private CompactTags() {
    if (this.browsePresentation.showGalleryTags && this.gallery.tags.length > 0) {
      Scroll(this.tagScroller) {
        Row({ space: ThemeTokens.SPACE_XS }) {
          this.CompactTagTextAt(0)
          this.CompactTagTextAt(1)
          this.CompactTagTextAt(2)
          this.CompactTagTextAt(3)
          this.CompactTagTextAt(4)
          this.CompactTagTextAt(5)
          this.CompactTagTextAt(6)
          this.CompactTagTextAt(7)
        }
        .alignItems(VerticalAlign.Center)
      }
      .scrollable(ScrollDirection.Horizontal)
      .nestedScroll({
        scrollForward: NestedScrollMode.SELF_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST,
      })
      .scrollBar(BarState.Off)
      .align(Alignment.Start)
      .width('100%')
      .height(WATERFALL_COMPACT_TAG_STRIP_HEIGHT)
      .renderGroup(true)
    }
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
          .blur(ThemeTokens.COVER_BG_BLUR_RADIUS)
          .renderGroup(true)
      }
      GalleryThumbnail({
        src: this.gallery.thumbnailUrl,
        widthValue: '100%',
        heightValue: '100%',
        objectFit: ImageFit.Contain,
        onErrorStateChange: (failed: boolean): void => {
          this.hasThumbnailError = failed
        },
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
    .brightness(this.selected ? 0.86 : 1)
    .id(this.transitionCoverId)
  }

  @Builder
  private BottomOverlay() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      this.CompactTags()
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
