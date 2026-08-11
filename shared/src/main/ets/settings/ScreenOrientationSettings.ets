import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import {
  connectScreenOrientation,
  SCREEN_ORIENTATION_AUTO_ROTATION_UNSPECIFIED,
  SCREEN_ORIENTATION_UNSPECIFIED,
} from '../state/ScreenOrientationState'

const SCREEN_ORIENTATION_STORE: string = 'nextn_layout'
const SCREEN_ORIENTATION_KEY: string = 'screen_orientation_mode'

type WindowOrientationApplier = (mode: string) => void

let windowOrientationApplier: WindowOrientationApplier | null = null

/** Persists system-managed orientation separately from the tablet split policy. */
export class ScreenOrientationSettings {
  static readonly MODE_UNSPECIFIED: string = SCREEN_ORIENTATION_UNSPECIFIED
  static readonly MODE_AUTO_ROTATION_UNSPECIFIED: string =
    SCREEN_ORIENTATION_AUTO_ROTATION_UNSPECIFIED

  static bindWindowOrientationApplier(applier: WindowOrientationApplier): void {
    windowOrientationApplier = applier
    ScreenOrientationSettings.applyWindowOrientation()
  }

  static normalizeMode(mode: string): string {
    return mode === SCREEN_ORIENTATION_AUTO_ROTATION_UNSPECIFIED
      ? SCREEN_ORIENTATION_AUTO_ROTATION_UNSPECIFIED
      : SCREEN_ORIENTATION_UNSPECIFIED
  }

  static apply(mode: string): void {
    connectScreenOrientation().mode = ScreenOrientationSettings.normalizeMode(mode)
    ScreenOrientationSettings.applyWindowOrientation()
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    let mode: string = SCREEN_ORIENTATION_UNSPECIFIED
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        context,
        SCREEN_ORIENTATION_STORE,
      )
      mode = store.getSync(SCREEN_ORIENTATION_KEY, SCREEN_ORIENTATION_UNSPECIFIED) as string
    } catch (_error) {}
    ScreenOrientationSettings.apply(mode)
  }

  static async setMode(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalized: string = ScreenOrientationSettings.normalizeMode(mode)
    ScreenOrientationSettings.apply(normalized)
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        context,
        SCREEN_ORIENTATION_STORE,
      )
      store.putSync(SCREEN_ORIENTATION_KEY, normalized)
      store.flushSync()
    } catch (_error) {}
  }

  private static applyWindowOrientation(): void {
    if (windowOrientationApplier !== null) {
      windowOrientationApplier(connectScreenOrientation().mode)
    }
  }
}
