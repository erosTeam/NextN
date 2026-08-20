import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { NhGalleryDetail, NhReadingHistoryItem } from '../model/NhGallery'
import { connectNhReadProgress } from '../state/NhReadProgressState'
import { connectReadingHistory } from '../state/ReadingHistoryState'
import { LocalDataStore } from './LocalDataStore'
const SQL_UPSERT_OPEN: string =
  'INSERT INTO reading_history (gallery_id, media_id, title, thumbnail_url, page_count, last_read_index, has_read_progress, last_opened_at) ' +
  'VALUES (?, ?, ?, ?, ?, 0, 0, ?) ON CONFLICT(gallery_id) DO UPDATE SET ' +
  'media_id = excluded.media_id, title = excluded.title, thumbnail_url = excluded.thumbnail_url, ' +
  'page_count = excluded.page_count, last_opened_at = excluded.last_opened_at'
const SQL_UPSERT_PROGRESS: string =
  'INSERT INTO reading_history (gallery_id, media_id, title, thumbnail_url, page_count, last_read_index, has_read_progress, last_opened_at) ' +
  'VALUES (?, ?, ?, ?, ?, ?, 1, ?) ON CONFLICT(gallery_id) DO UPDATE SET ' +
  'media_id = excluded.media_id, title = excluded.title, thumbnail_url = excluded.thumbnail_url, ' +
  'page_count = excluded.page_count, last_read_index = excluded.last_read_index, ' +
  'has_read_progress = excluded.has_read_progress, last_opened_at = excluded.last_opened_at'
const SQL_SELECT_PROGRESS: string =
  'SELECT last_read_index FROM reading_history WHERE gallery_id = ? LIMIT 1'
const SQL_SELECT_HAS_READ_PROGRESS: string =
  'SELECT has_read_progress FROM reading_history WHERE gallery_id = ? LIMIT 1'
const MAX_PAGE_SIZE: number = 100
const SQL_SELECT_ALL: string =
  'SELECT gallery_id, media_id, title, thumbnail_url, page_count, last_read_index, has_read_progress, last_opened_at ' +
  'FROM reading_history ORDER BY last_opened_at DESC, gallery_id DESC'
const SQL_SELECT_PAGE: string =
  'SELECT gallery_id, media_id, title, thumbnail_url, page_count, last_read_index, has_read_progress, last_opened_at ' +
  'FROM reading_history WHERE gallery_id > 0 ORDER BY last_opened_at DESC, gallery_id DESC LIMIT ?'
const SQL_SELECT_PAGE_AFTER: string =
  'SELECT gallery_id, media_id, title, thumbnail_url, page_count, last_read_index, has_read_progress, last_opened_at ' +
  'FROM reading_history WHERE gallery_id > 0 AND ' +
  '(last_opened_at < ? OR (last_opened_at = ? AND gallery_id < ?)) ' +
  'ORDER BY last_opened_at DESC, gallery_id DESC LIMIT ?'
const SQL_SELECT_SEARCH_PAGE: string =
  'SELECT gallery_id, media_id, title, thumbnail_url, page_count, last_read_index, has_read_progress, last_opened_at ' +
  'FROM reading_history WHERE gallery_id > 0 AND ' +
  '(LOWER(COALESCE(title, \'\')) LIKE ? OR CAST(gallery_id AS TEXT) LIKE ?) ' +
  'ORDER BY last_opened_at DESC, gallery_id DESC LIMIT ?'
const SQL_SELECT_SEARCH_PAGE_AFTER: string =
  'SELECT gallery_id, media_id, title, thumbnail_url, page_count, last_read_index, has_read_progress, last_opened_at ' +
  'FROM reading_history WHERE gallery_id > 0 AND ' +
  '(LOWER(COALESCE(title, \'\')) LIKE ? OR CAST(gallery_id AS TEXT) LIKE ?) AND ' +
  '(last_opened_at < ? OR (last_opened_at = ? AND gallery_id < ?)) ' +
  'ORDER BY last_opened_at DESC, gallery_id DESC LIMIT ?'
const SQL_COUNT_ALL: string = 'SELECT COUNT(*) AS total_count FROM reading_history WHERE gallery_id > 0'
const SQL_COUNT_SEARCH: string =
  'SELECT COUNT(*) AS total_count FROM reading_history WHERE gallery_id > 0 AND ' +
  '(LOWER(COALESCE(title, \'\')) LIKE ? OR CAST(gallery_id AS TEXT) LIKE ?)'
const SQL_DELETE_ONE: string = 'DELETE FROM reading_history WHERE gallery_id = ?'
const SQL_DELETE_ALL: string = 'DELETE FROM reading_history'

/** Durable keyset cursor matching the repository's deterministic descending order. */
export class HistoryCursor {
  lastOpenedAt: number
  galleryId: number

  constructor(lastOpenedAt: number = 0, galleryId: number = 0) {
    this.lastOpenedAt = lastOpenedAt
    this.galleryId = galleryId
  }
}

/** One bounded local history query result. */
export class HistoryPageResult {
  items: NhReadingHistoryItem[] = []
  nextCursor: HistoryCursor | null = null
  hasMore: boolean = false
  totalCount: number = 0
}

/**
 * Small RDB repository for the first native user-data contract. Reads and
 * writes happen only in response to local browse/reader interactions.
 */
export class HistoryRepository {
  private static writeTail: Promise<void> = Promise.resolve()

  static async recordOpen(context: common.UIAbilityContext, detail: NhGalleryDetail): Promise<void> {
    if (detail.id <= 0) {
      return
    }
    await HistoryRepository.enqueueWrite((): Promise<void> =>
      HistoryRepository.executeWrite(context, SQL_UPSERT_OPEN, HistoryRepository.openValues(detail)),
    )
    HistoryRepository.publishMutation()
  }

  static async saveProgress(
    context: common.UIAbilityContext,
    detail: NhGalleryDetail,
    pageIndex: number,
  ): Promise<void> {
    if (detail.id <= 0) {
      return
    }
    const clamped: number = Math.min(
      Math.max(0, Math.floor(pageIndex)),
      Math.max(0, detail.pages.length - 1),
    )
    // Publish every canonical Reader position immediately. Retained Detail
    // snapshots this state and controls when the final value becomes visible.
    connectNhReadProgress().set(detail.id, clamped)
    await HistoryRepository.enqueueWrite((): Promise<void> =>
      HistoryRepository.executeWrite(context, SQL_UPSERT_PROGRESS, HistoryRepository.values(detail, clamped)),
    )
    HistoryRepository.publishMutation()
  }

  static async progress(context: common.UIAbilityContext, galleryId: number): Promise<number> {
    let rows: relationalStore.ResultSet | null = null
    try {
      await HistoryRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql(SQL_SELECT_PROGRESS, [galleryId])
      if (!rows.goToNextRow()) {
        return 0
      }
      const index: number = rows.getColumnIndex('last_read_index')
      return rows.isColumnNull(index) ? 0 : Math.max(0, Math.floor(rows.getDouble(index)))
    } catch (error) {
      throw (error as Error)
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (error) {
          throw (error as Error)
        }
      }
    }
  }

  /**
   * Reads only durable, on-device resume truth. A zero-based page index alone
   * cannot answer this question because page zero is a valid Reader position.
   */
  static async hasReadProgress(context: common.UIAbilityContext, galleryId: number): Promise<boolean> {
    if (galleryId <= 0) {
      return false
    }
    let rows: relationalStore.ResultSet | null = null
    try {
      await HistoryRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql(SQL_SELECT_HAS_READ_PROGRESS, [galleryId])
      if (!rows.goToNextRow()) {
        return false
      }
      const index: number = rows.getColumnIndex('has_read_progress')
      return !rows.isColumnNull(index) && rows.getDouble(index) > 0
    } catch (error) {
      throw (error as Error)
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (error) {
          throw (error as Error)
        }
      }
    }
  }

  static async loadAll(context: common.UIAbilityContext): Promise<NhReadingHistoryItem[]> {
    let rows: relationalStore.ResultSet | null = null
    const items: NhReadingHistoryItem[] = []
    try {
      await HistoryRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql(SQL_SELECT_ALL)
      while (rows.goToNextRow()) {
        const item: NhReadingHistoryItem = new NhReadingHistoryItem()
        item.galleryId = HistoryRepository.numberColumn(rows, 'gallery_id')
        item.mediaId = HistoryRepository.stringColumn(rows, 'media_id')
        item.title = HistoryRepository.stringColumn(rows, 'title')
        item.thumbnailUrl = HistoryRepository.stringColumn(rows, 'thumbnail_url')
        item.pageCount = HistoryRepository.numberColumn(rows, 'page_count')
        item.lastReadIndex = HistoryRepository.numberColumn(rows, 'last_read_index')
        item.hasReadProgress = HistoryRepository.numberColumn(rows, 'has_read_progress') > 0
        item.lastOpenedAt = HistoryRepository.numberColumn(rows, 'last_opened_at')
        if (item.galleryId > 0) {
          items.push(item)
        }
      }
    } catch (error) {
      throw (error as Error)
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (error) {
          throw (error as Error)
        }
      }
    }
    return items
  }

  /**
   * Bounded, local-only keyset page. The timestamp/id pair prevents duplicates
   * when several opens share the same millisecond and remains stable if a new
   * history row is inserted ahead of the current cursor.
   */
  static async loadPage(
    context: common.UIAbilityContext,
    limit: number,
    cursor: HistoryCursor | null = null,
    query: string = '',
  ): Promise<HistoryPageResult> {
    const pageSize: number = Math.min(MAX_PAGE_SIZE, Math.max(1, Math.floor(limit)))
    const queryLimit: number = pageSize + 1
    const normalizedQuery: string = query.trim().toLowerCase()
    const searchPattern: string = `%${normalizedQuery}%`
    let rows: relationalStore.ResultSet | null = null
    let countRows: relationalStore.ResultSet | null = null
    const items: NhReadingHistoryItem[] = []
    try {
      await HistoryRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      if (normalizedQuery.length === 0) {
        rows = cursor === null
          ? await store.querySql(SQL_SELECT_PAGE, [queryLimit])
          : await store.querySql(SQL_SELECT_PAGE_AFTER, [
            cursor.lastOpenedAt,
            cursor.lastOpenedAt,
            cursor.galleryId,
            queryLimit,
          ])
        countRows = await store.querySql(SQL_COUNT_ALL)
      } else {
        rows = cursor === null
          ? await store.querySql(SQL_SELECT_SEARCH_PAGE, [searchPattern, searchPattern, queryLimit])
          : await store.querySql(SQL_SELECT_SEARCH_PAGE_AFTER, [
            searchPattern,
            searchPattern,
            cursor.lastOpenedAt,
            cursor.lastOpenedAt,
            cursor.galleryId,
            queryLimit,
          ])
        countRows = await store.querySql(SQL_COUNT_SEARCH, [searchPattern, searchPattern])
      }
      while (rows.goToNextRow()) {
        items.push(HistoryRepository.readItem(rows))
      }
      const result: HistoryPageResult = new HistoryPageResult()
      if (countRows.goToNextRow()) {
        result.totalCount = HistoryRepository.numberColumn(countRows, 'total_count')
      }
      result.hasMore = items.length > pageSize
      if (result.hasMore) {
        items.pop()
      }
      result.items = items
      if (result.hasMore && items.length > 0) {
        const last: NhReadingHistoryItem = items[items.length - 1]
        result.nextCursor = new HistoryCursor(last.lastOpenedAt, last.galleryId)
      }
      return result
    } catch (error) {
      throw (error as Error)
    } finally {
      if (rows !== null) {
        rows.close()
      }
      if (countRows !== null) {
        countRows.close()
      }
    }
  }

  /** Remove one gallery's on-device resume position. This never touches a remote account. */
  static async remove(context: common.UIAbilityContext, galleryId: number): Promise<void> {
    if (galleryId <= 0) {
      return
    }
    await HistoryRepository.enqueueWrite((): Promise<void> =>
      HistoryRepository.executeWrite(context, SQL_DELETE_ONE, [galleryId]),
    )
    HistoryRepository.publishMutation()
  }

  /** Clear only the local reading-history table; no network or session state is involved. */
  static async clear(context: common.UIAbilityContext): Promise<void> {
    await HistoryRepository.enqueueWrite((): Promise<void> =>
      HistoryRepository.executeWrite(context, SQL_DELETE_ALL),
    )
    HistoryRepository.publishMutation()
  }

  /**
   * Serializes mutations so an older Reader save cannot race a later remove or
   * clear and recreate a local history row after the user has erased it.
   */
  private static enqueueWrite(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = HistoryRepository.writeTail.then(
      (): Promise<void> => operation(),
      (): Promise<void> => operation(),
    )
    HistoryRepository.writeTail = queued.catch((): void => {})
    return queued
  }

  /** Publish only after the serialized RDB write has committed successfully. */
  private static publishMutation(): void {
    connectReadingHistory().publishMutation()
  }

  private static async executeWrite(
    context: common.UIAbilityContext,
    sql: string,
    values?: (string | number)[],
  ): Promise<void> {
    try {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      if (values === undefined) {
        await store.executeSql(sql)
      } else {
        await store.executeSql(sql, values)
      }
    } catch (error) {
      throw (error as Error)
    }
  }

  private static openValues(detail: NhGalleryDetail): (string | number)[] {
    return [
      detail.id,
      detail.mediaId,
      detail.displayTitle(),
      detail.thumbnailUrl.length > 0 ? detail.thumbnailUrl : detail.coverUrl,
      detail.pageCount,
      Date.now(),
    ]
  }

  private static values(detail: NhGalleryDetail, pageIndex: number): (string | number)[] {
    return [
      detail.id,
      detail.mediaId,
      detail.displayTitle(),
      detail.thumbnailUrl.length > 0 ? detail.thumbnailUrl : detail.coverUrl,
      detail.pageCount,
      pageIndex,
      Date.now(),
    ]
  }

  private static readItem(rows: relationalStore.ResultSet): NhReadingHistoryItem {
    const item: NhReadingHistoryItem = new NhReadingHistoryItem()
    item.galleryId = HistoryRepository.numberColumn(rows, 'gallery_id')
    item.mediaId = HistoryRepository.stringColumn(rows, 'media_id')
    item.title = HistoryRepository.stringColumn(rows, 'title')
    item.thumbnailUrl = HistoryRepository.stringColumn(rows, 'thumbnail_url')
    item.pageCount = HistoryRepository.numberColumn(rows, 'page_count')
    item.lastReadIndex = HistoryRepository.numberColumn(rows, 'last_read_index')
    item.hasReadProgress = HistoryRepository.numberColumn(rows, 'has_read_progress') > 0
    item.lastOpenedAt = HistoryRepository.numberColumn(rows, 'last_opened_at')
    return item
  }

  private static stringColumn(rows: relationalStore.ResultSet, name: string): string {
    try {
      const index: number = rows.getColumnIndex(name)
      return rows.isColumnNull(index) ? '' : rows.getString(index)
    } catch (error) {
      throw (error as Error)
    }
  }

  private static numberColumn(rows: relationalStore.ResultSet, name: string): number {
    try {
      const index: number = rows.getColumnIndex(name)
      return rows.isColumnNull(index) ? 0 : Math.floor(rows.getDouble(index))
    } catch (error) {
      throw (error as Error)
    }
  }

  /** Backup export: all durable history rows (opened and resumed). */
  static async exportForBackup(context: common.UIAbilityContext): Promise<NhReadingHistoryItem[]> {
    return HistoryRepository.loadAll(context)
  }

  /** Backup restore: authoritative replacement of the whole reading-history table. */
  static async restoreBackup(context: common.UIAbilityContext, items: NhReadingHistoryItem[]): Promise<void> {
    await HistoryRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_DELETE_ALL)
      for (let i: number = 0; i < items.length; i++) {
        const item: NhReadingHistoryItem = items[i]
        if (item.galleryId <= 0) {
          continue
        }
        if (item.hasReadProgress) {
          await store.executeSql(SQL_UPSERT_PROGRESS, [
            item.galleryId,
            item.mediaId,
            item.title,
            item.thumbnailUrl,
            item.pageCount,
            item.lastReadIndex,
            item.lastOpenedAt,
          ])
        } else {
          await store.executeSql(SQL_UPSERT_OPEN, [
            item.galleryId,
            item.mediaId,
            item.title,
            item.thumbnailUrl,
            item.pageCount,
            item.lastOpenedAt,
          ])
        }
      }
    })
    HistoryRepository.publishMutation()
  }
}
