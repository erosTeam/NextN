import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, MatchPattern, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { relationalStore } from '@kit.ArkData'
import { connectNextNReaderLabContextProbe } from 'reader'
import { ReaderPresentationService, ReaderSettingsRepository, NhReaderMode, NhReaderColumnMode,
  NhReaderSpreadLayout, connectReaderPresentation } from 'shared'

const DETAIL_OWNER: string = 'nextn-root-navigation'

class ActualTop { windowId: number = -1; id: string = ''; top: number = 0 }
class HostHolder { context: common.UIAbilityContext | null = null }
class PolicyCase {
  continuous: boolean = false
  vertical: boolean = false
  rtl: boolean = false
  spread: boolean = false
  split: boolean = false
  even: boolean = false
}
const SOURCE_PATTERN: string = '^reader-thumb-gallery-detail-[0-9]+-page-2$'

async function waitId(driver: Driver, id: string): Promise<Component> {
  for (let i = 0; i < 80; i++) {
    const found = await driver.findComponent(ON.id(id))
    if (found !== null) return found
    await driver.delayMs(250)
  }
  throw new Error('Missing endpoint: ' + id)
}
async function closeTrial(driver: Driver): Promise<void> {
  if (await driver.findComponent(ON.id('rkit-vertical-paged')) !== null) await driver.pressBack()
  const close = await driver.findComponent(ON.id('rkit-close'))
  if (close !== null) await close.click()
  else if (await driver.findComponent(ON.id('rkit-trial-navigation')) !== null ||
    await driver.findComponent(ON.id('rkit-entry-source-pending')) !== null ||
    await driver.findComponent(ON.id('rkit-phase')) !== null) await driver.pressBack()
  for (let i = 0; i < 40; i++) {
    if (await driver.findComponent(ON.id('rkit-trial-navigation')) === null &&
      await driver.findComponent(ON.id('rkit-chrome-page')) === null &&
      await driver.findComponent(ON.id('rkit-entry-source-pending')) === null &&
      await driver.findComponent(ON.id('rkit-phase')) === null) return
    await driver.delayMs(200)
  }
  throw new Error('Trial exit not confirmed')
}
async function capture(driver: Driver, name: string): Promise<void> {
  const d = abilityDelegatorRegistry.getAbilityDelegator(), cache = d.getAppContext().cacheDir
  // Host receives and independently parses the styled raw dump; no cross-sandbox file read.
  const result = await d.executeShellCommand('uitest dumpLayout -p /data/local/tmp/rkit-thumbnail-policy-' + name + '.json -a', 15)
  console.info('[ThumbnailPolicy] capture=' + name + ' exit=' + result.exitCode + ' result=' + result.stdResult)
  expect(result.exitCode).assertEqual(0)
  expect(await driver.screenCap(cache + '/rkit-thumbnail-policy-' + name + '.png')).assertTrue()
}
async function actualTop(driver: Driver, id: string): Promise<ActualTop> {
  await waitId(driver, id)
  expect((await driver.findComponents(ON.id(id))).length).assertEqual(1)
  const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()
  const win = await window.getLastWindow(ability.context)
  for (let i = 0; i < 40; i++) {
    const rect = win.getUIContext().getComponentUtils().getRectangleById(id)
    if (rect.size.width > 0 && rect.size.height > 0 && Number.isFinite(rect.windowOffset.y)) {
      const value = new ActualTop()
      const props = win.getWindowProperties()
      value.windowId = props.id; value.id = id; value.top = rect.windowOffset.y
      console.info('[ThumbnailPolicy] actualRect window=' + value.windowId + ' type=' + props.type +
        ' windowRect=' + JSON.stringify(props.windowRect) + ' id=' + id + ' rect=' + JSON.stringify(rect))
      return value
    }
    await driver.delayMs(100)
  }
  throw new Error('Actual component layout unavailable: ' + id)
}
async function findSource(driver: Driver): Promise<Component> {
  const pane = await waitId(driver, DETAIL_OWNER)
  const pb = await pane.getBounds()
  const lists = await driver.findComponents(ON.type('List').within(ON.id(DETAIL_OWNER)))
  const owners: Component[] = []
  for (const list of lists) {
    const b = await list.getBounds()
    if (b.left === pb.left && b.right === pb.right && b.top === pb.top && b.bottom === pb.bottom) owners.push(list)
  }
  if (owners.length !== 1) throw new Error('Detail metadata owner is not unique')
  const selector = ON.id(SOURCE_PATTERN, MatchPattern.REG_EXP).within(ON.id(DETAIL_OWNER))
  const source = await owners[0].scrollSearch(selector, true)
  if (source === null) throw new Error('Actual Detail source2 thumbnail missing')
  const matches = await driver.findComponents(selector)
  expect(matches.length).assertEqual(1)
  const id = await source.getId()
  expect(new RegExp(SOURCE_PATTERN).test(id)).assertTrue()
  return await driver.findComponent(ON.id(id))
}
async function page(driver: Driver): Promise<number> {
  return Number((await (await waitId(driver, 'rkit-chrome-page')).getText()).split('/')[0].trim())
}
async function bodyReady(driver: Driver, id: string): Promise<void> {
  for (let i = 0; i < 80; i++) {
    const images = await driver.findComponents(ON.type('Image').within(ON.id(id)))
    if (images.length > 0 &&
      await driver.findComponent(ON.type('LoadingProgress').within(ON.id(id))) === null &&
      await driver.findComponent(ON.id('^rkit-failure-page-[0-9]+$', MatchPattern.REG_EXP).within(ON.id(id))) === null &&
      await driver.findComponent(ON.id('rkit-entry-preview-image')) === null &&
      await driver.findComponent(ON.id('rkit-entry-source-pending')) === null) return
    await driver.delayMs(250)
  }
  throw new Error('Real source body did not complete handoff')
}
async function exercise(driver: Driver, label: string, policy: PolicyCase,
  stable: () => Promise<void>, previousSourceId: string = ''): Promise<string> {
  const source = await findSource(driver), sourceId = await source.getId(), before = await source.getBounds()
  expect(sourceId !== previousSourceId).assertTrue()
  await sourceReady(driver, sourceId)
  await stable()
  await capture(driver, label + '-source')
  console.info('[ThumbnailPolicy] click=' + Date.now() + ' source=' + sourceId + ' bounds=' + JSON.stringify(before))
  await (await driver.findComponent(ON.id(sourceId))).click()
  await waitId(driver, policy.continuous ? 'rkit-continuous-list' : 'rkit-native-pager')
  await bodyReady(driver, policy.continuous ? 'rkit-continuous-page-2' : 'rkit-image-viewport')
  expect(await page(driver)).assertEqual(3)
  const total = Number((await (await waitId(driver, 'rkit-chrome-page')).getText()).split('/')[1].trim())
  expect(total >= 6).assertTrue()
  if (!policy.continuous) {
    const a = await (await waitId(driver, 'rkit-part-2-whole')).getBounds()
    if (policy.spread) {
      const other = policy.even ? 1 : 3
      const b = await (await waitId(driver, 'rkit-part-' + other + '-whole')).getBounds()
      expect(a.left < b.left).assertEqual(policy.even ? policy.rtl : !policy.rtl)
      if (policy.split) {
        // Part rectangles are slots, not image pixels. This only checks inherited SPLIT topology.
        const viewport = await (await waitId(driver, 'rkit-image-viewport')).getBounds()
        expect(Math.abs((a.right - a.left) * 2 - (viewport.right - viewport.left)) <= 3).assertTrue()
      }
      await bodyReady(driver, 'rkit-part-' + other + '-whole')
    } else {
      expect(await driver.findComponent(ON.id('rkit-part-1-whole').within(ON.id('rkit-image-viewport')))).assertNull()
      expect(await driver.findComponent(ON.id('rkit-part-3-whole').within(ON.id('rkit-image-viewport')))).assertNull()
    }
  }
  await stable()
  await capture(driver, label + '-settled')
  let initialTop: ActualTop | null = null
  if (policy.continuous) {
    initialTop = await actualTop(driver, 'rkit-continuous-page-2')
    const listTop = await actualTop(driver, 'rkit-continuous-list')
    expect(initialTop.windowId).assertEqual(listTop.windowId)
    expect(Math.abs(initialTop.top - listTop.top) <= 2).assertTrue()
  }
  const b = await (await waitId(driver, policy.continuous ? 'rkit-continuous-list' : 'rkit-image-viewport')).getBounds()
  const x = Math.round((b.left + b.right) / 2), y = Math.round((b.top + b.bottom) / 2)
  const vertical = policy.continuous || policy.vertical
  const offset = Math.round((vertical ? b.bottom - b.top : b.right - b.left) * (policy.continuous ? 0.17 : 0.31))
  const sign = policy.rtl && !vertical ? -1 : 1
  await driver.swipe(vertical ? x : x + offset * sign, vertical ? y + offset : y,
    vertical ? x : x - offset * sign, vertical ? y - offset : y, 700)
  await driver.delayMs(900)
  await stable()
  await capture(driver, label + '-gesture')
  if (policy.continuous && initialTop !== null) {
    const moved = await actualTop(driver, 'rkit-continuous-page-2')
    expect(moved.windowId).assertEqual(initialTop.windowId)
    expect(moved.id).assertEqual(initialTop.id)
    expect(Math.abs(moved.top - initialTop.top) > 2).assertTrue()
  }
  else expect(await page(driver)).assertEqual(policy.spread ? (policy.even ? 4 : 5) : 4)
  await closeTrial(driver)
  await stable()
  const returned = await waitId(driver, sourceId), after = await returned.getBounds()
  expect(after.left).assertEqual(before.left); expect(after.top).assertEqual(before.top)
  expect(after.right).assertEqual(before.right); expect(after.bottom).assertEqual(before.bottom)
  expect(await driver.findComponent(ON.id('reader-overlay-navigation'))).assertNull()
  await capture(driver, label + '-closed')
  return sourceId
}

async function sourceReady(driver: Driver, sourceId: string): Promise<void> {
  // NextN does not publish the delay-once probe for normal timing. Do not arm that artificial delay here.
  for (let i = 0; i < 60; i++) {
    const image = await driver.findComponent(ON.type('Image').within(ON.id(sourceId)))
    if (image !== null) {
      const b = await image.getBounds()
      if (b.right > b.left && b.bottom > b.top) return
    }
    await driver.delayMs(250)
  }
  throw new Error('Actual source2 image node is unavailable')
}
class SavedKey {
  key: string
  value: string | null
  constructor(key: string, value: string | null) { this.key = key; this.value = value }
}
async function readKey(store: relationalStore.RdbStore, key: string): Promise<string | null> {
  const row = await store.querySql('SELECT value, typeof(value) FROM reader_settings WHERE key=?', [key])
  try {
    if (!row.goToFirstRow()) return null
    expect(row.getString(1)).assertEqual('text')
    const value = row.getString(0)
    expect(row.goToNextRow()).assertFalse()
    return value
  } finally { row.close() }
}
async function progressSignature(store: relationalStore.RdbStore, gallery: number): Promise<string> {
  const row = await store.querySql('SELECT last_read_index,has_read_progress FROM reading_history WHERE gallery_id=?', [gallery])
  try { return row.goToFirstRow() ? JSON.stringify([row.getLong(0), row.getLong(1)]) : 'absent' }
  finally { row.close() }
}
export default function readerThumbnailInitialPolicyTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  if (args['-s class'] === 'ReaderThumbnailPolicyCaptureSmoke') {
    describe('ReaderThumbnailPolicyCaptureSmoke', (): void => {
      it('actualRootAndStyledCaptureWithoutFixtureWrites', 0, async (): Promise<void> => {
        const driver = Driver.create(), d = abilityDelegatorRegistry.getAbilityDelegator()
        await d.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
        await waitId(driver, 'nextn-root-navigation')
        await actualTop(driver, 'nextn-root-navigation')
        await capture(driver, 'capture-smoke')
        console.info('[ThumbnailPolicy] captureSmoke=true actualRootMeasured=true fixtureWrites=0 hostRawReviewRequired=true')
      })
    })
    return
  }
  if (args['-s class'] !== 'ReaderThumbnailInitialPolicyTrial') return
  const work = args['-s readerLabWork']
  describe('ReaderThumbnailInitialPolicyTrial', (): void => {
    it('savedContinuousAndRtlSpreadFromActualSource2', 0, async (): Promise<void> => {
      expect(work).assertEqual('678049')
      const gallery = 678049, driver = Driver.create(), d = abilityDelegatorRegistry.getAbilityDelegator()
      const holder = new HostHolder(), probe = connectNextNReaderLabContextProbe()
      const epoch = probe.arm('678049', (ctx: common.UIAbilityContext): void => { holder.context = ctx })
      try {
        await d.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility', parameters: {
          readerLabWork: '678049', readerLabPage: '2', readerLabChrome: 'true', readerLabVolumeKeys: 'false' } })
        for (let i = 0; i < 60 && holder.context === null; i++) await driver.delayMs(250)
        if (holder.context === null) throw new Error('No actual entry Context')
        expect(holder.context.databaseDir.endsWith('/entry')).assertTrue()
        console.info('[ThumbnailPolicy] actualHostDir=' + holder.context.databaseDir)
        await waitId(driver, 'rkit-close')
      } finally { probe.cancel(epoch); await closeTrial(driver) }
      const ctx = holder.context
      if (ctx === null) throw new Error('Missing actual entry Context')
      await capture(driver, 'preflight')
      await ReaderPresentationService.restore(ctx)
      const live = ReaderPresentationService.snapshot()
      expect(live.mode).assertEqual(await ReaderSettingsRepository.mode(ctx))
      expect(live.doublePageEnabled).assertEqual(await ReaderSettingsRepository.doublePageEnabled(ctx))
      expect(live.spreadLayoutMode).assertEqual(await ReaderSettingsRepository.spreadLayout(ctx))
      const store = await relationalStore.getRdbStore(ctx, { name: 'NextN.db', securityLevel: relationalStore.SecurityLevel.S3 })
      const saved: SavedKey[] = []
      for (const key of ['reader_mode', 'reader_double_page_enabled', 'reader_spread_layout']) saved.push(new SavedKey(key, await readKey(store, key)))
      const columnKey = 'reader_column_mode:' + gallery
      const columnRaw = await readKey(store, columnKey)
      const column = await ReaderSettingsRepository.columnMode(ctx, gallery)
      let failed = false
      let previousSourceId: string = ''
      const selectedCase = args['-s readerThumbnailCase'] ?? ''
      expect(selectedCase === '' || selectedCase === 'rtl-spread' || selectedCase === 'continuous').assertTrue()
      try {
        for (let index = 0; index < 2; index++) {
          if (selectedCase === 'rtl-spread' && index === 0) continue
          if (selectedCase === 'continuous' && index === 1) continue
          const mode = index === 0 ? NhReaderMode.VERTICAL : NhReaderMode.PAGED_RTL
          await ReaderPresentationService.setMode(ctx, mode)
          await ReaderPresentationService.setDoublePageEnabled(ctx, index === 1)
          await ReaderPresentationService.setSpreadLayout(ctx, NhReaderSpreadLayout.SPLIT)
          const policy = new PolicyCase()
          policy.continuous = index === 0; policy.rtl = index === 1; policy.spread = index === 1
          policy.split = index === 1
          policy.even = column === NhReaderColumnMode.EVEN_LEFT
          let progress: string | null = null
          const stable = async (): Promise<void> => {
            expect(await ReaderSettingsRepository.mode(ctx)).assertEqual(mode)
            expect(await ReaderSettingsRepository.doublePageEnabled(ctx)).assertEqual(index === 1)
            expect(await ReaderSettingsRepository.spreadLayout(ctx)).assertEqual(NhReaderSpreadLayout.SPLIT)
            expect(await readKey(store, columnKey)).assertEqual(columnRaw)
            expect(await ReaderSettingsRepository.columnMode(ctx, gallery)).assertEqual(column)
            const current = await progressSignature(store, gallery)
            if (progress === null) progress = current
            else expect(current).assertEqual(progress)
          }
          await d.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility', parameters: {
            readerLabWork: '678049', readerLabPage: '2', readerLabChrome: 'true',
            readerLabThumbnailEntry: 'true', readerLabVolumeKeys: 'false' } })
          // startAbility returns before the newly pushed Detail replaces the preceding source scope.
          if (previousSourceId.length > 0) {
            for (let attempt = 0; attempt < 80 && await driver.findComponent(ON.id(previousSourceId)) !== null; attempt++) {
              await driver.delayMs(250)
            }
            expect(await driver.findComponent(ON.id(previousSourceId))).assertNull()
          }
          previousSourceId = await exercise(driver, index === 0 ? 'continuous' : 'rtl-spread', policy, stable, previousSourceId)
        }
      } catch (error) {
        failed = true
        console.error('[ThumbnailPolicy] failure=' + (error as Error).message)
        try { await capture(driver, 'exception') } catch (_) {}
        throw error as Error
      } finally {
        try { await closeTrial(driver) } catch (error) {
          console.error('[ThumbnailPolicy] close_failure=' + (error as Error).message)
          if (!failed) throw error as Error
        } finally {
          let restored = true
          try {
            await ReaderPresentationService.setMode(ctx, live.mode)
            await ReaderPresentationService.setDoublePageEnabled(ctx, live.doublePageEnabled)
            await ReaderPresentationService.setSpreadLayout(ctx, live.spreadLayoutMode)
          } catch (_) { restored = false }
          finally {
            for (const item of saved) {
              try {
                if (item.value === null) await store.executeSql('DELETE FROM reader_settings WHERE key=?', [item.key])
                else await store.executeSql('INSERT INTO reader_settings (key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value', [item.key, item.value])
                expect(await readKey(store, item.key)).assertEqual(item.value)
              } catch (_) { restored = false }
            }
            connectReaderPresentation().mode = live.mode
            connectReaderPresentation().doublePageEnabled = live.doublePageEnabled
            connectReaderPresentation().spreadLayoutMode = live.spreadLayoutMode
          }
          expect(await readKey(store, columnKey)).assertEqual(columnRaw)
          console.info('[ThumbnailPolicy] restored=' + restored + ' exactRdbTextKeys=3 columnReadOnly=true')
          expect(restored).assertTrue()
        }
      }
    })
  })
}
