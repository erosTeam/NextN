import { NhAccountProfile } from '../model/NhAccountProfile'
import {
  NhAccountAuthenticatedReadToken,
  NhAccountSessionService,
  NhResponseAuthCookieResult,
} from '../services/NhAccountSessionService'
import { NhCookieAuthority } from '../services/NhCookieAuthority'
import { NhApiHttpResponse, NhApiHttpTransport } from './NhApiHttpTransport'

const API_V2_PREFIX: string = 'https://nhentai.net/api/v2/'
const API_USER_URL: string = `${API_V2_PREFIX}user`
const MAX_API_TOKEN_CHARS: number = 4096
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
  AUTH_REJECTED,
  UNAVAILABLE,
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
    if (await NhSessionHttpClient.consumeResponseSetCookies(response, null) ===
      NhResponseAuthCookieResult.REJECTED) {
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
    if (await NhSessionHttpClient.consumeResponseSetCookies(response, readToken) ===
      NhResponseAuthCookieResult.REJECTED) {
      throw new Error('account_response_cookie_checkpoint_failed')
    }
    if (response.statusCode === 401) {
      const refreshOutcome: NhRefreshAfter401Outcome =
        await NhSessionHttpClient.recoverAfter401(readToken)
      if (readToken !== null && !NhAccountSessionService.isAuthenticatedReadTokenCurrent(readToken)) {
        throw new Error('account_session_generation_changed')
      }
      if (refreshOutcome === NhRefreshAfter401Outcome.AUTH_REJECTED) {
        if (readToken !== null) {
          const terminalRecorded: boolean =
            await NhAccountSessionService.recordAuthenticatedRefreshToken401(readToken)
          throw new Error(terminalRecorded
            ? 'account_authenticated_request_rejected'
            : 'account_session_generation_changed')
        }
        throw new Error('HTTP 401')
      }
      if (refreshOutcome === NhRefreshAfter401Outcome.UNAVAILABLE) {
        throw new Error(readToken === null ? 'HTTP 401' : 'account_authenticated_refresh_unavailable')
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
        if (await NhSessionHttpClient.consumeResponseSetCookies(response, readToken) ===
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
        throw new Error('account_mutation_not_replayed_after_refresh')
      }
    }
    await NhSessionHttpClient.completeResponse(response.statusCode, readToken, scope)
    return response
  }

  /** Loads and validates the current official API profile through the sole lifecycle. */
  static async requestAccountProfile(): Promise<NhAccountProfile> {
    if (!NhAccountSessionService.isAuthenticated()) {
      throw new Error('A signed-in account session is required to load the profile')
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
      await NhSessionHttpClient.requestJson(
        API_USER_URL,
        'GET',
        '',
        NhRequestScope.ACCOUNT_OWNED,
      )
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
    const responseCookieResult: NhResponseAuthCookieResult =
      await NhSessionHttpClient.consumeResponseSetCookies(response, readToken)
    if (responseCookieResult === NhResponseAuthCookieResult.REJECTED) {
      NhAccountSessionService.recordAuthenticatedReadRefreshEndpoint(0)
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    NhAccountSessionService.recordAuthenticatedReadRefreshEndpoint(response.statusCode)
    if (response.statusCode === 401) {
      return NhRefreshAfter401Outcome.AUTH_REJECTED
    }
    if (response.statusCode === 429) {
      await NhAccountSessionService.recordAuthenticatedRefreshCooldown(readToken, response.retryAfterMs)
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    if (response.statusCode < 200 || response.statusCode >= 300 ||
      !NhAccountSessionService.isAuthenticatedReadTokenCurrent(readToken)) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const record: Record<string, Object> | null = NhSessionHttpClient.parseJsonObject(response.body)
    const accessValue: Object | undefined = record?.['access_token']
    const refreshValue: Object | undefined = record?.['refresh_token']
    let refreshedTokensReady: boolean = responseCookieResult === NhResponseAuthCookieResult.APPLIED
    if (!refreshedTokensReady &&
      typeof accessValue === 'string' && typeof refreshValue === 'string' &&
      NhSessionHttpClient.validApiToken(accessValue) &&
      NhSessionHttpClient.validApiToken(refreshValue)) {
      refreshedTokensReady = await NhAccountSessionService.applyRefreshedApiTokens(
        readToken,
        accessValue,
        refreshValue,
      )
    }
    if (!refreshedTokensReady) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const authorization: string = NhAccountSessionService.authenticatedAuthorization(readToken)
    const verificationResponse: NhApiHttpResponse = await NhApiHttpTransport.requestJson(
      API_USER_URL,
      'GET',
      '',
      authorization,
    )
    if (await NhSessionHttpClient.consumeResponseSetCookies(verificationResponse, readToken) ===
      NhResponseAuthCookieResult.REJECTED) {
      return NhRefreshAfter401Outcome.UNAVAILABLE
    }
    const verificationStatus: number = verificationResponse.statusCode
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
        const terminalRecorded: boolean =
          await NhAccountSessionService.recordAuthenticatedReadReplay401(readToken)
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
   * One response side-effect boundary for every first-party v2 request. The
   * exact Set-Cookie values never leave the network/session layer: ArkWeb gets
   * the compatibility jar update and a successful authenticated response can
   * atomically checkpoint only the access/refresh pair into native storage.
   */
  private static async consumeResponseSetCookies(
    response: NhApiHttpResponse,
    readToken: NhAccountAuthenticatedReadToken | null,
  ): Promise<NhResponseAuthCookieResult> {
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

  private static validApiToken(value: string): boolean {
    return value.length > 0 && value.length <= MAX_API_TOKEN_CHARS &&
      !/[\u0000-\u001F\u007F;,]/.test(value)
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
