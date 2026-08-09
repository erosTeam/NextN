import { AppStorageV2 } from '@kit.ArkUI'

/**
 * Persisted visibility preference for the root floating HDS tabs.
 *
 * This mirrors NextE's default: root navigation remains immediately available
 * at rest, then gets out of the reading path while a root list scrolls down.
 */
@ObservedV2
export class HomeTabAutoHideState {
  @Trace autoHide: boolean = true
}

const HOME_TAB_AUTO_HIDE_STATE_KEY: string = 'nextn_home_tab_auto_hide'

/** Returns the app-wide reactive root-tab visibility preference. */
export function connectHomeTabAutoHide(): HomeTabAutoHideState {
  return AppStorageV2.connect(
    HomeTabAutoHideState,
    HOME_TAB_AUTO_HIDE_STATE_KEY,
    () => new HomeTabAutoHideState(),
  )!
}
