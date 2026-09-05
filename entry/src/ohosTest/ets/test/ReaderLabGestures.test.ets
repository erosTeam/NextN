import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON, PointerMatrix, Rect } from '@kit.TestKit'

async function pinchTrajectory(driver: Driver, bounds: Rect, expanding: boolean): Promise<void> {
  const points = PointerMatrix.create(2, 12)
  const centerX = (bounds.left + bounds.right) / 2
  const centerY = (bounds.top + bounds.bottom) / 2
  const width = bounds.right - bounds.left
  for (let step = 0; step < 12; step++) {
    const fraction = expanding ? 0.2 + 0.16 * step / 11 : 0.36 - 0.26 * step / 11
    points.setPoint(0, step, { x: Math.round(centerX - width * fraction), y: Math.round(centerY) })
    points.setPoint(1, step, { x: Math.round(centerX + width * fraction), y: Math.round(centerY) })
  }
  expect(await driver.injectMultiPointerAction(points, 600)).assertTrue()
}

/** Explicitly requested device gestures only; never runs in the normal data-test suite. */
export default function readerLabGesturesTest(): void {
  const parameters = abilityDelegatorRegistry.getArguments().parameters
  // Native arguments retain the '-s ' prefix; Hypium's log is a normalized copy.
  const selected = parameters['-s class']
  const work = parameters['-s readerLabWork']
  if ((selected !== 'ReaderLabPinchOut' && selected !== 'ReaderLabPinchReset') ||
    typeof work !== 'string' || work.length === 0) return
  describe(selected, (): void => {
    it('applyNativePinch', 0, async (): Promise<void> => {
      await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
        bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
        parameters: { readerLabWork: work },
      })
      const driver = Driver.create()
      await driver.delayMs(2500)
      const viewport = await driver.findComponent(ON.id('rkit-image-viewport'))
      const position = await driver.findComponent(ON.id('rkit-page-position'))
      expect(await position.getText()).assertContain('1 / ')
      // Resolve the live semantic viewport once, then execute an explicit two-pointer
      // trajectory. Component.pinchOut hit12x on this platform and is not a ratio oracle.
      const bounds = await viewport.getBounds()
      await pinchTrajectory(driver, bounds, true)
      await driver.delayMs(400)
      if (selected === 'ReaderLabPinchReset') {
        await pinchTrajectory(driver, bounds, false)
        await driver.delayMs(400)
      }
      console.info(`[ReaderLabGestureTest] native_injection_completed=${selected}`)
      // This checks command/page continuity only. The protocol captures actual pixels
      // and ReaderViewport logs for the owner's separate gesture acceptance.
      expect(await (await driver.findComponent(ON.id('rkit-page-position'))).getText()).assertContain('1 / ')
      // The native runner terminates its test process at completion. Capture this
      // terminal state before that teardown, not the app revealed underneath it.
      const cacheDir = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir
      expect(await driver.dumpLayout(`${cacheDir}/rkit-native-pinch-layout.json`)).assertTrue()
      expect(await driver.screenCap(`${cacheDir}/rkit-native-pinch.png`)).assertTrue()
      console.info(`[ReaderLabGestureTest] evidence_cache=${cacheDir}`)
    })
  })
}
