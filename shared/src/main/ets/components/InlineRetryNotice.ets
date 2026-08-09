import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'

/** Compact non-blocking failure state for a list that still has usable rows. */
@ComponentV2
export struct InlineRetryNotice {
  @Param message: string = ''
  @Param actionLabel: string = ''
  @Event onRetry?: () => void

  private resolvedActionLabel(): string {
    return this.actionLabel.length > 0 ? this.actionLabel : AppStrings.get('common_retry')
  }

  build() {
    Row({ space: ThemeTokens.SPACE_SM }) {
      Text(this.message)
        .layoutWeight(1)
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      // A quiet platform text action keeps a recoverable list failure inline;
      // it should not turn a single retry into a filled Material-style chip.
      Button() {
        Text(this.resolvedActionLabel())
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_LINK)
      }
        .height(ThemeTokens.MIN_TOUCH_TARGET)
        .backgroundColor(Color.Transparent)
        .borderRadius(ThemeTokens.RADIUS_SM)
        .onClick((): void => {
          if (this.onRetry) {
            this.onRetry()
          }
        })
    }
    .width('100%')
    .padding({
      left: ThemeTokens.SPACE_MD,
      right: ThemeTokens.SPACE_SM,
      top: ThemeTokens.SPACE_XS,
      bottom: ThemeTokens.SPACE_XS,
    })
    .alignItems(VerticalAlign.Center)
  }
}
