import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, MatchPattern, ON } from '@kit.TestKit'
import { KeyCode } from '@kit.InputKit'
import { fileIo } from '@kit.CoreFileKit'
import { window } from '@kit.ArkUI'
import { UIAbility } from '@kit.AbilityKit'
import { ReaderTrialEntryProbe, ReaderTrialOriginalProbe, connectReaderPresentation,
  connectReaderOverlayNavigation, ReaderRouteParams, ReaderPresentationService, ReaderSettingsRepository,
  NhReaderMode } from 'shared'

const ENTRY_WORK: string = '678049'
const FIRST_THUMBNAIL: string = '^reader-thumb-gallery-detail-[0-9]+-page-0$'
const captureNames: string[] = ['source', 'quick-return', 'no-late-open', 'fresh-source', 'fresh-reader', 'fresh-closed', 'exception']

function clearEntryCaptures(names: string[] = captureNames): void {
  const cache = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir
  for (const name of names) {
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

const chromeCaptureNames: string[] = ['chrome-shown', 'chrome-hidden', 'chrome-reshown', 'chrome-closed', 'chrome-exception']

function clearChromeCaptures(): void {
  const cache = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir
  for (const name of chromeCaptureNames) {
    for (const extension of ['json', 'png']) {
      const path = `${cache}/rkit-entry-${name}.${extension}`
      if (fileIo.accessSync(path)) fileIo.unlinkSync(path)
    }
  }
}

function chromeSystemArea(area: window.AvoidArea): number {
  return area.topRect.width * area.topRect.height + area.bottomRect.width * area.bottomRect.height +
    area.leftRect.width * area.leftRect.height + area.rightRect.width * area.rightRect.height
}

async function waitChromeState(driver: Driver, mainWindow: window.Window, shown: boolean, epoch: number): Promise<void> {
  const deadline = Date.now() + 10000
  while (Date.now() < deadline) {
    const close = await driver.findComponent(ON.id('rkit-close'))
    const area = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
    const probe = ReaderTrialEntryProbe.read()
    expect(probe.epoch).assertEqual(epoch)
    expect(probe.accepted && probe.handoff && !probe.discarded).assertTrue()
    if ((close !== null) === shown && (chromeSystemArea(area) > 0) === shown) {
      await abilityDelegatorRegistry.getAbilityDelegator().print(
        `ReaderThumbnailChrome shown=${shown} area=${JSON.stringify(area)} probe=${JSON.stringify(probe)}`)
      return
    }
    await driver.delayMs(200)
  }
  throw new Error(`NextN chrome/system-area did not become shown=${shown}`)
}

async function toggleChromeAtCurrentCenter(driver: Driver): Promise<void> {
  const viewport = await driver.findComponent(ON.id('rkit-image-viewport'))
  expect(viewport !== null).assertTrue()
  const bounds = await viewport.getBounds()
  expect(bounds.right > bounds.left && bounds.bottom > bounds.top).assertTrue()
  await driver.click(Math.round((bounds.left + bounds.right) / 2), Math.round((bounds.top + bounds.bottom) / 2))
}

async function waitChromeClosed(driver: Driver, mainWindow: window.Window, sourceId: string): Promise<void> {
  const deadline = Date.now() + 10000
  while (Date.now() < deadline) {
    if (await driver.findComponent(ON.id('rkit-trial-navigation')) === null &&
      await driver.findComponent(ON.id(sourceId)) !== null &&
      chromeSystemArea(mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)) > 0) {
      await assertNoReader(driver)
      return
    }
    await driver.delayMs(200)
  }
  throw new Error('NextN hidden Back did not restore Detail source and system area')
}

async function waitChromeEntrySpread(driver: Driver, baselineEpoch: number): Promise<number> {
  const deadline = Date.now() + 20000
  let epoch: number = 0
  while (Date.now() < deadline) {
    const probe = ReaderTrialEntryProbe.read()
    if (probe.epoch > baselineEpoch && probe.accepted) {
      if (epoch === 0) epoch = probe.epoch
      expect(probe.epoch).assertEqual(epoch)
      expect(probe.discarded).assertFalse()
      const viewport = await driver.findComponent(ON.id('rkit-image-viewport'))
      if (probe.handoff && viewport !== null &&
        await driver.findComponent(ON.id('rkit-entry-preview-image')) === null &&
        await driver.findComponent(ON.id('rkit-entry-source-pending')) === null) {
        let ready = true
        for (const page of [0, 1]) {
          const id = `rkit-part-${page}-whole`
          const part = await driver.findComponent(ON.id(id).within(ON.id('rkit-image-viewport')))
          if (part === null) { ready = false; break }
          const image = await driver.findComponent(ON.type('Image').within(ON.id(id)))
          if (image === null || await driver.findComponent(ON.type('LoadingProgress').within(ON.id(id))) !== null ||
            await driver.findComponent(ON.id(`rkit-failure-page-${page + 1}`).within(ON.id(id))) !== null) {
            ready = false; break
          }
          const bounds = await image.getBounds()
          if (bounds.right <= bounds.left || bounds.bottom <= bounds.top) { ready = false; break }
        }
        if (ready && await driver.findComponent(ON.type('LoadingProgress').within(ON.id('rkit-image-viewport'))) === null &&
          await driver.findComponent(ON.id('^rkit-failure-page-[0-9]+$', MatchPattern.REG_EXP)
            .within(ON.id('rkit-image-viewport'))) === null) {
          await assertFirstSpreadAnchor(driver)
          return epoch
        }
      }
    }
    await driver.delayMs(200)
  }
  throw new Error(`Chrome entry did not complete same-epoch P1/P2 handoff: ${JSON.stringify(ReaderTrialEntryProbe.read())}`)
}

function readerThumbnailChromeTrial(): void {
  describe('ReaderThumbnailChromeTrial', (): void => {
    it('shownHiddenReshownChromeRestoresStatusAreaOnHiddenBack', 0, async (): Promise<void> => {
      clearChromeCaptures()
      const driver = Driver.create()
      let mainWindow: window.Window | null = null
      let sourceId: string = ''
      let baselineEpoch: number = 0
      let entryClicked: boolean = false
      let failed: boolean = false
      try {
        await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
          bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
          parameters: { readerLabWork: ENTRY_WORK, readerLabPage: '0', readerLabChrome: 'true',
            readerLabThumbnailEntry: 'true', readerLabEntryLayout: 'spread', readerLabEntryDirection: 'rtl',
            // This existing opt-in is the only host path that publishes entry probe facts.
            readerLabEntryProbe: 'delay-once' },
        })
        const source = await findFirstDetailThumbnail(driver)
        sourceId = await source.getId()
        const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()
        mainWindow = await window.getLastWindow(ability.context)
        const sourceArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
        await abilityDelegatorRegistry.getAbilityDelegator().print(
          `ReaderThumbnailChrome source_area=${JSON.stringify(sourceArea)}`)
        expect(chromeSystemArea(sourceArea) > 0).assertTrue()
        baselineEpoch = ReaderTrialEntryProbe.read().epoch
        entryClicked = true
        await source.click()
        const epoch = await waitChromeEntrySpread(driver, baselineEpoch)
        const first = await driver.findComponent(ON.id('rkit-part-0-whole').within(ON.id('rkit-image-viewport')))
        const second = await driver.findComponent(ON.id('rkit-part-1-whole').within(ON.id('rkit-image-viewport')))
        expect(first !== null && second !== null).assertTrue()
        expect((await second.getBounds()).right <= (await first.getBounds()).left + 1).assertTrue()
        expect(epoch > 0).assertTrue()
        expect(ReaderTrialEntryProbe.read().delayedPreview).assertTrue()
        await waitChromeState(driver, mainWindow, true, epoch)
        await captureEntry(driver, 'chrome-shown')
        await toggleChromeAtCurrentCenter(driver)
        await waitChromeState(driver, mainWindow, false, epoch)
        await captureEntry(driver, 'chrome-hidden')
        await toggleChromeAtCurrentCenter(driver)
        await waitChromeState(driver, mainWindow, true, epoch)
        await captureEntry(driver, 'chrome-reshown')
        await toggleChromeAtCurrentCenter(driver)
        await waitChromeState(driver, mainWindow, false, epoch)
        await driver.pressBack()
        await waitChromeClosed(driver, mainWindow, sourceId)
        await captureEntry(driver, 'chrome-closed')
      } catch (error) {
        failed = true
        try { await captureEntry(driver, 'chrome-exception') } catch (_) {}
        try {
          const probe = ReaderTrialEntryProbe.read()
          const pending = await driver.findComponent(ON.id('rkit-entry-source-pending'))
          const trial = await driver.findComponent(ON.id('rkit-trial-navigation'))
          if (trial !== null || pending !== null ||
            (entryClicked && probe.epoch > baselineEpoch && probe.accepted && !probe.discarded)) {
            // The established Back path retires the pending claim as well as a mounted reader.
            await driver.triggerKey(KeyCode.KEYCODE_BACK)
            const deadline = Date.now() + 10000
            while (Date.now() < deadline) {
              const after = ReaderTrialEntryProbe.read()
              if (after.epoch > baselineEpoch && (after.discarded || after.handoff) &&
                await driver.findComponent(ON.id('rkit-entry-source-pending')) === null &&
                await driver.findComponent(ON.id('rkit-trial-navigation')) === null) break
              await driver.delayMs(100)
            }
            const retired = ReaderTrialEntryProbe.read()
            expect(retired.epoch > baselineEpoch && (retired.discarded || retired.handoff)).assertTrue()
            expect(await driver.findComponent(ON.id('rkit-entry-source-pending'))).assertNull()
            if (mainWindow !== null && sourceId.length > 0) await waitChromeClosed(driver, mainWindow, sourceId)
          }
        } catch (cleanupError) {
          try { await abilityDelegatorRegistry.getAbilityDelegator().print(
            `ReaderThumbnailChrome cleanup_failed=${String(cleanupError)}`) } catch (_) {}
        }
        throw error as Error
      } finally {
        try {
          await abilityDelegatorRegistry.getAbilityDelegator().print(
            `ReaderThumbnailChrome final_area=${JSON.stringify(mainWindow?.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM))}` +
            ` probe=${JSON.stringify(ReaderTrialEntryProbe.read())}`)
        } catch (error) { if (!failed) throw error as Error }
      }
    })
  })
}

function readerThumbnailSaveMenuTrial(positive: boolean = false, both: boolean = false): void {
  describe(both ? 'ReaderThumbnailSaveBothTrial' : positive ? 'ReaderThumbnailSaveTrial' : 'ReaderThumbnailSaveMenuTrial', (): void => {
    it(both ? 'visualBothSystemAllowRequiresTwoIndependentFileReadbacks' : positive ? 'visualRightP1SystemAllowRequiresExternalFileReadback' :
      'visualLeftMenuAndSystemDialogDiscoveryCancelOnly', 0, async (): Promise<void> => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      const cache = delegator.getAppContext().cacheDir
      const positivePrefix: string = both ? 'save-both' : 'save-positive'
      const names: string[] = positive ? [`${positivePrefix}-saved-reader`, `${positivePrefix}-closed`, `${positivePrefix}-exception`] :
        ['save-menu', 'save-dialog', 'save-closed', 'save-exception']
      for (const name of names) {
        for (const extension of ['png', 'json']) {
          const path = `${cache}/rkit-entry-${name}.${extension}`
          if (fileIo.accessSync(path)) fileIo.unlinkSync(path)
        }
      }
      const driver = Driver.create()
      let mainWindow: window.Window | null = null
      let sourceId: string = ''
      let baselineEpoch: number = 0
      let entryClicked: boolean = false
      let dialogAttempted: boolean = false
      try {
        await delegator.print(positive ?
          `ReaderThumbnailSave scope=${both ? 'P1-P2' : 'single-P1'}-system-allow album_file_readback_required=true` :
          'ReaderThumbnailSaveMenu scope=menu+dialog-discovery/cancel positive_album_save_acceptance=false')
        await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
          parameters: { readerLabWork: ENTRY_WORK, readerLabPage: '0', readerLabChrome: 'true',
            readerLabThumbnailEntry: 'true', readerLabEntryLayout: 'spread', readerLabEntryDirection: 'rtl',
            readerLabEntryProbe: 'delay-once' } })
        const source = await findFirstDetailThumbnail(driver)
        sourceId = await source.getId()
        const ability = await delegator.getCurrentTopAbility()
        mainWindow = await window.getLastWindow(ability.context)
        baselineEpoch = ReaderTrialEntryProbe.read().epoch
        entryClicked = true
        await source.click()
        const epoch = await waitChromeEntrySpread(driver, baselineEpoch)
        await waitChromeState(driver, mainWindow, true, epoch)
        const first = await driver.findComponent(ON.id('rkit-part-0-whole').within(ON.id('rkit-image-viewport')))
        const second = await driver.findComponent(ON.id('rkit-part-1-whole').within(ON.id('rkit-image-viewport')))
        expect(first !== null && second !== null).assertTrue()
        expect((await second.getBounds()).right <= (await first.getBounds()).left + 1).assertTrue()
        const save = await driver.findComponent(ON.id('rkit-save-image'))
        expect(save !== null).assertTrue()
        await save.click()
        let left: Component | null = null
        const menuDeadline = Date.now() + 5000
        while (Date.now() < menuDeadline && left === null) {
          left = await driver.findComponent(ON.id('rkit-save-left'))
          if (left === null) await driver.delayMs(100)
        }
        const right = await driver.findComponent(ON.id('rkit-save-right'))
        expect(left !== null && right !== null).assertTrue()
        if (left === null || right === null) throw new Error('Save menu did not appear before deadline')
        expect(await left.getText()).assertEqual('左侧 · 第 2 页')
        expect(await right.getText()).assertEqual('右侧 · 第 1 页')
        if (!positive) await captureEntry(driver, 'save-menu')
        dialogAttempted = true
        if (positive) {
          if (both) {
            const saveBoth = await driver.findComponent(ON.id('rkit-save-both'))
            if (saveBoth === null) throw new Error('Save both menu did not appear')
            await saveBoth.click()
          } else await right.click()
          const dialogTitle: string = both ? '允许“NextN”保存 2 张图片？' : '允许“NextN”保存 1 张图片？'
          let allow: Component | null = null
          const dialogDeadline = Date.now() + 15000
          while (Date.now() < dialogDeadline) {
            allow = await driver.findComponent(ON.id('advanced_dialog_button_1').text('允许'))
            const title = await driver.findComponent(ON.text(dialogTitle))
            if (allow !== null && title !== null) break
            allow = null
            await driver.delayMs(100)
          }
          if (allow === null) throw new Error(`Expected ${both ? 'two' : 'single'}-image save permission dialog did not appear`)
          await allow.click()
          const dismissedDeadline = Date.now() + 15000
          let dismissed: boolean = false
          while (Date.now() < dismissedDeadline) {
            if (await driver.findComponent(ON.id('advanced_dialog_button_1').text('允许')) === null &&
              await driver.findComponent(ON.text(dialogTitle)) === null) {
              dismissed = true
              break
            }
            await driver.delayMs(100)
          }
          expect(dismissed).assertTrue()
        } else {
          await left.click()
          // Discovery only: no unknown system action is selected and no save success is inferred.
          await driver.delayMs(1500)
          await captureEntry(driver, 'save-dialog')
          await delegator.print('ReaderThumbnailSaveMenu discovery_capture=save-dialog system_layout_requires_review saved=false')
          await driver.pressBack()
        }
        dialogAttempted = false
        await waitChromeEntrySpread(driver, baselineEpoch)
        if (positive) {
          const saveSettledDeadline = Date.now() + 15000
          let saveSettled: boolean = false
          while (Date.now() < saveSettledDeadline) {
            const saveAction = await driver.findComponent(ON.id('rkit-save-image'))
            if (saveAction !== null && await saveAction.isEnabled()) {
              saveSettled = true
              break
            }
            await driver.delayMs(100)
          }
          if (!saveSettled) throw new Error('Save action did not become enabled after system dialog dismissal')
          await captureEntry(driver, `${positivePrefix}-saved-reader`)
          await delegator.print(`ReaderThumbnailSave system_allow_completed=true source_pages=${both ? '1,2' : '1'} album_file_verified=false external_readback_required=true`)
        }
        await driver.pressBack()
        await waitChromeClosed(driver, mainWindow, sourceId)
        await captureEntry(driver, positive ? `${positivePrefix}-closed` : 'save-closed')
      } catch (error) {
        try { await captureEntry(driver, positive ? `${positivePrefix}-exception` : 'save-exception') } catch (_) {}
        try {
          if (dialogAttempted) { await driver.pressBack(); dialogAttempted = false }
          const probe = ReaderTrialEntryProbe.read()
          if (entryClicked && (await driver.findComponent(ON.id('rkit-trial-navigation')) !== null ||
            await driver.findComponent(ON.id('rkit-entry-source-pending')) !== null ||
            probe.epoch > baselineEpoch && probe.accepted && !probe.discarded && !probe.handoff)) {
            await driver.triggerKey(KeyCode.KEYCODE_BACK)
            if (mainWindow !== null && sourceId.length > 0) await waitChromeClosed(driver, mainWindow, sourceId)
          }
        } catch (cleanupError) {
          try { await delegator.print(`ReaderThumbnailSaveMenu cleanup_failed=${String(cleanupError)}`) } catch (_) {}
        }
        throw error as Error
      }
    })
  })
}

async function autoReadCurrentPage(driver: Driver): Promise<number> {
  const page = await driver.findComponent(ON.id('rkit-chrome-page'))
  if (page === null) throw new Error('Auto-read page label missing')
  return Number((await page.getText()).split('/')[0].trim())
}

function readerThumbnailAutoReadForegroundTrial(): void {
  describe('ReaderThumbnailAutoReadForegroundTrial', (): void => {
    it('liveBackgroundSessionPausesThenForegroundRestartsFullInterval', 0, async (): Promise<void> => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      const cache = delegator.getAppContext().cacheDir
      for (const name of ['auto-foreground-ready', 'auto-foreground-resumed',
        'auto-foreground-closed', 'auto-foreground-exception']) {
        for (const extension of ['png', 'json']) {
          const path = `${cache}/rkit-entry-${name}.${extension}`
          if (fileIo.accessSync(path)) fileIo.unlinkSync(path)
        }
      }
      const driver = Driver.create()
      let mainWindow: window.Window | null = null
      let sourceId: string = ''
      let entered: boolean = false
      let backgroundRequested: boolean = false
      let originalEpoch: number = 0
      let ownedAbility: UIAbility | null = null
      try {
        // Existing released original probe supplies live session facts even while UI is backgrounded.
        await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
          parameters: { readerLabWork: ENTRY_WORK, readerLabPage: '0', readerLabChrome: 'true',
            readerLabThumbnailEntry: 'true', readerLabEntryLayout: 'spread', readerLabEntryDirection: 'rtl',
            readerLabEntryProbe: 'delay-once', readerLabOriginalProbe: 'hold-once' } })
        const source = await findFirstDetailThumbnail(driver)
        const armedDeadline = Date.now() + 5000
        while (ReaderTrialOriginalProbe.read().state !== 'armed' && Date.now() < armedDeadline) {
          await driver.delayMs(25)
        }
        const armed = ReaderTrialOriginalProbe.read()
        expect(armed.state).assertEqual('armed')
        expect(armed.galleryId).assertEqual(ENTRY_WORK)
        expect(armed.pageIndex).assertEqual(0)
        originalEpoch = armed.epoch
        sourceId = await source.getId()
        const ability = await delegator.getCurrentTopAbility()
        ownedAbility = ability
        mainWindow = await window.getLastWindow(ability.context)
        const baseline = ReaderTrialEntryProbe.read().epoch
        entered = true
        await source.click()
        const heldDeadline = Date.now() + 20000
        while (ReaderTrialOriginalProbe.read().state !== 'held' && Date.now() < heldDeadline) {
          await driver.delayMs(100)
        }
        const held = ReaderTrialOriginalProbe.read()
        expect(held.epoch).assertEqual(originalEpoch)
        expect(held.state).assertEqual('held')
        expect(ReaderTrialOriginalProbe.release(originalEpoch, held.requestId)).assertTrue()
        const entryEpoch = await waitChromeEntrySpread(driver, baseline)
        await waitChromeState(driver, mainWindow, true, entryEpoch)
        await waitRetriedSpread(driver)
        const initial = ReaderTrialOriginalProbe.read()
        expect(initial.state).assertEqual('delivered')
        expect(initial.reader.assetPhase).assertEqual('displayed')
        expect(initial.reader.decodedReady).assertTrue()
        expect(initial.reader.hostActive).assertTrue()
        expect(initial.reader.anchor).assertEqual(0)
        const intervalMs = connectReaderPresentation().autoPageSeconds * 1000
        if (!Number.isInteger(intervalMs / 1000) || intervalMs < 1000 || intervalMs > 60000) {
          throw new Error('Invalid host auto-read interval')
        }
        const assertSameSession = (active: boolean): void => {
          const current = ReaderTrialOriginalProbe.read()
          expect(current.epoch).assertEqual(originalEpoch)
          expect(current.requestId).assertEqual(initial.requestId)
          expect(current.state).assertEqual('delivered')
          expect(current.reader.entryId).assertEqual(initial.reader.entryId)
          expect(current.reader.sessionPhase).assertEqual(initial.reader.sessionPhase)
          expect(current.reader.anchor).assertEqual(initial.reader.anchor)
          expect(current.reader.navigationRevision).assertEqual(initial.reader.navigationRevision)
          expect(current.reader.hostActive).assertEqual(active)
          expect(ReaderTrialEntryProbe.read().epoch).assertEqual(entryEpoch)
        }
        await captureEntry(driver, 'auto-foreground-ready')
        const clock = await driver.findComponent(ON.id('rkit-auto-read'))
        if (clock === null) throw new Error('Auto-read clock missing')
        await clock.click()
        assertSameSession(true)
        backgroundRequested = true
        await delegator.doAbilityBackground(ability)
        const backgroundDeadline = Date.now() + 5000
        while ((ReaderTrialOriginalProbe.read().reader.hostActive ||
          delegator.getAbilityState(ability) !== abilityDelegatorRegistry.AbilityLifecycleState.BACKGROUND) &&
          Date.now() < backgroundDeadline) await driver.delayMs(25)
        const backgroundStarted = Date.now()
        do {
          expect(delegator.getAbilityState(ability)).assertEqual(abilityDelegatorRegistry.AbilityLifecycleState.BACKGROUND)
          assertSameSession(false)
          await driver.delayMs(100)
        } while (Date.now() - backgroundStarted < intervalMs + 1500)
        await delegator.print(`ReaderThumbnailAutoReadForeground background_ms=${Date.now() - backgroundStarted} live=${JSON.stringify(ReaderTrialOriginalProbe.read())}`)
        assertSameSession(false)
        // doAbilityForeground replays the original debug Want on this device; an empty Want preserves the route.
        const foregroundRequestedAt = Date.now()
        await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
        const foregroundDeadline = Date.now() + 5000
        while ((!ReaderTrialOriginalProbe.read().reader.hostActive ||
          delegator.getAbilityState(ability) !== abilityDelegatorRegistry.AbilityLifecycleState.FOREGROUND) &&
          Date.now() < foregroundDeadline) await driver.delayMs(25)
        backgroundRequested = false
        const foregroundObservedAt = Date.now()
        // Bound the observation latency so this entire half-interval is before the earliest full timer expiry.
        if (foregroundObservedAt - foregroundRequestedAt >= intervalMs / 4) {
          throw new Error(`Foreground observation too late elapsed=${foregroundObservedAt - foregroundRequestedAt}` +
            ` ability=${delegator.getAbilityState(ability)} live=${JSON.stringify(ReaderTrialOriginalProbe.read())}` +
            ` entry=${JSON.stringify(ReaderTrialEntryProbe.read())}`)
        }
        do {
          expect(delegator.getAbilityState(ability)).assertEqual(abilityDelegatorRegistry.AbilityLifecycleState.FOREGROUND)
          assertSameSession(true)
          await driver.delayMs(25)
        } while (Date.now() - foregroundObservedAt < intervalMs / 2)
        assertSameSession(true)
        const shortWindowMs = Date.now() - foregroundObservedAt
        const advanceDeadline = Date.now() + intervalMs + 5000
        let advanced: boolean = false
        let firstAdvanceElapsed: number = -1
        while (Date.now() < advanceDeadline) {
          const current = ReaderTrialOriginalProbe.read()
          expect(current.epoch).assertEqual(originalEpoch)
          expect(current.reader.entryId).assertEqual(initial.reader.entryId)
          expect(current.reader.hostActive).assertTrue()
          if (firstAdvanceElapsed < 0 && (current.reader.anchor !== initial.reader.anchor ||
            current.reader.navigationRevision !== initial.reader.navigationRevision)) {
            firstAdvanceElapsed = Date.now() - foregroundRequestedAt
            expect(firstAdvanceElapsed >= intervalMs).assertTrue()
          }
          if (current.reader.anchor === 2 && current.reader.navigationRevision > initial.reader.navigationRevision &&
            await autoReadCurrentPage(driver) === 3 &&
            await driver.findComponent(ON.id('rkit-part-2-whole').within(ON.id('rkit-image-viewport'))) !== null &&
            await driver.findComponent(ON.id('rkit-part-3-whole').within(ON.id('rkit-image-viewport'))) !== null) {
            advanced = true
            break
          }
          await driver.delayMs(25)
        }
        if (!advanced) throw new Error('Same foreground reader did not automatically advance to P3/P4')
        const stop = await driver.findComponent(ON.id('rkit-auto-read'))
        if (stop === null) throw new Error('Auto-read stop clock missing')
        await stop.click()
        await captureEntry(driver, 'auto-foreground-resumed')
        await delegator.print(`ReaderThumbnailAutoReadForeground first_advance_elapsed_ms=${firstAdvanceElapsed} short_window_ms=${shortWindowMs} interval_ms=${intervalMs} released_original_probe=true settings_unmodified=true advanced_to=3 stopped=true P3_P4_decoded_not_asserted=true`)
        await driver.pressBack()
        await waitChromeClosed(driver, mainWindow, sourceId)
        entered = false
        await captureEntry(driver, 'auto-foreground-closed')
      } catch (error) {
        try { await captureEntry(driver, 'auto-foreground-exception') } catch (_) {}
        try {
          if (backgroundRequested && ownedAbility !== null) {
            await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
          }
          ReaderTrialOriginalProbe.cancel(originalEpoch)
          if (entered) {
            await driver.triggerKey(KeyCode.KEYCODE_BACK)
            if (mainWindow !== null && sourceId.length > 0) await waitChromeClosed(driver, mainWindow, sourceId)
          }
        } catch (cleanupError) { console.error(`ReaderThumbnailAutoReadForeground cleanup_failed=${String(cleanupError)}`) }
        throw error as Error
      }
    })
  })
}

function readerThumbnailAutoReadFailureTrial(): void {
  describe('ReaderThumbnailAutoReadFailureTrial', (): void => {
    it('waitsForMissingP2OriginalThenRetriesBeforeAutomaticAdvance', 0, async (): Promise<void> => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      const cache = delegator.getAppContext().cacheDir
      for (const name of ['auto-failure-waiting', 'auto-failure-resumed', 'auto-failure-closed', 'auto-failure-exception']) {
        for (const extension of ['png', 'json']) {
          const path = `${cache}/rkit-entry-${name}.${extension}`
          if (fileIo.accessSync(path)) fileIo.unlinkSync(path)
        }
      }
      const driver = Driver.create()
      let mainWindow: window.Window | null = null
      let sourceId: string = ''
      let entered: boolean = false
      try {
        // Same once-only missing original injection as armFailureEntry, with explicit RTL for this suite.
        await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
          parameters: { readerLabWork: ENTRY_WORK, readerLabPage: '0', readerLabChrome: 'true',
            readerLabThumbnailEntry: 'true', readerLabEntryLayout: 'spread', readerLabEntryDirection: 'rtl',
            readerLabFailPage: '1', readerLabEntryProbe: '' } })
        const source = await findFirstDetailThumbnail(driver)
        sourceId = await source.getId()
        const ability = await delegator.getCurrentTopAbility()
        mainWindow = await window.getLastWindow(ability.context)
        entered = true
        await source.click()
        await waitEntryFailure(driver, 2)
        const first = await driver.findComponent(ON.id('rkit-part-0-whole').within(ON.id('rkit-image-viewport')))
        const second = await driver.findComponent(ON.id('rkit-part-1-whole').within(ON.id('rkit-image-viewport')))
        if (first === null || second === null) throw new Error('Expected RTL P1/P2 failure spread unavailable')
        expect((await second.getBounds()).right <= (await first.getBounds()).left + 1).assertTrue()
        const interval = connectReaderPresentation().autoPageSeconds
        if (!Number.isInteger(interval) || interval < 1 || interval > 60) throw new Error('Invalid host auto-read interval')
        const clock = await driver.findComponent(ON.id('rkit-auto-read'))
        if (clock === null) throw new Error('Auto-read clock missing on failed spread')
        await clock.click()
        const waitingDeadline = Date.now() + interval * 1000 + 1500
        while (Date.now() < waitingDeadline) {
          await assertFirstSpreadAnchor(driver)
          expect(await driver.findComponent(ON.id('rkit-failure-page-2').within(ON.id('rkit-image-viewport'))) !== null).assertTrue()
          await driver.delayMs(200)
        }
        await captureEntry(driver, 'auto-failure-waiting')
        await delegator.print(`ReaderThumbnailAutoReadFailure wait_ms=${interval * 1000 + 1500} injected_missing_original=P2 transport_failure=false settings_unmodified=true`)
        const retry = await waitEntryFailure(driver, 2)
        await retry.click()
        await waitRetriedSpread(driver)
        const advanceDeadline = Date.now() + interval * 1000 + 5000
        let advanced: boolean = false
        while (Date.now() < advanceDeadline) {
          if (await autoReadCurrentPage(driver) === 3 &&
            await driver.findComponent(ON.id('rkit-part-2-whole').within(ON.id('rkit-image-viewport'))) !== null &&
            await driver.findComponent(ON.id('rkit-part-3-whole').within(ON.id('rkit-image-viewport'))) !== null) {
            advanced = true
            break
          }
          await driver.delayMs(100)
        }
        if (!advanced) throw new Error('Auto-read did not resume after P2 original retry')
        const stop = await driver.findComponent(ON.id('rkit-auto-read'))
        if (stop === null) throw new Error('Auto-read stop clock missing')
        await stop.click()
        await captureEntry(driver, 'auto-failure-resumed')
        await delegator.print('ReaderThumbnailAutoReadFailure retried_group_ready=true advanced_to=3 P3_P4_decoded_not_asserted=true')
        await driver.pressBack()
        await waitChromeClosed(driver, mainWindow, sourceId)
        entered = false
        await captureEntry(driver, 'auto-failure-closed')
      } catch (error) {
        try { await captureEntry(driver, 'auto-failure-exception') } catch (_) {}
        try {
          if (entered) {
            await driver.triggerKey(KeyCode.KEYCODE_BACK)
            if (mainWindow !== null && sourceId.length > 0) await waitChromeClosed(driver, mainWindow, sourceId)
          }
        } catch (cleanupError) { console.error(`ReaderThumbnailAutoReadFailure cleanup_failed=${String(cleanupError)}`) }
        throw error as Error
      }
    })
  })
}

function readerThumbnailAutoReadTrial(): void {
  describe('ReaderThumbnailAutoReadTrial', (): void => {
    it('rtlNextSpreadThenExplicitStopRetainsPage', 0, async (): Promise<void> => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      const cache = delegator.getAppContext().cacheDir
      for (const name of ['auto-start', 'auto-stopped', 'auto-closed', 'auto-exception']) {
        for (const extension of ['png', 'json']) {
          const path = `${cache}/rkit-entry-${name}.${extension}`
          if (fileIo.accessSync(path)) fileIo.unlinkSync(path)
        }
      }
      const driver = Driver.create()
      let mainWindow: window.Window | null = null
      let sourceId: string = ''
      let entered: boolean = false
      try {
        await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
          parameters: { readerLabWork: ENTRY_WORK, readerLabPage: '0', readerLabChrome: 'true',
            readerLabThumbnailEntry: 'true', readerLabEntryLayout: 'spread', readerLabEntryDirection: 'rtl',
            readerLabEntryProbe: 'delay-once' } })
        const source = await findFirstDetailThumbnail(driver)
        sourceId = await source.getId()
        const ability = await delegator.getCurrentTopAbility()
        mainWindow = await window.getLastWindow(ability.context)
        const baseline = ReaderTrialEntryProbe.read().epoch
        entered = true
        await source.click()
        const epoch = await waitChromeEntrySpread(driver, baseline)
        await waitChromeState(driver, mainWindow, true, epoch)
        const interval = connectReaderPresentation().autoPageSeconds
        if (!Number.isInteger(interval) || interval < 1 || interval > 60) throw new Error('Auto-read interval outside supported range')
        await delegator.print(`ReaderThumbnailAutoRead interval_seconds=${interval} settings_unmodified=true next_spread_decode_acceptance=false`)
        const clock = await driver.findComponent(ON.id('rkit-auto-read'))
        if (clock === null) throw new Error('Auto-read clock missing')
        await clock.click()
        await captureEntry(driver, 'auto-start')
        const advanceDeadline = Date.now() + interval * 1000 + 5000
        let advanced: boolean = false
        while (Date.now() < advanceDeadline) {
          if (await autoReadCurrentPage(driver) === 3 &&
            await driver.findComponent(ON.id('rkit-part-2-whole').within(ON.id('rkit-image-viewport'))) !== null &&
            await driver.findComponent(ON.id('rkit-part-3-whole').within(ON.id('rkit-image-viewport'))) !== null) {
            advanced = true
            break
          }
          await driver.delayMs(100)
        }
        if (!advanced) throw new Error('Auto-read did not advance to actual P3/P4 viewport')
        const stop = await driver.findComponent(ON.id('rkit-auto-read'))
        if (stop === null) throw new Error('Auto-read stop clock missing')
        await stop.click()
        const stoppedPage = await autoReadCurrentPage(driver)
        expect(stoppedPage).assertEqual(3)
        const stableDeadline = Date.now() + interval * 1000 + 1000
        while (Date.now() < stableDeadline) {
          expect(await autoReadCurrentPage(driver)).assertEqual(stoppedPage)
          await driver.delayMs(200)
        }
        expect(await autoReadCurrentPage(driver)).assertEqual(stoppedPage)
        await captureEntry(driver, 'auto-stopped')
        await delegator.print('ReaderThumbnailAutoRead advanced_to=3 stopped_stable=true P3_P4_decoded_not_asserted=true')
        await driver.pressBack()
        await waitChromeClosed(driver, mainWindow, sourceId)
        entered = false
        await captureEntry(driver, 'auto-closed')
      } catch (error) {
        try { await captureEntry(driver, 'auto-exception') } catch (_) {}
        try {
          if (entered) {
            await driver.triggerKey(KeyCode.KEYCODE_BACK)
            if (mainWindow !== null && sourceId.length > 0) await waitChromeClosed(driver, mainWindow, sourceId)
          }
        } catch (cleanupError) {
          try { await delegator.print(`ReaderThumbnailAutoRead cleanup_failed=${String(cleanupError)}`) } catch (_) {}
        }
        throw error as Error
      }
    })
  })
}

/** Explicit class selection: P1 entry cancellation or the authorized P1/P2 spread failure endpoints. */
function readerProductionCropTrial(work: string, layout: string): void {
  describe(layout === 'spread' ? 'ReaderProductionCropSpreadTrial' :
    layout === 'continuous' ? 'ReaderProductionCropContinuousTrial' : 'ReaderProductionCropTrial', (): void => {
    it('productionCropReferenceRestoresLiveAndDurableSettings', 0, async (): Promise<void> => {
      clearEntryCaptures(['reader', 'closed', 'exception'])
      const driver = Driver.create(), delegator = abilityDelegatorRegistry.getAbilityDelegator()
      await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
      for (let i = 0; i < 40; i++) {
        if (await driver.findComponent(ON.id('nextn-root-navigation')) !== null) break
        await driver.delayMs(250)
      }
      expect(await driver.findComponent(ON.id('nextn-root-navigation')) !== null).assertTrue()
      const ability = await delegator.getCurrentTopAbility(), context = ability.context
      await ReaderPresentationService.restore(context)
      const setting = connectReaderPresentation()
      const mode = setting.mode, doublePage = setting.doublePageEnabled
      const crop = setting.cropBordersPaged, continuousCrop = setting.cropBordersContinuous
      const superResolution = setting.superResolutionEnabled
      const overlay = connectReaderOverlayNavigation()
      expect(overlay.visible).assertFalse()
      const sourceIndex = layout === 'continuous' ? 5 : 2
      try {
        await ReaderPresentationService.setSuperResolutionEnabled(context, false)
        await ReaderPresentationService.setMode(context, layout === 'continuous' ? NhReaderMode.VERTICAL : NhReaderMode.PAGED)
        await ReaderPresentationService.setDoublePageEnabled(context, layout === 'spread')
        if (layout === 'continuous') await ReaderPresentationService.setCropBordersContinuous(context, true)
        else await ReaderPresentationService.setCropBordersPaged(context, true)
        overlay.open(new ReaderRouteParams(Number(work), sourceIndex), false)
        const surface = ON.id('reader-overlay-navigation')
        const slider = ON.type('Slider').within(surface)
        let ready = false
        for (let i = 0; i < 80; i++) {
          if (await driver.findComponent(surface) !== null &&
            await driver.findComponent(ON.type('Image').within(surface)) !== null &&
            await driver.findComponent(ON.type('LoadingProgress').within(surface)) === null) {
            ready = true; break
          }
          await driver.delayMs(250)
        }
        expect(ready).assertTrue()
        if (await driver.findComponent(slider) === null) {
          const bounds = await (await driver.findComponent(surface)).getBounds()
          await driver.click(Math.round((bounds.left + bounds.right) / 2), Math.round((bounds.top + bounds.bottom) / 2))
        }
        const label = layout === 'spread' ? '3–4 / 40' : `${sourceIndex + 1} / 40`
        for (let i = 0; i < 30; i++) {
          if (await driver.findComponent(ON.text(label).within(surface)) !== null &&
            await driver.findComponent(slider) !== null) break
          await driver.delayMs(200)
        }
        expect(await driver.findComponent(ON.text(label).within(surface)) !== null).assertTrue()
        expect(await driver.findComponent(slider) !== null).assertTrue()
        await captureEntry(driver, 'reader')
        await driver.pressBack()
        for (let i = 0; i < 40 && overlay.visible; i++) await driver.delayMs(200)
        expect(overlay.visible).assertFalse()
        await captureEntry(driver, 'closed')
      } catch (error) {
        await captureEntry(driver, 'exception')
        throw error as Error
      } finally {
        const errors: string[] = []
        try { if (overlay.visible) { await driver.pressBack(); await driver.delayMs(800) } }
        catch (error) { errors.push(String(error)) }
        try { await ReaderPresentationService.setMode(context, mode) } catch (error) { errors.push(String(error)) }
        try { await ReaderPresentationService.setDoublePageEnabled(context, doublePage) } catch (error) { errors.push(String(error)) }
        try { await ReaderPresentationService.setCropBordersPaged(context, crop) } catch (error) { errors.push(String(error)) }
        try { await ReaderPresentationService.setCropBordersContinuous(context, continuousCrop) } catch (error) { errors.push(String(error)) }
        try { await ReaderPresentationService.setSuperResolutionEnabled(context, superResolution) } catch (error) { errors.push(String(error)) }
        const live = connectReaderPresentation()
        const restored = live.mode === mode && live.doublePageEnabled === doublePage &&
          live.cropBordersPaged === crop && live.cropBordersContinuous === continuousCrop &&
          await ReaderSettingsRepository.mode(context) === mode &&
          await ReaderSettingsRepository.doublePageEnabled(context) === doublePage &&
          await ReaderSettingsRepository.cropBordersPaged(context) === crop &&
          await ReaderSettingsRepository.cropBordersContinuous(context) === continuousCrop &&
          live.superResolutionEnabled === superResolution &&
          await ReaderSettingsRepository.superResolutionEnabled(context) === superResolution
        await delegator.print(`ReaderProductionCrop restored=${restored} storage=reader_settings_RDB mode=${mode} double=${doublePage} crop=${crop} continuousCrop=${continuousCrop} superResolution=${superResolution} errors=${errors.length}`)
        expect(restored && errors.length === 0 && !overlay.visible).assertTrue()
      }
    })
  })
}

export default function readerThumbnailEntryTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  const trial = args['-s class']
  if (trial === 'ReaderProductionCropTrial' || trial === 'ReaderProductionCropSpreadTrial' ||
    trial === 'ReaderProductionCropContinuousTrial') {
    readerProductionCropTrial('663205', trial === 'ReaderProductionCropSpreadTrial' ? 'spread' :
      trial === 'ReaderProductionCropContinuousTrial' ? 'continuous' : 'single')
    return
  }
  if (args['-s class'] === 'ReaderThumbnailAutoReadForegroundTrial') {
    readerThumbnailAutoReadForegroundTrial()
    return
  }
  if (args['-s class'] === 'ReaderThumbnailAutoReadFailureTrial') {
    readerThumbnailAutoReadFailureTrial()
    return
  }
  if (args['-s class'] === 'ReaderThumbnailAutoReadTrial') {
    readerThumbnailAutoReadTrial()
    return
  }
  if (args['-s class'] === 'ReaderThumbnailSaveBothTrial') {
    readerThumbnailSaveMenuTrial(true, true)
    return
  }
  if (args['-s class'] === 'ReaderThumbnailSaveTrial') {
    readerThumbnailSaveMenuTrial(true)
    return
  }
  if (args['-s class'] === 'ReaderThumbnailSaveMenuTrial') {
    readerThumbnailSaveMenuTrial()
    return
  }
  if (args['-s class'] === 'ReaderThumbnailChromeTrial') {
    readerThumbnailChromeTrial()
    return
  }
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
