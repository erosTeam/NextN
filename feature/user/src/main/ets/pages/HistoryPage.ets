import { common } from '@kit.AbilityKit'
import {
  HistoryRepository,
  HistoryCursor,
  HistoryPageResult,
  InlineRetryNotice,
  LoadingFooter,
  AppStrings,
  LayoutSafeAreaState,
  NhReadingHistoryItem,
  PageEmptyState,
  PageErrorState,
  PageLoadingState,
  NextNPullRefreshController,
  PullRefreshListScaffold,
  ReadingHistoryState,
  RootRefreshRegistry,
  ThemeTokens,
  connectLayoutSafeArea,
  connectReadingHistory,
} from 'shared'
import { HistoryGalleryCard } from '../components/HistoryGalleryCard'
import {
  HistoryPinnedDayHeaderState,
  HISTORY_PINNED_DAY_HEADER_HEIGHT,
  connectHistoryPinnedDayHeader,
} from '../components/HistoryPinnedDayHeader'

const HISTORY_PAGE_SIZE: number = 24
const HISTORY_PREFETCH_DISTANCE: number = 4

/** Stable group-local source; LazyForEach subscribes directly to its listener. */
class HistoryDayDataSource implements IDataSource {
  private items: NhReadingHistoryItem[] = []
  private listeners: DataChangeListener[] = []

  totalCount(): number {
    return this.items.length
  }

  getData(index: number): NhReadingHistoryItem {
    return this.items[index]
  }

  getAll(): NhReadingHistoryItem[] {
    return this.items
  }

  setData(items: NhReadingHistoryItem[]): void {
    this.items = items
    this.notify([{ type: DataOperationType.RELOAD }])
  }

  appendData(items: NhReadingHistoryItem[]): void {
    if (items.length === 0) {
      return
    }
    const start: number = this.items.length
    items.forEach((item: NhReadingHistoryItem): void => {
      this.items.push(item)
    })
    this.notify([{
      type: DataOperationType.ADD,
      index: start,
      count: items.length,
      key: items.map((item: NhReadingHistoryItem): string => `${item.galleryId}`),
    }])
  }

  removeGallery(galleryId: number): boolean {
    const index: number = this.items.findIndex((item: NhReadingHistoryItem): boolean =>
      item.galleryId === galleryId,
    )
    if (index < 0) {
      return false
    }
    this.items.splice(index, 1)
    this.notify([{ type: DataOperationType.DELETE, index: index, count: 1 }])
    return true
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }

  private notify(operations: DataOperation[]): void {
    this.listeners.forEach((listener: DataChangeListener): void => {
      listener.onDatasetChange(operations)
    })
  }
}

/** A local-calendar group; its rows remain ordered by the repository's open time. */
class HistoryDayGroup {
  dayStart: number
  dataSource: HistoryDayDataSource = new HistoryDayDataSource()

  constructor(dayStart: number) {
    this.dayStart = dayStart
  }
}

/**
 * Local reading history. Search and date grouping are presentation over the
 * bounded RDB cursor: neither starts a network request nor changes stored
 * resume records.
 */
@ComponentV2
export struct HistoryPage {
  @Local items: NhReadingHistoryItem[] = []
  @Local loadedDayGroups: HistoryDayGroup[] = []
  @Local query: string = ''
  // Day groups keep their numeric local-calendar identity. This value is
  // refreshed at the next local midnight so relative labels never become
  // stale while the History tab remains mounted.
  @Local currentDayStart: number = 0
  @Local isInitialLoading: boolean = false
  @Local isRefreshing: boolean = false
  @Local isLoadingMore: boolean = false
  @Local hasMore: boolean = false
  @Local matchingCount: number = 0
  @Local hasHistoryRecords: boolean = false
  @Local errorMessage: string = ''
  @Local loadMoreErrorMessage: string = ''
  @Param scroller: Scroller = new Scroller()
  @Param reloadVersion: number = 0
  @Param clearVersion: number = 0
  @Event onOpenGallery?: (galleryId: number) => void
  @Event onOpenReader?: (galleryId: number, initialPageIndex: number) => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  private layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private history: ReadingHistoryState = connectReadingHistory()
  @Local private pinnedDayHeader: HistoryPinnedDayHeaderState = connectHistoryPinnedDayHeader()
  private requestGeneration: number = 0
  private cursor: HistoryCursor | null = null
  /** A retained History tab reloads only for its first activation or a local write. */
  private historyLoaded: boolean = false
  private observedHistoryRevision: number = -1
  private isVisible: boolean = false
  private refreshController: NextNPullRefreshController = new NextNPullRefreshController()
  private dayRolloverTimer: number = -1
  // ListItemGroup rectangles are in List viewport coordinates. This is the
  // corresponding window coordinate so the HDS pin surface can be compared
  // without making an offset assumption about the immersive title bar.
  private historyListGlobalY: number = -1
  private pinnedDaySyncTimer: number = -1

  aboutToAppear(): void {
    this.isVisible = true
    RootRefreshRegistry.register(this.scroller, (): void => {
      this.resetPinnedDayHeader()
      if (this.items.length > 0) {
        this.refreshController.requestRefresh()
        return
      }
      this.scroller.scrollToIndex(0)
      this.reload(true)
    })
    this.resetPinnedDayHeader()
    this.refreshCurrentDay()
    this.scheduleCurrentDayRefresh()
    this.reloadIfHistoryChanged()
  }

  aboutToDisappear(): void {
    this.isVisible = false
    RootRefreshRegistry.unregister(this.scroller)
    if (this.dayRolloverTimer >= 0) {
      clearTimeout(this.dayRolloverTimer)
      this.dayRolloverTimer = -1
    }
    if (this.pinnedDaySyncTimer >= 0) {
      clearTimeout(this.pinnedDaySyncTimer)
      this.pinnedDaySyncTimer = -1
    }
    this.historyListGlobalY = -1
    this.resetPinnedDayHeader()
  }

  @Monitor('reloadVersion')
  onReloadRequested(): void {
    if (this.reloadVersion > 0) {
      this.reload(true)
    }
  }

  @Monitor('clearVersion')
  onClearRequested(): void {
    if (this.clearVersion > 0) {
      this.confirmClearHistory()
    }
  }

  @Monitor('history.revision')
  onHistoryRevisionChanged(): void {
    if (this.isVisible) {
      this.reloadIfHistoryChanged()
    }
  }

  @Monitor('query')
  onHistoryQueryChanged(): void {
    // A filter can replace the visible day groups synchronously. Do not let
    // the prior group's label survive while ArkUI lays out the new result set.
    this.resetPinnedDayHeader()
    this.reload(true, true)
  }

  @Monitor('items', 'errorMessage')
  onHistoryPresentationChanged(): void {
    this.schedulePinnedDaySync()
  }

  @Monitor('pinnedDayHeader.pinSurfaceTopY')
  onPinnedDaySurfaceChanged(): void {
    this.syncPinnedDayHeader()
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private isCurrentRequest(generation: number): boolean {
    return generation === this.requestGeneration
  }

  /**
   * Align with NextE's page-owned cursor model: a retained root does not
   * reconstruct local rows on every tab appearance, but a completed history
   * write is still observed before the page is shown again.
   */
  private reloadIfHistoryChanged(): void {
    const revision: number = this.history.revision
    if (this.historyLoaded && revision === this.observedHistoryRevision) {
      return
    }
    if (!this.historyLoaded && (this.isInitialLoading || this.isRefreshing)) {
      return
    }
    this.reload(true)
  }

  private async reload(force: boolean = false, resetRows: boolean = false): Promise<void> {
    if (!force && (this.isInitialLoading || this.isRefreshing)) {
      return
    }
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    const requestedHistoryRevision: number = this.history.revision
    const requestedQuery: string = this.normalizedQuery()
    this.isLoadingMore = false
    if (resetRows) {
      this.items = []
      this.loadedDayGroups = []
      this.cursor = null
      this.hasMore = false
      this.matchingCount = 0
      this.isLoadingMore = false
      this.loadMoreErrorMessage = ''
    }
    const keepsRows: boolean = this.items.length > 0
    this.isInitialLoading = !keepsRows
    this.isRefreshing = keepsRows
    this.errorMessage = ''
    this.loadMoreErrorMessage = ''
    try {
      const page: HistoryPageResult = await HistoryRepository.loadPage(
        this.context(),
        HISTORY_PAGE_SIZE,
        null,
        requestedQuery,
      )
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.items = page.items
      this.resetDayGroups(page.items)
      this.cursor = page.nextCursor
      this.hasMore = page.hasMore
      this.matchingCount = page.totalCount
      if (requestedQuery.length === 0) {
        this.hasHistoryRecords = page.totalCount > 0
      }
      this.schedulePinnedDaySync()
    } catch (error) {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.errorMessage = (error as Error).message || AppStrings.get('history_load_failed')
      this.schedulePinnedDaySync()
    } finally {
      if (this.isCurrentRequest(generation)) {
        this.isInitialLoading = false
        this.isRefreshing = false
        this.historyLoaded = true
        this.observedHistoryRevision = requestedHistoryRevision
        if (this.isVisible && this.history.revision !== requestedHistoryRevision) {
          this.reloadIfHistoryChanged()
        }
      }
    }
  }

  private async loadMore(): Promise<void> {
    if (
      this.isInitialLoading ||
      this.isRefreshing ||
      this.isLoadingMore ||
      this.loadMoreErrorMessage.length > 0 ||
      !this.hasMore ||
      this.cursor === null
    ) {
      return
    }
    const generation: number = this.requestGeneration
    const requestedQuery: string = this.normalizedQuery()
    const requestedCursor: HistoryCursor = this.cursor
    this.isLoadingMore = true
    this.loadMoreErrorMessage = ''
    try {
      const page: HistoryPageResult = await HistoryRepository.loadPage(
        this.context(),
        HISTORY_PAGE_SIZE,
        requestedCursor,
        requestedQuery,
      )
      if (!this.isCurrentRequest(generation) || requestedQuery !== this.normalizedQuery()) {
        return
      }
      const appended: NhReadingHistoryItem[] = this.dedupePage(page.items)
      if (appended.length > 0) {
        this.items = this.items.concat(appended)
        this.appendDayGroups(appended)
      }
      this.cursor = page.nextCursor
      this.hasMore = page.hasMore
      this.matchingCount = page.totalCount
      this.schedulePinnedDaySync()
    } catch (error) {
      if (this.isCurrentRequest(generation)) {
        this.loadMoreErrorMessage = (error as Error).message || AppStrings.get('history_load_failed')
      }
    } finally {
      if (this.isCurrentRequest(generation)) {
        this.isLoadingMore = false
      }
    }
  }

  /**
   * A visible pagination failure stays stable at the tail. Only the footer's
   * deliberate retry clears that failure and starts one guarded request;
   * onReachEnd and row-appearance prefetches remain passive while it is shown.
   */
  private retryLoadMore(): void {
    if (
      this.loadMoreErrorMessage.length === 0 ||
      this.isInitialLoading ||
      this.isRefreshing ||
      this.isLoadingMore ||
      !this.hasMore ||
      this.cursor === null
    ) {
      return
    }
    this.loadMoreErrorMessage = ''
    this.loadMore()
  }

  private loadMoreIfNearTail(galleryId: number): void {
    const index: number = this.items.findIndex((item: NhReadingHistoryItem): boolean =>
      item.galleryId === galleryId,
    )
    if (index >= this.items.length - HISTORY_PREFETCH_DISTANCE) {
      this.loadMore()
    }
  }

  private async removeHistory(item: NhReadingHistoryItem): Promise<void> {
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    this.isInitialLoading = false
    this.isRefreshing = false
    this.isLoadingMore = false
    this.loadMoreErrorMessage = ''
    try {
      await HistoryRepository.remove(this.context(), item.galleryId)
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.items = this.items.filter((candidate: NhReadingHistoryItem): boolean =>
        candidate.galleryId !== item.galleryId,
      )
      this.removeFromDayGroups(item.galleryId)
      this.matchingCount = Math.max(0, this.matchingCount - 1)
      if (this.normalizedQuery().length === 0) {
        this.hasHistoryRecords = this.matchingCount > 0
      }
      this.errorMessage = ''
      this.historyLoaded = true
      this.observedHistoryRevision = this.history.revision
      this.schedulePinnedDaySync()
      if (this.hasMore) {
        this.loadMore()
      }
    } catch (error) {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.errorMessage = (error as Error).message || AppStrings.get('history_remove_failed')
    }
  }

  private async clearHistory(): Promise<void> {
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    this.isInitialLoading = false
    this.isRefreshing = false
    this.isLoadingMore = false
    try {
      await HistoryRepository.clear(this.context())
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.items = []
      this.loadedDayGroups = []
      this.cursor = null
      this.hasMore = false
      this.matchingCount = 0
      this.hasHistoryRecords = false
      this.errorMessage = ''
      this.loadMoreErrorMessage = ''
      this.historyLoaded = true
      this.observedHistoryRevision = this.history.revision
      this.resetPinnedDayHeader()
    } catch (error) {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.errorMessage = (error as Error).message || AppStrings.get('history_clear_failed')
    }
  }

  private confirmRemoveHistory(item: NhReadingHistoryItem): void {
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('history_remove_title'),
      message: AppStrings.get('history_remove_message'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('history_remove_action'),
        fontColor: Color.Red,
        action: (): void => {
          this.removeHistory(item)
        },
      },
    })
  }

  private confirmClearHistory(): void {
    if (!this.hasHistoryRecords && this.items.length === 0) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('history_clear_title'),
      message: AppStrings.get('history_clear_message'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('history_clear_action'),
        fontColor: Color.Red,
        action: (): void => {
          this.clearHistory()
        },
      },
    })
  }

  private localDayStart(timestamp: number): number {
    if (timestamp <= 0) {
      return 0
    }
    const date: Date = new Date(timestamp)
    return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()
  }

  private refreshCurrentDay(): void {
    this.currentDayStart = this.localDayStart(Date.now())
    this.pinnedDayHeader.currentDayStart = this.currentDayStart
    this.syncPinnedDayHeader()
  }

  private scheduleCurrentDayRefresh(): void {
    if (this.dayRolloverTimer >= 0) {
      clearTimeout(this.dayRolloverTimer)
    }
    const now: Date = new Date()
    const nextLocalMidnight: number = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate() + 1,
    ).getTime()
    this.dayRolloverTimer = setTimeout((): void => {
      this.dayRolloverTimer = -1
      this.refreshCurrentDay()
      this.scheduleCurrentDayRefresh()
    }, Math.max(1, nextLocalMidnight - now.getTime() + 1))
  }

  private resetPinnedDayHeader(): void {
    this.pinnedDayHeader.visible = false
  }

  private schedulePinnedDaySync(): void {
    if (this.pinnedDaySyncTimer >= 0) {
      clearTimeout(this.pinnedDaySyncTimer)
    }
    this.pinnedDaySyncTimer = setTimeout((): void => {
      this.pinnedDaySyncTimer = -1
      this.syncPinnedDayHeader()
    }, 0)
  }

  private onHistoryListArea(area: Area): void {
    this.historyListGlobalY = area.globalPosition.y as number
    this.syncPinnedDayHeader()
  }

  /**
   * PullRefreshListScaffold retains the same one top reserve as its
   * SecondaryListScaffold parent. History owns one search row, then an
   * optional failure ListItem; each following day remains one ListItemGroup,
   * which is the exact unit Scroller.getItemRect() indexes according to the
   * official List contract.
   */
  private historyDayGroupStartIndex(): number {
    return 2 + (this.errorMessage.length > 0 ? 1 : 0)
  }

  /**
   * Mirrors only a group header that has actually crossed the HDS bottom
   * surface. `getItemRect` intentionally returns a zero rect for off-screen
   * items, so hidden/off-screen groups cannot become a speculative pin target.
   */
  private syncPinnedDayHeader(): void {
    const pinSurfaceTopY: number = this.pinnedDayHeader.pinSurfaceTopY
    if (pinSurfaceTopY < 0 || this.historyListGlobalY < 0) {
      this.resetPinnedDayHeader()
      return
    }
    const groups: HistoryDayGroup[] = this.dayGroups()
    if (groups.length === 0) {
      this.resetPinnedDayHeader()
      return
    }
    const pinSurfaceYInList: number = pinSurfaceTopY - this.historyListGlobalY
    const firstGroupIndex: number = this.historyDayGroupStartIndex()
    let activeGroup: HistoryDayGroup | undefined = undefined
    let activeHeaderY: number = -Infinity
    try {
      for (let index: number = 0; index < groups.length; index += 1) {
        const groupRect = this.scroller.getItemRect(firstGroupIndex + index)
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
      // Before List attachment the controller has no geometry. A hidden
      // mirror is the only correct state until the next area/scroll callback.
      this.resetPinnedDayHeader()
      return
    }
    if (activeGroup === undefined) {
      this.resetPinnedDayHeader()
      return
    }
    const currentDayStart: number = this.currentDayStart > 0
      ? this.currentDayStart
      : this.localDayStart(Date.now())
    if (this.pinnedDayHeader.dayStart !== activeGroup.dayStart) {
      this.pinnedDayHeader.dayStart = activeGroup.dayStart
    }
    if (this.pinnedDayHeader.currentDayStart !== currentDayStart) {
      this.pinnedDayHeader.currentDayStart = currentDayStart
    }
    this.pinnedDayHeader.visible = true
  }

  /** Resolve relative day text only when the header is rendered, never in RDB. */
  private dayLabel(dayStart: number): string {
    if (dayStart <= 0) {
      return AppStrings.get('history_earlier')
    }
    const currentDayStart: number = this.currentDayStart > 0
      ? this.currentDayStart
      : this.localDayStart(Date.now())
    const dayDelta: number = Math.round((currentDayStart - dayStart) / 86400000)
    if (dayDelta === 0) {
      return AppStrings.get('history_today')
    }
    if (dayDelta === 1) {
      return AppStrings.get('history_yesterday')
    }
    if (dayDelta === 2) {
      return AppStrings.get('history_day_before_yesterday')
    }
    const date: Date = new Date(dayStart)
    const year: string = `${date.getFullYear()}`
    const month: string = `${date.getMonth() + 1}`.padStart(2, '0')
    const day: string = `${date.getDate()}`.padStart(2, '0')
    return `${year}-${month}-${day}`
  }

  private normalizedQuery(): string {
    return this.query.trim().toLowerCase()
  }

  private dayGroups(): HistoryDayGroup[] {
    return this.loadedDayGroups
  }

  private resetDayGroups(items: NhReadingHistoryItem[]): void {
    const existingByDay: Map<number, HistoryDayGroup> = new Map<number, HistoryDayGroup>()
    this.loadedDayGroups.forEach((group: HistoryDayGroup): void => {
      existingByDay.set(group.dayStart, group)
    })
    const groups: HistoryDayGroup[] = []
    const rowsByDay: Map<number, NhReadingHistoryItem[]> = new Map<number, NhReadingHistoryItem[]>()
    items.forEach((item: NhReadingHistoryItem): void => {
      const dayStart: number = this.localDayStart(item.lastOpenedAt)
      let rows: NhReadingHistoryItem[] | undefined = rowsByDay.get(dayStart)
      if (rows === undefined) {
        rows = []
        rowsByDay.set(dayStart, rows)
        let group: HistoryDayGroup | undefined = existingByDay.get(dayStart)
        if (group === undefined) {
          group = new HistoryDayGroup(dayStart)
        }
        groups.push(group)
      }
      rows.push(item)
    })
    groups.forEach((group: HistoryDayGroup): void => {
      group.dataSource.setData(rowsByDay.get(group.dayStart) ?? [])
    })
    this.loadedDayGroups = groups
  }

  private appendDayGroups(items: NhReadingHistoryItem[]): void {
    if (items.length === 0) {
      return
    }
    const groups: HistoryDayGroup[] = this.loadedDayGroups.slice()
    let group: HistoryDayGroup | undefined = groups.length > 0 ? groups[groups.length - 1] : undefined
    items.forEach((item: NhReadingHistoryItem): void => {
      const dayStart: number = this.localDayStart(item.lastOpenedAt)
      if (group === undefined || group.dayStart !== dayStart) {
        group = new HistoryDayGroup(dayStart)
        groups.push(group)
      }
      group.dataSource.appendData([item])
    })
    this.loadedDayGroups = groups
  }

  private removeFromDayGroups(galleryId: number): void {
    for (let index: number = 0; index < this.loadedDayGroups.length; index += 1) {
      const group: HistoryDayGroup = this.loadedDayGroups[index]
      if (!group.dataSource.removeGallery(galleryId)) {
        continue
      }
      if (group.dataSource.totalCount() === 0) {
        const groups: HistoryDayGroup[] = this.loadedDayGroups.slice()
        groups.splice(index, 1)
        this.loadedDayGroups = groups
      }
      return
    }
  }

  private dedupePage(items: NhReadingHistoryItem[]): NhReadingHistoryItem[] {
    const loadedIds: Set<number> = new Set<number>()
    this.items.forEach((item: NhReadingHistoryItem): void => {
      loadedIds.add(item.galleryId)
    })
    const unique: NhReadingHistoryItem[] = []
    items.forEach((item: NhReadingHistoryItem): void => {
      if (item.galleryId > 0 && !loadedIds.has(item.galleryId)) {
        loadedIds.add(item.galleryId)
        unique.push(item)
      }
    })
    return unique
  }

  private filteredCountLabel(): string {
    const key: string = this.normalizedQuery().length > 0
      ? 'history_filtered_matches'
      : 'history_local_records'
    return AppStrings.get(key).replace('%d', `${this.matchingCount}`)
  }

  @Builder
  private HistoryRefreshFailureNotice() {
    InlineRetryNotice({
      message: this.errorMessage,
      onRetry: (): void => {
        this.reload(true)
      },
    })
  }

  @Builder
  private HistorySearch(insideList: boolean = false) {
    if (this.hasHistoryRecords || this.items.length > 0 || this.normalizedQuery().length > 0) {
      Column({ space: ThemeTokens.SPACE_XS }) {
        Search({ value: this.query, placeholder: AppStrings.get('history_search_placeholder') })
          .width('100%')
          .height(ThemeTokens.SEARCH_FIELD_HEIGHT)
          .backgroundColor(ThemeTokens.SURFACE)
          .onChange((value: string): void => {
            this.query = value
          })
        Text(this.filteredCountLabel())
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
      }
      .width('100%')
      .padding({
        left: insideList ? 0 : ThemeTokens.LIST_HORIZONTAL_PADDING,
        right: insideList ? 0 : ThemeTokens.LIST_HORIZONTAL_PADDING,
        top: ThemeTokens.SPACE_MD,
        bottom: ThemeTokens.SPACE_SM,
      })
    }
  }

  @Builder
  private HistoryDayHeader(group: HistoryDayGroup) {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Text(this.dayLabel(group.dayStart))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .width('100%')
      Divider()
        .strokeWidth(0.5)
        .color(ThemeTokens.DIVIDER)
    }
    .width('100%')
    .padding({
      left: ThemeTokens.SPACE_MD,
      right: ThemeTokens.SPACE_MD,
      top: ThemeTokens.SPACE_MD,
      bottom: ThemeTokens.SPACE_XS,
    })
  }

  private contentTopInset(): number {
    return this.layoutSafeArea.topAvoidHeight + ThemeTokens.TITLE_BAR_HEIGHT +
      HISTORY_PINNED_DAY_HEADER_HEIGHT
  }

  @Builder
  private HistoryEntry(item: NhReadingHistoryItem) {
    HistoryGalleryCard({
      item: item,
      onOpenGallery: (galleryId: number): void => {
        if (this.onOpenGallery) {
          this.onOpenGallery(galleryId)
        }
      },
      onResume: (galleryId: number, initialPageIndex: number): void => {
        if (this.onOpenReader) {
          this.onOpenReader(galleryId, initialPageIndex)
        } else if (this.onOpenGallery) {
          this.onOpenGallery(galleryId)
        }
      },
    })
      .gesture(
        LongPressGesture({ repeat: false, duration: 500 })
          .onAction((): void => {
            this.confirmRemoveHistory(item)
          }),
      )
  }

  /**
   * The swipe affordance deliberately invokes the same confirmation path as
   * long press. It is not a destructive shortcut and does not mutate RDB
   * before the user confirms.
   */
  @Builder
  private HistoryDeleteSwipe(item: NhReadingHistoryItem) {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(ThemeTokens.FONT_SIZE_TITLE)
          .fontColor([Color.White])
      }
      .width(ThemeTokens.MIN_TOUCH_TARGET)
      .height(ThemeTokens.MIN_TOUCH_TARGET)
      .backgroundColor(Color.Red)
      .accessibilityText(AppStrings.get('history_remove_action'))
      .onClick((): void => {
        this.confirmRemoveHistory(item)
      })
    }
    .height('100%')
    .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private HistoryDayGroups() {
    ForEach(this.dayGroups(), (group: HistoryDayGroup): void => {
      ListItemGroup({ header: this.HistoryDayHeader(group), space: 0 }) {
        LazyForEach(group.dataSource, (item: NhReadingHistoryItem): void => {
          ListItem() {
            this.HistoryEntry(item)
          }
          .swipeAction({
            end: () => {
              this.HistoryDeleteSwipe(item)
            },
          })
          .onAppear((): void => {
            this.loadMoreIfNearTail(item.galleryId)
          })
        }, (item: NhReadingHistoryItem): string => item.galleryId.toString())
      }
    }, (group: HistoryDayGroup): string => `${group.dayStart}`)
  }

  @Builder
  private HistoryLoadingFooter() {
    LoadingFooter({
      isLoading: this.isLoadingMore,
      isError: this.loadMoreErrorMessage.length > 0,
      canLoadMore: this.hasMore,
      isComplete: !this.hasMore && this.items.length > 0,
      errorMessage: this.loadMoreErrorMessage,
      onRetry: (): void => {
        this.retryLoadMore()
      },
      onLoadMore: (): void => {
        this.loadMore()
      },
    })
  }

  build() {
    Column() {
      if (this.isInitialLoading && this.items.length === 0) {
        this.HistorySearch()
        PageLoadingState({ text: AppStrings.get('history_loading') })
      } else if (this.errorMessage.length > 0 && this.items.length === 0) {
        this.HistorySearch()
        PageErrorState({
          message: this.errorMessage,
          onRetry: (): void => {
            this.reload(true)
          },
        })
      } else if (this.items.length === 0 && this.normalizedQuery().length === 0) {
        this.HistorySearch()
        PageEmptyState({ message: AppStrings.get('history_empty') })
      } else if (this.items.length === 0) {
        this.HistorySearch()
        PageEmptyState({ message: AppStrings.get('history_filter_empty') })
      } else {
        Column() {
          PullRefreshListScaffold({
            scroller: this.scroller,
            listSpace: 0,
            // The root HDS History bottomBuilder is always part of the title
            // geometry, even while its passive label is intentionally hidden.
            // Reserve it exactly once in the scrollable top spacer.
            topPadding: HISTORY_PINNED_DAY_HEADER_HEIGHT,
            bottomPadding: ThemeTokens.ROOT_FLOATING_TAB_RESERVE,
            controller: this.refreshController,
            onRefresh: async (): Promise<void> => {
              await this.reload(true)
            },
            onReachEnd: (): void => {
              this.loadMore()
            },
            onDidScroll: (offset: number, state: ScrollState): void => {
              this.syncPinnedDayHeader()
              if (this.onDidScroll) {
                this.onDidScroll(offset, state)
              }
            },
            onListAreaChange: (area: Area): void => {
              this.onHistoryListArea(area)
            },
          }) {
            ListItem() {
              this.HistorySearch(true)
            }
            if (this.errorMessage.length > 0) {
              ListItem() {
                this.HistoryRefreshFailureNotice()
              }
            }
            this.HistoryDayGroups()
            ListItem() {
              this.HistoryLoadingFooter()
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.items.length === 0
        ? this.contentTopInset()
        : 0,
    })
    .backgroundColor(ThemeTokens.SURFACE)
  }
}
