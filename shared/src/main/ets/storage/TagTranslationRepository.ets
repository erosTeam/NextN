import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { NhTag } from '../model/NhGallery'
import { NhTagSuggestion } from '../model/NhTagSuggestion'
import { NhTagTranslationEntry, NhTagTranslationStatus } from '../model/NhTagTranslation'
import { CacheStat } from '../services/CacheStat'
import { connectTagTranslations } from '../state/TagTranslationState'
import { LocalDataStore } from './LocalDataStore'

const META_VERSION: string = 'version'
const META_SOURCE: string = 'source'
const META_UPDATED_AT: string = 'updated_at'
const MAX_LOOKUP_KEYS_PER_QUERY: number = 200
const INSERT_BATCH_SIZE: number = 500
const MAX_SUGGESTIONS: number = 12
const MAX_SUGGESTION_PREFIX_LENGTH: number = 128
const SQL_COUNT: string = 'SELECT COUNT(*) AS count FROM tag_translations'
const SQL_SELECT_META: string = 'SELECT value FROM tag_translation_meta WHERE key = ? LIMIT 1'
const SQL_LOOKUP_PREFIX: string =
  'SELECT raw_name, display_name FROM tag_translations WHERE namespace = ? AND raw_name IN ('
const SQL_SUGGEST: string =
  "SELECT namespace, raw_name, display_name FROM tag_translations " +
  "WHERE namespace = ? AND raw_name LIKE ? ESCAPE '\\' " +
  'ORDER BY last_used_at DESC, raw_name ASC LIMIT ?'
const SQL_SUGGEST_UNSCOPED: string =
  "SELECT namespace, raw_name, display_name FROM tag_translations " +
  "WHERE raw_name LIKE ? ESCAPE '\\' OR display_name LIKE ? ESCAPE '\\' " +
  'ORDER BY last_used_at DESC, raw_name ASC LIMIT ?'
const SQL_TOUCH_SUGGESTION: string =
  'UPDATE tag_translations SET last_used_at = ? WHERE namespace = ? AND raw_name = ?'
const SQL_CLEAR: string = 'DELETE FROM tag_translations'
const SQL_STAT: string =
  'SELECT COUNT(*) AS count, COALESCE(SUM(LENGTH(CAST(display_name AS BLOB))), 0) AS bytes ' +
  'FROM tag_translations'
const SQL_UPSERT_META: string =
  'INSERT INTO tag_translation_meta (key, value) VALUES (?, ?) ' +
  'ON CONFLICT(key) DO UPDATE SET value = excluded.value'

/**
 * Storage boundary for the optional local tag dictionary. Keys are always the
 * exact normalized namespace plus raw tag name; the dictionary never changes
 * the query sent to the anonymous API.
 */
export class TagTranslationRepository {
  static keyFor(tag: NhTag): string {
    return TagTranslationRepository.makeKey(
      TagTranslationRepository.normalizedNamespace(tag.type),
      TagTranslationRepository.normalizedRawName(tag.name),
    )
  }

  static async lookup(
    context: common.UIAbilityContext,
    tags: NhTag[],
  ): Promise<Map<string, string>> {
    const translations: Map<string, string> = new Map<string, string>()
    const keysByNamespace: Map<string, string[]> = new Map<string, string[]>()
    for (let index: number = 0; index < tags.length; index++) {
      const namespace: string = TagTranslationRepository.normalizedNamespace(tags[index].type)
      const rawName: string = TagTranslationRepository.normalizedRawName(tags[index].name)
      if (namespace.length === 0 || rawName.length === 0) {
        continue
      }
      const existing: string[] | undefined = keysByNamespace.get(namespace)
      if (existing === undefined) {
        keysByNamespace.set(namespace, [rawName])
      } else if (existing.indexOf(rawName) < 0) {
        existing.push(rawName)
      }
    }
    if (keysByNamespace.size === 0) {
      return translations
    }

    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const namespaces: string[] = Array.from(keysByNamespace.keys())
    for (let namespaceIndex: number = 0; namespaceIndex < namespaces.length; namespaceIndex++) {
      const namespace: string = namespaces[namespaceIndex]
      const rawNames: string[] | undefined = keysByNamespace.get(namespace)
      if (rawNames === undefined) {
        continue
      }
      for (let start: number = 0; start < rawNames.length; start += MAX_LOOKUP_KEYS_PER_QUERY) {
        const end: number = Math.min(rawNames.length, start + MAX_LOOKUP_KEYS_PER_QUERY)
        await TagTranslationRepository.lookupBatch(store, namespace, rawNames.slice(start, end), translations)
      }
    }
    return translations
  }

  static async status(context: common.UIAbilityContext): Promise<NhTagTranslationStatus> {
    const status: NhTagTranslationStatus = new NhTagTranslationStatus()
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    let rows: relationalStore.ResultSet | null = null
    try {
      rows = await store.querySql(SQL_COUNT)
      if (rows.goToFirstRow()) {
        status.rowCount = TagTranslationRepository.numberColumn(rows, 'count')
      }
    } finally {
      if (rows !== null) {
        rows.close()
      }
    }
    status.version = await TagTranslationRepository.metaValue(store, META_VERSION)
    status.source = await TagTranslationRepository.metaValue(store, META_SOURCE)
    status.updatedAt = TagTranslationRepository.parseTimestamp(
      await TagTranslationRepository.metaValue(store, META_UPDATED_AT),
    )
    return status
  }

  /** Aggregate-only dictionary state for the private cache page. */
  static async stat(context: common.UIAbilityContext): Promise<CacheStat> {
    const result: CacheStat = new CacheStat()
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const rows: relationalStore.ResultSet = await store.querySql(SQL_STAT)
    try {
      if (rows.goToFirstRow()) {
        result.count = TagTranslationRepository.numberColumn(rows, 'count')
        result.bytes = TagTranslationRepository.numberColumn(rows, 'bytes')
      }
    } finally {
      rows.close()
    }
    return result
  }

  /** Removes only the optional local dictionary; no catalog or query state is changed. */
  static async clear(context: common.UIAbilityContext): Promise<void> {
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    await store.executeSql(SQL_CLEAR)
    connectTagTranslations().publishMutation()
  }

  /**
   * Finds a bounded, namespace-scoped raw-name prefix in the local dictionary.
   * This deliberately does not search display names or cross namespaces: those
   * would turn a keystroke into a broad scan on a large optional dictionary.
   */
  static async suggest(
    context: common.UIAbilityContext,
    namespace: string,
    rawPrefix: string,
    limit: number = MAX_SUGGESTIONS,
  ): Promise<NhTagSuggestion[]> {
    const normalizedNamespace: string = TagTranslationRepository.normalizedNamespace(namespace)
    const normalizedPrefix: string = TagTranslationRepository.normalizedRawName(rawPrefix)
    if (
      normalizedNamespace.length === 0 ||
      normalizedPrefix.length === 0 ||
      normalizedPrefix.length > MAX_SUGGESTION_PREFIX_LENGTH
    ) {
      return []
    }
    const boundedLimit: number = TagTranslationRepository.boundedSuggestionLimit(limit)
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const like: string = `${TagTranslationRepository.escapeLike(normalizedPrefix)}%`
    const suggestions: NhTagSuggestion[] = []
    let rows: relationalStore.ResultSet | null = null
    try {
      rows = await store.querySql(SQL_SUGGEST, [normalizedNamespace, like, boundedLimit])
      while (rows.goToNextRow()) {
        const suggestion: NhTagSuggestion = new NhTagSuggestion()
        suggestion.namespace = TagTranslationRepository.stringColumn(rows, 'namespace')
        suggestion.rawName = TagTranslationRepository.stringColumn(rows, 'raw_name')
        suggestion.displayName = TagTranslationRepository.stringColumn(rows, 'display_name')
        if (
          suggestion.namespace.length > 0 &&
          suggestion.rawName.length > 0 &&
          suggestion.displayName.length > 0
        ) {
          suggestions.push(suggestion)
        }
      }
    } finally {
      if (rows !== null) {
        rows.close()
      }
    }
    return suggestions
  }

  /**
   * ErosN's ordinary-token local autocomplete. English-like input stays
   * prefix-bound; CJK input uses a bounded display-label contains match so a
   * user can discover translated tags before any network request. The result
   * remains the canonical namespace/raw-name pair, never a translated query.
   */
  static async suggestUnscoped(
    context: common.UIAbilityContext,
    query: string,
    limit: number = MAX_SUGGESTIONS,
  ): Promise<NhTagSuggestion[]> {
    const normalizedQuery: string = TagTranslationRepository.normalizedRawName(query)
    if (normalizedQuery.length === 0 || normalizedQuery.length > MAX_SUGGESTION_PREFIX_LENGTH) {
      return []
    }
    const escaped: string = TagTranslationRepository.escapeLike(normalizedQuery)
    const pattern: string = TagTranslationRepository.containsCjk(normalizedQuery)
      ? `%${escaped}%`
      : `${escaped}%`
    const boundedLimit: number = TagTranslationRepository.boundedSuggestionLimit(limit)
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const suggestions: NhTagSuggestion[] = []
    let rows: relationalStore.ResultSet | null = null
    try {
      rows = await store.querySql(SQL_SUGGEST_UNSCOPED, [pattern, pattern, boundedLimit])
      while (rows.goToNextRow()) {
        const suggestion: NhTagSuggestion = new NhTagSuggestion()
        suggestion.namespace = TagTranslationRepository.stringColumn(rows, 'namespace')
        suggestion.rawName = TagTranslationRepository.stringColumn(rows, 'raw_name')
        suggestion.displayName = TagTranslationRepository.stringColumn(rows, 'display_name')
        if (suggestion.namespace.length > 0 && suggestion.rawName.length > 0 &&
          suggestion.displayName.length > 0) {
          suggestions.push(suggestion)
        }
      }
    } finally {
      if (rows !== null) {
        rows.close()
      }
    }
    return suggestions
  }

  /** Records local recency only after the user explicitly accepts a candidate. */
  static async touchSuggestion(
    context: common.UIAbilityContext,
    namespace: string,
    rawName: string,
  ): Promise<void> {
    const normalizedNamespace: string = TagTranslationRepository.normalizedNamespace(namespace)
    const normalizedRawName: string = TagTranslationRepository.normalizedRawName(rawName)
    if (normalizedNamespace.length === 0 || normalizedRawName.length === 0) {
      return
    }
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    await store.executeSql(SQL_TOUCH_SUGGESTION, [Date.now(), normalizedNamespace, normalizedRawName])
  }

  static async replace(
    context: common.UIAbilityContext,
    entries: NhTagTranslationEntry[],
    version: string,
    source: string,
  ): Promise<void> {
    if (entries.length === 0) {
      throw new Error('The tag dictionary contained no usable entries.')
    }
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    let transactionOpen: boolean = false
    try {
      store.beginTransaction()
      transactionOpen = true
      await store.executeSql(SQL_CLEAR)
      const batch: relationalStore.ValuesBucket[] = []
      for (let index: number = 0; index < entries.length; index++) {
        batch.push(TagTranslationRepository.toBucket(entries[index]))
        if (batch.length >= INSERT_BATCH_SIZE) {
          await store.batchInsert('tag_translations', batch)
          batch.splice(0, batch.length)
        }
      }
      if (batch.length > 0) {
        await store.batchInsert('tag_translations', batch)
      }
      await store.executeSql(SQL_UPSERT_META, [META_VERSION, version])
      await store.executeSql(SQL_UPSERT_META, [META_SOURCE, source])
      await store.executeSql(SQL_UPSERT_META, [META_UPDATED_AT, `${Date.now()}`])
      store.commit()
      transactionOpen = false
      connectTagTranslations().publishMutation()
    } catch (error) {
      if (transactionOpen) {
        store.rollBack()
      }
      throw error as Error
    }
  }

  private static async lookupBatch(
    store: relationalStore.RdbStore,
    namespace: string,
    rawNames: string[],
    translations: Map<string, string>,
  ): Promise<void> {
    if (rawNames.length === 0) {
      return
    }
    const placeholders: string[] = []
    const args: relationalStore.ValueType[] = [namespace]
    for (let index: number = 0; index < rawNames.length; index++) {
      placeholders.push('?')
      args.push(rawNames[index])
    }
    let rows: relationalStore.ResultSet | null = null
    try {
      rows = await store.querySql(`${SQL_LOOKUP_PREFIX}${placeholders.join(',')})`, args)
      while (rows.goToNextRow()) {
        const rawName: string = TagTranslationRepository.stringColumn(rows, 'raw_name')
        const displayName: string = TagTranslationRepository.stringColumn(rows, 'display_name')
        if (rawName.length > 0 && displayName.length > 0) {
          translations.set(TagTranslationRepository.makeKey(namespace, rawName), displayName)
        }
      }
    } finally {
      if (rows !== null) {
        rows.close()
      }
    }
  }

  private static async metaValue(store: relationalStore.RdbStore, key: string): Promise<string> {
    let rows: relationalStore.ResultSet | null = null
    try {
      rows = await store.querySql(SQL_SELECT_META, [key])
      return rows.goToFirstRow() ? TagTranslationRepository.stringColumn(rows, 'value') : ''
    } finally {
      if (rows !== null) {
        rows.close()
      }
    }
  }

  private static toBucket(entry: NhTagTranslationEntry): relationalStore.ValuesBucket {
    return {
      'namespace': entry.namespace,
      'raw_name': entry.rawName,
      'display_name': entry.displayName,
      'last_used_at': 0,
    }
  }

  private static makeKey(namespace: string, rawName: string): string {
    return namespace.length === 0 || rawName.length === 0 ? '' : `${namespace}\u001f${rawName}`
  }

  private static normalizedNamespace(type: string): string {
    const normalized: string = type.trim().toLowerCase()
    switch (normalized) {
      case 'tags':
        return 'tag'
      case 'parodies':
        return 'parody'
      case 'characters':
        return 'character'
      case 'artists':
        return 'artist'
      case 'groups':
        return 'group'
      case 'languages':
        return 'language'
      case 'categories':
        return 'category'
      default:
        return normalized
    }
  }

  private static normalizedRawName(name: string): string {
    return name.trim().toLowerCase()
  }

  private static containsCjk(value: string): boolean {
    return /[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff66-\uff9f]/.test(value)
  }

  private static boundedSuggestionLimit(limit: number): number {
    if (!Number.isFinite(limit)) {
      return MAX_SUGGESTIONS
    }
    return Math.max(1, Math.min(MAX_SUGGESTIONS, Math.floor(limit)))
  }

  private static escapeLike(value: string): string {
    return value.replace(/\\/g, '\\\\').replace(/%/g, '\\%').replace(/_/g, '\\_')
  }

  private static stringColumn(rows: relationalStore.ResultSet, name: string): string {
    const column: number = rows.getColumnIndex(name)
    return rows.isColumnNull(column) ? '' : rows.getString(column).trim()
  }

  private static numberColumn(rows: relationalStore.ResultSet, name: string): number {
    const column: number = rows.getColumnIndex(name)
    return rows.isColumnNull(column) ? 0 : Math.floor(rows.getDouble(column))
  }

  private static parseTimestamp(value: string): number {
    const parsed: number = Number(value)
    return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : 0
  }
}
