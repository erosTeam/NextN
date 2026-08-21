import { NhGallerySummary } from '../model/NhGallery'
import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'
import { GalleryThumbnail } from './GalleryThumbnail'

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
  @Event onOpen?: (galleryId: number) => void

  private accessibilityLabel(): string {
    return AppStrings.format('gallery_card_a11y', [
      this.gallery.displayTitle(),
      AppStrings.format('gallery_meta_pages', [this.gallery.pageCount.toString()]),
    ])
  }

  build() {
    // Keep NextE's compact simple-row grammar fixed at 72×102: tags belong to
    // the distinct LIST and Waterfall contracts, not this metadata row.
    Row({ space: ThemeTokens.SPACE_SM }) {
      GalleryThumbnail({
        src: this.gallery.thumbnailUrl,
        widthValue: ThemeTokens.COVER_WIDTH,
        heightValue: ThemeTokens.COVER_HEIGHT,
        objectFit: ImageFit.Cover,
        radius: ThemeTokens.THUMB_RADIUS,
      })
        .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
        .borderRadius(ThemeTokens.THUMB_RADIUS)
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
