import { HomePage, HomeSubtabManagerPage, PopularPage } from 'home'
import {
  GalleryChromeState,
  GalleryCommentsPage,
  GalleryDetailPage,
  GalleryThumbnailsChromeState,
  GalleryThumbnailsPage,
} from 'gallery'
import {
  SearchChromeState,
  HomeSubtabEditPage,
  SearchPage,
} from 'search'
import { ReaderPage } from 'reader'
import {
  BrowserSessionPage,
  FAVORITES_TITLE_SEARCH_HEIGHT,
  FavoritesPage,
  FavoritesTitleSearchFieldCCBuilder,
  HistoryPage,
  HistoryPinnedDayHeaderCCBuilder,
  HistoryPinnedDayHeaderState,
  HISTORY_PINNED_DAY_HEADER_HEIGHT,
  connectHistoryPinnedDayHeader,
} from 'user'
import {
  DOWNLOAD_TITLE_SEARCH_HEIGHT,
  DownloadTitleBarCCBuilder,
  DownloadQueuePage,
  DownloadPinnedGroupHeaderState,
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
  LocalUserTagsPage,
  ReaderSuperResolutionModelsPage,
  SettingsPage,
  SettingsSurface,
  SyncSettingsPage,
  TagTranslationSettingsPage,
  ToriiWholePageLiveEvaluationPage,
  ToriiWholePageLiveEvaluationRouteParams,
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
  HdsSnackBar,
  SnackBarIconOptions,
  SnackBarMessageOptions,
  SnackBarOperationOptions,
  SnackBarOperationType,
  SnackBarStyleOptions,
} from '@kit.UIDesignKit'
import { ComponentContent, curves, FrameCallback, window } from '@kit.ArkUI'
import { image } from '@kit.ImageKit'
import {
  nextNHdsTitle,
  nextNHdsTitleBar,
  AppStrings,
  AccountAuthNoticeState,
  AccountListState,
  AccountSessionState,
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
  HomeSubtabEditParams,
  HomeSubtabState,
  NhHomeSubtabKind,
  NhHomeSubtabProfile,
  HomeTabAutoHideState,
  LLM_CONSUMER_COMMENT_TRANSLATION,
  LLM_CONSUMER_MANGA_TRANSLATION,
  ImmersiveMaterialSettings,
  ImmersiveMaterialSettingsState,
  LlmConsumerBinding,
  LlmSourceProfilesState,
  HOME_SOURCE_SELECTOR_HEIGHT,
  TabletLayoutSettings,
  TabletLayoutState,
  ThemeDisplayState,
  ToriiWholePageLiveEvaluationReport,
  connectGalleryDirectLaunch,
  connectAccountList,
  connectAccountSession,
  connectAccountAuthNotice,
  connectLayoutSafeArea,
  connectLoginRecoveryLaunch,
  connectDownloadQueueActions,
  connectFavoritesActions,
  connectHomeGallerySelection,
  connectHomeSource,
  connectHomeSubtabs,
  connectHomeTabAutoHide,
  connectImmersiveMaterialSettings,
  connectLlmSourceProfiles,
  connectTabletLayout,
  connectThemeDisplay,
  NhBrowserSessionBoundary,
  NhBrowsePresentation,
  NhComment,
  NhDownloadTaskStatus,
  NhApiClient,
  NhGalleryDetail,
  NhGalleryPage,
  NhGallerySummary,
  GalleryDetailTransitionPhase,
  GalleryDetailTransitionState,
  GalleryDetailTransitionCoordinator,
  ReaderThumbnailTransitionState,
  ReaderThumbnailTransitionCoordinator,
  ReaderOverlayNavigationState,
  SafeModeGate,
  SafeModeState,
  SettingsNavigationState,
  ReaderRouteParams,
  NhClipboardLinkState,
  RootRefreshRegistry,
  ThemeTokens,
  DiagnosticLogger,
  EhImageKnifeImage,
  connectGalleryDetailTransition,
  connectReaderThumbnailTransition,
  connectReaderOverlayNavigation,
  connectSafeMode,
  connectSettingsNavigation,
  clearNhClipboardGalleryCandidate,
  connectNhClipboardLink,
} from 'shared'
import { HomeSourceBarCCBuilder } from '../components/HomeSourceBar'
import { MainTabIcon } from '../components/MainTabIcon'
import { GalleryWebPage } from './GalleryWebPage'

const ROUTE_SEARCH: string = 'search'
const ROUTE_HOME_SUBTAB_MANAGER: string = 'homeSubtabManager'
const ROUTE_HOME_SUBTAB_EDIT: string = 'homeSubtabEdit'
const ROUTE_POPULAR: string = 'popular'
const ROUTE_GALLERY: string = 'gallery'
const ROUTE_GALLERY_WEB: string = 'GalleryWeb'
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
const ROUTE_LOCAL_USER_TAGS: string = 'localUserTags'
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
const ROUTE_TORII_WHOLE_PAGE_LIVE_EVALUATION: string = 'toriiWholePageLiveEvaluation'
const ROUTE_ABOUT: string = 'about'
const STATUS_BAR_LIGHT_CONTENT: string = '#FFFFFFFF'
const STATUS_BAR_DARK_CONTENT: string = '#FF000000'
const READER_ENTRY_STATUS_BAR_HIDE_DELAY_MS: number = 500

const GALLERY_DETAIL_OPEN_CURVE: curves.ICurve = curves.cubicBezierCurve(0.2, 0, 0, 1)
const GALLERY_DETAIL_CLOSE_CURVE: curves.ICurve = curves.cubicBezierCurve(0.3, 0, 0.2, 1)
// These thresholds are measured against visible geometry progress, not elapsed time. Changing a
// curve therefore cannot silently move the card/detail ownership handoff to a different window size.
const GALLERY_DETAIL_OPEN_CARD_EXIT_START_PROGRESS: number = 0
const GALLERY_DETAIL_OPEN_CARD_EXIT_END_PROGRESS: number = 0.55
const GALLERY_DETAIL_CLOSE_CARD_ENTRY_START_PROGRESS: number = 0.55
const GALLERY_DETAIL_CLOSE_CARD_ENTRY_END_PROGRESS: number = 0.9
const GALLERY_DETAIL_COVER_OPEN_CARD_EXIT_START_PROGRESS: number = 0.15
const GALLERY_DETAIL_COVER_OPEN_CARD_EXIT_END_PROGRESS: number = 0.5
const GALLERY_DETAIL_COVER_CLOSE_CARD_ENTRY_START_PROGRESS: number = 0.5
const GALLERY_DETAIL_COVER_CLOSE_CARD_ENTRY_END_PROGRESS: number = 0.75
const GALLERY_DETAIL_CURVE_INVERSE_ITERATIONS: number = 16

function galleryDetailTimeAtProgress(curve: curves.ICurve, targetProgress: number): number {
  const boundedTarget: number = Math.max(0, Math.min(1, targetProgress))
  let lower: number = 0
  let upper: number = 1
  for (let index: number = 0; index < GALLERY_DETAIL_CURVE_INVERSE_ITERATIONS; index += 1) {
    const candidate: number = (lower + upper) / 2
    if (curve.interpolate(candidate) < boundedTarget) {
      lower = candidate
    } else {
      upper = candidate
    }
  }
  return (lower + upper) / 2
}

const GALLERY_DETAIL_OPEN_CARD_EXIT_START_TIME: number = galleryDetailTimeAtProgress(
  GALLERY_DETAIL_OPEN_CURVE,
  GALLERY_DETAIL_OPEN_CARD_EXIT_START_PROGRESS,
)
const GALLERY_DETAIL_OPEN_CARD_EXIT_END_TIME: number = galleryDetailTimeAtProgress(
  GALLERY_DETAIL_OPEN_CURVE,
  GALLERY_DETAIL_OPEN_CARD_EXIT_END_PROGRESS,
)
const GALLERY_DETAIL_COVER_OPEN_CARD_EXIT_START_TIME: number = galleryDetailTimeAtProgress(
  GALLERY_DETAIL_OPEN_CURVE,
  GALLERY_DETAIL_COVER_OPEN_CARD_EXIT_START_PROGRESS,
)
const GALLERY_DETAIL_COVER_OPEN_CARD_EXIT_END_TIME: number = galleryDetailTimeAtProgress(
  GALLERY_DETAIL_OPEN_CURVE,
  GALLERY_DETAIL_COVER_OPEN_CARD_EXIT_END_PROGRESS,
)
const GALLERY_DETAIL_CLOSE_CARD_ENTRY_START_TIME: number = galleryDetailTimeAtProgress(
  GALLERY_DETAIL_CLOSE_CURVE,
  GALLERY_DETAIL_CLOSE_CARD_ENTRY_START_PROGRESS,
)
const GALLERY_DETAIL_CLOSE_CARD_ENTRY_END_TIME: number = galleryDetailTimeAtProgress(
  GALLERY_DETAIL_CLOSE_CURVE,
  GALLERY_DETAIL_CLOSE_CARD_ENTRY_END_PROGRESS,
)
const GALLERY_DETAIL_COVER_CLOSE_CARD_ENTRY_START_TIME: number = galleryDetailTimeAtProgress(
  GALLERY_DETAIL_CLOSE_CURVE,
  GALLERY_DETAIL_COVER_CLOSE_CARD_ENTRY_START_PROGRESS,
)
const GALLERY_DETAIL_COVER_CLOSE_CARD_ENTRY_END_TIME: number = galleryDetailTimeAtProgress(
  GALLERY_DETAIL_CLOSE_CURVE,
  GALLERY_DETAIL_COVER_CLOSE_CARD_ENTRY_END_PROGRESS,
)

/**
 * Typed params placed on the navigation stack. Keeping the route payload in the
 * entry shell prevents feature HARs from depending on one another.
 */
class GalleryRouteParams {
  galleryId: number = 0
  /** Runtime-only owner for this route instance's captured return transition. */
  transitionToken: string = ''
  /** Optional tapped-row snapshot; the detail paints it immediately before the verified response. */
  seed: NhGallerySummary | null = null
  /** Route-local scroll owner; stacked Gallery destinations must not overwrite each other's chrome offset. */
  scroller: Scroller = new Scroller()
  chrome: GalleryChromeState = new GalleryChromeState()
  commentSnapshot: NhComment[] = []
  commentSnapshotAvailable: boolean = false

  constructor(
    galleryId: number = 0,
    seed: NhGallerySummary | null = null,
    commentSnapshot: NhComment[] = [],
    commentSnapshotAvailable: boolean = false,
    transitionToken: string = '',
  ) {
    this.galleryId = galleryId
    this.seed = seed
    this.commentSnapshot = commentSnapshot
    this.commentSnapshotAvailable = commentSnapshotAvailable
    this.transitionToken = transitionToken
  }
}

class GalleryWebRouteParams {
  url: string = ''
  title: string = ''

  constructor(url: string = '', title: string = '') {
    this.url = url
    this.title = title
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
  detailSeed: NhGalleryDetail = new NhGalleryDetail()
  chrome: GalleryThumbnailsChromeState = new GalleryThumbnailsChromeState()

  constructor(
    galleryId: number = 0,
    pages: NhGalleryPage[] = [],
    detailSeed: NhGalleryDetail = new NhGalleryDetail(),
  ) {
    this.galleryId = galleryId
    this.pages = pages
    this.detailSeed = detailSeed.copy()
  }
}

class BrowseDensityRouteParams {
  mode: NhBrowsePresentation = NhBrowsePresentation.COVER_GRID

  constructor(mode: NhBrowsePresentation = NhBrowsePresentation.COVER_GRID) {
    this.mode = mode
  }
}

/** Login-only Web destination; native account management stays in AccountPage. */
class BrowserSessionRouteParams {
  autoOpenVisibleLogin: boolean = false
  addAccountMode: boolean = false

  constructor(autoOpenVisibleLogin: boolean = false, addAccountMode: boolean = false) {
    this.autoOpenVisibleLogin = autoOpenVisibleLogin
    this.addAccountMode = addAccountMode
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

class GalleryDetailPreparedPopFrameCallback extends FrameCallback {
  private action: () => void

  constructor(action: () => void) {
    super()
    this.action = action
  }

  onFrame(_frameTimeInNano: number): void {}

  onIdle(_timeLeftInNano: number): void {
    this.action()
  }
}

@ComponentV2
struct IndexReaderThumbnailTransitionProxy {
  @Require @Param state: ReaderThumbnailTransitionState

  build() {
    if (this.state.rootProxyVisible()) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.state.closingProxyVisible()) {
          if (this.state.readerSnapshot !== undefined) {
            Image(this.state.readerSnapshot)
              .width(this.state.proxyContentWidth())
              .height(this.state.proxyContentHeight())
              .objectFit(ImageFit.Fill)
              .syncLoad(true)
          } else if (this.state.closeTargetSnapshot !== undefined) {
            Image(this.state.closeTargetSnapshot)
              .width(this.state.proxyContentWidth())
              .height(this.state.proxyContentHeight())
              .objectFit(ImageFit.Fill)
              .syncLoad(true)
          }
          if (this.state.readerSnapshot !== undefined && this.state.closeTargetSnapshot !== undefined) {
            Image(this.state.closeTargetSnapshot)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Fill)
              .syncLoad(true)
              .opacity(this.state.closeTargetSnapshotOpacity)
          }
        } else {
          if (this.state.openingReverse() && this.state.openingReverseSnapshot !== undefined) {
            Image(this.state.openingReverseSnapshot)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Fill)
              .syncLoad(true)
          } else if (this.state.sourceSnapshot !== undefined) {
            Image(this.state.sourceSnapshot)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Fill)
              .syncLoad(true)
          } else if (this.state.image.thumbnailUrl.length > 0) {
            Image(this.state.image.thumbnailUrl)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Fill)
          }
        }
      }
      .width(this.state.proxyWidth)
      .height(this.state.proxyHeight)
      .position({ x: this.state.proxyX, y: this.state.proxyY })
      .borderRadius(this.state.proxyRadius)
      .clip(true)
      .opacity(this.state.closingProxyVisible() ? 1 : this.state.openingProxyOpacity)
      .hitTestBehavior(HitTestMode.None)
    }
  }
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
  private favoritesTitleSearchContent: ComponentContent<FavoritesActionState> | null = null
  private downloadTitleBarContent: ComponentContent<Object> | null = null
  private rootTabScrollers: Scroller[] = [new Scroller(), new Scroller(), new Scroller(), new Scroller()]
  // Retained Home sources own stable scrollers; this fallback is only used
  // before RetainedSubtabHost publishes its initial active source.
  private homeActiveScroller: Scroller = this.rootTabScrollers[0]
  private homeTabLastScrollOffsets: number[] = [0, 0, 0, 0]
  private homeTabAnimationGuardTimerId: number = -1
  private homeTabVisibleByScroll: boolean = true
  private searchScroller: Scroller = new Scroller()
  private homeSubtabManagerScroller: Scroller = new Scroller()
  private homeSubtabEditScroller: Scroller = new Scroller()
  private popularScroller: Scroller = new Scroller()
  private thumbnailScroller: Scroller = new Scroller()
  private commentsScroller: Scroller = new Scroller()
  private contentFiltersScroller: Scroller = new Scroller()
  private localUserTagsScroller: Scroller = new Scroller()
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
  @Local private accountList: AccountListState = connectAccountList()
  @Local private accountSession: AccountSessionState = connectAccountSession()
  @Local private accountAuthNotice: AccountAuthNoticeState = connectAccountAuthNotice()
  @Local private themeDisplay: ThemeDisplayState = connectThemeDisplay()
  @Local private tabletLayout: TabletLayoutState = connectTabletLayout()
  @Local private layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private downloadQueueActions: DownloadQueueActionState = connectDownloadQueueActions()
  @Local private homeGallerySelection: HomeGallerySelectionState = connectHomeGallerySelection()
  @Local private homeSource: HomeSourceState = connectHomeSource()
  @Local private homeSubtabs: HomeSubtabState = connectHomeSubtabs()
  @Local private historyPinnedDayHeader: HistoryPinnedDayHeaderState = connectHistoryPinnedDayHeader()
  @Local private downloadPinnedGroupHeader: DownloadPinnedGroupHeaderState = connectDownloadPinnedGroupHeader()
  @Local private homeTab: HomeTabAutoHideState = connectHomeTabAutoHide()
  @Local private safeMode: SafeModeState = connectSafeMode()
  @Local private immersiveMaterial: ImmersiveMaterialSettingsState = connectImmersiveMaterialSettings()
  @Local private galleryDetailTransition: GalleryDetailTransitionState = connectGalleryDetailTransition()
  @Local private readerThumbnailTransition: ReaderThumbnailTransitionState = connectReaderThumbnailTransition()
  @Local private readerOverlay: ReaderOverlayNavigationState = connectReaderOverlayNavigation()
  @Local private settingsNavigation: SettingsNavigationState = connectSettingsNavigation()
  @Local private clipboardLink: NhClipboardLinkState = connectNhClipboardLink()
  @Local private galleryDirectLaunch: GalleryDirectLaunchState = connectGalleryDirectLaunch()
  @Local private loginRecoveryLaunch: LoginRecoveryLaunchState = connectLoginRecoveryLaunch()
  /** Reactive chrome owner for the sole route in HDS's current secondary branch. */
  @Local private rootFirstSecondaryRoute: string = ''
  // HDS keeps the scrollable reference it is bound to.  Rebind it explicitly
  // on every root-tab switch, as NextE does, rather than deriving a temporary
  // array value during build.
  @Local private titleScroller: Scroller = this.rootTabScrollers[0]
  @Local private historyClearVersion: number = 0
  @Local private localUserTagsAddRequestVersion: number = 0
  @Local private favoritesActions: FavoritesActionState = connectFavoritesActions()
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
  private readerDestinationShownAtMs: number = 0
  private readerStatusBarHideTimerId: number = -1
  private readerSystemBarGeneration: number = 0
  private readerSystemBarWork: Promise<void> = Promise.resolve()
  private lastHandledClipboardCandidateRevision: number = 0
  private clipboardSnackBar: HdsSnackBar = new HdsSnackBar(this.getUIContext())
  private lastHandledAccountVerificationRevision: number = -1
  private displayedAccountVerificationRevision: number = -1
  private accountVerificationSnackBarVisible: boolean = false
  private accountVerificationSnackBar: HdsSnackBar = new HdsSnackBar(this.getUIContext())
  private lastHandledAccountAuthNoticeRevision: number = 0
  private accountAuthNoticeSnackBar: HdsSnackBar = new HdsSnackBar(this.getUIContext())
  @Local private randomGalleryBusy: boolean = false
  private randomGalleryActionEpoch: number = 0
  private rootNavigationEpoch: number = 0
  private galleryDetailTransitionSerial: number = 0
  private coverPopDispatching: boolean = false
  private readerBackRequest: (() => boolean) | null = null
  private readerDestinationCloseDispatched: boolean = false

  aboutToAppear(): void {
    this.installRootNavigationStateTracking()
    this.readerOverlay.reset()
    this.handleGalleryDirectLaunch()
    this.handleClipboardGalleryCandidate()
    this.handleLoginRecoveryLaunch()
    this.handleAccountVerificationRequired()
    this.handleAccountAuthNotice()
  }

  @Monitor('accountSession.revision')
  onAccountSessionChanged(): void {
    this.handleAccountVerificationRequired()
  }

  @Monitor('accountAuthNotice.revision')
  onAccountAuthNoticeChanged(): void {
    this.handleAccountAuthNotice()
  }

  /**
   * Publish the settled secondary branch into V2 state. Settings rows consume
   * this state instead of inspecting NavPathStack while building.
   */
  private installRootNavigationStateTracking(): void {
    this.settingsNavigation.syncSecondaryBranch(this.stack)
    this.syncHomeGallerySelection(this.stack)
    this.syncRootSecondaryBranch(this.stack)
    this.stack.setInterception({
      willShow: (_from, to, _operation, _animated): void => {
        this.cancelRandomGalleryRequest()
        const secondaryBranch: NavPathStack | null = typeof to === 'string' ? null : to.pathStack
        this.syncRootSecondaryBranch(secondaryBranch)
      },
      didShow: (_from, to, _operation, _animated): void => {
        this.rootNavigationEpoch += 1
        const secondaryBranch: NavPathStack | null = typeof to === 'string' ? null : to.pathStack
        this.settingsNavigation.syncSecondaryBranch(secondaryBranch)
        this.syncHomeGallerySelection(secondaryBranch)
        this.syncRootSecondaryBranch(secondaryBranch)
        // A verification event can arrive while the first-party login route
        // owns the foreground. Re-evaluate it after every settled route so a
        // temporarily suppressed root notice cannot disappear permanently.
        this.handleAccountVerificationRequired()
        this.handleAccountAuthNotice()
      },
    })
  }

  /**
   * Publish route depth into V2 state. NavPathStack is an imperative command
   * target, so reading it directly from a destination builder is not reactive.
   */
  private syncRootSecondaryBranch(pathStack: NavPathStack | null): void {
    const pathNames: string[] = pathStack === null ? [] : pathStack.getAllPathName()
    const nextRoute: string = pathNames.length === 1 ? pathNames[0] : ''
    if (this.rootFirstSecondaryRoute !== nextRoute) {
      this.rootFirstSecondaryRoute = nextRoute
    }
  }

  /** NextE rule: the sole destination in a physical secondary pane has no parent. */
  private rootDestinationBackButtonHidden(name: string): boolean {
    return this.layoutSafeArea.rootNavigationSplit && this.rootFirstSecondaryRoute === name
  }

  aboutToDisappear(): void {
    this.cancelRandomGalleryRequest()
    this.clearHomeTabAnimationGuardTimer()
  }

  @Monitor('homeTab.autoHide')
  onHomeTabAutoHideChanged(): void {
    this.applyHomeTabAutoHide()
  }

  @Monitor('safeMode.unlocked')
  onSafeModeChanged(): void {
    let target: number = this.activeTab
    if (this.safeMode.restricted()) {
      if (this.activeTab === 2) {
        target = 1
      } else if (this.activeTab === 3) {
        target = 2
      } else if (this.activeTab === 1) {
        target = 0
      }
    } else if (this.activeTab === 1 || this.activeTab === 2) {
      target = this.activeTab === 1 ? 2 : 3
    }
    this.cancelRandomGalleryRequest()
    this.activeTab = target
    this.titleScroller = this.rootTabScroller(target)
    this.applyHomeTabAutoHide()
    setTimeout((): void => {
      this.tabsController.changeIndex(target)
    }, 0)
    this.handleClipboardGalleryCandidate()
    // Safe Mode suppresses NH account surfaces, but it must not consume a
    // pending verification event. Re-evaluate the retained root notice when
    // the restriction changes in either direction.
    this.handleAccountVerificationRequired()
    this.handleAccountAuthNotice()
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

  @Monitor('homeSource.manageSubtabsRequestSeq')
  onManageHomeSubtabsRequested(): void {
    if (this.homeSource.manageSubtabsRequestSeq > 0) {
      this.pushHomeSubtabManager()
    }
  }

  @Monitor('homeSource.editSubtabRequestSeq')
  onEditHomeSubtabRequested(): void {
    if (this.homeSource.editSubtabRequestSeq > 0 && this.homeSource.editSubtabUuid.length > 0) {
      this.pushHomeSubtabEdit(new HomeSubtabEditParams(this.homeSource.editSubtabUuid))
    }
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
    if (this.safeMode.restricted()) {
      return
    }
    const galleryId: number = request.galleryId
    if (!Number.isSafeInteger(galleryId) || galleryId <= 0) {
      return
    }
    this.readerOverlay.reset()
    if (this.stack.getAllPathName().length > 0) {
      this.clearGalleryDetailTransitionOwnership()
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
    if (this.safeMode.restricted()) {
      return
    }
    if (this.stack.getAllPathName().length > 0) {
      this.clearGalleryDetailTransitionOwnership()
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
      this.safeMode.restricted() ||
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
    const icon: SnackBarIconOptions = {
      icon: $r('sys.symbol.link'),
    }
    const message: SnackBarMessageOptions = {
      title: AppStrings.get('clipboard_link_prompt_title'),
      content: AppStrings.get('clipboard_link_prompt_message'),
    }
    const operation: SnackBarOperationOptions = {
      operationType: SnackBarOperationType.TEXT_WITH_CLOSE,
      content: AppStrings.get('clipboard_link_open'),
      contentAccessibilityText: AppStrings.get('clipboard_link_open'),
      closeButtonAccessibilityText: AppStrings.get('common_cancel'),
      onContentClick: (): void => {
        this.clipboardSnackBar.dismiss()
        this.pushGallery(galleryId)
      },
      onCloseButtonClick: (): void => {
        this.clipboardSnackBar.dismiss()
      },
    }
    const style: SnackBarStyleOptions = {
      duration: 0,
    }
    this.clipboardSnackBar.dismiss()
    this.clipboardSnackBar.show(icon, message, operation, style)
  }

  /**
   * Terminal account authentication is one root-owned event. Feature pages
   * keep their cached content mounted and never invent local error banners;
   * this HDS surface is the sole visible request to re-verify the account.
   */
  private handleAccountVerificationRequired(): void {
    if (!this.accountSession.initialized || !this.accountSession.verificationRequired) {
      if (this.accountVerificationSnackBarVisible) {
        this.accountVerificationSnackBar.dismiss()
      }
      this.accountVerificationSnackBarVisible = false
      this.displayedAccountVerificationRevision = -1
      return
    }
    if (this.safeMode.restricted() || this.browserSessionRouteActive()) {
      if (this.accountVerificationSnackBarVisible) {
        this.accountVerificationSnackBar.dismiss()
      }
      // Suppression is not user handling. Keep the terminal revision pending
      // so it can be offered again after the root route becomes eligible.
      this.accountVerificationSnackBarVisible = false
      this.displayedAccountVerificationRevision = -1
      return
    }
    if (this.lastHandledAccountVerificationRevision === this.accountSession.revision) {
      return
    }
    if (this.accountVerificationSnackBarVisible &&
      this.displayedAccountVerificationRevision === this.accountSession.revision) {
      return
    }
    const verificationRevision: number = this.accountSession.revision
    const icon: SnackBarIconOptions = {
      icon: $r('sys.symbol.security_shield'),
    }
    const message: SnackBarMessageOptions = {
      title: AppStrings.get('account_status_verification_required'),
      content: AppStrings.get('account_subtitle_verification_required'),
    }
    const operation: SnackBarOperationOptions = {
      operationType: SnackBarOperationType.TEXT_WITH_CLOSE,
      content: AppStrings.get('account_verify_sign_in'),
      contentAccessibilityText: AppStrings.get('account_verify_sign_in_subtitle'),
      closeButtonAccessibilityText: AppStrings.get('common_cancel'),
      onContentClick: (): void => {
        this.lastHandledAccountVerificationRevision = verificationRevision
        this.accountVerificationSnackBarVisible = false
        this.displayedAccountVerificationRevision = -1
        this.accountVerificationSnackBar.dismiss()
        this.pushVisibleLoginSession()
      },
      onCloseButtonClick: (): void => {
        this.lastHandledAccountVerificationRevision = verificationRevision
        this.accountVerificationSnackBarVisible = false
        this.displayedAccountVerificationRevision = -1
        this.accountVerificationSnackBar.dismiss()
      },
    }
    const style: SnackBarStyleOptions = {
      duration: 0,
    }
    this.accountVerificationSnackBar.dismiss()
    this.displayedAccountVerificationRevision = verificationRevision
    this.accountVerificationSnackBarVisible = true
    this.accountVerificationSnackBar.show(icon, message, operation, style)
  }

  /** Explicit login failures are one root HDS event, never an inline list row. */
  private handleAccountAuthNotice(): void {
    if (this.browserSessionRouteActive()) {
      this.accountAuthNoticeSnackBar.dismiss()
      return
    }
    if (this.accountAuthNotice.revision <= 0 ||
      this.accountAuthNotice.revision === this.lastHandledAccountAuthNoticeRevision ||
      this.accountAuthNotice.code.length === 0 || this.safeMode.restricted()) {
      return
    }
    this.lastHandledAccountAuthNoticeRevision = this.accountAuthNotice.revision
    const specificKey: string = this.accountAuthNotice.code === 'rate_limited'
      ? 'account_api_login_rate_limited'
      : this.accountAuthNotice.code === 'challenge_unavailable' ||
          this.accountAuthNotice.code === 'challenge_invalid'
        ? 'account_api_login_challenge_unavailable'
      : this.accountAuthNotice.code === 'rejected' ||
          this.accountAuthNotice.code === 'verification_rejected'
        ? 'account_api_login_rejected'
        : this.accountAuthNotice.code === 'persistence_failed'
          ? 'account_api_login_save_failed'
          : 'account_api_login_failed'
    const icon: SnackBarIconOptions = {
      icon: $r('sys.symbol.security_shield'),
    }
    const message: SnackBarMessageOptions = {
      title: AppStrings.get('account_api_login_failed_title'),
      content: AppStrings.get(specificKey),
    }
    const operation: SnackBarOperationOptions = {
      operationType: SnackBarOperationType.TEXT_WITH_CLOSE,
      content: AppStrings.get('account_verify_sign_in'),
      contentAccessibilityText: AppStrings.get('account_verify_sign_in_subtitle'),
      closeButtonAccessibilityText: AppStrings.get('common_cancel'),
      onContentClick: (): void => {
        this.accountAuthNoticeSnackBar.dismiss()
        this.accountAuthNotice.clear()
        this.pushVisibleLoginSession()
      },
      onCloseButtonClick: (): void => {
        this.accountAuthNoticeSnackBar.dismiss()
        this.accountAuthNotice.clear()
      },
    }
    const style: SnackBarStyleOptions = { duration: 0 }
    this.accountAuthNoticeSnackBar.dismiss()
    this.accountAuthNoticeSnackBar.show(icon, message, operation, style)
  }

  private pushSearch(initialQuery: string = ''): void {
    if (this.safeMode.restricted()) {
      return
    }
    this.stack.pushPathByName(ROUTE_SEARCH, new SearchRouteParams(initialQuery.trim()))
  }

  private pushHomeSubtabManager(): void {
    if (this.safeMode.restricted()) {
      return
    }
    this.stack.pushPathByName(ROUTE_HOME_SUBTAB_MANAGER, '')
  }

  private pushHomeSubtabEdit(params: HomeSubtabEditParams): void {
    if (this.safeMode.restricted()) {
      return
    }
    this.stack.pushPathByName(ROUTE_HOME_SUBTAB_EDIT, params)
  }

  private pushPopular(): void {
    if (this.safeMode.restricted()) {
      return
    }
    this.stack.pushPathByName(ROUTE_POPULAR, '')
  }

  private pushGallery(galleryId: number, seed?: NhGallerySummary): void {
    if (galleryId <= 0) {
      return
    }
    this.stack.pushPathByName(
      ROUTE_GALLERY,
      new GalleryRouteParams(
        galleryId,
        seed ?? null,
        [],
        false,
        GalleryDetailTransitionCoordinator.activeRouteToken(galleryId.toString()),
      ),
    )
  }

  private pushGalleryWeb(route: GalleryRouteParams): void {
    if (route.galleryId <= 0 || this.safeMode.restricted()) {
      return
    }
    this.stack.pushPathByName(
      ROUTE_GALLERY_WEB,
      new GalleryWebRouteParams(
        NhBrowserSessionBoundary.canonicalGalleryUrl(route.galleryId),
        route.chrome.title,
      ),
    )
  }

  private pushNhSettings(): void {
    this.stack.pushPathByName(
      ROUTE_GALLERY_WEB,
      new GalleryWebRouteParams(
        NhBrowserSessionBoundary.userSettingsUrl(),
        AppStrings.get('nh_settings_title'),
      ),
    )
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
    if (this.randomGalleryBusy || this.activeTab !== 0 || this.safeMode.restricted()) {
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
      this.stack.replacePathByName(
        ROUTE_GALLERY,
        new GalleryRouteParams(
          galleryId,
          seed ?? null,
          [],
          false,
          GalleryDetailTransitionCoordinator.activeRouteToken(galleryId.toString()),
        ),
        true,
      )
      return
    }
    this.pushGallery(galleryId, seed)
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

  private pushThumbnails(
    galleryId: number,
    pages: NhGalleryPage[],
    detailSeed: NhGalleryDetail,
  ): void {
    if (galleryId <= 0 || pages.length === 0) {
      return
    }
    this.stack.pushPathByName(
      ROUTE_THUMBNAILS,
      new ThumbnailRouteParams(galleryId, pages, detailSeed),
    )
  }

  private pushReader(galleryId: number, initialPageIndex: number = -1, animated: boolean = true): void {
    if (galleryId <= 0) {
      return
    }
    this.readerOverlay.open(new ReaderRouteParams(galleryId, initialPageIndex), animated)
  }

  private pushComments(
    galleryId: number,
    commentSnapshot: NhComment[] = [],
    commentSnapshotAvailable: boolean = false,
  ): void {
    if (galleryId <= 0 || this.safeMode.restricted()) {
      return
    }
    this.stack.pushPathByName(
      ROUTE_COMMENTS,
      new GalleryRouteParams(galleryId, null, commentSnapshot, commentSnapshotAvailable),
    )
  }

  /** Leaves a detail route for the one durable Downloads root, matching NextE's task handoff. */
  private openDownloads(): void {
    const target: number = this.physicalTabForLogical(2)
    if (this.activeTab === target) {
      this.triggerRootRefresh(target)
      return
    }
    if (this.stack.getAllPathName().length > 0) {
      this.clearGalleryDetailTransitionOwnership()
      this.stack.clear(false)
    }
    this.settingsNavigation.clearRootLocation()
    this.clearHomeGallerySelection()
    this.activeTab = target
    this.titleScroller = this.rootTabScrollers[2]
    if (this.homeTab.autoHide) {
      this.restoreHomeTabIfHidden()
    }
    // Official HDS controller transition keeps root-tab selection and its
    // `onChange` lifecycle coherent; the stack was already explicitly closed.
    setTimeout((): void => {
      this.tabsController.changeIndex(target)
    }, 0)
  }

  private pushBrowserSession(addAccountMode: boolean = false): void {
    if (this.safeMode.restricted()) {
      return
    }
    this.stack.pushPathByName(ROUTE_BROWSER_SESSION, new BrowserSessionRouteParams(true, addAccountMode))
  }

  /** Empty ownership has no native choice to present; enter the visible login directly. */
  private pushVisibleLoginSession(): void {
    if (this.safeMode.restricted()) {
      return
    }
    // A root-owned account notice must never cover or intercept the visible
    // first-party login form. It may be offered again only after this route
    // leaves the stack and a later state transition asks for it.
    this.accountVerificationSnackBar.dismiss()
    this.accountVerificationSnackBarVisible = false
    this.displayedAccountVerificationRevision = -1
    this.accountAuthNoticeSnackBar.dismiss()
    this.stack.pushPathByName(ROUTE_BROWSER_SESSION, new BrowserSessionRouteParams(true))
  }

  private browserSessionRouteActive(): boolean {
    const pathNames: string[] = this.stack.getAllPathName()
    return pathNames.length > 0 && pathNames[pathNames.length - 1] === ROUTE_BROWSER_SESSION
  }

  /**
   * NextE closeLoginFlowToAccount parity: after a promoted visible login,
   * leave the login route and land on the Account page unless it is already
   * directly underneath (Account + add-account flow).
   */
  private closeBrowserSessionToAccount(): void {
    const pathNames: string[] = this.stack.getAllPathName()
    if (pathNames.length > 0 && pathNames[pathNames.length - 1] === ROUTE_BROWSER_SESSION) {
      this.stack.pop()
    }
    const updated: string[] = this.stack.getAllPathName()
    if (updated.length === 0 || updated[updated.length - 1] !== ROUTE_ACCOUNT) {
      this.pushAccount()
      this.settingsNavigation.publishRootLocation(ROUTE_ACCOUNT)
    }
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

  private pushLocalUserTags(): void {
    this.stack.pushPathByName(ROUTE_LOCAL_USER_TAGS, '')
  }

  private pushReaderSettings(): void {
    this.openSettingsRootDestination(ROUTE_READER_SETTINGS)
  }

  private pushReaderSuperResolutionModels(): void {
    this.stack.pushPathByName(ROUTE_READER_SUPER_RESOLUTION_MODELS, '')
  }

  private pushLlmSourceManager(): void {
    if (this.safeMode.restricted()) {
      return
    }
    this.stack.pushPathByName(ROUTE_LLM_SOURCE_MANAGER, new LlmSourceManagerRouteParams())
  }

  private pushLlmSourceDetail(sourceProfileId: string): void {
    if (this.safeMode.restricted()) {
      return
    }
    this.stack.pushPathByName(
      ROUTE_LLM_SOURCE_DETAIL,
      new LlmSourceDetailRouteParams(sourceProfileId),
    )
  }

  private pushTagTranslationSettings(): void {
    if (this.safeMode.restricted()) {
      return
    }
    this.stack.pushPathByName(ROUTE_TAG_TRANSLATION_SETTINGS, '')
  }

  private pushCommentTranslationSettings(): void {
    if (this.safeMode.restricted()) {
      return
    }
    this.stack.pushPathByName(ROUTE_COMMENT_TRANSLATION_SETTINGS, '')
  }

  private pushComicTranslationSettings(): void {
    if (this.safeMode.restricted()) {
      return
    }
    this.stack.pushPathByName(ROUTE_COMIC_TRANSLATION_SETTINGS, '')
  }

  private pushMangaRenderingService(): void {
    if (this.safeMode.restricted()) {
      return
    }
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
    if (this.safeMode.restricted()) {
      return
    }
    this.stack.pushPathByName(ROUTE_ACCOUNT, '')
  }

  /** An empty signed-out account list enters the first-party login surface directly. */
  private openAccountEntry(): void {
    if (this.accountList.accounts.length === 0 && !this.accountSession.signedIn) {
      this.pushVisibleLoginSession()
      return
    }
    this.pushAccount()
  }

  private pushSyncSettings(): void {
    if (this.safeMode.restricted()) {
      return
    }
    this.stack.pushPathByName(ROUTE_SYNC_SETTINGS, '')
  }

  private pushWebDavSyncSettings(): void {
    if (this.safeMode.restricted()) {
      return
    }
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
      name === ROUTE_LOCAL_USER_TAGS ||
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
    if (!SafeModeGate.routeAllowed(name)) {
      return
    }
    const pathNames: string[] = this.stack.getAllPathName()
    const topIndex: number = pathNames.length - 1
    if (topIndex >= 0 && pathNames[topIndex] === name) {
      return
    }
    if (topIndex < 0) {
      this.stack.pushPathByName(name, param)
      // Publish immediately so the primary Settings row highlights on tap
      // instead of waiting for HDS didShow after the transition settles.
      this.settingsNavigation.publishRootLocation(name)
      return
    }
    if (!this.isSettingsRoute(pathNames[topIndex])) {
      this.stack.pushPathByName(name, param)
      this.settingsNavigation.publishRootLocation(name)
      return
    }
    if (pathNames.length === 1) {
      this.stack.replacePathByName(name, param, true)
      this.settingsNavigation.publishRootLocation(name)
      return
    }
    this.clearGalleryDetailTransitionOwnership()
    this.stack.clear(false)
    this.settingsNavigation.clearRootLocation()
    this.stack.pushPathByName(name, param)
    this.settingsNavigation.publishRootLocation(name)
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
    this.clearPendingReaderStatusBarHide()
    const visible: boolean = !this.readerPresentationFullscreen || this.readerPresentationChromeVisible
    const lightIcons: boolean = this.readerPresentationChromeVisible || this.readerPresentationCanvasDark
    if (visible) {
      this.requestReaderStatusBar(true, lightIcons)
      return
    }
    const elapsedMs: number = this.readerDestinationShownAtMs > 0
      ? Math.max(0, Date.now() - this.readerDestinationShownAtMs)
      : 0
    const delayMs: number = Math.max(0, READER_ENTRY_STATUS_BAR_HIDE_DELAY_MS - elapsedMs)
    if (delayMs === 0) {
      this.requestReaderStatusBar(false, lightIcons)
      return
    }
    const routeEpoch: number = this.readerDestinationRouteEpoch
    this.readerStatusBarHideTimerId = setTimeout((): void => {
      this.readerStatusBarHideTimerId = -1
      if (!this.readerDestinationVisible || this.readerDestinationClosing ||
        routeEpoch !== this.readerDestinationRouteEpoch || !this.readerPresentationPending ||
        this.readerPresentationRouteEpoch !== routeEpoch || !this.readerPresentationFullscreen ||
        this.readerPresentationChromeVisible) {
        return
      }
      this.requestReaderStatusBar(false, this.readerPresentationCanvasDark)
    }, delayMs)
  }

  private clearPendingReaderStatusBarHide(): void {
    if (this.readerStatusBarHideTimerId < 0) {
      return
    }
    clearTimeout(this.readerStatusBarHideTimerId)
    this.readerStatusBarHideTimerId = -1
  }

  private clearRecordedReaderPresentation(): void {
    this.clearPendingReaderStatusBarHide()
    this.readerPresentationPending = false
    this.readerPresentationRouteEpoch = 0
    this.readerPresentationChromeVisible = false
    this.readerPresentationFullscreen = true
    this.readerPresentationCanvasDark = true
  }

  private prepareReaderDestinationClose(galleryId: number): Promise<boolean> {
    const readerGalleryId: string = galleryId > 0 ? galleryId.toString() : ''
    const requireVisibleStatusBarInset: boolean = this.readerPresentationPending &&
      this.readerPresentationFullscreen && !this.readerPresentationChromeVisible
    this.readerDestinationClosing = true
    this.clearRecordedReaderPresentation()
    return this.restoreAppStatusBar()
      .then((): Promise<boolean> => {
        if (this.readerThumbnailTransition.galleryId === readerGalleryId &&
          this.readerThumbnailTransition.openingCanReverse()) {
          return Promise.resolve(true)
        }
        if (!this.readerThumbnailTransition.normalCloseReadyFor(readerGalleryId)) {
          return Promise.resolve(false)
        }
        return ReaderThumbnailTransitionCoordinator.waitForTargetLayoutCommit(
          this.getUIContext(),
          requireVisibleStatusBarInset,
        )
      })
  }

  private finishReaderDestinationClose(animated: boolean): void {
    if (this.readerDestinationCloseDispatched) {
      return
    }
    this.readerDestinationClosing = true
    this.readerDestinationCloseDispatched = true
    this.clearRecordedReaderPresentation()
    this.readerOverlay.close(animated)
  }

  private closeReaderDestination(animated: boolean = true): void {
    if (this.readerDestinationCloseDispatched) {
      return
    }
    this.readerDestinationClosing = true
    this.clearRecordedReaderPresentation()
    this.restoreAppStatusBar().then((): void => {
      this.finishReaderDestinationClose(animated)
    })
  }

  /**
   * NextE keeps the root destinations few, stable, and visually legible.  NextN
   * has only the genuinely available roots today. Favorites has a real
   * account-bound read path; Downloads remains absent until its queue exists.
   */
  private rootTitle(): string {
    const logicalTab: number = this.logicalTabForPhysical(this.activeTab)
    if (logicalTab === 1) {
      return AppStrings.get('tab_favorites')
    }
    if (logicalTab === 2) {
      return AppStrings.get('tab_downloads')
    }
    if (logicalTab === 3) {
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

  /** Remote Favorites draft hosted by HDS; request ownership stays in the retained page. */
  private favoritesSearchBottomBuilder(): Record<string, Object> {
    if (this.favoritesTitleSearchContent === null) {
      this.favoritesTitleSearchContent = new ComponentContent<FavoritesActionState>(
        this.getUIContext(),
        wrapBuilder<[FavoritesActionState]>(FavoritesTitleSearchFieldCCBuilder),
        this.favoritesActions,
      )
    }
    return {
      'builderComponent': this.favoritesTitleSearchContent,
      'height': FAVORITES_TITLE_SEARCH_HEIGHT,
      'showType': BottomBuilderShowType.DIRECTLY_SHOW,
    }
  }

  /** NextE-shaped title owner for local Download search plus lifecycle mirror. */
  private downloadTitleBottomBuilder(): Record<string, Object> {
    if (this.downloadTitleBarContent === null) {
      this.downloadTitleBarContent = new ComponentContent<Object>(
        this.getUIContext(),
        wrapBuilder<[Object]>(DownloadTitleBarCCBuilder),
        new Object(),
      )
    }
    return {
      'builderComponent': this.downloadTitleBarContent,
      'height': (this.downloadQueueActions.searchActive ? DOWNLOAD_TITLE_SEARCH_HEIGHT : 0) +
        (this.downloadPinnedGroupHeader.visible ? DOWNLOAD_PINNED_GROUP_HEADER_HEIGHT : 0),
      'showType': BottomBuilderShowType.DIRECTLY_SHOW,
    }
  }

  private rootTabScroller(index: number): Scroller {
    const logicalTab: number = this.logicalTabForPhysical(index)
    return logicalTab === 0 ? this.homeActiveScroller : this.rootTabScrollers[logicalTab]
  }

  private logicalTabForPhysical(index: number): number {
    if (!this.safeMode.restricted()) {
      return index
    }
    if (index === 1) {
      return 2
    }
    if (index === 2) {
      return 3
    }
    return 0
  }

  private physicalTabForLogical(index: number): number {
    if (!this.safeMode.restricted()) {
      return index
    }
    if (index === 2) {
      return 1
    }
    if (index === 3) {
      return 2
    }
    return 0
  }

  private rootTabCount(): number {
    return this.safeMode.restricted() ? 3 : 4
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
    this.tabsController.unbindScroller(this.homeActiveScroller)
    for (let index = 1; index < this.rootTabScrollers.length; index += 1) {
      this.tabsController.unbindScroller(this.rootTabScrollers[index])
    }
    for (let index = 0; index < this.rootTabCount(); index += 1) {
      const scroller: Scroller = this.rootTabScroller(index)
      if (this.homeTab.autoHide) {
        this.tabsController.bindScroller(index, scroller)
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

  private onHomeTabDidScroll(index: number, offset: number, state: ScrollState): void {
    const offsetIndex: number = this.logicalTabForPhysical(index)
    if (index !== this.activeTab || !this.homeTab.autoHide) {
      this.homeTabLastScrollOffsets[offsetIndex] = offset
      return
    }
    if (offset <= this.HOME_TAB_SCROLL_DELTA_PX) {
      this.homeTabLastScrollOffsets[offsetIndex] = offset
      this.restoreHomeTabIfHidden()
      return
    }
    if (state === ScrollState.Idle) {
      this.homeTabLastScrollOffsets[offsetIndex] = offset
      return
    }
    const lastOffset: number = this.homeTabLastScrollOffsets[offsetIndex]
    this.homeTabLastScrollOffsets[offsetIndex] = offset
    const delta: number = offset - lastOffset
    if (delta < -this.HOME_TAB_SCROLL_DELTA_PX) {
      this.applyHomeTabScrollAnimation(true)
      return
    }
    if (delta > this.HOME_TAB_SCROLL_DELTA_PX) {
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

  private activeHomeSubtabKind(): NhHomeSubtabKind {
    const profile: NhHomeSubtabProfile | null = this.homeSubtabs.find(this.homeSubtabs.selectedUuid)
    return profile === null ? NhHomeSubtabKind.LATEST : profile.kind
  }

  private rootTitleBar(): Record<string, Object> {
    const title: Record<string, Object> = { 'mainTitle': this.rootTitle() }
    const content: Record<string, Object> = { 'title': title }
    const logicalTab: number = this.logicalTabForPhysical(this.activeTab)
    if (logicalTab === 0 && this.safeMode.restricted()) {
      content['bottomBuilder'] = this.homeSourceBottomBuilder()
      content['menu'] = this.emptyHdsMenu()
    } else if (logicalTab === 0) {
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
      const jumpAction: Record<string, Object> = {
        'label': AppStrings.get('action_jump_page'),
        'icon': $r('sys.symbol.chevron_right_circle'),
        'isEnabled': true,
        'action': (): void => {
          HomeSourceBridge.requestJumpDialog()
        },
      }
      const jumpMenuItem: Record<string, Object> = { 'content': jumpAction }
      const editSubtabAction: Record<string, Object> = {
        'label': AppStrings.get('action_edit_home_subtab'),
        'icon': $r('sys.symbol.pencil_line'),
        'isEnabled': true,
        'action': (): void => {
          HomeSourceBridge.requestEditSubtab(this.homeSubtabs.selectedUuid)
        },
      }
      const editSubtabMenuItem: Record<string, Object> = { 'content': editSubtabAction }
      // Popular is already a retained Browse source. Keep its old route only
      // for compatibility, but never present a duplicate title-bar entry.
      // Query controls belong only to Latest; the shared layout switcher is
      // intentionally available from either source.
      const kind: NhHomeSubtabKind = this.activeHomeSubtabKind()
      const browseMenuItems: Record<string, Object>[] = kind === NhHomeSubtabKind.LATEST
        ? [searchMenuItem, browseOptionsMenuItem, layoutMenuItem, jumpMenuItem, randomGalleryMenuItem]
        : kind === NhHomeSubtabKind.SEARCH
          ? [searchMenuItem, editSubtabMenuItem, layoutMenuItem, jumpMenuItem, randomGalleryMenuItem]
          : [searchMenuItem, layoutMenuItem, randomGalleryMenuItem]
      const searchMenu: Record<string, Object> = { 'value': browseMenuItems, 'maxCount': 3 }
      content['menu'] = searchMenu
    } else if (logicalTab === 1) {
      if (this.favoritesActions.actionsAvailable) {
        if (this.favoritesActions.searchActive) {
          content['bottomBuilder'] = this.favoritesSearchBottomBuilder()
        }
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
        const jumpAction: Record<string, Object> = {
          'label': AppStrings.get('action_jump_page'),
          'icon': $r('sys.symbol.chevron_right_circle'),
          'isEnabled': this.favoritesActions.actionsAvailable,
          'action': (): void => {
            FavoritesActionBridge.requestJumpDialog()
          },
        }
        const jumpMenuItem: Record<string, Object> = { 'content': jumpAction }
        const favoritesMenuItems: Record<string, Object>[] = [searchMenuItem, layoutMenuItem, jumpMenuItem]
        const favoritesMenu: Record<string, Object> = { 'value': favoritesMenuItems, 'maxCount': 3 }
        content['menu'] = favoritesMenu
      } else {
        content['menu'] = this.emptyHdsMenu()
      }
    } else if (logicalTab === 2) {
      // Root HDS owns only command intent. DownloadQueuePage owns all local
      // query, ordering, and menu state through the narrow action bridge.
      // Never leave HDS holding a cached zero-height Download builder. During
      // a Favorites -> Downloads transition that host can remain visually
      // collapsed even after the nested Search subtree becomes active.
      if (this.downloadQueueActions.searchActive || this.downloadPinnedGroupHeader.visible) {
        content['bottomBuilder'] = this.downloadTitleBottomBuilder()
      }
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
    if (logicalTab === 3) {
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
        route.chrome.favoriteRequestVersion += 1
      },
    }
    const externalOpenAction: Record<string, Object> = {
      'label': AppStrings.get('action_open_externally'),
      'icon': $r('sys.symbol.link'),
      'isEnabled': true,
      'action': (): void => {
        route.chrome.externalOpenRequestVersion += 1
      },
    }
    const internalWebAction: Record<string, Object> = {
      'label': AppStrings.get('action_open_internal_web'),
      'icon': $r('sys.symbol.house_fill'),
      'isEnabled': true,
      'action': (): void => {
        this.pushGalleryWeb(route)
      },
    }
    const shareAction: Record<string, Object> = {
      'label': AppStrings.get('action_share'),
      'icon': $r('sys.symbol.share'),
      'isEnabled': true,
      'action': (): void => {
        route.chrome.shareRequestVersion += 1
      },
    }
    const commentsAction: Record<string, Object> = {
      'label': AppStrings.get('gallery_action_comments'),
      'icon': $r('sys.symbol.doc_plaintext'),
      'isEnabled': route.galleryId > 0,
      'action': (): void => {
        route.chrome.commentsRequestVersion += 1
      },
    }
    const copyLinkAction: Record<string, Object> = {
      'label': AppStrings.get('detail_copy_link'),
      'icon': $r('sys.symbol.doc_text_on_doc_text'),
      'isEnabled': route.galleryId > 0,
      'action': (): void => {
        route.chrome.copyLinkRequestVersion += 1
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
    const favoriteMenuItem: Record<string, Object> = { 'content': favoriteAction }
    const externalOpenMenuItem: Record<string, Object> = { 'content': externalOpenAction }
    const internalWebMenuItem: Record<string, Object> = { 'content': internalWebAction }
    const shareMenuItem: Record<string, Object> = { 'content': shareAction }
    const commentsMenuItem: Record<string, Object> = { 'content': commentsAction }
    const reloadMenuItem: Record<string, Object> = { 'content': reloadAction }
    const copyLinkMenuItem: Record<string, Object> = { 'content': copyLinkAction }
    const menuItems: Record<string, Object>[] = [
      favoriteMenuItem,
      shareMenuItem,
      commentsMenuItem,
      reloadMenuItem,
      copyLinkMenuItem,
      externalOpenMenuItem,
      internalWebMenuItem,
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
  private tabBar(label: string, index: number, iconIndex: number) {
    MainTabIcon({
      title: label,
      idx: index,
      iconIdx: iconIndex,
      currentIndex: this.activeTab,
      onSelectedClick: (selectedIndex: number): void => {
        this.triggerRootRefresh(selectedIndex)
      },
    })
  }

  /** Matches NextE: a re-tap is routed to the currently registered root list. */
  private triggerRootRefresh(index: number): void {
    if (index < 0 || index >= this.rootTabCount()) {
      return
    }
    RootRefreshRegistry.trigger(this.rootTabScroller(index))
  }

  private galleryParams(param: Object): GalleryRouteParams {
    if (param instanceof GalleryRouteParams && param.galleryId > 0) {
      return param
    }
    return new GalleryRouteParams()
  }

  private galleryWebParams(param: Object): GalleryWebRouteParams {
    if (param instanceof GalleryWebRouteParams) {
      return param
    }
    return new GalleryWebRouteParams()
  }

  private searchParams(param: Object): SearchRouteParams {
    if (param instanceof SearchRouteParams) {
      return param
    }
    return new SearchRouteParams()
  }

  private homeSubtabEditParams(param: Object): HomeSubtabEditParams {
    if (param instanceof HomeSubtabEditParams) {
      return param
    }
    return new HomeSubtabEditParams()
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
      hideBackButton: this.rootDestinationBackButtonHidden(ROUTE_SEARCH),
      onOpenGallery: (galleryId: number, seed?: NhGallerySummary): void => {
        this.pushGallery(galleryId, seed)
      },
      onCreateSubtab: (params: HomeSubtabEditParams): void => {
        this.pushHomeSubtabEdit(params)
      },
    })
  }

  @Builder
  private homeSubtabManagerDestination() {
    HomeSubtabManagerPage({
      scroller: this.homeSubtabManagerScroller,
      hideBackButton: this.rootDestinationBackButtonHidden(ROUTE_HOME_SUBTAB_MANAGER),
      onCreate: (): void => {
        this.pushHomeSubtabEdit(new HomeSubtabEditParams())
      },
      onEdit: (uuid: string): void => {
        this.pushHomeSubtabEdit(new HomeSubtabEditParams(uuid))
      },
    })
  }

  @Builder
  private homeSubtabEditDestination(param: Object) {
    HomeSubtabEditPage({
      edit: this.homeSubtabEditParams(param),
      scroller: this.homeSubtabEditScroller,
      hideBackButton: this.rootDestinationBackButtonHidden(ROUTE_HOME_SUBTAB_EDIT),
      onDone: (): void => {
        this.stack.pop()
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
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_POPULAR))
    .bindToScrollable([this.popularScroller])
  }

  private syncGalleryDetailCoverTarget(): boolean {
    return GalleryDetailTransitionCoordinator.syncDetailCoverTarget(this.getUIContext())
  }

  private coverExpandSurfaceActive(): boolean {
    return this.galleryDetailTransition.eligible &&
      this.galleryDetailTransition.isCoverExpand() &&
      !this.galleryDetailTransition.independentPopSurfaceActive &&
      (this.galleryDetailTransition.phase === GalleryDetailTransitionPhase.OPENING ||
        this.galleryDetailTransition.phase === GalleryDetailTransitionPhase.CLOSING)
  }

  private handleGalleryDetailBackPressed(route: GalleryRouteParams): boolean {
    const alreadyActive: boolean = this.galleryDetailTransition.eligible &&
      route.transitionToken === this.galleryDetailTransition.routeToken
    // A Gallery opened in Stack keeps its transition token when Auto later
    // resolves to Split. HDS treats the sole secondary destination as a root,
    // so consume Back explicitly for that migrated route instead of allowing
    // the UIAbility to leave the foreground. A Gallery opened in Split has no
    // token and retains the existing first-secondary behavior.
    if (this.layoutSafeArea.rootNavigationSplit) {
      if (route.transitionToken.length === 0) {
        return false
      }
      GalleryDetailTransitionCoordinator.discardRouteTransition(route.transitionToken)
      this.stack.pop()
      return true
    }
    if (
      this.coverPopDispatching ||
      route.transitionToken.length === 0 ||
      !GalleryDetailTransitionCoordinator.activateRouteTransition(route.transitionToken) ||
      !this.galleryDetailTransition.eligible ||
      route.transitionToken !== this.galleryDetailTransition.routeToken
    ) {
      return false
    }
    if (!this.galleryDetailTransition.isCoverExpand()) {
      if (alreadyActive) {
        return false
      }
      this.coverPopDispatching = true
      this.getUIContext().postFrameCallback(new GalleryDetailPreparedPopFrameCallback((): void => {
        this.stack.pop()
        this.coverPopDispatching = false
      }))
      return true
    }
    this.coverPopDispatching = true
    const prepareAndDispatchPop: () => void = (): void => {
      const coverTargetVisible: boolean = this.syncGalleryDetailCoverTarget()
      let detailSnapshot: image.PixelMap | undefined = undefined
      if (coverTargetVisible) {
        try {
          detailSnapshot = this.getUIContext().getComponentSnapshot()
            .getSync('nextn-root-navigation', { waitUntilRenderFinished: true })
        } catch (error) {
          DiagnosticLogger.info(
            'gallery-detail-transition',
            'detail_pop_snapshot_failed',
            `gallery=${this.galleryDetailTransition.galleryId} error=${error}`,
          )
        }
      }
      this.galleryDetailTransition.prepareCoverPop(coverTargetVisible, detailSnapshot)
      this.getUIContext().postFrameCallback(new GalleryDetailPreparedPopFrameCallback((): void => {
        this.stack.pop()
        this.coverPopDispatching = false
      }))
    }
    if (!alreadyActive) {
      this.getUIContext().postFrameCallback(new GalleryDetailPreparedPopFrameCallback(prepareAndDispatchPop))
      return true
    }
    prepareAndDispatchPop()
    return true
  }

  @Builder
  private galleryDestination(param: Object) {
    HdsNavDestination() {
      Stack() {
        Column() {}
          .width('100%')
          .height('100%')
          .backgroundColor(ThemeTokens.SURFACE)
        if (
          !this.galleryDetailTransition.isCoverExpand() &&
          this.galleryDetailTransition.cardSnapshot !== undefined
        ) {
          Image(this.galleryDetailTransition.cardSnapshot)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Fill)
            .syncLoad(true)
            .opacity(this.galleryDetailTransition.cardOpacity)
            .hitTestBehavior(HitTestMode.None)
        }
        GalleryDetailPage({
          galleryId: this.galleryParams(param).galleryId,
          seed: this.galleryParams(param).seed,
          chrome: this.galleryParams(param).chrome,
          scroller: this.galleryParams(param).scroller,
          onOpenGallery: (galleryId: number, seed?: NhGallerySummary): void => {
            this.pushGallery(galleryId, seed)
          },
          onOpenThumbnails: (
            galleryId: number,
            pages: NhGalleryPage[],
            detailSeed: NhGalleryDetail,
          ): void => {
            this.pushThumbnails(galleryId, pages, detailSeed)
          },
          onOpenReader: (galleryId: number, initialPageIndex: number, animated: boolean): void => {
            this.pushReader(galleryId, initialPageIndex, animated)
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
          .opacity(this.galleryDetailTransition.contentOpacity)
      }
      .width('100%')
      .height('100%')
    }
    // Gallery's semantic title lives in its header first, then hands off to
    // HDS after the header scrolls away.
    .titleBar(this.galleryTitleBar(this.galleryParams(param)))
    .hideTitleBar(
      this.galleryDetailTransition.eligible && !this.galleryDetailTransition.chromeVisible,
      false,
    )
    .hideBackButton(
      this.rootDestinationBackButtonHidden(ROUTE_GALLERY) &&
        this.galleryParams(param).transitionToken.length === 0,
    )
    .onBackPressed((): boolean => this.handleGalleryDetailBackPressed(this.galleryParams(param)))
    .backgroundColor(this.galleryDetailTransition.eligible ? Color.Transparent : ThemeTokens.SURFACE)
    .scale({
      x: this.galleryDetailTransition.isCoverExpand() ? 1 : this.galleryDetailTransition.scaleX,
      y: this.galleryDetailTransition.isCoverExpand() ? 1 : this.galleryDetailTransition.scaleY,
      centerX: '50%',
      centerY: '50%',
    })
    .translate({
      x: this.galleryDetailTransition.isCoverExpand() ? 0 : this.galleryDetailTransition.translateX,
      y: this.galleryDetailTransition.isCoverExpand() ? 0 : this.galleryDetailTransition.translateY,
    })
    .borderRadius(this.galleryDetailTransition.isCoverExpand() ? 0 : this.galleryDetailTransition.radius)
    .clip(this.galleryDetailTransition.eligible && !this.galleryDetailTransition.isCoverExpand())
    .bindToScrollable([this.galleryParams(param).scroller])
  }

  @Builder
  private galleryWebDestination(param: Object) {
    // The destination's title bar lives inside GalleryWebPage (NextE
    // GalleryWebPage parity): it carries the live page title plus the
    // back/forward/refresh menu, so the shell must not wrap a second bar.
    GalleryWebPage({
      url: this.galleryWebParams(param).url,
      title: this.galleryWebParams(param).title,
      hideBackButton: this.rootDestinationBackButtonHidden(ROUTE_GALLERY_WEB),
    })
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
        onBack: (animated: boolean): void => {
          this.finishReaderDestinationClose(animated)
        },
        onPrepareClose: (): Promise<boolean> => {
          return this.prepareReaderDestinationClose(this.readerParams(param).galleryId)
        },
        onRegisterBackRequest: (request: () => boolean): void => {
          this.readerBackRequest = request
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
      if (this.readerBackRequest !== null) {
        return this.readerBackRequest()
      }
      this.closeReaderDestination(true)
      return true
    })
    .onShown((): void => {
      this.readerDestinationVisible = true
      this.readerDestinationClosing = false
      this.readerDestinationCloseDispatched = false
      this.readerDestinationRouteEpoch = this.readerParams(param).routeEpoch
      this.readerDestinationShownAtMs = Date.now()
      ReaderThumbnailTransitionCoordinator.startOpening(
        this.getUIContext(),
        this.readerParams(param).galleryId.toString(),
      )
      if (this.readerPresentationPending &&
        this.readerPresentationRouteEpoch === this.readerDestinationRouteEpoch) {
        this.applyRecordedReaderPresentation()
        return
      }
      this.clearRecordedReaderPresentation()
      // Keep the app status bar stable until this route publishes its restored
      // presentation. The first immersive hide still observes NextE's entry delay.
    })
    .onWillHide((): void => {
      this.readerBackRequest = null
      this.readerDestinationVisible = false
      this.readerDestinationClosing = true
      this.readerDestinationShownAtMs = 0
      this.clearRecordedReaderPresentation()
      this.restoreAppStatusBar()
    })
    .onDisAppear((): void => {
      this.readerBackRequest = null
      this.readerDestinationVisible = false
      this.readerDestinationShownAtMs = 0
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
        detailSeed: this.thumbnailParams(param).detailSeed,
        chrome: this.thumbnailParams(param).chrome,
        scroller: this.thumbnailScroller,
        onOpenReader: (galleryId: number, pageIndex: number, animated: boolean): void => {
          this.pushReader(galleryId, pageIndex, animated)
        },
      })
    }
    .titleBar(this.thumbnailsTitleBar(this.thumbnailParams(param)))
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_THUMBNAILS))
    .bindToScrollable([this.thumbnailScroller])
  }

  @Builder
  private commentsDestination(param: Object) {
    GalleryCommentsPage({
      galleryId: this.galleryParams(param).galleryId,
      scroller: this.commentsScroller,
      commentSnapshot: this.galleryParams(param).commentSnapshot,
      commentSnapshotAvailable: this.galleryParams(param).commentSnapshotAvailable,
      hideBackButton: this.rootDestinationBackButtonHidden(ROUTE_COMMENTS),
    })
  }

  @Builder
  private browserSessionDestination(param: Object) {
    HdsNavDestination() {
      BrowserSessionPage({
        autoOpenVisibleLogin: this.browserSessionParams(param).autoOpenVisibleLogin,
        addAccountMode: this.browserSessionParams(param).addAccountMode,
        onLoginFlowFinished: (): void => {
          this.closeBrowserSessionToAccount()
        },
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_account')))
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_BROWSER_SESSION))
  }

  @Builder
  private accountDestination() {
    HdsNavDestination() {
      AccountPage({
        onOpenNhSettings: (): void => {
          this.pushNhSettings()
        },
      })
    }
    .titleBar(this.accountTitleBar())
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_ACCOUNT))
  }

  /**
   * NextE AccountPage title-bar contract: the top-right person_badge_plus
   * opens the login/session leaf to add another account; the account list
   * itself stays a Radio-marked switcher without an inline add row.
   */
  private accountTitleBar(): Record<string, Object> {
    const addAccountAction: Record<string, Object> = {
      'label': AppStrings.get('settings_add_account'),
      'icon': $r('sys.symbol.person_badge_plus'),
      'isEnabled': true,
      'action': (): void => {
        this.pushBrowserSession(true)
      },
    }
    const menuItems: Record<string, Object>[] = [{ 'content': addAccountAction }]
    const menu: Record<string, Object> = { 'value': menuItems, 'maxCount': 1 }
    const title: Record<string, Object> = { 'mainTitle': AppStrings.get('settings_account') }
    return nextNHdsTitleBar({
      'title': title,
      'menu': menu,
    })
  }

  @Builder
  private contentFiltersDestination() {
    HdsNavDestination() {
      ContentFiltersPage({ scroller: this.contentFiltersScroller })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('title_content_filters')))
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_CONTENT_FILTERS))
    .bindToScrollable([this.contentFiltersScroller])
  }

  @Builder
  private localUserTagsDestination() {
    HdsNavDestination() {
      LocalUserTagsPage({
        scroller: this.localUserTagsScroller,
        addRequestVersion: this.localUserTagsAddRequestVersion,
      })
    }
    .titleBar(this.localUserTagsTitleBar())
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_LOCAL_USER_TAGS))
    .bindToScrollable([this.localUserTagsScroller])
  }

  private localUserTagsTitleBar(): Record<string, Object> {
    const title: Record<string, Object> = { 'mainTitle': AppStrings.get('title_local_user_tags') }
    const addAction: Record<string, Object> = {
      'label': AppStrings.get('local_user_tag_add'),
      'icon': $r('sys.symbol.plus'),
      'isEnabled': true,
      'action': (): void => { this.localUserTagsAddRequestVersion += 1 },
    }
    const addMenuItem: Record<string, Object> = { 'content': addAction }
    const menuItems: Record<string, Object>[] = [addMenuItem]
    const menu: Record<string, Object> = {
      'value': menuItems,
      'maxCount': 1,
    }
    return nextNHdsTitleBar({ 'title': title, 'menu': menu })
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
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_LAYOUT_SETTINGS))
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
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_BROWSE_SETTINGS))
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
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_SEARCH_SETTINGS))
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
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_BROWSE_DENSITY_SETTINGS))
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
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_READER_SETTINGS))
    .bindToScrollable([this.readerSettingsScroller])
  }

  @Builder
  private readerSuperResolutionModelsDestination() {
    HdsNavDestination() {
      ReaderSuperResolutionModelsPage({ scroller: this.readerSuperResolutionModelsScroller })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_reader_enhancement_models')))
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_READER_SUPER_RESOLUTION_MODELS))
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
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_LLM_SOURCE_MANAGER))
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
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_LLM_SOURCE_DETAIL))
    .bindToScrollable([this.translationSourceScroller])
  }

  @Builder
  private mangaRenderingServiceDestination() {
    HdsNavDestination() {
      MangaRenderingServiceSettingsPage({ scroller: this.mangaRenderingServiceScroller })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_manga_rendering_service')))
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_MANGA_RENDERING_SERVICE))
    .bindToScrollable([this.mangaRenderingServiceScroller])
  }

  @Builder
  private downloadSettingsDestination() {
    HdsNavDestination() {
      SettingsPage({ surface: SettingsSurface.DOWNLOAD, scroller: this.downloadSettingsScroller })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_download')))
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_DOWNLOAD_SETTINGS))
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
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_CACHE_SETTINGS))
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
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_SYNC_SETTINGS))
    .bindToScrollable([this.syncSettingsScroller])
  }

  @Builder
  private webDavSyncSettingsDestination() {
    HdsNavDestination() {
      WebDavSyncSettingsPage({ scroller: this.webDavSyncSettingsScroller })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('sync_webdav')))
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_WEBDAV_SYNC_SETTINGS))
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
        onOpenLocalUserTags: (): void => {
          this.pushLocalUserTags()
        },
        onOpenTranslationSource: (): void => {
          this.pushLlmSourceManager()
        },
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_advanced')))
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_ADVANCED_SETTINGS))
    .bindToScrollable([this.advancedSettingsScroller])
  }

  @Builder
  private tagTranslationSettingsDestination() {
    HdsNavDestination() {
      TagTranslationSettingsPage({ scroller: this.tagTranslationSettingsScroller })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_tag_translation_title')))
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_TAG_TRANSLATION_SETTINGS))
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
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_COMMENT_TRANSLATION_SETTINGS))
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
        onOpenToriiLiveEvaluation: (report: ToriiWholePageLiveEvaluationReport): void => {
          const params: ToriiWholePageLiveEvaluationRouteParams =
            new ToriiWholePageLiveEvaluationRouteParams()
          params.report = report
          this.stack.pushPathByName(ROUTE_TORII_WHOLE_PAGE_LIVE_EVALUATION, params)
        },
      })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_reader_comic_translation')))
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_COMIC_TRANSLATION_SETTINGS))
    .bindToScrollable([this.comicTranslationSettingsScroller])
  }

  @Builder
  private toriiWholePageLiveEvaluationDestination(_param: Object) {
    ToriiWholePageLiveEvaluationPage({
      hideBackButton: this.rootDestinationBackButtonHidden(ROUTE_TORII_WHOLE_PAGE_LIVE_EVALUATION),
    })
  }

  @Builder
  private aboutDestination() {
    HdsNavDestination() {
      AboutPage({ scroller: this.aboutScroller })
    }
    .titleBar(nextNHdsTitle(AppStrings.get('settings_about')))
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_ABOUT))
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
    .hideBackButton(this.rootDestinationBackButtonHidden(ROUTE_HISTORY))
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
    if (!SafeModeGate.routeAllowed(name)) {
      HdsNavDestination() {
        Column() {}
      }
      .hideTitleBar(true)
    } else if (name === ROUTE_SEARCH) {
      this.searchDestination(param)
    } else if (name === ROUTE_HOME_SUBTAB_MANAGER) {
      this.homeSubtabManagerDestination()
    } else if (name === ROUTE_HOME_SUBTAB_EDIT) {
      this.homeSubtabEditDestination(param)
    } else if (name === ROUTE_POPULAR) {
      this.popularDestination()
    } else if (name === ROUTE_GALLERY) {
      this.galleryDestination(param)
    } else if (name === ROUTE_GALLERY_WEB) {
      this.galleryWebDestination(param)
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
    } else if (name === ROUTE_LOCAL_USER_TAGS) {
      this.localUserTagsDestination()
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
    } else if (name === ROUTE_TORII_WHOLE_PAGE_LIVE_EVALUATION) {
      this.toriiWholePageLiveEvaluationDestination(param)
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

  private sourceCoverLeftInCard(): number {
    return Math.max(0, Math.min(
      this.galleryDetailTransition.handoffWidth,
      this.galleryDetailTransition.sourceCoverX - this.galleryDetailTransition.handoffX,
    ))
  }

  private sourceCoverTopInCard(): number {
    return Math.max(0, Math.min(
      this.galleryDetailTransition.handoffHeight,
      this.galleryDetailTransition.sourceCoverY - this.galleryDetailTransition.handoffY,
    ))
  }

  private sourceCoverRightInCard(): number {
    return Math.max(this.sourceCoverLeftInCard(), Math.min(
      this.galleryDetailTransition.handoffWidth,
      this.galleryDetailTransition.sourceCoverX + this.galleryDetailTransition.sourceCoverWidth -
        this.galleryDetailTransition.handoffX,
    ))
  }

  private sourceCoverBottomInCard(): number {
    return Math.max(this.sourceCoverTopInCard(), Math.min(
      this.galleryDetailTransition.handoffHeight,
      this.galleryDetailTransition.sourceCoverY + this.galleryDetailTransition.sourceCoverHeight -
        this.galleryDetailTransition.handoffY,
    ))
  }

  private targetCoverLeftInDetail(): number {
    return Math.max(0, Math.min(
      this.galleryDetailTransition.rootWidth,
      this.galleryDetailTransition.targetCoverX,
    ))
  }

  private targetCoverTopInDetail(): number {
    return Math.max(0, Math.min(
      this.galleryDetailTransition.rootHeight,
      this.galleryDetailTransition.targetCoverY,
    ))
  }

  private targetCoverRightInDetail(): number {
    return Math.max(this.targetCoverLeftInDetail(), Math.min(
      this.galleryDetailTransition.rootWidth,
      this.galleryDetailTransition.targetCoverX + this.galleryDetailTransition.targetCoverWidth,
    ))
  }

  private targetCoverBottomInDetail(): number {
    return Math.max(this.targetCoverTopInDetail(), Math.min(
      this.galleryDetailTransition.rootHeight,
      this.galleryDetailTransition.targetCoverY + this.galleryDetailTransition.targetCoverHeight,
    ))
  }

  @Builder
  private GalleryDetailSnapshotSlice(
    sliceX: number,
    sliceY: number,
    sliceWidth: number,
    sliceHeight: number,
  ) {
    if (this.galleryDetailTransition.detailSnapshot !== undefined && sliceWidth > 0 && sliceHeight > 0) {
      Stack({ alignContent: Alignment.TopStart }) {
        Image(this.galleryDetailTransition.detailSnapshot)
          .width(this.galleryDetailTransition.rootWidth)
          .height(this.galleryDetailTransition.rootHeight)
          .objectFit(ImageFit.Fill)
          .syncLoad(true)
          .position({ x: -sliceX, y: -sliceY })
          .hitTestBehavior(HitTestMode.None)
      }
      .width(sliceWidth)
      .height(sliceHeight)
      .position({ x: sliceX, y: sliceY })
      .clip(true)
      .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  private GalleryDetailSnapshotRemainder() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.GalleryDetailSnapshotSlice(
        0,
        0,
        this.galleryDetailTransition.rootWidth,
        this.targetCoverTopInDetail(),
      )
      this.GalleryDetailSnapshotSlice(
        0,
        this.targetCoverTopInDetail(),
        this.targetCoverLeftInDetail(),
        this.targetCoverBottomInDetail() - this.targetCoverTopInDetail(),
      )
      this.GalleryDetailSnapshotSlice(
        this.targetCoverRightInDetail(),
        this.targetCoverTopInDetail(),
        this.galleryDetailTransition.rootWidth - this.targetCoverRightInDetail(),
        this.targetCoverBottomInDetail() - this.targetCoverTopInDetail(),
      )
      this.GalleryDetailSnapshotSlice(
        0,
        this.targetCoverBottomInDetail(),
        this.galleryDetailTransition.rootWidth,
        this.galleryDetailTransition.rootHeight - this.targetCoverBottomInDetail(),
      )
    }
    .width(this.galleryDetailTransition.rootWidth)
    .height(this.galleryDetailTransition.rootHeight)
    .position({
      x: -this.galleryDetailTransition.clipX,
      y: -this.galleryDetailTransition.clipY,
    })
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private GalleryDetailCardSnapshotSlice(
    sliceX: number,
    sliceY: number,
    sliceWidth: number,
    sliceHeight: number,
  ) {
    if (this.galleryDetailTransition.cardSnapshot !== undefined && sliceWidth > 0 && sliceHeight > 0) {
      Stack({ alignContent: Alignment.TopStart }) {
        Image(this.galleryDetailTransition.cardSnapshot)
          .width(this.galleryDetailTransition.handoffWidth)
          .height(this.galleryDetailTransition.handoffHeight)
          .objectFit(ImageFit.Fill)
          .syncLoad(true)
          .position({ x: -sliceX, y: -sliceY })
          .hitTestBehavior(HitTestMode.None)
      }
      .width(sliceWidth)
      .height(sliceHeight)
      .position({ x: sliceX, y: sliceY })
      .clip(true)
      .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  private GalleryDetailSourceCardRemainder() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.GalleryDetailCardSnapshotSlice(
        0,
        0,
        this.galleryDetailTransition.handoffWidth,
        this.sourceCoverTopInCard(),
      )
      this.GalleryDetailCardSnapshotSlice(
        0,
        this.sourceCoverTopInCard(),
        this.sourceCoverLeftInCard(),
        this.sourceCoverBottomInCard() - this.sourceCoverTopInCard(),
      )
      this.GalleryDetailCardSnapshotSlice(
        this.sourceCoverRightInCard(),
        this.sourceCoverTopInCard(),
        this.galleryDetailTransition.handoffWidth - this.sourceCoverRightInCard(),
        this.sourceCoverBottomInCard() - this.sourceCoverTopInCard(),
      )
      this.GalleryDetailCardSnapshotSlice(
        0,
        this.sourceCoverBottomInCard(),
        this.galleryDetailTransition.handoffWidth,
        this.galleryDetailTransition.handoffHeight - this.sourceCoverBottomInCard(),
      )
    }
    .width(this.galleryDetailTransition.handoffWidth)
    .height(this.galleryDetailTransition.handoffHeight)
    .position({
      x: this.galleryDetailTransition.handoffX,
      y: this.galleryDetailTransition.handoffY,
    })
    .borderRadius(this.galleryDetailTransition.sourceCardRadius)
    .clip(true)
    .opacity(this.galleryDetailTransition.cardOpacity)
    .zIndex(2)
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private GalleryDetailSourceSurfaceSnapshot() {
    if (this.galleryDetailTransition.sourceSnapshot !== undefined) {
      Image(this.galleryDetailTransition.sourceSnapshot)
        .width(this.galleryDetailTransition.sourceSnapshotWidth)
        .height(this.galleryDetailTransition.sourceSnapshotHeight)
        .objectFit(ImageFit.Fill)
        .syncLoad(true)
        .position({
          x: this.galleryDetailTransition.sourceSnapshotX,
          y: this.galleryDetailTransition.sourceSnapshotY,
        })
        .hitTestBehavior(HitTestMode.None)
    }
  }

  private galleryDetailNavTransition(
    from: NavContentInfo,
    to: NavContentInfo,
    operation: NavigationOperation,
  ): NavigationAnimatedTransition | undefined {
    if (this.layoutSafeArea.rootNavigationSplit) {
      return undefined
    }
    const fromTransitionToken: string = this.galleryTransitionToken(from)
    const toTransitionToken: string = this.galleryTransitionToken(to)
    if (operation === NavigationOperation.POP && fromTransitionToken.length > 0) {
      GalleryDetailTransitionCoordinator.activateRouteTransition(fromTransitionToken)
    }
    if (!this.galleryDetailTransition.eligible) {
      return undefined
    }
    const isPush: boolean = operation === NavigationOperation.PUSH &&
      toTransitionToken === this.galleryDetailTransition.routeToken
    const isPop: boolean = operation === NavigationOperation.POP &&
      fromTransitionToken === this.galleryDetailTransition.routeToken
    if (!isPush && !isPop) {
      return undefined
    }
    this.galleryDetailTransitionSerial += 1
    const transitionSerial: number = this.galleryDetailTransitionSerial
    return {
      timeout: ThemeTokens.ANIM_DURATION * 12,
      transition: (proxy: NavigationTransitionProxy): void => {
        if (isPush) {
          if (this.galleryDetailTransition.isCoverExpand() && !this.syncGalleryDetailCoverTarget()) {
            DiagnosticLogger.info(
              'gallery-detail-transition',
              'cover_target_fallback',
              `gid=${this.galleryDetailTransition.galleryId}`,
            )
            this.galleryDetailTransition.useSeamlessFallback()
          }
          const coverExpand: boolean = this.galleryDetailTransition.isCoverExpand()
          this.getUIContext().animateTo({
            duration: ThemeTokens.ANIM_DURATION,
            curve: GALLERY_DETAIL_OPEN_CURVE,
            onFinish: (): void => {
              if (transitionSerial === this.galleryDetailTransitionSerial) {
                proxy.finishTransition()
              }
            },
          }, (): void => {
            this.galleryDetailTransition.expandWindow()
          })
          if (!coverExpand) {
            this.getUIContext().animateTo({
              delay: ThemeTokens.ANIM_DURATION * GALLERY_DETAIL_OPEN_CARD_EXIT_START_TIME,
              duration: ThemeTokens.ANIM_DURATION * (
                GALLERY_DETAIL_OPEN_CARD_EXIT_END_TIME - GALLERY_DETAIL_OPEN_CARD_EXIT_START_TIME
              ),
              curve: Curve.Linear,
            }, (): void => {
              this.galleryDetailTransition.crossfadeToDetail()
            })
          } else {
            this.getUIContext().animateTo({
              delay: ThemeTokens.ANIM_DURATION * GALLERY_DETAIL_COVER_OPEN_CARD_EXIT_START_TIME,
              duration: ThemeTokens.ANIM_DURATION * (
                GALLERY_DETAIL_COVER_OPEN_CARD_EXIT_END_TIME - GALLERY_DETAIL_COVER_OPEN_CARD_EXIT_START_TIME
              ),
              curve: Curve.Linear,
            }, (): void => {
              this.galleryDetailTransition.hideSourceCard()
            })
          }
          return
        }
        const animatePopSurface: (onFinish: () => void) => void = (onFinish: () => void): void => {
          if (transitionSerial !== this.galleryDetailTransitionSerial) {
            return
          }
          if (this.galleryDetailTransition.isCoverExpand() && !this.syncGalleryDetailCoverTarget()) {
            DiagnosticLogger.info(
              'gallery-detail-transition',
              'cover_pop_fallback',
              `gallery=${this.galleryDetailTransition.galleryId} reason=target_not_visible`,
            )
            this.galleryDetailTransition.useCoverFadePopFallback()
          }
          const coverExpand: boolean = this.galleryDetailTransition.isCoverExpand()
          this.getUIContext().animateTo({
            duration: ThemeTokens.ANIM_DURATION,
            curve: GALLERY_DETAIL_CLOSE_CURVE,
            onFinish: (): void => {
              if (transitionSerial === this.galleryDetailTransitionSerial) {
                onFinish()
              }
            },
          }, (): void => {
            this.galleryDetailTransition.collapseWindow(ThemeTokens.RADIUS_CARD)
          })
          if (!coverExpand) {
            this.getUIContext().animateTo({
              delay: ThemeTokens.ANIM_DURATION * GALLERY_DETAIL_CLOSE_CARD_ENTRY_START_TIME,
              duration: ThemeTokens.ANIM_DURATION * (
                GALLERY_DETAIL_CLOSE_CARD_ENTRY_END_TIME - GALLERY_DETAIL_CLOSE_CARD_ENTRY_START_TIME
              ),
              curve: Curve.Linear,
            }, (): void => {
              this.galleryDetailTransition.crossfadeToCard()
            })
          } else {
            this.getUIContext().animateTo({
              delay: ThemeTokens.ANIM_DURATION * GALLERY_DETAIL_COVER_CLOSE_CARD_ENTRY_START_TIME,
              duration: ThemeTokens.ANIM_DURATION * (
                GALLERY_DETAIL_COVER_CLOSE_CARD_ENTRY_END_TIME -
                  GALLERY_DETAIL_COVER_CLOSE_CARD_ENTRY_START_TIME
              ),
              curve: Curve.Linear,
            }, (): void => {
              this.galleryDetailTransition.revealSourceCard()
            })
          }
        }
        const startPopAnimation: () => void = (): void => {
          this.galleryDetailTransition.beginPop()
          animatePopSurface((): void => {
            proxy.finishTransition()
          })
        }
        const startIndependentPopAnimation: () => void = (): void => {
          this.galleryDetailTransition.beginPop()
          GalleryDetailTransitionCoordinator.finishNavigationBeforeIndependentPop(
            this.getUIContext(),
            (): void => {
              proxy.finishTransition()
            },
            (): void => {
              if (transitionSerial !== this.galleryDetailTransitionSerial) {
                return
              }
              animatePopSurface((): void => {
                const handoffStarted: boolean =
                  GalleryDetailTransitionCoordinator.finishPostPopHandoff(
                    this.getUIContext(),
                    (): void => {
                      if (transitionSerial === this.galleryDetailTransitionSerial) {
                        GalleryDetailTransitionCoordinator.discardRouteTransition(fromTransitionToken)
                      }
                    },
                  )
                if (!handoffStarted) {
                  GalleryDetailTransitionCoordinator.discardRouteTransition(fromTransitionToken)
                }
              })
            },
          )
        }
        const sourceGeometryNeedsRefresh: boolean =
          GalleryDetailTransitionCoordinator.sourceGeometryNeedsRefresh(this.getUIContext())
        if (sourceGeometryNeedsRefresh) {
          const useIndependentPopSurface: boolean = this.galleryDetailTransition.isCoverExpand()
          if (
            useIndependentPopSurface &&
            !GalleryDetailTransitionCoordinator.prepareIndependentPopSurface(this.getUIContext())
          ) {
            GalleryDetailTransitionCoordinator.discardRouteTransition(fromTransitionToken)
            proxy.finishTransition()
            return
          }
          // The destination list is now the real POP target. Measure it only after its current
          // orientation constraints have rendered; entry-time geometry is deliberately discarded.
          GalleryDetailTransitionCoordinator.refreshSourceGeometryForPop(
            this.getUIContext(),
            (success: boolean): void => {
              if (transitionSerial !== this.galleryDetailTransitionSerial) {
                return
              }
              if (!success) {
                GalleryDetailTransitionCoordinator.discardRouteTransition(fromTransitionToken)
                proxy.finishTransition()
                return
              }
              if (useIndependentPopSurface) {
                startIndependentPopAnimation()
              } else {
                startPopAnimation()
              }
            },
          )
          return
        }
        startPopAnimation()
      },
      onTransitionEnd: (success: boolean): void => {
        if (transitionSerial !== this.galleryDetailTransitionSerial) {
          return
        }
        if (isPush) {
          this.galleryDetailTransition.markPushSettled(success)
          if (!success) {
            GalleryDetailTransitionCoordinator.discardRouteTransition(toTransitionToken)
          }
        } else if (this.galleryDetailTransition.independentPopSurfaceActive) {
          if (!success) {
            GalleryDetailTransitionCoordinator.discardRouteTransition(fromTransitionToken)
          }
        } else if (success && this.galleryDetailTransition.isCoverExpand()) {
          const handoffStarted: boolean = GalleryDetailTransitionCoordinator.finishPostPopHandoff(
            this.getUIContext(),
            (): void => {
              if (transitionSerial === this.galleryDetailTransitionSerial) {
                GalleryDetailTransitionCoordinator.discardRouteTransition(fromTransitionToken)
              }
            },
          )
          if (!handoffStarted) {
            this.galleryDetailTransition.markPopSettled(true)
            GalleryDetailTransitionCoordinator.discardRouteTransition(fromTransitionToken)
          }
        } else {
          this.galleryDetailTransition.markPopSettled(success)
          if (success) {
            GalleryDetailTransitionCoordinator.discardRouteTransition(fromTransitionToken)
          }
        }
      },
    }
  }

  private galleryTransitionToken(content: NavContentInfo): string {
    if (content.name !== ROUTE_GALLERY || !(content.param instanceof GalleryRouteParams)) {
      return ''
    }
    return content.param.transitionToken
  }

  private clearGalleryDetailTransitionOwnership(): void {
    this.galleryDetailTransition.reset()
    GalleryDetailTransitionCoordinator.clearRetainedTransitions()
  }

  build() {
    Stack() {
      if (
        this.galleryDetailTransition.eligible &&
        this.galleryDetailTransition.sourceSnapshot !== undefined &&
        !this.galleryDetailTransition.independentPopSurfaceActive &&
        (
          !this.galleryDetailTransition.isCoverExpand() ||
          this.galleryDetailTransition.phase === GalleryDetailTransitionPhase.OPENING ||
          this.galleryDetailTransition.phase === GalleryDetailTransitionPhase.CLOSING ||
          this.galleryDetailTransition.phase === GalleryDetailTransitionPhase.POST_POP_HANDOFF
        )
      ) {
        this.GalleryDetailSourceSurfaceSnapshot()
      }
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
        .tabBar(this.tabBar(AppStrings.get('tab_browse'), 0, 0))
        if (!this.safeMode.restricted()) {
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
          .tabBar(this.tabBar(AppStrings.get('tab_favorites'), 1, 1))
        }
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
              this.onHomeTabDidScroll(this.physicalTabForLogical(2), offset, state)
            },
          })
        }
        .tabBar(this.tabBar(
          AppStrings.get('tab_downloads'),
          this.physicalTabForLogical(2),
          2,
        ))
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
              this.openAccountEntry()
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
            onOpenLocalUserTags: (): void => {
              this.pushLocalUserTags()
            },
            onDidScroll: (offset: number, state: ScrollState): void => {
              this.onHomeTabDidScroll(this.physicalTabForLogical(3), offset, state)
            },
          })
        }
        .tabBar(this.tabBar(AppStrings.get('tab_me'), this.physicalTabForLogical(3), 3))
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
          this.clearGalleryDetailTransitionOwnership()
          if (this.stack.getAllPathName().length > 0) {
            this.stack.clear(false)
          }
          this.settingsNavigation.clearRootLocation()
          this.clearHomeGallerySelection()
          this.syncRootSecondaryBranch(this.stack)
        }
        this.activeTab = index
        this.titleScroller = this.rootTabScroller(index)
        if (this.homeTab.autoHide) {
          this.restoreHomeTabIfHidden()
        }
      })
      }
      .navDestination(this.routerMap)
      .customNavContentTransition((
        from: NavContentInfo,
        to: NavContentInfo,
        operation: NavigationOperation,
      ): NavigationAnimatedTransition | undefined => {
        return this.galleryDetailNavTransition(from, to, operation)
      })
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
      .width(
        this.coverExpandSurfaceActive()
          ? Math.max(1, this.galleryDetailTransition.rootWidth)
          : '100%',
      )
      .height(
        this.coverExpandSurfaceActive()
          ? Math.max(1, this.galleryDetailTransition.rootHeight)
          : '100%',
      )
      .position({
        x: this.coverExpandSurfaceActive() ? -this.galleryDetailTransition.clipX : 0,
        y: this.coverExpandSurfaceActive() ? -this.galleryDetailTransition.clipY : 0,
      })
      .backgroundColor(this.galleryDetailTransition.eligible ? Color.Transparent : ThemeTokens.SURFACE)
      .id('nextn-root-navigation')
      }
      .width(
        this.coverExpandSurfaceActive()
          ? Math.max(1, this.galleryDetailTransition.clipWidth)
          : '100%',
      )
      .height(
        this.coverExpandSurfaceActive()
          ? Math.max(1, this.galleryDetailTransition.clipHeight)
          : '100%',
      )
      .position({
        x: this.coverExpandSurfaceActive() ? this.galleryDetailTransition.clipX : 0,
        y: this.coverExpandSurfaceActive() ? this.galleryDetailTransition.clipY : 0,
      })
      .backgroundColor(ThemeTokens.SURFACE)
      .shadow(ShadowStyle.OUTER_DEFAULT_MD)
      .borderRadius(this.coverExpandSurfaceActive() ? this.galleryDetailTransition.radius : 0)
      .clip(this.coverExpandSurfaceActive())

      if (this.galleryDetailTransition.independentPopSurfaceVisible()) {
        Stack({ alignContent: Alignment.TopStart }) {
          Image(this.galleryDetailTransition.detailSnapshot)
            .width(this.galleryDetailTransition.rootWidth)
            .height(this.galleryDetailTransition.rootHeight)
            .objectFit(ImageFit.Fill)
            .syncLoad(true)
            .position({
              x: -this.galleryDetailTransition.clipX,
              y: -this.galleryDetailTransition.clipY,
            })
            .hitTestBehavior(HitTestMode.None)
        }
        .width(Math.max(1, this.galleryDetailTransition.clipWidth))
        .height(Math.max(1, this.galleryDetailTransition.clipHeight))
        .position({
          x: this.galleryDetailTransition.clipX,
          y: this.galleryDetailTransition.clipY,
        })
        .backgroundColor(ThemeTokens.SURFACE)
        .shadow(ShadowStyle.OUTER_DEFAULT_MD)
        .borderRadius(this.galleryDetailTransition.radius)
        .clip(true)
        .zIndex(1)
        .hitTestBehavior(HitTestMode.None)
      }

      if (this.galleryDetailTransition.detailSnapshotVisible()) {
        Stack({ alignContent: Alignment.TopStart }) {
          this.GalleryDetailSnapshotRemainder()
        }
        .width(Math.max(1, this.galleryDetailTransition.clipWidth))
        .height(Math.max(1, this.galleryDetailTransition.clipHeight))
        .position({
          x: this.galleryDetailTransition.clipX,
          y: this.galleryDetailTransition.clipY,
        })
        .borderRadius(this.galleryDetailTransition.radius)
        .clip(true)
        .opacity(this.galleryDetailTransition.contentOpacity)
        .zIndex(1)
        .hitTestBehavior(HitTestMode.None)
      }

      if (
        this.galleryDetailTransition.phase === GalleryDetailTransitionPhase.PREPARING &&
        this.galleryDetailTransition.cardSnapshot !== undefined
      ) {
        Image(this.galleryDetailTransition.cardSnapshot)
          .width(this.galleryDetailTransition.handoffWidth)
          .height(this.galleryDetailTransition.handoffHeight)
          .objectFit(ImageFit.Fill)
          .syncLoad(true)
          .position({
            x: this.galleryDetailTransition.handoffX,
            y: this.galleryDetailTransition.handoffY,
          })
          .hitTestBehavior(HitTestMode.None)
      }
      if (
        this.galleryDetailTransition.eligible &&
        this.galleryDetailTransition.isCoverExpand() &&
        this.galleryDetailTransition.cardSnapshot !== undefined
      ) {
        if (this.galleryDetailTransition.preserveSourceCoverBackground) {
          // This replacement card was captured with only the foreground cover hidden, so the real
          // blur/gradient, badges and metadata remain one image without a separately composited seam.
          Image(this.galleryDetailTransition.cardSnapshot)
            .width(this.galleryDetailTransition.handoffWidth)
            .height(this.galleryDetailTransition.handoffHeight)
            .objectFit(ImageFit.Fill)
            .syncLoad(true)
            .position({
              x: this.galleryDetailTransition.handoffX,
              y: this.galleryDetailTransition.handoffY,
            })
            .borderRadius(this.galleryDetailTransition.sourceCardRadius)
            .clip(true)
            .opacity(this.galleryDetailTransition.cardOpacity)
            .zIndex(2)
            .hitTestBehavior(HitTestMode.None)
        } else {
          this.GalleryDetailSourceCardRemainder()
        }
      }
      if (
        this.galleryDetailTransition.coverFlightVisible() &&
        this.galleryDetailTransition.coverSnapshot !== undefined
      ) {
        Stack({ alignContent: Alignment.TopStart }) {
          Stack() {
            if (this.galleryDetailTransition.coverUrl.length > 0) {
              EhImageKnifeImage({
                src: this.galleryDetailTransition.coverUrl,
                widthValue: '100%',
                heightValue: '100%',
                objectFit: ImageFit.Cover,
                radius: this.galleryDetailTransition.flightCoverRadius,
                onComplete: (): void => {
                  this.galleryDetailTransition.markCoverResourceReady()
                },
              })
            }
            if (!this.galleryDetailTransition.coverResourceReady) {
              Image(this.galleryDetailTransition.coverSnapshot)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .syncLoad(true)
            }
          }
          .width(this.galleryDetailTransition.flightCoverWidth)
          .height(this.galleryDetailTransition.flightCoverHeight)
          .position({
            x: this.galleryDetailTransition.flightCoverX - this.galleryDetailTransition.clipX,
            y: this.galleryDetailTransition.flightCoverY - this.galleryDetailTransition.clipY,
          })
          .borderRadius(this.galleryDetailTransition.flightCoverRadius)
          .clip(true)
          .renderGroup(true)
          .hitTestBehavior(HitTestMode.None)
        }
        .width(Math.max(1, this.galleryDetailTransition.clipWidth))
        .height(Math.max(1, this.galleryDetailTransition.clipHeight))
        .position({
          x: this.galleryDetailTransition.clipX,
          y: this.galleryDetailTransition.clipY,
        })
        .borderRadius(this.galleryDetailTransition.radius)
        .clip(true)
        .zIndex(3)
        .hitTestBehavior(HitTestMode.None)
      }
      if (
        this.galleryDetailTransition.fallbackCoverVisible() &&
        this.galleryDetailTransition.coverSnapshot !== undefined
      ) {
        Image(this.galleryDetailTransition.coverSnapshot)
          .width(this.galleryDetailTransition.sourceCoverWidth)
          .height(this.galleryDetailTransition.sourceCoverHeight)
          .objectFit(ImageFit.Fill)
          .syncLoad(true)
          .position({
            x: this.galleryDetailTransition.sourceCoverX,
            y: this.galleryDetailTransition.sourceCoverY,
          })
          .borderRadius(this.galleryDetailTransition.sourceCoverRadius)
          .clip(true)
          .opacity(this.galleryDetailTransition.fallbackCoverOpacity)
          .zIndex(3)
          .hitTestBehavior(HitTestMode.None)
      }

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
        .opacity(this.readerThumbnailTransition.overlayOpacity)
        .onAppear((): void => {
          this.readerOverlay.presentPendingReader()
        })
        .id('reader-overlay-navigation')
      }
      IndexReaderThumbnailTransitionProxy({ state: this.readerThumbnailTransition })
    }
    .width('100%')
    .height('100%')
  }
}
