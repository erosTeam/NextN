import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, MatchPattern, ON, Rect } from '@kit.TestKit'
import { KeyCode } from '@kit.InputKit'
import { audio } from '@kit.AudioKit'
import { fileIo } from '@kit.CoreFileKit'
import { window } from '@kit.ArkUI'
import { AppStrings, ReaderTrialOriginalProbe, connectActionAlignment, connectActionHandEdge } from 'shared'
import { captureEntry, findFirstDetailThumbnail, assertNoReader, waitFreshFirstPage } from './ReaderThumbnailEntry.test'

const originalCaptures: string[] = ['original-source', 'original-held', 'original-released',
  'original-next', 'original-late', 'original-closed', 'original-exception',
  'original-back', 'original-rotated', 'original-restored', 'original-input-held']

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

function statusContent(mainWindow: window.Window): string {
  const color = mainWindow.getWindowSystemBarProperties().statusBarContentColor?.toUpperCase() ?? ''
  return color.length === 9 && color.startsWith('#FF') ? `#${color.substring(3)}` : color
}

async function assertStatusContent(mainWindow: window.Window, expected: string, label: string): Promise<void> {
  const color = statusContent(mainWindow)
  await abilityDelegatorRegistry.getAbilityDelegator().print(`ReaderOriginalStatus ${label}: ${color}`)
  expect(color.length > 0).assertTrue()
  expect(color).assertEqual(expected)
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

async function assertOriginalSourceBounds(driver: Driver, sourceId: string, before: Rect, rootBefore: Rect,
  readerClosed: boolean = true): Promise<void> {
  if (readerClosed) await assertNoReader(driver)
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

async function findFirstGridThumbnail(driver: Driver): Promise<Component> {
  await findFirstDetailThumbnail(driver)
  // Use the same real View all action observed in Grid17/18, never its historical coordinates.
  const links = await driver.findComponents(ON.text(AppStrings.get('detail_view_all'))
    .within(ON.id('nextn-root-navigation')))
  if (links.length !== 1) throw new Error('Detail View all semantic action is not unique')
  await links[0].click()
  const firstPage = '^reader-thumb-all-thumbnails-[0-9]+-page-0$'
  const selector = ON.id(firstPage, MatchPattern.REG_EXP).within(ON.type('Grid'))
  for (let attempt = 0; attempt < 30; attempt++) {
    const grids = await driver.findComponents(ON.type('Grid').within(ON.id('nextn-root-navigation')))
    if (grids.length > 1) throw new Error('Ambiguous full-thumbnail Grid; no coordinate fallback')
    if (grids.length === 1) {
      let matches = await driver.findComponents(selector)
      if (matches.length === 0) {
        const found = await grids[0].scrollSearch(selector, true)
        if (found === null) throw new Error('Grid P1 thumbnail was not found by semantic scrollSearch')
        matches = await driver.findComponents(selector)
      }
      if (matches.length !== 1) throw new Error('Grid P1 source identity is not unique')
      const sourceId = await matches[0].getId()
      const bounds = await matches[0].getBounds()
      const owner = await grids[0].getBounds()
      expect(bounds.right > bounds.left && bounds.bottom > bounds.top).assertTrue()
      expect(bounds.left >= owner.left && bounds.right <= owner.right &&
        bounds.top >= owner.top && bounds.bottom <= owner.bottom).assertTrue()
      return await driver.findComponent(ON.id(sourceId))
    }
    await driver.delayMs(200)
  }
  throw new Error('View all did not open the actual full-thumbnail Grid')
}

async function assertRetainedGrid(driver: Driver, sourceId: string, before: Rect): Promise<void> {
  const grids = await driver.findComponents(ON.type('Grid').within(ON.id('nextn-root-navigation')))
  expect(grids.length).assertEqual(1)
  const after = await grids[0].getBounds()
  expect(after.left).assertEqual(before.left)
  expect(after.top).assertEqual(before.top)
  expect(after.right).assertEqual(before.right)
  expect(after.bottom).assertEqual(before.bottom)
  expect((await driver.findComponents(ON.id(sourceId).within(ON.type('Grid')))).length).assertEqual(1)
}

async function unknownOriginalVolumeTrial(): Promise<void> {
  clearOriginalCaptures()
  const driver = Driver.create()
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  const manager = audio.getAudioManager().getVolumeManager()
  const usage = audio.StreamUsage.STREAM_USAGE_MUSIC
  let epoch: number = 0
  try {
    await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
      parameters: { readerLabWork: '678049', readerLabPage: '0', readerLabChrome: 'true',
        readerLabThumbnailEntry: 'true', readerLabEntryLayout: 'single', readerLabEntryDirection: 'ltr',
        readerLabOriginalProbe: 'hold-unknown-metrics-once', readerLabVolumeKeys: 'true' } })
    await driver.delayMs(1500)
    epoch = ReaderTrialOriginalProbe.read().epoch
    expect(epoch > 0).assertTrue()
    const source = await findFirstDetailThumbnail(driver)
    const sourceId = await source.getId()
    const before = await source.getBounds()
    const rootBefore = await (await driver.findComponent(ON.id('nextn-root-navigation'))).getBounds()
    const ability = await delegator.getCurrentTopAbility()
    const mainWindow = await window.getLastWindow(ability.context)
    const sourceStatusContent = statusContent(mainWindow)
    await captureEntry(driver, 'original-source')
    await source.click()
    await waitHeldOriginal(driver, true)
    const held = ReaderTrialOriginalProbe.read()
    expect(held.epoch).assertEqual(epoch)
    const entryId = held.reader.entryId
    const pendingBefore = await (await driver.findComponent(ON.id('rkit-entry-source-pending'))).getBounds()
    expect(await driver.findComponent(ON.id('rkit-entry-source-loading')) !== null).assertTrue()
    await assertOriginalSourceBounds(driver, sourceId, before, rootBefore, false)
    await assertStatusContent(mainWindow, sourceStatusContent, 'volume-hidden-held')
    await captureEntry(driver, 'original-held')

    // Use real native key injection. Pick a reversible pair even at the system volume boundary.
    const baseline = manager.getVolumeByStream(usage)
    const increase = baseline < manager.getMaxVolumeByStream(usage)
    const firstKey = increase ? KeyCode.KEYCODE_VOLUME_UP : KeyCode.KEYCODE_VOLUME_DOWN
    const secondKey = increase ? KeyCode.KEYCODE_VOLUME_DOWN : KeyCode.KEYCODE_VOLUME_UP
    await driver.triggerKey(firstKey)
    await driver.delayMs(650)
    const afterFirst = ReaderTrialOriginalProbe.read()
    const sourceAfterFirst = await (await driver.findComponent(ON.id(sourceId))).getBounds()
    await driver.triggerKey(secondKey)
    await driver.delayMs(650)
    const afterSecond = ReaderTrialOriginalProbe.read()
    await delegator.print(`ReaderOriginalVolume keys=${firstKey},${secondKey} first=${JSON.stringify(afterFirst)} second=${JSON.stringify(afterSecond)}`)
    expect(manager.getVolumeByStream(usage)).assertEqual(baseline)
    for (const current of [afterFirst, afterSecond]) {
      expect(current.epoch).assertEqual(epoch)
      expect(current.requestId).assertEqual(held.requestId)
      expect(current.state).assertEqual('held')
      expect(current.unknownMetrics).assertTrue()
      expect(current.reader.entryId).assertEqual(entryId)
      expect(current.reader.anchor).assertEqual(0)
      expect(current.reader.navigationRevision).assertEqual(held.reader.navigationRevision)
      expect(current.reader.entryPhase).assertEqual('layout')
      expect(current.reader.layoutReady).assertFalse()
      expect(current.reader.decodedReady).assertFalse()
      expect(current.reader.assetRequestId).assertEqual(0)
      expect(current.reader.originalWidth).assertEqual(0)
      expect(current.reader.originalHeight).assertEqual(0)
    }
    expect(await driver.findComponent(ON.id('reader-overlay-navigation'))).assertNull()
    expect(await driver.findComponent(ON.id('rkit-entry-source-loading')) !== null).assertTrue()
    // UiTest reports the exposed portion (990px) while the OS volume window
    // covers the right edge; compare geometry only after the same full viewport returns.
    for (let attempt = 0; attempt < 60; attempt++) {
      const bounds = await (await driver.findComponent(ON.id('nextn-root-navigation'))).getBounds()
      if (bounds.left === rootBefore.left && bounds.right === rootBefore.right &&
        bounds.top === rootBefore.top && bounds.bottom === rootBefore.bottom) break
      await driver.delayMs(100)
    }
    const pendingAfter = await (await driver.findComponent(ON.id('rkit-entry-source-pending'))).getBounds()
    expect(pendingAfter.left).assertEqual(pendingBefore.left)
    expect(pendingAfter.top).assertEqual(pendingBefore.top)
    expect(pendingAfter.right).assertEqual(pendingBefore.right)
    expect(pendingAfter.bottom).assertEqual(pendingBefore.bottom)
    expect(sourceAfterFirst.left).assertEqual(before.left)
    expect(sourceAfterFirst.top).assertEqual(before.top)
    expect(sourceAfterFirst.right).assertEqual(before.right)
    expect(sourceAfterFirst.bottom).assertEqual(before.bottom)
    await assertOriginalSourceBounds(driver, sourceId, before, rootBefore, false)
    await captureEntry(driver, 'original-input-held')
    await assertStatusContent(mainWindow, sourceStatusContent, 'volume-still-hidden')

    expect(ReaderTrialOriginalProbe.release(epoch, held.requestId)).assertTrue()
    await waitDeliveredOriginal(driver, epoch, entryId, 0, 'finished')
    await waitFreshFirstPage(driver)
    const released = ReaderTrialOriginalProbe.read()
    expect(released.requestId).assertEqual(held.requestId)
    expect(released.reader.originalWidth > 0 && released.reader.originalHeight > 0).assertTrue()
    expect(released.reader.decodedReady).assertTrue()
    expect(await driver.findComponent(ON.id('rkit-entry-source-pending'))).assertNull()
    await assertStatusContent(mainWindow, '#FFFFFF', 'volume-visible-released')
    await captureEntry(driver, 'original-released')

    await driver.triggerKey(KeyCode.KEYCODE_VOLUME_DOWN)
    // P2 can have its own download/metadata/decode wait; require the current original, not a cached neighbor Image.
    await waitDeliveredOriginal(driver, epoch, entryId, 1, 'finished')
    for (let attempt = 0; attempt < 40; attempt++) {
      const current = ReaderTrialOriginalProbe.read()
      expect(current.epoch).assertEqual(epoch)
      expect(current.requestId).assertEqual(held.requestId)
      expect(current.reader.entryId).assertEqual(entryId)
      expect(current.reader.anchor).assertEqual(1)
      if (current.reader.originalWidth > 0 && current.reader.originalHeight > 0) break
      await driver.delayMs(250)
    }
    const moved = ReaderTrialOriginalProbe.read()
    expect(moved.requestId).assertEqual(held.requestId)
    expect(moved.reader.navigationRevision > released.reader.navigationRevision).assertTrue()
    expect(moved.reader.originalWidth > 0 && moved.reader.originalHeight > 0).assertTrue()
    const page = await driver.findComponent(ON.id('rkit-chrome-page'))
    expect(Number((await page.getText()).split('/')[0].trim())).assertEqual(2)
    expect(manager.getVolumeByStream(usage)).assertEqual(baseline)
    await captureEntry(driver, 'original-next')

    await (await driver.findComponent(ON.id('rkit-close'))).click()
    await driver.delayMs(700)
    await assertOriginalSourceBounds(driver, sourceId, before, rootBefore)
    expect(await driver.findComponent(ON.id('rkit-entry-source-pending'))).assertNull()
    const closed = ReaderTrialOriginalProbe.read()
    expect(closed.epoch).assertEqual(epoch)
    expect(closed.requestId).assertEqual(held.requestId)
    expect(closed.reader.hostActive).assertFalse()
    expect(ReaderTrialOriginalProbe.release(epoch, held.requestId)).assertFalse()
    await assertStatusContent(mainWindow, sourceStatusContent, 'volume-closed')
    await reportOriginal('volume-closed')
    await captureEntry(driver, 'original-closed')
  } catch (error) {
    await reportOriginal('volume-exception')
    await captureEntry(driver, 'original-exception')
    throw error as Error
  } finally {
    if (epoch > 0) ReaderTrialOriginalProbe.cancel(epoch)
  }
}

export default function readerThumbnailOriginalProbeTest(): void {
  const className = abilityDelegatorRegistry.getArguments().parameters['-s class']
  if (className === 'ReaderThumbnailUnknownOriginalVolumeTrial') {
    describe(className, (): void => {
      it('nativeVolumeKeysCannotMoveHiddenEntryAndResumeAfterOriginalHandoff', 0, unknownOriginalVolumeTrial)
    })
    return
  }
  if (className === 'ReaderTrialWindowNoPreviewTrial') {
    describe(className, (): void => {
      it('ordinaryTrialOwnsAndRestoresStatusWithoutAnEntryPreview', 0, async (): Promise<void> => {
        clearOriginalCaptures()
        const driver = Driver.create()
        const delegator = abilityDelegatorRegistry.getAbilityDelegator()
        try {
          await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
          await driver.delayMs(1500)
          const ability = await delegator.getCurrentTopAbility()
          const mainWindow = await window.getLastWindow(ability.context)
          const before = statusContent(mainWindow)
          await assertStatusContent(mainWindow, before, 'ordinary-source')
          await captureEntry(driver, 'original-source')
          await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
            parameters: { readerLabWork: '678049', readerLabPage: '0', readerLabChrome: 'true' } })
          await waitFreshFirstPage(driver)
          expect(await driver.findComponent(ON.id('rkit-entry-preview-image'))).assertNull()
          await captureEntry(driver, 'original-released')
          await assertStatusContent(mainWindow, '#FFFFFF', 'ordinary-visible')
          await (await driver.findComponent(ON.id('rkit-close'))).click()
          await driver.delayMs(700)
          await assertNoReader(driver)
          await captureEntry(driver, 'original-closed')
          await assertStatusContent(mainWindow, before, 'ordinary-closed')
        } catch (error) {
          await captureEntry(driver, 'original-exception')
          throw error as Error
        }
      })
    })
    return
  }
  if (className !== 'ReaderThumbnailOriginalReleaseTrial' && className !== 'ReaderThumbnailOriginalNavigationTrial' &&
    className !== 'ReaderThumbnailOriginalBackTrial' && className !== 'ReaderThumbnailOriginalRotationTrial' &&
    className !== 'ReaderThumbnailUnknownOriginalTrial' && className !== 'ReaderThumbnailUnknownOriginalBackTrial' &&
    className !== 'ReaderThumbnailPendingInputTrial' && className !== 'ReaderThumbnailPendingRotationTrial' &&
    className !== 'ReaderThumbnailGridUnknownOriginalBackTrial') return
  const gridBack = className === 'ReaderThumbnailGridUnknownOriginalBackTrial'
  const pendingInput = className === 'ReaderThumbnailPendingInputTrial'
  const pendingRotation = className === 'ReaderThumbnailPendingRotationTrial'
  const unknownMetrics = className === 'ReaderThumbnailUnknownOriginalTrial' ||
    className === 'ReaderThumbnailUnknownOriginalBackTrial' || pendingInput || pendingRotation || gridBack
  const navigated = className === 'ReaderThumbnailOriginalNavigationTrial'
  const back = className === 'ReaderThumbnailOriginalBackTrial' ||
    className === 'ReaderThumbnailUnknownOriginalBackTrial' || gridBack
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
        const source = gridBack ? await findFirstGridThumbnail(driver) : await findFirstDetailThumbnail(driver)
        const sourceId = await source.getId()
        const before = await source.getBounds()
        const rootBefore = await (await driver.findComponent(ON.id('nextn-root-navigation'))).getBounds()
        const gridBefore: Rect | null = gridBack ?
          await (await driver.findComponent(ON.type('Grid').within(ON.id('nextn-root-navigation')))).getBounds() : null
        const sourceAbility = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()
        mainWindow = await window.getLastWindow(sourceAbility.context)
        const sourceStatusContent = statusContent(mainWindow)
        await assertStatusContent(mainWindow, sourceStatusContent, 'source')
        await reportOriginal('source')
        await captureEntry(driver, 'original-source')
        await source.click()
        await waitHeldOriginal(driver, unknownMetrics)
        const held = ReaderTrialOriginalProbe.read()
        if (gridBack) expect(held.epoch).assertEqual(epoch)
        epoch = held.epoch
        const entryId = held.reader.entryId
        if (gridBack) {
          expect(await driver.findComponent(ON.id('rkit-entry-source-loading')) !== null).assertTrue()
          expect(await driver.findComponent(ON.id('rkit-entry-source-pending')) !== null).assertTrue()
          await assertOriginalSourceBounds(driver, sourceId, before, rootBefore, false)
        }
        await captureEntry(driver, 'original-held')
        if (unknownMetrics) await assertStatusContent(mainWindow, sourceStatusContent, 'hidden-held')
        if (pendingInput) {
          expect(await driver.findComponent(ON.id('rkit-entry-source-loading')) !== null).assertTrue()
          expect(await driver.findComponent(ON.id('rkit-entry-source-pending')) !== null).assertTrue()
          await (await driver.findComponent(ON.id(sourceId))).click()
          await (await driver.findComponent(ON.id(sourceId))).click()
          const x = Math.round((rootBefore.left + rootBefore.right) / 2)
          await driver.swipe(x, rootBefore.bottom - 150, x, rootBefore.top + 350, 600)
          await driver.delayMs(300)
          expect(await driver.findComponent(ON.id('reader-overlay-navigation'))).assertNull()
          expect(ReaderTrialOriginalProbe.read().epoch).assertEqual(epoch)
          expect(ReaderTrialOriginalProbe.read().requestId).assertEqual(held.requestId)
          expect(ReaderTrialOriginalProbe.read().reader.entryId).assertEqual(entryId)
          expect(ReaderTrialOriginalProbe.read().reader.entryPhase).assertEqual('layout')
          await assertOriginalSourceBounds(driver, sourceId, before, rootBefore, false)
          await captureEntry(driver, 'original-input-held')
        }
        if (pendingRotation) {
          originalOrientation = mainWindow.getPreferredOrientation()
          await mainWindow.setPreferredOrientation(window.Orientation.LANDSCAPE)
          await waitBackReleased(driver, epoch, held.requestId)
          await driver.delayMs(800)
          const rotatedRoot = await (await driver.findComponent(ON.id('nextn-root-navigation'))).getBounds()
          expect(rotatedRoot.right - rotatedRoot.left > rotatedRoot.bottom - rotatedRoot.top).assertTrue()
          expect(await driver.findComponent(ON.id('rkit-entry-source-pending'))).assertNull()
          await assertNoReader(driver)
          await assertStatusContent(mainWindow, sourceStatusContent, 'pending-rotated')
          await captureEntry(driver, 'original-rotated')
          expect(ReaderTrialOriginalProbe.release(epoch, held.requestId)).assertFalse()
          for (let attempt = 0; attempt < 20; attempt++) {
            await driver.delayMs(200)
            await assertNoReader(driver)
            expect(ReaderTrialOriginalProbe.read().epoch).assertEqual(epoch)
          }
          await captureEntry(driver, 'original-late')
          await mainWindow.setPreferredOrientation(originalOrientation)
          await driver.delayMs(1600)
          orientationRestored = true
          await assertOriginalSourceBounds(driver, sourceId, before, rootBefore)
          await captureEntry(driver, 'original-restored')
          await captureEntry(driver, 'original-closed')
          return
        }
        if (back) {
          await driver.triggerKey(KeyCode.KEYCODE_BACK)
          await waitBackReleased(driver, epoch, held.requestId)
          expect(await driver.findComponent(ON.id('rkit-entry-source-pending'))).assertNull()
          await assertOriginalSourceBounds(driver, sourceId, before, rootBefore)
          if (gridBefore !== null) await assertRetainedGrid(driver, sourceId, gridBefore)
          await captureEntry(driver, 'original-back')
          await assertStatusContent(mainWindow, sourceStatusContent, 'back')
          for (let attempt = 0; attempt < 20; attempt++) {
            await driver.delayMs(200)
            await assertNoReader(driver)
            const state = ReaderTrialOriginalProbe.read()
            expect(state.epoch).assertEqual(epoch)
            expect(state.state).assertEqual('cancelled')
            expect(state.assetReleased).assertTrue()
            expect(statusContent(mainWindow)).assertEqual(sourceStatusContent)
            if (gridBack) {
              expect(state.requestId).assertEqual(held.requestId)
              expect(await driver.findComponent(ON.id('rkit-entry-source-pending'))).assertNull()
            }
          }
          expect(ReaderTrialOriginalProbe.release(epoch, held.requestId)).assertFalse()
          await captureEntry(driver, 'original-late')
          await assertOriginalSourceBounds(driver, sourceId, before, rootBefore)
          if (gridBefore !== null) await assertRetainedGrid(driver, sourceId, gridBefore)
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
        expect(await driver.findComponent(ON.id('rkit-entry-source-pending'))).assertNull()
        await assertStatusContent(mainWindow, '#FFFFFF', 'visible-released')
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
        await assertStatusContent(mainWindow, sourceStatusContent, 'closed')
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
