import { SymbolGlyphModifier } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { ReaderDisplaySettings, ReaderFilterBlendMode, normalizeReaderDisplaySettings } from '../model/ReaderDisplaySettings'
import { connectReaderDisplay, ReaderDisplayState } from '../state/ReaderDisplayState'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeTokens } from '../theme/ThemeTokens'
import { NextNListRow } from './NextNListRow'
import { NextNGroupedListSection } from './NextNGroupedListSection'

@ComponentV2
export struct ReaderDisplaySettingsContent {
  @Local private display: ReaderDisplayState = connectReaderDisplay()

  private change(edit: (settings: ReaderDisplaySettings) => void, commit: boolean = true): void {
    const next = normalizeReaderDisplaySettings(this.display.effective())
    edit(next)
    this.display.preview = normalizeReaderDisplaySettings(next)
    if (commit) {
      this.display.save(this.getUIContext().getHostContext() as common.UIAbilityContext, next)
      this.display.preview = null
    }
  }

  private setSlider(field: string, value: number, mode: SliderChangeMode): void {
    this.change((next: ReaderDisplaySettings): void => {
      if (field === 'brightness') next.brightness = value
      else if (field === 'red') next.red = value
      else if (field === 'green') next.green = value
      else if (field === 'blue') next.blue = value
      else next.alpha = value
    }, mode === SliderChangeMode.End || mode === SliderChangeMode.Click)
  }

  @Builder
  private BlendMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(['default', 'multiply', 'screen', 'overlay', 'lighten', 'darken'], (mode: string) => {
        MenuItem({ content: AppStrings.get('reader_display_blend_' + mode),
          symbolEndIcon: this.display.effective().blendMode === mode ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick((): void => { select((): void => { this.change((next): void => { next.blendMode = mode as ReaderFilterBlendMode }) }) })
      })
    }
  }

  @Builder
  private Controls() {
    Column({ space: ThemeTokens.SPACE_SM }) {
      NextNGroupedListSection() {
        NextNListRow({ title: AppStrings.get('reader_display_brightness_enabled'), hasSwitch: true,
          checked: this.display.effective().brightnessEnabled, showChevron: false,
          onSwitchChange: (value: boolean): void => { this.change((next): void => { next.brightnessEnabled = value }) } })
        if (this.display.effective().brightnessEnabled) ReaderDisplayValueSlider({ field: 'brightness', value: this.display.effective().brightness, min: -75, max: 100,
            onChange: (value: number, mode: SliderChangeMode): void => { this.setSlider('brightness', value, mode) } })
      }
      NextNGroupedListSection() {
        NextNListRow({ title: AppStrings.get('reader_display_filter_enabled'), hasSwitch: true,
          checked: this.display.effective().filterEnabled, showChevron: false,
          onSwitchChange: (value: boolean): void => { this.change((next): void => { next.filterEnabled = value }) } })
        if (this.display.effective().filterEnabled) {
          ReaderDisplayValueSlider({ field: 'red', value: this.display.effective().red, min: 0, max: 255,
            onChange: (value: number, mode: SliderChangeMode): void => { this.setSlider('red', value, mode) } })
          ReaderDisplayValueSlider({ field: 'green', value: this.display.effective().green, min: 0, max: 255,
            onChange: (value: number, mode: SliderChangeMode): void => { this.setSlider('green', value, mode) } })
          ReaderDisplayValueSlider({ field: 'blue', value: this.display.effective().blue, min: 0, max: 255,
            onChange: (value: number, mode: SliderChangeMode): void => { this.setSlider('blue', value, mode) } })
          ReaderDisplayValueSlider({ field: 'alpha', value: this.display.effective().alpha, min: 0, max: 255,
            onChange: (value: number, mode: SliderChangeMode): void => { this.setSlider('alpha', value, mode) } })
          NextNListRow({ title: AppStrings.get('reader_display_blend'),
            trailingText: AppStrings.get('reader_display_blend_' + this.display.effective().blendMode),
            trailingDropdown: true, dropdownMenuEnabled: true,
            dropdownMenuBuilder: (select: (action: () => void) => void) => { this.BlendMenu(select) } })
        }
      }
      NextNGroupedListSection() {
        NextNListRow({ title: AppStrings.get('reader_display_grayscale'), hasSwitch: true,
          checked: this.display.effective().grayscale, showChevron: false,
          onSwitchChange: (value: boolean): void => { this.change((next): void => { next.grayscale = value }) } })
        Divider().color($r('sys.color.comp_divider'))
        NextNListRow({ title: AppStrings.get('reader_display_inverted'), hasSwitch: true,
          checked: this.display.effective().inverted, showChevron: false,
          onSwitchChange: (value: boolean): void => { this.change((next): void => { next.inverted = value }) } })
      }
    }.width('100%')
  }

  build() {
    this.Controls()
  }
}

/** Primitive @Param values keep the displayed value in sync with native slider previews. */
@ComponentV2
struct ReaderDisplayValueSlider {
  @Require @Param field: string
  @Require @Param value: number
  @Param min: number = 0
  @Param max: number = 255
  @Event onChange: (value: number, mode: SliderChangeMode) => void = () => {}

  build() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Row() {
        Text(AppStrings.get('reader_display_' + this.field)).fontColor(ThemeTokens.TEXT_PRIMARY)
        Blank()
        Text(`${this.value}`).fontColor(ThemeTokens.TEXT_SECONDARY)
      }.width('100%')
      Slider({ value: this.value, min: this.min, max: this.max, step: 1, style: SliderStyle.InSet }).width('100%')
        .trackColor($r('app.color.reader_filter_slider_track'))
        .selectedColor(ThemeTokens.BRAND)
        .onChange((value: number, mode: SliderChangeMode): void => { this.onChange(value, mode) })
    }.padding({ left: ThemeTokens.SPACE_LG, right: ThemeTokens.SPACE_LG, top: ThemeTokens.SPACE_SM })
  }
}
