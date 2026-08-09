import { AppStorageV2 } from '@kit.ArkUI'

export const SETTINGS_ROOT_BROWSER_SESSION: string = 'browserSession'
export const SETTINGS_ROOT_LAYOUT: string = 'layoutSettings'
export const SETTINGS_ROOT_CATALOG: string = 'catalogSettings'
export const SETTINGS_ROOT_READER: string = 'readerSettings'
export const SETTINGS_ROOT_DOWNLOAD: string = 'downloadSettings'
export const SETTINGS_ROOT_CACHE: string = 'cacheSettings'
export const SETTINGS_ROOT_ADVANCED: string = 'advancedSettings'
export const SETTINGS_ROOT_ABOUT: string = 'about'

const SETTINGS_ROOT_ROUTES: string[] = [
  SETTINGS_ROOT_BROWSER_SESSION,
  SETTINGS_ROOT_LAYOUT,
  SETTINGS_ROOT_CATALOG,
  SETTINGS_ROOT_READER,
  SETTINGS_ROOT_DOWNLOAD,
  SETTINGS_ROOT_CACHE,
  SETTINGS_ROOT_ADVANCED,
  SETTINGS_ROOT_ABOUT,
]

/**
 * Reactive Settings location published by the root Navigation owner.
 *
 * `NavPathStack` remains an imperative command target. Settings rows render
 * from this small state instead of inspecting the stack during `build()`. The
 * first route in the secondary branch is retained while a real child route is
 * visible, so a nested page keeps its parent Settings row selected.
 */
@ObservedV2
export class SettingsNavigationState {
  @Trace selectedRootRoute: string = ''

  syncSecondaryBranch(pathStack: NavPathStack | null): void {
    if (pathStack === null) {
      this.clearRootLocation()
      return
    }
    const pathNames: string[] = pathStack.getAllPathName()
    const secondaryEntryName: string | undefined = pathNames[0]
    const nextRoute: string = secondaryEntryName !== undefined &&
      SETTINGS_ROOT_ROUTES.indexOf(secondaryEntryName) >= 0
      ? secondaryEntryName
      : ''
    if (this.selectedRootRoute !== nextRoute) {
      this.selectedRootRoute = nextRoute
    }
  }

  clearRootLocation(): void {
    if (this.selectedRootRoute.length > 0) {
      this.selectedRootRoute = ''
    }
  }

  isRootSelected(name: string, isSplitMode: boolean): boolean {
    return isSplitMode && this.selectedRootRoute === name
  }
}

const SETTINGS_NAVIGATION_V2_KEY: string = 'nextn_settings_navigation'

export function connectSettingsNavigation(): SettingsNavigationState {
  return AppStorageV2.connect(
    SettingsNavigationState,
    SETTINGS_NAVIGATION_V2_KEY,
    () => new SettingsNavigationState(),
  )!
}
