import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { LocalDataStore } from './LocalDataStore'

const DETAIL_CACHE_TTL_MS: number = 6 * 60 * 60 * 1000
const MAX_DETAIL_CACHE_ROWS: number = 128
const SQL_SELECT: string =
  'SELECT payload, expires_at FROM nh_gallery_detail_cache WHERE gallery_id = ? LIMIT 1'
const SQL_TOUCH: string =
  'UPDATE nh_gallery_detail_cache SET accessed_at = ? WHERE gallery_id = ?'
const SQL_UPSERT: string =
  'INSERT OR REPLACE INTO nh_gallery_detail_cache ' +
  '(gallery_id, payload, cached_at, expires_at, accessed_at) VALUES (?, ?, ?, ?, ?)'
const SQL_DELETE_EXACT: string = 'DELETE FROM nh_gallery_detail_cache WHERE gallery_id = ?'
const SQL_DELETE_EXPIRED: string = 'DELETE FROM nh_gallery_detail_cache WHERE expires_at <= ?'
const SQL_PRUNE: string =
  'DELETE FROM nh_gallery_detail_cache WHERE gallery_id NOT IN (' +
  'SELECT gallery_id FROM nh_gallery_detail_cache ORDER BY accessed_at DESC LIMIT ?' +
  ')'

/** A valid persisted payload together with its existing expiry boundary. */
export class NhGalleryDetailCachePayload {
  payload: string = ''
  expiresAt: number = 0
}

/** RDB storage for anonymous public Detail payloads; page and account state remain outside this boundary. */
export class NhGalleryDetailCacheRepository {
  static async load(
    context: common.UIAbilityContext,
    galleryId: number,
  ): Promise<NhGalleryDetailCachePayload | null> {
    const normalizedGalleryId: number = NhGalleryDetailCacheRepository.galleryId(galleryId)
    if (normalizedGalleryId <= 0) {
      return null
    }
    const now: number = Date.now()
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    let rows: relationalStore.ResultSet | null = null
    let found: boolean = false
    let payload: string = ''
    let expiresAt: number = 0
    try {
      rows = await store.querySql(SQL_SELECT, [normalizedGalleryId])
      if (rows.goToFirstRow()) {
        found = true
        const payloadColumn: number = rows.getColumnIndex('payload')
        const expiresColumn: number = rows.getColumnIndex('expires_at')
        payload = payloadColumn < 0 || rows.isColumnNull(payloadColumn) ? '' : rows.getString(payloadColumn)
        expiresAt = expiresColumn < 0 || rows.isColumnNull(expiresColumn) ? 0 : rows.getLong(expiresColumn)
      }
    } finally {
      if (rows !== null) {
        rows.close()
      }
    }
    if (!found || payload.length === 0 || expiresAt <= now) {
      if (found) {
        try {
          await store.executeSql(SQL_DELETE_EXACT, [normalizedGalleryId])
        } catch (_error) {
        }
      }
      return null
    }
    try {
      await store.executeSql(SQL_TOUCH, [now, normalizedGalleryId])
    } catch (_error) {
      // A valid cache hit remains usable if its best-effort LRU touch fails.
    }
    const result: NhGalleryDetailCachePayload = new NhGalleryDetailCachePayload()
    result.payload = payload
    result.expiresAt = expiresAt
    return result
  }

  static async save(context: common.UIAbilityContext, galleryId: number, payload: string): Promise<void> {
    const normalizedGalleryId: number = NhGalleryDetailCacheRepository.galleryId(galleryId)
    if (normalizedGalleryId <= 0 || payload.length === 0) {
      throw new Error('Gallery detail cache record is invalid')
    }
    const now: number = Date.now()
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    let transactionOpen: boolean = false
    try {
      store.beginTransaction()
      transactionOpen = true
      await store.executeSql(SQL_UPSERT, [
        normalizedGalleryId,
        payload,
        now,
        now + DETAIL_CACHE_TTL_MS,
        now,
      ])
      await store.executeSql(SQL_DELETE_EXPIRED, [now])
      await store.executeSql(SQL_PRUNE, [MAX_DETAIL_CACHE_ROWS])
      store.commit()
      transactionOpen = false
    } catch (error) {
      if (transactionOpen) {
        store.rollBack()
      }
      throw error as Error
    }
  }

  static async discard(context: common.UIAbilityContext, galleryId: number): Promise<void> {
    const normalizedGalleryId: number = NhGalleryDetailCacheRepository.galleryId(galleryId)
    if (normalizedGalleryId <= 0) {
      return
    }
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    await store.executeSql(SQL_DELETE_EXACT, [normalizedGalleryId])
  }

  private static galleryId(value: number): number {
    const normalized: number = Math.floor(value)
    return Number.isSafeInteger(normalized) && normalized > 0 ? normalized : 0
  }
}
