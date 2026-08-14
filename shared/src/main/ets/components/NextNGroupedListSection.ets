import { ThemeTokens } from '../theme/ThemeTokens'

/**
 * Shared grouped-list surface following NextE's `GroupedListSection` contract.
 *
 * The component deliberately owns only the surface, radius, clip, and small
 * inset. HDS rows continue to own their press states and row geometry, so
 * feature pages do not recreate filled-card treatments around every action.
 */
@ComponentV2
export struct NextNGroupedListSection {
  @BuilderParam content: () => void
  @Param inset: number = ThemeTokens.SPACE_XS
  @Param radius: number = ThemeTokens.RADIUS_CARD
  @Param accessibilityId: string = ''

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(this.radius)
    .clip(true)
    .padding(this.inset)
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
    .id(this.accessibilityId)
  }
}
