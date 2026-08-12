import { common } from '@kit.AbilityKit'
import { LengthMetrics, SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI'
import { AppStrings } from '../i18n/AppStrings'
import { AppColorFavoritesSettings } from '../settings/AppColorFavoritesSettings'
import { AppColorFavoritesState, connectAppColorFavorites } from '../state/AppColorFavoritesState'
import { connectThemeDisplay, ThemeDisplayState } from '../state/AppearanceState'
import { SegmentButtonTheme } from '../theme/SegmentButtonTheme'
import { ThemeTokens } from '../theme/ThemeTokens'

const COLOR_PICKER_MODE_GRID: number = 0
const COLOR_PICKER_MODE_SLIDERS: number = 1
const COLOR_PICKER_GRID_HUES: number[] = [190, 210, 235, 270, 315, 355, 25, 38, 50, 75, 125, 180]
const COLOR_PICKER_GRID_ROWS: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
const COLOR_FAVORITE_SLOTS: number[] = [
  0, 1, 2, 3, 4, 5, 6, 7, 8,
  9, 10, 11, 12, 13, 14, 15, 16, 17,
  18, 19, 20, 21, 22, 23, 24, 25, 26,
  27, 28, 29, 30, 31, 32, 33, 34, 35,
]

/**
 * Shared NextE-derived custom-color picker. It owns draft selection and
 * favorites only; the embedding Settings sheet owns preview, confirm and
 * rollback of the active accent.
 */
@ComponentV2
export struct AppColorPicker {
  @Param title: string = ''
  @Param color: string = ''
  @Param disabled: boolean = false
  @Event colorChange?: (color: string) => void
  @Local private mode: number = COLOR_PICKER_MODE_GRID
  @Local private modeItems: SegmentButtonV2Items = new SegmentButtonV2Items([{ text: '' }, { text: '' }])
  @Local private draftHue: number = 210
  @Local private draftSaturation: number = 80
  @Local private draftBrightness: number = 100
  @Local private draftHex: string = '#3377FF'
  @Local private lastEmittedColor: string = ''
  @Local private shrinkingFavoriteIndex: number = -1
  @Local private colorFavorites: AppColorFavoritesState = connectAppColorFavorites()
  @Local private themeDisplay: ThemeDisplayState = connectThemeDisplay()

  aboutToAppear(): void {
    this.syncModeLabels()
    this.syncDraftFromExternalColor()
  }

  @Monitor('color')
  private onExternalColorChange(): void {
    const incoming: string = this.normalizedColorFor(this.color)
    if (incoming.length > 0 && incoming.toUpperCase() === this.lastEmittedColor.toUpperCase()) {
      return
    }
    if (incoming.length > 0 && incoming.toUpperCase() === this.draftColor().toUpperCase()) {
      return
    }
    this.syncDraftFromExternalColor()
  }

  build() {
    Column({ space: ThemeTokens.SPACE_MD }) {
      Row({ space: ThemeTokens.SPACE_MD }) {
        Text(this.title)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .layoutWeight(1)
        Column()
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor(this.draftColor())
          .borderWidth(1)
          .borderColor(ThemeTokens.DIVIDER)
      }
      .width('100%')

      TabSegmentButtonV2({
        items: this.modeItems,
        selectedIndex: this.mode,
        enableStateAnimation: true,
        buttonBackgroundColor: SegmentButtonTheme.tabButtonBackground(this.themeDisplay.effectiveDark),
        itemSelectedBackgroundColor: SegmentButtonTheme.tabSelectedItemBackground(this.themeDisplay.effectiveDark),
        itemFontColor: SegmentButtonTheme.itemFont(this.themeDisplay.effectiveDark),
        itemSelectedFontColor: SegmentButtonTheme.tabSelectedItemFont(this.themeDisplay.effectiveDark),
        onItemClicked: (index: number): void => {
          this.mode = index
        },
        itemPadding: {
          top: LengthMetrics.vp(6),
          bottom: LengthMetrics.vp(6),
          start: LengthMetrics.vp(8),
          end: LengthMetrics.vp(8),
        },
      })
        .width('100%')

      if (this.mode === COLOR_PICKER_MODE_GRID) {
        this.ColorGrid()
      } else {
        this.HsbSliders()
      }

      Row({ space: ThemeTokens.SPACE_SM }) {
        Text(AppStrings.get('color_picker_hex'))
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
        TextInput({ text: this.draftHex, placeholder: '#3377FF' })
          .layoutWeight(1)
          .height(44)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
          .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
          .enabled(!this.disabled)
          .onChange((value: string): void => {
            this.handleHexInput(value)
          })
      }
      .width('100%')

      this.ColorFavorites()
    }
    .width('100%')
    .padding(ThemeTokens.SPACE_MD)
    .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
  }

  @Builder
  private ColorGrid() {
    Grid() {
      ForEach(
        COLOR_PICKER_GRID_ROWS,
        (row: number): void => {
          GridItem() {
            this.ColorCell(this.grayForGridRow(row))
          }
          ForEach(
            COLOR_PICKER_GRID_HUES,
            (hue: number): void => {
              GridItem() {
                this.ColorCell(this.hsbToHex(hue, this.saturationForGridRow(row), this.brightnessForGridRow(row)))
              }
            },
            (hue: number): string => `color_${row}_${hue}`,
          )
        },
        (row: number): string => `${row}`,
      )
    }
    .columnsTemplate('repeat(13, 1fr)')
    .rowsTemplate('repeat(10, 1fr)')
    .rowsGap(0)
    .columnsGap(0)
    .width('100%')
    .aspectRatio(13 / 10)
    .clip(true)
  }

  @Builder
  private ColorCell(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('102%')
        .height('102%')
        .backgroundColor(color)
      if (this.isCurrentColor(color)) {
        Column()
          .width(24)
          .height(24)
          .borderRadius(6)
          .borderWidth(3)
          .borderColor(Color.White)
          .backgroundColor(Color.Transparent)
      }
    }
    .width('100%')
    .height('100%')
    .enabled(!this.disabled)
    .onClick((): void => {
      if (!this.disabled) {
        this.selectColor(color)
      }
    })
  }

  @Builder
  private ColorFavorites() {
    Column({ space: ThemeTokens.SPACE_SM }) {
      Text(AppStrings.get('color_picker_favorites'))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .width('100%')
      Grid() {
        ForEach(
          COLOR_FAVORITE_SLOTS,
          (index: number): void => {
            GridItem() {
              this.FavoriteCell(index)
            }
          },
          (index: number): string => `${index}`,
        )
      }
      .columnsTemplate('repeat(9, 1fr)')
      .rowsTemplate('repeat(4, 1fr)')
      .rowsGap(8)
      .columnsGap(8)
      .width('100%')
      .aspectRatio(9 / 4)
    }
    .width('100%')
  }

  @Builder
  private FavoriteCell(index: number) {
    Stack({ alignContent: Alignment.Center }) {
      if (index < this.colorFavorites.colors.length) {
        Column() {
          Column()
            .width('100%')
            .aspectRatio(1)
            .borderRadius(this.favoriteColorBlockRadius(index))
            .backgroundColor(this.colorFavorites.colors[index])
            .borderWidth(this.favoriteColorBorderWidth(index))
            .borderColor(ThemeTokens.DIVIDER)
        }
        .width('100%')
        .aspectRatio(1)
        .borderRadius(8)
        .backgroundColor(ThemeTokens.CARD_BACKGROUND)
        .padding(this.favoriteSelectionGap(index))
        .borderWidth(this.favoriteSelectionBorderWidth(index))
        .borderColor(ThemeTokens.BRAND)
      } else if (index === this.colorFavorites.colors.length) {
        Column()
          .width('100%')
          .aspectRatio(1)
          .backgroundColor(ThemeTokens.CARD_BACKGROUND)
          .borderRadius(8)
          .borderWidth(1)
          .borderColor(ThemeTokens.DIVIDER)
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(20)
          .fontColor([ThemeTokens.TEXT_SECONDARY])
      } else {
        Column()
          .width('100%')
          .aspectRatio(1)
          .borderRadius(8)
          .backgroundColor(ThemeTokens.CARD_BACKGROUND)
          .borderWidth(1)
          .borderColor(ThemeTokens.DIVIDER)
      }
    }
    .width('100%')
    .height('100%')
    .enabled(!this.disabled)
    .onClick((): void => {
      if (this.disabled) {
        return
      }
      if (index < this.colorFavorites.colors.length) {
        this.selectFavoriteColor(index)
      } else if (index === this.colorFavorites.colors.length) {
        this.addFavoriteColor()
      }
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction((): void => {
          if (!this.disabled && index < this.colorFavorites.colors.length) {
            this.removeFavoriteColor(index)
          }
        }),
    )
  }

  @Builder
  private HsbSliders() {
    Column({ space: ThemeTokens.SPACE_MD }) {
      this.HueSlider()
      this.SaturationSlider()
      this.BrightnessSlider()
    }
    .width('100%')
  }

  @Builder
  private HueSlider() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      this.SliderHeader(AppStrings.get('color_picker_hue'), Math.round(this.draftHue).toString())
      Slider({ value: this.draftHue, min: 0, max: 360, step: 1, style: SliderStyle.InSet })
        .width('100%')
        .enabled(!this.disabled)
        .trackColor(this.hueGradient())
        .selectedColor(Color.Transparent)
        .onChange((value: number, _mode: SliderChangeMode): void => {
          this.draftHue = value
          this.commitDraftColor()
        })
    }
    .width('100%')
  }

  @Builder
  private SaturationSlider() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      this.SliderHeader(AppStrings.get('color_picker_saturation'), Math.round(this.draftSaturation).toString())
      Slider({ value: this.draftSaturation, min: 0, max: 100, step: 1, style: SliderStyle.InSet })
        .width('100%')
        .enabled(!this.disabled)
        .trackColor(this.saturationGradient())
        .selectedColor(Color.Transparent)
        .onChange((value: number, _mode: SliderChangeMode): void => {
          this.draftSaturation = value
          this.commitDraftColor()
        })
    }
    .width('100%')
  }

  @Builder
  private BrightnessSlider() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      this.SliderHeader(AppStrings.get('color_picker_brightness'), Math.round(this.draftBrightness).toString())
      Slider({ value: this.draftBrightness, min: 0, max: 100, step: 1, style: SliderStyle.InSet })
        .width('100%')
        .enabled(!this.disabled)
        .trackColor(this.brightnessGradient())
        .selectedColor(Color.Transparent)
        .onChange((value: number, _mode: SliderChangeMode): void => {
          this.draftBrightness = value
          this.commitDraftColor()
        })
    }
    .width('100%')
  }

  @Builder
  private SliderHeader(label: string, value: string) {
    Row({ space: ThemeTokens.SPACE_SM }) {
      Text(label)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
        .layoutWeight(1)
      Text(value)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .width(44)
        .textAlign(TextAlign.End)
    }
    .width('100%')
  }

  private syncModeLabels(): void {
    this.modeItems[0].text = AppStrings.get('color_picker_grid')
    this.modeItems[1].text = AppStrings.get('color_picker_sliders')
  }

  private emitColor(color: string): void {
    this.lastEmittedColor = this.normalizedColorFor(color)
    if (this.colorChange) {
      this.colorChange(color)
    }
  }

  private commitDraftColor(): void {
    const color: string = this.draftColor()
    this.draftHex = color
    this.emitColor(color)
  }

  private selectColor(color: string): void {
    const normalized: string = this.normalizedColorFor(color)
    if (normalized.length > 0) {
      this.syncDraftFromHex(normalized)
      this.draftHex = normalized
      this.emitColor(normalized)
    }
  }

  private selectFavoriteColor(index: number): void {
    const color: string = this.colorFavorites.colors[index]
    if (this.isCurrentColor(color)) {
      return
    }
    this.getUIContext().animateTo({ duration: 120, curve: Curve.EaseOut }, (): void => {
      this.shrinkingFavoriteIndex = index
    })
    setTimeout((): void => {
      if (this.shrinkingFavoriteIndex === index) {
        this.getUIContext().animateTo({ duration: 160, curve: Curve.EaseOut }, (): void => {
          this.shrinkingFavoriteIndex = -1
          this.selectColor(color)
        })
      }
    }, 130)
  }

  private favoriteSelectionBorderWidth(index: number): number {
    return this.isCurrentColor(this.colorFavorites.colors[index]) ? 3 : 0
  }

  private favoriteSelectionGap(index: number): number {
    return this.isCurrentColor(this.colorFavorites.colors[index]) || this.shrinkingFavoriteIndex === index ? 3 : 0
  }

  private favoriteColorBlockRadius(index: number): number {
    return this.isCurrentColor(this.colorFavorites.colors[index]) || this.shrinkingFavoriteIndex === index ? 4 : 8
  }

  private favoriteColorBorderWidth(index: number): number {
    return this.isCurrentColor(this.colorFavorites.colors[index]) || this.shrinkingFavoriteIndex === index ? 0 : 1
  }

  private addFavoriteColor(): void {
    const color: string = this.draftColor()
    const next: string[] = []
    let exists: boolean = false
    this.colorFavorites.colors.forEach((candidate: string): void => {
      if (candidate.toUpperCase() === color.toUpperCase()) {
        exists = true
      }
      if (next.length < COLOR_FAVORITE_SLOTS.length) {
        next.push(candidate)
      }
    })
    if (!exists && next.length < COLOR_FAVORITE_SLOTS.length) {
      next.push(color)
    }
    this.colorFavorites.colors = next
    AppColorFavoritesSettings.persist(this.context(), next)
  }

  private removeFavoriteColor(index: number): void {
    const next: string[] = []
    this.colorFavorites.colors.forEach((candidate: string, candidateIndex: number): void => {
      if (candidateIndex !== index && next.length < COLOR_FAVORITE_SLOTS.length) {
        next.push(candidate)
      }
    })
    this.colorFavorites.colors = next
    AppColorFavoritesSettings.persist(this.context(), next)
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private handleHexInput(value: string): void {
    if (value === this.draftHex) {
      return
    }
    this.draftHex = value
    const normalized: string = this.normalizedStrictHexFor(value)
    if (normalized.length === 0) {
      return
    }
    this.syncDraftFromHex(normalized)
    this.draftHex = normalized
    this.emitColor(normalized)
  }

  private normalizedColorFor(color: string): string {
    const value: string = color.trim()
    if (value.length === 0) {
      return ''
    }
    const normalized: string = value.startsWith('#') ? value : `#${value}`
    const digits: string = this.hexDigitsFor(normalized)
    return digits.length === 6 ? `#${digits}` : ''
  }

  private normalizedStrictHexFor(color: string): string {
    let value: string = color.trim()
    if (value.startsWith('#')) {
      value = value.substring(1)
    }
    return value.length === 6 && this.isHex(value) ? `#${value.toUpperCase()}` : ''
  }

  private isCurrentColor(color: string): boolean {
    const current: string = this.normalizedColorFor(this.draftHex)
    const target: string = this.normalizedColorFor(color)
    return current.length > 0 && target.length > 0
      ? current.toUpperCase() === target.toUpperCase()
      : this.draftColor().toUpperCase() === target.toUpperCase()
  }

  private hexDigitsFor(color: string): string {
    let value: string = color.trim()
    if (value.startsWith('#')) {
      value = value.substring(1)
    }
    if (value.length === 3) {
      value = `${value.substring(0, 1)}${value.substring(0, 1)}${value.substring(1, 2)}${value.substring(1, 2)}${value.substring(2, 3)}${value.substring(2, 3)}`
    }
    return value.length === 6 && this.isHex(value) ? value.toUpperCase() : ''
  }

  private isHex(value: string): boolean {
    for (let index: number = 0; index < value.length; index += 1) {
      const code: number = value.charCodeAt(index)
      if (!((code >= 48 && code <= 57) || (code >= 65 && code <= 70) || (code >= 97 && code <= 102))) {
        return false
      }
    }
    return true
  }

  private saturationForGridRow(row: number): number {
    if (row <= 0) { return 15 }
    if (row === 1) { return 25 }
    if (row === 2) { return 42 }
    if (row === 3) { return 60 }
    if (row === 4) { return 80 }
    return 100
  }

  private brightnessForGridRow(row: number): number {
    if (row <= 5) { return 100 }
    if (row === 6) { return 90 }
    if (row === 7) { return 78 }
    if (row === 8) { return 66 }
    return 54
  }

  private grayForGridRow(row: number): string {
    const values: number[] = [95, 90, 85, 80, 70, 60, 50, 30, 20, 10]
    const value: number = Math.round(values[row] / 100 * 255)
    return `#${this.byteToHex(value)}${this.byteToHex(value)}${this.byteToHex(value)}`
  }

  private hueGradient(): LinearGradient {
    return new LinearGradient([
      { color: this.hsbToHex(0, 100, 100), offset: 0 },
      { color: this.hsbToHex(60, 100, 100), offset: 0.17 },
      { color: this.hsbToHex(120, 100, 100), offset: 0.33 },
      { color: this.hsbToHex(180, 100, 100), offset: 0.5 },
      { color: this.hsbToHex(240, 100, 100), offset: 0.67 },
      { color: this.hsbToHex(300, 100, 100), offset: 0.83 },
      { color: this.hsbToHex(360, 100, 100), offset: 1 },
    ])
  }

  private saturationGradient(): LinearGradient {
    return new LinearGradient([
      { color: this.hsbToHex(this.draftHue, 0, this.draftBrightness), offset: 0 },
      { color: this.hsbToHex(this.draftHue, 100, this.draftBrightness), offset: 1 },
    ])
  }

  private brightnessGradient(): LinearGradient {
    return new LinearGradient([
      { color: this.hsbToHex(this.draftHue, this.draftSaturation, 0), offset: 0 },
      { color: this.hsbToHex(this.draftHue, this.draftSaturation, 100), offset: 1 },
    ])
  }

  private syncDraftFromExternalColor(): void {
    const normalized: string = this.normalizedColorFor(this.color)
    if (normalized.length > 0) {
      this.syncDraftFromHex(normalized)
      this.draftHex = normalized
    }
  }

  private syncDraftFromHex(color: string): void {
    const digits: string = this.hexDigitsFor(color)
    if (digits.length !== 6) {
      return
    }
    const red: number = Number.parseInt(digits.substring(0, 2), 16) / 255
    const green: number = Number.parseInt(digits.substring(2, 4), 16) / 255
    const blue: number = Number.parseInt(digits.substring(4, 6), 16) / 255
    const max: number = Math.max(red, Math.max(green, blue))
    const min: number = Math.min(red, Math.min(green, blue))
    const delta: number = max - min
    if (delta > 0) {
      let hue: number = 0
      if (max === red) {
        hue = 60 * ((green - blue) / delta)
      } else if (max === green) {
        hue = 60 * (((blue - red) / delta) + 2)
      } else {
        hue = 60 * (((red - green) / delta) + 4)
      }
      this.draftHue = hue < 0 ? hue + 360 : hue
      this.draftSaturation = ((max - min) / max) * 100
    } else {
      this.draftSaturation = 0
    }
    this.draftBrightness = max * 100
  }

  private draftColor(): string {
    return this.hsbToHex(this.draftHue, this.draftSaturation, this.draftBrightness)
  }

  private hsbToHex(hue: number, saturation: number, brightness: number): string {
    const h: number = ((hue % 360) + 360) % 360
    const s: number = Math.max(0, Math.min(100, saturation)) / 100
    const value: number = Math.max(0, Math.min(100, brightness)) / 100
    const chroma: number = value * s
    const x: number = chroma * (1 - Math.abs(((h / 60) % 2) - 1))
    const m: number = value - chroma
    let red: number = 0
    let green: number = 0
    let blue: number = 0
    if (h < 60) { red = chroma; green = x }
    else if (h < 120) { red = x; green = chroma }
    else if (h < 180) { green = chroma; blue = x }
    else if (h < 240) { green = x; blue = chroma }
    else if (h < 300) { red = x; blue = chroma }
    else { red = chroma; blue = x }
    return `#${this.byteToHex((red + m) * 255)}${this.byteToHex((green + m) * 255)}${this.byteToHex((blue + m) * 255)}`
  }

  private byteToHex(value: number): string {
    const digits: string = '0123456789ABCDEF'
    const normalized: number = Math.max(0, Math.min(255, Math.round(value)))
    const hi: number = Math.floor(normalized / 16)
    const lo: number = normalized - hi * 16
    return `${digits.substring(hi, hi + 1)}${digits.substring(lo, lo + 1)}`
  }
}
