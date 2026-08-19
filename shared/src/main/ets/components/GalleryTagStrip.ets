import { NhTag } from '../model/NhGallery'
import { BrowsePresentationState, connectBrowsePresentation } from '../state/BrowsePresentationState'
import { ThemeTokens } from '../theme/ThemeTokens'

/**
 * Normal LIST's wrapping tag leaf. Its fixed-height parent confines it to a
 * bounded middle region; the adaptive parent deliberately grows with content.
 * Waterfall cards own separate strip trees because their line budgets and
 * scroll owners are different.
 */
@ComponentV2
export struct GalleryTagStrip {
  @Require @Param tags: NhTag[]
  @Param maxTags: number = 10
  @Local browsePresentation: BrowsePresentationState = connectBrowsePresentation()

  private visibleTags(): NhTag[] {
    const result: NhTag[] = []
    const limit: number = Math.max(1, Math.min(10, Math.floor(this.maxTags)))
    for (let index: number = 0; index < this.tags.length && result.length < limit; index++) {
      if (this.displayLabel(this.tags[index]).length > 0) {
        result.push(this.tags[index])
      }
    }
    return result
  }

  private displayLabel(tag: NhTag): string {
    const translated: string = tag.displayName.trim()
    return this.browsePresentation.showTranslatedTagLabels && translated.length > 0
      ? translated
      : tag.name
  }

  @Builder
  private LightTagChip(tag: NhTag) {
    Column() {
      Text(this.displayLabel(tag))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .backgroundColor(ThemeTokens.BRAND_CONTAINER)
        .borderRadius(ThemeTokens.LIST_TAG_RADIUS)
        .padding({
          left: 6,
          right: 6,
          top: ThemeTokens.LIST_TAG_PADDING_VERTICAL,
          bottom: ThemeTokens.LIST_TAG_PADDING_VERTICAL,
        })
        .lineHeight(ThemeTokens.TAG_LINE_HEIGHT)
    }
    .height(ThemeTokens.TAG_LINE_HEIGHT + 2 * ThemeTokens.LIST_TAG_PADDING_VERTICAL)
    .justifyContent(FlexAlign.Center)
    .clip(true)
  }

  build() {
    Column() {
      if (this.browsePresentation.showGalleryTags && this.visibleTags().length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.visibleTags(), (tag: NhTag): void => {
            Column() {
              this.LightTagChip(tag)
            }
            .margin({ right: ThemeTokens.SPACE_XS, bottom: ThemeTokens.SPACE_XS })
          }, (tag: NhTag): string => tag.id.toString())
        }
        .width('100%')
      }
    }
    .width('100%')
  }
}
