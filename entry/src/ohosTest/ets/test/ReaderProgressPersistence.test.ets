import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, MatchPattern, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { fileIo } from '@kit.CoreFileKit'
import { connectNextNReaderObservedProgressProbe } from 'reader'
import { connectNhReadProgress } from 'shared'

const GALLERY_ID: number = 678049
const WORK: string = '678049'
const SNAPSHOT_FILE: string = 'rkit-progress-persistence-original.json'

class HistoryRowSnapshot {
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

async function context(driver: Driver): Promise<common.UIAbilityContext> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
  for (let attempt = 0; attempt < 60; attempt++) {
    const ability = await delegator.getCurrentTopAbility()
    if (ability.context.abilityInfo.name === 'EntryAbility') {
      expect(ability.context.applicationInfo.name).assertEqual('com.erosteam.nextn')
      return ability.context
    }
    await driver.delayMs(100)
  }
  throw new Error('EntryAbility context unavailable')
}

async function store(ctx: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
  return relationalStore.getRdbStore(ctx,
    { name: 'NextN.db', securityLevel: relationalStore.SecurityLevel.S3, autoCleanDirtyData: true })
}

async function snapshotHistory(database: relationalStore.RdbStore): Promise<HistoryRowSnapshot> {
  const value = new HistoryRowSnapshot()
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

function snapshotPath(): string {
  return abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir + '/' + SNAPSHOT_FILE
}

function writeSnapshot(value: HistoryRowSnapshot): void {
  const path = snapshotPath()
  const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
  try { fileIo.writeSync(file.fd, JSON.stringify(value)) } finally { fileIo.closeSync(file) }
}

function readSnapshot(): HistoryRowSnapshot {
  const path = snapshotPath()
  if (!fileIo.accessSync(path)) throw new Error('progress persistence snapshot unavailable')
  const value = JSON.parse(fileIo.readTextSync(path)) as HistoryRowSnapshot
  if (value.galleryId !== GALLERY_ID) throw new Error('progress persistence snapshot gallery mismatch')
  return value
}

async function restoreSnapshot(database: relationalStore.RdbStore, value: HistoryRowSnapshot): Promise<void> {
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

async function restoreAndVerify(database: relationalStore.RdbStore, value: HistoryRowSnapshot): Promise<void> {
  await restoreSnapshot(database, value)
  expect(JSON.stringify(await snapshotHistory(database))).assertEqual(JSON.stringify(value))
}

async function waitId(driver: Driver, id: string): Promise<Component> {
  for (let attempt = 0; attempt < 60; attempt++) {
    const value = await driver.findComponent(ON.id(id))
    if (value !== null) return value
    await driver.delayMs(250)
  }
  throw new Error('Progress persistence component unavailable: ' + id)
}

async function waitBody(driver: Driver, pageIndex: number, continuous: boolean = false): Promise<Component> {
  const ownerId = continuous ? `rkit-continuous-page-${pageIndex}` : `rkit-part-${pageIndex}-whole`
  for (let attempt = 0; attempt < 60; attempt++) {
    const value = await driver.findComponent(ON.type('Image').within(ON.id(ownerId)))
    if (value !== null &&
      await driver.findComponent(ON.type('LoadingProgress').within(ON.id(ownerId))) === null) return value
    await driver.delayMs(250)
  }
  throw new Error('Progress persistence body unavailable: ' + pageIndex)
}

async function findDetailThumbnail(driver: Driver, pageIndex: number): Promise<Component> {
  let owner: Component | null = null
  for (let attempt = 0; attempt < 60; attempt++) {
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
    await driver.delayMs(250)
  }
  if (owner === null) throw new Error('Detail metadata List unavailable')
  const pattern = `^reader-thumb-gallery-detail-[0-9]+-page-${pageIndex}$`
  const selector = ON.id(pattern, MatchPattern.REG_EXP).within(ON.id('nextn-root-navigation'))
  const source = await owner.scrollSearch(selector, true)
  if (source === null) throw new Error('Detail thumbnail unavailable: ' + pageIndex)
  const matches = await driver.findComponents(selector)
  expect(matches.length).assertEqual(1)
  const sourceId = await source.getId()
  expect(new RegExp(pattern).test(sourceId)).assertTrue()
  return await driver.findComponent(ON.id(sourceId))
}

async function waitRetry(driver: Driver, pageIndex: number): Promise<Component> {
  const displayPage = pageIndex + 1
  for (let attempt = 0; attempt < 80; attempt++) {
    const retry = await driver.findComponent(
      ON.id(`rkit-retry-page-${displayPage}`).within(ON.id(`rkit-failure-page-${displayPage}`)))
    if (retry !== null && await retry.isEnabled() &&
      await driver.findComponent(ON.id('rkit-entry-preview-image')) === null) return retry
    await driver.delayMs(250)
  }
  throw new Error('Thumbnail progress retry unavailable: ' + displayPage)
}

async function waitObserved(driver: Driver, events: number[], pageIndex: number): Promise<void> {
  for (let attempt = 0; attempt < 60; attempt++) {
    if (events.length > 0 && events[events.length - 1] === pageIndex) return
    await driver.delayMs(100)
  }
  throw new Error('Progress persistence event unavailable: ' + pageIndex)
}

async function waitHistory(database: relationalStore.RdbStore, pageIndex: number): Promise<void> {
  for (let attempt = 0; attempt < 60; attempt++) {
    const value = await snapshotHistory(database)
    if (value.present && value.lastReadIndex === pageIndex && value.hasReadProgress === 1) return
    await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 100) })
  }
  throw new Error('Durable progress unavailable: ' + pageIndex)
}

async function capture(driver: Driver, name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  expect((await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/rkit-progress-persistence-${name}.json -a`, 15)).exitCode).assertEqual(0)
  expect(await driver.screenCap(delegator.getAppContext().cacheDir + `/rkit-progress-persistence-${name}.png`)).assertTrue()
}

async function closeTrial(driver: Driver): Promise<void> {
  const close = await driver.findComponent(ON.id('rkit-close'))
  if (close !== null) await close.click()
  else if (await driver.findComponent(ON.id('rkit-reading-surface')) !== null) await driver.pressBack()
  for (let attempt = 0; attempt < 60; attempt++) {
    if (await driver.findComponent(ON.id('rkit-reading-surface')) === null) return
    await driver.delayMs(250)
  }
  throw new Error('Progress persistence trial did not close')
}

async function launchReadWrite(layout: string = 'single', direction: string = 'ltr'): Promise<void> {
  await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
    bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility', parameters: {
      readerLabWork: WORK, readerLabProgressReadWrite: 'true', readerLabChrome: 'true', readerLabVolumeKeys: 'false',
      readerLabEntryLayout: layout, readerLabEntryDirection: direction,
    },
  })
}

async function swipePaged(driver: Driver, vertical: boolean, forward: boolean): Promise<void> {
  const bounds = await (await waitId(driver, 'rkit-image-viewport')).getBounds()
  const x = Math.round((bounds.left + bounds.right) / 2)
  const y = Math.round((bounds.top + bounds.bottom) / 2)
  const extent = vertical ? bounds.bottom - bounds.top : bounds.right - bounds.left
  const offset = Math.round(extent * 0.31) * (forward ? 1 : -1)
  await driver.swipe(vertical ? x : x + offset, vertical ? y + offset : y,
    vertical ? x : x - offset, vertical ? y - offset : y, 700)
  await driver.delayMs(700)
}

async function armThumbnailReadWrite(pageIndex: number, failurePage: number = pageIndex,
  layout: string = 'single', direction: string = 'ltr'): Promise<void> {
  await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
    bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility', parameters: {
      readerLabWork: WORK, readerLabProgressReadWrite: 'true', readerLabPage: '0', readerLabChrome: 'true',
      readerLabThumbnailEntry: 'true', readerLabVolumeKeys: 'false', readerLabEntryLayout: layout,
      readerLabEntryDirection: direction, readerLabFailPage: failurePage.toString(),
    },
  })
}

async function seedPage(database: relationalStore.RdbStore, pageIndex: number): Promise<void> {
  const current = await snapshotHistory(database)
  if (current.present) {
    await database.executeSql(
      'UPDATE reading_history SET last_read_index=?,has_read_progress=1 WHERE gallery_id=?', [pageIndex, GALLERY_ID])
  } else {
    // The restore contract must also work for a gallery with no prior history.
    // The first real visible-position save replaces these non-secret placeholders
    // with adapter metadata; cleanup deletes the row because the snapshot was absent.
    await database.executeSql(
      'INSERT INTO reading_history ' +
        '(gallery_id,media_id,title,thumbnail_url,page_count,last_read_index,has_read_progress,last_opened_at) ' +
        'VALUES (?,?,?,?,?,?,1,?)', [GALLERY_ID, '', '', '', 14, pageIndex, Date.now()])
  }
  await waitHistory(database, pageIndex)
}

function removeSnapshotFile(): void {
  const path = snapshotPath()
  if (fileIo.accessSync(path)) fileIo.unlinkSync(path)
}

export default function readerProgressPersistenceTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  const selectedClass = args['-s class']
  if (selectedClass === 'ReaderProgressPersistenceWriteTrial') {
    describe(selectedClass, (): void => {
      it('writesVisibleProgressAndLeavesColdRestoreHandoff', 0, async (): Promise<void> => {
        expect(args['-s readerLabWork']).assertEqual(WORK)
        const driver = Driver.create()
        const database = await store(await context(driver))
        const original = await snapshotHistory(database)
        writeSnapshot(original)
        let handoffReady = false
        const events: number[] = []
        const probe = connectNextNReaderObservedProgressProbe()
        const epoch = probe.arm(WORK, (pageIndex: number): void => { events.push(pageIndex) })
        let failed = false
        try {
          await seedPage(database, 2)
          await launchReadWrite()
          await waitId(driver, 'rkit-close'); await waitBody(driver, 2); await waitObserved(driver, events, 2)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('3 / 14')
          expect(connectNhReadProgress().index(GALLERY_ID)).assertEqual(2)
          await waitHistory(database, 2); await capture(driver, 'write-initial')
          const viewport = await waitId(driver, 'rkit-image-viewport')
          const bounds = await viewport.getBounds()
          const width = bounds.right - bounds.left
          const y = Math.round((bounds.top + bounds.bottom) / 2)
          await driver.swipe(Math.round(bounds.left + width * 0.82), y,
            Math.round(bounds.left + width * 0.18), y, 700)
          await waitBody(driver, 3); await waitObserved(driver, events, 3)
          expect(connectNhReadProgress().index(GALLERY_ID)).assertEqual(3)
          await waitHistory(database, 3); await capture(driver, 'write-next')
          await closeTrial(driver)
          await waitHistory(database, 3); await capture(driver, 'write-exit')
          expect(events.length).assertEqual(2)
          expect(events[0]).assertEqual(2); expect(events[1]).assertEqual(3)
          handoffReady = true
          console.info('[ReaderProgressPersistenceTest] write events=[2,3] durable=3 handoffReady=true')
        } catch (error) {
          failed = true
          try { await capture(driver, 'write-exception') } catch (_) {}
          throw error as Error
        } finally {
          probe.cancel(epoch)
          try { await closeTrial(driver) } catch (error) { if (!failed) throw error as Error }
          if (!handoffReady) {
            await restoreAndVerify(database, original)
            removeSnapshotFile()
          }
        }
      })
    })
    return
  }
  if (selectedClass === 'ReaderProgressPersistenceRestoreTrial') {
    describe(selectedClass, (): void => {
      it('coldRestoresDurableProgressThenRestoresOriginalRow', 0, async (): Promise<void> => {
        expect(args['-s readerLabWork']).assertEqual(WORK)
        const driver = Driver.create()
        const database = await store(await context(driver))
        const original = readSnapshot()
        const before = await snapshotHistory(database)
        expect(before.present).assertTrue(); expect(before.lastReadIndex).assertEqual(3)
        const events: number[] = []
        const probe = connectNextNReaderObservedProgressProbe()
        const epoch = probe.arm(WORK, (pageIndex: number): void => { events.push(pageIndex) })
        let failed = false
        let restored = false
        try {
          await launchReadWrite()
          await waitId(driver, 'rkit-close'); await waitBody(driver, 3); await waitObserved(driver, events, 3)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('4 / 14')
          await waitHistory(database, 3); await capture(driver, 'cold-restore')
          await closeTrial(driver); await waitHistory(database, 3)
          expect(events.length).assertEqual(1); expect(events[0]).assertEqual(3)
          console.info('[ReaderProgressPersistenceTest] coldRestore=3 events=[3]')
        } catch (error) {
          failed = true
          try { await capture(driver, 'restore-exception') } catch (_) {}
          throw error as Error
        } finally {
          probe.cancel(epoch)
          try { await closeTrial(driver) } catch (error) { if (!failed) throw error as Error }
          try {
            await restoreAndVerify(database, original)
            restored = true
            await capture(driver, 'restored-exit')
          } finally {
            if (restored) removeSnapshotFile()
          }
        }
      })
    })
    return
  }
  if (selectedClass === 'ReaderProgressPersistenceThumbnailTrial') {
    describe(selectedClass, (): void => {
      it('clickedThumbnailBeatsStoredProgressAndWritesOnlyAfterRetryDisplay', 0, async (): Promise<void> => {
        expect(args['-s readerLabWork']).assertEqual(WORK)
        const clickedPage = 2
        const storedPage = 7
        const driver = Driver.create()
        const database = await store(await context(driver))
        const original = await snapshotHistory(database)
        writeSnapshot(original)
        const events: number[] = []
        const probe = connectNextNReaderObservedProgressProbe()
        const epoch = probe.arm(WORK, (pageIndex: number): void => { events.push(pageIndex) })
        let failed = false
        try {
          await seedPage(database, storedPage)
          await armThumbnailReadWrite(clickedPage)
          const source = await findDetailThumbnail(driver, clickedPage)
          await capture(driver, 'thumbnail-source')
          await source.click()
          const retry = await waitRetry(driver, clickedPage)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('3 / 14')
          await driver.delayMs(1000)
          expect(events.length).assertEqual(0)
          expect((await snapshotHistory(database)).lastReadIndex).assertEqual(storedPage)
          await capture(driver, 'thumbnail-failure')
          await retry.click()
          await waitBody(driver, clickedPage); await waitObserved(driver, events, clickedPage)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('3 / 14')
          await waitHistory(database, clickedPage)
          await capture(driver, 'thumbnail-retried')
          await closeTrial(driver); await waitHistory(database, clickedPage)
          expect(events.length).assertEqual(1); expect(events[0]).assertEqual(clickedPage)
          console.info('[ReaderProgressPersistenceTest] thumbnail stored=7 clicked=2 failureEvents=[] retryEvents=[2] durable=2')
        } catch (error) {
          failed = true
          try { await capture(driver, 'thumbnail-exception') } catch (_) {}
          throw error as Error
        } finally {
          probe.cancel(epoch)
          try { await closeTrial(driver) } catch (error) { if (!failed) throw error as Error }
          try { await restoreAndVerify(database, original) } finally { removeSnapshotFile() }
        }
      })
    })
    return
  }
  if (selectedClass === 'ReaderProgressPersistenceCrossModeTrial') {
    describe(selectedClass, (): void => {
      it('writesCanonicalSpreadAndContinuousSourcePages', 0, async (): Promise<void> => {
        expect(args['-s readerLabWork']).assertEqual(WORK)
        const driver = Driver.create()
        const database = await store(await context(driver))
        const original = await snapshotHistory(database)
        writeSnapshot(original)
        const events: number[] = []
        const probe = connectNextNReaderObservedProgressProbe()
        const epoch = probe.arm(WORK, (pageIndex: number): void => { events.push(pageIndex) })
        let failed = false
        try {
          await seedPage(database, 2)
          await launchReadWrite('spread', 'rtl')
          await waitId(driver, 'rkit-close'); await waitBody(driver, 2); await waitBody(driver, 3)
          await waitObserved(driver, events, 2); await waitHistory(database, 2)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('3 / 14')
          await capture(driver, 'cross-spread-initial')
          const viewport = await waitId(driver, 'rkit-image-viewport')
          const spreadBounds = await viewport.getBounds()
          const spreadWidth = spreadBounds.right - spreadBounds.left
          const spreadY = Math.round((spreadBounds.top + spreadBounds.bottom) / 2)
          await driver.swipe(Math.round(spreadBounds.left + spreadWidth * 0.18), spreadY,
            Math.round(spreadBounds.left + spreadWidth * 0.82), spreadY, 700)
          await waitBody(driver, 4); await waitBody(driver, 5)
          await waitObserved(driver, events, 4); await waitHistory(database, 4)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('5 / 14')
          await capture(driver, 'cross-spread-next')
          await closeTrial(driver); await waitHistory(database, 4)

          await launchReadWrite('continuous', 'ltr')
          await waitId(driver, 'rkit-close'); await waitBody(driver, 4, true)
          await waitObserved(driver, events, 4); await waitHistory(database, 4)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('5 / 14')
          await capture(driver, 'cross-continuous-initial')
          const list = await waitId(driver, 'rkit-continuous-list')
          const listBounds = await list.getBounds()
          const listX = Math.round((listBounds.left + listBounds.right) / 2)
          for (let attempt = 0; attempt < 14 && events[events.length - 1] !== 5; attempt++) {
            await driver.swipe(listX, Math.round(listBounds.top + (listBounds.bottom - listBounds.top) * 0.82),
              listX, Math.round(listBounds.top + (listBounds.bottom - listBounds.top) * 0.18), 450)
            await driver.delayMs(180)
          }
          await waitBody(driver, 5, true); await waitObserved(driver, events, 5); await waitHistory(database, 5)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('6 / 14')
          await capture(driver, 'cross-continuous-next')
          await closeTrial(driver); await waitHistory(database, 5)
          expect(events.length).assertEqual(4)
          expect(events[0]).assertEqual(2); expect(events[1]).assertEqual(4)
          expect(events[2]).assertEqual(4); expect(events[3]).assertEqual(5)
          console.info('[ReaderProgressPersistenceTest] crossMode events=[2,4,4,5] durable=5 spreadRtl=true continuous=true')
        } catch (error) {
          failed = true
          try { await capture(driver, 'cross-mode-exception') } catch (_) {}
          throw error as Error
        } finally {
          probe.cancel(epoch)
          try { await closeTrial(driver) } catch (error) { if (!failed) throw error as Error }
          try { await restoreAndVerify(database, original) } finally { removeSnapshotFile() }
        }
      })
    })
    return
  }
  if (selectedClass === 'ReaderProgressPersistenceVerticalTrial') {
    describe(selectedClass, (): void => {
      it('writesCanonicalVerticalPageAndRestoresAfterClose', 0, async (): Promise<void> => {
        expect(args['-s readerLabWork']).assertEqual(WORK)
        const driver = Driver.create()
        const database = await store(await context(driver))
        const original = await snapshotHistory(database)
        writeSnapshot(original)
        const events: number[] = []
        const probe = connectNextNReaderObservedProgressProbe()
        const epoch = probe.arm(WORK, (pageIndex: number): void => { events.push(pageIndex) })
        let failed = false
        try {
          await seedPage(database, 2)
          await launchReadWrite()
          await waitId(driver, 'rkit-close'); await waitBody(driver, 2)
          await waitObserved(driver, events, 2); await waitHistory(database, 2)
          await (await waitId(driver, 'rkit-reading-mode')).click()
          await (await waitId(driver, 'rkit-vertical-paged')).click()
          await driver.delayMs(600)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('3 / 14')
          await capture(driver, 'vertical-initial')
          await swipePaged(driver, true, true); await waitBody(driver, 3)
          await waitObserved(driver, events, 3); await waitHistory(database, 3)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('4 / 14')
          await capture(driver, 'vertical-next')
          await closeTrial(driver); await waitHistory(database, 3)

          await launchReadWrite()
          await waitId(driver, 'rkit-close'); await waitBody(driver, 3)
          await waitObserved(driver, events, 3); await waitHistory(database, 3)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('4 / 14')
          await capture(driver, 'vertical-reopen')
          await closeTrial(driver); await waitHistory(database, 3)
          expect(events.length).assertEqual(3)
          expect(events[0]).assertEqual(2); expect(events[1]).assertEqual(3); expect(events[2]).assertEqual(3)
          console.info('[ReaderProgressPersistenceTest] vertical events=[2,3,3] durable=3 dedupeSameAnchor=true')
        } catch (error) {
          failed = true
          try { await capture(driver, 'vertical-exception') } catch (_) {}
          throw error as Error
        } finally {
          probe.cancel(epoch)
          try { await closeTrial(driver) } catch (error) { if (!failed) throw error as Error }
          try { await restoreAndVerify(database, original) } finally { removeSnapshotFile() }
        }
      })
    })
    return
  }
  if (selectedClass === 'ReaderProgressPersistenceThumbnailVerticalRetryTrial') {
    describe(selectedClass, (): void => {
      it('thumbnailAnchorSurvivesVerticalFailureRetryAndReopen', 0, async (): Promise<void> => {
        expect(args['-s readerLabWork']).assertEqual(WORK)
        const clickedPage = 2
        const failedNextPage = 3
        const storedPage = 7
        const driver = Driver.create()
        const database = await store(await context(driver))
        const original = await snapshotHistory(database)
        writeSnapshot(original)
        const events: number[] = []
        const probe = connectNextNReaderObservedProgressProbe()
        const epoch = probe.arm(WORK, (pageIndex: number): void => { events.push(pageIndex) })
        let failed = false
        try {
          await seedPage(database, storedPage)
          await armThumbnailReadWrite(clickedPage, failedNextPage)
          const source = await findDetailThumbnail(driver, clickedPage)
          await source.click()
          await waitId(driver, 'rkit-close'); await waitBody(driver, clickedPage)
          await waitObserved(driver, events, clickedPage); await waitHistory(database, clickedPage)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('3 / 14')
          await capture(driver, 'thumbnail-vertical-selected')

          await (await waitId(driver, 'rkit-reading-mode')).click()
          await (await waitId(driver, 'rkit-vertical-paged')).click()
          await driver.delayMs(600)
          await swipePaged(driver, true, true)
          const retry = await waitRetry(driver, failedNextPage)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('4 / 14')
          await driver.delayMs(1000)
          expect(events.length).assertEqual(1); expect(events[0]).assertEqual(clickedPage)
          expect((await snapshotHistory(database)).lastReadIndex).assertEqual(clickedPage)
          await capture(driver, 'thumbnail-vertical-failure')

          await retry.click()
          await waitBody(driver, failedNextPage); await waitObserved(driver, events, failedNextPage)
          await waitHistory(database, failedNextPage)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('4 / 14')
          await capture(driver, 'thumbnail-vertical-retried')
          await closeTrial(driver); await waitHistory(database, failedNextPage)

          await launchReadWrite()
          await waitId(driver, 'rkit-close'); await waitBody(driver, failedNextPage)
          await waitObserved(driver, events, failedNextPage); await waitHistory(database, failedNextPage)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('4 / 14')
          // The image-ready semantic node can precede the compositor by one frame after relaunch.
          // Keep the acceptance capture behind a short render-stability gate so a black frame
          // cannot be mistaken for a restored reader page.
          await driver.delayMs(1200)
          await waitBody(driver, failedNextPage)
          await capture(driver, 'thumbnail-vertical-reopen')
          await closeTrial(driver); await waitHistory(database, failedNextPage)
          expect(events.length).assertEqual(3)
          expect(events[0]).assertEqual(clickedPage); expect(events[1]).assertEqual(failedNextPage)
          expect(events[2]).assertEqual(failedNextPage)
          console.info('[ReaderProgressPersistenceTest] thumbnailVertical stored=7 events=[2,3,3] failureDurable=2 retryDurable=3')
        } catch (error) {
          failed = true
          try { await capture(driver, 'thumbnail-vertical-exception') } catch (_) {}
          throw error as Error
        } finally {
          probe.cancel(epoch)
          try { await closeTrial(driver) } catch (error) { if (!failed) throw error as Error }
          try { await restoreAndVerify(database, original) } finally { removeSnapshotFile() }
        }
      })
    })
    return
  }
  if (selectedClass === 'ReaderProgressPersistenceThumbnailSpreadRetryTrial') {
    describe(selectedClass, (): void => {
      it('keepsClickedPageAsRtlSpreadAnchorAcrossNeighborRetryAndReopen', 0, async (): Promise<void> => {
        expect(args['-s readerLabWork']).assertEqual(WORK)
        const clickedPage = 2
        const failedNeighbor = 3
        const nextSpreadAnchor = 4
        const storedPage = 7
        const driver = Driver.create()
        const database = await store(await context(driver))
        const original = await snapshotHistory(database)
        writeSnapshot(original)
        const events: number[] = []
        const probe = connectNextNReaderObservedProgressProbe()
        const epoch = probe.arm(WORK, (pageIndex: number): void => { events.push(pageIndex) })
        let failed = false
        try {
          await seedPage(database, storedPage)
          await armThumbnailReadWrite(clickedPage, failedNeighbor, 'spread', 'rtl')
          const source = await findDetailThumbnail(driver, clickedPage)
          await source.click()
          await waitId(driver, 'rkit-close'); await waitBody(driver, clickedPage)
          const retry = await waitRetry(driver, failedNeighbor)
          await waitObserved(driver, events, clickedPage); await waitHistory(database, clickedPage)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('3 / 14')
          expect(events.length).assertEqual(1); expect(events[0]).assertEqual(clickedPage)
          await capture(driver, 'thumbnail-spread-neighbor-failure')

          await retry.click(); await waitBody(driver, failedNeighbor)
          await driver.delayMs(1000)
          expect(events.length).assertEqual(1); expect(events[0]).assertEqual(clickedPage)
          expect((await snapshotHistory(database)).lastReadIndex).assertEqual(clickedPage)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('3 / 14')
          await capture(driver, 'thumbnail-spread-neighbor-retried')

          const viewport = await waitId(driver, 'rkit-image-viewport')
          const bounds = await viewport.getBounds()
          const width = bounds.right - bounds.left
          const y = Math.round((bounds.top + bounds.bottom) / 2)
          await driver.swipe(Math.round(bounds.left + width * 0.18), y,
            Math.round(bounds.left + width * 0.82), y, 700)
          await waitBody(driver, nextSpreadAnchor); await waitBody(driver, nextSpreadAnchor + 1)
          await waitObserved(driver, events, nextSpreadAnchor); await waitHistory(database, nextSpreadAnchor)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('5 / 14')
          await capture(driver, 'thumbnail-spread-next')
          await closeTrial(driver); await waitHistory(database, nextSpreadAnchor)

          await launchReadWrite()
          await waitId(driver, 'rkit-close'); await waitBody(driver, nextSpreadAnchor)
          await waitObserved(driver, events, nextSpreadAnchor); await waitHistory(database, nextSpreadAnchor)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('5 / 14')
          await driver.delayMs(1200); await waitBody(driver, nextSpreadAnchor)
          await capture(driver, 'thumbnail-spread-reopen')
          await closeTrial(driver); await waitHistory(database, nextSpreadAnchor)
          expect(events.length).assertEqual(3)
          expect(events[0]).assertEqual(clickedPage); expect(events[1]).assertEqual(nextSpreadAnchor)
          expect(events[2]).assertEqual(nextSpreadAnchor)
          console.info('[ReaderProgressPersistenceTest] thumbnailSpread stored=7 events=[2,4,4] ' +
            'neighborFailureDurable=2 nextSpreadDurable=4 rtl=true')
        } catch (error) {
          failed = true
          try { await capture(driver, 'thumbnail-spread-exception') } catch (_) {}
          throw error as Error
        } finally {
          probe.cancel(epoch)
          try { await closeTrial(driver) } catch (error) { if (!failed) throw error as Error }
          try { await restoreAndVerify(database, original) } finally { removeSnapshotFile() }
        }
      })
    })
    return
  }
  if (selectedClass === 'ReaderProgressPersistenceThumbnailContinuousTrial') {
    describe(selectedClass, (): void => {
      it('persistsNextFullyVisibleContinuousPageAfterThumbnailEntryAndReopen', 0, async (): Promise<void> => {
        expect(args['-s readerLabWork']).assertEqual(WORK)
        const clickedPage = 2
        const nextPage = 3
        const storedPage = 7
        const driver = Driver.create()
        const database = await store(await context(driver))
        const original = await snapshotHistory(database)
        writeSnapshot(original)
        const events: number[] = []
        const probe = connectNextNReaderObservedProgressProbe()
        const epoch = probe.arm(WORK, (pageIndex: number): void => { events.push(pageIndex) })
        let failed = false
        try {
          await seedPage(database, storedPage)
          await armThumbnailReadWrite(clickedPage, -1, 'continuous', 'ltr')
          const source = await findDetailThumbnail(driver, clickedPage)
          await source.click()
          await waitId(driver, 'rkit-close'); await waitBody(driver, clickedPage, true)
          await waitObserved(driver, events, clickedPage); await waitHistory(database, clickedPage)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('3 / 14')
          await capture(driver, 'thumbnail-continuous-initial')

          const list = await waitId(driver, 'rkit-continuous-list')
          const bounds = await list.getBounds()
          const x = Math.round((bounds.left + bounds.right) / 2)
          for (let attempt = 0; attempt < 18 && events[events.length - 1] !== nextPage; attempt++) {
            await driver.swipe(x, Math.round(bounds.top + (bounds.bottom - bounds.top) * 0.82),
              x, Math.round(bounds.top + (bounds.bottom - bounds.top) * 0.18), 450)
            await driver.delayMs(180)
          }
          await waitBody(driver, nextPage, true); await waitObserved(driver, events, nextPage)
          await waitHistory(database, nextPage)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('4 / 14')
          await capture(driver, 'thumbnail-continuous-next')
          await closeTrial(driver); await waitHistory(database, nextPage)

          await launchReadWrite('continuous', 'ltr')
          await waitId(driver, 'rkit-close'); await waitBody(driver, nextPage, true)
          await waitObserved(driver, events, nextPage); await waitHistory(database, nextPage)
          expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertContain('4 / 14')
          await driver.delayMs(1200); await waitBody(driver, nextPage, true)
          await capture(driver, 'thumbnail-continuous-reopen')
          await closeTrial(driver); await waitHistory(database, nextPage)
          expect(events.length).assertEqual(3)
          expect(events[0]).assertEqual(clickedPage); expect(events[1]).assertEqual(nextPage)
          expect(events[2]).assertEqual(nextPage)
          console.info('[ReaderProgressPersistenceTest] thumbnailContinuous stored=7 events=[2,3,3] ' +
            'fullyVisibleNextDurable=3')
        } catch (error) {
          failed = true
          try { await capture(driver, 'thumbnail-continuous-exception') } catch (_) {}
          throw error as Error
        } finally {
          probe.cancel(epoch)
          try { await closeTrial(driver) } catch (error) { if (!failed) throw error as Error }
          try { await restoreAndVerify(database, original) } finally { removeSnapshotFile() }
        }
      })
    })
    return
  }
  if (selectedClass === 'ReaderProgressPersistenceCleanupTrial') {
    describe(selectedClass, (): void => {
      it('restoresExactOriginalHistoryIfInterrupted', 0, async (): Promise<void> => {
        const path = snapshotPath()
        if (!fileIo.accessSync(path)) {
          console.info('[ReaderProgressPersistenceTest] cleanup snapshotAbsent=true')
          return
        }
        const database = await store(await context(Driver.create()))
        const original = readSnapshot()
        await restoreAndVerify(database, original)
        removeSnapshotFile()
        console.info('[ReaderProgressPersistenceTest] cleanup restored=true')
      })
    })
  }
}
