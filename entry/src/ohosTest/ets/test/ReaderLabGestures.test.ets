import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON, PointerMatrix, Rect } from '@kit.TestKit'
import { fileIo } from '@kit.CoreFileKit'
import { window } from '@kit.ArkUI'

async function captureReflow(driver: Driver, name: string): Promise<void> {
  const cache = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir
  const layout = `${cache}/rkit-reflow-${name}.json`
  const screen = `${cache}/rkit-reflow-${name}.png`
  if (fileIo.accessSync(layout)) fileIo.unlinkSync(layout)
  if (fileIo.accessSync(screen)) fileIo.unlinkSync(screen)
  expect(await driver.dumpLayout(layout)).assertTrue()
  expect(await driver.screenCap(screen)).assertTrue()
  console.info(`[ReaderLabReflowTest] checkpoint=${name}`)
}

async function rotateContinuous(driver: Driver): Promise<void> {
  const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()
  const mainWindow = await window.getLastWindow(ability.context)
  const original = mainWindow.getPreferredOrientation()
  try {
    await captureReflow(driver, 'zoomed-portrait')
    await mainWindow.setPreferredOrientation(window.Orientation.LANDSCAPE)
    await driver.delayMs(1600)
    await captureReflow(driver, 'landscape')
    // HDS can keep this destination in a split pane. Assert the actual display
    // orientation, not an invented full-window width for the reader child.
    const wide = await driver.getDisplaySize()
    expect(wide.x > wide.y).assertTrue()
    await mainWindow.setPreferredOrientation(window.Orientation.PORTRAIT)
    await driver.delayMs(1600)
    await captureReflow(driver, 'returned-portrait')
  } finally {
    await mainWindow.setPreferredOrientation(original)
    await driver.delayMs(600)
    console.info(`[ReaderLabReflowTest] restored_orientation_policy=${mainWindow.getPreferredOrientation()} original=${original}`)
  }
}

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
  const reflow = selected === 'ReaderLabContinuousReflow' || selected === 'ReaderLabContinuousReflowEdge'
  const continuous = selected === 'ReaderLabContinuousPinchPan' || selected === 'ReaderLabContinuousPinchResetScroll' ||
    reflow
  if ((selected !== 'ReaderLabPinchOut' && selected !== 'ReaderLabPinchReset' &&
    selected !== 'ReaderLabPinchPan' && selected !== 'ReaderLabPinchResetSwipe' && !continuous) ||
    typeof work !== 'string' || work.length === 0) return
  describe(selected, (): void => {
    it('applyNativePinch', 0, async (): Promise<void> => {
      await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
        bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
        parameters: { readerLabWork: work },
      })
      const driver = Driver.create()
      await driver.delayMs(2500)
      if (continuous) {
        await (await driver.findComponent(ON.id('rkit-layout'))).click()
        await (await driver.findComponent(ON.text('连续'))).click()
        await driver.delayMs(600)
      }
      const viewport = await driver.findComponent(ON.id(continuous ? 'rkit-continuous-list' : 'rkit-image-viewport'))
      const position = await driver.findComponent(ON.id('rkit-page-position'))
      expect(await position.getText()).assertContain('1 / ')
      // Resolve the live semantic viewport once, then execute an explicit two-pointer
      // trajectory. Component.pinchOut hit12x on this platform and is not a ratio oracle.
      const bounds = await viewport.getBounds()
      if (continuous) {
        await driver.swipe(Math.round((bounds.left + bounds.right) / 2), bounds.bottom - 60,
          Math.round((bounds.left + bounds.right) / 2), bounds.top + 60, 600)
        await driver.delayMs(1200)
      }
      await pinchTrajectory(driver, bounds, true)
      await driver.delayMs(400)
      if (selected === 'ReaderLabPinchReset' || selected === 'ReaderLabPinchResetSwipe' ||
        selected === 'ReaderLabContinuousPinchResetScroll') {
        await pinchTrajectory(driver, bounds, false)
        await driver.delayMs(400)
      } else if (selected === 'ReaderLabPinchPan' || selected === 'ReaderLabContinuousPinchPan' ||
        reflow) {
        // After the two-pointer sequence fully ends, a new horizontal drag must
        // pan the zoomed item, never advance its parent Swiper to page2.
        await driver.swipe(Math.round(bounds.right - (bounds.right - bounds.left) * 0.15),
          Math.round((bounds.top + bounds.bottom) / 2),
          Math.round(bounds.left + (bounds.right - bounds.left) * 0.15),
          Math.round((bounds.top + bounds.bottom) / 2), 600)
        await driver.delayMs(500)
      }
      if (selected === 'ReaderLabPinchResetSwipe') {
        await driver.swipe(Math.round(bounds.right - (bounds.right - bounds.left) * 0.15),
          Math.round((bounds.top + bounds.bottom) / 2),
          Math.round(bounds.left + (bounds.right - bounds.left) * 0.15),
          Math.round((bounds.top + bounds.bottom) / 2), 600)
        await driver.delayMs(500)
      }
      if (selected === 'ReaderLabContinuousPinchResetScroll') {
        await driver.swipe(Math.round((bounds.left + bounds.right) / 2), bounds.bottom - 60,
          Math.round((bounds.left + bounds.right) / 2), bounds.top + 60, 600)
        await driver.delayMs(1200)
      }
      if (reflow) {
        if (selected === 'ReaderLabContinuousReflowEdge') {
          for (let i = 0; i < 3; i++) {
            await driver.swipe(Math.round((bounds.left + bounds.right) / 2), bounds.top + 30,
              Math.round((bounds.left + bounds.right) / 2), bounds.bottom - 30, 600)
          }
          await driver.delayMs(400)
        }
        await rotateContinuous(driver)
        await driver.swipe(Math.round(bounds.left + 100), Math.round((bounds.top + bounds.bottom) / 2),
          Math.round(bounds.right - 100), Math.round((bounds.top + bounds.bottom) / 2), 600)
        await driver.delayMs(500)
        await captureReflow(driver, 'post-rotation-pan')
        await pinchTrajectory(driver, bounds, false)
        await driver.delayMs(400)
        await driver.swipe(Math.round((bounds.left + bounds.right) / 2), bounds.bottom - 60,
          Math.round((bounds.left + bounds.right) / 2), bounds.top + 60, 600)
        await driver.delayMs(1200)
        await captureReflow(driver, 'reset-scroll')
      }
      console.info(`[ReaderLabGestureTest] native_injection_completed=${selected}`)
      // This checks command/page continuity only. The protocol captures actual pixels
      // and ReaderViewport logs for the owner's separate gesture acceptance.
      expect(await (await driver.findComponent(ON.id('rkit-page-position'))).getText())
        .assertContain(selected === 'ReaderLabPinchResetSwipe' ? '2 / ' : '1 / ')
      // The native runner terminates its test process at completion. Capture this
      // terminal state before that teardown, not the app revealed underneath it.
      const cacheDir = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir
      const layoutPath = `${cacheDir}/rkit-native-pinch-layout.json`
      const screenPath = `${cacheDir}/rkit-native-pinch.png`
      // Driver.dumpLayout can leave trailing bytes when replacing a larger capture.
      // Remove only these two test-owned exports; received protocol artifacts stay intact.
      if (fileIo.accessSync(layoutPath)) fileIo.unlinkSync(layoutPath)
      if (fileIo.accessSync(screenPath)) fileIo.unlinkSync(screenPath)
      expect(await driver.dumpLayout(layoutPath)).assertTrue()
      expect(await driver.screenCap(screenPath)).assertTrue()
      console.info(`[ReaderLabGestureTest] evidence_cache=${cacheDir}`)
    })
  })
}
