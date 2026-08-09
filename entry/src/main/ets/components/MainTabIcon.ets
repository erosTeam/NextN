import { ThemeTokens } from 'shared'

/**
 * Root tab item ported from NextE's V2Next-derived HDS implementation.
 *
 * The small leading spacer is intentional: it corrects SymbolGlyph's visual
 * center inside the fixed icon rail on physical HarmonyOS devices.
 */
const TAB_SYMBOL_LAYOUT_OFFSET_VP: number = 3

@ComponentV2
export struct MainTabIcon {
  @Param title: ResourceStr = ''
  @Param idx: number = 0
  @Param iconIdx: number = -1
  @Param currentIndex: number = 0
  @Event onSelectedClick?: (index: number) => void

  private symbol(): Resource {
    const glyphIndex: number = this.iconIdx >= 0 ? this.iconIdx : this.idx
    if (glyphIndex === 0) {
      return $r('sys.symbol.square_fill_grid_2x2')
    }
    if (glyphIndex === 1) {
      return $r('sys.symbol.heart_fill')
    }
    if (glyphIndex === 2) {
      // NextE uses the ranked-list glyph at index 2. NextN's third root is
      // local reading history, so retain the shared geometry but use the
      // available system clock glyph with the correct semantic meaning.
      return $r('sys.symbol.clock')
    }
    if (glyphIndex === 3) {
      return $r('sys.symbol.arrow_down_to_line_circle_fill')
    }
    return $r('sys.symbol.gearshape_fill')
  }

  build() {
    Column() {
      Row() {
        Blank().width(TAB_SYMBOL_LAYOUT_OFFSET_VP)
        SymbolGlyph(this.symbol())
          .fontSize(ThemeTokens.TAB_INDICATOR_SIZE - 6)
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          .fontColor([
            this.currentIndex === this.idx ? ThemeTokens.BRAND : ThemeTokens.TEXT_SECONDARY,
          ])
      }
      .width(ThemeTokens.TAB_INDICATOR_SIZE)
      .height(ThemeTokens.TAB_INDICATOR_SIZE - 2)
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      Text(this.title)
        .fontSize(ThemeTokens.FONT_SIZE_TINY)
        .fontColor(this.currentIndex === this.idx ? ThemeTokens.BRAND : ThemeTokens.TEXT_SECONDARY)
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ top: ThemeTokens.SPACE_SM - 2, bottom: ThemeTokens.SPACE_XS })
    .onClick((): void => {
      if (this.currentIndex === this.idx && this.onSelectedClick) {
        this.onSelectedClick(this.idx)
      }
    })
  }
}
