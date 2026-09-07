import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, MatchPattern, ON } from '@kit.TestKit'
import { KeyCode } from '@kit.InputKit'
import { fileIo } from '@kit.CoreFileKit'
import { ReaderTrialEntryProbe } from 'shared'

const ENTRY_WORK: string = '678049'
const FIRST_THUMBNAIL: string = '^reader-thumb-gallery-detail-[0-9]+-page-0$'
const captureNames: string[] = ['source', 'quick-return', 'no-late-open', 'fresh-source', 'fresh-reader', 'fresh-closed', 'exception']

function clearEntryCaptures(): void {
  const cache = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir
  for (const name of captureNames) {
    for (const extension of ['json', 'png']) {
      const path = `${cache}/rkit-entry-${name}.${extension}`
      if (fileIo.accessSync(path)) fileIo.unlinkSync(path)
    }
  }
}

export async function captureEntry(driver: Driver, name: string): Promise<void> {
  const cache = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir
  expect(await driver.dumpLayout(`${cache}/rkit-entry-${name}.json`)).assertTrue()
  expect(await driver.screenCap(`${cache}/rkit-entry-${name}.png`)).assertTrue()
}

async function armEntry(driver: Driver, delayed: boolean = false): Promise<void> {
  await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
    bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
    parameters: { readerLabWork: ENTRY_WORK, readerLabPage: '0', readerLabChrome: 'true',
      readerLabThumbnailEntry: 'true', readerLabEntryLayout: 'single', readerLabEntryDirection: 'ltr',
      readerLabEntryProbe: delayed ? 'delay-once' : '' },
  })
  await driver.delayMs(1500)
}

export async function findFirstDetailThumbnail(driver: Driver): Promise<Component> {
  // The accepted portrait Detail metadata List fills the current root Navigation.
  // Select that real owner by its current bounds, never the nested horizontal thumbnail List.
  let owner: Component | null = null
  for (let attempt = 0; attempt < 30; attempt++) {
    const root = await driver.findComponent(ON.id('nextn-root-navigation'))
    if (root !== null) {
      const rootBounds = await root.getBounds()
      const lists = await driver.findComponents(ON.type('List').within(ON.id('nextn-root-navigation')))
      const owners: Component[] = []
      for (const list of lists) {
        const bounds = await list.getBounds()
        if (bounds.left === rootBounds.left && bounds.right === rootBounds.right &&
          bounds.top === rootBounds.top && bounds.bottom === rootBounds.bottom) owners.push(list)
      }
      if (owners.length > 1) throw new Error('Ambiguous Detail metadata List; no coordinate fallback')
      if (owners.length === 1) { owner = owners[0]; break }
    }
    await driver.delayMs(300)
  }
  if (owner === null) throw new Error('Current full-height Detail metadata List is unavailable')
  const selector = ON.id(FIRST_THUMBNAIL, MatchPattern.REG_EXP).within(ON.id('nextn-root-navigation'))
  const source = await owner.scrollSearch(selector, true)
  if (source === null) throw new Error('Detail P1 thumbnail was not found by semantic scrollSearch')
  const matches = await driver.findComponents(selector)
  if (matches.length !== 1) throw new Error('Detail P1 source identity is not unique')
  const sourceId = await source.getId()
  expect(new RegExp(FIRST_THUMBNAIL).test(sourceId)).assertTrue()
  const bounds = await source.getBounds()
  expect(bounds.right > bounds.left && bounds.bottom > bounds.top).assertTrue()
  // Refetch by the resolved source ID after scrolling so the click uses the settled native node.
  return await driver.findComponent(ON.id(sourceId))
}

export async function assertNoReader(driver: Driver): Promise<void> {
  expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
  expect(await driver.findComponent(ON.id('reader-overlay-navigation'))).assertNull()
  expect(await driver.findComponent(ON.id('rkit-chrome-page'))).assertNull()
  expect(await driver.findComponent(ON.id('nextn-root-navigation')) !== null).assertTrue()
}

async function waitDelayedPreview(driver: Driver): Promise<number> {
  for (let attempt = 0; attempt < 20; attempt++) {
    const state = ReaderTrialEntryProbe.read()
    expect(state.handoff).assertFalse()
    expect(state.discarded).assertFalse()
    if (state.epoch > 0 && state.accepted && state.delayedPreview) return state.epoch
    await driver.delayMs(50)
  }
  await abilityDelegatorRegistry.getAbilityDelegator().print(`ReaderEntryProbe before Back: ${JSON.stringify(ReaderTrialEntryProbe.read())}`)
  throw new Error('The real preview was not acquired before Back; this cannot test pending handoff cancellation')
}

async function assertDelayedDiscard(driver: Driver, epoch: number): Promise<void> {
  for (let attempt = 0; attempt < 12; attempt++) {
    const state = ReaderTrialEntryProbe.read()
    expect(state.epoch).assertEqual(epoch)
    expect(state.accepted && state.delayedPreview).assertTrue()
    expect(state.handoff).assertFalse()
    if (state.discarded) {
      expect(state.navigationChanged).assertFalse()
      await abilityDelegatorRegistry.getAbilityDelegator().print(`ReaderEntryProbe verified: ${JSON.stringify(state)}`)
      return
    }
    await driver.delayMs(300)
  }
  await abilityDelegatorRegistry.getAbilityDelegator().print(`ReaderEntryProbe pending: ${JSON.stringify(ReaderTrialEntryProbe.read())}`)
  throw new Error('No same-epoch real-preview pending cancellation before fresh opt-in')
}

export async function waitFreshFirstPage(driver: Driver): Promise<void> {
  for (let attempt = 0; attempt < 40; attempt++) {
    const page = await driver.findComponent(ON.id('rkit-chrome-page'))
    if (page !== null && await driver.findComponent(ON.type('Image').within(ON.id('rkit-image-viewport'))) !== null &&
      await driver.findComponent(ON.type('LoadingProgress').within(ON.id('rkit-image-viewport'))) === null &&
      await driver.findComponent(ON.id('rkit-entry-preview-image')) === null) {
      expect(Number((await page.getText()).split('/')[0].trim())).assertEqual(1)
      expect(await driver.findComponent(ON.id('rkit-close')) !== null).assertTrue()
      return
    }
    await driver.delayMs(500)
  }
  throw new Error('Fresh optional P1 did not complete its image handoff')
}

const failureCaptureNames: string[] = ['failure-source', 'failure-reader', 'failure-retried',
  'failure-retried-settled', 'failure-closed', 'failure-exception']

function clearFailureCaptures(): void {
  const cache = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir
  for (const name of failureCaptureNames) {
    for (const extension of ['json', 'png']) {
      const path = `${cache}/rkit-entry-${name}.${extension}`
      if (fileIo.accessSync(path)) fileIo.unlinkSync(path)
    }
  }
}

async function armFailureEntry(driver: Driver, failurePage: number): Promise<void> {
  await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
    bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
    parameters: { readerLabWork: ENTRY_WORK, readerLabPage: '0', readerLabChrome: 'true',
      readerLabThumbnailEntry: 'true', readerLabEntryLayout: 'spread', readerLabEntryDirection: 'ltr',
      readerLabFailPage: failurePage.toString(), readerLabEntryProbe: '' },
  })
  await driver.delayMs(1500)
}

async function assertFirstSpreadAnchor(driver: Driver): Promise<void> {
  const page = await driver.findComponent(ON.id('rkit-chrome-page'))
  expect(page !== null).assertTrue()
  // ReaderChrome displays the source anchor, not a range: `${page()} / ${count()}`.
  expect(/^1\s*\/\s*[1-9]\d*$/.test((await page.getText()).trim())).assertTrue()
}

async function waitEntryFailure(driver: Driver, page: number): Promise<Component> {
  const failure = ON.id(`rkit-failure-page-${page}`).within(ON.id('rkit-image-viewport'))
  for (let attempt = 0; attempt < 40; attempt++) {
    const retry = await driver.findComponent(ON.id(`rkit-retry-page-${page}`).within(ON.id(`rkit-failure-page-${page}`)))
    if (retry !== null && await retry.isEnabled() &&
      await driver.findComponent(ON.id('rkit-entry-preview-image')) === null) {
      expect(await driver.findComponent(failure) !== null).assertTrue()
      await assertFirstSpreadAnchor(driver)
      return retry
    }
    await driver.delayMs(500)
  }
  throw new Error(`The entry did not hand off to the enabled P${page} failure panel`)
}

async function waitRetriedSpread(driver: Driver): Promise<void> {
  const viewport = ON.id('rkit-image-viewport')
  for (let attempt = 0; attempt < 40; attempt++) {
    expect(await driver.findComponent(ON.id('rkit-entry-preview-image'))).assertNull()
    const images = await driver.findComponents(ON.type('Image').within(viewport))
    if (images.length >= 2 &&
      await driver.findComponent(ON.type('LoadingProgress').within(viewport)) === null &&
      await driver.findComponent(ON.id('^rkit-failure-page-[0-9]+$', MatchPattern.REG_EXP).within(viewport)) === null) {
      await assertFirstSpreadAnchor(driver)
      return
    }
    await driver.delayMs(500)
  }
  throw new Error('The P1 spread did not complete both original images after retry')
}

function readerEntryFailureSuite(className: string, failurePage: number): void {
  describe(className, (): void => {
    it('realThumbnailFailureRetriesAndClosesToSameSourceBounds', 0, async (): Promise<void> => {
      clearFailureCaptures()
      const driver = Driver.create()
      try {
        await armFailureEntry(driver, failurePage)
        const source = await findFirstDetailThumbnail(driver)
        const sourceId = await source.getId()
        const before = await source.getBounds()
        await captureEntry(driver, 'failure-source')
        await source.click()
        const retry = await waitEntryFailure(driver, failurePage + 1)
        await captureEntry(driver, 'failure-reader')
        await retry.click()
        await waitRetriedSpread(driver)
        await captureEntry(driver, 'failure-retried')
        await driver.delayMs(1000)
        await waitRetriedSpread(driver)
        await captureEntry(driver, 'failure-retried-settled')
        await (await driver.findComponent(ON.id('rkit-close'))).click()
        await driver.delayMs(700)
        await assertNoReader(driver)
        const returned = await driver.findComponent(ON.id(sourceId))
        expect(returned !== null).assertTrue()
        const after = await returned.getBounds()
        await captureEntry(driver, 'failure-closed')
        await abilityDelegatorRegistry.getAbilityDelegator().print(
          `ReaderEntryFailure page=${failurePage + 1} source=${sourceId} before=${JSON.stringify(before)} after=${JSON.stringify(after)}`)
        expect(after.left).assertEqual(before.left)
        expect(after.top).assertEqual(before.top)
        expect(after.right).assertEqual(before.right)
        expect(after.bottom).assertEqual(before.bottom)
      } catch (error) {
        await captureEntry(driver, 'failure-exception')
        throw error as Error
      }
    })
  })
}

/** Explicit class selection: P1 entry cancellation or the authorized P1/P2 spread failure endpoints. */
export default function readerThumbnailEntryTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  if (args['-s class'] === 'ReaderThumbnailEntrySourceFailureTrial') {
    readerEntryFailureSuite('ReaderThumbnailEntrySourceFailureTrial', 0)
    return
  }
  if (args['-s class'] === 'ReaderThumbnailEntryNeighborFailureTrial') {
    readerEntryFailureSuite('ReaderThumbnailEntryNeighborFailureTrial', 1)
    return
  }
  if (args['-s class'] !== 'ReaderThumbnailEntryTrial') return
  describe('ReaderThumbnailEntryTrial', (): void => {
    it('immediateBackDoesNotReopenAndNewOptInCanClose', 0, async (): Promise<void> => {
      clearEntryCaptures()
      const driver = Driver.create()
      try {
        await armEntry(driver, true)
        const source = await findFirstDetailThumbnail(driver)
        const sourceId = await source.getId()
        const sourceBounds = await source.getBounds()
        await captureEntry(driver, 'source')
        ReaderTrialEntryProbe.reset()
        // The explicit host probe delays after the real snapshot, before its ownership fence.
        // Require real ownership before Back: an uncommitted tap cancelled by Back is not a snapshot race.
        const clickAt: number = Date.now()
        await source.click()
        const probeEpoch = await waitDelayedPreview(driver)
        await driver.triggerKey(KeyCode.KEYCODE_BACK)
        const clickToBackMs: number = Date.now() - clickAt
        console.info(`[ReaderEntryTest] probe=delay-once click_to_back_ms=${clickToBackMs}`)
        await abilityDelegatorRegistry.getAbilityDelegator().print(`click_to_back_ms=${clickToBackMs}`)
        expect(clickToBackMs < 2500).assertTrue()
        await abilityDelegatorRegistry.getAbilityDelegator().print(`ReaderEntryProbe epoch=${probeEpoch} preview=true beforeBack=true`)
        await driver.delayMs(700)
        await assertNoReader(driver)
        expect(await driver.findComponent(ON.id('rkit-entry-source-pending'))).assertNull()
        const returnedSource = await driver.findComponent(ON.id(sourceId))
        expect(returnedSource !== null).assertTrue()
        const returnedBounds = await returnedSource.getBounds()
        expect(returnedBounds.left).assertEqual(sourceBounds.left)
        expect(returnedBounds.top).assertEqual(sourceBounds.top)
        expect(returnedBounds.right).assertEqual(sourceBounds.right)
        expect(returnedBounds.bottom).assertEqual(sourceBounds.bottom)
        await captureEntry(driver, 'quick-return')
        await assertDelayedDiscard(driver, probeEpoch)
        for (let attempt = 0; attempt < 20; attempt++) {
          await driver.delayMs(300)
          await assertNoReader(driver)
        }
        await captureEntry(driver, 'no-late-open')

        // Successful source interception consumes the registration; a fresh Want must arm again.
        await armEntry(driver)
        const freshSource = await findFirstDetailThumbnail(driver)
        const freshSourceId = await freshSource.getId()
        await captureEntry(driver, 'fresh-source')
        await freshSource.click()
        await waitFreshFirstPage(driver)
        await captureEntry(driver, 'fresh-reader')
        await (await driver.findComponent(ON.id('rkit-close'))).click()
        await driver.delayMs(700)
        await assertNoReader(driver)
        expect(await driver.findComponent(ON.id(freshSourceId)) !== null).assertTrue()
        await captureEntry(driver, 'fresh-closed')
      } catch (error) {
        await captureEntry(driver, 'exception')
        throw error as Error
      }
    })
  })
}
