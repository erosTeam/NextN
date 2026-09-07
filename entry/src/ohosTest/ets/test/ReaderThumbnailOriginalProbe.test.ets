import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON, Rect } from '@kit.TestKit'
import { KeyCode } from '@kit.InputKit'
import { fileIo } from '@kit.CoreFileKit'
import { window } from '@kit.ArkUI'
import { ReaderTrialOriginalProbe, connectActionAlignment, connectActionHandEdge } from 'shared'
import { captureEntry, findFirstDetailThumbnail, assertNoReader, waitFreshFirstPage } from './ReaderThumbnailEntry.test'

const originalCaptures: string[] = ['original-source', 'original-held', 'original-released',
  'original-next', 'original-late', 'original-closed', 'original-exception',
  'original-back', 'original-rotated', 'original-restored']

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
  const alignment = connectActionAlignment()
  await abilityDelegatorRegistry.getAbilityDelegator().print(
    `ReaderOriginalAlignment ${label}: mode=${alignment.alignmentMode}, supported=${alignment.holdingHandSupported}, edge=${connectActionHandEdge().edge}`)
}

async function waitHeldOriginal(driver: Driver, unknownMetrics: boolean): Promise<void> {
  for (let attempt = 0; attempt < 60; attempt++) {
    const state = ReaderTrialOriginalProbe.read()
    if (state.state === 'failed' || state.state === 'cancelled') {
      await reportOriginal('unexpected-terminal')
      throw new Error('Original asset did not reach an owned hold')
    }
    if (state.state === 'held' && state.reader.sessionPhase === 'ready' &&
      state.reader.entryPhase === (unknownMetrics ? 'layout' : 'waiting') &&
      state.reader.layoutReady === !unknownMetrics) {
      expect(state.epoch > 0 && state.requestId > 0 && state.reader.entryId > 0).assertTrue()
      expect(state.pageIndex).assertEqual(0)
      expect(state.reader.anchor).assertEqual(0)
      expect(state.reader.decodedReady).assertFalse()
      if (unknownMetrics) {
        expect(state.reader.originalWidth).assertEqual(0)
        expect(state.reader.originalHeight).assertEqual(0)
      }
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

async function waitDeliveredOriginal(driver: Driver, epoch: number, entryId: number,
  anchor: number, phase: string): Promise<void> {
  for (let attempt = 0; attempt < 40; attempt++) {
    const state = ReaderTrialOriginalProbe.read()
    expect(state.epoch).assertEqual(epoch)
    expect(state.reader.entryId).assertEqual(entryId)
    expect(state.state === 'failed' || state.state === 'cancelled').assertFalse()
    if (state.state === 'delivered' && state.reader.anchor === anchor && state.reader.entryPhase === phase &&
      state.reader.assetPhase === 'displayed' && state.reader.assetRequestId > 0 &&
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

async function waitBackReleased(driver: Driver, epoch: number, requestId: number): Promise<void> {
  for (let attempt = 0; attempt < 30; attempt++) {
    const state = ReaderTrialOriginalProbe.read()
    expect(state.epoch).assertEqual(epoch)
    expect(state.requestId).assertEqual(requestId)
    if (state.state === 'cancelled' && state.assetReleased) {
      expect(ReaderTrialOriginalProbe.release(epoch, requestId)).assertFalse()
      await assertNoReader(driver)
      await reportOriginal('back-released')
      return
    }
    await driver.delayMs(100)
  }
  throw new Error('Back did not cancel and release the same held original')
}

async function waitRotatedOriginal(driver: Driver, epoch: number, entryId: number, before: Rect): Promise<void> {
  for (let attempt = 0; attempt < 30; attempt++) {
    const state = ReaderTrialOriginalProbe.read()
    expect(state.epoch).assertEqual(epoch)
    expect(state.reader.entryId).assertEqual(entryId)
    expect(state.state).assertEqual('held')
    const viewport = await driver.findComponent(ON.id('rkit-image-viewport'))
    if (viewport !== null) {
      const after = await viewport.getBounds()
      const changed = after.right - after.left !== before.right - before.left ||
        after.bottom - after.top !== before.bottom - before.top
      if (changed && state.reader.entryPhase === 'cancelled') {
        expect(state.reader.anchor).assertEqual(0)
        expect(await driver.findComponent(ON.id('rkit-entry-preview-image'))).assertNull()
        const display = await driver.getDisplaySize()
        expect(display.x > display.y).assertTrue()
        await reportOriginal('rotated-before-release')
        return
      }
    }
    await driver.delayMs(100)
  }
  throw new Error('Rotation did not change the real viewport and cancel the held entry')
}

async function assertOriginalSourceBounds(driver: Driver, sourceId: string, before: Rect, rootBefore: Rect): Promise<void> {
  await assertNoReader(driver)
  const root = await (await driver.findComponent(ON.id('nextn-root-navigation'))).getBounds()
  // A changed effective viewport is not a comparable source-return sample.
  expect(root.right - root.left).assertEqual(rootBefore.right - rootBefore.left)
  expect(root.bottom - root.top).assertEqual(rootBefore.bottom - rootBefore.top)
  const after = await (await driver.findComponent(ON.id(sourceId))).getBounds()
  expect(after.left).assertEqual(before.left)
  expect(after.top).assertEqual(before.top)
  expect(after.right).assertEqual(before.right)
  expect(after.bottom).assertEqual(before.bottom)
}

export default function readerThumbnailOriginalProbeTest(): void {
  const className = abilityDelegatorRegistry.getArguments().parameters['-s class']
  if (className !== 'ReaderThumbnailOriginalReleaseTrial' && className !== 'ReaderThumbnailOriginalNavigationTrial' &&
    className !== 'ReaderThumbnailOriginalBackTrial' && className !== 'ReaderThumbnailOriginalRotationTrial' &&
    className !== 'ReaderThumbnailUnknownOriginalTrial' && className !== 'ReaderThumbnailUnknownOriginalBackTrial') return
  const unknownMetrics = className === 'ReaderThumbnailUnknownOriginalTrial' ||
    className === 'ReaderThumbnailUnknownOriginalBackTrial'
  const navigated = className === 'ReaderThumbnailOriginalNavigationTrial'
  const back = className === 'ReaderThumbnailOriginalBackTrial' || className === 'ReaderThumbnailUnknownOriginalBackTrial'
  const rotated = className === 'ReaderThumbnailOriginalRotationTrial'
  describe(className, (): void => {
    it('heldRealOriginalHasAnObservedOwnerAndCannotReopenRetiredEntry', 0, async (): Promise<void> => {
      clearOriginalCaptures()
      const driver = Driver.create()
      let epoch: number = 0
      let mainWindow: window.Window | null = null
      let originalOrientation: window.Orientation | undefined = undefined
      let orientationRestored: boolean = false
      try {
        await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
          bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
          parameters: { readerLabWork: '678049', readerLabPage: '0', readerLabChrome: 'true',
            readerLabThumbnailEntry: 'true', readerLabEntryLayout: 'single', readerLabEntryDirection: 'ltr',
            readerLabOriginalProbe: unknownMetrics ? 'hold-unknown-metrics-once' : 'hold-once', readerLabVolumeKeys: 'true' },
        })
        await driver.delayMs(1500)
        epoch = ReaderTrialOriginalProbe.read().epoch
        expect(epoch > 0).assertTrue()
        const source = await findFirstDetailThumbnail(driver)
        const sourceId = await source.getId()
        const before = await source.getBounds()
        const rootBefore = await (await driver.findComponent(ON.id('nextn-root-navigation'))).getBounds()
        await reportOriginal('source')
        await captureEntry(driver, 'original-source')
        await source.click()
        await waitHeldOriginal(driver, unknownMetrics)
        const held = ReaderTrialOriginalProbe.read()
        epoch = held.epoch
        const entryId = held.reader.entryId
        await captureEntry(driver, 'original-held')
        if (back) {
          await driver.triggerKey(KeyCode.KEYCODE_BACK)
          await waitBackReleased(driver, epoch, held.requestId)
          await assertOriginalSourceBounds(driver, sourceId, before, rootBefore)
          await captureEntry(driver, 'original-back')
          for (let attempt = 0; attempt < 20; attempt++) {
            await driver.delayMs(200)
            await assertNoReader(driver)
            const state = ReaderTrialOriginalProbe.read()
            expect(state.epoch).assertEqual(epoch)
            expect(state.state).assertEqual('cancelled')
            expect(state.assetReleased).assertTrue()
          }
          expect(ReaderTrialOriginalProbe.release(epoch, held.requestId)).assertFalse()
          await captureEntry(driver, 'original-late')
          await assertOriginalSourceBounds(driver, sourceId, before, rootBefore)
          await captureEntry(driver, 'original-closed')
          return
        }
        if (navigated) {
          await driver.triggerKey(KeyCode.KEYCODE_VOLUME_DOWN)
          for (let attempt = 0; attempt < 30; attempt++) {
            const current = ReaderTrialOriginalProbe.read()
            expect(current.epoch).assertEqual(epoch)
            expect(current.reader.entryId).assertEqual(entryId)
            if (current.reader.anchor === 1 && current.reader.entryPhase === 'cancelled') break
            await driver.delayMs(100)
          }
          const moved = ReaderTrialOriginalProbe.read()
          expect(moved.epoch).assertEqual(epoch)
          expect(moved.reader.entryId).assertEqual(entryId)
          expect(moved.state).assertEqual('held')
          expect(moved.reader.anchor).assertEqual(1)
          expect(moved.reader.navigationRevision > held.reader.navigationRevision).assertTrue()
          expect(moved.reader.entryPhase).assertEqual('cancelled')
          expect(await driver.findComponent(ON.id('rkit-entry-preview-image'))).assertNull()
          await reportOriginal('navigated-before-release')
          await captureEntry(driver, 'original-next')
        }
        if (rotated) {
          const viewport = await (await driver.findComponent(ON.id('rkit-image-viewport'))).getBounds()
          const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()
          mainWindow = await window.getLastWindow(ability.context)
          originalOrientation = mainWindow.getPreferredOrientation()
          await mainWindow.setPreferredOrientation(window.Orientation.LANDSCAPE)
          await waitRotatedOriginal(driver, epoch, entryId, viewport)
          await captureEntry(driver, 'original-rotated')
        }
        expect(ReaderTrialOriginalProbe.release(epoch, held.requestId)).assertTrue()
        const expectedAnchor = navigated ? 1 : 0
        const expectedPhase = navigated || rotated ? 'cancelled' : 'finished'
        // Navigation checks the current P2, not whether cached P1 has decoded.
        await waitDeliveredOriginal(driver, epoch, entryId, expectedAnchor, expectedPhase)
        if (unknownMetrics) {
          const decoded = ReaderTrialOriginalProbe.read()
          expect(decoded.reader.originalWidth > 0).assertTrue()
          expect(decoded.reader.originalHeight > 0).assertTrue()
          expect(decoded.reader.decodedReady).assertTrue()
        }
        if (!navigated && !rotated) await waitFreshFirstPage(driver)
        await captureEntry(driver, 'original-released')
        await driver.delayMs(1000)
        await waitDeliveredOriginal(driver, epoch, entryId, expectedAnchor, expectedPhase)
        await captureEntry(driver, 'original-late')
        if (mainWindow !== null && originalOrientation !== undefined) {
          await mainWindow.setPreferredOrientation(originalOrientation)
          await driver.delayMs(1600)
          orientationRestored = true
          await waitDeliveredOriginal(driver, epoch, entryId, expectedAnchor, expectedPhase)
          await reportOriginal('restored')
          await captureEntry(driver, 'original-restored')
        }
        await (await driver.findComponent(ON.id('rkit-close'))).click()
        await driver.delayMs(700)
        await assertOriginalSourceBounds(driver, sourceId, before, rootBefore)
        await reportOriginal('closed')
        await captureEntry(driver, 'original-closed')
      } catch (error) {
        await reportOriginal('exception')
        await captureEntry(driver, 'original-exception')
        throw error as Error
      } finally {
        if (epoch > 0) ReaderTrialOriginalProbe.cancel(epoch)
        if (mainWindow !== null && originalOrientation !== undefined && !orientationRestored) {
          await mainWindow.setPreferredOrientation(originalOrientation)
          await driver.delayMs(600)
        }
      }
    })
  })
}
