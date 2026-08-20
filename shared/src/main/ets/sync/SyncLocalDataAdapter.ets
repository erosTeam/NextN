import { common } from '@kit.AbilityKit'
import { NhContentFilterRule, NhContentFilterType } from '../model/NhContentFilter'
import { NhQuickSearchItem } from '../model/NhQuickSearch'
import { NhReadingHistoryItem } from '../model/NhGallery'
import { NhSearchHistoryItem } from '../model/NhSearchHistory'
import { NhHomeSubtabProfile } from '../model/NhHomeSubtabProfile'
import { HomeSubtabSettings } from '../settings/HomeSubtabSettings'
import { BrowsePresentationRepository } from '../storage/BrowsePresentationRepository'
import { CatalogPreferencesRepository } from '../storage/CatalogPreferencesRepository'
import { ContentFilterRepository } from '../storage/ContentFilterRepository'
import { DownloadSettingsRepository } from '../storage/DownloadSettingsRepository'
import { HistoryRepository } from '../storage/HistoryRepository'
import {
  HomeSubtabRepository,
  HomeSubtabSelectionRecord,
  HomeSubtabStorageRecord,
} from '../storage/HomeSubtabRepository'
import { QuickSearchRepository } from '../storage/QuickSearchRepository'
import { ReaderSettingsRepository } from '../storage/ReaderSettingsRepository'
import { SearchHistoryRepository } from '../storage/SearchHistoryRepository'
import {
  SYNC_APP_ID,
  SYNC_MAGIC,
  SYNC_MIN_SUPPORTED_SCHEMA_VERSION,
  SYNC_SCHEMA_VERSION,
  SyncDatasetSelection,
  SyncDatasets,
  SyncEnvelopeV1,
  SyncHomeSubtabRecord,
  SyncLocalBlockRuleRecord,
  SyncLocalBlockSettingsRecord,
  SyncQuickSearchRecord,
  SyncReadProgressRecord,
  SyncSearchHistoryRecord,
  SyncSettingsTableRecord,
  SyncViewedHistoryRecord,
} from './SyncTypes'

const SHARD_COUNT: number = 64
const DATASET_READ_PROGRESS: string = 'read-progress'
const DATASET_VIEWED_HISTORY: string = 'viewed-history'
const DATASET_SEARCH_HISTORY: string = 'search-history'
const DATASET_QUICK_SEARCHES: string = 'quick-searches'
const DATASET_HOME_SUBTABS: string = 'home-subtabs'
const DATASET_LOCAL_BLOCK: string = 'local-block'
const DATASET_SETTINGS_TABLES: string = 'settings-tables'
const HOME_SUBTAB_SELECTION_RECORD: string = '@selection'
const TABLE_READER_SETTINGS: string = 'reader_settings'
const TABLE_DOWNLOAD_SETTINGS: string = 'download_settings'
const TABLE_BROWSE_PRESENTATION_SETTINGS: string = 'browse_presentation_settings'
const TABLE_CATALOG_PREFERENCES: string = 'catalog_preferences'
const SETTINGS_TABLE_NAMES: string[] = [
  TABLE_READER_SETTINGS,
  TABLE_DOWNLOAD_SETTINGS,
  TABLE_BROWSE_PRESENTATION_SETTINGS,
  TABLE_CATALOG_PREFERENCES,
]

/**
 * Reads/writes NextN's durable RDB datasets for WebDAV sync (ported from the
 * NextE sync chain). The NH data-source leaf replaces NextE's table set:
 *   - reading_history        -> readProgress + viewedHistory (single NH table)
 *   - search_history         -> searchHistory
 *   - search_quick           -> quickSearches (NH leaf; NextE has no equivalent)
 *   - content_filter_rules   -> localBlock (NH leaf for NextE's block rules)
 *   - reader/download/browse/catalog settings -> settingsTables (key-value)
 * NextN has no localFavorites/imageBlock/customProfiles datasets and no
 * comment-score scalars, so localBlockSettings stays empty for envelope
 * parity. Merge rules are preserved unchanged: primary-key merge with
 * max(updatedAt, deletedAt) winning, tombstone rows deleting local records,
 * and the NextE viewed-history snapshot special case adapted to the single
 * reading_history table.
 */
export class SyncLocalDataAdapter {
  static async exportEnvelope(
    context: common.UIAbilityContext,
    deviceId: string = '',
    selection: SyncDatasetSelection = new SyncDatasetSelection(),
  ): Promise<SyncEnvelopeV1> {
    const envelope: SyncEnvelopeV1 = new SyncEnvelopeV1()
    envelope.generatedAt = new Date().toISOString()
    envelope.deviceId = deviceId
    if (selection.readProgress) {
      envelope.datasets.readProgress = await SyncLocalDataAdapter.readProgress(context)
    }
    if (selection.viewedHistory) {
      envelope.datasets.viewedHistory = await SyncLocalDataAdapter.readViewedHistory(context)
    }
    if (selection.searchHistory) {
      envelope.datasets.searchHistory = await SyncLocalDataAdapter.readSearchHistory(context)
    }
    if (selection.quickSearches) {
      envelope.datasets.quickSearches = await SyncLocalDataAdapter.readQuickSearches(context)
    }
    if (selection.homeSubtabs) {
      envelope.datasets.homeSubtabs = await SyncLocalDataAdapter.readHomeSubtabs(context)
    }
    if (selection.localBlock) {
      // NH has no comment-score scalars; kept empty for NextE envelope parity.
      envelope.datasets.localBlockSettings = []
      envelope.datasets.localBlockRules = await SyncLocalDataAdapter.readLocalBlockRules(context)
    }
    if (selection.settingsTables) {
      envelope.datasets.settingsTables = await SyncLocalDataAdapter.readSettingsTables(context)
    }
    return envelope
  }

  static async applyEnvelope(
    context: common.UIAbilityContext,
    envelope: SyncEnvelopeV1,
    selection: SyncDatasetSelection = new SyncDatasetSelection(),
  ): Promise<void> {
    SyncLocalDataAdapter.normalizeEnvelope(envelope)
    if (!SyncLocalDataAdapter.hasCompleteEnvelopeShape(envelope)) {
      throw new Error('Invalid NextN sync envelope')
    }
    try {
      if (selection.readProgress || selection.viewedHistory) {
        await SyncLocalDataAdapter.applyReadingHistory(context, envelope, selection)
      }
      if (selection.searchHistory) {
        await SyncLocalDataAdapter.applySearchHistory(context, envelope.datasets.searchHistory)
      }
      if (selection.quickSearches) {
        await SyncLocalDataAdapter.applyQuickSearches(context, envelope.datasets.quickSearches)
      }
      if (selection.homeSubtabs) {
        await SyncLocalDataAdapter.applyHomeSubtabs(context, envelope.datasets.homeSubtabs)
      }
      if (selection.localBlock) {
        await SyncLocalDataAdapter.applyLocalBlockSettings(context, envelope.datasets.localBlockSettings)
        await SyncLocalDataAdapter.applyLocalBlockRules(context, envelope.datasets.localBlockRules)
      }
      if (selection.settingsTables) {
        await SyncLocalDataAdapter.applySettingsTables(context, envelope.datasets.settingsTables)
      }
    } catch (error) {
      const e: Error = error as Error
      throw new Error(e.message || 'Failed to apply sync envelope')
    }
  }

  static mergeEnvelopes(local: SyncEnvelopeV1, remote: SyncEnvelopeV1): SyncEnvelopeV1 {
    const merged: SyncEnvelopeV1 = new SyncEnvelopeV1()
    merged.generatedAt = new Date().toISOString()
    merged.datasets.readProgress =
      SyncLocalDataAdapter.mergeReadProgress(local.datasets.readProgress, remote.datasets.readProgress)
    merged.datasets.viewedHistory =
      SyncLocalDataAdapter.mergeViewedHistory(local.datasets.viewedHistory, remote.datasets.viewedHistory)
    merged.datasets.searchHistory =
      SyncLocalDataAdapter.mergeSearchHistory(local.datasets.searchHistory, remote.datasets.searchHistory)
    merged.datasets.quickSearches =
      SyncLocalDataAdapter.mergeQuickSearches(local.datasets.quickSearches, remote.datasets.quickSearches)
    merged.datasets.homeSubtabs =
      SyncLocalDataAdapter.mergeHomeSubtabs(local.datasets.homeSubtabs, remote.datasets.homeSubtabs)
    merged.datasets.localBlockSettings =
      SyncLocalDataAdapter.mergeLocalBlockSettings(
        local.datasets.localBlockSettings,
        remote.datasets.localBlockSettings,
      )
    merged.datasets.localBlockRules =
      SyncLocalDataAdapter.mergeLocalBlockRules(local.datasets.localBlockRules, remote.datasets.localBlockRules)
    merged.datasets.settingsTables =
      SyncLocalDataAdapter.mergeSettingsTables(local.datasets.settingsTables, remote.datasets.settingsTables)
    return merged
  }

  static mergeSelectedIntoRemote(
    remote: SyncEnvelopeV1,
    selectedMerged: SyncEnvelopeV1,
    selection: SyncDatasetSelection,
    deviceId: string = '',
  ): SyncEnvelopeV1 {
    const out: SyncEnvelopeV1 = new SyncEnvelopeV1()
    out.generatedAt = new Date().toISOString()
    out.deviceId = deviceId
    out.datasets.readProgress = selection.readProgress ?
      selectedMerged.datasets.readProgress : remote.datasets.readProgress
    out.datasets.viewedHistory = selection.viewedHistory ?
      selectedMerged.datasets.viewedHistory : remote.datasets.viewedHistory
    out.datasets.searchHistory = selection.searchHistory ?
      selectedMerged.datasets.searchHistory : remote.datasets.searchHistory
    out.datasets.quickSearches = selection.quickSearches ?
      selectedMerged.datasets.quickSearches : remote.datasets.quickSearches
    out.datasets.homeSubtabs = selection.homeSubtabs ?
      selectedMerged.datasets.homeSubtabs : remote.datasets.homeSubtabs
    out.datasets.localBlockSettings = selection.localBlock ?
      selectedMerged.datasets.localBlockSettings : remote.datasets.localBlockSettings
    out.datasets.localBlockRules = selection.localBlock ?
      selectedMerged.datasets.localBlockRules : remote.datasets.localBlockRules
    out.datasets.settingsTables = selection.settingsTables ?
      selectedMerged.datasets.settingsTables : remote.datasets.settingsTables
    return out
  }

  static validateEnvelope(envelope: SyncEnvelopeV1): boolean {
    return envelope.magic === SYNC_MAGIC &&
      envelope.appId === SYNC_APP_ID &&
      envelope.schemaVersion === SYNC_SCHEMA_VERSION &&
      envelope.minSupportedSchemaVersion <= SYNC_SCHEMA_VERSION &&
      envelope.datasets !== null
  }

  /**
   * Complete-shape normalization ported from the NextE SyncService/WebDAV
   * chain. Every dataset must be an array and every record field is coerced
   * to the safe sync type before merge/import so a missing or malformed field
   * can never silently become an empty replacement.
   */
  static normalizeEnvelope(envelope: SyncEnvelopeV1): void {
    if (envelope.datasets === null || envelope.datasets === undefined) {
      envelope.datasets = new SyncDatasets()
    }
    const data: SyncDatasets = envelope.datasets
    if (!Array.isArray(data.readProgress)) {
      data.readProgress = []
    }
    if (!Array.isArray(data.viewedHistory)) {
      data.viewedHistory = []
    }
    if (!Array.isArray(data.searchHistory)) {
      data.searchHistory = []
    }
    if (!Array.isArray(data.quickSearches)) {
      data.quickSearches = []
    }
    if (!Array.isArray(data.homeSubtabs)) {
      // v1 envelopes created before this dataset are an empty compatible set.
      data.homeSubtabs = []
    }
    if (!Array.isArray(data.localBlockSettings)) {
      data.localBlockSettings = []
    }
    if (!Array.isArray(data.localBlockRules)) {
      data.localBlockRules = []
    }
    if (!Array.isArray(data.settingsTables)) {
      data.settingsTables = []
    }
    for (let i: number = 0; i < data.readProgress.length; i++) {
      const r: SyncReadProgressRecord = data.readProgress[i]
      r.scopeKey = SyncLocalDataAdapter.safeString(r.scopeKey)
      r.galleryId = SyncLocalDataAdapter.safeNumber(r.galleryId)
      r.pageIndex = SyncLocalDataAdapter.safeNumber(r.pageIndex)
      r.updatedAt = SyncLocalDataAdapter.safeNumber(r.updatedAt)
      r.deletedAt = SyncLocalDataAdapter.safeNumber(r.deletedAt)
    }
    for (let i: number = 0; i < data.viewedHistory.length; i++) {
      const r: SyncViewedHistoryRecord = data.viewedHistory[i]
      r.scopeKey = SyncLocalDataAdapter.safeString(r.scopeKey)
      r.galleryId = SyncLocalDataAdapter.safeNumber(r.galleryId)
      r.mediaId = SyncLocalDataAdapter.safeString(r.mediaId)
      r.title = SyncLocalDataAdapter.safeString(r.title)
      r.thumbnailUrl = SyncLocalDataAdapter.safeString(r.thumbnailUrl)
      r.pageCount = SyncLocalDataAdapter.safeNumber(r.pageCount)
      r.lastReadIndex = SyncLocalDataAdapter.safeNumber(r.lastReadIndex)
      r.hasReadProgress = SyncLocalDataAdapter.safeBoolean(r.hasReadProgress)
      r.viewedAt = SyncLocalDataAdapter.safeNumber(r.viewedAt)
      r.deletedAt = SyncLocalDataAdapter.safeNumber(r.deletedAt)
    }
    for (let i: number = 0; i < data.searchHistory.length; i++) {
      const r: SyncSearchHistoryRecord = data.searchHistory[i]
      r.scopeKey = SyncLocalDataAdapter.safeString(r.scopeKey)
      r.queryText = SyncLocalDataAdapter.safeString(r.queryText)
      r.positionIndex = SyncLocalDataAdapter.safeNumber(r.positionIndex)
      r.updatedAt = SyncLocalDataAdapter.safeNumber(r.updatedAt)
      r.deletedAt = SyncLocalDataAdapter.safeNumber(r.deletedAt)
    }
    for (let i: number = 0; i < data.quickSearches.length; i++) {
      const r: SyncQuickSearchRecord = data.quickSearches[i]
      r.scopeKey = SyncLocalDataAdapter.safeString(r.scopeKey)
      r.queryText = SyncLocalDataAdapter.safeString(r.queryText)
      r.pinnedAt = SyncLocalDataAdapter.safeNumber(r.pinnedAt)
      r.updatedAt = SyncLocalDataAdapter.safeNumber(r.updatedAt)
      r.deletedAt = SyncLocalDataAdapter.safeNumber(r.deletedAt)
    }
    for (let i: number = 0; i < data.homeSubtabs.length; i++) {
      const r: SyncHomeSubtabRecord = data.homeSubtabs[i]
      r.scopeKey = SyncLocalDataAdapter.safeString(r.scopeKey)
      r.profileUuid = SyncLocalDataAdapter.safeString(r.profileUuid)
      r.positionIndex = SyncLocalDataAdapter.safeNumber(r.positionIndex)
      r.kind = SyncLocalDataAdapter.safeString(r.kind)
      r.name = SyncLocalDataAdapter.safeString(r.name)
      r.queryText = SyncLocalDataAdapter.safeString(r.queryText)
      r.language = SyncLocalDataAdapter.safeString(r.language)
      r.sort = SyncLocalDataAdapter.safeString(r.sort)
      r.displayMode = SyncLocalDataAdapter.safeString(r.displayMode)
      r.hidden = SyncLocalDataAdapter.safeBoolean(r.hidden)
      r.selectedUuid = SyncLocalDataAdapter.safeString(r.selectedUuid)
      r.updatedAt = SyncLocalDataAdapter.safeNumber(r.updatedAt)
      r.deletedAt = SyncLocalDataAdapter.safeNumber(r.deletedAt)
    }
    for (let i: number = 0; i < data.localBlockSettings.length; i++) {
      const r: SyncLocalBlockSettingsRecord = data.localBlockSettings[i]
      r.scopeKey = SyncLocalDataAdapter.safeString(r.scopeKey)
      r.filterCommentsByScore = SyncLocalDataAdapter.safeBoolean(r.filterCommentsByScore)
      r.scoreFilteringThreshold = SyncLocalDataAdapter.safeNumber(r.scoreFilteringThreshold)
      r.commentDisplayMode = SyncLocalDataAdapter.safeString(r.commentDisplayMode)
      r.updatedAt = SyncLocalDataAdapter.safeNumber(r.updatedAt)
      r.deletedAt = SyncLocalDataAdapter.safeNumber(r.deletedAt)
    }
    for (let i: number = 0; i < data.localBlockRules.length; i++) {
      const r: SyncLocalBlockRuleRecord = data.localBlockRules[i]
      r.scopeKey = SyncLocalDataAdapter.safeString(r.scopeKey)
      r.ruleId = SyncLocalDataAdapter.safeString(r.ruleId)
      r.positionIndex = SyncLocalDataAdapter.safeNumber(r.positionIndex)
      r.blockType = SyncLocalDataAdapter.safeString(r.blockType)
      r.ruleText = SyncLocalDataAdapter.safeString(r.ruleText)
      r.enabled = SyncLocalDataAdapter.safeBoolean(r.enabled)
      r.enableRegex = SyncLocalDataAdapter.safeBoolean(r.enableRegex)
      r.updatedAt = SyncLocalDataAdapter.safeNumber(r.updatedAt)
      r.deletedAt = SyncLocalDataAdapter.safeNumber(r.deletedAt)
    }
    for (let i: number = 0; i < data.settingsTables.length; i++) {
      const r: SyncSettingsTableRecord = data.settingsTables[i]
      r.scopeKey = SyncLocalDataAdapter.safeString(r.scopeKey)
      r.tableName = SyncLocalDataAdapter.safeString(r.tableName)
      r.key = SyncLocalDataAdapter.safeString(r.key)
      r.value = SyncLocalDataAdapter.safeString(r.value)
      r.updatedAt = SyncLocalDataAdapter.safeNumber(r.updatedAt)
      r.deletedAt = SyncLocalDataAdapter.safeNumber(r.deletedAt)
    }
  }

  /**
   * Complete-shape guard ported from the NextN backup chain: a missing or
   * malformed dataset must never become an empty replacement. Run after
   * normalizeEnvelope so numeric/boolean coercion has already converged.
   */
  static hasCompleteEnvelopeShape(envelope: SyncEnvelopeV1): boolean {
    if (envelope.datasets === null || envelope.datasets === undefined) {
      return false
    }
    const data: SyncDatasets = envelope.datasets
    if (
      !Array.isArray(data.readProgress) ||
      !Array.isArray(data.viewedHistory) ||
      !Array.isArray(data.searchHistory) ||
      !Array.isArray(data.quickSearches) ||
      !Array.isArray(data.homeSubtabs) ||
      !Array.isArray(data.localBlockSettings) ||
      !Array.isArray(data.localBlockRules) ||
      !Array.isArray(data.settingsTables)
    ) {
      return false
    }
    return SyncLocalDataAdapter.hasReadProgressShape(data.readProgress) &&
      SyncLocalDataAdapter.hasViewedHistoryShape(data.viewedHistory) &&
      SyncLocalDataAdapter.hasSearchHistoryShape(data.searchHistory) &&
      SyncLocalDataAdapter.hasQuickSearchShape(data.quickSearches) &&
      SyncLocalDataAdapter.hasHomeSubtabShape(data.homeSubtabs) &&
      SyncLocalDataAdapter.hasLocalBlockSettingsShape(data.localBlockSettings) &&
      SyncLocalDataAdapter.hasLocalBlockRuleShape(data.localBlockRules) &&
      SyncLocalDataAdapter.hasSettingsTableShape(data.settingsTables)
  }

  // Shard helpers ported from the NextE WebDavSyncService. SHARD_COUNT stays
  // 64 and the FNV-1a hash over the primary key is byte-for-byte identical;
  // only the NH primary keys (galleryId numbers, normalized query text,
  // tableName+key) replace the NextE string keys.
  static shardIdForKey(key: string): string {
    let hash: number = 2166136261
    for (let i: number = 0; i < key.length; i++) {
      hash ^= key.charCodeAt(i)
      hash = Math.imul(hash, 16777619) >>> 0
    }
    return (hash % SHARD_COUNT).toString(16).padStart(2, '0')
  }

  static sortShardEnvelope(envelope: SyncEnvelopeV1, datasetId: string): void {
    if (datasetId === DATASET_READ_PROGRESS) {
      envelope.datasets.readProgress.sort(
        (a: SyncReadProgressRecord, b: SyncReadProgressRecord): number => {
          return SyncLocalDataAdapter.compareKey(
            SyncLocalDataAdapter.readProgressKey(a),
            SyncLocalDataAdapter.readProgressKey(b),
          )
        },
      )
    } else if (datasetId === DATASET_VIEWED_HISTORY) {
      envelope.datasets.viewedHistory.sort(
        (a: SyncViewedHistoryRecord, b: SyncViewedHistoryRecord): number => {
          return SyncLocalDataAdapter.compareKey(
            SyncLocalDataAdapter.viewedHistoryKey(a),
            SyncLocalDataAdapter.viewedHistoryKey(b),
          )
        },
      )
    } else if (datasetId === DATASET_SEARCH_HISTORY) {
      envelope.datasets.searchHistory.sort(
        (a: SyncSearchHistoryRecord, b: SyncSearchHistoryRecord): number => {
          return SyncLocalDataAdapter.compareKey(
            SyncLocalDataAdapter.searchHistoryKey(a),
            SyncLocalDataAdapter.searchHistoryKey(b),
          )
        },
      )
    } else if (datasetId === DATASET_QUICK_SEARCHES) {
      envelope.datasets.quickSearches.sort(
        (a: SyncQuickSearchRecord, b: SyncQuickSearchRecord): number => {
          return SyncLocalDataAdapter.compareKey(
            SyncLocalDataAdapter.quickSearchKey(a),
            SyncLocalDataAdapter.quickSearchKey(b),
          )
        },
      )
    } else if (datasetId === DATASET_HOME_SUBTABS) {
      envelope.datasets.homeSubtabs.sort(
        (a: SyncHomeSubtabRecord, b: SyncHomeSubtabRecord): number => {
          return SyncLocalDataAdapter.compareKey(
            SyncLocalDataAdapter.homeSubtabKey(a),
            SyncLocalDataAdapter.homeSubtabKey(b),
          )
        },
      )
    } else if (datasetId === DATASET_LOCAL_BLOCK) {
      envelope.datasets.localBlockSettings.sort(
        (a: SyncLocalBlockSettingsRecord, b: SyncLocalBlockSettingsRecord): number => {
          return SyncLocalDataAdapter.compareKey(a.scopeKey, b.scopeKey)
        },
      )
      envelope.datasets.localBlockRules.sort(
        (a: SyncLocalBlockRuleRecord, b: SyncLocalBlockRuleRecord): number => {
          return SyncLocalDataAdapter.compareKey(
            SyncLocalDataAdapter.localBlockRuleKey(a),
            SyncLocalDataAdapter.localBlockRuleKey(b),
          )
        },
      )
    } else if (datasetId === DATASET_SETTINGS_TABLES) {
      envelope.datasets.settingsTables.sort(
        (a: SyncSettingsTableRecord, b: SyncSettingsTableRecord): number => {
          return SyncLocalDataAdapter.compareKey(
            SyncLocalDataAdapter.settingsTableKey(a),
            SyncLocalDataAdapter.settingsTableKey(b),
          )
        },
      )
    }
  }

  static datasetRecordCount(envelope: SyncEnvelopeV1, datasetId: string): number {
    if (datasetId === DATASET_READ_PROGRESS) {
      return envelope.datasets.readProgress.length
    }
    if (datasetId === DATASET_VIEWED_HISTORY) {
      return envelope.datasets.viewedHistory.length
    }
    if (datasetId === DATASET_SEARCH_HISTORY) {
      return envelope.datasets.searchHistory.length
    }
    if (datasetId === DATASET_QUICK_SEARCHES) {
      return envelope.datasets.quickSearches.length
    }
    if (datasetId === DATASET_HOME_SUBTABS) {
      return envelope.datasets.homeSubtabs.length
    }
    if (datasetId === DATASET_LOCAL_BLOCK) {
      return envelope.datasets.localBlockSettings.length + envelope.datasets.localBlockRules.length
    }
    if (datasetId === DATASET_SETTINGS_TABLES) {
      return envelope.datasets.settingsTables.length
    }
    return 0
  }

  static datasetUpdatedAt(envelope: SyncEnvelopeV1, datasetId: string): number {
    let out: number = 0
    if (datasetId === DATASET_READ_PROGRESS) {
      for (let i: number = 0; i < envelope.datasets.readProgress.length; i++) {
        const r: SyncReadProgressRecord = envelope.datasets.readProgress[i]
        out = Math.max(out, r.updatedAt, r.deletedAt)
      }
    } else if (datasetId === DATASET_VIEWED_HISTORY) {
      for (let i: number = 0; i < envelope.datasets.viewedHistory.length; i++) {
        const r: SyncViewedHistoryRecord = envelope.datasets.viewedHistory[i]
        out = Math.max(out, r.viewedAt, r.deletedAt)
      }
    } else if (datasetId === DATASET_SEARCH_HISTORY) {
      for (let i: number = 0; i < envelope.datasets.searchHistory.length; i++) {
        const r: SyncSearchHistoryRecord = envelope.datasets.searchHistory[i]
        out = Math.max(out, r.updatedAt, r.deletedAt)
      }
    } else if (datasetId === DATASET_QUICK_SEARCHES) {
      for (let i: number = 0; i < envelope.datasets.quickSearches.length; i++) {
        const r: SyncQuickSearchRecord = envelope.datasets.quickSearches[i]
        out = Math.max(out, r.updatedAt, r.deletedAt)
      }
    } else if (datasetId === DATASET_HOME_SUBTABS) {
      for (let i: number = 0; i < envelope.datasets.homeSubtabs.length; i++) {
        const r: SyncHomeSubtabRecord = envelope.datasets.homeSubtabs[i]
        out = Math.max(out, r.updatedAt, r.deletedAt)
      }
    } else if (datasetId === DATASET_LOCAL_BLOCK) {
      for (let i: number = 0; i < envelope.datasets.localBlockSettings.length; i++) {
        const r: SyncLocalBlockSettingsRecord = envelope.datasets.localBlockSettings[i]
        out = Math.max(out, r.updatedAt, r.deletedAt)
      }
      for (let i: number = 0; i < envelope.datasets.localBlockRules.length; i++) {
        const r: SyncLocalBlockRuleRecord = envelope.datasets.localBlockRules[i]
        out = Math.max(out, r.updatedAt, r.deletedAt)
      }
    } else if (datasetId === DATASET_SETTINGS_TABLES) {
      for (let i: number = 0; i < envelope.datasets.settingsTables.length; i++) {
        const r: SyncSettingsTableRecord = envelope.datasets.settingsTables[i]
        out = Math.max(out, r.updatedAt, r.deletedAt)
      }
    }
    return out
  }

  static stableGeneratedAt(envelope: SyncEnvelopeV1, datasetId: string): string {
    const updatedAt: number = SyncLocalDataAdapter.datasetUpdatedAt(envelope, datasetId)
    if (updatedAt <= 0) {
      return ''
    }
    return new Date(updatedAt).toISOString()
  }

  private static async readProgress(context: common.UIAbilityContext): Promise<SyncReadProgressRecord[]> {
    const source: NhReadingHistoryItem[] = await HistoryRepository.exportForBackup(context)
    const out: SyncReadProgressRecord[] = []
    for (let i: number = 0; i < source.length; i++) {
      const item: NhReadingHistoryItem = source[i]
      if (item.galleryId <= 0 || !item.hasReadProgress) {
        continue
      }
      const r: SyncReadProgressRecord = new SyncReadProgressRecord()
      r.scopeKey = ''
      r.galleryId = item.galleryId
      r.pageIndex = item.lastReadIndex
      r.updatedAt = item.lastOpenedAt
      r.deletedAt = 0
      out.push(r)
    }
    return out
  }

  private static async readViewedHistory(context: common.UIAbilityContext): Promise<SyncViewedHistoryRecord[]> {
    const source: NhReadingHistoryItem[] = await HistoryRepository.exportForBackup(context)
    const out: SyncViewedHistoryRecord[] = []
    for (let i: number = 0; i < source.length; i++) {
      const item: NhReadingHistoryItem = source[i]
      if (item.galleryId <= 0 || SyncLocalDataAdapter.isDisplayMetadataMissing(item)) {
        continue
      }
      const r: SyncViewedHistoryRecord = new SyncViewedHistoryRecord()
      r.scopeKey = ''
      r.galleryId = item.galleryId
      r.mediaId = item.mediaId
      r.title = item.title
      r.thumbnailUrl = item.thumbnailUrl
      r.pageCount = item.pageCount
      r.lastReadIndex = item.lastReadIndex
      r.hasReadProgress = item.hasReadProgress
      r.viewedAt = item.lastOpenedAt
      r.deletedAt = 0
      out.push(r)
    }
    return out
  }

  private static async readSearchHistory(context: common.UIAbilityContext): Promise<SyncSearchHistoryRecord[]> {
    const source: NhSearchHistoryItem[] = await SearchHistoryRepository.load(context)
    const out: SyncSearchHistoryRecord[] = []
    for (let i: number = 0; i < source.length; i++) {
      const item: NhSearchHistoryItem = source[i]
      if (item.query.trim().length === 0) {
        continue
      }
      const r: SyncSearchHistoryRecord = new SyncSearchHistoryRecord()
      r.scopeKey = ''
      r.queryText = item.query
      // The repository returns recency order (newest first); 0 is the newest
      // position, matching the NextE position_index contract.
      r.positionIndex = i
      r.updatedAt = item.lastUsedAt
      r.deletedAt = 0
      out.push(r)
    }
    return out
  }

  private static async readQuickSearches(context: common.UIAbilityContext): Promise<SyncQuickSearchRecord[]> {
    const source: NhQuickSearchItem[] = await QuickSearchRepository.exportForBackup(context)
    const out: SyncQuickSearchRecord[] = []
    for (let i: number = 0; i < source.length; i++) {
      const item: NhQuickSearchItem = source[i]
      if (item.query.trim().length === 0) {
        continue
      }
      const r: SyncQuickSearchRecord = new SyncQuickSearchRecord()
      r.scopeKey = ''
      r.queryText = item.query
      r.pinnedAt = item.pinnedAt
      r.updatedAt = item.pinnedAt
      r.deletedAt = 0
      out.push(r)
    }
    return out
  }

  private static async readHomeSubtabs(context: common.UIAbilityContext): Promise<SyncHomeSubtabRecord[]> {
    await HomeSubtabSettings.flushForSync()
    const source: HomeSubtabStorageRecord[] = await HomeSubtabRepository.exportRecords(context)
    const out: SyncHomeSubtabRecord[] = []
    for (let i: number = 0; i < source.length; i++) {
      const item: HomeSubtabStorageRecord = source[i]
      const profile: NhHomeSubtabProfile = item.profile
      const r: SyncHomeSubtabRecord = new SyncHomeSubtabRecord()
      r.scopeKey = ''
      r.profileUuid = profile.uuid
      r.positionIndex = item.positionIndex
      r.kind = profile.kind
      r.name = profile.name
      r.queryText = profile.query
      r.language = profile.language
      r.sort = profile.sort
      r.displayMode = profile.presentation
      r.hidden = profile.hidden
      r.updatedAt = profile.lastEditTime
      r.deletedAt = item.deletedAt
      out.push(r)
    }
    const selection: HomeSubtabSelectionRecord = await HomeSubtabRepository.loadSelection(context)
    if (selection.updatedAt > 0 || selection.deletedAt > 0) {
      const r: SyncHomeSubtabRecord = new SyncHomeSubtabRecord()
      r.scopeKey = ''
      r.profileUuid = HOME_SUBTAB_SELECTION_RECORD
      r.selectedUuid = selection.selectedUuid
      r.updatedAt = selection.updatedAt
      r.deletedAt = selection.deletedAt
      out.push(r)
    }
    return out
  }

  private static async readLocalBlockRules(context: common.UIAbilityContext): Promise<SyncLocalBlockRuleRecord[]> {
    const source: NhContentFilterRule[] = await ContentFilterRepository.exportForBackup(context)
    const out: SyncLocalBlockRuleRecord[] = []
    // content_filter_rules carries no timestamp; one export epoch keeps all
    // rows and the resulting shard deterministic within a single envelope.
    const now: number = Date.now()
    for (let i: number = 0; i < source.length; i++) {
      const rule: NhContentFilterRule = source[i]
      if (rule.id.length === 0 || rule.text.trim().length === 0) {
        continue
      }
      const r: SyncLocalBlockRuleRecord = new SyncLocalBlockRuleRecord()
      r.scopeKey = ''
      r.ruleId = rule.id
      r.positionIndex = i
      r.blockType = rule.type
      r.ruleText = rule.text
      r.enabled = rule.enabled
      r.enableRegex = rule.isRegex
      r.updatedAt = now
      r.deletedAt = 0
      out.push(r)
    }
    return out
  }

  private static async readSettingsTables(context: common.UIAbilityContext): Promise<SyncSettingsTableRecord[]> {
    const out: SyncSettingsTableRecord[] = []
    const now: number = Date.now()
    for (let i: number = 0; i < SETTINGS_TABLE_NAMES.length; i++) {
      const tableName: string = SETTINGS_TABLE_NAMES[i]
      const values: Record<string, string> = await SyncLocalDataAdapter.exportTable(context, tableName)
      const keys: string[] = Object.keys(values)
      for (let j: number = 0; j < keys.length; j++) {
        const r: SyncSettingsTableRecord = new SyncSettingsTableRecord()
        r.scopeKey = ''
        r.tableName = tableName
        r.key = keys[j]
        r.value = values[keys[j]]
        r.updatedAt = now
        r.deletedAt = 0
        out.push(r)
      }
    }
    return out
  }

  private static async exportTable(
    context: common.UIAbilityContext,
    tableName: string,
  ): Promise<Record<string, string>> {
    if (tableName === TABLE_READER_SETTINGS) {
      return ReaderSettingsRepository.exportForBackup(context)
    }
    if (tableName === TABLE_DOWNLOAD_SETTINGS) {
      return DownloadSettingsRepository.exportForBackup(context)
    }
    if (tableName === TABLE_BROWSE_PRESENTATION_SETTINGS) {
      return BrowsePresentationRepository.exportForBackup(context)
    }
    if (tableName === TABLE_CATALOG_PREFERENCES) {
      return CatalogPreferencesRepository.exportForBackup(context)
    }
    const empty: Record<string, string> = {}
    return empty
  }

  /**
   * The two envelope halves (progress + display rows) come from the same NH
   * reading_history table. Merge by gallery id like the NextN backup adapter:
   * display rows seed the replacement, progress rows overlay the resume
   * marker, and tombstoned records are omitted so the authoritative
   * HistoryRepository.restoreBackup deletes them.
   */
  private static async applyReadingHistory(
    context: common.UIAbilityContext,
    envelope: SyncEnvelopeV1,
    selection: SyncDatasetSelection,
  ): Promise<void> {
    const local: NhReadingHistoryItem[] = await HistoryRepository.exportForBackup(context)
    const items: NhReadingHistoryItem[] = []
    if (selection.viewedHistory) {
      const viewed: SyncViewedHistoryRecord[] = envelope.datasets.viewedHistory
      for (let i: number = 0; i < viewed.length; i++) {
        const r: SyncViewedHistoryRecord = viewed[i]
        if (r.galleryId <= 0 || r.deletedAt > 0) {
          continue
        }
        const item: NhReadingHistoryItem = new NhReadingHistoryItem()
        item.galleryId = r.galleryId
        item.mediaId = r.mediaId
        item.title = r.title
        item.thumbnailUrl = r.thumbnailUrl
        item.pageCount = r.pageCount
        item.lastOpenedAt = r.viewedAt
        const previous: NhReadingHistoryItem | undefined =
          SyncLocalDataAdapter.findReadingHistoryItem(local, r.galleryId)
        if (previous !== undefined) {
          // viewed-history owns display data only. Preserve the independent
          // read-progress half even though NextN currently stores both halves
          // in one RDB row. Also retain known display leaves when repairing a
          // GID-only payload produced by older builds.
          item.lastReadIndex = previous.lastReadIndex
          item.hasReadProgress = previous.hasReadProgress
          SyncLocalDataAdapter.fillReadingHistoryDisplay(item, previous)
        }
        items.push(item)
      }
    } else {
      // A read-progress shard must never reconstruct the whole table from its
      // progress-only records. Seed the replacement with every local display
      // row, then overlay only the selected progress fields below.
      for (let i: number = 0; i < local.length; i++) {
        items.push(SyncLocalDataAdapter.cloneReadingHistoryItem(local[i]))
      }
    }
    if (selection.readProgress) {
      const progress: SyncReadProgressRecord[] = envelope.datasets.readProgress
      for (let i: number = 0; i < progress.length; i++) {
        const r: SyncReadProgressRecord = progress[i]
        if (r.galleryId <= 0) {
          continue
        }
        let item: NhReadingHistoryItem | undefined =
          SyncLocalDataAdapter.findReadingHistoryItem(items, r.galleryId)
        if (r.deletedAt > 0) {
          // A winning progress tombstone clears only the resume marker; the
          // display row (if any) stays visible.
          if (item !== undefined) {
            item.hasReadProgress = false
            item.lastReadIndex = 0
          }
          continue
        }
        if (item === undefined) {
          item = new NhReadingHistoryItem()
          item.galleryId = r.galleryId
          item.lastOpenedAt = r.updatedAt
          items.push(item)
        }
        item.hasReadProgress = true
        item.lastReadIndex = r.pageIndex
        if (r.updatedAt > item.lastOpenedAt) {
          item.lastOpenedAt = r.updatedAt
        }
      }
    }
    await HistoryRepository.restoreBackup(context, items)
  }

  private static findReadingHistoryItem(
    items: NhReadingHistoryItem[],
    galleryId: number,
  ): NhReadingHistoryItem | undefined {
    for (let i: number = 0; i < items.length; i++) {
      if (items[i].galleryId === galleryId) {
        return items[i]
      }
    }
    return undefined
  }

  private static cloneReadingHistoryItem(source: NhReadingHistoryItem): NhReadingHistoryItem {
    const out: NhReadingHistoryItem = new NhReadingHistoryItem()
    out.galleryId = source.galleryId
    out.mediaId = source.mediaId
    out.title = source.title
    out.thumbnailUrl = source.thumbnailUrl
    out.pageCount = source.pageCount
    out.lastReadIndex = source.lastReadIndex
    out.hasReadProgress = source.hasReadProgress
    out.lastOpenedAt = source.lastOpenedAt
    return out
  }

  private static isDisplayMetadataMissing(item: NhReadingHistoryItem): boolean {
    return item.mediaId.length === 0 && item.title.length === 0 &&
      item.thumbnailUrl.length === 0 && item.pageCount <= 0
  }

  private static fillReadingHistoryDisplay(
    target: NhReadingHistoryItem,
    fallback: NhReadingHistoryItem,
  ): void {
    if (target.mediaId.length === 0) target.mediaId = fallback.mediaId
    if (target.title.length === 0) target.title = fallback.title
    if (target.thumbnailUrl.length === 0) target.thumbnailUrl = fallback.thumbnailUrl
    if (target.pageCount <= 0) target.pageCount = fallback.pageCount
  }

  private static async applySearchHistory(
    context: common.UIAbilityContext,
    records: SyncSearchHistoryRecord[],
  ): Promise<void> {
    const ordered: SyncSearchHistoryRecord[] = records.slice()
    ordered.sort((a: SyncSearchHistoryRecord, b: SyncSearchHistoryRecord): number => {
      return a.positionIndex - b.positionIndex
    })
    const queries: string[] = []
    for (let i: number = 0; i < ordered.length; i++) {
      const r: SyncSearchHistoryRecord = ordered[i]
      if (r.deletedAt > 0 || r.queryText.trim().length === 0) {
        continue
      }
      queries.push(r.queryText)
    }
    // Authoritative replacement: tombstones are omitted, so restoreBackup
    // deletes the local rows they outrank.
    await SearchHistoryRepository.restoreBackup(context, queries)
  }

  private static async applyQuickSearches(
    context: common.UIAbilityContext,
    records: SyncQuickSearchRecord[],
  ): Promise<void> {
    const items: NhQuickSearchItem[] = []
    for (let i: number = 0; i < records.length; i++) {
      const r: SyncQuickSearchRecord = records[i]
      if (r.deletedAt > 0 || r.queryText.trim().length === 0) {
        continue
      }
      const item: NhQuickSearchItem = new NhQuickSearchItem()
      item.query = r.queryText
      item.pinnedAt = r.pinnedAt > 0 ? r.pinnedAt : r.updatedAt
      items.push(item)
    }
    await QuickSearchRepository.restoreBackup(context, items)
  }

  private static async applyHomeSubtabs(
    context: common.UIAbilityContext,
    records: SyncHomeSubtabRecord[],
  ): Promise<void> {
    // Old v1 envelopes did not contain this dataset. Empty means absent, not
    // an authoritative delete of the locally seeded Home configuration.
    if (records.length === 0) {
      return
    }
    const profiles: HomeSubtabStorageRecord[] = []
    const selection: HomeSubtabSelectionRecord = new HomeSubtabSelectionRecord()
    for (let i: number = 0; i < records.length; i++) {
      const r: SyncHomeSubtabRecord = records[i]
      if (r.profileUuid === HOME_SUBTAB_SELECTION_RECORD) {
        selection.selectedUuid = r.selectedUuid
        selection.updatedAt = r.updatedAt
        selection.deletedAt = r.deletedAt
        continue
      }
      if (r.profileUuid.length === 0) {
        continue
      }
      const item: HomeSubtabStorageRecord = new HomeSubtabStorageRecord()
      item.positionIndex = r.positionIndex
      item.deletedAt = r.deletedAt
      item.profile.uuid = r.profileUuid
      item.profile.kind = NhHomeSubtabProfile.normalizeKind(r.kind)
      item.profile.name = r.name
      item.profile.query = r.queryText
      item.profile.language = NhHomeSubtabProfile.normalizeLanguage(r.language)
      item.profile.sort = NhHomeSubtabProfile.normalizeSort(r.sort)
      item.profile.presentation = r.displayMode
      item.profile.hidden = r.hidden
      item.profile.lastEditTime = r.updatedAt
      profiles.push(item)
    }
    await HomeSubtabRepository.importRecords(context, profiles, selection)
    await HomeSubtabSettings.refreshFromStorage(context)
  }

  private static async applyLocalBlockSettings(
    _context: common.UIAbilityContext,
    _records: SyncLocalBlockSettingsRecord[],
  ): Promise<void> {
    // NH has no comment-score scalars. The dataset is always empty on export
    // and is a no-op on import; the class is retained for NextE parity.
  }

  private static async applyLocalBlockRules(
    context: common.UIAbilityContext,
    records: SyncLocalBlockRuleRecord[],
  ): Promise<void> {
    const ordered: SyncLocalBlockRuleRecord[] = records.slice()
    ordered.sort((a: SyncLocalBlockRuleRecord, b: SyncLocalBlockRuleRecord): number => {
      return a.positionIndex - b.positionIndex
    })
    const rules: NhContentFilterRule[] = []
    for (let i: number = 0; i < ordered.length; i++) {
      const r: SyncLocalBlockRuleRecord = ordered[i]
      if (r.deletedAt > 0 || r.ruleId.length === 0 || r.ruleText.trim().length === 0) {
        continue
      }
      const rule: NhContentFilterRule = new NhContentFilterRule()
      rule.id = r.ruleId
      rule.type = SyncLocalDataAdapter.normalizeBlockType(r.blockType)
      rule.text = r.ruleText
      rule.enabled = r.enabled
      rule.isRegex = r.enableRegex
      rules.push(rule)
    }
    await ContentFilterRepository.restoreBackup(context, rules)
  }

  private static async applySettingsTables(
    context: common.UIAbilityContext,
    records: SyncSettingsTableRecord[],
  ): Promise<void> {
    const byTable: Record<string, Record<string, string>> = {}
    for (let i: number = 0; i < records.length; i++) {
      const r: SyncSettingsTableRecord = records[i]
      if (r.deletedAt > 0 || r.key.length === 0 || SETTINGS_TABLE_NAMES.indexOf(r.tableName) < 0) {
        continue
      }
      let table: Record<string, string> | undefined = byTable[r.tableName]
      if (table === undefined) {
        table = {}
        byTable[r.tableName] = table
      }
      table[r.key] = r.value
    }
    await ReaderSettingsRepository.restoreBackup(
      context,
      SyncLocalDataAdapter.tableValues(byTable, TABLE_READER_SETTINGS),
    )
    await DownloadSettingsRepository.restoreBackup(
      context,
      SyncLocalDataAdapter.tableValues(byTable, TABLE_DOWNLOAD_SETTINGS),
    )
    await BrowsePresentationRepository.restoreBackup(
      context,
      SyncLocalDataAdapter.tableValues(byTable, TABLE_BROWSE_PRESENTATION_SETTINGS),
    )
    await CatalogPreferencesRepository.restoreBackup(
      context,
      SyncLocalDataAdapter.tableValues(byTable, TABLE_CATALOG_PREFERENCES),
    )
  }

  private static tableValues(
    byTable: Record<string, Record<string, string>>,
    tableName: string,
  ): Record<string, string> {
    const values: Record<string, string> | undefined = byTable[tableName]
    if (values === undefined) {
      const empty: Record<string, string> = {}
      return empty
    }
    return values
  }

  private static mergeReadProgress(
    a: SyncReadProgressRecord[],
    b: SyncReadProgressRecord[],
  ): SyncReadProgressRecord[] {
    const map: Map<string, SyncReadProgressRecord> = new Map<string, SyncReadProgressRecord>()
    a.forEach((r: SyncReadProgressRecord): void => SyncLocalDataAdapter.keepReadProgress(map, r))
    b.forEach((r: SyncReadProgressRecord): void => SyncLocalDataAdapter.keepReadProgress(map, r))
    const out: SyncReadProgressRecord[] = []
    map.forEach((r: SyncReadProgressRecord): void => { out.push(r) })
    return out
  }

  private static keepReadProgress(
    map: Map<string, SyncReadProgressRecord>,
    r: SyncReadProgressRecord,
  ): void {
    const key: string = SyncLocalDataAdapter.readProgressKey(r)
    const prev: SyncReadProgressRecord | undefined = map.get(key)
    if (prev === undefined ||
      SyncLocalDataAdapter.effectiveTime(r.updatedAt, r.deletedAt) >=
      SyncLocalDataAdapter.effectiveTime(prev.updatedAt, prev.deletedAt)) {
      map.set(key, r)
    }
  }

  private static mergeViewedHistory(
    a: SyncViewedHistoryRecord[],
    b: SyncViewedHistoryRecord[],
  ): SyncViewedHistoryRecord[] {
    const map: Map<string, SyncViewedHistoryRecord> = new Map<string, SyncViewedHistoryRecord>()
    a.forEach((r: SyncViewedHistoryRecord): void => SyncLocalDataAdapter.keepViewedHistory(map, r))
    b.forEach((r: SyncViewedHistoryRecord): void => SyncLocalDataAdapter.keepViewedHistory(map, r))
    const out: SyncViewedHistoryRecord[] = []
    map.forEach((r: SyncViewedHistoryRecord): void => { out.push(r) })
    return out
  }

  private static keepViewedHistory(
    map: Map<string, SyncViewedHistoryRecord>,
    r: SyncViewedHistoryRecord,
  ): void {
    const key: string = SyncLocalDataAdapter.viewedHistoryKey(r)
    const prev: SyncViewedHistoryRecord | undefined = map.get(key)
    if (prev === undefined) {
      map.set(key, r)
      return
    }
    if (SyncLocalDataAdapter.effectiveTime(r.viewedAt, r.deletedAt) >=
      SyncLocalDataAdapter.effectiveTime(prev.viewedAt, prev.deletedAt)) {
      SyncLocalDataAdapter.fillViewedHistorySnapshot(r, prev)
      map.set(key, r)
    } else {
      SyncLocalDataAdapter.fillViewedHistorySnapshot(prev, r)
    }
  }

  /**
   * NextE's snapshot fill adapted to the NH display row: when the newer row
   * lacks display/progress fields, they are recovered from the older row so
   * a progress-only merge never loses the visible history row.
   */
  private static fillViewedHistorySnapshot(
    target: SyncViewedHistoryRecord,
    fallback: SyncViewedHistoryRecord,
  ): void {
    if (target.mediaId.length === 0) target.mediaId = fallback.mediaId
    if (target.title.length === 0) target.title = fallback.title
    if (target.thumbnailUrl.length === 0) target.thumbnailUrl = fallback.thumbnailUrl
    if (target.pageCount <= 0) target.pageCount = fallback.pageCount
    if (!target.hasReadProgress) {
      target.hasReadProgress = fallback.hasReadProgress
      if (fallback.hasReadProgress) {
        target.lastReadIndex = fallback.lastReadIndex
      }
    }
  }

  private static mergeSearchHistory(
    a: SyncSearchHistoryRecord[],
    b: SyncSearchHistoryRecord[],
  ): SyncSearchHistoryRecord[] {
    const map: Map<string, SyncSearchHistoryRecord> = new Map<string, SyncSearchHistoryRecord>()
    a.forEach((r: SyncSearchHistoryRecord): void => SyncLocalDataAdapter.keepSearchHistory(map, r))
    b.forEach((r: SyncSearchHistoryRecord): void => SyncLocalDataAdapter.keepSearchHistory(map, r))
    const out: SyncSearchHistoryRecord[] = []
    map.forEach((r: SyncSearchHistoryRecord): void => { out.push(r) })
    return out
  }

  private static keepSearchHistory(
    map: Map<string, SyncSearchHistoryRecord>,
    r: SyncSearchHistoryRecord,
  ): void {
    const key: string = SyncLocalDataAdapter.searchHistoryKey(r)
    const prev: SyncSearchHistoryRecord | undefined = map.get(key)
    if (prev === undefined ||
      SyncLocalDataAdapter.effectiveTime(r.updatedAt, r.deletedAt) >=
      SyncLocalDataAdapter.effectiveTime(prev.updatedAt, prev.deletedAt)) {
      map.set(key, r)
    }
  }

  private static mergeQuickSearches(
    a: SyncQuickSearchRecord[],
    b: SyncQuickSearchRecord[],
  ): SyncQuickSearchRecord[] {
    const map: Map<string, SyncQuickSearchRecord> = new Map<string, SyncQuickSearchRecord>()
    a.forEach((r: SyncQuickSearchRecord): void => SyncLocalDataAdapter.keepQuickSearch(map, r))
    b.forEach((r: SyncQuickSearchRecord): void => SyncLocalDataAdapter.keepQuickSearch(map, r))
    const out: SyncQuickSearchRecord[] = []
    map.forEach((r: SyncQuickSearchRecord): void => { out.push(r) })
    return out
  }

  private static mergeHomeSubtabs(
    a: SyncHomeSubtabRecord[],
    b: SyncHomeSubtabRecord[],
  ): SyncHomeSubtabRecord[] {
    const map: Map<string, SyncHomeSubtabRecord> = new Map<string, SyncHomeSubtabRecord>()
    a.forEach((r: SyncHomeSubtabRecord): void => SyncLocalDataAdapter.keepHomeSubtab(map, r))
    b.forEach((r: SyncHomeSubtabRecord): void => SyncLocalDataAdapter.keepHomeSubtab(map, r))
    const out: SyncHomeSubtabRecord[] = []
    map.forEach((r: SyncHomeSubtabRecord): void => { out.push(r) })
    return out
  }

  private static keepHomeSubtab(
    map: Map<string, SyncHomeSubtabRecord>,
    r: SyncHomeSubtabRecord,
  ): void {
    const key: string = SyncLocalDataAdapter.homeSubtabKey(r)
    const prev: SyncHomeSubtabRecord | undefined = map.get(key)
    if (prev === undefined ||
      SyncLocalDataAdapter.effectiveTime(r.updatedAt, r.deletedAt) >=
      SyncLocalDataAdapter.effectiveTime(prev.updatedAt, prev.deletedAt)) {
      map.set(key, r)
    }
  }

  private static keepQuickSearch(
    map: Map<string, SyncQuickSearchRecord>,
    r: SyncQuickSearchRecord,
  ): void {
    const key: string = SyncLocalDataAdapter.quickSearchKey(r)
    const prev: SyncQuickSearchRecord | undefined = map.get(key)
    if (prev === undefined ||
      SyncLocalDataAdapter.effectiveTime(r.updatedAt, r.deletedAt) >=
      SyncLocalDataAdapter.effectiveTime(prev.updatedAt, prev.deletedAt)) {
      map.set(key, r)
    }
  }

  private static mergeLocalBlockSettings(
    a: SyncLocalBlockSettingsRecord[],
    b: SyncLocalBlockSettingsRecord[],
  ): SyncLocalBlockSettingsRecord[] {
    const map: Map<string, SyncLocalBlockSettingsRecord> = new Map<string, SyncLocalBlockSettingsRecord>()
    a.forEach((r: SyncLocalBlockSettingsRecord): void => SyncLocalDataAdapter.keepLocalBlockSettings(map, r))
    b.forEach((r: SyncLocalBlockSettingsRecord): void => SyncLocalDataAdapter.keepLocalBlockSettings(map, r))
    const out: SyncLocalBlockSettingsRecord[] = []
    map.forEach((r: SyncLocalBlockSettingsRecord): void => { out.push(r) })
    return out
  }

  private static keepLocalBlockSettings(
    map: Map<string, SyncLocalBlockSettingsRecord>,
    r: SyncLocalBlockSettingsRecord,
  ): void {
    const prev: SyncLocalBlockSettingsRecord | undefined = map.get(r.scopeKey)
    if (prev === undefined ||
      SyncLocalDataAdapter.effectiveTime(r.updatedAt, r.deletedAt) >=
      SyncLocalDataAdapter.effectiveTime(prev.updatedAt, prev.deletedAt)) {
      map.set(r.scopeKey, r)
    }
  }

  private static mergeLocalBlockRules(
    a: SyncLocalBlockRuleRecord[],
    b: SyncLocalBlockRuleRecord[],
  ): SyncLocalBlockRuleRecord[] {
    const map: Map<string, SyncLocalBlockRuleRecord> = new Map<string, SyncLocalBlockRuleRecord>()
    a.forEach((r: SyncLocalBlockRuleRecord): void => SyncLocalDataAdapter.keepLocalBlockRule(map, r))
    b.forEach((r: SyncLocalBlockRuleRecord): void => SyncLocalDataAdapter.keepLocalBlockRule(map, r))
    const out: SyncLocalBlockRuleRecord[] = []
    map.forEach((r: SyncLocalBlockRuleRecord): void => { out.push(r) })
    return out
  }

  private static keepLocalBlockRule(
    map: Map<string, SyncLocalBlockRuleRecord>,
    r: SyncLocalBlockRuleRecord,
  ): void {
    const key: string = SyncLocalDataAdapter.localBlockRuleKey(r)
    const prev: SyncLocalBlockRuleRecord | undefined = map.get(key)
    if (prev === undefined ||
      SyncLocalDataAdapter.effectiveTime(r.updatedAt, r.deletedAt) >=
      SyncLocalDataAdapter.effectiveTime(prev.updatedAt, prev.deletedAt)) {
      map.set(key, r)
    }
  }

  private static mergeSettingsTables(
    a: SyncSettingsTableRecord[],
    b: SyncSettingsTableRecord[],
  ): SyncSettingsTableRecord[] {
    const map: Map<string, SyncSettingsTableRecord> = new Map<string, SyncSettingsTableRecord>()
    a.forEach((r: SyncSettingsTableRecord): void => SyncLocalDataAdapter.keepSettingsTable(map, r))
    b.forEach((r: SyncSettingsTableRecord): void => SyncLocalDataAdapter.keepSettingsTable(map, r))
    const out: SyncSettingsTableRecord[] = []
    map.forEach((r: SyncSettingsTableRecord): void => { out.push(r) })
    return out
  }

  private static keepSettingsTable(
    map: Map<string, SyncSettingsTableRecord>,
    r: SyncSettingsTableRecord,
  ): void {
    const key: string = SyncLocalDataAdapter.settingsTableKey(r)
    const prev: SyncSettingsTableRecord | undefined = map.get(key)
    if (prev === undefined ||
      SyncLocalDataAdapter.effectiveTime(r.updatedAt, r.deletedAt) >=
      SyncLocalDataAdapter.effectiveTime(prev.updatedAt, prev.deletedAt)) {
      map.set(key, r)
    }
  }

  private static effectiveTime(updatedAt: number, deletedAt: number): number {
    return Math.max(Math.floor(updatedAt), Math.floor(deletedAt))
  }

  private static compareKey(a: string, b: string): number {
    if (a < b) {
      return -1
    }
    if (a > b) {
      return 1
    }
    return 0
  }

  private static readProgressKey(r: SyncReadProgressRecord): string {
    return r.scopeKey + ':' + r.galleryId.toString()
  }

  private static viewedHistoryKey(r: SyncViewedHistoryRecord): string {
    return r.scopeKey + ':' + r.galleryId.toString()
  }

  private static searchHistoryKey(r: SyncSearchHistoryRecord): string {
    // search_history's NH primary key is normalized_query (trimmed,
    // case-insensitive), so merge/shard placement must use the same
    // normalized value while preserving the original query_text.
    return r.scopeKey + ':' + r.queryText.trim().toLowerCase()
  }

  private static quickSearchKey(r: SyncQuickSearchRecord): string {
    return r.scopeKey + ':' + r.queryText.trim().toLowerCase()
  }

  private static homeSubtabKey(r: SyncHomeSubtabRecord): string {
    return r.scopeKey + ':' + r.profileUuid
  }

  private static localBlockRuleKey(r: SyncLocalBlockRuleRecord): string {
    return r.scopeKey + ':' + r.ruleId
  }

  private static settingsTableKey(r: SyncSettingsTableRecord): string {
    return r.scopeKey + ':' + r.tableName + ':' + r.key
  }

  private static hasReadProgressShape(records: SyncReadProgressRecord[]): boolean {
    for (let i: number = 0; i < records.length; i++) {
      const r: SyncReadProgressRecord = records[i]
      if (!SyncLocalDataAdapter.isRecord(r) ||
        typeof r.scopeKey !== 'string' ||
        typeof r.galleryId !== 'number' ||
        r.galleryId <= 0 ||
        typeof r.pageIndex !== 'number' ||
        r.pageIndex < 0 ||
        typeof r.updatedAt !== 'number' ||
        typeof r.deletedAt !== 'number') {
        return false
      }
    }
    return true
  }

  private static hasViewedHistoryShape(records: SyncViewedHistoryRecord[]): boolean {
    for (let i: number = 0; i < records.length; i++) {
      const r: SyncViewedHistoryRecord = records[i]
      if (!SyncLocalDataAdapter.isRecord(r) ||
        typeof r.scopeKey !== 'string' ||
        typeof r.galleryId !== 'number' ||
        r.galleryId <= 0 ||
        typeof r.mediaId !== 'string' ||
        typeof r.title !== 'string' ||
        typeof r.thumbnailUrl !== 'string' ||
        typeof r.pageCount !== 'number' ||
        typeof r.lastReadIndex !== 'number' ||
        typeof r.hasReadProgress !== 'boolean' ||
        typeof r.viewedAt !== 'number' ||
        typeof r.deletedAt !== 'number') {
        return false
      }
    }
    return true
  }

  private static hasSearchHistoryShape(records: SyncSearchHistoryRecord[]): boolean {
    for (let i: number = 0; i < records.length; i++) {
      const r: SyncSearchHistoryRecord = records[i]
      if (!SyncLocalDataAdapter.isRecord(r) ||
        typeof r.scopeKey !== 'string' ||
        typeof r.queryText !== 'string' ||
        r.queryText.trim().length === 0 ||
        typeof r.positionIndex !== 'number' ||
        typeof r.updatedAt !== 'number' ||
        typeof r.deletedAt !== 'number') {
        return false
      }
    }
    return true
  }

  private static hasQuickSearchShape(records: SyncQuickSearchRecord[]): boolean {
    for (let i: number = 0; i < records.length; i++) {
      const r: SyncQuickSearchRecord = records[i]
      if (!SyncLocalDataAdapter.isRecord(r) ||
        typeof r.scopeKey !== 'string' ||
        typeof r.queryText !== 'string' ||
        r.queryText.trim().length === 0 ||
        typeof r.pinnedAt !== 'number' ||
        typeof r.updatedAt !== 'number' ||
        typeof r.deletedAt !== 'number') {
        return false
      }
    }
    return true
  }

  private static hasHomeSubtabShape(records: SyncHomeSubtabRecord[]): boolean {
    for (let i: number = 0; i < records.length; i++) {
      const r: SyncHomeSubtabRecord = records[i]
      if (!SyncLocalDataAdapter.isRecord(r) ||
        typeof r.scopeKey !== 'string' ||
        typeof r.profileUuid !== 'string' || r.profileUuid.length === 0 ||
        typeof r.positionIndex !== 'number' ||
        typeof r.kind !== 'string' || typeof r.name !== 'string' ||
        typeof r.queryText !== 'string' || typeof r.language !== 'string' ||
        typeof r.sort !== 'string' || typeof r.displayMode !== 'string' ||
        typeof r.hidden !== 'boolean' || typeof r.selectedUuid !== 'string' ||
        typeof r.updatedAt !== 'number' || typeof r.deletedAt !== 'number') {
        return false
      }
    }
    return true
  }

  private static hasLocalBlockSettingsShape(records: SyncLocalBlockSettingsRecord[]): boolean {
    for (let i: number = 0; i < records.length; i++) {
      const r: SyncLocalBlockSettingsRecord = records[i]
      if (!SyncLocalDataAdapter.isRecord(r) ||
        typeof r.scopeKey !== 'string' ||
        typeof r.filterCommentsByScore !== 'boolean' ||
        typeof r.scoreFilteringThreshold !== 'number' ||
        typeof r.commentDisplayMode !== 'string' ||
        typeof r.updatedAt !== 'number' ||
        typeof r.deletedAt !== 'number') {
        return false
      }
    }
    return true
  }

  private static hasLocalBlockRuleShape(records: SyncLocalBlockRuleRecord[]): boolean {
    for (let i: number = 0; i < records.length; i++) {
      const r: SyncLocalBlockRuleRecord = records[i]
      if (!SyncLocalDataAdapter.isRecord(r) ||
        typeof r.scopeKey !== 'string' ||
        typeof r.ruleId !== 'string' ||
        r.ruleId.length === 0 ||
        typeof r.positionIndex !== 'number' ||
        typeof r.blockType !== 'string' ||
        typeof r.ruleText !== 'string' ||
        typeof r.enabled !== 'boolean' ||
        typeof r.enableRegex !== 'boolean' ||
        typeof r.updatedAt !== 'number' ||
        typeof r.deletedAt !== 'number') {
        return false
      }
    }
    return true
  }

  private static hasSettingsTableShape(records: SyncSettingsTableRecord[]): boolean {
    for (let i: number = 0; i < records.length; i++) {
      const r: SyncSettingsTableRecord = records[i]
      if (!SyncLocalDataAdapter.isRecord(r) ||
        typeof r.scopeKey !== 'string' ||
        typeof r.tableName !== 'string' ||
        SETTINGS_TABLE_NAMES.indexOf(r.tableName) < 0 ||
        typeof r.key !== 'string' ||
        r.key.length === 0 ||
        typeof r.value !== 'string' ||
        typeof r.updatedAt !== 'number' ||
        typeof r.deletedAt !== 'number') {
        return false
      }
    }
    return true
  }

  private static isRecord(value: Object | undefined): boolean {
    return value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value)
  }

  private static safeString(value: Object): string {
    if (typeof value === 'string') {
      return value
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return `${value}`
    }
    return ''
  }

  private static safeNumber(value: Object): number {
    if (typeof value === 'number') {
      return Number.isFinite(value) ? Math.floor(value) : 0
    }
    if (typeof value === 'string') {
      const parsed: number = Number.parseFloat(value)
      return Number.isFinite(parsed) ? Math.floor(parsed) : 0
    }
    if (typeof value === 'boolean') {
      return value ? 1 : 0
    }
    return 0
  }

  private static safeBoolean(value: Object): boolean {
    if (typeof value === 'boolean') {
      return value
    }
    if (typeof value === 'number') {
      return value > 0
    }
    if (typeof value === 'string') {
      const normalized: string = value.toLowerCase()
      return normalized === 'true' || normalized === '1'
    }
    return false
  }

  private static normalizeBlockType(value: string): NhContentFilterType {
    if (value === NhContentFilterType.COMMENTER || value === NhContentFilterType.COMMENT) {
      return value as NhContentFilterType
    }
    return NhContentFilterType.TITLE
  }

}
