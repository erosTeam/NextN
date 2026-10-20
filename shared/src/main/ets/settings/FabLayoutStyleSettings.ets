import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { AppStrings } from '../i18n/AppStrings'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import {
  connectFabLayoutStyle,
  FAB_LAYOUT_BOTTOM,
  FAB_LAYOUT_CENTERED,
  FAB_LAYOUT_DEFAULT,
} from '../state/FabLayoutStyleState'

export interface FabLayoutStyleOption {
  label: ResourceStr
  style: string
}

/** Persists the gallery-detail floating action rail layout style. */
export class FabLayoutStyleSettings {
  static readonly STYLE_BOTTOM: string = FAB_LAYOUT_BOTTOM
  static readonly STYLE_CENTERED: string = FAB_LAYOUT_CENTERED

  static normalizeStyle(style: string): string {
    const value: string = (style || '').trim()
    if (value === FAB_LAYOUT_CENTERED) {
      return FAB_LAYOUT_CENTERED
    }
    return FAB_LAYOUT_BOTTOM
  }

  static isCentered(style: string): boolean {
    return FabLayoutStyleSettings.normalizeStyle(style) === FAB_LAYOUT_CENTERED
  }

  static options(): FabLayoutStyleOption[] {
    return [
      { label: $r('app.string.fab_layout_style_bottom'), style: FAB_LAYOUT_BOTTOM },
      { label: $r('app.string.fab_layout_style_centered'), style: FAB_LAYOUT_CENTERED },
    ]
  }

  static label(style: string): string {
    return FabLayoutStyleSettings.isCentered(style)
      ? AppStrings.get('fab_layout_style_centered')
      : AppStrings.get('fab_layout_style_bottom')
  }

  static apply(style: string): void {
    connectFabLayoutStyle().style = FabLayoutStyleSettings.normalizeStyle(style)
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        context,
        'nextn_layout',
      )
      const style: string = store.getSync(
        'fab_layout_style',
        FAB_LAYOUT_DEFAULT,
      ) as string
      FabLayoutStyleSettings.apply(style)
    } catch (error) {
      DiagnosticLogger.warn('settings', 'fab_layout_style_restore_failed', (error as Error).message)
    }
  }

  static async setStyle(context: common.UIAbilityContext, style: string): Promise<void> {
    const normalized: string = FabLayoutStyleSettings.normalizeStyle(style)
    FabLayoutStyleSettings.apply(normalized)
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        context,
        'nextn_layout',
      )
      store.putSync('fab_layout_style', normalized)
      store.flushSync()
    } catch (error) {
      DiagnosticLogger.warn('settings', 'fab_layout_style_save_failed', (error as Error).message)
    }
  }
}
