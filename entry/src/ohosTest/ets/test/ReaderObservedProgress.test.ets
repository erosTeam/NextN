import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { connectNextNReaderLabContextProbe, connectNextNReaderObservedProgressProbe } from 'reader'

class ContextHolder { value: common.UIAbilityContext | null = null }

async function waitId(driver: Driver, id: string): Promise<Component> {
  for (let attempt = 0; attempt < 60; attempt++) {
    const value = await driver.findComponent(ON.id(id))
    if (value !== null) return value
    await driver.delayMs(250)
  }
  throw new Error('Observed progress component unavailable: ' + id)
}

async function waitBody(driver: Driver, pageIndex: number): Promise<Component> {
  for (let attempt = 0; attempt < 60; attempt++) {
    const value = await driver.findComponent(ON.type('Image').within(ON.id(`rkit-part-${pageIndex}-whole`)))
    if (value !== null &&
      await driver.findComponent(ON.type('LoadingProgress').within(ON.id(`rkit-part-${pageIndex}-whole`))) === null) return value
    await driver.delayMs(250)
  }
  throw new Error('Observed progress body unavailable: ' + pageIndex)
}

async function waitObserved(driver: Driver, events: number[], pageIndex: number): Promise<void> {
  for (let attempt = 0; attempt < 60; attempt++) {
    if (events.length > 0 && events[events.length - 1] === pageIndex) return
    await driver.delayMs(100)
  }
  throw new Error('Observed progress event unavailable: ' + pageIndex)
}

async function capture(driver: Driver, name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  expect((await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/rkit-observed-${name}.json -a`, 15)).exitCode)
    .assertEqual(0)
  expect(await driver.screenCap(delegator.getAppContext().cacheDir + `/rkit-observed-${name}.png`)).assertTrue()
}

async function closeTrial(driver: Driver): Promise<void> {
  const close = await driver.findComponent(ON.id('rkit-close'))
  if (close !== null) await close.click()
  else if (await driver.findComponent(ON.id('rkit-reading-surface')) !== null) await driver.pressBack()
  for (let attempt = 0; attempt < 60; attempt++) {
    if (await driver.findComponent(ON.id('rkit-reading-surface')) === null) return
    await driver.delayMs(250)
  }
  throw new Error('Observed progress trial did not close')
}

async function history(store: relationalStore.RdbStore, galleryId: number): Promise<string> {
  const row = await store.querySql('SELECT last_read_index,has_read_progress FROM reading_history WHERE gallery_id=?', [galleryId])
  try { return row.goToFirstRow() ? JSON.stringify([row.getLong(0), row.getLong(1)]) : 'absent' }
  finally { row.close() }
}

export default function readerObservedProgressTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  if (args['-s class'] !== 'ReaderObservedProgressTrial') return
  describe('ReaderObservedProgressTrial', (): void => {
    it('actualVisibleOriginalEventsDoNotWriteHistory', 0, async (): Promise<void> => {
      const work = args['-s readerLabWork']
      expect(work).assertEqual('678049')
      const galleryId = Number(work), driver = Driver.create(), contexts = new ContextHolder(), events: number[] = []
      const contextProbe = connectNextNReaderLabContextProbe()
      const progressProbe = connectNextNReaderObservedProgressProbe()
      const contextEpoch = contextProbe.arm(work as string,
        (context: common.UIAbilityContext): void => { contexts.value = context })
      const progressEpoch = progressProbe.arm(work as string, (pageIndex: number): void => { events.push(pageIndex) })
      let failed = false
      try {
        await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
          bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility', parameters: {
            readerLabWork: work, readerLabPage: '2', readerLabChrome: 'true', readerLabVolumeKeys: 'false',
            readerLabEntryLayout: 'single', readerLabEntryDirection: 'ltr',
          },
        })
        await waitId(driver, 'rkit-close'); await waitBody(driver, 2); await waitObserved(driver, events, 2)
        for (let attempt = 0; attempt < 60 && contexts.value === null; attempt++) await driver.delayMs(100)
        const context = contexts.value
        if (context === null) throw new Error('Observed progress context unavailable')
        const store = await relationalStore.getRdbStore(context,
          { name: 'NextN.db', securityLevel: relationalStore.SecurityLevel.S3 })
        const originalHistory = await history(store, galleryId)
        await capture(driver, 'initial')
        const viewport = await waitId(driver, 'rkit-image-viewport')
        const bounds = await viewport.getBounds()
        const width = bounds.right - bounds.left
        const y = Math.round((bounds.top + bounds.bottom) / 2)
        await driver.swipe(Math.round(bounds.left + width * 0.82), y, Math.round(bounds.left + width * 0.18), y, 700)
        await waitBody(driver, 3); await waitObserved(driver, events, 3); await capture(driver, 'next')
        await driver.swipe(Math.round(bounds.left + width * 0.18), y, Math.round(bounds.left + width * 0.82), y, 700)
        await waitBody(driver, 2); await waitObserved(driver, events, 2); await capture(driver, 'return')
        expect(events.length).assertEqual(3)
        expect(events[0]).assertEqual(2); expect(events[1]).assertEqual(3); expect(events[2]).assertEqual(2)
        expect(await history(store, galleryId)).assertEqual(originalHistory)
        await closeTrial(driver)
        const count = events.length
        await driver.delayMs(700)
        expect(events.length).assertEqual(count)
        expect(await history(store, galleryId)).assertEqual(originalHistory)
        await capture(driver, 'exit')
        console.info(`[ReaderObservedProgressTest] events=${JSON.stringify(events)} historyUnchanged=true`)
      } catch (error) {
        failed = true
        try { await capture(driver, 'exception') } catch (_) {}
        throw error as Error
      } finally {
        contextProbe.cancel(contextEpoch); progressProbe.cancel(progressEpoch)
        try { await closeTrial(driver) } catch (error) { if (!failed) throw error as Error }
      }
    })
  })
}
