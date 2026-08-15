import {
  ContentFilterService,
  ContentFilterState,
  FavoriteMutationState,
  FavoritesAction,
  FavoritesActionBridge,
  FavoritesActionState,
  GalleryCollectionBody,
  AccountSessionState,
  AppStrings,
  NhApiClient,
  NhGalleryPageResult,
  NhGallerySummary,
  NhTagCatalogService,
  PageEmptyState,
  PageErrorState,
  PageLoadingState,
  NextNPullRefreshController,
  RootRefreshRegistry,
  ThemeTokens,
  connectContentFilters,
  connectFavoriteMutations,
  connectFavoritesActions,
  connectAccountSession,
  connectLayoutSafeArea,
  connectTagTranslations,
  LayoutSafeAreaState,
  TagTranslationState,
} from 'shared'

/**
 * Read-only favourites root. This follows NextE's cover-grid shell but keeps
 * its session boundary explicit: only a restored local ArkWeb session may
 * start the fixed authenticated GET request.
 */
@ComponentV2
export struct FavoritesPage {
  @Local galleries: NhGallerySummary[] = []
  /** Keep the authenticated GET snapshot separate from local presentation rules. */
  @Local rawGalleries: NhGallerySummary[] = []
  @Local contentFilters: ContentFilterState = connectContentFilters()
  @Local tagTranslations: TagTranslationState = connectTagTranslations()
  @Local accountSession: AccountSessionState = connectAccountSession()
  @Local favoriteMutations: FavoriteMutationState = connectFavoriteMutations()
  @Local titleActions: FavoritesActionState = connectFavoritesActions()
  @Local searchActive: boolean = false
  @Local searchQuery: string = ''
  @Local activeQuery: string = ''
  @Local signedIn: boolean = false
  @Local isResolvingSessionState: boolean = true
  @Local isInitialLoading: boolean = false
  @Local isRefreshing: boolean = false
  @Local isLoadingMore: boolean = false
  @Local errorMessage: string = ''
  @Local loadMoreErrorMessage: string = ''
  @Local currentPage: number = 0
  @Local totalPages: number = 1
  @Param scroller: Scroller = new Scroller()
  @Param reloadVersion: number = 0
  @Event onOpenGallery?: (galleryId: number, seed?: NhGallerySummary) => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  private layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  private requestGeneration: number = 0
  private tagTranslationRefreshEpoch: number = 0
  private sessionProjectionGeneration: number = 0
  private isVisible: boolean = false
  private pendingFavoriteMutationRefresh: boolean = false
  private handledFavoriteMutationRevision: number = 0
  private handledTitleActionSeq: number = 0
  /** Published account state is a real gate, never a retained-tab appearance effect. */
  private sessionStateApplied: boolean = false
  private appliedAccountSessionRevision: number = -1
  /** One retained interactive-refresh owner across every Favorites density branch. */
  private refreshController: NextNPullRefreshController = new NextNPullRefreshController()

  aboutToAppear(): void {
    this.isVisible = true
    this.handledTitleActionSeq = this.titleActions.commandSeq
    this.reportTitleActions()
    RootRefreshRegistry.register(this.scroller, (): void => {
      // The mounted collection owns the visible programmatic pull. State-only
      // branches retain their prior direct retry path until a collection is mounted.
      if (this.galleries.length > 0) {
        this.refreshController.requestRefresh()
        return
      }
      this.scroller.scrollToIndex(0)
      this.refresh()
    })
    // A mutation that completed while this retained tab was hidden keeps the
    // retained rows in place while the normal authenticated page read
    // reconciles the optimistic projection.
    this.consumeFavoriteMutationRevision()
    this.applyPublishedAccountSession()
    this.refreshForFavoriteMutationIfVisible()
  }

  aboutToDisappear(): void {
    this.isVisible = false
    RootRefreshRegistry.unregister(this.scroller)
  }

  @Monitor('reloadVersion')
  onReloadRequested(): void {
    if (this.reloadVersion > 0) {
      this.refresh()
    }
  }

  @Monitor('contentFilters.revision')
  onContentFiltersChanged(): void {
    this.applyContentFilters()
  }

  @Monitor('tagTranslations.revision')
  onTagTranslationsChanged(): void {
    this.refreshTagTranslationLabels()
  }

  @Monitor('accountSession.revision')
  onAccountSessionChanged(): void {
    if (this.accountSession.revision === this.appliedAccountSessionRevision && this.sessionStateApplied) {
      return
    }
    // The HDS is outside this retained page. Withdraw remote-only commands
    // before a visible or hidden account revision can expose stale actions.
    this.reportTitleActions()
    if (this.isVisible) {
      this.applyPublishedAccountSession()
    }
  }

  @Monitor('favoriteMutations.revision')
  onFavoriteMutationChanged(): void {
    if (!this.consumeFavoriteMutationRevision()) {
      return
    }
    this.refreshForFavoriteMutationIfVisible()
  }

  private consumeFavoriteMutationRevision(): boolean {
    const revision: number = this.favoriteMutations.revision
    if (revision <= this.handledFavoriteMutationRevision) {
      return false
    }
    this.handledFavoriteMutationRevision = revision
    this.applyConfirmedFavoriteMutation()
    this.pendingFavoriteMutationRefresh = true
    return true
  }

  /** Remove a confirmed unfavourite immediately; additions need server data. */
  private applyConfirmedFavoriteMutation(): void {
    const galleryId: number = this.favoriteMutations.galleryId
    if (galleryId <= 0 || this.favoriteMutations.isFavorited) {
      return
    }
    this.rawGalleries = this.rawGalleries.filter((gallery: NhGallerySummary): boolean => gallery.id !== galleryId)
    this.applyContentFilters()
  }

  @Monitor('titleActions.commandSeq')
  onTitleActionRequested(): void {
    if (this.titleActions.commandSeq <= this.handledTitleActionSeq) {
      return
    }
    this.handledTitleActionSeq = this.titleActions.commandSeq
    if (this.titleActions.command === FavoritesAction.TOGGLE_SEARCH && this.canUseTitleActions()) {
      this.toggleSearch()
    }
  }

  private toggleSearch(): void {
    if (!this.canUseTitleActions()) {
      this.reportTitleActions()
      return
    }
    this.searchActive = !this.searchActive
    if (!this.searchActive) {
      const hadSubmittedQuery: boolean = this.activeQuery.length > 0
      this.searchQuery = ''
      this.activeQuery = ''
      if (hadSubmittedQuery && this.signedIn) {
        this.scroller.scrollToIndex(0)
        this.loadFirstPage(false)
      }
    }
    this.reportTitleActions()
  }

  /** HDS actions exist only after Entry's published session state has settled. */
  private canUseTitleActions(): boolean {
    return this.sessionStateApplied && this.signedIn && !this.isResolvingSessionState &&
      this.appliedAccountSessionRevision === this.accountSession.revision
  }

  private reportTitleActions(): void {
    const available: boolean = this.canUseTitleActions()
    FavoritesActionBridge.reportActionsAvailable(available)
    FavoritesActionBridge.reportSearchActive(available && this.searchActive)
  }

  private submitSearch(value: string): void {
    const normalized: string = value.trim()
    this.searchQuery = normalized
    this.activeQuery = normalized
    this.scroller.scrollToIndex(0)
    if (this.signedIn) {
      this.loadFirstPage(false)
    }
  }

  private hasActiveSearch(): boolean {
    return this.activeQuery.length > 0
  }

  private searchFieldReserve(): number {
    return this.searchActive ? ThemeTokens.SEARCH_FIELD_HEIGHT + ThemeTokens.SPACE_SM : 0
  }

  /**
   * A retained tab has no direct access to the mutation route. Re-enter the
   * existing authenticated read flow once. The typed mutation is
   * projected immediately, while this reconcile retains usable rows and all
   * existing generation, search, 401, and signed-out guards.
   */
  private refreshForFavoriteMutationIfVisible(): void {
    if (!this.isVisible || !this.pendingFavoriteMutationRefresh) {
      return
    }
    if (!this.sessionStateApplied || !this.signedIn || this.isResolvingSessionState ||
      this.appliedAccountSessionRevision !== this.accountSession.revision) {
      return
    }
    this.pendingFavoriteMutationRefresh = false
    this.refresh()
  }

  private applyContentFilters(): void {
    this.galleries = ContentFilterService.filterGalleries(this.rawGalleries)
  }

  /** Re-label the retained authenticated snapshot without repeating its account GET. */
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

  /**
   * Entry owns durable recovery. This retained page only projects the latest
   * published state and starts its own authenticated page-one request once.
   */
  private applyPublishedAccountSession(): void {
    const revision: number = this.accountSession.revision
    if (this.sessionStateApplied && revision === this.appliedAccountSessionRevision) {
      return
    }
    const generation: number = this.sessionProjectionGeneration + 1
    this.sessionProjectionGeneration = generation
    this.isResolvingSessionState = true
    this.reportTitleActions()
    if (!this.accountSession.initialized) {
      this.sessionStateApplied = false
      this.signedIn = false
      return
    }
    this.sessionStateApplied = true
    this.appliedAccountSessionRevision = revision
    this.signedIn = this.accountSession.signedIn
    if (!this.signedIn) {
      this.resetForSignedOut()
      if (generation === this.sessionProjectionGeneration) {
        this.isResolvingSessionState = false
        this.reportTitleActions()
      }
      return
    }
    this.loadPublishedAccountPage(generation)
  }

  private async loadPublishedAccountPage(generation: number): Promise<void> {
    try {
      await this.loadFirstPage(false)
    } finally {
      if (generation === this.sessionProjectionGeneration) {
        this.isResolvingSessionState = false
        this.reportTitleActions()
        this.refreshForFavoriteMutationIfVisible()
      }
    }
  }

  private resetForSignedOut(): void {
    this.requestGeneration += 1
    this.searchActive = false
    this.searchQuery = ''
    this.activeQuery = ''
    this.rawGalleries = []
    this.applyContentFilters()
    this.errorMessage = ''
    this.loadMoreErrorMessage = ''
    this.currentPage = 0
    this.totalPages = 1
    this.isInitialLoading = false
    this.isRefreshing = false
    this.isLoadingMore = false
    this.reportTitleActions()
  }

  private canLoadMore(): boolean {
    return this.signedIn && this.currentPage > 0 && this.currentPage < this.totalPages &&
      !this.isInitialLoading && !this.isRefreshing && !this.isLoadingMore &&
      this.loadMoreErrorMessage.length === 0
  }

  private canRetryLoadMore(): boolean {
    return this.signedIn && this.currentPage > 0 && this.currentPage < this.totalPages &&
      !this.isInitialLoading && !this.isRefreshing && !this.isLoadingMore
  }

  private async loadFirstPage(keepUsableRows: boolean): Promise<void> {
    if (!this.signedIn) {
      return
    }
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    const querySnapshot: string = this.activeQuery
    this.errorMessage = ''
    this.loadMoreErrorMessage = ''
    this.isLoadingMore = false
    if (keepUsableRows) {
      this.isRefreshing = true
      this.isInitialLoading = false
    } else {
      this.isInitialLoading = true
      this.isRefreshing = false
      this.rawGalleries = []
      this.applyContentFilters()
      this.currentPage = 0
      this.totalPages = 1
    }
    try {
      const tagTranslationRevision: number = this.tagTranslations.revision
      const result: NhGalleryPageResult = await NhApiClient.favorites(1, querySnapshot)
      if (generation !== this.requestGeneration || querySnapshot !== this.activeQuery) {
        return
      }
      this.rawGalleries = result.galleries
      this.applyContentFilters()
      if (tagTranslationRevision !== this.tagTranslations.revision) {
        this.refreshTagTranslationLabels()
      }
      this.currentPage = 1
      this.totalPages = Math.max(1, result.totalPages)
    } catch (error) {
      if (generation === this.requestGeneration) {
        this.errorMessage = (error as Error).message || AppStrings.get('favorites_load_failed')
      }
    } finally {
      if (generation === this.requestGeneration) {
        this.isInitialLoading = false
        this.isRefreshing = false
      }
    }
  }

  /**
   * Pull/re-tap/mutation refresh is deliberately not a session restore. Keep
   * visible rows mounted while their replacement is pending, but when the
   * current projection is empty use the initial-load state so retry cannot
   * flash the empty placeholder before page one settles.
   */
  private async refresh(): Promise<void> {
    if (!this.sessionStateApplied || !this.signedIn || this.isResolvingSessionState ||
      this.appliedAccountSessionRevision !== this.accountSession.revision ||
      this.isInitialLoading || this.isRefreshing) {
      return
    }
    await this.loadFirstPage(this.galleries.length > 0)
  }

  private async loadMore(): Promise<void> {
    if (!this.canLoadMore()) {
      return
    }
    const generation: number = this.requestGeneration
    const nextPage: number = this.currentPage + 1
    const querySnapshot: string = this.activeQuery
    this.isLoadingMore = true
    this.loadMoreErrorMessage = ''
    try {
      const tagTranslationRevision: number = this.tagTranslations.revision
      const result: NhGalleryPageResult = await NhApiClient.favorites(nextPage, querySnapshot)
      if (generation !== this.requestGeneration || querySnapshot !== this.activeQuery) {
        return
      }
      this.appendUnique(result.galleries)
      if (tagTranslationRevision !== this.tagTranslations.revision) {
        this.refreshTagTranslationLabels()
      }
      this.currentPage = nextPage
      this.totalPages = Math.max(nextPage, result.totalPages)
    } catch (error) {
      if (generation === this.requestGeneration) {
        this.loadMoreErrorMessage = (error as Error).message || AppStrings.get('favorites_load_more_failed')
      }
    } finally {
      if (generation === this.requestGeneration) {
        this.isLoadingMore = false
      }
    }
  }

  private retryLoadMore(): void {
    if (!this.canRetryLoadMore()) {
      return
    }
    // A footer action is explicit; it alone clears the error that keeps
    // passive reach-end and visible-range pagination from retriggering.
    this.loadMoreErrorMessage = ''
    this.loadMore()
  }

  private appendUnique(nextPage: NhGallerySummary[]): void {
    const merged: NhGallerySummary[] = [...this.rawGalleries]
    nextPage.forEach((gallery: NhGallerySummary): void => {
      if (!merged.some((existing: NhGallerySummary): boolean => existing.id === gallery.id)) {
        merged.push(gallery)
      }
    })
    this.rawGalleries = merged
    this.applyContentFilters()
  }

  private openGallery(galleryId: number, seed?: NhGallerySummary): void {
    if (galleryId > 0 && this.onOpenGallery) {
      this.onOpenGallery(galleryId, seed)
    }
  }

  private pageProgressLabel(): string {
    return AppStrings.get('favorites_page_progress')
      .replace('%1$d', `${this.currentPage}`)
      .replace('%2$d', `${this.totalPages}`)
  }

  @Builder
  private FavoritesSearchField() {
    Row() {
      Search({ value: this.searchQuery, placeholder: AppStrings.get('favorites_search_placeholder') })
        .width('100%')
        .height(ThemeTokens.SEARCH_FIELD_HEIGHT)
        .searchButton(AppStrings.get('action_search'), { fontColor: ThemeTokens.BRAND })
        .onChange((value: string): void => {
          this.searchQuery = value
        })
        .onSubmit((value: string): void => {
          this.submitSearch(value)
        })
    }
    .width('100%')
    .height(this.searchFieldReserve())
    .padding({
      left: ThemeTokens.LIST_HORIZONTAL_PADDING,
      right: ThemeTokens.LIST_HORIZONTAL_PADDING,
      bottom: ThemeTokens.SPACE_SM,
    })
    .margin({ top: this.layoutSafeArea.topAvoidHeight + ThemeTokens.TITLE_BAR_HEIGHT })
    .backgroundColor(ThemeTokens.SURFACE)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        if (this.isResolvingSessionState) {
          PageLoadingState({ text: AppStrings.get('favorites_checking_session') })
        } else if (!this.signedIn) {
          PageEmptyState({ message: AppStrings.get('favorites_sign_in_settings') })
        } else if (this.isInitialLoading && this.galleries.length === 0) {
          PageLoadingState({ text: AppStrings.get('favorites_loading') })
        } else if (this.errorMessage.length > 0 && this.galleries.length === 0) {
          PageErrorState({
            message: this.errorMessage,
            onRetry: (): void => {
              this.refresh()
            },
          })
        } else if (this.galleries.length === 0) {
          PageEmptyState({
            message: this.hasActiveSearch()
              ? AppStrings.get('favorites_search_empty')
              : AppStrings.get('favorites_empty'),
          })
        } else {
          GalleryCollectionBody({
            galleries: this.galleries,
            isInitialLoading: this.isInitialLoading,
            isRefreshing: this.isRefreshing,
            isLoadingMore: this.isLoadingMore,
            canLoadMore: this.canLoadMore(),
            errorMessage: this.errorMessage,
            loadMoreErrorMessage: this.loadMoreErrorMessage,
            loadingMessage: AppStrings.get('favorites_loading'),
            emptyMessage: this.hasActiveSearch()
              ? AppStrings.get('favorites_search_empty')
              : AppStrings.get('favorites_empty'),
            footerLoadingText: AppStrings.get('favorites_loading_more'),
            footerAvailableText: AppStrings.get('favorites_more_available'),
            footerCompleteText: AppStrings.get('favorites_up_to_date'),
            footerIdleText: this.currentPage > 0 ? this.pageProgressLabel() : '',
            footerRetryLabel: AppStrings.get('favorites_retry_loading'),
            topPadding: this.searchFieldReserve(),
            bottomPadding: ThemeTokens.ROOT_FLOATING_TAB_RESERVE,
            scroller: this.scroller,
            controller: this.refreshController,
            refreshEnabled: !this.isInitialLoading && !this.isRefreshing,
            backToTop: true,
            onRefresh: async (): Promise<void> => {
              await this.refresh()
            },
            onRetry: (): void => {
              this.refresh()
            },
            onLoadMore: (): void => {
              this.loadMore()
            },
            onRetryLoadMore: (): void => {
              this.retryLoadMore()
            },
            onOpenGallery: (galleryId: number, seed?: NhGallerySummary): void => {
              this.openGallery(galleryId, seed)
            },
            onDidScroll: (offset: number, state: ScrollState): void => {
              if (this.onDidScroll) {
                this.onDidScroll(offset, state)
              }
            },
          })
        }
      }
      .width('100%')
      .height('100%')
      if (this.searchActive && this.canUseTitleActions()) {
        Column() {
          this.FavoritesSearchField()
        }
        .width('100%')
        .align(Alignment.TopStart)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE)
    .id('nextn-favorites-root')
  }
}
