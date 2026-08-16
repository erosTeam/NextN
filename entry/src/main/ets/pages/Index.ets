import { HomePage, PopularPage } from 'home'
import {
  GalleryChromeState,
  GalleryCommentsPage,
  GalleryDetailPage,
  GalleryThumbnailsChromeState,
  GalleryThumbnailsPage,
} from 'gallery'
import {
  SearchChromeState,
  SearchPage,
} from 'search'
import { ReaderPage } from 'reader'
import {
  BrowserSessionPage,
  FavoritesPage,
  HistoryPage,
  HistoryPinnedDayHeaderCCBuilder,
  HistoryPinnedDayHeaderState,
  HISTORY_PINNED_DAY_HEADER_HEIGHT,
  connectHistoryPinnedDayHeader,
} from 'user'
import {
  DownloadPinnedGroupHeaderCCBuilder,
  DownloadPinnedGroupHeaderState,
  DownloadQueuePage,
  DOWNLOAD_PINNED_GROUP_HEADER_HEIGHT,
  connectDownloadPinnedGroupHeader,
} from 'download'
import {
  AboutPage,
  AccountPage,
  BrowseDensitySettingsPage,
  CommentTranslationSettingsPage,
  ComicTranslationSettingsPage,
  LlmSourceDetailPage,
  LlmSourceManagerPage,
  MangaRenderingServiceSettingsPage,
  ContentFiltersPage,
  ReaderSuperResolutionModelsPage,
  SettingsPage,
  SettingsSurface,
  SyncSettingsPage,
  TagTranslationSettingsPage,
  WebDavSyncSettingsPage,
} from 'settings'
import { common } from '@kit.AbilityKit'
import {
  HdsNavDestination,
  HdsNavigation,
  HdsAnimationMode,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  BottomBuilderShowType,
  HideMode,
} from '@kit.UIDesignKit'
import { ComponentContent, window } from '@kit.ArkUI'
import {
  nextNHdsTitle,
  nextNHdsTitleBar,
  AppStrings,
  GalleryDirectLaunchState,
  LayoutSafeAreaBridge,
  LayoutSafeAreaState,
  LoginRecoveryLaunchState,
  DownloadQueueActionBridge,
  DownloadQueueActionState,
  FavoritesActionBridge,
  FavoritesActionState,
  HomeGallerySelectionState,
  HomeSourceBridge,
  HomeSourceState,
  HomeTabAutoHideState,
  LLM_CONSUMER_COMMENT_TRANSLATION,
  LLM_CONSUMER_MANGA_TRANSLATION,
  ImmersiveMaterialSettings,
  ImmersiveMaterialSettingsState,
  LlmConsumerBinding,
  LlmSourceProfilesState,
  HOME_SOURCE_LATEST,
  HOME_SOURCE_SELECTOR_HEIGHT,
  TabletLayoutSettings,
  TabletLayoutState,
  ThemeDisplayState,
  connectGalleryDirectLaunch,
  connectLayoutSafeArea,
  connectLoginRecoveryLaunch,
  connectDownloadQueueActions,
  connectFavoritesActions,
  connectHomeGallerySelection,
  connectHomeSource,
  connectHomeTabAutoHide,
  connectImmersiveMaterialSettings,
  connectLlmSourceProfiles,
  connectTabletLayout,
  connectThemeDisplay,
  NhArkWebSessionTransportHost,
  NhBrowsePresentation,
  NhComment,
  NhDownloadTaskStatus,
  NhApiClient,
  NhGalleryPage,
  NhGallerySummary,
  ReaderOverlayNavigationState,
  SettingsNavigationState,
  ReaderRouteParams,
  NhClipboardLinkState,
  RootRefreshRegistry,
  ThemeTokens,
  connectReaderOverlayNavigation,
  connectSettingsNavigation,
  clearNhClipboardGalleryCandidate,
  connectNhClipboardLink,
} from 'shared'
import { HomeSourceBarCCBuilder } from '../components/HomeSourceBar'
import { MainTabIcon } from '../components/MainTabIcon'

const ROUTE_SEARCH: string = 'search'
const ROUTE_POPULAR: string = 'popular'
const ROUTE_GALLERY: string = 'gallery'
const ROUTE_THUMBNAILS: string = 'thumbnails'
const ROUTE_COMMENTS: string = 'comments'
const ROUTE_READER: string = 'Reader'
const ROUTE_READER_OVERLAY_BACKDROP: string = 'ReaderOverlayBackdrop'
const ROUTE_BROWSER_SESSION: string = 'browserSession'
const ROUTE_ACCOUNT: string = 'account'
const ROUTE_SYNC_SETTINGS: string = 'syncSettings'
const ROUTE_WEBDAV_SYNC_SETTINGS: string = 'webDavSyncSettings'
const ROUTE_LAYOUT_SETTINGS: string = 'layoutSettings'
const ROUTE_BROWSE_SETTINGS: string = 'browseSettings'
const ROUTE_SEARCH_SETTINGS: string = 'searchSettings'
const ROUTE_BROWSE_DENSITY_SETTINGS: string = 'browseDensitySettings'
const ROUTE_CONTENT_FILTERS: string = 'contentFilters'
const ROUTE_HISTORY: string = 'history'
const ROUTE_READER_SETTINGS: string = 'readerSettings'
const ROUTE_READER_SUPER_RESOLUTION_MODELS: string = 'readerSuperResolutionModels'
const ROUTE_LLM_SOURCE_MANAGER: string = 'llmSourceManager'
const ROUTE_LLM_SOURCE_DETAIL: string = 'llmSourceDetail'
const ROUTE_MANGA_RENDERING_SERVICE: string = 'mangaRenderingService'
const ROUTE_DOWNLOAD_SETTINGS: string = 'downloadSettings'
const ROUTE_CACHE_SETTINGS: string = 'cacheSettings'
const ROUTE_ADVANCED_SETTINGS: string = 'advancedSettings'
const ROUTE_TAG_TRANSLATION_SETTINGS: string = 'tagTranslationSettings'
const ROUTE_COMMENT_TRANSLATION_SETTINGS: string = 'commentTranslationSettings'
const ROUTE_COMIC_TRANSLATION_SETTINGS: string = 'comicTranslationSettings'
const ROUTE_ABOUT: string = 'about'
const STATUS_BAR_LIGHT_CONTENT: string = '#FFFFFFFF'
const STATUS_BAR_DARK_CONTENT: string = '#FF000000'

/**
 * Typed params placed on the navigation stack. Keeping the route payload in the
 * entry shell prevents feature HARs from depending on one another.
 */
class GalleryRouteParams {
  galleryId: number = 0
  /** Optional tapped-row snapshot; the detail paints it immediately before the verified response. */
  seed: NhGallerySummary | null = null
  chrome: GalleryChromeState = new GalleryChromeState()
  commentSnapshot: NhComment[] = []
  commentSnapshotAvailable: boolean = false

  constructor(
    galleryId: number = 0,
    seed: NhGallerySummary | null = null,
    commentSnapshot: NhComment[] = [],
    commentSnapshotAvailable: boolean = false,
  ) {
    this.galleryId = galleryId
    this.seed = seed
    this.commentSnapshot = commentSnapshot
    this.commentSnapshotAvailable = commentSnapshotAvailable
  }
}

class LlmSourceManagerRouteParams {
}

class LlmSourceDetailRouteParams {
  sourceProfileId: string = ''

  constructor(sourceProfileId: string = '') {
    this.sourceProfileId = sourceProfileId
  }
}

class SearchRouteParams {
  initialQuery: string = ''
  chrome: SearchChromeState = new SearchChromeState()

  constructor(initialQuery: string = '') {
    this.initialQuery = initialQuery
  }
}

class ThumbnailRouteParams {
  galleryId: number = 0
  pages: NhGalleryPage[] = []
  chrome: GalleryThumbnailsChromeState = new GalleryThumbnailsChromeState()

  constructor(galleryId: number = 0, pages: NhGalleryPage[] = []) {
    this.galleryId = galleryId
    this.pages = pages
  }
}

class BrowseDensityRouteParams {
  mode: NhBrowsePresentation = NhBrowsePresentation.COVER_GRID

  constructor(mode: NhBrowsePresentation = NhBrowsePresentation.COVER_GRID) {
    this.mode = mode
  }
}

/** One-shot internal recovery route; never persisted or exposed in Settings. */
class BrowserSessionRouteParams {
  autoOpenVisibleLogin: boolean = false

  constructor(autoOpenVisibleLogin: boolean = false) {
    this.autoOpenVisibleLogin = autoOpenVisibleLogin
  }
}

/**
 * The detail pane is deliberately non-interactive while the root split stack
 * is empty. HDS owns that empty-state surface, so it cannot become a second
 * route or steal focus from the primary Browse/Favorites/History tabs.
 */
@ComponentV2
struct IndexSplitPlaceholder {
  // HDS caches ComponentContent. Read the display signal so the cached
  // placeholder remains tied to the active system/theme surface.
  @Local private themeDisplay: ThemeDisplayState = connectThemeDisplay()

  private themeTracked(color: ResourceColor): ResourceColor {
    return this.themeDisplay.effectiveDark ? color : color
  }

  build() {
    Column({ space: ThemeTokens.SPACE_MD }) {
      SymbolGlyph($r('sys.symbol.rectangle_split_1x2'))
        .fontSize(ThemeTokens.FONT_SIZE_H1)
        .fontColor([this.themeTracked(ThemeTokens.TEXT_TERTIARY)])
      Text(AppStrings.get('tablet_select_detail'))
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(this.themeTracked(ThemeTokens.TEXT_TERTIARY))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.themeTracked(ThemeTokens.SURFACE))
  }
}

@Builder
function IndexSplitPlaceholderCCBuilder(_state: Object) {
  IndexSplitPlaceholder()
}

/**
 * Entry owns the one Navigation/`NavPathStack` pair and only passes callback
 * intents into feature HARs. Browse, Favorites, History, and Settings remain
 * the root tabs; Search and Gallery are root-stack destinations. Reader uses its
 * own full-window stack so closing it restores the exact tab/detail state below.
 */
@Entry
@ComponentV2
struct Index {
  private stack: NavPathStack = new NavPathStack()
  private tabsController: HdsTabsController = new HdsTabsController()
  private readonly HOME_TAB_SCROLL_DELTA_PX: number = 6
  private readonly HOME_TAB_ANIMATION_GUARD_MS: number = 180
  private splitPlaceholderContent: ComponentContent<Object> | null = null
  private homeSourceBarContent: ComponentContent<Object> | null = null
  private historyPinnedDayHeaderContent: ComponentContent<HistoryPinnedDayHeaderState> | null = null
  private downloadPinnedGroupHeaderContent: ComponentContent<DownloadPinnedGroupHeaderState> | null = null
  private rootTabScrollers: Scroller[] = [new Scroller(), new Scroller(), new Scroller(), new Scroller()]
  // Retained Home sources own stable scrollers; this fallback is only used
  // before RetainedSubtabHost publishes its initial active source.
  private homeActiveScroller: Scroller = this.rootTabScrollers[0]
  private homeTabLastScrollOffsets: number[] = [0, 0, 0, 0]
  private homeTabDirectionTravel: number[] = [0, 0, 0, 0]
  private homeTabAnimationGuardTimerId: number = -1
  private homeTabVisibleByScroll: boolean = true
  private searchScroller: Scroller = new Scroller()
  private popularScroller: Scroller = new Scroller()
  private galleryScroller: Scroller = new Scroller()
  private thumbnailScroller: Scroller = new Scroller()
  private commentsScroller: Scroller = new Scroller()
  private contentFiltersScroller: Scroller = new Scroller()
  private layoutSettingsScroller: Scroller = new Scroller()
  private browseSettingsScroller: Scroller = new Scroller()
  private searchSettingsScroller: Scroller = new Scroller()
  private browseDensitySettingsScroller: Scroller = new Scroller()
  private readerSettingsScroller: Scroller = new Scroller()
  private readerSuperResolutionModelsScroller: Scroller = new Scroller()
  private translationSourceScroller: Scroller = new Scroller()
  private mangaRenderingServiceScroller: Scroller = new Scroller()
  private downloadSettingsScroller: Scroller = new Scroller()
  private cacheSettingsScroller: Scroller = new Scroller()
  private advancedSettingsScroller: Scroller = new Scroller()
  private tagTranslationSettingsScroller: Scroller = new Scroller()
  private commentTranslationSettingsScroller: Scroller = new Scroller()
  private comicTranslationSettingsScroller: Scroller = new Scroller()
  private aboutScroller: Scroller = new Scroller()
  private historyScroller: Scroller = new Scroller()
  private syncSettingsScroller: Scroller = new Scroller()
  private webDavSyncSettingsScroller: Scroller = new Scroller()
  private accountScroller: Scroller = new Scroller()
  @Local private activeTab: number = 0
  @Local private themeDisplay: ThemeDisplayState = connectThemeDisplay()
  @Local private tabletLayout: TabletLayoutState = connectTabletLayout()
  @Local private layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private downloadQueueActions: DownloadQueueActionState = connectDownloadQueueActions()
  @Local private homeGallerySelection: HomeGallerySelectionState = connectHomeGallerySelection()
  @Local private homeSource: HomeSourceState = connectHomeSource()
  @Local private historyPinnedDayHeader: HistoryPinnedDayHeaderState = connectHistoryPinnedDayHeader()
  @Local private downloadPinnedGroupHeader: DownloadPinnedGroupHeaderState = connectDownloadPinnedGroupHeader()
  @Local private homeTab: HomeTabAutoHideState = connectHomeTabAutoHide()
  @Local private immersiveMaterial: ImmersiveMaterialSettingsState = connectImmersiveMaterialSettings()
  @Local private readerOverlay: ReaderOverlayNavigationState = connectReaderOverlayNavigation()
  @Local private settingsNavigation: SettingsNavigationState = connectSettingsNavigation()
  @Local private clipboardLink: NhClipboardLinkState = connectNhClipboardLink()
  @Local private galleryDirectLaunch: GalleryDirectLaunchState = connectGalleryDirectLaunch()
  @Local private loginRecoveryLaunch: LoginRecoveryLaunchState = connectLoginRecoveryLaunch()
  // HDS keeps the scrollable reference it is bound to.  Rebind it explicitly
  // on every root-tab switch, as NextE does, rather than deriving a temporary
  // array value during build.
  @Local private titleScroller: Scroller = this.rootTabScrollers[0]
  @Local private historyClearVersion: number = 0
  @Local private favoritesActions: FavoritesActionState = connectFavoritesActions()
  @Local private galleryExternalOpenVersion: number = 0
  @Local private galleryShareVersion: number = 0
  @Local private galleryFavoriteVersion: number = 0
  @Local private galleryTorrentShareVersion: number = 0
  @Local private galleryChromeVersion: number = 0
  private readerDestinationVisible: boolean = false
  private readerDestinationClosing: boolean = false
  /** Route identity keeps a late closing Reader callback from becoming the next Reader's pending state. */
  private readerDestinationRouteEpoch: number = 0
  /** Reader settings can restore before this HDS destination reaches onShown. */
  private readerPresentationPending: boolean = false
  private readerPresentationRouteEpoch: number = 0
  private readerPresentationChromeVisible: boolean = false
  private readerPresentationFullscreen: boolean = true
  private readerPresentationCanvasDark: boolean = true
  private readerSystemBarGeneration: number = 0
  private readerSystemBarWork: Promise<void> = Promise.resolve()
  private lastHandledClipboardCandidateRevision: number = 0
  @Local private randomGalleryBusy: boolean = false
  private randomGalleryActionEpoch: number = 0
  private rootNavigationEpoch: number = 0

  aboutToAppear(): void {
    this.installRootNavigationStateTracking()
    this.readerOverlay.reset()
    this.handleGalleryDirectLaunch()
    this.handleClipboardGalleryCandidate()
    this.handleLoginRecoveryLaunch()
  }

  /**
   * Publish the settled secondary branch into V2 state. Settings rows consume
   * this state instead of inspecting NavPathStack while building.
   */
  private installRootNavigationStateTracking(): void {
    this.settingsNavigation.syncSecondaryBranch(this.stack)
    this.syncHomeGallerySelection(this.stack)
    this.stack.setInterception({
      willShow: (_from, _to, _operation, _animated): void => {
        this.cancelRandomGalleryRequest()
      },
      didShow: (_from, to, _operation, _animated): void => {
        this.rootNavigationEpoch += 1
        const secondaryBranch: NavPathStack | null = typeof to === 'string' ? null : to.pathStack
        this.settingsNavigation.syncSecondaryBranch(secondaryBranch)
        this.syncHomeGallerySelection(secondaryBranch)
      },
    })
  }

  aboutToDisappear(): void {
    this.cancelRandomGalleryRequest()
    this.clearHomeTabAnimationGuardTimer()
  }

  @Monitor('homeTab.autoHide')
  onHomeTabAutoHideChanged(): void {
    this.applyHomeTabAutoHide()
  }

  /** HDS alone resolves whether the root is physically in its wide split. */
  @Monitor('layoutSafeArea.rootNavigationSplit')
  onRootNavigationSplitChanged(): void {
    this.syncHomeGallerySelection(this.stack)
  }

  @Monitor('homeSource.selectedKey')
  onHomeSourceSelectionChanged(): void {
    this.cancelRandomGalleryRequest()
  }

  @Monitor('clipboardLink.candidateRevision', 'readerOverlay.visible')
  onClipboardGalleryCandidateChanged(): void {
    this.handleClipboardGalleryCandidate()
  }

  @Monitor('loginRecoveryLaunch.requestVersion')
  onLoginRecoveryLaunchRequested(): void {
    this.handleLoginRecoveryLaunch()
  }

  @Monitor('galleryDirectLaunch.requestVersion')
  onGalleryDirectLaunchRequested(): void {
    this.handleGalleryDirectLaunch()
  }

  /** Opens one explicit numeric Gallery route without a Browse-card detour. */
  private handleGalleryDirectLaunch(): void {
    const request = this.galleryDirectLaunch.consume()
    const galleryId: number = request.galleryId
    if (!Number.isSafeInteger(galleryId) || galleryId <= 0) {
      return
    }
    this.readerOverlay.reset()
    if (this.stack.getAllPathName().length > 0) {
      this.stack.clear(false)
    }
    this.settingsNavigation.clearRootLocation()
    this.clearHomeGallerySelection()
    if (request.openComments) {
      this.pushComments(galleryId)
      return
    }
    this.pushGallery(galleryId)
  }

  /** Consumes the one-shot cold-start recovery Want without opening Settings. */
  private handleLoginRecoveryLaunch(): void {
    if (!this.loginRecoveryLaunch.consume()) {
      return
    }
    if (this.stack.getAllPathName().length > 0) {
      this.stack.clear(false)
    }
    this.settingsNavigation.clearRootLocation()
    this.stack.pushPathByName(ROUTE_BROWSER_SESSION, new BrowserSessionRouteParams(true))
  }

  private handleClipboardGalleryCandidate(): void {
    const revision = this.clipboardLink.candidateRevision
    if (
      revision <= 0 ||
      revision === this.lastHandledClipboardCandidateRevision ||
      this.readerOverlay.visible
    ) {
      return
    }
    this.lastHandledClipboardCandidateRevision = revision
    const galleryId = this.clipboardLink.candidateGalleryId
    clearNhClipboardGalleryCandidate()
    if (!Number.isSafeInteger(galleryId) || galleryId <= 0) {
      return
    }
    try {
      this.getUIContext().showAlertDialog({
        title: AppStrings.get('clipboard_link_prompt_title'),
        message: AppStrings.get('clipboard_link_prompt_message'),
        primaryButton: {
          value: AppStrings.get('common_cancel'),
          action: (): void => {},
        },
        secondaryButton: {
          value: AppStrings.get('clipboard_link_open'),
          action: (): void => {
            this.pushGallery(galleryId)
          },
        },
      })
    } catch (_error) {}
  }

  private pushSearch(initialQuery: string = ''): void {
    this.stack.pushPathByName(ROUTE_SEARCH, new SearchRouteParams(initialQuery.trim()))
  }

  private pushPopular(): void {
    this.stack.pushPathByName(ROUTE_POPULAR, '')
  }

  private pushGallery(galleryId: number, seed?: NhGallerySummary): void {
    if (galleryId <= 0) {
      return
    }
    this.stack.pushPathByName(ROUTE_GALLERY, new GalleryRouteParams(galleryId, seed ?? null))
  }

  private cancelRandomGalleryRequest(): void {
    this.randomGalleryActionEpoch += 1
    this.randomGalleryBusy = false
  }

  private rootRouteSignature(): string {
    return this.stack.getAllPathName().join('\u001f')
  }

  private isRandomGalleryRequestCurrent(
    actionEpoch: number,
    navigationEpoch: number,
    sourceKey: string,
    routeSignature: string,
  ): boolean {
    return actionEpoch === this.randomGalleryActionEpoch &&
      navigationEpoch === this.rootNavigationEpoch &&
      this.activeTab === 0 &&
      this.homeSource.selectedKey === sourceKey &&
      routeSignature === this.rootRouteSignature() &&
      !this.readerOverlay.visible
  }

  private async requestRandomGallery(): Promise<void> {
    if (this.randomGalleryBusy || this.activeTab !== 0) {
      return
    }
    const actionEpoch: number = this.randomGalleryActionEpoch + 1
    this.randomGalleryActionEpoch = actionEpoch
    const navigationEpoch: number = this.rootNavigationEpoch
    const sourceKey: string = this.homeSource.selectedKey
    const routeSignature: string = this.rootRouteSignature()
    this.randomGalleryBusy = true
    try {
      const galleryId: number = await NhApiClient.randomGalleryId()
      if (!this.isRandomGalleryRequestCurrent(actionEpoch, navigationEpoch, sourceKey, routeSignature)) {
        return
      }
      this.selectHomeGalleryDetail(galleryId)
    } catch (_error) {
      if (this.isRandomGalleryRequestCurrent(actionEpoch, navigationEpoch, sourceKey, routeSignature)) {
        this.showRandomGalleryFailureDialog()
      }
    } finally {
      if (actionEpoch === this.randomGalleryActionEpoch) {
        this.randomGalleryBusy = false
      }
    }
  }

  private showRandomGalleryFailureDialog(): void {
    try {
      this.getUIContext().showAlertDialog({
        title: AppStrings.get('random_gallery_error_title'),
        message: AppStrings.get('random_gallery_error_message'),
        primaryButton: {
          value: AppStrings.get('common_cancel'),
          action: (): void => {},
        },
        secondaryButton: {
          value: AppStrings.get('common_retry'),
          action: (): void => {
            this.requestRandomGallery()
          },
        },
      })
    } catch (_error) {}
  }

  /**
   * Match NextE's primary-list rule without changing ordinary Gallery pushes:
   * the visible peer Detail is replaced, a different visible route is left in
   * its real back stack, and a same-gallery selection is a no-op.
   */
  private selectHomeGalleryDetail(galleryId: number, seed?: NhGallerySummary): void {
    if (galleryId <= 0) {
      return
    }
    if (this.activeTab !== 0 || !this.layoutSafeArea.rootNavigationSplit) {
      this.pushGallery(galleryId, seed)
      return
    }
    const pathNames: string[] = this.stack.getAllPathName()
    const topIndex: number = pathNames.length - 1
    if (topIndex >= 0 && pathNames[topIndex] === ROUTE_GALLERY) {
      const current: GalleryRouteParams | null = this.galleryParamsAt(this.stack, topIndex)
      if (current !== null && current.galleryId === galleryId) {
        return
      }
      this.stack.replacePathByName(ROUTE_GALLERY, new GalleryRouteParams(galleryId, seed ?? null), true)
      return
    }
    this.stack.pushPathByName(ROUTE_GALLERY, new GalleryRouteParams(galleryId, seed ?? null))
  }

  /** The selected card follows the secondary branch entry, not a nested leaf. */
  private syncHomeGallerySelection(pathStack: NavPathStack | null): void {
    if (this.activeTab !== 0 || !this.layoutSafeArea.rootNavigationSplit || pathStack === null) {
      this.homeGallerySelection.clear()
      return
    }
    const pathNames: string[] = pathStack.getAllPathName()
    if (pathNames[0] !== ROUTE_GALLERY) {
      this.homeGallerySelection.clear()
      return
    }
    const params: GalleryRouteParams | null = this.galleryParamsAt(pathStack, 0)
    this.homeGallerySelection.setSelectedGalleryId(params === null ? 0 : params.galleryId)
  }

  private galleryParamsAt(pathStack: NavPathStack, index: number): GalleryRouteParams | null {
    const value: Object | null | undefined = pathStack.getParamByIndex(index) as Object | null | undefined
    if (value instanceof GalleryRouteParams && value.galleryId > 0) {
      return value
    }
    return null
  }

  private clearHomeGallerySelection(): void {
    this.homeGallerySelection.clear()
  }

  private pushThumbnails(galleryId: number, pages: NhGalleryPage[]): void {
    if (galleryId <= 0 || pages.length === 0) {
      return
    }
    this.stack.pushPathByName(ROUTE_THUMBNAILS, new ThumbnailRouteParams(galleryId, pages))
  }

  private pushReader(galleryId: number, initialPageIndex: number = -1): void {
    if (galleryId <= 0) {
      return
    }
    this.readerOverlay.open(new ReaderRouteParams(galleryId, initialPageIndex))
  }

  private pushComments(
    galleryId: number,
    commentSnapshot: NhComment[] = [],
    commentSnapshotAvailable: boolean = false,
  ): void {
    if (galleryId <= 0) {
      return
    }
    this.stack.pushPathByName(
      ROUTE_COMMENTS,
      new GalleryRouteParams(galleryId, null, commentSnapshot, commentSnapshotAvailable),
    )
  }

  /** Leaves a detail route for the one durable Downloads root, matching NextE's task handoff. */
  private openDownloads(): void {
    const target: number = 2
    if (this.activeTab === target) {
      this.triggerRootRefresh(target)
      return
    }
    if (this.stack.getAllPathName().length > 0) {
      this.stack.clear(false)
    }
    this.settingsNavigation.clearRootLocation()
    this.clearHomeGallerySelection()
    this.activeTab = target
    this.titleScroller = this.rootTabScrollers[target]
    if (this.homeTab.autoHide) {
      this.restoreHomeTabIfHidden()
    }
    // Official HDS controller transition keeps root-tab selection and its
    // `onChange` lifecycle coherent; the stack was already explicitly closed.
    setTimeout((): void => {
      this.tabsController.changeIndex(target)
    }, 0)
  }

  private pushBrowserSession(): void {
    this.openSettingsRootDestination(ROUTE_BROWSER_SESSION, new BrowserSessionRouteParams())
  }

  private pushLayoutSettings(): void {
    this.openSettingsRootDestination(ROUTE_LAYOUT_SETTINGS)
  }

  private pushBrowseSettings(): void {
    this.openSettingsRootDestination(ROUTE_BROWSE_SETTINGS)
  }

  private pushSearchSettings(): void {
    this.openSettingsRootDestination(ROUTE_SEARCH_SETTINGS)
  }

  private pushBrowseDensitySettings(mode: NhBrowsePresentation): void {
    this.stack.pushPathByName(ROUTE_BROWSE_DENSITY_SETTINGS, new BrowseDensityRouteParams(mode))
  }

  private pushContentFilters(): void {
    this.stack.pushPathByName(ROUTE_CONTENT_FILTERS, '')
  }

  private pushReaderSettings(): void {
    this.openSettingsRootDestination(ROUTE_READER_SETTINGS)
  }

  private pushReaderSuperResolutionModels(): void {
    this.stack.pushPathByName(ROUTE_READER_SUPER_RESOLUTION_MODELS, '')
  }

  private pushLlmSourceManager(): void {
    this.stack.pushPathByName(ROUTE_LLM_SOURCE_MANAGER, new LlmSourceManagerRouteParams())
  }

  private pushLlmSourceDetail(sourceProfileId: string): void {
    this.stack.pushPathByName(
      ROUTE_LLM_SOURCE_DETAIL,
      new LlmSourceDetailRouteParams(sourceProfileId),
    )
  }

  private pushTagTranslationSettings(): void {
    this.stack.pushPathByName(ROUTE_TAG_TRANSLATION_SETTINGS, '')
  }

  private pushCommentTranslationSettings(): void {
    this.stack.pushPathByName(ROUTE_COMMENT_TRANSLATION_SETTINGS, '')
  }

  private pushComicTranslationSettings(): void {
    this.stack.pushPathByName(ROUTE_COMIC_TRANSLATION_SETTINGS, '')
  }

  private pushMangaRenderingService(): void {
    this.stack.pushPathByName(ROUTE_MANGA_RENDERING_SERVICE, '')
  }

  private pushDownloadSettings(): void {
    this.openSettingsRootDestination(ROUTE_DOWNLOAD_SETTINGS)
  }

  private pushCacheSettings(): void {
    this.openSettingsRootDestination(ROUTE_CACHE_SETTINGS)
  }

  private pushAdvancedSettings(): void {
    this.openSettingsRootDestination(ROUTE_ADVANCED_SETTINGS)
  }

  private pushAbout(): void {
    this.openSettingsRootDestination(ROUTE_ABOUT)
  }

  private pushHistory(): void {
    this.openSettingsRootDestination(ROUTE_HISTORY)
  }

  private pushAccount(): void {
    this.stack.pushPathByName(ROUTE_ACCOUNT, '')
  }

  private pushSyncSettings(): void {
    this.stack.pushPathByName(ROUTE_SYNC_SETTINGS, '')
  }

  private pushWebDavSyncSettings(): void {
    this.stack.pushPathByName(ROUTE_WEBDAV_SYNC_SETTINGS, '')
  }

  /** Root Settings choices are siblings, unlike their real nested subpages. */
  private isSettingsRoute(name: string): boolean {
    return name === ROUTE_BROWSER_SESSION ||
      name === ROUTE_ACCOUNT ||
      name === ROUTE_SYNC_SETTINGS ||
      name === ROUTE_WEBDAV_SYNC_SETTINGS ||
      name === ROUTE_LAYOUT_SETTINGS ||
      name === ROUTE_BROWSE_SETTINGS ||
      name === ROUTE_SEARCH_SETTINGS ||
      name === ROUTE_BROWSE_DENSITY_SETTINGS ||
      name === ROUTE_READER_SETTINGS ||
      name === ROUTE_DOWNLOAD_SETTINGS ||
      name === ROUTE_CACHE_SETTINGS ||
      name === ROUTE_ADVANCED_SETTINGS ||
      name === ROUTE_CONTENT_FILTERS ||
      name === ROUTE_HISTORY ||
      name === ROUTE_ABOUT
  }

  /**
   * Match NextE's settings-root contract: selecting a peer from the primary
   * Settings list replaces the current secondary detail rather than stacking
   * stale siblings behind it. A true nested subpage is discarded with its
   * parent before the new root choice opens, so Back returns to Settings.
   */
  private openSettingsRootDestination(name: string, param: Object = ''): void {
    const pathNames: string[] = this.stack.getAllPathName()
    const topIndex: number = pathNames.length - 1
    if (topIndex >= 0 && pathNames[topIndex] === name) {
      return
    }
    if (topIndex < 0) {
      this.stack.pushPathByName(name, param)
      return
    }
    if (!this.isSettingsRoute(pathNames[topIndex])) {
      this.stack.pushPathByName(name, param)
      return
    }
    if (pathNames.length === 1) {
      this.stack.replacePathByName(name, param, true)
      return
    }
    this.stack.clear(false)
    this.settingsNavigation.clearRootLocation()
    this.stack.pushPathByName(name, param)
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private appUsesDarkIcons(): boolean {
    return !this.themeDisplay.effectiveDark
  }

  /**
   * Serializing the Window calls prevents a late hide from winning over a
   * later chrome reveal or route close. This is the lifecycle boundary the
   * child Reader cannot own because Index owns its private overlay stack.
   */
  private requestReaderStatusBar(visible: boolean, lightIcons: boolean): Promise<void> {
    const generation: number = this.readerSystemBarGeneration + 1
    this.readerSystemBarGeneration = generation
    const contentColor: string = lightIcons ? STATUS_BAR_LIGHT_CONTENT : STATUS_BAR_DARK_CONTENT
    const work: Promise<void> = this.readerSystemBarWork
      .catch((): void => {})
      .then(async (): Promise<void> => {
        if (generation !== this.readerSystemBarGeneration) {
          return
        }
        const appWindow: window.Window = await window.getLastWindow(this.context())
        if (generation !== this.readerSystemBarGeneration) {
          return
        }
        if (visible) {
          await appWindow.setWindowSystemBarProperties({
            statusBarContentColor: contentColor,
            isStatusBarLightIcon: lightIcons,
          })
        }
        if (generation !== this.readerSystemBarGeneration) {
          return
        }
        await appWindow.setSpecificSystemBarEnabled('status', visible, false)
      })
      .catch((error: Error): void => {
        if (generation === this.readerSystemBarGeneration) {
          console.warn(`Unable to update Reader status bar: ${error.message}`)
        }
      })
    this.readerSystemBarWork = work
    return work
  }

  private restoreAppStatusBar(): Promise<void> {
    return this.requestReaderStatusBar(true, !this.appUsesDarkIcons())
  }

  /**
   * Reader owns its restored presentation state, while Index alone owns Window
   * calls. Retain a pre-onShown state and replay it once the destination is
   * actually visible instead of replacing it with a default.
   */
  private recordReaderPresentation(
    routeEpoch: number,
    chromeVisible: boolean,
    fullscreen: boolean,
    canvasDark: boolean = true,
  ): void {
    if (this.readerDestinationClosing && routeEpoch === this.readerDestinationRouteEpoch) {
      return
    }
    if (this.readerDestinationVisible && routeEpoch !== this.readerDestinationRouteEpoch) {
      return
    }
    this.readerPresentationPending = true
    this.readerPresentationRouteEpoch = routeEpoch
    this.readerPresentationChromeVisible = chromeVisible
    this.readerPresentationFullscreen = fullscreen
    this.readerPresentationCanvasDark = canvasDark
    if (!this.readerDestinationVisible) {
      return
    }
    this.applyRecordedReaderPresentation()
  }

  private applyRecordedReaderPresentation(): void {
    if (!this.readerPresentationPending ||
      this.readerPresentationRouteEpoch !== this.readerDestinationRouteEpoch ||
      !this.readerDestinationVisible || this.readerDestinationClosing) {
      return
    }
    const visible: boolean = !this.readerPresentationFullscreen || this.readerPresentationChromeVisible
    this.requestReaderStatusBar(visible, this.readerPresentationChromeVisible || this.readerPresentationCanvasDark)
  }

  private clearRecordedReaderPresentation(): void {
    this.readerPresentationPending = false
    this.readerPresentationRouteEpoch = 0
    this.readerPresentationChromeVisible = false
    this.readerPresentationFullscreen = true
    this.readerPresentationCanvasDark = true
  }

  private closeReaderDestination(): void {
    if (this.readerDestinationClosing) {
      return
    }
    this.readerDestinationClosing = true
    this.clearRecordedReaderPresentation()
    this.restoreAppStatusBar().then((): void => {
      if (this.readerDestinationClosing) {
        this.readerOverlay.close()
      }
    })
  }

  /**
   * NextE keeps the root destinations few, stable, and visually legible.  NextN
   * has only the genuinely available roots today. Favorites has a real
   * account-bound read path; Downloads remains absent until its queue exists.
   */
  private rootTitle(): string {
    if (this.activeTab === 1) {
      return AppStrings.get('tab_favorites')
    }
    if (this.activeTab === 2) {
      return AppStrings.get('tab_downloads')
    }
    if (this.activeTab === 3) {
      return AppStrings.get('tab_me')
    }
    return AppStrings.get('tab_browse')
  }

  /** Cached once: recreating HDS ComponentContent remounts a selector mid-swipe. */
  private homeSourceBottomBuilder(): Record<string, Object> {
    if (this.homeSourceBarContent === null) {
      this.homeSourceBarContent = new ComponentContent<Object>(
        this.getUIContext(),
        wrapBuilder<[Object]>(HomeSourceBarCCBuilder),
        new Object(),
      )
    }
    return {
      'builderComponent': this.homeSourceBarContent,
      'height': HOME_SOURCE_SELECTOR_HEIGHT,
      'showType': BottomBuilderShowType.DIRECTLY_SHOW,
    }
  }

  /**
   * Cached once like the Browse source selector: HDS may reissue title options
   * while scrolling, and recreating the content would reset its geometry just
   * as a History ListItemGroup is crossing the fixed title surface.
   */
  private historyPinnedDayBottomBuilder(): Record<string, Object> {
    if (this.historyPinnedDayHeaderContent === null) {
      this.historyPinnedDayHeaderContent = new ComponentContent<HistoryPinnedDayHeaderState>(
        this.getUIContext(),
        wrapBuilder<[HistoryPinnedDayHeaderState]>(HistoryPinnedDayHeaderCCBuilder),
        this.historyPinnedDayHeader,
      )
    }
    return {
      'builderComponent': this.historyPinnedDayHeaderContent,
      'height': HISTORY_PINNED_DAY_HEADER_HEIGHT,
      'showType': BottomBuilderShowType.DIRECTLY_SHOW,
    }
  }

  /** Destination title for the History page moved out of the root tab bar. */
  private historyDestinationTitleBar(): Record<string, Object> {
    const title: Record<string, Object> = { 'mainTitle': AppStrings.get('tab_history') }
    const clearAction: Record<string, Object> = {
      'label': AppStrings.get('action_clear'),
      'icon': $r('sys.symbol.trash'),
      'isEnabled': true,
      'action': (): void => {
        this.historyClearVersion += 1
      },
    }
    const clearMenuItem: Record<string, Object> = { 'content': clearAction }
    const historyMenu: Record<string, Object> = { 'value': [clearMenuItem], 'maxCount': 1 }
    return nextNHdsTitleBar({
      'title': title,
      'menu': historyMenu,
      'bottomBuilder': this.historyPinnedDayBottomBuilder(),
    })
  }

  /** Cached HDS mirror for the lifecycle group currently under the title. */
  private downloadPinnedGroupBottomBuilder(): Record<string, Object> {
    if (this.downloadPinnedGroupHeaderContent === null) {
      this.downloadPinnedGroupHeaderContent = new ComponentContent<DownloadPinnedGroupHeaderState>(
        this.getUIContext(),
        wrapBuilder<[DownloadPinnedGroupHeaderState]>(DownloadPinnedGroupHeaderCCBuilder),
        this.downloadPinnedGroupHeader,
      )
    }
    return {
      'builderComponent': this.downloadPinnedGroupHeaderContent,
      'height': DOWNLOAD_PINNED_GROUP_HEADER_HEIGHT,
      'showType': BottomBuilderShowType.DIRECTLY_SHOW,
    }
  }

  private rootTabScroller(index: number): Scroller {
    return index === 0 ? this.homeActiveScroller : this.rootTabScrollers[index]
  }

  private rootMaterialEffect(): Record<string, Object> {
    const effect = ImmersiveMaterialSettings.effect(this.immersiveMaterial.level)
    return {
      'materialType': effect.materialType,
      'materialLevel': effect.materialLevel,
    }
  }

  /** The HDS title, floating-tab animation, and Browse re-tap follow the settled retained source. */
  private onHomeSourceScrollerReady(scroller: Scroller): void {
    const oldScroller: Scroller = this.homeActiveScroller
    if (oldScroller === scroller) {
      if (this.homeTab.autoHide) {
        this.tabsController.bindScroller(0, scroller)
      }
      return
    }
    this.tabsController.unbindScroller(oldScroller)
    this.homeActiveScroller = scroller
    if (this.activeTab === 0) {
      this.titleScroller = scroller
    }
    if (this.homeTab.autoHide) {
      this.tabsController.bindScroller(0, scroller)
      this.restoreHomeTabIfHidden()
    }
  }

  private applyHomeTabAutoHide(): void {
    for (let index = 0; index < this.rootTabScrollers.length; index += 1) {
      const scroller: Scroller = this.rootTabScroller(index)
      if (this.homeTab.autoHide) {
        this.tabsController.bindScroller(index, scroller)
      } else {
        this.tabsController.unbindScroller(scroller)
      }
    }
    this.restoreHomeTabIfHidden()
  }

  private restoreHomeTabIfHidden(): void {
    if (this.homeTabVisibleByScroll) {
      return
    }
    this.homeTabVisibleByScroll = true
    this.tabsController.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION)
  }

  private clearHomeTabAnimationGuardTimer(): void {
    if (this.homeTabAnimationGuardTimerId === -1) {
      return
    }
    clearTimeout(this.homeTabAnimationGuardTimerId)
    this.homeTabAnimationGuardTimerId = -1
  }

  private startHomeTabAnimationGuardTimer(): void {
    this.clearHomeTabAnimationGuardTimer()
    this.homeTabAnimationGuardTimerId = setTimeout((): void => {
      this.homeTabAnimationGuardTimerId = -1
    }, this.HOME_TAB_ANIMATION_GUARD_MS)
  }

  private applyHomeTabScrollAnimation(visible: boolean): void {
    if (
      !this.homeTab.autoHide ||
      this.homeTabAnimationGuardTimerId !== -1 ||
      this.homeTabVisibleByScroll === visible
    ) {
      return
    }
    this.homeTabVisibleByScroll = visible
    if (visible) {
      this.tabsController.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION)
    } else {
      this.tabsController.applyHideAnimation(HdsAnimationMode.SCROLL_ANIMATION)
    }
    this.startHomeTabAnimationGuardTimer()
  }

  /**
   * Grid, List, and WaterFlow report a positive vertical offset while their
   * content moves up. Clamp only top-edge overscroll so root-tab direction
   * detection remains in physical content-distance space.
   */
  private homeTabScrollDistance(offset: number): number {
    return Math.max(0, offset)
  }

  private onHomeTabDidScroll(index: number, offset: number, state: ScrollState): void {
    const distance: number = this.homeTabScrollDistance(offset)
    if (index !== this.activeTab || !this.homeTab.autoHide) {
      this.homeTabLastScrollOffsets[index] = distance
      this.homeTabDirectionTravel[index] = 0
      return
    }
    if (distance <= this.HOME_TAB_SCROLL_DELTA_PX) {
      this.homeTabLastScrollOffsets[index] = distance
      this.homeTabDirectionTravel[index] = 0
      this.restoreHomeTabIfHidden()
      return
    }
    const lastOffset: number = this.homeTabLastScrollOffsets[index]
    this.homeTabLastScrollOffsets[index] = distance
    const delta: number = distance - lastOffset
    if (Math.abs(delta) < 0.01) {
      return
    }
    const priorTravel: number = this.homeTabDirectionTravel[index]
    const continuesDirection: boolean = priorTravel === 0 ||
      (priorTravel > 0 && delta > 0) ||
      (priorTravel < 0 && delta < 0)
    const directionTravel: number = continuesDirection ? priorTravel + delta : delta
    this.homeTabDirectionTravel[index] = directionTravel
    if (directionTravel < -this.HOME_TAB_SCROLL_DELTA_PX) {
      this.homeTabDirectionTravel[index] = 0
      this.applyHomeTabScrollAnimation(true)
      return
    }
    if (directionTravel > this.HOME_TAB_SCROLL_DELTA_PX) {
      this.homeTabDirectionTravel[index] = 0
      this.applyHomeTabScrollAnimation(false)
    }
  }

  /**
   * HDS keeps the last bound title-bar menu if a destination omits `menu`.
   * Use the same explicit empty-menu shape as NextE and the Settings root
   * whenever a root surface has no permitted trailing action.
   */
  private emptyHdsMenu(): Record<string, Object> {
    const emptyMenuItems: Record<string, Object>[] = []
    return { 'value': emptyMenuItems, 'maxCount': 0 }
  }

  private rootTitleBar(): Record<string, Object> {
    const title: Record<string, Object> = { 'mainTitle': this.rootTitle() }
    const content: Record<string, Object> = { 'title': title }
    if (this.activeTab === 0) {
      content['bottomBuilder'] = this.homeSourceBottomBuilder()
      const searchAction: Record<string, Object> = {
        'label': AppStrings.get('action_search'),
        'icon': $r('sys.symbol.magnifyingglass'),
        'isEnabled': true,
        'action': (): void => {
          this.pushSearch()
        },
      }
      const searchMenuItem: Record<string, Object> = { 'content': searchAction }
      const randomGalleryAction: Record<string, Object> = {
        'label': AppStrings.get('action_random_gallery'),
        'icon': $r('sys.symbol.shuffle'),
        'isEnabled': !this.randomGalleryBusy,
        'action': (): void => {
          this.requestRandomGallery()
        },
      }
      const randomGalleryMenuItem: Record<string, Object> = { 'content': randomGalleryAction }
      const browseOptionsAction: Record<string, Object> = {
        'label': AppStrings.get('action_browse_options'),
        'icon': $r('sys.symbol.slider_horizontal_2'),
        'isEnabled': true,
        'action': (): void => {
          HomeSourceBridge.requestBrowseOptions()
        },
      }
      const browseOptionsMenuItem: Record<string, Object> = { 'content': browseOptionsAction }
      const layoutAction: Record<string, Object> = {
        'label': AppStrings.get('browse_presentation'),
        'icon': $r('sys.symbol.square_grid_2x2'),
        'isEnabled': true,
        'action': (): void => {
          HomeSourceBridge.requestLayoutMenu()
        },
      }
      const layoutMenuItem: Record<string, Object> = { 'content': layoutAction }
      // Popular is already a retained Browse source. Keep its old route only
      // for compatibility, but never present a duplicate title-bar entry.
      // Query controls belong only to Latest; the shared layout switcher is
      // intentionally available from either source.
      const browseMenuItems: Record<string, Object>[] = this.homeSource.selectedKey === HOME_SOURCE_LATEST
        ? [searchMenuItem, browseOptionsMenuItem, layoutMenuItem, randomGalleryMenuItem]
        : [searchMenuItem, layoutMenuItem, randomGalleryMenuItem]
      const searchMenu: Record<string, Object> = { 'value': browseMenuItems, 'maxCount': 3 }
      content['menu'] = searchMenu
    } else if (this.activeTab === 1) {
      if (this.favoritesActions.actionsAvailable) {
        const searchAction: Record<string, Object> = {
          'label': this.favoritesActions.searchActive
            ? AppStrings.get('favorites_search_close')
            : AppStrings.get('action_search'),
          'icon': this.favoritesActions.searchActive
            ? $r('sys.symbol.xmark')
            : $r('sys.symbol.magnifyingglass'),
          'isEnabled': this.favoritesActions.actionsAvailable,
          'action': (): void => {
            FavoritesActionBridge.requestToggleSearch()
          },
        }
        const layoutAction: Record<string, Object> = {
          'label': AppStrings.get('browse_presentation'),
          'icon': $r('sys.symbol.square_grid_2x2'),
          'isEnabled': this.favoritesActions.actionsAvailable,
          'action': (): void => {
            FavoritesActionBridge.requestLayoutMenu()
          },
        }
        const searchMenuItem: Record<string, Object> = { 'content': searchAction }
        const layoutMenuItem: Record<string, Object> = { 'content': layoutAction }
        const favoritesMenuItems: Record<string, Object>[] = [searchMenuItem, layoutMenuItem]
        const favoritesMenu: Record<string, Object> = { 'value': favoritesMenuItems, 'maxCount': 2 }
        content['menu'] = favoritesMenu
      } else {
        content['menu'] = this.emptyHdsMenu()
      }
    } else if (this.activeTab === 2) {
      // Root HDS owns only command intent. DownloadQueuePage owns all local
      // query, ordering, and menu state through the narrow action bridge.
      content['bottomBuilder'] = this.downloadPinnedGroupBottomBuilder()
      const searchAction: Record<string, Object> = {
        'label': this.downloadQueueActions.searchActive
          ? AppStrings.get('download_search_close')
          : AppStrings.get('action_search'),
        'icon': this.downloadQueueActions.searchActive
          ? $r('sys.symbol.xmark')
          : $r('sys.symbol.magnifyingglass'),
        'isEnabled': true,
        'action': (): void => {
          DownloadQueueActionBridge.requestToggleSearch()
        },
      }
      const sortAction: Record<string, Object> = {
        'label': AppStrings.get('download_sort'),
        'icon': $r('sys.symbol.sort'),
        'isEnabled': true,
        'action': (): void => {
          DownloadQueueActionBridge.requestOpenSortMenu()
        },
      }
      const pauseVisibleAction: Record<string, Object> = {
        'label': AppStrings.get('download_action_pause_all'),
        'icon': $r('sys.symbol.pause'),
        'isEnabled': this.downloadQueueActions.pausableVisibleCount > 0,
        'action': (): void => {
          DownloadQueueActionBridge.requestPauseVisible()
        },
      }
      const resumeVisibleAction: Record<string, Object> = {
        'label': AppStrings.get('download_action_resume_all'),
        'icon': $r('sys.symbol.play_fill'),
        'isEnabled': this.downloadQueueActions.resumableVisibleCount > 0,
        'action': (): void => {
          DownloadQueueActionBridge.requestResumeVisible()
        },
      }
      const searchMenuItem: Record<string, Object> = { 'content': searchAction }
      const sortMenuItem: Record<string, Object> = { 'content': sortAction }
      const pauseVisibleMenuItem: Record<string, Object> = { 'content': pauseVisibleAction }
      const resumeVisibleMenuItem: Record<string, Object> = { 'content': resumeVisibleAction }
      const downloadMenuItems: Record<string, Object>[] = [searchMenuItem, sortMenuItem]
      if (this.downloadQueueActions.resumableVisibleCount > 0) {
        downloadMenuItems.push(resumeVisibleMenuItem)
      }
      if (this.downloadQueueActions.pausableVisibleCount > 0) {
        downloadMenuItems.push(pauseVisibleMenuItem)
      }
      const downloadMenu: Record<string, Object> = {
        'value': downloadMenuItems,
        'maxCount': downloadMenuItems.length,
      }
      content['menu'] = downloadMenu
    }
    if (this.activeTab === 3) {
      content['menu'] = this.emptyHdsMenu()
    }
    return nextNHdsTitleBar(content)
  }

  private thumbnailsTitleBar(route: ThumbnailRouteParams): Record<string, Object> {
    const title: Record<string, Object> = { 'mainTitle': AppStrings.get('title_pages') }
    const firstPageAction: Record<string, Object> = {
      'label': AppStrings.get('thumbnails_first_page'),
      'icon': $r('sys.symbol.arrow_up_circle'),
      'isEnabled': route.pages.length > 0,
      'action': (): void => {
        route.chrome.firstPageRequestVersion += 1
      },
    }
    const jumpPageAction: Record<string, Object> = {
      'label': AppStrings.get('thumbnails_jump_page'),
      'icon': $r('sys.symbol.arrow_right'),
      'isEnabled': route.pages.length > 0,
      'action': (): void => {
        route.chrome.jumpPageRequestVersion += 1
      },
    }
    const menuItems: Record<string, Object>[] = [
      { 'content': firstPageAction },
      { 'content': jumpPageAction },
    ]
    const menu: Record<string, Object> = { 'value': menuItems, 'maxCount': 2 }
    return nextNHdsTitleBar({ 'title': title, 'menu': menu })
  }

  /**
   * HDS receives only bounded local queue counters from Gallery chrome. Keep
   * status and page-count wording localized here, while task metadata and all
   * queue operations remain owned by the retained Gallery destination.
   */
  private galleryDownloadProgressLabel(status: string, completedPages: number, pageCount: number): string {
    const safePageCount: number = Math.max(0, pageCount)
    if (safePageCount === 0) {
      return ''
    }
    const safeCompletedPages: number = Math.min(safePageCount, Math.max(0, completedPages))
    const statusLabel: string = status === NhDownloadTaskStatus.QUEUED
      ? AppStrings.get('download_status_queued')
      : (status === NhDownloadTaskStatus.DOWNLOADING
        ? AppStrings.get('download_status_downloading')
        : (status === NhDownloadTaskStatus.PAUSED
          ? AppStrings.get('download_status_paused')
          : ''))
    if (statusLabel.length === 0) {
      return ''
    }
    const progress: string = AppStrings.format(
      'gallery_meta_pages',
      [`${safeCompletedPages} / ${safePageCount}`],
    )
    return `${statusLabel} · ${progress}`
  }

  private galleryTitleBar(route: GalleryRouteParams): Record<string, Object> {
    // The version is advanced by the page only when the header/title handoff
    // changes, so HDS can re-evaluate this route-local title without a
    // page-local duplicate toolbar.
    const revealedTitle: string = this.galleryChromeVersion >= 0 && route.chrome.showTitle
      ? route.chrome.title
      : ''
    const title: Record<string, Object> = { 'mainTitle': revealedTitle }
    const favoriteAction: Record<string, Object> = {
      'label': route.chrome.isFavorited
        ? AppStrings.get('action_remove_favorite')
        : AppStrings.get('action_add_favorite'),
      'icon': route.chrome.favoriteKnown && route.chrome.isFavorited
        ? $r('sys.symbol.heart_fill')
        : $r('sys.symbol.heart'),
      'isEnabled': !route.chrome.favoriteBusy,
      'action': (): void => {
        this.galleryFavoriteVersion += 1
      },
    }
    const downloadStatus: string = route.chrome.downloadStatus
    const downloadCompleted: boolean = downloadStatus === NhDownloadTaskStatus.COMPLETE
    const downloadNeedsResume: boolean = downloadStatus === NhDownloadTaskStatus.PAUSED ||
      downloadStatus === NhDownloadTaskStatus.ERROR
    const downloadActive: boolean = downloadStatus === NhDownloadTaskStatus.QUEUED ||
      downloadStatus === NhDownloadTaskStatus.DOWNLOADING
    const downloadShowsProgress: boolean = downloadActive ||
      downloadStatus === NhDownloadTaskStatus.PAUSED
    const downloadProgressLabel: string = downloadShowsProgress
      ? this.galleryDownloadProgressLabel(
        downloadStatus,
        route.chrome.downloadCompletedPages,
        route.chrome.downloadPageCount,
      )
      : ''
    const downloadAction: Record<string, Object> = {
      'label': downloadCompleted
        ? AppStrings.get('download_action_read')
        : (downloadProgressLabel.length > 0
          ? downloadProgressLabel
          : (downloadNeedsResume
            ? AppStrings.get('download_action_resume')
            : (downloadActive ? AppStrings.get('tab_downloads') : AppStrings.get('action_download')))),
      'icon': downloadCompleted
        ? $r('sys.symbol.doc_plaintext_fill')
        : (downloadNeedsResume
          ? $r('sys.symbol.arrow_clockwise')
          : (downloadActive ? $r('sys.symbol.rectangle_stack') : $r('sys.symbol.arrow_down_to_line'))),
      'isEnabled': route.chrome.downloadActionReady,
      'action': (): void => {
        if (route.chrome.downloadActionReady) {
          route.chrome.downloadRequestVersion += 1
        }
      },
    }
    const externalOpenAction: Record<string, Object> = {
      'label': AppStrings.get('action_open_externally'),
      'icon': $r('sys.symbol.link'),
      'isEnabled': true,
      'action': (): void => {
        this.galleryExternalOpenVersion += 1
      },
    }
    const shareAction: Record<string, Object> = {
      'label': AppStrings.get('action_share'),
      'icon': $r('sys.symbol.share'),
      'isEnabled': true,
      'action': (): void => {
        this.galleryShareVersion += 1
      },
    }
    const reloadAction: Record<string, Object> = {
      'label': AppStrings.get('action_reload'),
      'icon': $r('sys.symbol.arrow_clockwise'),
      'isEnabled': !route.chrome.refreshInFlight,
      'action': (): void => {
        route.chrome.reloadVersion += 1
      },
    }
    const wideThumbnailFirstPageAction: Record<string, Object> = {
      'label': AppStrings.get('thumbnails_first_page'),
      'icon': $r('sys.symbol.arrow_up_circle'),
      'isEnabled': route.chrome.wideThumbnailActionsAvailable,
      'action': (): void => {
        if (route.chrome.wideThumbnailActionsAvailable) {
          route.chrome.wideThumbnailFirstPageRequestVersion += 1
        }
      },
    }
    const wideThumbnailJumpPageAction: Record<string, Object> = {
      'label': AppStrings.get('thumbnails_jump_page'),
      'icon': $r('sys.symbol.arrow_right'),
      'isEnabled': route.chrome.wideThumbnailActionsAvailable,
      'action': (): void => {
        if (route.chrome.wideThumbnailActionsAvailable) {
          route.chrome.wideThumbnailJumpPageRequestVersion += 1
        }
      },
    }
    const torrentShareAction: Record<string, Object> = {
      'label': AppStrings.get('action_export_torrent'),
      'icon': $r('sys.symbol.arrow_up_circle'),
      'isEnabled': true,
      'action': (): void => {
        this.galleryTorrentShareVersion += 1
      },
    }
    const favoriteMenuItem: Record<string, Object> = { 'content': favoriteAction }
    const downloadMenuItem: Record<string, Object> = { 'content': downloadAction }
    const externalOpenMenuItem: Record<string, Object> = { 'content': externalOpenAction }
    const shareMenuItem: Record<string, Object> = { 'content': shareAction }
    const reloadMenuItem: Record<string, Object> = { 'content': reloadAction }
    const torrentShareMenuItem: Record<string, Object> = { 'content': torrentShareAction }
    const menuItems: Record<string, Object>[] = [
      favoriteMenuItem,
      shareMenuItem,
      externalOpenMenuItem,
      downloadMenuItem,
      reloadMenuItem,
    ]
    if (route.chrome.wideThumbnailActionsAvailable) {
      // Keep Favourite and Share as the two direct compact actions; wide
      // thumbnail commands remain contextual overflow actions just as in
      // NextE's split Detail title bar.
      menuItems.push(
        { 'content': wideThumbnailFirstPageAction },
        { 'content': wideThumbnailJumpPageAction },
      )
    }
    menuItems.push(torrentShareMenuItem)
    const menu: Record<string, Object> = {
      // Same NextE hierarchy: the title refresh is a secondary HDS command;
      // the page-local Read capsule remains the primary detail action.
      // Keep the compact Gallery chrome on the reference path: favorite and
      // share are the two direct context actions. Download remains available
      // in the overflow with its full lifecycle wording rather than claiming
      // a scarce first-level circular slot.
      'value': menuItems,
      'maxCount': 3,
    }
    return nextNHdsTitleBar({ 'title': title, 'menu': menu })
  }

  @Builder
  private tabBar(label: string, index: number) {
    MainTabIcon({
      title: label,
      idx: index,
      iconIdx: index,
      currentIndex: this.activeTab,
      onSelectedClick: (selectedIndex: number): void => {
        this.triggerRootRefresh(selectedIndex)
      },
    })
  }

  /** Matches NextE: a re-tap is routed to the currently registered root list. */
  private triggerRootRefresh(index: number): void {
    if (index < 0 || index >= this.rootTabScrollers.length) {
      return
    }
    if (index === 0) {
      RootRefreshRegistry.trigger(this.homeActiveScroller)
      return
    }
    RootRefreshRegistry.trigger(this.rootTabScrollers[index])
  }

  private galleryParams(param: Object): GalleryRouteParams {
    if (param instanceof GalleryRouteParams && param.galleryId > 0) {
      return param
    }
    return new GalleryRouteParams()
  }

  private searchParams(param: Object): SearchRouteParams {
    if (param instanceof SearchRouteParams) {
      return param
    }
    return new SearchRouteParams()
  }

  private readerParams(param: Object): ReaderRouteParams {
    if (param instanceof ReaderRouteParams && param.galleryId > 0) {
      return param
    }
    return new ReaderRouteParams()
  }

  private llmSourceManagerParams(param: Object): LlmSourceManagerRouteParams {
    if (param instanceof LlmSourceManagerRouteParams) {
      return param
    }
    return new LlmSourceManagerRouteParams()
  }

  private llmSourceDetailParams(param: Object): LlmSourceDetailRouteParams {
    if (param instanceof LlmSourceDetailRouteParams) {
      return new LlmSourceDetailRouteParams(param.sourceProfileId)
    }
    return new LlmSourceDetailRouteParams()
  }

  private thumbnailParams(param: Object): ThumbnailRouteParams {
    if (param instanceof ThumbnailRouteParams && param.galleryId > 0) {
      return param
    }
    return new ThumbnailRouteParams()
  }

  private browseDensityParams(param: Object): BrowseDensityRouteParams {
    if (param instanceof BrowseDensityRouteParams) {
      return param
    }
    return new BrowseDensityRouteParams()
  }

  private browserSessionParams(param: Object): BrowserSessionRouteParams {
    if (param instanceof BrowserSessionRouteParams) {
      return param
    }
    return new BrowserSessionRouteParams()
  }

  @Builder
  private searchDestination(param: Object) {
    SearchPage({
      initialQuery: this.searchParams(param).initialQuery,
      chrome: this.searchParams(param).chrome,
      scroller: this.searchScroller,
      onOpenGallery: (galleryId: number, seed?: NhGallerySummary): void => {
        this.pushGallery(galleryId, seed)
      },
    })
  }

  @Builder
  private popularDestination() {
    HdsNavDestination() {
      PopularPage({
        scroller: this.popularScroller,
        onOpenGallery: (galleryId: number, seed?: NhGallerySummary): void => {
          this.pushGallery(galleryId, seed)
        },
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('title_popular')))
    .hideBackButton(false)
    .bindToScrollable([this.popularScroller])
  }

  @Builder
  private galleryDestination(param: Object) {
    HdsNavDestination() {
      GalleryDetailPage({
        galleryId: this.galleryParams(param).galleryId,
        seed: this.galleryParams(param).seed,
        chrome: this.galleryParams(param).chrome,
        scroller: this.galleryScroller,
        externalOpenVersion: this.galleryExternalOpenVersion,
        shareVersion: this.galleryShareVersion,
        favoriteVersion: this.galleryFavoriteVersion,
        torrentShareVersion: this.galleryTorrentShareVersion,
        onOpenGallery: (galleryId: number, seed?: NhGallerySummary): void => {
          this.pushGallery(galleryId, seed)
        },
        onOpenThumbnails: (galleryId: number, pages: NhGalleryPage[]): void => {
          this.pushThumbnails(galleryId, pages)
        },
        onOpenReader: (galleryId: number, initialPageIndex: number): void => {
          this.pushReader(galleryId, initialPageIndex)
        },
        onOpenComments: (
          galleryId: number,
          commentSnapshot: NhComment[],
          commentSnapshotAvailable: boolean,
        ): void => {
          this.pushComments(galleryId, commentSnapshot, commentSnapshotAvailable)
        },
        onOpenDownloads: (): void => {
          this.openDownloads()
        },
        onSearchQuery: (query: string): void => {
          this.pushSearch(query)
        },
        onChromeChanged: (): void => {
          this.galleryChromeVersion += 1
        },
      })
    }
    // Gallery's semantic title lives in its header first, then hands off to
    // HDS after the header scrolls away.
    .titleBar(this.galleryTitleBar(this.galleryParams(param)))
    // The retained Gallery destination owns the root title-bar instance. Hide
    // it only while the private Reader overlay is visible so its HDS menu
    // leaves cannot receive top-chrome input behind Reader.
    .hideTitleBar(this.readerOverlay.visible)
    .hideBackButton(false)
    .bindToScrollable([this.galleryScroller])
  }

  @Builder
  private readerOverlayBackdropDestination() {
    HdsNavDestination() {
      Column() {}
        .id('reader-overlay-backdrop')
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
    }
    .hideTitleBar(true)
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private readerDestination(param: Object) {
    HdsNavDestination() {
      ReaderPage({
        galleryId: this.readerParams(param).galleryId,
        initialPageIndex: this.readerParams(param).initialPageIndex,
        readerRouteEpoch: this.readerParams(param).routeEpoch,
        settingsSheetContent: (dismiss: () => void): void => {
          this.ReaderSettingsSheet(dismiss)
        },
        onBack: (): void => {
          this.closeReaderDestination()
        },
        onReaderPresentationChanged: (chromeVisible: boolean, fullscreen: boolean, canvasDark: boolean): void => {
          this.recordReaderPresentation(
            this.readerParams(param).routeEpoch,
            chromeVisible,
            fullscreen,
            canvasDark,
          )
        },
      })
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      this.closeReaderDestination()
      return true
    })
    .onShown((): void => {
      this.readerDestinationVisible = true
      this.readerDestinationClosing = false
      this.readerDestinationRouteEpoch = this.readerParams(param).routeEpoch
      if (this.readerPresentationPending &&
        this.readerPresentationRouteEpoch === this.readerDestinationRouteEpoch) {
        this.applyRecordedReaderPresentation()
        return
      }
      this.clearRecordedReaderPresentation()
      // Reader restores its persisted preference asynchronously. Use the
      // documented default only until the current route publishes its state.
      this.requestReaderStatusBar(false, true)
    })
    .onWillHide((): void => {
      this.readerDestinationVisible = false
      this.readerDestinationClosing = true
      this.clearRecordedReaderPresentation()
      this.restoreAppStatusBar()
    })
    .onDisAppear((): void => {
      this.readerDestinationVisible = false
      this.clearRecordedReaderPresentation()
      this.readerOverlay.finishClose()
    })
  }

  /** The private Reader overlay injects the shared Settings semantic surface as a modal sheet. */
  @Builder
  private ReaderSettingsSheet(dismiss: () => void) {
    SettingsPage({
      surface: SettingsSurface.READER,
      sheetPresentation: true,
      onClose: (): void => {
        dismiss()
      },
    })
  }

  @Builder
  private thumbnailsDestination(param: Object) {
    HdsNavDestination() {
      GalleryThumbnailsPage({
        galleryId: this.thumbnailParams(param).galleryId,
        pages: this.thumbnailParams(param).pages,
        chrome: this.thumbnailParams(param).chrome,
        scroller: this.thumbnailScroller,
        onOpenReader: (galleryId: number, pageIndex: number): void => {
          this.pushReader(galleryId, pageIndex)
        },
      })
    }
    .titleBar(this.thumbnailsTitleBar(this.thumbnailParams(param)))
    .hideBackButton(false)
    .bindToScrollable([this.thumbnailScroller])
  }

  @Builder
  private commentsDestination(param: Object) {
    GalleryCommentsPage({
      galleryId: this.galleryParams(param).galleryId,
      scroller: this.commentsScroller,
      commentSnapshot: this.galleryParams(param).commentSnapshot,
      commentSnapshotAvailable: this.galleryParams(param).commentSnapshotAvailable,
    })
  }

  @Builder
  private browserSessionDestination(param: Object) {
    HdsNavDestination() {
      BrowserSessionPage({
        autoOpenVisibleLogin: this.browserSessionParams(param).autoOpenVisibleLogin,
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_account')))
    .hideBackButton(false)
  }

  @Builder
  private accountDestination() {
    HdsNavDestination() {
      AccountPage({
        onOpenBrowserSession: (): void => {
          this.pushBrowserSession()
        },
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_account')))
    .hideBackButton(false)
  }

  @Builder
  private contentFiltersDestination() {
    HdsNavDestination() {
      ContentFiltersPage({ scroller: this.contentFiltersScroller })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('title_content_filters')))
    .hideBackButton(false)
    .bindToScrollable([this.contentFiltersScroller])
  }

  @Builder
  private layoutSettingsDestination() {
    HdsNavDestination() {
      SettingsPage({
        surface: SettingsSurface.LAYOUT,
        scroller: this.layoutSettingsScroller,
        onOpenBrowseDensity: (mode: NhBrowsePresentation): void => {
          this.pushBrowseDensitySettings(mode)
        },
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_layout')))
    .hideBackButton(false)
    .bindToScrollable([this.layoutSettingsScroller])
  }

  @Builder
  private browseSettingsDestination() {
    HdsNavDestination() {
      SettingsPage({
        surface: SettingsSurface.BROWSE,
        scroller: this.browseSettingsScroller,
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_browse')))
    .hideBackButton(false)
    .bindToScrollable([this.browseSettingsScroller])
  }

  @Builder
  private searchSettingsDestination() {
    HdsNavDestination() {
      SettingsPage({
        surface: SettingsSurface.SEARCH,
        scroller: this.searchSettingsScroller,
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_search')))
    .hideBackButton(false)
    .bindToScrollable([this.searchSettingsScroller])
  }

  @Builder
  private browseDensitySettingsDestination(param: Object) {
    HdsNavDestination() {
      BrowseDensitySettingsPage({
        targetPresentation: this.browseDensityParams(param).mode,
        scroller: this.browseDensitySettingsScroller,
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_browse_column_width')))
    .hideBackButton(false)
    .bindToScrollable([this.browseDensitySettingsScroller])
  }

  @Builder
  private readerSettingsDestination() {
    HdsNavDestination() {
      SettingsPage({
        surface: SettingsSurface.READER,
        scroller: this.readerSettingsScroller,
        onOpenReaderEnhancementModels: (): void => {
          this.pushReaderSuperResolutionModels()
        },
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_reader')))
    .hideBackButton(false)
    .bindToScrollable([this.readerSettingsScroller])
  }

  @Builder
  private readerSuperResolutionModelsDestination() {
    HdsNavDestination() {
      ReaderSuperResolutionModelsPage({ scroller: this.readerSuperResolutionModelsScroller })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_reader_enhancement_models')))
    .hideBackButton(false)
    .bindToScrollable([this.readerSuperResolutionModelsScroller])
    .backgroundColor(ThemeTokens.SURFACE)
  }

  @Builder
  private llmSourceManagerDestination(param: Object) {
    HdsNavDestination() {
      LlmSourceManagerPage({
        scroller: this.translationSourceScroller,
        onOpenSource: (sourceProfileId: string): void => {
          this.pushLlmSourceDetail(sourceProfileId)
        },
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('llm_sources_title')))
    .hideBackButton(false)
    .bindToScrollable([this.translationSourceScroller])
  }

  @Builder
  private llmSourceDetailDestination(param: Object) {
    HdsNavDestination() {
      LlmSourceDetailPage({
        scroller: this.translationSourceScroller,
        requestedSourceProfileId: this.llmSourceDetailParams(param).sourceProfileId,
        onDeleted: (): void => {
          this.stack.pop()
        },
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('llm_source_detail_title')))
    .hideBackButton(false)
    .bindToScrollable([this.translationSourceScroller])
  }

  @Builder
  private mangaRenderingServiceDestination() {
    HdsNavDestination() {
      MangaRenderingServiceSettingsPage({ scroller: this.mangaRenderingServiceScroller })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_manga_rendering_service')))
    .hideBackButton(false)
    .bindToScrollable([this.mangaRenderingServiceScroller])
  }

  @Builder
  private downloadSettingsDestination() {
    HdsNavDestination() {
      SettingsPage({ surface: SettingsSurface.DOWNLOAD, scroller: this.downloadSettingsScroller })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_download')))
    .hideBackButton(false)
    .bindToScrollable([this.downloadSettingsScroller])
  }

  @Builder
  private cacheSettingsDestination() {
    HdsNavDestination() {
      SettingsPage({
        surface: SettingsSurface.CACHE,
        scroller: this.cacheSettingsScroller,
        onOpenSyncSettings: (): void => {
          this.pushSyncSettings()
        },
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_cache')))
    .hideBackButton(false)
    .bindToScrollable([this.cacheSettingsScroller])
  }

  @Builder
  private syncSettingsDestination() {
    HdsNavDestination() {
      SyncSettingsPage({
        scroller: this.syncSettingsScroller,
        onOpenWebDavSyncSettings: (): void => {
          this.pushWebDavSyncSettings()
        },
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_sync')))
    .hideBackButton(false)
    .bindToScrollable([this.syncSettingsScroller])
  }

  @Builder
  private webDavSyncSettingsDestination() {
    HdsNavDestination() {
      WebDavSyncSettingsPage({ scroller: this.webDavSyncSettingsScroller })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('sync_webdav')))
    .hideBackButton(false)
    .bindToScrollable([this.webDavSyncSettingsScroller])
  }

  @Builder
  private advancedSettingsDestination() {
    HdsNavDestination() {
      SettingsPage({
        surface: SettingsSurface.ADVANCED,
        scroller: this.advancedSettingsScroller,
        onOpenCommentTranslation: (): void => {
          this.pushCommentTranslationSettings()
        },
        onOpenComicTranslation: (): void => {
          this.pushComicTranslationSettings()
        },
        onOpenTagTranslation: (): void => {
          this.pushTagTranslationSettings()
        },
        onOpenContentFilters: (): void => {
          this.pushContentFilters()
        },
        onOpenTranslationSource: (): void => {
          this.pushLlmSourceManager()
        },
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_advanced')))
    .hideBackButton(false)
    .bindToScrollable([this.advancedSettingsScroller])
  }

  @Builder
  private tagTranslationSettingsDestination() {
    HdsNavDestination() {
      TagTranslationSettingsPage({ scroller: this.tagTranslationSettingsScroller })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_tag_translation_title')))
    .hideBackButton(false)
    .bindToScrollable([this.tagTranslationSettingsScroller])
  }

  @Builder
  private commentTranslationSettingsDestination() {
    HdsNavDestination() {
      CommentTranslationSettingsPage({
        scroller: this.commentTranslationSettingsScroller,
        onOpenTranslationSource: (consumerId: string): void => {
          this.pushLlmSourceManager()
        },
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_comment_translation')))
    .hideBackButton(false)
    .bindToScrollable([this.commentTranslationSettingsScroller])
  }

  @Builder
  private comicTranslationSettingsDestination() {
    HdsNavDestination() {
      ComicTranslationSettingsPage({
        scroller: this.comicTranslationSettingsScroller,
        onOpenTranslationSource: (consumerId: string): void => {
          this.pushLlmSourceManager()
        },
        onOpenMangaRenderingService: (): void => {
          this.pushMangaRenderingService()
        },
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_reader_comic_translation')))
    .hideBackButton(false)
    .bindToScrollable([this.comicTranslationSettingsScroller])
  }

  @Builder
  private aboutDestination() {
    HdsNavDestination() {
      AboutPage({ scroller: this.aboutScroller })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_about')))
    .hideBackButton(false)
    .bindToScrollable([this.aboutScroller])
  }

  @Builder
  private historyDestination() {
    HdsNavDestination() {
      HistoryPage({
        scroller: this.historyScroller,
        clearVersion: this.historyClearVersion,
        onOpenGallery: (galleryId: number, seed?: NhGallerySummary): void => {
          this.pushGallery(galleryId, seed)
        },
      })
    }
    .titleBar(this.historyDestinationTitleBar())
    .hideBackButton(false)
    .bindToScrollable([this.historyScroller])
    .backgroundColor(ThemeTokens.SURFACE)
  }

  private splitPlaceholder(): ComponentContent<Object> {
    if (this.splitPlaceholderContent === null) {
      this.splitPlaceholderContent = new ComponentContent<Object>(
        this.getUIContext(),
        wrapBuilder<[Object]>(IndexSplitPlaceholderCCBuilder),
        new Object(),
      )
    }
    return this.splitPlaceholderContent
  }

  /**
   * Policy gates only whether HDS may choose its adaptive wide split. AUTO
   * deliberately leaves HDS in charge of its width breakpoint; OFF and a
   * portrait landscape-only window retain the current Stack behaviour.
   */
  private rootNavigationMode(): NavigationMode {
    return TabletLayoutSettings.allowsSplit(
      this.tabletLayout.mode,
      this.layoutSafeArea.mainWindowWidthPx,
      this.layoutSafeArea.mainWindowHeightPx,
    )
      ? NavigationMode.Auto
      : NavigationMode.Stack
  }

  /** Static route map; entry is allowed to statically import feature HAR pages. */
  @Builder
  private routerMap(name: string, param: Object) {
    if (name === ROUTE_SEARCH) {
      this.searchDestination(param)
    } else if (name === ROUTE_POPULAR) {
      this.popularDestination()
    } else if (name === ROUTE_GALLERY) {
      this.galleryDestination(param)
    } else if (name === ROUTE_THUMBNAILS) {
      this.thumbnailsDestination(param)
    } else if (name === ROUTE_COMMENTS) {
      this.commentsDestination(param)
    } else if (name === ROUTE_BROWSER_SESSION) {
      this.browserSessionDestination(param)
    } else if (name === ROUTE_ACCOUNT) {
      this.accountDestination()
    } else if (name === ROUTE_SYNC_SETTINGS) {
      this.syncSettingsDestination()
    } else if (name === ROUTE_WEBDAV_SYNC_SETTINGS) {
      this.webDavSyncSettingsDestination()
    } else if (name === ROUTE_LAYOUT_SETTINGS) {
      this.layoutSettingsDestination()
    } else if (name === ROUTE_BROWSE_SETTINGS) {
      this.browseSettingsDestination()
    } else if (name === ROUTE_SEARCH_SETTINGS) {
      this.searchSettingsDestination()
    } else if (name === ROUTE_BROWSE_DENSITY_SETTINGS) {
      this.browseDensitySettingsDestination(param)
    } else if (name === ROUTE_CONTENT_FILTERS) {
      this.contentFiltersDestination()
    } else if (name === ROUTE_READER_SETTINGS) {
      this.readerSettingsDestination()
    } else if (name === ROUTE_READER_SUPER_RESOLUTION_MODELS) {
      this.readerSuperResolutionModelsDestination()
    } else if (name === ROUTE_LLM_SOURCE_MANAGER) {
      this.llmSourceManagerDestination(param)
    } else if (name === ROUTE_LLM_SOURCE_DETAIL) {
      this.llmSourceDetailDestination(param)
    } else if (name === ROUTE_MANGA_RENDERING_SERVICE) {
      this.mangaRenderingServiceDestination()
    } else if (name === ROUTE_DOWNLOAD_SETTINGS) {
      this.downloadSettingsDestination()
    } else if (name === ROUTE_CACHE_SETTINGS) {
      this.cacheSettingsDestination()
    } else if (name === ROUTE_ADVANCED_SETTINGS) {
      this.advancedSettingsDestination()
    } else if (name === ROUTE_TAG_TRANSLATION_SETTINGS) {
      this.tagTranslationSettingsDestination()
    } else if (name === ROUTE_COMMENT_TRANSLATION_SETTINGS) {
      this.commentTranslationSettingsDestination()
    } else if (name === ROUTE_COMIC_TRANSLATION_SETTINGS) {
      this.comicTranslationSettingsDestination()
    } else if (name === ROUTE_HISTORY) {
      this.historyDestination()
    } else if (name === ROUTE_ABOUT) {
      this.aboutDestination()
    } else {
      HdsNavDestination() {
        Column() {}
      }
      .hideTitleBar(true)
    }
  }

  /** The Reader's router deliberately has no root-tab routes. */
  @Builder
  private readerOverlayRouterMap(name: string, param: Object) {
    if (name === ROUTE_READER_OVERLAY_BACKDROP) {
      this.readerOverlayBackdropDestination()
    } else if (name === ROUTE_READER) {
      this.readerDestination(param)
    } else {
      HdsNavDestination() {
        Column() {}
      }
      .hideTitleBar(true)
    }
  }

  build() {
    Stack() {
      HdsNavigation(this.stack) {
      HdsTabs({ controller: this.tabsController }) {
        TabContent() {
          HomePage({
            onOpenGallery: (galleryId: number, seed?: NhGallerySummary): void => {
              this.selectHomeGalleryDetail(galleryId, seed)
            },
            onScrollerReady: (scroller: Scroller): void => {
              this.onHomeSourceScrollerReady(scroller)
            },
            onDidScroll: (offset: number, state: ScrollState): void => {
              this.onHomeTabDidScroll(0, offset, state)
            },
          })
        }
        .tabBar(this.tabBar(AppStrings.get('tab_browse'), 0))
        TabContent() {
          FavoritesPage({
            scroller: this.rootTabScrollers[1],
            onOpenGallery: (galleryId: number, seed?: NhGallerySummary): void => {
              this.pushGallery(galleryId, seed)
            },
            onDidScroll: (offset: number, state: ScrollState): void => {
              this.onHomeTabDidScroll(1, offset, state)
            },
          })
        }
        .tabBar(this.tabBar(AppStrings.get('tab_favorites'), 1))
        TabContent() {
          DownloadQueuePage({
            scroller: this.rootTabScrollers[2],
            onOpenGallery: (galleryId: number, seed?: NhGallerySummary): void => {
              this.pushGallery(galleryId, seed)
            },
            onOpenReader: (galleryId: number): void => {
              this.pushReader(galleryId)
            },
            onDidScroll: (offset: number, state: ScrollState): void => {
              this.onHomeTabDidScroll(2, offset, state)
            },
          })
        }
        .tabBar(this.tabBar(AppStrings.get('tab_downloads'), 2))
        TabContent() {
          SettingsPage({
            scroller: this.rootTabScrollers[3],
            onOpenHistory: (): void => {
              this.pushHistory()
            },
            onOpenBrowserSession: (): void => {
              this.pushBrowserSession()
            },
            onOpenAccount: (): void => {
              this.pushAccount()
            },
            onOpenLayoutSettings: (): void => {
              this.pushLayoutSettings()
            },
            onOpenBrowseSettings: (): void => {
              this.pushBrowseSettings()
            },
            onOpenSearchSettings: (): void => {
              this.pushSearchSettings()
            },
            onOpenReaderSettings: (): void => {
              this.pushReaderSettings()
            },
            onOpenDownloadSettings: (): void => {
              this.pushDownloadSettings()
            },
            onOpenCacheSettings: (): void => {
              this.pushCacheSettings()
            },
            onOpenSyncSettings: (): void => {
              this.pushSyncSettings()
            },
            onOpenAdvancedSettings: (): void => {
              this.pushAdvancedSettings()
            },
            onOpenAbout: (): void => {
              this.pushAbout()
            },
            onOpenContentFilters: (): void => {
              this.pushContentFilters()
            },
            onDidScroll: (offset: number, state: ScrollState): void => {
              this.onHomeTabDidScroll(3, offset, state)
            },
          })
        }
        .tabBar(this.tabBar(AppStrings.get('tab_me'), 3))
      }
      .width('100%')
      .height('100%')
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .barMode(BarMode.Fixed)
      .scrollable(false)
      .animationDuration(0)
      .barFloatingStyle({
        barBottomMargin: ThemeTokens.SPACE_XL,
        adaptToHandedness: true,
        systemMaterialEffect: this.rootMaterialEffect(),
      })
      .onAppear((): void => {
        this.applyHomeTabAutoHide()
      })
      .onChange((index: number): void => {
        // Match NextE's root-shell ownership: a different root tab ends the
        // current secondary navigation context instead of retaining a detail
        // page behind unrelated tab content.
        const changed: boolean = index !== this.activeTab
        if (changed) {
          this.cancelRandomGalleryRequest()
          if (this.stack.getAllPathName().length > 0) {
            this.stack.clear(false)
          }
          this.settingsNavigation.clearRootLocation()
          this.clearHomeGallerySelection()
        }
        this.activeTab = index
        this.titleScroller = index === 0 ? this.homeActiveScroller : this.rootTabScrollers[index]
        if (this.homeTab.autoHide) {
          this.restoreHomeTabIfHidden()
        }
      })
      }
      .navDestination(this.routerMap)
      // The root shell owns the optional large-screen split. Root tabs remain
      // the primary pane; detail routes stay on this existing root stack.
      .mode(this.rootNavigationMode())
      // NavigationMode.Auto is a policy request, not proof of a physical
      // split. Publish the HDS-resolved result for destination layout caches.
      .onNavigationModeChange((mode: NavigationMode): void => {
        LayoutSafeAreaBridge.publishRootNavigationSplit(mode === NavigationMode.Split)
      })
      .splitPlaceholder(this.splitPlaceholder())
      .navBarWidth(ThemeTokens.TABLET_PRIMARY_PANE_WIDTH)
      // Use NextE's fixed readable floor while allowing the native HDS drag
      // divider to expand the primary pane until the detail pane reaches its
      // own minimum width.
      .navBarWidthRange({
        minWidth: ThemeTokens.TABLET_PRIMARY_PANE_MIN_WIDTH,
        maxWidth: '100%',
      })
      .minContentWidth(ThemeTokens.TABLET_DETAIL_MIN_WIDTH)
      .enableDragBar(true)
      .titleBar(this.rootTitleBar())
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .dynamicHideTitleBar({
        hideTitleArea: true,
        hideBottomBuilder: false,
        hideStatusBar: false,
        mode: HideMode.SCROLL_UP,
      })
      .bindToScrollable([this.titleScroller])
      .width('100%')
      .height('100%')

      // The host is a transparent one-pixel overlay: it does not participate
      // in HDS layout. It exists only so authenticated v2 requests can stay
      // in the ArkWeb context that completed the visible login challenge.
      NhArkWebSessionTransportHost()

      // Reader deliberately owns a private full-window navigation stack. The
      // root HDS stack remains mounted below it, preserving the active tab,
      // Gallery detail, or thumbnails state through Reader close.
      if (this.readerOverlay.visible) {
        HdsNavigation(this.readerOverlay.stack) {
          Column() {}
        }
        .navDestination(this.readerOverlayRouterMap)
        .hideNavBar(true)
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .onAppear((): void => {
          this.readerOverlay.presentPendingReader()
        })
        .id('reader-overlay-navigation')
      }
    }
    .width('100%')
    .height('100%')
  }
}
