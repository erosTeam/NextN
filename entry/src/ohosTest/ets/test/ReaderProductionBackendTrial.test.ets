import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, MatchPattern, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { window } from '@kit.ArkUI'
import { fileIo } from '@kit.CoreFileKit'
import { KeyCode } from '@kit.InputKit'
import {
  AppStrings,
  connectNhReadProgress,
  connectNextNReaderBackendSelection,
  connectReaderPresentation,
  NextNReaderBackend,
  NhReaderColumnMode,
  NhReaderMode,
  NhReaderSpreadLayout,
  ReaderPresentationService,
  ReaderSettingsRepository,
  ReaderTrialOriginalProbe,
  ReaderTrialOriginalSnapshot,
} from 'shared'
import { NextNReaderProductionFailureFacts, NextNReaderProductionFailureProbe } from 'reader'

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

async function seedHistoryPage(database: relationalStore.RdbStore, pageIndex: number): Promise<void> {
  const current = await snapshotHistory(database)
  if (current.present) {
    await database.executeSql(
      'UPDATE reading_history SET last_read_index=?,has_read_progress=1 WHERE gallery_id=?',
      [pageIndex, GALLERY_ID])
  } else {
    await database.executeSql(
      'INSERT INTO reading_history ' +
        '(gallery_id,media_id,title,thumbnail_url,page_count,last_read_index,has_read_progress,last_opened_at) ' +
        'VALUES (?,?,?,?,?,?,1,?)', [GALLERY_ID, '', '', '', 14, pageIndex, Date.now()])
  }
  connectNhReadProgress().set(GALLERY_ID, pageIndex)
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

async function waitBackendSelection(driver: Driver, backend: string): Promise<void> {
  for (let attempt = 0; attempt < 80; attempt++) {
    if (connectNextNReaderBackendSelection().current() === backend) return
    await driver.delayMs(100)
  }
  throw new Error(`Production backend selection did not become ${backend}`)
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

async function findDetailThumbnail(driver: Driver, pageIndex: number): Promise<Component> {
  let owner: Component | null = null
  for (let attempt = 0; attempt < 80; attempt++) {
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
  if (source === null) throw new Error(`Detail thumbnail unavailable: ${pageIndex}`)
  const matches = await driver.findComponents(selector)
  expect(matches.length).assertEqual(1)
  const sourceId = await source.getId()
  expect(new RegExp(pattern).test(sourceId)).assertTrue()
  return await driver.findComponent(ON.id(sourceId))
}

async function findFullThumbnail(driver: Driver, pageIndex: number): Promise<Component> {
  await waitDetailRead(driver)
  const viewAll = await driver.findComponents(ON.text(AppStrings.get('detail_view_all'))
    .within(ON.id('nextn-root-navigation')))
  if (viewAll.length !== 1) throw new Error('Detail View all action is not unique')
  await viewAll[0].click()
  return findCurrentFullThumbnail(driver, pageIndex)
}

async function findCurrentFullThumbnail(driver: Driver, pageIndex: number): Promise<Component> {
  const pattern = `^reader-thumb-all-thumbnails-[0-9]+-page-${pageIndex}$`
  const selector = ON.id(pattern, MatchPattern.REG_EXP).within(ON.type('Grid'))
  for (let attempt = 0; attempt < 40; attempt++) {
    const grids = await driver.findComponents(ON.type('Grid').within(ON.id('nextn-root-navigation'))) ?? []
    if (grids.length > 1) throw new Error('Ambiguous full-thumbnail Grid; no coordinate fallback')
    if (grids.length === 1) {
      let matches = await driver.findComponents(selector) ?? []
      if (matches.length === 0) {
        const found = await grids[0].scrollSearch(selector, true)
        if (found === null) throw new Error(`Full thumbnail unavailable: ${pageIndex}`)
        matches = await driver.findComponents(selector) ?? []
      }
      expect(matches.length).assertEqual(1)
      const sourceId = await matches[0].getId()
      expect(new RegExp(pattern).test(sourceId)).assertTrue()
      return await driver.findComponent(ON.id(sourceId))
    }
    await driver.delayMs(250)
  }
  throw new Error('View all did not open the full-thumbnail Grid')
}

async function findWideDetailThumbnail(driver: Driver, pageIndex: number): Promise<Component> {
  await waitDetailRead(driver)
  const pane = await waitId(driver, 'gallery-detail-preview-pane')
  const grids = await driver.findComponents(ON.type('Grid').within(ON.id('gallery-detail-preview-pane')))
  if (grids.length !== 1) throw new Error('Wide Detail preview Grid is not unique')
  const pattern = `^reader-thumb-gallery-detail-[0-9]+-page-${pageIndex}$`
  const selector = ON.id(pattern, MatchPattern.REG_EXP).within(ON.id('gallery-detail-preview-pane'))
  let matches = await driver.findComponents(selector)
  if (matches.length === 0) {
    const found = await grids[0].scrollSearch(selector, true)
    if (found === null) throw new Error(`Wide Detail thumbnail unavailable: ${pageIndex}`)
    matches = await driver.findComponents(selector)
  }
  expect(matches.length).assertEqual(1)
  const sourceId = await matches[0].getId()
  expect(new RegExp(pattern).test(sourceId)).assertTrue()
  const paneBounds = await pane.getBounds()
  const sourceBounds = await matches[0].getBounds()
  expect(sourceBounds.left >= paneBounds.left && sourceBounds.right <= paneBounds.right &&
    sourceBounds.top >= paneBounds.top && sourceBounds.bottom <= paneBounds.bottom).assertTrue()
  return await driver.findComponent(ON.id(sourceId))
}

async function waitProductionSpreadHeld(driver: Driver, epoch: number): Promise<ReaderTrialOriginalSnapshot> {
  for (let attempt = 0; attempt < 120; attempt++) {
    const state = ReaderTrialOriginalProbe.read()
    expect(state.epoch).assertEqual(epoch)
    if (state.state === 'cancelled' || state.state === 'failed') {
      throw new Error(`Production spread entry became terminal while waiting: ${state.state}`)
    }
    if (state.state === 'held' && state.reader.entryPhase === 'waiting' && state.reader.layoutReady &&
      state.reader.anchor === 2 && state.reader.entryId > 0 && state.requestId > 0) {
      const viewport = await waitId(driver, 'rkit-image-viewport')
      const selected = await waitId(driver, 'rkit-part-2-whole')
      const neighbor = await waitId(driver, 'rkit-part-3-whole')
      const preview = await waitId(driver, 'rkit-entry-preview-image')
      const viewportBounds = await viewport.getBounds()
      const selectedBounds = await selected.getBounds()
      const neighborBounds = await neighbor.getBounds()
      const previewBounds = await preview.getBounds()
      expect(selectedBounds.left > neighborBounds.left).assertTrue()
      expect(selectedBounds.right <= viewportBounds.right && neighborBounds.left >= viewportBounds.left).assertTrue()
      const previewCenterX = (previewBounds.left + previewBounds.right) / 2
      expect(previewCenterX >= selectedBounds.left && previewCenterX <= selectedBounds.right).assertTrue()
      expect(await driver.findComponent(ON.type('Image').within(ON.id('rkit-part-3-whole'))) !== null).assertTrue()
      expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertEqual('3 / 14')
      return state
    }
    await driver.delayMs(100)
  }
  throw new Error('Production spread entry did not reach selected-page waiting geometry')
}

async function waitProductionSpreadDelivered(driver: Driver, epoch: number,
  requestId: number, entryId: number): Promise<void> {
  for (let attempt = 0; attempt < 80; attempt++) {
    const state = ReaderTrialOriginalProbe.read()
    expect(state.epoch).assertEqual(epoch)
    expect(state.requestId).assertEqual(requestId)
    if (state.state === 'cancelled' || state.state === 'failed') {
      throw new Error(`Production spread delivery became terminal: ${state.state}`)
    }
    if (state.state !== 'delivered') expect(state.reader.entryId).assertEqual(entryId)
    else expect(state.reader.entryId === entryId || state.reader.entryId === 0).assertTrue()
    const selected = await driver.findComponent(ON.type('Image').within(ON.id('rkit-part-2-whole')))
    const neighbor = await driver.findComponent(ON.type('Image').within(ON.id('rkit-part-3-whole')))
    const entrySettled = state.reader.entryId === 0 ||
      (state.reader.entryPhase === 'finished' && state.reader.decodedReady)
    if (state.state === 'delivered' && entrySettled && state.reader.anchor === 2 &&
      state.reader.assetPhase === 'displayed' &&
      selected !== null && neighbor !== null &&
      await driver.findComponent(ON.id('rkit-entry-preview-image')) === null &&
      await driver.findComponent(ON.type('LoadingProgress').within(ON.id('rkit-image-viewport'))) === null &&
      await driver.findComponent(ON.id('^rkit-failure-page-[0-9]+$', MatchPattern.REG_EXP)
        .within(ON.id('rkit-image-viewport'))) === null) return
    await driver.delayMs(100)
  }
  throw new Error('Production spread entry did not finish the real-image handoff')
}

async function waitProductionSingletonHeld(driver: Driver, epoch: number,
  pageIndex: number): Promise<ReaderTrialOriginalSnapshot> {
  const viewportSelector = ON.id('rkit-image-viewport')
  for (let attempt = 0; attempt < 120; attempt++) {
    const state = ReaderTrialOriginalProbe.read()
    expect(state.epoch).assertEqual(epoch)
    if (state.state === 'cancelled' || state.state === 'failed') {
      throw new Error(`Production singleton entry became terminal while waiting: ${state.state}`)
    }
    if (state.state === 'held' && state.reader.entryPhase === 'waiting' && state.reader.layoutReady &&
      state.reader.anchor === pageIndex && state.reader.entryId > 0 && state.requestId > 0) {
      const viewport = await waitId(driver, 'rkit-image-viewport')
      const selected = await waitId(driver, `rkit-part-${pageIndex}-whole`)
      const preview = await waitId(driver, 'rkit-entry-preview-image')
      const parts = await driver.findComponents(
        ON.id('^rkit-part-[0-9]+-whole$', MatchPattern.REG_EXP).within(viewportSelector))
      expect(parts.length).assertEqual(1)
      const viewportBounds = await viewport.getBounds()
      const selectedBounds = await selected.getBounds()
      const previewBounds = await preview.getBounds()
      expect(selectedBounds.left >= viewportBounds.left && selectedBounds.right <= viewportBounds.right &&
        selectedBounds.top >= viewportBounds.top && selectedBounds.bottom <= viewportBounds.bottom).assertTrue()
      expect(previewBounds.left >= selectedBounds.left && previewBounds.right <= selectedBounds.right &&
        previewBounds.top >= selectedBounds.top && previewBounds.bottom <= selectedBounds.bottom).assertTrue()
      const selectedCenterX = (selectedBounds.left + selectedBounds.right) / 2
      const previewCenterX = (previewBounds.left + previewBounds.right) / 2
      const viewportCenterX = (viewportBounds.left + viewportBounds.right) / 2
      expect(Math.abs(selectedCenterX - viewportCenterX) <= 2).assertTrue()
      expect(Math.abs(previewCenterX - viewportCenterX) <= 2).assertTrue()
      expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertEqual(`${pageIndex + 1} / 14`)
      return state
    }
    await driver.delayMs(100)
  }
  throw new Error(`Production P${pageIndex + 1} singleton did not reach centered waiting geometry`)
}

async function waitProductionSingletonDelivered(driver: Driver, epoch: number,
  requestId: number, entryId: number, pageIndex: number): Promise<void> {
  const viewportSelector = ON.id('rkit-image-viewport')
  for (let attempt = 0; attempt < 80; attempt++) {
    const state = ReaderTrialOriginalProbe.read()
    expect(state.epoch).assertEqual(epoch)
    expect(state.requestId).assertEqual(requestId)
    if (state.state === 'cancelled' || state.state === 'failed') {
      throw new Error(`Production singleton delivery became terminal: ${state.state}`)
    }
    if (state.state !== 'delivered') expect(state.reader.entryId).assertEqual(entryId)
    else expect(state.reader.entryId === entryId || state.reader.entryId === 0).assertTrue()
    const selected = await driver.findComponent(
      ON.type('Image').within(ON.id(`rkit-part-${pageIndex}-whole`)))
    const parts = await driver.findComponents(
      ON.id('^rkit-part-[0-9]+-whole$', MatchPattern.REG_EXP).within(viewportSelector))
    const entrySettled = state.reader.entryId === 0 ||
      (state.reader.entryPhase === 'finished' && state.reader.decodedReady)
    if (state.state === 'delivered' && entrySettled && state.reader.anchor === pageIndex &&
      state.reader.assetPhase === 'displayed' && selected !== null && parts.length === 1 &&
      await driver.findComponent(ON.id('rkit-entry-preview-image')) === null &&
      await driver.findComponent(ON.type('LoadingProgress').within(viewportSelector)) === null &&
      await driver.findComponent(ON.id('^rkit-failure-page-[0-9]+$', MatchPattern.REG_EXP)
        .within(viewportSelector)) === null) return
    await driver.delayMs(100)
  }
  throw new Error(`Production P${pageIndex + 1} singleton did not finish the real-image handoff`)
}

async function restoreProductionSpreadSettings(context: common.UIAbilityContext,
  database: relationalStore.RdbStore, settings: SettingSnapshot[], mode: NhReaderMode,
  doublePageEnabled: boolean, spreadLayout: NhReaderSpreadLayout): Promise<void> {
  await ReaderPresentationService.setMode(context, mode)
  await ReaderPresentationService.setDoublePageEnabled(context, doublePageEnabled)
  await ReaderPresentationService.setSpreadLayout(context, spreadLayout)
  for (const setting of settings) await restoreSetting(database, setting)
  connectReaderPresentation().mode = mode
  connectReaderPresentation().doublePageEnabled = doublePageEnabled
  connectReaderPresentation().spreadLayoutMode = spreadLayout
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

async function openAndVerifyNetworkThumbnailRail(driver: Driver, expectedPage: number): Promise<string> {
  await (await waitId(driver, 'rkit-toggle-thumbnails')).click()
  for (let attempt = 0; attempt < 80; attempt++) {
    const rail = await driver.findComponent(ON.id('rkit-thumbnail-rail'))
    const first = await driver.findComponent(ON.id('rkit-thumb-state-0-displayed'))
    const second = await driver.findComponent(ON.id('rkit-thumb-state-1-displayed'))
    if (rail !== null && first !== null && second !== null) {
      const firstBounds = await (await waitId(driver, 'rkit-thumb-image-0')).getBounds()
      const secondBounds = await (await waitId(driver, 'rkit-thumb-image-1')).getBounds()
      const firstRatio = (firstBounds.right - firstBounds.left) / (firstBounds.bottom - firstBounds.top)
      const secondRatio = (secondBounds.right - secondBounds.left) / (secondBounds.bottom - secondBounds.top)
      expect(firstRatio >= 0.44 && firstRatio <= 1.41).assertTrue()
      expect(secondRatio >= 0.44 && secondRatio <= 1.41).assertTrue()
      expect(pageIndex(await (await waitId(driver, 'rkit-chrome-page')).getText())).assertEqual(expectedPage)
      await capture(driver, 'network-thumbnail-rail')
      return `${firstRatio.toFixed(3)},${secondRatio.toFixed(3)}`
    }
    await driver.delayMs(250)
  }
  throw new Error('Production network thumbnail rail did not decode its first two previews')
}

async function shareCurrentPageAndCancel(driver: Driver, expectedPage: number): Promise<void> {
  const share = await waitId(driver, 'rkit-share-image')
  expect(await share.isEnabled()).assertTrue()
  await share.click()
  await driver.delayMs(2500)
  await capture(driver, 'network-share-panel')
  expect(await (await waitId(driver, 'rkit-share-image')).isEnabled()).assertFalse()
  await driver.triggerKey(KeyCode.KEYCODE_BACK)
  for (let attempt = 0; attempt < 40; attempt++) {
    const current = await driver.findComponent(ON.id('rkit-share-image'))
    if (current !== null && await current.isEnabled()) {
      expect(pageIndex(await (await waitId(driver, 'rkit-chrome-page')).getText())).assertEqual(expectedPage)
      await capture(driver, 'network-share-returned')
      return
    }
    await driver.delayMs(250)
  }
  throw new Error('Production network share action did not recover after cancellation')
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
  if (selectedClass === 'ReaderProductionFailureRecoveryTrial') {
    describe(selectedClass, (): void => {
      it('retriesProductionCacheAfterNativeDecodeFailure', 0, async (): Promise<void> => {
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
          NextNReaderProductionFailureProbe.arm(GALLERY_ID.toString(), 0)

          await (await waitDetailRead(driver)).click()
          const retry = await waitId(driver, 'rkit-retry-page-1', 160)
          const failedFacts: NextNReaderProductionFailureFacts = NextNReaderProductionFailureProbe.read()
          expect(failedFacts.consumed).assertTrue()
          expect(failedFacts.warmedRealAsset).assertTrue()
          expect(failedFacts.injectedDecodeFailure).assertTrue()
          expect(failedFacts.retryObserved).assertFalse()
          expect(pageIndex(await (await waitId(driver, 'rkit-chrome-page')).getText())).assertEqual(0)
          await capture(driver, 'production-failure')

          await retry.click()
          expect(await waitSharedReady(driver)).assertEqual(0)
          const recoveredFacts: NextNReaderProductionFailureFacts = NextNReaderProductionFailureProbe.read()
          expect(recoveredFacts.retryObserved).assertTrue()
          expect(recoveredFacts.retryForceReload).assertTrue()
          await capture(driver, 'production-recovered')

          await closeAnyReader(driver)
          await waitDetailRead(driver)
          await capture(driver, 'production-recovery-closed')
          await restoreAndVerify(database, original)
          restored = true
          removeSnapshot()
          console.info('[ReaderProductionBackendTrial] productionFailure=true warmedRealAsset=true ' +
            'retryForceReload=true recoveredPage=0 historyRestored=true')
        } catch (error) {
          failed = true
          try { await capture(driver, 'production-recovery-exception') } catch (_) {}
          throw error as Error
        } finally {
          try { await closeAnyReader(driver) } catch (error) { if (!failed) throw error as Error }
          if (!restored && database !== null && original !== null) {
            await restoreAndVerify(database, original)
            removeSnapshot()
          }
          NextNReaderProductionFailureProbe.reset()
          await launchBackend('legacy', false)
        }
      })
    })
    return
  }
  if (selectedClass === 'ReaderProductionNetworkActionsTrial') {
    describe(selectedClass, (): void => {
      it('keepsNetworkThumbnailGeometryAndSharesCurrentCachedPage', 0, async (): Promise<void> => {
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

          await (await waitDetailRead(driver)).click()
          const initial = await waitSharedReady(driver)
          expect(initial).assertEqual(0)
          await capture(driver, 'network-initial')
          const ratios = await openAndVerifyNetworkThumbnailRail(driver, initial)
          await shareCurrentPageAndCancel(driver, initial)
          await closeAnyReader(driver)
          await waitDetailRead(driver)
          await capture(driver, 'network-closed')

          await restoreAndVerify(database, original)
          restored = true
          removeSnapshot()
          console.info(`[ReaderProductionBackendTrial] networkThumbnails=${ratios} current=${initial} ` +
            'networkShareCancelled=true historyRestored=true')
        } catch (error) {
          failed = true
          try { await capture(driver, 'network-exception') } catch (_) {}
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

  if (selectedClass === 'ReaderProductionThumbnailEntryTrial') {
    describe(selectedClass, (): void => {
      it('opensExactCompactThumbnailThroughSharedBodyWithoutDebugFeatureLoss', 0, async (): Promise<void> => {
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
          await seedHistoryPage(database, 6)

          await waitDetailRead(driver)
          expect(connectNextNReaderBackendSelection().current()).assertEqual(NextNReaderBackend.SHARED)
          const source = await findDetailThumbnail(driver, 2)
          const sourceId = await source.getId()
          const before = await source.getBounds()
          await capture(driver, 'thumbnail-source')
          await source.click()
          const initial = await waitSharedReady(driver)
          expect(initial).assertEqual(2)
          expect(await driver.findComponent(ON.id('legacy-reader-surface'))).assertNull()
          expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
          for (let attempt = 0; attempt < 40; attempt++) {
            if (await driver.findComponent(ON.id('rkit-entry-preview-image')) === null &&
              await driver.findComponent(ON.id('rkit-entry-source-pending')) === null) break
            await driver.delayMs(100)
          }
          expect(await driver.findComponent(ON.id('rkit-entry-preview-image'))).assertNull()
          expect(await driver.findComponent(ON.id('rkit-entry-source-pending'))).assertNull()
          await (await waitId(driver, 'rkit-runtime-settings')).click()
          expect(await waitId(driver, 'rkit-crop-toggle') !== null).assertTrue()
          await capture(driver, 'thumbnail-shared')
          await driver.pressBack()
          await closeAnyReader(driver)
          await waitDetailRead(driver)
          const returned = await waitId(driver, sourceId)
          const after = await returned.getBounds()
          expect(after.left).assertEqual(before.left)
          expect(after.top).assertEqual(before.top)
          expect(after.right).assertEqual(before.right)
          expect(after.bottom).assertEqual(before.bottom)
          await capture(driver, 'thumbnail-closed')

          await restoreAndVerify(database, original)
          restored = true
          removeSnapshot()
          console.info('[ReaderProductionBackendTrial] thumbnailShared=true clicked=2 persistedBefore=6 ' +
            'cropAvailable=true sourceRestored=true debugTrialAbsent=true historyRestored=true')
        } catch (error) {
          failed = true
          try { await capture(driver, 'thumbnail-exception') } catch (_) {}
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

  if (selectedClass === 'ReaderProductionThumbnailSpreadEntryTrial') {
    describe(selectedClass, (): void => {
      it('movesTheSelectedGridThumbnailToItsActualRtlSpreadSideBeforeNeighborHandoff', 0,
        async (): Promise<void> => {
          const driver = Driver.create()
          let context: common.UIAbilityContext | null = null
          let database: relationalStore.RdbStore | null = null
          let history: HistorySnapshot | null = null
          let settings: SettingSnapshot[] = []
          let savedMode: NhReaderMode = NhReaderMode.PAGED
          let savedDoublePage: boolean = false
          let savedSpread: NhReaderSpreadLayout = NhReaderSpreadLayout.JOINED
          let historyRestored = false
          let settingsRestored = false
          let probeEpoch = 0
          let failed = false
          try {
            await launchBackend('shared', true)
            context = await entryContext(driver)
            database = await store(context)
            history = await snapshotHistory(database)
            writeSnapshot(history)
            await ReaderPresentationService.restore(context)
            const presentation = ReaderPresentationService.snapshot()
            savedMode = presentation.mode
            savedDoublePage = presentation.doublePageEnabled
            savedSpread = presentation.spreadLayoutMode
            for (const key of ['reader_mode', 'reader_double_page_enabled', 'reader_spread_layout',
              `reader_column_mode:${GALLERY_ID}`]) {
              settings.push(new SettingSnapshot(key, await settingValue(database, key)))
            }
            await ReaderPresentationService.setMode(context, NhReaderMode.PAGED_RTL)
            await ReaderPresentationService.setDoublePageEnabled(context, true)
            await ReaderPresentationService.setSpreadLayout(context, NhReaderSpreadLayout.SPLIT)
            await ReaderSettingsRepository.saveColumnMode(context, GALLERY_ID, NhReaderColumnMode.ODD_LEFT)
            await seedHistoryPage(database, 6)

            expect(connectNextNReaderBackendSelection().current()).assertEqual(NextNReaderBackend.SHARED)
            const source = await findFullThumbnail(driver, 2)
            const sourceId = await source.getId()
            const before = await source.getBounds()
            probeEpoch = ReaderTrialOriginalProbe.arm(GALLERY_ID.toString(), 2)
            await capture(driver, 'spread-source')
            await source.click()
            const held = await waitProductionSpreadHeld(driver, probeEpoch)
            expect(await driver.findComponent(ON.id('legacy-reader-surface'))).assertNull()
            expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
            await capture(driver, 'spread-waiting')

            expect(ReaderTrialOriginalProbe.release(probeEpoch, held.requestId)).assertTrue()
            await waitProductionSpreadDelivered(driver, probeEpoch, held.requestId, held.reader.entryId)
            expect(await (await waitId(driver, 'rkit-chrome-page')).getText()).assertEqual('3 / 14')
            await capture(driver, 'spread-settled')
            await closeAnyReader(driver)
            const returned = await waitId(driver, sourceId)
            const after = await returned.getBounds()
            expect(after.left).assertEqual(before.left)
            expect(after.top).assertEqual(before.top)
            expect(after.right).assertEqual(before.right)
            expect(after.bottom).assertEqual(before.bottom)
            await capture(driver, 'spread-closed')

            await restoreAndVerify(database, history)
            historyRestored = true
            removeSnapshot()
            await restoreProductionSpreadSettings(context, database, settings,
              savedMode, savedDoublePage, savedSpread)
            settingsRestored = true
            console.info('[ReaderProductionBackendTrial] thumbnailSpreadShared=true clicked=2 savedBefore=6 ' +
              'heldWaiting=true selectedRight=true neighborLeft=true delivered=true sourceRestored=true ' +
              'historyRestored=true settingsRestored=true')
          } catch (error) {
            failed = true
            try { await capture(driver, 'spread-exception') } catch (_) {}
            throw error as Error
          } finally {
            if (probeEpoch !== 0) ReaderTrialOriginalProbe.cancel(probeEpoch)
            try { await closeAnyReader(driver) } catch (error) { if (!failed) throw error as Error }
            if (!historyRestored && database !== null && history !== null) {
              await restoreAndVerify(database, history)
              removeSnapshot()
            }
            if (!settingsRestored && context !== null && database !== null && settings.length > 0) {
              await restoreProductionSpreadSettings(context, database, settings,
                savedMode, savedDoublePage, savedSpread)
            }
            await launchBackend('legacy', false)
          }
        })
    })
    return
  }

  if (selectedClass === 'ReaderProductionThumbnailSingletonEntryTrial') {
    describe(selectedClass, (): void => {
      it('keepsCoverAndTailThumbnailEntriesAsCenteredRtlSingletons', 0, async (): Promise<void> => {
        const driver = Driver.create()
        let context: common.UIAbilityContext | null = null
        let database: relationalStore.RdbStore | null = null
        let history: HistorySnapshot | null = null
        let settings: SettingSnapshot[] = []
        let savedMode: NhReaderMode = NhReaderMode.PAGED
        let savedDoublePage: boolean = false
        let savedSpread: NhReaderSpreadLayout = NhReaderSpreadLayout.JOINED
        let historyRestored = false
        let settingsRestored = false
        let probeEpoch = 0
        let failed = false
        try {
          await launchBackend('shared', true)
          context = await entryContext(driver)
          database = await store(context)
          history = await snapshotHistory(database)
          writeSnapshot(history)
          await ReaderPresentationService.restore(context)
          const presentation = ReaderPresentationService.snapshot()
          savedMode = presentation.mode
          savedDoublePage = presentation.doublePageEnabled
          savedSpread = presentation.spreadLayoutMode
          for (const key of ['reader_mode', 'reader_double_page_enabled', 'reader_spread_layout',
            `reader_column_mode:${GALLERY_ID}`]) {
            settings.push(new SettingSnapshot(key, await settingValue(database, key)))
          }
          await ReaderPresentationService.setMode(context, NhReaderMode.PAGED_RTL)
          await ReaderPresentationService.setDoublePageEnabled(context, true)
          await ReaderPresentationService.setSpreadLayout(context, NhReaderSpreadLayout.SPLIT)
          await ReaderSettingsRepository.saveColumnMode(context, GALLERY_ID, NhReaderColumnMode.EVEN_LEFT)
          await seedHistoryPage(database, 6)

          expect(connectNextNReaderBackendSelection().current()).assertEqual(NextNReaderBackend.SHARED)
          const coverSource = await findFullThumbnail(driver, 0)
          const coverSourceId = await coverSource.getId()
          const coverBefore = await coverSource.getBounds()
          probeEpoch = ReaderTrialOriginalProbe.arm(GALLERY_ID.toString(), 0)
          await capture(driver, 'singleton-cover-source')
          await coverSource.click()
          const coverHeld = await waitProductionSingletonHeld(driver, probeEpoch, 0)
          expect(await driver.findComponent(ON.id('legacy-reader-surface'))).assertNull()
          await capture(driver, 'singleton-cover-waiting')
          expect(ReaderTrialOriginalProbe.release(probeEpoch, coverHeld.requestId)).assertTrue()
          await waitProductionSingletonDelivered(driver, probeEpoch,
            coverHeld.requestId, coverHeld.reader.entryId, 0)
          await capture(driver, 'singleton-cover-settled')
          await closeAnyReader(driver)
          const coverReturned = await waitId(driver, coverSourceId)
          const coverAfter = await coverReturned.getBounds()
          expect(coverAfter.left).assertEqual(coverBefore.left)
          expect(coverAfter.top).assertEqual(coverBefore.top)
          expect(coverAfter.right).assertEqual(coverBefore.right)
          expect(coverAfter.bottom).assertEqual(coverBefore.bottom)
          await capture(driver, 'singleton-cover-closed')

          const tailSource = await findCurrentFullThumbnail(driver, 13)
          const tailSourceId = await tailSource.getId()
          const tailBefore = await tailSource.getBounds()
          probeEpoch = ReaderTrialOriginalProbe.arm(GALLERY_ID.toString(), 13)
          await capture(driver, 'singleton-tail-source')
          await tailSource.click()
          const tailHeld = await waitProductionSingletonHeld(driver, probeEpoch, 13)
          expect(await driver.findComponent(ON.id('legacy-reader-surface'))).assertNull()
          await capture(driver, 'singleton-tail-waiting')
          expect(ReaderTrialOriginalProbe.release(probeEpoch, tailHeld.requestId)).assertTrue()
          await waitProductionSingletonDelivered(driver, probeEpoch,
            tailHeld.requestId, tailHeld.reader.entryId, 13)
          await capture(driver, 'singleton-tail-settled')
          await closeAnyReader(driver)
          const tailReturned = await waitId(driver, tailSourceId)
          const tailAfter = await tailReturned.getBounds()
          expect(tailAfter.left).assertEqual(tailBefore.left)
          expect(tailAfter.top).assertEqual(tailBefore.top)
          expect(tailAfter.right).assertEqual(tailBefore.right)
          expect(tailAfter.bottom).assertEqual(tailBefore.bottom)
          await capture(driver, 'singleton-tail-closed')

          await restoreAndVerify(database, history)
          historyRestored = true
          removeSnapshot()
          await restoreProductionSpreadSettings(context, database, settings,
            savedMode, savedDoublePage, savedSpread)
          settingsRestored = true
          console.info('[ReaderProductionBackendTrial] thumbnailSingletonShared=true cover=0 tail=13 ' +
            'coverCentered=true tailCentered=true onePartEach=true deliveredBoth=true sourceRestoredBoth=true ' +
            'historyRestored=true settingsRestored=true')
        } catch (error) {
          failed = true
          try { await capture(driver, 'singleton-exception') } catch (_) {}
          throw error as Error
        } finally {
          if (probeEpoch !== 0) ReaderTrialOriginalProbe.cancel(probeEpoch)
          try { await closeAnyReader(driver) } catch (error) { if (!failed) throw error as Error }
          if (!historyRestored && database !== null && history !== null) {
            await restoreAndVerify(database, history)
            removeSnapshot()
          }
          if (!settingsRestored && context !== null && database !== null && settings.length > 0) {
            await restoreProductionSpreadSettings(context, database, settings,
              savedMode, savedDoublePage, savedSpread)
          }
          await launchBackend('legacy', false)
        }
      })
    })
    return
  }

  if (selectedClass === 'ReaderProductionThumbnailGridEntryTrial') {
    describe(selectedClass, (): void => {
      it('opensExactFullGridThumbnailThroughSharedBodyAndReturnsToGrid', 0, async (): Promise<void> => {
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
          await seedHistoryPage(database, 6)

          expect(connectNextNReaderBackendSelection().current()).assertEqual(NextNReaderBackend.SHARED)
          const source = await findFullThumbnail(driver, 2)
          const sourceId = await source.getId()
          const before = await source.getBounds()
          await capture(driver, 'grid-source')
          await source.click()
          expect(await waitSharedReady(driver)).assertEqual(2)
          expect(await driver.findComponent(ON.id('legacy-reader-surface'))).assertNull()
          expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
          for (let attempt = 0; attempt < 40; attempt++) {
            if (await driver.findComponent(ON.id('rkit-entry-preview-image')) === null &&
              await driver.findComponent(ON.id('rkit-entry-source-pending')) === null) break
            await driver.delayMs(100)
          }
          expect(await driver.findComponent(ON.id('rkit-entry-preview-image'))).assertNull()
          expect(await driver.findComponent(ON.id('rkit-entry-source-pending'))).assertNull()
          await capture(driver, 'grid-shared')
          await closeAnyReader(driver)
          const returned = await waitId(driver, sourceId)
          const after = await returned.getBounds()
          expect(after.left).assertEqual(before.left)
          expect(after.top).assertEqual(before.top)
          expect(after.right).assertEqual(before.right)
          expect(after.bottom).assertEqual(before.bottom)
          expect((await driver.findComponents(ON.type('Grid').within(ON.id('nextn-root-navigation')))).length)
            .assertEqual(1)
          await capture(driver, 'grid-closed')

          await restoreAndVerify(database, original)
          restored = true
          removeSnapshot()
          console.info('[ReaderProductionBackendTrial] thumbnailGridShared=true clicked=2 persistedBefore=6 ' +
            'sourceRestored=true debugTrialAbsent=true historyRestored=true')
        } catch (error) {
          failed = true
          try { await capture(driver, 'grid-exception') } catch (_) {}
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

  if (selectedClass === 'ReaderProductionThumbnailWideEntryTrial') {
    describe(selectedClass, (): void => {
      it('opensWideDetailGridThumbnailThroughSharedBodyAndReturnsToPane', 0, async (): Promise<void> => {
        const driver = Driver.create()
        let database: relationalStore.RdbStore | null = null
        let original: HistorySnapshot | null = null
        let mainWindow: window.Window | null = null
        let originalOrientation: window.Orientation | undefined = undefined
        let restored = false
        let failed = false
        try {
          await launchBackend('shared', true)
          const context = await entryContext(driver)
          database = await store(context)
          original = await snapshotHistory(database)
          writeSnapshot(original)
          await seedHistoryPage(database, 6)

          mainWindow = await window.getLastWindow(context)
          originalOrientation = mainWindow.getPreferredOrientation()
          await mainWindow.setPreferredOrientation(window.Orientation.LANDSCAPE)
          await driver.delayMs(1600)
          const display = await driver.getDisplaySize()
          expect(display.x > display.y).assertTrue()

          expect(connectNextNReaderBackendSelection().current()).assertEqual(NextNReaderBackend.SHARED)
          const source = await findWideDetailThumbnail(driver, 2)
          const sourceId = await source.getId()
          const before = await source.getBounds()
          await capture(driver, 'wide-source')
          await source.click()
          expect(await waitSharedReady(driver)).assertEqual(2)
          expect(await driver.findComponent(ON.id('legacy-reader-surface'))).assertNull()
          expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
          for (let attempt = 0; attempt < 40; attempt++) {
            if (await driver.findComponent(ON.id('rkit-entry-preview-image')) === null &&
              await driver.findComponent(ON.id('rkit-entry-source-pending')) === null) break
            await driver.delayMs(100)
          }
          expect(await driver.findComponent(ON.id('rkit-entry-preview-image'))).assertNull()
          expect(await driver.findComponent(ON.id('rkit-entry-source-pending'))).assertNull()
          await capture(driver, 'wide-shared')
          await closeAnyReader(driver)
          expect(await driver.findComponent(ON.id('gallery-detail-preview-pane')) !== null).assertTrue()
          const returned = await waitId(driver, sourceId)
          const after = await returned.getBounds()
          expect(after.left).assertEqual(before.left)
          expect(after.top).assertEqual(before.top)
          expect(after.right).assertEqual(before.right)
          expect(after.bottom).assertEqual(before.bottom)
          await capture(driver, 'wide-closed')

          await launchBackend('legacy', true)
          await waitBackendSelection(driver, NextNReaderBackend.LEGACY)
          const legacySource = await findWideDetailThumbnail(driver, 2)
          const legacySourceId = await legacySource.getId()
          const legacyBefore = await legacySource.getBounds()
          await legacySource.click()
          await waitLegacyReady(driver)
          await capture(driver, 'wide-legacy')
          await closeAnyReader(driver)
          const legacyReturned = await waitId(driver, legacySourceId)
          const legacyAfter = await legacyReturned.getBounds()
          expect(legacyAfter.left).assertEqual(legacyBefore.left)
          expect(legacyAfter.top).assertEqual(legacyBefore.top)
          expect(legacyAfter.right).assertEqual(legacyBefore.right)
          expect(legacyAfter.bottom).assertEqual(legacyBefore.bottom)
          await capture(driver, 'wide-legacy-closed')

          await restoreAndVerify(database, original)
          restored = true
          removeSnapshot()
          console.info('[ReaderProductionBackendTrial] thumbnailWideShared=true clicked=2 persistedBefore=6 ' +
            'sourceRestored=true debugTrialAbsent=true legacyCompared=true historyRestored=true')
        } catch (error) {
          failed = true
          try { await capture(driver, 'wide-exception') } catch (_) {}
          throw error as Error
        } finally {
          try { await closeAnyReader(driver) } catch (error) { if (!failed) throw error as Error }
          if (mainWindow !== null && originalOrientation !== undefined) {
            try {
              await mainWindow.setPreferredOrientation(originalOrientation)
              await driver.delayMs(800)
            } catch (error) { if (!failed) throw error as Error }
          }
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
