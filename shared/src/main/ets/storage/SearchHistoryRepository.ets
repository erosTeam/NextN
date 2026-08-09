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
  static async load(context: common.UIAbilityContext): Promise<NhSearchHistoryItem[]> {
    const items: NhSearchHistoryItem[] = []
    let rows: relationalStore.ResultSet | null = null
    try {
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
    try {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT, [normalized.toLowerCase(), normalized, Date.now()])
      await store.executeSql(SQL_TRIM, [MAX_HISTORY_ITEMS])
    } catch (error) {
      throw (error as Error)
    }
  }

  static async remove(context: common.UIAbilityContext, query: string): Promise<void> {
    const normalized: string = SearchHistoryRepository.normalizedQuery(query)
    if (normalized.length === 0) {
      return
    }
    try {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_DELETE_ONE, [normalized.toLowerCase()])
    } catch (error) {
      throw (error as Error)
    }
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_DELETE_ALL)
    } catch (error) {
      throw (error as Error)
    }
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
