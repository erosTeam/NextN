import { ThemeTokens } from '../theme/ThemeTokens'
import { AppStrings } from '../i18n/AppStrings'

/** Shared tail feedback for paged read-only lists. */
@ComponentV2
export struct LoadingFooter {
  @Param isLoading: boolean = false
  @Param isError: boolean = false
  @Param canLoadMore: boolean = false
  @Param isComplete: boolean = false
  @Param loadingText: string = AppStrings.get('footer_loading_more')
  @Param errorMessage: string = AppStrings.get('footer_unable_to_load_more')
  @Param availableText: string = AppStrings.get('footer_more_available')
  @Param completeText: string = AppStrings.get('footer_up_to_date')
  @Param idleText: string = ''
  @Param retryLabel: string = AppStrings.get('footer_try_again')
  @Param loadMoreLabel: string = AppStrings.get('footer_load_more')
  @Event onRetry?: () => void
  @Event onLoadMore?: () => void

  build() {
    Row({ space: ThemeTokens.SPACE_SM }) {
      if (this.isLoading) {
        LoadingProgress()
          .width(ThemeTokens.INLINE_PROGRESS_SIZE)
          .height(ThemeTokens.INLINE_PROGRESS_SIZE)
          .color(ThemeTokens.TEXT_SECONDARY)
        Text(this.loadingText)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
      } else if (this.isError) {
        Text(`${this.errorMessage} · ${this.retryLabel}`)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .maxLines(2)
          .textAlign(TextAlign.Center)
      } else if (this.canLoadMore) {
        Text(`${this.availableText} · ${this.loadMoreLabel}`)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
      } else if (this.isComplete) {
        Text(this.completeText)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
      } else if (this.idleText.length > 0) {
        Text(this.idleText)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: ThemeTokens.LIST_FOOTER_MIN_HEIGHT })
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .padding({ top: ThemeTokens.SPACE_LG, bottom: ThemeTokens.SPACE_XL })
    .accessibilityText(
      this.isLoading
        ? this.loadingText
        : this.isError
          ? `${this.errorMessage}, ${this.retryLabel}`
          : this.canLoadMore
            ? `${this.availableText}, ${this.loadMoreLabel}`
            : this.isComplete
              ? this.completeText
              : this.idleText,
    )
    .onClick((): void => {
      if (this.isError && this.onRetry) {
        this.onRetry()
      } else if (this.canLoadMore && this.onLoadMore) {
        this.onLoadMore()
      }
    })
  }
}
