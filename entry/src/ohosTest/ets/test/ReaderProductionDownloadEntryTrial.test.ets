import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { fileIo } from '@kit.CoreFileKit'
import { DownloadQueueService, NhDownloadTask } from 'shared'

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

async function entryContext(driver: Driver): Promise<common.UIAbilityContext> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  for (let attempt: number = 0; attempt < 80; attempt += 1) {
    const ability = await delegator.getCurrentTopAbility()
    if (ability.context.abilityInfo.name === 'EntryAbility') return ability.context
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

function pageTotal(text: string): number {
  const match = /^\s*([1-9][0-9]*)\s*\/\s*([1-9][0-9]*)\s*$/.exec(text)
  if (match === null) throw new Error(`Unexpected shared page label: ${text}`)
  return Number(match[2])
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

async function capture(driver: Driver, name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  const cache: string = delegator.getAppContext().cacheDir
  expect((await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/${CAPTURE_PREFIX}-${name}.json -a`, 15)).exitCode).assertEqual(0)
  expect(await driver.screenCap(`${cache}/${CAPTURE_PREFIX}-${name}.png`)).assertTrue()
}

export default function readerProductionDownloadEntryTrialTest(): void {
  const selectedClass = abilityDelegatorRegistry.getArguments().parameters['-s class']
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

        await closeSharedReader(driver)
        await waitId(driver, 'nextn-download-queue-root')
        expect(JSON.stringify(DownloadQueueService.snapshot())).assertEqual(queueBefore)
        await capture(driver, 'downloads-return')

        await restoreAndVerify(database, original)
        restored = true
        removeSnapshot()
        console.info(`[ReaderProductionDownloadEntryTrial] gallery=${task.galleryId} pages=${total} ` +
          'shared=true localQueueUnchanged=true returned=true historyRestored=true')
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
