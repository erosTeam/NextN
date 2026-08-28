import { common } from '@kit.AbilityKit'
import { fileIo, fileUri, picker } from '@kit.CoreFileKit'
import { NhGalleryDetail, NhGalleryPage } from '../model/NhGallery'
import { NhDownloadTask, NhDownloadTaskStatus } from '../model/NhDownloadTask'
import { NhApiClient } from '../network/NhApiClient'
import { StreamingHttpClient, StreamingHttpResponse } from '../network/StreamingHttpClient'
import { DownloadQueueRepository } from '../storage/DownloadQueueRepository'
import { DownloadQueueState, connectDownloadQueue } from '../state/DownloadQueueState'
import { DownloadSettingsService } from './DownloadSettingsService'
import { NhDownloadExportCacheService } from './NhDownloadExportCacheService'
import { DownloadNotificationService } from './DownloadNotificationService'

const DOWNLOAD_DIR_NAME: string = 'nextn-downloads'
const DOWNLOAD_ROOT_MARKER: string = '.nextn-download-root'
const METADATA_FILE_NAME: string = 'metadata.json'
const METADATA_SCHEMA: number = 1
const MAX_PAGE_BYTES: number = 64 * 1024 * 1024
const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 30000

class DownloadPageOutcome {
  completed: boolean = false
  failureMessage: string = ''
  /** Bytes atomically promoted by this page attempt; feeds the speed-limit delay. */
  bytes: number = 0
}

/**
 * Structured local batch outcome. It deliberately carries only counts: the
 * page can explain partial completion without exposing task/storage errors or
 * inventing a remote batch protocol.
 */
export class DownloadBatchResult {
  requestedCount: number = 0
  succeededCount: number = 0
  failedCount: number = 0

  isComplete(): boolean {
    return this.requestedCount > 0 && this.failedCount === 0
  }

  hasPartialSuccess(): boolean {
    return this.succeededCount > 0 && this.failedCount > 0
  }
}

/** Structured outcome of a user-initiated download-directory restore. */
export class DownloadRestoreResult {
  scannedCount: number = 0
  importedCount: number = 0
}

/**
 * User-initiated gallery download queue backed by the public Download folder.
 *
 * It intentionally mirrors the ErosN/NextE lifecycle: durable task metadata,
 * one gallery worker, a bounded page pool, atomic .part promotion, and a
 * cold-start transition from in-progress to paused. Legacy sandbox tasks stay
 * readable/removable, but every new page write uses the public Download root.
 */
export class DownloadQueueService {
  private static restoreTask: Promise<void> | null = null
  private static restored: boolean = false
  /**
   * EntryAbility is the sole cold-start owner. This retains only whether its
   * one durable restore failed, so a root tab never silently retries storage
   * merely because it mounted after that failure.
   */
  private static bootstrapRestoreAttempted: boolean = false
  private static bootstrapRestoreFailed: boolean = false
  private static bootstrapRestorePending: boolean = false
  private static bootstrapRestoreTask: Promise<void> | null = null
  private static activeGalleryIds: Set<number> = new Set<number>()
  private static executionTokens: Map<number, number> = new Map<number, number>()
  private static downloadPublicRoot: string = ''
  private static downloadRootRequest: Promise<boolean> | null = null

  /**
   * Preserve the original startup rejection for EntryAbility diagnostics while
   * publishing a non-sensitive result that retained pages can consume.
   */
  static restoreAtBootstrap(context: common.UIAbilityContext): Promise<void> {
    const task: Promise<void> = DownloadQueueService.restoreAtBootstrapInternal(context)
    DownloadQueueService.bootstrapRestoreTask = task
    return task
  }

  private static async restoreAtBootstrapInternal(context: common.UIAbilityContext): Promise<void> {
    DownloadQueueService.bootstrapRestoreAttempted = true
    DownloadQueueService.bootstrapRestoreFailed = false
    DownloadQueueService.bootstrapRestorePending = true
    try {
      await DownloadQueueService.restore(context)
    } catch (error) {
      DownloadQueueService.bootstrapRestoreFailed = true
      throw error as Error
    } finally {
      DownloadQueueService.bootstrapRestorePending = false
    }
  }

  static isRestored(): boolean {
    return DownloadQueueService.restored
  }

  static hasFailedBootstrapRestore(): boolean {
    return DownloadQueueService.bootstrapRestoreAttempted &&
      DownloadQueueService.bootstrapRestoreFailed &&
      !DownloadQueueService.restored
  }

  static isBootstrapRestorePending(): boolean {
    return DownloadQueueService.bootstrapRestoreAttempted && DownloadQueueService.bootstrapRestorePending
  }

  static currentBootstrapRestoreTask(): Promise<void> | null {
    return DownloadQueueService.bootstrapRestoreTask
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    await DownloadSettingsService.restore(context)
    if (DownloadQueueService.restored) {
      return
    }
    if (DownloadQueueService.restoreTask !== null) {
      await DownloadQueueService.restoreTask
      return
    }
    const task: Promise<void> = DownloadQueueService.restoreInternal(context)
    DownloadQueueService.restoreTask = task
    try {
      await task
      DownloadQueueService.restored = true
    } finally {
      DownloadQueueService.restoreTask = null
    }
    // Cold-start opt-in mirrors NextE: failed tasks retry automatically, but
    // paused tasks always stay paused and a retry failure never breaks bootstrap.
    if (DownloadSettingsService.snapshot().autoRetryFailed) {
      await DownloadQueueService.autoRetryFailedTasks(context)
    }
  }

  /**
   * Resume ERROR tasks once per cold start when the user opted in. PAUSED
   * tasks are deliberately excluded: pausing is a manual decision.
   */
  private static async autoRetryFailedTasks(context: common.UIAbilityContext): Promise<void> {
    try {
      const tasks: NhDownloadTask[] = DownloadQueueService.snapshot()
      for (let index: number = 0; index < tasks.length; index++) {
        if (tasks[index].status === NhDownloadTaskStatus.ERROR) {
          await DownloadQueueService.resume(context, tasks[index].galleryId)
        }
      }
    } catch (error) {
      console.warn(`NextNDownload auto-retry failed: ${(error as Error).message}`)
    }
  }

  /** Add a verified detail snapshot to the queue, or resume the same unfinished gallery. */
  static async enqueue(context: common.UIAbilityContext, detail: NhGalleryDetail): Promise<NhDownloadTask> {
    await DownloadQueueService.restore(context)
    if (detail.id <= 0 || detail.mediaId.length === 0 || detail.pages.length === 0) {
      throw new Error('Gallery pages are unavailable for download')
    }
    const existing: NhDownloadTask | null = DownloadQueueService.task(detail.id)
    if (existing !== null) {
      if (!existing.isComplete()) {
        await DownloadQueueService.resume(context, existing.galleryId)
      }
      return DownloadQueueService.task(detail.id) ?? existing
    }
    const extensions: string[] = []
    for (let index: number = 0; index < detail.pages.length; index++) {
      const extension: string = DownloadQueueService.normalizedExtension(detail.pages[index].extension)
      if (extension.length === 0) {
        throw new Error('Gallery page format is unsupported')
      }
      extensions.push(extension)
    }
    if (!await DownloadQueueService.ensureDownloadStorageReady(context)) {
      throw new Error('Public Download directory is unavailable')
    }
    const now: number = Date.now()
    const task: NhDownloadTask = new NhDownloadTask()
    task.galleryId = detail.id
    task.mediaId = detail.mediaId
    task.title = detail.displayTitle()
    task.thumbnailUrl = detail.thumbnailUrl.length > 0 ? detail.thumbnailUrl : detail.coverUrl
    task.pageCount = detail.pages.length
    task.pageExtensions = extensions
    task.storageDirectory = DownloadQueueService.publicTaskDirectory(task.galleryId)
    task.completedPages = 0
    task.status = NhDownloadTaskStatus.QUEUED
    task.createdAt = now
    task.updatedAt = now
    DownloadQueueService.putInState(task)
    try {
      await DownloadQueueRepository.save(context, task)
    } catch (error) {
      DownloadQueueService.removeFromState(task.galleryId)
      throw error as Error
    }
    DownloadQueueService.writeTaskMetadata(context, task)
    DownloadQueueService.pump(context)
    return task.copy()
  }

  /** Stop scheduling after current page streams settle; completed files stay resumable. */
  static async pause(context: common.UIAbilityContext, galleryId: number): Promise<void> {
    await DownloadQueueService.restore(context)
    const task: NhDownloadTask | null = DownloadQueueService.task(galleryId)
    if (task === null || task.isComplete()) {
      return
    }
    DownloadQueueService.invalidateExecution(galleryId)
    task.status = NhDownloadTaskStatus.PAUSED
    task.errorMessage = ''
    task.updatedAt = Date.now()
    DownloadQueueService.putInState(task)
    await DownloadQueueRepository.save(context, task)
    DownloadQueueService.writeTaskMetadata(context, task)
  }

  /** Reconcile promoted files, then schedule the remaining page set. */
  static async resume(context: common.UIAbilityContext, galleryId: number): Promise<void> {
    await DownloadQueueService.restore(context)
    const task: NhDownloadTask | null = DownloadQueueService.task(galleryId)
    if (task === null || task.isComplete()) {
      return
    }
    if (DownloadQueueService.isLegacyTaskDirectory(context, task.storageDirectory)) {
      if (!await DownloadQueueService.ensureDownloadStorageReady(context)) {
        throw new Error('Public Download directory is unavailable')
      }
      // Legacy partial files remain a read/removal source. Resuming starts a
      // clean public task directory so no new bytes extend the sandbox copy.
      task.storageDirectory = DownloadQueueService.publicTaskDirectory(task.galleryId)
    }
    const wasComplete: boolean = task.isComplete()
    task.completedPages = DownloadQueueService.completedFileCount(context, task)
    task.status = task.completedPages >= task.pageCount
      ? NhDownloadTaskStatus.COMPLETE
      : NhDownloadTaskStatus.QUEUED
    task.errorMessage = ''
    task.updatedAt = Date.now()
    DownloadQueueService.putInState(task)
    await DownloadQueueRepository.save(context, task)
    DownloadQueueService.writeTaskMetadata(context, task)
    if (!wasComplete && task.isComplete()) {
      await DownloadNotificationService.publishDownloadComplete(task.title)
    }
    if (!task.isComplete()) {
      DownloadQueueService.pump(context)
    }
  }

  /**
   * Apply a page-selected local batch by reusing the established pause path.
   * The caller supplies only visible eligible IDs; this service deliberately
   * adds neither another worker nor a remote/bulk request.
   */
  static async pauseVisible(
    context: common.UIAbilityContext,
    galleryIds: number[],
  ): Promise<DownloadBatchResult> {
    const ids: number[] = DownloadQueueService.uniqueGalleryIds(galleryIds)
    const result: DownloadBatchResult = new DownloadBatchResult()
    result.requestedCount = ids.length
    for (let index: number = 0; index < ids.length; index += 1) {
      try {
        await DownloadQueueService.pause(context, ids[index])
        result.succeededCount += 1
      } catch (_error) {
        result.failedCount += 1
      }
    }
    return result
  }

  /** Same bounded local operation for paused or retryable visible tasks. */
  static async resumeVisible(
    context: common.UIAbilityContext,
    galleryIds: number[],
  ): Promise<DownloadBatchResult> {
    const ids: number[] = DownloadQueueService.uniqueGalleryIds(galleryIds)
    const result: DownloadBatchResult = new DownloadBatchResult()
    result.requestedCount = ids.length
    for (let index: number = 0; index < ids.length; index += 1) {
      try {
        await DownloadQueueService.resume(context, ids[index])
        result.succeededCount += 1
      } catch (_error) {
        result.failedCount += 1
      }
    }
    return result
  }

  /** Forget one task and exactly its own public and legacy task directories. */
  static async remove(context: common.UIAbilityContext, galleryId: number): Promise<void> {
    await DownloadQueueService.restore(context)
    const task: NhDownloadTask | null = DownloadQueueService.task(galleryId)
    if (task === null) {
      return
    }
    DownloadQueueService.invalidateExecution(galleryId)
    DownloadQueueService.removeFromState(galleryId)
    try {
      DownloadQueueService.removeTaskFiles(context, task)
      NhDownloadExportCacheService.reclaimGallery(context, galleryId)
      await DownloadQueueRepository.remove(context, galleryId)
    } catch (error) {
      DownloadQueueService.putInState(task)
      throw error as Error
    }
  }

  static snapshot(): NhDownloadTask[] {
    return connectDownloadQueue().tasks.map((task: NhDownloadTask): NhDownloadTask => task.copy())
  }

  /** Wake queued work after a durable local policy change. */
  static async applySettings(context: common.UIAbilityContext): Promise<void> {
    await DownloadQueueService.restore(context)
    DownloadQueueService.pump(context)
  }

  /**
   * User-initiated restore (mirrors NextE's importTasksFromDownloadDirectory):
   * scan public Download metadata (plus the legacy sandbox compatibility root)
   * the queue row set lacks into state and RDB. Imported tasks keep their
   * durable status; paused and failed tasks resume through the normal rows.
   */
  static async restoreFromDownloadDirectory(
    context: common.UIAbilityContext,
  ): Promise<DownloadRestoreResult> {
    const result: DownloadRestoreResult = new DownloadRestoreResult()
    await DownloadQueueService.restore(context)
    if (!await DownloadQueueService.ensureDownloadStorageReady(context)) {
      throw new Error('Public Download directory is unavailable')
    }
    const scanned: NhDownloadTask[] = DownloadQueueService.loadTaskMetadataTasks(context)
    result.scannedCount = scanned.length
    const writes: Promise<void>[] = []
    for (let index: number = 0; index < scanned.length; index++) {
      const candidate: NhDownloadTask = scanned[index]
      if (DownloadQueueService.task(candidate.galleryId) !== null) {
        continue
      }
      const task: NhDownloadTask = candidate.copy()
      task.completedPages = DownloadQueueService.completedFileCount(context, task)
      if (task.status === NhDownloadTaskStatus.DOWNLOADING ||
        (task.status === NhDownloadTaskStatus.QUEUED &&
          DownloadQueueService.isLegacyTaskDirectory(context, task.storageDirectory))) {
        task.status = NhDownloadTaskStatus.PAUSED
        task.errorMessage = ''
      }
      DownloadQueueService.normalizeTaskState(task)
      task.updatedAt = Date.now()
      DownloadQueueService.putInState(task)
      writes.push(DownloadQueueRepository.save(context, task))
      result.importedCount += 1
    }
    for (let index: number = 0; index < writes.length; index++) {
      await writes[index]
    }
    if (result.importedCount > 0) {
      const tasks: NhDownloadTask[] = DownloadQueueService.snapshot()
      for (let index: number = 0; index < tasks.length; index++) {
        DownloadQueueService.writeTaskMetadata(context, tasks[index])
      }
      DownloadQueueService.pump(context)
    }
    return result
  }

  /**
   * Supplies a complete local download to Reader without asking the API for
   * a second copy of its page manifest. A task is eligible only when every
   * promoted page is still present in the task-owned directory.
   */
  static async localReaderDetail(
    context: common.UIAbilityContext,
    galleryId: number,
  ): Promise<NhGalleryDetail | null> {
    await DownloadQueueService.restore(context)
    const task: NhDownloadTask | null = DownloadQueueService.task(galleryId)
    if (task === null || !task.isComplete() ||
      DownloadQueueService.completedFileCount(context, task) !== task.pageCount) {
      return null
    }
    const detail: NhGalleryDetail = new NhGalleryDetail()
    detail.id = task.galleryId
    detail.mediaId = task.mediaId
    detail.title = task.title
    detail.prettyTitle = task.title
    detail.coverUrl = task.thumbnailUrl
    detail.thumbnailUrl = task.thumbnailUrl
    detail.pageCount = task.pageCount
    for (let index: number = 0; index < task.pageCount; index++) {
      const page: NhGalleryPage = new NhGalleryPage()
      page.number = index + 1
      page.extension = task.pageExtensions[index]
      detail.pages.push(page)
    }
    return detail
  }

  /** Returns a display URI only for a verified, fully downloaded local page. */
  static localPageUri(
    context: common.UIAbilityContext,
    galleryId: number,
    pageIndex: number,
    extension: string,
  ): string {
    const task: NhDownloadTask | null = DownloadQueueService.task(galleryId)
    if (task === null || !task.isComplete() || pageIndex < 0 || pageIndex >= task.pageCount ||
      task.pageExtensions[pageIndex] !== DownloadQueueService.normalizedExtension(extension) ||
      !DownloadQueueService.pageIsComplete(context, task, pageIndex)) {
      return ''
    }
    return DownloadQueueService.displayUri(DownloadQueueService.pagePath(context, task, pageIndex))
  }

  /**
   * Provides the ordered local source files for a local-only archive export.
   * This is deliberately a pure verification read: it neither reconciles nor
   * persists task state, so a cancelled or failed share cannot mutate the
   * download queue. A caller receives no paths unless every completed page is
   * still present under this task's owned directory.
   */
  static completeLocalPagePaths(
    context: common.UIAbilityContext,
    task: NhDownloadTask,
  ): string[] {
    if (!task.isComplete() || task.pageCount <= 0 || task.pageExtensions.length !== task.pageCount) {
      return []
    }
    const paths: string[] = []
    for (let index: number = 0; index < task.pageCount; index += 1) {
      if (!DownloadQueueService.pageIsComplete(context, task, index)) {
        return []
      }
      paths.push(DownloadQueueService.pagePath(context, task, index))
    }
    return paths
  }

  /**
   * Cold-start reconcile. The RDB row set is primary; per-task directory
   * metadata fills gaps the queue row lost (mirrors NextE's restore merge).
   * Both sources are re-verified against the page files before persisting,
   * and every sidecar is rewritten from the reconciled truth.
   */
  private static async restoreInternal(context: common.UIAbilityContext): Promise<void> {
    const restored: NhDownloadTask[] = await DownloadQueueRepository.loadAll(context)
    DownloadQueueService.adoptPublicRootFromTasks(context, restored)
    for (let index: number = 0; index < restored.length; index++) {
      if (restored[index].storageDirectory.length === 0) {
        const legacy: string = DownloadQueueService.legacyTaskDirectory(context, restored[index].galleryId)
        if (DownloadQueueService.directoryExists(legacy)) {
          restored[index].storageDirectory = legacy
        }
      }
    }
    const directoryTasks: NhDownloadTask[] = DownloadQueueService.loadTaskMetadataTasks(context)
    const merged: NhDownloadTask[] = []
    for (let index: number = 0; index < restored.length; index++) {
      merged.push(restored[index].copy())
    }
    for (let index: number = 0; index < directoryTasks.length; index++) {
      const candidate: NhDownloadTask = directoryTasks[index]
      const existing: NhDownloadTask | undefined = merged.find(
        (value: NhDownloadTask): boolean => value.galleryId === candidate.galleryId,
      )
      if (existing === undefined) {
        merged.push(candidate)
      } else if (existing.storageDirectory.length === 0 && candidate.storageDirectory.length > 0) {
        existing.storageDirectory = candidate.storageDirectory
      }
    }
    const writes: Promise<void>[] = []
    for (let index: number = 0; index < merged.length; index++) {
      const task: NhDownloadTask = merged[index]
      task.completedPages = DownloadQueueService.completedFileCount(context, task)
      if (task.status === NhDownloadTaskStatus.DOWNLOADING ||
        (task.status === NhDownloadTaskStatus.QUEUED &&
          DownloadQueueService.isLegacyTaskDirectory(context, task.storageDirectory))) {
        task.status = NhDownloadTaskStatus.PAUSED
        task.errorMessage = ''
      }
      DownloadQueueService.normalizeTaskState(task)
      task.updatedAt = Date.now()
      writes.push(DownloadQueueRepository.save(context, task))
    }
    DownloadQueueService.state().replace(merged)
    for (let index: number = 0; index < writes.length; index++) {
      await writes[index]
    }
    for (let index: number = 0; index < merged.length; index++) {
      DownloadQueueService.writeTaskMetadata(context, merged[index])
    }
    NhDownloadExportCacheService.pruneExpired(context)
    DownloadQueueService.pump(context)
  }

  private static pump(context: common.UIAbilityContext): void {
    if (!DownloadQueueService.restored && DownloadQueueService.restoreTask === null) {
      return
    }
    while (DownloadQueueService.activeGalleryIds.size < DownloadQueueService.maxConcurrentGalleries()) {
      const candidate: NhDownloadTask | null = DownloadQueueService.nextQueuedTask()
      if (candidate === null) {
        return
      }
      DownloadQueueService.activeGalleryIds.add(candidate.galleryId)
      const token: number = DownloadQueueService.nextExecutionToken(candidate.galleryId)
      DownloadQueueService.runGallery(context, candidate.galleryId, token)
        .catch((error: Error): void => {
          console.warn(`NextNDownload worker failed: ${error.message}`)
        })
        .finally((): void => {
          DownloadQueueService.activeGalleryIds.delete(candidate.galleryId)
          DownloadQueueService.pump(context)
        })
    }
  }

  private static nextQueuedTask(): NhDownloadTask | null {
    const tasks: NhDownloadTask[] = DownloadQueueService.state().tasks
    for (let index: number = 0; index < tasks.length; index++) {
      if (tasks[index].status === NhDownloadTaskStatus.QUEUED &&
        !DownloadQueueService.activeGalleryIds.has(tasks[index].galleryId)) {
        return tasks[index].copy()
      }
    }
    return null
  }

  private static async runGallery(
    context: common.UIAbilityContext,
    galleryId: number,
    token: number,
  ): Promise<void> {
    const task: NhDownloadTask | null = DownloadQueueService.task(galleryId)
    if (task === null || task.status !== NhDownloadTaskStatus.QUEUED ||
      DownloadQueueService.executionTokens.get(galleryId) !== token) {
      return
    }
    task.completedPages = DownloadQueueService.completedFileCount(context, task)
    task.status = NhDownloadTaskStatus.DOWNLOADING
    task.errorMessage = ''
    task.updatedAt = Date.now()
    await DownloadQueueService.persist(context, task)
    const pending: number[] = []
    for (let index: number = 0; index < task.pageCount; index++) {
      if (!DownloadQueueService.pageIsComplete(context, task, index)) {
        pending.push(index)
      }
    }
    let failureMessage: string = ''
    for (let start: number = 0; start < pending.length; start += DownloadQueueService.maxConcurrentPages()) {
      if (!DownloadQueueService.isExecutionActive(galleryId, token)) {
        return
      }
      // Batch-level pacing mirrors NextE: the interval pauses between batches.
      if (start > 0) {
        await DownloadQueueService.delay(DownloadQueueService.requestIntervalSeconds() * 1000)
        if (!DownloadQueueService.isExecutionActive(galleryId, token)) {
          return
        }
      }
      const batchStartedAt: number = Date.now()
      let batchBytes: number = 0
      const jobs: Promise<DownloadPageOutcome>[] = []
      const end: number = Math.min(pending.length, start + DownloadQueueService.maxConcurrentPages())
      for (let index: number = start; index < end; index++) {
        jobs.push(DownloadQueueService.downloadPage(context, task, pending[index], token))
      }
      const outcomes: DownloadPageOutcome[] = await Promise.all(jobs)
      if (!DownloadQueueService.isExecutionActive(galleryId, token)) {
        // A pause can invalidate this worker after a page has atomically
        // promoted its final file but before that page publishes its count.
        // Reconcile the durable task once the whole in-flight batch settles so
        // a full local set never remains presented as resumable.
        await DownloadQueueService.reconcileInterruptedTask(context, galleryId)
        return
      }
      for (let index: number = 0; index < outcomes.length; index++) {
        if (outcomes[index].failureMessage.length > 0 && failureMessage.length === 0) {
          failureMessage = outcomes[index].failureMessage
        }
        batchBytes += Math.max(0, outcomes[index].bytes)
      }
      DownloadQueueService.writeTaskMetadata(context, DownloadQueueService.task(galleryId) ?? task)
      if (failureMessage.length > 0) {
        break
      }
      await DownloadQueueService.delayBytesForSpeedLimit(batchStartedAt, batchBytes)
    }
    if (!DownloadQueueService.isExecutionActive(galleryId, token)) {
      return
    }
    const current: NhDownloadTask | null = DownloadQueueService.task(galleryId)
    if (current === null) {
      return
    }
    const wasComplete: boolean = current.isComplete()
    current.completedPages = DownloadQueueService.completedFileCount(context, current)
    current.status = current.completedPages >= current.pageCount
      ? NhDownloadTaskStatus.COMPLETE
      : NhDownloadTaskStatus.ERROR
    current.errorMessage = current.status === NhDownloadTaskStatus.ERROR
      ? (failureMessage.length > 0 ? failureMessage : 'One or more pages could not be saved')
      : ''
    current.updatedAt = Date.now()
    await DownloadQueueService.persist(context, current)
    DownloadQueueService.writeTaskMetadata(context, current)
    if (!wasComplete && current.isComplete()) {
      await DownloadNotificationService.publishDownloadComplete(current.title)
    }
  }

  private static async downloadPage(
    context: common.UIAbilityContext,
    task: NhDownloadTask,
    pageIndex: number,
    token: number,
  ): Promise<DownloadPageOutcome> {
    const outcome: DownloadPageOutcome = new DownloadPageOutcome()
    if (!DownloadQueueService.isExecutionActive(task.galleryId, token)) {
      return outcome
    }
    if (DownloadQueueService.pageIsComplete(context, task, pageIndex)) {
      outcome.completed = true
      return outcome
    }
    let lastFailure: string = ''
    const attempts: number = DownloadQueueService.retryCount() + 1
    for (let attempt: number = 0; attempt < attempts; attempt++) {
      if (!DownloadQueueService.isExecutionActive(task.galleryId, token)) {
        return outcome
      }
      try {
        const bytes: number = await DownloadQueueService.downloadPageOnce(context, task, pageIndex, token)
        const current: NhDownloadTask | null = DownloadQueueService.task(task.galleryId)
        if (current !== null && DownloadQueueService.isExecutionActive(task.galleryId, token)) {
          current.completedPages = DownloadQueueService.completedFileCount(context, current)
          current.updatedAt = Date.now()
          await DownloadQueueService.persist(context, current)
          outcome.completed = true
          outcome.bytes = bytes
        }
        return outcome
      } catch (error) {
        lastFailure = (error as Error).message || 'Page download failed'
        if (attempt + 1 < attempts && DownloadQueueService.isExecutionActive(task.galleryId, token)) {
          await DownloadQueueService.delay((attempt + 1) * 700)
        }
      }
    }
    outcome.failureMessage = lastFailure
    return outcome
  }

  private static async downloadPageOnce(
    context: common.UIAbilityContext,
    task: NhDownloadTask,
    pageIndex: number,
    token: number,
  ): Promise<number> {
    const finalPath: string = DownloadQueueService.pagePath(context, task, pageIndex)
    const temporaryPath: string = `${finalPath}.part`
    DownloadQueueService.ensureTaskDirectory(context, task)
    const directPublicWrite: boolean = DownloadQueueService.isPublicDownloadPath(finalPath)
    const writePath: string = directPublicWrite ? finalPath : temporaryPath
    DownloadQueueService.removeIfExists(writePath)
    let file: fileIo.File | null = null
    let written: number = 0
    let writeFailure: string = ''
    let promoted: boolean = false
    try {
      file = fileIo.openSync(
        writePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      const headers: Record<string, string> = {}
      headers['Accept'] = 'image/*'
      headers['User-Agent'] = 'NextN/1.0.0'
      const response: StreamingHttpResponse = await StreamingHttpClient.get(
        NhApiClient.imageUrl(task.mediaId, pageIndex, task.pageExtensions[pageIndex]),
        headers,
        CONNECT_TIMEOUT_MS,
        READ_TIMEOUT_MS,
        MAX_PAGE_BYTES,
        (data: ArrayBuffer): boolean => {
          if (file === null || writeFailure.length > 0) {
            return false
          }
          try {
            const count: number = fileIo.writeSync(file.fd, data)
            if (count !== data.byteLength) {
              throw new Error('Unable to save gallery page')
            }
            written += count
            return true
          } catch (error) {
            writeFailure = (error as Error).message || 'Unable to save gallery page'
            return false
          }
        },
        (): boolean => DownloadQueueService.isExecutionActive(task.galleryId, token),
      )
      if (!DownloadQueueService.isExecutionActive(task.galleryId, token)) {
        return 0
      }
      if (response.limitExceeded) {
        throw new Error('A gallery page exceeds the download limit')
      }
      if (writeFailure.length > 0) {
        throw new Error(writeFailure)
      }
      if (response.sinkRejected) {
        throw new Error('Unable to save gallery page')
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw new Error(`Gallery page request failed (${response.statusCode}).`)
      }
      if (written <= 0) {
        throw new Error('Gallery page response was empty')
      }
      fileIo.closeSync(file)
      file = null
      if (!directPublicWrite) {
        DownloadQueueService.removeIfExists(finalPath)
        fileIo.renameSync(temporaryPath, finalPath)
      }
      if (DownloadQueueService.fileSize(finalPath) !== written) {
        DownloadQueueService.removeIfExists(finalPath)
        throw new Error('Saved gallery page did not verify')
      }
      promoted = true
      return written
    } finally {
      if (file !== null) {
        fileIo.closeSync(file)
      }
      if (!promoted) {
        DownloadQueueService.removeIfExists(writePath)
      }
    }
  }

  private static async persist(context: common.UIAbilityContext, task: NhDownloadTask): Promise<void> {
    DownloadQueueService.putInState(task)
    await DownloadQueueRepository.save(context, task)
  }

  /**
   * A cancelled worker cannot publish page-by-page progress because its token
   * is no longer active. Its already-promoted files are still durable truth,
   * however, so reconcile the current task after that worker's batch settles.
   * Partial work remains paused; a full set is normalized to COMPLETE.
   */
  private static async reconcileInterruptedTask(
    context: common.UIAbilityContext,
    galleryId: number,
  ): Promise<void> {
    const task: NhDownloadTask | null = DownloadQueueService.task(galleryId)
    if (task === null) {
      return
    }
    const wasComplete: boolean = task.isComplete()
    const previousCompletedPages: number = task.completedPages
    const previousStatus: string = task.status
    const previousErrorMessage: string = task.errorMessage
    task.completedPages = DownloadQueueService.completedFileCount(context, task)
    DownloadQueueService.normalizeTaskState(task)
    if (task.completedPages === previousCompletedPages && task.status === previousStatus &&
      task.errorMessage === previousErrorMessage) {
      return
    }
    task.updatedAt = Date.now()
    await DownloadQueueService.persist(context, task)
    DownloadQueueService.writeTaskMetadata(context, task)
    if (!wasComplete && task.isComplete()) {
      await DownloadNotificationService.publishDownloadComplete(task.title)
    }
  }

  private static state(): DownloadQueueState {
    return connectDownloadQueue()
  }

  private static task(galleryId: number): NhDownloadTask | null {
    const tasks: NhDownloadTask[] = DownloadQueueService.state().tasks
    for (let index: number = 0; index < tasks.length; index++) {
      if (tasks[index].galleryId === galleryId) {
        return tasks[index].copy()
      }
    }
    return null
  }

  /** Defensive de-duplication keeps a projected title command bounded to one task mutation each. */
  private static uniqueGalleryIds(galleryIds: number[]): number[] {
    const ids: number[] = []
    const known: Set<number> = new Set<number>()
    for (let index: number = 0; index < galleryIds.length; index += 1) {
      const galleryId: number = galleryIds[index]
      if (galleryId > 0 && !known.has(galleryId)) {
        known.add(galleryId)
        ids.push(galleryId)
      }
    }
    return ids
  }

  /**
   * Queue lifecycle is authoritative here, before any state snapshot or
   * durable write. A fully promoted local page set is always COMPLETE: a
   * late pause may stop future work, but it must not hide a finished task
   * behind a resumable status.
   */
  private static normalizeTaskState(task: NhDownloadTask): void {
    const pageCount: number = Math.max(0, task.pageCount)
    task.pageCount = pageCount
    task.completedPages = Math.min(pageCount, Math.max(0, task.completedPages))
    if (pageCount === 0) {
      return
    }
    if (task.completedPages === pageCount) {
      task.status = NhDownloadTaskStatus.COMPLETE
      task.errorMessage = ''
      return
    }
    if (task.status === NhDownloadTaskStatus.COMPLETE) {
      task.status = NhDownloadTaskStatus.PAUSED
      task.errorMessage = ''
    }
  }

  private static putInState(task: NhDownloadTask): void {
    DownloadQueueService.normalizeTaskState(task)
    const tasks: NhDownloadTask[] = DownloadQueueService.snapshot()
    const index: number = tasks.findIndex((candidate: NhDownloadTask): boolean => candidate.galleryId === task.galleryId)
    if (index >= 0) {
      tasks[index] = task.copy()
    } else {
      tasks.unshift(task.copy())
    }
    DownloadQueueService.state().replace(tasks)
  }

  private static removeFromState(galleryId: number): void {
    const tasks: NhDownloadTask[] = DownloadQueueService.snapshot().filter(
      (task: NhDownloadTask): boolean => task.galleryId !== galleryId,
    )
    DownloadQueueService.state().replace(tasks)
  }

  private static nextExecutionToken(galleryId: number): number {
    const token: number = (DownloadQueueService.executionTokens.get(galleryId) ?? 0) + 1
    DownloadQueueService.executionTokens.set(galleryId, token)
    return token
  }

  private static invalidateExecution(galleryId: number): void {
    DownloadQueueService.executionTokens.set(
      galleryId,
      (DownloadQueueService.executionTokens.get(galleryId) ?? 0) + 1,
    )
  }

  private static isExecutionActive(galleryId: number, token: number): boolean {
    const task: NhDownloadTask | null = DownloadQueueService.task(galleryId)
    return task !== null && task.status === NhDownloadTaskStatus.DOWNLOADING &&
      DownloadQueueService.executionTokens.get(galleryId) === token
  }

  private static maxConcurrentGalleries(): number {
    return DownloadSettingsService.snapshot().maxConcurrentGalleries
  }

  private static maxConcurrentPages(): number {
    return DownloadSettingsService.snapshot().maxConcurrentPages
  }

  private static retryCount(): number {
    return DownloadSettingsService.snapshot().retryCount
  }

  private static requestIntervalSeconds(): number {
    return DownloadSettingsService.snapshot().requestIntervalSeconds
  }

  private static speedLimitKbps(): number {
    return DownloadSettingsService.snapshot().speedLimitKbps
  }

  /**
   * Batch-level speed governor (mirrors NextE): after a batch settles, sleep
   * so its bytes take no less than the capped-rate duration. A 0 cap is off.
   */
  private static async delayBytesForSpeedLimit(batchStartedAt: number, bytes: number): Promise<void> {
    const kbps: number = DownloadQueueService.speedLimitKbps()
    if (kbps <= 0 || bytes <= 0) {
      return
    }
    const expectedMs: number = Math.ceil((bytes * 1000) / (kbps * 1024))
    const remainMs: number = expectedMs - (Date.now() - batchStartedAt)
    if (remainMs > 0) {
      await DownloadQueueService.delay(remainMs)
    }
  }

  private static legacyDownloadRoot(context: common.UIAbilityContext): string {
    return `${context.filesDir}/${DOWNLOAD_DIR_NAME}`
  }

  private static legacyTaskDirectory(context: common.UIAbilityContext, galleryId: number): string {
    return `${DownloadQueueService.legacyDownloadRoot(context)}/${galleryId}`
  }

  private static publicDownloadRoot(): string {
    if (DownloadQueueService.downloadPublicRoot.length === 0) {
      throw new Error('Public Download directory is unavailable')
    }
    return `${DownloadQueueService.downloadPublicRoot}/${DOWNLOAD_DIR_NAME}`
  }

  private static publicTaskDirectory(galleryId: number): string {
    return `${DownloadQueueService.publicDownloadRoot()}/${galleryId}`
  }

  private static taskDirectory(context: common.UIAbilityContext, task: NhDownloadTask): string {
    return task.storageDirectory.length > 0
      ? DownloadQueueService.normalizePath(task.storageDirectory)
      : DownloadQueueService.legacyTaskDirectory(context, task.galleryId)
  }

  private static metadataPath(context: common.UIAbilityContext, task: NhDownloadTask): string {
    return `${DownloadQueueService.taskDirectory(context, task)}/${METADATA_FILE_NAME}`
  }

  private static pagePath(context: common.UIAbilityContext, task: NhDownloadTask, pageIndex: number): string {
    return `${DownloadQueueService.taskDirectory(context, task)}/${pageIndex + 1}.${task.pageExtensions[pageIndex]}`
  }

  private static ensureTaskDirectory(context: common.UIAbilityContext, task: NhDownloadTask): void {
    const directory: string = DownloadQueueService.taskDirectory(context, task)
    if (DownloadQueueService.isLegacyTaskDirectory(context, directory)) {
      throw new Error('Legacy sandbox downloads are read-only')
    }
    DownloadQueueService.ensureDirectory(directory)
  }

  private static ensureDirectory(directory: string): void {
    try {
      fileIo.mkdirSync(directory, true)
    } catch (error) {
      if (!fileIo.accessSync(directory)) {
        throw error as Error
      }
    }
  }

  private static directoryExists(directory: string): boolean {
    try {
      return directory.length > 0 && fileIo.accessSync(directory) && fileIo.statSync(directory).isDirectory()
    } catch (_error) {
      return false
    }
  }

  private static isLegacyTaskDirectory(context: common.UIAbilityContext, directory: string): boolean {
    const normalized: string = DownloadQueueService.normalizePath(directory)
    const legacyRoot: string = DownloadQueueService.legacyDownloadRoot(context)
    return normalized.length === 0 || normalized === legacyRoot || normalized.startsWith(`${legacyRoot}/`)
  }

  private static isPublicDownloadPath(path: string): boolean {
    if (DownloadQueueService.downloadPublicRoot.length === 0) {
      return false
    }
    const root: string = DownloadQueueService.normalizePath(DownloadQueueService.downloadPublicRoot)
    const normalized: string = DownloadQueueService.normalizePath(path)
    return normalized === root || normalized.startsWith(`${root}/`)
  }

  private static async ensureDownloadStorageReady(context: common.UIAbilityContext): Promise<boolean> {
    if (DownloadQueueService.downloadPublicRoot.length > 0) {
      try {
        DownloadQueueService.ensureDirectory(DownloadQueueService.publicDownloadRoot())
        return true
      } catch (_error) {
        DownloadQueueService.downloadPublicRoot = ''
      }
    }
    if (DownloadQueueService.downloadRootRequest !== null) {
      return await DownloadQueueService.downloadRootRequest
    }
    const request: Promise<boolean> = DownloadQueueService.requestPublicDownloadRoot(context)
    DownloadQueueService.downloadRootRequest = request
    try {
      return await request
    } finally {
      DownloadQueueService.downloadRootRequest = null
    }
  }

  private static async requestPublicDownloadRoot(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const options = new picker.DocumentSaveOptions()
      options.pickerMode = picker.DocumentPickerMode.DOWNLOAD
      const documentPicker = new picker.DocumentViewPicker(context)
      const result: string[] = await documentPicker.save(options)
      if (result.length === 0) {
        return false
      }
      const root: string = DownloadQueueService.pathFromDownloadModeUri(result[0])
      if (root.length === 0) {
        return false
      }
      DownloadQueueService.downloadPublicRoot = root
      DownloadQueueService.ensureDirectory(DownloadQueueService.publicDownloadRoot())
      return true
    } catch (_error) {
      DownloadQueueService.downloadPublicRoot = ''
      return false
    }
  }

  private static pathFromDownloadModeUri(uri: string): string {
    const markerPath: string = new fileUri.FileUri(
      `${DownloadQueueService.normalizePath(uri)}/${DOWNLOAD_ROOT_MARKER}`,
    ).path
    const suffix: string = `/${DOWNLOAD_ROOT_MARKER}`
    if (!markerPath.endsWith(suffix)) {
      throw new Error('Download directory URI could not be resolved')
    }
    let root: string = DownloadQueueService.normalizePath(
      markerPath.substring(0, markerPath.length - suffix.length),
    )
    if (root.endsWith('/NextN/NextN')) {
      root = root.substring(0, root.length - '/NextN'.length)
    }
    return root
  }

  private static normalizePath(path: string): string {
    let normalized: string = path.trim()
    while (normalized.endsWith('/') && normalized.length > 1) {
      normalized = normalized.substring(0, normalized.length - 1)
    }
    return normalized
  }

  private static adoptPublicRootFromTasks(context: common.UIAbilityContext, tasks: NhDownloadTask[]): void {
    if (DownloadQueueService.downloadPublicRoot.length > 0) {
      return
    }
    const suffix: string = `/${DOWNLOAD_DIR_NAME}`
    for (let index: number = 0; index < tasks.length; index++) {
      const directory: string = DownloadQueueService.normalizePath(tasks[index].storageDirectory)
      if (directory.length === 0 || DownloadQueueService.isLegacyTaskDirectory(context, directory)) {
        continue
      }
      const marker: string = `${suffix}/${tasks[index].galleryId}`
      if (directory.endsWith(marker)) {
        DownloadQueueService.downloadPublicRoot = directory.substring(0, directory.length - marker.length)
        return
      }
    }
  }

  /**
   * Per-task sidecar (mirrors NextE's metadata.json fallback): task identity
   * and status so a queue row lost from RDB can be restored from the page
   * directory. Fire-and-forget: a failed sidecar write must never break the
   * download path, because the RDB row and page files remain the recovery pair.
   */
  private static writeTaskMetadata(context: common.UIAbilityContext, task: NhDownloadTask): void {
    if (task.galleryId <= 0 || task.pageCount <= 0 || task.pageExtensions.length !== task.pageCount) {
      return
    }
    if (DownloadQueueService.isLegacyTaskDirectory(context, task.storageDirectory)) {
      return
    }
    try {
      const payload: Record<string, Object> = {
        'schema': METADATA_SCHEMA,
        'galleryId': task.galleryId,
        'mediaId': task.mediaId,
        'title': task.title,
        'thumbnailUrl': task.thumbnailUrl,
        'pageCount': task.pageCount,
        'pageExtensions': task.pageExtensions.slice(),
        'status': task.status,
        'createdAt': task.createdAt,
        'updatedAt': task.updatedAt,
      }
      DownloadQueueService.ensureTaskDirectory(context, task)
      const file: fileIo.File = fileIo.openSync(
        DownloadQueueService.metadataPath(context, task),
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      try {
        fileIo.writeSync(file.fd, JSON.stringify(payload))
      } finally {
        fileIo.closeSync(file)
      }
    } catch (_error) {
      // Sidecar failures are diagnostics only; they never interrupt downloads.
    }
  }

  /**
   * Scans the current public Download root first, then the legacy sandbox read
   * root. Each directory is parsed independently, and the containing directory
   * (not untrusted metadata text) becomes the task's storage owner.
   */
  private static loadTaskMetadataTasks(context: common.UIAbilityContext): NhDownloadTask[] {
    const out: NhDownloadTask[] = []
    const roots: string[] = []
    if (DownloadQueueService.downloadPublicRoot.length > 0) {
      roots.push(DownloadQueueService.publicDownloadRoot())
    }
    roots.push(DownloadQueueService.legacyDownloadRoot(context))
    for (let rootIndex: number = 0; rootIndex < roots.length; rootIndex++) {
      const root: string = roots[rootIndex]
      try {
        if (!fileIo.accessSync(root)) {
          continue
        }
        const names: string[] = fileIo.listFileSync(root)
        for (let index: number = 0; index < names.length; index++) {
          const directory: string = `${root}/${names[index]}`
          const path: string = `${directory}/${METADATA_FILE_NAME}`
          if (!fileIo.accessSync(path)) {
            continue
          }
          try {
            const task: NhDownloadTask | null = DownloadQueueService.parseTaskMetadata(fileIo.readTextSync(path))
            if (task !== null && !out.some(
              (existing: NhDownloadTask): boolean => existing.galleryId === task.galleryId,
            )) {
              task.storageDirectory = directory
              out.push(task)
            }
          } catch (_error) {
            // One unreadable sidecar is skipped; the scan continues.
          }
        }
      } catch (_error) {
        // A vanished root is an empty scan, not a failure.
      }
    }
    return out
  }

  /**
   * Validates one sidecar document (NextE's parse pattern: cast to the model
   * type, then guard every field with typeof so a corrupted document cannot
   * leak a malformed task into the queue).
   */
  private static parseTaskMetadata(raw: string): NhDownloadTask | null {
    let parsed: Object
    try {
      parsed = JSON.parse(raw)
    } catch (_error) {
      return null
    }
    if (typeof parsed !== 'object' || parsed === null) {
      return null
    }
    const rec: NhDownloadTask = parsed as NhDownloadTask
    const galleryId: number = typeof rec.galleryId === 'number' ? rec.galleryId : 0
    const mediaId: string = typeof rec.mediaId === 'string' ? rec.mediaId : ''
    const pageCount: number = typeof rec.pageCount === 'number' ? rec.pageCount : 0
    if (galleryId <= 0 || mediaId.length === 0 || pageCount <= 0) {
      return null
    }
    const extensions: string[] = []
    if (Array.isArray(rec.pageExtensions)) {
      rec.pageExtensions.forEach((value: string): void => {
        if (typeof value === 'string' && value.length > 0) {
          extensions.push(value)
        }
      })
    }
    if (extensions.length !== pageCount) {
      return null
    }
    const status: string = typeof rec.status === 'string' ? rec.status : NhDownloadTaskStatus.PAUSED
    const task: NhDownloadTask = new NhDownloadTask()
    task.galleryId = galleryId
    task.mediaId = mediaId
    task.title = typeof rec.title === 'string' ? rec.title : ''
    task.thumbnailUrl = typeof rec.thumbnailUrl === 'string' ? rec.thumbnailUrl : ''
    task.pageCount = pageCount
    task.pageExtensions = extensions
    task.status = DownloadQueueService.isKnownTaskStatus(status) ? status : NhDownloadTaskStatus.PAUSED
    task.createdAt = typeof rec.createdAt === 'number' ? rec.createdAt : 0
    task.updatedAt = typeof rec.updatedAt === 'number' ? rec.updatedAt : 0
    return task
  }

  private static isKnownTaskStatus(status: string): boolean {
    return status === NhDownloadTaskStatus.QUEUED || status === NhDownloadTaskStatus.DOWNLOADING ||
      status === NhDownloadTaskStatus.PAUSED || status === NhDownloadTaskStatus.COMPLETE ||
      status === NhDownloadTaskStatus.ERROR
  }

  private static pageIsComplete(context: common.UIAbilityContext, task: NhDownloadTask, pageIndex: number): boolean {
    return pageIndex >= 0 && pageIndex < task.pageExtensions.length &&
      DownloadQueueService.fileSize(DownloadQueueService.pagePath(context, task, pageIndex)) > 0
  }

  private static completedFileCount(context: common.UIAbilityContext, task: NhDownloadTask): number {
    let completed: number = 0
    for (let index: number = 0; index < task.pageCount; index++) {
      if (DownloadQueueService.pageIsComplete(context, task, index)) {
        completed += 1
      }
    }
    return completed
  }

  private static removeTaskFiles(context: common.UIAbilityContext, task: NhDownloadTask): void {
    const directories: string[] = []
    const owned: string = DownloadQueueService.taskDirectory(context, task)
    const legacy: string = DownloadQueueService.legacyTaskDirectory(context, task.galleryId)
    directories.push(owned)
    if (legacy !== owned) {
      directories.push(legacy)
    }
    for (let index: number = 0; index < directories.length; index++) {
      DownloadQueueService.removeTaskDirectory(directories[index])
    }
  }

  private static removeTaskDirectory(directory: string): void {
    try {
      if (!fileIo.accessSync(directory)) {
        return
      }
      const names: string[] = fileIo.listFileSync(directory)
      for (let index: number = 0; index < names.length; index++) {
        DownloadQueueService.removeIfExists(`${directory}/${names[index]}`)
      }
      fileIo.rmdirSync(directory)
    } catch (error) {
      throw error as Error
    }
  }

  private static removeIfExists(path: string): void {
    try {
      fileIo.unlinkSync(path)
    } catch (_error) {}
  }

  private static fileSize(path: string): number {
    try {
      return fileIo.statSync(path).size
    } catch (_error) {
      return 0
    }
  }

  private static displayUri(path: string): string {
    return path.startsWith('/') ? `file://${path}` : `file:///${path}`
  }

  private static normalizedExtension(value: string): string {
    const extension: string = value.toLowerCase().replace('.', '').trim()
    return /^[a-z0-9]{1,8}$/.test(extension) ? extension : ''
  }

  private static async delay(milliseconds: number): Promise<void> {
    await new Promise<void>((resolve: () => void): void => {
      setTimeout(resolve, milliseconds)
    })
  }
}
