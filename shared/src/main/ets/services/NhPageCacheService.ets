import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { LocalDataStore } from '../storage/LocalDataStore'
import { NhGalleryDetailCacheService } from './NhGalleryDetailCacheService'
import { CacheStat } from './CacheStat'

const SQL_STAT: string =
  'SELECT (' +
  'SELECT COUNT(*) FROM nh_gallery_list_cache' +
  ') + (' +
  'SELECT COUNT(*) FROM nh_gallery_detail_cache WHERE expires_at > ?' +
  ') AS c, (' +
  'SELECT COALESCE(SUM(LENGTH(payload)), 0) FROM nh_gallery_list_cache' +
  ') + (' +
  'SELECT COALESCE(SUM(LENGTH(payload)), 0) FROM nh_gallery_detail_cache WHERE expires_at > ?' +
  ') AS b'
const SQL_CLEAR_LIST: string = 'DELETE FROM nh_gallery_list_cache'
const SQL_CLEAR_DETAIL: string = 'DELETE FROM nh_gallery_detail_cache'

/**
 * Settings-surface aggregate for the durable page cache: Home/Favorites
 * page-one snapshots (nh_gallery_list_cache, display-only until overwritten)
 * plus unexpired gallery-detail payloads (nh_gallery_detail_cache). This is
 * NextE's "page cache" row equivalent; clearing never touches reading
 * history, tag data, or account state.
 */
export class NhPageCacheService {
  static async stat(context: common.UIAbilityContext): Promise<CacheStat> {
    const out: CacheStat = new CacheStat()
    const now: number = Date.now()
    try {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      const rs: relationalStore.ResultSet = await store.querySql(SQL_STAT, [now, now])
      try {
        if (rs.goToFirstRow()) {
          out.count = rs.getLong(rs.getColumnIndex('c'))
          out.bytes = rs.getLong(rs.getColumnIndex('b'))
        }
      } finally {
        rs.close()
      }
    } catch (_error) {
      // An unreadable cache stays displayed as empty; the storage page already
      // surfaces load failures through its own error row.
    }
    return out
  }

  static async clearAll(context: common.UIAbilityContext): Promise<void> {
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    await store.executeSql(SQL_CLEAR_LIST)
    await store.executeSql(SQL_CLEAR_DETAIL)
    NhGalleryDetailCacheService.clearRecentMemory()
  }
}
