import { webview } from '@kit.ArkWeb'
import { NhAccountSessionService } from './NhAccountSessionService'
import { NhBrowserSessionBoundary } from './NhBrowserSessionBoundary'

const API_PREFIX: string = 'https://nhentai.net/api/v2/'
const BOOTSTRAP_TIMEOUT_MS: number = 15000
const REQUEST_TIMEOUT_MS: number = 20000
const REQUEST_RESULT_TIMEOUT_MS: number = REQUEST_TIMEOUT_MS + 2000
const REQUEST_POLL_INTERVAL_MS: number = 100
const MAX_REQUEST_BODY_CHARS: number = 512 * 1024
const MAX_RESPONSE_BODY_CHARS: number = 4 * 1024 * 1024
const ACCOUNT_INFO_PATH: string = '/info/'
const MAX_ACCOUNT_PROFILE_HTML_CHARS: number = 512 * 1024
const MAX_ACCOUNT_PROFILE_USERNAME_CHARS: number = 256
const MAX_ACCOUNT_PROFILE_URL_CHARS: number = 2048
const MAX_ACCOUNT_PROFILE_ID_CHARS: number = 64
const MAX_ACCOUNT_PROFILE_AVATAR_CHARS: number = 2048

/**
 * A deliberately small result surface from a same-origin browser fetch. It
 * never contains response headers, cookies, a URL, or browser diagnostics.
 */
export class NhArkWebSessionResponse {
  statusCode: number = 0
  body: string = ''
}

/**
 * The only profile surface allowed to cross out of ArkWeb. The fixed script
 * extracts these four ErosN-defined values in the first-party document; HTML,
 * cookies, authorization values, headers, and page URLs never leave it.
 */
export class NhArkWebAccountProfileResponse {
  statusCode: number = 0
  username: string = ''
  userUrl: string = ''
  userId: string = ''
  avatarUrl: string = ''
}

/**
 * Owns the authenticated v2 transport after a visible ArkWeb login. This is
 * intentionally not a general browser proxy: it accepts only the fixed
 * first-party v2 origin and GET/POST/DELETE, and it never accepts native
 * Cookie, User-Agent, or Authorization values.
 *
 * The Web component is kept alive by the root host so same-origin fetches use
 * ArkWeb's existing TLS, HTTP, and regular-cookie context. This is the
 * crucial distinction from NetworkKit: matching a User-Agent alone does not
 * reproduce the browser transport that completed a managed challenge.
 */
export class NhArkWebSessionTransport {
  private static controller: webview.WebviewController | null = null
  private static isReady: boolean = false
  private static readyResolver: (() => void) | null = null
  private static readyRejecter: ((error: Error) => void) | null = null
  private static readyTimeoutId: number = -1
  private static bootstrapTask: Promise<void> | null = null
  private static browserIdentityRefreshTask: Promise<boolean> | null = null
  private static requestSequence: number = 0

  static attach(controller: webview.WebviewController): void {
    NhArkWebSessionTransport.controller = controller
    NhArkWebSessionTransport.isReady = false
    // The ArkWeb cookie store only becomes readable once a Web component
    // attaches. A cold-start restore that ran before this point may have
    // misclassified an empty store read as a missing session; give it the one
    // recorded retry instead of surfacing a fake re-verification gate.
    NhAccountSessionService.noteArkWebCookieStoreAvailable()
  }

  static detach(controller: webview.WebviewController): void {
    if (NhArkWebSessionTransport.controller !== controller) {
      return
    }
    NhArkWebSessionTransport.failBootstrap(new Error('The ArkWeb account transport was detached'))
    NhArkWebSessionTransport.controller = null
    NhArkWebSessionTransport.isReady = false
  }

  static observePageEnd(url: string): void {
    if (!NhBrowserSessionBoundary.isTrustedUrl(url)) {
      return
    }
    NhArkWebSessionTransport.isReady = true
    NhArkWebSessionTransport.completeBootstrap()
  }

  static observeLoadError(): void {
    NhArkWebSessionTransport.isReady = false
    NhAccountSessionService.recordArkWebTransportMainFrameLoadFailure()
    NhArkWebSessionTransport.failBootstrap(new Error('The ArkWeb account transport could not load'))
  }

  /**
   * A newly captured visible-browser candidate can have a different exact UA
   * from a prior signed-in surface. Force the next fixed-origin bootstrap to
   * apply that candidate UA before it makes the validation request.
   */
  static resetForVisibleSessionCandidate(): void {
    NhArkWebSessionTransport.resetForSessionRefresh()
  }

  /**
   * Forces the next fixed-origin operation to reload the retained Web host
   * using the current session UA and browser cookie state. Callers use this
   * only before a new idempotent request; mutation paths never retry.
   */
  static resetForSessionRefresh(): void {
    NhArkWebSessionTransport.isReady = false
  }

  /**
   * Same-origin JSON transport for authenticated v2 reads and explicit
   * mutations. The login Web context supplies its own cookies; the only
   * native value placed into the script is an already-serialized JSON body.
   */
  static async requestJson(url: string, method: string, body: string = ''): Promise<NhArkWebSessionResponse> {
    const normalizedMethod: string = method.toUpperCase()
    if (!NhArkWebSessionTransport.isFirstPartyApiUrl(url)) {
      throw new Error('Account transport is restricted to the first-party API')
    }
    if (normalizedMethod !== 'GET' && normalizedMethod !== 'POST' && normalizedMethod !== 'DELETE') {
      throw new Error('Account transport received an unsupported method')
    }
    if (body.length > MAX_REQUEST_BODY_CHARS) {
      throw new Error('Account request body is too large')
    }
    await NhArkWebSessionTransport.ensureReady()
    const controller: webview.WebviewController | null = NhArkWebSessionTransport.controller
    if (controller === null) {
      throw new Error('Account browser transport is unavailable')
    }
    const requestKey: string = NhArkWebSessionTransport.nextRequestKey()
    try {
      await controller.runJavaScript(
        NhArkWebSessionTransport.startFetchScript(
          requestKey,
          NhArkWebSessionTransport.relativeApiPath(url),
          normalizedMethod,
          body,
          false,
          true,
        ),
      )
      const rawResult: string = await NhArkWebSessionTransport.pollForResponse(controller, requestKey)
      return NhArkWebSessionTransport.parseResponse(rawResult)
    } finally {
      // The request result is transient page state. Delete it regardless of
      // completion so a later account operation cannot read a stale result.
      try {
        await controller.runJavaScript(NhArkWebSessionTransport.cleanupScript(requestKey))
      } catch (_error) {}
    }
  }

  /**
   * Performs the fixed-origin browser request needed to validate a newly
   * captured session. It returns only the HTTP status; account data never
   * enters ArkTS while the candidate is being checked.
   */
  static async requestStatus(url: string): Promise<number> {
    if (!NhArkWebSessionTransport.isFirstPartyApiUrl(url)) {
      throw new Error('Account transport is restricted to the first-party API')
    }
    await NhArkWebSessionTransport.ensureReady()
    const controller: webview.WebviewController | null = NhArkWebSessionTransport.controller
    if (controller === null) {
      throw new Error('Account browser transport is unavailable')
    }
    return NhArkWebSessionTransport.requestStatusFromCurrentDocument(controller, url)
  }

  /**
   * Checks a just-completed visible login before that Web component is removed.
   * The status-only request runs in the exact ArkWeb document that completed
   * Cloudflare and credential entry; it never exposes cookies or a response
   * body to ArkTS. The root-owned host remains the transport for later reads.
   */
  static async requestStatusFromCurrentDocument(
    controller: webview.WebviewController,
    url: string,
  ): Promise<number> {
    if (!NhArkWebSessionTransport.isFirstPartyApiUrl(url)) {
      throw new Error('Account transport is restricted to the first-party API')
    }
    // The visible login surface can temporarily make a Cloudflare challenge
    // its main document. Do not let the relative API path resolve from that
    // foreign origin. The injected script repeats this check because a
    // navigation can race between getUrl() and runJavaScript().
    if (!NhArkWebSessionTransport.isCurrentDocumentTrusted(controller)) {
      throw new Error('Account browser status requires a first-party document')
    }
    const requestKey: string = NhArkWebSessionTransport.nextRequestKey()
    try {
      await controller.runJavaScript(
        NhArkWebSessionTransport.startFetchScript(
          requestKey,
          NhArkWebSessionTransport.relativeApiPath(url),
          'GET',
          '',
          true,
          true,
        ),
      )
      const rawResult: string = await NhArkWebSessionTransport.pollForResponse(controller, requestKey)
      return NhArkWebSessionTransport.parseResponse(rawResult).statusCode
    } finally {
      try {
        await controller.runJavaScript(NhArkWebSessionTransport.cleanupScript(requestKey))
      } catch (_error) {}
    }
  }

  /**
   * Reloads the fixed first-party root so ArkWeb can renew its own Cookie jar,
   * then lets the caller replay the original request once. No sealed access
   * token is injected and no response may demote durable account ownership.
   */
  static async refreshSessionAfter401(): Promise<boolean> {
    const activeTask: Promise<boolean> | null = NhArkWebSessionTransport.browserIdentityRefreshTask
    if (activeTask !== null) {
      try {
        return await activeTask
      } catch (_error) {
        return false
      }
    }
    const task: Promise<boolean> = NhArkWebSessionTransport.refreshBrowserSession()
    NhArkWebSessionTransport.browserIdentityRefreshTask = task
    try {
      return await task
    } finally {
      if (NhArkWebSessionTransport.browserIdentityRefreshTask === task) {
        NhArkWebSessionTransport.browserIdentityRefreshTask = null
      }
    }
  }

  /** True while a retained-browser refresh owns the shared Webview controller. */
  static isBrowserIdentityRefreshActive(): boolean {
    return NhArkWebSessionTransport.browserIdentityRefreshTask !== null
  }

  private static async ensureReady(): Promise<void> {
    if (NhArkWebSessionTransport.isReady) {
      return
    }
    // A retained-browser refresh owns the same Webview controller and the
    // same single-slot ready signal as a bootstrap. If a refresh is in
    // flight, wait for it instead of starting a second navigation: a
    // concurrent loadUrl would overwrite the ready resolver and leave the
    // refresh promise permanently pending (and this caller would bootstrap
    // from a document that the refresh is about to replace).
    const refreshTask: Promise<boolean> | null = NhArkWebSessionTransport.browserIdentityRefreshTask
    if (refreshTask !== null) {
      try {
        await refreshTask
      } catch (_error) {}
      if (NhArkWebSessionTransport.isReady) {
        return
      }
    }
    if (NhArkWebSessionTransport.bootstrapTask !== null) {
      await NhArkWebSessionTransport.bootstrapTask
      return
    }
    const controller: webview.WebviewController | null = NhArkWebSessionTransport.controller
    if (controller === null) {
      throw new Error('Account browser transport is not attached')
    }
    const task: Promise<void> = NhArkWebSessionTransport.bootstrap(controller)
    NhArkWebSessionTransport.bootstrapTask = task
    try {
      await task
    } finally {
      if (NhArkWebSessionTransport.bootstrapTask === task) {
        NhArkWebSessionTransport.bootstrapTask = null
      }
    }
  }

  /**
   * Reads the ErosN identity pages inside the authenticated, root-owned
   * first-party ArkWeb document. This is intentionally separate from the
   * candidate status probe: promotion remains a body-free 2xx gate, then the
   * already-promoted session refreshes a display-safe profile asynchronously.
   */
  static async requestAccountProfile(): Promise<NhArkWebAccountProfileResponse> {
    await NhArkWebSessionTransport.ensureReady()
    const controller: webview.WebviewController | null = NhArkWebSessionTransport.controller
    if (controller === null) {
      throw new Error('Account browser transport is unavailable')
    }
    const requestKey: string = NhArkWebSessionTransport.nextRequestKey()
    try {
      await controller.runJavaScript(NhArkWebSessionTransport.startAccountProfileScript(requestKey))
      const rawResult: string = await NhArkWebSessionTransport.pollForResponse(controller, requestKey)
      return NhArkWebSessionTransport.parseAccountProfileResponse(rawResult)
    } finally {
      try {
        await controller.runJavaScript(NhArkWebSessionTransport.cleanupScript(requestKey))
      } catch (_error) {}
    }
  }

  private static async bootstrap(controller: webview.WebviewController): Promise<void> {
    NhArkWebSessionTransport.isReady = false
    // The regular ArkWeb CookieManager is the live session authority. A
    // sealed snapshot is only a cold-start fallback when that live jar has no
    // readable access token; failure to hydrate it must not prevent the root
    // navigation from using longer-lived browser cookies already owned by
    // ArkWeb (for example refresh_token or sessionid).
    if (NhAccountSessionService.hasRetainedAccount()) {
      try {
        await NhAccountSessionService.ensureRegularArkWebCookieJar()
      } catch (_error) {}
    }
    try {
      // Apply the UA captured from the visible login Web component before the
      // bridge makes its first navigation. ArkWeb owns the remaining browser
      // fingerprint; native HTTP never impersonates it.
      controller.setCustomUserAgent(
        NhAccountSessionService.requestUserAgent(controller.getUserAgent()),
      )
    } catch (_error) {}
    const ready: Promise<void> = new Promise<void>((resolve: () => void, reject: (error: Error) => void): void => {
      NhArkWebSessionTransport.readyResolver = resolve
      NhArkWebSessionTransport.readyRejecter = reject
      NhArkWebSessionTransport.readyTimeoutId = setTimeout((): void => {
        NhArkWebSessionTransport.failBootstrap(new Error('Account browser transport timed out'))
      }, BOOTSTRAP_TIMEOUT_MS)
    })
    try {
      controller.loadUrl(NhBrowserSessionBoundary.trustedOrigin())
    } catch (error) {
      NhArkWebSessionTransport.failBootstrap(error as Error)
    }
    await ready
  }

  private static async refreshBrowserSession(): Promise<boolean> {
    const controller: webview.WebviewController | null = NhArkWebSessionTransport.controller
    if (controller === null) {
      return false
    }
    try {
      const userAgent: string = NhAccountSessionService.requestUserAgent(controller.getUserAgent())
      if (userAgent.length === 0) {
        return false
      }
      controller.setCustomUserAgent(userAgent)
    } catch (_error) {
      return false
    }
    if (!await NhArkWebSessionTransport.loadTrustedSessionRefreshPage(controller)) {
      return false
    }
    try {
      if (!NhBrowserSessionBoundary.isTrustedUrl(controller.getUrl())) {
        return false
      }
    } catch (_error) {
      return false
    }
    // The refresh navigation has already allowed ArkWeb to consume every
    // response Set-Cookie. Keep this document ready; the caller now repeats
    // the original request once and derives Authorization from the refreshed
    // document.cookie, exactly as the normal request path does.
    NhArkWebSessionTransport.isReady = true
    await NhAccountSessionService.persistBrowserManagedCookies()
    return true
  }

  /**
   * Match ErosN's 401 repair: reload the authenticated root document so the
   * browser can consume its refresh cookie and rotate access_token. Loading
   * the login page here does not repair an existing session and can leave the
   * subsequent API replay on the same rejected token.
   */
  private static async loadTrustedSessionRefreshPage(
    controller: webview.WebviewController,
  ): Promise<boolean> {
    NhArkWebSessionTransport.isReady = false
    const ready: Promise<void> = new Promise<void>((resolve: () => void, reject: (error: Error) => void): void => {
      NhArkWebSessionTransport.readyResolver = resolve
      NhArkWebSessionTransport.readyRejecter = reject
      NhArkWebSessionTransport.readyTimeoutId = setTimeout((): void => {
        NhArkWebSessionTransport.failBootstrap(new Error('Account browser refresh timed out'))
      }, BOOTSTRAP_TIMEOUT_MS)
    })
    try {
      controller.loadUrl(`${NhBrowserSessionBoundary.trustedOrigin()}/`)
      await ready
      return true
    } catch (_error) {
      NhArkWebSessionTransport.failBootstrap(new Error('Account browser refresh failed'))
      return false
    }
  }

  private static completeBootstrap(): void {
    const resolve: (() => void) | null = NhArkWebSessionTransport.readyResolver
    NhArkWebSessionTransport.resetBootstrapSignals()
    if (resolve !== null) {
      resolve()
    }
  }

  private static failBootstrap(error: Error): void {
    const reject: ((error: Error) => void) | null = NhArkWebSessionTransport.readyRejecter
    NhArkWebSessionTransport.resetBootstrapSignals()
    if (reject !== null) {
      reject(error)
    }
  }

  private static resetBootstrapSignals(): void {
    if (NhArkWebSessionTransport.readyTimeoutId >= 0) {
      clearTimeout(NhArkWebSessionTransport.readyTimeoutId)
      NhArkWebSessionTransport.readyTimeoutId = -1
    }
    NhArkWebSessionTransport.readyResolver = null
    NhArkWebSessionTransport.readyRejecter = null
  }

  private static isFirstPartyApiUrl(url: string): boolean {
    return url.startsWith(API_PREFIX) && url.length <= 4096 && !/[\s\\]/.test(url)
  }

  private static relativeApiPath(url: string): string {
    return url.slice('https://nhentai.net'.length)
  }

  private static isCurrentDocumentTrusted(controller: webview.WebviewController): boolean {
    try {
      return NhBrowserSessionBoundary.isTrustedUrl(controller.getUrl())
    } catch (_error) {
      return false
    }
  }

  /**
   * ArkWeb does not consistently await a Promise returned from
   * runJavaScript(). Start the fetch explicitly, then have ArkTS poll only
   * the bounded response record. The browser keeps all cookie/token work in
   * document memory; only status and the response body cross this boundary.
   * This code executes only in the fixed first-party document and derives the
   * v2 authorization convention there, never in ArkTS.
   */
  private static startFetchScript(
    requestKey: string,
    relativeUrl: string,
    method: string,
    body: string,
    discardResponseBody: boolean = false,
    requireTrustedDocument: boolean = false,
  ): string {
    const encodedRequestKey: string = JSON.stringify(requestKey)
    const encodedUrl: string = JSON.stringify(relativeUrl)
    const encodedMethod: string = JSON.stringify(method)
    const encodedBody: string = JSON.stringify(body)
    const encodedDiscardResponseBody: string = discardResponseBody ? 'true' : 'false'
    const encodedRequireTrustedDocument: string = requireTrustedDocument ? 'true' : 'false'
    const encodedTrustedOrigin: string = JSON.stringify(NhBrowserSessionBoundary.trustedOrigin())
    return `
      (function nextNAccountRequest() {
        const slot = ${encodedRequestKey};
        window[slot] = { done: false };
        if (${encodedRequireTrustedDocument} &&
          (typeof location === 'undefined' || location.origin !== ${encodedTrustedOrigin})) {
          // The page navigated after the native getUrl() gate. Finish without
          // reading document cookies or issuing a relative request from a
          // challenge origin; ArkTS will defer this candidate with cooldown.
          window[slot] = { done: true, status: 0, body: '', oversized: false };
          return;
        }
        const headers = { 'Accept': 'application/json' };
        const match = /(?:^|;\\s*)access_token=([^;]+)/.exec(document.cookie);
        if (match && match[1]) {
          headers['Authorization'] = 'User ' + match[1];
        }
        const request = {
          method: ${encodedMethod},
          headers: headers,
          credentials: 'include',
          redirect: 'follow',
          cache: 'no-store',
        };
        if (${encodedMethod} === 'POST') {
          headers['Content-Type'] = 'application/json';
          request.body = ${encodedBody};
        }
        const aborter = typeof AbortController === 'function' ? new AbortController() : null;
        let timer = -1;
        if (aborter !== null) {
          request.signal = aborter.signal;
          timer = setTimeout(function () { aborter.abort(); }, ${REQUEST_TIMEOUT_MS});
        }
        const finish = function (result) {
          if (timer >= 0) {
            clearTimeout(timer);
          }
          window[slot] = result;
        };
        fetch(${encodedUrl}, request)
          .then(function (response) {
            if (${encodedDiscardResponseBody}) {
              finish({ done: true, status: response.status, body: '', oversized: false });
              return;
            }
            return response.text().then(function (responseBody) {
              if (responseBody.length > ${MAX_RESPONSE_BODY_CHARS}) {
                finish({ done: true, status: response.status, body: '', oversized: true });
                return;
              }
              finish({ done: true, status: response.status, body: responseBody, oversized: false });
            });
          })
          .catch(function (_error) {
            finish({ done: true, status: 0, body: '', oversized: false });
          });
      })()
    `
  }

  /**
   * Mirrors ErosN's current identity parsing exactly: `/info/` supplies the
   * `.username` text and parent `href` (whose first digit sequence is the
   * user id); the same-origin user page supplies `.bigavatar > img` `src`.
   * HTML is retained only in local JavaScript variables and the completion
   * record contains no response body.
   */
  private static startAccountProfileScript(requestKey: string): string {
    const encodedRequestKey: string = JSON.stringify(requestKey)
    const encodedTrustedOrigin: string = JSON.stringify(NhBrowserSessionBoundary.trustedOrigin())
    const encodedInfoPath: string = JSON.stringify(ACCOUNT_INFO_PATH)
    return `
      (function nextNAccountProfileRequest() {
        const slot = ${encodedRequestKey};
        window[slot] = { done: false };
        let timer = -1;
        const finish = function (result) {
          if (timer >= 0) {
            clearTimeout(timer);
          }
          window[slot] = result;
        };
        if (typeof location === 'undefined' || location.origin !== ${encodedTrustedOrigin}) {
          window[slot] = { done: true, status: 0, username: '', userUrl: '', userId: '', avatarUrl: '' };
          return;
        }
        const headers = { 'Accept': 'text/html,application/xhtml+xml' };
        const match = /(?:^|;\\s*)access_token=([^;]+)/.exec(document.cookie);
        if (match && match[1]) {
          headers['Authorization'] = 'User ' + match[1];
        }
        const request = {
          method: 'GET',
          headers: headers,
          credentials: 'include',
          redirect: 'follow',
          cache: 'no-store',
        };
        const aborter = typeof AbortController === 'function' ? new AbortController() : null;
        if (aborter !== null) {
          request.signal = aborter.signal;
          timer = setTimeout(function () { aborter.abort(); }, ${REQUEST_TIMEOUT_MS});
        }
        const boundedText = function (response) {
          return response.text().then(function (text) {
            return { status: response.status, text: text };
          });
        };
        const normalizeText = function (value, maxLength) {
          const text = typeof value === 'string' ? value.replace(/[\\u0000-\\u001F\\u007F]/g, ' ').trim() : '';
          return text.length > 0 && text.length <= maxLength ? text : '';
        };
        const safeAvatarUrl = function (rawValue) {
          const raw = normalizeText(rawValue, ${MAX_ACCOUNT_PROFILE_AVATAR_CHARS});
          if (!raw) {
            return '';
          }
          try {
            const parsed = new URL(raw, location.origin);
            return parsed.protocol === 'https:' && parsed.href.length <= ${MAX_ACCOUNT_PROFILE_AVATAR_CHARS}
              ? parsed.href
              : '';
          } catch (_error) {
            return '';
          }
        };
        fetch(${encodedInfoPath}, request)
          .then(boundedText)
          .then(function (infoResult) {
            if (infoResult.status < 200 || infoResult.status >= 300 ||
              infoResult.text.length > ${MAX_ACCOUNT_PROFILE_HTML_CHARS}) {
              finish({ done: true, status: infoResult.status, username: '', userUrl: '', userId: '', avatarUrl: '' });
              return;
            }
            const infoDocument = new DOMParser().parseFromString(infoResult.text, 'text/html');
            const usernameElement = infoDocument ? infoDocument.querySelector('.username') : null;
            const username = normalizeText(usernameElement ? usernameElement.textContent : '', ${MAX_ACCOUNT_PROFILE_USERNAME_CHARS});
            const parent = usernameElement ? usernameElement.parentElement : null;
            const rawUserUrl = parent ? parent.getAttribute('href') : '';
            let userProfileUrl;
            try {
              userProfileUrl = new URL(rawUserUrl || '', location.origin);
            } catch (_error) {
              finish({ done: true, status: infoResult.status, username: '', userUrl: '', userId: '', avatarUrl: '' });
              return;
            }
            const userIdMatch = /\\d+/.exec(rawUserUrl || '');
            const userId = userIdMatch ? userIdMatch[0] : '';
            const userUrl = userProfileUrl.pathname || '';
            if (!username || userProfileUrl.origin !== ${encodedTrustedOrigin} ||
              userProfileUrl.protocol !== 'https:' || !userUrl.startsWith('/') ||
              userUrl.length > ${MAX_ACCOUNT_PROFILE_URL_CHARS} ||
              !/^[0-9]{1,${MAX_ACCOUNT_PROFILE_ID_CHARS}}$/.test(userId)) {
              finish({ done: true, status: infoResult.status, username: '', userUrl: '', userId: '', avatarUrl: '' });
              return;
            }
            const profilePath = userProfileUrl.pathname + userProfileUrl.search;
            return fetch(profilePath, request)
              .then(boundedText)
              .then(function (profileResult) {
                if (profileResult.status < 200 || profileResult.status >= 300 ||
                  profileResult.text.length > ${MAX_ACCOUNT_PROFILE_HTML_CHARS}) {
                  finish({ done: true, status: profileResult.status, username: '', userUrl: '', userId: '', avatarUrl: '' });
                  return;
                }
                const profileDocument = new DOMParser().parseFromString(profileResult.text, 'text/html');
                const avatarElement = profileDocument ? profileDocument.querySelector('.bigavatar > img') : null;
                const avatarUrl = safeAvatarUrl(avatarElement ? avatarElement.getAttribute('src') : '');
                finish({
                  done: true,
                  status: profileResult.status,
                  username: username,
                  userUrl: userUrl,
                  userId: userId,
                  avatarUrl: avatarUrl,
                });
              });
          })
          .catch(function (_error) {
            finish({ done: true, status: 0, username: '', userUrl: '', userId: '', avatarUrl: '' });
          });
      })()
    `
  }

  private static async pollForResponse(controller: webview.WebviewController, requestKey: string): Promise<string> {
    const maxPolls: number = Math.ceil(REQUEST_RESULT_TIMEOUT_MS / REQUEST_POLL_INTERVAL_MS)
    for (let poll: number = 0; poll < maxPolls; poll++) {
      await NhArkWebSessionTransport.waitForRequestPoll()
      const rawResult: string = await controller.runJavaScript(
        NhArkWebSessionTransport.pollScript(requestKey),
      )
      if (NhArkWebSessionTransport.isCompletedResponse(rawResult)) {
        return rawResult
      }
    }
    throw new Error('Account browser request timed out')
  }

  private static waitForRequestPoll(): Promise<void> {
    return new Promise<void>((resolve: () => void): void => {
      setTimeout(resolve, REQUEST_POLL_INTERVAL_MS)
    })
  }

  private static nextRequestKey(): string {
    NhArkWebSessionTransport.requestSequence += 1
    if (NhArkWebSessionTransport.requestSequence > 2147480000) {
      NhArkWebSessionTransport.requestSequence = 1
    }
    return `__nextNAccountRequest_${NhArkWebSessionTransport.requestSequence}`
  }

  private static pollScript(requestKey: string): string {
    return `JSON.stringify(window[${JSON.stringify(requestKey)}] || { done: false })`
  }

  private static cleanupScript(requestKey: string): string {
    return `delete window[${JSON.stringify(requestKey)}]`
  }

  private static isCompletedResponse(raw: string): boolean {
    try {
      let parsed: Object = JSON.parse(raw) as Object
      if (typeof parsed === 'string') {
        parsed = JSON.parse(parsed as string) as Object
      }
      if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
        return false
      }
      return (parsed as Record<string, Object>)['done'] === true
    } catch (_error) {
      return false
    }
  }

  private static parseResponse(raw: string): NhArkWebSessionResponse {
    let parsed: Object = JSON.parse(raw) as Object
    // ArkWeb versions that serialize a returned JS string one additional
    // time still carry the same JSON payload. Accept that representation
    // without accepting any non-object response shape.
    if (typeof parsed === 'string') {
      parsed = JSON.parse(parsed as string) as Object
    }
    if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
      throw new Error('Account browser transport returned an invalid response')
    }
    const record: Record<string, Object> = parsed as Record<string, Object>
    if (record['done'] !== true) {
      throw new Error('Account browser transport returned an incomplete response')
    }
    const status: Object | undefined = record['status']
    const body: Object | undefined = record['body']
    const oversized: Object | undefined = record['oversized']
    if (oversized === true) {
      throw new Error('Account browser response was too large')
    }
    if (typeof status !== 'number' || !Number.isFinite(status) ||
      typeof body !== 'string' || body.length > MAX_RESPONSE_BODY_CHARS) {
      throw new Error('Account browser transport returned an invalid response')
    }
    const response: NhArkWebSessionResponse = new NhArkWebSessionResponse()
    response.statusCode = Math.floor(status)
    response.body = body as string
    return response
  }

  private static parseAccountProfileResponse(raw: string): NhArkWebAccountProfileResponse {
    let parsed: Object = JSON.parse(raw) as Object
    if (typeof parsed === 'string') {
      parsed = JSON.parse(parsed as string) as Object
    }
    if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
      throw new Error('Account profile transport returned an invalid response')
    }
    const record: Record<string, Object> = parsed as Record<string, Object>
    if (record['done'] !== true || typeof record['status'] !== 'number' ||
      !Number.isFinite(record['status'] as number)) {
      throw new Error('Account profile transport returned an incomplete response')
    }
    const response: NhArkWebAccountProfileResponse = new NhArkWebAccountProfileResponse()
    response.statusCode = Math.floor(record['status'] as number)
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return response
    }
    response.username = NhArkWebSessionTransport.profileString(
      record['username'],
      MAX_ACCOUNT_PROFILE_USERNAME_CHARS,
    )
    response.userUrl = NhArkWebSessionTransport.profileString(
      record['userUrl'],
      MAX_ACCOUNT_PROFILE_URL_CHARS,
    )
    response.userId = NhArkWebSessionTransport.profileString(record['userId'], MAX_ACCOUNT_PROFILE_ID_CHARS)
    response.avatarUrl = NhArkWebSessionTransport.profileString(
      record['avatarUrl'],
      MAX_ACCOUNT_PROFILE_AVATAR_CHARS,
    )
    if (!NhArkWebSessionTransport.isSafeProfileUsername(response.username) ||
      !NhArkWebSessionTransport.isSafeProfileUserUrl(response.userUrl) ||
      !/^[0-9]{1,64}$/.test(response.userId) ||
      (response.avatarUrl.length > 0 && !NhArkWebSessionTransport.isSafeProfileAvatarUrl(response.avatarUrl))) {
      throw new Error('Account profile transport returned an invalid profile')
    }
    return response
  }

  private static profileString(value: Object | undefined, maxLength: number): string {
    if (typeof value !== 'string') {
      return ''
    }
    const normalized: string = (value as string).trim()
    if (normalized.length === 0 || normalized.length > maxLength || /[\u0000-\u001F\u007F]/.test(normalized)) {
      return ''
    }
    return normalized
  }

  private static isSafeProfileUsername(value: string): boolean {
    return value.length > 0 && value.length <= MAX_ACCOUNT_PROFILE_USERNAME_CHARS &&
      !/[\u0000-\u001F\u007F]/.test(value)
  }

  private static isSafeProfileUserUrl(value: string): boolean {
    return value.length > 1 && value.length <= MAX_ACCOUNT_PROFILE_URL_CHARS &&
      value.startsWith('/') && !/[\s\\?#\u0000-\u001F\u007F]/.test(value)
  }

  private static isSafeProfileAvatarUrl(value: string): boolean {
    return value.length <= MAX_ACCOUNT_PROFILE_AVATAR_CHARS &&
      /^https:\/\/[^\s\\]+$/.test(value)
  }
}
