import { common } from '@kit.AbilityKit'
import { webview } from '@kit.ArkWeb'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  AccountListSettings,
  DiagnosticLogger,
  NhAccountSessionService,
  NhAccountProfileService,
  NhCookieAuthority,
  NhApiClient,
  AppStrings,
  NhBrowserSessionBoundary,
  NhBrowserSessionPhase,
  NhBrowserSessionStatus,
  NhBrowserSessionVerificationOutcome,
  LayoutSafeAreaState,
  ThemeTokens,
  AccountSessionState,
  AccountAuthNoticeState,
  connectAccountSession,
  connectAccountAuthNotice,
  connectLayoutSafeArea,
} from 'shared'

const SESSION_CAPTURE_INTERVAL_MS: number = 1000
const ACCOUNT_LOG_DOMAIN: number = 0xD001
const ACCOUNT_LOG_TAG: string = 'NextNAccount'

/**
 * A visible, exact-origin ArkWeb account session. Its UI state never contains
 * browser data; the service handles the encrypted native transport boundary.
 */
@ComponentV2
export struct BrowserSessionPage {
  /** One-shot internal cold-start recovery route; ordinary Account visits stay native. */
  @Param autoOpenVisibleLogin: boolean = false
  /** Adding another account keeps the current one saved and opens a clean form. */
  @Param addAccountMode: boolean = false
  /** Entry-owned handoff back to the sole native Account page. */
  @Event onLoginFlowFinished?: () => void
  @Local sessionStatus: NhBrowserSessionStatus = new NhBrowserSessionStatus()
  @Local isBrowserRequested: boolean = false
  @Local isControllerAttached: boolean = false
  @Local accountSession: AccountSessionState = connectAccountSession()
  @Local accountAuthNotice: AccountAuthNoticeState = connectAccountAuthNotice()
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
  private initialLoginActionConsumed: boolean = false
  private addAccountPromotionCompleted: boolean = false
  private loginFlowFinishScheduled: boolean = false
  private layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  private controller: webview.WebviewController = new webview.WebviewController()

  aboutToAppear(): void {
    this.applyPublishedAccountSession(true)
    this.consumeInitialLoginAction()
  }

  @Monitor('accountSession.revision')
  onAccountSessionChanged(): void {
    this.applyPublishedAccountSession()
    this.consumeInitialLoginAction()
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
    if (this.addAccountMode && !this.addAccountPromotionCompleted &&
      NhAccountSessionService.isAuthenticated()) {
      // The abandoned add-account form cleared the jar's identity cookies.
      // Restore the still-active account into the compatibility browser jar;
      // native request authorization remains owned by the sealed generation.
      NhAccountSessionService.ensureRegularArkWebCookieJar().catch((): void => {})
    }
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
    if (this.isBrowserRequested) {
      // A process-local explicit login transaction owns its visible lifetime.
      // Late restore/verification revisions describe the rejected old session;
      // they must not close the replacement transaction that is already
      // collecting a fresh CAPTCHA and credentials.
      hilog.info(ACCOUNT_LOG_DOMAIN, ACCOUNT_LOG_TAG,
        'visible login stage=session_revision_deferred')
      return
    }
    if (this.accountSession.authenticationAvailable &&
      !this.accountSession.verificationRequired) {
      if (this.addAccountMode && !this.addAccountPromotionCompleted) {
        // The formal Account page's add action owns this route. The initial
        // login action below saves the active account and opens Web directly.
        this.sessionStatus = NhBrowserSessionBoundary.preflight()
        return
      }
      this.sessionStatus = NhBrowserSessionBoundary.authenticated()
      this.finishLoginFlowToAccount()
      return
    }
    this.sessionStatus = this.accountSession.verificationRequired
      ? NhBrowserSessionBoundary.verificationRetryRequired()
      : NhBrowserSessionBoundary.preflight()
  }

  private openBrowserSession(): void {
    if (!this.accountSession.initialized) {
      this.sessionStatus = NhBrowserSessionBoundary.blockedNavigation()
      return
    }
    this.refreshBrowserStatus()
    if (!this.sessionStatus.canOpenBrowserSession() ||
      !NhAccountSessionService.canOpenVisibleLoginSession()) {
      this.accountAuthNotice.publish('unavailable')
      this.finishLoginFlowToAccount()
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
    this.accountAuthNotice.clear()
    NhAccountSessionService.registerExplicitVisibleLoginAction()
    this.openBrowserSession()
  }

  /** NextE add-account semantics: save the current account, then open a clean form. */
  private requestAddAccountSession(): void {
    if (!this.accountSession.initialized) {
      this.sessionStatus = NhBrowserSessionBoundary.blockedNavigation()
      return
    }
    this.accountAuthNotice.clear()
    NhAccountSessionService.registerExplicitVisibleLoginAction()
    AccountListSettings.recordActive(this.hostContext())
      .then((): void => {
        NhAccountSessionService.beginAddAccountVisibleLogin()
        this.openBrowserSession()
      })
      .catch((): void => {
        NhAccountSessionService.beginAddAccountVisibleLogin()
        this.openBrowserSession()
      })
  }

  /** A login destination performs one action; it never renders a second native Account page. */
  private consumeInitialLoginAction(): void {
    if (this.initialLoginActionConsumed || !this.accountSession.initialized) {
      return
    }
    this.initialLoginActionConsumed = true
    if (this.addAccountMode) {
      this.requestAddAccountSession()
      return
    }
    if (this.autoOpenVisibleLogin &&
      (!this.accountSession.signedIn || this.accountSession.verificationRequired)) {
      this.requestExplicitBrowserSession()
      return
    }
    this.finishLoginFlowToAccount()
  }

  /** Pop this login-only destination and reveal the sole native Account page. */
  private finishLoginFlowToAccount(): void {
    if (this.loginFlowFinishScheduled) {
      return
    }
    this.loginFlowFinishScheduled = true
    setTimeout((): void => {
      if (this.onLoginFlowFinished) {
        this.onLoginFlowFinished()
      }
    }, 0)
  }

  private attachAndLoad(): void {
    if (!this.isBrowserRequested || this.isControllerAttached) {
      return
    }
    this.isControllerAttached = true
    try {
      // Restore the original proven NextE-compatible identity before the
      // first navigation. The production NH challenge previously succeeded
      // under this exact WebView contract.
      const nativeUserAgent: string = this.controller.getUserAgent()
      const nextECompatibleUserAgent: string =
        NhAccountSessionService.nextECompatibleUserAgent(nativeUserAgent)
      if (nextECompatibleUserAgent.length === 0) {
        this.failBrowserInitialization()
        return
      }
      this.controller.setCustomUserAgent(nextECompatibleUserAgent)
      if (this.controller.getCustomUserAgent() !== nextECompatibleUserAgent) {
        this.failBrowserInitialization()
        return
      }
      this.browserSessionUserAgent = nextECompatibleUserAgent
      DiagnosticLogger.info(
        'arkweb',
        'browser_identity',
        this.browserIdentityProfile(nextECompatibleUserAgent),
      )
    } catch (_error) {
      this.failBrowserInitialization()
      return
    }
    try {
      // The visible login flow may embed a cross-origin challenge. Native
      // requests never receive those cookies; only the ArkWeb context does.
      NhCookieAuthority.initialize()
    } catch (_error) {
      this.failBrowserInitialization()
      return
    }
    this.sessionStatus = NhBrowserSessionBoundary.preflight()
    if (!this.sessionStatus.cookieAccessAllowed) {
      this.failBrowserInitialization()
      return
    }
    // Keep NH's original login document and its own form/challenge UI. The
    // native layer observes only URL-scoped Cookie state and verifies any
    // resulting candidate through the unified session client.
    this.startSessionCaptureTimer()
    try {
      this.controller.loadUrl(NhBrowserSessionBoundary.loginUrl())
    } catch (_error) {
      this.failBrowserInitialization()
    }
  }

  /** Redacted resource classes only; URLs never enter durable diagnostics. */
  private loginResourceTarget(url: string): string {
    if (url.startsWith('https://challenges.cloudflare.com/')) {
      if (url.includes('/turnstile/v0/api.js')) {
        return 'turnstile_script'
      }
      if (url.includes('/pat/')) {
        return 'turnstile_pat'
      }
      if (url.includes('/rcv/')) {
        return 'turnstile_challenge_response'
      }
      if (url.includes('/if/')) {
        return 'turnstile_iframe'
      }
      if (url.includes('/feedback')) {
        return 'turnstile_feedback'
      }
      if (url.includes('/cmg/')) {
        return 'turnstile_capability_measurement'
      }
      if (/\/d\//.test(url)) {
        return 'turnstile_device_signal'
      }
      if (/\/i\//.test(url)) {
        return 'turnstile_interaction_signal'
      }
      if (url.includes('/turnstile/v0/')) {
        return 'turnstile_v0_runtime'
      }
      if (url.includes('/cdn-cgi/challenge-platform/')) {
        return 'turnstile_challenge_platform'
      }
      return 'turnstile_runtime'
    }
    if (url.startsWith('about:')) {
      return 'about'
    }
    if (url.startsWith(`${NhBrowserSessionBoundary.trustedOrigin()}/`)) {
      if (url.includes('/cdn-cgi/challenge-platform/')) {
        return 'first_party_challenge'
      }
      if (url.includes('/favicon.ico')) {
        return 'first_party_favicon'
      }
      if (url.includes('/api/')) {
        return 'first_party_api'
      }
      return 'first_party_other'
    }
    if (url.startsWith('data:')) {
      return 'data'
    }
    return 'other'
  }

  /** Fixed browser capability shape only; the full user-agent is never logged. */
  private browserIdentityProfile(userAgent: string): string {
    const chromiumMatch: RegExpMatchArray | null = userAgent.match(/(?:Chrome|Chromium)\/(\d+)/)
    const chromiumMajor: string = chromiumMatch !== null ? chromiumMatch[1] : 'none'
    return `chromium=${chromiumMajor},harmony=${/HarmonyOS|OpenHarmony/i.test(userAgent)},` +
      `arkweb=${/ArkWeb/i.test(userAgent)},mobile=${/Mobile/i.test(userAgent)}`
  }

  /**
   * Extracts only Cloudflare's documented six-digit client error family.
   * Console text, source URLs, line numbers, and challenge data never enter
   * app diagnostics.
   */
  private turnstileConsoleErrorCode(message: string): string {
    const match: RegExpMatchArray | null = message.match(
      /\b(?:100|102|103|104|105|106|110|200|300|400|600)\d{3}\b/,
    )
    if (match !== null) {
      return match[0]
    }
    if (/failed to load resource|status(?: code)? (?:of |is )?[45]\d\d/i.test(message)) {
      return 'network_http_failure'
    }
    if (/unsupported/i.test(message)) {
      return 'unsupported'
    }
    if (/cloudflare turnstile/i.test(message) && /error|fail/i.test(message)) {
      return 'client_failure'
    }
    return ''
  }

  /**
   * A failed local ArkWeb setup is not a browser page. Return to the native
   * Account surface instead of retaining a blank Web component or its capture
   * timer. This changes no promoted session and discards the unfinished
   * in-memory candidate.
   */
  private failBrowserInitialization(noticeCode: string = 'unavailable'): void {
    hilog.error(
      ACCOUNT_LOG_DOMAIN,
      ACCOUNT_LOG_TAG,
      'visible login stage=closed code=%{public}s',
      noticeCode,
    )
    this.stopSessionCaptureTimer()
    this.sessionCaptureInFlight = false
    this.isBrowserRequested = false
    this.isControllerAttached = false
    this.isPageLoading = false
    this.browserSessionUserAgent = ''
    NhAccountSessionService.revokeExplicitVisibleLoginAction()
    this.sessionStatus = NhBrowserSessionBoundary.blockedNavigation()
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    this.accountAuthNotice.publish(noticeCode)
    this.finishLoginFlowToAccount()
  }

  private observePageEnd(url: string): void {
    this.sessionStatus = NhBrowserSessionBoundary.observePageEnd(url)
    if (this.sessionStatus.phase === NhBrowserSessionPhase.TRUSTED_REDIRECT_OBSERVED &&
      !this.hasObservedTrustedLoginRedirect) {
      this.hasObservedTrustedLoginRedirect = true
      // The one-shot redirect latch is also the only navigation
      // event that may reopen a transient candidate's bounded retry budget.
      // Repeated page-end callbacks must not turn into repeated account probes.
      NhAccountSessionService.observeTrustedVisibleBrowserNavigation()
      hilog.info(ACCOUNT_LOG_DOMAIN, ACCOUNT_LOG_TAG, 'trusted login redirect observed')
      DiagnosticLogger.info('account-login', 'trusted_redirect_observed', 'stage')
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
        DiagnosticLogger.info('account-login', 'candidate_captured', 'stage')
        // ArkWeb owns only the visible login carrier. Once its bounded Cookie
        // snapshot is captured, the candidate is verified by the same native
        // request boundary used for every promoted-session operation.
        const verificationOutcome: NhBrowserSessionVerificationOutcome =
          await NhApiClient.verifyAccountSession()
        if (verificationOutcome === NhBrowserSessionVerificationOutcome.RETRY_EXHAUSTED) {
          DiagnosticLogger.warn('account-login', 'candidate_verification_retry_exhausted', 'stage')
          this.closeBrowserAfterCandidateVerificationExhausted()
          return
        }
        if (verificationOutcome !== NhBrowserSessionVerificationOutcome.VERIFIED) {
          DiagnosticLogger.info('account-login', 'candidate_verification_deferred', 'stage')
          return
        }
        DiagnosticLogger.info('account-login', 'candidate_verified', 'stage')
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
          DiagnosticLogger.error('account-login', 'native_session_persist_failed', 'stage')
          // A verified web login must not leave the user inside an inert Web
          // component if its native persistence boundary cannot be completed.
          // Return to the Account surface, where the durable failure is visible
          // and the user can make a fresh explicit retry.
          this.accountAuthNotice.publish('persistence_failed')
          this.closeBrowserAfterPromotionFailure()
          return
        }
        this.sessionStatus = NhBrowserSessionBoundary.authenticated()
        hilog.info(ACCOUNT_LOG_DOMAIN, ACCOUNT_LOG_TAG, 'visible login session promoted')
        DiagnosticLogger.info('account-login', 'native_session_promoted', 'stage')
        this.isBrowserRequested = false
        this.isControllerAttached = false
        this.stopSessionCaptureTimer()
        this.refreshAccountProfile()
        // Promotion is not durable until the selected saved-account envelope
        // also receives the new complete Cookie snapshot. A fire-and-forget
        // copy allowed an immediate cold start to retain the old access-only
        // saved record and later destroy refresh/session on account switch.
        if (!await AccountListSettings.recordActive(this.hostContext())) {
          DiagnosticLogger.error('account-login', 'active_account_record_failed', 'stage')
          this.accountAuthNotice.publish('persistence_failed')
          this.closeBrowserAfterPromotionFailure()
          return
        }
        DiagnosticLogger.info('account-login', 'active_account_recorded', 'stage')
        this.announceVisibleLoginPromotion()
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
      DiagnosticLogger.error('account-login', 'promotion_failed', `stage=${stage}`)
      this.accountAuthNotice.publish('persistence_failed')
      this.closeBrowserAfterPromotionFailure()
    }
  }

  private announceVisibleLoginPromotion(): void {
    if (this.addAccountPromotionCompleted) {
      return
    }
    this.addAccountPromotionCompleted = true
    this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('login_success') })
    this.finishLoginFlowToAccount()
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
    this.finishLoginFlowToAccount()
  }

  /**
   * A same-document candidate can be delayed by a first-party challenge or
   * transport race, but it receives only the initial account probe plus one
   * delayed confirmation. Once both are non-terminal, return to the normal
   * native sign-in row. There is no separate "re-verify" account state: the
   * failed candidate remains a failed login attempt, not an owned account
   * transition.
   */
  private closeBrowserAfterCandidateVerificationExhausted(): void {
    this.accountAuthNotice.publish('verification_rejected')
    this.closeBrowserAfterPromotionFailure()
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

  @Builder
  private BrowserSurface() {
    if (this.isBrowserRequested) {
      Web({
        src: '',
        controller: this.controller,
      })
        .width('100%')
        .layoutWeight(1)
        .nestedScroll({
          scrollUp: NestedScrollMode.PARENT_FIRST,
          scrollDown: NestedScrollMode.PARENT_FIRST,
        })
        .overScrollMode(OverScrollMode.NEVER)
        .darkMode(WebDarkMode.Off)
        .backgroundColor(Color.White)
        // Preserve the original fresh-login request contract without clearing
        // the first-party Cookie jar or Cloudflare clearance.
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
        .onConsole((event: OnConsoleEvent): boolean => {
          const level: MessageLevel = event.message.getMessageLevel()
          if (level !== MessageLevel.Warn && level !== MessageLevel.Error) {
            return false
          }
          const sourceId: string = event.message.getSourceId()
          const message: string = event.message.getMessage()
          if (!sourceId.startsWith('https://challenges.cloudflare.com/') &&
            !/cloudflare turnstile/i.test(message)) {
            return false
          }
          const errorCode: string = this.turnstileConsoleErrorCode(message)
          if (errorCode.length === 0) {
            return false
          }
          DiagnosticLogger.warn(
            'account-login',
            'turnstile_client_error',
            `code=${errorCode}`,
          )
          return false
        })
        .onErrorReceive((event: OnErrorReceiveEvent): void => {
          this.isPageLoading = false
          DiagnosticLogger.warn(
            'account-login',
            'resource_error',
            `code=${event.error.getErrorCode()},target=${this.loginResourceTarget(event.request.getRequestUrl())},` +
            `mainFrame=${event.request.isMainFrame()}`,
          )
        })
        .onHttpErrorReceive((event: OnHttpErrorReceiveEvent): void => {
          const status: number = event.response.getResponseCode()
          const rawMethod: string = event.request.getRequestMethod().toUpperCase()
          const method: string = ['GET', 'POST', 'HEAD', 'PUT', 'DELETE', 'OPTIONS', 'PATCH']
            .includes(rawMethod) ? rawMethod : 'OTHER'
          const mainFrame: boolean = event.request.isMainFrame()
          const target: string = this.loginResourceTarget(event.request.getRequestUrl())
          DiagnosticLogger.warn(
            'account-login',
            'http_error',
            `status=${status},method=${method},target=${target},mainFrame=${mainFrame}`,
          )
        })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // This destination is the dedicated first-party Web login host. It has
      // no native account-management branch; AccountPage is the sole owner of
      // profile, multi-account switching and sign-out UI.
      Column() {
        this.BrowserSurface()
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.webContentTopInset() })
      if (this.isPageLoading || !this.isBrowserRequested) {
        LoadingProgress()
          .width(ThemeTokens.INLINE_PROGRESS_SIZE)
          .height(ThemeTokens.INLINE_PROGRESS_SIZE)
          .color(ThemeTokens.BRAND)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE)
  }
}
