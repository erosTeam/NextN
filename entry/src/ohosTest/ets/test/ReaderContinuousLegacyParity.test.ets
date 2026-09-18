import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, MatchPattern, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { connectNextNReaderBackendSelection, NextNReaderBackend, NhReaderMode, ReaderPresentationService } from 'shared'
import { openBackendRehearsal, selectBackendFromUi, returnFromReaderSettings } from './ReaderProductionDownloadEntryTrial.test'

const GALLERY_ID: number = 678049
const START_PAGE: number = 2

async function entryContext(driver: Driver): Promise<common.UIAbilityContext> {
  const d = abilityDelegatorRegistry.getAbilityDelegator()
  for (let i = 0; i < 80; i++) {
    try { const a = await d.getCurrentTopAbility(); if (a.context.abilityInfo.name === 'EntryAbility') return a.context as common.UIAbilityContext } catch (_) {}
    await driver.delayMs(100)
  }
  throw new Error('EntryAbility context unavailable')
}

async function waitId(driver: Driver, id: string, attempts: number = 120): Promise<Component> {
  for (let i = 0; i < attempts; i++) { const c = await driver.findComponent(ON.id(id)); if (c !== null) return c; await driver.delayMs(250) }
  throw new Error('component unavailable: ' + id)
}

async function openDetail(driver: Driver): Promise<void> {
  await (await waitId(driver, 'nextn-root-tab-3')).click()
  const hist = await driver.findComponents(ON.text('历史记录').within(ON.id('nextn-root-navigation')))
  if (hist.length !== 1) throw new Error('History entry not unique: ' + hist.length)
  await hist[0].click()
  const selector = ON.id('^gallery-list-history-[0-9]+-history-' + GALLERY_ID + '$', MatchPattern.REG_EXP).within(ON.id('nextn-root-navigation'))
  for (let i = 0; i < 120; i++) {
    const row = await driver.findComponent(selector)
    if (row !== null) { await row.click(); await waitId(driver, 'gallery-detail-read-action', 160); return }
    const owners = await driver.findComponents(ON.type('Scroll').within(ON.id('nextn-root-navigation'))) ?? []
    for (const o of owners) { const f = await o.scrollSearch(selector, true); if (f !== null) { await f.click(); await waitId(driver, 'gallery-detail-read-action', 160); return } }
    await driver.delayMs(250)
  }
  throw new Error('History row unavailable for ' + GALLERY_ID)
}

async function dumpTo(driver: Driver, path: string): Promise<void> {
  const d = abilityDelegatorRegistry.getAbilityDelegator()
  expect((await d.executeShellCommand('uitest dumpLayout -p ' + path + ' -a', 20)).exitCode).assertEqual(0)
}

export default function readerContinuousLegacyParityTrialTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  if (args['-s class'] !== 'ReaderContinuousLegacyParityTrial') return
  describe('ReaderContinuousLegacyParityTrial', (): void => {
    it('capturesSharedAndLegacyContinuousSameGalleryAndPage', 0, async (): Promise<void> => {
      const d = abilityDelegatorRegistry.getAbilityDelegator()
      const driver = Driver.create()
      await d.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
      const context = await entryContext(driver)
      const prevMode: NhReaderMode = ReaderPresentationService.snapshot().mode
      try {
        await ReaderPresentationService.setMode(context, NhReaderMode.VERTICAL)
        d.print('[P1L] mode=VERTICAL prev=' + prevMode)
        const backends: NextNReaderBackend[] = [NextNReaderBackend.SHARED, NextNReaderBackend.LEGACY]
        for (const backend of backends) {
          await openBackendRehearsal(driver)
          await selectBackendFromUi(driver, backend)
          await returnFromReaderSettings(driver)
          await openDetail(driver)
          await (await waitId(driver, 'gallery-detail-read-action')).click()
          if (backend === NextNReaderBackend.SHARED) {
            await waitId(driver, 'rkit-reading-surface', 200)
            await waitId(driver, 'rkit-continuous-list', 200)
          } else {
            await waitId(driver, 'legacy-reader-surface', 200)
          }
          await driver.delayMs(2500)
          await dumpTo(driver, '/data/local/tmp/p1-' + backend + '.json')
          d.print('[P1L] captured backend=' + backend)
          const surfaceSelector = backend === NextNReaderBackend.SHARED ? 'rkit-reading-surface' : 'legacy-reader-surface'
          const surface = await driver.findComponent(ON.id(surfaceSelector))
          d.print('[P1L] surface ' + backend + '=' + JSON.stringify(await surface.getBounds()))
          const close = await driver.findComponent(ON.id('rkit-close'))
          if (close !== null) await close.click()
          else if (await driver.findComponent(ON.id('reader-overlay-navigation')) !== null) await driver.pressBack()
          for (let i = 0; i < 80; i++) { if (await driver.findComponent(ON.id('reader-overlay-navigation')) === null) break; await driver.delayMs(250) }
          for (let i = 0; i < 12; i++) { if (await driver.findComponent(ON.id('nextn-root-tab-3')) !== null) break; await driver.pressBack(); await driver.delayMs(500) }
        }
        d.print('[P1L] done')
      } finally {
        try { await ReaderPresentationService.setMode(context, prevMode) } catch (_) {}
      }
    })
  })
}
