import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { NhCatalogPreferences } from '../model/NhCatalogPreferences'
import { LocalDataStore } from './LocalDataStore'

const BROWSE_LANGUAGE_KEY: string = 'browse_language'
const BROWSE_SORT_KEY: string = 'browse_sort'
const SEARCH_LANGUAGE_KEY: string = 'search_language'
const SEARCH_SORT_KEY: string = 'search_sort'
const SQL_SELECT: string = 'SELECT key, value FROM catalog_preferences'
const SQL_UPSERT: string =
  'INSERT INTO catalog_preferences (key, value) VALUES (?, ?) ' +
  'ON CONFLICT(key) DO UPDATE SET value = excluded.value'

/** Serialized local-only storage for catalog defaults; it has no account or remote scope. */
export class CatalogPreferencesRepository {
  private static writeTail: Promise<void> = Promise.resolve()

  static async load(context: common.UIAbilityContext): Promise<NhCatalogPreferences> {
    const preferences: NhCatalogPreferences = new NhCatalogPreferences()
    let rows: relationalStore.ResultSet | null = null
    try {
      await CatalogPreferencesRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql(SQL_SELECT)
      while (rows.goToNextRow()) {
        const keyColumn: number = rows.getColumnIndex('key')
        const valueColumn: number = rows.getColumnIndex('value')
        if (rows.isColumnNull(keyColumn) || rows.isColumnNull(valueColumn)) {
          continue
        }
        const key: string = rows.getString(keyColumn)
        const value: string = rows.getString(valueColumn)
        if (key === BROWSE_LANGUAGE_KEY) {
          preferences.browseLanguage = NhCatalogPreferences.normalizeLanguage(value)
        } else if (key === BROWSE_SORT_KEY) {
          preferences.browseSort = NhCatalogPreferences.normalizeSort(value)
        } else if (key === SEARCH_LANGUAGE_KEY) {
          preferences.searchLanguage = NhCatalogPreferences.normalizeLanguage(value)
        } else if (key === SEARCH_SORT_KEY) {
          preferences.searchSort = NhCatalogPreferences.normalizeSort(value)
        }
      }
      return NhCatalogPreferences.normalized(preferences)
    } catch (error) {
      throw error as Error
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (_error) {}
      }
    }
  }

  static save(context: common.UIAbilityContext, preferences: NhCatalogPreferences): Promise<void> {
    const snapshot: NhCatalogPreferences = NhCatalogPreferences.normalized(preferences)
    return CatalogPreferencesRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT, [BROWSE_LANGUAGE_KEY, snapshot.browseLanguage])
      await store.executeSql(SQL_UPSERT, [BROWSE_SORT_KEY, snapshot.browseSort])
      await store.executeSql(SQL_UPSERT, [SEARCH_LANGUAGE_KEY, snapshot.searchLanguage])
      await store.executeSql(SQL_UPSERT, [SEARCH_SORT_KEY, snapshot.searchSort])
    })
  }

  private static enqueueWrite(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = CatalogPreferencesRepository.writeTail.then(operation, operation)
    CatalogPreferencesRepository.writeTail = queued.catch((): void => {})
    return queued
  }
}
