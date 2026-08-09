import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { connectHomeTabAutoHide } from '../state/HomeTabAutoHideState'

const LAYOUT_STORE: string = 'nextn_layout'
const HOME_TAB_AUTO_HIDE_KEY: string = 'home_tab_auto_hide'

/** Durable NextE-style preference for hiding the floating root tabs on scroll. */
export class HomeTabSettings {
  static readonly DEFAULT_AUTO_HIDE: boolean = true

  static apply(autoHide: boolean): void {
    connectHomeTabAutoHide().autoHide = autoHide
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    let autoHide: boolean = HomeTabSettings.DEFAULT_AUTO_HIDE
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, LAYOUT_STORE)
      autoHide = store.getSync(HOME_TAB_AUTO_HIDE_KEY, HomeTabSettings.DEFAULT_AUTO_HIDE) as boolean
    } catch (_error) {}
    HomeTabSettings.apply(autoHide)
  }

  static async save(context: common.UIAbilityContext, autoHide: boolean): Promise<void> {
    HomeTabSettings.apply(autoHide)
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, LAYOUT_STORE)
      store.putSync(HOME_TAB_AUTO_HIDE_KEY, autoHide)
      store.flushSync()
    } catch (_error) {}
  }
}
