import { NhTag } from '../model/NhGallery'
import { BrowsePresentationState, connectBrowsePresentation } from '../state/BrowsePresentationState'
import { ThemeTokens } from '../theme/ThemeTokens'

export enum GalleryTagStripLayout {
  WRAP = 0,
  SINGLE_LINE = 1,
}

/**
 * Read-only gallery tag leaf. Its owner supplies already-resolved public
 * names and any optional local display label; this component never requests,
 * filters, translates, or navigates.
 */
@ComponentV2
export struct GalleryTagStrip {
  @Require @Param tags: NhTag[]
  @Param layout: GalleryTagStripLayout = GalleryTagStripLayout.WRAP
  @Param maxTags: number = 10
  @Param onDarkSurface: boolean = false
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
  private TagChip(tag: NhTag) {
    Text(this.displayLabel(tag))
      .fontSize(ThemeTokens.FONT_SIZE_TINY)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.onDarkSurface ? ThemeTokens.TEXT_ON_BRAND : ThemeTokens.TEXT_PRIMARY)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .border({
        width: this.onDarkSurface ? 0 : 1,
        color: this.onDarkSurface ? Color.Transparent : ThemeTokens.DIVIDER,
      })
      .borderRadius(ThemeTokens.RADIUS_MD)
      .padding({ left: 4, right: 4, top: 1, bottom: 1 })
  }

  build() {
    Column() {
      if (this.browsePresentation.showGalleryTags && this.visibleTags().length > 0) {
        if (this.layout === GalleryTagStripLayout.SINGLE_LINE) {
          List({ space: ThemeTokens.SPACE_XS }) {
            ForEach(this.visibleTags(), (tag: NhTag): void => {
              ListItem() {
                this.TagChip(tag)
              }
            }, (tag: NhTag): string => tag.id.toString())
          }
          .listDirection(Axis.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .height(20)
          .padding({ left: ThemeTokens.SPACE_XS, right: ThemeTokens.SPACE_XS })
        } else {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.visibleTags(), (tag: NhTag): void => {
              Column() {
                this.TagChip(tag)
              }
              .margin({ right: ThemeTokens.SPACE_XS, bottom: ThemeTokens.SPACE_XS })
            }, (tag: NhTag): string => tag.id.toString())
          }
          .width('100%')
        }
      }
    }
    .width('100%')
  }
}
