import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'

@ComponentV2
export struct PageLoadingState {
  @Param text: string = AppStrings.get('common_loading')

  build() {
    Column() {
      LoadingProgress()
        .width(ThemeTokens.STATE_INDICATOR_SIZE)
        .height(ThemeTokens.STATE_INDICATOR_SIZE)
        .color(ThemeTokens.BRAND)
        .accessibilityText(this.text)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(ThemeTokens.SPACE_XL)
  }
}

@ComponentV2
export struct PageErrorState {
  @Param message: string = AppStrings.get('common_unable_to_load_page')
  @Event onRetry?: () => void

  build() {
    Column({ space: ThemeTokens.SPACE_LG }) {
      Text(this.message)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
        .textAlign(TextAlign.Center)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Button(AppStrings.get('common_retry'), { type: ButtonType.Capsule })
        .height(ThemeTokens.ACTION_HEIGHT)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_ON_BRAND)
        .backgroundColor(ThemeTokens.BRAND)
        .onClick((): void => {
          if (this.onRetry) {
            this.onRetry()
          }
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(ThemeTokens.SPACE_XL)
  }
}

@ComponentV2
export struct PageEmptyState {
  @Param message: string = AppStrings.get('common_nothing_to_show')

  build() {
    Column() {
      Text(this.message)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
    }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding(ThemeTokens.SPACE_XL)
  }
}
