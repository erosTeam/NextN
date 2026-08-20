import { webview } from '@kit.ArkWeb'
import { NhBrowserSessionPhase, NhBrowserSessionStatus } from '../model/NhBrowserSessionState'

const TRUSTED_ORIGIN: string = 'https://nhentai.net'
const LOGIN_PATH: string = '/login/'
const LOGIN_URL: string = `${TRUSTED_ORIGIN}${LOGIN_PATH}`
const USER_SETTINGS_URL: string = `${TRUSTED_ORIGIN}/user/settings`

/**
 * The native session boundary owns exact-origin classification and capture.
 * The visible ArkWeb surface follows NextE's normal login navigation model so
 * managed cross-origin challenge resources can load without a native redirect
 * filter. This class never carries browser data itself.
 */
export class NhBrowserSessionBoundary {
  static preflight(): NhBrowserSessionStatus {
    const status: NhBrowserSessionStatus = new NhBrowserSessionStatus()
    try {
      status.cookieAccessAllowed = webview.WebCookieManager.isCookieAllowed()
      status.phase = status.cookieAccessAllowed
        ? NhBrowserSessionPhase.BROWSER_READY
        : NhBrowserSessionPhase.UNAVAILABLE
    } catch (_error) {
      status.phase = NhBrowserSessionPhase.UNAVAILABLE
    }
    return status
  }

  static loginUrl(): string {
    return LOGIN_URL
  }

  static trustedOrigin(): string {
    return TRUSTED_ORIGIN
  }

  static userSettingsUrl(): string {
    return USER_SETTINGS_URL
  }

  /**
   * Cookie lookup is URL-scoped in ArkWeb. Keep the completed first-party
   * login URL alongside the origin root so path-restricted session cookies
   * are not missed after a challenge or redirect.
   */
  static trustedSessionUrls(observedUrl: string = ''): string[] {
    const urls: string[] = []
    if (NhBrowserSessionBoundary.isTrustedUrl(observedUrl)) {
      urls.push(observedUrl)
    }
    urls.push(LOGIN_URL)
    urls.push(`${TRUSTED_ORIGIN}/`)
    return urls.filter((url: string, index: number): boolean => urls.indexOf(url) === index)
  }

  /**
   * Builds the public, credential-free gallery URL used by explicitly invoked
   * system sharing. It never receives a WebView URL, so a transient browser
   * navigation cannot contribute query parameters, cookies, or tokens.
   */
  static canonicalGalleryUrl(galleryId: number): string {
    if (!Number.isFinite(galleryId) || galleryId <= 0 || Math.floor(galleryId) !== galleryId) {
      throw new Error('A positive gallery id is required to create a public link')
    }
    return `${TRUSTED_ORIGIN}/g/${galleryId}/`
  }

  static isTrustedUrl(url: string): boolean {
    return url === TRUSTED_ORIGIN || url.startsWith(`${TRUSTED_ORIGIN}/`)
  }

  static observePageEnd(url: string): NhBrowserSessionStatus {
    const status: NhBrowserSessionStatus = new NhBrowserSessionStatus()
    if (!NhBrowserSessionBoundary.isTrustedUrl(url)) {
      // A managed challenge may be the main-frame destination temporarily.
      // It is not a native-session origin and therefore cannot be captured,
      // but it must remain part of the visible browser login instead of
      // being reported as an unavailable account surface.
      status.phase = NhBrowserSessionPhase.LOGIN_REQUIRED
      return status
    }
    status.cookieAccessAllowed = true
    status.phase = url.startsWith(`${TRUSTED_ORIGIN}${LOGIN_PATH}`)
      ? NhBrowserSessionPhase.LOGIN_REQUIRED
      : NhBrowserSessionPhase.TRUSTED_REDIRECT_OBSERVED
    return status
  }

  static authenticated(): NhBrowserSessionStatus {
    const status: NhBrowserSessionStatus = new NhBrowserSessionStatus()
    status.cookieAccessAllowed = true
    status.phase = NhBrowserSessionPhase.AUTHENTICATED
    return status
  }

  static blockedNavigation(): NhBrowserSessionStatus {
    const status: NhBrowserSessionStatus = new NhBrowserSessionStatus()
    status.phase = NhBrowserSessionPhase.UNAVAILABLE
    return status
  }
}
