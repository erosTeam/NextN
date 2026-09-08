import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { KeyCode } from '@kit.InputKit'
import { fileIo } from '@kit.CoreFileKit'
import { window } from '@kit.ArkUI'

const captureNames: string[] = ['baseline', 'single', 'single-return', 'spread', 'choice', 'left', 'right', 'returned', 'next', 'closed', 'exception',
  'recovery-baseline', 'failed', 'pending', 'changed', 'late', 'recovery-info', 'recovery-returned', 'recovery-closed']
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

async function informationPage(driver: Driver): Promise<number> {
  return Number((await (await driver.findComponent(ON.id('rkit-chrome-page'))).getText()).split('/')[0].trim())
}

async function informationRecoveryTrial(work: string, unit: string, mode: string): Promise<void> {
  clearInformationCaptures()
  const driver = Driver.create()
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
    parameters: { readerLabWork: work, readerLabUnit: unit, readerLabPage: '1', readerLabChrome: 'true',
      readerLabInformationProbe: mode === 'failure' ? 'fail-once' : 'delay-once' } })
  await driver.delayMs(1500); await informationReady(driver)
  expect(await informationPage(driver)).assertEqual(2)
  await captureInformation(driver, 'recovery-baseline')
  await openInformationMenu(driver)
  let expectedPage = 2
  if (mode === 'failure') {
    await informationReady(driver)
    await captureInformation(driver, 'failed')
    expect(await driver.findComponent(ON.type('AlertDialog'))).assertNull()
    expect(await informationPage(driver)).assertEqual(2)
  } else {
    expect(await (await driver.findComponent(ON.id('rkit-more'))).isEnabled()).assertFalse()
    await captureInformation(driver, 'pending')
    if (mode === 'page') {
      const bounds = await (await driver.findComponent(ON.id('rkit-image-viewport'))).getBounds()
      await driver.click(Math.round(bounds.left + (bounds.right - bounds.left) * 0.8),
        Math.round((bounds.top + bounds.bottom) / 2))
      expectedPage = 3
      await driver.delayMs(500); await informationReady(driver)
    } else if (mode === 'close') {
      await (await driver.findComponent(ON.id('rkit-close'))).click()
      await driver.delayMs(700)
      expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
    } else {
      const ability = await delegator.getCurrentTopAbility()
      try {
        await delegator.doAbilityBackground(ability); await driver.delayMs(500)
        expect(delegator.getAbilityState(ability)).assertEqual(abilityDelegatorRegistry.AbilityLifecycleState.BACKGROUND)
        await captureInformation(driver, 'changed')
      } finally {
        await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
      }
      await driver.delayMs(700); await informationReady(driver)
    }
    if (mode !== 'background') await captureInformation(driver, 'changed')
    await driver.delayMs(3500)
    await captureInformation(driver, 'late')
    expect(await driver.findComponent(ON.type('AlertDialog'))).assertNull()
    if (mode === 'close') {
      expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
      await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
        parameters: { readerLabWork: work, readerLabUnit: unit, readerLabPage: '1', readerLabChrome: 'true' } })
      await driver.delayMs(1500); await informationReady(driver)
    }
    expect(await informationPage(driver)).assertEqual(expectedPage)
  }
  await openInformationMenu(driver)
  await assertInformation(driver, expectedPage, 'recovery-info')
  expect(await informationPage(driver)).assertEqual(expectedPage)
  await captureInformation(driver, 'recovery-returned')
  await (await driver.findComponent(ON.id('rkit-close'))).click()
  await driver.delayMs(700)
  expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
  await captureInformation(driver, 'recovery-closed')
}

export default function readerImageInformationTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  const work = args['-s readerLabWork'], unit = args['-s readerLabUnit']
  const trial = args['-s class']
  if (trial === 'ReaderSpreadShiftTrial' && typeof work === 'string' && work.length > 0) {
    describe(trial, (): void => {
      it('rtlSpreadRePairsOnePageThenTurnsWithinTheNewPairing', 0, async (): Promise<void> => {
        clearInformationCaptures()
        const driver = Driver.create(), delegator = abilityDelegatorRegistry.getAbilityDelegator()
        try {
          await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
            parameters: { readerLabWork: work, readerLabUnit: typeof unit === 'string' ? unit : '',
              readerLabPage: '1', readerLabChrome: 'true', readerLabVolumeKeys: 'true' } })
          await informationReady(driver)
          expect(await driver.findComponent(ON.id('rkit-shift-spread'))).assertNull()
          await (await driver.findComponent(ON.id('rkit-runtime-settings'))).click()
          await driver.delayMs(400)
          await (await driver.findComponent(ON.text('右→左'))).click()
          await driver.delayMs(400)
          await (await driver.findComponent(ON.id('rkit-toggle-spread'))).click()
          await informationReady(driver)
          await captureInformation(driver, 'baseline')
          await (await driver.findComponent(ON.id('rkit-shift-spread'))).click()
          await driver.delayMs(500); await informationReady(driver)
          expect(await informationPage(driver)).assertEqual(2)
          await captureInformation(driver, 'changed')
          await openInformationMenu(driver)
          expect(await driver.findComponent(ON.id('rkit-info-source-1')) !== null).assertTrue()
          expect(await driver.findComponent(ON.id('rkit-info-source-2')) !== null).assertTrue()
          expect(await driver.findComponent(ON.id('rkit-info-source-0'))).assertNull()
          await driver.triggerKey(KeyCode.KEYCODE_BACK); await driver.delayMs(600)
          await driver.triggerKey(KeyCode.KEYCODE_VOLUME_DOWN)
          await driver.delayMs(700); await informationReady(driver)
          expect(await informationPage(driver)).assertEqual(4)
          await captureInformation(driver, 'next')
          await driver.triggerKey(KeyCode.KEYCODE_VOLUME_UP)
          await driver.delayMs(700); await informationReady(driver)
          expect(await informationPage(driver)).assertEqual(2)
          await captureInformation(driver, 'returned')
          await (await driver.findComponent(ON.id('rkit-close'))).click()
          await driver.delayMs(700)
          expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
          await captureInformation(driver, 'closed')
        } catch (error) {
          await captureInformation(driver, 'exception')
          throw error as Error
        }
      })
    })
    return
  }
  if (trial === 'ReaderStandaloneStatusTrial' && typeof work === 'string' && work.length > 0) {
    describe(trial, (): void => {
      it('standaloneStatusRestoresPreReaderProperties', 0, async (): Promise<void> => {
        clearInformationCaptures()
        const driver = Driver.create(), delegator = abilityDelegatorRegistry.getAbilityDelegator()
        await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
        await driver.delayMs(1000)
        const ability = await delegator.getCurrentTopAbility()
        const mainWindow = await window.getLastWindow(ability.context)
        const before = mainWindow.getWindowSystemBarProperties()
        await delegator.print(`ReaderStandaloneStatus before=${JSON.stringify(before)}`)
        await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
          parameters: { readerLabWork: work, readerLabUnit: typeof unit === 'string' ? unit : '',
            readerLabPage: '1', readerLabChrome: 'true' } })
        await informationReady(driver)
        await delegator.print(`ReaderStandaloneStatus shown=${JSON.stringify(mainWindow.getWindowSystemBarProperties())}`)
        await captureInformation(driver, 'baseline')
        await (await driver.findComponent(ON.id('rkit-close'))).click()
        await driver.delayMs(700)
        expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
        const after = mainWindow.getWindowSystemBarProperties()
        await delegator.print(`ReaderStandaloneStatus closed=${JSON.stringify(after)}`)
        expect(after.statusBarContentColor).assertEqual(before.statusBarContentColor)
        expect(after.isStatusBarLightIcon).assertEqual(before.isStatusBarLightIcon)
        await captureInformation(driver, 'closed')
      })
    })
    return
  }
  if (typeof work === 'string' && work.length > 0 &&
    (trial === 'ReaderInformationFailureTrial' || trial === 'ReaderInformationPageCancelTrial' ||
      trial === 'ReaderInformationCloseCancelTrial' || trial === 'ReaderInformationBackgroundTrial')) {
    describe(trial, (): void => {
      it('metadataFailureOrLateResultDoesNotBreakReadingOrFreshInformation', 0, async (): Promise<void> => {
        await informationRecoveryTrial(work, typeof unit === 'string' ? unit : '',
          trial === 'ReaderInformationFailureTrial' ? 'failure' : trial === 'ReaderInformationPageCancelTrial' ? 'page' :
            trial === 'ReaderInformationCloseCancelTrial' ? 'close' : 'background')
      })
    })
    return
  }
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
