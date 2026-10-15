import { deviceInfo } from '@kit.BasicServicesKit'
import { uiMaterial } from '@kit.ArkUI'
import { SubTabStyleSettings } from '../settings/SubTabStyleSettings'
import { SubTabStyleState, connectSubTabStyle } from '../state/SubTabStyleState'
import { ImmersiveMaterialSettings } from '../settings/ImmersiveMaterialSettings'
import { ImmersiveMaterialSettingsState, connectImmersiveMaterialSettings } from '../state/ImmersiveMaterialSettingsState'
import { ThemeTokens } from '../theme/ThemeTokens'
import { HOME_SOURCE_SELECTOR_HEIGHT } from '../state/HomeSourceState'
import { TabItem } from '../model/TabItem'
import { currentScrollOffsetX } from '../utils/ScrollUserInput'
import {
  connectLanguageState,
  connectThemeDisplay,
  LanguageState,
  ThemeDisplayState,
} from '../state/AppearanceState'

const PILL_HEIGHT: number = 30
const INDICATOR_WIDTH: number = 18
const TAB_GAP: number = ThemeTokens.SPACE_XS
const BAR_PADDING: number = 0
const INDICATOR_Y: number = HOME_SOURCE_SELECTOR_HEIGHT - 14

/**
 * The compact NextE selector bar. Its underline interpolates actual measured
 * tab centres from RetainedSubtabHost's visual index, while its semantic
 * selection remains separate for centring and click transitions.
 */
@ComponentV2
export struct SubTabBar {
  @Require @Param tabs: TabItem[]
  @Param visualIndex: number = 0
  @Param selectedIndex: number = -1
  @Event onSelect: (index: number) => void = (_index: number): void => {}
  @Local tabWidths: number[] = []
  @Local tabLefts: number[] = []
  @Local scrollOffsetX: number = 0
  @Local themeDisplay: ThemeDisplayState = connectThemeDisplay()
  @Local language: LanguageState = connectLanguageState()
  @Local tabStyle: SubTabStyleState = connectSubTabStyle()
  @Local immersiveMaterial: ImmersiveMaterialSettingsState = connectImmersiveMaterialSettings()
  private scroller: Scroller = new Scroller()
  private containerReady: boolean = false
  private containerGlobalLeft: number = 0
  private pendingCenterIndex: number = -1
  private pendingCenterSmooth: boolean = false
  private centeredTarget: number = -1

  aboutToAppear(): void {
    this.centerSelectedTab(false, true)
  }

  private themeTracked(color: ResourceColor): ResourceColor {
    return this.themeDisplay.effectiveDark ? color : color
  }

  private isCapsule(): boolean {
    return SubTabStyleSettings.isCapsule(this.tabStyle.style)
  }

  private tabGap(): number {
    return this.isCapsule() ? ThemeTokens.SPACE_SM : TAB_GAP
  }

  // Capsule contrast and neutral material treatment are adapted from PR #8 (91772b0e).
  private onFillTextColor(i: number): ResourceColor {
    const color: ResourceColor = this.tabAccentColor(i)
    const hex: string = typeof color === 'string' ? this.normalizedHex(color) : ''
    if (hex.length === 0) {
      return ThemeTokens.TEXT_ON_BRAND
    }
    const r: number = Number.parseInt(hex.substring(1, 3), 16)
    const g: number = Number.parseInt(hex.substring(3, 5), 16)
    const b: number = Number.parseInt(hex.substring(5, 7), 16)
    const luminance: number = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    return luminance > 0.6 ? '#FF000000' : ThemeTokens.TEXT_ON_BRAND
  }

  private selectedTextColor(i: number): ResourceColor {
    return this.isCapsule() ? this.onFillTextColor(i) : this.tabAccentColor(i)
  }

  private inactiveMaterial(): uiMaterial.Material | undefined {
    return ImmersiveMaterialSettings.systemMaterial(
      this.immersiveMaterial.level, uiMaterial.ImmersiveStyle.ULTRA_THIN, false,
    )
  }

  private tabFill(i: number): ResourceColor {
    if (!this.isCapsule()) {
      return Color.Transparent
    }
    if (this.visualSelectedIndex() === i) {
      return this.tabAccentColor(i)
    }
    return deviceInfo.apiAvailable('26.0.0')
      ? Color.Transparent : this.themeTracked($r('sys.color.ohos_id_color_button_normal'))
  }

  private visualSelectedIndex(): number {
    if (this.language.effectiveLocale.length < 0) {
      return 0
    }
    const count: number = this.tabs.length
    if (count <= 0) {
      return 0
    }
    return Math.max(0, Math.min(count - 1, Math.round(this.visualIndex)))
  }

  private tabLeft(index: number): number {
    if (index < this.tabLefts.length && this.tabLefts[index] >= 0) {
      return this.tabLefts[index]
    }
    let left: number = this.isCapsule() ? ThemeTokens.SPACE_MD : BAR_PADDING
    for (let cursor: number = 0; cursor < index; cursor += 1) {
      left += (cursor < this.tabWidths.length ? this.tabWidths[cursor] : 0) + this.tabGap()
    }
    return left
  }

  private tabCenter(index: number): number {
    const width: number = index < this.tabWidths.length ? this.tabWidths[index] : 0
    return this.tabLeft(index) + width / 2
  }

  private indicatorLeft(): number {
    const count: number = this.tabs.length
    if (count <= 0) {
      return 0
    }
    const visual: number = Math.max(0, Math.min(count - 1, this.visualIndex))
    const from: number = Math.floor(visual)
    const to: number = Math.min(from + 1, count - 1)
    const fraction: number = visual - from
    const center: number = this.tabCenter(from) + (this.tabCenter(to) - this.tabCenter(from)) * fraction
    return center - INDICATOR_WIDTH / 2 - this.scrollOffsetX
  }

  private areaX(value: Length | undefined): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      const parsed: number = Number.parseFloat(value)
      return Number.isNaN(parsed) ? 0 : parsed
    }
    return 0
  }

  private currentScrollOffsetX(): number {
    const offset: number = currentScrollOffsetX(this.scroller)
    return offset > 0 && !Number.isNaN(offset) ? offset : 0
  }

  private setScrollOffsetX(offset: number): void {
    const normalized: number = offset > 0 && !Number.isNaN(offset) ? offset : 0
    if (this.scrollOffsetX !== normalized) {
      this.scrollOffsetX = normalized
    }
  }

  private safeKeyPart(value: string): string {
    const out: string = value.replace(/[^A-Za-z0-9_]/g, '_')
    return out.length > 0 ? out : '_'
  }

  private tabRenderKey(tab: TabItem, index: number): string {
    const label: string = typeof tab.label === 'string' ? tab.label : this.language.effectiveLocale
    return `tab_${index}_${this.safeKeyPart(tab.key)}_${this.safeKeyPart(label)}_` +
      `${this.safeKeyPart(`${tab.count}`)}_${this.safeKeyPart(tab.selectedColor)}`
  }

  private updateTabLayout(index: number, area: Area): void {
    const width: number = area.width as number
    if (width <= 0) {
      return
    }
    const nextWidths: number[] = this.tabWidths.slice()
    while (nextWidths.length <= index) {
      nextWidths.push(0)
    }
    nextWidths[index] = width
    this.tabWidths = nextWidths
    const offset: number = this.currentScrollOffsetX()
    this.setScrollOffsetX(offset)
    const nextLefts: number[] = this.tabLefts.slice()
    while (nextLefts.length <= index) {
      nextLefts.push(-1)
    }
    nextLefts[index] = this.areaX(area.globalPosition?.x) - this.containerGlobalLeft + offset
    this.tabLefts = nextLefts
    if (this.pendingCenterIndex === index) {
      this.centerTab(index, this.pendingCenterSmooth)
    }
  }

  private normalizedHex(color: string): string {
    let value: string = color.trim()
    if (value.startsWith('#')) {
      value = value.substring(1)
    }
    if (/^[0-9a-fA-F]{3}$/.test(value)) {
      value = `${value[0]}${value[0]}${value[1]}${value[1]}${value[2]}${value[2]}`
    }
    return /^[0-9a-fA-F]{6}$/.test(value) ? `#${value.toUpperCase()}` : ''
  }

  private hex2(value: number): string {
    const hex: string = Math.max(0, Math.min(255, value)).toString(16).toUpperCase()
    return hex.length === 1 ? `0${hex}` : hex
  }

  private lerpHexColor(from: string, to: string, fraction: number): string {
    const a: number = Number.parseInt(from.substring(1), 16)
    const b: number = Number.parseInt(to.substring(1), 16)
    const red: number = Math.round(((a >> 16) & 255) + (((b >> 16) & 255) - ((a >> 16) & 255)) * fraction)
    const green: number = Math.round(((a >> 8) & 255) + (((b >> 8) & 255) - ((a >> 8) & 255)) * fraction)
    const blue: number = Math.round((a & 255) + ((b & 255) - (a & 255)) * fraction)
    return `#${this.hex2(red)}${this.hex2(green)}${this.hex2(blue)}`
  }

  private tabAccentColor(index: number): ResourceColor {
    if (index >= 0 && index < this.tabs.length && this.tabs[index].selectedColor.length > 0) {
      return this.tabs[index].selectedColor
    }
    return ThemeTokens.BRAND
  }

  private indicatorColor(): ResourceColor {
    const count: number = this.tabs.length
    if (count <= 0) {
      return ThemeTokens.BRAND
    }
    const visual: number = Math.max(0, Math.min(count - 1, this.visualIndex))
    const from: number = Math.floor(visual)
    const to: number = Math.min(from + 1, count - 1)
    const fraction: number = visual - from
    const fromColor: string = this.normalizedHex(this.tabs[from].selectedColor)
    const toColor: string = this.normalizedHex(this.tabs[to].selectedColor)
    if (fromColor.length > 0 && toColor.length > 0) {
      return this.lerpHexColor(fromColor, toColor, fraction)
    }
    if (fromColor.length > 0) {
      return fromColor
    }
    if (toColor.length > 0) {
      return toColor
    }
    return ThemeTokens.BRAND
  }

  @Monitor('selectedIndex')
  onSelectedIndexChange(): void {
    this.centerSelectedTab(true, false)
  }

  private centerIndex(): number {
    const count: number = this.tabs.length
    if (count <= 0) {
      return 0
    }
    const raw: number = this.selectedIndex >= 0 ? this.selectedIndex : this.visualSelectedIndex()
    return Math.max(0, Math.min(count - 1, raw))
  }

  private centerSelectedTab(smooth: boolean, force: boolean): void {
    const index: number = this.centerIndex()
    if (!force && index === this.centeredTarget && this.pendingCenterIndex !== index) {
      return
    }
    this.centeredTarget = index
    this.centerTab(index, smooth)
  }

  private centerTab(index: number, smooth: boolean): void {
    if (index < 0 || index >= this.tabs.length) {
      return
    }
    if (!this.containerReady) {
      this.pendingCenterIndex = index
      this.pendingCenterSmooth = smooth
      return
    }
    this.pendingCenterIndex = -1
    this.scroller.scrollToIndex(index, smooth, ScrollAlign.CENTER)
  }

  @Builder
  private IndicatorBar() {
    Row()
      .width(INDICATOR_WIDTH)
      .height(3)
      .borderRadius(1.5)
      .backgroundColor(this.indicatorColor())
      .position({ x: this.indicatorLeft(), y: INDICATOR_Y })
      .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      List({ space: this.tabGap(), scroller: this.scroller }) {
        ForEach(this.tabs, (tab: TabItem, index: number): void => {
          ListItem() {
            Row({ space: 3 }) {
              Text(tab.label)
                .fontSize(ThemeTokens.FONT_SIZE_BODY)
                .fontColor(this.visualSelectedIndex() === index ? this.selectedTextColor(index) : this.themeTracked(ThemeTokens.TEXT_SECONDARY))
                .fontWeight(this.visualSelectedIndex() === index ? FontWeight.Bold : FontWeight.Regular)
                .maxLines(1)
              if (tab.count >= 0) {
                Text(`${tab.count}`)
                  .fontSize(ThemeTokens.FONT_SIZE_TINY)
                  .fontColor(this.visualSelectedIndex() === index ? this.selectedTextColor(index) : this.themeTracked(ThemeTokens.TEXT_TERTIARY))
              }
            }
            .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD,
              top: this.isCapsule() ? 0 : ThemeTokens.SPACE_XS })
            .height(this.isCapsule() ? PILL_HEIGHT : undefined)
            .borderRadius(this.isCapsule() ? ThemeTokens.RADIUS_ROUND : 0)
            .clip(this.isCapsule())
            .systemMaterial(this.isCapsule() && this.visualSelectedIndex() !== index ? this.inactiveMaterial() : undefined)
            .backgroundColor(this.tabFill(index))
            .onClick((): void => {
              this.onSelect(index)
            })
            .onAreaChange((_oldValue: Area, newValue: Area): void => {
              this.updateTabLayout(index, newValue)
            })
          }
        }, (tab: TabItem, index: number): string => this.tabRenderKey(tab, index))
      }
      .listDirection(Axis.Horizontal)
      .alignListItem(this.isCapsule() ? ListItemAlign.Center : ListItemAlign.Start)
      .contentStartOffset(this.isCapsule() ? ThemeTokens.SPACE_MD : 0)
      .contentEndOffset(this.isCapsule() ? ThemeTokens.SPACE_MD : 0)
      .onDidScroll((_scrollOffset: number, _scrollState: ScrollState): void => {
        this.setScrollOffsetX(this.currentScrollOffsetX())
      })
      .onScrollIndex((_start: number, _end: number): void => {
        this.setScrollOffsetX(this.currentScrollOffsetX())
      })
      .scrollBar(BarState.Off)
      .padding({ left: BAR_PADDING, right: BAR_PADDING })
      .width('100%')
      .height(HOME_SOURCE_SELECTOR_HEIGHT)
      if (!this.isCapsule()) {
        this.IndicatorBar()
      }
    }
    .width('100%')
    .height(HOME_SOURCE_SELECTOR_HEIGHT)
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      this.containerGlobalLeft = this.areaX(newValue.globalPosition?.x)
      this.containerReady = true
      if (this.pendingCenterIndex >= 0) {
        this.centerTab(this.pendingCenterIndex, this.pendingCenterSmooth)
      } else {
        this.centerSelectedTab(false, true)
      }
    })
  }
}
