import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { connectSearchTranslation } from '../state/SearchTranslationState'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

const SETTINGS_STORE: string = 'nextn_settings'
const KEY_TRANSLATE_ENABLED: string = 'search_history_translate'

/** Preferences-backed translation display policy for search landing chips. */
export class SearchTranslationSettings {
  static async restore(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        context,
        SETTINGS_STORE,
      )
      connectSearchTranslation().translateEnabled =
        store.getSync(KEY_TRANSLATE_ENABLED, true) as boolean
    } catch (error) {
      DiagnosticLogger.warn('search', 'search_translation_restore_failed', (error as Error).message)
    }
  }

  static async setTranslateEnabled(
    context: common.UIAbilityContext,
    enabled: boolean,
  ): Promise<void> {
    connectSearchTranslation().translateEnabled = enabled
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        context,
        SETTINGS_STORE,
      )
      store.putSync(KEY_TRANSLATE_ENABLED, enabled)
      store.flushSync()
    } catch (error) {
      DiagnosticLogger.warn('search', 'search_translation_save_failed', (error as Error).message)
    }
  }
}
