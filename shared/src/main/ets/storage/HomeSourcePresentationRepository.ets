import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { NhBrowsePresentation } from '../model/NhBrowsePresentation'
import {
  HOME_SOURCE_LATEST,
  HOME_SOURCE_POPULAR,
  HOME_SOURCE_PRESENTATION_FOLLOW_GLOBAL,
  HomeSourceState,
  connectHomeSource,
} from '../state/HomeSourceState'
import { LocalDataStore } from './LocalDataStore'

const LATEST_PRESENTATION_KEY: string = 'home_source_latest_presentation'
const POPULAR_PRESENTATION_KEY: string = 'home_source_popular_presentation'
const SQL_SELECT_PRESENTATION: string =
  'SELECT value FROM browse_presentation_settings WHERE key = ? LIMIT 1'
const SQL_UPSERT_PRESENTATION: string =
  'INSERT INTO browse_presentation_settings (key, value) VALUES (?, ?) ' +
  'ON CONFLICT(key) DO UPDATE SET value = excluded.value'

/**
 * Durable NextE-style per-source display overrides for the two retained Home
 * sources. They intentionally share only the local key-value table with the
 * global Browse setting: keys and state publication stay independent.
 */
export class HomeSourcePresentationRepository {
  private static writeTail: Promise<void> = Promise.resolve()

  static async restore(context: common.UIAbilityContext): Promise<void> {
    await HomeSourcePresentationRepository.writeTail
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const state: HomeSourceState = connectHomeSource()
    state.setPresentationOverride(
      HOME_SOURCE_LATEST,
      HomeSourceState.normalizePresentationOverride(
        await HomeSourcePresentationRepository.readValue(store, LATEST_PRESENTATION_KEY),
      ),
    )
    state.setPresentationOverride(
      HOME_SOURCE_POPULAR,
      HomeSourceState.normalizePresentationOverride(
        await HomeSourcePresentationRepository.readValue(store, POPULAR_PRESENTATION_KEY),
      ),
    )
  }

  static save(
    context: common.UIAbilityContext,
    sourceKey: string,
    override: NhBrowsePresentation | null,
  ): Promise<void> {
    const normalized: NhBrowsePresentation | null = override === null
      ? null
      : HomeSourceState.normalizePresentationOverride(override)
    const normalizedSourceKey: string = sourceKey === HOME_SOURCE_POPULAR
      ? HOME_SOURCE_POPULAR
      : HOME_SOURCE_LATEST
    connectHomeSource().setPresentationOverride(normalizedSourceKey, normalized)
    const key: string = normalizedSourceKey === HOME_SOURCE_POPULAR
      ? POPULAR_PRESENTATION_KEY
      : LATEST_PRESENTATION_KEY
    const stored: string = normalized === null ? HOME_SOURCE_PRESENTATION_FOLLOW_GLOBAL : normalized
    return HomeSourcePresentationRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT_PRESENTATION, [key, stored])
    })
  }

  private static async readValue(store: relationalStore.RdbStore, key: string): Promise<string> {
    let rows: relationalStore.ResultSet | null = null
    try {
      rows = await store.querySql(SQL_SELECT_PRESENTATION, [key])
      if (!rows.goToNextRow()) {
        return ''
      }
      const column: number = rows.getColumnIndex('value')
      return rows.isColumnNull(column) ? '' : rows.getString(column)
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (_error) {}
      }
    }
  }

  private static enqueueWrite(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = HomeSourcePresentationRepository.writeTail.then(operation, operation)
    HomeSourcePresentationRepository.writeTail = queued.catch((): void => {})
    return queued
  }
}
