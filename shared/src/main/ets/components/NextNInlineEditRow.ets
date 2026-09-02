import { ThemeTokens } from '../theme/ThemeTokens'
import { NextNListRow } from './NextNListRow'

/** Shared inline editor used by list-based settings and modal option groups. */
@ComponentV2
export struct NextNInlineEditRow {
  @Param title: string = ''
  @Param subtitle: string = ''
  @Param subtitleMaxLines: number = 2
  @Param value: string = ''
  @Param placeholder: string = ''
  @Param numeric: boolean = false
  @Param isEnabled: boolean = true
  @Param suffix: string = ''
  @Event onChange: (value: string) => void = (): void => {}
  @Local private fieldText: string = ''

  aboutToAppear(): void {
    this.fieldText = this.value
  }

  @Monitor('value')
  onExternalValueChanged(): void {
    if (this.value !== this.fieldText) {
      this.fieldText = this.value
    }
  }

  @Builder
  private InputSuffix() {
    Row({ space: ThemeTokens.SPACE_XS }) {
      TextInput({ text: this.fieldText, placeholder: this.placeholder })
        .type(this.numeric ? InputType.Number : InputType.Normal)
        .textAlign(TextAlign.End)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
        .placeholderColor(ThemeTokens.TEXT_TERTIARY)
        .backgroundColor(Color.Transparent)
        .height(40)
        .enabled(this.isEnabled)
        .padding({ top: 0, bottom: 0, left: 0, right: 2 })
        .width(this.numeric ? 120 : 200)
        .onChange((next: string): void => {
          this.fieldText = next
          this.onChange(next)
        })
      if (this.suffix.length > 0) {
        Text(this.suffix)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
      }
    }
    .alignItems(VerticalAlign.Center)
  }

  build() {
    NextNListRow({
      title: this.title,
      subtitle: this.subtitle,
      subtitleMaxLines: this.subtitleMaxLines,
      showChevron: false,
      isEnabled: this.isEnabled,
      useCustomTrailing: true,
      suffixPaddingRight: ThemeTokens.SPACE_MD,
      customTrailing: (): void => {
        this.InputSuffix()
      },
    })
  }
}
