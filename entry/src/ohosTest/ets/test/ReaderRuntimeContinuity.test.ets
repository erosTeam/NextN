/**
 * Runtime continuity across an install -r upgrade/rollback cycle — Package 5.
 *
 * The A/B/C file-hash experiments prove only that `install -r` leaves the
 * checked durable files byte-identical between builds. They do not prove that
 * re-reading after an upgrade or rollback lands on the same content identity,
 * page, settings, and progress. These trials close that gap by driving the
 * real reader entry and then reading the host's own durable state.
 *
 * Three orchestrated phases, one device-protocol manifest each:
 *   Phase 1 `ReaderRuntimeContinuityWriteTrial`  — read to a chosen page.
 *   Phase 2 `ReaderRuntimeContinuityVerifyTrial` — read back after install -r.
 *
 * The written page and its durable record are captured to the app cache, which
 * survives `install -r`. Nothing is asserted from a hardcoded expectation: the
 * verify phase re-derives the expected page from the Phase 1 record and then
 * confirms the live reader shows it.
 *
 * Cold start deliberately keeps Legacy (the current production contract), so
 * every phase selects Shared in-process through the real Settings row and never
 * rewrites the persisted default.
 */
import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, MatchPattern, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { fileIo } from '@kit.CoreFileKit'
import {
  connectNextNReaderBackendSelection,
  NextNReaderBackend,
  ReaderSettingsRepository,
  AppStrings,
} from 'shared'
import {
  openBackendRehearsal,
  returnFromReaderSettings,
  selectBackendFromUi,
} from './ReaderProductionDownloadEntryTrial.test'

const GALLERY_ID: number = 678049
const RECORD_FILE: string = 'reader-runtime-continuity.json'
const CAPTURE_PREFIX: string = 'reader-runtime-continuity'

/** Durable facts a user would notice surviving an upgrade or a rollback. */
class ContinuityRecord {
  galleryId: number = GALLERY_ID
  /** Content identity, so a resume cannot be credited to a different title. */
  mediaId: string = ''
  title: string = ''
  pageCount: number = 0
  pageIndex: number = -1
  /** `reading_history.last_read_index` as observed after leaving the reader. */
  historyLastReadIndex: number = -1
  historyHasProgress: number = 0
  /** The persisted presentation choice the reader must still inherit. */
  readerMode: string = ''
  settingsRowCount: number = 0
  writtenAt: number = 0
}

function recordPath(): string {
  return `${abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir}/${RECORD_FILE}`
}

function writeRecord(value: ContinuityRecord): void {
  const file = fileIo.openSync(recordPath(),
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
  try { fileIo.writeSync(file.fd, JSON.stringify(value)) } finally { fileIo.closeSync(file) }
}

function readRecord(): ContinuityRecord {
  if (!fileIo.accessSync(recordPath())) {
    throw new Error('Runtime continuity record missing; the write phase did not complete')
  }
  return JSON.parse(fileIo.readTextSync(recordPath())) as ContinuityRecord
}

async function entryContext(driver: Driver): Promise<common.UIAbilityContext> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  for (let attempt = 0; attempt < 80; attempt++) {
    try {
      const ability = await delegator.getCurrentTopAbility()
      if (ability.context.abilityInfo.name === 'EntryAbility') return ability.context
    } catch (_) {}
    await driver.delayMs(100)
  }
  throw new Error('EntryAbility context unavailable')
}

async function store(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
  return relationalStore.getRdbStore(context,
    { name: 'NextN.db', securityLevel: relationalStore.SecurityLevel.S3, autoCleanDirtyData: true })
}

class HistoryFacts {
  present: boolean = false
  mediaId: string = ''
  title: string = ''
  pageCount: number = 0
  lastReadIndex: number = -1
  hasProgress: number = 0
}

async function historyFacts(database: relationalStore.RdbStore): Promise<HistoryFacts> {
  const facts = new HistoryFacts()
  const rows = await database.querySql(
    'SELECT media_id,title,page_count,last_read_index,has_read_progress ' +
      'FROM reading_history WHERE gallery_id=? LIMIT 1', [GALLERY_ID])
  try {
    if (!rows.goToFirstRow()) return facts
    facts.present = true
    facts.mediaId = rows.getString(0)
    facts.title = rows.getString(1)
    facts.pageCount = rows.getLong(2)
    facts.lastReadIndex = rows.getLong(3)
    facts.hasProgress = rows.getLong(4)
    return facts
  } finally { rows.close() }
}

/** The legacy overlay's "N / M" counter, which carries no stable id. */
async function legacyVisiblePage(driver: Driver): Promise<number> {
  for (let attempt: number = 0; attempt < 80; attempt++) {
    const labels = await driver.findComponents(
      ON.text('^[0-9]+\\s*/\\s*[0-9]+$', MatchPattern.REG_EXP)) ?? []
    for (const label of labels) {
      try {
        const value: string = await label.getText()
        if (/^[0-9]+\s*\/\s*[0-9]+$/.test(value)) return pageLabelIndex(value)
      } catch (_) {}
    }
    await driver.delayMs(250)
  }
  throw new Error('Legacy Reader exposed no readable page label')
}

/** Open the reader through the ordinary Detail action, asserting which surface owns it. */
async function openReaderFromDetail(driver: Driver, expectShared: boolean): Promise<void> {
  await openHistoryDetail(driver)
  await (await waitId(driver, 'gallery-detail-read-action')).click()
  if (expectShared) {
    await waitId(driver, 'rkit-reading-surface', 160)
    return
  }
  for (let attempt: number = 0; attempt < 160; attempt++) {
    const legacy = await driver.findComponent(ON.id('legacy-reader-surface'))
    if (legacy !== null && await driver.findComponent(ON.id('rkit-reading-surface')) === null) return
    await driver.delayMs(250)
  }
  throw new Error('Legacy Reader did not own the ordinary Detail entry')
}

async function settingsRowCount(database: relationalStore.RdbStore): Promise<number> {
  const rows = await database.querySql('SELECT COUNT(*) FROM reader_settings', [])
  try {
    rows.goToFirstRow()
    return rows.getLong(0)
  } finally { rows.close() }
}

async function waitId(driver: Driver, id: string, attempts: number = 120): Promise<Component> {
  for (let attempt: number = 0; attempt < attempts; attempt++) {
    const component = await driver.findComponent(ON.id(id))
    if (component !== null) return component
    await driver.delayMs(250)
  }
  throw new Error(`Runtime continuity component unavailable: ${id}`)
}

async function capture(driver: Driver, name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  expect((await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/${CAPTURE_PREFIX}-${name}.json -a`, 15)).exitCode).assertEqual(0)
  expect(await driver.screenCap(
    `${delegator.getAppContext().cacheDir}/${CAPTURE_PREFIX}-${name}.png`)).assertTrue()
}

/** Page label while the Shared chrome is up ("3 / 14"). */
function pageLabelIndex(text: string): number {
  const match = /^\s*([1-9][0-9]*)\s*\/\s*([1-9][0-9]*)\s*$/.exec(text)
  if (match === null) throw new Error(`Unexpected Shared page label: ${text}`)
  return Number(match[1]) - 1
}

/**
 * The reader's current position, read wherever the live UI exposes it. The
 * passive counter is only mounted while the page-number preference is on, so a
 * reader with that preference off falls back to raising the chrome.
 */
async function sharedVisiblePage(driver: Driver): Promise<number> {
  for (let attempt: number = 0; attempt < 40; attempt++) {
    const passive = await driver.findComponent(ON.id('rkit-persistent-page'))
    if (passive !== null) {
      try { return pageLabelIndex(await passive.getText()) } catch (_) {}
    }
    const chromePage = await driver.findComponent(ON.id('rkit-chrome-page'))
    if (chromePage !== null) {
      try { return pageLabelIndex(await chromePage.getText()) } catch (_) {}
    }
    await driver.delayMs(250)
  }
  throw new Error('Shared Reader exposed no readable page label')
}

/** Raise the Shared chrome so the same reader can also be read via its own top bar. */
async function showSharedChrome(driver: Driver): Promise<void> {
  if (await driver.findComponent(ON.id('rkit-chrome-page')) !== null) return
  const surface = await waitId(driver, 'rkit-reading-surface')
  const bounds = await surface.getBounds()
  await driver.click(Math.round((bounds.left + bounds.right) / 2), Math.round((bounds.top + bounds.bottom) / 2))
  await waitId(driver, 'rkit-chrome-page')
}

/** Drop the transient chrome again so the frame shows the reading surface. */
async function hideSharedChrome(driver: Driver): Promise<void> {
  for (let attempt: number = 0; attempt < 20; attempt++) {
    if (await driver.findComponent(ON.id('rkit-chrome-page')) === null) return
    const surface = await waitId(driver, 'rkit-reading-surface')
    const bounds = await surface.getBounds()
    await driver.click(Math.round((bounds.left + bounds.right) / 2), Math.round((bounds.top + bounds.bottom) / 2))
    await driver.delayMs(400)
  }
}

/**
 * Advance one page along whichever axis the reader is actually laid out in.
 * The persisted mode decides paged/continuous and the direction decides which
 * way forward runs, so both axes are attempted and the caller confirms progress
 * from the page label instead of trusting the gesture.
 */
async function turnOnePageForward(driver: Driver, forward: boolean): Promise<void> {
  const viewport = await waitId(driver, 'rkit-image-viewport')
  const bounds = await viewport.getBounds()
  const x = Math.round((bounds.left + bounds.right) / 2)
  const y = Math.round((bounds.top + bounds.bottom) / 2)
  const flip = forward ? -1 : 1
  const horizontal = Math.round((bounds.right - bounds.left) * 0.31) * flip
  const vertical = Math.round((bounds.bottom - bounds.top) * 0.31) * flip
  await driver.swipe(x + horizontal, y, x - horizontal, y, 600)
  await driver.delayMs(600)
  await driver.swipe(x, y - vertical, x, y + vertical, 600)
  await driver.delayMs(600)
}

async function closeAnyReader(driver: Driver): Promise<void> {
  const sharedClose = await driver.findComponent(ON.id('rkit-close'))
  if (sharedClose !== null) await sharedClose.click()
  else if (await driver.findComponent(ON.id('reader-overlay-navigation')) !== null) await driver.pressBack()
  for (let attempt: number = 0; attempt < 80; attempt++) {
    if (await driver.findComponent(ON.id('reader-overlay-navigation')) === null) return
    await driver.delayMs(250)
  }
  throw new Error('Runtime continuity Reader did not close')
}

/** Return from a retained Detail to the root surface that owns the tabs. */
async function backToHomeRoot(driver: Driver): Promise<void> {
  for (let attempt: number = 0; attempt < 16; attempt++) {
    // A pushed History/Detail page also leaves the root navigation mounted, so
    // "no Detail action and no reader" is not enough to call this the root. The
    // visible root tab bar is the actual discriminator; keep unwinding until it
    // is back.
    const tab = await driver.findComponent(ON.id('nextn-root-tab-3'))
    const reader = await driver.findComponent(ON.id('legacy-reader-surface'))
    const shared = await driver.findComponent(ON.id('rkit-reading-surface'))
    if (tab !== null && reader === null && shared === null) return
    await driver.pressBack()
    await driver.delayMs(600)
  }
  throw new Error('Home root did not return for the backend rehearsal')
}

/** Visible text at a failure point, so a stuck navigation is diagnosable. */
async function visibleTexts(driver: Driver): Promise<string[]> {
  const values: string[] = []
  const candidates: string[] = ['settings_reader', 'settings_reader_group_rehearsal', 'settings_reader_backend',
    'tab_history', 'tab_profile', 'detail_view_all']
  for (const key of candidates) {
    try {
      if (await driver.findComponent(ON.text(AppStrings.get(key))) !== null) values.push(key)
    } catch (_) {}
  }
  return values
}

async function openHistoryDetail(driver: Driver): Promise<void> {
  await (await waitId(driver, 'nextn-root-tab-3')).click()
  const historyRows = await driver.findComponents(
    ON.text('历史记录').within(ON.id('nextn-root-navigation')))
  if (historyRows.length !== 1) throw new Error('History entry is not unique')
  await historyRows[0].click()
  const selector = ON.id(`^gallery-list-history-[0-9]+-history-${GALLERY_ID}$`, MatchPattern.REG_EXP)
    .within(ON.id('nextn-root-navigation'))
  for (let attempt: number = 0; attempt < 120; attempt++) {
    const found = await driver.findComponent(selector)
    if (found !== null) {
      await found.click()
      await waitId(driver, 'gallery-detail-read-action')
      return
    }
    const owners = await driver.findComponents(ON.type('Scroll').within(ON.id('nextn-root-navigation'))) ?? []
    if (owners.length >= 1) {
      const scrolled = await owners[0].scrollSearch(selector, true)
      if (scrolled !== null) {
        await scrolled.click()
        await waitId(driver, 'gallery-detail-read-action')
        return
      }
    }
    await driver.delayMs(250)
  }
  throw new Error(`History entry unavailable for gallery ${GALLERY_ID}`)
}

/**
 * Reach the Reader settings subpage on whatever depth the navigation is at.
 * Closing a reader leaves a retained Detail behind, so a single Back is not a
 * reliable route to the tab shell; the root tab and the settings row are both
 * re-resolved until the rehearsal row exists.
 */
async function enterReaderSettings(driver: Driver): Promise<void> {
  for (let attempt: number = 0; attempt < 50; attempt++) {
    if (await driver.findComponent(ON.id('nextn-reader-backend-rehearsal-row')) !== null) return
    // The rehearsal row lives inside the Reader settings subpage, so the
    // settings root row is the step that actually advances this route.
    const readerRow = await driver.findComponent(ON.text(AppStrings.get('settings_reader')))
    if (readerRow !== null) {
      await readerRow.click()
      await driver.delayMs(500)
      continue
    }
    const tab = await driver.findComponent(ON.id('nextn-root-tab-3'))
    if (tab !== null) {
      await tab.click()
      await driver.delayMs(400)
      continue
    }
    const detailBack = await driver.findComponent(ON.id('gallery-detail-read-action'))
    if (detailBack !== null) {
      await driver.pressBack()
      await driver.delayMs(500)
      continue
    }
    await driver.delayMs(400)
  }
  await capture(driver, 'exception-reader-settings')
  throw new Error(`Reader settings unreachable; visible=${JSON.stringify(await visibleTexts(driver))}`)
}

/** Select Shared for this process only; the persisted default stays Legacy. */
async function selectSharedInProcess(driver: Driver): Promise<void> {
  await enterReaderSettings(driver)
  await selectBackendFromUi(driver, NextNReaderBackend.SHARED)
  await returnFromReaderSettings(driver)
}

/**
 * Open the Shared reader from the ordinary Detail action and advance with real
 * page turns until it reports the requested page. Forward direction on this
 * page axis is confirmed by the label, so a wrong-way first gesture is
 * corrected rather than silently accepted.
 */
async function openSharedFromDetailAndAdvance(driver: Driver, targetPage: number): Promise<number> {
  await openReaderFromDetail(driver, true)
  const start = await sharedVisiblePage(driver)
  if (start === targetPage) return start
  const forward = targetPage > start
  for (let turn: number = 0; turn < 40; turn++) {
    const current = await sharedVisiblePage(driver)
    if (current === targetPage) return current
    if ((forward && current > targetPage) || (!forward && current < targetPage)) break
    await turnOnePageForward(driver, forward)
  }
  const reached = await sharedVisiblePage(driver)
  if (reached !== targetPage) throw new Error(`Reader reached page ${reached}, expected ${targetPage}`)
  return reached
}

export default function readerRuntimeContinuityTest(): void {
  const selectedClass = abilityDelegatorRegistry.getArguments().parameters['-s class']

  if (selectedClass === 'ReaderRuntimeContinuityWriteTrial') {
    describe(selectedClass, (): void => {
      it('leavesRealProgressAndSettingsForTheNextInstall', 0, async (): Promise<void> => {
        const driver = Driver.create()
        const delegator = abilityDelegatorRegistry.getAbilityDelegator()
        await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
        const context = await entryContext(driver)
        const database = await store(context)
        expect(connectNextNReaderBackendSelection().current()).assertEqual(NextNReaderBackend.LEGACY)

        const targetPage: number = 3
        await selectSharedInProcess(driver)
        const reached = await openSharedFromDetailAndAdvance(driver, targetPage)
        await showSharedChrome(driver)
        expect(pageLabelIndex(await (await waitId(driver, 'rkit-chrome-page')).getText())).assertEqual(reached)
        await capture(driver, `write-page-${reached}`)
        await hideSharedChrome(driver)
        await closeAnyReader(driver)

        // Let the host finish its own durable write rather than assuming it.
        let facts = await historyFacts(database)
        for (let attempt: number = 0; attempt < 80; attempt++) {
          if (facts.present && facts.lastReadIndex === reached && facts.hasProgress === 1) break
          await driver.delayMs(250)
          facts = await historyFacts(database)
        }
        expect(facts.present).assertTrue()
        expect(facts.lastReadIndex).assertEqual(reached)
        expect(facts.hasProgress).assertEqual(1)
        expect(facts.mediaId.length > 0).assertTrue()

        const record = new ContinuityRecord()
        record.mediaId = facts.mediaId
        record.title = facts.title
        record.pageCount = facts.pageCount
        record.pageIndex = reached
        record.historyLastReadIndex = facts.lastReadIndex
        record.historyHasProgress = facts.hasProgress
        record.readerMode = await ReaderSettingsRepository.mode(context)
        record.settingsRowCount = await settingsRowCount(database)
        record.writtenAt = Date.now()
        writeRecord(record)
        await capture(driver, 'write-record')
        console.info(`[ReaderRuntimeContinuityWriteTrial] page=${reached} media=${record.mediaId} ` +
          `pages=${record.pageCount} mode=${record.readerMode} settingsRows=${record.settingsRowCount} ` +
          `historyProgress=${facts.hasProgress}`)
      })
    })
    return
  }

  if (selectedClass === 'ReaderRuntimeContinuityVerifyTrial') {
    describe(selectedClass, (): void => {
      it('resumesTheSamePageAndSettingsAfterInstallReplacement', 0, async (): Promise<void> => {
        const driver = Driver.create()
        const delegator = abilityDelegatorRegistry.getAbilityDelegator()
        const expected = readRecord()
        await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
        const context = await entryContext(driver)
        const database = await store(context)

        // Cold start must still be Legacy: continuity may not be bought by
        // silently making Shared the persisted production default.
        expect(connectNextNReaderBackendSelection().current()).assertEqual(NextNReaderBackend.LEGACY)

        const facts = await historyFacts(database)
        expect(facts.present).assertTrue()
        // Content identity first: a page number alone would not prove that the
        // same gallery resumed rather than an unrelated row.
        expect(facts.mediaId).assertEqual(expected.mediaId)
        expect(facts.title).assertEqual(expected.title)
        expect(facts.pageCount).assertEqual(expected.pageCount)
        expect(facts.lastReadIndex).assertEqual(expected.historyLastReadIndex)
        expect(facts.hasProgress).assertEqual(expected.historyHasProgress)
        expect(await ReaderSettingsRepository.mode(context)).assertEqual(expected.readerMode)

        // The cold-start default is Legacy, so the fallback path is verified
        // first through the same ordinary Detail entry, at the same page.
        await openReaderFromDetail(driver, false)
        const legacyPage = await legacyVisiblePage(driver)
        expect(legacyPage).assertEqual(expected.pageIndex)
        await capture(driver, `verify-legacy-${legacyPage}`)
        await closeAnyReader(driver)

        await backToHomeRoot(driver)
        await selectSharedInProcess(driver)
        await openReaderFromDetail(driver, true)
        const resumed = await sharedVisiblePage(driver)
        expect(resumed).assertEqual(expected.pageIndex)
        await capture(driver, `verify-shared-${resumed}`)
        await showSharedChrome(driver)
        expect(pageLabelIndex(await (await waitId(driver, 'rkit-chrome-page')).getText())).assertEqual(expected.pageIndex)
        await capture(driver, `verify-chrome-${expected.pageIndex}`)
        await hideSharedChrome(driver)
        await closeAnyReader(driver)

        // Selecting Shared must remain an in-process rehearsal: return to the
        // production-safe backend explicitly rather than leaving it sticky.
        await backToHomeRoot(driver)
        await enterReaderSettings(driver)
        await selectBackendFromUi(driver, NextNReaderBackend.LEGACY)
        await returnFromReaderSettings(driver)
        expect(connectNextNReaderBackendSelection().current()).assertEqual(NextNReaderBackend.LEGACY)
        console.info(`[ReaderRuntimeContinuityVerifyTrial] resumed=${resumed} expected=${expected.pageIndex} ` +
          `legacyFallback=${legacyPage} media=${facts.mediaId} ` +
          `settingsRows=${await settingsRowCount(database)} coldStart=legacy`)
      })
    })
    return
  }
}
