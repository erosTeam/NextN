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

export const COMMENT_TRANSLATION_PRIORITY_INTERACTIVE: number = 0
export const COMMENT_TRANSLATION_PRIORITY_AUTO: number = 1
const MAX_CONCURRENT_COMMENT_TRANSLATIONS: number = 2
export const MAX_PENDING_COMMENT_TRANSLATIONS: number = 32
const COMMENT_TRANSLATION_QUEUE_EVICTED_ERROR: string = 'comment_translation_queue_evicted'
const COMMENT_TRANSLATION_QUEUE_FULL_ERROR: string = 'comment_translation_queue_full'

/** A small FIFO scheduler that bounds both concurrent and waiting remote comment translations. */
export class CommentTranslationQueueTask {
  key: string = ''
  priority: number = COMMENT_TRANSLATION_PRIORITY_AUTO
  started: boolean = false
  active: boolean = false
  discarded: boolean = false
  private startAction: () => void = () => {}
  private discardAction: (error: Error) => void = (_error: Error): void => {}

  constructor(
    key: string,
    priority: number,
    startAction: () => void,
    discardAction: (error: Error) => void = (_error: Error): void => {},
  ) {
    this.key = key
    this.priority = priority
    this.startAction = startAction
    this.discardAction = discardAction
  }

  start(): void {
    this.startAction()
  }

  discard(error: Error): void {
    if (this.started || this.discarded) {
      return
    }
    this.discarded = true
    this.discardAction(error)
  }
}

/**
 * Bounds distinct remote translations while preserving priority/FIFO order (NextE parity).
 * Cache reads and same-key joins stay outside this scheduler; only the eventual provider
 * call occupies a slot. When the waiting budget is full, stale automatic work yields to
 * the newest visible automatic request or to an interactive request; running work is
 * never cancelled.
 */
export class CommentTranslationQueueScheduler {
  private queue: CommentTranslationQueueTask[] = []
  private running: number = 0

  schedule(task: CommentTranslationQueueTask): void {
    if (task.started || task.discarded) {
      return
    }
    if (!this.makeRoom(task)) {
      return
    }
    this.enqueue(task)
    this.drain()
  }

  /** A user-visible request can move an already-queued auto translation ahead of background work. */
  promote(task: CommentTranslationQueueTask, priority: number): void {
    if (task.discarded || priority >= task.priority) {
      return
    }
    task.priority = priority
    if (task.started || !this.removeQueued(task)) {
      return
    }
    this.enqueue(task)
    this.drain()
  }

  complete(task: CommentTranslationQueueTask): void {
    if (!task.active) {
      return
    }
    task.active = false
    if (this.running > 0) {
      this.running--
    }
    this.drain()
  }

  pendingCount(): number {
    return this.queue.length
  }

  private drain(): void {
    while (this.running < MAX_CONCURRENT_COMMENT_TRANSLATIONS && this.queue.length > 0) {
      const next: CommentTranslationQueueTask | undefined = this.queue.shift()
      if (next === undefined || next.started || next.discarded) {
        continue
      }
      next.started = true
      next.active = true
      this.running++
      next.start()
    }
  }

  private enqueue(task: CommentTranslationQueueTask): void {
    for (let i: number = 0; i < this.queue.length; i++) {
      if (task.priority < this.queue[i].priority) {
        this.queue.splice(i, 0, task)
        return
      }
    }
    this.queue.push(task)
  }

  private makeRoom(task: CommentTranslationQueueTask): boolean {
    if (this.queue.length < MAX_PENDING_COMMENT_TRANSLATIONS) {
      return true
    }
    const discarded: CommentTranslationQueueTask | undefined = this.discardOldestAuto()
    if (discarded !== undefined) {
      discarded.discard(new Error(COMMENT_TRANSLATION_QUEUE_EVICTED_ERROR))
      return true
    }
    task.discard(new Error(COMMENT_TRANSLATION_QUEUE_FULL_ERROR))
    return false
  }

  private discardOldestAuto(): CommentTranslationQueueTask | undefined {
    for (let i: number = 0; i < this.queue.length; i++) {
      if (this.queue[i].priority === COMMENT_TRANSLATION_PRIORITY_AUTO) {
        return this.queue.splice(i, 1)[0]
      }
    }
    return undefined
  }

  private removeQueued(task: CommentTranslationQueueTask): boolean {
    for (let i: number = 0; i < this.queue.length; i++) {
      if (this.queue[i] === task) {
        this.queue.splice(i, 1)
        return true
      }
    }
    return false
  }
}

class CommentTranslationNetworkTask {
  queueTask: CommentTranslationQueueTask
  private readonly work: () => Promise<string>
  private readonly scheduler: CommentTranslationQueueScheduler
  private completion: Promise<string> = Promise.resolve('')
  private resolveCompletion: (result: string) => void = (_result: string): void => {}
  private rejectCompletion: (error: Error) => void = (_error: Error): void => {}
  private settled: boolean = false
  private discardCleanup: () => void = () => {}

  constructor(
    key: string,
    priority: number,
    work: () => Promise<string>,
    scheduler: CommentTranslationQueueScheduler,
  ) {
    this.work = work
    this.scheduler = scheduler
    this.queueTask = new CommentTranslationQueueTask(
      key,
      priority,
      (): void => this.start(),
      (error: Error): void => this.rejectBeforeStart(error),
    )
    this.completion = new Promise<string>((resolve: (result: string) => void, reject: (error: Error) => void): void => {
      this.resolveCompletion = resolve
      this.rejectCompletion = reject
    })
  }

  wait(): Promise<string> {
    return this.completion
  }

  isSettled(): boolean {
    return this.settled
  }

  setDiscardCleanup(cleanup: () => void): void {
    this.discardCleanup = cleanup
  }

  private start(): void {
    try {
      this.work().then(
        (result: string): void => {
          this.resolve(result)
          this.scheduler.complete(this.queueTask)
        },
        (error: Error): void => {
          this.reject(error)
          this.scheduler.complete(this.queueTask)
        },
      )
    } catch (error) {
      this.reject(error as Error)
      this.scheduler.complete(this.queueTask)
    }
  }

  private rejectBeforeStart(error: Error): void {
    this.discardCleanup()
    this.reject(error)
  }

  private resolve(result: string): void {
    if (this.settled) {
      return
    }
    this.settled = true
    this.resolveCompletion(result)
  }

  private reject(error: Error): void {
    if (this.settled) {
      return
    }
    this.settled = true
    this.rejectCompletion(error)
  }
}

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
  private static inflight: Map<string, CommentTranslationNetworkTask> = new Map()
  private static readonly scheduler: CommentTranslationQueueScheduler = new CommentTranslationQueueScheduler()

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

  /**
   * Local, network-free language pre-check (NextE parity): a comment needs
   * translation only when its dominant script differs from the current UI
   * language's. Cheap heuristic — it cannot tell apart latin-script languages
   * or kana-less Japanese, so it errs toward translating when unsure. Used to
   * skip AUTO-translating comments the user can already read; the manual
   * translate button is unaffected.
   */
  static needsTranslation(text: string): boolean {
    const t: string = text.trim()
    if (t.length === 0) {
      return false
    }
    if (!CommentTranslationService.hasLanguageSignal(t)) {
      return false
    }
    const script: string = CommentTranslationService.detectScript(t)
    if (script === 'unknown') {
      return true
    }
    return script !== CommentTranslationService.targetScriptFamily()
  }

  private static targetScriptFamily(): string {
    const target: string = CommentTranslationService.targetLanguage()
    if (target.startsWith('zh')) {
      // Simplified and Traditional are the same spoken language: a Chinese
      // reader can read either, so a Chinese comment never auto-translates.
      return 'zh'
    }
    if (target === 'ja') {
      return 'ja'
    }
    if (target === 'ko') {
      return 'ko'
    }
    return 'latin'
  }

  private static hasLanguageSignal(text: string): boolean {
    let cjk: number = 0
    let other: number = 0
    let latinRun: number = 0
    let latinWordCount: number = 0
    let latinHasVowel: boolean = false
    for (let i: number = 0; i < text.length; i++) {
      const code: number = text.charCodeAt(i)
      if (CommentTranslationService.isLatinLetter(code)) {
        latinRun++
        const ch: string = text.charAt(i).toLowerCase()
        if (ch === 'a' || ch === 'e' || ch === 'i' || ch === 'o' || ch === 'u') {
          latinHasVowel = true
        }
        continue
      }
      if (latinRun >= 4 && latinHasVowel) {
        latinWordCount++
      }
      latinRun = 0
      latinHasVowel = false
      if (
        (code >= 0x3040 && code <= 0x30ff) ||
        (code >= 0x3400 && code <= 0x9fff) ||
        (code >= 0xac00 && code <= 0xd7a3)
      ) {
        cjk++
      } else if (CommentTranslationService.isOtherLetter(code)) {
        other++
      }
    }
    if (latinRun >= 4 && latinHasVowel) {
      latinWordCount++
    }
    return cjk >= 2 || other >= 2 || latinWordCount > 0
  }

  private static isLatinLetter(code: number): boolean {
    return (
      (code >= 0x41 && code <= 0x5a) ||
      (code >= 0x61 && code <= 0x7a) ||
      (code >= 0xc0 && code <= 0x24f)
    )
  }

  private static isOtherLetter(code: number): boolean {
    return (
      (code >= 0x0370 && code <= 0x03ff) ||
      (code >= 0x0400 && code <= 0x052f) ||
      (code >= 0x0590 && code <= 0x05ff) ||
      (code >= 0x0600 && code <= 0x06ff) ||
      (code >= 0x0900 && code <= 0x097f) ||
      (code >= 0x0e00 && code <= 0x0e7f)
    )
  }

  // Dominant-script classifier over the BMP: kana ⇒ Japanese, Hangul ⇒ Korean,
  // Han (no kana) ⇒ Chinese, else Latin letters ⇒ latin. Returns 'unknown'
  // when none are present (digits/punctuation/emoji only).
  private static detectScript(text: string): string {
    let han: number = 0
    let kana: number = 0
    let hangul: number = 0
    let latin: number = 0
    let other: number = 0
    for (let i: number = 0; i < text.length; i++) {
      const code: number = text.charCodeAt(i)
      if ((code >= 0x3040 && code <= 0x309f) || (code >= 0x30a0 && code <= 0x30ff)) {
        kana++
      } else if (
        (code >= 0xac00 && code <= 0xd7a3) ||
        (code >= 0x1100 && code <= 0x11ff) ||
        (code >= 0x3130 && code <= 0x318f)
      ) {
        hangul++
      } else if (
        (code >= 0x4e00 && code <= 0x9fff) ||
        (code >= 0x3400 && code <= 0x4dbf) ||
        (code >= 0xf900 && code <= 0xfaff)
      ) {
        han++
      } else if (CommentTranslationService.isLatinLetter(code)) {
        latin++
      } else if (CommentTranslationService.isOtherLetter(code)) {
        other++
      }
    }
    if (kana > 0) {
      return 'ja'
    }
    if (hangul > 0) {
      return 'ko'
    }
    if (han > 0) {
      return 'zh'
    }
    if (latin > 0) {
      return 'latin'
    }
    if (other > 0) {
      return 'other'
    }
    return 'unknown'
  }

  static isQueueCapacityError(error: Error): boolean {
    return error.message === COMMENT_TRANSLATION_QUEUE_EVICTED_ERROR ||
      error.message === COMMENT_TRANSLATION_QUEUE_FULL_ERROR
  }

  static async translate(
    context: common.UIAbilityContext,
    text: string,
    priority: number = COMMENT_TRANSLATION_PRIORITY_INTERACTIVE,
  ): Promise<string> {
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
    const inFlight: CommentTranslationNetworkTask | undefined = CommentTranslationService.inflight.get(key)
    if (inFlight !== undefined && !inFlight.isSettled()) {
      CommentTranslationService.scheduler.promote(inFlight.queueTask, priority)
      return inFlight.wait()
    }
    if (inFlight !== undefined) {
      CommentTranslationService.inflight.delete(key)
    }
    const queuedTask: CommentTranslationNetworkTask = new CommentTranslationNetworkTask(
      key,
      priority,
      (): Promise<string> => CommentTranslationService.translateNow(
        context,
        source,
        targetLanguage,
        scope,
        key,
        runtime,
      ),
      CommentTranslationService.scheduler,
    )
    const task: Promise<string> = queuedTask.wait()
    queuedTask.setDiscardCleanup((): void => {
      const active: CommentTranslationNetworkTask | undefined = CommentTranslationService.inflight.get(key)
      if (active === queuedTask) {
        CommentTranslationService.inflight.delete(key)
      }
    })
    CommentTranslationService.inflight.set(key, queuedTask)
    CommentTranslationService.scheduler.schedule(queuedTask.queueTask)
    try {
      return await task
    } finally {
      const active: CommentTranslationNetworkTask | undefined = CommentTranslationService.inflight.get(key)
      if (active === queuedTask) {
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
