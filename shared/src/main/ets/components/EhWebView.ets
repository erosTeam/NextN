import { webview } from '@kit.ArkWeb'
import { AppStrings } from '../i18n/AppStrings'

/**
 * Generic native Web wrapper (HarmonyOS @kit.ArkWeb), based on NextE's
 * EhWebView (itself from V2Next's V2exWebView). JS + DOM storage are
 * on (the first-party session page needs them); darkMode is Off so the site's
 * own page styling isn't double-inverted; overScroll is off to kill the
 * bounce/glow; nestedScroll defers to a scrollable parent first when there is
 * one (harmless in a plain Column). Title/load callbacks let the host show
 * the live page title and react to load completion. Kept parent-agnostic (no
 * ListItem wrap) so it drops into a Column or a List alike.
 */
@ComponentV2
export struct EhWebView {
  @Param controller: webview.WebviewController = new webview.WebviewController();
  @Param documentStartScripts: Array<ScriptItem> = [];
  @Event onControllerAttached?: (controller: webview.WebviewController) => void;
  @Event onPageBegin?: (event?: OnPageBeginEvent) => void;
  @Event onPageEnd?: (event?: OnPageEndEvent) => void;
  @Event onLoadFinished?: (event?: OnLoadFinishedEvent) => void;
  @Event onProgressChange?: (event?: OnProgressChangeEvent) => void;
  @Event onErrorReceive?: (event: OnErrorReceiveEvent) => void;
  @Event onHttpErrorReceive?: (event: OnHttpErrorReceiveEvent) => void;
  @Event onConsole?: (event: OnConsoleEvent) => boolean;
  @Event onTitleReceive?: (event?: OnTitleReceiveEvent) => void;

  build() {
    Web({ src: '', controller: this.controller })
      .nestedScroll({
        scrollUp: NestedScrollMode.PARENT_FIRST,
        scrollDown: NestedScrollMode.PARENT_FIRST,
      })
      .overScrollMode(OverScrollMode.NEVER)
      .darkMode(WebDarkMode.Off)
      .backgroundColor(Color.White)
      .cacheMode(CacheMode.Online)
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .onlineImageAccess(true)
      .fileAccess(false)
      .javaScriptOnDocumentStart(this.documentStartScripts)
      .width('100%')
      .height('100%')
      .onControllerAttached(() => {
        if (this.onControllerAttached) {
          this.onControllerAttached(this.controller)
        }
      })
      .onPageBegin((event: OnPageBeginEvent) => {
        if (this.onPageBegin) {
          this.onPageBegin(event)
        }
      })
      .onPageEnd((event: OnPageEndEvent) => {
        if (this.onPageEnd) {
          this.onPageEnd(event)
        }
      })
      .onLoadFinished((event: OnLoadFinishedEvent) => {
        if (this.onLoadFinished) {
          this.onLoadFinished(event)
        }
      })
      .onProgressChange((event: OnProgressChangeEvent) => {
        if (this.onProgressChange) {
          this.onProgressChange(event)
        }
      })
      .onErrorReceive((event: OnErrorReceiveEvent) => {
        if (this.onErrorReceive) {
          this.onErrorReceive(event)
        }
      })
      .onHttpErrorReceive((event: OnHttpErrorReceiveEvent) => {
        if (this.onHttpErrorReceive) {
          this.onHttpErrorReceive(event)
        }
      })
      .onConsole((event: OnConsoleEvent): boolean => {
        return this.onConsole ? this.onConsole(event) : false
      })
      .onConfirm((event: OnConfirmEvent): boolean => {
        let settled: boolean = false
        const settle = (confirmed: boolean): void => {
          if (settled) {
            return
          }
          settled = true
          if (confirmed) {
            event.result.handleConfirm()
          } else {
            event.result.handleCancel()
          }
        }
        try {
          this.getUIContext().showAlertDialog({
            message: event.message,
            autoCancel: true,
            cancel: (): void => settle(false),
            primaryButton: {
              value: AppStrings.get('common_cancel'),
              action: (): void => settle(false),
            },
            secondaryButton: {
              value: AppStrings.get('common_ok'),
              action: (): void => settle(true),
            },
          })
        } catch (_error) {
          settle(false)
        }
        return true
      })
      .onTitleReceive((event: OnTitleReceiveEvent) => {
        if (this.onTitleReceive) {
          this.onTitleReceive(event)
        }
      })
  }
}
