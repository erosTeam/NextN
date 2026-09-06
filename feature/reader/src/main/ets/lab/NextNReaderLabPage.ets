import { common } from '@kit.AbilityKit'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { ReaderPagedSession, ReaderUnitKey, ReaderInputPort } from '@reader-kit/core'
import { ReaderLabRequest, ReaderLabSurface, ReaderSurface, ReaderTrialWindow, ReaderLabVisibilityState, connectReaderLabVisibility, ReaderLabAssetProbe, ReaderVolumeKeys } from '@reader-kit/ui'
import { NextNReaderLabAdapter } from './NextNReaderLabAdapter'
import { connectLayoutSafeArea, LayoutSafeAreaState, ThemeTokens, nextNHdsTitle } from 'shared'

@ComponentV2
export struct NextNReaderLabPage {
  @Require @Param request: ReaderLabRequest
  @Event onClose: () => void = () => {}
  @Local private session: ReaderPagedSession | null = null
  @Local private labVisibility: ReaderLabVisibilityState = connectReaderLabVisibility()
  @Local private routeActive: boolean = false
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  private unitKey: ReaderUnitKey = new ReaderUnitKey('', '', '')
  private trialWindow: ReaderTrialWindow = new ReaderTrialWindow()
  private input: ReaderInputPort = new ReaderInputPort()
  private volumeKeys: ReaderVolumeKeys = new ReaderVolumeKeys(this.input)

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!context.applicationInfo.debug) return
    if (this.request.readingChrome) this.trialWindow.open(context)
    const adapter = new NextNReaderLabAdapter(context)
    this.unitKey = new ReaderUnitKey('nh', this.request.work, this.request.work)
    this.session = new ReaderPagedSession(adapter, new ReaderLabAssetProbe(adapter, this.request.thumbnailFailurePage))
  }

  aboutToDisappear(): void { this.volumeKeys.close(); this.trialWindow.close() }

  @Monitor('routeActive', 'labVisibility.foreground')
  syncVolumeKeys(): void {
    this.volumeKeys.setActive(this.session !== null && this.request.readingChrome && this.request.volumeKeys &&
      this.routeActive && this.labVisibility.foreground)
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.session !== null) {
          if (this.request.readingChrome) {
            ReaderSurface({ session: this.session, initialUnit: this.unitKey, initialIndex: this.request.pageIndex,
              input: this.input,
              active: this.routeActive && this.labVisibility.foreground,
              topInset: this.safeArea.topAvoidHeight, bottomInset: this.safeArea.bottomAvoidHeight,
              accent: ThemeTokens.BRAND, onClose: this.onClose })
          } else {
          ReaderLabSurface({ session: this.session, initialUnit: this.unitKey, initialIndex: this.request.pageIndex,
            failurePage: this.request.failurePage,
            failureLayout: this.request.failureLayout,
            delayedMetricsPage: this.request.delayedMetricsPage,
            active: this.routeActive && this.labVisibility.foreground })
          }
        }
      }
      .width('100%').height('100%')
      .padding({ top: this.request.readingChrome ? 0 : this.safeArea.topAvoidHeight + ThemeTokens.TITLE_BAR_HEIGHT,
        bottom: this.request.readingChrome ? 0 : this.safeArea.bottomAvoidHeight })
    }.titleBar(nextNHdsTitle($r('app.string.rkit_lab_title')))
    .hideTitleBar(this.request.readingChrome)
    .onBackPressed((): boolean => {
      if (!this.request.readingChrome) return false
      this.onClose()
      return true
    })
    .onShown((): void => { this.routeActive = true })
    .onHidden((): void => { this.routeActive = false })
  }
}
