import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { SAFE_MODE_BUILD_ENABLED } from '../safe/SafeModeBuildFlag'
import { SafeModeState, connectSafeMode } from '../state/SafeModeState'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

const SAFE_MODE_STORE: string = 'nextn_settings'
export const SAFE_MODE_UNLOCKED_KEY: string = 'safeMode.unlocked'

export class SafeModeSettings {
  static apply(unlocked: boolean): void {
    const state: SafeModeState = connectSafeMode()
    state.buildEnabled = SAFE_MODE_BUILD_ENABLED
    state.unlocked = SAFE_MODE_BUILD_ENABLED && unlocked
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, SAFE_MODE_STORE)
      const unlocked: boolean = store.getSync(SAFE_MODE_UNLOCKED_KEY, false) as boolean
      SafeModeSettings.apply(unlocked)
    } catch (error) {
      DiagnosticLogger.warn('settings', 'safe_mode_restore_failed', (error as Error).message)
      SafeModeSettings.apply(false)
    }
  }

  static async unlock(context: common.UIAbilityContext): Promise<void> {
    if (!SAFE_MODE_BUILD_ENABLED) {
      return
    }
    SafeModeSettings.apply(true)
    await SafeModeSettings.persist(context, true)
  }

  static async lock(context: common.UIAbilityContext): Promise<void> {
    if (!SAFE_MODE_BUILD_ENABLED) {
      return
    }
    SafeModeSettings.apply(false)
    await SafeModeSettings.persist(context, false)
  }

  private static async persist(context: common.UIAbilityContext, unlocked: boolean): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, SAFE_MODE_STORE)
      store.putSync(SAFE_MODE_UNLOCKED_KEY, unlocked)
      store.flushSync()
    } catch (error) {
      DiagnosticLogger.warn('settings', 'safe_mode_save_failed', (error as Error).message)
    }
  }
}
