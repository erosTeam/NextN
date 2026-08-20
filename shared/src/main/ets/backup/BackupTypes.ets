// Settings/local-data backup/restore envelope contract (ported from NextE backup chain).
// A plaintext envelope carries non-secret preferences + durable local data; the 'secrets' section
// is encryption-only and may travel ONLY inside the encrypted container below — never in cleartext.
export const BACKUP_MAGIC: string = 'NEXTN_BACKUP'
export const BACKUP_APP_ID: string = 'com.erosteam.nextn'
export const BACKUP_SCHEMA_VERSION: number = 1
export const BACKUP_MIN_SUPPORTED_SCHEMA_VERSION: number = 1
export const BACKUP_FILE_SUFFIX: string = '.nextn-backup.json'
export const BACKUP_CHECKSUM_ALGORITHM: string = 'SHA-256'
export const MAX_BACKUP_BYTES: number = 10 * 1024 * 1024

export type BackupSectionName = 'preferences' | 'localData' | 'secrets'
// Plaintext-eligible sections. 'secrets' is intentionally excluded — it only rides inside the cipher.
export const BACKUP_SECTION_NAMES: BackupSectionName[] = ['preferences', 'localData']
export const BACKUP_ENCRYPTED_ONLY_SECTION_NAMES: BackupSectionName[] = ['secrets']

// ── Encrypted container (AES-256-GCM + PBKDF2-SHA256), ported verbatim from NextE ──
export const BACKUP_CIPHER_ALGORITHM: string = 'AES-256-GCM'
export const BACKUP_KDF_ALGORITHM: string = 'PBKDF2-SHA256'
export const BACKUP_KDF_ITERATIONS: number = 210000
export const BACKUP_KDF_KEY_SIZE: number = 32
export const BACKUP_CIPHER_SALT_BYTES: number = 16
export const BACKUP_CIPHER_IV_BYTES: number = 12
export const BACKUP_CIPHER_TAG_BYTES: number = 16

export type BackupSettingsValue = string | number | boolean

export interface BackupChecksumInfo {
  algorithm: string
  value: string
}

export interface BackupCounts {
  preferences: number
  localData?: BackupLocalDataCounts
  secrets?: number
}

export interface BackupLocalDataCounts {
  readProgress: number
  viewedHistory: number
  searchHistory: number
  quickSearches: number
  homeSubtabs?: number
  localBlockRules: number
  settingsTableGroups: number
}

// NH reading-history progress row. `g` is the gallery id as a string so the
// envelope stays transport-neutral like the NextE `g` field.
export interface BackupReadProgressEntry {
  g: string
  i: number
  t: number
  c?: string
}

// NH reading-history display row (the durable metadata half of reading_history).
export interface BackupViewedHistoryEntry {
  galleryId: number
  mediaId: string
  title: string
  thumbnailUrl: string
  pageCount: number
  lastReadIndex: number
  hasReadProgress: boolean
  lastOpenedAt: number
}

// NH pinned quick-search row (NextN leaf; NextE has no equivalent table).
export interface BackupQuickSearchEntry {
  q: string
  p: number
}

export interface BackupHomeSubtabEntry {
  uuid: string
  kind: string
  name: string
  query: string
  language: string
  sort: string
  presentation: string
  hidden: boolean
  updatedAt: number
}

export interface BackupHomeSubtabSection {
  profiles: BackupHomeSubtabEntry[]
  selectedUuid: string
}

// NH content-filter rule (NextN's leaf replacement for NextE's local block rules).
export interface BackupLocalBlockRuleEntry {
  id: string
  blockType: string
  ruleText: string
  enabled: boolean
  enableRegex: boolean
}

// Comment-filter scalars do not exist in NH; the fields are retained in the
// contract for NextE shape parity and default to false/0/'' on restore.
export interface BackupLocalBlockSection {
  filterCommentsByScore?: boolean
  scoreFilteringThreshold?: number
  commentDisplayMode?: string
  rules: BackupLocalBlockRuleEntry[]
}

export interface BackupLocalDataSection {
  readProgress: BackupReadProgressEntry[]
  viewedHistory: BackupViewedHistoryEntry[]
  searchHistory: string[]
  quickSearches: BackupQuickSearchEntry[]
  /** Optional for schema-v1 backups created before Home SubTabs shipped. */
  homeSubtabs?: BackupHomeSubtabSection
  localBlock: BackupLocalBlockSection
  // NH key-value settings tables: reader_settings / download_settings /
  // browse_presentation_settings / catalog_preferences.
  settingsTables: Record<string, Record<string, string>>
}

export interface BackupData {
  // Raw Preferences scalars (booleans/numbers, or JSON strings for composite settings).
  // NextN keys are prefixed `<store>.<key>` so the six Preferences stores cannot collide.
  preferences?: Record<string, BackupSettingsValue>
  // Durable user-local records stored in RDB, kept out of disposable cache tables.
  localData?: BackupLocalDataSection
  // The denylisted secret keys (account session, LLM secrets, WebDAV configuration).
  secrets?: Record<string, BackupSettingsValue>
}

export interface BackupEnvelopeV1 {
  magic: string
  appId: string
  schemaVersion: number
  minSupportedSchemaVersion: number
  createdAt: string
  appVersion: string
  appVersionCode: number
  sections: BackupSectionName[]
  counts: BackupCounts
  data: BackupData
  checksum?: BackupChecksumInfo
}

export interface BackupCipherMeta {
  cipher: string
  kdf: string
  iterations: number
  keySize: number
  salt: string
  iv: string
}

export interface BackupEncryptedEnvelope {
  magic: string
  appId: string
  schemaVersion: number
  minSupportedSchemaVersion: number
  encrypted: boolean
  createdAt: string
  appVersion: string
  appVersionCode: number
  cipherMeta: BackupCipherMeta
  ciphertext: string
}

export interface BackupAppMetadata {
  appVersion: string
  appVersionCode: number
}

export interface BackupExportOptions {
  // When true the backup includes the 'secrets' section and MUST be sealed with a non-empty password.
  includeSecrets: boolean
  password: string
}

export interface BackupPreview {
  createdAt: string
  appVersion: string
  appVersionCode: number
  sections: BackupSectionName[]
  counts: BackupCounts
  hasSecrets: boolean
}

export interface BackupValidationResult {
  ok: boolean
  code: string
  message: string
}

export interface BackupParseResult {
  ok: boolean
  envelope?: BackupEnvelopeV1
  // Set when the raw file is a recognized encrypted NextN backup: ok=false, code='password_required';
  // the caller must prompt for a password and call the decrypt path.
  encrypted?: boolean
  code: string
  message: string
}

export interface BackupRestoreResult {
  ok: boolean
  restoredSections: BackupSectionName[]
  failedSections: BackupSectionName[]
  message: string
}
