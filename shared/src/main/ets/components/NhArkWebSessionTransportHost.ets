import { webview } from '@kit.ArkWeb'
import { NhArkWebSessionTransport } from '../services/NhArkWebSessionTransport'

/**
 * Root-owned ArkWeb context for authenticated first-party API fetches. It is
 * a one-pixel transparent overlay, so it cannot reserve space or alter the
 * visible HDS navigation/tabs geometry. It stays blank until an authenticated
 * API request explicitly bootstraps the fixed first-party origin.
 */
@ComponentV2
export struct NhArkWebSessionTransportHost {
  private controller: webview.WebviewController = new webview.WebviewController()

  aboutToDisappear(): void {
    NhArkWebSessionTransport.detach(this.controller)
  }

  build() {
    Web({ src: '', controller: this.controller, incognitoMode: false })
      .width(1)
      .height(1)
      .opacity(0)
      .position({ x: -1, y: -1 })
      .darkMode(WebDarkMode.Off)
      .backgroundColor(Color.Transparent)
      // This host owns the automatic first-party identity refresh after an
      // authenticated 401. It must execute the same fresh login navigation as
      // the visible native re-verification route: `None` prefers even expired
      // cached resources, which can leave the retained host probing an old
      // login document and then falsely persist a verification-required
      // boundary. `Online` keeps the regular CookieManager jar intact while
      // requiring the login navigation to reach the origin.
      .cacheMode(CacheMode.Online)
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .onlineImageAccess(true)
      .fileAccess(false)
      .onControllerAttached((): void => {
        NhArkWebSessionTransport.attach(this.controller)
      })
      .onPageEnd((event: OnPageEndEvent): void => {
        NhArkWebSessionTransport.observePageEnd(event.url)
      })
      .onErrorReceive((): void => {
        NhArkWebSessionTransport.observeLoadError()
      })
  }
}
