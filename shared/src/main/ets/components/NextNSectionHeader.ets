import { ThemeTokens } from '../theme/ThemeTokens'

/**
 * Section title above one native grouped-list surface.
 *
 * This is the direct NextN counterpart of NextE's `SectionHeader`: the
 * header names a coherent settings family while the HDS rows keep ownership
 * of values, switches, and navigation actions.
 */
@ComponentV2
export struct NextNSectionHeader {
  @Param title: string = ''

  build() {
    Text(this.title)
      .fontSize(ThemeTokens.FONT_SIZE_LIST_ITEM)
      .fontWeight(FontWeight.Medium)
      .fontColor(ThemeTokens.TEXT_SECONDARY)
      .padding({
        left: ThemeTokens.SPACE_SM,
        right: ThemeTokens.SPACE_SM,
        top: ThemeTokens.SPACE_XS,
        bottom: ThemeTokens.SPACE_XS,
      })
      .width('100%')
      .textAlign(TextAlign.Start)
  }
}
