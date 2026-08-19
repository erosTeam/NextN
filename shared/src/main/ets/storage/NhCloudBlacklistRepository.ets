import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

const BLACKLIST_STORE: string = 'nextn_settings'
const KEY_BLACKLIST_IDS: string = 'cloud_blacklist_ids_v1'

/**
 * Preferences-backed durable snapshot of the account's cloud tag-blacklist
 * ids. Keeping it separate from page caches means clearing 图片缓存/页面缓存
 * never forces the user to re-download the blacklist (same reasoning as the
 * tag-translation dictionary).
 */
export class NhCloudBlacklistRepository {
  static async load(context: common.UIAbilityContext): Promise<number[]> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        context,
        BLACKLIST_STORE,
      )
      const raw: string = store.getSync(KEY_BLACKLIST_IDS, '') as string
      if (raw.length === 0) {
        return []
      }
      const parsed: Object = JSON.parse(raw) as Object
      if (!Array.isArray(parsed)) {
        return []
      }
      const ids: number[] = []
      ;(parsed as Object[]).forEach((value: Object): void => {
        const id: number = Number(value)
        if (Number.isFinite(id) && id > 0 && ids.indexOf(Math.floor(id)) < 0) {
          ids.push(Math.floor(id))
        }
      })
      return ids
    } catch (error) {
      DiagnosticLogger.warn('account', 'cloud_blacklist_restore_failed', (error as Error).message)
      return []
    }
  }

  static async save(context: common.UIAbilityContext, ids: number[]): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(
        context,
        BLACKLIST_STORE,
      )
      store.putSync(KEY_BLACKLIST_IDS, JSON.stringify(ids))
      store.flushSync()
    } catch (error) {
      DiagnosticLogger.warn('account', 'cloud_blacklist_save_failed', (error as Error).message)
    }
  }
}
