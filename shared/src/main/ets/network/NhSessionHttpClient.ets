import { common } from '@kit.AbilityKit'
import { NhAccountProfile } from '../model/NhAccountProfile'
import {
  NhAccountAuthenticatedReadToken,
  NhAccountSessionService,
  NhNativeCredentialKind,
  NhResponseAuthCookieResult,
} from '../services/NhAccountSessionService'
import { NhCookieAuthority } from '../services/NhCookieAuthority'
import { NhApiHttpResponse, NhApiHttpTransport } from './NhApiHttpTransport'
import { NhRefreshResponse, NhRefreshResponseCodec } from './NhRefreshResponseCodec'

const API_V2_PREFIX: string = 'https://nhentai.net/api/v2/'
const API_USER_URL: string = `${API_V2_PREFIX}user`
const MAX_ACCOUNT_PROFILE_USERNAME_CHARS: number = 256
const MAX_ACCOUNT_PROFILE_SLUG_CHARS: number = 256
const MAX_ACCOUNT_PROFILE_AVATAR_CHARS: number = 2048
const ACCOUNT_AVATAR_ROOT: string = 'https://i3.nhentai.net'

/** Authentication semantics are declared once at the transport boundary. */
export enum NhRequestScope {
  /** Strictly anonymous: never attach a promoted account credential. */
  PUBLIC,
  /** Attach the current sealed generation when available, otherwise anonymous. */
  ACCOUNT_PREFERRED,
  /** Require the current sealed generation; anonymous fallback is forbidden. */
  ACCOUNT_OWNED,
}

/** Only idempotent reads may be replayed after the single refresh chain. */
export enum NhRequestReplayPolicy {
  SAFE_AFTER_REFRESH,
  NEVER,
}

/** A failed refresh is not automatically proof that the credential was rejected. */
enum NhRefreshAfter401Outcome {
  READY,
  CREDENTIAL_VALID_UNCHANGED,
  AUTH_REJECTED,
  UNAVAILABLE,
}

/** Only requests carrying a Web User Token may mutate the ArkWeb Cookie jar. */
enum NhResponseCookieAuthority {
  IGNORE,
  WEBSITE_SESSION,
}

/** Value-free outcome of the fixed API-key confirmation request. */
export enum NhApiKeyCheckDisposition {
  VALID_UNCHANGED,
  AUTH_REJECTED,
  UNAVAILABLE,
}

/** Only an explicit 401/403 from the fixed account probe rejects a key. */
export function apiKeyCheckDispositionForStatus(statusCode: number): NhApiKeyCheckDisposition {
  if (statusCode === 401 || statusCode === 403) {
    return NhApiKeyCheckDisposition.AUTH_REJECTED
  }
  if (statusCode >= 200 && statusCode < 300) {
    return NhApiKeyCheckDisposition.VALID_UNCHANGED
  }
  return NhApiKeyCheckDisposition.UNAVAILABLE
}

/**
 * The sole request lifecycle for nhentai v2 traffic.
 *
 * Every endpoint shares one native wire transport, scope, generation fence,
 * 401 recovery, replay policy, durable token checkpoint and terminal
 * verification transition. ArkWeb is limited to the visible Turnstile host;
 * it is not a request path or a credential authority.
 */
export class NhSessionHttpClient {
  private static refreshInFlight: Promise<NhRefreshAfter401Outcome> | null = null
  private static refreshInFlightEpoch: number = -1

  /**
   * One-time API-key onboarding. Validation crosses the same first-party
   * transport as ordinary requests; the active credential is replaced only
   * after a 2xx account response and a durable HUKS/RDB readback.
   */
  static async validateAndPromoteApiKey(
    context: common.UIAbilityContext,
    candidate: string,
    browserSessionOwnedByCandidate: boolean = false,
    keyName: string = '',
  ): Promise<void> {
    const apiKey: string = NhAccountSessionService.normalizeApiKeyCandidate(candidate)
    if (apiKey.length === 0) {
      throw new Error('account_api_key_invalid_input')
    }
    let response: NhApiHttpResponse
    try {
      response = await NhApiHttpTransport.requestJson(
        API_USER_URL,
        'GET',
        '',
        `Key ${apiKey}`,
      )
    } catch (_error) {
      throw new Error('account_api_key_unavailable')
    }
    if (response.statusCode === 401 || response.statusCode === 403) {
      throw new Error('account_api_key_rejected')
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('account_api_key_unavailable')
    }
    const accountId: string = NhSessionHttpClient.validatedAccountId(response.body)
    if (accountId.length === 0) {
      throw new Error('account_api_key_unavailable')
    }
    if (!await NhAccountSessionService.promoteVerifiedApiKey(
      context,
      apiKey,
      accountId,
      browserSessionOwnedByCandidate,
      keyName,
    )) {
      throw new Error('account_api_key_persistence_failed')
    }
  }

  /**
   * Verifies the visible official Web session and attaches it to the current
   * API-key envelope only when both credentials resolve to the same account.
   * The existing API key remains the native request credential throughout.
   */
  static async validateAndCheckpointApiKeyBrowserSession(
    context: common.UIAbilityContext,
    observedUrl: string,
    browserUserAgent: string,
  ): Promise<boolean> {
    let checkpointed: boolean = false
    try {
      if (!await NhAccountSessionService.captureApiKeySetupBrowserSessionCandidate(
        context,
        observedUrl,
        browserUserAgent,
      )) {
        return false
      }
      const authorization: string = NhAccountSessionService.pendingApiTokenAuthorization()
      if (authorization.length === 0) {
        return false
      }
      const response: NhApiHttpResponse = await NhApiHttpTransport.requestJson(
        API_USER_URL,
        'GET',
        '',
        authorization,
      )
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false
      }
      const accountId: string = NhSessionHttpClient.validatedAccountId(response.body)
      if (accountId.length === 0 || await NhSessionHttpClient.consumeResponseSetCookies(
        response,
        null,
        NhResponseCookieAuthority.WEBSITE_SESSION,
      ) === NhResponseAuthCookieResult.REJECTED ||
        !await NhAccountSessionService.captureApiKeySetupBrowserSessionCandidate(
          context,
          observedUrl,
          browserUserAgent,
        )) {
        return false
      }
      checkpointed = await NhAccountSessionService.checkpointVerifiedApiKeyBrowserSession(
        context,
        accountId,
      )
      return checkpointed
    } catch (_error) {
      return false
    } finally {
      if (!checkpointed) {
        NhAccountSessionService.discardPendingVisibleBrowserSession()
      }
    }
  }

  /**
   * Verifies the exact unpromoted access token captured by the login carrier.
   * The carrier may be ArkWeb, but the request itself always crosses the same
   * native wire boundary as every other NH API operation.
   */
  static async requestCandidateStatus(): Promise<number> {
    const authorization: string = NhAccountSessionService.pendingApiTokenAuthorization()
    if (authorization.length === 0) {
      throw new Error('account_session_candidate_missing')
    }
    const response: NhApiHttpResponse = await NhApiHttpTransport.requestJson(
      API_USER_URL,
      'GET',
      '',
      authorization,
    )
    if (response.statusCode >= 200 && response.statusCode < 300 &&
      NhSessionHttpClient.validatedAccountId(response.body).length > 0 &&
      await NhSessionHttpClient.consumeResponseSetCookies(
        response,
        null,
        NhResponseCookieAuthority.WEBSITE_SESSION,
      ) === NhResponseAuthCookieResult.REJECTED) {
      throw new Error('account_response_cookie_checkpoint_failed')
    }
    return response.statusCode
  }

  static async requestJson(
    url: string,
    method: string,
    body: string,
    scope: NhRequestScope,
    replayPolicy: NhRequestReplayPolicy = NhRequestReplayPolicy.SAFE_AFTER_REFRESH,
  ): Promise<NhApiHttpResponse> {
    NhSessionHttpClient.assertFirstPartyApiUrl(url)
    const readToken: NhAccountAuthenticatedReadToken | null =
      NhSessionHttpClient.captureRequestToken(scope)
    let authorization: string = readToken !== null
      ? NhAccountSessionService.authenticatedAuthorization(readToken)
      : ''
    let response: NhApiHttpResponse =
      await NhApiHttpTransport.requestJson(url, method, body, authorization)
    if (await NhSessionHttpClient.consumeResponseSetCookies(
      response,
      readToken,
      NhSessionHttpClient.responseCookieAuthorityFor(readToken),
    ) ===
      NhResponseAuthCookieResult.REJECTED) {
      throw new Error('account_response_cookie_checkpoint_failed')
    }
    const apiKeyRejectedStatus: boolean = readToken !== null &&
      NhAccountSessionService.isApiKeyCredential(readToken) && response.statusCode === 403
    if (response.statusCode === 401 || apiKeyRejectedStatus) {
      const refreshOutcome: NhRefreshAfter401Outcome =
        await NhSessionHttpClient.recoverAfter401(readToken)
      if (readToken !== null && !NhAccountSessionService.isAuthenticatedReadTokenCurrent(readToken)) {
        throw new Error('account_session_generation_changed')
      }
      if (refreshOutcome === NhRefreshAfter401Outcome.AUTH_REJECTED) {
        if (readToken !== null) {
          const terminalRecorded: boolean = NhAccountSessionService.isApiKeyCredential(readToken)
            ? await NhAccountSessionService.recordAuthenticatedApiKeyRejected(readToken)
            : await NhAccountSessionService.recordAuthenticatedRefreshToken401(readToken)
          throw new Error(terminalRecorded
            ? 'account_authenticated_request_rejected'
            : 'account_session_generation_changed')
        }
        throw new Error('HTTP 401')
      }
      if (refreshOutcome === NhRefreshAfter401Outcome.UNAVAILABLE) {
        throw new Error(readToken === null
          ? `HTTP ${response.statusCode}`
          : NhAccountSessionService.isApiKeyCredential(readToken)
            ? 'account_authenticated_credential_check_unavailable'
            : 'account_authenticated_refresh_unavailable')
      }
      if (refreshOutcome === NhRefreshAfter401Outcome.CREDENTIAL_VALID_UNCHANGED) {
        // The fixed account probe accepted the same API key. Preserve it, but
        // do not replay an endpoint-specific rejection or mutation.
        throw new Error(`HTTP ${response.statusCode}`)
      }
      if (readToken !== null &&
        !NhAccountSessionService.adoptCurrentAuthenticatedCredential(readToken)) {
        throw new Error('account_session_generation_changed')
      }
      if (replayPolicy === NhRequestReplayPolicy.SAFE_AFTER_REFRESH) {
        authorization = readToken !== null
          ? NhAccountSessionService.authenticatedAuthorization(readToken)
          : ''
        response = await NhApiHttpTransport.requestJson(url, method, body, authorization)
        if (await NhSessionHttpClient.consumeResponseSetCookies(
          response,
          readToken,
          NhSessionHttpClient.responseCookieAuthorityFor(readToken),
        ) ===
          NhResponseAuthCookieResult.REJECTED) {
          throw new Error('account_response_cookie_checkpoint_failed')
        }
        if (readToken !== null) {
          NhAccountSessionService.recordAuthenticatedReadBrowserReplay(response.statusCode === 401)
          if (response.statusCode === 401) {
            await NhAccountSessionService.recordBrowserAuthCookieShape('after_replay_401')
          }
        }
      } else {
        // The session recovered, but a state-changing request is never
        // repeated implicitly. The caller may offer an explicit retry.
        throw new Error('account_mutation_not_replayed_after_recovery')
      }
    }
    await NhSessionHttpClient.completeResponse(response.statusCode, readToken, scope)
    return response
  }

  /**
   * One-shot mutation for endpoints whose official contract requires a User
   * Token even when the native account is owned by an API key. The optional
   * Web token is validated (and safely refreshed when needed) before the
   * mutation; the mutation itself is never replayed.
   */
  static async requestJsonUserTokenMutation(
    url: string,
    method: string,
    body: string,
  ): Promise<NhApiHttpResponse> {
    NhSessionHttpClient.assertFirstPartyApiUrl(url)
    if (method !== 'POST' && method !== 'DELETE') {
      throw new Error('account_user_token_mutation_method_invalid')
    }
    const initialToken: NhAccountAuthenticatedReadToken | null =
      NhSessionHttpClient.captureRequestToken(NhRequestScope.ACCOUNT_OWNED)
    if (initialToken === null) {
      throw new Error('account_session_unavailable')
    }
    await NhSessionHttpClient.ensureUserTokenMutationReady(initialToken)
    const readToken: NhAccountAuthenticatedReadToken | null =
      NhAccountSessionService.captureAuthenticatedReadToken()
    if (readToken === null || readToken.sessionEpoch !== initialToken.sessionEpoch ||
      readToken.accountId !== initialToken.accountId) {
      throw new Error('account_session_generation_changed')
    }
    const authorization: string =
      NhAccountSessionService.authenticatedUserTokenAuthorization(readToken)
    if (authorization.length === 0) {
      throw new Error('account_website_session_required')
    }
    const response: NhApiHttpResponse = await NhApiHttpTransport.requestJson(
      url,
      method,
      body,
      authorization,
    )
    if (response.statusCode === 401) {
      const outcome: NhRefreshAfter401Outcome =
        NhAccountSessionService.isApiKeyCredential(readToken)
          ? await NhSessionHttpClient.performApiKeyWebsiteRefreshAfter401(readToken)
          : await NhSessionHttpClient.recoverAfter401(readToken)
      if (outcome === NhRefreshAfter401Outcome.AUTH_REJECTED) {
        if (!NhAccountSessionService.isApiKeyCredential(readToken)) {
          await NhAccountSessionService.recordAuthenticatedRefreshToken401(readToken)
        }
        throw new Error('account_website_session_rejected')
      }
      if (outcome === NhRefreshAfter401Outcome.READY) {
        throw new Error('account_mutation_not_replayed_after_recovery')
      }
      throw new Error('account_website_session_unavailable')
    }
    await NhSessionHttpClient.completeResponse(
      response.statusCode,
      readToken,
      NhRequestScope.ACCOUNT_OWNED,
    )
    return response
  }

  /** Loads and validates the current official API profile through the sole lifecycle. */
  static async requestAccountProfile(): Promise<NhAccountProfile> {
    if (!NhAccountSessionService.isAuthenticated()) {
      throw new Error('A signed-in account session is required to load the profile')
    }
    const ownerToken: NhAccountAuthenticatedReadToken | null =
      NhAccountSessionService.captureAuthenticatedReadToken()
    if (ownerToken === null) {
      throw new Error('account_session_generation_changed')
    }
    const response: NhApiHttpResponse = await NhSessionHttpClient.requestJson(
      API_USER_URL,
      'GET',
      '',
      NhRequestScope.ACCOUNT_OWNED,
    )
    const record: Record<string, Object> | null = NhSessionHttpClient.parseJsonObject(response.body)
    if (record === null) {
      throw new Error('Account profile returned an invalid response')
    }
    const username: string = NhSessionHttpClient.profileString(
      record['username'],
      MAX_ACCOUNT_PROFILE_USERNAME_CHARS,
    )
    const slug: string = NhSessionHttpClient.profileString(
      record['slug'],
      MAX_ACCOUNT_PROFILE_SLUG_CHARS,
    )
    const rawId: Object | undefined = record['id']
    if (username.length === 0 || slug.length === 0 ||
      typeof rawId !== 'number' || !Number.isFinite(rawId as number) ||
      Math.floor(rawId as number) !== rawId as number || (rawId as number) <= 0) {
      throw new Error('Account profile did not contain a valid identity')
    }
    const userId: string = `${Math.floor(rawId as number)}`
    if (!NhAccountSessionService.authenticatedIdentityMatchesActiveAccount(userId)) {
      if (!NhAccountSessionService.adoptCurrentAuthenticatedCredential(ownerToken)) {
        throw new Error('account_session_generation_changed')
      }
      const recorded: boolean =
        await NhAccountSessionService.recordAuthenticatedIdentityMismatch(ownerToken)
      throw new Error(recorded
        ? 'account_authenticated_identity_mismatch'
        : 'account_session_generation_changed')
    }
    const profile: NhAccountProfile = new NhAccountProfile()
    profile.username = username
    profile.userId = userId
    profile.userUrl = `/users/${userId}/${encodeURIComponent(slug)}/`
    profile.avatarUrl = NhSessionHttpClient.profileAvatarUrl(record['avatar_url'])
    return profile
  }

  /**
   * One bounded foreground/bootstrap health probe. Transport and server
   * failures leave the current generation untouched; a terminal 401 uses the
   * same single-flight refresh and durable notification path as every other
   * account-owned request.
   */
  static async validatePromotedSession(): Promise<boolean> {
    if (!NhAccountSessionService.isAuthenticated()) {
      return false
    }
    try {
      await NhSessionHttpClient.requestAccountProfile()
      return NhAccountSessionService.isAuthenticated()
    } catch (_error) {
      return NhAccountSessionService.isAuthenticated()
    }
  }

  private static captureRequestToken(scope: NhRequestScope): NhAccountAuthenticatedReadToken | null {
    if (scope === NhRequestScope.PUBLIC) {
      return null
    }
    if (!NhAccountSessionService.hasRetainedAccount()) {
      if (scope === NhRequestScope.ACCOUNT_PREFERRED) {
        return null
      }
      throw new Error('account_session_unavailable')
    }
    const token: NhAccountAuthenticatedReadToken | null =
      NhAccountSessionService.captureAuthenticatedReadToken()
    if (token === null) {
      if (scope === NhRequestScope.ACCOUNT_PREFERRED) {
        return null
      }
      throw new Error('account_session_generation_changed')
    }
    return token
  }

  private static async ensureUserTokenMutationReady(
    readToken: NhAccountAuthenticatedReadToken,
  ): Promise<void> {
    if (!NhAccountSessionService.isApiKeyCredential(readToken)) {
      await NhSessionHttpClient.requestJson(
        API_USER_URL,
        'GET',
        '',
        NhRequestScope.ACCOUNT_OWNED,
      )
      return
    }
    const authorization: string =
      NhAccountSessionService.authenticatedUserTokenAuthorization(readToken)
    if (authorization.length === 0) {
      throw new Error('account_website_session_required')
    }
    let response: NhApiHttpResponse
    try {
      response = await NhApiHttpTransport.requestJson(
        API_USER_URL,
        'GET',
        '',
        authorization,
      )
    } catch (_error) {
      throw new Error('account_website_session_unavailable')
    }
    if (await NhSessionHttpClient.consumeResponseSetCookies(
      response,
      readToken,
      NhResponseCookieAuthority.WEBSITE_SESSION,
    ) ===
      NhResponseAuthCookieResult.REJECTED) {
      throw new Error('account_response_cookie_checkpoint_failed')
    }
    if (response.statusCode === 401) {
      const outcome: NhRefreshAfter401Outcome =
        await NhSessionHttpClient.performApiKeyWebsiteRefreshAfter401(readToken)
      if (outcome === NhRefreshAfter401Outcome.READY) {
        return
      }
      throw new Error(outcome === NhRefreshAfter401Outcome.AUTH_REJECTED
        ? 'account_website_session_rejected'
        : 'account_website_session_unavailable')
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(response.statusCode === 403
        ? 'account_website_session_rejected'
        : 'account_website_session_unavailable')
    }
    const accountId: string = NhSessionHttpClient.validatedAccountId(response.body)
    if (accountId.length === 0 || accountId !== readToken.accountId) {
      throw new Error('account_website_session_identity_mismatch')
    }
    if (await NhSessionHttpClient.consumeResponseSetCookies(
      response,
      readToken,
      NhResponseCookieAuthority.WEBSITE_SESSION,
      accountId,
    ) === NhResponseAuthCookieResult.REJECTED) {
      throw new Error('account_response_cookie_checkpoint_failed')
    }
  }

  /** Refreshes only the optional website pair inside an API-key envelope. */
  private static async performApiKeyWebsiteRefreshAfter401(
    readToken: NhAccountAuthenticatedReadToken,
  ): Promise<NhRefreshAfter401Outcome> {
    if (!NhAccountSessionService.isApiKeyCredential(readToken)) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    if (await NhAccountSessionService.authenticatedRefreshCooldownRemainingMs(readToken) > 0) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const refreshBody: string =
      NhAccountSessionService.authenticatedUserTokenRefreshRequestBody(readToken)
    if (refreshBody.length === 0) {
      return NhRefreshAfter401Outcome.AUTH_REJECTED
    }
    let response: NhApiHttpResponse
    try {
      response = await NhApiHttpTransport.requestJson(
        `${API_V2_PREFIX}auth/refresh`,
        'POST',
        refreshBody,
        '',
      )
    } catch (_error) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    if (response.statusCode === 401) {
      await NhSessionHttpClient.consumeResponseSetCookies(
        response,
        readToken,
        NhResponseCookieAuthority.WEBSITE_SESSION,
      )
      return NhRefreshAfter401Outcome.AUTH_REJECTED
    }
    if (response.statusCode === 429) {
      await NhSessionHttpClient.consumeResponseSetCookies(
        response,
        readToken,
        NhResponseCookieAuthority.WEBSITE_SESSION,
      )
      await NhAccountSessionService.recordAuthenticatedRefreshCooldown(
        readToken,
        response.retryAfterMs,
      )
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    if (response.statusCode < 200 || response.statusCode >= 300 ||
      !NhAccountSessionService.isAuthenticatedReadTokenCurrent(readToken)) {
      await NhSessionHttpClient.consumeResponseSetCookies(
        response,
        readToken,
        NhResponseCookieAuthority.WEBSITE_SESSION,
      )
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const refreshed: NhRefreshResponse | null = NhRefreshResponseCodec.decode(
      response.body,
      readToken.accountId,
    )
    if (refreshed === null || refreshed.accountId !== readToken.accountId) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const responseCookieResult: NhResponseAuthCookieResult =
      await NhSessionHttpClient.consumeResponseSetCookies(
        response,
        readToken,
        NhResponseCookieAuthority.WEBSITE_SESSION,
        refreshed.accountId,
      )
    if (responseCookieResult === NhResponseAuthCookieResult.REJECTED) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    let refreshedTokensReady: boolean = responseCookieResult === NhResponseAuthCookieResult.APPLIED
    if (!refreshedTokensReady) {
      refreshedTokensReady = await NhAccountSessionService.applyRefreshedUserTokens(
        readToken,
        refreshed.accessToken,
        refreshed.refreshToken,
        false,
        refreshed.accountId,
      )
    }
    if (!refreshedTokensReady) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const authorization: string =
      NhAccountSessionService.authenticatedUserTokenAuthorization(readToken)
    if (authorization.length === 0) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    let verificationResponse: NhApiHttpResponse
    try {
      verificationResponse = await NhApiHttpTransport.requestJson(
        API_USER_URL,
        'GET',
        '',
        authorization,
      )
    } catch (_error) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const verifiedAccountId: string = verificationResponse.statusCode >= 200 &&
      verificationResponse.statusCode < 300
      ? NhSessionHttpClient.validatedAccountId(verificationResponse.body)
      : ''
    if (await NhSessionHttpClient.consumeResponseSetCookies(
      verificationResponse,
      readToken,
      NhResponseCookieAuthority.WEBSITE_SESSION,
      verifiedAccountId,
    ) === NhResponseAuthCookieResult.REJECTED) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    if (verificationResponse.statusCode === 401) {
      return NhRefreshAfter401Outcome.AUTH_REJECTED
    }
    if (verificationResponse.statusCode < 200 || verificationResponse.statusCode >= 300 ||
      verifiedAccountId !== refreshed.accountId ||
      !NhAccountSessionService.isAuthenticatedReadTokenCurrent(readToken)) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    await NhAccountSessionService.clearAuthenticatedRefreshCooldown(readToken)
    return NhRefreshAfter401Outcome.READY
  }

  private static async recoverAfter401(
    readToken: NhAccountAuthenticatedReadToken | null,
  ): Promise<NhRefreshAfter401Outcome> {
    if (readToken === null) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(readToken)) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const existing: Promise<NhRefreshAfter401Outcome> | null = NhSessionHttpClient.refreshInFlight
    if (existing !== null &&
      NhSessionHttpClient.refreshInFlightEpoch === readToken.sessionEpoch) {
      return await existing
    }
    if (!NhAccountSessionService.isAuthenticatedReadCredentialCurrent(readToken)) {
      NhAccountSessionService.recordAuthenticatedReadStale401AfterRefresh()
      return NhRefreshAfter401Outcome.READY
    }
    NhAccountSessionService.recordAuthenticatedReadInitial401()
    await NhAccountSessionService.recordBrowserAuthCookieShape('after_initial_401')
    const afterDiagnostic: Promise<NhRefreshAfter401Outcome> | null =
      NhSessionHttpClient.refreshInFlight
    if (afterDiagnostic !== null &&
      NhSessionHttpClient.refreshInFlightEpoch === readToken.sessionEpoch) {
      return await afterDiagnostic
    }
    if (!NhAccountSessionService.isAuthenticatedReadCredentialCurrent(readToken)) {
      NhAccountSessionService.recordAuthenticatedReadStale401AfterRefresh()
      return NhRefreshAfter401Outcome.READY
    }
    const task: Promise<NhRefreshAfter401Outcome> =
      NhSessionHttpClient.performRefreshAfter401(readToken)
    NhSessionHttpClient.refreshInFlight = task
    NhSessionHttpClient.refreshInFlightEpoch = readToken.sessionEpoch
    try {
      return await task
    } finally {
      if (NhSessionHttpClient.refreshInFlight === task) {
        NhSessionHttpClient.refreshInFlight = null
        NhSessionHttpClient.refreshInFlightEpoch = -1
      }
    }
  }

  private static async performRefreshAfter401(
    readToken: NhAccountAuthenticatedReadToken,
  ): Promise<NhRefreshAfter401Outcome> {
    if (NhAccountSessionService.isApiKeyCredential(readToken)) {
      return await NhSessionHttpClient.performApiKeyCheckAfterRejection(readToken)
    }
    if (await NhAccountSessionService.authenticatedRefreshCooldownRemainingMs(readToken) > 0) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    if (!NhAccountSessionService.isAuthenticatedReadCredentialCurrent(readToken)) {
      return NhRefreshAfter401Outcome.READY
    }
    const refreshBody: string = NhAccountSessionService.authenticatedRefreshRequestBody(readToken)
    if (refreshBody.length === 0) {
      NhAccountSessionService.recordAuthenticatedReadRefreshEndpoint(0)
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    let response: NhApiHttpResponse
    try {
      response = await NhApiHttpTransport.requestJson(
        `${API_V2_PREFIX}auth/refresh`,
        'POST',
        refreshBody,
        '',
      )
    } catch (_error) {
      NhAccountSessionService.recordAuthenticatedReadRefreshEndpoint(0)
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    NhAccountSessionService.recordAuthenticatedReadRefreshEndpoint(response.statusCode)
    if (response.statusCode === 401) {
      await NhSessionHttpClient.consumeResponseSetCookies(
        response,
        readToken,
        NhResponseCookieAuthority.WEBSITE_SESSION,
      )
      return NhRefreshAfter401Outcome.AUTH_REJECTED
    }
    if (response.statusCode === 429) {
      await NhSessionHttpClient.consumeResponseSetCookies(
        response,
        readToken,
        NhResponseCookieAuthority.WEBSITE_SESSION,
      )
      await NhAccountSessionService.recordAuthenticatedRefreshCooldown(readToken, response.retryAfterMs)
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    if (response.statusCode < 200 || response.statusCode >= 300 ||
      !NhAccountSessionService.isAuthenticatedReadTokenCurrent(readToken)) {
      await NhSessionHttpClient.consumeResponseSetCookies(
        response,
        readToken,
        NhResponseCookieAuthority.WEBSITE_SESSION,
      )
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const refreshed: NhRefreshResponse | null = NhRefreshResponseCodec.decode(
      response.body,
      readToken.accountId,
    )
    if (refreshed === null ||
      !NhAccountSessionService.authenticatedIdentityMatchesActiveAccount(refreshed.accountId)) {
      NhAccountSessionService.recordAuthenticatedReadRefreshResponseRejected()
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    // The official response identity is checked before either the encrypted
    // generation or the compatibility ArkWeb jar can receive replacements.
    const responseCookieResult: NhResponseAuthCookieResult =
      await NhSessionHttpClient.consumeResponseSetCookies(
        response,
        readToken,
        NhResponseCookieAuthority.WEBSITE_SESSION,
        refreshed.accountId,
      )
    if (responseCookieResult === NhResponseAuthCookieResult.REJECTED) {
      NhAccountSessionService.recordAuthenticatedReadRefreshEndpoint(0)
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    let refreshedTokensReady: boolean = responseCookieResult === NhResponseAuthCookieResult.APPLIED
    if (!refreshedTokensReady) {
      refreshedTokensReady = await NhAccountSessionService.applyRefreshedApiTokens(
        readToken,
        refreshed.accessToken,
        refreshed.refreshToken,
        false,
        refreshed.accountId,
      )
    }
    if (!refreshedTokensReady) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const authorization: string = NhAccountSessionService.authenticatedAuthorization(readToken)
    let verificationResponse: NhApiHttpResponse
    try {
      verificationResponse = await NhApiHttpTransport.requestJson(
        API_USER_URL,
        'GET',
        '',
        authorization,
      )
    } catch (_error) {
      NhAccountSessionService.recordAuthenticatedReadBrowserRefresh(false)
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const verificationStatus: number = verificationResponse.statusCode
    const verificationAccountId: string = verificationStatus >= 200 && verificationStatus < 300
      ? NhSessionHttpClient.validatedAccountId(verificationResponse.body)
      : ''
    if (verificationStatus >= 200 && verificationStatus < 300 &&
      verificationAccountId !== refreshed.accountId) {
      NhAccountSessionService.recordAuthenticatedReadRefreshResponseRejected()
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    if (await NhSessionHttpClient.consumeResponseSetCookies(
      verificationResponse,
      readToken,
      NhResponseCookieAuthority.WEBSITE_SESSION,
      verificationAccountId,
    ) === NhResponseAuthCookieResult.REJECTED) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const refreshReady: boolean = verificationStatus >= 200 && verificationStatus < 300 &&
      NhAccountSessionService.isAuthenticatedReadTokenCurrent(readToken)
    NhAccountSessionService.recordAuthenticatedReadBrowserRefresh(refreshReady)
    if (!refreshReady) {
      return verificationStatus === 401
        ? NhRefreshAfter401Outcome.AUTH_REJECTED
        : NhRefreshAfter401Outcome.UNAVAILABLE
    }
    await NhAccountSessionService.clearAuthenticatedRefreshCooldown(readToken)
    NhAccountSessionService.markAuthenticatedRequestVerified()
    return NhRefreshAfter401Outcome.READY
  }

  private static async performApiKeyCheckAfterRejection(
    readToken: NhAccountAuthenticatedReadToken,
  ): Promise<NhRefreshAfter401Outcome> {
    if (!NhAccountSessionService.isAuthenticatedReadCredentialCurrent(readToken) ||
      !NhAccountSessionService.isApiKeyCredential(readToken)) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const authorization: string = NhAccountSessionService.authenticatedAuthorization(readToken)
    if (authorization.length === 0) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    let response: NhApiHttpResponse
    try {
      response = await NhApiHttpTransport.requestJson(
        API_USER_URL,
        'GET',
        '',
        authorization,
      )
    } catch (_error) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const disposition: NhApiKeyCheckDisposition =
      apiKeyCheckDispositionForStatus(response.statusCode)
    if (disposition === NhApiKeyCheckDisposition.AUTH_REJECTED) {
      return NhRefreshAfter401Outcome.AUTH_REJECTED
    }
    if (disposition === NhApiKeyCheckDisposition.UNAVAILABLE) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    NhAccountSessionService.markAuthenticatedRequestVerified()
    return NhRefreshAfter401Outcome.CREDENTIAL_VALID_UNCHANGED
  }

  private static async completeResponse(
    statusCode: number,
    readToken: NhAccountAuthenticatedReadToken | null,
    scope: NhRequestScope,
  ): Promise<void> {
    if (statusCode === 401) {
      if (readToken !== null) {
        if (!NhAccountSessionService.isAuthenticatedReadCredentialCurrent(readToken)) {
          NhAccountSessionService.recordAuthenticatedReadStale401AfterRefresh()
          throw new Error('account_session_generation_changed')
        }
        const terminalRecorded: boolean = NhAccountSessionService.isApiKeyCredential(readToken)
          ? await NhAccountSessionService.recordAuthenticatedApiKeyRejected(readToken)
          : await NhAccountSessionService.recordAuthenticatedReadReplay401(readToken)
        if (!terminalRecorded) {
          throw new Error('account_session_generation_changed')
        }
      }
      throw new Error('account_authenticated_request_rejected')
    }
    if (statusCode === 403) {
      throw new Error('HTTP 403')
    }
    if (statusCode < 200 || statusCode >= 300) {
      throw new Error(`HTTP ${statusCode}`)
    }
    if (readToken !== null && !NhAccountSessionService.isAuthenticatedReadTokenCurrent(readToken)) {
      throw new Error('account_session_generation_changed')
    }
    if (scope === NhRequestScope.ACCOUNT_OWNED) {
      NhAccountSessionService.markAuthenticatedRequestVerified()
    }
  }

  /**
   * One response side-effect boundary for Web-session-authorized traffic.
   * API-key and anonymous responses are deliberately ignored: they cannot
   * replace the separate ArkWeb session. For authorized Web traffic, the
   * encrypted generation is checkpointed before the compatibility jar.
   */
  private static async consumeResponseSetCookies(
    response: NhApiHttpResponse,
    readToken: NhAccountAuthenticatedReadToken | null,
    authority: NhResponseCookieAuthority,
    verifiedAccountId: string = '',
  ): Promise<NhResponseAuthCookieResult> {
    if (authority !== NhResponseCookieAuthority.WEBSITE_SESSION) {
      return NhResponseAuthCookieResult.NONE
    }
    if (response.setCookieHeadersRejected) {
      NhAccountSessionService.recordResponseCookieCheckpoint(
        false,
        NhResponseAuthCookieResult.REJECTED,
      )
      return NhResponseAuthCookieResult.REJECTED
    }
    if (response.setCookieHeaders.length === 0) {
      return NhResponseAuthCookieResult.NONE
    }
    let authResult: NhResponseAuthCookieResult = NhResponseAuthCookieResult.NONE
    try {
      if (readToken !== null && response.statusCode >= 200 && response.statusCode < 300) {
        authResult = await NhAccountSessionService.applyResponseAuthSetCookies(
          readToken,
          response.setCookieHeaders,
          verifiedAccountId,
        )
        if (authResult === NhResponseAuthCookieResult.REJECTED) {
          NhAccountSessionService.recordResponseCookieCheckpoint(false, authResult)
          return authResult
        }
      }
    } catch (_error) {
      NhAccountSessionService.recordResponseCookieCheckpoint(
        false,
        NhResponseAuthCookieResult.REJECTED,
      )
      return NhResponseAuthCookieResult.REJECTED
    }
    // The encrypted native generation is the crash-recovery authority. Commit
    // an authenticated rotation there before mutating ArkWeb's compatibility
    // jar; otherwise a process death between these two stores can leave a new
    // browser refresh token paired with the old cold-start envelope.
    try {
      NhCookieAuthority.storeFirstPartyResponseCookies(response.setCookieHeaders)
    } catch (_error) {
      NhAccountSessionService.recordResponseCookieCheckpoint(
        false,
        NhResponseAuthCookieResult.REJECTED,
      )
      return NhResponseAuthCookieResult.REJECTED
    }
    NhAccountSessionService.recordResponseCookieCheckpoint(true, authResult)
    return authResult
  }

  private static responseCookieAuthorityFor(
    readToken: NhAccountAuthenticatedReadToken | null,
  ): NhResponseCookieAuthority {
    return readToken !== null && readToken.credentialKind === NhNativeCredentialKind.WEB_TOKEN
      ? NhResponseCookieAuthority.WEBSITE_SESSION
      : NhResponseCookieAuthority.IGNORE
  }

  private static assertFirstPartyApiUrl(url: string): void {
    if (!url.startsWith(API_V2_PREFIX)) {
      throw new Error('The NH transport is restricted to the first-party API')
    }
  }

  private static parseJsonObject(value: string): Record<string, Object> | null {
    try {
      const parsed: Object = JSON.parse(value) as Object
      if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
        return null
      }
      return parsed as Record<string, Object>
    } catch (_error) {
      return null
    }
  }

  private static profileString(value: Object | undefined, maxChars: number): string {
    if (typeof value !== 'string') {
      return ''
    }
    const normalized: string = (value as string).trim()
    return normalized.length > 0 && normalized.length <= maxChars &&
      !/[\u0000-\u001F\u007F]/.test(normalized)
      ? normalized
      : ''
  }

  /** Stable non-secret owner returned by a successful API-key validation. */
  private static validatedAccountId(body: string): string {
    const record: Record<string, Object> | null = NhSessionHttpClient.parseJsonObject(body)
    const rawId: Object | undefined = record?.['id']
    if (typeof rawId !== 'number' || !Number.isFinite(rawId as number) ||
      Math.floor(rawId as number) !== rawId as number || (rawId as number) <= 0) {
      return ''
    }
    return `${Math.floor(rawId as number)}`
  }

  private static profileAvatarUrl(value: Object | undefined): string {
    if (typeof value !== 'string') {
      return ''
    }
    const raw: string = (value as string).trim()
    if (raw.length === 0) {
      return ''
    }
    let resolved: string = raw
    if (raw.startsWith('//')) {
      resolved = `https:${raw}`
    } else if (raw.startsWith('/')) {
      resolved = `${ACCOUNT_AVATAR_ROOT}${raw}`
    } else if (!raw.startsWith('https://')) {
      resolved = `${ACCOUNT_AVATAR_ROOT}/${raw}`
    }
    return resolved.length <= MAX_ACCOUNT_PROFILE_AVATAR_CHARS &&
      /^https:\/\/[^\s\\]+$/.test(resolved)
      ? resolved
      : ''
  }

}
