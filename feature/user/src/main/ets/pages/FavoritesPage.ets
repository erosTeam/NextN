import { common } from '@kit.AbilityKit'
import { CustomContentDialog, SymbolGlyphModifier } from '@kit.ArkUI'
import {
  BrowsePresentationService,
  BrowsePresentationState,
  ContentFilterService,
  ContentFilterState,
  DiagnosticLogger,
  FavoriteMutationState,
  FavoritesAction,
  FavoritesActionBridge,
  FavoritesActionState,
  GalleryCollectionBody,
  GalleryListCacheRepository,
  AccountSessionState,
  AppStrings,
  NhApiClient,
  NhBrowsePresentation,
  NhGalleryPageResult,
  NhGallerySummary,
  NhLocalUserTagState,
  NhTagCatalogService,
  PageEmptyState,
  PageErrorState,
  PageLoadingState,
  NextNPullRefreshController,
  RootRefreshRegistry,
  ThemeTokens,
  connectBrowsePresentation,
  connectContentFilters,
  connectFavoriteMutations,
  connectFavoritesActions,
  connectLocalUserTags,
  connectAccountSession,
  connectTagTranslations,
  TagTranslationState,
} from 'shared'
import { appMenuOptions } from 'shared'
import { FAVORITES_TITLE_SEARCH_HEIGHT } from '../components/FavoritesTitleSearchField'

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
  @Local localUserTags: NhLocalUserTagState = connectLocalUserTags()
  @Local tagTranslations: TagTranslationState = connectTagTranslations()
  @Local accountSession: AccountSessionState = connectAccountSession()
  @Local favoriteMutations: FavoriteMutationState = connectFavoriteMutations()
  @Local titleActions: FavoritesActionState = connectFavoritesActions()
  @Local browsePresentation: BrowsePresentationState = connectBrowsePresentation()
  @Local layoutMenuShown: boolean = false
  @Local searchActive: boolean = false
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
  @Event onOpenGallery?: (galleryId: number, seed?: NhGallerySummary) => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  private requestGeneration: number = 0
  private tagTranslationRefreshEpoch: number = 0
  private sessionProjectionGeneration: number = 0
  private isVisible: boolean = false
  private pendingFavoriteMutationRefresh: boolean = false
  private handledFavoriteMutationRevision: number = 0
  private handledTitleActionSeq: number = 0
  private handledSearchSubmitVersion: number = 0
  /** Published account state is a real gate, never a retained-tab appearance effect. */
  private sessionStateApplied: boolean = false
  private appliedAccountSessionRevision: number = -1
  /** One retained interactive-refresh owner across every Favorites density branch. */
  private refreshController: NextNPullRefreshController = new NextNPullRefreshController()
  @Local jumpPageText: string = ''
  @Local jumpPageError: string = ''
  private jumpSubmitting: boolean = false
  private jumpDialogController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: AppStrings.get('jump_page_confirm'),
      contentBuilder: (): void => {
        this.JumpDialogContent()
      },
      buttons: [
        {
          value: AppStrings.get('common_cancel'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: (): void => {
            this.closeJumpDialog()
          },
        },
        {
          value: AppStrings.get('jump_page_confirm'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: (): void => {
            this.confirmJumpDialog()
          },
        },
      ],
    }),
    autoCancel: true,
    onWillDismiss: (_action: DismissDialogAction) => {
      this.jumpPageText = ''
      this.jumpPageError = ''
    },
    alignment: DialogAlignment.Center,
    customStyle: false,
  });

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  /** Single-user device key; cleared on sign-out so another account cannot reuse it. */
  private favoritesCacheKey(): string {
    return 'favorites:v1:default'
  }

  aboutToAppear(): void {
    this.isVisible = true
    this.handledTitleActionSeq = this.titleActions.commandSeq
    this.handledSearchSubmitVersion = this.titleActions.searchSubmitVersion
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


  @Monitor('contentFilters.revision')
  onContentFiltersChanged(): void {
    this.applyContentFilters()
  }

  @Monitor('localUserTags.revision')
  onLocalUserTagsChanged(): void {
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
      return
    }
    if (this.titleActions.command === FavoritesAction.OPEN_LAYOUT_MENU && this.canUseTitleActions()) {
      this.layoutMenuShown = true
    }
    if (this.titleActions.command === FavoritesAction.OPEN_JUMP_DIALOG && this.canUseTitleActions()) {
      this.openJumpDialog()
    }
  }

  @Monitor('titleActions.searchSubmitVersion')
  onTitleSearchSubmitted(): void {
    if (this.titleActions.searchSubmitVersion <= this.handledSearchSubmitVersion) {
      return
    }
    this.handledSearchSubmitVersion = this.titleActions.searchSubmitVersion
    if (this.searchActive && this.canUseTitleActions()) {
      this.submitSearch(this.titleActions.searchDraft)
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
      this.titleActions.searchDraft = ''
      this.activeQuery = ''
      if (hadSubmittedQuery && this.canRequestAccountData()) {
        this.scroller.scrollToIndex(0)
        this.loadFirstPage(false)
      }
    }
    this.reportTitleActions()
  }

  /** Favorites is a direct global-Browse consumer; the menu writes the shared mode. */
  private setBrowsePresentation(mode: NhBrowsePresentation): void {
    this.layoutMenuShown = false
    if (this.browsePresentation.mode === mode) {
      return
    }
    BrowsePresentationService.setMode(this.context(), mode).catch((): void => {})
  }

  @Builder
  private LayoutMenu() {
    Menu() {
      this.LayoutMenuItem(AppStrings.get('browse_list'), NhBrowsePresentation.LIST)
      this.LayoutMenuItem(AppStrings.get('browse_simple_list'), NhBrowsePresentation.SIMPLE_LIST)
      this.LayoutMenuItem(AppStrings.get('browse_cover_grid'), NhBrowsePresentation.COVER_GRID)
      this.LayoutMenuItem(AppStrings.get('browse_waterfall'), NhBrowsePresentation.WATERFALL)
      this.LayoutMenuItem(AppStrings.get('browse_waterfall_compact'), NhBrowsePresentation.WATERFALL_COMPACT)
      this.LayoutMenuItem(AppStrings.get('browse_cover_wall'), NhBrowsePresentation.COVER_WALL)
    }
  }

  @Builder
  private LayoutMenuItem(label: string, mode: NhBrowsePresentation) {
    MenuItem({
      content: label,
      symbolEndIcon: this.browsePresentation.mode === mode
        ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
        : undefined,
    }).onClick((): void => {
      this.setBrowsePresentation(mode)
    })
  }

  /** One published gate for every authenticated Favorites request. */
  private canRequestAccountData(): boolean {
    return this.sessionStateApplied && this.signedIn && !this.isResolvingSessionState &&
      this.accountSession.authenticationAvailable && !this.accountSession.verificationRequired &&
      this.appliedAccountSessionRevision === this.accountSession.revision
  }

  /** HDS actions exist only after Entry's published session state has settled. */
  private canUseTitleActions(): boolean {
    return this.canRequestAccountData()
  }

  private reportTitleActions(): void {
    const available: boolean = this.canUseTitleActions()
    FavoritesActionBridge.reportActionsAvailable(available)
    FavoritesActionBridge.reportSearchActive(available && this.searchActive)
  }

  private submitSearch(value: string): void {
    const normalized: string = value.trim()
    this.titleActions.searchDraft = normalized
    this.activeQuery = normalized
    this.scroller.scrollToIndex(0)
    if (this.canRequestAccountData()) {
      this.loadFirstPage(false)
    }
  }

  private hasActiveSearch(): boolean {
    return this.activeQuery.length > 0
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
    if (!this.canRequestAccountData()) {
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
    this.isResolvingSessionState = !this.accountSession.initialized
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
    if (!this.canRequestAccountData()) {
      this.loadRetainedAccountCacheOnly(generation)
      return
    }
    this.loadPublishedAccountPage(generation)
  }

  /**
   * Durable ownership survives a terminal authentication failure. Keep cached
   * cards mounted, cancel remote work, and leave the single visible recovery
   * prompt to Entry's HDS SnackBar.
   */
  private async loadRetainedAccountCacheOnly(generation: number): Promise<void> {
    this.requestGeneration += 1
    this.isResolvingSessionState = false
    this.isInitialLoading = false
    this.isRefreshing = false
    this.isLoadingMore = false
    this.errorMessage = ''
    this.loadMoreErrorMessage = ''
    this.reportTitleActions()
    if (this.rawGalleries.length === 0) {
      await this.hydrateCachedFavorites(generation)
    }
  }

  private async loadPublishedAccountPage(generation: number): Promise<void> {
    this.isResolvingSessionState = false
    this.reportTitleActions()
    await this.hydrateCachedFavorites(generation)
    if (generation !== this.sessionProjectionGeneration) {
      return
    }
    try {
      await this.loadFirstPage(this.rawGalleries.length > 0)
    } finally {
      if (generation === this.sessionProjectionGeneration) {
        this.reportTitleActions()
        this.refreshForFavoriteMutationIfVisible()
      }
    }
  }

  private async hydrateCachedFavorites(generation: number): Promise<void> {
    try {
      const cached: NhGallerySummary[] | null = await GalleryListCacheRepository.load(
        this.context(),
        this.favoritesCacheKey(),
      )
      if (generation !== this.sessionProjectionGeneration ||
        cached === null || cached.length === 0) {
        return
      }
      const labeled: NhGallerySummary[] = await NhTagCatalogService.refreshLocalDisplayLabels(cached)
      if (generation !== this.sessionProjectionGeneration) {
        return
      }
      this.rawGalleries = labeled
      this.applyContentFilters()
      this.currentPage = 1
      this.totalPages = 1
    } catch (_error) {
      DiagnosticLogger.warn('favorites', 'cache_hydrate_failed', '')
    }
  }

  private resetForSignedOut(): void {
    GalleryListCacheRepository.clearPrefix(this.context(), 'favorites:v1:').catch((): void => {})
    this.requestGeneration += 1
    this.searchActive = false
    this.titleActions.searchDraft = ''
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
    return this.canRequestAccountData() && this.currentPage > 0 && this.currentPage < this.totalPages &&
      !this.isInitialLoading && !this.isRefreshing && !this.isLoadingMore &&
      this.loadMoreErrorMessage.length === 0
  }

  private canRetryLoadMore(): boolean {
    return this.canRequestAccountData() && this.currentPage > 0 && this.currentPage < this.totalPages &&
      !this.isInitialLoading && !this.isRefreshing && !this.isLoadingMore
  }

  /** NextE ToplistPeriodPage parity: digits only, empty value collapses to ''. */
  private normalizeJumpInput(value: string): string {
    return (value || '').replace(/[^0-9]/g, '')
  }

  private jumpHelpText(): string {
    const help: string = AppStrings.get('jump_page_help')
    if (this.totalPages <= 0) {
      return help
    }
    return `${help} 1 - ${this.totalPages}`
  }

  private openJumpDialog(): void {
    this.jumpPageText = `${Math.max(1, this.currentPage)}`
    this.jumpPageError = ''
    try {
      this.jumpDialogController.open()
    } catch (_error) {}
  }

  private closeJumpDialog(): void {
    try {
      this.jumpDialogController.close()
    } catch (_error) {}
  }

  /** Replaces the favourites first page with the requested server page. */
  private async jumpToPage(page: number): Promise<boolean> {
    if (!this.canRequestAccountData()) {
      return false
    }
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    const querySnapshot: string = this.activeQuery
    this.errorMessage = ''
    this.loadMoreErrorMessage = ''
    this.isLoadingMore = false
    this.isInitialLoading = true
    this.isRefreshing = false
    this.rawGalleries = []
    this.applyContentFilters()
    this.currentPage = 0
    this.totalPages = 1
    try {
      const result: NhGalleryPageResult = await NhApiClient.favorites(page, querySnapshot)
      if (generation !== this.requestGeneration || querySnapshot !== this.activeQuery) {
        return false
      }
      this.rawGalleries = result.galleries
      this.applyContentFilters()
      this.currentPage = page
      this.totalPages = Math.max(1, result.totalPages)
      return true
    } catch (error) {
      if (generation === this.requestGeneration) {
        this.errorMessage = AppStrings.get('favorites_load_failed')
      }
      return false
    } finally {
      if (generation === this.requestGeneration) {
        this.isInitialLoading = false
        this.isRefreshing = false
      }
    }
  }

  private confirmJumpDialog(): void {
    if (this.jumpSubmitting) {
      return
    }
    const page: number = Number.parseInt(this.jumpPageText, 10)
    if (!this.canRequestAccountData() || Number.isNaN(page) || page <= 0 ||
      (this.totalPages > 0 && page > this.totalPages)) {
      this.jumpPageError = AppStrings.get('jump_page_invalid')
      return
    }
    this.jumpSubmitting = true
    this.jumpToPage(page).then((ok: boolean): void => {
      if (ok) {
        this.closeJumpDialog()
        setTimeout((): void => {
          this.scroller.scrollToIndex(0)
        }, 50)
      } else {
        this.jumpPageError = AppStrings.get('common_load_failed')
      }
    }).catch((): void => {
      this.jumpPageError = AppStrings.get('common_load_failed')
    }).finally((): void => {
      this.jumpSubmitting = false
    })
  }

  @Builder
  private JumpDialogContent() {
    Column({ space: ThemeTokens.SPACE_SM }) {
      Text(this.jumpHelpText())
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
      TextInput({ text: this.jumpPageText, placeholder: AppStrings.get('jump_page_placeholder') })
        .type(InputType.Number)
        .inputFilter('^[0-9]*$')
        .defaultFocus(true)
        .width('100%')
        .onChange((value: string): void => {
          this.jumpPageText = this.normalizeJumpInput(value)
          this.jumpPageError = ''
        })
      if (this.jumpPageError.length > 0) {
        Text(this.jumpPageError)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
          .width('100%')
      }
    }
    .width('100%')
  }

  private async loadFirstPage(keepUsableRows: boolean): Promise<void> {
    if (!this.canRequestAccountData()) {
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
      DiagnosticLogger.info('favorites-session', 'favorites_request_success', 'stage')
      if (querySnapshot.length === 0) {
        GalleryListCacheRepository.save(this.context(), this.favoritesCacheKey(), result.galleries)
          .catch((): void => {})
      }
    } catch (error) {
      if (generation === this.requestGeneration && this.canRequestAccountData()) {
        DiagnosticLogger.info('favorites-session', 'favorites_request_failed', 'stage')
        this.errorMessage = AppStrings.get('favorites_load_failed')
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
    if (!this.canRequestAccountData() || this.isInitialLoading || this.isRefreshing) {
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
        this.loadMoreErrorMessage = AppStrings.get('favorites_load_more_failed')
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

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
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
            topPadding: this.searchActive && this.canUseTitleActions()
              ? FAVORITES_TITLE_SEARCH_HEIGHT
              : 0,
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
      // HDS title actions cannot anchor a Menu; the retained Favorites host
      // owns the same invisible anchor as NextE FavoritesPage/FavcatPage.
      Row()
        .width(1)
        .height(1)
        .hitTestBehavior(HitTestMode.None)
        .bindMenu(this.layoutMenuShown, this.LayoutMenu, appMenuOptions({
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.layoutMenuShown = false
          },
        }))
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE)
    .id('nextn-favorites-root')
  }
}
