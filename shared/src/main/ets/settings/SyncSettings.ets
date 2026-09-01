import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import {
  SYNC_STATUS_FAILED,
  SYNC_STATUS_IDLE,
  SYNC_STATUS_OK,
  connectSyncSettings,
} from '../state/SyncSettingsState'
import { SyncDatasetSelection } from '../sync/SyncTypes'

const SYNC_STORE: string = 'nextn_settings'
const WEBDAV_CONFIG_PERSIST_DELAY_MS: number = 250
const KEY_WEBDAV_URL: string = 'sync.webdav.url'
const KEY_WEBDAV_USERNAME: string = 'sync.webdav.username'
const KEY_WEBDAV_ENABLED: string = 'sync.webdav.enabled'
const KEY_WEBDAV_PASSWORD: string = 'sync.webdav.password'
const KEY_DATASET_READ_PROGRESS: string = 'sync.dataset.read_progress'
const KEY_DATASET_VIEWED_HISTORY: string = 'sync.dataset.viewed_history'
const KEY_DATASET_SEARCH_HISTORY: string = 'sync.dataset.search_history'
const KEY_DATASET_QUICK_SEARCHES: string = 'sync.dataset.quick_searches'
const KEY_DATASET_HOME_SUBTABS: string = 'sync.dataset.home_subtabs'
const KEY_DATASET_LOCAL_USER_TAGS: string = 'sync.dataset.local_user_tags'
const KEY_DATASET_LOCAL_BLOCK: string = 'sync.dataset.local_block'
const KEY_DATASET_SETTINGS_TABLES: string = 'sync.dataset.settings_tables'
const KEY_LAST_RUN_AT: string = 'sync.last_run_at'
const KEY_LAST_STATUS: string = 'sync.last_status'
const KEY_LAST_DETAIL: string = 'sync.last_detail'

/**
 * Serializes a latest-value settings write. An active write is allowed to finish, then the newest
 * pending snapshot follows it so an older asynchronous Preferences continuation cannot win.
 */
export class WebDavConfigPersistScheduler {
  private readonly delayMs: number
  private timer: number = -1
  private pendingWrite: (() => Promise<void>) | null = null
  private writeTail: Promise<void> = Promise.resolve()

  constructor(delayMs: number = WEBDAV_CONFIG_PERSIST_DELAY_MS) {
    this.delayMs = delayMs >= 0 ? delayMs : 0
  }

  schedule(write: () => Promise<void>): void {
    this.pendingWrite = write
    if (this.timer >= 0) {
      clearTimeout(this.timer)
    }
    this.timer = setTimeout(() => {
      this.timer = -1
      this.flush()
    }, this.delayMs)
  }

  flush(): Promise<void> {
    if (this.timer >= 0) {
      clearTimeout(this.timer)
      this.timer = -1
    }
    const write: (() => Promise<void>) | null = this.pendingWrite
    if (write === null) {
      return this.writeTail
    }
    this.pendingWrite = null
    this.writeTail = this.writeTail.then(write, write)
    return this.writeTail
  }
}

class WebDavConfigSnapshot {
  webdavUrl: string = ''
  webdavUsername: string = ''
  webdavPassword: string = ''
  webdavEnabled: boolean = false
}

/** Provider-neutral WebDAV sync settings snapshot (ported from NextE, NH datasets). */
export class SyncSettingsSnapshot {
  webdavUrl: string = ''
  webdavUsername: string = ''
  webdavPassword: string = ''
  webdavEnabled: boolean = false
  datasetReadProgress: boolean = true
  datasetViewedHistory: boolean = true
  datasetSearchHistory: boolean = true
  datasetQuickSearches: boolean = true
  datasetHomeSubtabs: boolean = true
  datasetLocalUserTags: boolean = true
  datasetLocalBlock: boolean = true
  datasetSettingsTables: boolean = true
  lastRunAt: number = 0
  lastStatus: string = SYNC_STATUS_IDLE
  lastDetail: string = ''
}

/** Sync provider settings. WebDAV password is intentionally local-only and never exported. */
export class SyncSettings {
  private static readonly webDavConfigPersistScheduler: WebDavConfigPersistScheduler =
    new WebDavConfigPersistScheduler()

  static apply(snapshot: SyncSettingsSnapshot): void {
    const state = connectSyncSettings()
    state.webdavUrl = snapshot.webdavUrl
    state.webdavUsername = snapshot.webdavUsername
    state.webdavPassword = snapshot.webdavPassword
    state.webdavEnabled = snapshot.webdavEnabled
    state.datasetReadProgress = snapshot.datasetReadProgress
    state.datasetViewedHistory = snapshot.datasetViewedHistory
    state.datasetSearchHistory = snapshot.datasetSearchHistory
    state.datasetQuickSearches = snapshot.datasetQuickSearches
    state.datasetHomeSubtabs = snapshot.datasetHomeSubtabs
    state.datasetLocalUserTags = snapshot.datasetLocalUserTags
    state.datasetLocalBlock = snapshot.datasetLocalBlock
    state.datasetSettingsTables = snapshot.datasetSettingsTables
    state.lastRunAt = Math.max(0, snapshot.lastRunAt)
    state.lastStatus = SyncSettings.normalizeStatus(snapshot.lastStatus)
    state.lastDetail = SyncSettings.normalizeDetail(snapshot.lastDetail)
  }

  static current(): SyncSettingsSnapshot {
    const state = connectSyncSettings()
    const snapshot = new SyncSettingsSnapshot()
    snapshot.webdavUrl = state.webdavUrl
    snapshot.webdavUsername = state.webdavUsername
    snapshot.webdavPassword = state.webdavPassword
    snapshot.webdavEnabled = state.webdavEnabled
    snapshot.datasetReadProgress = state.datasetReadProgress
    snapshot.datasetViewedHistory = state.datasetViewedHistory
    snapshot.datasetSearchHistory = state.datasetSearchHistory
    snapshot.datasetQuickSearches = state.datasetQuickSearches
    snapshot.datasetHomeSubtabs = state.datasetHomeSubtabs
    snapshot.datasetLocalUserTags = state.datasetLocalUserTags
    snapshot.datasetLocalBlock = state.datasetLocalBlock
    snapshot.datasetSettingsTables = state.datasetSettingsTables
    snapshot.lastRunAt = state.lastRunAt
    snapshot.lastStatus = SyncSettings.normalizeStatus(state.lastStatus)
    snapshot.lastDetail = SyncSettings.normalizeDetail(state.lastDetail)
    return snapshot
  }

  static selection(snapshot: SyncSettingsSnapshot): SyncDatasetSelection {
    const selection = new SyncDatasetSelection()
    selection.readProgress = snapshot.datasetReadProgress
    selection.viewedHistory = snapshot.datasetViewedHistory
    selection.searchHistory = snapshot.datasetSearchHistory
    selection.quickSearches = snapshot.datasetQuickSearches
    selection.homeSubtabs = snapshot.datasetHomeSubtabs
    selection.localUserTags = snapshot.datasetLocalUserTags
    selection.localBlock = snapshot.datasetLocalBlock
    selection.settingsTables = snapshot.datasetSettingsTables
    return selection
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, SYNC_STORE)
      const snapshot = new SyncSettingsSnapshot()
      snapshot.webdavUrl = store.getSync(KEY_WEBDAV_URL, '') as string
      snapshot.webdavUsername = store.getSync(KEY_WEBDAV_USERNAME, '') as string
      snapshot.webdavPassword = store.getSync(KEY_WEBDAV_PASSWORD, '') as string
      snapshot.webdavEnabled =
        store.getSync(KEY_WEBDAV_ENABLED, snapshot.webdavUrl.trim().length > 0) as boolean
      snapshot.datasetReadProgress = store.getSync(KEY_DATASET_READ_PROGRESS, true) as boolean
      snapshot.datasetViewedHistory = store.getSync(KEY_DATASET_VIEWED_HISTORY, true) as boolean
      snapshot.datasetSearchHistory = store.getSync(KEY_DATASET_SEARCH_HISTORY, true) as boolean
      snapshot.datasetQuickSearches = store.getSync(KEY_DATASET_QUICK_SEARCHES, true) as boolean
      snapshot.datasetHomeSubtabs = store.getSync(KEY_DATASET_HOME_SUBTABS, true) as boolean
      snapshot.datasetLocalUserTags = store.getSync(KEY_DATASET_LOCAL_USER_TAGS, true) as boolean
      snapshot.datasetLocalBlock = store.getSync(KEY_DATASET_LOCAL_BLOCK, true) as boolean
      snapshot.datasetSettingsTables = store.getSync(KEY_DATASET_SETTINGS_TABLES, true) as boolean
      snapshot.lastRunAt = store.getSync(KEY_LAST_RUN_AT, 0) as number
      snapshot.lastStatus = store.getSync(KEY_LAST_STATUS, SYNC_STATUS_IDLE) as string
      snapshot.lastDetail = store.getSync(KEY_LAST_DETAIL, '') as string
      SyncSettings.apply(snapshot)
      console.info(`NextNSync settings_restore localBlock=${snapshot.datasetLocalBlock}`)
    } catch (error) {
      console.warn(`NextNSync settings_restore_failed ${(error as Error).message}`)
      SyncSettings.apply(new SyncSettingsSnapshot())
    }
  }

  static async save(context: common.UIAbilityContext, snapshot: SyncSettingsSnapshot): Promise<void> {
    snapshot.webdavUrl = snapshot.webdavUrl.trim()
    snapshot.webdavUsername = snapshot.webdavUsername.trim()
    snapshot.lastRunAt = Math.max(0, snapshot.lastRunAt)
    snapshot.lastStatus = SyncSettings.normalizeStatus(snapshot.lastStatus)
    snapshot.lastDetail = SyncSettings.normalizeDetail(snapshot.lastDetail)
    SyncSettings.apply(snapshot)
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, SYNC_STORE)
      store.putSync(KEY_WEBDAV_URL, snapshot.webdavUrl)
      store.putSync(KEY_WEBDAV_USERNAME, snapshot.webdavUsername)
      store.putSync(KEY_WEBDAV_ENABLED, snapshot.webdavEnabled)
      store.putSync(KEY_WEBDAV_PASSWORD, snapshot.webdavPassword)
      store.putSync(KEY_DATASET_READ_PROGRESS, snapshot.datasetReadProgress)
      store.putSync(KEY_DATASET_VIEWED_HISTORY, snapshot.datasetViewedHistory)
      store.putSync(KEY_DATASET_SEARCH_HISTORY, snapshot.datasetSearchHistory)
      store.putSync(KEY_DATASET_QUICK_SEARCHES, snapshot.datasetQuickSearches)
      store.putSync(KEY_DATASET_HOME_SUBTABS, snapshot.datasetHomeSubtabs)
      store.putSync(KEY_DATASET_LOCAL_USER_TAGS, snapshot.datasetLocalUserTags)
      store.putSync(KEY_DATASET_LOCAL_BLOCK, snapshot.datasetLocalBlock)
      store.putSync(KEY_DATASET_SETTINGS_TABLES, snapshot.datasetSettingsTables)
      store.putSync(KEY_LAST_RUN_AT, snapshot.lastRunAt)
      store.putSync(KEY_LAST_STATUS, snapshot.lastStatus)
      store.putSync(KEY_LAST_DETAIL, snapshot.lastDetail)
      store.flushSync()
    } catch (error) {
      console.warn(`NextNSync settings_save_failed ${(error as Error).message}`)
    }
  }

  /**
   * Applies WebDAV edits immediately, but coalesces their local durable write. This intentionally
   * excludes dataset and run-status keys so typing configuration cannot replay a stale full snapshot.
   */
  static saveWebDavConfig(context: common.UIAbilityContext, snapshot: SyncSettingsSnapshot): void {
    const config: WebDavConfigSnapshot = SyncSettings.webDavConfig(snapshot)
    SyncSettings.applyWebDavConfig(config)
    SyncSettings.webDavConfigPersistScheduler.schedule(
      (): Promise<void> => SyncSettings.writeWebDavConfig(context, config),
    )
  }

  /** Force the newest WebDAV configuration through the same serialized write path. */
  static async flushWebDavConfig(
    context: common.UIAbilityContext,
    snapshot: SyncSettingsSnapshot,
  ): Promise<void> {
    SyncSettings.saveWebDavConfig(context, snapshot)
    await SyncSettings.webDavConfigPersistScheduler.flush()
  }

  static async markRun(
    context: common.UIAbilityContext,
    status: string,
    detail: string = '',
    timeMs: number = Date.now(),
  ): Promise<void> {
    const state = connectSyncSettings()
    state.lastRunAt = Math.max(0, timeMs)
    state.lastStatus = SyncSettings.normalizeStatus(status)
    state.lastDetail =
      state.lastStatus === SYNC_STATUS_FAILED ? SyncSettings.normalizeDetail(detail) : ''
    await SyncSettings.saveRunStatus(context, state.lastRunAt, state.lastStatus, state.lastDetail)
  }

  static configured(snapshot: SyncSettingsSnapshot): boolean {
    return snapshot.webdavEnabled && snapshot.webdavUrl.trim().length > 0
  }

  static normalizeStatus(status: string): string {
    if (status === SYNC_STATUS_OK || status === SYNC_STATUS_FAILED) {
      return status
    }
    return SYNC_STATUS_IDLE
  }

  private static normalizeDetail(detail: string): string {
    const trimmed: string = detail.trim()
    if (trimmed.length > 240) {
      return trimmed.substring(0, 240)
    }
    return trimmed
  }

  private static webDavConfig(snapshot: SyncSettingsSnapshot): WebDavConfigSnapshot {
    const config = new WebDavConfigSnapshot()
    config.webdavUrl = snapshot.webdavUrl.trim()
    config.webdavUsername = snapshot.webdavUsername.trim()
    config.webdavPassword = snapshot.webdavPassword
    config.webdavEnabled = snapshot.webdavEnabled
    return config
  }

  private static applyWebDavConfig(config: WebDavConfigSnapshot): void {
    const state = connectSyncSettings()
    state.webdavUrl = config.webdavUrl
    state.webdavUsername = config.webdavUsername
    state.webdavPassword = config.webdavPassword
    state.webdavEnabled = config.webdavEnabled
  }

  private static async writeWebDavConfig(
    context: common.UIAbilityContext,
    config: WebDavConfigSnapshot,
  ): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, SYNC_STORE)
      let changed: boolean = false
      if ((store.getSync(KEY_WEBDAV_URL, '') as string) !== config.webdavUrl) {
        store.putSync(KEY_WEBDAV_URL, config.webdavUrl)
        changed = true
      }
      if ((store.getSync(KEY_WEBDAV_USERNAME, '') as string) !== config.webdavUsername) {
        store.putSync(KEY_WEBDAV_USERNAME, config.webdavUsername)
        changed = true
      }
      if ((store.getSync(KEY_WEBDAV_PASSWORD, '') as string) !== config.webdavPassword) {
        store.putSync(KEY_WEBDAV_PASSWORD, config.webdavPassword)
        changed = true
      }
      if ((store.getSync(KEY_WEBDAV_ENABLED, false) as boolean) !== config.webdavEnabled) {
        store.putSync(KEY_WEBDAV_ENABLED, config.webdavEnabled)
        changed = true
      }
      if (changed) {
        await store.flush()
      }
    } catch (error) {
      console.warn(`NextNSync webdav_config_save_failed ${(error as Error).message}`)
    }
  }

  private static async saveRunStatus(
    context: common.UIAbilityContext,
    lastRunAt: number,
    lastStatus: string,
    lastDetail: string,
  ): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, SYNC_STORE)
      store.putSync(KEY_LAST_RUN_AT, lastRunAt)
      store.putSync(KEY_LAST_STATUS, lastStatus)
      store.putSync(KEY_LAST_DETAIL, lastDetail)
      await store.flush()
    } catch (error) {
      console.warn(`NextNSync run_status_save_failed ${(error as Error).message}`)
    }
  }
}
