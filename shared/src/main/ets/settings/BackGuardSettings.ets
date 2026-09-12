import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { connectBackGuard } from '../state/BackGuardState'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

const BACK_GUARD_STORE: string = 'nextn_settings'
const BACK_GUARD_ENABLED_KEY: string = 'navigation.backGuardEnabled'

/**
 * Persists the home back-guard and is the SINGLE WRITER of BackGuardState.
 * Mirrors NextE BackGuardSettings: restore() seeds the AppStorageV2 mirror at startup, setEnabled()
 * writes the mirror first then flushes to the preferences store.
 */
export class BackGuardSettings {
  static async restore(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, BACK_GUARD_STORE)
      connectBackGuard().enabled = store.getSync(
        BACK_GUARD_ENABLED_KEY,
        true,
      ) as boolean
    } catch (error) {
      DiagnosticLogger.warn('settings', 'backguard_restore_failed', (error as Error).message)
    }
  }

  static async setEnabled(context: common.UIAbilityContext, value: boolean): Promise<void> {
    connectBackGuard().enabled = value
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, BACK_GUARD_STORE)
      store.putSync(BACK_GUARD_ENABLED_KEY, value)
      store.flushSync()
    } catch (error) {
      DiagnosticLogger.warn('settings', 'backguard_save_failed', (error as Error).message)
    }
  }
}
