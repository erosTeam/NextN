import {
  AppStrings,
  ActiveKeyState,
  ContentFilterService,
  ContentFilterState,
  GalleryCollectionBody,
  HomeGallerySelectionState,
  HomeSourceState,
  NextNPullRefreshController,
  NhApiClient,
  NhGallerySummary,
  RootRefreshRegistry,
  ThemeTokens,
  HOME_SOURCE_SELECTOR_HEIGHT,
  connectContentFilters,
  connectHomeGallerySelection,
  connectHomeSource,
} from 'shared'

/**
 * Standalone popular-gallery destination. The HDS host owns its title and
 * Back affordance; the retained-source form additionally owns its selector
 * reserve through the shared gallery collection parent tree.
 */
@ComponentV2
export struct PopularPage {
  /** `false` keeps the existing pushed Popular route fully compatible. */
  @Param sourceTab: boolean = false
  @Param sourceKey: string = ''
  @Param active: ActiveKeyState = new ActiveKeyState()
  @Event onOpenGallery?: (galleryId: number) => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  @Local galleries: NhGallerySummary[] = []
  /** Preserve the successful response while local display rules are toggled. */
  @Local rawGalleries: NhGallerySummary[] = []
  @Local contentFilters: ContentFilterState = connectContentFilters()
  @Local homeGallerySelection: HomeGallerySelectionState = connectHomeGallerySelection()
  @Local homeSource: HomeSourceState = connectHomeSource()
  @Local isInitialLoading: boolean = false
  @Local isRefreshing: boolean = false
  @Local errorMessage: string = ''
  @Param scroller: Scroller = new Scroller()
  private refreshController: NextNPullRefreshController = new NextNPullRefreshController()
  private requestGeneration: number = 0
  /** A successful empty response is still a completed retained first load. */
  private loadedOnce: boolean = false

  aboutToAppear(): void {
    this.registerRootRefresh()
    this.ensureInitialLoad()
  }

  aboutToDisappear(): void {
    if (!this.sourceTab) {
      // A pushed standalone route is actually leaving the navigation stack.
      // Its old request must not mutate a later route instance. Retained source
      // tabs deliberately keep their generation and first-load state alive.
      this.requestGeneration += 1
      if (this.isInitialLoading && this.rawGalleries.length === 0 && this.errorMessage.length === 0) {
        this.loadedOnce = false
      }
      this.isInitialLoading = false
      this.isRefreshing = false
    }
    RootRefreshRegistry.unregister(this.scroller)
  }

  private isActive(): boolean {
    return !this.sourceTab || this.active.activeKey === this.sourceKey
  }

  private registerRootRefresh(): void {
    RootRefreshRegistry.register(this.scroller, (): void => {
      if (this.galleries.length > 0) {
        this.refreshController.requestRefresh()
        return
      }
      this.scroller.scrollToIndex(0)
      this.refresh()
    })
  }

  private ensureInitialLoad(): void {
    if (!this.isActive() || this.loadedOnce) {
      return
    }
    this.loadedOnce = true
    this.loadPopular()
  }

  @Monitor('active.activeKey')
  onActiveChange(): void {
    if (this.sourceTab && this.isActive()) {
      this.registerRootRefresh()
      this.ensureInitialLoad()
    }
  }

  private isCurrentRequest(generation: number): boolean {
    return generation === this.requestGeneration
  }

  @Monitor('contentFilters.revision')
  onContentFiltersChanged(): void {
    this.applyContentFilters()
  }

  private applyContentFilters(): void {
    this.galleries = ContentFilterService.filterGalleries(this.rawGalleries)
  }

  private async loadPopular(): Promise<void> {
    if (this.isInitialLoading || this.isRefreshing) {
      return
    }
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    const keepsContent: boolean = this.rawGalleries.length > 0
    this.isInitialLoading = !keepsContent
    this.isRefreshing = keepsContent
    this.errorMessage = ''
    try {
      const galleries: NhGallerySummary[] = await NhApiClient.popular()
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.rawGalleries = galleries
      this.applyContentFilters()
    } catch (error) {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.errorMessage = (error as Error).message || AppStrings.get('popular_load_failed')
    } finally {
      if (this.isCurrentRequest(generation)) {
        this.isInitialLoading = false
        this.isRefreshing = false
      }
    }
  }

  /** Retained rows refresh in place; an in-flight first load is never duplicated. */
  private async refresh(): Promise<void> {
    await this.loadPopular()
  }

  private sourceBottomPadding(): number {
    return this.sourceTab ? ThemeTokens.ROOT_FLOATING_TAB_RESERVE : ThemeTokens.LIST_BOTTOM_PADDING
  }

  build() {
    GalleryCollectionBody({
      galleries: this.galleries,
      // Only the retained Home source receives its own NextE-style profile
      // override. The legacy pushed route remains a global Browse consumer.
      presentationOverride: this.sourceTab
        ? this.homeSource.presentationOverrideFor(this.sourceKey)
        : null,
      selectedGalleryId: this.sourceTab ? this.homeGallerySelection.selectedGalleryId : 0,
      isInitialLoading: this.isInitialLoading,
      isLoadingMore: false,
      canLoadMore: false,
      errorMessage: this.errorMessage,
      loadingMessage: AppStrings.get('popular_loading'),
      emptyMessage: AppStrings.get('popular_empty'),
      // NextE keeps Popular's non-paginated snapshot in the same collection
      // parent and gives its fixed footer an explicit "no more" terminus.
      // Keeping that leaf visible avoids a blank footer-height tail here.
      footerCompleteText: AppStrings.get('popular_no_more'),
      topPadding: this.sourceTab ? HOME_SOURCE_SELECTOR_HEIGHT : 0,
      bottomPadding: this.sourceBottomPadding(),
      scroller: this.scroller,
      controller: this.refreshController,
      refreshEnabled: !this.isInitialLoading && !this.isRefreshing,
      onRefresh: async (): Promise<void> => {
        await this.refresh()
      },
      onRetry: (): void => {
        this.refresh()
      },
      onOpenGallery: (galleryId: number): void => {
        if (this.onOpenGallery) {
          this.onOpenGallery(galleryId)
        }
      },
      onDidScroll: (offset: number, state: ScrollState): void => {
        if (this.onDidScroll) {
          this.onDidScroll(offset, state)
        }
      },
    })
    .backgroundColor(ThemeTokens.SURFACE)
  }
}
