import { webview } from '@kit.ArkWeb'
import { HdsNavDestination } from '@kit.UIDesignKit'
import {
  DiagnosticLogger,
  EhWebView,
  NhAccountSessionService,
  SecondaryListScaffold,
  ThemeTokens,
  nextNHdsTitleBar,
} from 'shared'

/**
 * Generic in-app NH WebView escape hatch, ported from NextE's GalleryWebPage.
 * The scaffold's List owns the scroll; the Web's nestedScroll PARENT_FIRST
 * bubbles into it so the page scrolls UNDER the immersive title bar. The
 * title-bar menu carries browser-style history nav (back / forward / refresh)
 * because the site's pages have deep internal links.
 */
@ComponentV2
export struct GalleryWebPage {
  @Param url: string = ''
  @Param title: string = ''
  @Local loading: boolean = true
  @Local controllerReady: boolean = false
  // Live <title> from the loaded page (onTitleReceive); falls back to the
  // passed title/url until it arrives.
  @Local pageTitle: string = ''
  // Toolbar back/forward enablement, refreshed after each navigation
  // (WebviewController.accessBackward/Forward).
  @Local canBack: boolean = false
  @Local canForward: boolean = false
  private controller: webview.WebviewController = new webview.WebviewController()
  private scroller: Scroller = new Scroller()
  private loadedUrl: string = ''

  private titleText(): string {
    if (this.pageTitle.length > 0) {
      return this.pageTitle
    }
    return this.title.length > 0 ? this.title : this.url
  }

  private updateNavState(): void {
    if (!this.controllerReady) {
      return
    }
    try {
      this.canBack = this.controller.accessBackward()
      this.canForward = this.controller.accessForward()
    } catch (_error) {
      this.canBack = false
      this.canForward = false
    }
  }

  // Back / forward / refresh in the title-bar menu (same Record shape as the
  // shell's tab menus, ported from NextE GalleryWebPage).
  private webMenu(): Record<string, Object> {
    const back: Record<string, Object> = {
      'label': $r('app.string.web_nav_back'),
      'icon': $r('sys.symbol.chevron_left'),
      'isEnabled': this.canBack,
      'action': () => {
        if (this.controllerReady && this.controller.accessBackward()) {
          this.controller.backward()
        }
      },
    }
    const forward: Record<string, Object> = {
      'label': $r('app.string.web_nav_forward'),
      'icon': $r('sys.symbol.chevron_right'),
      'isEnabled': this.canForward,
      'action': () => {
        if (this.controllerReady && this.controller.accessForward()) {
          this.controller.forward()
        }
      },
    }
    const refresh: Record<string, Object> = {
      'label': $r('app.string.web_nav_refresh'),
      'icon': $r('sys.symbol.arrow_clockwise'),
      'isEnabled': true,
      'action': () => {
        if (this.controllerReady) {
          this.controller.refresh()
        }
      },
    }
    const items: Record<string, Object>[] = [
      { 'content': back },
      { 'content': forward },
      { 'content': refresh },
    ]
    return { 'value': items, 'maxCount': 3 }
  }

  private titleBarOpts(): Record<string, Object> {
    const title: Record<string, Object> = { 'mainTitle': this.titleText() }
    const content: Record<string, Object> = { 'title': title, 'menu': this.webMenu() }
    return nextNHdsTitleBar(content)
  }

  private loadIfReady(): void {
    if (!this.controllerReady || this.url.length === 0 || this.loadedUrl === this.url) {
      return
    }
    this.loadedUrl = this.url
    this.controller.setCustomUserAgent(this.sessionUserAgent())
    this.loadWithSessionIdentity(this.url)
  }

  // NH session cookies are issued against one browser user agent, so the
  // WebView must carry the same session UA instead of NextE's fixed
  // EhConstants.USER_AGENT.
  private sessionUserAgent(): string {
    try {
      return NhAccountSessionService.requestUserAgent(this.controller.getUserAgent())
    } catch (_error) {
      return NhAccountSessionService.requestUserAgent()
    }
  }
  private async loadWithSessionIdentity(url: string): Promise<void> {
    // NH keeps the session in ArkWeb's regular cookie jar, which this regular
    // WebView shares. Only the cold-start hydration needs to be ensured before
    // the first navigation; NextE instead injects EhCookieStore cookies per
    // cookie because EH keeps them in a separate store.
    try {
      if (NhAccountSessionService.isAuthenticated()) {
        await NhAccountSessionService.ensureRegularArkWebCookieJar()
      }
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.warn('webview', 'gallery_webview_session_prepare_failed', e.message)
    }
    this.safeLoadUrl(url)
  }

  private safeLoadUrl(url: string): void {
    try {
      this.controller.loadUrl(url)
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.warn('webview', 'gallery_webview_load_url_failed', e.message)
      this.loading = false
    }
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        // The scaffold's first row insets past the status bar + title bar;
        // the Web (full-bleed ListItem, height 100%) scrolls UNDER the
        // immersive title bar as nestedScroll feeds the List.
        SecondaryListScaffold({
          scroller: this.scroller,
          horizontalPadding: 0,
          bottomPadding: 0,
          listSpace: 0,
        }) {
          ListItem() {
            EhWebView({
              controller: this.controller,
              onControllerAttached: () => {
                this.controllerReady = true
                this.loadIfReady()
              },
              onPageBegin: () => {
                this.loading = true
              },
              onPageEnd: () => {
                this.loading = false
                this.updateNavState()
              },
              onErrorReceive: () => {
                this.loading = false
              },
              onTitleReceive: (event?: OnTitleReceiveEvent) => {
                if (event !== undefined && event.title.length > 0) {
                  this.pageTitle = event.title
                }
              },
            })
          }
          .height('100%')
          .clip(false)
        }

        if (this.loading) {
          LoadingProgress()
            .width(ThemeTokens.LOADING_SIZE)
            .height(ThemeTokens.LOADING_SIZE)
            .color(ThemeTokens.BRAND)
        }
      }
      .width('100%')
      .height('100%')
    }
    .titleBar(this.titleBarOpts())
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
