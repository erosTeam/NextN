import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode } from '@kit.UIDesignKit'
import { ThemeTokens } from '../theme/ThemeTokens'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'

/**
 * NextE AppModalScaffold port for NextN sheets. The HDS navigation binds to
 * the actual List scroller; callers supply ListItem children rather than
 * nesting another generic Scroll host under an HDS title bar.
 */
@ComponentV2
export struct NextNModalScaffold {
  @BuilderParam content: () => void
  @Param title: ResourceStr = ''
  @Param enableComponentSafeArea: boolean = true
  /** Kept opt-in so existing modal surfaces retain their established host colour. */
  @Param contentBackgroundColor: ResourceColor = ThemeTokens.SURFACE
  @Param contentHorizontalPadding: number = ThemeTokens.SPACE_MD
  @Param footerReserveHeight: number = 0
  @Param scroller: Scroller = new Scroller()
  @Param confirmLoading: boolean = false
  // Keep save/remove controls in the HDS modal title cluster, exactly as the
  // established NextE AppModalScaffold does.  Individual sheets therefore do
  // not invent full-width Material-style action buttons inside their content.
  @Param showConfirmAction: boolean = false
  @Param confirmIcon: Resource = $r('sys.symbol.checkmark')
  @Param confirmText: ResourceStr = ''
  @Param confirmEnabled: boolean = true
  @Param showSecondaryAction: boolean = false
  @Param secondaryIcon: Resource = $r('sys.symbol.trash')
  @Param secondaryText: ResourceStr = ''
  @Param secondaryEnabled: boolean = true
  @Event onClose?: () => void
  @Event onConfirm?: () => void
  @Event onSecondary?: () => void
  layout: LayoutSafeAreaState = connectLayoutSafeArea()

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      HdsNavigation() {
        List({ space: ThemeTokens.SPACE_SM, scroller: this.scroller }) {
          this.content()

          ListItem() {
            Column() {
              Blank()
                .height(this.layout.bottomAvoidHeight + ThemeTokens.SPACE_MD + this.footerReserveHeight)
            }
            .width('100%')
          }
          .width('100%')
        }
        .height('100%')
        .width('100%')
        .padding({ left: this.contentHorizontalPadding, right: this.contentHorizontalPadding })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .nestedScroll({
          scrollForward: NestedScrollMode.SELF_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST,
        })
      }
      .titleBar({
        enableComponentSafeArea: this.enableComponentSafeArea,
        content: {
          title: {
            mainTitle: this.title,
          },
          subIcon: {
            content: {
              label: 'modal_close',
              icon: $r('sys.symbol.xmark'),
              isEnabled: !this.confirmLoading,
              type: IconStyleMode.SMALL,
              action: (): void => {
                if (this.onClose) {
                  this.onClose()
                }
              },
            },
          },
          menu: {
            value: this.menuItems(),
            maxCount: this.menuItems().length,
          },
        },
      })
      .titleMode(HdsNavigationTitleMode.MODAL)
      .bindToScrollable([this.scroller])
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.contentBackgroundColor)
  }

  private menuItems(): Record<string, Object>[] {
    const items: Record<string, Object>[] = []
    if (this.showSecondaryAction) {
      const secondaryAction: Record<string, Object> = {
        'label': this.secondaryText,
        'icon': this.secondaryIcon,
        'isEnabled': this.secondaryEnabled && !this.confirmLoading,
        'type': IconStyleMode.SMALL,
        'action': (): void => {
          if (this.onSecondary) {
            this.onSecondary()
          }
        },
      }
      const secondaryItem: Record<string, Object> = { 'content': secondaryAction }
      items.push(secondaryItem)
    }
    if (this.showConfirmAction) {
      const confirmAction: Record<string, Object> = {
        'label': this.confirmText,
        'icon': this.confirmIcon,
        'isEnabled': this.confirmEnabled && !this.confirmLoading,
        'type': IconStyleMode.SMALL,
        'action': (): void => {
          if (this.onConfirm) {
            this.onConfirm()
          }
        },
      }
      const confirmItem: Record<string, Object> = { 'content': confirmAction }
      items.push(confirmItem)
    }
    return items
  }
}
