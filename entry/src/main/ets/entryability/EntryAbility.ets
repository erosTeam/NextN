import { AbilityConstant, Configuration, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { webview } from '@kit.ArkWeb'
import {
  BrowsePresentationService,
  CatalogPreferencesService,
  CoverBackgroundSettings,
  GalleryTitleSettings,
  GalleryDetailTransitionSettings,
  HomeSourcePresentationService,
  HomeSubtabSettings,
  ContentFilterService,
  DownloadQueueService,
  HomeTabSettings,
  ImmersiveMaterialSettings,
  LayoutSafeAreaBridge,
  AppStrings,
  CommentTranslationSettings,
  LanguageSettings,
  LlmSourceProfileRepository,
  MangaRenderingServiceSettings,
  NhAccountProfileService,
  NhApiClient,
  NhAccountSessionService,
  NhCookieAuthority,
  NhTagCatalogService,
  NhCloudBlacklistService,
  NhClipboardLinkService,
  ClipboardLinkBuildFlag,
  NhClipboardLinkSettings,
  ActionAlignmentSettings,
  MotionHandStateService,
  ReadButtonStyleSettings,
  requestGalleryDirectLaunch,
  requestLoginRecoveryLaunch,
  publishNhClipboardGalleryCandidate,
  ScreenOrientationSettings,
  SafeModeSettings,
  AccountListSettings,
  SearchTranslationSettings,
  SyncScheduler,
  SyncSettings,
  TagTranslationSettings,
  ReaderImageCacheSettings,
  ImagePipelineService,
  TabletLayoutSettings,
  ThemeColorSettings,
  AppColorFavoritesSettings,
  ThemeSettings,
  DiagnosticLogger,
  DiagnosticsSettings,
  connectSafeMode,
} from 'shared'

const ENTRY_PAGE: string = 'pages/Index'
const TRANSPARENT_COLOR: string = '#00FFFFFF'
const FALLBACK_TOP_AVOID: number = 40
const FALLBACK_BOTTOM_AVOID: number = 0
const DEBUG_WEB_DEVTOOLS_PORT: number = 19222
const ACCOUNT_FOREGROUND_PROBE_INTERVAL_MS: number = 5 * 60 * 1000

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null
  private safeAreaUiContext: UIContext | null = null
  private avoidAreaChangeCallback: ((data: window.AvoidAreaOptions) => void) | null = null
  private windowSizeChangeCallback: ((size: window.Size) => void) | null = null
  private keyboardHeightCallback: ((height: number) => void) | null = null
  private environmentCallbackId: number = -1
  private mainContentReady: boolean = false
  private abilityForeground: boolean = true
  private clipboardProbeInFlight: boolean = false
  private loginRecoveryRequestedAtLaunch: boolean = false
  private galleryDirectLaunchIdAtLaunch: number = 0
  private galleryDirectLaunchCommentsAtLaunch: boolean = false
  private accountRestoredAtBootstrap: boolean = false
  private accountProbeInFlight: boolean = false
  private lastAccountProbeStartedAt: number = 0

  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    this.galleryDirectLaunchIdAtLaunch = this.galleryDirectLaunchId(want)
    this.galleryDirectLaunchCommentsAtLaunch = this.galleryDirectLaunchWantsComments(want)
    const recoveryValue: Object | undefined = want.parameters?.['nextn_login_recovery']
    this.loginRecoveryRequestedAtLaunch = this.galleryDirectLaunchIdAtLaunch === 0 &&
      typeof recoveryValue === 'string' && recoveryValue === '1'
    AppStrings.init(this.context)
    DiagnosticLogger.initializePersistentSink(this.context)
    DiagnosticLogger.info('lifecycle', 'session_start', 'application created')
    ImagePipelineService.initialize(this.context)
    SyncScheduler.rememberContext(this.context)
    // Public tag-name enrichment needs the same app-private RDB context as
    // the rest of the anonymous local cache. It never opens an account route
    // or starts a network request on its own.
    NhTagCatalogService.initialize(this.context)
    // Follow NextE's application-level ArkWeb boot order. Cookie access is
    // queried by the Account route before its visible Web component attaches,
    // so initialize the engine and configure both cookie scopes before any
    // route can run that preflight.
    try {
      webview.WebviewController.initializeWebEngine()
      NhCookieAuthority.initialize()
      const activeEngine: webview.ArkWebEngineVersion =
        webview.WebviewController.getActiveWebEngineVersion()
      DiagnosticLogger.info(
        'arkweb',
        'engine_profile',
        activeEngine === webview.ArkWebEngineVersion.ARKWEB_EVERGREEN ? 'evergreen' :
          activeEngine === webview.ArkWebEngineVersion.M144 ? 'm144' :
            activeEngine === webview.ArkWebEngineVersion.M132 ? 'm132' :
              activeEngine === webview.ArkWebEngineVersion.M114 ? 'm114' : 'system_default',
      )
    } catch (_error) {}
    try {
      this.environmentCallbackId = this.context.getApplicationContext().on('environment', {
        onConfigurationUpdated: (config: Configuration): void => {
          ThemeSettings.onSystemColorModeChanged(config.colorMode)
          LanguageSettings.onSystemLanguageChanged(config.language)
        },
        onMemoryLevel: (_level: AbilityConstant.MemoryLevel): void => {},
      })
    } catch (_error) {}
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    if (this.context.applicationInfo.debug || this.context.applicationInfo.appProvisionType === 'debug') {
      try {
        webview.WebviewController.setWebDebuggingAccess(true, DEBUG_WEB_DEVTOOLS_PORT)
      } catch (_error) {}
    }
    let mainWindow: window.Window | null = null
    try {
      mainWindow = windowStage.getMainWindowSync()
      mainWindow.setWindowLayoutFullScreen(true)
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: TRANSPARENT_COLOR,
        navigationBarColor: TRANSPARENT_COLOR,
      })
      this.mainWindow = mainWindow
      ScreenOrientationSettings.bindWindowOrientationApplier((mode: string): void => {
        this.applyWindowOrientation(mode)
      })
      this.watchMainWindowMetrics(mainWindow)
    } catch (_error) {
      LayoutSafeAreaBridge.publishInsets(FALLBACK_TOP_AVOID, FALLBACK_BOTTOM_AVOID)
    }

    Promise.all([
      DiagnosticsSettings.restore(this.context),
      // Publish the persisted presentation signal before the first component
      // mounts. The platform color-mode call itself remains below
      // `loadContent`, which is the lifecycle point required by ArkUI.
      ThemeSettings.restore(this.context, false),
      // Restore the build-only restricted shell before any retained Browse
      // source or external route can mount.
      SafeModeSettings.restore(this.context),
      // Accent selection changes only app tokens, so it is safe to publish
      // before the first component mounts.
      ThemeColorSettings.restore(this.context),
      // Favorites are independent picker data; restoring them never changes
      // the active accent or any system/default selection.
      AppColorFavoritesSettings.restore(this.context),
      LanguageSettings.restore(this.context),
      // Restore the HDS title and floating-tab material before either surface
      // first renders; unsupported devices still resolve ADAPTIVE at use time.
      ImmersiveMaterialSettings.restore(this.context),
      // Restore the large-screen policy before the adaptive root HDS shell
      // mounts. HDS still resolves the physical Stack/Split mode itself.
      TabletLayoutSettings.restore(this.context),
      // This is separate from the split-layout policy: it applies the
      // persisted system-managed orientation to the main window.
      ScreenOrientationSettings.restore(this.context),
      // Keep the NextE root-tab visibility preference live before the HDS
      // tabs attach, so the first scroll does not use a stale default.
      HomeTabSettings.restore(this.context),
      // Restore the optional NextE-style letterbox treatment before gallery
      // cards first mount. It is an appearance preference only.
      CoverBackgroundSettings.restore(this.context),
      // Detail title ordering is restored before a Gallery destination can
      // render. It only reorders fields already included in the v2 response.
      GalleryTitleSettings.restore(this.context),
      GalleryDetailTransitionSettings.restore(this.context),
      ReadButtonStyleSettings.restore(this.context),
      ActionAlignmentSettings.restore(this.context),
      NhClipboardLinkSettings.restore(this.context),
      this.restoreAccountIdentity(),
      ContentFilterService.restore(this.context),
      NhCloudBlacklistService.restore(this.context),
      BrowsePresentationService.restore(this.context),
      // Latest and Popular match NextE's active-profile semantics: each may
      // pin a local renderer or explicitly fall back to the global Browse mode.
      HomeSourcePresentationService.restore(this.context),
      // Browse Latest and Search keep independent local defaults. Restore
      // them before either retained catalog surface can start its first GET.
      CatalogPreferencesService.restore(this.context),
      // Metadata and consumer bindings are safe to restore before Reader
      // routes mount; API keys remain in the separate HUKS vault.
      LlmSourceProfileRepository.restore(this.context),
      // Keep the optional self-hosted renderer's non-secret invalidation state
      // live before a retained Reader can project a translated page.
      MangaRenderingServiceSettings.restore(this.context),
      // Restore the comment-translation policy and the tag-dictionary
      // preference/status summary before their settings surfaces mount.
      CommentTranslationSettings.restore(this.context),
      TagTranslationSettings.restore(this.context),
      SearchTranslationSettings.restore(this.context),
      ReaderImageCacheSettings.restore(this.context),
      SyncSettings.restore(this.context),
      AccountListSettings.load(this.context),
      // Resume only the durable, user-created private queue. Any process-killed
      // active task is restored as paused by the service before a user resumes it.
      // Keep the final startup outcome available to the retained Downloads
      // tab. A failed bootstrap still rejects this Promise as before; the page
      // merely must not turn its first appearance into a hidden second retry.
      DownloadQueueService.restoreAtBootstrap(this.context),
    ]).finally((): Promise<void> => {
      // The unified SubTab store migrates Latest/Popular presentation from
      // the legacy fixed-source settings. Keep that one-time read ordered
      // after the legacy restore while still publishing it before Home mounts.
      return HomeSubtabSettings.restore(this.context)
    }).finally((): void => {
      // Resolve the persisted Read-action alignment before the first Detail
      // destination can mount. Unsupported sensing falls back inside the
      // service; it never blocks app startup or Reader routing.
      SyncScheduler.rememberContext(this.context)
      SyncScheduler.requestAfterForeground(this.context, 'startup')
      if (this.abilityForeground) {
        MotionHandStateService.start()
      }
      if (this.loginRecoveryRequestedAtLaunch &&
        !this.accountRestoredAtBootstrap &&
        !connectSafeMode().restricted()) {
        requestLoginRecoveryLaunch()
      }
      windowStage.loadContent(ENTRY_PAGE, (error): void => {
        if (error.code) {
          console.error(`NextN failed to load ${ENTRY_PAGE}: ${JSON.stringify(error)}`)
          return
        }
        // Official ApplicationContext.setColorMode requires both the window
        // and its UIAbility page to be loaded. Restore the durable choice at
        // this first valid lifecycle point instead of swallowing a startup
        // exception before loadContent.
        ThemeSettings.restore(this.context).catch((): void => {})
        this.mainContentReady = true
        this.probeRestoredAccountSession()
        this.dispatchColdGalleryDirectLaunchIfPending()
        this.probeClipboardLinkIfReady()
        try {
          const contentWindow: window.Window = mainWindow ?? windowStage.getMainWindowSync()
          const uiContext: UIContext = contentWindow.getUIContext()
          this.mainWindow = contentWindow
          this.safeAreaUiContext = uiContext
          this.watchMainWindowMetrics(contentWindow)
          this.refreshSafeAreaInsets(contentWindow, uiContext)
          this.watchSafeAreaInsets(contentWindow, uiContext)
          this.watchKeyboardHeight(contentWindow, uiContext)
        } catch (_error) {
          LayoutSafeAreaBridge.publishInsets(FALLBACK_TOP_AVOID, FALLBACK_BOTTOM_AVOID)
        }
      })
    })
  }

  /** Restore a display-only profile only after its sealed session is live. */
  private async restoreAccountIdentity(): Promise<void> {
    let restored: boolean = false
    try {
      restored = await NhAccountSessionService.restoreAtBootstrap(this.context)
    } finally {
      this.accountRestoredAtBootstrap = restored
      // This is the sole startup owner of durable account-session recovery.
      // Pages consume its published result and never invoke restore themselves.
      NhAccountSessionService.publishBootstrapState()
    }
    if (restored || NhAccountSessionService.hasRetainedAccount()) {
      await NhAccountProfileService.restore(this.context)
    }
  }

  private applyWindowOrientation(mode: string): void {
    if (this.mainWindow === null) {
      return
    }
    const orientation: window.Orientation =
      mode === ScreenOrientationSettings.MODE_AUTO_ROTATION_UNSPECIFIED
        ? window.Orientation.AUTO_ROTATION_UNSPECIFIED
        : window.Orientation.UNSPECIFIED
    this.mainWindow.setPreferredOrientation(orientation).catch((): void => {})
  }

  onDestroy(): void {
    DiagnosticLogger.info('lifecycle', 'session_end', 'application destroyed')
    DiagnosticLogger.closePersistentSink()
    MotionHandStateService.stop()
    if (this.environmentCallbackId >= 0) {
      try {
        this.context.getApplicationContext().off('environment', this.environmentCallbackId).catch((): void => {})
      } catch (_error) {}
    }
    this.environmentCallbackId = -1
    if (this.mainWindow !== null) {
      try {
        if (this.avoidAreaChangeCallback !== null) {
          this.mainWindow.off('avoidAreaChange', this.avoidAreaChangeCallback)
        }
        if (this.windowSizeChangeCallback !== null) {
          this.mainWindow.off('windowSizeChange', this.windowSizeChangeCallback)
        }
        if (this.keyboardHeightCallback !== null) {
          this.mainWindow.off('keyboardHeightChange', this.keyboardHeightCallback)
        }
      } catch (_error) {}
    }
    this.mainWindow = null
    this.safeAreaUiContext = null
    this.avoidAreaChangeCallback = null
    this.windowSizeChangeCallback = null
    this.keyboardHeightCallback = null
  }

  onForeground(): void {
    this.abilityForeground = true
    ImagePipelineService.reloadOnForeground()
    SyncScheduler.rememberContext(this.context)
    SyncScheduler.requestAfterForeground(this.context, 'foreground')
    if (this.mainContentReady) {
      MotionHandStateService.start()
      this.probeRestoredAccountSession()
    }
    this.probeClipboardLinkIfReady()
  }

  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    if (connectSafeMode().restricted()) {
      return
    }
    const recoveryValue: Object | undefined = want.parameters?.['nextn_login_recovery']
    if (typeof recoveryValue === 'string' && recoveryValue === '1') {
      requestLoginRecoveryLaunch()
      return
    }
    const galleryId: number = this.galleryDirectLaunchId(want)
    if (galleryId <= 0) {
      return
    }
    if (this.mainContentReady) {
      requestGalleryDirectLaunch(galleryId, this.galleryDirectLaunchWantsComments(want))
      return
    }
    this.galleryDirectLaunchIdAtLaunch = galleryId
    this.galleryDirectLaunchCommentsAtLaunch = this.galleryDirectLaunchWantsComments(want)
  }

  onBackground(): void {
    this.abilityForeground = false
    ImagePipelineService.clearOnBackground()
    MotionHandStateService.stop()
  }

  /**
   * A restored account must not wait for a favourite mutation to discover an
   * expired access token. Probe once after cold start and after a sufficiently
   * separated foreground transition; the unified session client owns refresh,
   * terminal state and the root HDS notice.
   */
  private probeRestoredAccountSession(): void {
    if (this.accountProbeInFlight || !NhAccountSessionService.isAuthenticated()) {
      return
    }
    const now: number = Date.now()
    if (now - this.lastAccountProbeStartedAt < ACCOUNT_FOREGROUND_PROBE_INTERVAL_MS) {
      return
    }
    this.accountProbeInFlight = true
    this.lastAccountProbeStartedAt = now
    NhApiClient.validateRestoredAccountSession()
      .finally((): void => {
        this.accountProbeInFlight = false
      })
  }

  private galleryDirectLaunchId(want: Want): number {
    const value: Object | undefined = want.parameters?.['nextn_gallery_id']
    if (typeof value === 'number' && Number.isSafeInteger(value) && value > 0) {
      return value
    }
    // The public route has no query/action variants. Keep URI parsing exact so
    // a broad custom scheme cannot become an unintended navigation surface.
    const uri: string | undefined = want.uri
    if (typeof uri !== 'string') {
      return 0
    }
    const match: RegExpExecArray | null = /^nextn:\/\/gallery\/([1-9][0-9]*)$/.exec(uri)
    if (match === null) {
      return 0
    }
    const galleryId: number = Number(match[1])
    return Number.isSafeInteger(galleryId) && galleryId > 0 ? galleryId : 0
  }

  private galleryDirectLaunchWantsComments(want: Want): boolean {
    const value: Object | undefined = want.parameters?.['nextn_gallery_destination']
    return typeof value === 'string' && value === 'comments'
  }

  /** Publishes the one-shot cold Want only after the root content exists. */
  private dispatchColdGalleryDirectLaunchIfPending(): void {
    const galleryId: number = this.galleryDirectLaunchIdAtLaunch
    if (galleryId <= 0) {
      return
    }
    const openComments: boolean = this.galleryDirectLaunchCommentsAtLaunch
    this.galleryDirectLaunchIdAtLaunch = 0
    this.galleryDirectLaunchCommentsAtLaunch = false
    if (connectSafeMode().restricted()) {
      return
    }
    requestGalleryDirectLaunch(galleryId, openComments)
  }

  private probeClipboardLinkIfReady(): void {
    if (!ClipboardLinkBuildFlag.CLIPBOARD_LINK_BUILD_ENABLED || connectSafeMode().restricted()) {
      return
    }
    if (!this.mainContentReady || !this.abilityForeground || this.clipboardProbeInFlight) {
      return
    }
    this.clipboardProbeInFlight = true
    NhClipboardLinkService.probe(this.context)
      .then((galleryId: number): void => {
        if (galleryId > 0 && this.abilityForeground) {
          publishNhClipboardGalleryCandidate(galleryId)
        }
      })
      .finally((): void => {
        this.clipboardProbeInFlight = false
      })
  }

  /**
   * Snapshot the initial geometry and keep it current through rotation,
   * fold/unfold, and multi-window resizing.  The Window API requires this
   * listener to run on the main thread; UIAbility lifecycle callbacks do.
   */
  private publishMainWindowMetrics(win: window.Window): void {
    try {
      const rect = win.getWindowProperties().windowRect
      LayoutSafeAreaBridge.publishMainWindowSizePx(rect.width, rect.height)
    } catch (_error) {}
  }

  private watchMainWindowMetrics(win: window.Window): void {
    this.publishMainWindowMetrics(win)
    if (this.windowSizeChangeCallback !== null) {
      return
    }
    this.windowSizeChangeCallback = (size: window.Size): void => {
      LayoutSafeAreaBridge.publishMainWindowSizePx(size.width, size.height)
      // A fold/unfold, rotation, or multi-window resize invalidates the old
      // gallery collection and GalleryDetail pane widths. Their next visible
      // measurements repopulate the caches under the new window geometry.
      LayoutSafeAreaBridge.publishGalleryContentWidth(0)
      LayoutSafeAreaBridge.invalidateGalleryDetailContentWidths()
      if (this.safeAreaUiContext !== null) {
        this.refreshSafeAreaInsets(win, this.safeAreaUiContext)
      }
    }
    try {
      win.on('windowSizeChange', this.windowSizeChangeCallback)
    } catch (_error) {
      this.windowSizeChangeCallback = null
    }
  }

  private refreshSafeAreaInsets(win: window.Window, uiContext: UIContext): void {
    const top: number = Math.max(
      this.topHeight(win, uiContext, window.AvoidAreaType.TYPE_SYSTEM),
      this.topHeight(win, uiContext, window.AvoidAreaType.TYPE_CUTOUT),
    )
    const bottom: number = Math.max(
      this.bottomHeight(win, uiContext, window.AvoidAreaType.TYPE_SYSTEM),
      this.bottomHeight(win, uiContext, window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR),
      this.bottomHeight(win, uiContext, window.AvoidAreaType.TYPE_SYSTEM_GESTURE),
    )
    LayoutSafeAreaBridge.publishInsets(top, bottom)
  }

  private topHeight(win: window.Window, uiContext: UIContext, type: window.AvoidAreaType): number {
    try {
      return uiContext.px2vp(win.getWindowAvoidArea(type).topRect.height)
    } catch (_error) {
      return 0
    }
  }

  private bottomHeight(win: window.Window, uiContext: UIContext, type: window.AvoidAreaType): number {
    try {
      return uiContext.px2vp(win.getWindowAvoidArea(type).bottomRect.height)
    } catch (_error) {
      return 0
    }
  }

  private watchSafeAreaInsets(win: window.Window, uiContext: UIContext): void {
    this.avoidAreaChangeCallback = (_data: window.AvoidAreaOptions): void => {
      this.refreshSafeAreaInsets(win, uiContext)
    }
    try {
      win.on('avoidAreaChange', this.avoidAreaChangeCallback)
    } catch (_error) {
      this.avoidAreaChangeCallback = null
    }
  }

  private watchKeyboardHeight(win: window.Window, uiContext: UIContext): void {
    if (this.keyboardHeightCallback !== null) {
      return
    }
    this.keyboardHeightCallback = (height: number): void => {
      LayoutSafeAreaBridge.publishKeyboardHeight(uiContext.px2vp(Math.max(0, height)))
    }
    try {
      win.on('keyboardHeightChange', this.keyboardHeightCallback)
    } catch (_error) {
      this.keyboardHeightCallback = null
    }
  }
}
