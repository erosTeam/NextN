import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import { NhGalleryDetail, NhGalleryPage } from '../model/NhGallery'
import { NhDownloadTask, NhDownloadTaskStatus } from '../model/NhDownloadTask'
import { NhApiClient } from '../network/NhApiClient'
import { DownloadQueueRepository } from '../storage/DownloadQueueRepository'
import { DownloadQueueState, connectDownloadQueue } from '../state/DownloadQueueState'
import { DownloadSettingsService } from './DownloadSettingsService'

const DOWNLOAD_DIR_NAME: string = 'nextn-downloads'
const MAX_PAGE_BYTES: number = 64 * 1024 * 1024
const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 30000

class DownloadPageOutcome {
  completed: boolean = false
  failureMessage: string = ''
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

/**
 * User-initiated, app-private gallery download queue.
 *
 * It intentionally mirrors the ErosN/NextE lifecycle: durable task metadata,
 * one gallery worker, a bounded page pool, atomic .part promotion, and a
 * cold-start transition from in-progress to paused. No public-files export,
 * background transfer, account mutation, or non-GET request is involved.
 */
export class DownloadQueueService {
  private static restoreTask: Promise<void> | null = null
  private static restored: boolean = false
  private static activeGalleryIds: Set<number> = new Set<number>()
  private static executionTokens: Map<number, number> = new Map<number, number>()

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
  }

  /** Add a verified detail snapshot to the queue, or resume the same unfinished gallery. */
  static async enqueue(context: common.UIAbilityContext, detail: NhGalleryDetail): Promise<NhDownloadTask> {
    await DownloadQueueService.restore(context)
    if (detail.id <= 0 || detail.mediaId.length === 0 || detail.pages.length === 0) {
      throw new Error('Gallery pages are unavailable for download.')
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
        throw new Error('Gallery page format is unsupported.')
      }
      extensions.push(extension)
    }
    const now: number = Date.now()
    const task: NhDownloadTask = new NhDownloadTask()
    task.galleryId = detail.id
    task.mediaId = detail.mediaId
    task.title = detail.displayTitle()
    task.thumbnailUrl = detail.thumbnailUrl.length > 0 ? detail.thumbnailUrl : detail.coverUrl
    task.pageCount = detail.pages.length
    task.pageExtensions = extensions
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
  }

  /** Reconcile already-promoted private files, then schedule the remaining page set. */
  static async resume(context: common.UIAbilityContext, galleryId: number): Promise<void> {
    await DownloadQueueService.restore(context)
    const task: NhDownloadTask | null = DownloadQueueService.task(galleryId)
    if (task === null || task.isComplete()) {
      return
    }
    task.completedPages = DownloadQueueService.completedFileCount(context, task)
    task.status = task.completedPages >= task.pageCount
      ? NhDownloadTaskStatus.COMPLETE
      : NhDownloadTaskStatus.QUEUED
    task.errorMessage = ''
    task.updatedAt = Date.now()
    DownloadQueueService.putInState(task)
    await DownloadQueueRepository.save(context, task)
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

  /** Forget one task and exactly its own app-private files. This never touches public storage. */
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
   * Supplies a complete private download to Reader without asking the API for
   * a second copy of its page manifest. A task is eligible only when every
   * promoted page is still present in this app's private files directory.
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

  /** Returns a safe display URI only for a verified, fully downloaded page. */
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
   * Provides the ordered private source files for a local-only archive export.
   * This is deliberately a pure verification read: it neither reconciles nor
   * persists task state, so a cancelled or failed share cannot mutate the
   * download queue. A caller receives no paths unless every completed page is
   * still present under this task's private directory.
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

  private static async restoreInternal(context: common.UIAbilityContext): Promise<void> {
    const restored: NhDownloadTask[] = await DownloadQueueRepository.loadAll(context)
    const writes: Promise<void>[] = []
    for (let index: number = 0; index < restored.length; index++) {
      const task: NhDownloadTask = restored[index]
      task.completedPages = DownloadQueueService.completedFileCount(context, task)
      if (task.status === NhDownloadTaskStatus.DOWNLOADING) {
        task.status = NhDownloadTaskStatus.PAUSED
        task.errorMessage = ''
      }
      DownloadQueueService.normalizeTaskState(task)
      task.updatedAt = Date.now()
      writes.push(DownloadQueueRepository.save(context, task))
    }
    DownloadQueueService.state().replace(restored)
    for (let index: number = 0; index < writes.length; index++) {
      await writes[index]
    }
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
      }
      if (failureMessage.length > 0) {
        break
      }
    }
    if (!DownloadQueueService.isExecutionActive(galleryId, token)) {
      return
    }
    const current: NhDownloadTask | null = DownloadQueueService.task(galleryId)
    if (current === null) {
      return
    }
    current.completedPages = DownloadQueueService.completedFileCount(context, current)
    current.status = current.completedPages >= current.pageCount
      ? NhDownloadTaskStatus.COMPLETE
      : NhDownloadTaskStatus.ERROR
    current.errorMessage = current.status === NhDownloadTaskStatus.ERROR
      ? (failureMessage.length > 0 ? failureMessage : 'One or more pages could not be saved.')
      : ''
    current.updatedAt = Date.now()
    await DownloadQueueService.persist(context, current)
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
        await DownloadQueueService.downloadPageOnce(context, task, pageIndex, token)
        const current: NhDownloadTask | null = DownloadQueueService.task(task.galleryId)
        if (current !== null && DownloadQueueService.isExecutionActive(task.galleryId, token)) {
          current.completedPages = DownloadQueueService.completedFileCount(context, current)
          current.updatedAt = Date.now()
          await DownloadQueueService.persist(context, current)
          outcome.completed = true
        }
        return outcome
      } catch (error) {
        lastFailure = (error as Error).message || 'Page download failed.'
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
  ): Promise<void> {
    const finalPath: string = DownloadQueueService.pagePath(context, task, pageIndex)
    const temporaryPath: string = `${finalPath}.part`
    DownloadQueueService.ensureTaskDirectory(context, task)
    DownloadQueueService.removeIfExists(temporaryPath)
    let file: fileIo.File | null = null
    let request: http.HttpRequest | null = null
    let written: number = 0
    let writeFailure: string = ''
    let promoted: boolean = false
    try {
      file = fileIo.openSync(
        temporaryPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      request = http.createHttp()
      request.on('dataReceiveProgress', (info: http.DataReceiveProgressInfo): void => {
        if (info.totalSize > MAX_PAGE_BYTES) {
          writeFailure = 'A gallery page exceeds the private download limit.'
          request?.destroy()
        }
      })
      request.on('dataReceive', (data: ArrayBuffer): void => {
        if (file === null || writeFailure.length > 0 || !DownloadQueueService.isExecutionActive(task.galleryId, token)) {
          request?.destroy()
          return
        }
        try {
          if (written + data.byteLength > MAX_PAGE_BYTES) {
            writeFailure = 'A gallery page exceeds the private download limit.'
            request?.destroy()
            return
          }
          const count: number = fileIo.writeSync(file.fd, data, { offset: written })
          if (count !== data.byteLength) {
            throw new Error('Unable to save gallery page.')
          }
          written += count
        } catch (error) {
          writeFailure = (error as Error).message || 'Unable to save gallery page.'
          request?.destroy()
        }
      })
      const status: number = await request.requestInStream(
        NhApiClient.imageUrl(task.mediaId, pageIndex, task.pageExtensions[pageIndex]),
        {
          method: http.RequestMethod.GET,
          header: {
            Accept: 'image/*',
            'User-Agent': 'NextN/1.0.0',
          },
          connectTimeout: CONNECT_TIMEOUT_MS,
          readTimeout: READ_TIMEOUT_MS,
          usingCache: false,
        },
      )
      if (!DownloadQueueService.isExecutionActive(task.galleryId, token)) {
        return
      }
      if (writeFailure.length > 0) {
        throw new Error(writeFailure)
      }
      if (status < 200 || status >= 300) {
        throw new Error(`Gallery page request failed (${status}).`)
      }
      if (written <= 0) {
        throw new Error('Gallery page response was empty.')
      }
      request.destroy()
      request = null
      fileIo.closeSync(file)
      file = null
      DownloadQueueService.removeIfExists(finalPath)
      fileIo.renameSync(temporaryPath, finalPath)
      if (DownloadQueueService.fileSize(finalPath) !== written) {
        DownloadQueueService.removeIfExists(finalPath)
        throw new Error('Saved gallery page did not verify.')
      }
      promoted = true
    } finally {
      if (request !== null) {
        request.destroy()
      }
      if (file !== null) {
        fileIo.closeSync(file)
      }
      if (!promoted) {
        DownloadQueueService.removeIfExists(temporaryPath)
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

  private static taskDirectory(context: common.UIAbilityContext, task: NhDownloadTask): string {
    return `${context.filesDir}/${DOWNLOAD_DIR_NAME}/${task.galleryId}`
  }

  private static pagePath(context: common.UIAbilityContext, task: NhDownloadTask, pageIndex: number): string {
    return `${DownloadQueueService.taskDirectory(context, task)}/${pageIndex + 1}.${task.pageExtensions[pageIndex]}`
  }

  private static ensureTaskDirectory(context: common.UIAbilityContext, task: NhDownloadTask): void {
    const directory: string = DownloadQueueService.taskDirectory(context, task)
    try {
      fileIo.mkdirSync(directory, true)
    } catch (error) {
      if (!fileIo.accessSync(directory)) {
        throw error as Error
      }
    }
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
    const directory: string = DownloadQueueService.taskDirectory(context, task)
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
