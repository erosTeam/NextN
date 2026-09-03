import { common, Want } from '@kit.AbilityKit'
import { pasteboard } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { vibrator } from '@kit.SensorServiceKit'
import { HdsTabsController } from '@kit.UIDesignKit'
import {
  ContentFilterService,
  ContentFilterState,
  DiagnosticLogger,
  BrowsePresentationState,
  GalleryTitleState,
  GalleryDetailTransitionState,
  ReaderThumbnailTransitionCoordinator,
  ReaderThumbnailTransitionState,
  GalleryTitleTranslationService,
  DownloadQueueService,
  DownloadQueueState,
  FavoriteMutationState,
  HistoryRepository,
  InlineRetryNotice,
  LocalUserTagEditorSheet,
  LayoutSafeAreaBridge,
  LayoutSafeAreaState,
  LlmSourceProfilesState,
  NhApiClient,
  NhTagCatalogService,
  AccountSessionState,
  ActionFollowTouchState,
  ActionFollowTouchTracker,
  ActionHandEdgeState,
  MotionHandStateService,
  connectActionHandEdge,
  connectBrowsePresentation,
  AppStrings,
  currentScrollOffsetY,
  NhComment,
  NhGalleryDetail,
  NhGalleryDetailCacheService,
  NhGalleryFavoriteStatus,
  NhGalleryExternalOpenService,
  NhBrowserSessionBoundary,
  NhGalleryPage,
  NhGalleryShareService,
  NhGallerySummary,
  NhLocalUserTagService,
  NhLocalUserTagState,
  NhLocalUserTag,
  NhDownloadTask,
  NhDownloadTaskStatus,
  NhTag,
  NhTagQuery,
  NhTagTranslationInfo,
  NhTagSuggestionDisplay,
  NhTorrentFileExportService,
  NextNHdsCapsuleBarButton,
  NextNPullRefreshController,
  nextNHdsCapsuleActivityHeight,
  NextNGroupedListSection,
  NextNModalScaffold,
  PullRefreshListScaffold,
  TagTranslationRepository,
  TagTranslationInfoService,
  TagTranslationSettingsState,
  TagTranslationState,
  PageErrorState,
  PageLoadingState,
  ReadButtonStyleSettings,
  ReadButtonStyleState,
  ThemeTokens,
  connectAccountSession,
  connectContentFilters,
  connectDownloadQueue,
  connectFavoriteMutations,
  connectGalleryTitle,
  connectGalleryDetailTransition,
  connectLayoutSafeArea,
  connectLlmSourceProfiles,
  connectLocalUserTags,
  connectReaderOverlayNavigation,
  connectReaderThumbnailTransition,
  connectReadButtonStyle,
  connectTagTranslations,
  connectTagTranslationSettings,
  ReaderOverlayNavigationState,
  NhReadProgressState,
  connectNhReadProgress,
  supportsCommentTranslation,
} from 'shared'
import { appSheetOptions, EhImageKnifeImage, EH_IMAGE_PRIORITY_LOW } from 'shared'
import { GalleryChromeState } from '../state/GalleryChromeState'
import { GalleryThumbnailsChromeState } from '../state/GalleryThumbnailsChromeState'
import { GalleryThumbnailGridContent } from '../components/GalleryThumbnailGridContent'
import {
  GalleryCompactPreviewTile,
  GALLERY_COMPACT_PREVIEW_IMAGE_HEIGHT,
} from '../components/GalleryCompactPreviewTile'
import {
  GalleryCommentPreviewCarousel,
  GalleryRelatedCarousel,
} from '../components/GalleryDetailContentSections'

const DETAIL_TITLE_REVEAL_OFFSET: number = 160
// The cached destination width is an ArkUI layout measurement in vp.  A
// detail pane only becomes a workspace after HDS has actually resolved the
// root to Split and the real secondary pane can comfortably hold both halves.
const GALLERY_DETAIL_WIDE_WORKSPACE_MIN_WIDTH: number = 720
// Compact detail intentionally mounts only a bounded, non-scrollable preview
// peek inside its metadata List. The full virtualised page browser remains a
// separate destination, while a page tile still carries its real Reader index.
const GALLERY_COMPACT_PREVIEW_LIMIT: number = 6
const TITLE_TRANSLATION_ACTION_SIZE: number = 30
const TITLE_TRANSLATION_ICON_SIZE: number = 16
const TITLE_TRANSLATION_ENGLISH: string = 'english'
const TITLE_TRANSLATION_JAPANESE: string = 'japanese'
const TAG_INFO_ACTION_SIZE: number = 32
const TAG_INFO_HAPTIC_INTENSITY: number = 80
const TAG_INFO_HAPTIC_FALLBACK_DURATION: number = 30
const TAG_INFO_IMAGE_FALLBACK_RATIO: number = 3 / 4
const TAG_INFO_IMAGE_MIN_RATIO: number = 0.42
const TAG_INFO_IMAGE_MAX_RATIO: number = 1.8
const FOLLOW_OPERATION_VERTICAL_SCROLL_THRESHOLD: number = 12
const FOLLOW_OPERATION_VERTICAL_DOMINANCE_RATIO: number = 1.2
const DETAIL_CACHE_LOG_DOMAIN: number = 0x0000
const DETAIL_CACHE_LOG_TAG: string = 'NextNDetailCache'
/**
 * A retained Gallery destination has three materially different request
 * starts. Only a validated refresh for the same route may keep its current
 * snapshot interactive while the replacement response is pending.
 */
enum GalleryDetailLoadKind {
  INITIAL,
  SAME_GALLERY_REFRESH,
  ROUTE_CHANGE,
}

/**
 * Presentation-only tag grouping. The source API remains a flat array, so the
 * original index stays with every item and keeps local translation lookup
 * aligned with the raw tag that is used for search.
 */
class GalleryTagVisualItem {
  tag: NhTag
  originalIndex: number
  translatedName: string

  constructor(tag: NhTag, originalIndex: number, translatedName: string) {
    this.tag = tag
    this.originalIndex = originalIndex
    this.translatedName = translatedName
  }
}

class GalleryTagVisualGroup {
  namespace: string
  items: GalleryTagVisualItem[] = []

  constructor(namespace: string) {
    this.namespace = namespace
  }
}

class TagInfoLinkItem {
  label: string = ''
  url: string = ''
}

@ComponentV2
struct TagInfoIntroImage {
  @Param url: string = ''
  @Local loadedAspectRatio: number = 0

  private imageSizeMatch(): RegExpExecArray | null {
    const pattern: RegExp = /-\d+-(\d+)-(\d+)-[A-Za-z0-9]+(?:_(\d+)|_[A-Za-z]+)?\.[A-Za-z0-9]+(?:[?#].*)?$/
    return pattern.exec(this.url)
  }

  private clampAspectRatio(ratio: number): number {
    return Math.min(TAG_INFO_IMAGE_MAX_RATIO, Math.max(TAG_INFO_IMAGE_MIN_RATIO, ratio))
  }

  private sourceAspectRatio(): number {
    if (this.loadedAspectRatio > 0) {
      return this.loadedAspectRatio
    }
    const match: RegExpExecArray | null = this.imageSizeMatch()
    if (match === null) {
      return TAG_INFO_IMAGE_FALLBACK_RATIO
    }
    const width: number = Number.parseInt(match[1], 10)
    const height: number = Number.parseInt(match[2], 10)
    return width > 0 && height > 0
      ? this.clampAspectRatio(width / height)
      : TAG_INFO_IMAGE_FALLBACK_RATIO
  }

  private updateLoadedAspectRatio(width: number, height: number): void {
    if (width > 0 && height > 0) {
      this.loadedAspectRatio = this.clampAspectRatio(width / height)
    }
  }

  build() {
    EhImageKnifeImage({
      src: this.url,
      widthValue: '100%',
      heightValue: '100%',
      objectFit: ImageFit.Contain,
      radius: ThemeTokens.LIST_ROW_RADIUS,
      onImageInfo: (width: number, height: number): void => {
        this.updateLoadedAspectRatio(width, height)
      },
    })
      .width('100%')
      .aspectRatio(this.sourceAspectRatio())
      .backgroundColor(ThemeTokens.CARD_BACKGROUND)
      .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
      .clip(true)
  }
}

/** Local presentation for stable NH namespaces; members retain raw tag data. */
class GalleryTagNamespacePresentation {
  label: string
  foreground: ResourceColor
  background: ResourceColor

  constructor(label: string, foreground: ResourceColor, background: ResourceColor) {
    this.label = label
    this.foreground = foreground
    this.background = background
  }
}

/** Route-local title state; neither source text nor results alter gallery DTOs. */
class GalleryTitleTranslationState {
  kind: string = ''
  source: string = ''
  translated: string = ''
  shown: boolean = false
  loading: boolean = false
}

@ComponentV2
export struct GalleryDetailPage {
  @Require @Param galleryId: number
  /** Optional tapped-row snapshot; its fields paint immediately and are upgraded by the verified detail. */
  @Param seed?: NhGallerySummary | null = null
  @Local detail: NhGalleryDetail = new NhGalleryDetail()
  @Local isLoading: boolean = true
  @Local errorMessage: string = ''
  @Local isDetailReadyForCurrentGallery: boolean = false
  /** Distinct from index zero: only Reader persistence may set this true. */
  @Local hasReadProgress: boolean = false
  /**
   * The locally persisted zero-based Reader position. It is meaningful only
   * while `hasReadProgress` is true, because page zero is a real resume page.
   */
  @Local resumePageIndex: number = 0
  // In-memory reactive marker written by Reader page turns. Build-time readers
  // of has()/index() subscribe to its revision. Detail snapshots this state so
  // covered Reader changes become visible only when the exit transition starts.
  @Local readProgress: NhReadProgressState = connectNhReadProgress()
  @Local displayedHasReadProgress: boolean = false
  @Local displayedResumePageIndex: number = 0
  /**
   * The full-title sheet is strictly presentational. It is two-way bound to
   * the native sheet so drag/back dismissal cannot leave stale local state.
   */
  @Local fullTitleSheetShown: boolean = false
  @Local selectedTag: NhTag = new NhTag()
  @Local selectedTagDisplay: string = ''
  @Local tagInfoSheetShown: boolean = false
  @Local tagEditorSheetShown: boolean = false
  @Local tagHiddenMutationInFlight: boolean = false
  @Local tagInfoLoading: boolean = false
  @Local tagInfoError: string = ''
  @Local tagInfoName: string = ''
  @Local tagInfoIntro: string = ''
  @Local tagInfoLinks: string = ''
  @Local tagInfoImages: string[] = []
  @Local tagInfoEpoch: number = 0
  @Local pendingTagEditorSave: NhLocalUserTag | null = null
  @Local pendingTagEditorDeleteId: number = 0
  @Local coverFailedUrl: string = ''
  /** The cover bitmap currently on screen; a verified cover replaces it only after loading. */
  @Local displayedCoverUrl: string = ''
  /** Verified cover waiting to replace the seed thumbnail without a visible flash. */
  @Local pendingCoverUrl: string = ''
  @Local tagTranslationLabels: string[] = []
  /**
   * Identity-keyed translation labels. The positional label array changes
   * basis between the seed snapshot (list order) and the verified detail
   * (API order), while stable group ForEach keys reuse group components that
   * captured old items — a positional live read then shows one tag's
   * translation under another. Members resolve their own label by tag
   * identity instead, which is invariant to any reorder or component reuse.
   */
  @Local tagTranslationLabelMap: Map<string, string> = new Map()
  @Local tagTranslationPending: boolean = false
  @Local tagTranslations: TagTranslationState = connectTagTranslations()
  @Local tagTranslationSettings: TagTranslationSettingsState = connectTagTranslationSettings()
  @Local browsePresentation: BrowsePresentationState = connectBrowsePresentation()
  @Local relatedGalleries: NhGallerySummary[] = []
  /** Related rows use the same local title-rule view as every other gallery list. */
  @Local rawRelatedGalleries: NhGallerySummary[] = []
  /** The public discussion cache is filtered locally before the compact peek renders. */
  @Local commentPeek: NhComment[] = []
  @Local rawCommentPeek: NhComment[] = []
  /** A successful response is distinguishable from an empty or still-pending peek. */
  @Local commentPeekLoadedGalleryId: number = 0
  /** Related peek settled (rows or empty); false while the optional request runs. */
  @Local relatedLoaded: boolean = false
  /** Public comment peek settled; false while the optional request runs. */
  @Local commentPeekLoaded: boolean = false
  @Local favoriteStatusKnown: boolean = false
  @Local isFavorited: boolean = false
  @Local isFavoriteMutationInFlight: boolean = false
  @Local isTorrentExportInFlight: boolean = false
  @Local favoriteCountFromSession: number = -1
  @Local contentFilters: ContentFilterState = connectContentFilters()
  @Local localUserTags: NhLocalUserTagState = connectLocalUserTags()
  @Local accountSession: AccountSessionState = connectAccountSession()
  @Local favoriteMutations: FavoriteMutationState = connectFavoriteMutations()
  @Local layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  // Seed future wide-detail decisions from the width measured for the root
  // HDS mode that is actually active, not merely from the persisted policy.
  // Keep this adjacent to the layout connection: it must be available on the
  // destination's first frame before its own area measurement runs.
  @Local detailRootWidth: number = connectLayoutSafeArea().rememberedGalleryDetailContentWidth(
    connectLayoutSafeArea().rootNavigationSplit,
  )
  @Local galleryTitle: GalleryTitleState = connectGalleryTitle()
  @Local galleryDetailTransition: GalleryDetailTransitionState = connectGalleryDetailTransition()
  @Local llmSources: LlmSourceProfilesState = connectLlmSourceProfiles()
  @Local readButtonStyle: ReadButtonStyleState = connectReadButtonStyle()
  @Local actionHandEdge: ActionHandEdgeState = connectActionHandEdge()
  // The service resolves the persisted alignment before this page mounts. Keep
  // a local target solely so the existing floating Read rail can animate.
  @Local visualActionHandEdge: string = connectActionHandEdge().edge
  @Local detailWorkspaceWidth: number = 0
  @Local detailWorkspaceGlobalX: number = 0
  @Local readFabWidth: number = 0
  @Local readFabLayoutReady: boolean = false
  @Local readFabShouldAnimate: boolean = false
  @Local downloadQueue: DownloadQueueState = connectDownloadQueue()
  @Local titleTranslations: GalleryTitleTranslationState[] = []
  /**
   * NH list rows do not carry Detail's `title.pretty`. Keep the outgoing Hero
   * text alive while the verified title layer fades in, otherwise replacing
   * the reactive Detail DTO changes Text content in one unanimated frame.
   */
  @Local heroTitleOutgoingPrimary: string = ''
  @Local heroTitleOutgoingSecondary: string = ''
  @Local heroTitleOutgoingId: string = ''
  @Local heroTitleOutgoingMaxLines: number = 1
  @Local heroTitleTransitionProgress: number = 1
  @Local heroTitleTransitionActive: boolean = false
  // This is not navigation ownership. Gallery only stages its already
  // validated public DTO; the entry-owned overlay attaches it to the next
  // matching Reader route and Reader consumes it exactly once.
  @Local readerOverlay: ReaderOverlayNavigationState = connectReaderOverlayNavigation()
  private readerThumbnailTransition: ReaderThumbnailTransitionState = connectReaderThumbnailTransition()
  private readerTransitionScope: string =
    ReaderThumbnailTransitionCoordinator.allocateScope('gallery-detail')
  @Param scroller: Scroller = new Scroller()
  @Param chrome: GalleryChromeState = new GalleryChromeState()
  @Event onOpenGallery?: (galleryId: number, seed?: NhGallerySummary) => void
  @Event onOpenThumbnails?: (
    galleryId: number,
    pages: NhGalleryPage[],
    detailSeed: NhGalleryDetail,
  ) => void
  @Event onOpenReader?: (galleryId: number, initialPageIndex: number, animated: boolean) => void
  @Event onOpenComments?: (galleryId: number, comments: NhComment[], snapshotAvailable: boolean) => void
  @Event onOpenDownloads?: () => void
  @Event onSearchQuery?: (query: string) => void
  @Event onChromeChanged?: () => void
  private requestGeneration: number = 0
  private relatedRequestGeneration: number = 0
  private commentPeekGeneration: number = 0
  private titleTranslationEpoch: number = 0
  private heroTitleTransitionEpoch: number = 0
  private tagTranslationEpoch: number = 0
  private readProgressRequestGeneration: number = 0
  private favoriteStatusGeneration: number = 0
  private readFabController: HdsTabsController = new HdsTabsController()
  private followTouchState: ActionFollowTouchState = ActionFollowTouchTracker.initialState()
  /** Shared refresh host; it never represents this page's initial-load state. */
  private detailRefreshController: NextNPullRefreshController = new NextNPullRefreshController()
  // This owner intentionally never aliases the metadata List scroller: the
  // reference wide workspace keeps full-thumbnail browsing independent.
  private widePreviewScroller: Scroller = new Scroller()
  private widePreviewChrome: GalleryThumbnailsChromeState = new GalleryThumbnailsChromeState()

  aboutToAppear(): void {
    this.resetNavigationChromeForCurrentRoute()
    this.publishWideThumbnailActionAvailability()
    if (!this.readerOverlay.visible) {
      this.syncDisplayedReadProgress()
    }
    // A retained destination returning from Reader already has a verified
    // snapshot. Reloading it here was what painted an unsolicited pull-refresh
    // state on every return; only the first unresolved route loads on appear.
    if (this.detail.id !== this.galleryId) {
      this.loadDetail()
    }
  }

  aboutToDisappear(): void {
    // A pushed Reader keeps this detail destination alive on the navigation
    // stack.  Cancel an in-flight response, but do not revoke the already
    // verified detail: returning from Reader must leave its Read action ready.
    this.requestGeneration += 1
    this.readProgressRequestGeneration += 1
    // A cache hit may still be revalidating in the background. That request
    // belongs to the departed route, not to the retained Detail workspace.
    // Clear only its transient ownership; the verified snapshot stays ready.
    this.isLoading = false
    this.publishRefreshChrome(false)
    // Related galleries are supplemental. Do not let an old background
    // response mutate this retained destination while another route is shown.
    this.relatedRequestGeneration += 1
    // The comments peek is also supplementary. Its request must not mutate a
    // retained destination after Reader or another gallery takes focus.
    this.commentPeekGeneration += 1
    this.titleTranslationEpoch += 1
  }

  @Monitor('galleryId')
  onGalleryChanged(): void {
    // `loadDetail` classifies this as ROUTE_CHANGE before starting the
    // request, so stale route actions cannot remain interactive while the
    // retained destination resolves the replacement Gallery.
    this.loadDetail()
  }

  @Monitor('contentFilters.revision')
  onContentFiltersChanged(): void {
    this.applyRelatedContentFilters()
    this.applyCommentPeekFilters()
  }

  @Monitor('localUserTags.revision')
  onLocalUserTagsChanged(): void {
    this.applyRelatedContentFilters()
  }

  @Monitor('tagTranslations.revision')
  onTagTranslationsChanged(): void {
    if (this.isDetailReadyForCurrentGallery && this.detail.id === this.galleryId) {
      this.requestTagTranslations(this.requestGeneration, this.detail.id, this.detail.tags)
    }
  }

  /** The route-local HDS command reuses the same generation-fenced loader. */
  @Monitor('chrome.reloadVersion')
  onReloadRequested(): void {
    if (this.chrome.reloadVersion > 0) {
      this.requestDetailRefresh()
    }
  }

  @Monitor('layoutSafeArea.rootNavigationSplit')
  onRootNavigationModeChanged(): void {
    // HDS has changed its resolved physical mode. Reuse only the matching
    // cache until onAreaChange provides this destination's current width.
    this.detailRootWidth = this.layoutSafeArea.rememberedGalleryDetailContentWidth(
      this.layoutSafeArea.rootNavigationSplit,
    )
    this.publishWideThumbnailActionAvailability()
  }

  @Monitor('actionHandEdge.edge')
  onActionHandEdgeChanged(): void {
    this.readFabShouldAnimate = this.readFabLayoutReady
    this.visualActionHandEdge = this.actionHandEdge.edge
  }

  @Monitor('readButtonStyle.style')
  onReadButtonStyleChanged(): void {
    this.readFabWidth = 0
    this.readFabLayoutReady = false
    this.readFabShouldAnimate = false
  }

  @Monitor('accountSession.revision')
  onAccountSessionChanged(): void {
    // Account status can change while this destination is retained. Consume
    // Entry's published state; this page must not inspect or restore session
    // material on its own.
    if (this.isDetailReadyForCurrentGallery && !this.isFavoriteMutationInFlight) {
      if (!this.hasPublishedAccountSession()) {
        this.favoriteStatusKnown = false
        this.isFavorited = false
        this.favoriteCountFromSession = -1
        this.publishFavoriteChrome(false, false, false)
        return
      }
      this.loadFavoriteStatus(this.requestGeneration, this.detail.id)
    }
  }

  private hasPublishedAccountSession(): boolean {
    return this.accountSession.initialized && this.accountSession.signedIn &&
      this.accountSession.authenticationAvailable && !this.accountSession.verificationRequired
  }

  @Monitor('chrome.wideThumbnailFirstPageRequestVersion')
  onWideThumbnailFirstPageRequested(): void {
    if (this.chrome.wideThumbnailFirstPageRequestVersion <= 0 ||
      !this.wideThumbnailActionsAvailable()) {
      return
    }
    this.widePreviewChrome.firstPageRequestVersion += 1
  }

  @Monitor('chrome.wideThumbnailJumpPageRequestVersion')
  onWideThumbnailJumpPageRequested(): void {
    if (this.chrome.wideThumbnailJumpPageRequestVersion <= 0 ||
      !this.wideThumbnailActionsAvailable()) {
      return
    }
    this.widePreviewChrome.jumpPageRequestVersion += 1
  }

  private applyRelatedContentFilters(): void {
    this.relatedGalleries = ContentFilterService.filterGalleries(this.rawRelatedGalleries)
  }

  private applyCommentPeekFilters(): void {
    this.commentPeek = ContentFilterService.filterComments(this.rawCommentPeek)
  }

  @Monitor('chrome.shareRequestVersion')
  onShareRequested(): void {
    if (this.chrome.shareRequestVersion > 0) {
      this.shareCurrentGallery()
    }
  }

  @Monitor('chrome.copyLinkRequestVersion')
  onCopyLinkRequested(): void {
    if (this.chrome.copyLinkRequestVersion > 0) {
      this.copyCurrentGalleryLink()
    }
  }

  @Monitor('chrome.commentsRequestVersion')
  onCommentsRequested(): void {
    if (this.chrome.commentsRequestVersion > 0) {
      this.openComments()
    }
  }

  @Monitor('chrome.externalOpenRequestVersion')
  onExternalOpenRequested(): void {
    if (this.chrome.externalOpenRequestVersion > 0) {
      this.openCurrentGalleryExternally()
    }
  }

  @Monitor('downloadQueue.revision')
  onDownloadQueueChanged(): void {
    this.publishDownloadChrome()
  }

  @Monitor('chrome.favoriteRequestVersion')
  onFavoriteRequested(): void {
    if (this.chrome.favoriteRequestVersion > 0) {
      this.requestFavoriteToggle()
    }
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message })
  }

  private copyCurrentGalleryLink(): void {
    try {
      const data = pasteboard.createData(
        pasteboard.MIMETYPE_TEXT_PLAIN,
        NhBrowserSessionBoundary.canonicalGalleryUrl(this.galleryId),
      )
      const board = pasteboard.getSystemPasteboard()
      board.setDataSync(data)
      this.toast(AppStrings.get('detail_link_copied'))
    } catch (_error) {
      this.toast(AppStrings.get('detail_link_copy_failed'))
    }
  }

  private isCurrentRequest(generation: number): boolean {
    return generation === this.requestGeneration
  }

  private isCurrentRelatedRequest(generation: number): boolean {
    return generation === this.relatedRequestGeneration
  }

  private detailLoadKind(): GalleryDetailLoadKind {
    if (this.detail.id <= 0) {
      return GalleryDetailLoadKind.INITIAL
    }
    if (this.isDetailReadyForCurrentGallery && this.detail.id === this.galleryId) {
      return GalleryDetailLoadKind.SAME_GALLERY_REFRESH
    }
    return GalleryDetailLoadKind.ROUTE_CHANGE
  }

  /**
   * Initial loads and route changes must not leave a previous Gallery's
   * actions, title, preview, or account-scoped chrome reachable. A same-ID
   * refresh deliberately does not call this: its validated snapshot remains
   * usable until the next response replaces it.
   */
  private resetDetailForReplacementRoute(): void {
    this.isDetailReadyForCurrentGallery = false
    this.detail = new NhGalleryDetail()
    this.hasReadProgress = false
    this.resumePageIndex = 0
    this.displayedHasReadProgress = false
    this.displayedResumePageIndex = 0
    this.fullTitleSheetShown = false
    this.coverFailedUrl = ''
    this.displayedCoverUrl = ''
    this.pendingCoverUrl = ''
    this.tagTranslationLabels = []
    this.tagTranslationLabelMap = new Map()
    this.tagTranslationPending = false
    this.tagTranslationEpoch += 1
    this.readProgressRequestGeneration += 1
    this.titleTranslationEpoch += 1
    this.titleTranslations = []
    this.resetHeroTitleTransition()
    this.favoriteStatusGeneration += 1
    this.favoriteStatusKnown = false
    this.isFavorited = false
    this.isFavoriteMutationInFlight = false
    this.favoriteCountFromSession = -1
    this.publishNavigationChrome('', false)
    this.publishFavoriteChrome(false, false, false)
    this.publishDownloadChrome()
    this.publishWideThumbnailActionAvailability()
    this.relatedRequestGeneration += 1
    this.rawRelatedGalleries = []
    this.relatedLoaded = false
    this.applyRelatedContentFilters()
    this.commentPeekGeneration += 1
    this.rawCommentPeek = []
    this.commentPeekLoadedGalleryId = 0
    this.commentPeekLoaded = false
    this.applyCommentPeekFilters()
  }

  /**
   * Same-gallery refreshes fence every background response without clearing
   * the already validated snapshot. This keeps Read, thumbnail navigation,
   * favourite/download actions, and metadata responsive while Refresh owns
   * the in-flight affordance.
   */
  private invalidateSameGalleryRefreshRequests(): void {
    this.favoriteStatusGeneration += 1
    this.relatedRequestGeneration += 1
    this.commentPeekGeneration += 1
  }

  private beginDetailLoad(): number {
    const loadKind: GalleryDetailLoadKind = this.detailLoadKind()
    const generation: number = this.requestGeneration + 1
    this.requestGeneration = generation
    this.isLoading = true
    this.publishRefreshChrome(true)
    this.errorMessage = ''
    switch (loadKind) {
      case GalleryDetailLoadKind.SAME_GALLERY_REFRESH:
        this.invalidateSameGalleryRefreshRequests()
        break
      case GalleryDetailLoadKind.INITIAL:
      case GalleryDetailLoadKind.ROUTE_CHANGE:
        this.resetDetailForReplacementRoute()
        break
      default:
        this.resetDetailForReplacementRoute()
    }
    return generation
  }

  private publishNavigationChrome(title: string, showTitle: boolean): void {
    const normalizedTitle: string = title.trim()
    if (this.chrome.title === normalizedTitle && this.chrome.showTitle === showTitle) {
      return
    }
    this.chrome.title = normalizedTitle
    this.chrome.showTitle = showTitle
    if (this.onChromeChanged) {
      this.onChromeChanged()
    }
  }

  private publishFavoriteChrome(known: boolean, favorited: boolean, busy: boolean): void {
    if (this.chrome.favoriteKnown === known && this.chrome.isFavorited === favorited &&
      this.chrome.favoriteBusy === busy) {
      return
    }
    this.chrome.favoriteKnown = known
    this.chrome.isFavorited = favorited
    this.chrome.favoriteBusy = busy
    if (this.onChromeChanged) {
      this.onChromeChanged()
    }
  }

  /**
   * The refresh affordance lives in the entry-owned HDS title bar, so mirror
   * only this page's existing loading truth through its route-local chrome.
   */
  private publishRefreshChrome(inFlight: boolean): void {
    if (this.chrome.refreshInFlight === inFlight) {
      return
    }
    this.chrome.refreshInFlight = inFlight
    if (this.onChromeChanged) {
      this.onChromeChanged()
    }
  }

  /**
   * Lifecycle changes may intentionally replace an in-flight request, but a
   * repeated title command must not create a second request for this detail.
   */
  private requestDetailRefresh(): void {
    if (this.isLoading) {
      return
    }
    if (this.isDetailReadyForCurrentGallery && this.detail.id === this.galleryId) {
      this.detailRefreshController.requestRefresh()
      return
    }
    // There is no mounted interactive host while initial/route replacement
    // error content is on screen, so retry that unresolved state directly.
    this.loadDetail(true)
  }

  /** Called only by the shared top-pull/programmatic refresh host. */
  private async refreshCurrentDetail(): Promise<void> {
    if (this.isLoading || !this.isDetailReadyForCurrentGallery || this.detail.id !== this.galleryId) {
      return
    }
    await this.loadDetail(true)
  }

  private isDownloadActionReady(): boolean {
    return this.isDetailReadyForCurrentGallery &&
      this.detail.id === this.galleryId &&
      this.detail.pages.length > 0
  }

  /** A durable task for the current gallery id, independent of the fresh
   *  verified response, so an already-downloaded old gallery keeps an
   *  actionable chip even when revalidation is pending or fails. */
  private hasKnownDownloadTask(): boolean {
    if (this.detail.id !== this.galleryId) {
      return false
    }
    return this.downloadQueue.tasks.some(
      (candidate: NhDownloadTask): boolean => candidate.galleryId === this.detail.id,
    )
  }

  /** The chip is actionable when a durable task exists or fresh pages are ready. */
  private downloadChipEnabled(): boolean {
    return this.hasKnownDownloadTask() || this.isDownloadActionReady()
  }

  private currentDownloadTask(): NhDownloadTask | null {
    if (this.detail.id !== this.galleryId) {
      return null
    }
    const task: NhDownloadTask | undefined = this.downloadQueue.tasks.find(
      (candidate: NhDownloadTask): boolean => candidate.galleryId === this.detail.id,
    )
    return task ?? null
  }

  /** Download chip title mirrors NextE's stateful chip: task-less shows the
   *  action, existing tasks show their durable status. */
  private downloadActionTitle(): string {
    const task: NhDownloadTask | null = this.currentDownloadTask()
    if (task === null) {
      return AppStrings.get('action_download')
    }
    if (task.isComplete()) {
      return AppStrings.get('action_downloaded')
    }
    if (task.status === NhDownloadTaskStatus.DOWNLOADING) {
      return AppStrings.get('download_status_downloading')
    }
    if (task.status === NhDownloadTaskStatus.PAUSED) {
      return AppStrings.get('download_status_paused')
    }
    if (task.status === NhDownloadTaskStatus.ERROR) {
      return AppStrings.get('download_status_error')
    }
    return AppStrings.get('download_status_queued')
  }

  private publishDownloadChrome(): void {
    const ready: boolean = this.downloadChipEnabled()
    const task: NhDownloadTask | null = this.currentDownloadTask()
    const status: string = task === null ? '' : task.status
    const pageCount: number = task === null ? 0 : Math.max(0, task.pageCount)
    const completedPages: number = task === null || pageCount === 0
      ? 0
      : Math.min(pageCount, Math.max(0, task.completedPages))
    if (this.chrome.downloadActionReady === ready &&
      this.chrome.downloadStatus === status &&
      this.chrome.downloadCompletedPages === completedPages &&
      this.chrome.downloadPageCount === pageCount) {
      return
    }
    this.chrome.downloadActionReady = ready
    this.chrome.downloadStatus = status
    this.chrome.downloadCompletedPages = completedPages
    this.chrome.downloadPageCount = pageCount
    if (this.onChromeChanged) {
      this.onChromeChanged()
    }
  }

  private resetNavigationChromeForCurrentRoute(): void {
    if (this.detail.id !== this.galleryId) {
      this.publishNavigationChrome('', false)
      this.publishFavoriteChrome(false, false, false)
      this.publishDownloadChrome()
    }
  }

  private updateNavigationChromeForScroll(): void {
    if (!this.isDetailReadyForCurrentGallery || this.detail.id !== this.galleryId) {
      this.publishNavigationChrome('', false)
      return
    }
    // The shared helper treats the not-yet-attached Scroller frame as 0,
    // which resolves to the collapsed title state.
    const revealTitle: boolean = currentScrollOffsetY(this.scroller) > DETAIL_TITLE_REVEAL_OFFSET
    this.publishNavigationChrome(this.galleryHeroPrimaryTitle(), revealTitle)
  }

  private openReader(initialPageIndex: number = -1, animated: boolean = true): void {
    if (!this.isDetailReadyForCurrentGallery || this.detail.id !== this.galleryId || this.detail.pages.length === 0 || !this.onOpenReader) {
      return
    }
    if (initialPageIndex >= this.detail.pages.length) {
      return
    }
    this.readerOverlay.stageDetailSeed(this.detail)
    try {
      this.onOpenReader(this.detail.id, initialPageIndex, animated)
    } finally {
      // The entry opens Reader synchronously and has already attached the
      // seed. A no-op/alternate host must not leave it staged for a later
      // unrelated Reader route.
      this.readerOverlay.discardStagedDetailSeed(this.detail.id)
    }
  }

  private openReaderFromThumbnail(pageIndex: number): void {
    if (pageIndex < 0 || pageIndex >= this.detail.pages.length) {
      return
    }
    ReaderThumbnailTransitionCoordinator.open(
      this.getUIContext(),
      this.readerTransitionScope,
      this.detail.id.toString(),
      pageIndex,
      this.detail.pages[pageIndex],
      (animated: boolean): void => {
        this.openReader(pageIndex, animated)
      },
    )
  }

  private detailTransitionCoverId(): string {
    return this.galleryDetailTransition.galleryId === this.galleryId.toString()
      ? this.galleryDetailTransition.targetCoverComponentId
      : ''
  }

  private detailCoverMasked(): boolean {
    return this.galleryDetailTransition.galleryId === this.galleryId.toString() &&
      this.galleryDetailTransition.coverMaskVisible()
  }

  private openComments(): void {
    if (this.galleryId <= 0 || !this.onOpenComments) {
      return
    }
    const snapshotAvailable: boolean = this.commentPeekLoadedGalleryId === this.galleryId
    this.onOpenComments(
      this.galleryId,
      snapshotAvailable ? this.rawCommentPeek : [],
      snapshotAvailable,
    )
  }

  private openRelatedGallery(galleryId: number): void {
    if (galleryId <= 0 || galleryId === this.galleryId || !this.onOpenGallery) {
      return
    }
    let seed: NhGallerySummary | null = null
    for (let index: number = 0; index < this.relatedGalleries.length; index++) {
      if (this.relatedGalleries[index].id === galleryId) {
        seed = this.relatedGalleries[index]
        break
      }
    }
    this.onOpenGallery(galleryId, seed === null ? undefined : seed)
  }

  private openThumbnails(): void {
    const onOpenThumbnails = this.onOpenThumbnails
    if (!this.canOpenThumbnails() || !onOpenThumbnails) {
      return
    }
    onOpenThumbnails(this.detail.id, this.detail.pages, this.detail.copy())
  }

  private async shareCurrentGallery(): Promise<void> {
    if (!this.isDetailReadyForCurrentGallery || this.detail.id !== this.galleryId) {
      return
    }
    const opened: boolean = await NhGalleryShareService.shareCanonicalGallery(this.context(), this.detail.id)
    if (!opened) {
      this.showShareUnavailable()
    }
  }

  private async openCurrentGalleryExternally(): Promise<void> {
    if (!this.isDetailReadyForCurrentGallery || this.detail.id !== this.galleryId) {
      return
    }
    const opened: boolean = await NhGalleryExternalOpenService.openCanonicalGallery(this.context(), this.detail.id)
    if (!opened) {
      this.showExternalOpenUnavailable()
    }
  }

  private openDownloads(): void {
    if (this.onOpenDownloads) {
      this.onOpenDownloads()
    }
  }

  private async handleDownloadAction(): Promise<void> {
    if (!this.hasKnownDownloadTask() && !this.isDownloadActionReady()) {
      return
    }
    const existing: NhDownloadTask | null = this.currentDownloadTask()
    if (existing === null) {
      await this.enqueueDownload()
      return
    }
    if (existing.status === NhDownloadTaskStatus.PAUSED || existing.status === NhDownloadTaskStatus.ERROR) {
      try {
        await DownloadQueueService.resume(this.context(), existing.galleryId)
      } catch (_error) {
        this.showDownloadToast(AppStrings.get('gallery_error_add_download'))
        return
      }
    }
    // The chip is download-only: NextE opens its download-variant menu for
    // existing tasks, and NextN's NH queue has no original/regular variant, so
    // the durable queue screen is the equivalent surface. Reading belongs
    // exclusively to the Read action, never to this button.
    this.openDownloads()
  }

  private async enqueueDownload(): Promise<void> {
    if (!this.isDownloadActionReady()) {
      return
    }
    try {
      await DownloadQueueService.enqueue(this.context(), this.detail)
      this.showDownloadToast(AppStrings.get('gallery_toast_added_downloads'))
    } catch (_error) {
      DiagnosticLogger.warn('download', 'gallery_enqueue_failed', '')
      this.showDownloadToast(AppStrings.get('gallery_error_add_download'))
    }
  }

  private showDownloadToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_error) {}
  }

  private requestTorrentFileExport(): void {
    if (this.detail.id !== this.galleryId || this.isTorrentExportInFlight) {
      return
    }
    if (!this.hasPublishedAccountSession()) {
      this.showTorrentToast(AppStrings.get('gallery_error_signin_export_torrent'))
      return
    }
    this.exportTorrentFile()
  }

  private async exportTorrentFile(): Promise<void> {
    if (this.isTorrentExportInFlight ||
      this.detail.id !== this.galleryId || !this.hasPublishedAccountSession()) {
      return
    }
    const galleryId: number = this.detail.id
    this.isTorrentExportInFlight = true
    try {
      const issuedUrl: string = await NhApiClient.issueTorrentLink(galleryId)
      if (this.detail.id !== galleryId || this.galleryId !== galleryId) {
        return
      }
      const shared: boolean = await NhTorrentFileExportService.downloadAndShare(this.context(), galleryId, issuedUrl)
      if (!shared) {
        this.showTorrentToast(AppStrings.get('gallery_error_export_torrent_retry'))
      }
    } catch (_error) {
      DiagnosticLogger.warn('download', 'gallery_torrent_export_failed', '')
      this.showTorrentToast(AppStrings.get('gallery_error_export_torrent_session'))
    } finally {
      this.isTorrentExportInFlight = false
    }
  }

  private showTorrentToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_error) {}
  }

  /**
   * Resolves account-scoped favourite state only after the public detail is
   * ready. A failed lookup remains deliberately unknown, so the next title
   * action refreshes rather than guessing whether to add or remove remotely.
   */
  private async loadFavoriteStatus(detailGeneration: number, galleryId: number): Promise<void> {
    const statusGeneration: number = this.favoriteStatusGeneration + 1
    this.favoriteStatusGeneration = statusGeneration
    const status: NhGalleryFavoriteStatus = await NhApiClient.favoriteStatus(galleryId)
    if (!this.isCurrentRequest(detailGeneration) || this.detail.id !== galleryId ||
      statusGeneration !== this.favoriteStatusGeneration || this.isFavoriteMutationInFlight) {
      return
    }
    this.favoriteStatusKnown = status.known
    this.isFavorited = status.isFavorited
    this.favoriteCountFromSession = status.hasFavoriteCount ? status.favoriteCount : -1
    this.publishFavoriteChrome(status.known, status.isFavorited, false)
  }

  /** True only while this retained destination still owns the local read result. */
  private isCurrentReadProgressRequest(
    detailGeneration: number,
    galleryId: number,
    readProgressGeneration: number,
  ): boolean {
    return readProgressGeneration === this.readProgressRequestGeneration &&
      this.isCurrentRequest(detailGeneration) &&
      this.isDetailReadyForCurrentGallery &&
      this.galleryId === galleryId &&
      this.detail.id === galleryId
  }

  /**
   * Reader opens the actual `detail.pages` collection, so its length is the
   * only page-count authority that can safely label the local resume index.
   */
  private localResumePageCount(): number {
    return Math.max(0, this.detail.pages.length)
  }

  /** Clamp stale durable state to the current Gallery page collection. */
  private clampResumePageIndex(pageIndex: number): number {
    const pageCount: number = this.localResumePageCount()
    return Math.min(Math.max(0, Math.floor(pageIndex)), Math.max(0, pageCount - 1))
  }

  /**
   * The gallery read control needs only local resume truth. This remains
   * independent of detail, account, comments, and any remote request state.
   * Read the marker before the index: page zero is a valid Reader position,
   * not evidence that this Gallery has never been read.
   */
  private async loadReadProgress(detailGeneration: number, galleryId: number): Promise<void> {
    const readProgressGeneration: number = this.readProgressRequestGeneration + 1
    this.readProgressRequestGeneration = readProgressGeneration
    try {
      const hasProgress: boolean = await HistoryRepository.hasReadProgress(this.context(), galleryId)
      if (!this.isCurrentReadProgressRequest(detailGeneration, galleryId, readProgressGeneration)) {
        return
      }
      let resumePageIndex: number = 0
      if (hasProgress) {
        const persistedPageIndex: number = await HistoryRepository.progress(this.context(), galleryId)
        if (!this.isCurrentReadProgressRequest(detailGeneration, galleryId, readProgressGeneration)) {
          return
        }
        resumePageIndex = this.clampResumePageIndex(persistedPageIndex)
      }
      if (!this.isCurrentReadProgressRequest(detailGeneration, galleryId, readProgressGeneration)) {
        return
      }
      this.hasReadProgress = hasProgress
      this.resumePageIndex = resumePageIndex
      if (hasProgress) {
        // Keep the durable seed in the in-memory holder so a later Reader
        // turn always has a reactive baseline even before any new write.
        this.readProgress.seed(galleryId, resumePageIndex)
      }
      if (!this.readerOverlay.visible) {
        this.syncDisplayedReadProgress()
      }
    } catch (error) {
      if (this.isCurrentReadProgressRequest(detailGeneration, galleryId, readProgressGeneration)) {
        console.warn(`Unable to load local reading progress: ${(error as Error).message}`)
      }
    }
  }

  private requestFavoriteToggle(): void {
    if (!this.isDetailReadyForCurrentGallery || this.detail.id !== this.galleryId ||
      this.isFavoriteMutationInFlight) {
      return
    }
    if (!this.hasPublishedAccountSession()) {
      this.showFavoriteToast(AppStrings.get('gallery_error_signin_favourites'))
      return
    }
    if (!this.favoriteStatusKnown) {
      this.loadFavoriteStatus(this.requestGeneration, this.detail.id)
      // Optimistic toggle: an unknown status is treated as not-favourited.
      // The user intent executes immediately; the POST response is the
      // authoritative confirmation and a failure rolls the UI back below.
      this.saveFavorite(true)
      return
    }
    if (this.isFavorited) {
      this.confirmRemoveFavorite()
      return
    }
    this.saveFavorite(true)
  }

  private confirmRemoveFavorite(): void {
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('gallery_dialog_remove_favourite_title'),
      message: AppStrings.get('gallery_dialog_remove_favourite_message'),
      primaryButton: {
        value: AppStrings.get('gallery_action_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('gallery_action_remove'),
        fontColor: Color.Red,
        action: (): void => {
          this.saveFavorite(false)
        },
      },
    })
  }

  private async saveFavorite(shouldFavorite: boolean): Promise<void> {
    if (this.isFavoriteMutationInFlight || !this.isDetailReadyForCurrentGallery ||
      this.detail.id !== this.galleryId) {
      return
    }
    this.isFavoriteMutationInFlight = true
    this.favoriteStatusGeneration += 1
    // Optimistic snapshot: flip the visible state immediately; roll back to
    // exactly these values if the mutation fails.
    const previousKnown: boolean = this.favoriteStatusKnown
    const previousFavorited: boolean = this.isFavorited
    const previousCount: number = this.favoriteCountFromSession
    this.favoriteStatusKnown = true
    this.isFavorited = shouldFavorite
    this.favoriteCountFromSession = shouldFavorite
      ? Math.max(0, this.favoriteCountFromSession + 1)
      : Math.max(0, this.favoriteCountFromSession - 1)
    this.publishFavoriteChrome(this.favoriteStatusKnown, this.isFavorited, true)
    const galleryId: number = this.detail.id
    try {
      const status: NhGalleryFavoriteStatus = await NhApiClient.setFavorite(galleryId, shouldFavorite)
      // The mutation is confirmed by the typed v2 response even if this
      // retained route was replaced while it was in flight. Publish before
      // route-local state checks so Favorites cannot retain a stale snapshot.
      this.favoriteMutations.publishConfirmedMutation(galleryId, status.isFavorited)
      if (this.detail.id !== galleryId || this.galleryId !== galleryId) {
        return
      }
      this.favoriteStatusKnown = status.known
      this.isFavorited = status.isFavorited
      this.favoriteCountFromSession = status.hasFavoriteCount ? status.favoriteCount : -1
      this.showFavoriteToast(status.isFavorited
        ? AppStrings.get('gallery_toast_favourite_added')
        : AppStrings.get('gallery_toast_favourite_removed'))
    } catch (error) {
      // Failed mutation: restore the pre-toggle snapshot so the UI never
      // keeps an optimistic state the server rejected.
      this.favoriteStatusKnown = previousKnown
      this.isFavorited = previousFavorited
      this.favoriteCountFromSession = previousCount
      this.showFavoriteToast(AppStrings.get('gallery_error_update_favourites'))
    } finally {
      this.isFavoriteMutationInFlight = false
      if (this.detail.id === this.galleryId) {
        this.publishFavoriteChrome(this.favoriteStatusKnown, this.isFavorited, false)
      }
    }
  }

  private showFavoriteToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_error) {}
  }

  private showShareUnavailable(): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('gallery_error_share_unavailable') })
    } catch (_error) {
      // A failed notification must not mutate gallery state or expose its link.
    }
  }

  private showExternalOpenUnavailable(): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('gallery_error_external_open_unavailable') })
    } catch (_error) {
      // A failed notification must not mutate gallery state or expose its link.
    }
  }

  private applyVerifiedDetailSnapshot(
    generation: number,
    detail: NhGalleryDetail,
    animateNetworkTitle: boolean,
  ): boolean {
    if (!this.isCurrentRequest(generation) || detail.id <= 0 || detail.id !== this.galleryId) {
      return false
    }
    const previousPrimary: string = this.galleryHeroPrimaryTitle()
    const previousSecondary: string = this.galleryHeroSecondaryTitle()
    const previousId: string = this.galleryHeroIdText()
    const previousMaxLines: number = this.galleryHeroTitleMaxLines()
    const nextPrimary: string = this.galleryHeroPrimaryTitleFor(detail)
    const nextSecondary: string = this.galleryHeroSecondaryTitleFor(detail)
    const nextId: string = this.galleryHeroIdTextFor(detail)
    const shouldTransitionTitle: boolean = animateNetworkTitle &&
      this.detail.id === this.galleryId &&
      previousPrimary.trim().length > 0 &&
      (previousPrimary !== nextPrimary || previousSecondary !== nextSecondary || previousId !== nextId)
    if (shouldTransitionTitle) {
      this.prepareHeroTitleTransition(
        previousPrimary,
        previousSecondary,
        previousId,
        previousMaxLines,
      )
    }
    // A cache snapshot intentionally contains only raw tag names. Prepare the
    // presentation owner before publishing the reactive Detail DTO; otherwise
    // a seed-less cache hit can render one raw-English frame before the pending
    // gate and asynchronous local-dictionary result arrive.
    this.tagTranslationPending = true
    const pendingTagLabels: string[] = this.pendingLabelsForDetail(detail)
    this.tagTranslationLabels = pendingTagLabels
    this.rebuildTagTranslationLabelMap(detail.tags, pendingTagLabels)
    this.detail = detail
    if (shouldTransitionTitle) {
      this.startHeroTitleTransition()
    }
    // The verified response normally carries cover dimensions; a legacy or
    // direct-route detail without them falls back to the tapped row's known
    // source size (same gallery, same cover) exactly like NextE's imgWidth/
    // imgHeight seed fallback.
    if ((this.detail.coverWidth <= 0 || this.detail.coverHeight <= 0) &&
      this.seed !== null && this.seed !== undefined && this.seed.id === this.galleryId) {
      this.detail.coverWidth = this.seed.thumbnailWidth
      this.detail.coverHeight = this.seed.thumbnailHeight
    }
    // Swap the visible cover only after the verified cover bitmap has
    // loaded, so the seed thumbnail never blanks or jumps in the hero slot.
    if (this.detail.coverUrl.length > 0 && this.detail.coverUrl !== this.displayedCoverUrl) {
      this.pendingCoverUrl = this.detail.coverUrl
    }
    this.isDetailReadyForCurrentGallery = true
    this.publishDownloadChrome()
    this.publishWideThumbnailActionAvailability()
    this.updateNavigationChromeForScroll()
    this.requestTagTranslations(generation, detail.id, detail.tags)
    return true
  }

  /** Seed labels reused for a verified detail, matched by stable tag identity. */
  private pendingLabelsForDetail(detail: NhGalleryDetail): string[] {
    const labels: string[] = []
    for (let index: number = 0; index < detail.tags.length; index++) {
      const tag: NhTag = detail.tags[index]
      const retainedLabel: string = this.tagTranslationLabelMap.get(this.tagIdentityKey(tag)) ?? ''
      labels.push(retainedLabel.trim().length > 0 ? retainedLabel.trim() : this.seedLabelForTag(tag))
    }
    return labels
  }

  private seedLabelForTag(tag: NhTag): string {
    if (this.seed === null || this.seed === undefined || this.seed.id !== this.galleryId) {
      return ''
    }
    for (let index: number = 0; index < this.seed.tags.length; index++) {
      const candidate: NhTag = this.seed.tags[index]
      if (candidate.id === tag.id && candidate.type === tag.type && candidate.name === tag.name) {
        return candidate.displayName.trim()
      }
    }
    return ''
  }

  private startDetailSupplementalLoads(generation: number, detail: NhGalleryDetail): void {
    this.loadRelatedGalleries(detail.id)
    this.loadCommentPeek(generation, detail.id)
    this.loadFavoriteStatus(generation, detail.id)
  }

  /** A cache snapshot is sufficient for the local read marker, but never for history metadata. */
  private loadCachedDetailReadProgress(generation: number, galleryId: number): void {
    this.loadReadProgress(generation, galleryId).catch((error: Error): void => {
      if (this.isCurrentRequest(generation)) {
        console.warn(`Unable to load cached local reading progress: ${error.message}`)
      }
    })
  }

  private async recordDetailOpenAndLoadProgress(generation: number, detail: NhGalleryDetail): Promise<void> {
    try {
      await HistoryRepository.recordOpen(this.context(), detail)
    } catch (error) {
      if (this.isCurrentRequest(generation)) {
        console.warn(`Unable to record local reading history: ${(error as Error).message}`)
      }
    }
    await this.loadReadProgress(generation, detail.id)
  }

  /** Paint the tapped-row snapshot immediately; the verified response upgrades it. */
  private applySeedSnapshot(generation: number, seed: NhGallerySummary): void {
    if (!this.isCurrentRequest(generation) || seed.id <= 0 || seed.id !== this.galleryId ||
      this.detail.id !== 0) {
      return
    }
    const seeded: NhGalleryDetail = new NhGalleryDetail()
    seeded.id = seed.id
    seeded.mediaId = seed.mediaId
    seeded.title = seed.englishTitle
    seeded.japaneseTitle = seed.japaneseTitle
    seeded.prettyTitle = seed.displayTitle()
    seeded.coverUrl = seed.thumbnailUrl
    seeded.thumbnailUrl = seed.thumbnailUrl
    seeded.coverWidth = seed.thumbnailWidth
    seeded.coverHeight = seed.thumbnailHeight
    seeded.pageCount = seed.pageCount
    seeded.tags = seed.tags.map((tag: NhTag): NhTag => tag.copy())
    this.detail = seeded
    this.displayedCoverUrl = seed.thumbnailUrl
    this.pendingCoverUrl = ''
    this.seedTagTranslations(seeded.tags)
    this.publishDownloadChrome()
    this.publishWideThumbnailActionAvailability()
  }

  /** Seed labels come from the tapped row's already-resolved local dictionary. */
  private seedTagTranslations(tags: NhTag[]): void {
    const labels: string[] = []
    for (let index: number = 0; index < tags.length; index++) {
      labels.push(tags[index].displayName.trim())
    }
    this.tagTranslationLabels = labels
    this.rebuildTagTranslationLabelMap(tags, labels)
    this.tagTranslationPending = false
    this.tagTranslationEpoch += 1
  }

  private async loadDetail(forceNetwork: boolean = false): Promise<void> {
    const requestedGalleryId: number = this.galleryId
    const generation: number = this.beginDetailLoad()
    if (!forceNetwork && this.seed !== null && this.seed !== undefined &&
      this.seed.id === requestedGalleryId) {
      this.applySeedSnapshot(generation, this.seed)
    }
    let cacheApplied: boolean = false
    try {
      if (forceNetwork) {
        // Explicit user refreshes deliberately bypass both app-owned snapshots
        // and the Detail endpoint's NetworkKit cache. Keep this observable
        // without logging a gallery identity or response data.
        hilog.info(DETAIL_CACHE_LOG_DOMAIN, DETAIL_CACHE_LOG_TAG, 'event=%{public}s', 'bypass=explicit-refresh')
      }
      if (!forceNetwork) {
        const recent: NhGalleryDetail | null = NhGalleryDetailCacheService.getRecent(requestedGalleryId)
        if (recent !== null && this.applyVerifiedDetailSnapshot(generation, recent, false)) {
          cacheApplied = true
          // The current workspace is ready; background revalidation must not
          // impersonate the user's explicit refresh affordance.
          this.isLoading = false
          this.publishRefreshChrome(false)
          this.startDetailSupplementalLoads(generation, recent)
          this.loadCachedDetailReadProgress(generation, recent.id)
        }
        if (!cacheApplied) {
          const persisted: NhGalleryDetail | null = await NhGalleryDetailCacheService.loadPersisted(
            this.context(),
            requestedGalleryId,
          )
          if (!this.isCurrentRequest(generation)) {
            return
          }
          if (persisted !== null && this.applyVerifiedDetailSnapshot(generation, persisted, false)) {
            cacheApplied = true
            this.isLoading = false
            this.publishRefreshChrome(false)
            this.startDetailSupplementalLoads(generation, persisted)
            this.loadCachedDetailReadProgress(generation, persisted.id)
          }
        }
      }
      const detail: NhGalleryDetail = await NhApiClient.detail(requestedGalleryId, forceNetwork)
      if (!this.isCurrentRequest(generation)) {
        return
      }
      if (detail.id <= 0 || detail.id !== requestedGalleryId || detail.id !== this.galleryId) {
        throw new Error('Gallery response did not match the requested gallery')
      }
      if (!this.applyVerifiedDetailSnapshot(generation, detail, !forceNetwork && !cacheApplied)) {
        return
      }
      if (forceNetwork) {
        // The page has accepted this user-triggered, transport-cache-bypassed
        // response for the current route. Queue the catalog promotion only
        // here, rather than in the network client, so an old route response
        // can never overwrite a newer ordinary catalog record.
        NhTagCatalogService.promoteAcceptedFreshDetailTags(detail.tags)
      }
      // The verified response is now renderable. Cache persistence is awaited
      // only for ordering/device-proof purposes; it never owns page loading.
      this.isLoading = false
      this.publishRefreshChrome(false)
      await NhGalleryDetailCacheService.save(this.context(), detail)
      if (!this.isCurrentRequest(generation)) {
        return
      }
      if (!cacheApplied) {
        this.startDetailSupplementalLoads(generation, detail)
      }
      // The fresh page list may change the valid persisted-resume clamp and
      // remains the canonical source for the local History projection.
      await this.recordDetailOpenAndLoadProgress(generation, detail)
    } catch (error) {
      if (!this.isCurrentRequest(generation)) {
        return
      }
      this.errorMessage = AppStrings.get('gallery_error_load')
    } finally {
      if (this.isCurrentRequest(generation)) {
        this.isLoading = false
        this.publishRefreshChrome(false)
      }
    }
  }

  private canOpenReader(): boolean {
    return this.isDetailReadyForCurrentGallery &&
      this.detail.id === this.galleryId &&
      this.detail.pages.length > 0
  }

  /** The compact preview header owns the one standalone all-pages route. */
  private canOpenThumbnails(): boolean {
    return this.isDetailReadyForCurrentGallery &&
      this.detail.id === this.galleryId &&
      this.detail.pages.length > 0 &&
      this.onOpenThumbnails !== undefined
  }

  /**
   * Use the same public, parsed comments client as the full destination only
   * after this exact detail has passed its id check. The request runs outside
   * the detail lifecycle, so failure is intentionally invisible and cannot
   * delay Read, tags, preview pages, or the full Comments route.
   */
  private async loadCommentPeek(detailGeneration: number, galleryId: number): Promise<void> {
    const generation: number = this.commentPeekGeneration + 1
    this.commentPeekGeneration = generation
    try {
      const comments: NhComment[] = await NhApiClient.comments(galleryId)
      if (generation !== this.commentPeekGeneration ||
        !this.isCurrentRequest(detailGeneration) ||
        !this.isDetailReadyForCurrentGallery ||
        this.galleryId !== galleryId ||
        this.detail.id !== galleryId) {
        return
      }
      this.rawCommentPeek = comments
      this.commentPeekLoadedGalleryId = galleryId
      this.commentPeekLoaded = true
      this.applyCommentPeekFilters()
    } catch (_error) {
      if (generation === this.commentPeekGeneration &&
        this.isDetailReadyForCurrentGallery &&
        this.galleryId === galleryId &&
        this.detail.id === galleryId) {
        this.commentPeekLoaded = true
      }
      // The full destination retains retry/error UI. This optional response
      // stays empty on failure, while the already-available Comments route
      // remains visible and never competes with the ready detail surface.
    }
  }

  /**
   * The user policy is deliberately not consulted here: HDS alone confirms
   * whether this destination really lives in the root Split, and this page's
   * mode-keyed width cache is the only geometry gate for the wide workspace.
   */
  private usesWideDetailWorkspace(): boolean {
    return this.layoutSafeArea.rootNavigationSplit &&
      this.detailRootWidth >= GALLERY_DETAIL_WIDE_WORKSPACE_MIN_WIDTH
  }

  private wideThumbnailActionsAvailable(): boolean {
    return this.usesWideDetailWorkspace() && this.canOpenReader() && this.onOpenReader !== undefined
  }

  /**
   * In wide mode the inline right pane, not a duplicate pushed route, owns
   * First/Jump. The entry title bar only publishes route-local intent.
   */
  private publishWideThumbnailActionAvailability(): void {
    const available: boolean = this.wideThumbnailActionsAvailable()
    if (this.chrome.wideThumbnailActionsAvailable === available) {
      return
    }
    this.chrome.wideThumbnailActionsAvailable = available
    if (this.onChromeChanged) {
      this.onChromeChanged()
    }
  }

  private readFabUsesHdsMaterial(): boolean {
    return this.readButtonStyle.style === ReadButtonStyleSettings.STYLE_HDS
  }

  private readFabAvailableWidth(): number {
    return this.detailWorkspaceWidth > 0 ? this.detailWorkspaceWidth : this.detailRootWidth
  }

  private numberFromLength(value: Length | undefined): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      const parsed: number = Number.parseFloat(value)
      return Number.isNaN(parsed) ? 0 : parsed
    }
    return 0
  }

  private readFabVisualX(): number {
    if (this.visualActionHandEdge === 'left') {
      return 0
    }
    const innerWidth: number = this.readFabAvailableWidth() - this.readFabRailSideInset() * 2
    return Math.max(0, innerWidth - this.readFabWidth)
  }

  private readFabAnimationDuration(): number {
    return this.readFabShouldAnimate ? ThemeTokens.REFRESH_ANIMATION_DURATION : 0
  }

  private updateReadFabLayoutReady(): void {
    if (this.readFabAvailableWidth() > 0 && this.readFabWidth > 0) {
      this.readFabLayoutReady = true
    }
  }

  private handleFollowTouch(event: TouchEvent): void {
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.followTouchState = ActionFollowTouchTracker.initialState()
      return
    }
    // The selected side belongs to one ordinary scroll gesture only. A second
    // finger or an incomplete touch sequence must not borrow another finger's
    // coordinates and move the floating Read action.
    if (event.touches.length !== 1) {
      this.followTouchState = ActionFollowTouchTracker.initialState()
      return
    }
    const touch: TouchObject = event.touches[0]
    const update = ActionFollowTouchTracker.update(
      this.followTouchState,
      event.type,
      touch.windowX - this.detailWorkspaceGlobalX,
      touch.y,
      FOLLOW_OPERATION_VERTICAL_SCROLL_THRESHOLD,
      FOLLOW_OPERATION_VERTICAL_DOMINANCE_RATIO,
    )
    this.followTouchState = update.state
    if (update.shouldReport) {
      MotionHandStateService.reportFollowOperationX(update.reportX, this.readFabAvailableWidth())
    }
  }

  /** NextE rail geometry: HDS owns its activity padding; Filled owns its inset. */
  private readFabRailSideInset(): number {
    return this.readFabUsesHdsMaterial() ? 0 : ThemeTokens.SPACE_LG
  }

  private readFabRailBottomInset(): number {
    return this.readFabUsesHdsMaterial() ? 0 : ThemeTokens.SPACE_LG
  }

  /** Must remain the exact NextNHdsCapsuleBarButton activity box. */
  private readFabOuterHeight(): number {
    return this.readFabUsesHdsMaterial()
      ? nextNHdsCapsuleActivityHeight(ThemeTokens.ACTION_HEIGHT, ThemeTokens.SPACE_LG)
      : ThemeTokens.ACTION_HEIGHT
  }

  /**
   * Both style branches reserve the same source-derived 78vp tail: HDS owns
   * its 46 + 2×16 activity box; Filled uses 46 + bottom 16 + terminal 16.
   */
  private readFabContentReserve(): number {
    return this.readFabOuterHeight() + this.readFabRailBottomInset() +
      (this.readFabUsesHdsMaterial() ? 0 : ThemeTokens.SPACE_LG)
  }

  /** Snapshot live progress without making persistence own covered Detail timing. */
  private syncDisplayedReadProgress(): void {
    const hasLiveProgress: boolean = this.readProgress.has(this.galleryId)
    this.displayedHasReadProgress = hasLiveProgress || this.hasReadProgress
    this.displayedResumePageIndex = hasLiveProgress
      ? this.clampResumePageIndex(this.readProgress.index(this.galleryId))
      : this.clampResumePageIndex(this.resumePageIndex)
  }

  @Monitor('readProgress.revision')
  private onReadProgressChanged(): void {
    if (!this.readerOverlay.visible) {
      this.syncDisplayedReadProgress()
    }
  }

  @Monitor('readerOverlay.closing')
  private onReaderOverlayClosingChanged(): void {
    if (this.readerOverlay.closing) {
      this.syncDisplayedReadProgress()
    }
  }

  private readFabMaterialBarWidth(): number {
    const pageIndex: number = this.displayedResumePageIndex
    if (pageIndex <= 0) {
      return 86
    }
    return Math.min(172, 104 + (pageIndex + 1).toString().length * 8)
  }

  private readActionLabel(): string {
    const pageCount: number = this.localResumePageCount()
    const pageIndex: number = this.displayedResumePageIndex
    // A saved marker at page zero means the reader was opened but never
    // advanced: resuming there is the same as starting from the beginning,
    // so the label stays 阅读/Read instead of an impossible 继续 P1.
    if (!this.displayedHasReadProgress || pageCount <= 0 || pageIndex <= 0) {
      return AppStrings.get('gallery_action_read')
    }
    return AppStrings.format('gallery_action_continue_page', [
      (pageIndex + 1).toString(),
    ])
  }

  private canOpenComments(): boolean {
    return this.isDetailReadyForCurrentGallery && this.detail.id === this.galleryId
  }

  private commentPreviewItems(): NhComment[] {
    // The compact rail has a fixed height. A server record can be structurally
    // valid yet contain no body; keep it reachable from the full Comments
    // route, but do not mount a visually empty preview card.
    return this.commentPeek.filter((comment: NhComment): boolean => comment.body.trim().length > 0)
  }

  /** The full Comments route is useful even while its optional peek is empty. */
  private shouldShowCommentPreview(): boolean {
    return this.detail.id === this.galleryId
  }

  private shouldShowRelatedGalleries(): boolean {
    return this.isDetailReadyForCurrentGallery &&
      this.detail.id === this.galleryId &&
      this.relatedGalleries.length > 0
  }

  /** Reserve the related rail while its optional request is still pending. */
  private shouldShowRelatedGalleriesLoading(): boolean {
    return this.detail.id === this.galleryId && !this.relatedLoaded
  }

  private galleryPageCountText(): string {
    return this.detail.pageCount > 0
      ? AppStrings.format('gallery_meta_pages', [this.detail.pageCount.toString()])
      : ''
  }

  private galleryFavoriteCountText(): string {
    const count: number = this.favoriteCountFromSession >= 0
      ? this.favoriteCountFromSession
      : this.detail.favoriteCount
    return count > 0 ? count.toString() : ''
  }

  /** The v2 detail has no separate language field; its language tag is authoritative. */
  private galleryLanguageText(): string {
    for (let index: number = 0; index < this.detail.tags.length; index++) {
      const tag: NhTag = this.detail.tags[index]
      const type: string = tag.type.trim().toLowerCase()
      if (type === 'language' || type === 'languages') {
        return tag.name.trim()
      }
    }
    return ''
  }

  /** Preserve the API timestamp as a compact, locale-neutral metadata cell. */
  private galleryUploadDateText(): string {
    if (this.detail.uploadDate <= 0) {
      return ''
    }
    const date: Date = new Date(this.detail.uploadDate * 1000)
    if (isNaN(date.getTime())) {
      return ''
    }
    const month: string = `${date.getMonth() + 1}`.padStart(2, '0')
    const day: string = `${date.getDate()}`.padStart(2, '0')
    return `${date.getFullYear()}-${month}-${day}`
  }

  private openTagSearch(tag: NhTag): void {
    const query: string = NhTagQuery.format(tag)
    if (query.length > 0 && this.onSearchQuery) {
      this.onSearchQuery(query)
    }
  }

  private triggerTagLongPressHaptic(): void {
    try {
      if (vibrator.isHdHapticSupported()) {
        vibrator.startVibration({
          type: 'preset',
          effectId: 'haptic.effect.soft',
          count: 1,
          intensity: TAG_INFO_HAPTIC_INTENSITY,
        }, { usage: 'physicalFeedback' })
      } else {
        vibrator.startVibration({
          type: 'time',
          duration: TAG_INFO_HAPTIC_FALLBACK_DURATION,
        }, { usage: 'physicalFeedback' })
      }
    } catch (_error) {}
  }

  private openTagInfo(item: GalleryTagVisualItem): void {
    const selected: NhTag = new NhTag()
    selected.id = item.tag.id
    selected.type = item.tag.type
    selected.name = item.tag.name
    selected.count = item.tag.count
    this.selectedTag = selected
    const translated: string = this.tagMemberTranslatedLabel(item).trim()
    if (translated.length > 0 && translated !== selected.name) {
      const prefix: string = NhTagSuggestionDisplay.namespaceLabel(selected.type)
      this.selectedTagDisplay = prefix.length > 0 ? `${prefix}:${translated}` : translated
    } else {
      this.selectedTagDisplay = selected.name
    }
    this.tagInfoName = ''
    this.tagInfoIntro = ''
    this.tagInfoLinks = ''
    this.tagInfoImages = []
    this.tagInfoError = ''
    const epoch: number = this.tagInfoEpoch + 1
    this.tagInfoEpoch = epoch
    this.triggerTagLongPressHaptic()
    this.tagInfoSheetShown = true
    this.loadTagInfo(epoch)
  }

  private async loadTagInfo(epoch: number): Promise<void> {
    this.tagInfoLoading = true
    this.tagInfoError = ''
    try {
      const info: NhTagTranslationInfo | null = await TagTranslationInfoService.lookupTagInfo(
        this.getUIContext().getHostContext() as common.UIAbilityContext,
        this.selectedTag.type,
        this.selectedTag.name,
        this.tagTranslationSettings.introImageLevel,
      )
      if (epoch !== this.tagInfoEpoch) {
        return
      }
      if (info !== null) {
        this.tagInfoName = info.displayName
        this.tagInfoIntro = info.intro
        this.tagInfoLinks = info.links
        this.tagInfoImages = info.images
      }
    } catch (error) {
      if (epoch === this.tagInfoEpoch) {
        this.tagInfoError = (error as Error).message
      }
    } finally {
      if (epoch === this.tagInfoEpoch) {
        this.tagInfoLoading = false
      }
    }
  }

  private selectedTagIdentity(): string {
    return this.selectedTag.type.trim().length > 0
      ? `${this.selectedTag.type}:${this.selectedTag.name}`
      : this.selectedTag.name
  }

  private selectedLocalTagRecord(): NhLocalUserTag | null {
    const revision: number = this.localUserTags.revision
    const records: NhLocalUserTag[] = NhLocalUserTagService.activeTags()
    if (revision < 0) {
      return null
    }
    for (let index: number = 0; index < records.length; index++) {
      if (records[index].tagId === this.selectedTag.id) {
        return records[index]
      }
    }
    return null
  }

  private selectedTagIsHidden(): boolean {
    const record: NhLocalUserTag | null = this.selectedLocalTagRecord()
    return record !== null && record.hidden
  }

  private queueSelectedTagSave(record: NhLocalUserTag): void {
    this.pendingTagEditorSave = record
  }

  private queueSelectedTagDelete(tagId: number): void {
    this.pendingTagEditorDeleteId = tagId
  }

  private async commitSelectedTagEditorMutation(): Promise<void> {
    const pendingSave: NhLocalUserTag | null = this.pendingTagEditorSave
    const pendingDeleteId: number = this.pendingTagEditorDeleteId
    this.pendingTagEditorSave = null
    this.pendingTagEditorDeleteId = 0
    try {
      if (pendingSave !== null) {
        await NhLocalUserTagService.save(this.context(), pendingSave)
      } else if (pendingDeleteId > 0) {
        await NhLocalUserTagService.remove(this.context(), pendingDeleteId)
      }
    } catch (_error) {
      try {
        this.getUIContext().getPromptAction().showToast({
          message: pendingDeleteId > 0
            ? AppStrings.get('local_user_tag_delete_failed')
            : AppStrings.get('local_user_tag_save_failed'),
        })
      } catch (_promptError) {}
    }
  }

  private async toggleSelectedTagHidden(): Promise<void> {
    if (this.tagHiddenMutationInFlight || this.selectedTag.id <= 0) {
      return
    }
    const current: NhLocalUserTag | null = this.selectedLocalTagRecord()
    const record: NhLocalUserTag = current !== null ? current.copy() : new NhLocalUserTag()
    if (current === null) {
      record.tagId = this.selectedTag.id
      record.namespaceSnapshot = this.selectedTag.type
      record.nameSnapshot = this.selectedTag.name
    }
    record.hidden = !this.selectedTagIsHidden()
    this.tagHiddenMutationInFlight = true
    try {
      await NhLocalUserTagService.save(this.context(), record)
      this.toast(AppStrings.get(record.hidden ? 'gallery_tag_hidden' : 'gallery_tag_unhidden'))
    } catch (_error) {
      this.toast(AppStrings.get('local_user_tag_save_failed'))
    } finally {
      this.tagHiddenMutationInFlight = false
    }
  }

  private requestTagTranslations(generation: number, galleryId: number, tags: NhTag[]): void {
    const epoch: number = this.tagTranslationEpoch + 1
    this.tagTranslationEpoch = epoch
    this.tagTranslationPending = true
    this.loadTagTranslations(generation, galleryId, tags, epoch)
  }

  private async loadTagTranslations(
    generation: number,
    galleryId: number,
    tags: NhTag[],
    epoch: number,
  ): Promise<void> {
    try {
      const translations: Map<string, string> = await TagTranslationRepository.lookup(this.context(), tags)
      if (!this.isCurrentRequest(generation) || epoch !== this.tagTranslationEpoch ||
        this.galleryId !== galleryId || this.detail.id !== galleryId) {
        return
      }
      const labels: string[] = []
      let translatedCount: number = 0
      for (let index: number = 0; index < tags.length; index++) {
        const translated: string | undefined = translations.get(TagTranslationRepository.keyFor(tags[index]))
        const label: string = translated === undefined ? '' : translated
        if (label.length > 0) {
          translatedCount += 1
        }
        labels.push(label)
      }
      this.tagTranslationLabels = labels
      this.rebuildTagTranslationLabelMap(tags, labels)
      // The first cold-start render of a gallery already ran with epoch N and
      // empty labels, so group/member ForEach keys are unchanged when the
      // async lookup completes. Advance the epoch with the resolved labels so
      // ArkUI rebuilds the rows instead of reusing the empty-label objects.
      this.tagTranslationEpoch += 1
      this.tagTranslationPending = false
      console.info(`NextNTagDictionary galleryMatched=${translatedCount} galleryTags=${tags.length}`)
    } catch (_error) {
      // The optional local dictionary must never delay Gallery metadata or
      // replace the raw tag with an error when it is absent or unavailable.
      this.tagTranslationPending = false
    }
  }

  /**
   * This deliberately remains outside the detail request lifecycle: a slow or
   * failed related response must never delay, invalidate, or retry metadata,
   * Read, comments, or any paginated source list.
   */
  private async loadRelatedGalleries(galleryId: number): Promise<void> {
    const generation: number = this.relatedRequestGeneration + 1
    this.relatedRequestGeneration = generation
    try {
      const related: NhGallerySummary[] = await NhApiClient.related(galleryId)
      if (!this.isCurrentRelatedRequest(generation) ||
        !this.isDetailReadyForCurrentGallery ||
        this.galleryId !== galleryId ||
        this.detail.id !== galleryId) {
        return
      }
      this.rawRelatedGalleries = this.uniqueRelatedGalleries(related, galleryId)
      this.relatedLoaded = true
      this.applyRelatedContentFilters()
    } catch (error) {
      if (this.isCurrentRelatedRequest(generation)) {
        this.relatedLoaded = true
        console.warn(`Unable to load related galleries: ${(error as Error).message}`)
      }
    }
  }

  private uniqueRelatedGalleries(galleries: NhGallerySummary[], sourceGalleryId: number): NhGallerySummary[] {
    const unique: NhGallerySummary[] = []
    galleries.forEach((gallery: NhGallerySummary): void => {
      if (gallery.id <= 0 || gallery.id === sourceGalleryId ||
        unique.some((existing: NhGallerySummary): boolean => existing.id === gallery.id)) {
        return
      }
      unique.push(gallery)
    })
    return unique
  }

  private tagSearchLabel(tag: NhTag): string {
    return `${tag.type}: ${tag.name}`
  }

  private isSearchableTag(tag: NhTag): boolean {
    return NhTagQuery.format(tag).length > 0
  }

  private tagIdentityKey(tag: NhTag): string {
    return tag.id + '_' + tag.type + '_' + tag.name
  }

  /**
   * Detail tags keep the tapped-row seed order when a same-gallery seed
   * exists. The list endpoint's tag_ids order differs from the detail
   * response's tags order, so without this the verified detail re-sorts the
   * visible tag groups the moment it replaces the seed frame. Detail-only
   * tags append at the end in their API order; direct routes without a seed
   * keep the detail order unchanged.
   */
  private presentationTagIndices(): number[] {
    const indices: number[] = []
    for (let index: number = 0; index < this.detail.tags.length; index++) {
      indices.push(index)
    }
    const seedOrder: Map<string, number> = new Map()
    if (this.seed !== null && this.seed !== undefined && this.seed.id === this.galleryId) {
      for (let index: number = 0; index < this.seed.tags.length; index++) {
        const key: string = this.tagIdentityKey(this.seed.tags[index])
        if (!seedOrder.has(key)) {
          seedOrder.set(key, index)
        }
      }
    }
    if (seedOrder.size === 0) {
      return indices
    }
    indices.sort((left: number, right: number): number => {
      const leftKey: string = this.tagIdentityKey(this.detail.tags[left])
      const rightKey: string = this.tagIdentityKey(this.detail.tags[right])
      const leftOrder: number | undefined = seedOrder.get(leftKey)
      const rightOrder: number | undefined = seedOrder.get(rightKey)
      const leftRank: number = leftOrder === undefined ? Number.MAX_SAFE_INTEGER : leftOrder
      const rightRank: number = rightOrder === undefined ? Number.MAX_SAFE_INTEGER : rightOrder
      if (leftRank !== rightRank) {
        return leftRank - rightRank
      }
      return left - right
    })
    return indices
  }

  private tagVisualGroups(labels: string[]): GalleryTagVisualGroup[] {
    const groups: GalleryTagVisualGroup[] = []
    const presentationIndices: number[] = this.presentationTagIndices()
    for (let position: number = 0; position < presentationIndices.length; position++) {
      const index: number = presentationIndices[position]
      const tag: NhTag = this.detail.tags[index]
      const namespace: string = tag.type.trim().length > 0 ? tag.type.trim() : AppStrings.get('gallery_tag_fallback')
      const translatedName: string = index < labels.length
        ? labels[index]
        : ''
      let group: GalleryTagVisualGroup | null = null
      for (let groupIndex: number = 0; groupIndex < groups.length; groupIndex++) {
        if (groups[groupIndex].namespace === namespace) {
          group = groups[groupIndex]
          break
        }
      }
      if (group === null) {
        group = new GalleryTagVisualGroup(namespace)
        groups.push(group)
      }
      group.items.push(new GalleryTagVisualItem(tag, index, translatedName))
    }
    return groups
  }

  private tagMemberLabel(item: GalleryTagVisualItem): string {
    // Resolve by tag identity, never by array position: the label array
    // changes basis between seed (list order) and verified detail (API
    // order), and stable group keys intentionally reuse group components
    // whose captured items still carry the previous basis' originalIndex.
    // Identity lookup returns each chip its own translation under every
    // reorder, re-seed, and async dictionary arrival.
    const liveLabel: string = this.tagTranslationLabelMap.get(this.tagIdentityKey(item.tag)) ??
      item.translatedName
    return this.tagTranslationSettings.enabled &&
      this.browsePresentation.showTranslatedTagLabels && liveLabel.length > 0
      ? liveLabel
      : item.tag.name
  }

  /** Pending visibility must inspect translation availability, not the display fallback to raw English. */
  private tagMemberTranslatedLabel(item: GalleryTagVisualItem): string {
    return this.tagTranslationLabelMap.get(this.tagIdentityKey(item.tag)) ?? item.translatedName
  }

  private rebuildTagTranslationLabelMap(tags: NhTag[], labels: string[]): void {
    const map: Map<string, string> = new Map()
    const count: number = Math.min(tags.length, labels.length)
    for (let index: number = 0; index < count; index++) {
      map.set(this.tagIdentityKey(tags[index]), labels[index])
    }
    this.tagTranslationLabelMap = map
  }

  /** Mirrors ErosN's localized namespace header without changing raw tag members. */
  private tagNamespacePresentation(namespace: string): GalleryTagNamespacePresentation {
    const normalized: string = namespace.trim().toLowerCase()
    let label: string = namespace
    switch (normalized) {
      case 'parody':
      case 'parodies':
        label = AppStrings.get('gallery_tag_namespace_parodies')
        return new GalleryTagNamespacePresentation(
          label,
          ThemeTokens.TEXT_PRIMARY,
          $r('app.color.tagns_parody'),
        )
      case 'character':
      case 'characters':
        label = AppStrings.get('gallery_tag_namespace_characters')
        return new GalleryTagNamespacePresentation(
          label,
          ThemeTokens.TEXT_PRIMARY,
          $r('app.color.tagns_character'),
        )
      case 'tag':
      case 'tags':
        label = AppStrings.get('gallery_tag_namespace_tags')
        break
      case 'artist':
      case 'artists':
        label = AppStrings.get('gallery_tag_namespace_artists')
        return new GalleryTagNamespacePresentation(
          label,
          ThemeTokens.TEXT_PRIMARY,
          $r('app.color.tagns_artist'),
        )
      case 'group':
      case 'groups':
        label = AppStrings.get('gallery_tag_namespace_groups')
        return new GalleryTagNamespacePresentation(
          label,
          ThemeTokens.TEXT_PRIMARY,
          $r('app.color.tagns_group'),
        )
      case 'language':
      case 'languages':
        label = AppStrings.get('gallery_tag_namespace_languages')
        return new GalleryTagNamespacePresentation(
          label,
          ThemeTokens.TEXT_PRIMARY,
          $r('app.color.tagns_language'),
        )
      case 'category':
      case 'categories':
        label = AppStrings.get('gallery_tag_namespace_categories')
        break
    }
    // NH's tag/category namespaces have no equivalent NextE namespace swatch,
    // so retain the neutral header rather than inventing a brand-color meaning.
    return new GalleryTagNamespacePresentation(label, ThemeTokens.TEXT_PRIMARY, ThemeTokens.SURFACE_SUB)
  }

  private tagGroupKey(group: GalleryTagVisualGroup): string {
    // Stable identity only. Index and item-count in the key made any pending
    // translation resolution change the key, so ArkUI tore down and re-added
    // the whole row (one-frame card collapse, preview sliding up into the
    // middle). Translation content changes rebuild members, never the row.
    return group.namespace
  }

  private tagMemberKey(item: GalleryTagVisualItem): string {
    // Stable identity + rendered label. originalIndex is positional and must
    // not participate in component identity.
    return `${item.tag.id}_${item.tag.type}_${item.tag.name}_${item.translatedName}`
  }

  private tagNamespaceLabel(namespace: string): string {
    return this.tagNamespacePresentation(namespace).label
  }

  private tagNamespaceForeground(namespace: string): ResourceColor {
    return this.tagNamespacePresentation(namespace).foreground
  }

  private tagNamespaceBackground(namespace: string): ResourceColor {
    return this.tagNamespacePresentation(namespace).background
  }

  @Builder
  private GalleryMetaItem(icon: Resource, value: string) {
    Row({ space: ThemeTokens.SPACE_XS }) {
      SymbolGlyph(icon)
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor([ThemeTokens.TEXT_TERTIARY])
      Text(value)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('50%')
    .padding({ top: ThemeTokens.SPACE_XS, bottom: ThemeTokens.SPACE_XS })
    .alignItems(VerticalAlign.Center)
  }

  /** Metadata with no stable peer owns a complete row. */
  @Builder
  private GalleryMetaFullRow(icon: Resource, value: string) {
    Row({ space: ThemeTokens.SPACE_XS }) {
      SymbolGlyph(icon)
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor([ThemeTokens.TEXT_TERTIARY])
      Text(value)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: ThemeTokens.SPACE_XS, bottom: ThemeTokens.SPACE_XS })
    .alignItems(VerticalAlign.Center)
  }

  /** Same-geometry metadata row used only while the verified detail is pending. */
  @Builder
  private GalleryMetaLoadingRow() {
    Row({ space: ThemeTokens.SPACE_XS }) {
      LoadingProgress()
        .width(ThemeTokens.FONT_SIZE_CAPTION)
        .height(ThemeTokens.FONT_SIZE_CAPTION)
        .color(ThemeTokens.BRAND)
      Text(AppStrings.get('common_loading'))
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: ThemeTokens.SPACE_XS, bottom: ThemeTokens.SPACE_XS })
    .alignItems(VerticalAlign.Center)
  }

  /** Compact in-card action chip, matching NextE's sub-background capsule family. */
  @Builder
  private GalleryActionChip(icon: Resource, label: string, enabled: boolean, action: () => void) {
    Button({ type: ButtonType.Capsule }) {
      Row({ space: ThemeTokens.DETAIL_ACTION_CHIP_GAP }) {
        SymbolGlyph(icon)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor([enabled ? ThemeTokens.BRAND : ThemeTokens.TEXT_SECONDARY])
        Text(label)
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(enabled ? ThemeTokens.BRAND : ThemeTokens.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(ThemeTokens.DETAIL_ACTION_CHIP_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .padding({ left: ThemeTokens.SPACE_SM, right: ThemeTokens.SPACE_MD })
    }
    .width('100%')
    .height(ThemeTokens.DETAIL_ACTION_CHIP_HEIGHT)
    .backgroundColor(ThemeTokens.SURFACE_SUB)
    .enabled(enabled)
    .onClick(action)
  }

  /**
   * Stateful download chip mirrors NextE's zero-argument DownloadActionChip:
   * a multi-argument @Builder freezes by-value parameters at first render
   * (ArkUI does not rebuild multi-argument builder calls), which left the
   * seed-frame disabled state stuck after the verified detail arrived.
   * Reading page state inside this builder keeps enabled/label live.
   */
  @Builder
  private DownloadActionChip() {
    Button({ type: ButtonType.Capsule }) {
      Row({ space: ThemeTokens.DETAIL_ACTION_CHIP_GAP }) {
        SymbolGlyph($r('sys.symbol.arrow_down_to_line'))
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor([this.downloadChipEnabled() ? ThemeTokens.BRAND : ThemeTokens.TEXT_SECONDARY])
        Text(this.downloadActionTitle())
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.downloadChipEnabled() ? ThemeTokens.BRAND : ThemeTokens.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(ThemeTokens.DETAIL_ACTION_CHIP_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .padding({ left: ThemeTokens.SPACE_SM, right: ThemeTokens.SPACE_MD })
    }
    .width('100%')
    .height(ThemeTokens.DETAIL_ACTION_CHIP_HEIGHT)
    .backgroundColor(ThemeTokens.SURFACE_SUB)
    .enabled(this.downloadChipEnabled())
    .onClick((): void => {
      this.handleDownloadAction()
    })
  }

  /** Detail metadata is a peer information block, not hero-card decoration. */
  @Builder
  private GalleryInformation() {
    if (this.detail.id === this.galleryId) {
      Row({ space: ThemeTokens.SPACE_MD }) {
        Column() {
          NextNGroupedListSection({ inset: ThemeTokens.SPACE_MD }) {
            Flex({ wrap: FlexWrap.Wrap }) {
              if (this.galleryLanguageText().length > 0) {
                this.GalleryMetaItem($r('sys.symbol.translate'), this.galleryLanguageText())
              }
              if (this.galleryPageCountText().length > 0) {
                this.GalleryMetaItem($r('sys.symbol.picture'), this.galleryPageCountText())
              }
              if (this.detail.scanlator.length > 0) {
                this.GalleryMetaFullRow($r('sys.symbol.person'), this.detail.scanlator)
              }
              if (this.galleryFavoriteCountText().length > 0) {
                this.GalleryMetaItem($r('sys.symbol.heart'), this.galleryFavoriteCountText())
              }
              if (!this.isDetailReadyForCurrentGallery) {
                this.GalleryMetaLoadingRow()
              }
              if (this.galleryUploadDateText().length > 0) {
                this.GalleryMetaItem($r('sys.symbol.clock'), this.galleryUploadDateText())
              }
            }
            .width('100%')
          }
        }
        .layoutWeight(1)

        Column({ space: ThemeTokens.DETAIL_ACTION_CHIP_STACK_GAP }) {
          this.DownloadActionChip()
          this.GalleryActionChip(
            $r('sys.symbol.link'),
            AppStrings.get('action_torrent'),
            this.detail.id === this.galleryId,
            (): void => {
              this.requestTorrentFileExport()
            },
          )
        }
        .width(ThemeTokens.DETAIL_ACTION_CARD_WIDTH)
        .constraintSize({ minHeight: ThemeTokens.DETAIL_ACTION_CARD_MIN_HEIGHT })
        .alignSelf(ItemAlign.Stretch)
        .justifyContent(FlexAlign.SpaceBetween)
        .padding(ThemeTokens.DETAIL_ACTION_CARD_PADDING)
        .backgroundColor(ThemeTokens.CARD_BACKGROUND)
        .borderRadius(ThemeTokens.DETAIL_ACTION_CARD_RADIUS)
        .clip(true)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  /** Mirrors NextE's EhThumbnail containFit slot: real cover proportion, no grey letterbox. */
  private heroCoverHasSourceSize(): boolean {
    return this.detail.coverWidth > 0 && this.detail.coverHeight > 0
  }

  private heroCoverFitByHeight(): boolean {
    if (!this.heroCoverHasSourceSize()) {
      return false
    }
    return this.detail.coverHeight / this.detail.coverWidth >
      ThemeTokens.DETAIL_COVER_HEIGHT / ThemeTokens.DETAIL_COVER_WIDTH
  }

  private heroCoverFittedWidth(): number {
    if (!this.heroCoverHasSourceSize()) {
      return ThemeTokens.DETAIL_COVER_WIDTH
    }
    if (this.heroCoverFitByHeight()) {
      return (ThemeTokens.DETAIL_COVER_HEIGHT * this.detail.coverWidth) / this.detail.coverHeight
    }
    return ThemeTokens.DETAIL_COVER_WIDTH
  }

  private heroCoverFittedHeight(): number {
    if (!this.heroCoverHasSourceSize()) {
      return ThemeTokens.DETAIL_COVER_HEIGHT
    }
    if (this.heroCoverFitByHeight()) {
      return ThemeTokens.DETAIL_COVER_HEIGHT
    }
    return (ThemeTokens.DETAIL_COVER_WIDTH * this.detail.coverHeight) / this.detail.coverWidth
  }

  private resetHeroTitleTransition(): void {
    this.heroTitleTransitionEpoch += 1
    this.heroTitleOutgoingPrimary = ''
    this.heroTitleOutgoingSecondary = ''
    this.heroTitleOutgoingId = ''
    this.heroTitleOutgoingMaxLines = 1
    this.heroTitleTransitionProgress = 1
    this.heroTitleTransitionActive = false
  }

  private prepareHeroTitleTransition(
    primary: string,
    secondary: string,
    idText: string,
    maxLines: number,
  ): void {
    this.heroTitleTransitionEpoch += 1
    this.heroTitleOutgoingPrimary = primary
    this.heroTitleOutgoingSecondary = secondary
    this.heroTitleOutgoingId = idText
    this.heroTitleOutgoingMaxLines = maxLines
    this.heroTitleTransitionProgress = 0
    this.heroTitleTransitionActive = true
  }

  private startHeroTitleTransition(): void {
    const epoch: number = this.heroTitleTransitionEpoch
    // Commit the two-layer start frame before changing opacity. ArkUI cannot
    // interpolate Text content itself; only these stable layers are animated.
    setTimeout((): void => {
      if (epoch !== this.heroTitleTransitionEpoch || !this.heroTitleTransitionActive) {
        return
      }
      this.getUIContext().animateTo({
        duration: ThemeTokens.ANIM_DURATION,
        curve: Curve.EaseOut,
        onFinish: (): void => {
          if (epoch !== this.heroTitleTransitionEpoch) {
            return
          }
          this.heroTitleOutgoingPrimary = ''
          this.heroTitleOutgoingSecondary = ''
          this.heroTitleOutgoingId = ''
          this.heroTitleOutgoingMaxLines = 1
          this.heroTitleTransitionActive = false
        },
      }, (): void => {
        this.heroTitleTransitionProgress = 1
      })
    }, 0)
  }

  @Builder
  private GalleryHero() {
    NextNGroupedListSection({ inset: ThemeTokens.SPACE_MD }) {
      Row({ space: ThemeTokens.SPACE_MD }) {
        Stack({ alignContent: Alignment.Center }) {
          Stack({ alignContent: Alignment.Center }) {
            if (this.displayedCoverUrl.length > 0 && this.coverFailedUrl !== this.displayedCoverUrl) {
              EhImageKnifeImage({
                src: this.displayedCoverUrl,
                widthValue: '100%',
                heightValue: '100%',
                objectFit: this.heroCoverHasSourceSize() ? ImageFit.Fill : ImageFit.Contain,
                radius: ThemeTokens.DETAIL_COVER_RADIUS,
                priority: EH_IMAGE_PRIORITY_LOW,
                onError: (): void => {
                  this.coverFailedUrl = this.displayedCoverUrl
                },
              })
            } else {
              SymbolGlyph($r('sys.symbol.picture'))
                .fontSize(32)
                .fontColor([ThemeTokens.TEXT_TERTIARY])
            }
          }
          .width(this.heroCoverFittedWidth())
          .height(this.heroCoverFittedHeight())
          .backgroundColor(
            this.heroCoverHasSourceSize() ? Color.Transparent : ThemeTokens.COVER_PLACEHOLDER,
          )
          .borderRadius(ThemeTokens.DETAIL_COVER_RADIUS)
          .clip(true)
          // Measure and mask the actual visible contain-fit surface, not its fixed 112x160 layout slot.
          // A wide source therefore flies directly to its final aspect without landing and then jumping.
          .id(this.detailTransitionCoverId())
          .opacity(this.detailCoverMasked() ? 0 : 1)
          if (this.pendingCoverUrl.length > 0 && this.pendingCoverUrl !== this.displayedCoverUrl) {
            EhImageKnifeImage({
              src: this.pendingCoverUrl,
              widthValue: 1,
              heightValue: 1,
              objectFit: ImageFit.Fill,
              priority: EH_IMAGE_PRIORITY_LOW,
              onComplete: (): void => {
                const ready: string = this.pendingCoverUrl
                if (ready.length > 0 && ready !== this.displayedCoverUrl) {
                  this.displayedCoverUrl = ready
                  this.pendingCoverUrl = ''
                }
              },
              onError: (): void => {
                // Keep the seed thumbnail; a failed verified cover is
                // retried by the normal error path on a later route.
                this.pendingCoverUrl = ''
              },
            })
              .width(1)
              .height(1)
              .opacity(0)
          }
        }
        .width(ThemeTokens.DETAIL_COVER_WIDTH)
        .height(ThemeTokens.DETAIL_COVER_HEIGHT)
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.heroTitleTransitionActive) {
            Column({ space: ThemeTokens.SPACE_XS }) {
              Text(this.heroTitleOutgoingPrimary)
                .fontSize(ThemeTokens.FONT_SIZE_TITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeTokens.TEXT_PRIMARY)
                .lineHeight(ThemeTokens.LINE_HEIGHT_TITLE)
                .maxLines(this.heroTitleOutgoingMaxLines)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              if (this.heroTitleOutgoingSecondary.length > 0) {
                Text(this.heroTitleOutgoingSecondary)
                  .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                  .fontColor(ThemeTokens.TEXT_SECONDARY)
                  .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
              if (this.heroTitleOutgoingId.length > 0) {
                Text(this.heroTitleOutgoingId)
                  .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                  .fontColor(ThemeTokens.TEXT_TERTIARY)
                  .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
            }
            .width('100%')
            .height(ThemeTokens.DETAIL_COVER_HEIGHT)
            .clip(true)
            .alignItems(HorizontalAlign.Start)
            .opacity(1 - this.heroTitleTransitionProgress)
            .hitTestBehavior(HitTestMode.None)
          }
          Column({ space: ThemeTokens.SPACE_XS }) {
            Text(this.galleryHeroPrimaryTitle())
              .fontSize(ThemeTokens.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeTokens.TEXT_PRIMARY)
              .lineHeight(ThemeTokens.LINE_HEIGHT_TITLE)
              .maxLines(this.galleryHeroTitleMaxLines())
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .onClick((): void => {
                this.openFullTitleSheet()
              })
            if (this.galleryHeroSecondaryTitle().length > 0) {
              Text(this.galleryHeroSecondaryTitle())
                .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                .fontColor(ThemeTokens.TEXT_SECONDARY)
                .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .onClick((): void => {
                  this.openFullTitleSheet()
                })
            }
            if (this.galleryHeroIdText().length > 0) {
              Text(this.galleryHeroIdText())
                .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                .fontColor(ThemeTokens.TEXT_TERTIARY)
                .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
            }
          }
          .width('100%')
          .height(ThemeTokens.DETAIL_COVER_HEIGHT)
          .clip(true)
          .alignItems(HorizontalAlign.Start)
          .opacity(this.heroTitleTransitionActive ? this.heroTitleTransitionProgress : 1)
        }
        .layoutWeight(1)
        .height(ThemeTokens.DETAIL_COVER_HEIGHT)
        .clip(true)
        .bindSheet($$this.fullTitleSheetShown, this.FullTitleSheet(), appSheetOptions({
          detents: [SheetSize.LARGE],
          showClose: false,
        }))
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  /** Direct NextE header-line budget: secondary text keeps its two lines. */
  private galleryHeroPrimaryTitleFor(detail: NhGalleryDetail): string {
    if (this.galleryTitle.japaneseTitlePrimary && detail.japaneseTitle.length > 0) {
      return detail.japaneseTitle
    }
    return detail.displayTitle()
  }

  private galleryHeroPrimaryTitle(): string {
    return this.galleryHeroPrimaryTitleFor(this.detail)
  }

  private galleryHeroSecondaryTitleFor(detail: NhGalleryDetail): string {
    const standard: string = detail.displayTitle()
    const japanese: string = detail.japaneseTitle
    if (this.galleryTitle.japaneseTitlePrimary) {
      return japanese.length > 0 && japanese !== standard ? standard : ''
    }
    return japanese.length > 0 && japanese !== standard ? japanese : ''
  }

  private galleryHeroSecondaryTitle(): string {
    return this.galleryHeroSecondaryTitleFor(this.detail)
  }

  private galleryHeroIdTextFor(detail: NhGalleryDetail): string {
    return detail.id === this.galleryId && detail.id > 0
      ? `#${detail.id.toString()}`
      : ''
  }

  private galleryHeroIdText(): string {
    return this.galleryHeroIdTextFor(this.detail)
  }

  private galleryHeroTitleMaxLinesFor(secondaryTitle: string, idText: string): number {
    const hasSecondary: boolean = secondaryTitle.length > 0
    const secondaryReserve: number = hasSecondary
      ? 2 * ThemeTokens.LINE_HEIGHT_BODY + ThemeTokens.SPACE_XS
      : 0
    const idReserve: number = idText.length > 0
      ? ThemeTokens.LINE_HEIGHT_BODY + ThemeTokens.SPACE_XS
      : 0
    const available: number = ThemeTokens.DETAIL_COVER_HEIGHT - secondaryReserve - idReserve
    const lines: number = Math.floor(available / ThemeTokens.LINE_HEIGHT_TITLE)
    return Math.min(Math.max(lines, 1), 6)
  }

  private galleryHeroTitleMaxLines(): number {
    return this.galleryHeroTitleMaxLinesFor(
      this.galleryHeroSecondaryTitle(),
      this.galleryHeroIdText(),
    )
  }

  /**
   * Long hero titles are ellipsized to protect the fixed cover slot. Their
   * disclosure is deliberately local: only a validated detail for this route
   * may open it, and it neither refreshes nor changes gallery data.
   */
  private openFullTitleSheet(): void {
    if (!this.isDetailReadyForCurrentGallery || this.detail.id !== this.galleryId ||
      this.galleryHeroPrimaryTitle().trim().length === 0) {
      return
    }
    this.fullTitleSheetShown = true
  }

  private closeFullTitleSheet(): void {
    this.fullTitleSheetShown = false
  }

  private englishFullTitle(): string {
    return this.detail.title.trim().length > 0 ? this.detail.title.trim() : this.detail.displayTitle().trim()
  }

  private japaneseFullTitle(): string {
    const title: string = this.detail.japaneseTitle.trim()
    return title !== this.englishFullTitle() ? title : ''
  }

  private titleSourceForKind(kind: string): string {
    return kind === TITLE_TRANSLATION_JAPANESE ? this.japaneseFullTitle() : this.englishFullTitle()
  }

  private titleTranslationConfigured(): boolean {
    const binding = this.llmSources.commentBinding
    if (!binding.configured()) {
      return false
    }
    const profile = this.llmSources.findById(binding.sourceProfileId)
    return profile !== null && supportsCommentTranslation(profile)
  }

  private titleTranslationState(kind: string): GalleryTitleTranslationState | null {
    for (let index: number = 0; index < this.titleTranslations.length; index += 1) {
      if (this.titleTranslations[index].kind === kind) {
        return this.titleTranslations[index]
      }
    }
    return null
  }

  private ensureTitleTranslationState(kind: string, source: string): GalleryTitleTranslationState {
    const existing: GalleryTitleTranslationState | null = this.titleTranslationState(kind)
    if (existing !== null && existing.source === source) {
      return existing
    }
    const state: GalleryTitleTranslationState = new GalleryTitleTranslationState()
    state.kind = kind
    state.source = source
    const next: GalleryTitleTranslationState[] = this.titleTranslations.filter(
      (candidate: GalleryTitleTranslationState): boolean => candidate.kind !== kind,
    )
    next.push(state)
    this.titleTranslations = next
    return state
  }

  private publishTitleTranslations(): void {
    this.titleTranslations = this.titleTranslations.slice()
  }

  private titleTranslationLoading(kind: string): boolean {
    const source: string = this.titleSourceForKind(kind)
    const state: GalleryTitleTranslationState | null = this.titleTranslationState(kind)
    return state !== null && state.source === source && state.loading
  }

  private titleTranslationShown(kind: string): boolean {
    const source: string = this.titleSourceForKind(kind)
    const state: GalleryTitleTranslationState | null = this.titleTranslationState(kind)
    return state !== null && state.source === source && state.shown && state.translated.length > 0
  }

  private titleTranslationText(kind: string): string {
    const source: string = this.titleSourceForKind(kind)
    const state: GalleryTitleTranslationState | null = this.titleTranslationState(kind)
    return state !== null && state.source === source ? state.translated : ''
  }

  private canTranslateTitle(kind: string): boolean {
    return this.titleTranslationConfigured() && this.titleSourceForKind(kind).length > 0
  }

  private showTitleTranslationFailed(): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: AppStrings.get('gallery_title_translation_failed'),
      })
    } catch (_error) {}
  }

  private async toggleOrTranslateTitle(kind: string): Promise<void> {
    if (!this.canTranslateTitle(kind)) {
      return
    }
    const source: string = this.titleSourceForKind(kind)
    const state: GalleryTitleTranslationState = this.ensureTitleTranslationState(kind, source)
    if (state.loading) {
      return
    }
    if (state.translated.length > 0) {
      state.shown = !state.shown
      this.publishTitleTranslations()
      return
    }
    const epoch: number = this.titleTranslationEpoch + 1
    this.titleTranslationEpoch = epoch
    const galleryId: number = this.detail.id
    state.loading = true
    this.publishTitleTranslations()
    try {
      const translated: string = await GalleryTitleTranslationService.translate(this.context(), source)
      if (epoch === this.titleTranslationEpoch && this.detail.id === galleryId &&
        this.titleSourceForKind(kind) === source) {
        state.translated = translated.trim()
        state.shown = state.translated.length > 0
        if (!state.shown) {
          this.showTitleTranslationFailed()
        }
      }
    } catch (_error) {
      if (epoch === this.titleTranslationEpoch && this.detail.id === galleryId) {
        this.showTitleTranslationFailed()
      }
    } finally {
      if (epoch === this.titleTranslationEpoch) {
        state.loading = false
        this.publishTitleTranslations()
      }
    }
  }

  @Builder
  private TitleTranslationAction(kind: string, label: string) {
    Button({ type: ButtonType.Circle }) {
      if (this.titleTranslationLoading(kind)) {
        LoadingProgress()
          .width(TITLE_TRANSLATION_ICON_SIZE)
          .height(TITLE_TRANSLATION_ICON_SIZE)
      } else {
        SymbolGlyph($r('sys.symbol.translate'))
          .fontSize(TITLE_TRANSLATION_ICON_SIZE)
          .fontColor([
            this.titleTranslationShown(kind) ? ThemeTokens.BRAND : ThemeTokens.TEXT_TERTIARY,
          ])
      }
    }
    .width(TITLE_TRANSLATION_ACTION_SIZE)
    .height(TITLE_TRANSLATION_ACTION_SIZE)
    .backgroundColor(Color.Transparent)
    .enabled(this.canTranslateTitle(kind) && !this.titleTranslationLoading(kind))
    .accessibilityText(label)
    .onClick((): void => {
      this.toggleOrTranslateTitle(kind)
    })
  }

  @Builder
  private TitleReadBlock(label: string, source: string, kind: string, actionLabel: string) {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Row({ space: ThemeTokens.SPACE_SM }) {
        Text(label)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .layoutWeight(1)
        this.TitleTranslationAction(kind, actionLabel)
      }
      .alignItems(VerticalAlign.Center)
      .width('100%')
      Text(source)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
        .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
        .copyOption(CopyOptions.LocalDevice)
        .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
        .width('100%')
      if (this.titleTranslationShown(kind)) {
        Column({ space: ThemeTokens.SPACE_XS }) {
          Text(AppStrings.get('gallery_title_translation_result'))
            .fontSize(ThemeTokens.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .width('100%')
          Text(this.titleTranslationText(kind))
            .fontSize(ThemeTokens.FONT_SIZE_BODY)
            .fontColor(ThemeTokens.TEXT_PRIMARY)
            .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
            .copyOption(CopyOptions.LocalDevice)
            .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
            .width('100%')
        }
        .width('100%')
        .padding({ top: ThemeTokens.SPACE_SM })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * Keep the hero's preference-resolved order intact rather than exposing
   * raw model fields. The modal List provides unbounded, scrollable text for
   * titles that cannot fit inside the compact or wide header card.
   */
  @Builder
  private FullTitleSheet() {
    NextNModalScaffold({
      title: AppStrings.get('gallery_full_title'),
      onClose: (): void => {
        this.closeFullTitleSheet()
      },
    }) {
      ListItem() {
        NextNGroupedListSection({ inset: ThemeTokens.SPACE_MD }) {
          Column({ space: ThemeTokens.SPACE_SM }) {
            if (this.englishFullTitle().length > 0) {
              this.TitleReadBlock(
                AppStrings.get('gallery_title_english'),
                this.englishFullTitle(),
                TITLE_TRANSLATION_ENGLISH,
                AppStrings.get('gallery_title_translate_english'),
              )
            }
            if (this.japaneseFullTitle().length > 0) {
              if (this.englishFullTitle().length > 0) {
                Divider()
                  .strokeWidth(0.5)
                  .color(ThemeTokens.DIVIDER)
              }
              this.TitleReadBlock(
                AppStrings.get('gallery_title_japanese'),
                this.japaneseFullTitle(),
                TITLE_TRANSLATION_JAPANESE,
                AppStrings.get('gallery_title_translate_japanese'),
              )
            }
            if (this.englishFullTitle().length === 0 && this.japaneseFullTitle().length === 0) {
              Divider()
                .strokeWidth(0.5)
                .color(ThemeTokens.DIVIDER)
              Text(this.galleryHeroPrimaryTitle())
                .fontSize(ThemeTokens.FONT_SIZE_BODY)
                .fontColor(ThemeTokens.TEXT_SECONDARY)
                .lineHeight(ThemeTokens.LINE_HEIGHT_BODY)
                .width('100%')
            }
          }
          .width('100%')
        }
      }
    }
  }

  @Builder
  private TagInfoAction(icon: Resource, label: string, active: boolean, enabled: boolean, action: () => void) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(icon)
        .fontSize(ThemeTokens.FONT_SIZE_HEADING)
        .fontColor([active ? Color.Red : ThemeTokens.TEXT_SECONDARY])
    }
    .buttonStyle(ButtonStyleMode.NORMAL)
    .width(TAG_INFO_ACTION_SIZE)
    .height(TAG_INFO_ACTION_SIZE)
    .enabled(enabled)
    .accessibilityText(label)
    .onClick(action)
  }

  @Builder
  private SelectedTagEditor() {
    LocalUserTagEditorSheet({
      tag: this.selectedTag,
      allowDelete: true,
      onClose: (): void => { this.tagEditorSheetShown = false },
      onSaveRequested: (record: NhLocalUserTag): void => this.queueSelectedTagSave(record),
      onDeleteRequested: (tagId: number): void => this.queueSelectedTagDelete(tagId),
    })
  }

  private markdownBodyLines(markdown: string): string[] {
    let text: string = markdown.replace(/\r\n/g, '\n')
    text = text.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '')
    text = text.replace(/^#{1,6}\s*/gm, '')
    text = text.replace(/\*\*([^*]+)\*\*/g, '$1')
    text = text.replace(/__([^_]+)__/g, '$1')
    text = text.replace(/`([^`]+)`/g, '$1')
    text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '$1')
    text = text.replace(/[ \t]+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim()
    return text.length > 0
      ? text.split('\n').map((line: string): string => line.trim())
        .filter((line: string): boolean => line.length > 0)
      : []
  }

  private markdownLinks(markdown: string): TagInfoLinkItem[] {
    const links: TagInfoLinkItem[] = []
    const pattern: RegExp = /\[([^\]]+)\]\(([^)]+)\)/g
    let match: RegExpExecArray | null = pattern.exec(markdown)
    while (match !== null) {
      const item: TagInfoLinkItem = new TagInfoLinkItem()
      item.label = match[1].trim()
      item.url = match[2].trim()
      if (item.label.length > 0 || item.url.length > 0) {
        links.push(item)
      }
      match = pattern.exec(markdown)
    }
    if (links.length === 0 && markdown.trim().length > 0) {
      const item: TagInfoLinkItem = new TagInfoLinkItem()
      item.label = markdown.trim()
      links.push(item)
    }
    return links
  }

  private openTagInfoLink(url: string): void {
    if (url.length === 0) {
      return
    }
    const want: Want = { action: 'ohos.want.action.viewData', uri: url }
    const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    context.startAbility(want).catch((_error: Error): void => {
      this.getUIContext().getPromptAction().showToast({ message: url })
    })
  }

  private tagInfoHeaderTitle(): string {
    if (this.tagInfoName.length > 0 && this.tagInfoName !== this.selectedTag.name) {
      const prefix: string = NhTagSuggestionDisplay.namespaceLabel(this.selectedTag.type)
      return prefix.length > 0 ? `${prefix}:${this.tagInfoName}` : this.tagInfoName
    }
    return this.selectedTagDisplay.length > 0 ? this.selectedTagDisplay : this.selectedTag.name
  }

  @Builder
  private TagInfoMarkdownText(title: string, markdown: string) {
    if (this.markdownBodyLines(markdown).length > 0) {
      ListItem() {
        Column({ space: ThemeTokens.SPACE_XS }) {
          Text(title)
            .fontSize(ThemeTokens.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.TEXT_PRIMARY)
            .width('100%')
          ForEach(this.markdownBodyLines(markdown), (line: string) => {
            Text(line)
              .fontSize(ThemeTokens.FONT_SIZE_BODY)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
              .width('100%')
          }, (_line: string, index: number): string => `tag_info_line_${index}`)
        }
        .width('100%')
        .padding({ top: ThemeTokens.SPACE_SM, bottom: ThemeTokens.SPACE_SM })
      }
    }
  }

  @Builder
  private TagInfoLinks(title: string, markdown: string) {
    if (markdown.trim().length > 0) {
      ListItem() {
        Column({ space: ThemeTokens.SPACE_XS }) {
          Text(title)
            .fontSize(ThemeTokens.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.TEXT_PRIMARY)
            .width('100%')
          ForEach(this.markdownLinks(markdown), (item: TagInfoLinkItem) => {
            Column({ space: ThemeTokens.SPACE_XS }) {
              Text(item.label.length > 0 ? item.label : item.url)
                .fontSize(ThemeTokens.FONT_SIZE_BODY)
                .fontColor(item.url.length > 0 ? ThemeTokens.TEXT_LINK : ThemeTokens.TEXT_SECONDARY)
                .width('100%')
              if (item.url.length > 0 && item.url !== item.label) {
                Text(item.url)
                  .fontSize(ThemeTokens.FONT_SIZE_META)
                  .fontColor(ThemeTokens.TEXT_SECONDARY)
                  .width('100%')
              }
            }
            .width('100%')
            .onClick((): void => { this.openTagInfoLink(item.url) })
          }, (item: TagInfoLinkItem, index: number): string =>
            `tag_info_link_${index}_${item.label}_${item.url}`.replace(/[^A-Za-z0-9_]/g, '_'))
        }
        .width('100%')
        .padding({ top: ThemeTokens.SPACE_SM, bottom: ThemeTokens.SPACE_SM })
      }
    }
  }

  @Builder
  private TagInfoImageColumn(remainder: number) {
    Column({ space: ThemeTokens.SPACE_SM }) {
      ForEach(this.tagInfoImages, (url: string, index: number) => {
        if (index % 2 === remainder) {
          TagInfoIntroImage({ url: url })
        }
      }, (url: string, index: number): string =>
        `tag_info_image_${index}_${url}`.replace(/[^A-Za-z0-9_]/g, '_'))
    }
    .layoutWeight(1)
  }

  @Builder
  private TagInfoImages() {
    if (this.tagInfoImages.length > 0) {
      ListItem() {
        Row({ space: ThemeTokens.SPACE_SM }) {
          this.TagInfoImageColumn(0)
          this.TagInfoImageColumn(1)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
        .padding({ top: ThemeTokens.SPACE_SM, bottom: ThemeTokens.SPACE_SM })
      }
    }
  }

  @Builder
  private TagInfoHeader() {
    ListItem() {
      Row({ space: ThemeTokens.SPACE_MD }) {
        Column({ space: ThemeTokens.SPACE_XS }) {
          Text(this.tagInfoHeaderTitle())
            .fontSize(ThemeTokens.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.TEXT_PRIMARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(`${this.selectedTagIdentity()} · #${this.selectedTag.id}`)
            .fontSize(ThemeTokens.FONT_SIZE_META)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row({ space: ThemeTokens.SPACE_XS }) {
          this.TagInfoAction(
            $r('sys.symbol.eye_slash'),
            AppStrings.get(this.selectedTagIsHidden() ? 'gallery_tag_unhide_action' : 'gallery_tag_hide_action'),
            this.selectedTagIsHidden(),
            !this.tagHiddenMutationInFlight,
            (): void => { this.toggleSelectedTagHidden() },
          )
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.bookmark'))
              .fontSize(ThemeTokens.FONT_SIZE_HEADING)
              .fontColor([ThemeTokens.TEXT_SECONDARY])
          }
          .buttonStyle(ButtonStyleMode.NORMAL)
          .width(TAG_INFO_ACTION_SIZE)
          .height(TAG_INFO_ACTION_SIZE)
          .enabled(this.selectedTag.id > 0 && !this.tagHiddenMutationInFlight)
          .accessibilityText(AppStrings.get('gallery_tag_manage_action'))
          .onClick((): void => { this.tagEditorSheetShown = true })
          .bindSheet($$this.tagEditorSheetShown, this.SelectedTagEditor(), appSheetOptions({
            detents: [SheetSize.LARGE],
            showClose: false,
            keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE,
            onDisappear: (): void => {
              this.tagEditorSheetShown = false
              this.commitSelectedTagEditorMutation()
            },
          }))
        }
        .flexShrink(0)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ top: ThemeTokens.SPACE_SM, bottom: ThemeTokens.SPACE_SM })
    }
  }

  @Builder
  private TagInfoBody() {
    if (this.tagInfoLoading) {
      ListItem() {
        Text(AppStrings.get('common_loading'))
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .width('100%')
      }
    } else if (this.tagInfoError.length > 0) {
      ListItem() {
        Text(this.tagInfoError)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontColor(Color.Red)
          .width('100%')
      }
    } else {
      this.TagInfoMarkdownText(AppStrings.get('gallery_tag_info_intro'), this.tagInfoIntro)
      this.TagInfoLinks(AppStrings.get('gallery_tag_info_links'), this.tagInfoLinks)
      this.TagInfoImages()
      if (this.tagInfoIntro.length === 0 && this.tagInfoLinks.length === 0 && this.tagInfoImages.length === 0) {
        ListItem() {
          Text(AppStrings.get('gallery_tag_info_empty'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_TERTIARY)
            .width('100%')
        }
      }
    }
  }

  @Builder
  private TagInfoSheet() {
    NextNModalScaffold({
      title: AppStrings.get('gallery_tag_info_title'),
      showConfirmAction: false,
      closeInMenu: true,
      contentHorizontalPadding: ThemeTokens.SPACE_LG,
      contentBackgroundColor: ThemeTokens.SURFACE_SUB,
      onClose: (): void => { this.tagInfoSheetShown = false },
    }) {
      this.TagInfoHeader()
      this.TagInfoBody()
    }
  }

  @Builder
  private TagMember(item: GalleryTagVisualItem) {
    Text(this.tagMemberLabel(item))
      .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
      .lineHeight(ThemeTokens.TAG_LINE_HEIGHT)
      .fontColor(this.tagMemberForeground(item.tag))
      .backgroundColor(this.tagMemberBackground(item.tag))
      .borderRadius(ThemeTokens.TAG_RADIUS)
      .padding({
        left: ThemeTokens.SPACE_SM,
        right: ThemeTokens.SPACE_SM,
        top: ThemeTokens.TAG_PADDING_VERTICAL,
        bottom: ThemeTokens.TAG_PADDING_VERTICAL,
      })
      .margin({ right: ThemeTokens.SPACE_XS, bottom: ThemeTokens.SPACE_XS })
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      // While a translation lookup is pending, an unresolved member keeps its
      // layout slot but stays invisible instead of painting raw English that
      // is about to be replaced. Visibility.Hidden preserves geometry, so the
      // row never collapses and the preview below never jumps.
      .visibility(
        this.tagTranslationSettings.enabled &&
          this.tagTranslationPending &&
          this.browsePresentation.showTranslatedTagLabels &&
          this.tagMemberTranslatedLabel(item).length === 0
          ? Visibility.Hidden
          : Visibility.Visible
      )
      .constraintSize({ maxWidth: 180 })
      .accessibilityText(this.isSearchableTag(item.tag)
        ? AppStrings.format('gallery_tag_search_a11y', [this.tagSearchLabel(item.tag)])
        : this.tagSearchLabel(item.tag))
      .onClick((): void => {
        if (this.isSearchableTag(item.tag)) {
          this.openTagSearch(item.tag)
        }
      })
      .gesture(
        LongPressGesture({ repeat: false, duration: 500 })
          .onAction((): void => { this.openTagInfo(item) }),
      )
  }

  private tagMemberColorCode(tag: NhTag): string {
    const revision: number = this.localUserTags.revision
    return revision >= 0 ? NhLocalUserTagService.colorCode(tag.id) : ''
  }

  private tagMemberForeground(tag: NhTag): ResourceColor {
    return this.tagMemberColorCode(tag).length > 0
      ? NhLocalUserTagService.readableTextColor(tag.id)
      : ThemeTokens.TEXT_SECONDARY
  }

  private tagMemberBackground(tag: NhTag): ResourceColor {
    const colorCode: string = this.tagMemberColorCode(tag)
    return colorCode.length > 0 ? colorCode : ThemeTokens.SURFACE_SUB
  }

  @Builder
  private TagGroupRow(group: GalleryTagVisualGroup) {
    Row({ space: ThemeTokens.SPACE_SM }) {
      Text(this.tagNamespaceLabel(group.namespace))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .lineHeight(ThemeTokens.TAG_LINE_HEIGHT)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.tagNamespaceForeground(group.namespace))
        .backgroundColor(this.tagNamespaceBackground(group.namespace))
        .borderRadius(ThemeTokens.TAG_RADIUS)
        .padding({ left: 6, right: 6, top: ThemeTokens.TAG_PADDING_VERTICAL, bottom: ThemeTokens.TAG_PADDING_VERTICAL })
        .constraintSize({ minWidth: 44 })
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .flexShrink(0)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(group.items, (item: GalleryTagVisualItem): void => {
          this.TagMember(item)
        }, (item: GalleryTagVisualItem): string => this.tagMemberKey(item))
      }
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private GalleryTags() {
    NextNGroupedListSection({ inset: ThemeTokens.SPACE_MD }) {
      Column({ space: ThemeTokens.SPACE_SM }) {
        Text(AppStrings.get('gallery_section_tags'))
          .fontSize(ThemeTokens.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
        // Read the label array directly in the builder body: ForEach data
        // source expressions are not tracked as UI dependencies in ArkUI, so
        // without this read an async dictionary result never re-renders the
        // tag rows even though the state is populated.
        if (this.tagTranslationLabels.length >= 0) {
          ForEach(this.tagVisualGroups(this.tagTranslationLabels), (group: GalleryTagVisualGroup): void => {
            this.TagGroupRow(group)
          }, (group: GalleryTagVisualGroup): string => this.tagGroupKey(group))
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  /**
   * Compact detail follows ErosN's single all-thumbnails entry plus a bounded
   * horizontal first-page rail. The tiles retain their actual zero-based
   * Reader index; the section header is the sole route to all thumbnails.
   */
  private shouldShowCompactPreview(): boolean {
    return !this.usesWideDetailWorkspace() && this.canOpenThumbnails()
  }

  /** The preview slot keeps its height while page metadata is still pending. */
  private shouldShowCompactPreviewLoading(): boolean {
    return !this.usesWideDetailWorkspace() &&
      this.detail.id === this.galleryId &&
      this.detail.pages.length === 0
  }

  private compactPreviewPages(): NhGalleryPage[] {
    return this.detail.pages.slice(0, GALLERY_COMPACT_PREVIEW_LIMIT)
  }

  private compactPreviewPageKey(page: NhGalleryPage, pageIndex: number): string {
    return `compact_preview_${pageIndex}_${page.number}`
  }

  @Builder
  private CompactPreviewPeek() {
    NextNGroupedListSection({ inset: 0 }) {
      Column({ space: ThemeTokens.SPACE_SM }) {
        Row({ space: ThemeTokens.SPACE_XS }) {
          SymbolGlyph($r('sys.symbol.square_fill_grid_2x2'))
            .fontSize(ThemeTokens.FONT_SIZE_BODY)
            .fontColor([ThemeTokens.TEXT_SECONDARY])
          Text(AppStrings.get('gallery_preview'))
            .fontSize(ThemeTokens.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.TEXT_PRIMARY)
          Text(this.detail.pages.length.toString())
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_TERTIARY)
          Blank()
          Text(AppStrings.get('detail_view_all'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor([ThemeTokens.TEXT_TERTIARY])
        }
        .width('100%')
        .padding({
          left: ThemeTokens.SPACE_MD,
          top: ThemeTokens.SPACE_MD,
          right: ThemeTokens.SPACE_MD,
        })
        .alignItems(VerticalAlign.Center)
        .accessibilityText(AppStrings.format('gallery_pages_a11y', [this.detail.pages.length.toString()]))
        .onClick((): void => {
          this.openThumbnails()
        })
        List({ space: ThemeTokens.SPACE_SM }) {
          ForEach(this.compactPreviewPages(), (page: NhGalleryPage, pageIndex: number): void => {
            ListItem() {
              GalleryCompactPreviewTile({
                page: page,
                pageIndex: pageIndex,
                transitionSourceId: ReaderThumbnailTransitionCoordinator.sourceId(
                  this.readerTransitionScope,
                  pageIndex,
                ),
                onOpen: (selectedIndex: number): void => {
                  this.openReaderFromThumbnail(selectedIndex)
                },
              })
            }
            .margin({
              left: pageIndex === 0 ? ThemeTokens.SPACE_MD : 0,
              right: pageIndex === this.compactPreviewPages().length - 1 ? ThemeTokens.SPACE_MD : 0,
            })
            .onVisibleAreaChange([0.0, 1.0], (isExpanding: boolean, currentRatio: number): void => {
              const sourceId: string = ReaderThumbnailTransitionCoordinator.sourceId(
                this.readerTransitionScope,
                pageIndex,
              )
              this.readerThumbnailTransition.reportSourceVisibility(
                sourceId,
                isExpanding && currentRatio >= 0.999,
              )
            })
          }, (page: NhGalleryPage, pageIndex: number): string => this.compactPreviewPageKey(page, pageIndex))
        }
        .width('100%')
        .height(GALLERY_COMPACT_PREVIEW_IMAGE_HEIGHT + ThemeTokens.FONT_SIZE_TINY + ThemeTokens.SPACE_XS)
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ bottom: ThemeTokens.SPACE_MD })
    }
  }

  @Builder
  private CompactPreviewLoading() {
    NextNGroupedListSection({ inset: 0 }) {
      Column({ space: ThemeTokens.SPACE_SM }) {
        Row({ space: ThemeTokens.SPACE_XS }) {
          SymbolGlyph($r('sys.symbol.square_fill_grid_2x2'))
            .fontSize(ThemeTokens.FONT_SIZE_BODY)
            .fontColor([ThemeTokens.TEXT_SECONDARY])
          Text(AppStrings.get('gallery_preview'))
            .fontSize(ThemeTokens.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.TEXT_PRIMARY)
          Blank()
          LoadingProgress()
            .width(ThemeTokens.FONT_SIZE_BODY)
            .height(ThemeTokens.FONT_SIZE_BODY)
            .color(ThemeTokens.BRAND)
        }
        .width('100%')
        .padding({
          left: ThemeTokens.SPACE_MD,
          top: ThemeTokens.SPACE_MD,
          right: ThemeTokens.SPACE_MD,
        })
        .alignItems(VerticalAlign.Center)
        Column() {
          LoadingProgress()
            .width(ThemeTokens.STATE_INDICATOR_SIZE)
            .height(ThemeTokens.STATE_INDICATOR_SIZE)
            .color(ThemeTokens.BRAND)
        }
        .width('100%')
        .height(GALLERY_COMPACT_PREVIEW_IMAGE_HEIGHT + ThemeTokens.FONT_SIZE_TINY + ThemeTokens.SPACE_XS)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ bottom: ThemeTokens.SPACE_MD })
    }
  }

  @Builder
  private DetailRefreshState() {
    if (this.errorMessage.length > 0) {
      InlineRetryNotice({
        message: this.errorMessage,
        onRetry: (): void => {
          this.requestDetailRefresh()
        },
      })
    }
  }

  @Builder
  private ReadFab() {
    if (this.canOpenReader()) {
      if (!this.readFabUsesHdsMaterial()) {
        this.ReadFabFilled()
      } else {
        this.ReadFabHds()
      }
    }
  }

  @Builder
  private ReadFabFilled() {
    Button({ type: ButtonType.Capsule }) {
      Row({ space: ThemeTokens.SPACE_SM }) {
        SymbolGlyph($r('sys.symbol.doc_plaintext_fill'))
          .fontSize(ThemeTokens.FONT_SIZE_HEADING)
          .fontColor([ThemeTokens.TEXT_ON_BRAND])
        Text(this.readActionLabel())
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.TEXT_ON_BRAND)
      }
      .height(ThemeTokens.ACTION_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .height(ThemeTokens.ACTION_HEIGHT)
    .padding({ left: ThemeTokens.SPACE_LG, right: ThemeTokens.SPACE_LG })
    .backgroundColor(ThemeTokens.BRAND)
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .onClick((): void => {
      // Reader remains the only resume authority: it resolves its own
      // marker-backed local index when no explicit page was selected.
      this.openReader(-1)
    })
  }

  @Builder
  private ReadFabHds() {
    NextNHdsCapsuleBarButton({
      controller: this.readFabController,
      barWidth: this.readFabMaterialBarWidth(),
      barHeight: ThemeTokens.ACTION_HEIGHT,
      activityPadding: ThemeTokens.SPACE_LG,
      barBottomMargin: ThemeTokens.SPACE_LG,
      onButtonClick: (): void => {
        // Keep the exact same Reader-owned resume path as the filled action.
        this.openReader(-1)
      },
    }) {
      Row({ space: ThemeTokens.SPACE_SM }) {
        SymbolGlyph($r('sys.symbol.doc_plaintext_fill'))
          .fontSize(ThemeTokens.FONT_SIZE_HEADING)
          .fontColor([ThemeTokens.BRAND])
        Text(this.readActionLabel())
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeTokens.BRAND)
      }
      .width('100%')
      .height(ThemeTokens.ACTION_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .translate({ y: -ThemeTokens.SPACE_XS })
    }
  }

  /**
   * HDS Tabs needs a measured, transparent rail above the detail Scroll.
   * This preserves the capsule material's own touch target while preventing
   * the full-page Scroll from winning an overlapping hit test.
   */
  @Builder
  private ReadFabRail() {
    if (this.canOpenReader()) {
      Row() {
        // The outer rail stays transparent so its unused horizontal space
        // remains an overlay. This inner owner is deliberately default-hit:
        // it prevents an overlapped Detail leaf from receiving a Read tap.
        Row() {
          this.ReadFab()
        }
        .height(this.readFabOuterHeight())
        .hitTestBehavior(HitTestMode.Default)
        .translate({ x: this.readFabVisualX() })
        .opacity(this.readFabLayoutReady ? 1 : 0)
        .animation({ duration: this.readFabAnimationDuration(), curve: Curve.EaseOut })
        .onAreaChange((_oldArea: Area, area: Area): void => {
          this.readFabWidth = area.width as number
          this.updateReadFabLayoutReady()
        })
      }
      .width('100%')
      .height(this.readFabOuterHeight())
      .padding({
        left: this.readFabRailSideInset(),
        right: this.readFabRailSideInset(),
      })
      .justifyContent(FlexAlign.Start)
      .hitTestBehavior(HitTestMode.Transparent)
      .position({ left: 0, bottom: this.readFabRailBottomInset() })
    }
  }

  /**
   * The compact metadata surface stays one List. The wide workspace mounts
   * this exact List in its left pane, so horizontal navigation and content
   * insets remain owned by the existing root HDS destination.
   */
  @Builder
  private DetailMetadataList() {
    PullRefreshListScaffold({
      scroller: this.scroller,
      listSpace: ThemeTokens.SPACE_MD,
      bottomPadding: this.readFabContentReserve(),
      controller: this.detailRefreshController,
      onRefresh: async (): Promise<void> => {
        await this.refreshCurrentDetail()
      },
      onDidScroll: (_offset: number, _state: ScrollState): void => {
        this.updateNavigationChromeForScroll()
      },
      onScrollTouch: (event: TouchEvent): void => {
        this.handleFollowTouch(event)
      },
    }) {
      ListItem() {
        this.GalleryHero()
      }
      if (this.errorMessage.length > 0 && this.detail.id === this.galleryId) {
        ListItem() {
          this.DetailRefreshState()
        }
      }
      ListItem() {
        this.GalleryInformation()
      }
      if (this.detail.tags.length > 0) {
        ListItem() {
          this.GalleryTags()
        }
      }
      if (this.shouldShowCompactPreview()) {
        ListItem() {
          this.CompactPreviewPeek()
        }
      } else if (this.shouldShowCompactPreviewLoading()) {
        ListItem() {
          this.CompactPreviewLoading()
        }
      }
      if (this.shouldShowRelatedGalleries()) {
        ListItem() {
          GalleryRelatedCarousel({
            galleries: this.relatedGalleries,
            loading: false,
            onOpen: (galleryId: number): void => {
              this.openRelatedGallery(galleryId)
            },
          })
        }
      } else if (this.shouldShowRelatedGalleriesLoading()) {
        ListItem() {
          GalleryRelatedCarousel({
            galleries: [],
            loading: true,
            onOpen: (galleryId: number): void => {
              this.openRelatedGallery(galleryId)
            },
          })
        }
      }
      if (this.shouldShowCommentPreview()) {
        ListItem() {
          GalleryCommentPreviewCarousel({
            comments: this.commentPreviewItems(),
            loading: !this.commentPeekLoaded,
            emptyText: this.commentPeekLoaded ? AppStrings.get('comments_status_empty') : '',
            onOpen: (): void => {
              this.openComments()
            },
          })
        }
      }
    }
  }

  /**
   * Mirrors NextE's detail pull refresh without coupling the independent wide
   * preview Grid to metadata gestures. Both layouts bind the same request
   * state that drives the route-local HDS title action.
   */
  @Builder
  private DetailMetadataRefreshSurface() {
    this.DetailMetadataList()
  }

  /** The wide right pane is the same full-thumbnail owner as the HDS route. */
  @Builder
  private WidePreviewPane() {
    GalleryThumbnailGridContent({
      pages: this.detail.pages,
      chrome: this.widePreviewChrome,
      scroller: this.widePreviewScroller,
      transitionScope: this.readerTransitionScope,
      bottomPadding: this.readFabContentReserve(),
      onScrollTouch: (event: TouchEvent): void => {
        this.handleFollowTouch(event)
      },
      onOpenPage: (pageIndex: number): void => {
        this.openReaderFromThumbnail(pageIndex)
      },
    })
  }

  /**
   * Keep the existing compact Stack intact below the actual-mode/width gate.
   * The wide branch is one root workspace: two equal panes and one outer
   * full-width Read capsule rail, without a nested HDS navigation surface.
   */
  @Builder
  private DetailWorkspace() {
    Stack() {
      if (this.usesWideDetailWorkspace()) {
        Row() {
          Column() {
            this.DetailMetadataRefreshSurface()
          }
          .layoutWeight(1)
          .height('100%')
          .id('gallery-detail-metadata-pane')

          Column() {
            this.WidePreviewPane()
          }
          .layoutWeight(1)
          .height('100%')
          .id('gallery-detail-preview-pane')
        }
        .width('100%')
        .height('100%')
        .alignItems(VerticalAlign.Top)
        this.ReadFabRail()
      } else {
        this.DetailMetadataRefreshSurface()
        this.ReadFabRail()
      }
    }
    .layoutWeight(1)
    .width('100%')
    .height('100%')
    .onAreaChange((_oldArea: Area, area: Area): void => {
      this.detailWorkspaceWidth = area.width as number
      this.detailWorkspaceGlobalX = this.numberFromLength(area.globalPosition?.x)
      this.updateReadFabLayoutReady()
    })
  }

  build() {
    Column() {
      if (this.isLoading && this.detail.id === 0) {
        PageLoadingState({ text: AppStrings.get('gallery_status_loading') })
      } else if (this.errorMessage.length > 0 && this.detail.id === 0) {
        PageErrorState({
          message: this.errorMessage,
          onRetry: (): void => {
            this.requestDetailRefresh()
          },
        })
      } else {
        this.DetailWorkspace()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE)
    .bindSheet($$this.tagInfoSheetShown, this.TagInfoSheet(), appSheetOptions({
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: false,
      onDisappear: (): void => {
        this.tagInfoSheetShown = false
        this.tagEditorSheetShown = false
      },
    }))
    .onAreaChange((_oldArea: Area, area: Area): void => {
      const width: number = area.width as number
      if (this.detailRootWidth !== width) {
        this.detailRootWidth = width
      }
      this.publishWideThumbnailActionAvailability()
      LayoutSafeAreaBridge.publishGalleryDetailContentWidth(
        width,
        this.layoutSafeArea.rootNavigationSplit,
      )
    })
  }
}
