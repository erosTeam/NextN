import { AppStrings } from '../i18n/AppStrings'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import {
  connectSubTabStyle,
  SUBTAB_STYLE_UNDERLINE,
  SUBTAB_STYLE_CAPSULE,
  SUBTAB_STYLE_DEFAULT,
} from '../state/SubTabStyleState'

const APPEARANCE_STORE: string = 'nextn_appearance'
const SUBTAB_STYLE_KEY: string = 'sub_tab_style'

export interface SubTabStyleOption {
  label: ResourceStr
  style: string
}

/** Shared appearance for the Home source selector sub-tabs. */
export class SubTabStyleSettings {
  static isCapsule(style: string): boolean {
    return SubTabStyleSettings.normalizeStyle(style) === SUBTAB_STYLE_CAPSULE
  }

  static normalizeStyle(style: string): string {
    const normalized: string = (style || '').trim()
    return normalized === SUBTAB_STYLE_UNDERLINE ? SUBTAB_STYLE_UNDERLINE : SUBTAB_STYLE_DEFAULT
  }

  static options(): SubTabStyleOption[] {
    return [
      { label: AppStrings.get('subtab_style_underline'), style: SUBTAB_STYLE_UNDERLINE },
      { label: $r('app.string.subtab_style_capsule'), style: SUBTAB_STYLE_CAPSULE },
    ]
  }

  static label(style: string): string {
    return SubTabStyleSettings.isCapsule(style)
      ? AppStrings.get('subtab_style_capsule')
      : AppStrings.get('subtab_style_underline')
  }

  static apply(style: string): void {
    connectSubTabStyle().style = SubTabStyleSettings.normalizeStyle(style)
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, APPEARANCE_STORE)
      SubTabStyleSettings.apply(store.getSync(SUBTAB_STYLE_KEY, SUBTAB_STYLE_DEFAULT) as string)
    } catch (error) {
      DiagnosticLogger.warn('settings', 'subtab_style_restore_failed', (error as Error).message)
    }
  }

  static async setStyle(context: common.UIAbilityContext, style: string): Promise<void> {
    const normalized: string = SubTabStyleSettings.normalizeStyle(style)
    SubTabStyleSettings.apply(normalized)
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, APPEARANCE_STORE)
      store.putSync(SUBTAB_STYLE_KEY, normalized)
      store.flushSync()
    } catch (error) {
      DiagnosticLogger.warn('settings', 'subtab_style_save_failed', (error as Error).message)
    }
  }
}
