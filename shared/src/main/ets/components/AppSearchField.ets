import { uiMaterial } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'
import { ThemeTokens } from '../theme/ThemeTokens'
import { connectThemeDisplay, ThemeDisplayState } from '../state/AppearanceState'

let appSearchFieldSequence: number = 0

/**
 * Shared title-bar search control. The owner keeps the route-local query while
 * this component retains its own displayed value, so HDS bottomBuilder updates
 * never remount an actively edited field or dismiss the IME.
 *
 * API-26 devices receive the native interactive ultra-thin material. The
 * high-version calls stay lexically inside direct apiAvailable() positive
 * branches: the API-23 compatibility checker recognizes that shape, while
 * older devices retain the same geometry with a semantic solid surface.
 */
@ComponentV2
export struct AppSearchField {
  @Param text: string = ''
  @Param placeholder: ResourceStr = ''
  @Param autoFocus: boolean = false
  @Param searchButtonText: string = ''
  @Param useSystemMaterial: boolean = false
  /** Optional leaf correction for title-bar hosts; ordinary page fields keep zero. */
  @Param verticalOffset: number = 0
  @Local fieldText: string = ''
  @Local private themeDisplay: ThemeDisplayState = connectThemeDisplay()
  @Event onTextChange?: (value: string) => void
  @Event onSubmit?: (value: string) => void
  // A cached HDS ComponentContent can coexist with another Search page. Keep a
  // per-instance ID so focus always targets this page's mounted native field.
  private fieldId: string = `nextn-app-search-field-${appSearchFieldSequence++}`

  aboutToAppear(): void {
    this.fieldText = this.text
    if (this.autoFocus) {
      this.requestSearchFocus()
    }
  }

  @Monitor('autoFocus')
  onAutoFocusChanged(): void {
    if (this.autoFocus) {
      this.requestSearchFocus()
    }
  }

  @Monitor('text')
  onExternalTextChanged(): void {
    if (this.text !== this.fieldText) {
      this.fieldText = this.text
    }
  }

  build() {
    if (this.useSystemMaterial) {
      // Keep the compatibility gate as a direct if condition. Combining this
      // with useSystemMaterial in one && expression prevents the ArkTS SDK
      // checker from proving the API-26 calls are guarded.
      if (deviceInfo.apiAvailable('26.0.0')) {
        Search({ value: this.fieldText, placeholder: this.placeholder })
          .id(this.fieldId)
          .width('100%')
          .height(ThemeTokens.SEARCH_FIELD_HEIGHT)
          .translate({ y: this.verticalOffset })
          .backgroundColor(Color.Transparent)
          .systemMaterial(this.searchSystemMaterial())
          .searchButton(this.searchButtonText, { fontColor: ThemeTokens.BRAND })
          .onChange((value: string): void => {
            this.handleTextChange(value)
          })
          .onSubmit((value: string): void => {
            this.handleSubmit(value)
          })
      } else {
        this.PlainSearchField()
      }
    } else {
      this.PlainSearchField()
    }
  }

  @Builder
  private PlainSearchField() {
    Search({ value: this.fieldText, placeholder: this.placeholder })
      .id(this.fieldId)
      .width('100%')
      .height(ThemeTokens.SEARCH_FIELD_HEIGHT)
      .translate({ y: this.verticalOffset })
      .backgroundColor(this.themeTracked(ThemeTokens.CARD_BACKGROUND))
      .searchButton(this.searchButtonText, { fontColor: ThemeTokens.BRAND })
      .onChange((value: string): void => {
        this.handleTextChange(value)
      })
      .onSubmit((value: string): void => {
        this.handleSubmit(value)
      })
  }

  private searchSystemMaterial() {
    // The construction itself must also live in a direct positive gate. The
    // caller is guarded as well, but ArkTS compatibility analysis is lexical.
    if (deviceInfo.apiAvailable('26.0.0')) {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
        colorInvert: true,
        applyShadow: true,
        interactive: true,
      })
    }
    return undefined
  }

  // Reading the effective mode registers a dependency for cached title fields;
  // the semantic resource itself supplies the light/dark color value.
  private themeTracked(color: ResourceColor): ResourceColor {
    return this.themeDisplay.effectiveDark ? color : color
  }

  private handleTextChange(value: string): void {
    this.fieldText = value
    if (this.onTextChange) {
      this.onTextChange(value)
    }
  }

  private handleSubmit(value: string): void {
    if (this.onSubmit) {
      this.onSubmit(value)
    }
  }

  private requestSearchFocus(): void {
    // HDS bottomBuilder content is mounted asynchronously. Request focus in
    // the next turn after its stable field ID has joined the component tree.
    setTimeout((): void => {
      this.getUIContext().getFocusController().requestFocus(this.fieldId)
    }, 80)
  }
}
