import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import {
  connectTabletLayout,
  TABLET_LAYOUT_AUTO,
  TABLET_LAYOUT_LANDSCAPE_ONLY,
  TABLET_LAYOUT_OFF,
} from '../state/TabletLayoutState'

const TABLET_LAYOUT_STORE: string = 'nextn_layout'
const TABLET_LAYOUT_KEY: string = 'tablet_layout_mode'

/**
 * Durable policy only.  It deliberately does not request an orientation or
 * alter the root HDS mode; phase 3 will consume this value at the shell.
 */
export class TabletLayoutSettings {
  static readonly MODE_AUTO: string = TABLET_LAYOUT_AUTO
  static readonly MODE_OFF: string = TABLET_LAYOUT_OFF
  static readonly MODE_LANDSCAPE_ONLY: string = TABLET_LAYOUT_LANDSCAPE_ONLY

  static normalizeMode(mode: string): string {
    if (mode === TABLET_LAYOUT_OFF || mode === TABLET_LAYOUT_LANDSCAPE_ONLY) {
      return mode
    }
    return TABLET_LAYOUT_AUTO
  }

  /**
   * Evaluates policy against current main-window geometry, rather than asking
   * the device to rotate.  No phase-2 caller switches navigation from this.
   */
  static allowsSplit(mode: string, widthPx: number, heightPx: number): boolean {
    const normalized: string = TabletLayoutSettings.normalizeMode(mode)
    if (normalized === TABLET_LAYOUT_OFF) {
      return false
    }
    if (normalized === TABLET_LAYOUT_LANDSCAPE_ONLY) {
      return widthPx > 0 && heightPx > 0 && widthPx > heightPx
    }
    return true
  }

  static apply(mode: string): void {
    connectTabletLayout().mode = TabletLayoutSettings.normalizeMode(mode)
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    let mode: string = TABLET_LAYOUT_AUTO
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, TABLET_LAYOUT_STORE)
      mode = store.getSync(TABLET_LAYOUT_KEY, TABLET_LAYOUT_AUTO) as string
    } catch (_error) {}
    TabletLayoutSettings.apply(mode)
  }

  static async setMode(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalized: string = TabletLayoutSettings.normalizeMode(mode)
    TabletLayoutSettings.apply(normalized)
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, TABLET_LAYOUT_STORE)
      store.putSync(TABLET_LAYOUT_KEY, normalized)
      store.flushSync()
    } catch (_error) {}
  }
}
