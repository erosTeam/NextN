import { common } from '@kit.AbilityKit'
import { connectReadingHistory } from '../state/ReadingHistoryState'
import { BrowsePresentationService } from '../services/BrowsePresentationService'
import { CatalogPreferencesService } from '../services/CatalogPreferencesService'
import { ContentFilterService } from '../services/ContentFilterService'
import { DownloadSettingsService } from '../services/DownloadSettingsService'
import { ReaderPresentationService } from '../services/ReaderPresentationService'
import { HomeSubtabSettings } from '../settings/HomeSubtabSettings'
import { BrowsePresentationRepository } from '../storage/BrowsePresentationRepository'
import { CatalogPreferencesRepository } from '../storage/CatalogPreferencesRepository'
import { ContentFilterRepository } from '../storage/ContentFilterRepository'
import { DownloadSettingsRepository } from '../storage/DownloadSettingsRepository'
import { HistoryRepository } from '../storage/HistoryRepository'
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
import { SyncLocalDataAdapter } from './SyncLocalDataAdapter'

export class SyncService {
  static async exportRaw(
    context: common.UIAbilityContext,
    deviceId: string = '',
    selection: SyncDatasetSelection = new SyncDatasetSelection(),
  ): Promise<string> {
    await SyncService.flushSelectedForExport(context, selection)
    const envelope: SyncEnvelopeV1 = await SyncLocalDataAdapter.exportEnvelope(context, deviceId, selection)
    return JSON.stringify(envelope)
  }

  // Transport-neutral file sync core: merge a remote envelope with local RDB, apply the merged result
  // locally, and return the exact raw payload that the provider should write back.
  static async mergeRemoteRaw(
    context: common.UIAbilityContext,
    remoteRaw: string,
    deviceId: string = '',
    selection: SyncDatasetSelection = new SyncDatasetSelection(),
  ): Promise<string> {
    const remote: SyncEnvelopeV1 = SyncService.parseRaw(remoteRaw)
    const selectedMerged: SyncEnvelopeV1 =
      await SyncService.mergeRemoteEnvelope(context, remote, deviceId, selection)
    const writeBack: SyncEnvelopeV1 =
      SyncLocalDataAdapter.mergeSelectedIntoRemote(remote, selectedMerged, selection, deviceId)
    return JSON.stringify(writeBack)
  }

  static async mergeRemoteEnvelope(
    context: common.UIAbilityContext,
    remote: SyncEnvelopeV1,
    deviceId: string = '',
    selection: SyncDatasetSelection = new SyncDatasetSelection(),
  ): Promise<SyncEnvelopeV1> {
    await SyncService.flushSelectedForExport(context, selection)
    const local: SyncEnvelopeV1 =
      await SyncLocalDataAdapter.exportEnvelope(context, deviceId, selection)
    const selectedRemote: SyncEnvelopeV1 = SyncService.selectDatasets(remote, selection)
    const selectedMerged: SyncEnvelopeV1 =
      SyncLocalDataAdapter.mergeEnvelopes(local, selectedRemote)
    selectedMerged.deviceId = deviceId
    await SyncLocalDataAdapter.applyEnvelope(context, selectedMerged, selection)
    await SyncService.refreshSelectedState(context, selection)
    return selectedMerged
  }

  static async importRaw(context: common.UIAbilityContext, raw: string): Promise<void> {
    const envelope: SyncEnvelopeV1 = SyncService.parseRaw(raw)
    const all: SyncDatasetSelection = new SyncDatasetSelection()
    await SyncService.flushSelectedForExport(context, all)
    await SyncLocalDataAdapter.applyEnvelope(context, envelope)
    await SyncService.refreshSelectedState(context, all)
  }

  static parseRaw(raw: string): SyncEnvelopeV1 {
    if (raw.trim().length === 0) {
      const empty: SyncEnvelopeV1 = new SyncEnvelopeV1()
      empty.generatedAt = new Date().toISOString()
      return empty
    }
    const parsed: SyncEnvelopeV1 = JSON.parse(raw) as SyncEnvelopeV1
    if (parsed.magic !== SYNC_MAGIC || parsed.appId !== SYNC_APP_ID) {
      throw new Error('Invalid NextN sync file')
    }
    if (
      parsed.schemaVersion !== SYNC_SCHEMA_VERSION ||
      parsed.minSupportedSchemaVersion > SYNC_SCHEMA_VERSION
    ) {
      throw new Error('Unsupported NextN sync schema')
    }
    if (parsed.datasets === null || parsed.datasets === undefined) {
      parsed.datasets = new SyncDatasets()
    }
    SyncService.normalizeDatasets(parsed)
    return parsed
  }

  private static normalizeDatasets(envelope: SyncEnvelopeV1): void {
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
      r.scopeKey = SyncService.safeString(r.scopeKey)
      r.galleryId = SyncService.safeNumber(r.galleryId)
      r.pageIndex = SyncService.safeNumber(r.pageIndex)
      r.updatedAt = SyncService.safeNumber(r.updatedAt)
      r.deletedAt = SyncService.safeNumber(r.deletedAt)
    }
    for (let i: number = 0; i < data.viewedHistory.length; i++) {
      const r: SyncViewedHistoryRecord = data.viewedHistory[i]
      r.scopeKey = SyncService.safeString(r.scopeKey)
      r.galleryId = SyncService.safeNumber(r.galleryId)
      r.mediaId = SyncService.safeString(r.mediaId)
      r.title = SyncService.safeString(r.title)
      r.thumbnailUrl = SyncService.safeString(r.thumbnailUrl)
      r.pageCount = SyncService.safeNumber(r.pageCount)
      r.lastReadIndex = SyncService.safeNumber(r.lastReadIndex)
      r.hasReadProgress = SyncService.safeBoolean(r.hasReadProgress)
      r.viewedAt = SyncService.safeNumber(r.viewedAt)
      r.deletedAt = SyncService.safeNumber(r.deletedAt)
    }
    for (let i: number = 0; i < data.searchHistory.length; i++) {
      const r: SyncSearchHistoryRecord = data.searchHistory[i]
      r.scopeKey = SyncService.safeString(r.scopeKey)
      r.queryText = SyncService.safeString(r.queryText)
      r.positionIndex = SyncService.safeNumber(r.positionIndex)
      r.updatedAt = SyncService.safeNumber(r.updatedAt)
      r.deletedAt = SyncService.safeNumber(r.deletedAt)
    }
    for (let i: number = 0; i < data.quickSearches.length; i++) {
      const r: SyncQuickSearchRecord = data.quickSearches[i]
      r.scopeKey = SyncService.safeString(r.scopeKey)
      r.queryText = SyncService.safeString(r.queryText)
      r.pinnedAt = SyncService.safeNumber(r.pinnedAt)
      r.updatedAt = SyncService.safeNumber(r.updatedAt)
      r.deletedAt = SyncService.safeNumber(r.deletedAt)
    }
    for (let i: number = 0; i < data.homeSubtabs.length; i++) {
      const r: SyncHomeSubtabRecord = data.homeSubtabs[i]
      r.scopeKey = SyncService.safeString(r.scopeKey)
      r.profileUuid = SyncService.safeString(r.profileUuid)
      r.positionIndex = SyncService.safeNumber(r.positionIndex)
      r.kind = SyncService.safeString(r.kind)
      r.name = SyncService.safeString(r.name)
      r.queryText = SyncService.safeString(r.queryText)
      r.language = SyncService.safeString(r.language)
      r.sort = SyncService.safeString(r.sort)
      r.displayMode = SyncService.safeString(r.displayMode)
      r.hidden = SyncService.safeBoolean(r.hidden)
      r.selectedUuid = SyncService.safeString(r.selectedUuid)
      r.updatedAt = SyncService.safeNumber(r.updatedAt)
      r.deletedAt = SyncService.safeNumber(r.deletedAt)
    }
    for (let i: number = 0; i < data.localBlockSettings.length; i++) {
      const r: SyncLocalBlockSettingsRecord = data.localBlockSettings[i]
      r.scopeKey = SyncService.safeString(r.scopeKey)
      r.filterCommentsByScore = SyncService.safeBoolean(r.filterCommentsByScore)
      r.scoreFilteringThreshold = SyncService.safeNumber(r.scoreFilteringThreshold)
      r.commentDisplayMode = SyncService.safeString(r.commentDisplayMode)
      r.updatedAt = SyncService.safeNumber(r.updatedAt)
      r.deletedAt = SyncService.safeNumber(r.deletedAt)
    }
    for (let i: number = 0; i < data.localBlockRules.length; i++) {
      const r: SyncLocalBlockRuleRecord = data.localBlockRules[i]
      r.scopeKey = SyncService.safeString(r.scopeKey)
      r.ruleId = SyncService.safeString(r.ruleId)
      r.positionIndex = SyncService.safeNumber(r.positionIndex)
      r.blockType = SyncService.safeString(r.blockType)
      r.ruleText = SyncService.safeString(r.ruleText)
      r.enabled = SyncService.safeBoolean(r.enabled)
      r.enableRegex = SyncService.safeBoolean(r.enableRegex)
      r.updatedAt = SyncService.safeNumber(r.updatedAt)
      r.deletedAt = SyncService.safeNumber(r.deletedAt)
    }
    for (let i: number = 0; i < data.settingsTables.length; i++) {
      const r: SyncSettingsTableRecord = data.settingsTables[i]
      r.scopeKey = SyncService.safeString(r.scopeKey)
      r.tableName = SyncService.safeString(r.tableName)
      r.key = SyncService.safeString(r.key)
      r.value = SyncService.safeString(r.value)
      r.updatedAt = SyncService.safeNumber(r.updatedAt)
      r.deletedAt = SyncService.safeNumber(r.deletedAt)
    }
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

  /**
   * Drains any queued local RDB writes for the selected NH datasets before a
   * provider reads them. NextN repositories persist through awaited write
   * tails, so this is a contract-preserving drain equivalent to the NextE
   * settings flushForSync chain.
   */
  private static async flushSelectedForExport(
    context: common.UIAbilityContext,
    selection: SyncDatasetSelection,
  ): Promise<void> {
    if (selection.readProgress || selection.viewedHistory) {
      await HistoryRepository.exportForBackup(context)
    }
    if (selection.searchHistory) {
      await SearchHistoryRepository.exportForBackup(context)
    }
    if (selection.quickSearches) {
      await QuickSearchRepository.exportForBackup(context)
    }
    if (selection.homeSubtabs) {
      await HomeSubtabSettings.flushForSync()
    }
    if (selection.localBlock) {
      await ContentFilterRepository.exportForBackup(context)
    }
    if (selection.settingsTables) {
      await ReaderSettingsRepository.exportForBackup(context)
      await DownloadSettingsRepository.exportForBackup(context)
      await BrowsePresentationRepository.exportForBackup(context)
      await CatalogPreferencesRepository.exportForBackup(context)
    }
  }

  private static selectDatasets(
    source: SyncEnvelopeV1,
    selection: SyncDatasetSelection,
  ): SyncEnvelopeV1 {
    const out: SyncEnvelopeV1 = new SyncEnvelopeV1()
    out.generatedAt = source.generatedAt
    out.deviceId = source.deviceId
    if (selection.readProgress) {
      out.datasets.readProgress = source.datasets.readProgress
    }
    if (selection.viewedHistory) {
      out.datasets.viewedHistory = source.datasets.viewedHistory
    }
    if (selection.searchHistory) {
      out.datasets.searchHistory = source.datasets.searchHistory
    }
    if (selection.quickSearches) {
      out.datasets.quickSearches = source.datasets.quickSearches
    }
    if (selection.homeSubtabs) {
      out.datasets.homeSubtabs = source.datasets.homeSubtabs
    }
    if (selection.localBlock) {
      out.datasets.localBlockSettings = source.datasets.localBlockSettings
      out.datasets.localBlockRules = source.datasets.localBlockRules
    }
    if (selection.settingsTables) {
      out.datasets.settingsTables = source.datasets.settingsTables
    }
    return out
  }

  static async refreshSelectedState(
    context: common.UIAbilityContext,
    selection: SyncDatasetSelection,
  ): Promise<void> {
    if (selection.readProgress || selection.viewedHistory) {
      connectReadingHistory().publishMutation()
    }
    if (selection.localBlock) {
      await ContentFilterService.restore(context)
    }
    if (selection.homeSubtabs) {
      await HomeSubtabSettings.refreshFromStorage(context)
    }
    if (selection.settingsTables) {
      await ReaderPresentationService.restoreFromBackup(context)
      await DownloadSettingsService.restoreFromBackup(context)
      await BrowsePresentationService.restore(context)
      await CatalogPreferencesService.restoreFromBackup(context)
    }
  }
}
