import { common } from '@kit.AbilityKit'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { ReaderPagedSession, ReaderUnitKey } from '@reader-kit/core'
import { ReaderLabRequest, ReaderLabSurface, ReaderLabVisibilityState, connectReaderLabVisibility } from '@reader-kit/ui'
import { NextNReaderLabAdapter } from './NextNReaderLabAdapter'
import { connectLayoutSafeArea, LayoutSafeAreaState, ThemeTokens, nextNHdsTitle } from 'shared'

@ComponentV2
export struct NextNReaderLabPage {
  @Require @Param request: ReaderLabRequest
  @Local private session: ReaderPagedSession | null = null
  @Local private labVisibility: ReaderLabVisibilityState = connectReaderLabVisibility()
  @Local private routeActive: boolean = false
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  private unitKey: ReaderUnitKey = new ReaderUnitKey('', '', '')

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!context.applicationInfo.debug) return
    const adapter = new NextNReaderLabAdapter(context)
    this.unitKey = new ReaderUnitKey('nh', this.request.work, this.request.work)
    this.session = new ReaderPagedSession(adapter, adapter)
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.session !== null) {
          ReaderLabSurface({ session: this.session, initialUnit: this.unitKey, initialIndex: this.request.pageIndex,
            failurePage: this.request.failurePage,
            delayedMetricsPage: this.request.delayedMetricsPage,
            active: this.routeActive && this.labVisibility.foreground })
        }
      }
      .width('100%').height('100%')
      .padding({ top: this.safeArea.topAvoidHeight + ThemeTokens.TITLE_BAR_HEIGHT, bottom: this.safeArea.bottomAvoidHeight })
    }.titleBar(nextNHdsTitle($r('app.string.rkit_lab_title')))
    .onShown((): void => { this.routeActive = true })
    .onHidden((): void => { this.routeActive = false })
  }
}
