import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { NhQuickSearchItem } from '../model/NhQuickSearch'
import { LocalDataStore } from './LocalDataStore'

/** Keep the manually pinned search surface compact on phones and tablets. */
const MAX_QUICK_SEARCH_ITEMS: number = 12
const SQL_SELECT_ALL: string =
  'SELECT query_text, pinned_at FROM search_quick ' +
  'ORDER BY pinned_at DESC, normalized_query ASC LIMIT ?'
const SQL_UPSERT: string =
  'INSERT INTO search_quick (normalized_query, query_text, pinned_at) VALUES (?, ?, ?) ' +
  'ON CONFLICT(normalized_query) DO UPDATE SET query_text = excluded.query_text, ' +
  'pinned_at = excluded.pinned_at'
const SQL_TRIM: string =
  'DELETE FROM search_quick WHERE normalized_query NOT IN (' +
  'SELECT normalized_query FROM search_quick ' +
  'ORDER BY pinned_at DESC, normalized_query ASC LIMIT ?)'
const SQL_DELETE_ONE: string = 'DELETE FROM search_quick WHERE normalized_query = ?'

/**
 * Local-only user pins for repeatable public searches. This deliberately does
 * not share search_history, so clearing recents never deletes a quick search.
 */
export class QuickSearchRepository {
  /** Keep pin/remove persistence ordered across retained Search interactions. */
  private static writeTail: Promise<void> = Promise.resolve()

  static async load(context: common.UIAbilityContext): Promise<NhQuickSearchItem[]> {
    const items: NhQuickSearchItem[] = []
    let rows: relationalStore.ResultSet | null = null
    try {
      await QuickSearchRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql(SQL_SELECT_ALL, [MAX_QUICK_SEARCH_ITEMS])
      while (rows.goToNextRow()) {
        const item: NhQuickSearchItem = new NhQuickSearchItem()
        item.query = QuickSearchRepository.stringColumn(rows, 'query_text')
        item.pinnedAt = QuickSearchRepository.numberColumn(rows, 'pinned_at')
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

  /** Pin the trimmed expression with case-insensitive local deduplication. */
  static async pin(context: common.UIAbilityContext, query: string): Promise<void> {
    const normalized: string = QuickSearchRepository.normalizedQuery(query)
    if (normalized.length === 0) {
      return
    }
    await QuickSearchRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT, [normalized.toLowerCase(), normalized, Date.now()])
      await store.executeSql(SQL_TRIM, [MAX_QUICK_SEARCH_ITEMS])
    })
  }

  static async remove(context: common.UIAbilityContext, query: string): Promise<void> {
    const normalized: string = QuickSearchRepository.normalizedQuery(query)
    if (normalized.length === 0) {
      return
    }
    await QuickSearchRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_DELETE_ONE, [normalized.toLowerCase()])
    })
  }

  /** A failed mutation must not poison the following explicit local action. */
  private static enqueueWrite(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = QuickSearchRepository.writeTail.then(
      (): Promise<void> => operation(),
      (): Promise<void> => operation(),
    )
    QuickSearchRepository.writeTail = queued.catch((): void => {})
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
