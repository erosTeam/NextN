import { common } from '@kit.AbilityKit'
import { webview } from '@kit.ArkWeb'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  AccountListSettings,
  NhAccountSessionService,
  NhAccountProfileService,
  NhArkWebSessionTransport,
  NhApiClient,
  AppStrings,
  NhBrowserSessionBoundary,
  NhBrowserSessionPhase,
  NhBrowserSessionStatus,
  NhBrowserSessionVerificationOutcome,
  LayoutSafeAreaState,
  NextNGroupedListSection,
  NextNListRow,
  SecondaryListScaffold,
  ThemeTokens,
  AccountSessionState,
  AccountProfileState,
  connectAccountSession,
  connectAccountProfile,
  connectLayoutSafeArea,
} from 'shared'

const SESSION_CAPTURE_INTERVAL_MS: number = 1000
const ACCOUNT_LOG_DOMAIN: number = 0x0000
const ACCOUNT_LOG_TAG: string = 'NextNAccount'

/**
 * A visible, exact-origin ArkWeb account session. Its UI state never contains
 * browser data; the service handles the encrypted native transport boundary.
 */
@ComponentV2
export struct BrowserSessionPage {
  /** One-shot internal cold-start recovery route; ordinary Account visits stay native. */
  @Param autoOpenVisibleLogin: boolean = false
  @Local sessionStatus: NhBrowserSessionStatus = new NhBrowserSessionStatus()
  @Local isBrowserRequested: boolean = false
  @Local isControllerAttached: boolean = false
  @Local isSigningOut: boolean = false
  @Local accountActionError: string = ''
  @Local accountSession: AccountSessionState = connectAccountSession()
  @Local accountProfile: AccountProfileState = connectAccountProfile()
  // Match NextE's dedicated login Web host: the only native overlay is an
  // activity indicator while ArkWeb is navigating. It neither alters nor
  // observes the login form or managed challenge.
  @Local isPageLoading: boolean = true
  private sessionCaptureTimerId: number = -1
  private sessionCaptureInFlight: boolean = false
  private hasObservedTrustedLoginRedirect: boolean = false
  // This is the exact UA supplied to ArkWeb before the login navigation. It
  // stays out of reactive UI state and is transferred only into the encrypted
  // native session if the visible first-party login actually succeeds.
  private browserSessionUserAgent: string = ''
  private appliedAccountSessionRevision: number = -1
  private autoOpenVisibleLoginConsumed: boolean = false
  private scroller: Scroller = new Scroller()
  private layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  private controller: webview.WebviewController = new webview.WebviewController()

  aboutToAppear(): void {
    this.applyPublishedAccountSession(true)
    this.consumeAutoOpenVisibleLogin()
  }

  @Monitor('accountSession.revision')
  onAccountSessionChanged(): void {
    this.applyPublishedAccountSession()
    this.consumeAutoOpenVisibleLogin()
  }

  aboutToDisappear(): void {
    // The visible regular Web surface may retain its own first-party storage.
    // No browser data is kept in this page's UI state.
    this.isBrowserRequested = false
    this.isControllerAttached = false
    this.isPageLoading = true
    this.browserSessionUserAgent = ''
    this.hasObservedTrustedLoginRedirect = false
    this.stopSessionCaptureTimer()
    NhAccountSessionService.revokeExplicitVisibleLoginAction()
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhAccountSessionService.resetRejectedVisibleBrowserSessionCandidate()
    // A candidate probe can have already reloaded the retained transport
    // host. On route exit it must not leave that host ready under a discarded
    // candidate UA; an existing sealed account will bootstrap its own UA on
    // the next fixed-origin request.
    NhArkWebSessionTransport.resetForVisibleSessionCandidate()
  }

  private hostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private refreshBrowserStatus(): void {
    this.sessionStatus = NhBrowserSessionBoundary.preflight()
  }

  private applyPublishedAccountSession(force: boolean = false): void {
    const revision: number = this.accountSession.revision
    if (!force && revision === this.appliedAccountSessionRevision) {
      return
    }
    this.appliedAccountSessionRevision = revision
    if (!this.accountSession.initialized) {
      // Entry owns the sole durable restore. Do not open or replace a visible
      // login surface while that startup state is still unresolved.
      this.sessionStatus = NhBrowserSessionBoundary.blockedNavigation()
      return
    }
    if (this.accountSession.signedIn) {
      this.stopSessionCaptureTimer()
      this.sessionCaptureInFlight = false
      this.isBrowserRequested = false
      this.isControllerAttached = false
      this.isPageLoading = false
      this.sessionStatus = NhBrowserSessionBoundary.authenticated()
      this.restorePublishedAccountProfile()
      return
    }
    this.stopSessionCaptureTimer()
    this.sessionCaptureInFlight = false
    this.isBrowserRequested = false
    this.isControllerAttached = false
    this.isPageLoading = false
    if (this.accountSession.verificationRequired) {
      this.sessionStatus = NhBrowserSessionBoundary.verificationRetryRequired()
      return
    }
    // A signed-out Account route remains native until the user explicitly
    // chooses Sign in. Appearing on this page must not itself enter ArkWeb.
    this.sessionStatus = NhBrowserSessionBoundary.preflight()
  }

  private restorePublishedAccountProfile(): void {
    NhAccountProfileService.restore(this.hostContext())
      .then((): void => {
        this.refreshAccountProfile()
      })
      .catch((): void => {})
  }

  private openBrowserSession(): void {
    this.accountActionError = ''
    if (!this.accountSession.initialized) {
      this.sessionStatus = NhBrowserSessionBoundary.blockedNavigation()
      return
    }
    this.refreshBrowserStatus()
    if (!this.sessionStatus.canOpenBrowserSession() ||
      !NhAccountSessionService.canOpenVisibleLoginSession()) {
      if (NhAccountSessionService.requiresExplicitVisibleLoginAction()) {
        this.sessionStatus = NhBrowserSessionBoundary.verificationRetryRequired()
      }
      return
    }
    this.stopSessionCaptureTimer()
    this.sessionCaptureInFlight = false
    this.isControllerAttached = false
    this.isPageLoading = true
    this.browserSessionUserAgent = ''
    this.hasObservedTrustedLoginRedirect = false
    NhAccountSessionService.resetRejectedVisibleBrowserSessionCandidate()
    this.isBrowserRequested = true
  }

  /** Opens a retained-failure replacement flow only after this native action. */
  private requestExplicitBrowserSession(): void {
    if (!this.accountSession.initialized) {
      return
    }
    NhAccountSessionService.registerExplicitVisibleLoginAction()
    this.openBrowserSession()
  }

  /** The recovery route supplies the same explicit action the native row uses. */
  private consumeAutoOpenVisibleLogin(): void {
    if (!this.autoOpenVisibleLogin || this.autoOpenVisibleLoginConsumed ||
      !this.accountSession.initialized || this.accountSession.signedIn) {
      return
    }
    this.autoOpenVisibleLoginConsumed = true
    this.requestExplicitBrowserSession()
  }

  private attachAndLoad(): void {
    if (!this.isBrowserRequested || this.isControllerAttached) {
      return
    }
    this.isControllerAttached = true
    try {
      // Match NextE's production ArkWeb login host. This is scoped to the
      // current Web context and is applied before the first navigation.
      const nativeUserAgent: string = this.controller.getUserAgent()
      const nextECompatibleUserAgent: string =
        NhAccountSessionService.nextECompatibleUserAgent(nativeUserAgent)
      if (nextECompatibleUserAgent.length === 0) {
        this.failBrowserInitialization()
        return
      }
      this.controller.setCustomUserAgent(nextECompatibleUserAgent)
      // ArkWeb exposes the per-component value back through the controller.
      // Do not begin a challenge flow under the native UA if the replacement
      // was rejected; that would knowingly create the same failure mode the
      // NextE transform exists to avoid.
      if (this.controller.getCustomUserAgent() !== nextECompatibleUserAgent) {
        this.failBrowserInitialization()
        return
      }
      this.browserSessionUserAgent = nextECompatibleUserAgent
    } catch (_error) {
      this.failBrowserInitialization()
      return
    }
    try {
      // The visible login flow may embed a cross-origin challenge. Native
      // requests never receive those cookies; only the ArkWeb context does.
      webview.WebCookieManager.putAcceptCookieEnabled(true)
      webview.WebCookieManager.putAcceptThirdPartyCookieEnabled(true)
    } catch (_error) {
      this.failBrowserInitialization()
      return
    }
    // ErosN polls its visible WebView because the final account cookies can
    // be committed by a same-page request rather than a main-frame redirect.
    // Keep that timing behavior, but use ArkWeb's URL-scoped cookie API only:
    // no DOM script, form field, cookie value, or browser diagnostic is read.
    this.startSessionCaptureTimer()
    try {
      // Keep the navigation surface aligned with NextE. The login page may
      // legitimately load a managed challenge from a different origin; native
      // session capture stays constrained to the first-party origin below.
      this.controller.loadUrl(NhBrowserSessionBoundary.loginUrl())
    } catch (_error) {
      this.failBrowserInitialization()
    }
  }

  /**
   * A failed local ArkWeb setup is not a browser page. Return to the native
   * Account surface instead of retaining a blank Web component or its capture
   * timer. This changes no promoted session and keeps an unfinished candidate
   * out of the retained transport host.
   */
  private failBrowserInitialization(): void {
    this.stopSessionCaptureTimer()
    this.sessionCaptureInFlight = false
    this.isBrowserRequested = false
    this.isControllerAttached = false
    this.isPageLoading = false
    this.browserSessionUserAgent = ''
    NhAccountSessionService.revokeExplicitVisibleLoginAction()
    this.sessionStatus = NhBrowserSessionBoundary.blockedNavigation()
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhArkWebSessionTransport.resetForVisibleSessionCandidate()
  }

  private observePageEnd(url: string): void {
    this.sessionStatus = NhBrowserSessionBoundary.observePageEnd(url)
    if (this.sessionStatus.phase === NhBrowserSessionPhase.TRUSTED_REDIRECT_OBSERVED &&
      !this.hasObservedTrustedLoginRedirect) {
      this.hasObservedTrustedLoginRedirect = true
      // The one-shot ErosN-style redirect latch is also the only navigation
      // event that may reopen a transient candidate's bounded retry budget.
      // Repeated page-end callbacks must not turn into repeated account probes.
      NhAccountSessionService.observeTrustedVisibleBrowserNavigation()
      hilog.info(ACCOUNT_LOG_DOMAIN, ACCOUNT_LOG_TAG, 'trusted login redirect observed')
    }
    this.requestAccountSessionCapture(url)
  }

  private startSessionCaptureTimer(): void {
    if (this.sessionCaptureTimerId >= 0) {
      return
    }
    this.sessionCaptureTimerId = setInterval((): void => {
      this.requestAccountSessionCapture()
    }, SESSION_CAPTURE_INTERVAL_MS)
  }

  private stopSessionCaptureTimer(): void {
    if (this.sessionCaptureTimerId >= 0) {
      clearInterval(this.sessionCaptureTimerId)
      this.sessionCaptureTimerId = -1
    }
  }

  private requestAccountSessionCapture(observedUrl: string = ''): void {
    if (!this.isBrowserRequested || !this.sessionStatus.cookieAccessAllowed ||
      this.sessionCaptureInFlight) {
      return
    }
    this.sessionCaptureInFlight = true
    this.captureAccountSession(observedUrl)
      .then((): void => {
        this.sessionCaptureInFlight = false
      })
      .catch((): void => {
        this.sessionCaptureInFlight = false
      })
  }

  private async captureAccountSession(observedUrl: string): Promise<void> {
    if (!this.isBrowserRequested || !this.sessionStatus.cookieAccessAllowed) {
      return
    }
    try {
      if (await NhAccountSessionService.captureVisibleBrowserSession(
        this.hostContext(),
        observedUrl,
        this.browserSessionUserAgent,
      )) {
        hilog.info(ACCOUNT_LOG_DOMAIN, ACCOUNT_LOG_TAG, 'visible login candidate captured')
        // The visible page is the exact ArkWeb context that completed the
        // Cloudflare challenge and credential submit. Validate there before
        // it is removed; asking a second hidden Web component to re-bootstrap
        // is not a valid signal for whether this login route may return.
        const verificationOutcome: NhBrowserSessionVerificationOutcome =
          await NhApiClient.verifyAccountSessionFromVisibleBrowser(this.controller)
        if (verificationOutcome === NhBrowserSessionVerificationOutcome.RETRY_EXHAUSTED) {
          this.closeBrowserAfterCandidateVerificationExhausted()
          return
        }
        if (verificationOutcome !== NhBrowserSessionVerificationOutcome.VERIFIED) {
          return
        }
        // The account response itself can rotate the browser token. Re-read
        // the candidate before sealing: a changed snapshot remains pending
        // and must receive its own bounded verification on the next capture
        // tick, never be promoted on the strength of the prior token's 2xx.
        if (!await NhAccountSessionService.isPendingVisibleBrowserSessionStableAfterVerification(
          this.hostContext(),
          observedUrl,
          this.browserSessionUserAgent,
        )) {
          return
        }
        // A verified, unchanged visible-browser candidate must converge
        // exactly once. Leaving the timer active while local promotion is
        // pending previously re-probed a successful account every second and
        // could exhaust the service rate limit without returning to native UI.
        this.stopSessionCaptureTimer()
        if (!await NhAccountSessionService.confirmPendingVisibleBrowserSession(this.hostContext())) {
          // A verified web login must not leave the user inside an inert Web
          // component if its native persistence boundary cannot be completed.
          // Return to the Account surface, where the durable failure is visible
          // and the user can make a fresh explicit retry.
          this.accountActionError = AppStrings.get('account_save_failed')
          this.closeBrowserAfterPromotionFailure()
          return
        }
        // The root-owned host takes over only after promotion, reloading
        // with the captured UA for later authenticated read operations.
        NhArkWebSessionTransport.resetForVisibleSessionCandidate()
        this.sessionStatus = NhBrowserSessionBoundary.authenticated()
        hilog.info(ACCOUNT_LOG_DOMAIN, ACCOUNT_LOG_TAG, 'visible login session promoted')
        this.isBrowserRequested = false
        this.isControllerAttached = false
        this.stopSessionCaptureTimer()
        this.refreshAccountProfile()
        AccountListSettings.recordActive(this.hostContext()).catch((): void => {})
      }
    } catch (error) {
      // Session data never reaches logs. The small stable stage code is
      // sufficient to distinguish ArkWeb login success from local promotion
      // failure on a physical device.
      const stage: string = error instanceof Error && error.message.startsWith('account_session_')
        ? error.message
        : 'account_session_promotion_failed'
      hilog.error(ACCOUNT_LOG_DOMAIN, ACCOUNT_LOG_TAG,
        'visible login promotion failed stage=%{public}s', stage)
      this.accountActionError = AppStrings.get('account_save_failed')
      this.closeBrowserAfterPromotionFailure()
    }
  }

  /**
   * After the visible browser has proved the account session, a local seal or
   * database failure must converge to native UI instead of stranding a stopped
   * capture timer behind the Web component. It deliberately does not clear
   * ArkWeb's first-party cookies, so a user-initiated retry can reuse the
   * browser's already-completed challenge state.
   */
  private closeBrowserAfterPromotionFailure(): void {
    this.stopSessionCaptureTimer()
    this.sessionCaptureInFlight = false
    this.isBrowserRequested = false
    this.isControllerAttached = false
    this.isPageLoading = false
    this.browserSessionUserAgent = ''
    this.hasObservedTrustedLoginRedirect = false
    NhAccountSessionService.revokeExplicitVisibleLoginAction()
    this.sessionStatus = NhBrowserSessionBoundary.preflight()
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhAccountSessionService.resetRejectedVisibleBrowserSessionCandidate()
    NhArkWebSessionTransport.resetForVisibleSessionCandidate()
  }

  /**
   * A same-document candidate can be delayed by a first-party challenge or
   * transport race, but it receives only the initial account probe plus one
   * delayed confirmation. Once both are non-terminal, return to the native
   * HDS account row and make the next verification a deliberate user action.
   * No browser value, response status, or profile data enters this state.
   */
  private closeBrowserAfterCandidateVerificationExhausted(): void {
    this.closeBrowserAfterPromotionFailure()
    this.sessionStatus = NhBrowserSessionBoundary.verificationRetryRequired()
  }

  private confirmSignOut(): void {
    if (this.isSigningOut || this.sessionStatus.phase !== NhBrowserSessionPhase.AUTHENTICATED) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('account_sign_out_title'),
      message: AppStrings.get('account_sign_out_message'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('account_sign_out_action'),
        fontColor: Color.Red,
        action: (): void => {
          this.signOut()
        },
      },
    })
  }

  private async signOut(): Promise<void> {
    if (this.isSigningOut) {
      return
    }
    this.isSigningOut = true
    this.accountActionError = ''
    this.stopSessionCaptureTimer()
    this.isBrowserRequested = false
    this.isControllerAttached = false
    this.isPageLoading = false
    try {
      await NhAccountSessionService.clear(this.hostContext())
      this.refreshBrowserStatus()
    } catch (_error) {
      this.accountActionError = AppStrings.get('account_clear_failed')
    } finally {
      this.isSigningOut = false
    }
  }

  private statusLabel(): string {
    switch (this.sessionStatus.phase) {
      case NhBrowserSessionPhase.BROWSER_READY:
        return AppStrings.get('account_status_not_signed_in')
      case NhBrowserSessionPhase.LOGIN_REQUIRED:
        return AppStrings.get('account_status_signing_in')
      case NhBrowserSessionPhase.AUTHENTICATED:
        return AppStrings.get('account_status_signed_in')
      case NhBrowserSessionPhase.TRUSTED_REDIRECT_OBSERVED:
        return AppStrings.get('account_status_signing_in')
      case NhBrowserSessionPhase.VERIFICATION_RETRY_REQUIRED:
        return AppStrings.get('account_status_verification_required')
      case NhBrowserSessionPhase.UNAVAILABLE:
        return AppStrings.get('account_status_unavailable')
      default:
        return AppStrings.get('account_status_not_signed_in')
    }
  }

  /** A transient profile failure never changes a verified session's UI state. */
  private refreshAccountProfile(): void {
    if (this.sessionStatus.phase !== NhBrowserSessionPhase.AUTHENTICATED) {
      return
    }
    NhAccountProfileService.refresh(this.hostContext()).catch((): void => {})
  }

  private webContentTopInset(): number {
    return this.layoutSafeArea.topAvoidHeight + ThemeTokens.TITLE_BAR_HEIGHT
  }

  private statusSubtitle(): string {
    switch (this.sessionStatus.phase) {
      case NhBrowserSessionPhase.BROWSER_READY:
        return AppStrings.get('account_subtitle_sign_in')
      case NhBrowserSessionPhase.LOGIN_REQUIRED:
        return AppStrings.get('account_subtitle_complete_browser')
      case NhBrowserSessionPhase.AUTHENTICATED:
        return AppStrings.get('account_subtitle_signed_in_device')
      case NhBrowserSessionPhase.TRUSTED_REDIRECT_OBSERVED:
        return AppStrings.get('account_subtitle_completing_sign_in')
      case NhBrowserSessionPhase.VERIFICATION_RETRY_REQUIRED:
        return AppStrings.get('account_subtitle_verification_required')
      case NhBrowserSessionPhase.UNAVAILABLE:
        return AppStrings.get('account_subtitle_unavailable')
      default:
        return AppStrings.get('account_subtitle_sign_in')
    }
  }

  private accountBrowserActionTitle(): string {
    if (this.sessionStatus.phase === NhBrowserSessionPhase.AUTHENTICATED) {
      return AppStrings.get('account_open_browser')
    }
    if (this.sessionStatus.phase === NhBrowserSessionPhase.VERIFICATION_RETRY_REQUIRED) {
      return AppStrings.get('account_verify_sign_in')
    }
    return AppStrings.get('account_sign_in')
  }

  private accountBrowserActionSubtitle(): string {
    if (this.sessionStatus.phase === NhBrowserSessionPhase.AUTHENTICATED) {
      return AppStrings.get('account_open_browser_subtitle')
    }
    if (this.sessionStatus.phase === NhBrowserSessionPhase.VERIFICATION_RETRY_REQUIRED) {
      return AppStrings.get('account_verify_sign_in_subtitle')
    }
    return AppStrings.get('account_sign_in_subtitle')
  }

  private accountBrowserActionAccessibilityLabel(): string {
    return `${this.accountBrowserActionTitle()}. ${this.accountBrowserActionSubtitle()}`
  }

  /**
   * The native account landing view stays deliberately small. The in-app
   * ArkWeb sign-in experience owns credential entry; storage and request
   * mechanics do not belong in the customer-facing surface.
   */
  @Builder
  private AccountSection() {
    NextNGroupedListSection({ accessibilityId: 'nextn-account-native-root' }) {
      if (this.sessionStatus.phase === NhBrowserSessionPhase.AUTHENTICATED && this.accountProfile.hasSnapshot) {
        NextNListRow({
          leadingImageUrl: this.accountProfile.avatarUrl,
          leadingIcon: this.accountProfile.avatarUrl.length > 0 ? undefined : $r('sys.symbol.person_fill'),
          title: this.accountProfile.username,
          subtitle: AppStrings.format('account_profile_id', [this.accountProfile.userId]),
          trailingText: this.statusLabel(),
          showChevron: false,
          accessibilityLabel: `${this.accountProfile.username}, ${AppStrings.format('account_profile_id', [this.accountProfile.userId])}. ${this.statusLabel()}`,
        })
      } else {
        NextNListRow({
          leadingIcon: $r('sys.symbol.security_shield'),
          title: AppStrings.get('account_title'),
          subtitle: this.statusSubtitle(),
          trailingText: this.statusLabel(),
          showChevron: false,
          accessibilityLabel: `${AppStrings.get('account_title')}, ${this.statusLabel()}. ${this.statusSubtitle()}`,
        })
      }
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.worldclock'),
        title: this.accountBrowserActionTitle(),
        subtitle: this.accountBrowserActionSubtitle(),
        trailingText: this.sessionStatus.canOpenBrowserSession() ? '' : AppStrings.get('account_status_unavailable'),
        showChevron: this.sessionStatus.canOpenBrowserSession(),
        isEnabled: this.sessionStatus.canOpenBrowserSession(),
        accessibilityLabel: this.accountBrowserActionAccessibilityLabel(),
        onAction: (): void => {
          this.requestExplicitBrowserSession()
        },
      })
      if (this.sessionStatus.phase === NhBrowserSessionPhase.AUTHENTICATED) {
        this.RowDivider()
        NextNListRow({
          leadingIcon: $r('sys.symbol.arrow_right_to_line'),
          title: this.isSigningOut
            ? AppStrings.get('account_signing_out')
            : AppStrings.get('account_sign_out'),
          subtitle: AppStrings.get('account_sign_out_subtitle'),
          showChevron: false,
          destructive: true,
          isEnabled: !this.isSigningOut,
          accessibilityLabel: this.isSigningOut
            ? AppStrings.get('account_signing_out_a11y')
            : AppStrings.get('account_sign_out_a11y'),
          onAction: (): void => {
            this.confirmSignOut()
          },
        })
      }
      if (this.accountActionError.length > 0) {
        this.RowDivider()
        NextNListRow({
          title: this.accountActionError,
          showChevron: false,
          isEnabled: false,
          accessibilityLabel: this.accountActionError,
        })
      }
    }
  }

  @Builder
  private RowDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(ThemeTokens.DIVIDER)
      .margin({ left: ThemeTokens.SPACE_MD })
  }

  @Builder
  private BrowserSurface() {
    if (this.isBrowserRequested) {
      Web({ src: '', controller: this.controller, incognitoMode: false })
        .width('100%')
        .layoutWeight(1)
        .nestedScroll({
          scrollUp: NestedScrollMode.PARENT_FIRST,
          scrollDown: NestedScrollMode.PARENT_FIRST,
        })
        .overScrollMode(OverScrollMode.NEVER)
        .darkMode(WebDarkMode.Off)
        .backgroundColor(Color.White)
        // Match ErosN's fresh-login behavior without clearing first-party
        // cookies: ArkWeb's `None` mode may still use an existing resource
        // cache, while `Online` makes the login and managed-challenge entry
        // request hit the origin again.  The retained CookieManager state is
        // intentionally untouched so a valid Cloudflare clearance persists.
        .cacheMode(CacheMode.Online)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onlineImageAccess(true)
        .fileAccess(false)
        .onPageBegin((): void => {
          this.isPageLoading = true
        })
        .onControllerAttached((): void => {
          this.attachAndLoad()
        })
        .onPageEnd((event: OnPageEndEvent): void => {
          this.isPageLoading = false
          this.observePageEnd(event.url)
        })
        .onLoadFinished((): void => {
          this.isPageLoading = false
          this.requestAccountSessionCapture()
        })
        .onErrorReceive((): void => {
          this.isPageLoading = false
        })
    }
  }

  build() {
    if (this.isBrowserRequested) {
      Stack({ alignContent: Alignment.Center }) {
        // This is the dedicated NextE web-login host, not the generic
        // Gallery Web page. Its Web content starts below the immersive HDS
        // title bar exactly once; the root shell and ordinary list pages do
        // not receive this login-only inset.
        Column() {
          this.BrowserSurface()
        }
        .width('100%')
        .height('100%')
        .padding({ top: this.webContentTopInset() })
        if (this.isPageLoading) {
          LoadingProgress()
            .width(ThemeTokens.INLINE_PROGRESS_SIZE)
            .height(ThemeTokens.INLINE_PROGRESS_SIZE)
            .color(ThemeTokens.BRAND)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeTokens.SURFACE)
    } else {
      Column() {
        SecondaryListScaffold({
          scroller: this.scroller,
          bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
          alwaysEnableEdgeSpring: true,
        }) {
          ListItem() {
            this.AccountSection()
          }
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeTokens.SURFACE)
    }
  }
}
