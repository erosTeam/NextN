import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { connectThemeDisplay } from '../state/AppearanceState'

const APPEARANCE_STORE: string = 'nextn_appearance'
const THEME_KEY: string = 'theme_mode'

/** NextE-compatible system/light/dark choice applied through ApplicationContext. */
export class ThemeSettings {
  static readonly MODE_SYSTEM: string = 'system'
  static readonly MODE_LIGHT: string = 'light'
  static readonly MODE_DARK: string = 'dark'

  static normalize(mode: string): string {
    if (mode === ThemeSettings.MODE_LIGHT || mode === ThemeSettings.MODE_DARK) {
      return mode
    }
    return ThemeSettings.MODE_SYSTEM
  }

  private static effectiveDark(context: common.UIAbilityContext, mode: string): boolean {
    if (mode === ThemeSettings.MODE_DARK) {
      return true
    }
    if (mode === ThemeSettings.MODE_LIGHT) {
      return false
    }
    return context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
  }

  /**
   * Applying ApplicationContext color mode is only legal after loadContent
   * completed. `publish` supports startup preference loading before the first
   * component mounts without making an illegal platform call.
   */
  private static publish(context: common.UIAbilityContext, mode: string): void {
    const normalized: string = ThemeSettings.normalize(mode)
    const state = connectThemeDisplay()
    state.mode = normalized
    state.effectiveDark = ThemeSettings.effectiveDark(context, normalized)
  }

  static apply(context: common.UIAbilityContext, mode: string): void {
    const normalized: string = ThemeSettings.normalize(mode)
    let colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    if (normalized === ThemeSettings.MODE_LIGHT) {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    } else if (normalized === ThemeSettings.MODE_DARK) {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    }
    try {
      context.getApplicationContext().setColorMode(colorMode)
    } catch (_error) {}
    ThemeSettings.publish(context, normalized)
  }

  static async restore(context: common.UIAbilityContext, applyPlatform: boolean = true): Promise<void> {
    let mode: string = ThemeSettings.MODE_SYSTEM
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, APPEARANCE_STORE)
      mode = store.getSync(THEME_KEY, ThemeSettings.MODE_SYSTEM) as string
    } catch (_error) {}
    if (applyPlatform) {
      ThemeSettings.apply(context, mode)
    } else {
      ThemeSettings.publish(context, mode)
    }
  }

  static async setMode(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalized: string = ThemeSettings.normalize(mode)
    ThemeSettings.apply(context, normalized)
    const store: preferences.Preferences = await preferences.getPreferences(context, APPEARANCE_STORE)
    store.putSync(THEME_KEY, normalized)
    store.flushSync()
  }

  static onSystemColorModeChanged(colorMode: ConfigurationConstant.ColorMode): void {
    const state = connectThemeDisplay()
    if (state.mode === ThemeSettings.MODE_SYSTEM) {
      state.effectiveDark = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    }
  }
}
