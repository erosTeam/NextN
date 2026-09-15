import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, MatchPattern, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { fileIo } from '@kit.CoreFileKit'
import { KeyCode } from '@kit.InputKit'
import {
  AppStrings,
  connectNextNReaderBackendSelection,
  connectReaderPresentation,
  DownloadQueueService,
  NextNReaderBackend,
  NhDownloadTask,
  NhReaderMode,
  NhReaderSpreadLayout,
  ReaderPresentationService,
} from 'shared'

const CAPTURE_PREFIX: string = 'reader-production-download-entry'
const SNAPSHOT_FILE: string = 'reader-production-download-entry-history.json'

class HistorySnapshot {
  present: boolean = false
  galleryId: number = 0
  mediaId: string = ''
  title: string = ''
  thumbnailUrl: string = ''
  pageCount: number = 0
  lastReadIndex: number = 0
  hasReadProgress: number = 0
  lastOpenedAt: number = 0
}

class SettingSnapshot {
  key: string
  value: string | null
  constructor(key: string, value: string | null) { this.key = key; this.value = value }
}

function snapshotPath(): string {
  return `${abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir}/${SNAPSHOT_FILE}`
}

function writeSnapshot(value: HistorySnapshot): void {
  const file = fileIo.openSync(snapshotPath(),
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
  try { fileIo.writeSync(file.fd, JSON.stringify(value)) } finally { fileIo.closeSync(file) }
}

function readSnapshot(): HistorySnapshot {
  const path: string = snapshotPath()
  if (!fileIo.accessSync(path)) throw new Error('Download entry history snapshot unavailable')
  return JSON.parse(fileIo.readTextSync(path)) as HistorySnapshot
}

function removeSnapshot(): void {
  const path: string = snapshotPath()
  if (fileIo.accessSync(path)) fileIo.unlinkSync(path)
}

async function startSharedBackend(): Promise<void> {
  await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
    bundleName: 'com.erosteam.nextn',
    abilityName: 'EntryAbility',
    parameters: { nextn_reader_backend: 'shared' },
  })
}

async function startLegacyBackend(): Promise<void> {
  await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
    bundleName: 'com.erosteam.nextn',
    abilityName: 'EntryAbility',
    parameters: { nextn_reader_backend: 'legacy' },
  })
}

async function startNormalHost(): Promise<void> {
  await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
    bundleName: 'com.erosteam.nextn',
    abilityName: 'EntryAbility',
  })
}

async function entryContext(driver: Driver): Promise<common.UIAbilityContext> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  for (let attempt: number = 0; attempt < 80; attempt += 1) {
    try {
      const ability = await delegator.getCurrentTopAbility()
      if (ability.context.abilityInfo.name === 'EntryAbility') return ability.context
    } catch (_error) {
      // Ability startup can briefly expose no top ability to the delegator.
    }
    await driver.delayMs(100)
  }
  throw new Error('EntryAbility context unavailable')
}

async function store(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
  return relationalStore.getRdbStore(context,
    { name: 'NextN.db', securityLevel: relationalStore.SecurityLevel.S3, autoCleanDirtyData: true })
}

async function snapshotHistory(
  database: relationalStore.RdbStore,
  galleryId: number,
): Promise<HistorySnapshot> {
  const value = new HistorySnapshot()
  value.galleryId = galleryId
  const row = await database.querySql(
    'SELECT gallery_id,media_id,title,thumbnail_url,page_count,last_read_index,has_read_progress,last_opened_at ' +
      'FROM reading_history WHERE gallery_id=? LIMIT 1', [galleryId])
  try {
    if (!row.goToFirstRow()) return value
    value.present = true
    value.galleryId = row.getLong(0)
    value.mediaId = row.getString(1)
    value.title = row.getString(2)
    value.thumbnailUrl = row.getString(3)
    value.pageCount = row.getLong(4)
    value.lastReadIndex = row.getLong(5)
    value.hasReadProgress = row.getLong(6)
    value.lastOpenedAt = row.getLong(7)
    return value
  } finally {
    row.close()
  }
}

async function restoreHistory(
  database: relationalStore.RdbStore,
  value: HistorySnapshot,
): Promise<void> {
  if (!value.present) {
    await database.executeSql('DELETE FROM reading_history WHERE gallery_id=?', [value.galleryId])
    return
  }
  await database.executeSql(
    'INSERT INTO reading_history ' +
      '(gallery_id,media_id,title,thumbnail_url,page_count,last_read_index,has_read_progress,last_opened_at) ' +
      'VALUES (?,?,?,?,?,?,?,?) ON CONFLICT(gallery_id) DO UPDATE SET ' +
      'media_id=excluded.media_id,title=excluded.title,thumbnail_url=excluded.thumbnail_url,' +
      'page_count=excluded.page_count,last_read_index=excluded.last_read_index,' +
      'has_read_progress=excluded.has_read_progress,last_opened_at=excluded.last_opened_at',
    [value.galleryId, value.mediaId, value.title, value.thumbnailUrl, value.pageCount, value.lastReadIndex,
      value.hasReadProgress, value.lastOpenedAt])
}

async function restoreAndVerify(database: relationalStore.RdbStore, value: HistorySnapshot): Promise<void> {
  await restoreHistory(database, value)
  expect(JSON.stringify(await snapshotHistory(database, value.galleryId))).assertEqual(JSON.stringify(value))
}

async function settingValue(database: relationalStore.RdbStore, key: string): Promise<string | null> {
  const rows = await database.querySql('SELECT value FROM reader_settings WHERE key=? LIMIT 1', [key])
  try {
    if (!rows.goToFirstRow()) return null
    return rows.isColumnNull(0) ? '' : rows.getString(0)
  } finally { rows.close() }
}

async function restoreSetting(database: relationalStore.RdbStore, value: SettingSnapshot): Promise<void> {
  if (value.value === null) {
    await database.executeSql('DELETE FROM reader_settings WHERE key=?', [value.key])
  } else {
    await database.executeSql(
      'INSERT INTO reader_settings (key,value) VALUES (?,?) ' +
        'ON CONFLICT(key) DO UPDATE SET value=excluded.value', [value.key, value.value])
  }
  expect(await settingValue(database, value.key)).assertEqual(value.value)
}

async function waitId(driver: Driver, id: string, attempts: number = 80): Promise<Component> {
  for (let attempt: number = 0; attempt < attempts; attempt += 1) {
    const component = await driver.findComponent(ON.id(id))
    if (component !== null) return component
    await driver.delayMs(250)
  }
  throw new Error(`Production download entry component unavailable: ${id}`)
}

async function findDownloadEntry(driver: Driver, galleryId: number): Promise<Component> {
  const id: string = `download-task-reader-${galleryId}`
  const root: Component = await waitId(driver, 'nextn-download-queue-root', 120)
  for (let attempt: number = 0; attempt < 24; attempt += 1) {
    const row = await driver.findComponent(ON.id(id))
    if (row !== null) return row
    const bounds = await root.getBounds()
    const x: number = Math.round((bounds.left + bounds.right) / 2)
    await driver.swipe(x, bounds.bottom - 260, x, bounds.top + 320, 450)
    await driver.delayMs(250)
  }
  throw new Error(`Complete download row unavailable: ${galleryId}`)
}

async function waitText(driver: Driver, key: string, attempts: number = 80): Promise<Component> {
  const selector = ON.text(AppStrings.get(key))
  for (let attempt: number = 0; attempt < attempts; attempt += 1) {
    const direct = await driver.findComponent(selector)
    if (direct !== null) return direct
    const lists: Component[] = await driver.findComponents(ON.type('List'))
    for (const list of lists) {
      const found = await list.scrollSearch(selector, true)
      if (found !== null) return found
    }
    await driver.delayMs(150)
  }
  throw new Error(`Production backend text unavailable: ${key}`)
}

export async function openBackendRehearsal(driver: Driver): Promise<void> {
  await (await waitId(driver, 'nextn-root-tab-3')).click()
  await (await waitText(driver, 'settings_reader')).click()
  await waitId(driver, 'nextn-reader-backend-rehearsal-row')
}

export async function selectBackendFromUi(driver: Driver, backend: NextNReaderBackend): Promise<void> {
  await (await waitId(driver, 'nextn-reader-backend-rehearsal-row')).click()
  const key: string = backend === NextNReaderBackend.SHARED
    ? 'settings_reader_backend_shared'
    : 'settings_reader_backend_legacy'
  await (await waitText(driver, key)).click()
  for (let attempt: number = 0; attempt < 80; attempt += 1) {
    if (connectNextNReaderBackendSelection().current() === backend) {
      await waitText(driver, key)
      return
    }
    await driver.delayMs(100)
  }
  throw new Error(`In-app Reader backend selection did not become ${backend}`)
}

export async function returnFromReaderSettings(driver: Driver): Promise<void> {
  await driver.pressBack()
  await waitId(driver, 'nextn-root-tab-2')
}

function pageTotal(text: string): number {
  const match = /^\s*([1-9][0-9]*)\s*\/\s*([1-9][0-9]*)\s*$/.exec(text)
  if (match === null) throw new Error(`Unexpected shared page label: ${text}`)
  return Number(match[2])
}

function pageCurrent(text: string): number {
  const match = /^\s*([1-9][0-9]*)\s*\/\s*([1-9][0-9]*)\s*$/.exec(text)
  if (match === null) throw new Error(`Unexpected shared page label: ${text}`)
  return Number(match[1]) - 1
}

async function waitSharedReady(driver: Driver): Promise<number> {
  for (let attempt: number = 0; attempt < 120; attempt += 1) {
    const surface = await driver.findComponent(ON.id('rkit-reading-surface'))
    const page = await driver.findComponent(ON.id('rkit-chrome-page'))
    const failure = await driver.findComponent(ON.id('^rkit-failure-page-[0-9]+$'))
    const loading = await driver.findComponent(ON.type('LoadingProgress').within(ON.id('rkit-reading-surface')))
    const image = await driver.findComponent(ON.type('Image').within(ON.id('rkit-reading-surface')))
    if (surface !== null && page !== null && image !== null && failure === null && loading === null &&
      await driver.findComponent(ON.id('legacy-reader-surface')) === null) {
      return pageTotal(await page.getText())
    }
    await driver.delayMs(250)
  }
  throw new Error('Shared Reader did not render the completed download')
}

async function closeSharedReader(driver: Driver): Promise<void> {
  let close = await driver.findComponent(ON.id('rkit-close'))
  if (close === null && await driver.findComponent(ON.id('rkit-reading-surface')) !== null) {
    const surface = await waitId(driver, 'rkit-reading-surface')
    const bounds = await surface.getBounds()
    await driver.click(Math.round((bounds.left + bounds.right) / 2), Math.round((bounds.top + bounds.bottom) / 2))
    close = await waitId(driver, 'rkit-close')
  }
  if (close !== null) await close.click()
  for (let attempt: number = 0; attempt < 80; attempt += 1) {
    if (await driver.findComponent(ON.id('reader-overlay-navigation')) === null) return
    await driver.delayMs(250)
  }
  throw new Error('Shared Reader did not return to Downloads')
}

async function exerciseSharedTouch(driver: Driver): Promise<void> {
  const surface: Component = await waitId(driver, 'rkit-reading-surface')
  const bounds = await surface.getBounds()
  await driver.click(Math.round((bounds.left + bounds.right) / 2), Math.round((bounds.top + bounds.bottom) / 2))
  await driver.delayMs(400)
  expect(await driver.findComponent(ON.id('rkit-reading-surface')) !== null).assertTrue()
}

async function waitLegacyReady(driver: Driver): Promise<Component> {
  for (let attempt: number = 0; attempt < 120; attempt += 1) {
    const legacy = await driver.findComponent(ON.id('legacy-reader-surface'))
    if (legacy !== null && await driver.findComponent(ON.id('rkit-reading-surface')) === null) return legacy
    await driver.delayMs(250)
  }
  throw new Error('Legacy Reader did not open from the normal completed-download entry')
}

async function exerciseLegacyTouchAndClose(driver: Driver): Promise<void> {
  const legacy: Component = await waitLegacyReady(driver)
  const bounds = await legacy.getBounds()
  await driver.click(Math.round((bounds.left + bounds.right) / 2), Math.round((bounds.top + bounds.bottom) / 2))
  await driver.delayMs(500)
  expect(await driver.findComponent(ON.id('legacy-reader-surface')) !== null).assertTrue()
  await driver.pressBack()
  for (let attempt: number = 0; attempt < 80; attempt += 1) {
    if (await driver.findComponent(ON.id('reader-overlay-navigation')) === null) return
    await driver.delayMs(250)
  }
  throw new Error('Legacy Reader did not return to Downloads')
}

async function shareCurrentPageAndCancel(driver: Driver, expectedTotal: number): Promise<void> {
  const share: Component = await waitId(driver, 'rkit-share-image')
  expect(await share.isEnabled()).assertTrue()
  await share.click()
  await driver.delayMs(2500)
  await capture(driver, 'share-panel')
  expect(await (await waitId(driver, 'rkit-share-image')).isEnabled()).assertFalse()
  await driver.triggerKey(KeyCode.KEYCODE_BACK)
  for (let attempt: number = 0; attempt < 40; attempt += 1) {
    const current = await driver.findComponent(ON.id('rkit-share-image'))
    if (current !== null && await current.isEnabled()) {
      expect(pageTotal(await (await waitId(driver, 'rkit-chrome-page')).getText())).assertEqual(expectedTotal)
      await capture(driver, 'shared-after-share')
      return
    }
    await driver.delayMs(250)
  }
  throw new Error('Reader share action did not recover after system-sheet cancellation')
}

async function reloadCurrentLocalPage(driver: Driver, expectedTotal: number, captureName: string): Promise<void> {
  let more = await driver.findComponent(ON.id('rkit-more'))
  if (more === null) {
    const surface: Component = await waitId(driver, 'rkit-reading-surface')
    const bounds = await surface.getBounds()
    await driver.click(Math.round((bounds.left + bounds.right) / 2), Math.round((bounds.top + bounds.bottom) / 2))
    more = await waitId(driver, 'rkit-more')
  }
  await more.click()
  const reload: Component = await waitId(driver, 'rkit-reload-source')
  expect(await reload.isEnabled()).assertTrue()
  await reload.click()
  expect(await waitSharedReady(driver)).assertEqual(expectedTotal)
  await driver.delayMs(1200)
  expect(pageTotal(await (await waitId(driver, 'rkit-chrome-page')).getText())).assertEqual(expectedTotal)
  await capture(driver, captureName)
}

async function waitSpreadLocalReady(driver: Driver, expectedTotal: number): Promise<number[]> {
  for (let attempt: number = 0; attempt < 120; attempt += 1) {
    const page = await driver.findComponent(ON.id('rkit-chrome-page'))
    const images = await driver.findComponents(ON.type('Image').within(ON.id('rkit-image-viewport')))
    const parts = await driver.findComponents(
      ON.id('^rkit-part-[0-9]+-whole$', MatchPattern.REG_EXP).within(ON.id('rkit-image-viewport')),
    )
    const loading = await driver.findComponent(ON.type('LoadingProgress').within(ON.id('rkit-image-viewport')))
    const failure = await driver.findComponent(ON.id('^rkit-failure-page-[0-9]+$', MatchPattern.REG_EXP))
    if (page !== null && images.length === 2 && parts.length === 2 && loading === null && failure === null &&
      await driver.findComponent(ON.id('rkit-native-pager')) !== null &&
      await driver.findComponent(ON.id('legacy-reader-surface')) === null) {
      expect(pageTotal(await page.getText())).assertEqual(expectedTotal)
      const sources: number[] = []
      for (const part of parts) {
        const id: string = await part.getId()
        const match = /^rkit-part-([0-9]+)-whole$/.exec(id)
        if (match === null) throw new Error(`Unexpected spread part id: ${id}`)
        sources.push(Number(match[1]))
      }
      sources.sort((left: number, right: number): number => left - right)
      return sources
    }
    await driver.delayMs(250)
  }
  throw new Error('Shared local split spread did not settle with two source images')
}

async function reloadSpreadLocalSource(driver: Driver, sourceIndex: number,
  expectedSources: number[], expectedTotal: number, captureName: string): Promise<void> {
  let more = await driver.findComponent(ON.id('rkit-more'))
  if (more === null) {
    const surface: Component = await waitId(driver, 'rkit-reading-surface')
    const bounds = await surface.getBounds()
    await driver.click(Math.round((bounds.left + bounds.right) / 2), Math.round((bounds.top + bounds.bottom) / 2))
    more = await waitId(driver, 'rkit-more')
  }
  await more.click()
  await (await waitId(driver, 'rkit-reload-source-spread')).click()
  const reload: Component = await waitId(driver, `rkit-reload-source-${sourceIndex}`)
  expect(await reload.isEnabled()).assertTrue()
  await reload.click()
  const sources: number[] = await waitSpreadLocalReady(driver, expectedTotal)
  expect(JSON.stringify(sources)).assertEqual(JSON.stringify(expectedSources))
  await driver.delayMs(1200)
  await capture(driver, captureName)
}

async function waitContinuousLocalReady(driver: Driver, expectedIndex: number): Promise<void> {
  const pageId: string = `rkit-continuous-page-${expectedIndex}`
  for (let attempt: number = 0; attempt < 120; attempt += 1) {
    const page = await driver.findComponent(ON.id(pageId))
    const image = await driver.findComponent(ON.type('Image').within(ON.id(pageId)))
    const loading = await driver.findComponent(ON.type('LoadingProgress').within(ON.id(pageId)))
    const failure = await driver.findComponent(ON.id(`rkit-failure-page-${expectedIndex + 1}`))
    if (page !== null && image !== null && loading === null && failure === null &&
      await driver.findComponent(ON.id('rkit-continuous-list')) !== null &&
      await driver.findComponent(ON.id('legacy-reader-surface')) === null) return
    await driver.delayMs(250)
  }
  throw new Error(`Shared continuous local page did not settle: ${expectedIndex}`)
}

async function reloadCurrentContinuousLocalPage(driver: Driver, expectedIndex: number,
  expectedTotal: number, captureName: string): Promise<void> {
  let more = await driver.findComponent(ON.id('rkit-more'))
  if (more === null) {
    const surface: Component = await waitId(driver, 'rkit-reading-surface')
    const bounds = await surface.getBounds()
    await driver.click(Math.round((bounds.left + bounds.right) / 2), Math.round((bounds.top + bounds.bottom) / 2))
    more = await waitId(driver, 'rkit-more')
  }
  await more.click()
  const reload: Component = await waitId(driver, 'rkit-reload-source')
  expect(await reload.isEnabled()).assertTrue()
  await reload.click()
  await waitContinuousLocalReady(driver, expectedIndex)
  await driver.delayMs(1200)
  const label: string = await (await waitId(driver, 'rkit-chrome-page')).getText()
  expect(pageCurrent(label)).assertEqual(expectedIndex)
  expect(pageTotal(label)).assertEqual(expectedTotal)
  await capture(driver, captureName)
}

async function capture(driver: Driver, name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  const cache: string = delegator.getAppContext().cacheDir
  expect((await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/${CAPTURE_PREFIX}-${name}.json -a`, 15)).exitCode).assertEqual(0)
  expect(await driver.screenCap(`${cache}/${CAPTURE_PREFIX}-${name}.png`)).assertTrue()
}

export default function readerProductionDownloadEntryTrialTest(): void {
  const selectedClass = abilityDelegatorRegistry.getArguments().parameters['-s class']
  if (selectedClass === 'ReaderProductionInAppBackendRehearsalTrial') describe(selectedClass, (): void => {
    it('selectsSharedAndRestoresLegacyThroughNormalInAppEntries', 0, async (): Promise<void> => {
      const driver = Driver.create()
      let database: relationalStore.RdbStore | null = null
      let original: HistorySnapshot | null = null
      let restored: boolean = false
      let failed: boolean = false
      try {
        await startNormalHost()
        const context: common.UIAbilityContext = await entryContext(driver)
        expect(connectNextNReaderBackendSelection().current()).assertEqual(NextNReaderBackend.LEGACY)
        await DownloadQueueService.restore(context)
        const queueBefore: string = JSON.stringify(DownloadQueueService.snapshot())
        const complete: NhDownloadTask[] = DownloadQueueService.snapshot()
          .filter((task: NhDownloadTask): boolean => task.isComplete())
          .sort((left: NhDownloadTask, right: NhDownloadTask): number => right.createdAt - left.createdAt)
        if (complete.length === 0) throw new Error('A verified complete download is required')
        const task: NhDownloadTask = complete[0]
        database = await store(context)
        original = await snapshotHistory(database, task.galleryId)
        writeSnapshot(original)

        await openBackendRehearsal(driver)
        await waitText(driver, 'settings_reader_backend_legacy')
        await capture(driver, 'in-app-backend-legacy-setting')
        await selectBackendFromUi(driver, NextNReaderBackend.SHARED)
        await capture(driver, 'in-app-backend-shared-setting')
        await returnFromReaderSettings(driver)
        await (await waitId(driver, 'nextn-root-tab-2')).click()
        await (await findDownloadEntry(driver, task.galleryId)).click()
        const total: number = await waitSharedReady(driver)
        expect(total).assertEqual(task.pageCount)
        await exerciseSharedTouch(driver)
        await capture(driver, 'in-app-backend-shared-reader')
        await closeSharedReader(driver)
        await waitId(driver, 'nextn-download-queue-root')
        await capture(driver, 'in-app-backend-shared-return')

        await openBackendRehearsal(driver)
        expect(connectNextNReaderBackendSelection().current()).assertEqual(NextNReaderBackend.SHARED)
        await selectBackendFromUi(driver, NextNReaderBackend.LEGACY)
        await capture(driver, 'in-app-backend-legacy-restored-setting')
        await returnFromReaderSettings(driver)
        await (await waitId(driver, 'nextn-root-tab-2')).click()
        await (await findDownloadEntry(driver, task.galleryId)).click()
        await waitLegacyReady(driver)
        await capture(driver, 'in-app-backend-legacy-reader')
        await exerciseLegacyTouchAndClose(driver)
        await waitId(driver, 'nextn-download-queue-root')
        expect(JSON.stringify(DownloadQueueService.snapshot())).assertEqual(queueBefore)
        await restoreAndVerify(database, original)
        restored = true
        removeSnapshot()
        await capture(driver, 'in-app-backend-legacy-return')
        console.info(`[ReaderProductionInAppBackendRehearsalTrial] gallery=${task.galleryId} pages=${task.pageCount} ` +
          'initial=legacy sharedSelectedInApp=true sharedTouch=true sharedReturned=true ' +
          'legacySelectedInApp=true legacyTouch=true legacyReturned=true queueUnchanged=true historyRestored=true')
      } catch (error) {
        failed = true
        try { await capture(driver, 'in-app-backend-exception') } catch (_) {}
        throw error as Error
      } finally {
        try { await closeSharedReader(driver) } catch (error) { if (!failed) throw error as Error }
        try {
          if (await driver.findComponent(ON.id('legacy-reader-surface')) !== null) await driver.pressBack()
        } catch (error) { if (!failed) throw error as Error }
        if (!restored && database !== null && original !== null) {
          await restoreAndVerify(database, original)
          removeSnapshot()
        }
        await startLegacyBackend()
      }
    })
  })
  if (selectedClass === 'ReaderProductionDownloadEntryTrial') describe(selectedClass, (): void => {
    it('opensCompleteDownloadThroughSharedProductionBodyAndReturns', 0, async (): Promise<void> => {
      const driver = Driver.create()
      let database: relationalStore.RdbStore | null = null
      let original: HistorySnapshot | null = null
      let restored: boolean = false
      let failed: boolean = false
      try {
        await startSharedBackend()
        const context: common.UIAbilityContext = await entryContext(driver)
        await DownloadQueueService.restore(context)
        const queueBefore: string = JSON.stringify(DownloadQueueService.snapshot())
        const complete: NhDownloadTask[] = DownloadQueueService.snapshot()
          .filter((task: NhDownloadTask): boolean => task.isComplete())
          .sort((left: NhDownloadTask, right: NhDownloadTask): number => right.createdAt - left.createdAt)
        if (complete.length === 0) throw new Error('A verified complete download is required')
        const task: NhDownloadTask = complete[0]
        database = await store(context)
        original = await snapshotHistory(database, task.galleryId)
        writeSnapshot(original)

        await (await waitId(driver, 'nextn-root-tab-2')).click()
        const entry: Component = await findDownloadEntry(driver, task.galleryId)
        await capture(driver, 'downloads-before')
        await entry.click()
        const total: number = await waitSharedReady(driver)
        expect(total).assertEqual(task.pageCount)
        await capture(driver, 'shared-local')
        await shareCurrentPageAndCancel(driver, total)

        await closeSharedReader(driver)
        await waitId(driver, 'nextn-download-queue-root')
        expect(JSON.stringify(DownloadQueueService.snapshot())).assertEqual(queueBefore)
        await capture(driver, 'downloads-return')

        await restoreAndVerify(database, original)
        restored = true
        removeSnapshot()
        console.info(`[ReaderProductionDownloadEntryTrial] gallery=${task.galleryId} pages=${total} ` +
          'shared=true localShareCancelled=true localQueueUnchanged=true returned=true historyRestored=true')
      } catch (error) {
        failed = true
        try { await capture(driver, 'exception') } catch (_) {}
        throw error as Error
      } finally {
        try { await closeSharedReader(driver) } catch (error) { if (!failed) throw error as Error }
        if (!restored && database !== null && original !== null) {
          await restoreAndVerify(database, original)
          removeSnapshot()
        }
        await startLegacyBackend()
      }
    })
  })
  if (selectedClass === 'ReaderProductionDownloadReloadTrial') describe(selectedClass, (): void => {
    it('reloadsCompleteLocalDownloadTwiceWithoutMutatingQueue', 0, async (): Promise<void> => {
      const driver = Driver.create()
      let database: relationalStore.RdbStore | null = null
      let original: HistorySnapshot | null = null
      let restored: boolean = false
      let failed: boolean = false
      try {
        await startSharedBackend()
        const context: common.UIAbilityContext = await entryContext(driver)
        await DownloadQueueService.restore(context)
        const queueBefore: string = JSON.stringify(DownloadQueueService.snapshot())
        const complete: NhDownloadTask[] = DownloadQueueService.snapshot()
          .filter((task: NhDownloadTask): boolean => task.isComplete())
          .sort((left: NhDownloadTask, right: NhDownloadTask): number => right.createdAt - left.createdAt)
        if (complete.length === 0) throw new Error('A verified complete download is required')
        const task: NhDownloadTask = complete[0]
        database = await store(context)
        original = await snapshotHistory(database, task.galleryId)
        writeSnapshot(original)

        await (await waitId(driver, 'nextn-root-tab-2')).click()
        await (await findDownloadEntry(driver, task.galleryId)).click()
        const total: number = await waitSharedReady(driver)
        expect(total).assertEqual(task.pageCount)
        await capture(driver, 'local-reload-initial')
        await reloadCurrentLocalPage(driver, total, 'local-reload-first')
        await reloadCurrentLocalPage(driver, total, 'local-reload-second')

        await closeSharedReader(driver)
        await waitId(driver, 'nextn-download-queue-root')
        expect(JSON.stringify(DownloadQueueService.snapshot())).assertEqual(queueBefore)
        await capture(driver, 'local-reload-return')

        await restoreAndVerify(database, original)
        restored = true
        removeSnapshot()
        console.info(`[ReaderProductionDownloadReloadTrial] gallery=${task.galleryId} pages=${total} ` +
          'localReloads=2 queueUnchanged=true returned=true historyRestored=true')
      } catch (error) {
        failed = true
        try { await capture(driver, 'local-reload-exception') } catch (_) {}
        throw error as Error
      } finally {
        try { await closeSharedReader(driver) } catch (error) { if (!failed) throw error as Error }
        if (!restored && database !== null && original !== null) {
          await restoreAndVerify(database, original)
          removeSnapshot()
        }
        await startLegacyBackend()
      }
    })
  })
  if (selectedClass === 'ReaderProductionDownloadSpreadReloadTrial') describe(selectedClass, (): void => {
    it('reloadsBothCompleteLocalSpreadSourcesWithoutMutatingQueue', 0, async (): Promise<void> => {
      const driver = Driver.create()
      let context: common.UIAbilityContext | null = null
      let database: relationalStore.RdbStore | null = null
      let originalHistory: HistorySnapshot | null = null
      let originalMode: NhReaderMode = NhReaderMode.PAGED
      let originalDouble: boolean = false
      let originalSpread: NhReaderSpreadLayout = NhReaderSpreadLayout.JOINED
      let modeSetting: SettingSnapshot | null = null
      let doubleSetting: SettingSnapshot | null = null
      let spreadSetting: SettingSnapshot | null = null
      let restored: boolean = false
      let failed: boolean = false
      try {
        await startSharedBackend()
        context = await entryContext(driver)
        await DownloadQueueService.restore(context)
        const queueBefore: string = JSON.stringify(DownloadQueueService.snapshot())
        const complete: NhDownloadTask[] = DownloadQueueService.snapshot()
          .filter((task: NhDownloadTask): boolean => task.isComplete() && task.pageCount >= 4)
          .sort((left: NhDownloadTask, right: NhDownloadTask): number => right.createdAt - left.createdAt)
        if (complete.length === 0) throw new Error('A verified complete multi-page download is required')
        const task: NhDownloadTask = complete[0]
        database = await store(context)
        originalHistory = await snapshotHistory(database, task.galleryId)
        writeSnapshot(originalHistory)
        await ReaderPresentationService.restore(context)
        const original = ReaderPresentationService.snapshot()
        originalMode = original.mode
        originalDouble = original.doublePageEnabled
        originalSpread = original.spreadLayoutMode
        modeSetting = new SettingSnapshot('reader_mode', await settingValue(database, 'reader_mode'))
        doubleSetting = new SettingSnapshot('reader_double_page_enabled',
          await settingValue(database, 'reader_double_page_enabled'))
        spreadSetting = new SettingSnapshot('reader_spread_layout', await settingValue(database, 'reader_spread_layout'))
        await ReaderPresentationService.setMode(context, NhReaderMode.PAGED_RTL)
        await ReaderPresentationService.setDoublePageEnabled(context, true)
        await ReaderPresentationService.setSpreadLayout(context, NhReaderSpreadLayout.SPLIT)
        connectReaderPresentation().mode = NhReaderMode.PAGED_RTL
        connectReaderPresentation().doublePageEnabled = true
        connectReaderPresentation().spreadLayoutMode = NhReaderSpreadLayout.SPLIT

        await (await waitId(driver, 'nextn-root-tab-2')).click()
        await (await findDownloadEntry(driver, task.galleryId)).click()
        const label: string = await (await waitId(driver, 'rkit-chrome-page', 120)).getText()
        const total: number = pageTotal(label)
        expect(total).assertEqual(task.pageCount)
        const sources: number[] = await waitSpreadLocalReady(driver, total)
        await capture(driver, 'spread-local-reload-initial')
        await reloadSpreadLocalSource(driver, sources[0], sources, total, 'spread-local-reload-first')
        await reloadSpreadLocalSource(driver, sources[1], sources, total, 'spread-local-reload-second')

        await closeSharedReader(driver)
        await waitId(driver, 'nextn-download-queue-root')
        expect(JSON.stringify(DownloadQueueService.snapshot())).assertEqual(queueBefore)
        await restoreAndVerify(database, originalHistory)
        await ReaderPresentationService.setMode(context, originalMode)
        await ReaderPresentationService.setDoublePageEnabled(context, originalDouble)
        await ReaderPresentationService.setSpreadLayout(context, originalSpread)
        await restoreSetting(database, modeSetting)
        await restoreSetting(database, doubleSetting)
        await restoreSetting(database, spreadSetting)
        connectReaderPresentation().mode = originalMode
        connectReaderPresentation().doublePageEnabled = originalDouble
        connectReaderPresentation().spreadLayoutMode = originalSpread
        restored = true
        removeSnapshot()
        await capture(driver, 'spread-local-reload-return')
        console.info(`[ReaderProductionDownloadSpreadReloadTrial] gallery=${task.galleryId} pages=${total} ` +
          `sources=${sources.join(',')} localReloads=2 queueUnchanged=true historyRestored=true settingsRestored=true`)
      } catch (error) {
        failed = true
        try { await capture(driver, 'spread-local-reload-exception') } catch (_) {}
        throw error as Error
      } finally {
        try { await closeSharedReader(driver) } catch (error) { if (!failed) throw error as Error }
        if (!restored && context !== null && database !== null && originalHistory !== null &&
          modeSetting !== null && doubleSetting !== null && spreadSetting !== null) {
          await restoreAndVerify(database, originalHistory)
          await ReaderPresentationService.setMode(context, originalMode)
          await ReaderPresentationService.setDoublePageEnabled(context, originalDouble)
          await ReaderPresentationService.setSpreadLayout(context, originalSpread)
          await restoreSetting(database, modeSetting)
          await restoreSetting(database, doubleSetting)
          await restoreSetting(database, spreadSetting)
          connectReaderPresentation().mode = originalMode
          connectReaderPresentation().doublePageEnabled = originalDouble
          connectReaderPresentation().spreadLayoutMode = originalSpread
          removeSnapshot()
        }
        await startLegacyBackend()
      }
    })
  })
  if (selectedClass === 'ReaderProductionDownloadContinuousReloadTrial') describe(selectedClass, (): void => {
    it('reloadsCompleteLocalDownloadTwiceInContinuousMode', 0, async (): Promise<void> => {
      const driver = Driver.create()
      let context: common.UIAbilityContext | null = null
      let database: relationalStore.RdbStore | null = null
      let originalHistory: HistorySnapshot | null = null
      let originalMode: NhReaderMode = NhReaderMode.PAGED
      let modeSetting: SettingSnapshot | null = null
      let restored: boolean = false
      let failed: boolean = false
      try {
        await startSharedBackend()
        context = await entryContext(driver)
        await DownloadQueueService.restore(context)
        const queueBefore: string = JSON.stringify(DownloadQueueService.snapshot())
        const complete: NhDownloadTask[] = DownloadQueueService.snapshot()
          .filter((task: NhDownloadTask): boolean => task.isComplete())
          .sort((left: NhDownloadTask, right: NhDownloadTask): number => right.createdAt - left.createdAt)
        if (complete.length === 0) throw new Error('A verified complete download is required')
        const task: NhDownloadTask = complete[0]
        database = await store(context)
        originalHistory = await snapshotHistory(database, task.galleryId)
        writeSnapshot(originalHistory)
        await ReaderPresentationService.restore(context)
        originalMode = ReaderPresentationService.snapshot().mode
        modeSetting = new SettingSnapshot('reader_mode', await settingValue(database, 'reader_mode'))
        await ReaderPresentationService.setMode(context, NhReaderMode.VERTICAL)
        connectReaderPresentation().mode = NhReaderMode.VERTICAL

        await (await waitId(driver, 'nextn-root-tab-2')).click()
        await (await findDownloadEntry(driver, task.galleryId)).click()
        const label: string = await (await waitId(driver, 'rkit-chrome-page', 120)).getText()
        const current: number = pageCurrent(label)
        const total: number = pageTotal(label)
        expect(total).assertEqual(task.pageCount)
        await waitContinuousLocalReady(driver, current)
        await capture(driver, 'continuous-local-reload-initial')
        await reloadCurrentContinuousLocalPage(driver, current, total, 'continuous-local-reload-first')
        await reloadCurrentContinuousLocalPage(driver, current, total, 'continuous-local-reload-second')

        await closeSharedReader(driver)
        await waitId(driver, 'nextn-download-queue-root')
        expect(JSON.stringify(DownloadQueueService.snapshot())).assertEqual(queueBefore)
        await restoreAndVerify(database, originalHistory)
        await ReaderPresentationService.setMode(context, originalMode)
        await restoreSetting(database, modeSetting)
        connectReaderPresentation().mode = originalMode
        restored = true
        removeSnapshot()
        await capture(driver, 'continuous-local-reload-return')
        console.info(`[ReaderProductionDownloadContinuousReloadTrial] gallery=${task.galleryId} pages=${total} ` +
          `page=${current + 1} localReloads=2 queueUnchanged=true historyRestored=true modeRestored=true`)
      } catch (error) {
        failed = true
        try { await capture(driver, 'continuous-local-reload-exception') } catch (_) {}
        throw error as Error
      } finally {
        try { await closeSharedReader(driver) } catch (error) { if (!failed) throw error as Error }
        if (!restored && context !== null && database !== null && originalHistory !== null && modeSetting !== null) {
          await restoreAndVerify(database, originalHistory)
          await ReaderPresentationService.setMode(context, originalMode)
          await restoreSetting(database, modeSetting)
          connectReaderPresentation().mode = originalMode
          removeSnapshot()
        }
        await startLegacyBackend()
      }
    })
  })
  if (selectedClass === 'ReaderProductionDownloadEntryCleanupTrial') describe(selectedClass, (): void => {
    it('restoresInterruptedDownloadEntryHistoryAndLegacyBackend', 0, async (): Promise<void> => {
      await startLegacyBackend()
      if (!fileIo.accessSync(snapshotPath())) {
        console.info('[ReaderProductionDownloadEntryTrial] cleanup snapshotAbsent=true backend=legacy')
        return
      }
      const driver = Driver.create()
      const context: common.UIAbilityContext = await entryContext(driver)
      const database: relationalStore.RdbStore = await store(context)
      const original: HistorySnapshot = readSnapshot()
      await restoreAndVerify(database, original)
      removeSnapshot()
      console.info('[ReaderProductionDownloadEntryTrial] cleanup restored=true backend=legacy')
    })
  })
}
