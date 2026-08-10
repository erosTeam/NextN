import { AbilityConstant, Configuration, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { webview } from '@kit.ArkWeb'
import {
  BrowsePresentationService,
  CatalogPreferencesService,
  CoverBackgroundSettings,
  GalleryTitleSettings,
  HomeSourcePresentationService,
  ContentFilterService,
  DownloadQueueService,
  HomeTabSettings,
  ImmersiveMaterialSettings,
  LayoutSafeAreaBridge,
  AppStrings,
  LanguageSettings,
  NhAccountProfileService,
  NhAccountSessionService,
  NhClipboardLinkService,
  NhClipboardLinkSettings,
  ReadButtonStyleSettings,
  requestGalleryDirectLaunch,
  requestLoginRecoveryLaunch,
  publishNhClipboardGalleryCandidate,
  TabletLayoutSettings,
  ThemeSettings,
} from 'shared'

const ENTRY_PAGE: string = 'pages/Index'
const TRANSPARENT_COLOR: string = '#00FFFFFF'
const FALLBACK_TOP_AVOID: number = 40
const FALLBACK_BOTTOM_AVOID: number = 0

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null
  private safeAreaUiContext: UIContext | null = null
  private avoidAreaChangeCallback: ((data: window.AvoidAreaOptions) => void) | null = null
  private windowSizeChangeCallback: ((size: window.Size) => void) | null = null
  private environmentCallbackId: number = -1
  private mainContentReady: boolean = false
  private abilityForeground: boolean = true
  private clipboardProbeInFlight: boolean = false
  private loginRecoveryRequestedAtLaunch: boolean = false
  private galleryDirectLaunchIdAtLaunch: number = 0
  private galleryDirectLaunchCommentsAtLaunch: boolean = false
  private accountRestoredAtBootstrap: boolean = false

  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    this.galleryDirectLaunchIdAtLaunch = this.galleryDirectLaunchId(want)
    this.galleryDirectLaunchCommentsAtLaunch = this.galleryDirectLaunchWantsComments(want)
    const recoveryValue: Object | undefined = want.parameters?.['nextn_login_recovery']
    this.loginRecoveryRequestedAtLaunch = this.galleryDirectLaunchIdAtLaunch === 0 &&
      typeof recoveryValue === 'string' && recoveryValue === '1'
    AppStrings.init(this.context)
    // Follow NextE's application-level ArkWeb boot order. Cookie access is
    // queried by the Account route before its visible Web component attaches,
    // so initialize the engine and configure both cookie scopes before any
    // route can run that preflight.
    try {
      webview.WebviewController.initializeWebEngine()
      webview.WebCookieManager.putAcceptCookieEnabled(true)
      webview.WebCookieManager.putAcceptThirdPartyCookieEnabled(true)
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
        webview.WebviewController.setWebDebuggingAccess(true)
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
      this.watchMainWindowMetrics(mainWindow)
    } catch (_error) {
      LayoutSafeAreaBridge.publishInsets(FALLBACK_TOP_AVOID, FALLBACK_BOTTOM_AVOID)
    }

    Promise.all([
      // Publish the persisted presentation signal before the first component
      // mounts. The platform color-mode call itself remains below
      // `loadContent`, which is the lifecycle point required by ArkUI.
      ThemeSettings.restore(this.context, false),
      LanguageSettings.restore(this.context),
      // Restore the HDS title and floating-tab material before either surface
      // first renders; unsupported devices still resolve ADAPTIVE at use time.
      ImmersiveMaterialSettings.restore(this.context),
      // Restore the large-screen policy before the adaptive root HDS shell
      // mounts. HDS still resolves the physical Stack/Split mode itself.
      TabletLayoutSettings.restore(this.context),
      // Keep the NextE root-tab visibility preference live before the HDS
      // tabs attach, so the first scroll does not use a stale default.
      HomeTabSettings.restore(this.context),
      // Restore the optional NextE-style letterbox treatment before gallery
      // cards first mount. It is an appearance preference only.
      CoverBackgroundSettings.restore(this.context),
      // Detail title ordering is restored before a Gallery destination can
      // render. It only reorders fields already included in the v2 response.
      GalleryTitleSettings.restore(this.context),
      ReadButtonStyleSettings.restore(this.context),
      NhClipboardLinkSettings.restore(this.context),
      this.restoreAccountIdentity(),
      ContentFilterService.restore(this.context),
      BrowsePresentationService.restore(this.context),
      // Latest and Popular match NextE's active-profile semantics: each may
      // pin a local renderer or explicitly fall back to the global Browse mode.
      HomeSourcePresentationService.restore(this.context),
      // Browse Latest and Search keep independent local defaults. Restore
      // them before either retained catalog surface can start its first GET.
      CatalogPreferencesService.restore(this.context),
      // Resume only the durable, user-created private queue. Any process-killed
      // active task is restored as paused by the service before a user resumes it.
      DownloadQueueService.restore(this.context),
    ]).finally((): void => {
      if (this.loginRecoveryRequestedAtLaunch && !this.accountRestoredAtBootstrap) {
        requestLoginRecoveryLaunch()
      }
      if (this.galleryDirectLaunchIdAtLaunch > 0) {
        requestGalleryDirectLaunch(this.galleryDirectLaunchIdAtLaunch, this.galleryDirectLaunchCommentsAtLaunch)
        this.galleryDirectLaunchIdAtLaunch = 0
        this.galleryDirectLaunchCommentsAtLaunch = false
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
        this.probeClipboardLinkIfReady()
        try {
          const contentWindow: window.Window = mainWindow ?? windowStage.getMainWindowSync()
          const uiContext: UIContext = contentWindow.getUIContext()
          this.mainWindow = contentWindow
          this.safeAreaUiContext = uiContext
          this.watchMainWindowMetrics(contentWindow)
          this.refreshSafeAreaInsets(contentWindow, uiContext)
          this.watchSafeAreaInsets(contentWindow, uiContext)
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
    if (restored) {
      await NhAccountProfileService.restore(this.context)
    }
  }

  onDestroy(): void {
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
      } catch (_error) {}
    }
    this.mainWindow = null
    this.safeAreaUiContext = null
    this.avoidAreaChangeCallback = null
    this.windowSizeChangeCallback = null
  }

  onForeground(): void {
    this.abilityForeground = true
    this.probeClipboardLinkIfReady()
  }

  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
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
  }

  private galleryDirectLaunchId(want: Want): number {
    const value: Object | undefined = want.parameters?.['nextn_gallery_id']
    return typeof value === 'number' && Number.isSafeInteger(value) && value > 0 ? value : 0
  }

  private galleryDirectLaunchWantsComments(want: Want): boolean {
    const value: Object | undefined = want.parameters?.['nextn_gallery_destination']
    return typeof value === 'string' && value === 'comments'
  }

  private probeClipboardLinkIfReady(): void {
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
      // GalleryDetail pane width. The next visible measurement repopulates
      // the cache under the current resolved root HDS mode.
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
}
