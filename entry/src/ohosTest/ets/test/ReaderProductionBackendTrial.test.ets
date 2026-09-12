import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { fileIo } from '@kit.CoreFileKit'
import { connectNhReadProgress } from 'shared'

const GALLERY_ID: number = 678049
const SNAPSHOT_FILE: string = 'reader-production-backend-history.json'
const CAPTURE_PREFIX: string = 'reader-production-backend'

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

function snapshotPath(): string {
  return `${abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir}/${SNAPSHOT_FILE}`
}

function writeSnapshot(value: HistorySnapshot): void {
  const file = fileIo.openSync(snapshotPath(),
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
  try { fileIo.writeSync(file.fd, JSON.stringify(value)) } finally { fileIo.closeSync(file) }
}

function readSnapshot(): HistorySnapshot {
  const path = snapshotPath()
  if (!fileIo.accessSync(path)) throw new Error('Production backend history snapshot unavailable')
  return JSON.parse(fileIo.readTextSync(path)) as HistorySnapshot
}

function removeSnapshot(): void {
  const path = snapshotPath()
  if (fileIo.accessSync(path)) fileIo.unlinkSync(path)
}

async function entryContext(driver: Driver): Promise<common.UIAbilityContext> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  for (let attempt = 0; attempt < 80; attempt++) {
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

async function restoreHistory(database: relationalStore.RdbStore, value: HistorySnapshot): Promise<void> {
  if (!value.present) {
    await database.executeSql('DELETE FROM reading_history WHERE gallery_id=?', [GALLERY_ID])
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
  expect(JSON.stringify(await snapshotHistory(database))).assertEqual(JSON.stringify(value))
}

async function seedFirstPage(database: relationalStore.RdbStore): Promise<void> {
  const current = await snapshotHistory(database)
  if (current.present) {
    await database.executeSql(
      'UPDATE reading_history SET last_read_index=0,has_read_progress=1 WHERE gallery_id=?', [GALLERY_ID])
  } else {
    await database.executeSql(
      'INSERT INTO reading_history ' +
        '(gallery_id,media_id,title,thumbnail_url,page_count,last_read_index,has_read_progress,last_opened_at) ' +
        'VALUES (?,?,?,?,?,0,1,?)', [GALLERY_ID, '', '', '', 14, Date.now()])
  }
  connectNhReadProgress().set(GALLERY_ID, 0)
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

async function waitId(driver: Driver, id: string, attempts: number = 80): Promise<Component> {
  for (let attempt = 0; attempt < attempts; attempt++) {
    const component = await driver.findComponent(ON.id(id))
    if (component !== null) return component
    await driver.delayMs(250)
  }
  throw new Error(`Production backend component unavailable: ${id}`)
}

async function waitDetailRead(driver: Driver): Promise<Component> {
  for (let attempt = 0; attempt < 120; attempt++) {
    if (await driver.findComponent(ON.id('reader-overlay-navigation')) === null) {
      const action = await driver.findComponent(ON.id('gallery-detail-read-action'))
      if (action !== null) return action
    }
    await driver.delayMs(250)
  }
  throw new Error('Ready Detail Read action unavailable')
}

function pageIndex(text: string): number {
  const match = /^\s*([1-9][0-9]*)\s*\/\s*([1-9][0-9]*)\s*$/.exec(text)
  if (match === null) throw new Error(`Unexpected shared page label: ${text}`)
  return Number(match[1]) - 1
}

async function waitSharedReady(driver: Driver): Promise<number> {
  for (let attempt = 0; attempt < 120; attempt++) {
    const surface = await driver.findComponent(ON.id('rkit-reading-surface'))
    const page = await driver.findComponent(ON.id('rkit-chrome-page'))
    const failure = await driver.findComponent(ON.id('^rkit-failure-page-[0-9]+$'))
    const loading = await driver.findComponent(ON.type('LoadingProgress').within(ON.id('rkit-reading-surface')))
    if (surface !== null && page !== null && failure === null && loading === null &&
      await driver.findComponent(ON.id('legacy-reader-surface')) === null) {
      return pageIndex(await page.getText())
    }
    await driver.delayMs(250)
  }
  throw new Error('Shared production Reader did not become ready')
}

async function waitDifferentSharedPage(driver: Driver, previous: number): Promise<number> {
  for (let attempt = 0; attempt < 80; attempt++) {
    const page = await driver.findComponent(ON.id('rkit-chrome-page'))
    if (page !== null) {
      const current = pageIndex(await page.getText())
      if (current !== previous) return current
    }
    await driver.delayMs(250)
  }
  throw new Error(`Shared production Reader did not leave page ${previous + 1}`)
}

async function waitHistory(database: relationalStore.RdbStore, expected: number): Promise<void> {
  for (let attempt = 0; attempt < 80; attempt++) {
    const current = await snapshotHistory(database)
    if (current.present && current.lastReadIndex === expected && current.hasReadProgress === 1) return
    await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 100) })
  }
  throw new Error(`Shared production progress unavailable: ${expected}`)
}

async function waitLegacyReady(driver: Driver): Promise<void> {
  for (let attempt = 0; attempt < 120; attempt++) {
    const legacy = await driver.findComponent(ON.id('legacy-reader-surface'))
    if (legacy !== null && await driver.findComponent(ON.id('rkit-reading-surface')) === null &&
      await driver.findComponent(ON.id('reader-overlay-navigation')) !== null) return
    await driver.delayMs(250)
  }
  throw new Error('Legacy Reader did not own the production destination')
}

async function capture(driver: Driver, name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  const cache = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir
  expect((await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/${CAPTURE_PREFIX}-${name}.json -a`, 15)).exitCode).assertEqual(0)
  expect(await driver.screenCap(`${cache}/${CAPTURE_PREFIX}-${name}.png`)).assertTrue()
}

async function closeAnyReader(driver: Driver): Promise<void> {
  const sharedClose = await driver.findComponent(ON.id('rkit-close'))
  if (sharedClose !== null) await sharedClose.click()
  else if (await driver.findComponent(ON.id('reader-overlay-navigation')) !== null) await driver.pressBack()
  for (let attempt = 0; attempt < 80; attempt++) {
    if (await driver.findComponent(ON.id('reader-overlay-navigation')) === null) return
    await driver.delayMs(250)
  }
  throw new Error('Production Reader did not close')
}

export default function readerProductionBackendTrialTest(): void {
  const selectedClass = abilityDelegatorRegistry.getArguments().parameters['-s class']
  if (selectedClass === 'ReaderProductionBackendTrial') {
    describe(selectedClass, (): void => {
      it('routesNormalReadThroughSharedBodyThenRollsBackToLegacyBody', 0, async (): Promise<void> => {
        const driver = Driver.create()
        let database: relationalStore.RdbStore | null = null
        let original: HistorySnapshot | null = null
        let restored = false
        let failed = false
        try {
          await launchBackend('shared', true)
          database = await store(await entryContext(driver))
          original = await snapshotHistory(database)
          writeSnapshot(original)
          await seedFirstPage(database)

          const sharedRead = await waitDetailRead(driver)
          await capture(driver, 'shared-detail')
          await sharedRead.click()
          const initial = await waitSharedReady(driver)
          expect(initial).assertEqual(0)
          expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
          await capture(driver, 'shared-initial')

          const slider = await waitId(driver, 'rkit-source-slider')
          await slider.click()
          const changed = await waitDifferentSharedPage(driver, initial)
          await waitHistory(database, changed)
          await capture(driver, 'shared-changed')
          await closeAnyReader(driver)
          await waitDetailRead(driver)
          await capture(driver, 'shared-closed')

          await launchBackend('legacy', false)
          const legacyRead = await waitDetailRead(driver)
          await legacyRead.click()
          await waitLegacyReady(driver)
          await capture(driver, 'legacy-reopened')
          await closeAnyReader(driver)
          await waitDetailRead(driver)
          await capture(driver, 'legacy-closed')

          await restoreAndVerify(database, original)
          restored = true
          removeSnapshot()
          console.info(`[ReaderProductionBackendTrial] sharedInitial=${initial} sharedChanged=${changed} ` +
            'sharedClosed=true legacyReopened=true legacyClosed=true historyRestored=true')
        } catch (error) {
          failed = true
          try { await capture(driver, 'exception') } catch (_) {}
          throw error as Error
        } finally {
          try { await closeAnyReader(driver) } catch (error) { if (!failed) throw error as Error }
          if (!restored && database !== null && original !== null) {
            await restoreAndVerify(database, original)
            removeSnapshot()
          }
          await launchBackend('legacy', false)
        }
      })
    })
    return
  }

  if (selectedClass === 'ReaderProductionBackendCleanupTrial') {
    describe(selectedClass, (): void => {
      it('restoresInterruptedProductionBackendHistory', 0, async (): Promise<void> => {
        await launchBackend('legacy', false)
        if (!fileIo.accessSync(snapshotPath())) {
          console.info('[ReaderProductionBackendTrial] cleanup snapshotAbsent=true backend=legacy')
          return
        }
        const driver = Driver.create()
        const database = await store(await entryContext(driver))
        const original = readSnapshot()
        await restoreAndVerify(database, original)
        removeSnapshot()
        console.info('[ReaderProductionBackendTrial] cleanup restored=true backend=legacy')
      })
    })
  }
}
