import { HdsNavDestination } from '@kit.UIDesignKit'
import { ThemeTokens } from '../theme/ThemeTokens'
import { SecondaryListScaffold } from './SecondaryListScaffold'

/**
 * The single full-page Web container. Callers provide an embeddable WebView;
 * this scaffold owns immersive chrome, parent scrolling and the loading layer.
 */
@ComponentV2
export struct NextNWebPageScaffold {
  @BuilderParam content: () => void
  @Param titleBarOptions: Record<string, Object> = {}
  @Param hideBackButton: boolean = false
  @Param loading: boolean = false
  @Param loadingSize: number = ThemeTokens.LOADING_SIZE
  private scroller: Scroller = new Scroller()

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        SecondaryListScaffold({
          scroller: this.scroller,
          horizontalPadding: 0,
          bottomPadding: 0,
          listSpace: 0,
        }) {
          ListItem() {
            this.content()
          }
          .height('100%')
          .clip(false)
        }

        if (this.loading) {
          LoadingProgress()
            .width(this.loadingSize)
            .height(this.loadingSize)
            .color(ThemeTokens.BRAND)
        }
      }
      .width('100%')
      .height('100%')
    }
    .titleBar(this.titleBarOptions)
    .hideBackButton(this.hideBackButton)
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
