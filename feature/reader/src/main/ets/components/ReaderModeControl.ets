import { SymbolGlyphModifier } from '@kit.ArkUI'
import { AppStrings, NhReaderMode, ThemeTokens, appMenuOptions } from 'shared'

/** NextN's existing reader-direction control, shared by both reader backends. */
@ComponentV2
export struct ReaderModeControl {
  @Param readerMode: NhReaderMode = NhReaderMode.PAGED
  @Param controlEnabled: boolean = true
  @Event onModeChange: (mode: NhReaderMode) => void = (_mode: NhReaderMode): void => {}
  @Event onMenuVisible: (visible: boolean) => void = (_visible: boolean): void => {}
  @Local private modeShown: boolean = false

  private modeLabel(mode: NhReaderMode): string {
    if (mode === NhReaderMode.PAGED_RTL) return AppStrings.get('settings_reader_mode_paged_rtl')
    if (mode === NhReaderMode.PAGED_VERTICAL) return AppStrings.get('settings_reader_mode_paged_vertical')
    if (mode === NhReaderMode.PAGED) return AppStrings.get('settings_reader_mode_paged')
    return AppStrings.get('settings_reader_mode_vertical')
  }

  private modeIcon(mode: NhReaderMode): Resource {
    if (mode === NhReaderMode.PAGED_RTL) return $r('sys.symbol.arrow_left_and_square')
    if (mode === NhReaderMode.PAGED_VERTICAL) return $r('sys.symbol.single_page_flipping')
    if (mode === NhReaderMode.PAGED) return $r('sys.symbol.arrow_right_and_square')
    return $r('sys.symbol.scroll_vertical')
  }

  @Builder
  private ModeMenu() {
    Menu() {
      MenuItem({
        content: this.modeLabel(NhReaderMode.PAGED),
        symbolStartIcon: new SymbolGlyphModifier(this.modeIcon(NhReaderMode.PAGED)),
        symbolEndIcon: this.readerMode === NhReaderMode.PAGED
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
      }).onClick((): void => { this.onModeChange(NhReaderMode.PAGED); this.modeShown = false })
      MenuItem({
        content: this.modeLabel(NhReaderMode.PAGED_RTL),
        symbolStartIcon: new SymbolGlyphModifier(this.modeIcon(NhReaderMode.PAGED_RTL)),
        symbolEndIcon: this.readerMode === NhReaderMode.PAGED_RTL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
      }).onClick((): void => { this.onModeChange(NhReaderMode.PAGED_RTL); this.modeShown = false })
      MenuItem({
        content: this.modeLabel(NhReaderMode.PAGED_VERTICAL),
        symbolStartIcon: new SymbolGlyphModifier(this.modeIcon(NhReaderMode.PAGED_VERTICAL)),
        symbolEndIcon: this.readerMode === NhReaderMode.PAGED_VERTICAL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
      }).onClick((): void => { this.onModeChange(NhReaderMode.PAGED_VERTICAL); this.modeShown = false })
      MenuItem({
        content: this.modeLabel(NhReaderMode.VERTICAL),
        symbolStartIcon: new SymbolGlyphModifier(this.modeIcon(NhReaderMode.VERTICAL)),
        symbolEndIcon: this.readerMode === NhReaderMode.VERTICAL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
      }).onClick((): void => { this.onModeChange(NhReaderMode.VERTICAL); this.modeShown = false })
    }
  }

  build() {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(this.modeIcon(this.readerMode))
        .fontSize(ThemeTokens.SYMBOL_SIZE_ROW)
        .fontColor([ThemeTokens.TEXT_ON_BRAND])
    }
    .width(44).height(44).backgroundColor(Color.Transparent).enabled(this.controlEnabled)
    .accessibilityText(AppStrings.format('settings_reader_layout_a11y', [this.modeLabel(this.readerMode)]))
    .onClick((): void => { this.modeShown = true })
    .bindMenu(this.modeShown, this.ModeMenu, appMenuOptions({
      placement: Placement.TopRight,
      aboutToAppear: (): void => { this.onMenuVisible(true) },
      onDisappear: (): void => { this.modeShown = false; this.onMenuVisible(false) },
    }))
  }
}
