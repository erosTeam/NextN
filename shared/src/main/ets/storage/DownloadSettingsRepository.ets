import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { NhDownloadSettings } from '../model/NhDownloadSettings'
import { LocalDataStore } from './LocalDataStore'

const GALLERY_CONCURRENCY_KEY: string = 'gallery_concurrency'
const PAGE_CONCURRENCY_KEY: string = 'page_concurrency'
const RETRY_COUNT_KEY: string = 'retry_count'
const NOTIFY_ON_COMPLETE_KEY: string = 'notify_on_complete'
const REQUEST_INTERVAL_KEY: string = 'request_interval_seconds'
const AUTO_RETRY_KEY: string = 'auto_retry_failed'
const SPEED_LIMIT_KEY: string = 'speed_limit_kbps'
const SQL_SELECT: string = 'SELECT key, value FROM download_settings'
const SQL_UPSERT: string =
  'INSERT INTO download_settings (key, value) VALUES (?, ?) ' +
  'ON CONFLICT(key) DO UPDATE SET value = excluded.value'

/** Serialized RDB store for the conservative private-download policy. */
export class DownloadSettingsRepository {
  private static writeTail: Promise<void> = Promise.resolve()

  static async load(context: common.UIAbilityContext): Promise<NhDownloadSettings> {
    const settings: NhDownloadSettings = new NhDownloadSettings()
    let rows: relationalStore.ResultSet | null = null
    try {
      await DownloadSettingsRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql(SQL_SELECT)
      while (rows.goToNextRow()) {
        const keyColumn: number = rows.getColumnIndex('key')
        const valueColumn: number = rows.getColumnIndex('value')
        if (rows.isColumnNull(keyColumn) || rows.isColumnNull(valueColumn)) {
          continue
        }
        const key: string = rows.getString(keyColumn)
        const value: number = Number(rows.getString(valueColumn))
        if (key === GALLERY_CONCURRENCY_KEY) {
          settings.maxConcurrentGalleries = value
        } else if (key === PAGE_CONCURRENCY_KEY) {
          settings.maxConcurrentPages = value
        } else if (key === RETRY_COUNT_KEY) {
          settings.retryCount = value
        } else if (key === NOTIFY_ON_COMPLETE_KEY) {
          settings.notifyOnComplete = value === 1
        } else if (key === REQUEST_INTERVAL_KEY) {
          settings.requestIntervalSeconds = value
        } else if (key === AUTO_RETRY_KEY) {
          settings.autoRetryFailed = value === 1
        } else if (key === SPEED_LIMIT_KEY) {
          settings.speedLimitKbps = value
        }
      }
    } catch (error) {
      throw error as Error
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (_error) {}
      }
    }
    return settings
  }

  static save(context: common.UIAbilityContext, settings: NhDownloadSettings): Promise<void> {
    const snapshot: NhDownloadSettings = settings.copy()
    return DownloadSettingsRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT, [GALLERY_CONCURRENCY_KEY, `${snapshot.maxConcurrentGalleries}`])
      await store.executeSql(SQL_UPSERT, [PAGE_CONCURRENCY_KEY, `${snapshot.maxConcurrentPages}`])
      await store.executeSql(SQL_UPSERT, [RETRY_COUNT_KEY, `${snapshot.retryCount}`])
      await store.executeSql(SQL_UPSERT, [NOTIFY_ON_COMPLETE_KEY, snapshot.notifyOnComplete ? '1' : '0'])
      await store.executeSql(SQL_UPSERT, [REQUEST_INTERVAL_KEY, `${snapshot.requestIntervalSeconds}`])
      await store.executeSql(SQL_UPSERT, [AUTO_RETRY_KEY, snapshot.autoRetryFailed ? '1' : '0'])
      await store.executeSql(SQL_UPSERT, [SPEED_LIMIT_KEY, `${snapshot.speedLimitKbps}`])
    })
  }

  private static enqueueWrite(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = DownloadSettingsRepository.writeTail.then(operation, operation)
    DownloadSettingsRepository.writeTail = queued.catch((): void => {})
    return queued
  }

  /** Backup export: whole download_settings key-value table. */
  static async exportForBackup(context: common.UIAbilityContext): Promise<Record<string, string>> {
    const out: Record<string, string> = {}
    let rows: relationalStore.ResultSet | null = null
    try {
      await DownloadSettingsRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql('SELECT key, value FROM download_settings')
      while (rows.goToNextRow()) {
        const keyColumn: number = rows.getColumnIndex('key')
        const valueColumn: number = rows.getColumnIndex('value')
        if (!rows.isColumnNull(keyColumn) && !rows.isColumnNull(valueColumn)) {
          out[rows.getString(keyColumn)] = rows.getString(valueColumn)
        }
      }
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (_error) {}
      }
    }
    return out
  }

  /** Backup restore: authoritative replacement of the download_settings table. */
  static async restoreBackup(context: common.UIAbilityContext, values: Record<string, string>): Promise<void> {
    await DownloadSettingsRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql('DELETE FROM download_settings')
      const keys: string[] = Object.keys(values)
      for (let i: number = 0; i < keys.length; i++) {
        await store.executeSql(SQL_UPSERT, [keys[i], values[keys[i]]])
      }
    })
  }
}
