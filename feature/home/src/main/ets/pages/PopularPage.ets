import {
  AppStrings,
  ActiveKeyState,
  ContentFilterService,
  ContentFilterState,
  DiagnosticLogger,
  GalleryCollectionBody,
  HomeGallerySelectionState,
  HomeSubtabState,
  NextNPullRefreshController,
  NhApiClient,
  NhGallerySummary,
  NhTagCatalogService,
  RootRefreshRegistry,
  TagTranslationState,
  ThemeTokens,
  HOME_SOURCE_SELECTOR_HEIGHT,
  connectContentFilters,
  connectHomeGallerySelection,
  connectHomeSubtabs,
  connectTagTranslations,
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
  @Event onOpenGallery?: (galleryId: number, seed?: NhGallerySummary) => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  @Local galleries: NhGallerySummary[] = []
  /** Preserve the successful response while local display rules are toggled. */
  @Local rawGalleries: NhGallerySummary[] = []
  @Local contentFilters: ContentFilterState = connectContentFilters()
  @Local tagTranslations: TagTranslationState = connectTagTranslations()
  @Local homeGallerySelection: HomeGallerySelectionState = connectHomeGallerySelection()
  @Local homeSubtabs: HomeSubtabState = connectHomeSubtabs()
  // Retained pages mount before their first activation. Until the first
  // request settles, zero rows mean "not loaded yet", never "empty".
  @Local isInitialLoading: boolean = true
  @Local isRefreshing: boolean = false
  @Local errorMessage: string = ''
  @Param scroller: Scroller = new Scroller()
  private refreshController: NextNPullRefreshController = new NextNPullRefreshController()
  private requestGeneration: number = 0
  /** Loading presentation and request exclusion are separate state contracts. */
  private requestPending: boolean = false
  private tagTranslationRefreshEpoch: number = 0
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
      this.requestPending = false
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

  @Monitor('tagTranslations.revision')
  onTagTranslationsChanged(): void {
    this.refreshTagTranslationLabels()
  }

  private applyContentFilters(): void {
    this.galleries = ContentFilterService.filterGalleries(this.rawGalleries)
  }

  /** Re-label the retained snapshot locally after a committed dictionary change. */
  private async refreshTagTranslationLabels(): Promise<void> {
    const epoch: number = this.tagTranslationRefreshEpoch + 1
    this.tagTranslationRefreshEpoch = epoch
    const snapshot: NhGallerySummary[] = this.rawGalleries
    const relabeled: NhGallerySummary[] = await NhTagCatalogService.refreshLocalDisplayLabels(snapshot)
    if (epoch !== this.tagTranslationRefreshEpoch || snapshot !== this.rawGalleries) {
      return
    }
    this.rawGalleries = relabeled
    this.applyContentFilters()
  }

  private async loadPopular(): Promise<void> {
    if (this.requestPending) {
      return
    }
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    this.requestPending = true
    const keepsContent: boolean = this.rawGalleries.length > 0
    this.isInitialLoading = !keepsContent
    this.isRefreshing = keepsContent
    this.errorMessage = ''
    let refreshOutcome: string = 'pending'
    if (keepsContent) {
      DiagnosticLogger.info(
        'collection',
        'collection_refresh_started',
        `source=popular generation=${generation} rows=${this.rawGalleries.length}`,
      )
    }
    try {
      const tagTranslationRevision: number = this.tagTranslations.revision
      const galleries: NhGallerySummary[] = await NhApiClient.popular()
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.rawGalleries = galleries
      this.applyContentFilters()
      refreshOutcome = 'success'
      if (tagTranslationRevision !== this.tagTranslations.revision) {
        this.refreshTagTranslationLabels()
      }
    } catch (error) {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.errorMessage = (error as Error).message || AppStrings.get('popular_load_failed')
      refreshOutcome = 'error'
    } finally {
      if (this.isCurrentRequest(generation)) {
        this.requestPending = false
        this.isInitialLoading = false
        this.isRefreshing = false
        if (keepsContent) {
          DiagnosticLogger.info(
            'collection',
            'collection_refresh_settled',
            `source=popular generation=${generation} outcome=${refreshOutcome} rows=${this.rawGalleries.length}`,
          )
        }
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
        ? this.homeSubtabs.find(this.sourceKey)?.presentationOverride() ?? null
        : null,
      selectedGalleryId: this.sourceTab ? this.homeGallerySelection.selectedGalleryId : 0,
      isInitialLoading: this.isInitialLoading,
      isRefreshing: this.isRefreshing,
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
      onOpenGallery: (galleryId: number, seed?: NhGallerySummary): void => {
        if (this.onOpenGallery) {
          this.onOpenGallery(galleryId, seed)
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
