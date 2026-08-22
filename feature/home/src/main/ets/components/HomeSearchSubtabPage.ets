import { common } from '@kit.AbilityKit'
import { CustomContentDialog } from '@kit.ArkUI'
import {
  ActiveKeyState,
  AppStrings,
  ContentFilterService,
  ContentFilterState,
  DiagnosticLogger,
  GalleryCollectionBody,
  GalleryListCacheRepository,
  HomeGallerySelectionState,
  HomeSourceState,
  HomeSubtabState,
  HOME_SOURCE_SELECTOR_HEIGHT,
  NextNPullRefreshController,
  NhApiClient,
  NhGalleryPageResult,
  NhGallerySummary,
  NhHomeSubtabProfile,
  NhSearchLanguage,
  NhSearchOptions,
  NhSearchSort,
  NhTagCatalogService,
  RootRefreshRegistry,
  SafeModeGate,
  SafeModeState,
  TagTranslationState,
  ThemeTokens,
  connectContentFilters,
  connectHomeGallerySelection,
  connectHomeSource,
  connectHomeSubtabs,
  connectSafeMode,
  connectTagTranslations,
} from 'shared'

/**
 * One retained NH search SubTab. Its UUID owns the list, Scroller, cache and
 * request generation; contentRevision alone invalidates remote state.
 */
@ComponentV2
export struct HomeSearchSubtabPage {
  @Local galleries: NhGallerySummary[] = []
  @Local rawGalleries: NhGallerySummary[] = []
  @Local contentFilters: ContentFilterState = connectContentFilters()
  @Local tagTranslations: TagTranslationState = connectTagTranslations()
  @Local homeSubtabs: HomeSubtabState = connectHomeSubtabs()
  @Local homeSource: HomeSourceState = connectHomeSource()
  @Local homeGallerySelection: HomeGallerySelectionState = connectHomeGallerySelection()
  @Local safeMode: SafeModeState = connectSafeMode()
  // Retained pages mount before their first activation. Until cache hydration
  // or page one settles, zero rows mean "not loaded yet", never "empty".
  @Local isInitialLoading: boolean = true
  @Local isRefreshing: boolean = false
  @Local isLoadingMore: boolean = false
  @Local errorMessage: string = ''
  @Local loadMoreErrorMessage: string = ''
  @Local currentPage: number = 0
  @Local totalPages: number = 1
  @Local jumpPageText: string = ''
  @Local jumpPageError: string = ''
  @Param sourceKey: string = ''
  @Param active: ActiveKeyState = new ActiveKeyState()
  @Param scroller: Scroller = new Scroller()
  @Event onOpenGallery?: (galleryId: number, seed?: NhGallerySummary) => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void

  private requestGeneration: number = 0
  private loadedOnce: boolean = false
  private activeRevision: string = ''
  private activeQuery: string = ''
  private activeLanguage: NhSearchLanguage = NhSearchLanguage.ALL
  private activeSort: NhSearchSort = NhSearchSort.RECENT
  private tagTranslationRefreshEpoch: number = 0
  private jumpSubmitting: boolean = false
  private refreshController: NextNPullRefreshController = new NextNPullRefreshController()
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
          action: (): void => this.closeJumpDialog(),
        },
        {
          value: AppStrings.get('jump_page_confirm'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: (): void => this.confirmJumpDialog(),
        },
      ],
    }),
    autoCancel: true,
    onWillDismiss: (_action: DismissDialogAction): void => {
      this.jumpPageText = ''
      this.jumpPageError = ''
    },
    alignment: DialogAlignment.Center,
    customStyle: false,
  })

  aboutToAppear(): void {
    this.registerRootRefresh()
    this.loadOnce()
  }

  aboutToDisappear(): void {
    RootRefreshRegistry.unregister(this.scroller)
    this.requestGeneration += 1
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private profile(): NhHomeSubtabProfile | null {
    return this.homeSubtabs.find(this.sourceKey)
  }

  private isActive(): boolean {
    return this.active.activeKey === this.sourceKey
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

  private loadOnce(): void {
    if (!this.isActive()) {
      return
    }
    const profile: NhHomeSubtabProfile | null = this.profile()
    if (profile === null || !profile.isSearch()) {
      return
    }
    const revision: string = profile.contentRevision()
    if (!this.loadedOnce) {
      this.loadedOnce = true
      this.activeRevision = revision
      this.loadOnceWithCachedRows(profile.copy())
      return
    }
    if (this.activeRevision !== revision) {
      this.loadFirstPage(profile.copy(), this.rawGalleries.length > 0)
    }
  }

  @Monitor('active.activeKey')
  onActiveChange(): void {
    if (this.isActive()) {
      this.registerRootRefresh()
      this.loadOnce()
    }
  }

  @Monitor('homeSubtabs.profiles')
  onProfilesChanged(): void {
    const profile: NhHomeSubtabProfile | null = this.profile()
    const revision: string = profile === null ? '' : profile.contentRevision()
    if (revision === this.activeRevision) {
      return
    }
    // Supersede an in-flight response immediately, even while this page is
    // inactive. Its replacement request remains delayed until activation.
    this.requestGeneration += 1
    if (this.loadedOnce && this.isActive() && profile !== null && profile.isSearch()) {
      this.loadFirstPage(profile.copy(), this.rawGalleries.length > 0)
    }
  }

  @Monitor('homeSource.jumpDialogRequestSeq')
  onJumpDialogRequested(): void {
    if (this.isActive() && this.homeSource.jumpDialogRequestSeq > 0) {
      this.openJumpDialog()
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

  @Monitor('safeMode.unlocked')
  onSafeModeChanged(): void {
    this.requestGeneration += 1
    this.activeRevision = ''
    if (this.loadedOnce && this.isActive()) {
      const profile: NhHomeSubtabProfile | null = this.profile()
      if (profile !== null && profile.isSearch()) {
        this.loadFirstPage(profile.copy(), false)
      }
    }
  }

  private async loadOnceWithCachedRows(profile: NhHomeSubtabProfile): Promise<void> {
    const cacheKey: string = this.cacheKey(profile.contentRevision())
    try {
      const cached: NhGallerySummary[] | null = await GalleryListCacheRepository.load(this.context(), cacheKey)
      if (this.loadedOnce && this.rawGalleries.length === 0 &&
        this.profileRevision() === profile.contentRevision() && cached !== null && cached.length > 0) {
        const labeled: NhGallerySummary[] = await NhTagCatalogService.refreshLocalDisplayLabels(cached)
        if (this.loadedOnce && this.rawGalleries.length === 0 &&
          this.profileRevision() === profile.contentRevision()) {
          this.rawGalleries = SafeModeGate.safeRows(labeled)
          this.applyContentFilters()
          this.currentPage = 1
          this.totalPages = 1
        }
      }
    } catch (_error) {
      DiagnosticLogger.warn('home', 'subtab_cache_hydrate_failed', this.sourceKey)
    }
    await this.loadFirstPage(profile, this.rawGalleries.length > 0)
  }

  private profileRevision(): string {
    const profile: NhHomeSubtabProfile | null = this.profile()
    return profile === null ? '' : profile.contentRevision()
  }

  private cacheKey(revision: string): string {
    return SafeModeGate.safeCacheScope(`home:subtab:v1:${this.sourceKey}:${revision}`)
  }

  private effectiveQuery(profile: NhHomeSubtabProfile): string {
    const trimmed: string = profile.query.trim()
    const profileQuery: string = trimmed.length === 0
      ? (profile.language === NhSearchLanguage.ALL ? '' : `language:${profile.language}`)
      : NhSearchOptions.queryWithLanguage(trimmed, profile.language)
    return SafeModeGate.safeQuery(profileQuery)
  }

  private requestPage(page: number): Promise<NhGalleryPageResult> {
    return NhApiClient.search(
      this.activeQuery,
      page,
      NhSearchOptions.sortValue(this.activeSort),
    )
  }

  private async loadFirstPage(profile: NhHomeSubtabProfile, keepUsableRows: boolean): Promise<void> {
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    this.activeRevision = profile.contentRevision()
    this.activeLanguage = profile.language
    this.activeSort = profile.sort
    this.activeQuery = this.effectiveQuery(profile)
    this.isLoadingMore = false
    this.errorMessage = ''
    this.loadMoreErrorMessage = ''
    let refreshOutcome: string = 'pending'
    if (keepUsableRows) {
      this.isRefreshing = true
      this.isInitialLoading = false
      DiagnosticLogger.info(
        'collection',
        'collection_refresh_started',
        `source=search generation=${generation} rows=${this.rawGalleries.length}`,
      )
    } else {
      this.isInitialLoading = true
      this.isRefreshing = false
      this.rawGalleries = []
      this.applyContentFilters()
      this.currentPage = 0
      this.totalPages = 1
    }
    try {
      const translationRevision: number = this.tagTranslations.revision
      const result: NhGalleryPageResult = await this.requestPage(1)
      if (!this.isCurrent(generation, profile.contentRevision())) {
        return
      }
      this.rawGalleries = SafeModeGate.safeRows(result.galleries)
      this.applyContentFilters()
      if (translationRevision !== this.tagTranslations.revision) {
        this.refreshTagTranslationLabels()
      }
      this.currentPage = 1
      this.totalPages = Math.max(1, result.totalPages)
      refreshOutcome = 'success'
      GalleryListCacheRepository.save(this.context(), this.cacheKey(this.activeRevision), this.rawGalleries)
        .catch((): void => {})
    } catch (error) {
      if (this.isCurrent(generation, profile.contentRevision())) {
        this.errorMessage = AppStrings.get('browse_load_failed')
        refreshOutcome = 'error'
      }
    } finally {
      if (generation === this.requestGeneration) {
        this.isInitialLoading = false
        this.isRefreshing = false
        if (keepUsableRows) {
          DiagnosticLogger.info(
            'collection',
            'collection_refresh_settled',
            `source=search generation=${generation} outcome=${refreshOutcome} rows=${this.rawGalleries.length}`,
          )
        }
      }
    }
  }

  private isCurrent(generation: number, revision: string): boolean {
    return generation === this.requestGeneration && revision === this.profileRevision()
  }

  private async refresh(): Promise<void> {
    if (this.isInitialLoading || this.isRefreshing) {
      return
    }
    const profile: NhHomeSubtabProfile | null = this.profile()
    if (profile !== null && profile.isSearch()) {
      await this.loadFirstPage(profile.copy(), this.rawGalleries.length > 0)
    }
  }

  private canLoadMore(): boolean {
    return this.currentPage > 0 && this.currentPage < this.totalPages &&
      !this.isInitialLoading && !this.isRefreshing && !this.isLoadingMore &&
      this.loadMoreErrorMessage.length === 0
  }

  private canRetryLoadMore(): boolean {
    return this.currentPage > 0 && this.currentPage < this.totalPages &&
      !this.isInitialLoading && !this.isRefreshing && !this.isLoadingMore
  }

  private async loadMore(): Promise<void> {
    if (!this.canLoadMore()) {
      return
    }
    const generation: number = this.requestGeneration
    const revision: string = this.activeRevision
    const nextPage: number = this.currentPage + 1
    this.isLoadingMore = true
    this.loadMoreErrorMessage = ''
    try {
      const translationRevision: number = this.tagTranslations.revision
      const result: NhGalleryPageResult = await this.requestPage(nextPage)
      if (!this.isCurrent(generation, revision)) {
        return
      }
      this.appendUnique(SafeModeGate.safeRows(result.galleries))
      if (translationRevision !== this.tagTranslations.revision) {
        this.refreshTagTranslationLabels()
      }
      this.currentPage = nextPage
      this.totalPages = Math.max(nextPage, result.totalPages)
    } catch (error) {
      if (this.isCurrent(generation, revision)) {
        this.loadMoreErrorMessage = AppStrings.get('browse_load_more_failed')
      }
    } finally {
      if (generation === this.requestGeneration) {
        this.isLoadingMore = false
      }
    }
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

  private applyContentFilters(): void {
    this.galleries = ContentFilterService.filterGalleries(this.rawGalleries)
  }

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

  private retryLoadMore(): void {
    if (!this.canRetryLoadMore()) {
      return
    }
    this.loadMoreErrorMessage = ''
    this.loadMore()
  }

  private normalizeJumpInput(value: string): string {
    return (value || '').replace(/[^0-9]/g, '')
  }

  private jumpHelpText(): string {
    return `${AppStrings.get('jump_page_help')} 1 - ${Math.max(1, this.totalPages)}`
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

  private async jumpToPage(page: number): Promise<boolean> {
    const profile: NhHomeSubtabProfile | null = this.profile()
    if (profile === null || !profile.isSearch()) {
      return false
    }
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    this.activeRevision = profile.contentRevision()
    this.activeLanguage = profile.language
    this.activeSort = profile.sort
    this.activeQuery = this.effectiveQuery(profile)
    this.isLoadingMore = false
    this.errorMessage = ''
    this.loadMoreErrorMessage = ''
    this.isInitialLoading = true
    this.isRefreshing = false
    this.rawGalleries = []
    this.applyContentFilters()
    this.currentPage = 0
    this.totalPages = 1
    try {
      const result: NhGalleryPageResult = await this.requestPage(page)
      if (!this.isCurrent(generation, profile.contentRevision())) {
        return false
      }
      this.rawGalleries = SafeModeGate.safeRows(result.galleries)
      this.applyContentFilters()
      this.currentPage = page
      this.totalPages = Math.max(1, result.totalPages)
      return true
    } catch (error) {
      if (this.isCurrent(generation, profile.contentRevision())) {
        this.errorMessage = AppStrings.get('browse_load_failed')
      }
      return false
    } finally {
      if (generation === this.requestGeneration) {
        this.isInitialLoading = false
      }
    }
  }

  private confirmJumpDialog(): void {
    if (this.jumpSubmitting) {
      return
    }
    const page: number = Number.parseInt(this.jumpPageText, 10)
    if (Number.isNaN(page) || page <= 0 || page > Math.max(1, this.totalPages)) {
      this.jumpPageError = AppStrings.get('jump_page_invalid')
      return
    }
    this.jumpSubmitting = true
    this.jumpToPage(page).then((ok: boolean): void => {
      if (ok) {
        this.closeJumpDialog()
        setTimeout((): void => this.scroller.scrollToIndex(0), 50)
      } else {
        this.jumpPageError = AppStrings.get('common_load_failed')
      }
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

  build() {
    GalleryCollectionBody({
      galleries: this.galleries,
      selectedGalleryId: this.homeGallerySelection.selectedGalleryId,
      presentationOverride: this.profile()?.presentationOverride() ?? null,
      isInitialLoading: this.isInitialLoading,
      isRefreshing: this.isRefreshing,
      isLoadingMore: this.isLoadingMore,
      canLoadMore: this.canLoadMore(),
      errorMessage: this.errorMessage,
      loadMoreErrorMessage: this.loadMoreErrorMessage,
      loadingMessage: AppStrings.get('browse_loading_public'),
      emptyMessage: AppStrings.get('browse_empty'),
      footerLoadingText: AppStrings.get('browse_footer_loading'),
      footerAvailableText: AppStrings.get('browse_footer_available'),
      footerCompleteText: AppStrings.get('footer_up_to_date'),
      footerIdleText: this.currentPage > 0
        ? AppStrings.format('common_page_of', [this.currentPage.toString(), this.totalPages.toString()])
        : '',
      footerRetryLabel: AppStrings.get('common_try_loading_again'),
      topPadding: HOME_SOURCE_SELECTOR_HEIGHT,
      bottomPadding: ThemeTokens.ROOT_FLOATING_TAB_RESERVE,
      scroller: this.scroller,
      controller: this.refreshController,
      refreshEnabled: !this.isInitialLoading && !this.isRefreshing,
      backToTop: true,
      onRefresh: async (): Promise<void> => this.refresh(),
      onRetry: (): void => {
        this.refresh()
      },
      onLoadMore: (): void => {
        this.loadMore()
      },
      onRetryLoadMore: (): void => this.retryLoadMore(),
      onOpenGallery: (galleryId: number, seed?: NhGallerySummary): void => {
        if (galleryId > 0 && this.onOpenGallery) {
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
