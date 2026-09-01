import { common } from '@kit.AbilityKit'
import { NhContentFilterRule, NhContentFilterType } from '../model/NhContentFilter'
import { NhQuickSearchItem } from '../model/NhQuickSearch'
import { NhReadingHistoryItem } from '../model/NhGallery'
import { NhHomeSubtabProfile } from '../model/NhHomeSubtabProfile'
import {
  NhLocalUserTag,
  NhLocalUserTagSettings,
  NhLocalUserTagSnapshot,
} from '../model/NhLocalUserTag'
import { HomeSubtabBackupSnapshot, HomeSubtabSettings } from '../settings/HomeSubtabSettings'
import { BrowsePresentationRepository } from '../storage/BrowsePresentationRepository'
import { CatalogPreferencesRepository } from '../storage/CatalogPreferencesRepository'
import { ContentFilterRepository } from '../storage/ContentFilterRepository'
import { DownloadSettingsRepository } from '../storage/DownloadSettingsRepository'
import { HistoryRepository } from '../storage/HistoryRepository'
import { NhLocalUserTagRepository } from '../storage/NhLocalUserTagRepository'
import { QuickSearchRepository } from '../storage/QuickSearchRepository'
import { ReaderSettingsRepository } from '../storage/ReaderSettingsRepository'
import { SearchHistoryRepository } from '../storage/SearchHistoryRepository'
import {
  BackupLocalBlockRuleEntry,
  BackupLocalBlockSection,
  BackupHomeSubtabEntry,
  BackupHomeSubtabSection,
  BackupLocalDataSection,
  BackupLocalUserTagEntry,
  BackupLocalUserTagSettingsEntry,
  BackupQuickSearchEntry,
  BackupReadProgressEntry,
  BackupViewedHistoryEntry,
} from './BackupTypes'

/**
 * Reads/writes NextN's durable RDB datasets for backup (ported from the NextE
 * backup chain). The NH data-source leaf replaces NextE's table set:
 *   - reading_history        -> readProgress + viewedHistory (single NH table)
 *   - search_history         -> searchHistory
 *   - search_quick           -> quickSearches (NH leaf; NextE has no equivalent)
 *   - content_filter_rules   -> localBlock (NH leaf for NextE's block rules)
 *   - reader/download/browse/catalog settings -> settingsTables (key-value)
 * Restore is an authoritative replacement with the same complete-shape guard
 * and rollback semantics as NextE: a missing or malformed section must never
 * become an empty replacement.
 */
export class BackupLocalDataAdapter {
  static async exportSection(context: common.UIAbilityContext): Promise<BackupLocalDataSection> {
    const localUserTags: NhLocalUserTagSnapshot = await NhLocalUserTagRepository.exportSnapshot(context)
    return {
      readProgress: await BackupLocalDataAdapter.exportReadProgress(context),
      viewedHistory: await BackupLocalDataAdapter.exportViewedHistory(context),
      searchHistory: await BackupLocalDataAdapter.exportSearchHistory(context),
      quickSearches: await BackupLocalDataAdapter.exportQuickSearches(context),
      homeSubtabs: await BackupLocalDataAdapter.exportHomeSubtabs(context),
      localUserTags: BackupLocalDataAdapter.exportLocalUserTags(localUserTags),
      localUserTagSettings: [BackupLocalDataAdapter.exportLocalUserTagSettings(localUserTags.settings)],
      localBlock: await BackupLocalDataAdapter.exportLocalBlock(context),
      settingsTables: await BackupLocalDataAdapter.exportSettingsTables(context),
    }
  }

  private static exportLocalUserTags(snapshot: NhLocalUserTagSnapshot): BackupLocalUserTagEntry[] {
    const out: BackupLocalUserTagEntry[] = []
    for (let index: number = 0; index < snapshot.tags.length; index++) {
      const record: NhLocalUserTag = snapshot.tags[index]
      out.push({
        scopeKey: record.scopeKey,
        tagId: record.tagId,
        namespaceSnapshot: record.namespaceSnapshot,
        nameSnapshot: record.nameSnapshot,
        colorCode: record.colorCode,
        weight: record.weight,
        hidden: record.hidden,
        updatedAt: record.updatedAt,
        deletedAt: record.deletedAt,
      })
    }
    return out
  }

  private static exportLocalUserTagSettings(
    settings: NhLocalUserTagSettings,
  ): BackupLocalUserTagSettingsEntry {
    return {
      scopeKey: settings.scopeKey,
      filteringThreshold: settings.filteringThreshold,
      updatedAt: settings.updatedAt,
      deletedAt: settings.deletedAt,
    }
  }

  private static async exportReadProgress(
    context: common.UIAbilityContext,
  ): Promise<BackupReadProgressEntry[]> {
    const source: NhReadingHistoryItem[] = await HistoryRepository.exportForBackup(context)
    const out: BackupReadProgressEntry[] = []
    for (let i: number = 0; i < source.length; i++) {
      const item: NhReadingHistoryItem = source[i]
      if (item.galleryId > 0 && item.hasReadProgress) {
        out.push({
          g: item.galleryId.toString(),
          i: item.lastReadIndex,
          t: item.lastOpenedAt,
          c: '',
        })
      }
    }
    return out
  }

  private static async exportViewedHistory(
    context: common.UIAbilityContext,
  ): Promise<BackupViewedHistoryEntry[]> {
    const source: NhReadingHistoryItem[] = await HistoryRepository.exportForBackup(context)
    const out: BackupViewedHistoryEntry[] = []
    for (let i: number = 0; i < source.length; i++) {
      const item: NhReadingHistoryItem = source[i]
      if (item.galleryId <= 0) {
        continue
      }
      out.push({
        galleryId: item.galleryId,
        mediaId: item.mediaId,
        title: item.title,
        thumbnailUrl: item.thumbnailUrl,
        pageCount: item.pageCount,
        lastReadIndex: item.lastReadIndex,
        hasReadProgress: item.hasReadProgress,
        lastOpenedAt: item.lastOpenedAt,
      })
    }
    return out
  }

  private static async exportSearchHistory(context: common.UIAbilityContext): Promise<string[]> {
    return SearchHistoryRepository.exportForBackup(context)
  }

  private static async exportQuickSearches(
    context: common.UIAbilityContext,
  ): Promise<BackupQuickSearchEntry[]> {
    const source: NhQuickSearchItem[] = await QuickSearchRepository.exportForBackup(context)
    const out: BackupQuickSearchEntry[] = []
    for (let i: number = 0; i < source.length; i++) {
      const item: NhQuickSearchItem = source[i]
      if (item.query.trim().length > 0) {
        out.push({ q: item.query, p: item.pinnedAt })
      }
    }
    return out
  }

  private static async exportHomeSubtabs(
    context: common.UIAbilityContext,
  ): Promise<BackupHomeSubtabSection> {
    const snapshot: HomeSubtabBackupSnapshot = await HomeSubtabSettings.exportForBackup(context)
    const profiles: BackupHomeSubtabEntry[] = []
    for (let i: number = 0; i < snapshot.profiles.length; i++) {
      const profile: NhHomeSubtabProfile = snapshot.profiles[i]
      profiles.push({
        uuid: profile.uuid,
        kind: profile.kind,
        name: profile.name,
        query: profile.query,
        language: profile.language,
        sort: profile.sort,
        presentation: profile.presentation,
        hidden: profile.hidden,
        ignoreLocalUserTagFiltering: profile.ignoreLocalUserTagFiltering,
        updatedAt: profile.lastEditTime,
      })
    }
    return { profiles: profiles, selectedUuid: snapshot.selectedUuid }
  }

  private static async exportLocalBlock(
    context: common.UIAbilityContext,
  ): Promise<BackupLocalBlockSection> {
    const source: NhContentFilterRule[] = await ContentFilterRepository.exportForBackup(context)
    const rules: BackupLocalBlockRuleEntry[] = []
    for (let i: number = 0; i < source.length; i++) {
      const rule: NhContentFilterRule = source[i]
      if (rule.text.trim().length === 0) {
        continue
      }
      rules.push({
        id: rule.id,
        blockType: rule.type,
        ruleText: rule.text,
        enabled: rule.enabled,
        enableRegex: rule.isRegex,
      })
    }
    return {
      // NH has no comment-score scalars; defaults keep NextE envelope parity.
      filterCommentsByScore: false,
      scoreFilteringThreshold: 0,
      commentDisplayMode: '',
      rules: rules,
    }
  }

  private static async exportSettingsTables(
    context: common.UIAbilityContext,
  ): Promise<Record<string, Record<string, string>>> {
    const tables: Record<string, Record<string, string>> = {}
    tables['reader_settings'] = await ReaderSettingsRepository.exportForBackup(context)
    tables['download_settings'] = await DownloadSettingsRepository.exportForBackup(context)
    tables['browse_presentation_settings'] = await BrowsePresentationRepository.exportForBackup(context)
    tables['catalog_preferences'] = await CatalogPreferencesRepository.exportForBackup(context)
    return tables
  }

  /**
   * A local-data backup is an authoritative replacement for several durable
   * tables. Validate its complete runtime shape before any restore can turn a
   * missing or damaged field into an empty replacement.
   */
  static hasCompleteRestoreShape(section: BackupLocalDataSection | undefined): boolean {
    if (!BackupLocalDataAdapter.isRecord(section)) {
      return false
    }
    const candidate: BackupLocalDataSection = section as BackupLocalDataSection
    if (
      !Array.isArray(candidate.readProgress) ||
      !Array.isArray(candidate.viewedHistory) ||
      !Array.isArray(candidate.searchHistory) ||
      !Array.isArray(candidate.quickSearches) ||
      !BackupLocalDataAdapter.hasLocalBlockShape(candidate.localBlock) ||
      !BackupLocalDataAdapter.hasSettingsTablesShape(candidate.settingsTables)
    ) {
      return false
    }
    return (
      BackupLocalDataAdapter.hasReadProgressEntries(candidate.readProgress) &&
      BackupLocalDataAdapter.hasViewedHistoryEntries(candidate.viewedHistory) &&
      BackupLocalDataAdapter.hasSearchHistoryEntries(candidate.searchHistory) &&
      BackupLocalDataAdapter.hasQuickSearchEntries(candidate.quickSearches) &&
      BackupLocalDataAdapter.hasHomeSubtabSection(candidate.homeSubtabs) &&
      BackupLocalDataAdapter.hasLocalUserTagSections(
        candidate.localUserTags,
        candidate.localUserTagSettings,
      )
    )
  }

  private static hasLocalUserTagSections(
    tags: BackupLocalUserTagEntry[] | undefined,
    settings: BackupLocalUserTagSettingsEntry[] | undefined,
  ): boolean {
    if (tags === undefined && settings === undefined) {
      return true
    }
    if (!Array.isArray(tags) || !Array.isArray(settings) || settings.length !== 1) {
      return false
    }
    for (let index: number = 0; index < tags.length; index++) {
      const record: BackupLocalUserTagEntry = tags[index]
      if (!BackupLocalDataAdapter.isRecord(record) || typeof record.scopeKey !== 'string' ||
        typeof record.tagId !== 'number' || record.tagId <= 0 ||
        typeof record.namespaceSnapshot !== 'string' || typeof record.nameSnapshot !== 'string' ||
        typeof record.colorCode !== 'string' || typeof record.weight !== 'number' ||
        typeof record.hidden !== 'boolean' || typeof record.updatedAt !== 'number' ||
        typeof record.deletedAt !== 'number') {
        return false
      }
    }
    const value: BackupLocalUserTagSettingsEntry = settings[0]
    return BackupLocalDataAdapter.isRecord(value) && typeof value.scopeKey === 'string' &&
      typeof value.filteringThreshold === 'number' && typeof value.updatedAt === 'number' &&
      typeof value.deletedAt === 'number'
  }

  private static hasHomeSubtabSection(section: BackupHomeSubtabSection | undefined): boolean {
    // Missing is the explicit backward-compatible empty dataset.
    if (section === undefined) {
      return true
    }
    if (!BackupLocalDataAdapter.isRecord(section) || !Array.isArray(section.profiles) ||
      typeof section.selectedUuid !== 'string') {
      return false
    }
    for (let i: number = 0; i < section.profiles.length; i++) {
      const entry: BackupHomeSubtabEntry = section.profiles[i]
      if (!BackupLocalDataAdapter.isRecord(entry) || typeof entry.uuid !== 'string' ||
        entry.uuid.length === 0 || typeof entry.kind !== 'string' || typeof entry.name !== 'string' ||
        typeof entry.query !== 'string' || typeof entry.language !== 'string' ||
        typeof entry.sort !== 'string' || typeof entry.presentation !== 'string' ||
        typeof entry.hidden !== 'boolean' || typeof entry.updatedAt !== 'number') {
        return false
      }
      if (entry.ignoreLocalUserTagFiltering !== undefined &&
        typeof entry.ignoreLocalUserTagFiltering !== 'boolean') {
        return false
      }
    }
    return true
  }

  private static hasReadProgressEntries(entries: BackupReadProgressEntry[]): boolean {
    for (let i: number = 0; i < entries.length; i++) {
      const entry: BackupReadProgressEntry = entries[i]
      if (
        !BackupLocalDataAdapter.isRecord(entry) ||
        typeof entry.g !== 'string' ||
        entry.g.length === 0 ||
        typeof entry.i !== 'number' ||
        entry.i < 0 ||
        typeof entry.t !== 'number' ||
        (entry.c !== undefined && typeof entry.c !== 'string')
      ) {
        return false
      }
    }
    return true
  }

  private static hasViewedHistoryEntries(entries: BackupViewedHistoryEntry[]): boolean {
    for (let i: number = 0; i < entries.length; i++) {
      const entry: BackupViewedHistoryEntry = entries[i]
      if (
        !BackupLocalDataAdapter.isRecord(entry) ||
        typeof entry.galleryId !== 'number' ||
        entry.galleryId <= 0 ||
        typeof entry.mediaId !== 'string' ||
        typeof entry.title !== 'string' ||
        typeof entry.thumbnailUrl !== 'string' ||
        typeof entry.pageCount !== 'number' ||
        typeof entry.lastReadIndex !== 'number' ||
        typeof entry.hasReadProgress !== 'boolean' ||
        typeof entry.lastOpenedAt !== 'number'
      ) {
        return false
      }
    }
    return true
  }

  private static hasSearchHistoryEntries(entries: string[]): boolean {
    for (let i: number = 0; i < entries.length; i++) {
      if (typeof entries[i] !== 'string' || entries[i].trim().length === 0) {
        return false
      }
    }
    return true
  }

  private static hasQuickSearchEntries(entries: BackupQuickSearchEntry[]): boolean {
    for (let i: number = 0; i < entries.length; i++) {
      const entry: BackupQuickSearchEntry = entries[i]
      if (
        !BackupLocalDataAdapter.isRecord(entry) ||
        typeof entry.q !== 'string' ||
        entry.q.trim().length === 0 ||
        typeof entry.p !== 'number'
      ) {
        return false
      }
    }
    return true
  }

  private static hasLocalBlockShape(section: BackupLocalBlockSection): boolean {
    if (!BackupLocalDataAdapter.isRecord(section) || !Array.isArray(section.rules)) {
      return false
    }
    if (
      section.filterCommentsByScore !== undefined &&
      typeof section.filterCommentsByScore !== 'boolean'
    ) {
      return false
    }
    if (
      section.scoreFilteringThreshold !== undefined &&
      typeof section.scoreFilteringThreshold !== 'number'
    ) {
      return false
    }
    if (section.commentDisplayMode !== undefined && typeof section.commentDisplayMode !== 'string') {
      return false
    }
    for (let i: number = 0; i < section.rules.length; i++) {
      const rule: BackupLocalBlockRuleEntry = section.rules[i]
      if (
        !BackupLocalDataAdapter.isRecord(rule) ||
        typeof rule.id !== 'string' ||
        typeof rule.blockType !== 'string' ||
        typeof rule.ruleText !== 'string' ||
        rule.ruleText.trim().length === 0 ||
        typeof rule.enabled !== 'boolean' ||
        typeof rule.enableRegex !== 'boolean'
      ) {
        return false
      }
    }
    return true
  }

  private static hasSettingsTablesShape(tables: Record<string, Record<string, string>>): boolean {
    if (!BackupLocalDataAdapter.isRecord(tables)) {
      return false
    }
    const names: string[] = [
      'reader_settings',
      'download_settings',
      'browse_presentation_settings',
      'catalog_preferences',
    ]
    for (let i: number = 0; i < names.length; i++) {
      const table: Record<string, string> | undefined = tables[names[i]]
      if (!BackupLocalDataAdapter.isRecord(table)) {
        return false
      }
      const keys: string[] = Object.keys(table as Object)
      for (let j: number = 0; j < keys.length; j++) {
        if (typeof (table as Record<string, string>)[keys[j]] !== 'string') {
          return false
        }
      }
    }
    return true
  }

  private static isRecord(value: Object | undefined): boolean {
    return value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value)
  }

  static async restoreSection(
    context: common.UIAbilityContext,
    section: BackupLocalDataSection,
  ): Promise<void> {
    if (!BackupLocalDataAdapter.hasCompleteRestoreShape(section)) {
      throw new Error('backup local data is malformed')
    }
    await BackupLocalDataAdapter.restoreHistory(context, section)
    await SearchHistoryRepository.restoreBackup(context, section.searchHistory)

    const quick: NhQuickSearchItem[] = []
    for (let i: number = 0; i < section.quickSearches.length; i++) {
      const entry: BackupQuickSearchEntry = section.quickSearches[i]
      if (entry.q.trim().length === 0) {
        continue
      }
      const item: NhQuickSearchItem = new NhQuickSearchItem()
      item.query = entry.q
      item.pinnedAt = entry.p
      quick.push(item)
    }
    await QuickSearchRepository.restoreBackup(context, quick)

    if (section.homeSubtabs !== undefined) {
      const profiles: NhHomeSubtabProfile[] = []
      for (let i: number = 0; i < section.homeSubtabs.profiles.length; i++) {
        const entry: BackupHomeSubtabEntry = section.homeSubtabs.profiles[i]
        const profile: NhHomeSubtabProfile = new NhHomeSubtabProfile()
        profile.uuid = entry.uuid
        profile.kind = NhHomeSubtabProfile.normalizeKind(entry.kind)
        profile.name = entry.name
        profile.query = entry.query
        profile.language = NhHomeSubtabProfile.normalizeLanguage(entry.language)
        profile.sort = NhHomeSubtabProfile.normalizeSort(entry.sort)
        profile.presentation = entry.presentation
        profile.hidden = entry.hidden
        profile.ignoreLocalUserTagFiltering = entry.ignoreLocalUserTagFiltering ?? false
        profile.lastEditTime = entry.updatedAt
        profiles.push(profile)
      }
      await HomeSubtabSettings.restoreBackup(context, profiles, section.homeSubtabs.selectedUuid)
    }

    if (section.localUserTags !== undefined && section.localUserTagSettings !== undefined) {
      const snapshot: NhLocalUserTagSnapshot = new NhLocalUserTagSnapshot()
      for (let index: number = 0; index < section.localUserTags.length; index++) {
        const entry: BackupLocalUserTagEntry = section.localUserTags[index]
        const record: NhLocalUserTag = new NhLocalUserTag()
        record.scopeKey = entry.scopeKey
        record.tagId = entry.tagId
        record.namespaceSnapshot = entry.namespaceSnapshot
        record.nameSnapshot = entry.nameSnapshot
        record.colorCode = entry.colorCode
        record.weight = entry.weight
        record.hidden = entry.hidden
        record.updatedAt = entry.updatedAt
        record.deletedAt = entry.deletedAt
        snapshot.tags.push(record)
      }
      const settingsEntry: BackupLocalUserTagSettingsEntry = section.localUserTagSettings[0]
      snapshot.settings.scopeKey = settingsEntry.scopeKey
      snapshot.settings.filteringThreshold = settingsEntry.filteringThreshold
      snapshot.settings.updatedAt = settingsEntry.updatedAt
      snapshot.settings.deletedAt = settingsEntry.deletedAt
      await NhLocalUserTagRepository.replaceSnapshot(context, snapshot)
    }

    const rules: NhContentFilterRule[] = []
    for (let i: number = 0; i < section.localBlock.rules.length; i++) {
      const entry: BackupLocalBlockRuleEntry = section.localBlock.rules[i]
      if (entry.ruleText.trim().length === 0) {
        continue
      }
      const rule: NhContentFilterRule = new NhContentFilterRule()
      rule.id = entry.id
      rule.type = BackupLocalDataAdapter.normalizeBlockType(entry.blockType)
      rule.text = entry.ruleText
      rule.enabled = entry.enabled
      rule.isRegex = entry.enableRegex
      rules.push(rule)
    }
    await ContentFilterRepository.restoreBackup(context, rules)

    await ReaderSettingsRepository.restoreBackup(context, section.settingsTables['reader_settings'])
    await DownloadSettingsRepository.restoreBackup(context, section.settingsTables['download_settings'])
    await BrowsePresentationRepository.restoreBackup(
      context,
      section.settingsTables['browse_presentation_settings'],
    )
    await CatalogPreferencesRepository.restoreBackup(context, section.settingsTables['catalog_preferences'])
  }

  /**
   * The two envelope halves (progress + display rows) come from the same NH
   * reading_history table. Merge by gallery id so a restored row never loses
   * its resume marker, and a progress-only row stays recoverable.
   */
  private static async restoreHistory(
    context: common.UIAbilityContext,
    section: BackupLocalDataSection,
  ): Promise<void> {
    const items: NhReadingHistoryItem[] = []
    for (let i: number = 0; i < section.viewedHistory.length; i++) {
      const entry: BackupViewedHistoryEntry = section.viewedHistory[i]
      const item: NhReadingHistoryItem = new NhReadingHistoryItem()
      item.galleryId = entry.galleryId
      item.mediaId = entry.mediaId
      item.title = entry.title
      item.thumbnailUrl = entry.thumbnailUrl
      item.pageCount = entry.pageCount
      item.lastReadIndex = entry.lastReadIndex
      item.hasReadProgress = entry.hasReadProgress
      item.lastOpenedAt = entry.lastOpenedAt
      items.push(item)
    }
    for (let i: number = 0; i < section.readProgress.length; i++) {
      const entry: BackupReadProgressEntry = section.readProgress[i]
      const galleryId: number = Number(entry.g)
      if (!Number.isSafeInteger(galleryId) || galleryId <= 0) {
        continue
      }
      let item: NhReadingHistoryItem | undefined = undefined
      for (let j: number = 0; j < items.length; j++) {
        if (items[j].galleryId === galleryId) {
          item = items[j]
          break
        }
      }
      if (item === undefined) {
        item = new NhReadingHistoryItem()
        item.galleryId = galleryId
        item.lastOpenedAt = entry.t
        items.push(item)
      }
      item.hasReadProgress = true
      item.lastReadIndex = entry.i
    }
    await HistoryRepository.restoreBackup(context, items)
  }

  private static normalizeBlockType(value: string): NhContentFilterType {
    if (value === NhContentFilterType.COMMENTER || value === NhContentFilterType.COMMENT) {
      return value as NhContentFilterType
    }
    return NhContentFilterType.TITLE
  }

  /**
   * NextN never carried these datasets in Preferences, so there is nothing to
   * migrate from legacy preference-only backups. Kept as a no-op to preserve
   * the NextE restore contract for preference-only envelopes.
   */
  static async restoreLegacyPreferences(context: common.UIAbilityContext): Promise<void> {
  }
}
