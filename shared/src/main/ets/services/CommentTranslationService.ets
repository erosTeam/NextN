import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { util } from '@kit.ArkTS'
import { connectLanguageState } from '../state/AppearanceState'
import { LocalDataStore } from '../storage/LocalDataStore'
import { CacheStat } from './CacheStat'
import { ComicTranslationDiagnosticLogger } from './ComicTranslationDiagnosticLogger'
import { LlmSourceRuntimeConfig, LlmSourceRuntimeResolver } from './LlmSourceRuntimeResolver'
import { OpenAiChatCompletionsClient, OpenAiChatCompletionsConfig } from './OpenAiChatCompletionsClient'

const CACHE_TTL_MS: number = 7 * 24 * 60 * 60 * 1000
const MAX_SOURCE_CHARS: number = 12000
const MAX_TRANSLATED_CHARS: number = 16000
const MAX_CACHE_ROWS: number = 512
const SQL_SELECT: string =
  'SELECT translated FROM comment_translation_cache WHERE cache_key = ? AND expires_at > ? LIMIT 1'
const SQL_UPSERT: string =
  'INSERT OR REPLACE INTO comment_translation_cache (cache_key, scope_key, translated, cached_at, expires_at) ' +
  'VALUES (?, ?, ?, ?, ?)'
const SQL_DELETE_ALL: string = 'DELETE FROM comment_translation_cache'
const SQL_DELETE_EXPIRED: string = 'DELETE FROM comment_translation_cache WHERE expires_at <= ?'
const SQL_STAT: string =
  'SELECT COUNT(*) AS c, COALESCE(SUM(LENGTH(CAST(translated AS BLOB))), 0) AS b ' +
  'FROM comment_translation_cache WHERE expires_at > ?'
const SQL_PRUNE: string =
  'DELETE FROM comment_translation_cache WHERE rowid NOT IN (' +
  'SELECT rowid FROM comment_translation_cache WHERE expires_at > ? ORDER BY cached_at DESC LIMIT ?' +
  ')'

class MemoryEntry {
  translated: string = ''
  expiresAt: number = 0
}

/**
 * Text-only translation for explicitly bound comment sources. There is no
 * anonymous fallback: an absent or incapable source is a no-request failure,
 * preserving the user's provider and privacy boundary.
 */
export class CommentTranslationService {
  private static memory: Map<string, MemoryEntry> = new Map()
  private static inflight: Map<string, Promise<string>> = new Map()

  static targetLanguage(): string {
    const locale: string = connectLanguageState().effectiveLocale.toLowerCase()
    if (locale.startsWith('zh-tw') || locale.startsWith('zh-hant')) {
      return 'zh-TW'
    }
    if (locale.startsWith('zh')) {
      return 'zh-CN'
    }
    if (locale.startsWith('ja')) {
      return 'ja'
    }
    if (locale.startsWith('en')) {
      return 'en'
    }
    return locale.length >= 2 ? locale.substring(0, 2) : 'zh-CN'
  }

  static async translate(context: common.UIAbilityContext, text: string): Promise<string> {
    const source: string = text.trim()
    if (source.length === 0) {
      return ''
    }
    if (source.length > MAX_SOURCE_CHARS) {
      throw new Error('Comment text is too large to translate')
    }
    const runtime: LlmSourceRuntimeConfig = await LlmSourceRuntimeResolver.resolveComment(context)
    const targetLanguage: string = CommentTranslationService.targetLanguage()
    const scope: string = `${targetLanguage}|${runtime.requestIdentity()}`
    const key: string = CommentTranslationService.cacheKey(scope, source)
    const cached: string = await CommentTranslationService.cached(context, key)
    if (cached.length > 0) {
      return cached
    }
    const active: Promise<string> | undefined = CommentTranslationService.inflight.get(key)
    if (active !== undefined) {
      return await active
    }
    const task: Promise<string> = CommentTranslationService.translateNow(
      context,
      source,
      targetLanguage,
      scope,
      key,
      runtime,
    )
    CommentTranslationService.inflight.set(key, task)
    try {
      return await task
    } finally {
      if (CommentTranslationService.inflight.get(key) === task) {
        CommentTranslationService.inflight.delete(key)
      }
    }
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    CommentTranslationService.memory.clear()
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    await store.executeSql(SQL_DELETE_ALL)
  }

  static async count(context: common.UIAbilityContext): Promise<number> {
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const rows: relationalStore.ResultSet = await store.querySql(
      'SELECT COUNT(*) AS c FROM comment_translation_cache WHERE expires_at > ?',
      [Date.now()],
    )
    try {
      return rows.goToFirstRow() ? rows.getLong(rows.getColumnIndex('c')) : 0
    } finally {
      rows.close()
    }
  }

  /** Aggregate-only private cache state for Settings; neither text nor cache keys escape this boundary. */
  static async stat(context: common.UIAbilityContext): Promise<CacheStat> {
    const result: CacheStat = new CacheStat()
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const rows: relationalStore.ResultSet = await store.querySql(SQL_STAT, [Date.now()])
    try {
      if (rows.goToFirstRow()) {
        result.count = rows.getDouble(rows.getColumnIndex('c'))
        result.bytes = rows.getDouble(rows.getColumnIndex('b'))
      }
    } finally {
      rows.close()
    }
    return result
  }

  private static async translateNow(
    context: common.UIAbilityContext,
    source: string,
    targetLanguage: string,
    scope: string,
    key: string,
    runtime: LlmSourceRuntimeConfig,
  ): Promise<string> {
    try {
      const config: OpenAiChatCompletionsConfig = new OpenAiChatCompletionsConfig()
      config.baseUrl = runtime.baseUrl
      config.modelId = runtime.modelId
      config.apiKey = runtime.apiKey
      const translated: string = await OpenAiChatCompletionsClient.requestText(
        CommentTranslationService.instructions(targetLanguage),
        source,
        config,
      )
      if (translated.length === 0 || translated.length > MAX_TRANSLATED_CHARS) {
        throw new Error('Comment translation output is invalid')
      }
      await CommentTranslationService.save(context, key, scope, translated)
      return translated
    } catch (error) {
      ComicTranslationDiagnosticLogger.warn('comment-translation', 'comment_translation_failed', '')
      throw error as Error
    }
  }

  private static async cached(context: common.UIAbilityContext, key: string): Promise<string> {
    const now: number = Date.now()
    const memory: MemoryEntry | undefined = CommentTranslationService.memory.get(key)
    if (memory !== undefined) {
      if (memory.expiresAt > now) {
        return memory.translated
      }
      CommentTranslationService.memory.delete(key)
    }
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const rows: relationalStore.ResultSet = await store.querySql(SQL_SELECT, [key, now])
    try {
      if (!rows.goToFirstRow()) {
        return ''
      }
      const translated: string = rows.getString(rows.getColumnIndex('translated'))
      if (translated.length > 0 && translated.length <= MAX_TRANSLATED_CHARS) {
        CommentTranslationService.remember(key, translated, now + CACHE_TTL_MS)
        return translated
      }
    } finally {
      rows.close()
    }
    return ''
  }

  private static async save(
    context: common.UIAbilityContext,
    key: string,
    scope: string,
    translated: string,
  ): Promise<void> {
    const now: number = Date.now()
    const expiresAt: number = now + CACHE_TTL_MS
    CommentTranslationService.remember(key, translated, expiresAt)
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    await store.executeSql(SQL_UPSERT, [key, scope, translated, now, expiresAt])
    try {
      await store.executeSql(SQL_DELETE_EXPIRED, [now])
      await store.executeSql(SQL_PRUNE, [now, MAX_CACHE_ROWS])
    } catch (_error) {
      // A successful translation remains usable even when best-effort cache maintenance fails.
    }
  }

  private static remember(key: string, translated: string, expiresAt: number): void {
    while (CommentTranslationService.memory.size >= 256) {
      const oldest: string | undefined = CommentTranslationService.memory.keys().next().value
      if (oldest === undefined) {
        break
      }
      CommentTranslationService.memory.delete(oldest)
    }
    const entry: MemoryEntry = new MemoryEntry()
    entry.translated = translated
    entry.expiresAt = expiresAt
    CommentTranslationService.memory.delete(key)
    CommentTranslationService.memory.set(key, entry)
  }

  private static cacheKey(scope: string, source: string): string {
    const encoder: util.TextEncoder = new util.TextEncoder()
    const digest = cryptoFramework.createMd('SHA256')
    digest.updateSync({ data: encoder.encodeInto(scope + '\u001f' + source) })
    const bytes: Uint8Array = digest.digestSync().data
    let output: string = ''
    for (let index: number = 0; index < bytes.length; index++) {
      output += bytes[index].toString(16).padStart(2, '0')
    }
    return output
  }

  private static instructions(targetLanguage: string): string {
    return 'Translate the user-provided public gallery comment into ' +
      CommentTranslationService.languageName(targetLanguage) +
      '. Preserve line breaks, quoted text, URLs, and explicit mentions. Return only the translation.'
  }

  private static languageName(language: string): string {
    if (language === 'zh-CN') {
      return 'Simplified Chinese'
    }
    if (language === 'zh-TW') {
      return 'Traditional Chinese'
    }
    if (language === 'ja') {
      return 'Japanese'
    }
    if (language === 'en') {
      return 'English'
    }
    return language
  }
}
