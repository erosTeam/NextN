import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  CatalogPreferencesService,
  CatalogPreferencesState,
  ContentFilterService,
  ContentFilterState,
  BrowsePresentationState,
  GalleryCollectionBody,
  SecondaryListScaffold,
  LayoutSafeAreaState,
  NextNPullRefreshController,
  NhApiClient,
  NhClipboardLinkService,
  NhBrowsePresentation,
  NhGalleryPageResult,
  NhGallerySummary,
  NhTagCatalogService,
  NhSearchLanguage,
  NhSearchOptions,
  NhSearchSort,
  NhSearchHistoryItem,
  NhQuickSearchItem,
  NhTagQuery,
  NhTagSuggestion,
  NextNGroupedListSection,
  NextNListRow,
  NextNModalScaffold,
  PageEmptyState,
  PageErrorState,
  PageLoadingState,
  QuickSearchRepository,
  SearchHistoryRepository,
  TagTranslationRepository,
  ThemeTokens,
  connectBrowsePresentation,
  connectCatalogPreferences,
  connectContentFilters,
  connectLayoutSafeArea,
  connectTagTranslations,
  nextNHdsTitleBar,
  TagTranslationState,
} from 'shared'
import { ComponentContent, KeyboardAvoidMode } from '@kit.ArkUI'
import { BottomBuilderShowType, HdsNavDestination, HideMode } from '@kit.UIDesignKit'
import { SearchChromeState } from '../state/SearchChromeState'
import { SEARCH_TITLE_FIELD_BOTTOM_HEIGHT, SearchTitleFieldCCBuilder } from '../components/SearchTitleField'

const SEARCH_LANGUAGES: NhSearchLanguage[] = [
  NhSearchLanguage.ALL,
  NhSearchLanguage.JAPANESE,
  NhSearchLanguage.CHINESE,
  NhSearchLanguage.ENGLISH,
  NhSearchLanguage.TRANSLATED,
]

const SEARCH_SORTS: NhSearchSort[] = [
  NhSearchSort.RECENT,
  NhSearchSort.POPULAR_TODAY,
  NhSearchSort.POPULAR_WEEK,
  NhSearchSort.POPULAR_MONTH,
  NhSearchSort.POPULAR_ALL_TIME,
]

const TAG_SUGGEST_DELAY_MS: number = 180
const TAG_SUGGESTION_LIMIT: number = 8
const MAX_TAG_SUGGESTION_PREFIX_LENGTH: number = 128

/** The final editable catalog token, kept separate from remote-search state. */
class LocalTagSuggestionInput {
  tokenStart: number = 0
  namespace: string = ''
  rawPrefix: string = ''
}

@ComponentV2
export struct SearchPage {
  @Param initialQuery: string = ''
  @Param chrome: SearchChromeState = new SearchChromeState()
  @Local query: string = ''
  @Local activeQuery: string = ''
  @Local galleries: NhGallerySummary[] = []
  /** Retains search responses so display-rule edits do not restart a search. */
  @Local rawGalleries: NhGallerySummary[] = []
  @Local contentFilters: ContentFilterState = connectContentFilters()
  @Local tagTranslations: TagTranslationState = connectTagTranslations()
  @Local browsePresentation: BrowsePresentationState = connectBrowsePresentation()
  @Local catalogPreferences: CatalogPreferencesState = connectCatalogPreferences()
  @Local isInitialLoading: boolean = false
  @Local isRefreshing: boolean = false
  @Local isLoadingMore: boolean = false
  @Local errorMessage: string = ''
  @Local loadMoreErrorMessage: string = ''
  @Local currentPage: number = 0
  @Local totalPages: number = 1
  @Local quickSearches: NhQuickSearchItem[] = []
  @Local isQuickSearchesLoaded: boolean = false
  @Local isQuickSearchMutation: boolean = false
  @Local recentSearches: NhSearchHistoryItem[] = []
  @Local isSearchHistoryLoaded: boolean = false
  @Local activeLanguageFilter: NhSearchLanguage = NhSearchLanguage.ALL
  @Local activeSearchSort: NhSearchSort = NhSearchSort.RECENT
  @Local showSearchOptions: boolean = false
  @Local tagSuggestions: NhTagSuggestion[] = []
  @Local isSuggestingTags: boolean = false
  @Param scroller: Scroller = new Scroller()
  @Event onOpenGallery?: (galleryId: number) => void
  private layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  private requestGeneration: number = 0
  private tagTranslationRefreshEpoch: number = 0
  private tagSuggestionEpoch: number = 0
  private tagSuggestionTimer: number = -1
  /** Local landing tables are read on initial entry and only after this page writes them. */
  private quickSearchesRevision: number = 0
  private loadedQuickSearchesRevision: number = -1
  private recentSearchesRevision: number = 0
  private loadedRecentSearchesRevision: number = -1
  private initialQueryConsumed: boolean = false
  private isVisible: boolean = false
  private searchOptionsScroller: Scroller = new Scroller()
  /** Independent surfaces mirror NextE: each HDS-visible search state owns its scroller. */
  private suggestionScroller: Scroller = new Scroller()
  private historyScroller: Scroller = new Scroller()
  /** One retained top-refresh owner for every committed-result presentation. */
  private refreshController: NextNPullRefreshController = new NextNPullRefreshController()
  // The HDS bottom-builder is owned by this destination, never by NavPathStack
  // params or the root navigation shell. This keeps route payloads pure and
  // prevents the title chrome from being retained by Browse after a push.
  private searchFieldContent: ComponentContent<SearchChromeState> | null = null

  aboutToAppear(): void {
    this.isVisible = true
    // Search keeps its result/history surfaces in the visible page viewport
    // while the native field owns the IME. Restore the normal page behavior
    // when this destination leaves.
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
    this.chrome.focusOnAppear = this.initialQuery.trim().length === 0
    this.loadQuickSearchesIfNeeded()
    this.loadRecentSearchesIfNeeded()
    this.consumeInitialQuery()
    // A retained Search destination may return after its local defaults were
    // changed elsewhere. Defer its one scoped reload until it is visible.
    this.reapplySearchOptions()
  }

  @Monitor('initialQuery')
  onInitialQueryChanged(): void {
    this.initialQueryConsumed = false
    this.chrome.focusOnAppear = this.initialQuery.trim().length === 0
    this.consumeInitialQuery()
  }

  @Monitor('chrome.keyword')
  onChromeKeywordChanged(): void {
    this.onSearchInputChanged(this.chrome.keyword)
  }

  @Monitor('chrome.submitVersion')
  onChromeSubmitRequested(): void {
    if (this.chrome.submitVersion > 0) {
      this.runSearch()
    }
  }

  @Monitor('chrome.filterVersion')
  onChromeFilterRequested(): void {
    if (this.chrome.filterVersion > 0) {
      this.showSearchOptions = true
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

  @Monitor('catalogPreferences.searchRevision')
  onSearchCatalogPreferencesChanged(): void {
    if (this.isVisible) {
      this.reapplySearchOptions()
    }
  }

  private applyContentFilters(): void {
    this.galleries = ContentFilterService.filterGalleries(this.rawGalleries)
  }

  /** Re-label the retained search snapshot without repeating its public query. */
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

  aboutToDisappear(): void {
    this.isVisible = false
    // A Gallery opened from a committed result only pushes over this
    // destination. Keep the request epoch intact so a first-page or paging
    // response can populate the retained Search page before Back returns.
    // Explicit query replacement/clear and direct-link navigation cancel in
    // their own actions below.
    this.cancelTagSuggestions()
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  /** A pushed tag search seeds once; returning from Gallery preserves results. */
  private consumeInitialQuery(): void {
    if (!this.isVisible || this.initialQueryConsumed) {
      return
    }
    this.initialQueryConsumed = true
    const normalized: string = this.initialQuery.trim()
    if (normalized.length === 0) {
      return
    }
    this.query = normalized
    this.chrome.keyword = normalized
    this.submitSearch(normalized)
  }

  /** Search history is supplemental: an RDB failure must never block public search. */
  private async loadRecentSearchesIfNeeded(): Promise<void> {
    const revision: number = this.recentSearchesRevision
    if (this.loadedRecentSearchesRevision === revision) {
      return
    }
    try {
      const history: NhSearchHistoryItem[] = await SearchHistoryRepository.load(this.context())
      if (this.isVisible && revision === this.recentSearchesRevision) {
        this.recentSearches = history
      }
    } catch (error) {
      console.warn(`Unable to load local search history: ${(error as Error).message}`)
    } finally {
      if (this.isVisible && revision === this.recentSearchesRevision) {
        this.isSearchHistoryLoaded = true
        this.loadedRecentSearchesRevision = revision
      }
    }
  }

  /** Quick-search pins have a dedicated table and must not follow recents. */
  private async loadQuickSearchesIfNeeded(): Promise<void> {
    const revision: number = this.quickSearchesRevision
    if (this.loadedQuickSearchesRevision === revision) {
      return
    }
    try {
      const quickSearches: NhQuickSearchItem[] = await QuickSearchRepository.load(this.context())
      if (this.isVisible && revision === this.quickSearchesRevision) {
        this.quickSearches = quickSearches
      }
    } catch (error) {
      console.warn(`Unable to load local quick searches: ${(error as Error).message}`)
    } finally {
      if (this.isVisible && revision === this.quickSearchesRevision) {
        this.isQuickSearchesLoaded = true
        this.loadedQuickSearchesRevision = revision
      }
    }
  }

  private async refreshRecentSearchesAfterWrite(): Promise<void> {
    this.recentSearchesRevision += 1
    await this.loadRecentSearchesIfNeeded()
  }

  private async refreshQuickSearchesAfterWrite(): Promise<void> {
    this.quickSearchesRevision += 1
    await this.loadQuickSearchesIfNeeded()
  }

  /** ErosN records the submitted term before the GET so failed requests remain reusable locally. */
  private async rememberSearch(query: string): Promise<void> {
    try {
      await SearchHistoryRepository.record(this.context(), query)
      await this.refreshRecentSearchesAfterWrite()
    } catch (error) {
      console.warn(`Unable to save local search history: ${(error as Error).message}`)
    }
  }

  private async removeRecentSearch(item: NhSearchHistoryItem): Promise<void> {
    try {
      await SearchHistoryRepository.remove(this.context(), item.query)
      if (this.isVisible) {
        this.recentSearches = this.recentSearches.filter((candidate: NhSearchHistoryItem): boolean =>
          candidate.query.trim().toLowerCase() !== item.query.trim().toLowerCase(),
        )
      }
      await this.refreshRecentSearchesAfterWrite()
    } catch (error) {
      console.warn(`Unable to remove local search history: ${(error as Error).message}`)
    }
  }

  /** Clearing recents intentionally never touches manually pinned quick searches. */
  private async clearRecentSearches(): Promise<void> {
    try {
      await SearchHistoryRepository.clear(this.context())
      if (this.isVisible) {
        this.recentSearches = []
      }
      await this.refreshRecentSearchesAfterWrite()
    } catch (error) {
      console.warn(`Unable to clear local search history: ${(error as Error).message}`)
    }
  }

  private quickSearchableActiveQuery(): string {
    const normalized: string = this.activeQuery.trim()
    // A non-empty editor draft deliberately preserves the old result snapshot,
    // but its HDS action must not mutate that invisible older expression. This
    // also hides the bookmark while the editor is showing a gallery-link route.
    if (
      normalized.length === 0 ||
      this.query.trim() !== normalized ||
      NhClipboardLinkService.canonicalGalleryId(normalized) > 0
    ) {
      return ''
    }
    return normalized
  }

  private isActiveQuickSearchPinned(): boolean {
    const activeQuery: string = this.quickSearchableActiveQuery()
    return activeQuery.length > 0 && this.quickSearches.some((item: NhQuickSearchItem): boolean =>
      item.query.trim().toLowerCase() === activeQuery.toLowerCase(),
    )
  }

  /** The HDS action operates only on the last committed public expression. */
  private async toggleActiveQuickSearch(): Promise<void> {
    const activeQuery: string = this.quickSearchableActiveQuery()
    if (activeQuery.length === 0 || !this.isQuickSearchesLoaded || this.isQuickSearchMutation) {
      return
    }
    this.isQuickSearchMutation = true
    try {
      if (this.isActiveQuickSearchPinned()) {
        await QuickSearchRepository.remove(this.context(), activeQuery)
      } else {
        await QuickSearchRepository.pin(this.context(), activeQuery)
      }
      await this.refreshQuickSearchesAfterWrite()
    } catch (error) {
      console.warn(`Unable to update local quick searches: ${(error as Error).message}`)
    } finally {
      this.isQuickSearchMutation = false
    }
  }

  private async removeQuickSearch(item: NhQuickSearchItem): Promise<void> {
    try {
      await QuickSearchRepository.remove(this.context(), item.query)
      if (this.isVisible) {
        this.quickSearches = this.quickSearches.filter((candidate: NhQuickSearchItem): boolean =>
          candidate.query.trim().toLowerCase() !== item.query.trim().toLowerCase(),
        )
      }
      await this.refreshQuickSearchesAfterWrite()
    } catch (error) {
      console.warn(`Unable to remove local quick search: ${(error as Error).message}`)
    }
  }

  private confirmClearRecentSearches(): void {
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('search_clear_recent_title'),
      message: AppStrings.get('search_clear_recent_message'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('common_clear'),
        fontColor: Color.Red,
        action: (): void => {
          this.clearRecentSearches()
        },
      },
    })
  }

  private async submitSearch(query: string): Promise<void> {
    this.cancelTagSuggestions()
    const galleryId: number = NhClipboardLinkService.canonicalGalleryId(query)
    if (galleryId > 0) {
      // A full public gallery URL is navigation intent, not a catalog term.
      // Do not write it into local search history or send it to /api/v2/search.
      this.openGallery(galleryId, true)
      return
    }
    await this.rememberSearch(query)
    if (!this.isVisible) {
      return
    }
    await this.loadFirstPage(query)
  }

  private isCurrentRequest(generation: number): boolean {
    return generation === this.requestGeneration
  }

  private cancelPendingSearch(): void {
    this.requestGeneration += 1
    this.isInitialLoading = false
    this.isRefreshing = false
    this.isLoadingMore = false
  }

  /** Cancels delayed local-or-catalog suggestions without affecting a submitted GET. */
  private cancelTagSuggestions(): void {
    if (this.tagSuggestionTimer >= 0) {
      clearTimeout(this.tagSuggestionTimer)
      this.tagSuggestionTimer = -1
    }
    this.tagSuggestionEpoch += 1
    this.tagSuggestions = []
    this.isSuggestingTags = false
  }

  private isWhitespace(value: string): boolean {
    return value === ' ' || value === '\n' || value === '\r' || value === '\t'
  }

  /**
   * Accepts the final namespace:prefix token or an ordinary unquoted token.
   * An unfinished quoted name remains one token so suggestions can safely
   * replace it as a whole, but it never becomes a broad online probe.
   */
  private activeTagSuggestionInput(value: string): LocalTagSuggestionInput | null {
    let tokenStart: number = 0
    let quoteOpen: boolean = false
    for (let index: number = 0; index < value.length; index++) {
      const character: string = value.charAt(index)
      if (character === '"') {
        quoteOpen = !quoteOpen
      } else if (!quoteOpen && this.isWhitespace(character)) {
        tokenStart = index + 1
      }
    }
    const token: string = value.substring(tokenStart)
    const separator: number = token.indexOf(':')
    let namespace: string = ''
    let rawPrefix: string = ''
    if (separator < 0) {
      if (quoteOpen || token.includes('"')) {
        return null
      }
      rawPrefix = token
    } else {
      if (separator === 0 || token.indexOf(':', separator + 1) >= 0) {
        return null
      }
      namespace = token.substring(0, separator).trim().toLowerCase()
      if (!/^[a-z][a-z0-9_-]{0,31}$/.test(namespace)) {
        return null
      }
      rawPrefix = token.substring(separator + 1)
      if (rawPrefix.startsWith('"')) {
        if (!quoteOpen || rawPrefix.indexOf('"', 1) >= 0) {
          return null
        }
        rawPrefix = rawPrefix.substring(1)
      } else if (quoteOpen || rawPrefix.includes('"')) {
        return null
      }
    }
    rawPrefix = rawPrefix.trim().toLowerCase()
    if (rawPrefix.length === 0 || rawPrefix.length > MAX_TAG_SUGGESTION_PREFIX_LENGTH) {
      return null
    }
    const input: LocalTagSuggestionInput = new LocalTagSuggestionInput()
    input.tokenStart = tokenStart
    input.namespace = namespace
    input.rawPrefix = rawPrefix
    return input
  }

  private matchesCurrentTagSuggestionInput(input: LocalTagSuggestionInput): boolean {
    const current: LocalTagSuggestionInput | null = this.activeTagSuggestionInput(this.query)
    return current !== null &&
      current.tokenStart === input.tokenStart &&
      current.namespace === input.namespace &&
      current.rawPrefix === input.rawPrefix
  }

  private scheduleTagSuggestions(value: string): void {
    this.cancelTagSuggestions()
    // A complete public gallery link has dedicated navigation semantics.
    // Treating its `https:` prefix as a tag namespace briefly surfaced a
    // misleading suggestion state before the direct-open submit path ran.
    if (NhClipboardLinkService.canonicalGalleryId(value) > 0) {
      return
    }
    const input: LocalTagSuggestionInput | null = this.activeTagSuggestionInput(value)
    if (input === null || !this.isVisible) {
      return
    }
    const epoch: number = this.tagSuggestionEpoch
    const context: common.UIAbilityContext = this.context()
    this.isSuggestingTags = true
    this.tagSuggestionTimer = setTimeout((): void => {
      this.tagSuggestionTimer = -1
      this.loadTagSuggestions(context, input, epoch)
    }, TAG_SUGGEST_DELAY_MS)
  }

  private async loadTagSuggestions(
    context: common.UIAbilityContext,
    input: LocalTagSuggestionInput,
    epoch: number,
  ): Promise<void> {
    try {
      let suggestions: NhTagSuggestion[] = []
      if (input.namespace.length > 0) {
        suggestions = await TagTranslationRepository.suggest(
          context,
          input.namespace,
          input.rawPrefix,
          TAG_SUGGESTION_LIMIT,
        )
      } else {
        suggestions = await TagTranslationRepository.suggestUnscoped(
          context,
          input.rawPrefix,
          TAG_SUGGESTION_LIMIT,
        )
      }
      if (
        !this.isVisible ||
        epoch !== this.tagSuggestionEpoch ||
        !this.matchesCurrentTagSuggestionInput(input)
      ) {
        return
      }
      // The optional on-device dictionary remains first choice. ErosN's
      // catalog endpoint accepts English only, so a pure CJK token returns
      // local translated matches without issuing five pointless probes.
      if (suggestions.length < TAG_SUGGESTION_LIMIT && !this.isPureCjk(input.rawPrefix)) {
        const remoteSuggestions: NhTagSuggestion[] = await NhApiClient.tagSuggestions(
          input.namespace,
          input.rawPrefix,
          TAG_SUGGESTION_LIMIT - suggestions.length,
        )
        suggestions = this.mergeTagSuggestions(suggestions, remoteSuggestions)
      }
      if (
        !this.isVisible ||
        epoch !== this.tagSuggestionEpoch ||
        !this.matchesCurrentTagSuggestionInput(input)
      ) {
        return
      }
      this.tagSuggestions = suggestions
    } catch (_error) {
      if (this.isVisible && epoch === this.tagSuggestionEpoch) {
        this.tagSuggestions = []
      }
      console.warn('Unable to load local tag suggestions.')
    } finally {
      if (this.isVisible && epoch === this.tagSuggestionEpoch) {
        this.isSuggestingTags = false
      }
    }
  }

  private onSearchInputChanged(value: string): void {
    if (value === this.query) {
      return
    }
    this.query = value
    const normalized: string = value.trim()
    if (normalized.length === 0) {
      // Clearing the editor intentionally returns to the search landing state.
      // This is distinct from an in-progress non-empty draft, which must keep
      // the last submitted rows available until the user submits a replacement.
      this.clearSubmittedSearchState()
      this.cancelTagSuggestions()
      return
    }
    if (normalized === this.activeQuery) {
      // Returning to the submitted expression restores its snapshot without a
      // redundant local/remote autocomplete pass.
      this.cancelTagSuggestions()
      return
    }
    this.preserveResultSnapshotForDraftChange()
    this.scheduleTagSuggestions(value)
  }

  private isPureCjk(value: string): boolean {
    const hasCjk: boolean = /[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff66-\uff9f]/.test(value)
    return hasCjk && !/[A-Za-z0-9]/.test(value)
  }

  private mergeTagSuggestions(
    localSuggestions: NhTagSuggestion[],
    remoteSuggestions: NhTagSuggestion[],
  ): NhTagSuggestion[] {
    const merged: NhTagSuggestion[] = []
    const seen: Set<string> = new Set<string>()
    const candidates: NhTagSuggestion[] = localSuggestions.concat(remoteSuggestions)
    for (let index: number = 0; index < candidates.length && merged.length < TAG_SUGGESTION_LIMIT; index++) {
      const suggestion: NhTagSuggestion = candidates[index]
      const key: string = `${suggestion.namespace}\u001f${suggestion.rawName.toLowerCase()}`
      if (suggestion.namespace.length === 0 || suggestion.rawName.length === 0 || seen.has(key)) {
        continue
      }
      seen.add(key)
      merged.push(suggestion)
    }
    return merged
  }

  private acceptTagSuggestion(suggestion: NhTagSuggestion): void {
    const input: LocalTagSuggestionInput | null = this.activeTagSuggestionInput(this.query)
    const replacement: string = NhTagQuery.formatExact(suggestion.namespace, suggestion.rawName)
    if (input === null || replacement.length === 0) {
      this.cancelTagSuggestions()
      return
    }
    this.preserveResultSnapshotForDraftChange()
    this.query = `${this.query.substring(0, input.tokenStart)}${replacement}`
    this.chrome.keyword = this.query
    this.cancelTagSuggestions()
    this.recordAcceptedTagSuggestion(suggestion)
  }

  private async recordAcceptedTagSuggestion(suggestion: NhTagSuggestion): Promise<void> {
    try {
      await TagTranslationRepository.touchSuggestion(this.context(), suggestion.namespace, suggestion.rawName)
    } catch (_error) {
      console.warn('Unable to save local tag suggestion usage.')
    }
  }

  /**
   * Keeps usable rows from the last submitted request visible while the title
   * field contains a new non-empty draft. A request in flight is still
   * invalidated so an old response cannot merge after the draft changed.
  */
  private preserveResultSnapshotForDraftChange(): void {
    if (this.rawGalleries.length === 0) {
      this.clearSubmittedSearchState()
      return
    }
    this.cancelPendingSearch()
    this.errorMessage = ''
    this.loadMoreErrorMessage = ''
  }

  /** Clears the committed snapshot only for an explicit empty-input action. */
  private clearSubmittedSearchState(): void {
    this.cancelPendingSearch()
    this.activeQuery = ''
    this.rawGalleries = []
    this.applyContentFilters()
    this.currentPage = 0
    this.totalPages = 1
    this.errorMessage = ''
    this.loadMoreErrorMessage = ''
  }

  /**
   * Result-card navigation is a transient push and must retain its committed
   * request epoch. A direct gallery URL replaces the editor's search intent,
   * so that explicit route does invalidate outstanding catalog work.
   */
  private openGallery(galleryId: number, replacesSearchIntent: boolean = false): void {
    if (replacesSearchIntent) {
      this.cancelPendingSearch()
    }
    this.cancelTagSuggestions()
    if (this.onOpenGallery) {
      this.onOpenGallery(galleryId)
    }
  }

  private async runSearch(): Promise<void> {
    this.cancelTagSuggestions()
    const normalized: string = this.query.trim()
    if (normalized.length === 0) {
      this.clearSubmittedSearchState()
      this.errorMessage = AppStrings.get('search_enter_term')
      return
    }
    const galleryId: number = NhClipboardLinkService.canonicalGalleryId(normalized)
    if (galleryId > 0) {
      // Keep the visible field intact for a Back navigation, while opening the
      // resolved Gallery directly without creating a public search request.
      this.openGallery(galleryId, true)
      return
    }
    await this.rememberSearch(normalized)
    if (!this.isVisible) {
      return
    }
    if (normalized === this.activeQuery && this.currentPage > 0) {
      await this.refresh()
      return
    }
    await this.loadFirstPage(normalized)
  }

  private openRecentSearch(query: string): void {
    this.query = query
    this.chrome.keyword = query
    this.runSearch()
  }

  /** Quick-search taps intentionally reuse the normal submit and result flow. */
  private openQuickSearch(query: string): void {
    this.openRecentSearch(query)
  }

  private canLoadMore(): boolean {
    return this.activeQuery.length > 0 &&
      this.currentPage > 0 &&
      this.currentPage < this.totalPages &&
      !this.isInitialLoading &&
      !this.isRefreshing &&
      !this.isLoadingMore &&
      this.loadMoreErrorMessage.length === 0
  }

  private canRetryLoadMore(): boolean {
    return this.activeQuery.length > 0 &&
      this.currentPage > 0 &&
      this.currentPage < this.totalPages &&
      !this.isInitialLoading &&
      !this.isRefreshing &&
      !this.isLoadingMore
  }

  private async loadFirstPage(query: string): Promise<void> {
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    this.activeQuery = query
    this.activeLanguageFilter = this.catalogPreferences.searchLanguage
    this.activeSearchSort = this.catalogPreferences.searchSort
    this.isInitialLoading = true
    this.isRefreshing = false
    this.isLoadingMore = false
    this.rawGalleries = []
    this.applyContentFilters()
    this.currentPage = 0
    this.totalPages = 1
    this.errorMessage = ''
    this.loadMoreErrorMessage = ''
    try {
      const result: NhGalleryPageResult = await this.requestSearch(
        query,
        1,
        this.activeLanguageFilter,
        this.activeSearchSort,
      )
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.rawGalleries = result.galleries
      this.applyContentFilters()
      this.currentPage = 1
      this.totalPages = Math.max(1, result.totalPages)
    } catch (error) {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.errorMessage = (error as Error).message || AppStrings.get('search_failed')
    } finally {
      if (this.isCurrentRequest(generation)) {
        this.isInitialLoading = false
      }
    }
  }

  /** Refreshes the submitted query without blanking already usable rows. */
  private async refresh(force: boolean = false): Promise<void> {
    if (this.activeQuery.length === 0 || this.isInitialLoading || (!force && this.isRefreshing)) {
      return
    }
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    this.activeLanguageFilter = this.catalogPreferences.searchLanguage
    this.activeSearchSort = this.catalogPreferences.searchSort
    this.isLoadingMore = false
    const keepsContent: boolean = this.rawGalleries.length > 0
    this.errorMessage = ''
    this.loadMoreErrorMessage = ''
    if (keepsContent) {
      this.isRefreshing = true
    } else {
      this.isInitialLoading = true
    }
    try {
      const result: NhGalleryPageResult = await this.requestSearch(
        this.activeQuery,
        1,
        this.activeLanguageFilter,
        this.activeSearchSort,
      )
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.rawGalleries = result.galleries
      this.applyContentFilters()
      this.currentPage = 1
      this.totalPages = Math.max(1, result.totalPages)
    } catch (error) {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.errorMessage = (error as Error).message || AppStrings.get('search_failed')
    } finally {
      if (this.isCurrentRequest(generation)) {
        this.isInitialLoading = false
        this.isRefreshing = false
      }
    }
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
      const result: NhGalleryPageResult = await this.requestSearch(
        this.activeQuery,
        nextPage,
        this.activeLanguageFilter,
        this.activeSearchSort,
      )
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.appendUnique(result.galleries)
      this.currentPage = nextPage
      this.totalPages = Math.max(nextPage, result.totalPages)
    } catch (error) {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.loadMoreErrorMessage = (error as Error).message || AppStrings.get('search_load_more_failed')
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
    // Keep passive reach-end blocked by the visible error. An explicit footer
    // retry clears that one paging error before entering the ordinary gate.
    this.loadMoreErrorMessage = ''
    this.loadMore()
  }

  /**
   * Pagination uses the active option snapshot, not live controls. A filter
   * edit starts a new generation through refresh, so a stale page can never
   * merge into results from a different request target.
   */
  private requestSearch(
    query: string,
    page: number,
    language: NhSearchLanguage,
    sort: NhSearchSort,
  ): Promise<NhGalleryPageResult> {
    return NhApiClient.search(
      NhSearchOptions.queryWithLanguage(query, language),
      page,
      NhSearchOptions.sortValue(sort),
    )
  }

  private selectLanguage(option: NhSearchLanguage): void {
    if (this.catalogPreferences.searchLanguage === option) {
      return
    }
    CatalogPreferencesService.setSearchLanguage(this.context(), option).catch((): void => {})
  }

  private selectSort(option: NhSearchSort): void {
    if (this.catalogPreferences.searchSort === option) {
      return
    }
    CatalogPreferencesService.setSearchSort(this.context(), option).catch((): void => {})
  }

  private searchPreferencesChanged(): boolean {
    return this.activeLanguageFilter !== this.catalogPreferences.searchLanguage ||
      this.activeSearchSort !== this.catalogPreferences.searchSort
  }

  /** A local default edit reloads the active public query without changing its raw text. */
  private reapplySearchOptions(): void {
    if (this.activeQuery.length === 0 || !this.searchPreferencesChanged()) {
      return
    }
    if (this.isInitialLoading) {
      this.loadFirstPage(this.activeQuery)
    } else {
      this.refresh(true)
    }
  }

  private hasTagSuggestionSurface(): boolean {
    return this.isSuggestingTags || this.tagSuggestions.length > 0
  }

  private directGalleryId(): number {
    return NhClipboardLinkService.canonicalGalleryId(this.query)
  }

  private openRecognizedGalleryLink(): void {
    const galleryId: number = this.directGalleryId()
    if (galleryId > 0) {
      // Recognition is navigation-only: do not record the URL as search
      // history and do not send it to the public catalog endpoint.
      this.openGallery(galleryId, true)
    }
  }

  /**
   * NextE promotes a recognized gallery URL to one explicit navigation row as
   * soon as the field is edited. Reuse the suggestion scroller so HDS chrome,
   * safe-area reserve, and Back behavior remain identical to tag suggestions.
   */
  @Builder
  private DirectGalleryLinkView() {
    SecondaryListScaffold({
      scroller: this.suggestionScroller,
      listSpace: ThemeTokens.SPACE_XS,
      topPadding: SEARCH_TITLE_FIELD_BOTTOM_HEIGHT,
      bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
      alwaysEnableEdgeSpring: true,
      backToTop: false,
    }) {
      ListItem() {
        Row({ space: ThemeTokens.SPACE_MD }) {
          SymbolGlyph($r('sys.symbol.link'))
            .fontSize(24)
            .fontColor([ThemeTokens.BRAND])
          Column({ space: ThemeTokens.SPACE_XS }) {
            Text(AppStrings.get('search_open_gallery_link'))
              .fontSize(ThemeTokens.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeTokens.TEXT_PRIMARY)
              .maxLines(1)
            Text(this.query.trim())
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          SymbolGlyph($r('sys.symbol.arrow_right'))
            .fontSize(ThemeTokens.FONT_SIZE_HEADING)
            .fontColor([ThemeTokens.TEXT_TERTIARY])
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({
          left: ThemeTokens.SPACE_LG,
          right: ThemeTokens.SPACE_LG,
          top: ThemeTokens.SPACE_SM,
          bottom: ThemeTokens.SPACE_SM,
        })
        .accessibilityText(AppStrings.get('search_open_gallery_link'))
        .onClick((): void => {
          this.openRecognizedGalleryLink()
        })
      }
    }
  }

  /**
   * Suggestions are a first-class input state, never a short Column placed
   * above a second page state. This mirrors NextE's dedicated suggestion
   * scroller and keeps the first row below the immersive HDS search field.
   */
  @Builder
  private SearchSuggestionsView() {
    SecondaryListScaffold({
      scroller: this.suggestionScroller,
      listSpace: ThemeTokens.SPACE_XS,
      topPadding: SEARCH_TITLE_FIELD_BOTTOM_HEIGHT,
      bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
      alwaysEnableEdgeSpring: true,
      backToTop: false,
    }) {
      ListItem() {
        Row({ space: ThemeTokens.SPACE_SM }) {
          Text(AppStrings.get('search_tag_suggestions'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .layoutWeight(1)
          if (this.isSuggestingTags) {
            Text(AppStrings.get('search_looking_suggestions'))
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ top: ThemeTokens.SPACE_SM, bottom: ThemeTokens.SPACE_SM })
      }
      ForEach(this.tagSuggestions, (suggestion: NhTagSuggestion): void => {
        ListItem() {
          NextNListRow({
            leadingIcon: $r('sys.symbol.magnifyingglass'),
            title: suggestion.displayName,
            subtitle: `${suggestion.namespace}: ${suggestion.rawName}`,
            showChevron: false,
            accessibilityLabel: AppStrings.get('search_use_tag_suggestion'),
            onAction: (): void => {
              this.acceptTagSuggestion(suggestion)
            },
          })
        }
      }, (suggestion: NhTagSuggestion): string => `${suggestion.namespace}\u001f${suggestion.rawName}`)
      // Keep the original input runnable even while autocomplete is visible.
      // ErosN exposes this explicit action after matching tags so choosing a
      // suggestion never becomes the only way to leave the suggestion state.
      if (this.query.trim().length > 0) {
        ListItem() {
          NextNListRow({
            leadingIcon: $r('sys.symbol.magnifyingglass'),
            title: AppStrings.format('search_submit_query', [this.query.trim()]),
            showChevron: false,
            accessibilityLabel: AppStrings.format('search_submit_query', [this.query.trim()]),
            onAction: (): void => {
              this.runSearch()
            },
          })
        }
      }
    }
  }

  @Builder
  private SearchOptionsPanel() {
    Column({ space: ThemeTokens.SPACE_MD }) {
      Text(AppStrings.get('browse_section_language'))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
      NextNGroupedListSection() {
        ForEach(SEARCH_LANGUAGES, (option: NhSearchLanguage): void => {
          NextNListRow({
            title: NhSearchOptions.languageLabel(option),
            trailingText: this.catalogPreferences.searchLanguage === option ? AppStrings.get('common_selected') : '',
            showChevron: false,
            accessibilityLabel: AppStrings.format('browse_select_language', [NhSearchOptions.languageLabel(option)]),
            onAction: (): void => {
              this.selectLanguage(option)
            },
          })
          if (option !== SEARCH_LANGUAGES[SEARCH_LANGUAGES.length - 1]) {
            this.SearchOptionDivider()
          }
        }, (option: NhSearchLanguage): string => option)
      }
      Text(AppStrings.get('browse_section_order'))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
      NextNGroupedListSection() {
        ForEach(SEARCH_SORTS, (option: NhSearchSort): void => {
          NextNListRow({
            title: NhSearchOptions.sortLabel(option),
            trailingText: this.catalogPreferences.searchSort === option ? AppStrings.get('common_selected') : '',
            showChevron: false,
            accessibilityLabel: AppStrings.format('browse_select_order', [NhSearchOptions.sortLabel(option)]),
            onAction: (): void => {
              this.selectSort(option)
            },
          })
          if (option !== SEARCH_SORTS[SEARCH_SORTS.length - 1]) {
            this.SearchOptionDivider()
          }
        }, (option: NhSearchSort): string => option)
      }
      Text(AppStrings.get('search_options_hint'))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
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
  private SearchOptionDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(ThemeTokens.DIVIDER)
      .margin({ left: ThemeTokens.SPACE_MD })
  }

  @Builder
  private SearchOptionsSheet() {
    NextNModalScaffold({
      title: AppStrings.get('title_search_options'),
      scroller: this.searchOptionsScroller,
      onClose: (): void => {
        this.showSearchOptions = false
      },
    }) {
      ListItem() {
        this.SearchOptionsPanel()
      }
    }
  }

  @Builder
  private QuickSearchesPanel() {
    if (this.isQuickSearchesLoaded && this.quickSearches.length > 0) {
      Column() {
        Text(AppStrings.get('search_quick'))
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .width('100%')
          .padding({ bottom: ThemeTokens.SPACE_SM })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.quickSearches, (item: NhQuickSearchItem): void => {
            Row({ space: ThemeTokens.SPACE_XS }) {
              Text(item.query)
                .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                .fontColor(ThemeTokens.TEXT_PRIMARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
                .accessibilityText(AppStrings.format('search_quick_item_a11y', [item.query]))
                .onClick((): void => {
                  this.openQuickSearch(item.query)
                })
              Button({ type: ButtonType.Circle, stateEffect: true }) {
                SymbolGlyph($r('sys.symbol.xmark'))
                  .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                  .fontColor([ThemeTokens.TEXT_SECONDARY])
              }
              .width(28)
              .height(28)
              .backgroundColor(Color.Transparent)
              .padding(0)
              .accessibilityText(AppStrings.format('search_remove_quick_item_a11y', [item.query]))
              .onClick((): void => {
                this.removeQuickSearch(item)
              })
            }
              .height(28)
              .constraintSize({ maxWidth: '90%' })
              .backgroundColor(ThemeTokens.CARD_BACKGROUND)
              .borderRadius(ThemeTokens.RADIUS_ROUND)
              .padding({
                left: ThemeTokens.SPACE_MD,
                right: ThemeTokens.SPACE_XS,
              })
              .margin({ right: ThemeTokens.SPACE_SM, bottom: ThemeTokens.SPACE_SM })
              .gesture(
                LongPressGesture({ repeat: false, duration: 500 })
                  .onAction((): void => {
                    this.removeQuickSearch(item)
                  }),
              )
          }, (item: NhQuickSearchItem): string => item.query.toLowerCase())
        }
        .width('100%')
      }
      .width('100%')
    }
  }

  private hasSearchLandingContent(): boolean {
    return (this.isQuickSearchesLoaded && this.quickSearches.length > 0) ||
      (this.isSearchHistoryLoaded && this.recentSearches.length > 0)
  }

  @Builder
  private RecentSearchesPanel() {
    if (this.isSearchHistoryLoaded && this.recentSearches.length > 0) {
      Column() {
        Row() {
          Text(AppStrings.get('search_recent'))
            .fontSize(ThemeTokens.FONT_SIZE_BODY)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
          Blank()
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(ThemeTokens.SECTION_ICON_SIZE)
              .fontColor([ThemeTokens.TEXT_SECONDARY])
          }
          .width(ThemeTokens.MIN_TOUCH_TARGET)
          .height(ThemeTokens.MIN_TOUCH_TARGET)
          .backgroundColor(Color.Transparent)
          .padding(0)
          .accessibilityText(AppStrings.get('search_clear_recent_a11y'))
          .onClick((): void => {
            this.confirmClearRecentSearches()
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ bottom: ThemeTokens.SPACE_SM })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.recentSearches, (item: NhSearchHistoryItem): void => {
            Row({ space: ThemeTokens.SPACE_XS }) {
              Text(item.query)
                .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                .fontColor(ThemeTokens.TEXT_PRIMARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
                .accessibilityText(AppStrings.format('search_recent_item_a11y', [item.query]))
                .onClick((): void => {
                  this.openRecentSearch(item.query)
                })
              Button({ type: ButtonType.Circle, stateEffect: true }) {
                SymbolGlyph($r('sys.symbol.xmark'))
                  .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                  .fontColor([ThemeTokens.TEXT_SECONDARY])
              }
              .width(28)
              .height(28)
              .backgroundColor(Color.Transparent)
              .padding(0)
              .accessibilityText(AppStrings.format('search_remove_recent_item_a11y', [item.query]))
              .onClick((): void => {
                this.removeRecentSearch(item)
              })
            }
              .height(28)
              .constraintSize({ maxWidth: '90%' })
              .backgroundColor(ThemeTokens.CARD_BACKGROUND)
              .borderRadius(ThemeTokens.RADIUS_ROUND)
              .padding({
                left: ThemeTokens.SPACE_MD,
                right: ThemeTokens.SPACE_XS,
              })
              .margin({ right: ThemeTokens.SPACE_SM, bottom: ThemeTokens.SPACE_SM })
              .gesture(
                LongPressGesture({ repeat: false, duration: 500 })
                  .onAction((): void => {
                    this.removeRecentSearch(item)
                  }),
              )
          }, (item: NhSearchHistoryItem): string => item.query.toLowerCase())
        }
        .width('100%')
      }
      .width('100%')
    }
  }

  @Builder
  private SearchGuide() {
    if (this.hasSearchLandingContent()) {
      // Both local surfaces can be longer than a phone's remaining viewport.
      // Keep pinned Quick searches before recents in one scroll-backed landing
      // surface rather than allowing either list to squeeze below HDS chrome.
      Scroll(this.historyScroller) {
        Column({ space: ThemeTokens.SPACE_SM }) {
          if (this.errorMessage.length > 0) {
            Column({ space: ThemeTokens.SPACE_SM }) {
              Text(this.errorMessage)
                .fontSize(ThemeTokens.FONT_SIZE_TITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeTokens.TEXT_PRIMARY)
                .textAlign(TextAlign.Center)
              Text(AppStrings.get('search_guide'))
                .fontSize(ThemeTokens.FONT_SIZE_BODY)
                .fontColor(ThemeTokens.TEXT_SECONDARY)
                .textAlign(TextAlign.Center)
                .maxLines(3)
            }
            .width('100%')
            .padding({ bottom: ThemeTokens.SPACE_XL })
          }
          this.QuickSearchesPanel()
          this.RecentSearchesPanel()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        // Search has its own pinned title-bar field. Unlike a root Browse
        // full-pane state, its landing/history content must begin below the
        // status/title/field stack; this mirrors NextE GallerySearchPage's
        // SearchHistoryView geometry and prevents history or guidance from
        // rendering underneath HDS chrome.
        .padding({
          left: ThemeTokens.SPACE_XL,
          right: ThemeTokens.SPACE_XL,
          top: this.searchGuideTopPadding(),
          bottom: this.layoutSafeArea.bottomAvoidHeight + ThemeTokens.SPACE_XL,
        })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    } else {
      Column({ space: ThemeTokens.SPACE_SM }) {
        Text(this.errorMessage.length > 0 ? this.errorMessage : AppStrings.get('search_find_something'))
          .fontSize(ThemeTokens.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .textAlign(TextAlign.Center)
        Text(AppStrings.get('search_guide'))
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
          .maxLines(3)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({
        left: ThemeTokens.SPACE_XL,
        right: ThemeTokens.SPACE_XL,
        top: this.searchGuideTopPadding(),
        bottom: this.layoutSafeArea.bottomAvoidHeight + ThemeTokens.SPACE_XL,
      })
    }
  }

  private searchGuideTopPadding(): number {
    return this.layoutSafeArea.topAvoidHeight +
      ThemeTokens.TITLE_BAR_HEIGHT +
      SEARCH_TITLE_FIELD_BOTTOM_HEIGHT +
      ThemeTokens.SPACE_MD
  }

  /**
   * Result pagination and its summary share the active request snapshot,
   * rather than live editor values which may be waiting for a replacement.
   */
  private hasActiveSearchOptions(): boolean {
    return this.activeLanguageFilter !== NhSearchLanguage.ALL ||
      this.activeSearchSort !== NhSearchSort.RECENT
  }

  @Builder
  private SearchResultOptionsSummary() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.funnel'),
        title: NhSearchOptions.languageLabel(this.activeLanguageFilter),
        subtitle: NhSearchOptions.sortLabel(this.activeSearchSort),
        accessibilityLabel: AppStrings.get('title_search_options'),
        onAction: (): void => {
          this.showSearchOptions = true
        },
      })
    }
  }

  /**
   * The single shared collection parent owns its four collection renderers.
   * Search contributes only its committed options snapshot, wrapped in the
   * primitive required by the active renderer so the common parent can keep
   * the row index and full-row accounting correct.
   */
  @Builder
  private SearchCollectionLeadingContent() {
    if (this.hasActiveSearchOptions()) {
      if (this.browsePresentation.mode === NhBrowsePresentation.COVER_GRID) {
        GridItem() {
          this.SearchResultOptionsSummary()
        }
      } else if (
        this.browsePresentation.mode === NhBrowsePresentation.WATERFALL ||
        this.browsePresentation.mode === NhBrowsePresentation.WATERFALL_COMPACT ||
        this.browsePresentation.mode === NhBrowsePresentation.COVER_WALL
      ) {
        FlowItem() {
          this.SearchResultOptionsSummary()
        }
      } else {
        ListItem() {
          this.SearchResultOptionsSummary()
        }
      }
    }
  }

  private ensureSearchFieldContent(): ComponentContent<SearchChromeState> {
    let content: ComponentContent<SearchChromeState> | null = this.searchFieldContent
    if (content === null) {
      content = new ComponentContent<SearchChromeState>(
        this.getUIContext(),
        wrapBuilder<[SearchChromeState]>(SearchTitleFieldCCBuilder),
        this.chrome,
      )
      this.searchFieldContent = content
    }
    return content
  }

  private searchTitleBar(): Record<string, Object> {
    const title: Record<string, Object> = { 'mainTitle': AppStrings.get('title_search') }
    const filterAction: Record<string, Object> = {
      'label': AppStrings.get('title_search_options'),
      'icon': $r('sys.symbol.funnel'),
      'isEnabled': true,
      'action': (): void => {
        this.chrome.filterVersion += 1
      },
    }
    const filterMenuItem: Record<string, Object> = { 'content': filterAction }
    const menuItems: Record<string, Object>[] = [filterMenuItem]
    const quickSearchQuery: string = this.quickSearchableActiveQuery()
    if (this.isQuickSearchesLoaded && quickSearchQuery.length > 0) {
      const isPinned: boolean = this.isActiveQuickSearchPinned()
      const quickSearchAction: Record<string, Object> = {
        'label': isPinned
          ? AppStrings.format('search_remove_quick_a11y', [quickSearchQuery])
          : AppStrings.format('search_add_quick_a11y', [quickSearchQuery]),
        'icon': isPinned
          ? $r('sys.symbol.bookmark_fill')
          : $r('sys.symbol.bookmark'),
        'isEnabled': !this.isQuickSearchMutation,
        'action': (): void => {
          this.toggleActiveQuickSearch()
        },
      }
      menuItems.push({ 'content': quickSearchAction })
    }
    const menu: Record<string, Object> = { 'value': menuItems, 'maxCount': menuItems.length }
    const bottomBuilder: Record<string, Object> = {
      'builderComponent': this.ensureSearchFieldContent(),
      'height': SEARCH_TITLE_FIELD_BOTTOM_HEIGHT,
      'showType': BottomBuilderShowType.DIRECTLY_SHOW,
    }
    return nextNHdsTitleBar({ 'title': title, 'menu': menu, 'bottomBuilder': bottomBuilder })
  }

  build() {
    HdsNavDestination() {
      Column() {
      if (this.isInitialLoading && this.galleries.length === 0) {
        PageLoadingState({ text: AppStrings.get('search_loading') })
      } else if (this.directGalleryId() > 0) {
        this.DirectGalleryLinkView()
      } else if (this.hasTagSuggestionSurface()) {
        this.SearchSuggestionsView()
      } else if (this.activeQuery.length === 0) {
        this.SearchGuide()
      } else if (this.errorMessage.length > 0 && this.galleries.length === 0) {
        PageErrorState({
          message: this.errorMessage,
          onRetry: (): void => {
            this.runSearch()
          },
        })
      } else if (this.galleries.length === 0) {
        PageEmptyState({ message: AppStrings.get('search_empty') })
      } else {
        GalleryCollectionBody({
          galleries: this.galleries,
          isInitialLoading: this.isInitialLoading,
          isRefreshing: this.isRefreshing,
          isLoadingMore: this.isLoadingMore,
          canLoadMore: this.canLoadMore(),
          errorMessage: this.errorMessage,
          loadMoreErrorMessage: this.loadMoreErrorMessage,
          loadingMessage: AppStrings.get('search_loading'),
          emptyMessage: AppStrings.get('search_empty'),
          footerLoadingText: AppStrings.get('search_footer_loading'),
          footerAvailableText: AppStrings.get('search_footer_available'),
          footerCompleteText: AppStrings.get('search_footer_complete'),
          footerIdleText: this.currentPage > 0
            ? AppStrings.format('common_page_of', [this.currentPage.toString(), this.totalPages.toString()])
            : '',
          footerRetryLabel: AppStrings.get('common_try_loading_again'),
          topPadding: SEARCH_TITLE_FIELD_BOTTOM_HEIGHT,
          bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
          leadingItemCount: this.hasActiveSearchOptions() ? 1 : 0,
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
          onOpenGallery: (galleryId: number): void => {
            this.openGallery(galleryId)
          },
        }) {
          this.SearchCollectionLeadingContent()
        }
      }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeTokens.SURFACE)
      .bindSheet($$this.showSearchOptions, this.SearchOptionsSheet(), {
        detents: [SheetSize.LARGE],
        showClose: false,
      })
    }
    .titleBar(this.searchTitleBar())
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideBottomBuilder: false,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP,
    })
    .hideBackButton(false)
    .bindToScrollable([this.scroller, this.suggestionScroller, this.historyScroller])
  }
}
