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
      .cacheMode(CacheMode.None)
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
