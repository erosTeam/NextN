import { SymbolGlyphModifier } from '@kit.ArkUI'
import { AppStrings } from '../i18n/AppStrings'
import { NextNListRow } from './NextNListRow'

export interface SettingsChoiceOption {
  value: string
  label: string
}

/** A single choice owns both the row label and native menu checks. */
@ComponentV2
export struct SettingsChoiceRow {
  @Require @Param title: string
  @Require @Param value: string
  @Require @Param options: SettingsChoiceOption[]
  @Param accessibilityId: string = ''
  @Event selectAction?: (value: string) => void

  private valueLabel(): string {
    const option = this.options.find((item: SettingsChoiceOption): boolean => item.value === this.value)
    return option?.label ?? ''
  }

  @Builder
  private ChoiceMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(this.options, (option: SettingsChoiceOption) => {
        MenuItem({
          content: option.label,
          symbolEndIcon: option.value === this.value
            ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
            : undefined,
        }).onClick((): void => {
          select((): void => this.selectAction?.(option.value))
        })
      }, (option: SettingsChoiceOption): string => option.value)
    }
  }

  build() {
    NextNListRow({
      title: this.title,
      trailingText: this.valueLabel(),
      trailingDropdown: true,
      dropdownMenuEnabled: true,
      dropdownMenuBuilder: (select: (action: () => void) => void): void => {
        this.ChoiceMenu(select)
      },
      accessibilityId: this.accessibilityId,
      accessibilityLabel: AppStrings.format('settings_row_a11y', [this.title, this.valueLabel()]),
    })
  }
}
