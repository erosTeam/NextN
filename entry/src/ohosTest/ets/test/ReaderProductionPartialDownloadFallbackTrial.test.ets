import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { fileIo } from '@kit.CoreFileKit'
import { ReaderCancellation } from '@reader-kit/core'
import { NextNProductionReaderDataSource } from 'reader'
import {
  DownloadQueueService,
  DownloadSettingsService,
  NhApiClient,
  NhDownloadSettings,
  NhDownloadTask,
  NhDownloadTaskStatus,
  NhGalleryDetail,
} from 'shared'

const GALLERY_ID: number = 678049
const SNAPSHOT_FILE: string = 'reader-production-partial-download-fallback.json'
const CAPTURE_PREFIX: string = 'reader-production-partial-download-fallback'

class HistorySnapshot {
  present: boolean = false
  galleryId: number = GALLERY_ID
  mediaId: string = ''
  title: string = ''
  thumbnailUrl: string = ''
  pageCount: number = 0
  lastReadIndex: number = 0
  hasReadProgress: number = 0
  lastOpenedAt: number = 0
}

class TrialSnapshot {
  galleryId: number = GALLERY_ID
  queueBefore: string = ''
  settings: NhDownloadSettings = new NhDownloadSettings()
  history: HistorySnapshot = new HistorySnapshot()
}

function snapshotPath(): string {
  return `${abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir}/${SNAPSHOT_FILE}`
}

function writeSnapshot(value: TrialSnapshot): void {
  const file = fileIo.openSync(snapshotPath(),
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
  try { fileIo.writeSync(file.fd, JSON.stringify(value)) } finally { fileIo.closeSync(file) }
}

function readSnapshot(): TrialSnapshot {
  const path: string = snapshotPath()
  if (!fileIo.accessSync(path)) throw new Error('Partial-download trial snapshot unavailable')
  const raw = JSON.parse(fileIo.readTextSync(path)) as TrialSnapshot
  const value = new TrialSnapshot()
  value.galleryId = raw.galleryId
  value.queueBefore = raw.queueBefore
  value.settings.maxConcurrentGalleries = raw.settings.maxConcurrentGalleries
  value.settings.maxConcurrentPages = raw.settings.maxConcurrentPages
  value.settings.retryCount = raw.settings.retryCount
  value.settings.notifyOnComplete = raw.settings.notifyOnComplete
  value.settings.hideFromMediaLibrary = raw.settings.hideFromMediaLibrary
  value.settings.requestIntervalSeconds = raw.settings.requestIntervalSeconds
  value.settings.autoRetryFailed = raw.settings.autoRetryFailed
  value.settings.speedLimitKbps = raw.settings.speedLimitKbps
  value.history.present = raw.history.present
  value.history.galleryId = raw.history.galleryId
  value.history.mediaId = raw.history.mediaId
  value.history.title = raw.history.title
  value.history.thumbnailUrl = raw.history.thumbnailUrl
  value.history.pageCount = raw.history.pageCount
  value.history.lastReadIndex = raw.history.lastReadIndex
  value.history.hasReadProgress = raw.history.hasReadProgress
  value.history.lastOpenedAt = raw.history.lastOpenedAt
  return value
}

function removeSnapshot(): void {
  const path: string = snapshotPath()
  if (fileIo.accessSync(path)) fileIo.unlinkSync(path)
}

async function launchBackend(backend: string, directGallery: boolean): Promise<void> {
  if (directGallery) {
    await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
      bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
      parameters: { nextn_reader_backend: backend, nextn_gallery_id: GALLERY_ID },
    })
    return
  }
  await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
    bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
    parameters: { nextn_reader_backend: backend },
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

async function snapshotHistory(database: relationalStore.RdbStore): Promise<HistorySnapshot> {
  const value = new HistorySnapshot()
  const row = await database.querySql(
    'SELECT gallery_id,media_id,title,thumbnail_url,page_count,last_read_index,has_read_progress,last_opened_at ' +
      'FROM reading_history WHERE gallery_id=? LIMIT 1', [GALLERY_ID])
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

async function seedFirstPage(database: relationalStore.RdbStore, detail: NhGalleryDetail): Promise<void> {
  await database.executeSql(
    'INSERT INTO reading_history ' +
      '(gallery_id,media_id,title,thumbnail_url,page_count,last_read_index,has_read_progress,last_opened_at) ' +
      'VALUES (?,?,?,?,?,0,1,?) ON CONFLICT(gallery_id) DO UPDATE SET ' +
      'media_id=excluded.media_id,title=excluded.title,thumbnail_url=excluded.thumbnail_url,' +
      'page_count=excluded.page_count,last_read_index=0,has_read_progress=1,last_opened_at=excluded.last_opened_at',
    [GALLERY_ID, detail.mediaId, detail.displayTitle(), detail.thumbnailUrl,
      detail.pages.length, Date.now()])
}

async function restoreHistory(database: relationalStore.RdbStore, value: HistorySnapshot): Promise<void> {
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
    [value.galleryId, value.mediaId, value.title, value.thumbnailUrl, value.pageCount,
      value.lastReadIndex, value.hasReadProgress, value.lastOpenedAt])
}

async function waitId(driver: Driver, id: string, attempts: number = 80): Promise<Component> {
  for (let attempt: number = 0; attempt < attempts; attempt += 1) {
    const component = await driver.findComponent(ON.id(id))
    if (component !== null) return component
    await driver.delayMs(250)
  }
  throw new Error(`Partial-download trial component unavailable: ${id}`)
}

async function waitDetailRead(driver: Driver): Promise<Component> {
  for (let attempt: number = 0; attempt < 120; attempt += 1) {
    if (await driver.findComponent(ON.id('reader-overlay-navigation')) === null) {
      const action = await driver.findComponent(ON.id('gallery-detail-read-action'))
      if (action !== null) return action
    }
    await driver.delayMs(250)
  }
  throw new Error('Ready Detail Read action unavailable')
}

async function waitPartialTask(driver: Driver, pageCount: number): Promise<NhDownloadTask> {
  for (let attempt: number = 0; attempt < 1200; attempt += 1) {
    const task = DownloadQueueService.snapshot().find(
      (candidate: NhDownloadTask): boolean => candidate.galleryId === GALLERY_ID,
    )
    if (task !== undefined) {
      if (task.isComplete()) throw new Error('Trial download completed before a partial checkpoint')
      if (task.completedPages > 0 && task.completedPages < pageCount) {
        await DownloadQueueService.pause(await entryContext(driver), GALLERY_ID)
        await driver.delayMs(750)
        const paused = DownloadQueueService.snapshot().find(
          (candidate: NhDownloadTask): boolean => candidate.galleryId === GALLERY_ID,
        )
        if (paused !== undefined && paused.status === NhDownloadTaskStatus.PAUSED &&
          paused.completedPages > 0 && paused.completedPages < pageCount) return paused
      }
    }
    await driver.delayMs(100)
  }
  throw new Error('A verified partial download was not produced before timeout')
}

function firstCompletedPath(task: NhDownloadTask): string {
  if (task.completedPageIndexes.length === 0) return ''
  const index: number = task.completedPageIndexes[0]
  if (index < 0 || index >= task.pageExtensions.length) return ''
  return `${task.storageDirectory}/${index + 1}.${task.pageExtensions[index]}`
}

function pageTotal(text: string): number {
  const match = /^\s*([1-9][0-9]*)\s*\/\s*([1-9][0-9]*)\s*$/.exec(text)
  if (match === null) throw new Error(`Unexpected shared page label: ${text}`)
  return Number(match[2])
}

async function waitSharedReady(driver: Driver): Promise<number> {
  for (let attempt: number = 0; attempt < 160; attempt += 1) {
    const surface = await driver.findComponent(ON.id('rkit-reading-surface'))
    const page = await driver.findComponent(ON.id('rkit-chrome-page'))
    const failure = await driver.findComponent(ON.id('^rkit-failure-page-[0-9]+$'))
    const loading = await driver.findComponent(ON.type('LoadingProgress').within(ON.id('rkit-reading-surface')))
    const image = await driver.findComponent(ON.type('Image').within(ON.id('rkit-reading-surface')))
    if (surface !== null && page !== null && image !== null && failure === null && loading === null &&
      await driver.findComponent(ON.id('legacy-reader-surface')) === null) return pageTotal(await page.getText())
    await driver.delayMs(250)
  }
  throw new Error('Shared Reader did not render through partial-download fallback')
}

async function closeSharedReader(driver: Driver): Promise<void> {
  let close = await driver.findComponent(ON.id('rkit-close'))
  if (close === null && await driver.findComponent(ON.id('rkit-reading-surface')) !== null) {
    const bounds = await (await waitId(driver, 'rkit-reading-surface')).getBounds()
    await driver.click(Math.round((bounds.left + bounds.right) / 2), Math.round((bounds.top + bounds.bottom) / 2))
    close = await waitId(driver, 'rkit-close')
  }
  if (close !== null) await close.click()
  for (let attempt: number = 0; attempt < 80; attempt += 1) {
    if (await driver.findComponent(ON.id('reader-overlay-navigation')) === null) return
    await driver.delayMs(250)
  }
  throw new Error('Shared Reader did not return to Detail')
}

async function capture(driver: Driver, name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  const cache: string = delegator.getAppContext().cacheDir
  expect((await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/${CAPTURE_PREFIX}-${name}.json -a`, 15)).exitCode).assertEqual(0)
  expect(await driver.screenCap(`${cache}/${CAPTURE_PREFIX}-${name}.png`)).assertTrue()
}

async function restoreTrial(context: common.UIAbilityContext, database: relationalStore.RdbStore,
  snapshot: TrialSnapshot): Promise<void> {
  await DownloadQueueService.pause(context, snapshot.galleryId)
  await DownloadQueueService.remove(context, snapshot.galleryId)
  await DownloadSettingsService.save(context, snapshot.settings)
  await restoreHistory(database, snapshot.history)
  expect(JSON.stringify(DownloadQueueService.snapshot())).assertEqual(snapshot.queueBefore)
}

export default function readerProductionPartialDownloadFallbackTrialTest(): void {
  const selectedClass = abilityDelegatorRegistry.getArguments().parameters['-s class']
  if (selectedClass === 'ReaderProductionPartialDownloadFallbackTrial') describe(selectedClass, (): void => {
    it('rejectsPartialFilesAsLocalCatalogAndRendersThroughRouteSeed', 0, async (): Promise<void> => {
      const driver = Driver.create()
      let context: common.UIAbilityContext | null = null
      let database: relationalStore.RdbStore | null = null
      let snapshot: TrialSnapshot | null = null
      let restored: boolean = false
      let failed: boolean = false
      try {
        await launchBackend('shared', true)
        context = await entryContext(driver)
        await DownloadQueueService.restore(context)
        expect(DownloadQueueService.snapshot().some(
          (task: NhDownloadTask): boolean => task.galleryId === GALLERY_ID,
        )).assertFalse()
        expect(DownloadQueueService.snapshot().some(
          (task: NhDownloadTask): boolean => task.status === NhDownloadTaskStatus.QUEUED ||
            task.status === NhDownloadTaskStatus.DOWNLOADING,
        )).assertFalse()
        const detail: NhGalleryDetail = await NhApiClient.detail(GALLERY_ID)
        expect(detail.pages.length > 2).assertTrue()
        database = await store(context)
        snapshot = new TrialSnapshot()
        snapshot.queueBefore = JSON.stringify(DownloadQueueService.snapshot())
        snapshot.settings = DownloadSettingsService.snapshot()
        snapshot.history = await snapshotHistory(database)
        writeSnapshot(snapshot)
        await seedFirstPage(database, detail)

        const throttled: NhDownloadSettings = snapshot.settings.copy()
        throttled.maxConcurrentGalleries = 1
        throttled.maxConcurrentPages = 1
        throttled.retryCount = 0
        throttled.notifyOnComplete = false
        throttled.requestIntervalSeconds = 10
        throttled.autoRetryFailed = false
        throttled.speedLimitKbps = 256
        await DownloadSettingsService.save(context, throttled)
        await DownloadQueueService.enqueue(context, detail)
        const partial: NhDownloadTask = await waitPartialTask(driver, detail.pages.length)
        const completedPath: string = firstCompletedPath(partial)
        expect(completedPath.length > 0 && fileIo.accessSync(completedPath)).assertTrue()

        const source = new NextNProductionReaderDataSource(context, detail)
        const opened: NhGalleryDetail = await source.openDetail(GALLERY_ID, new ReaderCancellation())
        expect(opened.id).assertEqual(GALLERY_ID)
        expect(opened.pages.length).assertEqual(detail.pages.length)
        expect(source.localPageUri(opened, partial.completedPageIndexes[0])).assertEqual('')
        expect(await DownloadQueueService.localReaderDetail(context, GALLERY_ID)).assertNull()

        await capture(driver, 'detail-with-partial-task')
        await (await waitDetailRead(driver)).click()
        expect(await waitSharedReady(driver)).assertEqual(detail.pages.length)
        await capture(driver, 'shared-route-seed')
        await closeSharedReader(driver)
        await waitDetailRead(driver)
        await capture(driver, 'detail-returned')

        await restoreTrial(context, database, snapshot)
        restored = true
        removeSnapshot()
        console.info(`[ReaderProductionPartialDownloadFallbackTrial] gallery=${GALLERY_ID} ` +
          `partial=${partial.completedPages}/${partial.pageCount} physicalFile=true localCatalog=false ` +
          'localPageUriEmpty=true sharedRendered=true routeSeedFallback=true queueRestored=true ' +
          'settingsRestored=true historyRestored=true')
      } catch (error) {
        failed = true
        try { await capture(driver, 'exception') } catch (_) {}
        throw error as Error
      } finally {
        try { await closeSharedReader(driver) } catch (error) { if (!failed) throw error as Error }
        if (!restored && context !== null && database !== null && snapshot !== null) {
          await restoreTrial(context, database, snapshot)
          removeSnapshot()
        }
        await launchBackend('legacy', false)
      }
    })
  })

  if (selectedClass === 'ReaderProductionPartialDownloadFallbackCleanupTrial') describe(selectedClass, (): void => {
    it('removesInterruptedFixtureAndRestoresOwnedState', 0, async (): Promise<void> => {
      await launchBackend('legacy', false)
      if (!fileIo.accessSync(snapshotPath())) {
        console.info('[ReaderProductionPartialDownloadFallbackTrial] cleanup snapshotAbsent=true backend=legacy')
        return
      }
      const driver = Driver.create()
      const context: common.UIAbilityContext = await entryContext(driver)
      const database: relationalStore.RdbStore = await store(context)
      const snapshot: TrialSnapshot = readSnapshot()
      await DownloadQueueService.restore(context)
      await restoreTrial(context, database, snapshot)
      removeSnapshot()
      console.info('[ReaderProductionPartialDownloadFallbackTrial] cleanup restored=true backend=legacy')
    })
  })
}
