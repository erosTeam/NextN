import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { i18n } from '@kit.LocalizationKit'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState } from '../state/AppearanceState'

const APPEARANCE_STORE: string = 'nextn_appearance'
const LANGUAGE_KEY: string = 'language_mode'

/** NextE-compatible application language choice: system, Chinese, English, or Japanese. */
export class LanguageSettings {
  static readonly MODE_SYSTEM: string = 'system'
  static readonly MODE_ZH_CN: string = 'zh-Hans'
  static readonly MODE_EN: string = 'en-US'
  static readonly MODE_JA: string = 'ja-JP'

  static normalize(mode: string): string {
    if (
      mode === LanguageSettings.MODE_ZH_CN ||
      mode === LanguageSettings.MODE_EN ||
      mode === LanguageSettings.MODE_JA
    ) {
      return mode
    }
    return LanguageSettings.MODE_SYSTEM
  }

  private static systemLocale(): string {
    try {
      // The preferred-language list remains system-scoped even while an
      // application has a transient explicit language. Prefer it when
      // restoring Follow system so a just-cleared app preference cannot feed
      // its former language back into the current-process resource override.
      const preferred: string = i18n.System.getFirstPreferredLanguage()
      if (preferred.length > 0) {
        return preferred
      }
    } catch (_error) {}
    try {
      return i18n.System.getSystemLanguage()
    } catch (_error) {
      return ''
    }
  }

  static apply(mode: string): void {
    const normalized: string = LanguageSettings.normalize(mode)
    // The official i18n API uses the literal `default` to clear a previous
    // app preference. Resolving the system locale and pinning it would make
    // the row look like Follow system while silently ignoring later system
    // language changes.
    const preferredLanguage: string = normalized === LanguageSettings.MODE_SYSTEM
      ? 'default'
      : normalized
    try {
      i18n.System.setAppPreferredLanguage(preferredLanguage)
    } catch (_error) {}
    const locale: string = normalized === LanguageSettings.MODE_SYSTEM
      ? LanguageSettings.systemLocale()
      : normalized
    // `setAppPreferredLanguage('default')` correctly restores the durable
    // follow-system choice, but the platform documents it as cold-start
    // effective. Keep an explicit resource-manager override for the current
    // system locale so every AppStrings caller redraws immediately as well.
    // This does not call ApplicationContext.setLanguage, which would pin the
    // application language and suppress subsequent environment callbacks.
    AppStrings.setOverrideLocale(locale)
    const state = connectLanguageState()
    state.mode = normalized
    state.effectiveLocale = locale
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    let mode: string = LanguageSettings.MODE_SYSTEM
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, APPEARANCE_STORE)
      mode = store.getSync(LANGUAGE_KEY, LanguageSettings.MODE_SYSTEM) as string
    } catch (_error) {}
    LanguageSettings.apply(mode)
  }

  static async setMode(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalized: string = LanguageSettings.normalize(mode)
    LanguageSettings.apply(normalized)
    const store: preferences.Preferences = await preferences.getPreferences(context, APPEARANCE_STORE)
    store.putSync(LANGUAGE_KEY, normalized)
    store.flushSync()
  }

  /** Refresh only the effective signal when the system locale changes. */
  static onSystemLanguageChanged(language: string): void {
    const state = connectLanguageState()
    if (state.mode !== LanguageSettings.MODE_SYSTEM) {
      return
    }
    // Configuration.language may only carry a coarse language code. Resolve
    // the current system preference again so the override retains its full
    // locale while the durable application preference stays `default`.
    const systemLocale: string = LanguageSettings.systemLocale()
    state.effectiveLocale = systemLocale.length > 0 ? systemLocale : language
    // Keep the current process in sync too. The durable preference remains
    // `default`; this resource override only selects the current system
    // locale until the next environment update or cold start.
    AppStrings.setOverrideLocale(state.effectiveLocale)
  }
}
