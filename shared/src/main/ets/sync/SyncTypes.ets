/**
 * NextN WebDAV sync envelope/manifest contract (ported from the NextE sync
 * chain). Application identity is NextN; dataset records are NH leaves:
 * reading_history, search_history, search_quick, content_filter_rules and the
 * user-selected NH datasets. Legacy settings-table records remain parseable so
 * a current client can preserve old remote manifests without consuming them.
 * All merge/shard parameters stay identical to NextE (64 shards, FNV-1a,
 * ETag guard, tombstone by max timestamp).
 */
export const SYNC_MAGIC: string = 'NEXTN_SYNC'
export const SYNC_APP_ID: string = 'com.erosteam.nextn'
export const SYNC_SCHEMA_VERSION: number = 1
export const SYNC_MIN_SUPPORTED_SCHEMA_VERSION: number = 1
export const SYNC_FILE_NAME: string = 'nextn-sync-v1.json'
export const SYNC_WEBDAV_ROOT_DIR: string = 'nextn-sync-v1'
export const SYNC_WEBDAV_MANIFEST_FILE: string = 'manifest.json'

/** NH reading-history resume marker. */
export class SyncReadProgressRecord {
  scopeKey: string = ''
  galleryId: number = 0
  pageIndex: number = 0
  updatedAt: number = 0
  deletedAt: number = 0
}

/** NH reading-history display row. */
export class SyncViewedHistoryRecord {
  scopeKey: string = ''
  galleryId: number = 0
  mediaId: string = ''
  title: string = ''
  thumbnailUrl: string = ''
  pageCount: number = 0
  lastReadIndex: number = 0
  hasReadProgress: boolean = false
  viewedAt: number = 0
  deletedAt: number = 0
}

/** NH search-history query. */
export class SyncSearchHistoryRecord {
  scopeKey: string = ''
  queryText: string = ''
  positionIndex: number = 0
  updatedAt: number = 0
  deletedAt: number = 0
}

/** NH pinned quick-search query. */
export class SyncQuickSearchRecord {
  scopeKey: string = ''
  queryText: string = ''
  pinnedAt: number = 0
  updatedAt: number = 0
  deletedAt: number = 0
}

/** Home SubTab profile. `selectedUuid` remains only for old envelope parsing. */
export class SyncHomeSubtabRecord {
  scopeKey: string = ''
  profileUuid: string = ''
  positionIndex: number = 0
  kind: string = ''
  name: string = ''
  queryText: string = ''
  language: string = ''
  sort: string = ''
  displayMode: string = ''
  hidden: boolean = false
  ignoreLocalUserTagFiltering: boolean = false
  selectedUuid: string = ''
  updatedAt: number = 0
  deletedAt: number = 0
}

/** One locally configured NH tag rule, including syncable tombstones. */
export class SyncLocalUserTagRecord {
  scopeKey: string = ''
  tagId: number = 0
  namespaceSnapshot: string = ''
  nameSnapshot: string = ''
  colorCode: string = ''
  weight: number = 10
  hidden: boolean = false
  updatedAt: number = 0
  deletedAt: number = 0
}

/** Scope-wide soft-filter threshold for the local user-tag dataset. */
export class SyncLocalUserTagSettingsRecord {
  scopeKey: string = ''
  filteringThreshold: number = 0
  updatedAt: number = 0
  deletedAt: number = 0
}

/** NH comment-filter scalars do not exist; retained for NextE envelope parity. */
export class SyncLocalBlockSettingsRecord {
  scopeKey: string = ''
  filterCommentsByScore: boolean = false
  scoreFilteringThreshold: number = 0
  commentDisplayMode: string = ''
  updatedAt: number = 0
  deletedAt: number = 0
}

/** NH content-filter rule. */
export class SyncLocalBlockRuleRecord {
  scopeKey: string = ''
  ruleId: string = ''
  positionIndex: number = 0
  blockType: string = ''
  ruleText: string = ''
  enabled: boolean = true
  enableRegex: boolean = false
  updatedAt: number = 0
  deletedAt: number = 0
}

/** NH key-value settings table row (reader/download/browse/catalog settings). */
export class SyncSettingsTableRecord {
  scopeKey: string = ''
  tableName: string = ''
  key: string = ''
  value: string = ''
  updatedAt: number = 0
  deletedAt: number = 0
}

export class SyncDatasets {
  readProgress: SyncReadProgressRecord[] = []
  viewedHistory: SyncViewedHistoryRecord[] = []
  searchHistory: SyncSearchHistoryRecord[] = []
  quickSearches: SyncQuickSearchRecord[] = []
  homeSubtabs: SyncHomeSubtabRecord[] = []
  localUserTags: SyncLocalUserTagRecord[] = []
  localUserTagSettings: SyncLocalUserTagSettingsRecord[] = []
  localBlockSettings: SyncLocalBlockSettingsRecord[] = []
  localBlockRules: SyncLocalBlockRuleRecord[] = []
  settingsTables: SyncSettingsTableRecord[] = []
}

export class SyncManifestShard {
  id: string = ''
  path: string = ''
  sha256: string = ''
  recordCount: number = 0
  updatedAt: number = 0
}

export class SyncManifestDataset {
  id: string = ''
  shards: SyncManifestShard[] = []
}

export class SyncManifestV1 {
  magic: string = SYNC_MAGIC
  appId: string = SYNC_APP_ID
  schemaVersion: number = SYNC_SCHEMA_VERSION
  minSupportedSchemaVersion: number = SYNC_MIN_SUPPORTED_SCHEMA_VERSION
  generatedAt: string = ''
  datasets: SyncManifestDataset[] = []
}

export class SyncDatasetSelection {
  readProgress: boolean = true
  viewedHistory: boolean = true
  searchHistory: boolean = true
  quickSearches: boolean = true
  homeSubtabs: boolean = true
  localUserTags: boolean = true
  localBlock: boolean = true
  /** Legacy sync-envelope field; current WebDAV selection keeps it disabled. */
  settingsTables: boolean = false
}

export class SyncEnvelopeV1 {
  magic: string = SYNC_MAGIC
  appId: string = SYNC_APP_ID
  schemaVersion: number = SYNC_SCHEMA_VERSION
  minSupportedSchemaVersion: number = SYNC_MIN_SUPPORTED_SCHEMA_VERSION
  generatedAt: string = ''
  deviceId: string = ''
  datasetId: string = ''
  shardId: string = ''
  datasets: SyncDatasets = new SyncDatasets()
}
