import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import {
  AppStrings,
  CatalogPreferencesService,
  CatalogPreferencesState,
  ContentFilterService,
  ContentFilterState,
  GalleryCollectionBody,
  GalleryListCacheRepository,
  ActiveKeyState,
  HomeGallerySelectionState,
  HomeSourceBridge,
  HomeSourceState,
  HomeSourceVisualIndexState,
  HOME_SOURCE_LATEST,
  HOME_SOURCE_POPULAR,
  HOME_SOURCE_SELECTOR_HEIGHT,
  HomeSourcePresentationService,
  NextNGroupedListSection,
  NextNListRow,
  NextNPullRefreshController,
  NextNSectionHeader,
  NhApiClient,
  NhBrowsePresentation,
  NhGalleryPageResult,
  NhGallerySummary,
  NhTagCatalogService,
  NhSearchLanguage,
  NhSearchOptions,
  NhSearchSort,
  NextNModalScaffold,
  RootRefreshRegistry,
  RetainedSubtabHost,
  SubtabTransitionState,
  SUBTAB_TRANSITION_SCOPE_HOME,
  ThemeTokens,
  connectCatalogPreferences,
  connectContentFilters,
  connectHomeGallerySelection,
  connectHomeSource,
  connectHomeSourceVisualIndex,
  connectSubtabTransition,
  connectTagTranslations,
  TagTranslationState,
} from 'shared'
import { appMenuOptions } from 'shared'
import { appSheetOptions } from 'shared'
import { PopularPage } from './PopularPage'

const BROWSE_LANGUAGES: NhSearchLanguage[] = [
  NhSearchLanguage.ALL,
  NhSearchLanguage.JAPANESE,
  NhSearchLanguage.CHINESE,
  NhSearchLanguage.ENGLISH,
  NhSearchLanguage.TRANSLATED,
]

const BROWSE_SORTS: NhSearchSort[] = [
  NhSearchSort.RECENT,
  NhSearchSort.POPULAR_TODAY,
  NhSearchSort.POPULAR_WEEK,
  NhSearchSort.POPULAR_MONTH,
  NhSearchSort.POPULAR_ALL_TIME,
]

/**
 * Anonymous public browse. The durable local choices stay separate from the
 * active request snapshot, so an old pagination response cannot merge into a
 * different language or ordering choice.
 */
@ComponentV2
export struct LatestSourcePage {
  @Local galleries: NhGallerySummary[] = []
  /** The response snapshot stays intact so a local rule change never needs another GET. */
  @Local rawGalleries: NhGallerySummary[] = []
  @Local contentFilters: ContentFilterState = connectContentFilters()
  @Local tagTranslations: TagTranslationState = connectTagTranslations()
  @Local catalogPreferences: CatalogPreferencesState = connectCatalogPreferences()
  @Local isInitialLoading: boolean = false
  @Local isRefreshing: boolean = false
  @Local isLoadingMore: boolean = false
  @Local errorMessage: string = ''
  @Local loadMoreErrorMessage: string = ''
  @Local currentPage: number = 0
  @Local totalPages: number = 1
  @Local activeLanguageFilter: NhSearchLanguage = NhSearchLanguage.ALL
  @Local activeBrowseSort: NhSearchSort = NhSearchSort.RECENT
  @Local showBrowseOptions: boolean = false
  @Param sourceKey: string = HOME_SOURCE_LATEST
  @Param active: ActiveKeyState = new ActiveKeyState()
  @Param scroller: Scroller = new Scroller()
  @Event onOpenGallery?: (galleryId: number, seed?: NhGallerySummary) => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  @Local homeSource: HomeSourceState = connectHomeSource()
  @Local homeGallerySelection: HomeGallerySelectionState = connectHomeGallerySelection()
  private requestGeneration: number = 0
  /** Retained pages load only after their own first activation. */
  private loadedOnce: boolean = false
  /** A stable synthetic negative clause is held for this request generation only. */
  private activeBrowseQuery: string = ''
  private tagTranslationRefreshEpoch: number = 0
  private browseOptionsScroller: Scroller = new Scroller()
  private refreshController: NextNPullRefreshController = new NextNPullRefreshController()

  aboutToAppear(): void {
    this.registerRootRefresh()
    this.loadOnce()
  }

  aboutToDisappear(): void {
    RootRefreshRegistry.unregister(this.scroller)
  }

  private isActive(): boolean {
    return this.active.activeKey === this.sourceKey
  }

  private registerRootRefresh(): void {
    RootRefreshRegistry.register(this.scroller, (): void => {
      // The mounted collection owns the visible programmatic pull and its
      // scroll-to-top animation. State-only branches retain the existing
      // retry behavior until a collection host is mounted.
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
    if (!this.loadedOnce) {
      this.loadedOnce = true
      this.loadOnceWithCachedRows()
      return
    }
    this.reloadForCatalogPreferences()
  }

  /** Cold-start first paint comes from the durable snapshot; the live page
   *  read then replaces it in place without blanking the grid. */
  private async loadOnceWithCachedRows(): Promise<void> {
    const cacheKey: string = this.homeCacheKey()
    try {
      const cached: NhGallerySummary[] | null = await GalleryListCacheRepository.load(
        this.context(),
        cacheKey,
      )
      if (this.loadedOnce && this.rawGalleries.length === 0 &&
        this.homeCacheKey() === cacheKey && cached !== null && cached.length > 0) {
        const labeled: NhGallerySummary[] = await NhTagCatalogService.refreshLocalDisplayLabels(cached)
        if (this.loadedOnce && this.rawGalleries.length === 0 &&
          this.homeCacheKey() === cacheKey) {
          this.rawGalleries = labeled
          this.applyContentFilters()
          this.currentPage = 1
          this.totalPages = 1
        }
      }
    } catch (_error) {
    }
    await this.loadFirstPage(this.rawGalleries.length > 0)
  }

  private homeCacheKey(): string {
    return `home:v1:${this.sourceKey}:${this.catalogPreferences.browseLanguage}:${this.catalogPreferences.browseSort}`
  }

  @Monitor('active.activeKey')
  onActiveChange(): void {
    if (this.isActive()) {
      this.registerRootRefresh()
      this.loadOnce()
    }
  }

  @Monitor('homeSource.browseOptionsRequestSeq')
  onBrowseOptionsRequested(): void {
    if (this.isActive() && this.homeSource.browseOptionsRequestSeq > 0) {
      this.showBrowseOptions = true
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

  @Monitor('catalogPreferences.browseRevision')
  onBrowseCatalogPreferencesChanged(): void {
    this.reloadForCatalogPreferences()
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

  private isCurrentRequest(generation: number): boolean {
    return generation === this.requestGeneration
  }

  private canLoadMore(): boolean {
    return this.currentPage > 0 &&
      this.currentPage < this.totalPages &&
      !this.isInitialLoading &&
      !this.isRefreshing &&
      !this.isLoadingMore &&
      this.loadMoreErrorMessage.length === 0
  }

  private canRetryLoadMore(): boolean {
    return this.currentPage > 0 &&
      this.currentPage < this.totalPages &&
      !this.isInitialLoading &&
      !this.isRefreshing &&
      !this.isLoadingMore
  }

  /**
   * The latest endpoint covers the default state. The ErosN-compatible search
   * endpoint needs a nonempty term for every other option combination; this
   * private negative clause is never displayed or saved in local history.
   */
  private browseQueryForGeneration(generation: number): string {
    if (this.activeLanguageFilter === NhSearchLanguage.ALL && this.activeBrowseSort === NhSearchSort.RECENT) {
      return ''
    }
    return `-"nextn-browse-${Date.now()}-${generation}"`
  }

  private requestBrowse(
    page: number,
    query: string,
    language: NhSearchLanguage,
    sort: NhSearchSort,
  ): Promise<NhGalleryPageResult> {
    if (language === NhSearchLanguage.ALL && sort === NhSearchSort.RECENT) {
      return NhApiClient.latest(page)
    }
    return NhApiClient.search(
      NhSearchOptions.queryWithLanguage(query, language),
      page,
      NhSearchOptions.sortValue(sort),
    )
  }

  /** Starts a new public-list generation; option changes may intentionally supersede a pending load. */
  private async loadFirstPage(keepUsableRows: boolean): Promise<void> {
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    this.activeLanguageFilter = this.catalogPreferences.browseLanguage
    this.activeBrowseSort = this.catalogPreferences.browseSort
    this.activeBrowseQuery = this.browseQueryForGeneration(generation)
    this.isLoadingMore = false
    this.errorMessage = ''
    this.loadMoreErrorMessage = ''
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
      const result: NhGalleryPageResult = await this.requestBrowse(
        1,
        this.activeBrowseQuery,
        this.activeLanguageFilter,
        this.activeBrowseSort,
      )
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.rawGalleries = result.galleries
      this.applyContentFilters()
      if (tagTranslationRevision !== this.tagTranslations.revision) {
        this.refreshTagTranslationLabels()
      }
      this.currentPage = 1
      this.totalPages = Math.max(1, result.totalPages)
      GalleryListCacheRepository.save(this.context(), this.homeCacheKey(), result.galleries)
        .catch((): void => {})
    } catch (error) {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.errorMessage = (error as Error).message || AppStrings.get('browse_load_failed')
    } finally {
      if (this.isCurrentRequest(generation)) {
        this.isInitialLoading = false
        this.isRefreshing = false
      }
    }
  }

  /** Replaces page one without blanking usable rows unless this is the first load. */
  private async refresh(): Promise<void> {
    if (this.isInitialLoading || this.isRefreshing) {
      return
    }
    await this.loadFirstPage(this.rawGalleries.length > 0)
  }

  private async loadMore(): Promise<void> {
    if (!this.canLoadMore()) {
      return
    }
    const generation: number = this.requestGeneration
    const nextPage: number = this.currentPage + 1
    this.isLoadingMore = true
    this.loadMoreErrorMessage = ''
    try {
      const tagTranslationRevision: number = this.tagTranslations.revision
      const result: NhGalleryPageResult = await this.requestBrowse(
        nextPage,
        this.activeBrowseQuery,
        this.activeLanguageFilter,
        this.activeBrowseSort,
      )
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.appendUnique(result.galleries)
      if (tagTranslationRevision !== this.tagTranslations.revision) {
        this.refreshTagTranslationLabels()
      }
      this.currentPage = nextPage
      this.totalPages = Math.max(nextPage, result.totalPages)
    } catch (error) {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.loadMoreErrorMessage = (error as Error).message || AppStrings.get('browse_load_more_failed')
    } finally {
      if (this.isCurrentRequest(generation)) {
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

  private retryLoadMore(): void {
    if (!this.canRetryLoadMore()) {
      return
    }
    // Reach-end deliberately stays blocked while an error is visible. A
    // deliberate footer retry clears only that pagination error, then uses
    // the same guarded request path exactly once.
    this.loadMoreErrorMessage = ''
    this.loadMore()
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private browsePreferencesChanged(): boolean {
    return this.activeLanguageFilter !== this.catalogPreferences.browseLanguage ||
      this.activeBrowseSort !== this.catalogPreferences.browseSort
  }

  /** Only an active retained Latest source may turn its own preference revision into one new generation. */
  private reloadForCatalogPreferences(): void {
    if (!this.loadedOnce || !this.isActive() || !this.browsePreferencesChanged()) {
      return
    }
    this.loadFirstPage(this.rawGalleries.length > 0)
  }

  private selectLanguage(option: NhSearchLanguage): void {
    if (this.catalogPreferences.browseLanguage === option) {
      return
    }
    CatalogPreferencesService.setBrowseLanguage(this.context(), option).catch((): void => {})
  }

  private selectSort(option: NhSearchSort): void {
    if (this.catalogPreferences.browseSort === option) {
      return
    }
    CatalogPreferencesService.setBrowseSort(this.context(), option).catch((): void => {})
  }

  private openGallery(galleryId: number, seed?: NhGallerySummary): void {
    if (galleryId > 0 && this.onOpenGallery) {
      this.onOpenGallery(galleryId, seed)
    }
  }

  @Builder
  private BrowseOptionsPanel() {
    Column({ space: ThemeTokens.SPACE_MD }) {
      NextNSectionHeader({ title: AppStrings.get('browse_section_language') })
      NextNGroupedListSection() {
        ForEach(BROWSE_LANGUAGES, (option: NhSearchLanguage): void => {
          NextNListRow({
            title: NhSearchOptions.languageLabel(option),
            trailingText: this.catalogPreferences.browseLanguage === option ? AppStrings.get('common_selected') : '',
            showChevron: false,
            accessibilityLabel: AppStrings.format('browse_select_language', [NhSearchOptions.languageLabel(option)]),
            onAction: (): void => {
              this.selectLanguage(option)
            },
          })
          if (option !== BROWSE_LANGUAGES[BROWSE_LANGUAGES.length - 1]) {
            this.BrowseOptionDivider()
          }
        }, (option: NhSearchLanguage): string => option)
      }
      NextNSectionHeader({ title: AppStrings.get('browse_section_order') })
      NextNGroupedListSection() {
        ForEach(BROWSE_SORTS, (option: NhSearchSort): void => {
          NextNListRow({
            title: NhSearchOptions.sortLabel(option),
            trailingText: this.catalogPreferences.browseSort === option ? AppStrings.get('common_selected') : '',
            showChevron: false,
            accessibilityLabel: AppStrings.format('browse_select_order', [NhSearchOptions.sortLabel(option)]),
            onAction: (): void => {
              this.selectSort(option)
            },
          })
          if (option !== BROWSE_SORTS[BROWSE_SORTS.length - 1]) {
            this.BrowseOptionDivider()
          }
        }, (option: NhSearchSort): string => option)
      }
    }
    .width('100%')
    .padding({
      left: ThemeTokens.SPACE_SM,
      right: ThemeTokens.SPACE_SM,
      top: ThemeTokens.SPACE_SM,
      bottom: ThemeTokens.SPACE_SM,
    })
  }

  @Builder
  private BrowseOptionDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(ThemeTokens.DIVIDER)
      .margin({ left: ThemeTokens.SPACE_MD })
  }

  @Builder
  private BrowseOptionsSheet() {
    NextNModalScaffold({
      title: AppStrings.get('action_browse_options'),
      scroller: this.browseOptionsScroller,
      onClose: (): void => {
        this.showBrowseOptions = false
      },
    }) {
      ListItem() {
        this.BrowseOptionsPanel()
      }
    }
  }

  build() {
    GalleryCollectionBody({
      galleries: this.galleries,
      selectedGalleryId: this.homeGallerySelection.selectedGalleryId,
      presentationOverride: this.homeSource.presentationOverrideFor(this.sourceKey),
      isInitialLoading: this.isInitialLoading,
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
    .backgroundColor(ThemeTokens.SURFACE)
    .bindSheet($$this.showBrowseOptions, this.BrowseOptionsSheet(), appSheetOptions({
      detents: [SheetSize.LARGE],
      showClose: false,
    }))
  }
}

/**
 * File-global by design: ComponentV2 may lose an instance builder's `this`
 * when it is passed through RetainedSubtabHost. Each branch gets its own
 * retained component instance, Scroller, request state and load guard.
 */
@Builder
function homeSourcePageBuilder(
  key: string,
  active: ActiveKeyState,
  scroller: Scroller,
  onDidScroll: (offset: number, state: ScrollState) => void,
  onOpenGallery: (galleryId: number, seed?: NhGallerySummary) => void,
) {
  if (key === HOME_SOURCE_POPULAR) {
    PopularPage({
      sourceKey: key,
      active: active,
      scroller: scroller,
      sourceTab: true,
      onOpenGallery: onOpenGallery,
      onDidScroll: onDidScroll,
    })
  } else {
    LatestSourcePage({
      sourceKey: HOME_SOURCE_LATEST,
      active: active,
      scroller: scroller,
      onOpenGallery: onOpenGallery,
      onDidScroll: onDidScroll,
    })
  }
}

/**
 * Browse shell only coordinates source selection, native page transition and
 * the active Scroller handoff. It owns no gallery rows or pagination state.
 */
@ComponentV2
export struct HomePage {
  @Local homeSource: HomeSourceState = connectHomeSource()
  @Local visual: HomeSourceVisualIndexState = connectHomeSourceVisualIndex()
  @Local subtabTransition: SubtabTransitionState = connectSubtabTransition()
  @Local layoutMenuShown: boolean = false
  @Event onOpenGallery?: (galleryId: number, seed?: NhGallerySummary) => void
  @Event onScrollerReady?: (scroller: Scroller) => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private sourceKeys(): string[] {
    return [HOME_SOURCE_LATEST, HOME_SOURCE_POPULAR]
  }

  private selectedKey(): string {
    return this.homeSource.selectedKey === HOME_SOURCE_POPULAR
      ? HOME_SOURCE_POPULAR
      : HOME_SOURCE_LATEST
  }

  /** HDS title actions cannot anchor a Menu; the retained Home host owns it. */
  @Monitor('homeSource.layoutMenuRequestSeq')
  onLayoutMenuRequested(): void {
    if (this.homeSource.layoutMenuRequestSeq > 0) {
      this.layoutMenuShown = true
    }
  }

  /** Matches NextE's active-profile display-mode choice without changing global Browse consumers. */
  private setSourcePresentation(override: NhBrowsePresentation | null): void {
    this.layoutMenuShown = false
    const sourceKey: string = this.selectedKey()
    if (this.homeSource.presentationOverrideFor(sourceKey) === override) {
      return
    }
    // A source override only selects a mounted renderer. It deliberately
    // leaves retained snapshots, cursors, Scrollers and all global consumers
    // (Search, Favorites, History) untouched.
    HomeSourcePresentationService.setOverride(this.context(), sourceKey, override).catch((): void => {})
  }

  private activePresentationOverride(): NhBrowsePresentation | null {
    return this.homeSource.presentationOverrideFor(this.selectedKey())
  }

  @Builder
  private LayoutMenu() {
    Menu() {
      this.LayoutMenuItem(AppStrings.get('browse_follow_global'), null)
      this.LayoutMenuItem(AppStrings.get('browse_list'), NhBrowsePresentation.LIST)
      this.LayoutMenuItem(AppStrings.get('browse_simple_list'), NhBrowsePresentation.SIMPLE_LIST)
      this.LayoutMenuItem(AppStrings.get('browse_cover_grid'), NhBrowsePresentation.COVER_GRID)
      this.LayoutMenuItem(AppStrings.get('browse_waterfall'), NhBrowsePresentation.WATERFALL)
      this.LayoutMenuItem(AppStrings.get('browse_waterfall_compact'), NhBrowsePresentation.WATERFALL_COMPACT)
      this.LayoutMenuItem(AppStrings.get('browse_cover_wall'), NhBrowsePresentation.COVER_WALL)
    }
  }

  @Builder
  private LayoutMenuItem(label: string, override: NhBrowsePresentation | null) {
    MenuItem({
      content: label,
      symbolEndIcon: this.activePresentationOverride() === override
        ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
        : undefined,
    }).onClick((): void => {
      this.setSourcePresentation(override)
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      RetainedSubtabHost({
        keys: this.sourceKeys(),
        selectedKey: this.selectedKey(),
        subtabTransition: this.subtabTransition,
        transitionScope: SUBTAB_TRANSITION_SCOPE_HOME,
        pageBuilder: homeSourcePageBuilder,
        onSelectKey: (key: string): void => {
          HomeSourceBridge.select(key)
        },
        onVisualIndex: (value: number): void => {
          this.visual.value = value
        },
        onOpenGallery: (galleryId: number, seed?: NhGallerySummary): void => {
          if (this.onOpenGallery) {
            this.onOpenGallery(galleryId, seed)
          }
        },
        onScrollerReady: (scroller: Scroller): void => {
          if (this.onScrollerReady) {
            this.onScrollerReady(scroller)
          }
        },
        onDidScroll: (offset: number, state: ScrollState): void => {
          if (this.onDidScroll) {
            this.onDidScroll(offset, state)
          }
        },
      })
        .width('100%')
        .height('100%')
      // A 1vp non-hit-testable anchor lets the title-bar command open a
      // native menu without adding a visible control or changing page layout.
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
  }
}
