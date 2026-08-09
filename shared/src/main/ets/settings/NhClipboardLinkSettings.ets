import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { pasteboard } from '@kit.BasicServicesKit'
import { connectNhClipboardLink } from '../state/NhClipboardLinkState'

const LAYOUT_STORE: string = 'nextn_layout'
const ENABLED_KEY: string = 'clipboard_link_enabled'
const CHANGE_COUNT_KEY: string = 'clipboard_link_change_count'
const READ_PASTEBOARD_PERMISSION: Permissions = 'ohos.permission.READ_PASTEBOARD'

/** Durable, explicit opt-in for detecting copied canonical NH gallery links. */
export class NhClipboardLinkSettings {
  static async restore(context: common.UIAbilityContext): Promise<void> {
    let enabled: boolean = false
    let lastChangeCount: number = -1
    try {
      const store = await preferences.getPreferences(context, LAYOUT_STORE)
      enabled = store.getSync(ENABLED_KEY, false) as boolean
      lastChangeCount = store.getSync(CHANGE_COUNT_KEY, -1) as number
    } catch (_error) {}
    const state = connectNhClipboardLink()
    state.enabled = enabled
    state.lastChangeCount = lastChangeCount
  }

  static async setEnabled(context: common.UIAbilityContext, enabled: boolean): Promise<boolean> {
    if (enabled && !await NhClipboardLinkSettings.requestPermission(context)) {
      return false
    }
    let changeCount: number = connectNhClipboardLink().lastChangeCount
    if (enabled) {
      try {
        // Seed the cursor after consent: copied content from before opt-in is
        // never read or surfaced by this feature.
        changeCount = pasteboard.getSystemPasteboard().getChangeCount()
      } catch (_error) {}
    }
    await NhClipboardLinkSettings.persist(context, enabled, changeCount)
    return true
  }

  static async markChangeCount(context: common.UIAbilityContext, changeCount: number): Promise<void> {
    await NhClipboardLinkSettings.persist(context, connectNhClipboardLink().enabled, changeCount)
  }

  static async disableAfterPermissionFailure(context: common.UIAbilityContext): Promise<void> {
    await NhClipboardLinkSettings.persist(context, false, connectNhClipboardLink().lastChangeCount)
  }

  private static async persist(context: common.UIAbilityContext, enabled: boolean, changeCount: number): Promise<void> {
    const state = connectNhClipboardLink()
    state.enabled = enabled
    state.lastChangeCount = changeCount
    try {
      const store = await preferences.getPreferences(context, LAYOUT_STORE)
      store.putSync(ENABLED_KEY, enabled)
      store.putSync(CHANGE_COUNT_KEY, changeCount)
      store.flushSync()
    } catch (_error) {}
  }

  private static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const manager = abilityAccessCtrl.createAtManager()
      const result = await manager.requestPermissionsFromUser(context, [READ_PASTEBOARD_PERMISSION])
      return result.authResults.length > 0 && result.authResults[0] === 0
    } catch (_error) {
      return false
    }
  }
}
