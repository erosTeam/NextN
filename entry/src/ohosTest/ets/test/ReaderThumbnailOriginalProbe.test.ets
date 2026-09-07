import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { KeyCode } from '@kit.InputKit'
import { fileIo } from '@kit.CoreFileKit'
import { ReaderTrialOriginalProbe } from 'shared'
import { captureEntry, findFirstDetailThumbnail, assertNoReader, waitFreshFirstPage } from './ReaderThumbnailEntry.test'

const originalCaptures: string[] = ['original-source', 'original-held', 'original-released',
  'original-next', 'original-late', 'original-closed', 'original-exception']

function clearOriginalCaptures(): void {
  const cache = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir
  for (const name of originalCaptures) {
    for (const extension of ['json', 'png']) {
      const path = `${cache}/rkit-entry-${name}.${extension}`
      if (fileIo.accessSync(path)) fileIo.unlinkSync(path)
    }
  }
}

async function reportOriginal(label: string): Promise<void> {
  await abilityDelegatorRegistry.getAbilityDelegator().print(
    `ReaderOriginalProbe ${label}: ${JSON.stringify(ReaderTrialOriginalProbe.read())}`)
}

async function waitHeldOriginal(driver: Driver): Promise<void> {
  for (let attempt = 0; attempt < 60; attempt++) {
    const state = ReaderTrialOriginalProbe.read()
    if (state.state === 'failed' || state.state === 'cancelled') {
      await reportOriginal('unexpected-terminal')
      throw new Error('Original asset did not reach an owned hold')
    }
    if (state.state === 'held' && state.reader.sessionPhase === 'ready' &&
      state.reader.entryPhase === 'waiting' && state.reader.layoutReady) {
      expect(state.epoch > 0 && state.requestId > 0 && state.reader.entryId > 0).assertTrue()
      expect(state.pageIndex).assertEqual(0)
      expect(state.reader.anchor).assertEqual(0)
      expect(state.reader.decodedReady).assertFalse()
      expect(state.reader.assetRequestId).assertEqual(0)
      expect(await driver.findComponent(ON.id('rkit-entry-preview-image')) !== null).assertTrue()
      // The full held capture additionally judges ancestor visibility, not merely
      // the presence of a preview node or this in-app state observation.
      await reportOriginal('held')
      return
    }
    await driver.delayMs(250)
  }
  await reportOriginal('hold-timeout')
  throw new Error('Held real original did not reach measured waiting before the native observation deadline')
}

async function waitDeliveredOriginal(driver: Driver, epoch: number, navigated: boolean): Promise<void> {
  for (let attempt = 0; attempt < 40; attempt++) {
    const state = ReaderTrialOriginalProbe.read()
    expect(state.epoch).assertEqual(epoch)
    expect(state.state === 'failed' || state.state === 'cancelled').assertFalse()
    if (state.state === 'delivered' && state.reader.anchor === (navigated ? 1 : 0) &&
      state.reader.entryPhase === (navigated ? 'cancelled' : 'finished') &&
      await driver.findComponent(ON.id('rkit-entry-preview-image')) === null &&
      await driver.findComponent(ON.type('LoadingProgress').within(ON.id('rkit-image-viewport'))) === null &&
      await driver.findComponent(ON.type('Image').within(ON.id('rkit-image-viewport'))) !== null) {
      await reportOriginal('delivered')
      return
    }
    await driver.delayMs(250)
  }
  await reportOriginal('delivery-timeout')
  throw new Error('Held asset delivery did not preserve the expected current entry and source page')
}

export default function readerThumbnailOriginalProbeTest(): void {
  const className = abilityDelegatorRegistry.getArguments().parameters['-s class']
  if (className !== 'ReaderThumbnailOriginalReleaseTrial' && className !== 'ReaderThumbnailOriginalNavigationTrial') return
  const navigated = className === 'ReaderThumbnailOriginalNavigationTrial'
  describe(className, (): void => {
    it('heldRealOriginalHasAnObservedOwnerAndCannotReopenRetiredEntry', 0, async (): Promise<void> => {
      clearOriginalCaptures()
      const driver = Driver.create()
      let epoch: number = 0
      try {
        await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
          bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
          parameters: { readerLabWork: '678049', readerLabPage: '0', readerLabChrome: 'true',
            readerLabThumbnailEntry: 'true', readerLabEntryLayout: 'single', readerLabEntryDirection: 'ltr',
            readerLabOriginalProbe: 'hold-once', readerLabVolumeKeys: 'true' },
        })
        await driver.delayMs(1500)
        epoch = ReaderTrialOriginalProbe.read().epoch
        expect(epoch > 0).assertTrue()
        const source = await findFirstDetailThumbnail(driver)
        const sourceId = await source.getId()
        const before = await source.getBounds()
        await captureEntry(driver, 'original-source')
        await source.click()
        await waitHeldOriginal(driver)
        const held = ReaderTrialOriginalProbe.read()
        epoch = held.epoch
        await captureEntry(driver, 'original-held')
        if (navigated) {
          await driver.triggerKey(KeyCode.KEYCODE_VOLUME_DOWN)
          for (let attempt = 0; attempt < 30; attempt++) {
            const current = ReaderTrialOriginalProbe.read()
            if (current.reader.anchor === 1 && current.reader.entryPhase === 'cancelled') break
            await driver.delayMs(100)
          }
          const moved = ReaderTrialOriginalProbe.read()
          expect(moved.epoch).assertEqual(epoch)
          expect(moved.state).assertEqual('held')
          expect(moved.reader.anchor).assertEqual(1)
          expect(moved.reader.navigationRevision > held.reader.navigationRevision).assertTrue()
          expect(moved.reader.entryPhase).assertEqual('cancelled')
          expect(await driver.findComponent(ON.id('rkit-entry-preview-image'))).assertNull()
          await reportOriginal('navigated-before-release')
          await captureEntry(driver, 'original-next')
        }
        expect(ReaderTrialOriginalProbe.release(epoch, held.requestId)).assertTrue()
        await waitDeliveredOriginal(driver, epoch, navigated)
        if (!navigated) await waitFreshFirstPage(driver)
        await captureEntry(driver, 'original-released')
        await driver.delayMs(1000)
        await waitDeliveredOriginal(driver, epoch, navigated)
        await captureEntry(driver, 'original-late')
        await (await driver.findComponent(ON.id('rkit-close'))).click()
        await driver.delayMs(700)
        await assertNoReader(driver)
        const after = await (await driver.findComponent(ON.id(sourceId))).getBounds()
        expect(after.left).assertEqual(before.left)
        expect(after.top).assertEqual(before.top)
        expect(after.right).assertEqual(before.right)
        expect(after.bottom).assertEqual(before.bottom)
        await captureEntry(driver, 'original-closed')
      } catch (error) {
        await reportOriginal('exception')
        await captureEntry(driver, 'original-exception')
        throw error as Error
      } finally {
        if (epoch > 0) ReaderTrialOriginalProbe.cancel(epoch)
      }
    })
  })
}
