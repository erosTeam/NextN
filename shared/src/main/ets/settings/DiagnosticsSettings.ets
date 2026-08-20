import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { connectDiagnostics } from '../state/DiagnosticsState'

const DIAGNOSTICS_STORE: string = 'nextn_settings'
const DIAGNOSTICS_ENABLED_KEY: string = 'diagnostics.enabled'
const DIAGNOSTICS_MIN_LEVEL_KEY: string = 'diagnostics.minLevel'

export class DiagnosticsSettingsSnapshot {
  enabled: boolean = true
  minLevel: string = 'info'
}

export class DiagnosticsSettings {
  static readonly LEVEL_DEBUG: string = 'debug'
  static readonly LEVEL_INFO: string = 'info'
  static readonly LEVEL_WARN: string = 'warn'
  static readonly LEVEL_ERROR: string = 'error'
  static readonly DEFAULT_ENABLED: boolean = true
  static readonly DEFAULT_MIN_LEVEL: string = DiagnosticsSettings.LEVEL_INFO

  static apply(snapshot: DiagnosticsSettingsSnapshot): void {
    const safeLevel: string = DiagnosticsSettings.normalizeLevel(snapshot.minLevel)
    const state = connectDiagnostics()
    state.enabled = snapshot.enabled
    state.minLevel = safeLevel
    DiagnosticLogger.configure(snapshot.enabled, safeLevel)
  }

  static current(): DiagnosticsSettingsSnapshot {
    const state = connectDiagnostics()
    const snapshot: DiagnosticsSettingsSnapshot = new DiagnosticsSettingsSnapshot()
    snapshot.enabled = state.enabled
    snapshot.minLevel = DiagnosticsSettings.normalizeLevel(state.minLevel)
    return snapshot
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, DIAGNOSTICS_STORE)
      const snapshot: DiagnosticsSettingsSnapshot = new DiagnosticsSettingsSnapshot()
      snapshot.enabled = store.getSync(
        DIAGNOSTICS_ENABLED_KEY,
        DiagnosticsSettings.DEFAULT_ENABLED,
      ) as boolean
      snapshot.minLevel = DiagnosticsSettings.normalizeLevel(
        store.getSync(DIAGNOSTICS_MIN_LEVEL_KEY, DiagnosticsSettings.DEFAULT_MIN_LEVEL) as string,
      )
      DiagnosticsSettings.apply(snapshot)
      DiagnosticLogger.info(
        'diagnostics',
        'settings_restored',
        `enabled=${snapshot.enabled} minLevel=${snapshot.minLevel}`,
      )
    } catch (error) {
      DiagnosticsSettings.apply(new DiagnosticsSettingsSnapshot())
      DiagnosticLogger.warn('settings', 'diagnostics_restore_failed', (error as Error).message)
    }
  }

  static async save(
    context: common.UIAbilityContext,
    snapshot: DiagnosticsSettingsSnapshot,
  ): Promise<void> {
    snapshot.minLevel = DiagnosticsSettings.normalizeLevel(snapshot.minLevel)
    DiagnosticsSettings.apply(snapshot)
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, DIAGNOSTICS_STORE)
      store.putSync(DIAGNOSTICS_ENABLED_KEY, snapshot.enabled)
      store.putSync(DIAGNOSTICS_MIN_LEVEL_KEY, snapshot.minLevel)
      store.flushSync()
      DiagnosticLogger.info(
        'diagnostics',
        'settings_saved',
        `enabled=${snapshot.enabled} minLevel=${snapshot.minLevel}`,
      )
    } catch (error) {
      DiagnosticLogger.warn('settings', 'diagnostics_save_failed', (error as Error).message)
    }
  }

  static exportText(): string {
    return DiagnosticLogger.exportText()
  }

  static count(): number {
    return DiagnosticLogger.count()
  }

  static clearLogs(): void {
    DiagnosticLogger.clear()
    DiagnosticLogger.info('diagnostics', 'logs_cleared', 'current launch memory log cleared')
  }

  static normalizeLevel(level: string): string {
    if (level === DiagnosticsSettings.LEVEL_DEBUG || level === DiagnosticsSettings.LEVEL_INFO ||
      level === DiagnosticsSettings.LEVEL_WARN || level === DiagnosticsSettings.LEVEL_ERROR) {
      return level
    }
    return DiagnosticsSettings.DEFAULT_MIN_LEVEL
  }
}
