import { http } from '@kit.NetworkKit'
import { webview } from '@kit.ArkWeb'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import {
  NhGalleryDetail,
  NhGalleryFavoriteStatus,
  NhGalleryPage,
  NhGalleryPageResult,
  NhGallerySummary,
  NhTag,
} from '../model/NhGallery'
import { NhComment } from '../model/NhComment'
import { NhAccountProfile } from '../model/NhAccountProfile'
import { NhTagSuggestion } from '../model/NhTagSuggestion'
import { NhTagCatalogService } from '../services/NhTagCatalogService'
import { NhBrowserSessionVerificationOutcome } from '../model/NhBrowserSessionState'
import { NhAccountAuthenticatedReadToken, NhAccountSessionService } from '../services/NhAccountSessionService'
import {
  NhArkWebAccountProfileResponse,
  NhArkWebSessionResponse,
  NhArkWebSessionTransport,
} from '../services/NhArkWebSessionTransport'

const API_ROOT: string = 'https://nhentai.net'
const API_V2_PREFIX: string = `${API_ROOT}/api/v2/`
const THUMB_ROOT: string = 'https://t.nhentai.net'
const IMAGE_ROOT: string = 'https://i.nhentai.net'
const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 20000
const MAX_COMMENT_POW_DIFFICULTY: number = 24
const ACCOUNT_LOG_DOMAIN: number = 0x0000
const ACCOUNT_LOG_TAG: string = 'NextNAccount'
const MAX_COMMENT_POW_ATTEMPTS: number = 2000000
const COMMENT_POW_YIELD_INTERVAL: number = 2048
// ErosN's unscoped search autocomplete probes these catalog namespaces in
// order. Keep the list short: expanding it would multiply anonymous requests
// for every edit without improving the ordinary tag-search path.
const DEFAULT_AUTOCOMPLETE_TYPES: string[] = ['tag', 'parody', 'character', 'artist', 'group']

/**
 * Public catalog reads must never carry account authority or decide whether a
 * durable session is valid. Authenticated scopes are opt-in and still guarded
 * by the exact endpoint matcher below; only the authenticated Favorites list,
 * never display enrichment, may retire the global account state.
 */
enum NhJsonReadScope {
  PUBLIC,
  ACCOUNT_OWNED,
  // Gallery-detail favourite enrichment may use the authenticated browser
  // transport, but an unknown best-effort leaf must never retire the global
  // account state behind a swallowed error.
  ACCOUNT_OWNED_NON_RETIRING,
}

/** Ephemeral challenge material; it is never persisted, logged, or exposed to UI state. */
class NhCommentProofOfWork {
  challenge: string = ''
  nonce: string = ''
}

/**
 * Native NetworkKit transport for anonymous ErosN v2 reads plus a fixed
 * ArkWeb bridge for authenticated v2 work. When a visible browser session
 * exists, account-bearing requests stay inside that browser context rather
 * than replaying cookies through native HTTP. Authenticated writes remain
 * one-shot operations reached solely from an explicit native action.
 */
export class NhApiClient {
  static async latest(page: number = 1): Promise<NhGalleryPageResult> {
    const root: Record<string, Object> = await NhApiClient.getJson(
      `${API_ROOT}/api/v2/galleries?page=${Math.max(1, Math.floor(page))}`,
    )
    return await NhApiClient.parseGalleryPage(root)
  }

  static async search(query: string, page: number = 1, sort: string = ''): Promise<NhGalleryPageResult> {
    const encoded: string = encodeURIComponent(query.trim())
    const normalizedSort: string = sort.trim()
    const sortPart: string = normalizedSort.length > 0 ? `&sort=${encodeURIComponent(normalizedSort)}` : ''
    const root: Record<string, Object> = await NhApiClient.getJson(
      `${API_ROOT}/api/v2/search?query=${encoded}&page=${Math.max(1, Math.floor(page))}${sortPart}`,
    )
    return await NhApiClient.parseGalleryPage(root)
  }

  /**
   * Popular is deliberately kept separate from Browse: the public endpoint
   * returns a bare, non-paginated array rather than the usual page envelope.
   * Treating that difference as a first-class contract prevents an error body
   * from being mistaken for an empty gallery list.
   */
  static async popular(): Promise<NhGallerySummary[]> {
    const rawItems: Object[] = await NhApiClient.getBareJsonArray(
      `${API_ROOT}/api/v2/galleries/popular`,
    )
    const galleries: NhGallerySummary[] = []
    rawItems.forEach((raw: Object): void => {
      const item: Record<string, Object> = NhApiClient.asRecord(raw)
      if (NhApiClient.asBoolean(item['blacklisted'])) {
        return
      }
      const gallery: NhGallerySummary = NhApiClient.parseGallerySummary(item)
      if (gallery.id > 0) {
        galleries.push(gallery)
      }
    })
    await NhApiClient.enrichGallerySummaryTags(galleries)
    return galleries
  }

  /**
   * Account favourites are deliberately read-only at this layer. The browser
   * session must be present before the request is permitted; the fixed
   * ArkWeb transport then confines browser credentials and v2 authorization
   * to the first-party API origin.
   */
  static async favorites(page: number = 1, query: string = ''): Promise<NhGalleryPageResult> {
    if (!NhAccountSessionService.isAuthenticated()) {
      throw new Error('A signed-in account session is required to load favourites.')
    }
    const normalizedPage: number = Math.max(1, Math.floor(page))
    const normalizedQuery: string = query.trim()
    const queryPart: string = normalizedQuery.length > 0
      ? `&q=${encodeURIComponent(normalizedQuery)}`
      : ''
    const root: Record<string, Object> = await NhApiClient.getJson(
      `${API_ROOT}/api/v2/favorites?page=${normalizedPage}${queryPart}`,
      NhJsonReadScope.ACCOUNT_OWNED,
    )
    return await NhApiClient.parseGalleryPage(root)
  }

  static async detail(galleryId: number, bypassTransportCache: boolean = false): Promise<NhGalleryDetail> {
    const root: Record<string, Object> = await NhApiClient.getJson(
      `${API_ROOT}/api/v2/galleries/${Math.max(0, Math.floor(galleryId))}`,
      NhJsonReadScope.PUBLIC,
      !bypassTransportCache,
    )
    const detail: NhGalleryDetail = NhApiClient.parseGalleryDetail(root)
    NhTagCatalogService.rememberDetailTags(detail.tags)
    return detail
  }

  /**
   * Returns one anonymous public random-gallery identifier. The endpoint's
   * current minimal object response is intentionally validated here, while the
   * existing Gallery destination remains the only detail/cache owner.
   */
  static async randomGalleryId(): Promise<number> {
    const value: Object = await NhApiClient.getJsonValue(
      `${API_V2_PREFIX}galleries/random`,
      NhJsonReadScope.PUBLIC,
      false,
      true,
      true,
    )
    const root: Record<string, Object> = NhApiClient.asRecord(value)
    const galleryId: Object | undefined = root['id']
    if (typeof galleryId !== 'number' || !Number.isSafeInteger(galleryId) || galleryId <= 0) {
      throw new Error('Random gallery service returned an invalid identifier.')
    }
    return galleryId
  }

  /**
   * Related galleries are an optional anonymous supplement to a verified
   * detail. They use the same page envelope and blacklist filter as Browse
   * and Search. That filter is an intentional NextN read-only safety policy,
   * even though ErosN's direct mapper does not apply it here. This endpoint
   * has no pagination or persistence surface of its own.
   */
  static async related(galleryId: number): Promise<NhGallerySummary[]> {
    const normalizedGalleryId: number = Math.max(0, Math.floor(galleryId))
    if (normalizedGalleryId <= 0) {
      throw new Error('A gallery id is required to load related galleries.')
    }
    const root: Record<string, Object> = await NhApiClient.getJson(
      `${API_ROOT}/api/v2/galleries/${normalizedGalleryId}/related`,
    )
    return (await NhApiClient.parseGalleryPage(root)).galleries
  }

  /**
   * The public comment endpoint returns a top-level array, unlike the browse
   * and detail endpoints. Keep that response shape explicit rather than
   * loosening the object parser used by the rest of the client.
   */
  static async comments(galleryId: number): Promise<NhComment[]> {
    const normalizedGalleryId: number = Math.max(0, Math.floor(galleryId))
    if (normalizedGalleryId <= 0) {
      throw new Error('A gallery id is required to load comments.')
    }
    const rawComments: Object[] = await NhApiClient.getJsonArray(
      `${API_ROOT}/api/v2/galleries/${normalizedGalleryId}/comments`,
    )
    return NhApiClient.parseComments(rawComments)
  }

  /**
   * ErosN's public v2 catalog autocomplete. An explicit namespace uses one
   * precise request; an ordinary final token probes ErosN's five useful
   * catalog namespaces. It never carries browser account headers: this is a
   * discovery request, not an account operation.
   */
  static async tagSuggestions(namespace: string, prefix: string, limit: number = 8): Promise<NhTagSuggestion[]> {
    const requestedType: string = NhApiClient.autocompleteType(namespace)
    const query: string = prefix.trim().toLowerCase()
    if (query.length === 0 || query.length > 128) {
      return []
    }
    const boundedLimit: number = Math.max(1, Math.min(15, Math.floor(limit)))
    const types: string[] = requestedType.length > 0 ? [requestedType] : DEFAULT_AUTOCOMPLETE_TYPES
    const suggestions: NhTagSuggestion[] = []
    const seen: Set<string> = new Set<string>()
    for (let typeIndex: number = 0; typeIndex < types.length && suggestions.length < boundedLimit; typeIndex++) {
      const type: string = types[typeIndex]
      const payload: string = JSON.stringify({
        'type': type,
        'query': query,
        'limit': boundedLimit,
      })
      try {
        const rawItems: Object[] = await NhApiClient.postPublicJsonArray(
          `${API_V2_PREFIX}tags/search`,
          payload,
        )
        rawItems.forEach((raw: Object): void => {
          const item: Record<string, Object> = NhApiClient.asRecord(raw)
          const rawName: string = NhApiClient.asString(item['name'])
          const responseType: string = NhApiClient.autocompleteType(NhApiClient.asString(item['type']))
          if (rawName.length === 0 || responseType.length === 0) {
            return
          }
          const key: string = `${responseType}\u001f${rawName.toLowerCase()}`
          if (seen.has(key) || suggestions.length >= boundedLimit) {
            return
          }
          seen.add(key)
          const suggestion: NhTagSuggestion = new NhTagSuggestion()
          suggestion.namespace = responseType
          suggestion.rawName = rawName
          suggestion.displayName = rawName
          suggestions.push(suggestion)
        })
      } catch (_error) {
        // A failed anonymous autocomplete namespace is not a search failure.
        // Continue the bounded ErosN probe list and return any useful result.
      }
    }
    return suggestions
  }

  /**
   * Sends a comment only after an explicit in-app submit action. The comment
   * text lives solely in the composer until this single request; there is no
   * retry because a transport retry could duplicate a user's public post.
   */
  static async postComment(galleryId: number, commentBody: string): Promise<NhComment | null> {
    const normalizedGalleryId: number = Math.max(0, Math.floor(galleryId))
    const body: string = commentBody.trim()
    if (normalizedGalleryId <= 0) {
      throw new Error('A gallery id is required to post a comment.')
    }
    if (body.length === 0) {
      throw new Error('Write a comment before posting.')
    }
    if (!NhAccountSessionService.isAuthenticated()) {
      throw new Error('Sign in from Settings before posting a comment.')
    }
    const proof: NhCommentProofOfWork = await NhApiClient.solveCommentProofOfWork()
    const payload: string = JSON.stringify({
      'body': body,
      'pow_challenge': proof.challenge,
      'pow_nonce': proof.nonce,
    })
    const root: Record<string, Object> = await NhApiClient.requestJsonMutation(
      `${API_ROOT}/api/v2/galleries/${normalizedGalleryId}/comments`,
      http.RequestMethod.POST,
      payload,
      'Comment service rejected this post.',
    )
    const candidate: Record<string, Object> = root['comment'] !== undefined
      ? NhApiClient.asRecord(root['comment'])
      : root
    const comment: NhComment | null = NhApiClient.parseComment(candidate)
    if (comment !== null) {
      return comment
    }
    // ErosN observes a successful `{ ok: true }` acknowledgement without a
    // comment body on some v2 deployments. Treat it as a confirmed publish;
    // the caller reloads the idempotent public list instead of reposting.
    if (root['ok'] === true) {
      return null
    }
    throw new Error('Comment service did not confirm this post.')
  }

  /**
   * Best-effort state enrichment for the visible gallery detail.  A failed or
   * non-authenticated response intentionally remains unknown; callers must
   * not infer a remote favourite state from it.
   */
  static async favoriteStatus(galleryId: number): Promise<NhGalleryFavoriteStatus> {
    const status: NhGalleryFavoriteStatus = new NhGalleryFavoriteStatus()
    const normalizedGalleryId: number = Math.max(0, Math.floor(galleryId))
    if (normalizedGalleryId <= 0 || !NhAccountSessionService.isAuthenticated()) {
      return status
    }
    try {
      const root: Record<string, Object> = await NhApiClient.getJson(
        `${API_ROOT}/api/v2/galleries/${normalizedGalleryId}/favorite`,
        NhJsonReadScope.ACCOUNT_OWNED_NON_RETIRING,
      )
      if (typeof root['favorited'] !== 'boolean') {
        return status
      }
      status.known = true
      status.isFavorited = root['favorited'] as boolean
      if (typeof root['num_favorites'] === 'number') {
        status.favoriteCount = Math.max(0, root['num_favorites'] as number)
        status.hasFavoriteCount = true
      }
      return status
    } catch (_error) {
      return status
    }
  }

  /**
   * ErosN's v2 favourite contract is POST to add and DELETE to remove.  This
   * intentionally has no automatic retry: remote mutation is a single user
   * decision, not a request that transport recovery may replay.
   */
  static async setFavorite(galleryId: number, shouldFavorite: boolean): Promise<NhGalleryFavoriteStatus> {
    const normalizedGalleryId: number = Math.max(0, Math.floor(galleryId))
    if (normalizedGalleryId <= 0) {
      throw new Error('A gallery id is required to change favourites.')
    }
    if (!NhAccountSessionService.isAuthenticated()) {
      throw new Error('Sign in from Settings before changing favourites.')
    }
    const url: string = `${API_ROOT}/api/v2/galleries/${normalizedGalleryId}/favorite`
    const root: Record<string, Object> = await NhApiClient.requestJsonMutation(
      url,
      shouldFavorite ? http.RequestMethod.POST : http.RequestMethod.DELETE,
      '',
      'Favourite service rejected this request.',
    )
    if (typeof root['favorited'] !== 'boolean') {
      throw new Error('Favourite service did not confirm the saved state.')
    }
    const status: NhGalleryFavoriteStatus = new NhGalleryFavoriteStatus()
    status.known = true
    status.isFavorited = root['favorited'] as boolean
    if (typeof root['num_favorites'] === 'number') {
      status.favoriteCount = Math.max(0, root['num_favorites'] as number)
      status.hasFavoriteCount = true
    }
    return status
  }

  /**
   * Requests ErosN's short-lived torrent capability URL. The value is never
   * persisted or logged; the detail page consumes it immediately into a
   * private `.torrent` file before sending that file to the system share sheet.
   */
  static async issueTorrentLink(galleryId: number): Promise<string> {
    const normalizedGalleryId: number = Math.max(0, Math.floor(galleryId))
    if (normalizedGalleryId <= 0) {
      throw new Error('A gallery id is required to request a torrent link.')
    }
    if (!NhAccountSessionService.isAuthenticated()) {
      throw new Error('Sign in from Settings before requesting a torrent link.')
    }
    const root: Record<string, Object> = await NhApiClient.requestJsonMutation(
      `${API_V2_PREFIX}galleries/${normalizedGalleryId}/download?format=torrent`,
      http.RequestMethod.POST,
      '',
      'Torrent service rejected this request.',
    )
    const url: string = NhApiClient.asString(root['url'])
    if (!NhApiClient.isSafeIssuedTorrentUrl(url)) {
      throw new Error('Torrent service did not return a safe download link.')
    }
    return url
  }

  static imageUrl(mediaId: string, zeroBasedIndex: number, extension: string): string {
    return `${IMAGE_ROOT}/galleries/${mediaId}/${zeroBasedIndex + 1}.${extension}`
  }

  /**
   * Checks a freshly captured visible-browser session without reading a user
   * profile into native code. Only a 401 conclusively retires a candidate;
   * every other status uses the service's finite candidate-keyed delayed
   * retry budget. An existing verified session is invalidated later only by
   * its own 401 on an authenticated operation.
   */
  static async verifyAccountSession(): Promise<boolean> {
    const outcome: NhBrowserSessionVerificationOutcome = await NhApiClient.verifyCapturedAccountSession(
      NhArkWebSessionTransport.requestStatus(`${API_V2_PREFIX}user`),
    )
    return outcome === NhBrowserSessionVerificationOutcome.VERIFIED
  }

  /**
   * The one-time login confirmation must run in the visible Web component
   * that completed the challenge. A separately bootstrapped hidden Web host
   * is reserved for later API reads and must not decide whether this login
   * route can return to native UI.
   */
  static async verifyAccountSessionFromVisibleBrowser(
    controller: webview.WebviewController,
  ): Promise<NhBrowserSessionVerificationOutcome> {
    return NhApiClient.verifyCapturedAccountSession(
      NhArkWebSessionTransport.requestStatusFromCurrentDocument(
        controller,
        `${API_V2_PREFIX}user`,
      ),
    )
  }

  /**
   * Reads the ErosN-defined display profile only after a session has already
   * been promoted. The ArkWeb bridge returns four parsed strings rather than
   * HTML, cookie state, headers, or an API response body.
   */
  static async accountProfile(): Promise<NhAccountProfile> {
    if (!NhAccountSessionService.isAuthenticated()) {
      throw new Error('A signed-in account session is required to load the profile.')
    }
    const readToken = NhAccountSessionService.captureAuthenticatedReadToken()
    if (readToken === null) {
      throw new Error('Your account session is changing. Please try again.')
    }
    let response: NhArkWebAccountProfileResponse = await NhArkWebSessionTransport.requestAccountProfile()
    if (response.statusCode === 401) {
      // This profile bridge makes only fixed GET requests. A real 401 can
      // prove that a previously preserved regular-cookie token is stale, so
      // restore the current sealed non-HttpOnly fallback once before replaying
      // this idempotent read. Never share this helper with mutation paths.
      const recoveryPrepared: boolean = await NhApiClient.prepareIdempotentAuthenticatedReadRetryAfter401(readToken)
      if (recoveryPrepared && NhAccountSessionService.isAuthenticatedReadTokenCurrent(readToken)) {
        response = await NhArkWebSessionTransport.requestAccountProfile()
      }
      if (response.statusCode === 401) {
        // Profile is display enrichment, not an authoritative account check.
        // Even an actual replayed 401 may fail only this request; Favorites
        // remains the sole owner allowed to change durable session state.
        throw new Error('Your account session could not be rechecked. Please try again.')
      }
    }
    if (response.statusCode === 403) {
      throw new Error('Your account session needs to be refreshed in Settings.')
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`HTTP ${response.statusCode}`)
    }
    // The response may have completed while an explicit clear or a newer
    // verified promotion was durably taking ownership. Do not let a prior
    // session's successful profile payload reach a later account revision.
    if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(readToken)) {
      throw new Error('Your account session changed. Please try again.')
    }
    const profile: NhAccountProfile = new NhAccountProfile()
    profile.username = response.username
    profile.userUrl = response.userUrl
    profile.userId = response.userId
    profile.avatarUrl = response.avatarUrl
    if (!profile.hasIdentity()) {
      throw new Error('Account profile did not contain a valid identity.')
    }
    return profile
  }

  private static async verifyCapturedAccountSession(
    statusTask: Promise<number>,
  ): Promise<NhBrowserSessionVerificationOutcome> {
    try {
      const status: number = await statusTask
      hilog.info(ACCOUNT_LOG_DOMAIN, ACCOUNT_LOG_TAG, 'candidate account probe status=%{public}d', status)
      if (status >= 200 && status < 300) {
        return NhBrowserSessionVerificationOutcome.VERIFIED
      }
      if (status === 401) {
        NhAccountSessionService.rejectPendingVisibleBrowserSession()
        NhArkWebSessionTransport.resetForVisibleSessionCandidate()
        return NhBrowserSessionVerificationOutcome.REJECTED
      } else {
        // A 0, 403, 5xx, or other non-401 response can arrive while the
        // first-party login landing page or managed challenge is still
        // settling. It is not evidence that the browser-issued token is bad.
        const retryExhausted: boolean = NhAccountSessionService.deferPendingVisibleBrowserSession()
        // The candidate probe may have reloaded the retained ArkWeb host with
        // a different UA. The pending value is now gone, so make the next
        // active-session request bootstrap with the previously sealed UA
        // instead of reusing the failed candidate's ready document.
        NhArkWebSessionTransport.resetForVisibleSessionCandidate()
        return retryExhausted
          ? NhBrowserSessionVerificationOutcome.RETRY_EXHAUSTED
          : NhBrowserSessionVerificationOutcome.RETRY_SCHEDULED
      }
    } catch (_error) {
      hilog.error(ACCOUNT_LOG_DOMAIN, ACCOUNT_LOG_TAG, 'candidate account probe failed')
      // Keep a failed visible-document/origin/transport probe retryable. The
      // service applies its own finite candidate-keyed cooldown and budget,
      // so the page's one-second capture timer cannot flood retries.
      const retryExhausted: boolean = NhAccountSessionService.deferPendingVisibleBrowserSession()
      NhArkWebSessionTransport.resetForVisibleSessionCandidate()
      return retryExhausted
        ? NhBrowserSessionVerificationOutcome.RETRY_EXHAUSTED
        : NhBrowserSessionVerificationOutcome.RETRY_SCHEDULED
    }
  }

  private static async getJson(
    url: string,
    scope: NhJsonReadScope = NhJsonReadScope.PUBLIC,
    allowTransportCache: boolean = true,
  ): Promise<Record<string, Object>> {
    const value: Object = await NhApiClient.getJsonValue(url, scope, allowTransportCache)
    if (Array.isArray(value) || typeof value !== 'object' || value === null) {
      throw new Error('Expected an object response.')
    }
    return value as Record<string, Object>
  }

  private static async getJsonArray(url: string): Promise<Object[]> {
    const value: Object = await NhApiClient.getJsonValue(url)
    if (Array.isArray(value)) {
      return value as Object[]
    }
    // ErosN's observed contract is a top-level array. A small compatibility
    // allowance is intentionally limited to the two conventional array
    // envelopes below; it never treats an arbitrary object or an error body
    // as a comment list.
    const root: Record<string, Object> = NhApiClient.asRecord(value)
    if (Array.isArray(root['result'])) {
      return root['result'] as Object[]
    }
    if (Array.isArray(root['comments'])) {
      return root['comments'] as Object[]
    }
    if (root['error'] !== undefined || root['message'] !== undefined) {
      throw new Error('Comment service rejected the anonymous request.')
    }
    throw new Error('Comment service returned an unsupported response.')
  }

  /** Popular has no compatibility envelopes; only its documented bare array is valid. */
  private static async getBareJsonArray(
    url: string,
    allowTransportCache: boolean = true,
  ): Promise<Object[]> {
    const value: Object = await NhApiClient.getJsonValue(
      url,
      NhJsonReadScope.PUBLIC,
      allowTransportCache,
    )
    if (!Array.isArray(value)) {
      throw new Error('Expected an array response.')
    }
    return value as Object[]
  }

  private static async getJsonValue(
    url: string,
    scope: NhJsonReadScope = NhJsonReadScope.PUBLIC,
    allowTransportCache: boolean = true,
    denyRedirects: boolean = false,
    singleAttempt: boolean = false,
  ): Promise<Object> {
    // ArkWeb authority and the two-401 retirement boundary belong only to
    // explicit account reads. Public Browse/Search/Popular/Detail/Related/
    // Comments/PoW traffic must remain anonymous even while an account is
    // signed in: a public endpoint cannot prove that the account is stale.
    if ((scope === NhJsonReadScope.ACCOUNT_OWNED ||
      scope === NhJsonReadScope.ACCOUNT_OWNED_NON_RETIRING) &&
      NhAccountSessionService.isAuthenticated() &&
      NhApiClient.isAccountOwnedIdempotentReadUrl(url)) {
      let readToken = NhAccountSessionService.captureAuthenticatedReadToken()
      if (readToken === null) {
        throw new Error('Your account session is changing. Please try again.')
      }
      let response: NhArkWebSessionResponse = await NhArkWebSessionTransport.requestJson(url, 'GET')
      if (response.statusCode === 401) {
        // The browser may have rotated its access token while the retained
        // root document was idle. This is an idempotent GET, so a single
        // sealed-token fallback and one replay are safe. Mutation methods do
        // not call this branch because repeating a write can duplicate a user
        // action.
        const recoveryPrepared: boolean = await NhApiClient.prepareIdempotentAuthenticatedReadRetryAfter401(readToken)
        let replayExecuted: boolean = false
        if (recoveryPrepared && NhAccountSessionService.isAuthenticatedReadTokenCurrent(readToken)) {
          response = await NhArkWebSessionTransport.requestJson(url, 'GET')
          replayExecuted = true
        }
        if (replayExecuted && response.statusCode === 401 &&
          scope === NhJsonReadScope.ACCOUNT_OWNED) {
          // The visible native re-verification route can restore a fresh
          // access token from ArkWeb's retained first-party identity without
          // credentials. Try the same bounded browser-owned refresh before
          // persisting a marker that would otherwise make the user appear
          // signed out. A newly promoted session gets one fresh idempotent
          // replay; another 401 remains a request failure rather than a
          // second marker decision from this old read token.
          if (await NhArkWebSessionTransport.refreshFromRegularBrowserIdentityAfterAuthenticated401(readToken)) {
            const refreshedReadToken = NhAccountSessionService.captureAuthenticatedReadToken()
            if (refreshedReadToken === null) {
              throw new Error('Your account session changed. Please try again.')
            }
            readToken = refreshedReadToken
            response = await NhArkWebSessionTransport.requestJson(url, 'GET')
            if (response.statusCode === 401) {
              throw new Error('Your account session could not be rechecked. Please try again.')
            }
          }
        }
        if (replayExecuted && response.statusCode === 401 &&
          scope === NhJsonReadScope.ACCOUNT_OWNED) {
          // Only an actual replay that also returns 401 can prove the account
          // needs explicit verification after the retained browser identity
          // itself could not refresh. The original 401 is not enough when
          // recovery could not issue its bounded replay.
          if (!await NhAccountSessionService.requireVisibleVerificationAfterAccountGet401(readToken)) {
            throw new Error('Your account session changed. Please try again.')
          }
          throw new Error('Your account session needs to be refreshed in Settings.')
        }
        if (response.statusCode === 401) {
          throw new Error('Your account session could not be rechecked. Please try again.')
        }
      }
      if (response.statusCode === 403) {
        throw new Error('Your account session needs to be refreshed in Settings.')
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw new Error(`HTTP ${response.statusCode}`)
      }
      // The first response or its one recovery replay can become stale while
      // a durable clear/new verified session is in flight. Gate before JSON
      // parsing so Favorites and favourite status never receive prior-session
      // data after that ownership transition.
      if (!NhAccountSessionService.isAuthenticatedReadTokenCurrent(readToken)) {
        throw new Error('Your account session changed. Please try again.')
      }
      const browserValue: Object = JSON.parse(response.body) as Object
      if (browserValue === null) {
        throw new Error('Received an empty JSON response.')
      }
      return browserValue
    }
    let lastError: Error = new Error('Network request failed')
    const attemptLimit: number = singleAttempt ? 1 : 2
    for (let attempt: number = 0; attempt < attemptLimit; attempt++) {
      const request: http.HttpRequest = http.createHttp()
      try {
        const response: http.HttpResponse = await request.request(url, {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.STRING,
          usingCache: allowTransportCache,
          connectTimeout: CONNECT_TIMEOUT_MS,
          readTimeout: READ_TIMEOUT_MS,
          // Public browse reads preserve NetworkKit's documented default.
          // The fixed first-party random-ID leaf denies all redirects so it
          // cannot silently follow an unexpected cross-origin Location.
          maxRedirects: denyRedirects ? 0 : 30,
          // Native catalog reads are always anonymous. The exact account
          // endpoints above stay in ArkWeb; no other GET may replay browser
          // authority through NetworkKit or retire the sealed session.
          header: NhApiClient.publicJsonHeaders(),
        })
        if (response.responseCode < 200 || response.responseCode >= 300) {
          throw new Error(`HTTP ${response.responseCode}`)
        }
        const value: Object = JSON.parse(response.result as string) as Object
        if (value === null) {
          throw new Error('Received an empty JSON response.')
        }
        return value
      } catch (error) {
        lastError = error as Error
        if (attempt + 1 < attemptLimit) {
          await NhApiClient.delay(400)
        }
      } finally {
        request.destroy()
      }
    }
    throw lastError
  }

  /**
   * Prepares exactly one replay of an already authenticated idempotent read.
   * It does not issue a request itself, so POST/DELETE mutation paths cannot
   * accidentally inherit this recovery. A failed forced cookie replacement
   * leaves the caller's original 401 as a request failure; only a physically
   * issued replay can establish the verification boundary.
   */
  private static async prepareIdempotentAuthenticatedReadRetryAfter401(
    readToken: NhAccountAuthenticatedReadToken,
  ): Promise<boolean> {
    if (!await NhAccountSessionService.recoverRegularArkWebCookieJarAfterAuthenticated401(readToken)) {
      return false
    }
    NhArkWebSessionTransport.resetForSessionRefresh()
    return true
  }

  /**
   * One-shot authenticated mutation transport. API 24 uses `extraData`, not
   * the API-26 `body` field. The generic error intentionally omits response
   * payloads, which can contain a public comment or account-specific data.
   */
  private static async requestJsonMutation(
    url: string,
    method: http.RequestMethod,
    extraData: string,
    rejectedMessage: string,
  ): Promise<Record<string, Object>> {
    if (!NhApiClient.isFirstPartyApiV2Url(url)) {
      throw new Error('This account action is restricted to the first-party API.')
    }
    if (method !== http.RequestMethod.POST && method !== http.RequestMethod.DELETE) {
      throw new Error('This account action uses an unsupported request method.')
    }
    if (!NhAccountSessionService.isAuthenticated()) {
      throw new Error('Sign in from Settings before changing account data.')
    }
    const browserMethod: string = method === http.RequestMethod.POST ? 'POST' : 'DELETE'
    const response: NhArkWebSessionResponse = await NhArkWebSessionTransport.requestJson(
      url,
      browserMethod,
      extraData,
    )
    if (response.statusCode === 401) {
      // A mutation cannot be replayed safely: the server might already have
      // applied it even though the response reached ArkWeb as a 401. That one
      // response also cannot distinguish a stale regular cookie from a sealed
      // fallback that will recover on the next idempotent read. Preserve the
      // sealed record here; only explicit sign-out or a real replayed GET
      // followed by 401 may delete it.
      throw new Error('Your account session needs to be refreshed in Settings.')
    }
    if (response.statusCode === 403) {
      throw new Error('Your account session needs to be refreshed in Settings.')
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`${rejectedMessage} (HTTP ${response.statusCode}).`)
    }
    const value: Object = JSON.parse(response.body) as Object
    if (Array.isArray(value) || value === null || typeof value !== 'object') {
      throw new Error(`${rejectedMessage} The server response was invalid.`)
    }
    return value as Record<string, Object>
  }

  /** A single anonymous catalog POST with no cookie or authorization header. */
  private static async postPublicJsonArray(url: string, extraData: string): Promise<Object[]> {
    if (!NhApiClient.isFirstPartyApiV2Url(url)) {
      return []
    }
    const request: http.HttpRequest = http.createHttp()
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.POST,
        extraData: extraData,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        header: NhApiClient.publicJsonHeaders(),
      })
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return []
      }
      const value: Object = JSON.parse(response.result as string) as Object
      return Array.isArray(value) ? value as Object[] : []
    } catch (_error) {
      return []
    } finally {
      request.destroy()
    }
  }

  private static async solveCommentProofOfWork(): Promise<NhCommentProofOfWork> {
    const root: Record<string, Object> = await NhApiClient.getJson(`${API_V2_PREFIX}pow?action=comment`)
    const challenge: string = NhApiClient.asString(root['challenge'])
    const difficulty: number = NhApiClient.asNumber(root['difficulty'])
    if (!/^[0-9a-fA-F]{16,256}$/.test(challenge) || difficulty <= 0 ||
      difficulty > MAX_COMMENT_POW_DIFFICULTY) {
      throw new Error('Comment service returned an unsupported proof-of-work challenge.')
    }
    const proof: NhCommentProofOfWork = new NhCommentProofOfWork()
    proof.challenge = challenge
    for (let attempt: number = 0; attempt < MAX_COMMENT_POW_ATTEMPTS; attempt++) {
      const nonce: string = attempt.toString()
      if (NhApiClient.leadingZeroBits(NhApiClient.sha256(`${challenge}${nonce}`)) >= difficulty) {
        proof.nonce = nonce
        return proof
      }
      if ((attempt + 1) % COMMENT_POW_YIELD_INTERVAL === 0) {
        await NhApiClient.delay(0)
      }
    }
    throw new Error('Comment proof-of-work could not be completed safely.')
  }

  private static sha256(value: string): Uint8Array {
    const md = cryptoFramework.createMd('SHA256')
    md.updateSync({ data: new util.TextEncoder().encodeInto(value) })
    return md.digestSync().data
  }

  private static leadingZeroBits(bytes: Uint8Array): number {
    let count: number = 0
    for (let index: number = 0; index < bytes.length; index++) {
      const value: number = bytes[index]
      if (value === 0) {
        count += 8
        continue
      }
      for (let bit: number = 7; bit >= 0; bit--) {
        if ((value & (1 << bit)) !== 0) {
          return count
        }
        count += 1
      }
    }
    return count
  }

  private static async delay(milliseconds: number): Promise<void> {
    await new Promise<void>((resolve: () => void): void => {
      setTimeout(resolve, milliseconds)
    })
  }

  private static isFirstPartyApiV2Url(url: string): boolean {
    return url.startsWith(API_V2_PREFIX)
  }

  /**
   * This is deliberately an allowlist, not a first-party prefix test. These
   * two GETs are the only generic JSON reads that expose account-specific
   * state; profile uses its separate fixed `/info/` bridge.
   */
  private static isAccountOwnedIdempotentReadUrl(url: string): boolean {
    if (url.startsWith(`${API_V2_PREFIX}favorites?`)) {
      return true
    }
    const galleryFavoritePrefix: string = `${API_V2_PREFIX}galleries/`
    const galleryFavoriteSuffix: string = '/favorite'
    if (!url.startsWith(galleryFavoritePrefix) || !url.endsWith(galleryFavoriteSuffix)) {
      return false
    }
    const galleryId: string = url.slice(
      galleryFavoritePrefix.length,
      url.length - galleryFavoriteSuffix.length,
    )
    return /^[1-9][0-9]*$/.test(galleryId)
  }

  private static autocompleteType(value: string): string {
    const normalized: string = value.trim().toLowerCase()
    switch (normalized) {
      case 'tag':
      case 'tags':
      case 'female':
      case 'male':
      case 'mixed':
      case 'other':
        return 'tag'
      case 'parody':
      case 'parodies':
        return 'parody'
      case 'character':
      case 'characters':
        return 'character'
      case 'artist':
      case 'artists':
      case 'cosplayer':
        return 'artist'
      case 'group':
      case 'groups':
        return 'group'
      case 'language':
      case 'languages':
        return 'language'
      case 'category':
      case 'categories':
      case 'reclass':
        return 'category'
      default:
        return ''
    }
  }

  private static isSafeIssuedTorrentUrl(value: string): boolean {
    const url: string = value.trim()
    return url.length > 0 && url.length <= 4096 &&
      /^https:\/\/[A-Za-z0-9.-]+(?::[0-9]{1,5})?(?:[/?#]|$)/.test(url) &&
      !/[\s\\]/.test(url)
  }

  private static publicJsonHeaders(): Record<string, string> {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'NextN/1.0.0',
    }
  }

  private static async parseGalleryPage(root: Record<string, Object>): Promise<NhGalleryPageResult> {
    const result: NhGalleryPageResult = new NhGalleryPageResult()
    const rawItems: Object[] = NhApiClient.asArray(root['result'])
    rawItems.forEach((raw: Object): void => {
      const item: Record<string, Object> = NhApiClient.asRecord(raw)
      if (NhApiClient.asBoolean(item['blacklisted'])) {
        return
      }
      result.galleries.push(NhApiClient.parseGallerySummary(item))
    })
    result.totalPages = Math.max(1, NhApiClient.asNumber(root['num_pages']))
    await NhApiClient.enrichGallerySummaryTags(result.galleries)
    return result
  }

  /**
   * ErosN's v2 list mapper resolves tag ids in one bounded catalog batch
   * before cards render. The cache layer treats failures as optional visual
   * enrichment, so a name lookup can never fail a Browse/Search/Favorites
   * page or change its request/cursor state.
   */
  private static async enrichGallerySummaryTags(galleries: NhGallerySummary[]): Promise<void> {
    await NhTagCatalogService.enrich(
      galleries,
      async (ids: number[]): Promise<NhTag[]> => await NhApiClient.tagsByIds(ids),
    )
  }

  private static async tagsByIds(rawIds: number[]): Promise<NhTag[]> {
    const ids: number[] = rawIds
      .map((value: number): number => Math.floor(value))
      .filter((value: number): boolean => value > 0)
    if (ids.length === 0) {
      return []
    }
    const rawItems: Object[] = await NhApiClient.getBareJsonArray(
      `${API_ROOT}/api/v2/tags/ids?ids=${encodeURIComponent(ids.join(','))}`,
      false,
    )
    const tags: NhTag[] = []
    rawItems.forEach((raw: Object): void => {
      const item: Record<string, Object> = NhApiClient.asRecord(raw)
      const tag: NhTag = new NhTag()
      tag.id = NhApiClient.asNumber(item['id'])
      tag.type = NhApiClient.asString(item['type'])
      tag.name = NhApiClient.asString(item['name'])
      tag.count = NhApiClient.asNumber(item['count'])
      if (tag.id > 0 && tag.name.length > 0) {
        tags.push(tag)
      }
    })
    return tags
  }

  private static parseGallerySummary(item: Record<string, Object>): NhGallerySummary {
    const gallery: NhGallerySummary = new NhGallerySummary()
    gallery.id = NhApiClient.asNumber(item['id'])
    gallery.mediaId = NhApiClient.asString(item['media_id'])
    gallery.englishTitle = NhApiClient.asString(item['english_title'])
    gallery.japaneseTitle = NhApiClient.asString(item['japanese_title'])
    gallery.pageCount = NhApiClient.asNumber(item['num_pages'])
    gallery.uploadDate = NhApiClient.asNumber(item['upload_date'])
    gallery.favoriteCount = NhApiClient.asNumber(item['num_favorites'])
    gallery.thumbnailWidth = NhApiClient.asNumber(item['thumbnail_width'])
    gallery.thumbnailHeight = NhApiClient.asNumber(item['thumbnail_height'])
    gallery.thumbnailUrl = NhApiClient.cdnUrl(NhApiClient.asString(item['thumbnail']), THUMB_ROOT)
    const tagIds: Object[] = NhApiClient.asArray(item['tag_ids'])
    gallery.tagIds = tagIds.map((value: Object): number => NhApiClient.asNumber(value))
      .filter((value: number): boolean => value > 0)
    return gallery
  }

  private static parseGalleryDetail(root: Record<string, Object>): NhGalleryDetail {
    const detail: NhGalleryDetail = new NhGalleryDetail()
    detail.id = NhApiClient.asNumber(root['id'])
    detail.mediaId = NhApiClient.asString(root['media_id'])
    detail.pageCount = NhApiClient.asNumber(root['num_pages'])
    detail.favoriteCount = NhApiClient.asNumber(root['num_favorites'])
    detail.scanlator = NhApiClient.asString(root['scanlator'])
    detail.uploadDate = NhApiClient.asNumber(root['upload_date'])

    const title: Record<string, Object> = NhApiClient.asRecord(root['title'])
    detail.title = NhApiClient.asString(title['english'])
    detail.japaneseTitle = NhApiClient.asString(title['japanese'])
    detail.prettyTitle = NhApiClient.asString(title['pretty'])

    const cover: Record<string, Object> = NhApiClient.asRecord(root['cover'])
    detail.coverUrl = NhApiClient.cdnUrl(NhApiClient.asString(cover['path']), THUMB_ROOT)
    const thumbnail: Record<string, Object> = NhApiClient.asRecord(root['thumbnail'])
    detail.thumbnailUrl = NhApiClient.cdnUrl(NhApiClient.asString(thumbnail['path']), THUMB_ROOT)
    const coverWidth: number = NhApiClient.asNumber(root['thumbnail_width']) ||
      NhApiClient.asNumber(cover['width']) || NhApiClient.asNumber(thumbnail['width'])
    const coverHeight: number = NhApiClient.asNumber(root['thumbnail_height']) ||
      NhApiClient.asNumber(cover['height']) || NhApiClient.asNumber(thumbnail['height'])
    detail.coverWidth = Math.floor(coverWidth)
    detail.coverHeight = Math.floor(coverHeight)

    const rawTags: Object[] = NhApiClient.asArray(root['tags'])
    rawTags.forEach((raw: Object): void => {
      const item: Record<string, Object> = NhApiClient.asRecord(raw)
      const tag: NhTag = new NhTag()
      tag.id = NhApiClient.asNumber(item['id'])
      tag.type = NhApiClient.asString(item['type'])
      tag.name = NhApiClient.asString(item['name'])
      tag.count = NhApiClient.asNumber(item['count'])
      detail.tags.push(tag)
    })

    const rawPages: Object[] = NhApiClient.asArray(root['pages'])
    rawPages.forEach((raw: Object, index: number): void => {
      const item: Record<string, Object> = NhApiClient.asRecord(raw)
      const page: NhGalleryPage = new NhGalleryPage()
      page.number = Math.max(1, NhApiClient.asNumber(item['number']) || index + 1)
      page.extension = NhApiClient.fileExtension(NhApiClient.asString(item['path']))
      page.width = NhApiClient.asNumber(item['width'])
      page.height = NhApiClient.asNumber(item['height'])
      page.thumbnailUrl = NhApiClient.cdnUrl(NhApiClient.asString(item['thumbnail']), THUMB_ROOT)
      detail.pages.push(page)
    })
    if (detail.pageCount <= 0) {
      detail.pageCount = detail.pages.length
    }
    return detail
  }

  private static parseComments(rawItems: Object[]): NhComment[] {
    const comments: NhComment[] = []
    rawItems.forEach((raw: Object): void => {
      const comment: NhComment | null = NhApiClient.parseComment(NhApiClient.asRecord(raw))
      if (comment !== null) {
        comments.push(comment)
      }
    })
    return comments
  }

  private static parseComment(item: Record<string, Object>): NhComment | null {
    const comment: NhComment = new NhComment()
    comment.commentId = NhApiClient.asNumber(item['id'])
    comment.galleryId = NhApiClient.asNumber(item['gallery_id'])
    comment.postDate = NhApiClient.asNumber(item['post_date'])
    comment.body = NhApiClient.asString(item['body'])
    const poster: Record<string, Object> = NhApiClient.asRecord(item['poster'])
    comment.posterId = NhApiClient.asNumber(poster['id'])
    comment.posterName = NhApiClient.asString(poster['username'])
    // A stable List key is required by ArkUI; incomplete server records
    // cannot be displayed safely or attributed to a gallery.
    return comment.commentId > 0 ? comment : null
  }

  private static cdnUrl(path: string, root: string): string {
    if (path.length === 0) {
      return ''
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path
    }
    return `${root}/${path.replace(/^\/+/, '')}`
  }

  private static fileExtension(path: string): string {
    const segment: string = path.split('/').pop() ?? ''
    const extension: string = segment.split('.').pop()?.toLowerCase() ?? 'jpg'
    if (extension === 'jpeg') {
      return 'jpg'
    }
    if (extension === 'png' || extension === 'gif' || extension === 'webp' || extension === 'jpg') {
      return extension
    }
    return 'jpg'
  }

  private static asRecord(value: Object | undefined): Record<string, Object> {
    if (value === undefined || value === null || Array.isArray(value)) {
      return {} as Record<string, Object>
    }
    return value as Record<string, Object>
  }

  private static asArray(value: Object | undefined): Object[] {
    if (value === undefined || value === null || !Array.isArray(value)) {
      return []
    }
    return value as Object[]
  }

  private static asString(value: Object | undefined): string {
    return typeof value === 'string' ? value : ''
  }

  private static asNumber(value: Object | undefined): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value === 'string') {
      return Number(value) || 0
    }
    return 0
  }

  private static asBoolean(value: Object | undefined): boolean {
    return value === true
  }
}
