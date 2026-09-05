import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
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
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { NhBrowserSessionBoundary } from './NhBrowserSessionBoundary'
import { NhCookieAuthority } from './NhCookieAuthority'

const KEY_ALIAS: string = 'com.erosteam.nextn.account-session.v1'
const ASSOCIATED_DATA: string = 'com.erosteam.nextn.account-session'
const NONCE_BYTES: number = 12
const AUTH_TAG_BYTES: number = 16
const MAX_COOKIE_HEADER_BYTES: number = 16 * 1024
const MAX_BROWSER_USER_AGENT_CHARS: number = 2048
const MAX_AUTH_COOKIE_VALUE_CHARS: number = 4096
const MAX_AUTH_COOKIE_ATTRIBUTE_CHARS: number = 1024
const AUTH_EXPIRY_ONE_HOUR_MS: number = 60 * 60 * 1000
const AUTH_EXPIRY_ONE_DAY_MS: number = 24 * AUTH_EXPIRY_ONE_HOUR_MS
const AUTH_EXPIRY_ONE_WEEK_MS: number = 7 * AUTH_EXPIRY_ONE_DAY_MS
const AUTH_REFRESH_CHECKPOINT_MAX_ATTEMPTS: number = 3
const AUTH_REFRESH_CHECKPOINT_RETRY_DELAY_MS: number = 250
const MAX_ACCOUNT_BACKUP_BUNDLE_CHARS: number = 512 * 1024
const MAX_ACCOUNT_BACKUP_ID_CHARS: number = 512
const MAX_API_KEY_NAME_CHARS: number = 160
const RECOVERABLE_ARKWEB_COOKIE_NAMES: string[] = [
  'access_token',
  'refresh_token',
  'sessionid',
  'ipb_member_id',
  'ipb_pass_hash',
]
// The visible page polls for a completed login every second. A candidate that
// reaches the account endpoint while a challenge is still settling must not
// turn that poll into a one-request-per-second retry loop.
const TRANSIENT_CANDIDATE_RETRY_DELAY_MS: number = 5000
// A completed WebView login is a bounded one-shot decision: after the initial
// probe, an unchanged
// browser candidate gets one delayed confirmation attempt, never an endless
// five-second poll. A changed cookie+UA, explicit new login, or trusted
// redirect is a new candidate phase and can start this small budget again.
const MAX_TRANSIENT_CANDIDATE_RETRIES: number = 1
// ArkWeb's all-cookie metadata API is supplementary to the URL-scoped Cookie
// header. It must never strand the visible-login capture loop indefinitely.
const VISIBLE_AUTH_COOKIE_SNAPSHOT_TIMEOUT_MS: number = 1500
const ACCOUNT_LOG_DOMAIN: number = 0xE001
const ACCOUNT_LOG_TAG: string = 'NextNAccount'
const ACCOUNT_STATE_STORE: string = 'nextn_settings'
const ACCOUNT_PRESENT_KEY: string = 'account.session.present'
const AUTH_REFRESH_RETRY_AT_KEY: string = 'account.session.authRefreshRetryAt'
const AUTH_REFRESH_DEFAULT_COOLDOWN_MS: number = 5 * 60 * 1000
const AUTH_REFRESH_MIN_COOLDOWN_MS: number = 60 * 1000
const AUTH_REFRESH_MAX_COOLDOWN_MS: number = 24 * 60 * 60 * 1000

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
  RESTORE_HYDRATION_READY_AFTER_PAGE = 'account_restore_hydration_ready_after_page',
  RESTORE_HYDRATION_UNAVAILABLE_AFTER_PAGE = 'account_restore_hydration_unavailable_after_page',
  RESTORE_SAVED_ENVELOPE_USED = 'account_restore_saved_envelope_used',
  RESTORE_SAVED_ENVELOPE_EXHAUSTED = 'account_restore_saved_envelope_exhausted',
  RESTORE_COOKIE_STORE_RETRY = 'account_restore_cookie_store_retry',
  RESTORE_VERIFICATION_REQUIRED = 'account_restore_verification_required',
  RESTORE_VERIFICATION_REQUIRED_AFTER_BROWSER_REFRESH_FAILURE =
    'account_restore_verification_required_after_browser_refresh_failure',
  AUTHENTICATED_READ_INITIAL_401 = 'account_authenticated_read_initial_401',
  AUTHENTICATED_READ_STALE_401_AFTER_REFRESH = 'account_authenticated_read_stale_401_after_refresh',
  AUTHENTICATED_READ_BROWSER_REFRESH_READY = 'account_authenticated_read_browser_refresh_ready',
  AUTHENTICATED_READ_BROWSER_REFRESH_UNAVAILABLE = 'account_authenticated_read_browser_refresh_unavailable',
  AUTHENTICATED_READ_REFRESH_ENDPOINT_READY = 'account_authenticated_read_refresh_endpoint_ready',
  AUTHENTICATED_READ_REFRESH_ENDPOINT_UNAVAILABLE = 'account_authenticated_read_refresh_endpoint_unavailable',
  AUTHENTICATED_READ_REFRESH_RESPONSE_REJECTED = 'account_authenticated_read_refresh_response_rejected',
  AUTHENTICATED_READ_IDENTITY_MISMATCH = 'account_authenticated_read_identity_mismatch',
  AUTHENTICATED_READ_REFRESH_TOKEN_REJECTED = 'account_authenticated_read_refresh_token_rejected',
  AUTHENTICATED_READ_API_KEY_REJECTED = 'account_authenticated_read_api_key_rejected',
  AUTHENTICATED_READ_BROWSER_REPLAY_RECOVERED = 'account_authenticated_read_browser_replay_recovered',
  AUTHENTICATED_READ_BROWSER_REPLAY_401 = 'account_authenticated_read_browser_replay_401',
  AUTHENTICATED_READ_TERMINAL_401_AFTER_RESTORE = 'account_authenticated_read_terminal_401_after_restore',
  AUTHENTICATED_READ_TERMINAL_401_AFTER_PROMOTION = 'account_authenticated_read_terminal_401_after_promotion',
  RESPONSE_COOKIE_STORED = 'account_response_cookie_stored',
  RESPONSE_AUTH_COOKIE_APPLIED = 'account_response_auth_cookie_applied',
  RESPONSE_COOKIE_REJECTED = 'account_response_cookie_rejected',
  VERIFICATION_MARKER_PERSIST_FAILED = 'account_verification_marker_persist_failed',
  PROFILE_SNAPSHOT_CLEAR_FAILED = 'account_profile_snapshot_clear_failed',
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
  credentialKind: NhNativeCredentialKind = NhNativeCredentialKind.NONE
  apiKey: string = ''
  apiKeyName: string = ''
  cookieHeader: string = ''
  browserUserAgent: string = ''
  authCookies: SealedAuthCookie[] = []
  isEnvelopeValid: boolean = false
  validationCode: string = 'empty'
}

/** The single native API credential stored inside the HUKS session envelope. */
export enum NhNativeCredentialKind {
  NONE = 'none',
  WEB_TOKEN = 'web_token',
  API_KEY = 'api_key',
}

class AccountSessionBackupEntry {
  accountId: string = ''
  payload: string = ''
}

class AccountSessionBackupBundle {
  version: number = 1
  activePayload: string = ''
  saved: AccountSessionBackupEntry[] = []
}

/**
 * Exact first-party authentication cookie attributes kept only inside the
 * HUKS-encrypted envelope. Challenge cookies and unrelated browser state are
 * never copied into the native account store.
 */
class SealedAuthCookie {
  name: string = ''
  value: string = ''
  domain: string = ''
  path: string = '/'
  expiresDate: string = ''
  isHttpOnly: boolean = false
  isSecure: boolean = true
  isSessionCookie: boolean = true
  sameSitePolicy: number = webview.WebHttpCookieSameSitePolicy.LAX
}

/**
 * Non-secret ownership of one authenticated native request. A response may alter
 * session state only while this exact runtime epoch remains active and no
 * durable sign-out or verified-promotion transition has started.
 */
export class NhAccountAuthenticatedReadToken {
  sessionEpoch: number = -1
  /** Non-secret owner selected when this request began; empty only while a new login is being identified. */
  accountId: string = ''
  /** Non-secret generation of the access/refresh pair used when this request began. */
  credentialRevision: number = -1
  /** Non-secret discriminator; the credential value never leaves the service. */
  credentialKind: NhNativeCredentialKind = NhNativeCredentialKind.NONE
}

/** Result of consuming auth cookies from one bounded first-party response. */
export enum NhResponseAuthCookieResult {
  NONE,
  APPLIED,
  REJECTED,
}

/**
 * Owns the atomic native account-session generation without retaining a
 * password. ArkWeb may supply a visible-login candidate, but only a verified
 * access/renewal pair sealed with the non-exportable HUKS key can authorize
 * native requests or make the native UI report an authenticated state.
 */
export class NhAccountSessionService {
  private static nativeCredentialKind: NhNativeCredentialKind = NhNativeCredentialKind.NONE
  private static nativeApiKey: string = ''
  private static nativeApiKeyName: string = ''
  private static nativeApiKeyIdentity: string = ''
  // Flattened compatibility view. Request authorization is derived only from
  // `sealedAuthCookies`; this string and the regular ArkWeb jar cannot vote on
  // whether the native account is authenticated.
  private static cookieHeader: string = ''
  private static sealedFallbackCookieHeader: string = ''
  private static sealedAuthCookies: SealedAuthCookie[] = []
  private static browserUserAgent: string = ''
  // Candidate values remain only in memory until the native account probe
  // succeeds. They are deliberately separate from the active sealed session
  // so a managed-challenge 403 cannot replace a working account marker.
  private static pendingCookieHeader: string = ''
  private static pendingBrowserUserAgent: string = ''
  private static pendingAuthCookies: SealedAuthCookie[] = []
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
  private static candidateShapeDiagnosticEpoch: number = -1
  private static candidateCookieFallbackDiagnosticEpoch: number = -1
  private static keyReadyTask: Promise<void> | null = null
  private static sessionContext: common.UIAbilityContext | null = null
  // EntryAbility owns the single cold-start restore. Keep its HUKS/RDB read
  // single-flight so an overlapping durable transition cannot publish a stale
  // session result.
  private static restoreTask: Promise<boolean> | null = null
  // Best-effort compatibility sink for visible browser surfaces. It never
  // participates in native request authentication.
  private static cookieJarHydrationTask: Promise<boolean> | null = null
  private static cookieJarHydrationHeader: string = ''
  private static cookieJarHydrationEpoch: number = -1
  private static sessionEpoch: number = 0
  // Unlike sessionEpoch, this advances for an in-place access/refresh
  // rotation. It lets a late 401 from the preceding pair replay with the new
  // access token instead of launching a second refresh after the single-flight
  // promise has already settled.
  private static credentialRevision: number = 0
  // Durable clear and verified promotion announce ownership before their RDB
  // operation starts. An old ArkWeb GET can then neither replay its cookie
  // recovery nor enqueue a verification marker behind the newer transition.
  private static sessionTransitionEpoch: number = 0
  private static sessionTransitionInFlight: boolean = false
  private static sessionTransitionChangesOwnership: boolean = false
  private static sessionOrigin: AccountSessionOrigin = AccountSessionOrigin.NONE
  // A persisted marker is loaded before any sealed-record decrypt or ArkWeb
  // hydration. This in-process mirror changes only after that RDB marker has
  // committed, so published verification state can survive a cold start.
  private static verificationRequiredMarkerPresent: boolean = false
  private static verificationRecoveryKind: string = 'web_login'
  // Page-facing account ownership is deliberately distinct from transport
  // availability. Once a verified envelope exists, request, ArkWeb, HUKS, or
  // RDB recovery failures cannot make the user signed out; only explicit
  // clear/removal may reset this flag.
  private static retainedAccountPresent: boolean = false
  // Non-secret owner key for the active saved envelope. AccountListSettings
  // restores it independently from the optional display-profile snapshot so
  // a missing profile can never deselect the account or stop token rotation
  // from updating the matching saved envelope.
  private static activeSavedAccountId: string = ''
  private static lastSavedAccountCheckpointId: string = ''
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
    if (NhAccountSessionService.verificationRequiredMarkerPresent) {
      return false
    }
    if (NhAccountSessionService.nativeCredentialKind === NhNativeCredentialKind.API_KEY) {
      return NhAccountSessionService.safeApiToken(NhAccountSessionService.nativeApiKey).length > 0
    }
    return NhAccountSessionService.nativeCredentialKind === NhNativeCredentialKind.WEB_TOKEN &&
      NhAccountSessionService.hasAccessAuthCookie(NhAccountSessionService.sealedAuthCookies) &&
      NhAccountSessionService.hasRefreshAuthCookie(NhAccountSessionService.sealedAuthCookies)
  }

  static credentialKind(): NhNativeCredentialKind {
    return NhAccountSessionService.nativeCredentialKind
  }

  /** Non-secret UI identity for matching the active key without exposing it. */
  static apiKeyIdentityForDisplay(candidate: string): string {
    const normalized: string = NhAccountSessionService.normalizeApiKeyCandidate(candidate)
    if (normalized.length < 5) {
      return normalized.length > 0 ? '••••' : ''
    }
    if (normalized.length < 12) {
      return `••••${normalized.slice(-4)}`
    }
    return `${normalized.slice(0, 4)}••••${normalized.slice(-4)}`
  }

  private static normalizeApiKeyName(value: string): string {
    const normalized: string = value.trim()
    if (normalized.length === 0 || normalized.length > MAX_API_KEY_NAME_CHARS ||
      /[\u0000-\u001F\u007F]/.test(normalized)) {
      return ''
    }
    return normalized
  }

  /** Durable account ownership as projected to native pages. */
  static hasRetainedAccount(): boolean {
    return NhAccountSessionService.retainedAccountPresent ||
      NhAccountSessionService.isAuthenticated()
  }

  static setActiveSavedAccountId(accountId: string): void {
    const normalized: string = accountId.trim()
    if (normalized !== NhAccountSessionService.activeSavedAccountId) {
      NhAccountSessionService.lastSavedAccountCheckpointId = ''
    }
    NhAccountSessionService.activeSavedAccountId = normalized
  }

  /** Captured synchronously before an authenticated native request is issued. */
  static captureAuthenticatedReadToken(): NhAccountAuthenticatedReadToken | null {
    if (!NhAccountSessionService.isAuthenticated() ||
      (NhAccountSessionService.sessionTransitionInFlight &&
        NhAccountSessionService.sessionTransitionChangesOwnership)) {
      return null
    }
    const token: NhAccountAuthenticatedReadToken = new NhAccountAuthenticatedReadToken()
    token.sessionEpoch = NhAccountSessionService.sessionEpoch
    token.accountId = NhAccountSessionService.activeSavedAccountId
    token.credentialRevision = NhAccountSessionService.credentialRevision
    token.credentialKind = NhAccountSessionService.nativeCredentialKind
    return token
  }

  /** Returns false as soon as clear or verified promotion owns the session. */
  static isAuthenticatedReadTokenCurrent(token: NhAccountAuthenticatedReadToken): boolean {
    return NhAccountSessionService.isAuthenticated() &&
      !(NhAccountSessionService.sessionTransitionInFlight &&
        NhAccountSessionService.sessionTransitionChangesOwnership) &&
      token.sessionEpoch === NhAccountSessionService.sessionEpoch
  }

  /** True only while this request still belongs to the access/refresh pair it started with. */
  static isAuthenticatedReadCredentialCurrent(token: NhAccountAuthenticatedReadToken): boolean {
    return NhAccountSessionService.isAuthenticatedReadTokenCurrent(token) &&
      token.credentialRevision === NhAccountSessionService.credentialRevision &&
      token.credentialKind === NhAccountSessionService.nativeCredentialKind
  }

  /** A successfully recovered safe read adopts the current pair before replay. */
  static adoptCurrentAuthenticatedCredential(
    token: NhAccountAuthenticatedReadToken,
  ): boolean {
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
      return false
    }
    token.credentialRevision = NhAccountSessionService.credentialRevision
    token.credentialKind = NhAccountSessionService.nativeCredentialKind
    return true
  }

  static isApiKeyCredential(token: NhAccountAuthenticatedReadToken): boolean {
    return NhAccountSessionService.isAuthenticatedReadTokenCurrent(token) &&
      token.credentialKind === NhNativeCredentialKind.API_KEY &&
      NhAccountSessionService.nativeCredentialKind === NhNativeCredentialKind.API_KEY
  }

  /** A returned account identity may fill an ownerless new login, but never replace a known owner. */
  static authenticatedIdentityMatchesActiveAccount(accountId: string): boolean {
    const normalized: string = accountId.trim()
    if (!/^[1-9][0-9]*$/.test(normalized)) {
      return false
    }
    return NhAccountSessionService.activeSavedAccountId.length === 0 ||
      NhAccountSessionService.activeSavedAccountId === normalized
  }

  /**
   * Builds the fixed NH token-refresh body for the exact retained read epoch.
   * The value stays inside the account transport call, is never logged or
   * returned by JavaScript, and can target only the fixed first-party refresh
   * endpoint.
   */
  static authenticatedRefreshRequestBody(token: NhAccountAuthenticatedReadToken): string {
    if (!NhAccountSessionService.isAuthenticatedReadCredentialCurrent(token) ||
      token.credentialKind !== NhNativeCredentialKind.WEB_TOKEN) {
      return ''
    }
    const refreshCookie: SealedAuthCookie | undefined =
      NhAccountSessionService.sealedAuthCookies.find((cookie: SealedAuthCookie): boolean =>
        cookie.name === 'refresh_token' && cookie.value.length > 0)
    if (refreshCookie === undefined) {
      return ''
    }
    let refreshValue: string = refreshCookie.value
    try {
      refreshValue = decodeURIComponent(refreshValue)
    } catch (_error) {}
    return JSON.stringify({
      'refresh_token': refreshValue,
    })
  }

  /**
   * Returns the fixed API v2 authorization header for the exact retained
   * session epoch. The value never enters page state or feature code; only
   * `NhSessionHttpClient` may pass it to the private first-party transport.
   */
  static authenticatedAuthorization(token: NhAccountAuthenticatedReadToken): string {
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
      return ''
    }
    if (token.credentialKind === NhNativeCredentialKind.API_KEY) {
      const apiKey: string = NhAccountSessionService.safeApiToken(
        NhAccountSessionService.nativeApiKey,
      )
      return apiKey.length > 0 ? `Key ${apiKey}` : ''
    }
    const accessCookie: SealedAuthCookie | undefined =
      NhAccountSessionService.sealedAuthCookies.find((cookie: SealedAuthCookie): boolean =>
        cookie.name === 'access_token' && cookie.value.length > 0)
    if (accessCookie === undefined) {
      return ''
    }
    let accessValue: string = accessCookie.value
    try {
      accessValue = decodeURIComponent(accessValue)
    } catch (_error) {}
    return NhAccountSessionService.safeApiToken(accessValue).length > 0
      ? `User ${accessValue}`
      : ''
  }

  /**
   * Returns the account-owned Web authorization required by first-party
   * endpoints that explicitly reject API keys (currently comment mutations).
   * For an API-key account this reads only the optional Web snapshot sealed in
   * the same owner envelope; it never changes the native credential kind.
   */
  static authenticatedUserTokenAuthorization(token: NhAccountAuthenticatedReadToken): string {
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token) ||
      NhAccountSessionService.normalizeUserAgent(NhAccountSessionService.browserUserAgent).length === 0 ||
      !NhAccountSessionService.hasAccessAuthCookie(NhAccountSessionService.sealedAuthCookies) ||
      !NhAccountSessionService.hasRefreshAuthCookie(NhAccountSessionService.sealedAuthCookies)) {
      return ''
    }
    const accessCookie: SealedAuthCookie | undefined =
      NhAccountSessionService.sealedAuthCookies.find((cookie: SealedAuthCookie): boolean =>
        cookie.name === 'access_token' && cookie.value.length > 0)
    if (accessCookie === undefined) {
      return ''
    }
    let accessValue: string = accessCookie.value
    try {
      accessValue = decodeURIComponent(accessValue)
    } catch (_error) {}
    return NhAccountSessionService.safeApiToken(accessValue).length > 0
      ? `User ${accessValue}`
      : ''
  }

  /** Complete optional Web refresh body, fenced to the captured account epoch. */
  static authenticatedUserTokenRefreshRequestBody(token: NhAccountAuthenticatedReadToken): string {
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
      return ''
    }
    const refreshCookie: SealedAuthCookie | undefined =
      NhAccountSessionService.sealedAuthCookies.find((cookie: SealedAuthCookie): boolean =>
        cookie.name === 'refresh_token' && cookie.value.length > 0)
    if (refreshCookie === undefined) {
      return ''
    }
    let refreshValue: string = refreshCookie.value
    try {
      refreshValue = decodeURIComponent(refreshValue)
    } catch (_error) {}
    return NhAccountSessionService.safeApiToken(refreshValue).length > 0
      ? JSON.stringify({ 'refresh_token': refreshValue })
      : ''
  }

  /** Normalizes a user-supplied API key without ever publishing or logging it. */
  static normalizeApiKeyCandidate(value: string): string {
    const normalized: string = value.trim()
    if (normalized.length === 0 || /\s/.test(normalized) ||
      NhAccountSessionService.safeApiToken(normalized).length === 0) {
      return ''
    }
    return normalized
  }

  /**
   * Persists a candidate only after `NhSessionHttpClient` has verified it on
   * the fixed first-party account endpoint. Existing browser state is carried
   * only as optional, device-local Web compatibility state; it never becomes
   * the native request credential for this envelope.
   */
  static async promoteVerifiedApiKey(
    context: common.UIAbilityContext,
    candidate: string,
    accountId: string,
    browserSessionOwnedByCandidate: boolean = false,
    keyName: string = '',
  ): Promise<boolean> {
    const apiKey: string = NhAccountSessionService.normalizeApiKeyCandidate(candidate)
    const apiKeyName: string = NhAccountSessionService.normalizeApiKeyName(keyName)
    const normalizedAccountId: string = accountId.trim()
    if (apiKey.length === 0 || !/^[1-9][0-9]*$/.test(normalizedAccountId) ||
      NhAccountSessionService.sessionTransitionInFlight) {
      return false
    }
    NhAccountSessionService.sessionContext = context
    const browserSessionMatchesCandidate: boolean =
      NhBrowserSessionBoundary.browserSessionMatchesValidatedAccount(
        NhAccountSessionService.activeSavedAccountId,
        normalizedAccountId,
        browserSessionOwnedByCandidate,
      )
    const browserSessionComplete: boolean = browserSessionMatchesCandidate &&
      NhAccountSessionService.hasLoginCookies(NhAccountSessionService.cookieHeader) &&
      NhAccountSessionService.hasAccessAuthCookie(NhAccountSessionService.sealedAuthCookies) &&
      NhAccountSessionService.hasRefreshAuthCookie(NhAccountSessionService.sealedAuthCookies) &&
      NhAccountSessionService.normalizeUserAgent(NhAccountSessionService.browserUserAgent).length > 0
    const ownedCookieHeader: string = browserSessionComplete
      ? NhAccountSessionService.cookieHeader
      : ''
    const ownedBrowserUserAgent: string = browserSessionComplete
      ? NhAccountSessionService.browserUserAgent
      : ''
    const ownedAuthCookies: SealedAuthCookie[] = browserSessionComplete
      ? NhAccountSessionService.sealedAuthCookies
      : []
    const transitionEpoch: number = NhAccountSessionService.beginDurableSessionTransition()
    let record: EncryptedAccountSession
    try {
      record = await NhAccountSessionService.encrypt(
        NhAccountSessionService.serializeSessionPayload(
          ownedCookieHeader,
          ownedBrowserUserAgent,
          ownedAuthCookies,
          NhNativeCredentialKind.API_KEY,
          apiKey,
          apiKeyName,
        ),
      )
      await AccountSessionRepository.saveVerifiedForAccount(
        context,
        record,
        normalizedAccountId,
      )
      const persisted: AccountSessionRestoreSnapshot =
        await AccountSessionRepository.loadForRestore(context)
      if (persisted.record === null || persisted.record.ciphertext !== record.ciphertext ||
        persisted.record.nonce !== record.nonce) {
        throw new Error('account_api_key_persistence_readback_failed')
      }
      await NhAccountSessionService.persistRetainedAccountMarker(context, true)
    } catch (_error) {
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
      return false
    }
    if (!NhAccountSessionService.isDurableSessionTransitionCurrent(transitionEpoch)) {
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
      return false
    }
    NhAccountSessionService.advanceSessionEpoch()
    NhAccountSessionService.cookieHeader = ownedCookieHeader
    NhAccountSessionService.sealedFallbackCookieHeader = ownedCookieHeader
    NhAccountSessionService.sealedAuthCookies = ownedAuthCookies
    NhAccountSessionService.browserUserAgent = ownedBrowserUserAgent
    NhAccountSessionService.nativeCredentialKind = NhNativeCredentialKind.API_KEY
    NhAccountSessionService.nativeApiKey = apiKey
    NhAccountSessionService.nativeApiKeyName = apiKeyName
    NhAccountSessionService.nativeApiKeyIdentity =
      NhAccountSessionService.apiKeyIdentityForDisplay(apiKey)
    NhAccountSessionService.sessionOrigin = AccountSessionOrigin.PROMOTED
    NhAccountSessionService.activeSavedAccountId = normalizedAccountId
    NhAccountSessionService.lastSavedAccountCheckpointId = normalizedAccountId
    NhAccountSessionService.verificationRequiredMarkerPresent = false
    NhAccountSessionService.verificationRecoveryKind = 'web_login'
    NhAccountSessionService.retainedAccountPresent = true
    NhAccountSessionService.clearRetainedRestoreLoginGate()
    if (!browserSessionComplete) {
      NhAccountSessionService.discardPendingVisibleBrowserSession()
      NhAccountSessionService.resetRejectedVisibleBrowserSessionCandidate()
      NhAccountSessionService.expireVisibleBrowserIdentityCookies()
    }
    const profileClearTask: Promise<void> = NhAccountSessionService.clearAccountProfileSnapshot(context)
    NhAccountSessionService.publishSessionChange()
    try {
      await profileClearTask
      return true
    } finally {
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
    }
  }

  /**
   * Atomically checkpoints a successful official refresh response into the
   * HUKS envelope before the rejected request is replayed. This removes the
   * old split where ArkWeb could own a new token while native cold-start
   * storage still owned the rejected one.
   */
  static async applyRefreshedApiTokens(
    token: NhAccountAuthenticatedReadToken,
    accessToken: string,
    refreshToken: string,
    responseCookieSinkOwnedByCaller: boolean = false,
    verifiedAccountId: string = '',
  ): Promise<boolean> {
    if (!NhAccountSessionService.isAuthenticatedReadCredentialCurrent(token) ||
      token.credentialKind !== NhNativeCredentialKind.WEB_TOKEN) {
      return false
    }
    const access: string = NhAccountSessionService.safeApiToken(accessToken)
    const refresh: string = NhAccountSessionService.safeApiToken(refreshToken)
    const resolvedOwner: string | null = NhAccountSessionService.resolveAuthenticatedReadOwner(
      token,
      verifiedAccountId,
    )
    const context: common.UIAbilityContext | null = NhAccountSessionService.sessionContext
    if (resolvedOwner === null || access.length === 0 || refresh.length === 0 || context === null ||
      NhAccountSessionService.browserUserAgent.length === 0) {
      return false
    }
    const currentAccess: string = NhAccountSessionService.currentAuthCookieValue('access_token')
    const currentRefresh: string = NhAccountSessionService.currentAuthCookieValue('refresh_token')
    if (access === currentAccess && refresh === currentRefresh &&
      (resolvedOwner.length === 0 || resolvedOwner === NhAccountSessionService.activeSavedAccountId)) {
      return true
    }
    const authCookies: SealedAuthCookie[] = [
      NhAccountSessionService.apiTokenCookie('access_token', access, false),
      NhAccountSessionService.apiTokenCookie('refresh_token', refresh, true),
    ]
    const header: string = `access_token=${access}; refresh_token=${refresh}`
    const transitionEpoch: number = NhAccountSessionService.beginDurableSessionTransition(false)
    try {
      const record: EncryptedAccountSession = await NhAccountSessionService.encrypt(
        NhAccountSessionService.serializeSessionPayload(
          header,
          NhAccountSessionService.browserUserAgent,
          authCookies,
          NhNativeCredentialKind.WEB_TOKEN,
        ),
      )
      let checkpointed: boolean = false
      for (let attempt: number = 1; attempt <= AUTH_REFRESH_CHECKPOINT_MAX_ATTEMPTS; attempt += 1) {
        if (!NhAccountSessionService.isDurableSessionTransitionCurrent(transitionEpoch) ||
          !NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
          return false
        }
        try {
          await AccountSessionRepository.saveVerifiedForAccount(
            context,
            record,
            resolvedOwner,
          )
          const persisted: AccountSessionRestoreSnapshot =
            await AccountSessionRepository.loadForRestore(context)
          if (persisted.record === null ||
            persisted.record.ciphertext !== record.ciphertext ||
            persisted.record.nonce !== record.nonce) {
            throw new Error('account_refresh_checkpoint_readback_failed')
          }
          checkpointed = true
          if (attempt > 1) {
            DiagnosticLogger.info(
              'account-session',
              'account_refresh_checkpoint_recovered',
              `attempt=${attempt}`,
            )
          }
          break
        } catch (_error) {
          if (attempt >= AUTH_REFRESH_CHECKPOINT_MAX_ATTEMPTS) {
            DiagnosticLogger.warn(
              'account-session',
              'account_refresh_checkpoint_failed',
              `attempts=${AUTH_REFRESH_CHECKPOINT_MAX_ATTEMPTS}`,
            )
            break
          }
          DiagnosticLogger.warn(
            'account-session',
            'account_refresh_checkpoint_retry',
            `attempt=${attempt}`,
          )
          await NhAccountSessionService.delay(AUTH_REFRESH_CHECKPOINT_RETRY_DELAY_MS * attempt)
        }
      }
      if (!checkpointed) {
        return false
      }
      if (!NhAccountSessionService.isDurableSessionTransitionCurrent(transitionEpoch) ||
        !NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
        return false
      }
      NhAccountSessionService.cookieHeader = header
      NhAccountSessionService.sealedFallbackCookieHeader = header
      NhAccountSessionService.sealedAuthCookies = authCookies
      NhAccountSessionService.nativeCredentialKind = NhNativeCredentialKind.WEB_TOKEN
      NhAccountSessionService.nativeApiKey = ''
      NhAccountSessionService.nativeApiKeyName = ''
      NhAccountSessionService.nativeApiKeyIdentity = ''
      if (resolvedOwner.length > 0) {
        NhAccountSessionService.activeSavedAccountId = resolvedOwner
        NhAccountSessionService.lastSavedAccountCheckpointId = resolvedOwner
        token.accountId = resolvedOwner
      }
      NhAccountSessionService.credentialRevision += 1
      token.credentialRevision = NhAccountSessionService.credentialRevision
      NhAccountSessionService.recordAuthCookieExpiryShape('refresh_checkpoint', authCookies)
      // A response-Set-Cookie caller owns the later one-shot raw-header sink.
      // Writing JSON compatibility defaults here would create an intermediate
      // jar generation and then replace the server expiry/SameSite attributes.
      // Only a JSON token response without an authoritative Cookie sink needs
      // this compatibility hydration.
      if (!responseCookieSinkOwnedByCaller) {
        try {
          NhCookieAuthority.storeRefreshedAuthTokens(access, refresh)
        } catch (_error) {}
      }
      return true
    } catch (_error) {
      return false
    } finally {
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
    }
  }

  /**
   * Checkpoints a refreshed website token pair without replacing a stable
   * native API key. Legacy Web-token accounts reuse the ordinary native
   * checkpoint because their website token is also their native authority.
   */
  static async applyRefreshedUserTokens(
    token: NhAccountAuthenticatedReadToken,
    accessToken: string,
    refreshToken: string,
    responseCookieSinkOwnedByCaller: boolean = false,
    verifiedAccountId: string = '',
  ): Promise<boolean> {
    if (token.credentialKind === NhNativeCredentialKind.WEB_TOKEN) {
      return await NhAccountSessionService.applyRefreshedApiTokens(
        token,
        accessToken,
        refreshToken,
        responseCookieSinkOwnedByCaller,
        verifiedAccountId,
      )
    }
    if (!NhAccountSessionService.isAuthenticatedReadCredentialCurrent(token) ||
      token.credentialKind !== NhNativeCredentialKind.API_KEY) {
      return false
    }
    const access: string = NhAccountSessionService.safeApiToken(accessToken)
    const refresh: string = NhAccountSessionService.safeApiToken(refreshToken)
    const apiKey: string = NhAccountSessionService.safeApiToken(
      NhAccountSessionService.nativeApiKey,
    )
    const resolvedOwner: string | null = NhAccountSessionService.resolveAuthenticatedReadOwner(
      token,
      verifiedAccountId,
    )
    const context: common.UIAbilityContext | null = NhAccountSessionService.sessionContext
    if (resolvedOwner === null || resolvedOwner.length === 0 || access.length === 0 ||
      refresh.length === 0 || apiKey.length === 0 || context === null ||
      NhAccountSessionService.normalizeUserAgent(NhAccountSessionService.browserUserAgent).length === 0) {
      return false
    }
    const authCookies: SealedAuthCookie[] =
      NhAccountSessionService.sealedAuthCookies.filter((cookie: SealedAuthCookie): boolean =>
        cookie.name !== 'access_token' && cookie.name !== 'refresh_token')
    authCookies.push(NhAccountSessionService.apiTokenCookie('access_token', access, false))
    authCookies.push(NhAccountSessionService.apiTokenCookie('refresh_token', refresh, true))
    authCookies.sort((left: SealedAuthCookie, right: SealedAuthCookie): number => {
      const leftKey: string = `${left.name}|${left.domain}|${left.path}`
      const rightKey: string = `${right.name}|${right.domain}|${right.path}`
      return leftKey.localeCompare(rightKey)
    })
    const header: string = NhAccountSessionService.mergeCookieHeaders([
      NhAccountSessionService.cookieHeader,
      `access_token=${access}; refresh_token=${refresh}`,
    ])
    if (!NhAccountSessionService.hasLoginCookies(header)) {
      return false
    }
    const transitionEpoch: number = NhAccountSessionService.beginDurableSessionTransition(false)
    try {
      const record: EncryptedAccountSession = await NhAccountSessionService.encrypt(
        NhAccountSessionService.serializeSessionPayload(
          header,
          NhAccountSessionService.browserUserAgent,
          authCookies,
          NhNativeCredentialKind.API_KEY,
          apiKey,
          NhAccountSessionService.nativeApiKeyName,
        ),
      )
      await AccountSessionRepository.saveVerifiedForAccount(context, record, resolvedOwner)
      const persisted: AccountSessionRestoreSnapshot =
        await AccountSessionRepository.loadForRestore(context)
      if (persisted.record === null || persisted.record.ciphertext !== record.ciphertext ||
        persisted.record.nonce !== record.nonce ||
        !NhAccountSessionService.isDurableSessionTransitionCurrent(transitionEpoch) ||
        !NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
        return false
      }
      NhAccountSessionService.cookieHeader = header
      NhAccountSessionService.sealedFallbackCookieHeader = header
      NhAccountSessionService.sealedAuthCookies = authCookies
      NhAccountSessionService.recordAuthCookieExpiryShape('website_refresh_checkpoint', authCookies)
      if (!responseCookieSinkOwnedByCaller) {
        try {
          NhCookieAuthority.storeRefreshedAuthTokens(access, refresh)
        } catch (_error) {}
      }
      return true
    } catch (_error) {
      return false
    } finally {
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
    }
  }

  /**
   * Applies every successful first-party response's auth Set-Cookie values to
   * the same HUKS/RDB generation used by Authorization and cold restore. A
   * partial rotation is completed only from the current fenced pair; malformed
   * or conflicting auth cookies reject the response checkpoint.
   */
  static async applyResponseAuthSetCookies(
    token: NhAccountAuthenticatedReadToken,
    setCookieHeaders: string[],
    verifiedAccountId: string = '',
  ): Promise<NhResponseAuthCookieResult> {
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
      return NhResponseAuthCookieResult.REJECTED
    }
    const responseAccess: string | null = NhAccountSessionService.responseAuthCookieValue(
      setCookieHeaders,
      'access_token',
    )
    const responseRefresh: string | null = NhAccountSessionService.responseAuthCookieValue(
      setCookieHeaders,
      'refresh_token',
    )
    if (responseAccess === null && responseRefresh === null) {
      return NhResponseAuthCookieResult.NONE
    }
    if (responseAccess === '' || responseRefresh === '') {
      return NhResponseAuthCookieResult.REJECTED
    }
    const access: string = responseAccess ??
      NhAccountSessionService.currentAuthCookieValue('access_token')
    const refresh: string = responseRefresh ??
      NhAccountSessionService.currentAuthCookieValue('refresh_token')
    if (access.length === 0 || refresh.length === 0 ||
      !await NhAccountSessionService.applyRefreshedUserTokens(
        token,
        access,
        refresh,
        true,
        verifiedAccountId,
      )) {
      return NhResponseAuthCookieResult.REJECTED
    }
    return NhResponseAuthCookieResult.APPLIED
  }

  /**
   * Returns the remaining server-directed refresh cooldown. This marker is
   * deliberately process-independent: Account and Favorites can be opened in
   * separate app processes during S0, and neither may turn one 429 into a
   * second refresh attempt. The stored value is only a timestamp.
   */
  static async authenticatedRefreshCooldownRemainingMs(
    token: NhAccountAuthenticatedReadToken,
  ): Promise<number> {
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
      return AUTH_REFRESH_MIN_COOLDOWN_MS
    }
    const context: common.UIAbilityContext | null = NhAccountSessionService.sessionContext
    if (context === null) {
      return 0
    }
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, ACCOUNT_STATE_STORE)
      const retryAtValue: preferences.ValueType = store.getSync(AUTH_REFRESH_RETRY_AT_KEY, 0)
      const retryAtMs: number = typeof retryAtValue === 'number' && Number.isFinite(retryAtValue)
        ? Math.floor(retryAtValue)
        : 0
      return Math.max(0, retryAtMs - Date.now())
    } catch (_error) {
      return 0
    }
  }

  /** Persists only a bounded next-attempt timestamp after a refresh 429. */
  static async recordAuthenticatedRefreshCooldown(
    token: NhAccountAuthenticatedReadToken,
    retryAfterMs: number,
  ): Promise<void> {
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
      return
    }
    const context: common.UIAbilityContext | null = NhAccountSessionService.sessionContext
    if (context === null) {
      return
    }
    const requestedMs: number = Number.isFinite(retryAfterMs) && retryAfterMs > 0
      ? Math.floor(retryAfterMs)
      : AUTH_REFRESH_DEFAULT_COOLDOWN_MS
    const boundedMs: number = Math.min(
      AUTH_REFRESH_MAX_COOLDOWN_MS,
      Math.max(AUTH_REFRESH_MIN_COOLDOWN_MS, requestedMs),
    )
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, ACCOUNT_STATE_STORE)
      store.putSync(AUTH_REFRESH_RETRY_AT_KEY, Date.now() + boundedMs)
      store.flushSync()
      DiagnosticLogger.info(
        'account-session',
        'account_authenticated_read_refresh_cooldown_recorded',
        `seconds=${Math.ceil(boundedMs / 1000)}`,
      )
    } catch (_error) {}
  }

  /** A successful rotation removes any prior server-rate-limit marker. */
  static async clearAuthenticatedRefreshCooldown(
    token: NhAccountAuthenticatedReadToken,
  ): Promise<void> {
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(token)) {
      return
    }
    const context: common.UIAbilityContext | null = NhAccountSessionService.sessionContext
    if (context === null) {
      return
    }
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, ACCOUNT_STATE_STORE)
      store.deleteSync(AUTH_REFRESH_RETRY_AT_KEY)
      store.flushSync()
    } catch (_error) {}
  }

  /** Returns one fixed lifecycle code only; safe for redacted acceptance diagnostics. */
  static latestDiagnosticStageCode(): string {
    return NhAccountSessionService.latestDiagnosticStage
  }

  /** True only while a retained sealed record needs an explicit replacement decision. */
  static requiresExplicitVisibleLoginAction(): boolean {
    return NhAccountSessionService.retainedRestoreRequiresExplicitLogin ||
      NhAccountSessionService.verificationRequiredMarkerPresent
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
    if (NhAccountSessionService.requiresExplicitVisibleLoginAction()) {
      NhAccountSessionService.explicitVisibleLoginActionRegistered = false
    }
  }

  /** Defense in depth for any visible-login caller, not just BrowserSessionPage. */
  static canOpenVisibleLoginSession(): boolean {
    return !NhAccountSessionService.requiresExplicitVisibleLoginAction() ||
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

  /** Produces the proven NextE-compatible UA shape for visible and retained hosts. */
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
    if (userAgent.length > 0 && NhAccountSessionService.browserUserAgent.length === 0 &&
      NhAccountSessionService.pendingBrowserUserAgent.length === 0) {
      // The visible ArkWeb login controller has now chosen the exact compatible UA
      // used for this live browser session. Keep it as part of the session
      // snapshot so a successful response cannot re-seal a valid Cookie tuple
      // with an empty UA and make the next cold restore reject the envelope.
      NhAccountSessionService.browserUserAgent = userAgent
    }
    return userAgent
  }

  static async restoreAtBootstrap(context: common.UIAbilityContext): Promise<boolean> {
    NhAccountSessionService.sessionContext = context
    await NhAccountSessionService.loadRetainedAccountMarker(context)
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
   * Re-runs the non-visible RDB/HUKS recovery for a retained account.
   * It never opens a login page, changes account ownership, or clears cached
   * profile/content when the transport remains unavailable.
   */
  static async repairAuthentication(): Promise<boolean> {
    if (NhAccountSessionService.isAuthenticated()) {
      return true
    }
    const context: common.UIAbilityContext | null = NhAccountSessionService.sessionContext
    if (context === null || !NhAccountSessionService.retainedAccountPresent ||
      NhAccountSessionService.verificationRequiredMarkerPresent) {
      return false
    }
    const restored: boolean = await NhAccountSessionService.restoreAtBootstrap(context)
    NhAccountSessionService.publishSessionChange()
    return restored && NhAccountSessionService.isAuthenticated()
  }

  /**
   * EntryAbility calls this once after its single cold-start restore attempt.
   * It publishes only non-secret state, so pages can render without becoming
   * secondary owners of RDB/HUKS recovery.
   */
  static publishBootstrapState(): void {
    NhAccountSessionService.publishCurrentSessionState()
  }

  /**
   * Makes a valid sealed browser identity usable by the regular ArkWeb store.
   * The visible login and the retained transport share that store, but a
   * process restart can retain the encrypted record while losing or partially
   * advancing a session cookie. Never write outside the fixed first-party root;
   * only a jar matching the sealed request generation can suppress hydration.
   */
  static async ensureRegularArkWebCookieJar(): Promise<boolean> {
    const sealedCookieHeader: string = NhAccountSessionService.sealedFallbackCookieHeader
    const hydrationEpoch: number = NhAccountSessionService.sessionEpoch
    if (!NhAccountSessionService.hasLoginCookies(NhAccountSessionService.cookieHeader)) {
      return false
    }
    if (!NhAccountSessionService.hasLoginCookies(sealedCookieHeader)) {
      return false
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

  /** Persist ArkWeb's complete live cookie jar after browser-managed updates. */
  static async persistBrowserManagedCookies(): Promise<void> {
    try {
      NhCookieAuthority.saveCookieSync()
    } catch (_error) {
      try {
        await NhCookieAuthority.saveCookieAsync()
      } catch (_asyncError) {}
    }
  }

  /**
   * Retains only the presence/HttpOnly shape of the three NH identity cookie
   * names. Values, domains, paths, expirations, URLs, and account data never
   * enter diagnostics. This distinguishes a stale access token with a usable
   * refresh identity from a browser jar that has already lost that identity.
   */
  static async recordBrowserAuthCookieShape(phase: string): Promise<void> {
    let accessPresent: boolean = false
    let accessHttpOnly: boolean = false
    let refreshPresent: boolean = false
    let refreshHttpOnly: boolean = false
    let sessionPresent: boolean = false
    let sessionHttpOnly: boolean = false
    try {
      const cookies: webview.WebHttpCookie[] = await NhCookieAuthority.fetchAllAuthCookies()
      for (let index: number = 0; index < cookies.length; index++) {
        const cookie: webview.WebHttpCookie = cookies[index]
        const domain: string = cookie.domain.trim().toLowerCase().replace(/^\./, '')
        if (domain !== 'nhentai.net' && !domain.endsWith('.nhentai.net')) {
          continue
        }
        if (cookie.name === 'access_token') {
          accessPresent = cookie.value.length > 0
          accessHttpOnly = cookie.isHttpOnly
        } else if (cookie.name === 'refresh_token') {
          refreshPresent = cookie.value.length > 0
          refreshHttpOnly = cookie.isHttpOnly
        } else if (cookie.name === 'sessionid') {
          sessionPresent = cookie.value.length > 0
          sessionHttpOnly = cookie.isHttpOnly
        }
      }
      DiagnosticLogger.info(
        'account-session',
        'account_browser_cookie_shape',
        `phase=${phase};access=${accessPresent ? 1 : 0};accessHttpOnly=${accessHttpOnly ? 1 : 0};` +
          `refresh=${refreshPresent ? 1 : 0};refreshHttpOnly=${refreshHttpOnly ? 1 : 0};` +
          `session=${sessionPresent ? 1 : 0};sessionHttpOnly=${sessionHttpOnly ? 1 : 0}`,
      )
    } catch (_error) {
      DiagnosticLogger.info(
        'account-session',
        'account_browser_cookie_shape_unavailable',
        `phase=${phase}`,
      )
    }
  }

  /**
   * Records only coarse expiry classes for the sealed access/refresh pair.
   * It never emits a Cookie value, exact expiry, token-derived identifier,
   * account value, domain, path, or user agent.
   */
  private static recordAuthCookieExpiryShape(
    phase: string,
    cookies: SealedAuthCookie[],
  ): void {
    DiagnosticLogger.info(
      'account-session',
      'account_auth_expiry_shape',
      `phase=${phase};` +
        `access=${NhAccountSessionService.authCookieExpiryClass(cookies, 'access_token')};` +
        `refresh=${NhAccountSessionService.authCookieExpiryClass(cookies, 'refresh_token')}`,
    )
  }

  private static authCookieExpiryClass(
    cookies: SealedAuthCookie[],
    name: string,
  ): string {
    const cookie: SealedAuthCookie | undefined = cookies.find(
      (candidate: SealedAuthCookie): boolean => candidate.name === name,
    )
    if (cookie === undefined) {
      return 'absent'
    }
    const rawExpiry: string = cookie.expiresDate.trim()
    if (rawExpiry.length === 0) {
      return cookie.isSessionCookie ? 'session' : 'unknown'
    }
    let deadlineMs: number = Number.NaN
    if (/^[0-9]{10,13}$/.test(rawExpiry)) {
      const numericExpiry: number = Number(rawExpiry)
      deadlineMs = rawExpiry.length <= 10 ? numericExpiry * 1000 : numericExpiry
    } else {
      deadlineMs = Date.parse(rawExpiry)
    }
    if (!Number.isFinite(deadlineMs)) {
      return 'unknown'
    }
    const remainingMs: number = deadlineMs - Date.now()
    if (remainingMs <= 0) {
      return 'expired'
    }
    if (remainingMs <= AUTH_EXPIRY_ONE_HOUR_MS) {
      return 'lt_1h'
    }
    if (remainingMs <= AUTH_EXPIRY_ONE_DAY_MS) {
      return 'lt_24h'
    }
    if (remainingMs <= AUTH_EXPIRY_ONE_WEEK_MS) {
      return 'lt_7d'
    }
    return 'ge_7d'
  }

  /** Records a successful request without creating a second authentication authority. */
  static markAuthenticatedRequestVerified(): void {
    if (!NhAccountSessionService.isAuthenticated()) {
      return
    }
    NhAccountSessionService.retainedAccountPresent = true
  }

  /**
   * Clears the native sealed session and only first-party identity cookies
   * from this app's regular ArkWeb store. Cloudflare challenge state is not
   * identity state and is deliberately retained, matching NextE's logout
   * boundary so a later user-initiated login does not have to restart a
   * managed challenge unnecessarily.
   */
  static async clear(
    context: common.UIAbilityContext,
    savedAccountId: string = '',
  ): Promise<void> {
    NhAccountSessionService.sessionContext = context
    // A durable clear must not interleave with a verified promotion or a
    // sealed-envelope re-seal that is already writing RDB. Otherwise the
    // older writer can commit a record after this clear's DELETE, and a
    // cold start would restore a session the user just signed out of.
    // Wait for any in-flight transition to finish (bounded), then own the
    // durable boundary exclusively.
    let transitionWaitMs: number = 0
    while (NhAccountSessionService.sessionTransitionInFlight) {
     if (transitionWaitMs >= 500) {
       throw new Error('account_session_clear_busy')
     }
      await NhAccountSessionService.delay(100)
      transitionWaitMs += 100
    }
   const transitionEpoch: number = NhAccountSessionService.beginDurableSessionTransition()
    try {
      await AccountSessionRepository.clear(context, savedAccountId)
      await NhAccountSessionService.persistRetainedAccountMarker(context, false)
      const store: preferences.Preferences = await preferences.getPreferences(context, ACCOUNT_STATE_STORE)
      store.deleteSync(AUTH_REFRESH_RETRY_AT_KEY)
      store.flushSync()
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
    NhAccountSessionService.verificationRecoveryKind = 'web_login'
    NhAccountSessionService.retainedAccountPresent = false
    NhAccountSessionService.activeSavedAccountId = ''
    NhAccountSessionService.lastSavedAccountCheckpointId = ''
    NhAccountSessionService.clearRetainedRestoreLoginGate()
    NhAccountSessionService.advanceSessionEpoch()
    NhAccountSessionService.cookieHeader = ''
    NhAccountSessionService.sealedFallbackCookieHeader = ''
    NhAccountSessionService.sealedAuthCookies = []
    NhAccountSessionService.browserUserAgent = ''
    NhAccountSessionService.nativeCredentialKind = NhNativeCredentialKind.NONE
    NhAccountSessionService.nativeApiKey = ''
    NhAccountSessionService.nativeApiKeyName = ''
    NhAccountSessionService.nativeApiKeyIdentity = ''
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
   * A replayed account-owned 401 after the bounded refresh chain is definitive.
   * Keep the encrypted account and saved-account ownership, but atomically
   * persist and publish one explicit re-verification gate to every consumer.
   */
  static async recordAuthenticatedReadReplay401(
    token: NhAccountAuthenticatedReadToken,
  ): Promise<boolean> {
    return await NhAccountSessionService.recordAuthenticatedVerificationRequired(
      token,
      'terminal_401_replay_rejected',
      true,
    )
  }

  /** A direct 401 from the fixed refresh endpoint conclusively rejects the retained renewal token. */
  static async recordAuthenticatedRefreshToken401(
    token: NhAccountAuthenticatedReadToken,
  ): Promise<boolean> {
    if (!NhAccountSessionService.isAuthenticatedReadCredentialCurrent(token)) {
      NhAccountSessionService.recordAuthenticatedReadStale401AfterRefresh()
      return false
    }
    NhAccountSessionService.recordDiagnosticStage(
      AccountSessionDiagnosticStage.AUTHENTICATED_READ_REFRESH_TOKEN_REJECTED,
    )
    return await NhAccountSessionService.recordAuthenticatedVerificationRequired(
      token,
      'terminal_401_refresh_token_rejected',
      true,
    )
  }

  /** A fixed account-endpoint 401/403 conclusively rejects an API key. */
  static async recordAuthenticatedApiKeyRejected(
    token: NhAccountAuthenticatedReadToken,
  ): Promise<boolean> {
    if (!NhAccountSessionService.isAuthenticatedReadCredentialCurrent(token) ||
      token.credentialKind !== NhNativeCredentialKind.API_KEY) {
      return false
    }
    NhAccountSessionService.recordDiagnosticStage(
      AccountSessionDiagnosticStage.AUTHENTICATED_READ_API_KEY_REJECTED,
    )
    return await NhAccountSessionService.recordAuthenticatedVerificationRequired(
      token,
      'terminal_api_key_rejected',
      true,
    )
  }

  /** A successful account response for a different saved owner is terminal for that credential binding. */
  static async recordAuthenticatedIdentityMismatch(
    token: NhAccountAuthenticatedReadToken,
  ): Promise<boolean> {
    if (!NhAccountSessionService.isAuthenticatedReadCredentialCurrent(token)) {
      return false
    }
    NhAccountSessionService.recordDiagnosticStage(
      AccountSessionDiagnosticStage.AUTHENTICATED_READ_IDENTITY_MISMATCH,
    )
    return await NhAccountSessionService.recordAuthenticatedVerificationRequired(
      token,
      token.credentialKind === NhNativeCredentialKind.API_KEY
        ? 'terminal_api_key_identity_mismatch'
        : 'terminal_web_token_identity_mismatch',
      false,
    )
  }

  private static async recordAuthenticatedVerificationRequired(
    token: NhAccountAuthenticatedReadToken,
    markerReason: string,
    recordTerminal401Stage: boolean,
  ): Promise<boolean> {
    if (!NhAccountSessionService.isAuthenticatedReadCredentialCurrent(token)) {
      return false
    }
    if (recordTerminal401Stage &&
      NhAccountSessionService.sessionOrigin === AccountSessionOrigin.RESTORED) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.AUTHENTICATED_READ_TERMINAL_401_AFTER_RESTORE,
      )
    } else if (recordTerminal401Stage &&
      NhAccountSessionService.sessionOrigin === AccountSessionOrigin.PROMOTED) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.AUTHENTICATED_READ_TERMINAL_401_AFTER_PROMOTION,
      )
    }
    // Claim this exact read epoch synchronously before the durable write. A
    // later clear or verified promotion may supersede this transition; its
    // queued envelope write also clears the marker in the same RDB transaction.
    const transitionEpoch: number = NhAccountSessionService.beginDurableSessionTransition()
    const context: common.UIAbilityContext | null = NhAccountSessionService.sessionContext
    try {
      if (context === null) {
        throw new Error('account_verification_marker_context_missing')
      }
      await AccountSessionRepository.markVerificationRequired(
        context,
        markerReason,
      )
    } catch (_error) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.VERIFICATION_MARKER_PERSIST_FAILED,
      )
    }
    if (!NhAccountSessionService.isDurableSessionTransitionCurrent(transitionEpoch) ||
      token.sessionEpoch !== NhAccountSessionService.sessionEpoch) {
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
      return false
    }
    // A local marker-write failure must not turn a definitive server rejection
    // into a silent request error. Publish the same fail-closed runtime state
    // now; a later cold-start/foreground probe will retry the durable marker
    // path if the local store was temporarily unavailable.
    NhAccountSessionService.verificationRequiredMarkerPresent = true
    const apiKeyRecovery: boolean = NhAccountSessionService.isApiKeyRecoveryReason(markerReason)
    NhAccountSessionService.verificationRecoveryKind = apiKeyRecovery ? 'api_key' : 'web_login'
    NhAccountSessionService.retainedAccountPresent = true
    NhAccountSessionService.updateRetainedRestoreLoginGate(true)
    NhAccountSessionService.advanceSessionEpoch()
    if (!apiKeyRecovery) {
      NhAccountSessionService.cookieHeader = ''
      NhAccountSessionService.sealedFallbackCookieHeader = ''
      NhAccountSessionService.sealedAuthCookies = []
      NhAccountSessionService.browserUserAgent = ''
    }
    NhAccountSessionService.nativeCredentialKind = NhNativeCredentialKind.NONE
    NhAccountSessionService.nativeApiKey = ''
    NhAccountSessionService.sessionOrigin = AccountSessionOrigin.NONE
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhAccountSessionService.resetRejectedVisibleBrowserSessionCandidate()
    NhAccountSessionService.publishSessionChange()
    NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
    return true
  }

  private static isApiKeyRecoveryReason(reasonCode: string): boolean {
    return reasonCode === 'terminal_api_key_rejected' ||
      reasonCode === 'terminal_api_key_identity_mismatch'
  }

  /** Fixed, non-secret stages for the bounded authenticated-read repair chain. */
  static recordAuthenticatedReadInitial401(): void {
    NhAccountSessionService.recordAuthCookieExpiryShape(
      'initial_401',
      NhAccountSessionService.sealedAuthCookies,
    )
    NhAccountSessionService.recordDiagnosticStage(
      AccountSessionDiagnosticStage.AUTHENTICATED_READ_INITIAL_401,
    )
  }

  static recordAuthenticatedReadStale401AfterRefresh(): void {
    NhAccountSessionService.recordDiagnosticStage(
      AccountSessionDiagnosticStage.AUTHENTICATED_READ_STALE_401_AFTER_REFRESH,
    )
  }

  static recordAuthenticatedReadBrowserRefresh(ready: boolean): void {
    NhAccountSessionService.recordDiagnosticStage(ready
      ? AccountSessionDiagnosticStage.AUTHENTICATED_READ_BROWSER_REFRESH_READY
      : AccountSessionDiagnosticStage.AUTHENTICATED_READ_BROWSER_REFRESH_UNAVAILABLE)
  }

  static recordAuthenticatedReadRefreshEndpoint(statusCode: number): void {
    const ready: boolean = statusCode >= 200 && statusCode < 300
    DiagnosticLogger.info(
      'account-session',
      'account_authenticated_read_refresh_endpoint_status',
      `status=${statusCode}`,
    )
    NhAccountSessionService.recordDiagnosticStage(ready
      ? AccountSessionDiagnosticStage.AUTHENTICATED_READ_REFRESH_ENDPOINT_READY
      : AccountSessionDiagnosticStage.AUTHENTICATED_READ_REFRESH_ENDPOINT_UNAVAILABLE)
  }

  static recordAuthenticatedReadRefreshResponseRejected(): void {
    NhAccountSessionService.recordDiagnosticStage(
      AccountSessionDiagnosticStage.AUTHENTICATED_READ_REFRESH_RESPONSE_REJECTED,
    )
  }

  static recordAuthenticatedReadBrowserReplay(returned401: boolean): void {
    NhAccountSessionService.recordDiagnosticStage(returned401
      ? AccountSessionDiagnosticStage.AUTHENTICATED_READ_BROWSER_REPLAY_401
      : AccountSessionDiagnosticStage.AUTHENTICATED_READ_BROWSER_REPLAY_RECOVERED)
  }

  /** Fixed, value-free evidence for the global first-party response Cookie boundary. */
  static recordResponseCookieCheckpoint(
    compatibilityStored: boolean,
    authResult: NhResponseAuthCookieResult,
  ): void {
    if (!compatibilityStored || authResult === NhResponseAuthCookieResult.REJECTED) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.RESPONSE_COOKIE_REJECTED,
      )
      return
    }
    NhAccountSessionService.recordDiagnosticStage(
      AccountSessionDiagnosticStage.RESPONSE_COOKIE_STORED,
    )
    if (authResult === NhResponseAuthCookieResult.APPLIED) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.RESPONSE_AUTH_COOKIE_APPLIED,
      )
    }
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

  /** Fixed pending-candidate header used only for the one verification GET. */
  static pendingApiTokenAuthorization(): string {
    const access: string = NhAccountSessionService.cookieValue(
      NhAccountSessionService.pendingCookieHeader,
      'access_token',
    )
    return NhAccountSessionService.safeApiToken(access).length > 0 ? `User ${access}` : ''
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
      NhCookieAuthority.saveCookieSync()
    } catch (_error) {
      try {
        await NhCookieAuthority.saveCookieAsync()
      } catch (_asyncError) {}
    }
    const rawHeaders: string[] = []
    NhBrowserSessionBoundary.trustedSessionUrls(observedUrl).forEach((url: string): void => {
      try {
        rawHeaders.push(NhCookieAuthority.fetchCookieSync(url, false))
      } catch (_error) {}
    })
    const normalized: string = NhAccountSessionService.mergeCookieHeaders(rawHeaders)
    const normalizedUserAgent: string = NhAccountSessionService.normalizeUserAgent(browserUserAgent)
    const authCookies: SealedAuthCookie[] =
      await NhAccountSessionService.captureVisibleCandidateAuthCookies(normalized)
    const headerAccessAvailable: boolean = NhAccountSessionService.hasLoginCookies(normalized)
    const userAgentAvailable: boolean = normalizedUserAgent.length > 0
    const authAccessAvailable: boolean = NhAccountSessionService.hasAccessAuthCookie(authCookies)
    const renewalAvailable: boolean = NhAccountSessionService.hasRefreshAuthCookie(authCookies)
    if (!headerAccessAvailable || !userAgentAvailable || !authAccessAvailable || !renewalAvailable) {
      const navigationEpoch: number = NhAccountSessionService.visibleLoginNavigationEpoch
      if (navigationEpoch > 0 &&
        NhAccountSessionService.candidateShapeDiagnosticEpoch !== navigationEpoch) {
        NhAccountSessionService.candidateShapeDiagnosticEpoch = navigationEpoch
        DiagnosticLogger.info(
          'account-login',
          'candidate_shape_incomplete',
          `headerAccess=${headerAccessAvailable ? 1 : 0};ua=${userAgentAvailable ? 1 : 0};` +
            `authCount=${authCookies.length};authAccess=${authAccessAvailable ? 1 : 0};` +
            `renewal=${renewalAvailable ? 1 : 0};` +
            `refresh=${NhAccountSessionService.hasNamedAuthCookie(authCookies, 'refresh_token') ? 1 : 0};` +
            `session=${NhAccountSessionService.hasNamedAuthCookie(authCookies, 'sessionid') ? 1 : 0};` +
            `legacy=${NhAccountSessionService.hasNamedAuthCookie(authCookies, 'ipb_pass_hash') ? 1 : 0}`,
        )
      }
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
      await NhCookieAuthority.saveCookieAsync()
    } catch (_error) {}
    NhAccountSessionService.pendingCookieHeader = normalized
    NhAccountSessionService.pendingBrowserUserAgent = normalizedUserAgent
    NhAccountSessionService.pendingAuthCookies = authCookies
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
    const verifiedAuthCookieFingerprint: string = NhAccountSessionService.authCookieFingerprint(
      NhAccountSessionService.pendingAuthCookies,
    )
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
      NhAccountSessionService.pendingBrowserUserAgent === verifiedBrowserUserAgent &&
      NhAccountSessionService.authCookieFingerprint(NhAccountSessionService.pendingAuthCookies) ===
        verifiedAuthCookieFingerprint
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

  private static async confirmPendingBrowserSession(context: common.UIAbilityContext): Promise<boolean> {
    NhAccountSessionService.sessionContext = context
    if (!NhAccountSessionService.hasLoginCookies(NhAccountSessionService.pendingCookieHeader) ||
      NhAccountSessionService.pendingBrowserUserAgent.length === 0 ||
      !NhAccountSessionService.hasAccessAuthCookie(NhAccountSessionService.pendingAuthCookies) ||
      !NhAccountSessionService.hasRefreshAuthCookie(NhAccountSessionService.pendingAuthCookies)) {
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
          NhAccountSessionService.pendingAuthCookies,
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
      await NhAccountSessionService.persistRetainedAccountMarker(context, true)
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
    NhAccountSessionService.sealedAuthCookies = NhAccountSessionService.pendingAuthCookies
    NhAccountSessionService.nativeCredentialKind = NhNativeCredentialKind.WEB_TOKEN
    NhAccountSessionService.nativeApiKey = ''
    NhAccountSessionService.nativeApiKeyName = ''
    NhAccountSessionService.nativeApiKeyIdentity = ''
    NhAccountSessionService.recordAuthCookieExpiryShape(
      'visible_promotion',
      NhAccountSessionService.sealedAuthCookies,
    )
    NhAccountSessionService.browserUserAgent = NhAccountSessionService.pendingBrowserUserAgent
    NhAccountSessionService.sessionOrigin = AccountSessionOrigin.PROMOTED
    // The visible credential has replaced the active owner. Its stable user id
    // is established by the first account response and must not be inherited
    // from the account that opened the add-account flow.
    NhAccountSessionService.activeSavedAccountId = ''
    NhAccountSessionService.lastSavedAccountCheckpointId = ''
    NhAccountSessionService.verificationRequiredMarkerPresent = false
    NhAccountSessionService.verificationRecoveryKind = 'web_login'
    NhAccountSessionService.retainedAccountPresent = true
    NhAccountSessionService.clearRetainedRestoreLoginGate()
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhAccountSessionService.resetRejectedVisibleBrowserSessionCandidate()
    const promotedAccess: string = NhAccountSessionService.cookieValue(
      NhAccountSessionService.sealedFallbackCookieHeader,
      'access_token',
    )
    const promotedRefresh: SealedAuthCookie | undefined =
      NhAccountSessionService.sealedAuthCookies.find((cookie: SealedAuthCookie): boolean =>
        cookie.name === 'refresh_token')
    try {
      NhCookieAuthority.storeRefreshedAuthTokens(
        promotedAccess,
        promotedRefresh?.value ?? '',
      )
    } catch (_error) {}
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
    NhAccountSessionService.pendingAuthCookies = []
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

  /** Backup export: portable mode strips every device-local Web session field. */
  static async exportSealedForBackup(
    context: common.UIAbilityContext,
    portable: boolean = true,
  ): Promise<string | null> {
    const snapshot: AccountSessionRestoreSnapshot = await AccountSessionRepository.loadForRestore(context)
    const record: EncryptedAccountSession | null = snapshot.record
    if (record === null) {
      return null
    }
    const plaintext: string = await NhAccountSessionService.decryptWithExistingKey(record)
    return portable ? NhAccountSessionService.portableApiKeyPayload(plaintext) : plaintext
  }

  /** Exports API-key accounts portably, or a full local-only rollback snapshot. */
  static async exportAllSealedForBackup(
    context: common.UIAbilityContext,
    portable: boolean = true,
  ): Promise<string> {
    const snapshot: AccountSessionRestoreSnapshot = await AccountSessionRepository.loadForRestore(context)
    const bundle: AccountSessionBackupBundle = new AccountSessionBackupBundle()
    bundle.version = portable ? 2 : 1
    if (snapshot.record !== null) {
      const plaintext: string = await NhAccountSessionService.decryptWithExistingKey(snapshot.record)
      const exportPayload: string | null = portable
        ? NhAccountSessionService.portableApiKeyPayload(plaintext)
        : plaintext
      if (exportPayload !== null) {
        bundle.activePayload = exportPayload
        NhAccountSessionService.validateBackupSessionPayload(bundle.activePayload, portable)
      }
    }
    if (snapshot.savedKeys.length !== snapshot.savedRecords.length) {
      throw new Error('account_session_backup_shape_invalid')
    }
    const seen: Set<string> = new Set<string>()
    for (let i: number = 0; i < snapshot.savedKeys.length; i++) {
      const accountId: string = NhAccountSessionService.validateBackupAccountId(snapshot.savedKeys[i])
      if (seen.has(accountId)) {
        throw new Error('account_session_backup_shape_invalid')
      }
      seen.add(accountId)
      const entry: AccountSessionBackupEntry = new AccountSessionBackupEntry()
      entry.accountId = accountId
      const plaintext: string = await NhAccountSessionService.decryptWithExistingKey(snapshot.savedRecords[i])
      const exportPayload: string | null = portable
        ? NhAccountSessionService.portableApiKeyPayload(plaintext)
        : plaintext
      if (exportPayload !== null) {
        entry.payload = exportPayload
        NhAccountSessionService.validateBackupSessionPayload(entry.payload, portable)
        bundle.saved.push(entry)
      }
    }
    const raw: string = JSON.stringify(bundle)
    if (raw.length <= 0 || raw.length > MAX_ACCOUNT_BACKUP_BUNDLE_CHARS) {
      throw new Error('account_session_backup_shape_invalid')
    }
    return raw
  }

  /** Non-secret saved-account ids whose sealed envelopes are currently usable. */
  static async savedCredentialAccountIds(context: common.UIAbilityContext): Promise<string[]> {
    const snapshot: AccountSessionRestoreSnapshot = await AccountSessionRepository.loadForRestore(context)
    if (snapshot.savedKeys.length !== snapshot.savedRecords.length) {
      return []
    }
    const ids: string[] = []
    for (let index: number = 0; index < snapshot.savedKeys.length; index += 1) {
      try {
        const plaintext: string = await NhAccountSessionService.decryptWithExistingKey(
          snapshot.savedRecords[index],
        )
        const payload: SealedBrowserSessionPayload = NhAccountSessionService.decodeSessionPayload(plaintext)
        if (NhAccountSessionService.isUsableDecodedPayload(payload)) {
          ids.push(snapshot.savedKeys[index])
        }
      } catch (_error) {}
    }
    return ids
  }

  /** Re-wraps a portable API-key set or an explicitly local rollback snapshot. */
  static async restoreAllSealedFromBackup(
    context: common.UIAbilityContext,
    raw: string,
    replace: boolean,
    allowLocalLegacySessions: boolean = false,
  ): Promise<void> {
    if (raw.length === 0) {
      if (replace) {
        await AccountSessionRepository.restoreBackup(context, null, [], [], true)
      }
      return
    }
    if (raw.length > MAX_ACCOUNT_BACKUP_BUNDLE_CHARS) {
      throw new Error('account_session_backup_shape_invalid')
    }
    let parsed: AccountSessionBackupBundle
    try {
      parsed = JSON.parse(raw) as AccountSessionBackupBundle
    } catch (_error) {
      throw new Error('account_session_backup_shape_invalid')
    }
    if (parsed === null || typeof parsed !== 'object' ||
      (parsed.version !== 1 && parsed.version !== 2) ||
      typeof parsed.activePayload !== 'string' || !Array.isArray(parsed.saved)) {
      throw new Error('account_session_backup_shape_invalid')
    }
    const portable: boolean = parsed.version === 2
    if (!portable && !allowLocalLegacySessions) {
      // Legacy portable backups contain device/session-family credentials.
      // Ignore them instead of cloning a rotating Web session onto this device.
      return
    }
    let primary: EncryptedAccountSession | null = null
    let primaryOwnerId: string = ''
    let primaryOwnerMatchCount: number = 0
    if (parsed.activePayload.length > 0) {
      NhAccountSessionService.validateBackupSessionPayload(parsed.activePayload, portable)
      primary = await NhAccountSessionService.encrypt(parsed.activePayload)
    }
    const savedKeys: string[] = []
    const savedRecords: EncryptedAccountSession[] = []
    const seen: Set<string> = new Set<string>()
    for (let i: number = 0; i < parsed.saved.length; i++) {
      const entry: AccountSessionBackupEntry = parsed.saved[i]
      if (entry === null || typeof entry !== 'object' || typeof entry.accountId !== 'string' ||
        typeof entry.payload !== 'string') {
        throw new Error('account_session_backup_shape_invalid')
      }
      const accountId: string = NhAccountSessionService.validateBackupAccountId(entry.accountId)
      if (seen.has(accountId)) {
        throw new Error('account_session_backup_shape_invalid')
      }
      seen.add(accountId)
      NhAccountSessionService.validateBackupSessionPayload(entry.payload, portable)
      if (parsed.activePayload.length > 0 && entry.payload === parsed.activePayload) {
        primaryOwnerId = accountId
        primaryOwnerMatchCount += 1
      }
      savedKeys.push(accountId)
      savedRecords.push(await NhAccountSessionService.encrypt(entry.payload))
    }
    await AccountSessionRepository.restoreBackup(
      context,
      primary,
      savedKeys,
      savedRecords,
      replace,
      NhAccountSessionService.backupRestorePreservesExistingPrimary(portable, replace),
      primaryOwnerMatchCount === 1 ? primaryOwnerId : '',
    )
    if (primary !== null || savedRecords.length > 0) {
      NhAccountSessionService.retainedAccountPresent = true
    }
  }

  /** Portable merge adopts the backed-up primary only when the target has none. */
  static backupRestorePreservesExistingPrimary(portable: boolean, replace: boolean): boolean {
    return portable && !replace
  }

  private static validateBackupAccountId(value: string): string {
    const normalized: string = value.trim()
    if (normalized.length === 0 || normalized.length > MAX_ACCOUNT_BACKUP_ID_CHARS ||
      normalized !== value || normalized === 'primary' || /[\r\n\t\u0000]/.test(normalized)) {
      throw new Error('account_session_backup_shape_invalid')
    }
    return normalized
  }

  private static validateBackupSessionPayload(plaintext: string, portable: boolean): void {
    if (portable) {
      if (!NhAccountSessionService.isPortableBackupSessionPayload(plaintext)) {
        throw new Error('account_session_backup_payload_invalid')
      }
      return
    }
    const payload: SealedBrowserSessionPayload = NhAccountSessionService.decodeSessionPayload(plaintext)
    if (!NhAccountSessionService.isUsableDecodedPayload(payload)) {
      throw new Error('account_session_backup_payload_invalid')
    }
  }

  /** The exact pure admission predicate used by portable restore. */
  static isPortableBackupSessionPayload(plaintext: string): boolean {
    const payload: SealedBrowserSessionPayload = NhAccountSessionService.decodeSessionPayload(plaintext)
    return NhAccountSessionService.isUsableDecodedPayload(payload) &&
      payload.credentialKind === NhNativeCredentialKind.API_KEY &&
      payload.cookieHeader.length === 0 && payload.browserUserAgent.length === 0 &&
      payload.authCookies.length === 0
  }

  /**
   * Converts one valid local envelope into the only cross-device shape we
   * accept. This stays value-preserving for the API key itself, but removes
   * every device/session-family Web field before the encrypted backup layer
   * can serialize it.
   */
  static portableApiKeyPayload(plaintext: string): string | null {
    const payload: SealedBrowserSessionPayload = NhAccountSessionService.decodeSessionPayload(plaintext)
    if (!payload.isEnvelopeValid || payload.credentialKind !== NhNativeCredentialKind.API_KEY ||
      NhAccountSessionService.normalizeApiKeyCandidate(payload.apiKey).length === 0) {
      return null
    }
    return NhAccountSessionService.serializeSessionPayload(
      '',
      '',
      [],
      NhNativeCredentialKind.API_KEY,
      payload.apiKey,
      payload.apiKeyName,
    )
  }

  /** Backup restore: re-wraps a backed-up plaintext session with the target device HUKS key. */
  static async restoreSealedFromBackup(context: common.UIAbilityContext, plaintext: string): Promise<void> {
    if (plaintext.length === 0) {
      throw new Error('account_session_backup_payload_invalid')
    }
    const payload: SealedBrowserSessionPayload = NhAccountSessionService.decodeSessionPayload(plaintext)
    if (!NhAccountSessionService.isUsableDecodedPayload(payload) ||
      payload.credentialKind !== NhNativeCredentialKind.API_KEY ||
      payload.cookieHeader.length > 0 || payload.browserUserAgent.length > 0 ||
      payload.authCookies.length > 0) {
      throw new Error('account_session_backup_payload_invalid')
    }
    const record: EncryptedAccountSession = await NhAccountSessionService.encrypt(plaintext)
    await AccountSessionRepository.saveVerified(context, record)
    NhAccountSessionService.retainedAccountPresent = true
  }

  /** Backup rollback: deletes the sealed account record (explicit rollback only). */
  static async clearSealedForBackup(context: common.UIAbilityContext): Promise<void> {
    await AccountSessionRepository.clear(context)
  }

  /** Saves the active sealed envelope under a stable non-secret account id. */
  static async saveActiveAsSaved(context: common.UIAbilityContext, accountId: string): Promise<boolean> {
    if (accountId.length === 0 || !NhAccountSessionService.isAuthenticated()) {
      return false
    }
    try {
      const active: EncryptedAccountSession = await NhAccountSessionService.encrypt(
        NhAccountSessionService.serializeSessionPayload(
          NhAccountSessionService.cookieHeader,
          NhAccountSessionService.browserUserAgent,
          NhAccountSessionService.sealedAuthCookies,
          NhAccountSessionService.nativeCredentialKind,
          NhAccountSessionService.nativeApiKey,
          NhAccountSessionService.nativeApiKeyName,
        ),
      )
      await AccountSessionRepository.saveVerifiedForAccount(context, active, accountId)
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
    if (!NhAccountSessionService.isUsableDecodedPayload(payload)) {
      return false
    }
    if (NhAccountSessionService.sessionTransitionInFlight) {
      return false
    }
    const transitionEpoch: number = NhAccountSessionService.beginDurableSessionTransition()
    try {
      await AccountSessionRepository.saveVerifiedForAccount(context, record, accountId)
      if (!NhAccountSessionService.isDurableSessionTransitionCurrent(transitionEpoch)) {
        return false
      }
      NhAccountSessionService.advanceSessionEpoch()
      NhAccountSessionService.cookieHeader = normalized
      NhAccountSessionService.sealedFallbackCookieHeader = normalized
      NhAccountSessionService.sealedAuthCookies = payload.authCookies
      NhAccountSessionService.browserUserAgent = normalizedUserAgent
      NhAccountSessionService.nativeCredentialKind = payload.credentialKind
      NhAccountSessionService.nativeApiKey = payload.apiKey
      NhAccountSessionService.nativeApiKeyName = payload.apiKeyName
      NhAccountSessionService.nativeApiKeyIdentity =
        NhAccountSessionService.apiKeyIdentityForDisplay(payload.apiKey)
      NhAccountSessionService.sessionOrigin = AccountSessionOrigin.RESTORED
      NhAccountSessionService.activeSavedAccountId = accountId
      NhAccountSessionService.lastSavedAccountCheckpointId = accountId
      NhAccountSessionService.verificationRequiredMarkerPresent = false
      NhAccountSessionService.verificationRecoveryKind = 'web_login'
      NhAccountSessionService.retainedAccountPresent = true
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

  /**
   * Fences an encrypted backup restore before its first durable mutation. Old
   * authenticated responses cannot checkpoint into the imported primary, and
   * no new account request can start until success or rollback is rehydrated.
   */
  static async beginBackupRestoreTransition(context: common.UIAbilityContext): Promise<number> {
    NhAccountSessionService.sessionContext = context
    if (NhAccountSessionService.restoreTask !== null) {
      await NhAccountSessionService.restoreTask
    }
    if (NhAccountSessionService.sessionTransitionInFlight) {
      return -1
    }
    return NhAccountSessionService.beginDurableSessionTransition()
  }

  /** Publishes one new epoch only after the restored or rolled-back state has been rehydrated. */
  static finishBackupRestoreTransition(transitionEpoch: number): void {
    const current: boolean = NhAccountSessionService.isDurableSessionTransitionCurrent(transitionEpoch)
    if (current) {
      NhAccountSessionService.advanceSessionEpoch()
    }
    NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
    if (current) {
      NhAccountSessionService.publishSessionChange()
    }
  }

  private static async restoreInternal(
    context: common.UIAbilityContext,
    restoredEpoch: number,
  ): Promise<boolean> {
    // The encrypted access/renewal pair is the native request authority.
    // ArkWeb's regular jar is inspected only so a restored native session can
    // avoid rewriting an already-compatible visible-browser jar.
    const regularJarHeader: string = NhAccountSessionService.readRegularArkWebCookieHeader()
    const regularJarReady: boolean = NhAccountSessionService.hasLoginCookies(regularJarHeader)
    if (regularJarReady) {
      if (restoredEpoch !== NhAccountSessionService.sessionEpoch) {
        return NhAccountSessionService.isAuthenticated()
      }
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
      NhAccountSessionService.retainedAccountPresent = true
      NhAccountSessionService.verificationRequiredMarkerPresent = true
      NhAccountSessionService.verificationRecoveryKind =
        NhAccountSessionService.isApiKeyRecoveryReason(verificationSnapshot.reasonCode)
          ? 'api_key'
          : 'web_login'
      NhAccountSessionService.updateRetainedRestoreLoginGate(true)
      if (NhAccountSessionService.verificationRecoveryKind === 'api_key') {
        await NhAccountSessionService.restoreRejectedApiKeyDisplayMetadata(context)
      }
      NhAccountSessionService.recordDiagnosticStage(
        verificationSnapshot.reasonCode === 'terminal_401_refresh_token_rejected'
          ? AccountSessionDiagnosticStage.RESTORE_VERIFICATION_REQUIRED_AFTER_BROWSER_REFRESH_FAILURE
          : AccountSessionDiagnosticStage.RESTORE_VERIFICATION_REQUIRED,
      )
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
    const savedRecords: EncryptedAccountSession[] = restoreSnapshot.savedRecords
    if (record !== null || savedRecords.length > 0) {
      NhAccountSessionService.retainedAccountPresent = true
    }
    let failureRequiresExplicitVisibleLogin: boolean = verificationRequired
    if (record === null) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.RESTORE_RECORD_ABSENT,
      )
      if (restoreSnapshot.rebuiltOrRepaired) {
        // The platform reported a rebuilt/repaired RDB and the sealed row is
        // absent. Do not misclassify this as a fresh install and implicitly
        // open Web; require the existing explicit verification action.
        NhAccountSessionService.recordDiagnosticStage(
          AccountSessionDiagnosticStage.RESTORE_RDB_REBUILT_RECORD_ABSENT,
        )
        failureRequiresExplicitVisibleLogin = true
      }
      if (savedRecords.length === 0) {
        return await NhAccountSessionService.keepRegularJarOrPublishRestoreFailure(
          context,
          restoredEpoch,
          regularJarReady,
          failureRequiresExplicitVisibleLogin,
        )
      }
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
    let restoredPayload: SealedBrowserSessionPayload | null = null
    let restoredFallbackRecord: EncryptedAccountSession | null = null
    let restoredFallbackAccountId: string = ''
    if (record !== null) {
      let restored: string = ''
      try {
        // Restore is intentionally non-generative. Key creation belongs only to
        // a newly verified visible-login promotion through `encrypt`.
        restored = await NhAccountSessionService.decryptWithExistingKey(record)
      } catch (_error) {
        NhAccountSessionService.recordDiagnosticStage(
          AccountSessionDiagnosticStage.RESTORE_HUKS_DECRYPT_FAILED,
        )
      }
      if (restored.length > 0) {
        const payload: SealedBrowserSessionPayload = NhAccountSessionService.decodeSessionPayload(restored)
        const payloadNormalized: string = NhAccountSessionService.normalizeCookieHeader(payload.cookieHeader)
        const payloadUserAgent: string =
          NhAccountSessionService.normalizeUserAgent(payload.browserUserAgent)
        DiagnosticLogger.info(
          'account-session',
          'account_restore_payload_shape',
          `code=${payload.validationCode};headerAccess=${NhAccountSessionService.hasLoginCookies(payloadNormalized) ? 1 : 0};` +
            `ua=${payloadUserAgent.length > 0 ? 1 : 0};authCount=${payload.authCookies.length};` +
            `renewal=${NhAccountSessionService.hasRefreshAuthCookie(payload.authCookies) ? 1 : 0};` +
            `refresh=${NhAccountSessionService.hasNamedAuthCookie(payload.authCookies, 'refresh_token') ? 1 : 0};` +
            `session=${NhAccountSessionService.hasNamedAuthCookie(payload.authCookies, 'sessionid') ? 1 : 0};` +
            `legacy=${NhAccountSessionService.hasNamedAuthCookie(payload.authCookies, 'ipb_pass_hash') ? 1 : 0}`,
        )
        NhAccountSessionService.recordAuthCookieExpiryShape('restore', payload.authCookies)
        if (!NhAccountSessionService.isUsableDecodedPayload(payload)) {
          NhAccountSessionService.recordDiagnosticStage(
            AccountSessionDiagnosticStage.RESTORE_PAYLOAD_INVALID,
          )
        } else {
          restoredPayload = payload
        }
      }
    }
    if (restoredPayload === null && savedRecords.length > 0) {
      // Multi-account envelopes are sealed with the same non-exportable HUKS
      // key. When the primary row is absent or unreadable, one saved envelope
      // remains the authoritative fallback regardless of whether the
      // compatibility-only ArkWeb jar happens to be readable. A regular jar
      // must never suppress HUKS recovery and manufacture a "re-verify" gate
      // over recoverable ciphertext.
      const candidateIndexes: number[] = []
      const preferredIndex: number = restoreSnapshot.savedKeys.indexOf(
        NhAccountSessionService.activeSavedAccountId,
      )
      if (preferredIndex >= 0 && preferredIndex < savedRecords.length) {
        candidateIndexes.push(preferredIndex)
      }
      for (let index: number = 0; index < savedRecords.length; index += 1) {
        if (index !== preferredIndex) {
          candidateIndexes.push(index)
        }
      }
      for (let orderIndex: number = 0; orderIndex < candidateIndexes.length; orderIndex += 1) {
        const index: number = candidateIndexes[orderIndex]
        const candidatePayload: SealedBrowserSessionPayload | null =
          await NhAccountSessionService.decryptRestoreCandidate(savedRecords[index])
        if (candidatePayload !== null) {
          restoredPayload = candidatePayload
          restoredFallbackRecord = savedRecords[index]
          restoredFallbackAccountId = restoreSnapshot.savedKeys[index]
          NhAccountSessionService.recordDiagnosticStage(
            AccountSessionDiagnosticStage.RESTORE_SAVED_ENVELOPE_USED,
          )
          break
        }
      }
    }
    if (restoredPayload === null) {
      NhAccountSessionService.recordDiagnosticStage(
        record === null
          ? AccountSessionDiagnosticStage.RESTORE_SAVED_ENVELOPE_EXHAUSTED
          : AccountSessionDiagnosticStage.RESTORE_PAYLOAD_INVALID,
      )
      return await NhAccountSessionService.keepRegularJarOrPublishRestoreFailure(
        context,
        restoredEpoch,
        regularJarReady,
        record === null ? failureRequiresExplicitVisibleLogin : true,
      )
    }
    if (restoredFallbackRecord !== null) {
      try {
        // Repair the missing/unusable primary with the selected saved owner so
        // later cold starts no longer depend on fallback query order.
        await AccountSessionRepository.saveVerifiedForAccount(
          context,
          restoredFallbackRecord,
          restoredFallbackAccountId,
        )
        NhAccountSessionService.activeSavedAccountId = restoredFallbackAccountId
        NhAccountSessionService.lastSavedAccountCheckpointId = restoredFallbackAccountId
      } catch (_error) {
        // The decrypted runtime credential remains usable. A later cold start
        // can retry this non-destructive repair from the retained saved row.
      }
    }
    NhAccountSessionService.retainedAccountPresent = true
    NhAccountSessionService.persistRetainedAccountMarker(context, true).catch((): void => {})
    const normalized: string =
      NhAccountSessionService.normalizeCookieHeader(restoredPayload.cookieHeader)
    const normalizedUserAgent: string =
      NhAccountSessionService.normalizeUserAgent(restoredPayload.browserUserAgent)
    if (restoredEpoch !== NhAccountSessionService.sessionEpoch) {
      return NhAccountSessionService.isAuthenticated()
    }

    NhAccountSessionService.clearRetainedRestoreLoginGate()

    // Publish the sealed generation before any best-effort browser-jar sink.
    // A Web engine failure cannot withhold native API authentication.
    const preservesActiveSessionOrigin: boolean =
      NhAccountSessionService.isAuthenticated() &&
      NhAccountSessionService.cookieHeader === normalized &&
      NhAccountSessionService.browserUserAgent === normalizedUserAgent
    NhAccountSessionService.cookieHeader = normalized
    NhAccountSessionService.sealedFallbackCookieHeader = normalized
    NhAccountSessionService.sealedAuthCookies = restoredPayload.authCookies
    NhAccountSessionService.browserUserAgent = normalizedUserAgent
    NhAccountSessionService.nativeCredentialKind = restoredPayload.credentialKind
    NhAccountSessionService.nativeApiKey = restoredPayload.apiKey
    NhAccountSessionService.nativeApiKeyName = restoredPayload.apiKeyName
    NhAccountSessionService.nativeApiKeyIdentity =
      NhAccountSessionService.apiKeyIdentityForDisplay(restoredPayload.apiKey)
    if (!preservesActiveSessionOrigin) {
      NhAccountSessionService.sessionOrigin = AccountSessionOrigin.RESTORED
    }
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhAccountSessionService.recordDiagnosticStage(AccountSessionDiagnosticStage.RESTORE_READY)
    // Presence alone is insufficient: a crash between two persistence stores
    // can leave ArkWeb and the sealed request generation on different token
    // pairs. The hydrator accepts an existing jar only when it contains the
    // exact sealed pair; otherwise the encrypted generation repairs the jar.
    const completeWebCompatibilityState: boolean =
      NhBrowserSessionBoundary.hasCompleteOwnedBrowserSessionSnapshot(
        NhAccountSessionService.hasLoginCookies(normalized),
        normalizedUserAgent.length > 0,
        NhAccountSessionService.hasAccessAuthCookie(restoredPayload.authCookies),
        NhAccountSessionService.hasRefreshAuthCookie(restoredPayload.authCookies),
      )
    let hydrated: boolean = !completeWebCompatibilityState
    if (completeWebCompatibilityState) {
      try {
        hydrated = await NhAccountSessionService.ensureRegularArkWebCookieJar()
      } catch (_error) {}
    }
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
   * Tries one saved multi-account envelope with the same non-exportable HUKS
   * key. It never generates a key and never mutates durable state; a null
   * return simply means this candidate cannot restore the session.
   */
  private static async decryptRestoreCandidate(
    candidate: EncryptedAccountSession,
  ): Promise<SealedBrowserSessionPayload | null> {
    let plaintext: string = ''
    try {
      plaintext = await NhAccountSessionService.decryptWithExistingKey(candidate)
    } catch (_error) {
      return null
    }
    const payload: SealedBrowserSessionPayload = NhAccountSessionService.decodeSessionPayload(plaintext)
    const normalized: string = NhAccountSessionService.normalizeCookieHeader(payload.cookieHeader)
    const normalizedUserAgent: string = NhAccountSessionService.normalizeUserAgent(payload.browserUserAgent)
    if (!NhAccountSessionService.isUsableDecodedPayload(payload)) {
      return null
    }
    return payload
  }

  /**
   * Restores only the non-secret label and masked identity for a terminally
   * rejected API key. The raw key is decrypted into a local value solely to
   * derive its display mask; it is never promoted back into request state.
   */
  private static async restoreRejectedApiKeyDisplayMetadata(
    context: common.UIAbilityContext,
  ): Promise<void> {
    let snapshot: AccountSessionRestoreSnapshot
    try {
      snapshot = await AccountSessionRepository.loadForRestore(context)
    } catch (_error) {
      return
    }
    const candidates: EncryptedAccountSession[] = []
    if (snapshot.record !== null) {
      candidates.push(snapshot.record)
    }
    const preferredOwners: string[] = [
      snapshot.primaryOwnerId.trim(),
      NhAccountSessionService.activeSavedAccountId.trim(),
    ]
    for (let ownerIndex: number = 0; ownerIndex < preferredOwners.length; ownerIndex += 1) {
      const owner: string = preferredOwners[ownerIndex]
      const savedIndex: number = owner.length > 0 ? snapshot.savedKeys.indexOf(owner) : -1
      if (savedIndex < 0 || savedIndex >= snapshot.savedRecords.length) {
        continue
      }
      const saved: EncryptedAccountSession = snapshot.savedRecords[savedIndex]
      if (!candidates.some((candidate: EncryptedAccountSession): boolean =>
        candidate.ciphertext === saved.ciphertext && candidate.nonce === saved.nonce)) {
        candidates.push(saved)
      }
    }
    for (let index: number = 0; index < candidates.length; index += 1) {
      try {
        const plaintext: string = await NhAccountSessionService.decryptWithExistingKey(candidates[index])
        const payload: SealedBrowserSessionPayload = NhAccountSessionService.decodeSessionPayload(plaintext)
        const apiKey: string = NhAccountSessionService.normalizeApiKeyCandidate(payload.apiKey)
        if (!payload.isEnvelopeValid || payload.credentialKind !== NhNativeCredentialKind.API_KEY ||
          apiKey.length === 0) {
          continue
        }
        NhAccountSessionService.nativeApiKeyName = payload.apiKeyName
        NhAccountSessionService.nativeApiKeyIdentity =
          NhAccountSessionService.apiKeyIdentityForDisplay(apiKey)
        return
      } catch (_error) {}
    }
  }

  /**
   * A regular ArkWeb jar is never sufficient native authentication. Missing or
   * unreadable HUKS/RDB state enters the same fail-closed ownership boundary
   * even if a visible-browser compatibility jar still contains token names.
   */
  private static async keepRegularJarOrPublishRestoreFailure(
    context: common.UIAbilityContext,
    restoredEpoch: number,
    regularJarReady: boolean,
    requiresExplicitVisibleLogin: boolean,
  ): Promise<boolean> {
    if (regularJarReady) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.RESTORE_ARKWEB_JAR_READY,
      )
    }
    return await NhAccountSessionService.publishSignedOutAfterRestoreFailure(
      context,
      restoredEpoch,
      requiresExplicitVisibleLogin,
    )
  }

  /**
   * A cold transport restore failure keeps durable account ownership while
   * withholding request authentication. The encrypted record can become
   * usable after a temporary HUKS/RDB/ArkWeb issue; only explicit sign-out
   * may remove ownership or its profile/cache projection.
   */
  private static async publishSignedOutAfterRestoreFailure(
    context: common.UIAbilityContext,
    restoredEpoch: number,
    requiresExplicitVisibleLogin: boolean,
  ): Promise<boolean> {
    if (restoredEpoch !== NhAccountSessionService.sessionEpoch) {
      return NhAccountSessionService.isAuthenticated()
    }
    const accountPresent: boolean = NhAccountSessionService.retainedAccountPresent ||
      requiresExplicitVisibleLogin
    const preserveRejectedApiKeyDisplay: boolean = requiresExplicitVisibleLogin &&
      NhAccountSessionService.verificationRequiredMarkerPresent &&
      NhAccountSessionService.verificationRecoveryKind === 'api_key'
    NhAccountSessionService.retainedAccountPresent = accountPresent
    if (requiresExplicitVisibleLogin) {
      NhAccountSessionService.updateRetainedRestoreLoginGate(true)
      NhAccountSessionService.verificationRequiredMarkerPresent = true
    } else {
      NhAccountSessionService.clearRetainedRestoreLoginGate()
    }
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
    NhAccountSessionService.sealedAuthCookies = []
    NhAccountSessionService.browserUserAgent = ''
    NhAccountSessionService.nativeCredentialKind = NhNativeCredentialKind.NONE
    NhAccountSessionService.nativeApiKey = ''
    if (!preserveRejectedApiKeyDisplay) {
      NhAccountSessionService.nativeApiKeyName = ''
      NhAccountSessionService.nativeApiKeyIdentity = ''
    }
    NhAccountSessionService.sessionOrigin = AccountSessionOrigin.NONE
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhAccountSessionService.resetRejectedVisibleBrowserSessionCandidate()
    const profileClearTask: Promise<void> = accountPresent
      ? Promise.resolve()
      : NhAccountSessionService.clearAccountProfileSnapshot(context)
    if (hadNativeSession || accountPresent) {
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
    const sealedAuthCookies: SealedAuthCookie[] = NhAccountSessionService.sealedAuthCookies
    if (!NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, hydrationEpoch)) {
      return false
    }
    try {
      const existing: string = NhAccountSessionService.normalizeCookieHeader(
        NhCookieAuthority.fetchCookieSync(rootUrl, false),
      )
      const existingAuthCookies: SealedAuthCookie[] =
        await NhAccountSessionService.captureFirstPartyAuthCookies()
      // The encrypted generation is the native request and crash-recovery
      // authority. A complete but different browser pair may be the first half
      // of an interrupted response checkpoint, so presence alone cannot make
      // it authoritative or suppress sealed-jar repair.
      const existingComplete: boolean = NhAccountSessionService.hasAccessAuthCookie(existingAuthCookies) &&
        (sealedAuthCookies.length === 0 || NhAccountSessionService.hasRefreshAuthCookie(existingAuthCookies))
      const existingMatchesSealed: boolean = sealedAuthCookies.length === 0 ||
        NhAccountSessionService.authCookieSnapshotContains(existingAuthCookies, sealedAuthCookies)
      if (NhAccountSessionService.hasLoginCookies(existing) && existingComplete && existingMatchesSealed) {
        if (NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, hydrationEpoch)) {
          NhAccountSessionService.cookieHeader = existing
        }
        return true
      }
    } catch (_error) {}

    if (sealedAuthCookies.length > 0) {
      for (let index: number = 0; index < sealedAuthCookies.length; index += 1) {
        if (!NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, hydrationEpoch)) {
          return false
        }
        try {
          NhCookieAuthority.configCookieSync(
            rootUrl,
            NhAccountSessionService.authCookieSetValue(sealedAuthCookies[index]),
            false,
            true,
          )
        } catch (_error) {
          return false
        }
      }
    } else {
      // Version-2 envelopes predate complete cookie snapshots. Read them for
      // compatibility, but restore only the one value they actually contain;
      // they are never mislabeled as a renewable version-3 session.
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
          NhCookieAuthority.configCookieSync(
            rootUrl,
            `${cookiePairs[index]}; Path=/; Secure`,
            false,
            false,
          )
        } catch (_error) {
          return false
        }
      }
    }
    try {
      NhCookieAuthority.saveCookieSync()
    } catch (_error) {
      try {
        await NhCookieAuthority.saveCookieAsync()
      } catch (_asyncError) {
        return false
      }
    }
    if (!NhAccountSessionService.isCurrentSealedSession(sealedCookieHeader, hydrationEpoch)) {
      return false
    }
    try {
      const restored: string = NhAccountSessionService.normalizeCookieHeader(
        NhCookieAuthority.fetchCookieSync(rootUrl, false),
      )
      const restoredAuthCookies: SealedAuthCookie[] =
        await NhAccountSessionService.captureFirstPartyAuthCookies()
      const restoredMatchesFallback: boolean = sealedAuthCookies.length > 0
        ? NhAccountSessionService.authCookieSnapshotContains(restoredAuthCookies, sealedAuthCookies)
        : NhAccountSessionService.cookieValue(restored, 'access_token') ===
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

  /**
   * Checkpoints a complete live first-party ArkWeb session for the API-key
   * creation bridge. Callers outside that visible Web flow must not adopt an
   * unrelated account's browser jar.
   */
  static async adoptCompleteRegularArkWebCookieJar(browserUserAgent: string = ''): Promise<boolean> {
    try {
      const capturedUserAgent: string = NhAccountSessionService.normalizeUserAgent(browserUserAgent)
      if (browserUserAgent.length > 0 && capturedUserAgent.length === 0) {
        return false
      }
      const currentHeader: string = NhAccountSessionService.readRegularArkWebCookieHeader()
      const currentAuthCookies: SealedAuthCookie[] =
        await NhAccountSessionService.captureFirstPartyAuthCookies()
      if (!NhAccountSessionService.hasLoginCookies(currentHeader) ||
        !NhAccountSessionService.hasAccessAuthCookie(currentAuthCookies) ||
        !NhAccountSessionService.hasRefreshAuthCookie(currentAuthCookies)) {
        return false
      }
      NhAccountSessionService.cookieHeader = currentHeader
      NhAccountSessionService.sealedFallbackCookieHeader = currentHeader
      NhAccountSessionService.sealedAuthCookies = currentAuthCookies
      if (capturedUserAgent.length > 0) {
        NhAccountSessionService.browserUserAgent = capturedUserAgent
      }
      return true
    } catch (_error) {
      return false
    }
  }

  /**
   * Captures the visible API-key setup browser as an uncommitted candidate.
   * Unlike the regular login transaction, this never replaces the current
   * native credential before the candidate account has been verified.
   */
  static async captureApiKeySetupBrowserSessionCandidate(
    context: common.UIAbilityContext,
    observedUrl: string,
    browserUserAgent: string,
  ): Promise<boolean> {
    return await NhAccountSessionService.captureBrowserSessionCandidate(
      context,
      observedUrl,
      browserUserAgent,
      false,
    )
  }

  /**
   * Adds a verified same-account Web snapshot to the existing API-key
   * envelope without replacing that API key. The primary and saved rows are
   * updated atomically, and read back before the live snapshot is published.
   */
  static async checkpointVerifiedApiKeyBrowserSession(
    context: common.UIAbilityContext,
    verifiedAccountId: string,
  ): Promise<boolean> {
    const accountId: string = verifiedAccountId.trim()
    const apiKey: string = NhAccountSessionService.normalizeApiKeyCandidate(
      NhAccountSessionService.nativeApiKey,
    )
    if (NhAccountSessionService.nativeCredentialKind !== NhNativeCredentialKind.API_KEY ||
      apiKey.length === 0 || !/^[1-9][0-9]*$/.test(accountId) ||
      accountId !== NhAccountSessionService.activeSavedAccountId ||
      !NhAccountSessionService.hasLoginCookies(NhAccountSessionService.pendingCookieHeader) ||
      !NhAccountSessionService.hasAccessAuthCookie(NhAccountSessionService.pendingAuthCookies) ||
      !NhAccountSessionService.hasRefreshAuthCookie(NhAccountSessionService.pendingAuthCookies) ||
      NhAccountSessionService.normalizeUserAgent(
        NhAccountSessionService.pendingBrowserUserAgent,
      ).length === 0 || NhAccountSessionService.sessionTransitionInFlight) {
      return false
    }
    const expectedApiKey: string = apiKey
    const transitionEpoch: number = NhAccountSessionService.beginDurableSessionTransition(false)
    let record: EncryptedAccountSession
    try {
      record = await NhAccountSessionService.encrypt(
        NhAccountSessionService.serializeSessionPayload(
          NhAccountSessionService.pendingCookieHeader,
          NhAccountSessionService.pendingBrowserUserAgent,
          NhAccountSessionService.pendingAuthCookies,
          NhNativeCredentialKind.API_KEY,
          expectedApiKey,
          NhAccountSessionService.nativeApiKeyName,
        ),
      )
      await AccountSessionRepository.saveVerifiedForAccount(context, record, accountId)
      const persisted: AccountSessionRestoreSnapshot =
        await AccountSessionRepository.loadForRestore(context)
      if (persisted.record === null || persisted.record.ciphertext !== record.ciphertext ||
        persisted.record.nonce !== record.nonce) {
        throw new Error('account_api_key_browser_checkpoint_readback_failed')
      }
    } catch (_error) {
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
      return false
    }
    if (!NhAccountSessionService.isDurableSessionTransitionCurrent(transitionEpoch) ||
      NhAccountSessionService.nativeCredentialKind !== NhNativeCredentialKind.API_KEY ||
      NhAccountSessionService.nativeApiKey !== expectedApiKey ||
      NhAccountSessionService.activeSavedAccountId !== accountId) {
      NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
      return false
    }
    NhAccountSessionService.cookieHeader = NhAccountSessionService.pendingCookieHeader
    NhAccountSessionService.sealedFallbackCookieHeader =
      NhAccountSessionService.pendingCookieHeader
    NhAccountSessionService.sealedAuthCookies =
      NhAccountSessionService.pendingAuthCookies.slice()
    NhAccountSessionService.browserUserAgent =
      NhAccountSessionService.pendingBrowserUserAgent
    NhAccountSessionService.discardPendingVisibleBrowserSession()
    NhAccountSessionService.finishDurableSessionTransition(transitionEpoch)
    return true
  }

  /** Reads only the fixed first-party cookie scopes used by the retained transport. */
  private static readRegularArkWebCookieHeader(): string {
    const headers: string[] = []
    NhBrowserSessionBoundary.trustedSessionUrls().forEach((url: string): void => {
      try {
        headers.push(NhCookieAuthority.fetchCookieSync(url, false))
      } catch (_error) {}
    })
    return NhAccountSessionService.mergeCookieHeaders(headers)
  }

  private static isCurrentSealedSession(sealedCookieHeader: string, expectedEpoch: number): boolean {
    return expectedEpoch === NhAccountSessionService.sessionEpoch &&
      sealedCookieHeader === NhAccountSessionService.sealedFallbackCookieHeader
  }

  /** Resolves a checkpoint owner without allowing a response to change a known request owner. */
  private static resolveAuthenticatedReadOwner(
    token: NhAccountAuthenticatedReadToken,
    verifiedAccountId: string,
  ): string | null {
    const captured: string = token.accountId.trim()
    const active: string = NhAccountSessionService.activeSavedAccountId.trim()
    const verified: string = verifiedAccountId.trim()
    if ((captured.length > 0 && !/^[1-9][0-9]*$/.test(captured)) ||
      (active.length > 0 && !/^[1-9][0-9]*$/.test(active)) ||
      (verified.length > 0 && !/^[1-9][0-9]*$/.test(verified))) {
      return null
    }
    if (captured.length > 0 && active.length > 0 && captured !== active) {
      return null
    }
    if (verified.length > 0 &&
      ((captured.length > 0 && verified !== captured) ||
        (active.length > 0 && verified !== active))) {
      return null
    }
    return verified.length > 0 ? verified : (captured.length > 0 ? captured : active)
  }

  private static advanceSessionEpoch(): void {
    NhAccountSessionService.sessionEpoch += 1
  }

  /** Begins a durable clear or verified-promotion transition before it awaits RDB. */
  private static beginDurableSessionTransition(changesOwnership: boolean = true): number {
    NhAccountSessionService.sessionTransitionEpoch += 1
    NhAccountSessionService.sessionTransitionInFlight = true
    NhAccountSessionService.sessionTransitionChangesOwnership = changesOwnership
    return NhAccountSessionService.sessionTransitionEpoch
  }

  private static isDurableSessionTransitionCurrent(transitionEpoch: number): boolean {
    return NhAccountSessionService.sessionTransitionInFlight &&
      transitionEpoch === NhAccountSessionService.sessionTransitionEpoch
  }

  private static finishDurableSessionTransition(transitionEpoch: number): void {
    if (transitionEpoch === NhAccountSessionService.sessionTransitionEpoch) {
      NhAccountSessionService.sessionTransitionInFlight = false
      NhAccountSessionService.sessionTransitionChangesOwnership = false
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
    const authenticated: boolean = NhAccountSessionService.isAuthenticated()
    connectAccountSession().publish(
      true,
      NhAccountSessionService.retainedAccountPresent || authenticated,
      authenticated,
      NhAccountSessionService.verificationRequiredMarkerPresent,
      NhAccountSessionService.verificationRecoveryKind,
      NhAccountSessionService.nativeCredentialKind,
      NhAccountSessionService.nativeApiKeyIdentity,
      NhAccountSessionService.nativeApiKeyName,
    )
  }

  /**
   * A non-secret ownership marker keeps page identity stable even when RDB,
   * HUKS, or ArkWeb recovery is temporarily unavailable during cold start.
   * Only the explicit clear path writes false.
   */
  private static async loadRetainedAccountMarker(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, ACCOUNT_STATE_STORE)
      if (store.getSync(ACCOUNT_PRESENT_KEY, false) as boolean) {
        NhAccountSessionService.retainedAccountPresent = true
      }
    } catch (_error) {}
  }

  private static async persistRetainedAccountMarker(
    context: common.UIAbilityContext,
    present: boolean,
  ): Promise<void> {
    const store: preferences.Preferences = await preferences.getPreferences(context, ACCOUNT_STATE_STORE)
    if (present) {
      store.putSync(ACCOUNT_PRESENT_KEY, true)
    } else {
      store.deleteSync(ACCOUNT_PRESENT_KEY)
    }
    store.flushSync()
  }

  /** Emits each fixed, non-sensitive account lifecycle stage at most once per process. */
  private static recordDiagnosticStage(stage: AccountSessionDiagnosticStage): void {
    NhAccountSessionService.latestDiagnosticStage = stage
    if (NhAccountSessionService.emittedDiagnosticStages.has(stage)) {
      return
    }
    NhAccountSessionService.emittedDiagnosticStages.add(stage)
    DiagnosticLogger.info('account-session', stage, 'stage')
    try {
      hilog.info(ACCOUNT_LOG_DOMAIN, ACCOUNT_LOG_TAG, 'account session stage=%{public}s', stage)
    } catch (_ignored) {}
  }

  /**
   * Account identity data is deliberately separate from the HUKS envelope,
   * but it has the same explicit ownership lifecycle: an absent, replaced,
   * or signed-out account must not leave a profile snapshot restorable.
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
    } catch (_error) {
      NhAccountSessionService.recordDiagnosticStage(
        AccountSessionDiagnosticStage.PROFILE_SNAPSHOT_CLEAR_FAILED,
      )
    }
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
          NhCookieAuthority.configCookieSync(
            url,
            `${name}=; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT`,
            false,
            true,
          )
        } catch (_error) {}
      })
    })
    try {
      NhCookieAuthority.saveCookieSync()
    } catch (_error) {
      NhCookieAuthority.saveCookieAsync().catch((): void => {})
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

  private static async delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void): void => {
      setTimeout((): void => {
        resolve()
      }, milliseconds)
    })
  }

  /**
   * Restore-only decrypt path. It deliberately performs no key creation: the
   * caller has already completed the non-mutating HUKS presence check.
   */
  private static async decryptWithExistingKey(record: EncryptedAccountSession): Promise<string> {
    const sealed: Uint8Array = new util.Base64Helper().decodeSync(record.ciphertext)
    const nonce: Uint8Array = new util.Base64Helper().decodeSync(record.nonce)
    if (nonce.length !== NONCE_BYTES || sealed.length <= AUTH_TAG_BYTES) {
      throw new Error('The stored account session is invalid')
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

  private static async captureFirstPartyAuthCookies(): Promise<SealedAuthCookie[]> {
    const captured: SealedAuthCookie[] = []
    const cookies: webview.WebHttpCookie[] = await NhCookieAuthority.fetchAllAuthCookies()
    for (let index: number = 0; index < cookies.length; index += 1) {
      const source: webview.WebHttpCookie = cookies[index]
      const candidate: SealedAuthCookie = new SealedAuthCookie()
      candidate.name = source.name
      candidate.value = source.value
      candidate.domain = source.domain
      candidate.path = source.path
      candidate.expiresDate = source.expiresDate
      candidate.isHttpOnly = source.isHttpOnly
      candidate.isSecure = source.isSecure
      candidate.isSessionCookie = source.isSessionCookie
      candidate.sameSitePolicy = source.samesitePolicy
      const normalized: SealedAuthCookie | null = NhAccountSessionService.normalizeAuthCookie(candidate)
      if (normalized !== null) {
        captured.push(normalized)
      }
    }
    captured.sort((left: SealedAuthCookie, right: SealedAuthCookie): number => {
      const leftKey: string = `${left.name}|${left.domain}|${left.path}`
      const rightKey: string = `${right.name}|${right.domain}|${right.path}`
      return leftKey.localeCompare(rightKey)
    })
    return captured
  }

  /**
   * Reads exact ArkWeb Cookie metadata when available, but never lets that
   * supplementary API strand the visible-login state machine. The URL-scoped
   * first-party header remains the CookieManager's network view and supplies a
   * canonical access/refresh pair only when both tokens independently pass the
   * fixed token validator. The candidate still has to pass the native account
   * endpoint before it can be sealed or published.
   */
  private static async captureVisibleCandidateAuthCookies(
    cookieHeader: string,
  ): Promise<SealedAuthCookie[]> {
    const metadataCookies: SealedAuthCookie[] | null =
      await NhAccountSessionService.captureFirstPartyAuthCookiesWithinTimeout()
    if (metadataCookies !== null &&
      NhAccountSessionService.hasAccessAuthCookie(metadataCookies) &&
      NhAccountSessionService.hasRefreshAuthCookie(metadataCookies)) {
      return metadataCookies
    }
    const access: string = NhAccountSessionService.safeApiToken(
      NhAccountSessionService.cookieValue(cookieHeader, 'access_token'),
    )
    const refresh: string = NhAccountSessionService.safeApiToken(
      NhAccountSessionService.cookieValue(cookieHeader, 'refresh_token'),
    )
    if (access.length === 0 || refresh.length === 0) {
      return metadataCookies ?? []
    }
    const navigationEpoch: number = NhAccountSessionService.visibleLoginNavigationEpoch
    if (navigationEpoch > 0 &&
      NhAccountSessionService.candidateCookieFallbackDiagnosticEpoch !== navigationEpoch) {
      NhAccountSessionService.candidateCookieFallbackDiagnosticEpoch = navigationEpoch
      DiagnosticLogger.info(
        'account-login',
        'candidate_cookie_metadata_fallback',
        `metadata=${metadataCookies === null ? 'unavailable' : 'incomplete'};` +
          'headerAccess=1;headerRefresh=1',
      )
    }
    return [
      NhAccountSessionService.apiTokenCookie('access_token', access, false),
      NhAccountSessionService.apiTokenCookie('refresh_token', refresh, true),
    ]
  }

  /** Resolves once; a late ArkWeb result has no shared-state side effect. */
  private static async captureFirstPartyAuthCookiesWithinTimeout(): Promise<SealedAuthCookie[] | null> {
    return new Promise<SealedAuthCookie[] | null>(
      (resolve: (cookies: SealedAuthCookie[] | null) => void): void => {
        let settled: boolean = false
        const finish = (cookies: SealedAuthCookie[] | null): void => {
          if (settled) {
            return
          }
          settled = true
          clearTimeout(timeoutId)
          resolve(cookies)
        }
        const timeoutId: number = setTimeout((): void => {
          finish(null)
        }, VISIBLE_AUTH_COOKIE_SNAPSHOT_TIMEOUT_MS)
        NhAccountSessionService.captureFirstPartyAuthCookies()
          .then((cookies: SealedAuthCookie[]): void => {
            finish(cookies)
          })
          .catch((): void => {
            finish(null)
          })
      },
    )
  }

  private static decodeAuthCookie(raw: Object): SealedAuthCookie | null {
    if (raw === null || Array.isArray(raw) || typeof raw !== 'object') {
      return null
    }
    const record: Record<string, Object> = raw as Record<string, Object>
    if (typeof record['name'] !== 'string' || typeof record['value'] !== 'string' ||
      typeof record['domain'] !== 'string' || typeof record['path'] !== 'string' ||
      typeof record['expiresDate'] !== 'string' || typeof record['isHttpOnly'] !== 'boolean' ||
      typeof record['isSecure'] !== 'boolean' || typeof record['isSessionCookie'] !== 'boolean' ||
      typeof record['sameSitePolicy'] !== 'number') {
      return null
    }
    const candidate: SealedAuthCookie = new SealedAuthCookie()
    candidate.name = record['name'] as string
    candidate.value = record['value'] as string
    candidate.domain = record['domain'] as string
    candidate.path = record['path'] as string
    candidate.expiresDate = record['expiresDate'] as string
    candidate.isHttpOnly = record['isHttpOnly'] as boolean
    candidate.isSecure = record['isSecure'] as boolean
    candidate.isSessionCookie = record['isSessionCookie'] as boolean
    candidate.sameSitePolicy = record['sameSitePolicy'] as number
    return NhAccountSessionService.normalizeAuthCookie(candidate)
  }

  private static normalizeAuthCookie(candidate: SealedAuthCookie): SealedAuthCookie | null {
    const name: string = candidate.name.trim()
    if (RECOVERABLE_ARKWEB_COOKIE_NAMES.indexOf(name) < 0 ||
      candidate.value.length === 0 || candidate.value.length > MAX_AUTH_COOKIE_VALUE_CHARS ||
      /[;\r\n\u0000]/.test(candidate.value)) {
      return null
    }
    const domain: string = candidate.domain.trim().toLowerCase()
    const bareDomain: string = domain.replace(/^\./, '')
    if (bareDomain !== 'nhentai.net') {
      return null
    }
    const path: string = candidate.path.trim()
    if (!path.startsWith('/') || path.length > MAX_AUTH_COOKIE_ATTRIBUTE_CHARS ||
      /[;\r\n\u0000]/.test(path)) {
      return null
    }
    const expiresDate: string = candidate.expiresDate.trim()
    if (expiresDate.length > MAX_AUTH_COOKIE_ATTRIBUTE_CHARS || /[;\r\n\u0000]/.test(expiresDate)) {
      return null
    }
    if (candidate.sameSitePolicy !== webview.WebHttpCookieSameSitePolicy.NONE &&
      candidate.sameSitePolicy !== webview.WebHttpCookieSameSitePolicy.LAX &&
      candidate.sameSitePolicy !== webview.WebHttpCookieSameSitePolicy.STRICT) {
      return null
    }
    const normalized: SealedAuthCookie = new SealedAuthCookie()
    normalized.name = name
    normalized.value = candidate.value
    normalized.domain = domain.startsWith('.') ? '.nhentai.net' : 'nhentai.net'
    normalized.path = path
    normalized.expiresDate = expiresDate
    normalized.isHttpOnly = candidate.isHttpOnly
    normalized.isSecure = candidate.isSecure
    normalized.isSessionCookie = candidate.isSessionCookie
    normalized.sameSitePolicy = candidate.sameSitePolicy
    return normalized
  }

  private static safeApiToken(value: string): string {
    if (value.length <= 0 || value.length > MAX_AUTH_COOKIE_VALUE_CHARS ||
      /[\u0000-\u001F\u007F;,]/.test(value)) {
      return ''
    }
    return value
  }

  private static currentAuthCookieValue(name: string): string {
    const cookie: SealedAuthCookie | undefined =
      NhAccountSessionService.sealedAuthCookies.find((candidate: SealedAuthCookie): boolean =>
        candidate.name === name)
    return cookie === undefined ? '' : NhAccountSessionService.safeApiToken(cookie.value)
  }

  /** Null means absent; empty means the server supplied an invalid/deleting value. */
  private static responseAuthCookieValue(
    setCookieHeaders: string[],
    expectedName: string,
  ): string | null {
    let found: boolean = false
    let selected: string = ''
    for (let index: number = 0; index < setCookieHeaders.length; index += 1) {
      const header: string = setCookieHeaders[index]
      const pairEnd: number = header.indexOf(';')
      const pair: string = (pairEnd >= 0 ? header.slice(0, pairEnd) : header).trim()
      const separator: number = pair.indexOf('=')
      if (separator <= 0 || pair.slice(0, separator).trim() !== expectedName) {
        continue
      }
      if (/;\s*Max-Age\s*=\s*0(?:\s*;|\s*$)/i.test(header)) {
        return ''
      }
      const expiresMatch: RegExpExecArray | null =
        /;\s*Expires\s*=\s*([^;]+)/i.exec(header)
      if (expiresMatch !== null) {
        const deadline: number = Date.parse(expiresMatch[1].trim())
        if (Number.isFinite(deadline) && deadline <= Date.now()) {
          return ''
        }
      }
      const value: string = NhAccountSessionService.safeApiToken(
        pair.slice(separator + 1).trim(),
      )
      if (value.length === 0 || (found && value !== selected)) {
        return ''
      }
      found = true
      selected = value
    }
    return found ? selected : null
  }

  private static apiTokenCookie(
    name: string,
    value: string,
    httpOnly: boolean,
  ): SealedAuthCookie {
    const cookie: SealedAuthCookie = new SealedAuthCookie()
    cookie.name = name
    cookie.value = value
    cookie.domain = 'nhentai.net'
    cookie.path = '/'
    cookie.expiresDate = ''
    cookie.isHttpOnly = httpOnly
    cookie.isSecure = true
    cookie.isSessionCookie = false
    cookie.sameSitePolicy = webview.WebHttpCookieSameSitePolicy.LAX
    return cookie
  }

  private static hasAccessAuthCookie(cookies: SealedAuthCookie[]): boolean {
    return cookies.some((cookie: SealedAuthCookie): boolean =>
      cookie.name === 'access_token' && cookie.value.length > 0)
  }

  /** Native authentication is renewable only with the token used by the fixed refresh endpoint. */
  private static hasRefreshAuthCookie(cookies: SealedAuthCookie[]): boolean {
    return cookies.some((cookie: SealedAuthCookie): boolean =>
      cookie.name === 'refresh_token' && cookie.value.length > 0)
  }

  private static hasNamedAuthCookie(cookies: SealedAuthCookie[], name: string): boolean {
    return cookies.some((cookie: SealedAuthCookie): boolean =>
      cookie.name === name && cookie.value.length > 0)
  }

  private static authCookieSnapshotContains(
    actual: SealedAuthCookie[],
    expected: SealedAuthCookie[],
  ): boolean {
    return expected.every((expectedCookie: SealedAuthCookie): boolean =>
      actual.some((actualCookie: SealedAuthCookie): boolean =>
        actualCookie.name === expectedCookie.name &&
        actualCookie.value === expectedCookie.value &&
        actualCookie.domain === expectedCookie.domain &&
        actualCookie.path === expectedCookie.path))
  }

  private static authCookieFingerprint(cookies: SealedAuthCookie[]): string {
    return JSON.stringify(cookies)
  }

  private static authCookieSetValue(cookie: SealedAuthCookie): string {
    let value: string = `${cookie.name}=${cookie.value}; Path=${cookie.path}`
    if (cookie.domain.startsWith('.')) {
      value += '; Domain=nhentai.net'
    }
    if (cookie.isSecure) {
      value += '; Secure'
    }
    if (cookie.isHttpOnly) {
      value += '; HttpOnly'
    }
    if (!cookie.isSessionCookie && cookie.expiresDate.length > 0) {
      value += `; Expires=${cookie.expiresDate}`
    }
    if (cookie.sameSitePolicy === webview.WebHttpCookieSameSitePolicy.NONE) {
      value += '; SameSite=None'
    } else if (cookie.sameSitePolicy === webview.WebHttpCookieSameSitePolicy.STRICT) {
      value += '; SameSite=Strict'
    } else {
      value += '; SameSite=Lax'
    }
    return value
  }

  /** Only probe-verified envelopes are accepted; older marker-only records are retired. */
  private static decodeSessionPayload(plaintext: string): SealedBrowserSessionPayload {
    const payload: SealedBrowserSessionPayload = new SealedBrowserSessionPayload()
    if (plaintext.length === 0) {
      return payload
    }
    if (!plaintext.startsWith('{')) {
      payload.validationCode = 'not_json_object'
      return payload
    }
    try {
      const parsed: Object = JSON.parse(plaintext) as Object
      if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
        payload.validationCode = 'root_not_object'
        return payload
      }
      const record: Record<string, Object> = parsed as Record<string, Object>
      const version: Object = record['version']
      if (version !== 2 && version !== 3 && version !== 4) {
        payload.validationCode = 'version'
        return payload
      }
      if (typeof record['cookieHeader'] !== 'string' || typeof record['browserUserAgent'] !== 'string') {
        payload.validationCode = 'header_or_ua_type'
        return payload
      }
      payload.cookieHeader = record['cookieHeader'] as string
      payload.browserUserAgent = record['browserUserAgent'] as string
      if (version === 2) {
        // Version 2 retained only a flattened access-token header. Treating it
        // as a restored envelope creates a false middle state: Account remains
        // selected while no refresh credential can authorize or repair native
        // requests. Preserve the record, but route it through the explicit
        // verification boundary instead of publishing a fake successful restore.
        payload.validationCode = 'legacy_v2_access_only'
        return payload
      }
      if (version === 4) {
        if (record['credentialKind'] === NhNativeCredentialKind.API_KEY) {
          if (typeof record['apiKey'] !== 'string') {
            payload.validationCode = 'api_key_type'
            return payload
          }
          payload.credentialKind = NhNativeCredentialKind.API_KEY
          payload.apiKey = NhAccountSessionService.normalizeApiKeyCandidate(record['apiKey'] as string)
          if (payload.apiKey.length === 0) {
            payload.validationCode = 'api_key_invalid'
            return payload
          }
          if (record['apiKeyName'] !== undefined && typeof record['apiKeyName'] !== 'string') {
            payload.validationCode = 'api_key_name_type'
            return payload
          }
          payload.apiKeyName = typeof record['apiKeyName'] === 'string'
            ? NhAccountSessionService.normalizeApiKeyName(record['apiKeyName'] as string)
            : ''
        } else if (record['credentialKind'] === NhNativeCredentialKind.WEB_TOKEN) {
          payload.credentialKind = NhNativeCredentialKind.WEB_TOKEN
        } else {
          payload.validationCode = 'credential_kind'
          return payload
        }
      } else {
        payload.credentialKind = NhNativeCredentialKind.WEB_TOKEN
      }
      if (!Array.isArray(record['authCookies'])) {
        payload.validationCode = 'auth_array'
        return payload
      }
      const rawCookies: Object[] = record['authCookies'] as Object[]
      for (let index: number = 0; index < rawCookies.length; index += 1) {
        const normalizedCookie: SealedAuthCookie | null =
          NhAccountSessionService.decodeAuthCookie(rawCookies[index])
        if (normalizedCookie === null) {
          payload.validationCode = 'auth_cookie'
          return payload
        }
        payload.authCookies.push(normalizedCookie)
      }
      if (payload.credentialKind === NhNativeCredentialKind.API_KEY) {
        payload.isEnvelopeValid = true
        payload.validationCode = 'valid_v4_api_key'
        return payload
      }
      if (!NhAccountSessionService.hasAccessAuthCookie(payload.authCookies)) {
        payload.validationCode = 'auth_access_missing'
        return payload
      }
      if (!NhAccountSessionService.hasRefreshAuthCookie(payload.authCookies)) {
        payload.validationCode = 'auth_renewal_missing'
        return payload
      }
      payload.isEnvelopeValid = true
      payload.validationCode = version === 4 ? 'valid_v4_web_token' : 'valid_v3'
    } catch (_error) {
      payload.validationCode = 'json_parse'
    }
    return payload
  }

  private static isUsableDecodedPayload(payload: SealedBrowserSessionPayload): boolean {
    if (!payload.isEnvelopeValid) {
      return false
    }
    if (payload.credentialKind === NhNativeCredentialKind.API_KEY) {
      return NhAccountSessionService.normalizeApiKeyCandidate(payload.apiKey).length > 0
    }
    return payload.credentialKind === NhNativeCredentialKind.WEB_TOKEN &&
      NhAccountSessionService.hasLoginCookies(
        NhAccountSessionService.normalizeCookieHeader(payload.cookieHeader),
      ) &&
      NhAccountSessionService.normalizeUserAgent(payload.browserUserAgent).length > 0 &&
      NhAccountSessionService.hasAccessAuthCookie(payload.authCookies) &&
      NhAccountSessionService.hasRefreshAuthCookie(payload.authCookies)
  }

  private static serializeSessionPayload(
    cookieHeader: string,
    browserUserAgent: string,
    authCookies: SealedAuthCookie[],
    credentialKind: NhNativeCredentialKind = NhNativeCredentialKind.WEB_TOKEN,
    apiKey: string = '',
    apiKeyName: string = '',
  ): string {
    return JSON.stringify({
      'version': 4,
      'credentialKind': credentialKind,
      'apiKey': credentialKind === NhNativeCredentialKind.API_KEY ? apiKey : '',
      'apiKeyName': credentialKind === NhNativeCredentialKind.API_KEY ? apiKeyName : '',
      'cookieHeader': cookieHeader,
      'browserUserAgent': browserUserAgent,
      'authCookies': authCookies,
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
    // Native candidate verification can derive `Authorization: User …` only
    // from this first-party access token. A refresh token, legacy session marker, or a
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
