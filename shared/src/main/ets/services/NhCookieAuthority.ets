import { webview } from '@kit.ArkWeb'

/**
 * The sole native authority for ArkWeb CookieManager access.
 *
 * ArkWeb owns the live HttpOnly/challenge jar. Other layers may ask this
 * authority to initialize, inspect, hydrate, or persist that jar, but they
 * must never create a second Cookie policy or call WebCookieManager directly.
 */
export class NhCookieAuthority {
  private static readonly NH_ORIGIN: string = 'https://nhentai.net/'
  private static readonly AUTH_TOKEN_MAX_CHARS: number = 8192
  private static readonly MAX_RESPONSE_COOKIE_HEADERS: number = 32
  private static readonly MAX_RESPONSE_COOKIE_HEADER_CHARS: number = 32 * 1024

  static initialize(): void {
    webview.WebCookieManager.putAcceptCookieEnabled(true)
    webview.WebCookieManager.putAcceptThirdPartyCookieEnabled(true)
  }

  static isCookieAllowed(): boolean {
    return webview.WebCookieManager.isCookieAllowed()
  }

  static saveCookieSync(): void {
    webview.WebCookieManager.saveCookieSync()
  }

  static async saveCookieAsync(): Promise<void> {
    await webview.WebCookieManager.saveCookieAsync()
  }

  static fetchCookieSync(url: string, incognito: boolean): string {
    return webview.WebCookieManager.fetchCookieSync(url, incognito)
  }

  /**
   * Reads the regular ArkWeb profile used by the visible login component.
   * The SDK boolean selects the incognito cookie store; it is not an
   * include-HttpOnly flag. Auth-cookie filtering remains centralized in the
   * account-session service.
   */
  static async fetchAllAuthCookies(): Promise<webview.WebHttpCookie[]> {
    return await webview.WebCookieManager.fetchAllCookies(false)
  }

  static configCookieSync(
    url: string,
    cookie: string,
    incognito: boolean,
    includeHttpOnly: boolean,
  ): void {
    webview.WebCookieManager.configCookieSync(url, cookie, incognito, includeHttpOnly)
  }

  /**
   * Global first-party Set-Cookie sink for the native NH response lifecycle.
   * The transport has already bounded and isolated these values to
   * the fixed first-party v2 transport. No caller can choose another origin.
   */
  static storeFirstPartyResponseCookies(setCookieHeaders: string[]): void {
    if (setCookieHeaders.length === 0) {
      return
    }
    if (setCookieHeaders.length > NhCookieAuthority.MAX_RESPONSE_COOKIE_HEADERS) {
      throw new Error('account_response_cookie_count_rejected')
    }
    // Validate the complete batch before the first CookieManager mutation so
    // an invalid later header cannot turn a rejected response into a partial
    // in-memory jar update.
    const headers: string[] = setCookieHeaders.map((rawHeader: string): string => {
      const header: string = rawHeader.trim()
      const separator: number = header.indexOf('=')
      const cookieName: string = separator > 0 ? header.slice(0, separator).trim() : ''
      if (header.length === 0 ||
        header.length > NhCookieAuthority.MAX_RESPONSE_COOKIE_HEADER_CHARS ||
        !/^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$/.test(cookieName) ||
        /[\u0000-\u001F\u007F]/.test(header)) {
        throw new Error('account_response_cookie_header_rejected')
      }
      return header
    })
    headers.forEach((header: string): void => {
      webview.WebCookieManager.configCookieSync(
        NhCookieAuthority.NH_ORIGIN,
        header,
        false,
        // `includeHttpOnly` controls permission to replace an existing
        // HttpOnly cookie; it does not assign the attribute to the new value.
        // Always permit the first-party server response to rotate or delete
        // its existing HttpOnly cookie. The raw Set-Cookie header remains the
        // sole source of the resulting cookie's attributes.
        true,
      )
    })
    webview.WebCookieManager.saveCookieSync()
  }

  /** Fixed refresh-token sink; arbitrary names, origins and attributes are impossible. */
  static storeRefreshedAuthTokens(accessToken: string, refreshToken: string): void {
    const access: string = NhCookieAuthority.safeAuthToken(accessToken)
    const refresh: string = NhCookieAuthority.safeAuthToken(refreshToken)
    if (access.length > 0) {
      webview.WebCookieManager.configCookieSync(
        NhCookieAuthority.NH_ORIGIN,
        `access_token=${access}; Max-Age=1209600; Path=/; Secure; SameSite=Lax`,
        false,
        false,
      )
    }
    if (refresh.length > 0) {
      webview.WebCookieManager.configCookieSync(
        NhCookieAuthority.NH_ORIGIN,
        `refresh_token=${refresh}; Max-Age=1209600; Path=/; Secure; HttpOnly; SameSite=Lax`,
        false,
        true,
      )
    }
    if (access.length > 0 || refresh.length > 0) {
      webview.WebCookieManager.saveCookieSync()
    }
  }

  private static safeAuthToken(value: string): string {
    if (value.length <= 0 || value.length > NhCookieAuthority.AUTH_TOKEN_MAX_CHARS ||
      /[\u0000-\u001F\u007F;,]/.test(value)) {
      return ''
    }
    return value
  }
}
