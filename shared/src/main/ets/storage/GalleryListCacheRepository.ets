import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { NhGallerySummary, NhTag } from '../model/NhGallery'
import { LocalDataStore } from './LocalDataStore'

const CACHE_RECORD_VERSION: number = 1
const MAX_CACHE_PAYLOAD_CHARS: number = 1_200_000
const SQL_LOAD: string =
  'SELECT payload FROM nh_gallery_list_cache WHERE cache_key = ? LIMIT 1'
const SQL_UPSERT: string =
  'INSERT INTO nh_gallery_list_cache (cache_key, payload, cached_at) VALUES (?, ?, ?) ' +
  'ON CONFLICT(cache_key) DO UPDATE SET payload = excluded.payload, cached_at = excluded.cached_at'
const SQL_DELETE_PREFIX: string = 'DELETE FROM nh_gallery_list_cache WHERE cache_key LIKE ?'

class GalleryListCacheEnvelope {
  v: number = 0
  galleries: NhGallerySummary[] = []
}

/**
 * Durable page-one gallery snapshots for Home/Favorites cold starts.
 *
 * Cache rows are display-only: every read is immediately followed by the
 * normal network/authenticated refresh. The favorites key is cleared on
 * sign-out so a later account cannot inherit the previous account's rows.
 */
export class GalleryListCacheRepository {
  private static writeTail: Promise<void> = Promise.resolve()

  static async load(
    context: common.UIAbilityContext,
    cacheKey: string,
  ): Promise<NhGallerySummary[] | null> {
    if (cacheKey.length === 0) {
      return null
    }
    let payload: string = ''
    try {
      await GalleryListCacheRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      let rows: relationalStore.ResultSet | null = null
      try {
        rows = await store.querySql(SQL_LOAD, [cacheKey])
        if (rows.goToFirstRow()) {
          const column: number = rows.getColumnIndex('payload')
          payload = column < 0 || rows.isColumnNull(column) ? '' : rows.getString(column)
        }
      } finally {
        if (rows !== null) {
          rows.close()
        }
      }
    } catch (_error) {
      return null
    }
    return GalleryListCacheRepository.decode(payload)
  }

  static save(
    context: common.UIAbilityContext,
    cacheKey: string,
    galleries: NhGallerySummary[],
  ): Promise<void> {
    if (cacheKey.length === 0) {
      return Promise.resolve()
    }
    const payload: string = JSON.stringify({
      v: CACHE_RECORD_VERSION,
      galleries: galleries,
    })
    if (payload.length === 0 || payload.length > MAX_CACHE_PAYLOAD_CHARS) {
      return Promise.resolve()
    }
    return GalleryListCacheRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT, [cacheKey, payload, Date.now()])
    })
  }

  static clearPrefix(context: common.UIAbilityContext, prefix: string): Promise<void> {
    if (prefix.length === 0) {
      return Promise.resolve()
    }
    return GalleryListCacheRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_DELETE_PREFIX, [`${prefix}%`])
    })
  }

  private static decode(payload: string): NhGallerySummary[] | null {
    if (payload.length === 0 || payload.length > MAX_CACHE_PAYLOAD_CHARS) {
      return null
    }
    let record: GalleryListCacheEnvelope | null = null
    try {
      record = JSON.parse(payload) as GalleryListCacheEnvelope
    } catch (_error) {
      return null
    }
    if (record === null || typeof record !== 'object' ||
      record.v !== CACHE_RECORD_VERSION ||
      !Array.isArray(record.galleries)) {
      return null
    }
    const result: NhGallerySummary[] = []
    for (let index: number = 0; index < record.galleries.length; index++) {
      const source: NhGallerySummary = record.galleries[index]
      if (source === null || typeof source !== 'object' ||
        typeof source.id !== 'number' || typeof source.pageCount !== 'number' ||
        typeof source.thumbnailWidth !== 'number' || typeof source.thumbnailHeight !== 'number' ||
        source.id <= 0 || source.pageCount < 0 ||
        source.thumbnailWidth < 0 || source.thumbnailHeight < 0) {
        continue
      }
      const gallery: NhGallerySummary = new NhGallerySummary()
      gallery.id = Math.floor(source.id)
      gallery.mediaId = GalleryListCacheRepository.text(source.mediaId)
      gallery.englishTitle = GalleryListCacheRepository.text(source.englishTitle)
      gallery.japaneseTitle = GalleryListCacheRepository.text(source.japaneseTitle)
      gallery.thumbnailUrl = GalleryListCacheRepository.text(source.thumbnailUrl)
      gallery.pageCount = Math.floor(source.pageCount)
      gallery.uploadDate = GalleryListCacheRepository.nonNegativeNumber(source.uploadDate)
      gallery.favoriteCount = GalleryListCacheRepository.nonNegativeNumber(source.favoriteCount)
      gallery.thumbnailWidth = Math.floor(source.thumbnailWidth)
      gallery.thumbnailHeight = Math.floor(source.thumbnailHeight)
      gallery.tagIds = GalleryListCacheRepository.idList(source.tagIds)
      gallery.tags = GalleryListCacheRepository.tagList(source.tags)
      result.push(gallery)
    }
    return result.length === 0 ? null : result
  }

  private static text(value: string): string {
    return typeof value === 'string' ? (value as string) : ''
  }

  private static nonNegativeNumber(value: number): number {
    if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) {
      return 0
    }
    return Math.floor(value)
  }

  private static idList(value: number[]): number[] {
    if (!Array.isArray(value)) {
      return []
    }
    const ids: number[] = []
    for (let index: number = 0; index < value.length; index++) {
      if (typeof value[index] === 'number' && value[index] > 0) {
        ids.push(Math.floor(value[index]))
      }
    }
    return ids
  }

  private static tagList(value: NhTag[]): NhTag[] {
    if (!Array.isArray(value)) {
      return []
    }
    const tags: NhTag[] = []
    for (let index: number = 0; index < value.length; index++) {
      const source: NhTag = value[index]
      if (source === null || typeof source !== 'object' ||
        typeof source.id !== 'number' || typeof source.count !== 'number' ||
        source.id <= 0 || source.count < 0) {
        continue
      }
      const tag: NhTag = new NhTag()
      tag.id = Math.floor(source.id)
      tag.type = GalleryListCacheRepository.text(source.type)
      tag.name = GalleryListCacheRepository.text(source.name)
      tag.count = Math.floor(source.count)
      // Keep the resolved display label: a cold-start card or detail seed
      // must never paint raw English before the dictionary lookup
      // finishes. Live reads and the dictionary revision path re-apply
      // the current dictionary, so a stale label is self-correcting.
      tag.displayName = GalleryListCacheRepository.text(source.displayName)
      tags.push(tag)
    }
    return tags
  }

  private static enqueueWrite(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = GalleryListCacheRepository.writeTail.then(operation, operation)
    GalleryListCacheRepository.writeTail = queued.catch((): void => {})
    return queued
  }
}
