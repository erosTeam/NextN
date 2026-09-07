import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { KeyCode } from '@kit.InputKit'
import { fileIo } from '@kit.CoreFileKit'

const captureNames: string[] = ['baseline', 'single', 'single-return', 'spread', 'choice', 'left', 'right', 'returned', 'next', 'closed', 'exception']
function clearInformationCaptures(): void {
  const cache = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir
  for (const name of captureNames) {
    for (const extension of ['json', 'png']) {
      const path = `${cache}/rkit-info-${name}.${extension}`
      if (fileIo.accessSync(path)) fileIo.unlinkSync(path)
    }
  }
}
async function captureInformation(driver: Driver, name: string): Promise<void> {
  const cache = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir
  expect(await driver.dumpLayout(`${cache}/rkit-info-${name}.json`)).assertTrue()
  expect(await driver.screenCap(`${cache}/rkit-info-${name}.png`)).assertTrue()
}
async function informationReady(driver: Driver): Promise<void> {
  for (let attempt = 0; attempt < 40; attempt++) {
    const more = await driver.findComponent(ON.id('rkit-more'))
    if (more !== null && await more.isEnabled()) return
    await driver.delayMs(500)
  }
  await captureInformation(driver, 'exception')
  expect(false).assertTrue()
}
async function openInformationMenu(driver: Driver): Promise<void> {
  await informationReady(driver)
  await (await driver.findComponent(ON.id('rkit-more'))).click()
  await driver.delayMs(400)
  await (await driver.findComponent(ON.id('rkit-image-info'))).click()
  await driver.delayMs(500)
}
async function assertInformation(driver: Driver, page: number, name: string): Promise<void> {
  const title = `图片信息 · 第 ${page} 页`
  for (let attempt = 0; attempt < 20; attempt++) {
    if (await driver.findComponent(ON.text(title)) !== null) break
    await driver.delayMs(300)
  }
  const found = await driver.findComponent(ON.text(title)) !== null
  if (!found) await captureInformation(driver, 'exception')
  expect(found).assertTrue()
  await captureInformation(driver, name)
  await driver.triggerKey(KeyCode.KEYCODE_BACK)
  await driver.delayMs(600)
  expect(await driver.findComponent(ON.type('AlertDialog'))).assertNull()
  await informationReady(driver)
}

export default function readerImageInformationTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  const work = args['-s readerLabWork'], unit = args['-s readerLabUnit']
  if (args['-s class'] !== 'ReaderImageInformationTrial' || typeof work !== 'string' || work.length === 0) return
  describe('ReaderImageInformationTrial', (): void => {
    it('actualFileInformationKeepsSingleAndBothSpreadSourceIdentities', 0, async (): Promise<void> => {
      clearInformationCaptures()
      const driver = Driver.create()
      await abilityDelegatorRegistry.getAbilityDelegator().startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
        parameters: { readerLabWork: work, readerLabUnit: typeof unit === 'string' ? unit : '',
          readerLabPage: '1', readerLabChrome: 'true', readerLabVolumeKeys: 'true' } })
      await driver.delayMs(1500); await informationReady(driver)
      await captureInformation(driver, 'baseline')
      await openInformationMenu(driver)
      await assertInformation(driver, 2, 'single')
      await captureInformation(driver, 'single-return')
      await (await driver.findComponent(ON.id('rkit-toggle-spread'))).click()
      await driver.delayMs(700); await informationReady(driver)
      await captureInformation(driver, 'spread')
      await openInformationMenu(driver)
      await captureInformation(driver, 'choice')
      await (await driver.findComponent(ON.id('rkit-info-source-0'))).click()
      await assertInformation(driver, 1, 'left')
      await openInformationMenu(driver)
      await (await driver.findComponent(ON.id('rkit-info-source-1'))).click()
      await assertInformation(driver, 2, 'right')
      await captureInformation(driver, 'returned')
      await driver.triggerKey(KeyCode.KEYCODE_VOLUME_DOWN)
      await driver.delayMs(700); await informationReady(driver)
      expect((await (await driver.findComponent(ON.id('rkit-chrome-page'))).getText()).trim().startsWith('3 /')).assertTrue()
      await captureInformation(driver, 'next')
      await (await driver.findComponent(ON.id('rkit-close'))).click()
      await driver.delayMs(700)
      expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
      await captureInformation(driver, 'closed')
    })
  })
}
