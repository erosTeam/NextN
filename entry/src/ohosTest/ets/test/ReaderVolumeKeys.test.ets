import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON, PointerMatrix } from '@kit.TestKit'
import { KeyCode } from '@kit.InputKit'
import { audio } from '@kit.AudioKit'
import { fileIo } from '@kit.CoreFileKit'

async function captureVolume(driver: Driver, name: string): Promise<void> {
  const cache = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir
  const layout = `${cache}/rkit-volume-${name}.json`
  const screen = `${cache}/rkit-volume-${name}.png`
  if (fileIo.accessSync(layout)) fileIo.unlinkSync(layout)
  if (fileIo.accessSync(screen)) fileIo.unlinkSync(screen)
  expect(await driver.dumpLayout(layout)).assertTrue()
  expect(await driver.screenCap(screen)).assertTrue()
}
async function volumePage(driver: Driver): Promise<number> {
  return Number((await (await driver.findComponent(ON.id('rkit-chrome-page'))).getText()).split('/')[0].trim())
}
async function volumeKey(driver: Driver, key: number, page: number): Promise<void> {
  await driver.triggerKey(key)
  await driver.delayMs(650)
  const actual = await volumePage(driver)
  if (actual !== page) await captureVolume(driver, 'exception')
  expect(actual).assertEqual(page)
}
async function volumeImage(driver: Driver): Promise<void> {
  for (let attempt = 0; attempt < 40; attempt++) {
    if (await driver.findComponent(ON.type('Image').within(ON.id('rkit-image-viewport'))) !== null &&
      await driver.findComponent(ON.type('LoadingProgress').within(ON.id('rkit-image-viewport'))) === null) return
    await driver.delayMs(500)
  }
  expect(false).assertTrue()
}


async function volumeReleaseTrial(work: string, unit: string): Promise<void> {
  const driver = Driver.create()
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  const manager = audio.getAudioManager().getVolumeManager()
  const usage = audio.StreamUsage.STREAM_USAGE_MUSIC
  const baseline = manager.getVolumeByStream(usage)
  await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
    parameters: { readerLabWork: work, readerLabUnit: unit,
      readerLabChrome: 'true', readerLabVolumeKeys: 'true' } })
  await driver.delayMs(1800); await volumeImage(driver)
  await volumeKey(driver, KeyCode.KEYCODE_VOLUME_DOWN, 2)
  expect(manager.getVolumeByStream(usage)).assertEqual(baseline)
  await (await driver.findComponent(ON.id('rkit-close'))).click()
  await driver.delayMs(700)
  expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
  await captureVolume(driver, 'release-host')
  const increase = baseline < manager.getMaxVolumeByStream(usage)
  const key = increase ? KeyCode.KEYCODE_VOLUME_UP : KeyCode.KEYCODE_VOLUME_DOWN
  const inverse = increase ? KeyCode.KEYCODE_VOLUME_DOWN : KeyCode.KEYCODE_VOLUME_UP
  try {
    await driver.triggerKey(key); await driver.delayMs(500)
    const changed = manager.getVolumeByStream(usage)
    console.info(`[ReaderVolumeRelease] before=${baseline} after=${changed} increase=${increase}`)
    await captureVolume(driver, 'release-system')
    expect(changed).assertEqual(baseline + (increase ? 1 : -1))
  } finally {
    if (manager.getVolumeByStream(usage) !== baseline) {
      await driver.triggerKey(inverse); await driver.delayMs(500)
    }
    console.info(`[ReaderVolumeRelease] restored=${manager.getVolumeByStream(usage)} expected=${baseline}`)
    expect(manager.getVolumeByStream(usage)).assertEqual(baseline)
    await driver.delayMs(2200)
    await captureVolume(driver, 'release-restored')
  }
}

export default function readerVolumeKeysTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  const work = args['-s readerLabWork']
  const unit = args['-s readerLabUnit']
  if (args['-s class'] === 'ReaderVolumeReleaseTrial' && typeof work === 'string' && work.length > 0) {
    describe('ReaderVolumeReleaseTrial', (): void => {
      it('closeReturnsRealSystemVolumeAndRestoresBaseline', 0, async (): Promise<void> => {
        await volumeReleaseTrial(work, typeof unit === 'string' ? unit : '')
      })
    })
    return
  }
  if (args['-s class'] !== 'ReaderVolumeKeysTrial' || typeof work !== 'string' || work.length === 0) return
  describe('ReaderVolumeKeysTrial', (): void => {
    it('logicalKeysRespectZoomMenuAndRouteLifecycle', 0, async (): Promise<void> => {
      const driver = Driver.create()
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
        parameters: { readerLabWork: work, readerLabUnit: typeof unit === 'string' ? unit : '',
          readerLabChrome: 'true', readerLabVolumeKeys: 'true' } })
      await driver.delayMs(1800); await volumeImage(driver)
      expect(await volumePage(driver)).assertEqual(1)
      await captureVolume(driver, 'baseline')
      await volumeKey(driver, KeyCode.KEYCODE_VOLUME_DOWN, 2)
      await volumeImage(driver); await captureVolume(driver, 'next')
      await (await driver.findComponent(ON.id('rkit-runtime-settings'))).click()
      await volumeKey(driver, KeyCode.KEYCODE_VOLUME_DOWN, 2)
      await (await driver.findComponent(ON.text('右→左'))).click()
      await driver.delayMs(600)
      await volumeKey(driver, KeyCode.KEYCODE_VOLUME_DOWN, 3)
      await volumeImage(driver); await captureVolume(driver, 'rtl-next')
      await volumeKey(driver, KeyCode.KEYCODE_VOLUME_UP, 2)
      await volumeImage(driver)
      const viewport = await (await driver.findComponent(ON.id('rkit-image-viewport'))).getBounds()
      const x = Math.round((viewport.left + viewport.right) / 2)
      const y = Math.round((viewport.top + viewport.bottom) / 2)
      const original = await (await driver.findComponent(ON.type('Image').within(ON.id('rkit-image-viewport')))).getBounds()
      await driver.doubleClick(x, y); await driver.delayMs(500)
      const zoomed = await (await driver.findComponent(ON.type('Image').within(ON.id('rkit-image-viewport')))).getBounds()
      expect(zoomed.right - zoomed.left > original.right - original.left ||
        zoomed.bottom - zoomed.top > original.bottom - original.top).assertTrue()
      await volumeKey(driver, KeyCode.KEYCODE_VOLUME_DOWN, 2)
      await captureVolume(driver, 'zoom-blocked')
      const ability = await delegator.getCurrentTopAbility()
      try {
        await delegator.doAbilityBackground(ability); await driver.delayMs(500)
        expect(delegator.getAbilityState(ability)).assertEqual(abilityDelegatorRegistry.AbilityLifecycleState.BACKGROUND)
        await captureVolume(driver, 'background')
      } finally {
        await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
      }
      await driver.delayMs(900)
      await volumeKey(driver, KeyCode.KEYCODE_VOLUME_DOWN, 2)
      await captureVolume(driver, 'restored-blocked')
      // Double-tap cycles fit -> 2x -> native -> fit; it is not a universal reset.
      const points = PointerMatrix.create(2, 12)
      for (let step = 0; step < 12; step++) {
        const distance = (viewport.right - viewport.left) * (0.36 - 0.29 * step / 11)
        points.setPoint(0, step, { x: Math.round(x - distance), y })
        points.setPoint(1, step, { x: Math.round(x + distance), y })
      }
      expect(await driver.injectMultiPointerAction(points, 600)).assertTrue()
      await driver.delayMs(500)
      const reset = await (await driver.findComponent(ON.type('Image').within(ON.id('rkit-image-viewport')))).getBounds()
      expect(Math.abs(reset.right - reset.left - (original.right - original.left)) <= 2).assertTrue()
      await volumeKey(driver, KeyCode.KEYCODE_VOLUME_DOWN, 3)
      await volumeImage(driver); await captureVolume(driver, 'reset-next')
      await (await driver.findComponent(ON.id('rkit-runtime-settings'))).click()
      await (await driver.findComponent(ON.text('连续'))).click()
      await driver.delayMs(1000)
      await volumeKey(driver, KeyCode.KEYCODE_VOLUME_DOWN, 4)
      await captureVolume(driver, 'continuous-next')
      await (await driver.findComponent(ON.id('rkit-close'))).click()
      await driver.delayMs(700)
      expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
      await captureVolume(driver, 'closed')
    })
  })
}
