import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { NhSearchHistoryItem } from '../model/NhSearchHistory'
import { LocalDataStore } from './LocalDataStore'

const MAX_HISTORY_ITEMS: number = 50
const SQL_SELECT_ALL: string =
  'SELECT query_text, last_used_at FROM search_history ' +
  'ORDER BY last_used_at DESC, normalized_query ASC LIMIT ?'
const SQL_UPSERT: string =
  'INSERT INTO search_history (normalized_query, query_text, last_used_at) VALUES (?, ?, ?) ' +
  'ON CONFLICT(normalized_query) DO UPDATE SET query_text = excluded.query_text, ' +
  'last_used_at = excluded.last_used_at'
const SQL_TRIM: string =
  'DELETE FROM search_history WHERE normalized_query NOT IN (' +
  'SELECT normalized_query FROM search_history ' +
  'ORDER BY last_used_at DESC, normalized_query ASC LIMIT ?)'
const SQL_DELETE_ONE: string = 'DELETE FROM search_history WHERE normalized_query = ?'
const SQL_DELETE_ALL: string = 'DELETE FROM search_history'

/** Local anonymous search history, deliberately separate from reading progress. */
export class SearchHistoryRepository {
  /**
   * Search submit, item removal, and clear may arrive from adjacent retained
   * Search states. Keep their durable order so an older write cannot finish
   * after a later local deletion.
   */
  private static writeTail: Promise<void> = Promise.resolve()

  static async load(context: common.UIAbilityContext): Promise<NhSearchHistoryItem[]> {
    const items: NhSearchHistoryItem[] = []
    let rows: relationalStore.ResultSet | null = null
    try {
      await SearchHistoryRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql(SQL_SELECT_ALL, [MAX_HISTORY_ITEMS])
      while (rows.goToNextRow()) {
        const item: NhSearchHistoryItem = new NhSearchHistoryItem()
        item.query = SearchHistoryRepository.stringColumn(rows, 'query_text')
        item.lastUsedAt = SearchHistoryRepository.numberColumn(rows, 'last_used_at')
        if (item.query.length > 0) {
          items.push(item)
        }
      }
      return items
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

  /** Match ErosN's case-insensitive deduplication and 50-query retention policy. */
  static async record(context: common.UIAbilityContext, query: string): Promise<void> {
    const normalized: string = SearchHistoryRepository.normalizedQuery(query)
    if (normalized.length === 0) {
      return
    }
    await SearchHistoryRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT, [normalized.toLowerCase(), normalized, Date.now()])
      await store.executeSql(SQL_TRIM, [MAX_HISTORY_ITEMS])
    })
  }

  static async remove(context: common.UIAbilityContext, query: string): Promise<void> {
    const normalized: string = SearchHistoryRepository.normalizedQuery(query)
    if (normalized.length === 0) {
      return
    }
    await SearchHistoryRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_DELETE_ONE, [normalized.toLowerCase()])
    })
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    await SearchHistoryRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_DELETE_ALL)
    })
  }

  /** A failed mutation must not block a later explicit local operation. */
  private static enqueueWrite(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = SearchHistoryRepository.writeTail.then(
      (): Promise<void> => operation(),
      (): Promise<void> => operation(),
    )
    SearchHistoryRepository.writeTail = queued.catch((): void => {})
    return queued
  }

  private static normalizedQuery(query: string): string {
    return query.trim()
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
}
