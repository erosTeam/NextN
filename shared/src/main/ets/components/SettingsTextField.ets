import { ThemeTokens } from '../theme/ThemeTokens'

/** Standard full-width labeled text field used inside settings cards. */
@ComponentV2
export struct SettingsTextField {
  @Param label: ResourceStr = ''
  @Param value: string = ''
  @Param placeholder: ResourceStr = ''
  @Param inputType: InputType = InputType.Normal
  @Param isEnabled: boolean = true
  @Event onChange: (value: string) => void = (_value: string): void => {}
  @Local private fieldText: string = ''

  aboutToAppear(): void {
    this.fieldText = this.value
  }

  @Monitor('value')
  private onExternalValueChange(): void {
    if (this.value !== this.fieldText) {
      this.fieldText = this.value
    }
  }

  build() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Text(this.label)
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .width('100%')
      TextInput({ text: this.fieldText, placeholder: this.placeholder })
        .type(this.inputType)
        .width('100%')
        .height(48)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
        .enabled(this.isEnabled)
        .onChange((value: string): void => {
          this.fieldText = value
          this.onChange(value)
        })
    }
    .width('100%')
    .padding({
      left: ThemeTokens.SPACE_MD,
      right: ThemeTokens.SPACE_MD,
      top: ThemeTokens.SPACE_SM,
      bottom: ThemeTokens.SPACE_SM,
    })
  }
}
