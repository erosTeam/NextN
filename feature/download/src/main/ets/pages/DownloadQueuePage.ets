import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import {
  DownloadQueueAction,
  DownloadQueueActionBridge,
  DownloadQueueActionState,
  DownloadBatchResult,
  NhDownloadCbzExportService,
  DownloadQueueService,
  DownloadQueueSignalState,
  DownloadQueueState,
  AppStrings,
  NhDownloadTask,
  NhDownloadTaskProjection,
  NhDownloadSortMode,
  NhDownloadTaskStatus,
  PageEmptyState,
  PageErrorState,
  PageLoadingState,
  GalleryThumbnail,
  SecondaryListScaffold,
  ThemeTokens,
  connectDownloadQueueActions,
  connectDownloadQueue,
  connectDownloadQueueSignal,
} from 'shared'
import { appMenuOptions } from 'shared'
import {
  DOWNLOAD_TITLE_SEARCH_HEIGHT,
} from '../components/DownloadTitleBar'
import {
  DownloadPinnedGroupHeaderState,
  DOWNLOAD_PINNED_GROUP_HEADER_HEIGHT,
  connectDownloadPinnedGroupHeader,
  downloadTaskGroupTitle,
} from '../components/DownloadPinnedGroupHeader'

// These mirror the local pieces of NextE's DownloadGalleryTaskCard. They stay
// page-local because the queue model deliberately contains no visual concerns.
const DOWNLOAD_TASK_PROGRESS_HEIGHT: number = 4
const DOWNLOAD_TASK_COVER_WIDTH: number = 78
const DOWNLOAD_TASK_COVER_HEIGHT: number = 110
const DOWNLOAD_TASK_CARD_PADDING: number = ThemeTokens.SPACE_SM
const DOWNLOAD_TASK_COVER_RADIUS: number = ThemeTokens.RADIUS_CARD - DOWNLOAD_TASK_CARD_PADDING
const DOWNLOAD_TASK_ACTION_SIZE: number = 32
const DOWNLOAD_TASK_ACTION_BUTTON_SIZE: number = DOWNLOAD_TASK_ACTION_SIZE - ThemeTokens.SPACE_XS

/**
 * A queued download already retains the gallery thumbnail URL captured at
 * enqueue time. Keep that visual identity local to the queue card instead of
 * issuing another gallery request just to render a cover. The cover is a
 * separate hit target: it opens the gallery while the card and inline actions
 * retain their reader and pause/resume behavior.
 */
@ComponentV2
struct DownloadTaskCover {
  @Require @Param task: NhDownloadTask
  @Event onOpenGallery?: (galleryId: number) => void

  build() {
    GalleryThumbnail({
      src: this.task.thumbnailUrl,
      widthValue: DOWNLOAD_TASK_COVER_WIDTH,
      heightValue: DOWNLOAD_TASK_COVER_HEIGHT,
      objectFit: ImageFit.Cover,
      radius: DOWNLOAD_TASK_COVER_RADIUS,
    })
      .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
      .borderRadius(DOWNLOAD_TASK_COVER_RADIUS)
      .accessibilityText(AppStrings.get('gallery_action_open'))
      .onClick((): void => {
        if (this.onOpenGallery) {
          this.onOpenGallery(this.task.galleryId)
        }
      })
  }
}

/**
 * Presentation-only failure codes. DownloadQueueService retains raw storage
 * and transport failures on its worker/task boundary; this page maps the
 * visible state to localized copy without changing queue behavior.
 */
class DownloadQueueUiErrorCode {
  static readonly LOAD_FAILED: string = 'download_queue_load_failed'
  static readonly UPDATE_FAILED: string = 'download_queue_update_failed'
  static readonly REMOVE_FAILED: string = 'download_queue_remove_failed'
  static readonly EXPORT_FAILED: string = 'download_queue_export_failed'
}

/**
 * The real fifth root: app-private downloads only appear after the queue
 * exists. It uses the same HDS grouped-list grammar as NextE's queue while
 * deliberately keeping export to one verified local CBZ share action. It does
 * not expose a remote archive lane or mutate the download worker.
 */
@ComponentV2
export struct DownloadQueuePage {
  @Local tasks: NhDownloadTask[] = []
  @Local isLoading: boolean = true
  @Local errorMessage: string = ''
  @Param scroller: Scroller = new Scroller()
  @Event onOpenGallery?: (galleryId: number) => void
  @Event onOpenReader?: (galleryId: number) => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  @Local queue: DownloadQueueState = connectDownloadQueue()
  @Local queueSignal: DownloadQueueSignalState = connectDownloadQueueSignal()
  @Local queueProjectionTick: number = 0
  @Local taskGroups: NhDownloadTask[][] = [[], [], [], []]
  /** Sort is page-local; search draft/open state lives in the HDS bridge. */
  @Local sortMode: string = NhDownloadSortMode.ADDED_DESC
  @Local sortMenuShown: boolean = false
  @Local taskActionMenuGalleryId: number = 0
  @Local exportingGalleryId: number = 0
  @Local titleActions: DownloadQueueActionState = connectDownloadQueueActions()
  @Local private pinnedGroupHeader: DownloadPinnedGroupHeaderState = connectDownloadPinnedGroupHeader()
  /**
   * EntryAbility restores the durable queue before the root tabs mount. The
   * page keeps a fallback only when no startup result exists. It observes an
   * in-flight startup restore without becoming a second storage owner. A
   * known startup failure remains in the existing error state until the user
   * explicitly retries it; mounting or re-entering this tab never retries.
   */
  private queueBootstrapResolved: boolean = false
  private queueBootstrapInFlight: boolean = false
  /** A failed first restore stays visible until the user explicitly retries it. */
  private queueBootstrapAttempted: boolean = false
  private queueBootstrapGeneration: number = 0
  /** Last queue publication projected into this page-local search/sort view. */
  private resolvedQueueRevision: number = -1
  private handledTitleActionSeq: number = 0
  private downloadListGlobalY: number = -1
  private pinnedGroupSyncTimer: number = -1

  aboutToAppear(): void {
    // Do not replay an old retained title command when this page is recreated.
    this.handledTitleActionSeq = this.titleActions.commandSeq
    this.reportVisibleEligibility()
    this.resetPinnedGroupHeader()
    this.ensureQueueForAppearance()
  }

  aboutToDisappear(): void {
    if (this.pinnedGroupSyncTimer >= 0) {
      clearTimeout(this.pinnedGroupSyncTimer)
      this.pinnedGroupSyncTimer = -1
    }
    this.downloadListGlobalY = -1
    this.taskActionMenuGalleryId = 0
    this.resetPinnedGroupHeader()
  }

  @Monitor('queueSignal.version')
  onQueueChanged(): void {
    // The signal is published after every in-memory queue replacement,
    // including per-page progress. Rebuild the retained page's local
    // projection without re-reading durable storage.
    if (!this.queueBootstrapResolved && DownloadQueueService.isRestored()) {
      this.adoptRestoredQueue()
      return
    }
    this.projectQueueSnapshot()
  }

  private ensureQueueForAppearance(): void {
    if (!this.queueBootstrapResolved && DownloadQueueService.isRestored()) {
      this.adoptRestoredQueue()
      return
    }
    if (!this.queueBootstrapAttempted) {
      if (DownloadQueueService.isBootstrapRestorePending()) {
        this.observeBootstrapRestore()
        return
      }
      if (DownloadQueueService.hasFailedBootstrapRestore()) {
        this.adoptFailedBootstrapRestore()
        return
      }
      this.bootstrapQueue()
      return
    }
    if (!this.queueBootstrapResolved) {
      return
    }
    this.reconcileQueueProjection()
    // aboutToDisappear clears the HDS mirror. Re-arm the existing geometry
    // sync without rebuilding cards or changing the ListItemGroup indexes.
    this.schedulePinnedGroupSync()
  }

  private observeBootstrapRestore(): void {
    if (this.queueBootstrapAttempted || this.queueBootstrapInFlight) {
      return
    }
    const task: Promise<void> | null = DownloadQueueService.currentBootstrapRestoreTask()
    if (task === null) {
      this.bootstrapQueue()
      return
    }
    const generation: number = this.queueBootstrapGeneration + 1
    this.queueBootstrapGeneration = generation
    this.queueBootstrapAttempted = true
    this.queueBootstrapInFlight = true
    this.isLoading = this.tasks.length === 0
    this.errorMessage = ''
    task.then(
      (): void => {
        if (generation !== this.queueBootstrapGeneration) {
          return
        }
        if (DownloadQueueService.isRestored()) {
          this.adoptRestoredQueue()
          return
        }
        this.adoptFailedBootstrapRestore()
      },
      (): void => {
        if (generation === this.queueBootstrapGeneration) {
          this.adoptFailedBootstrapRestore()
        }
      },
    )
  }

  private adoptRestoredQueue(): void {
    this.queueBootstrapAttempted = true
    this.queueBootstrapResolved = true
    this.queueBootstrapInFlight = false
    this.isLoading = false
    this.errorMessage = ''
    this.projectQueueSnapshot()
  }

  private adoptFailedBootstrapRestore(): void {
    this.queueBootstrapAttempted = true
    this.queueBootstrapResolved = false
    this.queueBootstrapInFlight = false
    this.isLoading = false
    this.resolvedQueueRevision = -1
    this.errorMessage = this.queueErrorMessage(DownloadQueueUiErrorCode.LOAD_FAILED)
  }

  private reconcileQueueProjection(): void {
    if (this.resolvedQueueRevision === this.queue.revision) {
      return
    }
    this.projectQueueSnapshot()
  }

  private projectQueueSnapshot(): void {
    // Preserve the queue's observed task identities. Stable ForEach keys then
    // keep their rows while @Trace field changes and this tick invalidate the
    // dynamic progress/status builders.
    this.tasks = this.queue.tasks.slice()
    this.resolvedQueueRevision = this.queue.revision
    this.rebuildTaskProjection()
    this.queueProjectionTick += 1
  }

  @Monitor('titleActions.searchText', 'sortMode')
  onLocalPresentationChanged(): void {
    this.rebuildTaskProjection()
  }

  @Monitor('pinnedGroupHeader.pinSurfaceTopY')
  onPinnedGroupSurfaceChanged(): void {
    this.syncPinnedGroupHeader()
  }

  @Monitor('titleActions.commandSeq')
  onTitleActionRequested(): void {
    if (this.titleActions.commandSeq <= this.handledTitleActionSeq) {
      return
    }
    this.handledTitleActionSeq = this.titleActions.commandSeq
    if (this.titleActions.command === DownloadQueueAction.TOGGLE_SEARCH) {
      this.toggleSearch()
      return
    }
    if (this.titleActions.command === DownloadQueueAction.OPEN_SORT_MENU) {
      this.sortMenuShown = true
      return
    }
    if (this.titleActions.command === DownloadQueueAction.PAUSE_VISIBLE) {
      this.applyVisibleBatch(true)
      return
    }
    if (this.titleActions.command === DownloadQueueAction.RESUME_VISIBLE) {
      this.applyVisibleBatch(false)
    }
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  /**
   * This is a bootstrap/error-retry boundary, never an appearance refresh.
   * The service already serializes cold restore; the page guard additionally
   * keeps a retained empty queue from briefly returning to PageLoadingState.
   */
  private async bootstrapQueue(): Promise<void> {
    if (this.queueBootstrapResolved || this.queueBootstrapInFlight) {
      return
    }
    const generation: number = this.queueBootstrapGeneration + 1
    this.queueBootstrapGeneration = generation
    this.queueBootstrapAttempted = true
    this.queueBootstrapInFlight = true
    this.isLoading = this.tasks.length === 0
    this.errorMessage = ''
    try {
      await DownloadQueueService.restore(this.context())
      if (generation === this.queueBootstrapGeneration) {
        this.queueBootstrapResolved = true
        this.projectQueueSnapshot()
      }
    } catch (_error) {
      if (generation === this.queueBootstrapGeneration) {
        // Only a failed bootstrap re-opens this boundary for the explicit
        // retry action. Queue revisions themselves are projection-only.
        this.queueBootstrapResolved = false
        this.resolvedQueueRevision = -1
        this.errorMessage = this.queueErrorMessage(DownloadQueueUiErrorCode.LOAD_FAILED)
      }
    } finally {
      if (generation === this.queueBootstrapGeneration) {
        this.queueBootstrapInFlight = false
        this.isLoading = false
      }
    }
  }

  /**
   * A visible error can also come from a local task action, not just durable
   * queue bootstrap. Keep its retry as a projection/error-dismissal when the
   * queue is already resolved; only an unresolved bootstrap may read storage.
   */
  private retryQueuePresentation(): void {
    if (!this.queueBootstrapResolved) {
      this.bootstrapQueue()
      return
    }
    this.errorMessage = ''
    this.reconcileQueueProjection()
    this.schedulePinnedGroupSync()
  }

  private openTaskIfComplete(task: NhDownloadTask): void {
    if (!task.isComplete()) {
      return
    }
    if (this.onOpenReader) {
      this.onOpenReader(task.galleryId)
    } else if (this.onOpenGallery) {
      this.onOpenGallery(task.galleryId)
    }
  }

  private async toggleTask(task: NhDownloadTask): Promise<void> {
    if (task.isComplete()) {
      this.openTaskIfComplete(task)
      return
    }
    this.errorMessage = ''
    try {
      if (task.status === NhDownloadTaskStatus.DOWNLOADING || task.status === NhDownloadTaskStatus.QUEUED) {
        await DownloadQueueService.pause(this.context(), task.galleryId)
      } else {
        await DownloadQueueService.resume(this.context(), task.galleryId)
      }
      this.tasks = DownloadQueueService.snapshot()
      this.rebuildTaskProjection()
    } catch (_error) {
      this.errorMessage = this.queueErrorMessage(DownloadQueueUiErrorCode.UPDATE_FAILED)
    }
  }

  /**
   * A completed task can be shared as one local CBZ. The export service only
   * reads verified private pages; this page deliberately does not refresh,
   * pause, resume, or otherwise mutate the queue around that handoff.
   */
  private async exportTask(task: NhDownloadTask): Promise<void> {
    if (!task.isComplete() || this.exportingGalleryId !== 0) {
      return
    }
    this.exportingGalleryId = task.galleryId
    this.errorMessage = ''
    try {
      const shared: boolean = await NhDownloadCbzExportService.exportAndShare(this.context(), task)
      if (!shared) {
        this.errorMessage = this.queueErrorMessage(DownloadQueueUiErrorCode.EXPORT_FAILED)
      }
    } finally {
      this.exportingGalleryId = 0
    }
  }

  private confirmRemove(task: NhDownloadTask): void {
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('download_remove_title'),
      message: AppStrings.get('download_remove_message'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('download_remove_action'),
        fontColor: Color.Red,
        action: (): void => {
          this.remove(task)
        },
      },
    })
  }

  private async remove(task: NhDownloadTask): Promise<void> {
    try {
      await DownloadQueueService.remove(this.context(), task.galleryId)
      this.tasks = DownloadQueueService.snapshot()
      this.rebuildTaskProjection()
      this.errorMessage = ''
    } catch (_error) {
      this.errorMessage = this.queueErrorMessage(DownloadQueueUiErrorCode.REMOVE_FAILED)
    }
  }

  private taskStatusLabel(task: NhDownloadTask): string {
    if (task.status === NhDownloadTaskStatus.DOWNLOADING) {
      return AppStrings.get('download_status_downloading')
    }
    if (task.status === NhDownloadTaskStatus.PAUSED) {
      return AppStrings.get('download_status_paused')
    }
    if (task.status === NhDownloadTaskStatus.COMPLETE) {
      return AppStrings.get('download_status_complete')
    }
    if (task.status === NhDownloadTaskStatus.ERROR) {
      return AppStrings.get('download_status_error')
    }
    return AppStrings.get('download_status_queued')
  }

  private rebuildTaskProjection(): void {
    this.taskGroups = NhDownloadTaskProjection.build(
      this.tasks,
      this.titleActions.searchText,
      this.sortMode,
    ).groups
    this.reportVisibleEligibility()
    this.schedulePinnedGroupSync()
  }

  /**
   * The title bar cannot inspect query/sort state. Flatten this local
   * projection so bulk commands affect precisely what the user can see.
   */
  private visibleTasks(): NhDownloadTask[] {
    const visible: NhDownloadTask[] = []
    for (let group: number = 0; group < this.taskGroups.length; group += 1) {
      for (let index: number = 0; index < this.taskGroups[group].length; index += 1) {
        visible.push(this.taskGroups[group][index])
      }
    }
    return visible
  }

  private visiblePausableIds(): number[] {
    return this.visibleTasks()
      .filter((task: NhDownloadTask): boolean => {
        return task.status === NhDownloadTaskStatus.DOWNLOADING || task.status === NhDownloadTaskStatus.QUEUED
      })
      .map((task: NhDownloadTask): number => task.galleryId)
  }

  private visibleResumableIds(): number[] {
    return this.visibleTasks()
      .filter((task: NhDownloadTask): boolean => {
        return task.status === NhDownloadTaskStatus.PAUSED || task.status === NhDownloadTaskStatus.ERROR
      })
      .map((task: NhDownloadTask): number => task.galleryId)
  }

  private reportVisibleEligibility(): void {
    DownloadQueueActionBridge.reportVisibleEligibility(
      this.visiblePausableIds().length,
      this.visibleResumableIds().length,
    )
  }

  private async applyVisibleBatch(pause: boolean): Promise<void> {
    const galleryIds: number[] = pause ? this.visiblePausableIds() : this.visibleResumableIds()
    if (galleryIds.length === 0) {
      this.reportVisibleEligibility()
      return
    }
    this.errorMessage = ''
    const result: DownloadBatchResult = pause
      ? await DownloadQueueService.pauseVisible(this.context(), galleryIds)
      : await DownloadQueueService.resumeVisible(this.context(), galleryIds)
    // Every successful mutation is already durable. Always reconcile the
    // projection before presenting the aggregate outcome, including partials.
    this.tasks = DownloadQueueService.snapshot()
    this.rebuildTaskProjection()
    if (result.failedCount === 0) {
      return
    }
    const message: string = this.batchOutcomeMessage(result)
    if (result.hasPartialSuccess()) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: message })
      } catch (_error) {
        // Keep the same localized aggregate result visible if the transient
        // system toast surface is unavailable.
        this.errorMessage = message
      }
    } else {
      this.errorMessage = message
    }
  }

  private batchOutcomeMessage(result: DownloadBatchResult): string {
    if (result.hasPartialSuccess()) {
      return AppStrings.get('download_batch_partial')
        .replace('%1$d', `${result.succeededCount}`)
        .replace('%2$d', `${result.requestedCount}`)
        .replace('%3$d', `${result.failedCount}`)
    }
    return AppStrings.get('download_batch_failed')
      .replace('%1$d', `${result.failedCount}`)
  }

  private toggleSearch(): void {
    this.titleActions.searchActive = !this.titleActions.searchActive
    if (!this.titleActions.searchActive) {
      this.titleActions.searchText = ''
    }
  }

  private hasActiveSearch(): boolean {
    return this.titleActions.searchText.trim().length > 0
  }

  private visibleTaskCount(): number {
    let count: number = 0
    for (let group: number = 0; group < this.taskGroups.length; group += 1) {
      count += this.taskGroups[group].length
    }
    return count
  }

  /** Preserve the page's established list offset beneath the active search slot. */
  private searchFieldReserve(): number {
    return this.titleActions.searchActive
      ? DOWNLOAD_TITLE_SEARCH_HEIGHT
      : 0
  }

  private setSortMode(sortMode: string): void {
    this.sortMode = sortMode
    this.sortMenuShown = false
  }

  private taskGroupTitle(group: number): string {
    return downloadTaskGroupTitle(group)
  }

  private visibleGroupIndexes(): number[] {
    const visible: number[] = []
    for (let group: number = 0; group < NhDownloadTaskProjection.GROUP_COUNT; group += 1) {
      if (this.taskGroups[group].length > 0) {
        visible.push(group)
      }
    }
    return visible
  }

  private resetPinnedGroupHeader(): void {
    this.pinnedGroupHeader.visible = false
  }

  private schedulePinnedGroupSync(): void {
    if (this.pinnedGroupSyncTimer >= 0) {
      clearTimeout(this.pinnedGroupSyncTimer)
    }
    this.pinnedGroupSyncTimer = setTimeout((): void => {
      this.pinnedGroupSyncTimer = -1
      this.syncPinnedGroupHeader()
    }, 0)
  }

  private onDownloadListArea(area: Area): void {
    this.downloadListGlobalY = area.globalPosition.y as number
    this.syncPinnedGroupHeader()
  }

  /**
   * Each nonempty lifecycle projection is one ListItemGroup after the scaffold
   * spacer. Mirror only a measured group whose header has crossed the HDS
   * surface; off-screen zero rects are never treated as active context.
   */
  private syncPinnedGroupHeader(): void {
    if (this.downloadListGlobalY < 0) {
      this.resetPinnedGroupHeader()
      return
    }
    // With search closed there is intentionally no zero-height title builder.
    // Its former global Y was the list's own top boundary, so use that stable
    // boundary directly for group crossing instead of depending on an
    // invisible HDS component to publish geometry.
    const pinSurfaceTopY: number = this.titleActions.searchActive
      ? this.pinnedGroupHeader.pinSurfaceTopY
      : this.downloadListGlobalY
    if (pinSurfaceTopY < 0) {
      this.resetPinnedGroupHeader()
      return
    }
    const groups: number[] = this.visibleGroupIndexes()
    if (groups.length === 0) {
      this.resetPinnedGroupHeader()
      return
    }
    const pinSurfaceYInList: number = pinSurfaceTopY - this.downloadListGlobalY
    let activeGroup: number = -1
    let activeHeaderY: number = -Infinity
    try {
      for (let index: number = 0; index < groups.length; index += 1) {
        const groupRect = this.scroller.getItemRect(1 + index)
        if (
          groupRect.height > 0 &&
          groupRect.y < pinSurfaceYInList &&
          groupRect.y > activeHeaderY
        ) {
          activeGroup = groups[index]
          activeHeaderY = groupRect.y
        }
      }
    } catch (_error) {
      this.resetPinnedGroupHeader()
      return
    }
    if (activeGroup < 0) {
      this.resetPinnedGroupHeader()
      return
    }
    this.pinnedGroupHeader.group = activeGroup
    this.pinnedGroupHeader.count = this.taskGroups[activeGroup].length
    this.pinnedGroupHeader.visible = true
  }

  private taskSubtitle(task: NhDownloadTask): string {
    const detail: string = AppStrings.get('download_task_subtitle')
      .replace('%1$s', task.progressText())
      .replace('%2$s', this.taskStatusLabel(task))
    const failure: string = task.errorMessage.length > 0
      ? this.queueErrorMessage(DownloadQueueUiErrorCode.UPDATE_FAILED)
      : ''
    return failure.length > 0 ? `${detail} · ${failure}` : detail
  }

  private taskStatusText(task: NhDownloadTask): string {
    if (this.queueProjectionTick < 0) {
      return ''
    }
    const status: string = this.taskStatusLabel(task)
    if (task.errorMessage.length === 0) {
      return status
    }
    return `${status} · ${this.queueErrorMessage(DownloadQueueUiErrorCode.UPDATE_FAILED)}`
  }

  private taskProgressText(task: NhDownloadTask): string {
    if (this.queueProjectionTick < 0) {
      return ''
    }
    return task.pageCount > 0 ? task.progressText() : ''
  }

  private taskProgressPercent(task: NhDownloadTask): number {
    if (this.queueProjectionTick < 0) {
      return 0
    }
    if (task.pageCount <= 0) {
      return 0
    }
    const percent: number = task.completedPages * 100 / task.pageCount
    return Math.min(100, Math.max(0, percent))
  }

  private shouldShowTaskProgress(task: NhDownloadTask): boolean {
    if (this.queueProjectionTick < 0) {
      return false
    }
    return task.pageCount > 0 &&
      task.status !== NhDownloadTaskStatus.COMPLETE &&
      task.status !== NhDownloadTaskStatus.ERROR
  }

  private taskStatusColor(task: NhDownloadTask): ResourceColor {
    if (task.status === NhDownloadTaskStatus.ERROR || task.errorMessage.length > 0) {
      return Color.Red
    }
    return ThemeTokens.TEXT_PRIMARY
  }

  private taskActionIcon(task: NhDownloadTask): Resource {
    if (task.status === NhDownloadTaskStatus.DOWNLOADING || task.status === NhDownloadTaskStatus.QUEUED) {
      return $r('sys.symbol.pause')
    }
    return $r('sys.symbol.play_fill')
  }

  private queueErrorMessage(errorCode: string): string {
    switch (errorCode) {
      case DownloadQueueUiErrorCode.LOAD_FAILED:
        return AppStrings.get('download_error_load')
      case DownloadQueueUiErrorCode.REMOVE_FAILED:
        return AppStrings.get('download_error_remove')
      case DownloadQueueUiErrorCode.EXPORT_FAILED:
        return AppStrings.get('download_error_export')
      case DownloadQueueUiErrorCode.UPDATE_FAILED:
      default:
        return AppStrings.get('download_error_update')
    }
  }

  private taskActionLabel(task: NhDownloadTask): string {
    if (task.status === NhDownloadTaskStatus.ERROR) {
      return AppStrings.get('common_retry')
    }
    if (task.status === NhDownloadTaskStatus.DOWNLOADING || task.status === NhDownloadTaskStatus.QUEUED) {
      return AppStrings.get('download_action_pause')
    }
    return AppStrings.get('download_action_resume')
  }

  private taskExportLabel(task: NhDownloadTask): string {
    return this.exportingGalleryId === task.galleryId
      ? AppStrings.get('download_action_exporting')
      : AppStrings.get('download_action_export_cbz')
  }

  private taskAccessibilityLabel(task: NhDownloadTask): string {
    return AppStrings.get('download_task_accessibility')
      .replace('%1$s', task.title)
      .replace('%2$s', this.taskSubtitle(task))
  }

  @Builder
  private TaskActionButton(task: NhDownloadTask) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(this.taskActionIcon(task))
        .fontSize(ThemeTokens.FONT_SIZE_TITLE)
        .fontColor([ThemeTokens.BRAND])
    }
      .width(DOWNLOAD_TASK_ACTION_BUTTON_SIZE)
      .height(DOWNLOAD_TASK_ACTION_BUTTON_SIZE)
      .backgroundColor(Color.Transparent)
      .accessibilityText(this.taskActionLabel(task))
      .onClick((): void => {
        this.toggleTask(task)
      })
  }

  @Builder
  private TaskMetaLine(task: NhDownloadTask) {
    if (this.taskProgressText(task).length > 0) {
      Text(this.taskProgressText(task))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
  }

  @Builder
  private TaskStatusText(task: NhDownloadTask) {
    Text(this.taskStatusText(task))
      .fontSize(ThemeTokens.FONT_SIZE_META)
      .fontColor(this.taskStatusColor(task))
      .fontWeight(FontWeight.Medium)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
  }

  @Builder
  private TaskProgressBar(task: NhDownloadTask) {
    Progress({
      value: this.taskProgressPercent(task),
      total: 100,
      type: ProgressType.Linear,
    })
      .width('100%')
      .style({
        strokeWidth: DOWNLOAD_TASK_PROGRESS_HEIGHT,
        strokeRadius: DOWNLOAD_TASK_PROGRESS_HEIGHT / 2,
        enableSmoothEffect: true,
      })
      .color(ThemeTokens.BRAND)
      .backgroundColor(ThemeTokens.BRAND_CONTAINER)
  }

  @Builder
  private TaskPrimaryAction(task: NhDownloadTask) {
    if (!task.isComplete()) {
      this.TaskActionButton(task)
    }
  }

  private activeTaskActionMenuTask(): NhDownloadTask | null {
    for (let index: number = 0; index < this.tasks.length; index += 1) {
      if (this.tasks[index].galleryId === this.taskActionMenuGalleryId) {
        return this.tasks[index]
      }
    }
    return null
  }

  private activeTaskCanExport(): boolean {
    const task: NhDownloadTask | null = this.activeTaskActionMenuTask()
    return task !== null && task.isComplete()
  }

  private activeTaskExportLabel(): string {
    const task: NhDownloadTask | null = this.activeTaskActionMenuTask()
    return task === null ? AppStrings.get('download_action_export_cbz') : this.taskExportLabel(task)
  }

  private closeTaskActionMenu(): void {
    this.taskActionMenuGalleryId = 0
  }

  private exportActiveTask(): void {
    const task: NhDownloadTask | null = this.activeTaskActionMenuTask()
    this.closeTaskActionMenu()
    if (task !== null) {
      this.exportTask(task)
    }
  }

  private confirmRemoveActiveTask(): void {
    const task: NhDownloadTask | null = this.activeTaskActionMenuTask()
    this.closeTaskActionMenu()
    if (task !== null) {
      this.confirmRemove(task)
    }
  }

  @Builder
  private TaskActionMenu() {
    Menu() {
      if (this.activeTaskCanExport()) {
        MenuItem({ content: this.activeTaskExportLabel() })
          .onClick((): void => {
            this.exportActiveTask()
          })
      }
      if (this.activeTaskActionMenuTask() !== null) {
        MenuItem({ content: AppStrings.get('download_remove_action') })
          .onClick((): void => {
            this.confirmRemoveActiveTask()
          })
      }
    }
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
  }

  @Builder
  private TaskMoreButton(task: NhDownloadTask) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
        .fontSize(ThemeTokens.FONT_SIZE_TITLE)
        .fontColor([ThemeTokens.TEXT_SECONDARY])
    }
      .width(DOWNLOAD_TASK_ACTION_BUTTON_SIZE)
      .height(DOWNLOAD_TASK_ACTION_BUTTON_SIZE)
      .backgroundColor(Color.Transparent)
      .accessibilityText(AppStrings.get('download_action_more'))
      .onClick((): void => {
        this.taskActionMenuGalleryId = task.galleryId
      })
      .bindMenu(this.taskActionMenuGalleryId === task.galleryId, this.TaskActionMenu, appMenuOptions({
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          if (this.taskActionMenuGalleryId === task.galleryId) {
            this.closeTaskActionMenu()
          }
        },
      }))
  }

  @Builder
  private TaskInlineActionColumn(task: NhDownloadTask) {
    Column({ space: ThemeTokens.SPACE_XS }) {
      this.TaskPrimaryAction(task)
      this.TaskMoreButton(task)
    }
    .width(DOWNLOAD_TASK_ACTION_SIZE)
    .height('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private QueueRow(task: NhDownloadTask) {
    Row({ space: ThemeTokens.SPACE_MD }) {
      DownloadTaskCover({
        task: task,
        onOpenGallery: (galleryId: number): void => {
          if (this.onOpenGallery) {
            this.onOpenGallery(galleryId)
          }
        },
      })

      Column({ space: ThemeTokens.SPACE_XS }) {
        Text(task.title.length > 0 ? task.title : `#${task.galleryId}`)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row({ space: ThemeTokens.SPACE_XS }) {
          Column({ space: ThemeTokens.SPACE_XS }) {
            this.TaskMetaLine(task)
            if (this.shouldShowTaskProgress(task)) {
              this.TaskProgressBar(task)
            }
            this.TaskStatusText(task)
          }
          .layoutWeight(1)
          .height('100%')
          this.TaskInlineActionColumn(task)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
        .height(0)
        .layoutWeight(1)
      }
      .layoutWeight(1)
      .height(DOWNLOAD_TASK_COVER_HEIGHT)
      .justifyContent(FlexAlign.Start)
      .accessibilityText(this.taskAccessibilityLabel(task))
      .onClick((): void => {
        this.openTaskIfComplete(task)
      })
    }
    .width('100%')
    .padding({
      left: DOWNLOAD_TASK_CARD_PADDING,
      right: DOWNLOAD_TASK_CARD_PADDING,
      top: DOWNLOAD_TASK_CARD_PADDING,
      bottom: DOWNLOAD_TASK_CARD_PADDING,
    })
    .borderRadius(ThemeTokens.RADIUS_CARD)
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
    .alignItems(VerticalAlign.Top)
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction((): void => {
          this.confirmRemove(task)
        }),
    )
  }

  @Builder
  private QueueGroupHeader(group: number) {
    Row({ space: ThemeTokens.SPACE_XS }) {
        Text(this.taskGroupTitle(group))
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontColor(ThemeTokens.BRAND)
          .fontWeight(FontWeight.Medium)
        Text(`${this.taskGroups[group].length}`)
          .fontSize(ThemeTokens.FONT_SIZE_TINY)
          .fontColor(ThemeTokens.TEXT_ON_BRAND)
          .fontWeight(FontWeight.Medium)
          .padding({
            left: ThemeTokens.SPACE_XS,
            right: ThemeTokens.SPACE_XS,
            top: ThemeTokens.SPACE_XS / 2,
            bottom: ThemeTokens.SPACE_XS / 2,
          })
          .borderRadius(ThemeTokens.RADIUS_ROUND)
          .backgroundColor(ThemeTokens.BRAND)
    }
    .width('100%')
    .height(DOWNLOAD_PINNED_GROUP_HEADER_HEIGHT)
    .padding({ left: ThemeTokens.SPACE_SM, right: ThemeTokens.SPACE_SM })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private QueueGroup(group: number) {
    ListItemGroup({ header: this.QueueGroupHeader(group), space: ThemeTokens.SPACE_SM - 2 }) {
      ForEach(this.taskGroups[group], (task: NhDownloadTask): void => {
        ListItem() {
          this.QueueRow(task)
        }
        .clip(false)
      }, (task: NhDownloadTask): string => task.galleryId.toString())
    }
    .clip(false)
  }

  @Builder
  private QueueList() {
    SecondaryListScaffold({
      scroller: this.scroller,
      listSpace: 0,
      topPadding: this.titleActions.searchActive
        ? this.searchFieldReserve() + ThemeTokens.SPACE_SM
        : 0,
      bottomPadding: ThemeTokens.ROOT_FLOATING_TAB_RESERVE,
      onDidScroll: (offset: number, state: ScrollState): void => {
        this.syncPinnedGroupHeader()
        if (this.onDidScroll) {
          this.onDidScroll(offset, state)
        }
      },
      onListAreaChange: (area: Area): void => {
        this.onDownloadListArea(area)
      },
    }) {
      if (this.hasActiveSearch() && this.visibleTaskCount() === 0) {
        ListItem() {
          PageEmptyState({ message: AppStrings.get('download_search_empty') })
        }
      } else {
        ForEach([0, 1, 2, 3], (group: number): void => {
          if (this.taskGroups[group].length > 0) {
            this.QueueGroup(group)
          }
        }, (group: number): string => group.toString())
      }
      if (this.errorMessage.length > 0) {
        ListItem() {
          PageErrorState({
            message: this.errorMessage,
            onRetry: (): void => {
              this.retryQueuePresentation()
            },
          })
        }
      }
    }
  }

  @Builder
  private SortMenu() {
    Menu() {
      MenuItem({
        content: AppStrings.get('download_sort_added_desc'),
        symbolEndIcon: this.sortMode === NhDownloadSortMode.ADDED_DESC
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      })
        .onClick((): void => {
          this.setSortMode(NhDownloadSortMode.ADDED_DESC)
        })
      MenuItem({
        content: AppStrings.get('download_sort_added_asc'),
        symbolEndIcon: this.sortMode === NhDownloadSortMode.ADDED_ASC
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      })
        .onClick((): void => {
          this.setSortMode(NhDownloadSortMode.ADDED_ASC)
        })
      MenuItem({
        content: AppStrings.get('download_sort_title_asc'),
        symbolEndIcon: this.sortMode === NhDownloadSortMode.TITLE_ASC
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      })
        .onClick((): void => {
          this.setSortMode(NhDownloadSortMode.TITLE_ASC)
        })
      MenuItem({
        content: AppStrings.get('download_sort_title_desc'),
        symbolEndIcon: this.sortMode === NhDownloadSortMode.TITLE_DESC
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      })
        .onClick((): void => {
          this.setSortMode(NhDownloadSortMode.TITLE_DESC)
        })
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        if (this.isLoading && this.tasks.length === 0) {
          PageLoadingState({ text: AppStrings.get('download_loading') })
        } else if (this.errorMessage.length > 0 && this.tasks.length === 0) {
          PageErrorState({
            message: this.errorMessage,
            onRetry: (): void => {
              this.retryQueuePresentation()
            },
          })
        } else if (this.tasks.length === 0) {
          PageEmptyState({ message: AppStrings.get('download_empty') })
        } else {
          this.QueueList()
        }
      }
      .width('100%')
      .height('100%')
      // The page owns the native sort menu and only opens it when the root
      // HDS action bridge requests the command.
      Row()
        .width(1)
        .height(1)
        .hitTestBehavior(HitTestMode.None)
        .bindMenu(this.sortMenuShown, this.SortMenu, appMenuOptions({
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.sortMenuShown = false
          },
        }))
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE)
  }
}
