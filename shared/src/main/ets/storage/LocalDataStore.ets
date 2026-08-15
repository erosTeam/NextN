import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'NextN.db',
  securityLevel: relationalStore.SecurityLevel.S3,
  autoCleanDirtyData: true,
}

const SCHEMA_VERSION: number = 20
const SQL_CREATE_READING_HISTORY: string =
  'CREATE TABLE IF NOT EXISTS reading_history (' +
  'gallery_id INTEGER PRIMARY KEY, ' +
  'media_id TEXT NOT NULL, ' +
  'title TEXT NOT NULL, ' +
  'thumbnail_url TEXT NOT NULL, ' +
  'page_count INTEGER NOT NULL, ' +
  'last_read_index INTEGER NOT NULL DEFAULT 0, ' +
  'has_read_progress INTEGER NOT NULL DEFAULT 0, ' +
  'last_opened_at INTEGER NOT NULL)'
const SQL_ADD_READING_HISTORY_HAS_READ_PROGRESS: string =
  'ALTER TABLE reading_history ADD COLUMN has_read_progress INTEGER NOT NULL DEFAULT 0'
const SQL_INSPECT_READING_HISTORY_COLUMNS: string = 'SELECT * FROM reading_history LIMIT 0'
const SQL_CREATE_READING_HISTORY_ORDER: string =
  'CREATE INDEX IF NOT EXISTS idx_reading_history_opened ON reading_history (last_opened_at DESC)'
const SQL_CREATE_SEARCH_HISTORY: string =
  'CREATE TABLE IF NOT EXISTS search_history (' +
  'normalized_query TEXT PRIMARY KEY, ' +
  'query_text TEXT NOT NULL, ' +
  'last_used_at INTEGER NOT NULL)'
const SQL_CREATE_SEARCH_HISTORY_ORDER: string =
  'CREATE INDEX IF NOT EXISTS idx_search_history_used ON search_history (last_used_at DESC)'
const SQL_CREATE_SEARCH_QUICK: string =
  'CREATE TABLE IF NOT EXISTS search_quick (' +
  'normalized_query TEXT PRIMARY KEY, ' +
  'query_text TEXT NOT NULL, ' +
  'pinned_at INTEGER NOT NULL)'
const SQL_CREATE_SEARCH_QUICK_ORDER: string =
  'CREATE INDEX IF NOT EXISTS idx_search_quick_pinned ON search_quick (pinned_at DESC)'
const SQL_CREATE_TAG_TRANSLATIONS: string =
  'CREATE TABLE IF NOT EXISTS tag_translations (' +
  'namespace TEXT NOT NULL, ' +
  'raw_name TEXT NOT NULL, ' +
  'display_name TEXT NOT NULL, ' +
  'last_used_at INTEGER NOT NULL DEFAULT 0, ' +
  'PRIMARY KEY (namespace, raw_name))'
const SQL_CREATE_TAG_TRANSLATION_USAGE_ORDER: string =
  'CREATE INDEX IF NOT EXISTS idx_tag_translations_used ON tag_translations (last_used_at DESC)'
const SQL_CREATE_TAG_TRANSLATION_META: string =
  'CREATE TABLE IF NOT EXISTS tag_translation_meta (' +
  'key TEXT PRIMARY KEY NOT NULL, ' +
  'value TEXT NOT NULL)'
// The public v2 list payload contains only tag ids. Keep the resolved public
// catalog separately from the optional translation dictionary so a catalog
// refresh never replaces a user's local display dictionary.
const SQL_CREATE_NH_TAG_CATALOG: string =
  'CREATE TABLE IF NOT EXISTS nh_tag_catalog (' +
  'id INTEGER PRIMARY KEY, ' +
  'type TEXT NOT NULL, ' +
  'name TEXT NOT NULL, ' +
  'count INTEGER NOT NULL, ' +
  'updated_at INTEGER NOT NULL)'
const SQL_CREATE_NH_GALLERY_DETAIL_CACHE: string =
  'CREATE TABLE IF NOT EXISTS nh_gallery_detail_cache (' +
  'gallery_id INTEGER PRIMARY KEY, ' +
  'payload TEXT NOT NULL, ' +
  'cached_at INTEGER NOT NULL, ' +
  'expires_at INTEGER NOT NULL, ' +
  'accessed_at INTEGER NOT NULL)'
const SQL_CREATE_NH_GALLERY_DETAIL_CACHE_ACCESS_ORDER: string =
  'CREATE INDEX IF NOT EXISTS idx_nh_gallery_detail_cache_access ON nh_gallery_detail_cache (accessed_at DESC)'
const SQL_CREATE_READER_SETTINGS: string =
  'CREATE TABLE IF NOT EXISTS reader_settings (' +
  'key TEXT PRIMARY KEY NOT NULL, ' +
  'value TEXT NOT NULL)'
const SQL_CREATE_ACCOUNT_SESSION: string =
  'CREATE TABLE IF NOT EXISTS account_session (' +
  'key TEXT PRIMARY KEY NOT NULL, ' +
  'ciphertext TEXT NOT NULL, ' +
  'nonce TEXT NOT NULL, ' +
  'updated_at INTEGER NOT NULL)'
const SQL_CREATE_ACCOUNT_PROFILE: string =
  'CREATE TABLE IF NOT EXISTS account_profile (' +
  'key TEXT PRIMARY KEY NOT NULL, ' +
  'username TEXT NOT NULL, ' +
  'user_url TEXT NOT NULL, ' +
  'user_id TEXT NOT NULL, ' +
  'avatar_url TEXT NOT NULL, ' +
  'updated_at INTEGER NOT NULL)'
// This is deliberately separate from the encrypted envelope. It is only a
// durable, non-secret recovery decision: the sealed record and ArkWeb cookie
// store remain intact until the user explicitly signs out or verifies again.
const SQL_CREATE_ACCOUNT_SESSION_VERIFICATION: string =
  'CREATE TABLE IF NOT EXISTS account_session_verification (' +
  'key TEXT PRIMARY KEY NOT NULL, ' +
  'verification_required INTEGER NOT NULL, ' +
  'reason_code TEXT NOT NULL DEFAULT \'\', ' +
  'updated_at INTEGER NOT NULL)'
const SQL_INSPECT_ACCOUNT_SESSION_VERIFICATION_COLUMNS: string =
  'SELECT * FROM account_session_verification LIMIT 0'
const SQL_ADD_ACCOUNT_SESSION_VERIFICATION_REASON_CODE: string =
  'ALTER TABLE account_session_verification ADD COLUMN reason_code TEXT NOT NULL DEFAULT \'\''
const SQL_CREATE_DOWNLOAD_QUEUE: string =
  'CREATE TABLE IF NOT EXISTS download_queue (' +
  'gallery_id INTEGER PRIMARY KEY, ' +
  'media_id TEXT NOT NULL, ' +
  'title TEXT NOT NULL, ' +
  'thumbnail_url TEXT NOT NULL, ' +
  'page_count INTEGER NOT NULL, ' +
  'page_extensions TEXT NOT NULL, ' +
  'completed_pages INTEGER NOT NULL DEFAULT 0, ' +
  'status TEXT NOT NULL, ' +
  'error_message TEXT NOT NULL DEFAULT \'\', ' +
  'created_at INTEGER NOT NULL, ' +
  'updated_at INTEGER NOT NULL)'
const SQL_CREATE_DOWNLOAD_QUEUE_UPDATED_ORDER: string =
  'CREATE INDEX IF NOT EXISTS idx_download_queue_updated ON download_queue (updated_at DESC)'
const SQL_CREATE_DOWNLOAD_SETTINGS: string =
  'CREATE TABLE IF NOT EXISTS download_settings (' +
  'key TEXT PRIMARY KEY NOT NULL, ' +
  'value TEXT NOT NULL)'
const SQL_CREATE_CONTENT_FILTER_RULES: string =
  'CREATE TABLE IF NOT EXISTS content_filter_rules (' +
  'rule_id TEXT PRIMARY KEY NOT NULL, ' +
  'rule_type TEXT NOT NULL, ' +
  'rule_text TEXT NOT NULL, ' +
  'enabled INTEGER NOT NULL DEFAULT 1, ' +
  'is_regex INTEGER NOT NULL DEFAULT 0, ' +
  'position_index INTEGER NOT NULL DEFAULT 0)'
const SQL_CREATE_CONTENT_FILTER_RULES_ORDER: string =
  'CREATE INDEX IF NOT EXISTS idx_content_filter_rules_order ON content_filter_rules (position_index ASC, rule_id ASC)'
const SQL_CREATE_BROWSE_PRESENTATION_SETTINGS: string =
  'CREATE TABLE IF NOT EXISTS browse_presentation_settings (' +
  'key TEXT PRIMARY KEY NOT NULL, ' +
  'value TEXT NOT NULL)'
const SQL_CREATE_CATALOG_PREFERENCES: string =
  'CREATE TABLE IF NOT EXISTS catalog_preferences (' +
  'key TEXT PRIMARY KEY NOT NULL, ' +
  'value TEXT NOT NULL)'
// Generated comic-analysis documents are app-private cache records. They are
// deliberately separate from rendered image artifacts so a corrupt document
// can be discarded without touching a rendered Reader page.
const SQL_CREATE_COMIC_TRANSLATION_DOCUMENT_CACHE: string =
  'CREATE TABLE IF NOT EXISTS comic_translation_document_cache (' +
  'cache_key TEXT PRIMARY KEY NOT NULL, ' +
  'scope_key TEXT NOT NULL, ' +
  'project_id TEXT NOT NULL, ' +
  'page_index INTEGER NOT NULL, ' +
  'payload TEXT NOT NULL, ' +
  'cached_at INTEGER NOT NULL, ' +
  'accessed_at INTEGER NOT NULL)'
const SQL_CREATE_COMIC_TRANSLATION_DOCUMENT_CACHE_SCOPE_ORDER: string =
  'CREATE INDEX IF NOT EXISTS idx_comic_translation_document_cache_scope ' +
  'ON comic_translation_document_cache (scope_key, page_index DESC, accessed_at DESC)'
const SQL_CREATE_COMIC_TRANSLATION_DOCUMENT_CACHE_ACCESS_ORDER: string =
  'CREATE INDEX IF NOT EXISTS idx_comic_translation_document_cache_access ' +
  'ON comic_translation_document_cache (accessed_at DESC)'
// Comment translations are public-comment derivatives, kept separately from
// Reader page documents so either cache can be cleared without touching the
// other one.
const SQL_CREATE_COMMENT_TRANSLATION_CACHE: string =
  'CREATE TABLE IF NOT EXISTS comment_translation_cache (' +
  'cache_key TEXT PRIMARY KEY NOT NULL, ' +
  'scope_key TEXT NOT NULL, ' +
  'translated TEXT NOT NULL, ' +
  'cached_at INTEGER NOT NULL, ' +
  'expires_at INTEGER NOT NULL)'
const SQL_CREATE_COMMENT_TRANSLATION_CACHE_EXPIRY_ORDER: string =
  'CREATE INDEX IF NOT EXISTS idx_comment_translation_cache_expiry ' +
  'ON comment_translation_cache (expires_at ASC, cached_at DESC)'
const SQL_CREATE_NH_GALLERY_LIST_CACHE: string =
  'CREATE TABLE IF NOT EXISTS nh_gallery_list_cache (' +
  'cache_key TEXT PRIMARY KEY NOT NULL, ' +
  'payload TEXT NOT NULL, ' +
  'cached_at INTEGER NOT NULL)'

/**
 * Owns the small on-device schema shared by anonymous local capabilities.
 * Reopening the same store remains idempotent so old reading-history data is
 * preserved while new local tables are introduced.
 */
export class LocalDataStore {
  private static schemaReady: boolean = false
  private static schemaTask: Promise<void> | null = null

  static async open(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    try {
      const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG)
      await LocalDataStore.ensureSchema(store)
      return store
    } catch (error) {
      throw (error as Error)
    }
  }

  private static async ensureSchema(store: relationalStore.RdbStore): Promise<void> {
    if (LocalDataStore.schemaReady) {
      return
    }
    if (LocalDataStore.schemaTask !== null) {
      await LocalDataStore.schemaTask
      return
    }
    const task: Promise<void> = LocalDataStore.createSchema(store)
    LocalDataStore.schemaTask = task
    try {
      await task
      LocalDataStore.schemaReady = true
    } finally {
      LocalDataStore.schemaTask = null
    }
  }

  private static async createSchema(store: relationalStore.RdbStore): Promise<void> {
    try {
      // RdbStore does not infer upgrades from this number. Read it once before
      // structural work, then persist the new version only after every schema
      // guarantee below has completed.
      const existingVersion: number = store.version
      await store.executeSql(SQL_CREATE_READING_HISTORY)
      await store.executeSql(SQL_CREATE_READING_HISTORY_ORDER)
      await store.executeSql(SQL_CREATE_SEARCH_HISTORY)
      await store.executeSql(SQL_CREATE_SEARCH_HISTORY_ORDER)
      await store.executeSql(SQL_CREATE_SEARCH_QUICK)
      await store.executeSql(SQL_CREATE_SEARCH_QUICK_ORDER)
      await store.executeSql(SQL_CREATE_TAG_TRANSLATIONS)
      await store.executeSql(SQL_CREATE_TAG_TRANSLATION_USAGE_ORDER)
      await store.executeSql(SQL_CREATE_TAG_TRANSLATION_META)
      await store.executeSql(SQL_CREATE_NH_TAG_CATALOG)
      await store.executeSql(SQL_CREATE_NH_GALLERY_DETAIL_CACHE)
      await store.executeSql(SQL_CREATE_NH_GALLERY_DETAIL_CACHE_ACCESS_ORDER)
      await store.executeSql(SQL_CREATE_READER_SETTINGS)
      await store.executeSql(SQL_CREATE_ACCOUNT_SESSION)
      await store.executeSql(SQL_CREATE_ACCOUNT_PROFILE)
      await store.executeSql(SQL_CREATE_ACCOUNT_SESSION_VERIFICATION)
      await store.executeSql(SQL_CREATE_DOWNLOAD_QUEUE)
      await store.executeSql(SQL_CREATE_DOWNLOAD_QUEUE_UPDATED_ORDER)
      await store.executeSql(SQL_CREATE_DOWNLOAD_SETTINGS)
      await store.executeSql(SQL_CREATE_CONTENT_FILTER_RULES)
      await store.executeSql(SQL_CREATE_CONTENT_FILTER_RULES_ORDER)
      await store.executeSql(SQL_CREATE_BROWSE_PRESENTATION_SETTINGS)
      await store.executeSql(SQL_CREATE_CATALOG_PREFERENCES)
      await store.executeSql(SQL_CREATE_COMIC_TRANSLATION_DOCUMENT_CACHE)
      await store.executeSql(SQL_CREATE_COMIC_TRANSLATION_DOCUMENT_CACHE_SCOPE_ORDER)
      await store.executeSql(SQL_CREATE_COMIC_TRANSLATION_DOCUMENT_CACHE_ACCESS_ORDER)
      await store.executeSql(SQL_CREATE_COMMENT_TRANSLATION_CACHE)
      await store.executeSql(SQL_CREATE_COMMENT_TRANSLATION_CACHE_EXPIRY_ORDER)
      await store.executeSql(SQL_CREATE_NH_GALLERY_LIST_CACHE)
      await LocalDataStore.ensureReadingHistoryProgressColumn(store)
      await LocalDataStore.ensureAccountVerificationReasonColumn(store)
      if (existingVersion < SCHEMA_VERSION) {
        store.version = SCHEMA_VERSION
      }
    } catch (error) {
      throw (error as Error)
    }
  }

  /**
   * The RDB version is app-managed rather than schema-introspected by the
   * platform. Inspect the just-opened table so both a fresh install and an
   * interrupted/legacy upgrade safely converge without a duplicate ALTER.
   */
  private static async ensureReadingHistoryProgressColumn(store: relationalStore.RdbStore): Promise<void> {
    let rows: relationalStore.ResultSet | null = null
    let hasProgressColumn: boolean = false
    try {
      rows = await store.querySql(SQL_INSPECT_READING_HISTORY_COLUMNS)
      hasProgressColumn = rows.getColumnNames().indexOf('has_read_progress') >= 0
    } finally {
      if (rows !== null) {
        rows.close()
      }
    }
    if (!hasProgressColumn) {
      // Existing rows are deliberately initialized as false: old schemas
      // recorded `0` both for unopened and first-page history, so inferring
      // resume state here would be semantically unsafe.
      await store.executeSql(SQL_ADD_READING_HISTORY_HAS_READ_PROGRESS)
    }
  }

  /** Adds one finite recovery-origin code without touching the sealed envelope. */
  private static async ensureAccountVerificationReasonColumn(store: relationalStore.RdbStore): Promise<void> {
    let rows: relationalStore.ResultSet | null = null
    let hasReasonCode: boolean = false
    try {
      rows = await store.querySql(SQL_INSPECT_ACCOUNT_SESSION_VERIFICATION_COLUMNS)
      hasReasonCode = rows.getColumnNames().indexOf('reason_code') >= 0
    } finally {
      if (rows !== null) {
        rows.close()
      }
    }
    if (!hasReasonCode) {
      await store.executeSql(SQL_ADD_ACCOUNT_SESSION_VERIFICATION_REASON_CODE)
    }
  }
}
