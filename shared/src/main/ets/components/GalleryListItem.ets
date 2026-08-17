import { NhGallerySummary } from '../model/NhGallery'
import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'
import { EhImageKnifeImage } from './EhImageKnifeImage'
import {
  EH_IMAGE_PRIORITY_LOW,
  EH_THUMBNAIL_CONNECT_TIMEOUT_MS,
  EH_THUMBNAIL_READ_TIMEOUT_MS,
} from '../services/ImagePipelineTypes'

@ComponentV2
export struct GalleryListItem {
  @Require @Param gallery: NhGallerySummary
  @Param selected: boolean = false
  @Local isThumbnailLoading: boolean = true
  @Local hasThumbnailError: boolean = false
  @Event onOpen?: (galleryId: number) => void

  @Monitor('gallery')
  onGalleryChanged(): void {
    this.isThumbnailLoading = this.gallery.thumbnailUrl.length > 0
    this.hasThumbnailError = false
  }

  private accessibilityLabel(): string {
    return AppStrings.format('gallery_card_a11y', [
      this.gallery.displayTitle(),
      AppStrings.format('gallery_meta_pages', [this.gallery.pageCount.toString()]),
    ])
  }

  @Builder
  private ThumbnailState() {
    if (this.isThumbnailLoading || this.hasThumbnailError) {
      Column({ space: ThemeTokens.SPACE_XS }) {
        if (this.hasThumbnailError) {
          SymbolGlyph($r('sys.symbol.picture'))
            .fontSize(28)
            .fontColor([ThemeTokens.TEXT_TERTIARY])
          Text(AppStrings.get('gallery_image_unavailable'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(ThemeTokens.TEXT_TERTIARY)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
      .borderRadius(ThemeTokens.THUMB_RADIUS)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  build() {
    // Keep NextE's compact simple-row grammar fixed at 72×102: tags belong to
    // the distinct LIST and Waterfall contracts, not this metadata row.
    Row({ space: ThemeTokens.SPACE_SM }) {
      if (this.gallery.thumbnailUrl.length > 0) {
        Stack({ alignContent: Alignment.Center }) {
          EhImageKnifeImage({
            src: this.gallery.thumbnailUrl,
            widthValue: '100%',
            heightValue: '100%',
            objectFit: ImageFit.Cover,
            radius: ThemeTokens.THUMB_RADIUS,
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
          this.ThumbnailState()
        }
          .width(ThemeTokens.COVER_WIDTH)
          .height(ThemeTokens.COVER_HEIGHT)
          .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
          .borderRadius(ThemeTokens.THUMB_RADIUS)
      } else {
        Column() {
          Text(AppStrings.get('gallery_no_cover'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_TERTIARY)
        }
          .width(ThemeTokens.COVER_WIDTH)
          .height(ThemeTokens.COVER_HEIGHT)
          .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
          .borderRadius(ThemeTokens.THUMB_RADIUS)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
      }
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
