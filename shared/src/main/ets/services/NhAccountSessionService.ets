import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { huks } from '@kit.UniversalKeystoreKit'
import { webview } from '@kit.ArkWeb'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  AccountSessionRepository,
  AccountSessionRestoreSnapshot,
  AccountSessionVerificationSnapshot,
  EncryptedAccountSession,
} from '../storage/AccountSessionRepository'
import { AccountProfileRepository } from '../storage/AccountProfileRepository'
import { connectAccountSession } from '../state/AccountSessionState'
import { connectAccountProfile } from '../state/AccountProfileState'
import { NhBrowserSessionBoundary } from './NhBrowserSessionBoundary'

const KEY_ALIAS: string = 'com.erosteam.nextn.account-session.v1'
const ASSOCIATED_DATA: string = 'com.erosteam.nextn.account-session'
const NONCE_BYTES: number = 12
const AUTH_TAG_BYTES: number = 16
const MAX_COOKIE_HEADER_BYTES: number = 16 * 1024
const MAX_BROWSER_USER_AGENT_CHARS: number = 2048
// The retained ArkWeb transport derives its account authorization exclusively
// from this one visible document cookie. The encrypted header is not a
// recoverable Set-Cookie archive: it lacks original domain/path/expiry flags,
// so never replay unrelated site or challenge state at a weaker scope.
const RECOVERABLE_ARKWEB_COOKIE_NAMES: string[] = ['access_token']
// The visible page polls for a completed login every second. A candidate that
// reaches the account endpoint while a challenge is still settling must not
// turn that poll into a one-request-per-second retry loop.
const TRANSIENT_CANDIDATE_RETRY_DELAY_MS: number = 5000
// ErosN treats a completed WebView login as a one-shot decision. Mirror that
// bounded completion behavior here: after the initial probe, an unchanged
// browser candidate gets one delayed confirmation attempt, never an endless
// five-second poll. A changed cookie+UA, explicit new login, or trusted
// redirect is a new candidate phase and can start this small budget again.
const MAX_TRANSIENT_CANDIDATE_RETRIES: number = 1
const ACCOUNT_LOG_DOMAIN: number = 0x0000
const ACCOUNT_LOG_TAG: string = 'NextNAccount'

/**
 * Account diagnostics deliberately carry a fixed lifecycle code only. They
 * never include browser data, RDB errors, HUKS errors, or payload details.
 */
enum AccountSessionDiagnosticStage {
  RESTORE_NOT_OBSERVED = 'account_restore_not_observed',
  RESTORE_RECORD_ABSENT = 'account_restore_record_absent',
  RESTORE_RDB_REBUILT_RECORD_ABSENT = 'account_restore_rdb_rebuilt_record_absent',
  RESTORE_RDB_READ_FAILED = 'account_restore_rdb_read_failed',
  RESTORE_HUKS_KEY_CHECK_FAILED = 'account_restore_huks_key_check_failed',
  RESTORE_HUKS_KEY_ABSENT = 'account_restore_huks_key_absent',
  RESTORE_HUKS_DECRYPT_FAILED = 'account_restore_huks_decrypt_failed',
  RESTORE_PAYLOAD_INVALID = 'account_restore_payload_invalid',
  RESTORE_ARKWEB_JAR_READY = 'account_restore_arkweb_jar_ready',
  RESTORE_READY = 'account_restore_ready',
  RESTORE_HYDRATION_DEFERRED = 'account_restore_hydration_deferred',
  RESTORE_VERIFICATION_REQUIRED = 'account_restore_verification_required',
  RESTORE_VERIFICATION_REQUIRED_AFTER_BROWSER_REFRESH_FAILURE =
    'account_restore_verification_required_after_browser_refresh_failure',
  VERIFICATION_REQUIRED_POST_RESTORE_401 = 'account_verification_required_post_restore_401',
  VERIFICATION_REQUIRED_POST_PROMOTION_401 = 'account_verification_required_post_promotion_401',
  VERIFICATION_MARKER_PERSIST_FAILED = 'account_verification_marker_persist_failed',
  ARKWEB_TRANSPORT_MAIN_FRAME_LOAD_FAILED = 'account_arkweb_transport_main_frame_load_failed',
}

/** Distinguishes a cold restore from a visible browser promotion for a later 401. */
enum AccountSessionOrigin {
  NONE = 'none',
  RESTORED = 'restored',
  PROMOTED = 'promoted',
}

/**
 * Kept only inside the encrypted session envelope. A clearance cookie can be
 * bound to the exact user agent which obtained it, so the later ArkWeb
 * account transport must retain the visible login surface's UA as well as
 * its cookies. This is not UI state and is never logged.
 */
class SealedBrowserSessionPayload {
  cookieHeader: string = ''
  browserUserAgent: string = ''
  isEnvelopeValid: boolean = false
}

/**
 * Non-secret ownership of one authenticated ArkWeb GET. A response may alter
 * session state only while this exact runtime epoch remains active and no
 * durable sign-out or verified-promotion transition has started.
 */
export class NhAccountAuthenticatedReadToken {
  sessionEpoch: number = -1
  transitionEpoch: number = -1
}

/**
 * Owns the local account-session marker without ever accepting or retaining
 * a password. A visible ArkWeb login is the sole producer of the browser
 * cookie header; persistence is encrypted with a non-exportable HUKS AES key.
 * Authenticated dispatch remains in ArkWeb's regular cookie context.
 */
export class NhAccountSessionService {
  // `cookieHeader` is the current normal ArkWeb cookie-jar view used by the
  // retained transport. The encrypted envelope is only a recovery fallback;
  // treating its flattened snapshot as the live authority split one browser
  // session into two independently expiring identities after a cold start.
  private static cookieHeader: string = ''
  private static sealedFallbackCookieHeader: string = ''
  private static browserUserAgent: string = ''
  // Candidate values remain only in memory until a same-origin account probe
  // succeeds. They are deliberately separate from the active sealed session
  // so a managed-challenge 403 cannot replace a working account marker.
  private static pendingCookieHeader: string = ''
  private static pendingBrowserUserAgent: string = ''
  // A definitive 401 can expose a token-shaped but unusable cookie. Keep only
  // that terminally rejected candidate in memory for the visible login page
  // so its one-second cookie poll does not repeatedly rebuild the retained
  // ArkWeb host. This is cleared on a new visible login attempt, sign-out, a
  // successful promotion, or a genuinely changed candidate; it is never
  // persisted or rendered.
  private static rejectedCandidateCookieHeader: string = ''
  private static rejectedCandidateBrowserUserAgent: string = ''
  // A non-401 result cannot prove that a browser-issued account token is
  // invalid: it can be a challenge, navigation, transport, or origin race.
  // Keep that candidate only in memory until its short retry window opens.
  // This is deliberately separate from the terminal 401 rejection above.
  private static deferredCandidateCookieHeader: string = ''
  private static deferredCandidateBrowserUserAgent: string = ''
  private static deferredCandidateRetryAtMs: number = 0
  // Counts only delayed re-probes, not the initial candidate probe. It stays
  // associated with the exact candidate and trusted-navigation epoch so the
  // visible page's one-second timer cannot silently reset its own budget.
  private static deferredCandidateRetryAttempts: number = 0
  private static deferredCandidateNavigationEpoch: number = 0
  private static visibleLoginNavigationEpoch: number = 0
  private static keyReadyTask: Promise<void> | null = null
  private static sessionContext: common.UIAbilityContext | null = null
  // EntryAbility owns the single cold-start restore. Keep its HUKS/RDB read
  // single-flight so an overlapping durable transition cannot publish a stale
  // session result.
  private static restoreTask: Promise<boolean> | null = null
  // ArkWeb owns the usable browser identity. This task is deliberately
  // separate from the sealed-record restore: an early lifecycle call can
  // retry from the retained transport Web component without deleting a valid
  // encrypted record just because the Web engine was not ready yet.
  private static cookieJarHydrationTask: Promise<boolean> | null = null
  private static cookieJarHydrationHeader: string = ''
  private static cookieJarHydrationEpoch: number = -1
  // Initial transport bootstrap deliberately preserves an ArkWeb token that
  // may be newer than the sealed fallback. If an authenticated, idempotent
  // read actually gets 401, that presumption is no longer safe: permit one
  // epoch-scoped attempt to restore the sealed access token to the normal
  // non-HttpOnly cookie slot before the caller retries that original read.
  private static sealedCookieJarRecoveryEpoch: number = -1
  private static sealedCookieJarRecoverySucceeded: boolean = false
  private static sealedCookieJarRecoveryTask: Promise<boolean> | null = null
  private static sealedCookieJarRecoveryTaskEpoch: number = -1
  private static sessionEpoch: number = 0
  // Durable clear and verified promotion announce ownership before their RDB
  // operation starts. An old ArkWeb GET can then neither replay its cookie
  // recovery nor enqueue a verification marker behind the newer transition.
  private static sessionTransitionEpoch: number = 0
  private static sessionTransitionInFlight: boolean = false
  private static sessionOrigin: AccountSessionOrigin = AccountSessionOrigin.NONE
  // A persisted marker is loaded before any sealed-record decrypt or ArkWeb
  // hydration. This in-process mirror changes only after that RDB marker has
  // committed, so published verification state can survive a cold start.
  private static verificationRequiredMarkerPresent: boolean = false
  // A retained sealed record that cannot currently restore is a recovery
  // boundary, not an implicit replacement-login request. This pair contains
  // no browser or account data and exists only for the active process: a
  // normal absent-record login remains usable, while a replacement attempt
  // must start from one explicit native Account action.
  private static retainedRestoreRequiresExplicitLogin: boolean = false
  private static explicitVisibleLoginActionRegistered: boolean = false
  // This is a fixed, non-secret classification for the current process. It
  // remains available even when an external log collector cannot attach in
  // time to EntryAbility startup. It never carries an RDB, HUKS, browser, or
  // account value.
  private static latestDiagnosticStage: AccountSessionDiagnosticStage =
    AccountSessionDiagnosticStage.RESTORE_NOT_OBSERVED
  private static emittedDiagnosticStages: Set<AccountSessionDiagnosticStage> =
    new Set<AccountSessionDiagnosticStage>()

  static isAuthenticated(): boolean {
    return NhAccountSessionService.hasLoginCookies(NhAccountSessionService.cookieHeader)
  }

  /** Captured synchronously before an authenticated ArkWeb GET is issued. */
  static captureAuthenticatedReadToken(): NhAccountAuthenticatedReadToken | null {
    if (!NhAccountSessionService.isAuthenticated() ||
      NhAccountSessionService.sessionTransitionInFlight) {
      return null
    }
    const token: NhAccountAuthenticatedReadToken = new NhAccountAuthenticatedReadToken()
    token.sessionEpoch = NhAccountSessionService.sessionEpoch
    token.transitionEpoch = NhAccountSessionService.sessionTransitionEpoch
    return token
  }

  /** Returns false as soon as clear or verified promotion owns the session. */
  static isAuthenticatedReadTokenCurrent(token: NhAccountAuthenticatedReadToken): boolean {
    return NhAccountSessionService.isAuthenticated() &&
      !NhAccountSessionService.sessionTransitionInFlight &&
      token.sessionEpoch === NhAccountSessionService.sessionEpoch &&
      token.transitionEpoch === NhAccountSessionService.sessionTransitionEpoch
  }

  /**
   * The retained ArkWeb transport may use the current ability context only
   * while it is repairing the exact authenticated read that supplied this
   * token. The context carries no account or browser data; it lets the
   * already-authorized browser identity atomically re-promote a newly
   * verified access token before a terminal 401 becomes a visible failure.
   */
  static authenticatedRecoveryContext(token: NhAccountAuthenticatedReadToken): common.UIAbilityContext | null {
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
      return null
    }
    return NhAccountSessionService.sessionContext
  }

  /** Returns one fixed lifecycle code only; safe for redacted acceptance diagnostics. */
  static latestDiagnosticStageCode(): string {
    return NhAccountSessionService.latestDiagnosticStage
  }

  /**
   * The retained ArkWeb host has already classified an error as main-frame
   * only. Preserve that finite fact for the next account-persistence evidence
   * run without carrying a request URL, error code, response, cookie, or
   * browser payload across the service boundary.
   */
  static recordArkWebTransportMainFrameLoadFailure(): void {
    NhAccountSessionService.recordDiagnosticStage(
      AccountSessionDiagnosticStage.ARKWEB_TRANSPORT_MAIN_FRAME_LOAD_FAILED,
    )
  }

  /** True only while a retained sealed record needs an explicit replacement decision. */
  static requiresExplicitVisibleLoginAction(): boolean {
    return NhAccountSessionService.retainedRestoreRequiresExplicitLogin
  }

  /**
   * Registers one native user action before a retained failed bootstrap may
   * open the visible login surface. This is intentionally process-local and
   * carries no credential, field, URL, or browser value.
   */
  static registerExplicitVisibleLoginAction(): void {
    // Register before navigation rather than after a bootstrap outcome arrives:
    // a fast native tap while `restore()` is still in flight is still an
    // explicit decision if that bootstrap subsequently reports a retained
    // record failure.
    NhAccountSessionService.explicitVisibleLoginActionRegistered = true
  }

  /** Cancels a not-yet-promoted explicit login action when its visible route ends. */
  static revokeExplicitVisibleLoginAction(): void {
    if (NhAccountSessionService.retainedRestoreRequiresExplicitLogin) {
      NhAccountSessionService.explicitVisibleLoginActionRegistered = false
    }
  }

  /** Defense in depth for any visible-login caller, not just BrowserSessionPage. */
  static canOpenVisibleLoginSession(): boolean {
    return !NhAccountSessionService.retainedRestoreRequiresExplicitLogin ||
      NhAccountSessionService.explicitVisibleLoginActionRegistered
  }

  /**
   * Starts a visible login for ADDING another account (NextE parity: a
   * newly-added account must not inherit the previous account's browser
   * identity cookies). The caller persists the current account first; this
   * method only clears the first-party identity cookies from the ArkWeb jar
   * and drops every stale candidate. The active runtime session and its
   * sealed fallback stay untouched, so abandoning the flow keeps the current
   * account signed in; the next authenticated read rehydrates the jar.
   */
  static beginAddAccountVisibleLogin(): void {
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhAccountSessionService.resetRejectedVisibleBrowserSessionCandidate()
    NhAccountSessionService.expireVisibleBrowserIdentityCookies()
  }

  /** Produces the one ArkWeb-compatible UA shape for visible and retained hosts. */
  static nextECompatibleUserAgent(nativeUserAgent: string): string {
    const normalizedNativeUserAgent: string = NhAccountSessionService.normalizeUserAgent(nativeUserAgent)
    if (normalizedNativeUserAgent.length === 0) {
      return ''
    }
    return NhAccountSessionService.normalizeUserAgent(
      normalizedNativeUserAgent.replace(') AppleWebKit', '; Android 10) AppleWebKit'),
    )
  }

  /**
   * Uses the exact user agent configured before the ArkWeb login navigation.
   * When a regular ArkWeb jar survives but the encrypted fallback is absent,
   * the retained host derives that same compatible UA from its own controller.
   */
  static requestUserAgent(nativeUserAgent: string = ''): string {
    const candidate: string = NhAccountSessionService.pendingBrowserUserAgent.length > 0
      ? NhAccountSessionService.pendingBrowserUserAgent
      : NhAccountSessionService.browserUserAgent.length > 0
        ? NhAccountSessionService.browserUserAgent
        : NhAccountSessionService.nextECompatibleUserAgent(nativeUserAgent)
    const userAgent: string = NhAccountSessionService.normalizeUserAgent(
      candidate,
    )
    return userAgent
  }

  static async restoreAtBootstrap(context: common.UIAbilityContext): Promise<boolean> {
    NhAccountSessionService.sessionContext = context
    // Bootstrap restore is a cold-start recovery path. Once this process already owns a
    // verified runtime session, retained pages must not re-read RDB/HUKS and
    // turn a transient local-storage failure into a visible signed-out state.
    // A durable clear/promotion or a persisted verification gate deliberately
    // bypasses this fast path so its ownership/fail-closed boundary remains
    // authoritative.
    if (NhAccountSessionService.isAuthenticated() &&
      !NhAccountSessionService.sessionTransitionInFlight &&
      !NhAccountSessionService.verificationRequiredMarkerPresent) {
      return true
    }
    if (NhAccountSessionService.restoreTask !== null) {
      return await NhAccountSessionService.restoreTask
    }
    const restoredEpoch: number = NhAccountSessionService.sessionEpoch
    const task: Promise<boolean> = NhAccountSessionService.restoreInternal(context, restoredEpoch)
    NhAccountSessionService.restoreTask = task
    try {
      return await task
    } finally {
      if (NhAccountSessionService.restoreTask === task) {
        NhAccountSessionService.restoreTask = null
      }
    }
  }

  /**
   * EntryAbility calls this once after its single cold-start restore attempt.
   * It publishes only non-secret state, so pages can render without becoming
   * secondary owners of RDB/HUKS/ArkWeb recovery.
   */
  static publishBootstrapState(): void {
    NhAccountSessionService.publishCurrentSessionState()
  }

  /**
   * Makes a valid sealed browser identity usable by the regular ArkWeb store.
   * The visible login and the retained transport share that store, but a
   * process restart can retain the encrypted record while losing a session
   * cookie. Never write outside the fixed first-party root and never replace a
   * browser token that ArkWeb has already refreshed on its own.
   */
  static async ensureRegularArkWebCookieJar(): Promise<boolean> {
    const sealedCookieHeader: string = NhAccountSessionService.sealedFallbackCookieHeader
    const hydrationEpoch: number = NhAccountSessionService.sessionEpoch
    if (!NhAccountSessionService.hasLoginCookies(NhAccountSessionService.cookieHeader)) {
      return false
    }
    // A cold start can have a fully usable regular ArkWeb session even when
    // its old encrypted fallback is absent. Never synthesize a cookie from a
    // transient in-memory value in that case; simply confirm ArkWeb's own
    // current URL-scoped identity.
    if (!NhAccountSessionService.hasLoginCookies(sealedCookieHeader)) {
      const currentJarHeader: string = NhAccountSessionService.readRegularArkWebCookieHeader()
      if (!NhAccountSessionService.hasLoginCookies(currentJarHeader)) {
        return false
      }
      NhAccountSessionService.cookieHeader = currentJarHeader
      return true
    }
    const activeTask: Promise<boolean> | null = NhAccountSessionService.cookieJarHydrationTask
    if (activeTask !== null &&
      NhAccountSessionService.cookieJarHydrationHeader === sealedCookieHeader &&
      NhAccountSessionService.cookieJarHydrationEpoch === hydrationEpoch) {
      return await activeTask
    }
    if (activeTask !== null) {
      try {
        await activeTask
      } catch (_error) {}
      if (!NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, hydrationEpoch)) {
        return false
      }
    }
    const task: Promise<boolean> = NhAccountSessionService.hydrateRegularArkWebCookieJar(
      sealedCookieHeader,
      hydrationEpoch,
    )
    NhAccountSessionService.cookieJarHydrationTask = task
    NhAccountSessionService.cookieJarHydrationHeader = sealedCookieHeader
    NhAccountSessionService.cookieJarHydrationEpoch = hydrationEpoch
    try {
      return await task
    } finally {
      if (NhAccountSessionService.cookieJarHydrationTask === task) {
        NhAccountSessionService.cookieJarHydrationTask = null
        NhAccountSessionService.cookieJarHydrationHeader = ''
        NhAccountSessionService.cookieJarHydrationEpoch = -1
      }
    }
  }

  /**
   * Performs the one permitted sealed-token fallback after a real 401 from an
   * already authenticated, idempotent ArkWeb read. It never changes the
   * normal bootstrap preference for a browser-owned token, never writes an
   * HttpOnly cookie, and is bounded to one physical overwrite per sealed
   * session epoch. Concurrent reads may share the same successful recovery
   * and each retry their own original GET once; a later failed recovery for
   * the same epoch cannot trigger another overwrite.
   */
  static async recoverRegularArkWebCookieJarAfterAuthenticated401(
    token: NhAccountAuthenticatedReadToken,
  ): Promise<boolean> {
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
      return false
    }
    const sealedCookieHeader: string = NhAccountSessionService.sealedFallbackCookieHeader
    const recoveryEpoch: number = token.sessionEpoch
    if (!NhAccountSessionService.hasLoginCookies(sealedCookieHeader)) {
      return false
    }
    const activeTask: Promise<boolean> | null = NhAccountSessionService.sealedCookieJarRecoveryTask
    if (activeTask !== null &&
      NhAccountSessionService.sealedCookieJarRecoveryTaskEpoch === recoveryEpoch) {
      try {
        return await activeTask
      } catch (_error) {
        return false
      }
    }
    if (activeTask !== null) {
      try {
        await activeTask
      } catch (_error) {}
      if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token) ||
        !NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, recoveryEpoch)) {
        return false
      }
    }
    if (NhAccountSessionService.sealedCookieJarRecoveryEpoch === recoveryEpoch) {
      return NhAccountSessionService.sealedCookieJarRecoverySucceeded &&
        NhAccountSessionService.isAuthenticatedReadTokenCurrent(token) &&
        NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, recoveryEpoch)
    }
    NhAccountSessionService.sealedCookieJarRecoveryEpoch = recoveryEpoch
    NhAccountSessionService.sealedCookieJarRecoverySucceeded = false
    const task: Promise<boolean> = NhAccountSessionService.forceRegularArkWebCookieJarFromSealedSession(
      sealedCookieHeader,
      recoveryEpoch,
      token,
    )
    NhAccountSessionService.sealedCookieJarRecoveryTask = task
    NhAccountSessionService.sealedCookieJarRecoveryTaskEpoch = recoveryEpoch
    try {
      const recovered: boolean = await task
      if (NhAccountSessionService.isAuthenticatedReadTokenCurrent(token) &&
        NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, recoveryEpoch)) {
        NhAccountSessionService.sealedCookieJarRecoverySucceeded = recovered
      }
      return recovered
    } finally {
      if (NhAccountSessionService.sealedCookieJarRecoveryTask === task) {
        NhAccountSessionService.sealedCookieJarRecoveryTask = null
        NhAccountSessionService.sealedCookieJarRecoveryTaskEpoch = -1
      }
    }
  }

  /**
   * Clears the native sealed session and only first-party identity cookies
   * from this app's regular ArkWeb store. Cloudflare challenge state is not
   * identity state and is deliberately retained, matching NextE's logout
   * boundary so a later user-initiated login does not have to restart a
   * managed challenge unnecessarily.
   */
  static async clear(context: common.UIAbilityContext): Promise<void> {
    NhAccountSessionService.sessionContext = context
    const transitionEpoch: number = NhAccountSessionService.beginDurableSessionTransition()
    try {
      await AccountSessionRepository.clear(context)
    } catch (error) {
      // Do not make a failed durable clear look like a completed logout. The
      // existing authenticated runtime and ArkWeb identity remain usable, so
      // the Account page can truthfully surface its clear failure.
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
      throw error as Error
    }
    if (!NhAccountSessionService.isDurableSessionTransitionCurrent(transitionEpoch)) {
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
      return
    }
    NhAccountSessionService.verificationRequiredMarkerPresent = false
    NhAccountSessionService.clearRetainedRestoreLoginGate()
    NhAccountSessionService.advanceSessionEpoch()
    NhAccountSessionService.cookieHeader = ''
    NhAccountSessionService.sealedFallbackCookieHeader = ''
    NhAccountSessionService.browserUserAgent = ''
    NhAccountSessionService.sessionOrigin = AccountSessionOrigin.NONE
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhAccountSessionService.resetRejectedVisibleBrowserSessionCandidate()
    NhAccountSessionService.expireVisibleBrowserIdentityCookies()
    const profileClearTask: Promise<void> = NhAccountSessionService.clearAccountProfileSnapshot(context)
    NhAccountSessionService.publishSessionChange()
    try {
      await profileClearTask
    } finally {
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
    }
  }

  /**
   * An authenticated account GET reached a terminal 401 after its bounded
   * sealed-cookie recovery. It is evidence that this request needs a visible
   * verification, not evidence that deleting the user's encrypted envelope or
   * first-party ArkWeb cookies is safe. The existing Account recovery row is
   * therefore persisted across cold start and is the only route that may
   * reopen visible ArkWeb.
   */
  static async requireVisibleVerificationAfterAccountGet401(
    token: NhAccountAuthenticatedReadToken,
  ): Promise<boolean> {
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
      return false
    }
    if (NhAccountSessionService.sessionOrigin === AccountSessionOrigin.RESTORED) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.VERIFICATION_REQUIRED_POST_RESTORE_401,
      )
    } else if (NhAccountSessionService.sessionOrigin === AccountSessionOrigin.PROMOTED) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.VERIFICATION_REQUIRED_POST_PROMOTION_401,
      )
    }
    const context: common.UIAbilityContext | null = NhAccountSessionService.sessionContext
    try {
      if (context === null) {
        throw new Error('account_verification_marker_context_missing')
      }
      // The durable recovery decision must commit before this method clears
      // runtime identity or publishes its revision. Otherwise process death
      // between those two steps could make the next cold restore reuse the
      // same sealed envelope without the native verification gate.
      await AccountSessionRepository.markVerificationRequired(
        context,
        'terminal_401_browser_refresh_unsuccessful',
      )
    } catch (_error) {
      // No runtime/session publication has happened yet. Retain the prior
      // authenticated state rather than presenting a verification-required UI
      // that would disappear on the next cold start.
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.VERIFICATION_MARKER_PERSIST_FAILED,
      )
      throw new Error('account_verification_marker_persist_failed')
    }
    // If clear or verified promotion began while this marker was queued, its
    // later transaction owns the durable record (and deletes this marker).
    // Never publish the old GET's verification state over that transition.
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
      return false
    }
    NhAccountSessionService.verificationRequiredMarkerPresent = true
    NhAccountSessionService.updateRetainedRestoreLoginGate(true)
    NhAccountSessionService.advanceSessionEpoch()
    NhAccountSessionService.cookieHeader = ''
    NhAccountSessionService.browserUserAgent = ''
    NhAccountSessionService.sessionOrigin = AccountSessionOrigin.NONE
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhAccountSessionService.resetRejectedVisibleBrowserSessionCandidate()
    const profileClearTask: Promise<void> = NhAccountSessionService.clearAccountProfileSnapshot(context)
    NhAccountSessionService.publishSessionChange()
    await profileClearTask
    return true
  }

  /** Must be called from the visible Web component's UI-thread callback. */
  static async captureVisibleBrowserSession(
    context: common.UIAbilityContext,
    observedUrl: string = '',
    browserUserAgent: string = '',
  ): Promise<boolean> {
    return await NhAccountSessionService.captureBrowserSessionCandidate(
      context,
      observedUrl,
      browserUserAgent,
      true,
    )
  }

  /**
   * A bounded retained-host recovery may capture only the same first-party
   * candidate that it will immediately status-check and seal. It is distinct
   * from the visible-login entry point: no login surface, field, credential,
   * or user decision is involved here.
   */
  static async captureRegularArkWebSessionForAuthenticatedRecovery(
    context: common.UIAbilityContext,
    token: NhAccountAuthenticatedReadToken,
    observedUrl: string = '',
    browserUserAgent: string = '',
  ): Promise<boolean> {
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
      return false
    }
    return await NhAccountSessionService.captureBrowserSessionCandidate(
      context,
      observedUrl,
      browserUserAgent,
      false,
    )
  }

  private static async captureBrowserSessionCandidate(
    context: common.UIAbilityContext,
    observedUrl: string,
    browserUserAgent: string,
    requireExplicitVisibleAction: boolean,
  ): Promise<boolean> {
    NhAccountSessionService.sessionContext = context
    if (requireExplicitVisibleAction && !NhAccountSessionService.canOpenVisibleLoginSession()) {
      return false
    }
    // Flush before reading. A challenge or login redirect can have just
    // committed a first-party cookie when this visible Web callback arrives.
    try {
      webview.WebCookieManager.saveCookieSync()
    } catch (_error) {
      try {
        await webview.WebCookieManager.saveCookieAsync()
      } catch (_asyncError) {}
    }
    const rawHeaders: string[] = []
    NhBrowserSessionBoundary.trustedSessionUrls(observedUrl).forEach((url: string): void => {
      try {
        rawHeaders.push(webview.WebCookieManager.fetchCookieSync(url, false))
      } catch (_error) {}
    })
    const normalized: string = NhAccountSessionService.mergeCookieHeaders(rawHeaders)
    const normalizedUserAgent: string = NhAccountSessionService.normalizeUserAgent(browserUserAgent)
    if (!NhAccountSessionService.hasLoginCookies(normalized) || normalizedUserAgent.length === 0) {
      // A visible login page, including a Cloudflare challenge, is not proof
      // that an already persisted native session is invalid. Keep the old
      // sealed session until a complete account probe confirms a candidate. A
      // cookie without the exact visible ArkWeb UA must never reach that probe.
      return false
    }

    if ((NhAccountSessionService.rejectedCandidateCookieHeader.length > 0 ||
      NhAccountSessionService.rejectedCandidateBrowserUserAgent.length > 0) &&
      (normalized !== NhAccountSessionService.rejectedCandidateCookieHeader ||
        normalizedUserAgent !== NhAccountSessionService.rejectedCandidateBrowserUserAgent)) {
      // A genuinely changed browser candidate is not covered by a prior
      // terminal result. Forget the old in-memory marker before probing it.
      NhAccountSessionService.resetRejectedVisibleBrowserSessionCandidate()
    }

    if (normalized === NhAccountSessionService.rejectedCandidateCookieHeader &&
      normalizedUserAgent === NhAccountSessionService.rejectedCandidateBrowserUserAgent) {
      return false
    }

    const visibleNavigationEpoch: number = NhAccountSessionService.visibleLoginNavigationEpoch
    if (normalized === NhAccountSessionService.deferredCandidateCookieHeader &&
      normalizedUserAgent === NhAccountSessionService.deferredCandidateBrowserUserAgent) {
      if (NhAccountSessionService.deferredCandidateNavigationEpoch !== visibleNavigationEpoch) {
        // A trusted redirect happened after the old probe. It is a distinct
        // login phase even if the visible access-token pair has not rotated.
        NhAccountSessionService.resetDeferredVisibleBrowserSessionCandidate()
      } else {
        if (Date.now() < NhAccountSessionService.deferredCandidateRetryAtMs) {
          return false
        }
        if (NhAccountSessionService.deferredCandidateRetryAttempts >=
          MAX_TRANSIENT_CANDIDATE_RETRIES) {
          return false
        }
        // Keep the candidate fingerprint and its retry count while it is
        // pending. Clearing the marker here used to recreate the same five
        // second retry window after every transient result.
        NhAccountSessionService.deferredCandidateRetryAttempts += 1
        NhAccountSessionService.deferredCandidateRetryAtMs = 0
      }
    } else if (NhAccountSessionService.deferredCandidateCookieHeader.length > 0 ||
      NhAccountSessionService.deferredCandidateBrowserUserAgent.length > 0 ||
      NhAccountSessionService.deferredCandidateRetryAtMs > 0) {
      // A changed browser candidate supersedes a prior transient result. Do
      // not retain either value beyond the active visible login surface.
      NhAccountSessionService.resetDeferredVisibleBrowserSessionCandidate()
    }

    // The URL-scoped reads above already captured the candidate needed for the
    // same-document account probe. A final CookieManager disk flush is useful
    // for ArkWeb continuity, but it is not the durable account boundary: the
    // verified candidate is sealed with HUKS and committed to RDB below.
    // Do not turn a late best-effort browser-store failure into a false local
    // login-promotion failure after the synchronous flush has already worked.
    try {
      await webview.WebCookieManager.saveCookieAsync()
    } catch (_error) {}
    NhAccountSessionService.pendingCookieHeader = normalized
    NhAccountSessionService.pendingBrowserUserAgent = normalizedUserAgent
    return true
  }

  /**
   * A candidate is safe to seal only when the exact cookie+UA snapshot that
   * received a successful visible-document account probe is still current.
   * The account endpoint may rotate an access token while it responds. In
   * that case leave the newer candidate pending for the ordinary bounded
   * capture loop to verify rather than persisting a pre-response token.
   */
  static async isPendingVisibleBrowserSessionStableAfterVerification(
    context: common.UIAbilityContext,
    observedUrl: string = '',
    browserUserAgent: string = '',
  ): Promise<boolean> {
    const verifiedCookieHeader: string = NhAccountSessionService.pendingCookieHeader
    const verifiedBrowserUserAgent: string = NhAccountSessionService.pendingBrowserUserAgent
    if (!NhAccountSessionService.hasLoginCookies(verifiedCookieHeader) ||
      verifiedBrowserUserAgent.length === 0) {
      return false
    }
    if (!await NhAccountSessionService.captureVisibleBrowserSession(
      context,
      observedUrl,
      browserUserAgent,
    )) {
      return false
    }
    return NhAccountSessionService.pendingCookieHeader === verifiedCookieHeader &&
      NhAccountSessionService.pendingBrowserUserAgent === verifiedBrowserUserAgent
  }

  /** Same candidate-stability fence for the retained browser recovery lane. */
  static async isPendingRegularArkWebSessionStableAfterVerification(
    context: common.UIAbilityContext,
    token: NhAccountAuthenticatedReadToken,
    observedUrl: string = '',
    browserUserAgent: string = '',
  ): Promise<boolean> {
    const verifiedCookieHeader: string = NhAccountSessionService.pendingCookieHeader
    const verifiedBrowserUserAgent: string = NhAccountSessionService.pendingBrowserUserAgent
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token) ||
      !NhAccountSessionService.hasLoginCookies(verifiedCookieHeader) ||
      verifiedBrowserUserAgent.length === 0) {
      return false
    }
    if (!await NhAccountSessionService.captureRegularArkWebSessionForAuthenticatedRecovery(
      context,
      token,
      observedUrl,
      browserUserAgent,
    )) {
      return false
    }
    return NhAccountSessionService.pendingCookieHeader === verifiedCookieHeader &&
      NhAccountSessionService.pendingBrowserUserAgent === verifiedBrowserUserAgent
  }

  /**
   * Promotes only a candidate that the caller has verified through the fixed
   * same-origin ArkWeb account probe. No browser value is returned here.
   */
  static async confirmPendingVisibleBrowserSession(context: common.UIAbilityContext): Promise<boolean> {
    if (!NhAccountSessionService.canOpenVisibleLoginSession()) {
      throw new Error('account_session_recovery_action_required')
    }
    return await NhAccountSessionService.confirmPendingBrowserSession(context)
  }

  /** Commits only the candidate already checked by the retained recovery lane. */
  static async confirmPendingRegularArkWebSessionForAuthenticatedRecovery(
    context: common.UIAbilityContext,
    token: NhAccountAuthenticatedReadToken,
  ): Promise<boolean> {
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
      return false
    }
    return await NhAccountSessionService.confirmPendingBrowserSession(context)
  }

  private static async confirmPendingBrowserSession(context: common.UIAbilityContext): Promise<boolean> {
    NhAccountSessionService.sessionContext = context
    if (!NhAccountSessionService.hasLoginCookies(NhAccountSessionService.pendingCookieHeader) ||
      NhAccountSessionService.pendingBrowserUserAgent.length === 0) {
      return false
    }
    if (NhAccountSessionService.sessionTransitionInFlight) {
      return false
    }
    // Announce promotion ownership before the HUKS/RDB awaits. A stale GET
    // token must not enqueue a verification marker after this new envelope is
    // committed.
    const transitionEpoch: number = NhAccountSessionService.beginDurableSessionTransition()
    let record: EncryptedAccountSession
    try {
      record = await NhAccountSessionService.encrypt(
        NhAccountSessionService.serializeSessionPayload(
          NhAccountSessionService.pendingCookieHeader,
          NhAccountSessionService.pendingBrowserUserAgent,
        ),
      )
    } catch (error) {
      // The visible browser already owns the credentials. Surface only a
      // fixed local stage to the caller; no cookie or account data may escape
      // this service through a diagnostic.
      if (error instanceof Error && error.message.startsWith('account_session_')) {
        NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
        throw error
      }
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
      throw new Error('account_session_encryption_failed')
    }
    try {
      await AccountSessionRepository.saveVerified(context, record)
      // Do not publish native signed-in state merely because the queued write
      // resolved. Read the same encrypted row back before dismissing the
      // visible browser: a later cold restore must have a concrete durable
      // fallback, not only the still-live ArkWeb page that produced it.
      const persisted: AccountSessionRestoreSnapshot =
        await AccountSessionRepository.loadForRestore(context)
      if (persisted.record === null ||
        persisted.record.ciphertext !== record.ciphertext ||
        persisted.record.nonce !== record.nonce) {
        throw new Error('account_session_persistence_readback_failed')
      }
    } catch (_error) {
      // Keep the exact same redaction boundary for database failures.
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
      throw new Error('account_session_persistence_failed')
    }
    if (!NhAccountSessionService.isDurableSessionTransitionCurrent(transitionEpoch)) {
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
      return false
    }
    // Fence any old profile refresh before awaiting the serialized snapshot
    // deletion. Otherwise an old request can pass its liveness check while
    // this method is suspended on RDB work and repaint the prior account.
    NhAccountSessionService.advanceSessionEpoch()
    NhAccountSessionService.cookieHeader = NhAccountSessionService.pendingCookieHeader
    NhAccountSessionService.sealedFallbackCookieHeader = NhAccountSessionService.pendingCookieHeader
    NhAccountSessionService.browserUserAgent = NhAccountSessionService.pendingBrowserUserAgent
    NhAccountSessionService.sessionOrigin = AccountSessionOrigin.PROMOTED
    NhAccountSessionService.verificationRequiredMarkerPresent = false
    NhAccountSessionService.clearRetainedRestoreLoginGate()
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhAccountSessionService.resetRejectedVisibleBrowserSessionCandidate()
    const profileClearTask: Promise<void> = NhAccountSessionService.clearAccountProfileSnapshot(context)
    NhAccountSessionService.publishSessionChange()
    try {
      await profileClearTask
      return true
    } finally {
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
    }
  }

  /** Drop an unverified candidate without touching the regular Web cookie store. */
  static discardPendingVisibleBrowserSession(): void {
    NhAccountSessionService.pendingCookieHeader = ''
    NhAccountSessionService.pendingBrowserUserAgent = ''
  }

  /**
   * Records the one status that conclusively proves this candidate cannot
   * authenticate: a 401 from the fixed first-party account endpoint. The
   * values stay process-memory-only and simply suppress a duplicate probe
   * until a new visible login attempt or browser candidate is observed.
   */
  static rejectPendingVisibleBrowserSession(): void {
    NhAccountSessionService.rejectedCandidateCookieHeader = NhAccountSessionService.pendingCookieHeader
    NhAccountSessionService.rejectedCandidateBrowserUserAgent = NhAccountSessionService.pendingBrowserUserAgent
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhAccountSessionService.resetDeferredVisibleBrowserSessionCandidate()
  }

  /**
   * Defers a candidate after a result that does not establish credential
   * invalidity (for example 0, 403, 5xx, or a visible-document race). This
   * keeps the one-second capture timer from flooding the account endpoint
   * while allowing only the candidate's finite delayed retry budget.
   */
  static deferPendingVisibleBrowserSession(): boolean {
    if (!NhAccountSessionService.hasLoginCookies(NhAccountSessionService.pendingCookieHeader) ||
      NhAccountSessionService.pendingBrowserUserAgent.length === 0) {
      NhAccountSessionService.discardPendingVisibleBrowserSession()
      return false
    }
    const visibleNavigationEpoch: number = NhAccountSessionService.visibleLoginNavigationEpoch
    const isSameDeferredCandidate: boolean =
      NhAccountSessionService.pendingCookieHeader === NhAccountSessionService.deferredCandidateCookieHeader &&
      NhAccountSessionService.pendingBrowserUserAgent === NhAccountSessionService.deferredCandidateBrowserUserAgent &&
      NhAccountSessionService.deferredCandidateNavigationEpoch === visibleNavigationEpoch
    if (!isSameDeferredCandidate) {
      // This covers a changed cookie+UA and a trusted navigation that arrived
      // while the visible-document status request was still in flight. Neither
      // shares the old candidate's retry budget.
      NhAccountSessionService.resetDeferredVisibleBrowserSessionCandidate()
      NhAccountSessionService.deferredCandidateCookieHeader = NhAccountSessionService.pendingCookieHeader
      NhAccountSessionService.deferredCandidateBrowserUserAgent =
        NhAccountSessionService.pendingBrowserUserAgent
      NhAccountSessionService.deferredCandidateNavigationEpoch = visibleNavigationEpoch
      NhAccountSessionService.deferredCandidateRetryAttempts = 0
    }
    if (isSameDeferredCandidate &&
      NhAccountSessionService.deferredCandidateRetryAttempts >= MAX_TRANSIENT_CANDIDATE_RETRIES) {
      // The initial probe and its one delayed confirmation have both ended
      // non-terminally. Do not schedule a third request or strand the user in
      // Web: the caller receives this fixed signal and returns to the native
      // Account row for one explicit, user-triggered verification attempt.
      NhAccountSessionService.discardPendingVisibleBrowserSession()
      return true
    }
    NhAccountSessionService.deferredCandidateRetryAtMs = Date.now() + TRANSIENT_CANDIDATE_RETRY_DELAY_MS
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    return false
  }

  /**
   * Records the first trusted redirect of a visible login. It does not clear a
   * terminal 401 marker: only a changed candidate or an explicit new login may
   * do that. It only gives a transiently deferred candidate a new phase when
   * the page has actually progressed from the login/challenge route.
   */
  static observeTrustedVisibleBrowserNavigation(): void {
    NhAccountSessionService.visibleLoginNavigationEpoch += 1
    NhAccountSessionService.resetDeferredVisibleBrowserSessionCandidate()
  }

  /** Starts a fresh visible login attempt without preserving prior candidate state. */
  static resetRejectedVisibleBrowserSessionCandidate(): void {
    NhAccountSessionService.rejectedCandidateCookieHeader = ''
    NhAccountSessionService.rejectedCandidateBrowserUserAgent = ''
    NhAccountSessionService.resetDeferredVisibleBrowserSessionCandidate()
  }

  private static resetDeferredVisibleBrowserSessionCandidate(): void {
    NhAccountSessionService.deferredCandidateCookieHeader = ''
    NhAccountSessionService.deferredCandidateBrowserUserAgent = ''
    NhAccountSessionService.deferredCandidateRetryAtMs = 0
    NhAccountSessionService.deferredCandidateRetryAttempts = 0
    NhAccountSessionService.deferredCandidateNavigationEpoch = 0
  }

  /** Backup export: decrypts the sealed account session to the backup container. */
  static async exportSealedForBackup(context: common.UIAbilityContext): Promise<string | null> {
    const snapshot: AccountSessionRestoreSnapshot = await AccountSessionRepository.loadForRestore(context)
    const record: EncryptedAccountSession | null = snapshot.record
    if (record === null) {
      return null
    }
    return await NhAccountSessionService.decryptWithExistingKey(record)
  }

  /** Backup restore: re-wraps a backed-up plaintext session with the target device HUKS key. */
  static async restoreSealedFromBackup(context: common.UIAbilityContext, plaintext: string): Promise<void> {
    if (plaintext.length === 0) {
      throw new Error('account_session_backup_payload_invalid')
    }
    const payload: SealedBrowserSessionPayload = NhAccountSessionService.decodeSessionPayload(plaintext)
    const normalized: string = NhAccountSessionService.normalizeCookieHeader(payload.cookieHeader)
    const normalizedUserAgent: string = NhAccountSessionService.normalizeUserAgent(payload.browserUserAgent)
    if (!payload.isEnvelopeValid || !NhAccountSessionService.hasLoginCookies(normalized) ||
      normalizedUserAgent.length === 0) {
      throw new Error('account_session_backup_payload_invalid')
    }
    const record: EncryptedAccountSession = await NhAccountSessionService.encrypt(plaintext)
    await AccountSessionRepository.saveVerified(context, record)
  }

  /** Backup rollback: deletes the sealed account record (explicit rollback only). */
  static async clearSealedForBackup(context: common.UIAbilityContext): Promise<void> {
    await AccountSessionRepository.clear(context)
  }

  /** Saves the active sealed envelope under a stable non-secret account id. */
  static async saveActiveAsSaved(context: common.UIAbilityContext, accountId: string): Promise<boolean> {
    if (accountId.length === 0) {
      return false
    }
    try {
      const active: EncryptedAccountSession | null = await AccountSessionRepository.load(context)
      if (active === null) {
        return false
      }
      await AccountSessionRepository.saveVerifiedByKey(context, accountId, active)
      return true
    } catch (_error) {
      return false
    }
  }

  /** Removes one saved account's sealed envelope; never touches the active row. */
  static async removeSaved(context: common.UIAbilityContext, accountId: string): Promise<void> {
    if (accountId.length === 0) {
      return
    }
    await AccountSessionRepository.deleteByKey(context, accountId)
    await AccountProfileRepository.deleteByKey(context, accountId)
  }

  /**
   * Switches the active session to a saved account (NextE CookieJarSettings
   * switch semantics). The saved HUKS envelope is moved into the 'primary'
   * active row and the runtime + ArkWeb jar are re-seeded under one durable
   * transition, so a stale GET cannot enqueue a verification marker behind it.
   */
  static async switchToSaved(context: common.UIAbilityContext, accountId: string): Promise<boolean> {
    if (accountId.length === 0) {
      return false
    }
    NhAccountSessionService.sessionContext = context
    let record: EncryptedAccountSession | null = null
    try {
      record = await AccountSessionRepository.loadByKey(context, accountId)
    } catch (_error) {
      return false
    }
    if (record === null) {
      return false
    }
    let plaintext: string
    try {
      plaintext = await NhAccountSessionService.decryptWithExistingKey(record)
    } catch (_error) {
      return false
    }
    const payload: SealedBrowserSessionPayload = NhAccountSessionService.decodeSessionPayload(plaintext)
    const normalized: string = NhAccountSessionService.normalizeCookieHeader(payload.cookieHeader)
    const normalizedUserAgent: string = NhAccountSessionService.normalizeUserAgent(payload.browserUserAgent)
    if (!payload.isEnvelopeValid || !NhAccountSessionService.hasLoginCookies(normalized) ||
      normalizedUserAgent.length === 0) {
      return false
    }
    if (NhAccountSessionService.sessionTransitionInFlight) {
      return false
    }
    const transitionEpoch: number = NhAccountSessionService.beginDurableSessionTransition()
    try {
      await AccountSessionRepository.saveVerified(context, record)
      if (!NhAccountSessionService.isDurableSessionTransitionCurrent(transitionEpoch)) {
        return false
      }
      NhAccountSessionService.advanceSessionEpoch()
      NhAccountSessionService.cookieHeader = normalized
      NhAccountSessionService.sealedFallbackCookieHeader = normalized
      NhAccountSessionService.browserUserAgent = normalizedUserAgent
      NhAccountSessionService.sessionOrigin = AccountSessionOrigin.RESTORED
      NhAccountSessionService.verificationRequiredMarkerPresent = false
      NhAccountSessionService.clearRetainedRestoreLoginGate()
      NhAccountSessionService.discardPendingVisibleBrowserSession()
      NhAccountSessionService.resetRejectedVisibleBrowserSessionCandidate()
      NhAccountSessionService.expireVisibleBrowserIdentityCookies()
      const profileClearTask: Promise<void> =
        NhAccountSessionService.clearAccountProfileSnapshot(context)
      NhAccountSessionService.publishSessionChange()
      try {
        await profileClearTask
      } catch (_error) {}
      try {
        await NhAccountSessionService.ensureRegularArkWebCookieJar()
      } catch (_error) {}
      return true
    } catch (_error) {
      return false
    } finally {
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
    }
  }

  /** Backup restore reapply: re-reads the freshly written sealed record into runtime state. */
  static async restoreAfterBackup(context: common.UIAbilityContext): Promise<boolean> {
    NhAccountSessionService.sessionContext = context
    if (NhAccountSessionService.restoreTask !== null) {
      await NhAccountSessionService.restoreTask
    }
    const restoredEpoch: number = NhAccountSessionService.sessionEpoch
    return await NhAccountSessionService.restoreInternal(context, restoredEpoch)
  }

  private static async restoreInternal(
    context: common.UIAbilityContext,
    restoredEpoch: number,
  ): Promise<boolean> {
    // The normal ArkWeb cookie store is the live browser identity. It persists
    // independently of the encrypted fallback and remains primary when it is
    // present. It must still load a valid sealed record as a non-destructive
    // one-401 recovery fallback: returning here used to leave an apparently
    // signed-in native Account with no way for Favorites to repair a stale
    // regular ArkWeb token.
    const regularJarHeader: string = NhAccountSessionService.readRegularArkWebCookieHeader()
    const regularJarReady: boolean = NhAccountSessionService.hasLoginCookies(regularJarHeader)
    if (regularJarReady) {
      if (restoredEpoch !== NhAccountSessionService.sessionEpoch) {
        return NhAccountSessionService.isAuthenticated()
      }
      NhAccountSessionService.clearRetainedRestoreLoginGate()
      NhAccountSessionService.cookieHeader = regularJarHeader
      NhAccountSessionService.sessionOrigin = AccountSessionOrigin.RESTORED
      NhAccountSessionService.verificationRequiredMarkerPresent = false
      NhAccountSessionService.discardPendingVisibleBrowserSession()
    }
    if (NhAccountSessionService.verificationRequiredMarkerPresent) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.RESTORE_VERIFICATION_REQUIRED,
      )
    }
    let verificationSnapshot: AccountSessionVerificationSnapshot
    try {
      verificationSnapshot = await AccountSessionRepository.loadVerificationSnapshot(context)
    } catch (_error) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.RESTORE_RDB_READ_FAILED,
      )
      return await NhAccountSessionService.keepRegularJarOrPublishRestoreFailure(
        context,
        restoredEpoch,
        regularJarReady,
        true,
      )
    }
    const verificationRequired: boolean = verificationSnapshot.required
    if (verificationRequired) {
      NhAccountSessionService.verificationRequiredMarkerPresent = true
      NhAccountSessionService.recordDiagnosticStage(
        verificationSnapshot.reasonCode === 'terminal_401_browser_refresh_unsuccessful'
          ? AccountSessionDiagnosticStage.RESTORE_VERIFICATION_REQUIRED_AFTER_BROWSER_REFRESH_FAILURE
          : AccountSessionDiagnosticStage.RESTORE_VERIFICATION_REQUIRED,
      )
      // A durable terminal-401 marker is an explicit native verification
      // boundary. Retain both recovery materials for the existing visible
      // Account action, but never hydrate either one into a signed-in native
      // projection until a verified promotion atomically clears the marker.
      return await NhAccountSessionService.publishSignedOutAfterRestoreFailure(
        context,
        restoredEpoch,
        true,
      )
    }
    let restoreSnapshot: AccountSessionRestoreSnapshot
    try {
      restoreSnapshot = await AccountSessionRepository.loadForRestore(context)
    } catch (_error) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.RESTORE_RDB_READ_FAILED,
      )
      return await NhAccountSessionService.keepRegularJarOrPublishRestoreFailure(
        context,
        restoredEpoch,
        regularJarReady,
        true,
      )
    }
    const record: EncryptedAccountSession | null = restoreSnapshot.record
    if (record === null) {
      if (restoreSnapshot.rebuiltOrRepaired) {
        // The platform reported a rebuilt/repaired RDB and the sealed row is
        // absent. Do not misclassify this as a fresh install and implicitly
        // open Web; require the existing explicit verification action.
        NhAccountSessionService.recordDiagnosticStage(
          AccountSessionDiagnosticStage.RESTORE_RDB_REBUILT_RECORD_ABSENT,
        )
        return await NhAccountSessionService.keepRegularJarOrPublishRestoreFailure(
          context,
          restoredEpoch,
          regularJarReady,
          true,
        )
      }
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.RESTORE_RECORD_ABSENT,
      )
      return await NhAccountSessionService.keepRegularJarOrPublishRestoreFailure(
        context,
        restoredEpoch,
        regularJarReady,
        verificationRequired,
      )
    }

    const keyPresent: boolean | null = await NhAccountSessionService.sealedKeyPresentForRestore()
    if (keyPresent === false) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.RESTORE_HUKS_KEY_ABSENT,
      )
      // Never generate a replacement key while a sealed record exists. A new
      // key cannot decrypt this envelope and used to turn a recoverable
      // unavailable-key condition into destructive ciphertext loss.
      return await NhAccountSessionService.keepRegularJarOrPublishRestoreFailure(
        context,
        restoredEpoch,
        regularJarReady,
        true,
      )
    }
    if (keyPresent === null) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.RESTORE_HUKS_KEY_CHECK_FAILED,
      )
      return await NhAccountSessionService.keepRegularJarOrPublishRestoreFailure(
        context,
        restoredEpoch,
        regularJarReady,
        true,
      )
    }
    let restored: string
    try {
      // Restore is intentionally non-generative. Key creation belongs only to
      // a newly verified visible-login promotion through `encrypt`.
      restored = await NhAccountSessionService.decryptWithExistingKey(record)
    } catch (_error) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.RESTORE_HUKS_DECRYPT_FAILED,
      )
      return await NhAccountSessionService.keepRegularJarOrPublishRestoreFailure(
        context,
        restoredEpoch,
        regularJarReady,
        true,
      )
    }
    const payload: SealedBrowserSessionPayload = NhAccountSessionService.decodeSessionPayload(restored)
    const normalized: string = NhAccountSessionService.normalizeCookieHeader(payload.cookieHeader)
    const normalizedUserAgent: string = NhAccountSessionService.normalizeUserAgent(payload.browserUserAgent)
    if (!payload.isEnvelopeValid || !NhAccountSessionService.hasLoginCookies(normalized) ||
      normalizedUserAgent.length === 0) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.RESTORE_PAYLOAD_INVALID,
      )
      return await NhAccountSessionService.keepRegularJarOrPublishRestoreFailure(
        context,
        restoredEpoch,
        regularJarReady,
        true,
      )
    }
    if (restoredEpoch !== NhAccountSessionService.sessionEpoch) {
      return NhAccountSessionService.isAuthenticated()
    }

    NhAccountSessionService.clearRetainedRestoreLoginGate()

    if (regularJarReady) {
      // Keep ArkWeb's live cookie and its controller-provided user agent
      // untouched. The sealed header is only the recovery source used after a
      // real authenticated 401; it never replaces a regular jar during
      // bootstrap merely because it was successfully decrypted.
      NhAccountSessionService.sealedFallbackCookieHeader = normalized
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.RESTORE_ARKWEB_JAR_READY,
      )
      return true
    }

    // Seed the sealed values before attempting the cookie-store recovery so a
    // retained ArkWeb host can retry the same operation immediately before it
    // loads the fixed origin. An unavailable early Web engine must not erase a
    // valid encrypted record or turn into a destructive 401 cycle.
    const preservesActiveSessionOrigin: boolean =
      NhAccountSessionService.isAuthenticated() &&
      NhAccountSessionService.cookieHeader === normalized &&
      NhAccountSessionService.browserUserAgent === normalizedUserAgent
    NhAccountSessionService.cookieHeader = normalized
    NhAccountSessionService.sealedFallbackCookieHeader = normalized
    NhAccountSessionService.browserUserAgent = normalizedUserAgent
    // A terminal request warning is not a second durable auth owner. A valid
    // encrypted fallback still receives one normal ArkWeb restore attempt.
    NhAccountSessionService.verificationRequiredMarkerPresent = false
    if (!preservesActiveSessionOrigin) {
      NhAccountSessionService.sessionOrigin = AccountSessionOrigin.RESTORED
    }
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhAccountSessionService.recordDiagnosticStage(AccountSessionDiagnosticStage.RESTORE_READY)
    let hydrated: boolean = false
    try {
      hydrated = await NhAccountSessionService.ensureRegularArkWebCookieJar()
    } catch (_error) {}
    if (restoredEpoch !== NhAccountSessionService.sessionEpoch) {
      return NhAccountSessionService.isAuthenticated()
    }
    if (!hydrated) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.RESTORE_HYDRATION_DEFERRED,
      )
    }
    return true
  }

  /**
   * A usable regular ArkWeb session remains valid when the encrypted fallback
   * is unavailable. Its failure must not clear native state; only the absent-
   * jar path enters the existing fail-closed restore boundary.
   */
  private static async keepRegularJarOrPublishRestoreFailure(
    context: common.UIAbilityContext,
    restoredEpoch: number,
    regularJarReady: boolean,
    requiresExplicitVisibleLogin: boolean,
  ): Promise<boolean> {
    if (regularJarReady) {
      // Match the original regular-jar-first policy even when the optional
      // fallback read reports a stale verification marker or local-store
      // failure. That fallback must add recovery capability, never demote a
      // live ArkWeb identity or retain an in-memory gate that the original
      // branch would have cleared.
      NhAccountSessionService.verificationRequiredMarkerPresent = false
      NhAccountSessionService.clearRetainedRestoreLoginGate()
      return NhAccountSessionService.isAuthenticated()
    }
    return await NhAccountSessionService.publishSignedOutAfterRestoreFailure(
      context,
      restoredEpoch,
      requiresExplicitVisibleLogin,
    )
  }

  /**
   * A cold restore failure must be fail-closed for the native UI without
   * deleting the sealed RDB record. The record can become usable after a
   * temporary HUKS/RDB availability issue. Explicit sign-out remains the
   * only destructive path; an authenticated GET 401 becomes verification-
   * required without deleting the envelope.
   */
  private static async publishSignedOutAfterRestoreFailure(
    context: common.UIAbilityContext,
    restoredEpoch: number,
    requiresExplicitVisibleLogin: boolean,
  ): Promise<boolean> {
    if (restoredEpoch !== NhAccountSessionService.sessionEpoch) {
      return NhAccountSessionService.isAuthenticated()
    }
    NhAccountSessionService.updateRetainedRestoreLoginGate(requiresExplicitVisibleLogin)
    // A normal first launch can repeatedly ask `restore()` from retained
    // root surfaces. Publish only a real signed-in -> signed-out transition;
    // otherwise the Settings revision monitor would call restore again and
    // create its own notification loop.
    const hadNativeSession: boolean = NhAccountSessionService.isAuthenticated() ||
      NhAccountSessionService.browserUserAgent.length > 0 ||
      NhAccountSessionService.sessionOrigin !== AccountSessionOrigin.NONE
    if (hadNativeSession) {
      NhAccountSessionService.advanceSessionEpoch()
    }
    NhAccountSessionService.cookieHeader = ''
    NhAccountSessionService.sealedFallbackCookieHeader = ''
    NhAccountSessionService.browserUserAgent = ''
    NhAccountSessionService.sessionOrigin = AccountSessionOrigin.NONE
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhAccountSessionService.resetRejectedVisibleBrowserSessionCandidate()
    const profileClearTask: Promise<void> = NhAccountSessionService.clearAccountProfileSnapshot(context)
    if (hadNativeSession) {
      // A revision is the non-sensitive account-state publication boundary
      // for retained Settings, Favorites, and Gallery surfaces. Without it,
      // an unavailable sealed record could leave a stale signed-in
      // presentation.
      NhAccountSessionService.publishSessionChange()
    }
    await profileClearTask
    return false
  }

  private static async hydrateRegularArkWebCookieJar(
    sealedCookieHeader: string,
    hydrationEpoch: number,
  ): Promise<boolean> {
    const rootUrl: string = `${NhBrowserSessionBoundary.trustedOrigin()}/`
    if (!NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, hydrationEpoch)) {
      return false
    }
    try {
      const existing: string = NhAccountSessionService.normalizeCookieHeader(
        webview.WebCookieManager.fetchCookieSync(rootUrl, false),
      )
      // A retained browser may have silently rotated a token. That value is
      // newer than the sealed fallback and must remain ArkWeb's authority.
      if (NhAccountSessionService.hasLoginCookies(existing)) {
        if (NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, hydrationEpoch)) {
          NhAccountSessionService.cookieHeader = existing
        }
        return true
      }
    } catch (_error) {}

    const cookiePairs: string[] = sealedCookieHeader.split(';')
      .map((segment: string): string => segment.trim())
      .filter((segment: string): boolean => NhAccountSessionService.isRecoverableArkWebCookiePair(segment))
    if (cookiePairs.length === 0) {
      return false
    }
    for (let index: number = 0; index < cookiePairs.length; index += 1) {
      if (!NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, hydrationEpoch)) {
        return false
      }
      try {
        // configCookieSync expects exactly one RFC 6265 Set-Cookie value. The
        // sealed form is only a normalized name=value pair, so bind the one
        // required API cookie to the fixed HTTPS root. Do not overwrite an
        // HttpOnly site cookie when reconstructing this limited fallback.
        webview.WebCookieManager.configCookieSync(
          rootUrl,
          `${cookiePairs[index]}; Path=/; Secure`,
          false,
          false,
        )
      } catch (_error) {
        return false
      }
    }
    try {
      webview.WebCookieManager.saveCookieSync()
    } catch (_error) {
      try {
        await webview.WebCookieManager.saveCookieAsync()
      } catch (_asyncError) {
        return false
      }
    }
    if (!NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, hydrationEpoch)) {
      return false
    }
    try {
      const restored: string = NhAccountSessionService.normalizeCookieHeader(
        webview.WebCookieManager.fetchCookieSync(rootUrl, false),
      )
      const restoredMatchesFallback: boolean = NhAccountSessionService.cookieValue(restored, 'access_token') ===
        NhAccountSessionService.cookieValue(sealedCookieHeader, 'access_token')
      if (restoredMatchesFallback &&
        NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, hydrationEpoch)) {
        NhAccountSessionService.cookieHeader = restored
      }
      return restoredMatchesFallback
    } catch (_error) {
      return false
    }
  }

  /** Reads only the fixed first-party cookie scopes used by the retained transport. */
  private static readRegularArkWebCookieHeader(): string {
    const headers: string[] = []
    NhBrowserSessionBoundary.trustedSessionUrls().forEach((url: string): void => {
      try {
        headers.push(webview.WebCookieManager.fetchCookieSync(url, false))
      } catch (_error) {}
    })
    return NhAccountSessionService.mergeCookieHeaders(headers)
  }

  /**
   * This is intentionally separate from normal hydration: it is reached only
   * after the caller has received an authenticated-read 401. The sealed token
   * was previously verified in this app's visible first-party browser, so it
   * must be able to replace a stale HttpOnly cookie with the same fixed name.
   * ArkWeb's API-14 includeHttpOnly flag is required for that exact collision;
   * the replacement remains a normal readable cookie because the fixed v2
   * bridge derives its Authorization header from document.cookie.
   */
  private static async forceRegularArkWebCookieJarFromSealedSession(
    sealedCookieHeader: string,
    recoveryEpoch: number,
    token: NhAccountAuthenticatedReadToken,
  ): Promise<boolean> {
    const rootUrl: string = `${NhBrowserSessionBoundary.trustedOrigin()}/`
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token) ||
      !NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, recoveryEpoch)) {
      return false
    }
    const cookiePairs: string[] = sealedCookieHeader.split(';')
      .map((segment: string): string => segment.trim())
      .filter((segment: string): boolean => NhAccountSessionService.isRecoverableArkWebCookiePair(segment))
    if (cookiePairs.length !== 1) {
      return false
    }
    try {
      webview.WebCookieManager.configCookieSync(
        rootUrl,
        `${cookiePairs[0]}; Path=/; Secure`,
        false,
        true,
      )
    } catch (_error) {
      return false
    }
    try {
      webview.WebCookieManager.saveCookieSync()
    } catch (_error) {
      try {
        await webview.WebCookieManager.saveCookieAsync()
      } catch (_asyncError) {
        return false
      }
    }
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token) ||
      !NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, recoveryEpoch)) {
      return false
    }
    try {
      const restored: string = NhAccountSessionService.normalizeCookieHeader(
        webview.WebCookieManager.fetchCookieSync(rootUrl, false),
      )
      const restoredMatchesFallback: boolean = NhAccountSessionService.cookieValue(restored, 'access_token') ===
        NhAccountSessionService.cookieValue(sealedCookieHeader, 'access_token')
      if (restoredMatchesFallback &&
        NhAccountSessionService.isAuthenticatedReadTokenCurrent(token) &&
        NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, recoveryEpoch)) {
        NhAccountSessionService.cookieHeader = restored
      }
      return restoredMatchesFallback
    } catch (_error) {
      return false
    }
  }

  private static isCurrentSealedSession(sealedCookieHeader: string, expectedEpoch: number): boolean {
    return expectedEpoch === NhAccountSessionService.sessionEpoch &&
      sealedCookieHeader === NhAccountSessionService.sealedFallbackCookieHeader
  }

  private static advanceSessionEpoch(): void {
    NhAccountSessionService.sessionEpoch += 1
  }

  /** Begins a durable clear or verified-promotion transition before it awaits RDB. */
  private static beginDurableSessionTransition(): number {
    NhAccountSessionService.sessionTransitionEpoch += 1
    NhAccountSessionService.sessionTransitionInFlight = true
    return NhAccountSessionService.sessionTransitionEpoch
  }

  private static isDurableSessionTransitionCurrent(transitionEpoch: number): boolean {
    return NhAccountSessionService.sessionTransitionInFlight &&
      transitionEpoch === NhAccountSessionService.sessionTransitionEpoch
  }

  private static finishDurableSessionTransition(transitionEpoch: number): void {
    if (transitionEpoch === NhAccountSessionService.sessionTransitionEpoch) {
      NhAccountSessionService.sessionTransitionInFlight = false
    }
  }

  private static updateRetainedRestoreLoginGate(requiresExplicitVisibleLogin: boolean): void {
    if (!requiresExplicitVisibleLogin) {
      NhAccountSessionService.clearRetainedRestoreLoginGate()
      return
    }
    NhAccountSessionService.retainedRestoreRequiresExplicitLogin = true
  }

  private static clearRetainedRestoreLoginGate(): void {
    NhAccountSessionService.retainedRestoreRequiresExplicitLogin = false
    NhAccountSessionService.explicitVisibleLoginActionRegistered = false
  }

  /**
   * Restore must distinguish an absent device-local key from an encrypted
   * record that fails to decrypt. This probe does not create, delete, or
   * otherwise mutate a key; the established decrypt path remains unchanged.
   */
  private static async sealedKeyPresentForRestore(): Promise<boolean | null> {
    const activeKeyTask: Promise<void> | null = NhAccountSessionService.keyReadyTask
    if (activeKeyTask !== null) {
      try {
        await activeKeyTask
      } catch (_ignored) {
        return null
      }
    }
    const emptyOptions: huks.HuksOptions = { properties: [] }
    try {
      return await huks.hasKeyItem(KEY_ALIAS, emptyOptions)
    } catch (_error) {
      return null
    }
  }

  private static isRecoverableArkWebCookiePair(cookiePair: string): boolean {
    const separator: number = cookiePair.indexOf('=')
    if (separator <= 0) {
      return false
    }
    const name: string = cookiePair.slice(0, separator).trim()
    return RECOVERABLE_ARKWEB_COOKIE_NAMES.indexOf(name) >= 0
  }

  private static publishSessionChange(): void {
    NhAccountSessionService.publishCurrentSessionState()
  }

  private static publishCurrentSessionState(): void {
    const verificationRequired: boolean =
      NhAccountSessionService.verificationRequiredMarkerPresent ||
      NhAccountSessionService.retainedRestoreRequiresExplicitLogin
    connectAccountSession().publish(
      true,
      NhAccountSessionService.isAuthenticated(),
      verificationRequired,
    )
  }

  /** Emits each fixed, non-sensitive account lifecycle stage at most once per process. */
  private static recordDiagnosticStage(stage: AccountSessionDiagnosticStage): void {
    NhAccountSessionService.latestDiagnosticStage = stage
    if (NhAccountSessionService.emittedDiagnosticStages.has(stage)) {
      return
    }
    NhAccountSessionService.emittedDiagnosticStages.add(stage)
    try {
      hilog.info(ACCOUNT_LOG_DOMAIN, ACCOUNT_LOG_TAG, 'account session stage=%{public}s', stage)
    } catch (_ignored) {}
  }

  /**
   * Account identity data is deliberately separate from the HUKS envelope,
   * but it has the same lifecycle: a missing, replaced, signed-out, or 401
   * session must never leave a profile snapshot visible or restorable.
   */
  private static async clearAccountProfileSnapshot(
    context: common.UIAbilityContext | null,
  ): Promise<void> {
    connectAccountProfile().clear()
    if (context === null) {
      return
    }
    try {
      await AccountProfileRepository.clear(context)
    } catch (_error) {}
  }

  private static expireVisibleBrowserIdentityCookies(): void {
    const authCookieNames: string[] = [
      'access_token',
      'refresh_token',
      'sessionid',
      'ipb_member_id',
      'ipb_pass_hash',
    ]
    const sessionUrls: string[] = NhBrowserSessionBoundary.trustedSessionUrls()
    authCookieNames.forEach((name: string): void => {
      sessionUrls.forEach((url: string): void => {
        try {
          webview.WebCookieManager.configCookieSync(
            url,
            `${name}=; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT`,
            false,
            true,
          )
        } catch (_error) {}
      })
    })
    try {
      webview.WebCookieManager.saveCookieSync()
    } catch (_error) {
      webview.WebCookieManager.saveCookieAsync().catch((): void => {})
    }
  }

  private static async encrypt(plaintext: string): Promise<EncryptedAccountSession> {
    try {
      await NhAccountSessionService.ensureKey()
    } catch (_error) {
      throw new Error('account_session_key_failed')
    }
    const nonce: Uint8Array = cryptoFramework.createRandom().generateRandomSync(NONCE_BYTES).data
    const properties: huks.HuksParam[] = NhAccountSessionService.cryptoProperties(
      huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT,
      nonce,
    )
    const options: huks.HuksOptions = {
      properties: properties,
      inData: new util.TextEncoder().encodeInto(plaintext),
    }
    let handle: huks.HuksSessionHandle
    try {
      handle = await huks.initSession(KEY_ALIAS, options)
    } catch (_error) {
      throw new Error('account_session_encrypt_init_failed')
    }
    let result: huks.HuksReturnResult
    try {
      result = await huks.finishSession(handle.handle, options)
    } catch (_error) {
      throw new Error('account_session_encrypt_finish_failed')
    }
    const sealed: Uint8Array = result.outData ?? new Uint8Array()
    if (sealed.length <= AUTH_TAG_BYTES) {
      throw new Error('account_session_encrypt_output_invalid')
    }
    const record: EncryptedAccountSession = new EncryptedAccountSession()
    record.ciphertext = new util.Base64Helper().encodeToStringSync(sealed)
    record.nonce = new util.Base64Helper().encodeToStringSync(nonce)
    return record
  }

  /**
   * Restore-only decrypt path. It deliberately performs no key creation: the
   * caller has already completed the non-mutating HUKS presence check.
   */
  private static async decryptWithExistingKey(record: EncryptedAccountSession): Promise<string> {
    const sealed: Uint8Array = new util.Base64Helper().decodeSync(record.ciphertext)
    const nonce: Uint8Array = new util.Base64Helper().decodeSync(record.nonce)
    if (nonce.length !== NONCE_BYTES || sealed.length <= AUTH_TAG_BYTES) {
      throw new Error('The stored account session is invalid.')
    }
    const body: Uint8Array = sealed.slice(0, sealed.length - AUTH_TAG_BYTES)
    const tag: Uint8Array = sealed.slice(sealed.length - AUTH_TAG_BYTES)
    const properties: huks.HuksParam[] = NhAccountSessionService.cryptoProperties(
      huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT,
      nonce,
      tag,
    )
    const options: huks.HuksOptions = { properties: properties, inData: body }
    const handle = await huks.initSession(KEY_ALIAS, options)
    const result = await huks.finishSession(handle.handle, options)
    const plaintext: Uint8Array = result.outData ?? new Uint8Array()
    return util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(plaintext)
  }

  private static cryptoProperties(
    purpose: huks.HuksKeyPurpose,
    nonce: Uint8Array,
    authTag?: Uint8Array,
  ): huks.HuksParam[] {
    const properties: huks.HuksParam[] = [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
      { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
      {
        tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA,
        value: new util.TextEncoder().encodeInto(ASSOCIATED_DATA),
      },
    ]
    if (authTag !== undefined) {
      properties.push({ tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: authTag })
    }
    return properties
  }

  private static async ensureKey(): Promise<void> {
    if (NhAccountSessionService.keyReadyTask !== null) {
      await NhAccountSessionService.keyReadyTask
      return
    }
    const keyTask: Promise<void> = NhAccountSessionService.createKeyIfNeeded()
    NhAccountSessionService.keyReadyTask = keyTask
    try {
      await keyTask
    } catch (error) {
      NhAccountSessionService.keyReadyTask = null
      throw (error as Error)
    }
  }

  private static async createKeyIfNeeded(): Promise<void> {
    // `isKeyItemExist` rejects with 12000011 when the key is absent, which
    // prevents first-login key generation. The official HUKS API explicitly
    // provides `hasKeyItem` for this branch: it resolves `false` when absent.
    const emptyOptions: huks.HuksOptions = { properties: [] }
    if (await huks.hasKeyItem(KEY_ALIAS, emptyOptions)) {
      return
    }
    const properties: huks.HuksParam[] = [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      {
        tag: huks.HuksTag.HUKS_TAG_PURPOSE,
        value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT |
          huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT,
      },
    ]
    await huks.generateKeyItem(KEY_ALIAS, { properties: properties })
  }

  private static normalizeCookieHeader(value: string): string {
    if (value.length === 0 || value.length > MAX_COOKIE_HEADER_BYTES || /[\r\n]/.test(value)) {
      return ''
    }
    const normalized: string[] = []
    value.split(';').forEach((segment: string): void => {
      const separator: number = segment.indexOf('=')
      if (separator <= 0) {
        return
      }
      const name: string = segment.slice(0, separator).trim()
      const cookieValue: string = segment.slice(separator + 1).trim()
      if (!/^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$/.test(name) || cookieValue.length === 0) {
        return
      }
      normalized.push(`${name}=${cookieValue}`)
    })
    return normalized.join('; ')
  }

  /** Only probe-verified envelopes are accepted; older marker-only records are retired. */
  private static decodeSessionPayload(plaintext: string): SealedBrowserSessionPayload {
    const payload: SealedBrowserSessionPayload = new SealedBrowserSessionPayload()
    if (plaintext.length === 0) {
      return payload
    }
    if (!plaintext.startsWith('{')) {
      return payload
    }
    try {
      const parsed: Object = JSON.parse(plaintext) as Object
      if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
        return payload
      }
      const record: Record<string, Object> = parsed as Record<string, Object>
      if (record['version'] !== 2) {
        return payload
      }
      if (typeof record['cookieHeader'] !== 'string' || typeof record['browserUserAgent'] !== 'string') {
        return payload
      }
      payload.cookieHeader = record['cookieHeader'] as string
      payload.browserUserAgent = record['browserUserAgent'] as string
      payload.isEnvelopeValid = true
    } catch (_error) {}
    return payload
  }

  private static serializeSessionPayload(cookieHeader: string, browserUserAgent: string): string {
    return JSON.stringify({
      'version': 2,
      'cookieHeader': cookieHeader,
      'browserUserAgent': browserUserAgent,
    })
  }

  private static normalizeUserAgent(value: string): string {
    const normalized: string = value.trim()
    if (normalized.length === 0 || normalized.length > MAX_BROWSER_USER_AGENT_CHARS ||
      /[\u0000-\u001F\u007F]/.test(normalized)) {
      return ''
    }
    return normalized
  }

  private static mergeCookieHeaders(headers: string[]): string {
    const values: Map<string, string> = new Map<string, string>()
    headers.forEach((header: string): void => {
      const normalized: string = NhAccountSessionService.normalizeCookieHeader(header)
      normalized.split(';').forEach((segment: string): void => {
        const separator: number = segment.indexOf('=')
        if (separator <= 0) {
          return
        }
        const name: string = segment.slice(0, separator).trim()
        const value: string = segment.slice(separator + 1).trim()
        if (name.length > 0 && value.length > 0) {
          values.set(name, value)
        }
      })
    })
    // A visible onPageEnd capture and the one-second timer can query the same
    // URL scopes in a different order. Canonicalize cookie names before using
    // the merged header as the in-memory candidate fingerprint; otherwise an
    // identical browser state could look changed and repeatedly regain its
    // finite retry budget.
    const names: string[] = []
    values.forEach((_value: string, name: string): void => {
      names.push(name)
    })
    names.sort()
    const merged: string[] = []
    names.forEach((name: string): void => {
      const value: string | undefined = values.get(name)
      if (value !== undefined) {
        merged.push(`${name}=${value}`)
      }
    })
    return merged.join('; ')
  }

  private static hasLoginCookies(header: string): boolean {
    if (header.length === 0) {
      return false
    }
    // The ArkWeb transport derives `Authorization: User …` only from this
    // first-party cookie. A refresh token, legacy session marker, or a
    // Cloudflare clearance proves neither that the account request can be
    // authorized nor that the signed-in UI is truthful. Keep those cookies in
    // the regular Web context for the site itself, but never use them as a
    // native "signed in" marker.
    return NhAccountSessionService.cookieValue(header, 'access_token').length > 0
  }

  private static cookieValue(header: string, expectedName: string): string {
    let result: string = ''
    header.split(';').forEach((segment: string): void => {
      const separator: number = segment.indexOf('=')
      if (separator <= 0) {
        return
      }
      const name: string = segment.slice(0, separator).trim()
      const value: string = segment.slice(separator + 1).trim()
      if (name === expectedName) {
        result = value
      }
    })
    return result
  }

}
