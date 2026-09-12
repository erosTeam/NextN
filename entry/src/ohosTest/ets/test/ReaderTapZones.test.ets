import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { relationalStore } from '@kit.ArkData'
import { connectNextNReaderLabContextProbe } from 'reader'
import { ReaderPresentationService, ReaderSettingsRepository, NhReaderMode, NhReaderTapZoneLayout,
  NhReaderTapZoneInvert, connectReaderPresentation } from 'shared'

class ContextHolder { context: common.UIAbilityContext | null = null }
class StoredKey {
  key: string
  value: string | null
  constructor(key: string, value: string | null) { this.key = key; this.value = value }
}
class Geometry {
  id: string = ''
  windowId: number = -1
  left: number = 0
  top: number = 0
  width: number = 0
  height: number = 0
}
async function waitId(driver: Driver, id: string): Promise<Component> {
  for (let i = 0; i < 80; i++) {
    const c = await driver.findComponent(ON.id(id))
    if (c !== null) return c
    await driver.delayMs(250)
  }
  throw new Error('Missing component: ' + id)
}
async function capture(driver: Driver, name: string): Promise<void> {
  const d = abilityDelegatorRegistry.getAbilityDelegator()
  const result = await d.executeShellCommand('uitest dumpLayout -p /data/local/tmp/rkit-tap-zones-' + name + '.json -a', 15)
  console.info('[ReaderTapZonesTest] capture=' + name + ' exit=' + result.exitCode)
  expect(result.exitCode).assertEqual(0)
  expect(await driver.screenCap(d.getAppContext().cacheDir + '/rkit-tap-zones-' + name + '.png')).assertTrue()
}
async function rect(driver: Driver, id: string): Promise<Geometry> {
  await waitId(driver, id)
  expect((await driver.findComponents(ON.id(id))).length).assertEqual(1)
  const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()
  const win = await window.getLastWindow(ability.context)
  for (let i = 0; i < 40; i++) {
    const r = win.getUIContext().getComponentUtils().getRectangleById(id)
    if (r.size.width > 0 && r.size.height > 0 && Number.isFinite(r.windowOffset.y)) {
      const props = win.getWindowProperties(), value = new Geometry()
      value.id = id; value.windowId = props.id
      value.left = r.windowOffset.x; value.top = r.windowOffset.y
      value.width = r.size.width; value.height = r.size.height
      console.info('[ReaderTapZonesTest] geometry=' + JSON.stringify(value) + ' windowRect=' + JSON.stringify(props.windowRect))
      return value
    }
    await driver.delayMs(100)
  }
  throw new Error('Actual layout unavailable: ' + id)
}
async function closeTrial(driver: Driver): Promise<void> {
  if (await driver.findComponent(ON.id('rkit-image-info')) !== null ||
    await driver.findComponent(ON.id('rkit-vertical-paged')) !== null) await dismissMenu(driver)
  let close = await driver.findComponent(ON.id('rkit-close'))
  if (close === null && await driver.findComponent(ON.id('rkit-trial-navigation')) !== null) {
    const viewport = await rect(driver, await driver.findComponent(ON.id('rkit-continuous-list')) !== null ?
      'rkit-continuous-list' : 'rkit-image-viewport')
    await driver.click(Math.round(viewport.left + viewport.width / 2), Math.round(viewport.top + viewport.height / 2))
    await driver.delayMs(500)
    close = await driver.findComponent(ON.id('rkit-close'))
  }
  if (close !== null) await close.click()
  else if (await driver.findComponent(ON.id('rkit-trial-navigation')) !== null) await driver.pressBack()
  for (let i = 0; i < 40; i++) {
    if (await driver.findComponent(ON.id('rkit-trial-navigation')) === null &&
      await driver.findComponent(ON.id('rkit-phase')) === null) return
    await driver.delayMs(200)
  }
  throw new Error('Trial exit not confirmed')
}
async function dismissMenu(driver: Driver, expectedIndex: number | null = null): Promise<void> {
  await driver.pressBack()
  let dismissed = false
  for (let i = 0; i < 60; i++) {
    if (await driver.findComponent(ON.id('rkit-image-info')) === null &&
      await driver.findComponent(ON.id('rkit-vertical-paged')) === null &&
      await driver.findComponent(ON.id('rkit-spread-layout')) === null) {
      dismissed = true
      break
    }
    await driver.delayMs(100)
  }
  expect(dismissed).assertTrue()
  const continuous = await driver.findComponent(ON.id('rkit-continuous-list')) !== null
  await rect(driver, continuous ? 'rkit-continuous-list' : 'rkit-image-viewport')
  if (expectedIndex !== null) await source(driver, expectedIndex, continuous)
  // Let the native dismissal layout commit after semantic disappearance, before one new tap.
  await driver.delayMs(200)
  console.info('[ReaderTapZonesTest] menuDismissedAt=' + Date.now() + ' continuous=' + continuous + ' source=' + expectedIndex)
}
async function source(driver: Driver, index: number, continuous: boolean): Promise<void> {
  const id = continuous ? 'rkit-continuous-page-' + index : 'rkit-part-' + index + '-whole'
  for (let i = 0; i < 80; i++) {
    const part = await driver.findComponent(ON.id(id))
    const body = await driver.findComponent(ON.type('Image').within(ON.id(id)))
    if (part !== null && body !== null) {
      const b = await body.getBounds()
      if (b.right > b.left && b.bottom > b.top) {
        console.info('[ReaderTapZonesTest] actualSource=' + index + ' continuous=' + continuous + ' imageBounds=' + JSON.stringify(b))
        return
      }
    }
    await driver.delayMs(250)
  }
  throw new Error('Expected actual source body unavailable: ' + index)
}
async function tap(driver: Driver, viewport: Geometry, y: number): Promise<void> {
  await driver.click(Math.round(viewport.left + viewport.width * 0.5), Math.round(viewport.top + viewport.height * y))
  await driver.delayMs(700)
}
async function hideChrome(driver: Driver, viewport: Geometry): Promise<void> {
  if (await driver.findComponent(ON.id('rkit-chrome-page')) !== null) await tap(driver, viewport, 0.5)
  expect(await driver.findComponent(ON.id('rkit-chrome-page'))).assertNull()
}
async function showChrome(driver: Driver, viewport: Geometry): Promise<void> {
  if (await driver.findComponent(ON.id('rkit-chrome-page')) === null) await tap(driver, viewport, 0.5)
  await waitId(driver, 'rkit-chrome-page')
}
async function launch(driver: Driver): Promise<void> {
  await abilityDelegatorRegistry.getAbilityDelegator().startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
    parameters: { readerLabWork: '678049', readerLabPage: '2', readerLabChrome: 'true', readerLabVolumeKeys: 'false' } })
  await waitId(driver, 'rkit-close')
}
async function readKey(store: relationalStore.RdbStore, key: string): Promise<string | null> {
  const row = await store.querySql('SELECT value,typeof(value) FROM reader_settings WHERE key=?', [key])
  try {
    if (!row.goToFirstRow()) return null
    expect(row.getString(1)).assertEqual('text')
    const value = row.getString(0)
    expect(row.goToNextRow()).assertFalse()
    return value
  } finally { row.close() }
}
async function history(store: relationalStore.RdbStore): Promise<string> {
  const row = await store.querySql('SELECT last_read_index,has_read_progress FROM reading_history WHERE gallery_id=?', [678049])
  try { return row.goToFirstRow() ? JSON.stringify([row.getLong(0), row.getLong(1)]) : 'absent' }
  finally { row.close() }
}
export default function readerTapZonesTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  if (args['-s class'] !== 'ReaderTapZonesTrial') return
  describe('ReaderTapZonesTrial', (): void => {
    it('savedLShapePagedAndContinuousWithZoomMenuIsolation', 0, async (): Promise<void> => {
      expect(args['-s readerLabWork']).assertEqual('678049')
      const driver = Driver.create(), holder = new ContextHolder(), probe = connectNextNReaderLabContextProbe()
      const epoch = probe.arm('678049', (context: common.UIAbilityContext): void => { holder.context = context })
      try {
        await launch(driver)
        for (let i = 0; i < 60 && holder.context === null; i++) await driver.delayMs(250)
        if (holder.context === null) throw new Error('Actual entry Context missing')
        expect(holder.context.databaseDir.endsWith('/entry')).assertTrue()
        console.info('[ReaderTapZonesTest] actualHostDir=' + holder.context.databaseDir)
      } finally { probe.cancel(epoch); await closeTrial(driver) }
      const ctx = holder.context
      if (ctx === null) throw new Error('No entry Context')
      await ReaderPresentationService.restore(ctx)
      const live = ReaderPresentationService.snapshot()
      expect(live.mode).assertEqual(await ReaderSettingsRepository.mode(ctx))
      expect(live.doublePageEnabled).assertEqual(await ReaderSettingsRepository.doublePageEnabled(ctx))
      expect(live.tapZoneLayoutPaged).assertEqual(await ReaderSettingsRepository.tapZoneLayoutPaged(ctx))
      expect(live.tapZoneInvertPaged).assertEqual(await ReaderSettingsRepository.tapZoneInvertPaged(ctx))
      expect(live.tapZoneLayoutContinuous).assertEqual(await ReaderSettingsRepository.tapZoneLayoutContinuous(ctx))
      expect(live.tapZoneInvertContinuous).assertEqual(await ReaderSettingsRepository.tapZoneInvertContinuous(ctx))
      const store = await relationalStore.getRdbStore(ctx, { name: 'NextN.db', securityLevel: relationalStore.SecurityLevel.S3 })
      const saved: StoredKey[] = [], readonlyKeys: StoredKey[] = []
      for (const key of ['reader_mode', 'reader_double_page_enabled', 'reader_tap_zone_layout_paged', 'reader_tap_zone_invert_paged',
        'reader_tap_zone_layout_continuous', 'reader_tap_zone_invert_continuous']) saved.push(new StoredKey(key, await readKey(store, key)))
      for (const key of ['reader_tap_zone_layout', 'reader_tap_zone_invert', 'reader_column_mode:678049']) {
        readonlyKeys.push(new StoredKey(key, await readKey(store, key)))
      }
      const originalHistory = await history(store)
      const unchanged = async (): Promise<void> => {
        for (const item of readonlyKeys) expect(await readKey(store, item.key)).assertEqual(item.value)
        expect(await history(store)).assertEqual(originalHistory)
      }
      let failed = false
      try {
        await ReaderPresentationService.setMode(ctx, NhReaderMode.PAGED_RTL)
        await ReaderPresentationService.setDoublePageEnabled(ctx, false)
        await ReaderPresentationService.setTapZoneLayoutPaged(ctx, NhReaderTapZoneLayout.L_SHAPED)
        await ReaderPresentationService.setTapZoneInvertPaged(ctx, NhReaderTapZoneInvert.NONE)
        await ReaderPresentationService.setTapZoneLayoutContinuous(ctx, NhReaderTapZoneLayout.L_SHAPED)
        await ReaderPresentationService.setTapZoneInvertContinuous(ctx, NhReaderTapZoneInvert.NONE)
        expect(await ReaderSettingsRepository.mode(ctx)).assertEqual(NhReaderMode.PAGED_RTL)
        expect(await ReaderSettingsRepository.doublePageEnabled(ctx)).assertFalse()
        expect(await ReaderSettingsRepository.tapZoneLayoutPaged(ctx)).assertEqual(NhReaderTapZoneLayout.L_SHAPED)
        expect(await ReaderSettingsRepository.tapZoneInvertPaged(ctx)).assertEqual(NhReaderTapZoneInvert.NONE)
        expect(await ReaderSettingsRepository.tapZoneLayoutContinuous(ctx)).assertEqual(NhReaderTapZoneLayout.L_SHAPED)
        expect(await ReaderSettingsRepository.tapZoneInvertContinuous(ctx)).assertEqual(NhReaderTapZoneInvert.NONE)
        await launch(driver); await source(driver, 2, false)
        const viewport = await rect(driver, 'rkit-image-viewport')
        await hideChrome(driver, viewport); await capture(driver, 'paged-initial')
        await tap(driver, viewport, 0.2); await source(driver, 1, false); await capture(driver, 'paged-previous')
        await hideChrome(driver, viewport)
        await tap(driver, viewport, 0.8); await source(driver, 2, false); await capture(driver, 'paged-next')
        await showChrome(driver, viewport); await source(driver, 2, false)
        await (await waitId(driver, 'rkit-more')).click(); await waitId(driver, 'rkit-image-info')
        await source(driver, 2, false); await capture(driver, 'paged-more'); await dismissMenu(driver, 2)
        await hideChrome(driver, viewport)
        const image = await waitId(driver, 'rkit-part-2-whole')
        const before = await image.getBounds()
        await driver.doubleClick(Math.round(viewport.left + viewport.width / 2), Math.round(viewport.top + viewport.height / 2))
        await driver.delayMs(700)
        const after = await (await waitId(driver, 'rkit-part-2-whole')).getBounds()
        expect(after.right - after.left > (before.right - before.left) * 1.5).assertTrue()
        await source(driver, 2, false); await capture(driver, 'zoomed')
        await showChrome(driver, viewport); await source(driver, 2, false)
        await capture(driver, 'zoom-menu-shown')
        await (await waitId(driver, 'rkit-more')).click(); await waitId(driver, 'rkit-image-info')
        await source(driver, 2, false); await capture(driver, 'zoom-more'); await dismissMenu(driver, 2)
        await hideChrome(driver, viewport); await source(driver, 2, false)
        await capture(driver, 'zoom-menu-hidden')
        console.info('[ReaderTapZonesTest] zoomMenuObserved=true samePidViewportScaleLogAndImagesRequired=true retryIsolation=UNVERIFIED')
        await closeTrial(driver); await unchanged()
        await ReaderPresentationService.setMode(ctx, NhReaderMode.VERTICAL)
        expect(await ReaderSettingsRepository.mode(ctx)).assertEqual(NhReaderMode.VERTICAL)
        await launch(driver); await source(driver, 2, true)
        const list = await rect(driver, 'rkit-continuous-list')
        await hideChrome(driver, list)
        const initial = await rect(driver, 'rkit-continuous-page-2')
        expect(initial.windowId).assertEqual(list.windowId)
        expect(Math.abs(initial.top - list.top) <= 2).assertTrue()
        expect(initial.height > list.height * 2).assertTrue()
        await capture(driver, 'continuous-initial')
        await tap(driver, list, 0.8); await source(driver, 2, true)
        const down = await rect(driver, 'rkit-continuous-page-2')
        expect(down.windowId).assertEqual(initial.windowId); expect(down.id).assertEqual(initial.id)
        expect(Math.abs(initial.top - down.top - list.height * 0.75) <= 8).assertTrue()
        await capture(driver, 'continuous-next')
        await tap(driver, list, 0.2); await source(driver, 2, true)
        const up = await rect(driver, 'rkit-continuous-page-2')
        expect(up.windowId).assertEqual(initial.windowId); expect(up.id).assertEqual(initial.id)
        expect(Math.abs(up.top - down.top - list.height * 0.75) <= 8).assertTrue()
        expect(Math.abs(up.top - initial.top) <= 8).assertTrue()
        await capture(driver, 'continuous-previous')
        await showChrome(driver, list); await source(driver, 2, true)
        await (await waitId(driver, 'rkit-more')).click(); await waitId(driver, 'rkit-image-info')
        const menu = await rect(driver, 'rkit-continuous-page-2')
        expect(Math.abs(menu.top - up.top) <= 2).assertTrue()
        await capture(driver, 'continuous-more'); await dismissMenu(driver, 2)
        await closeTrial(driver); await unchanged(); await capture(driver, 'closed')
      } catch (error) {
        failed = true
        console.error('[ReaderTapZonesTest] failure=' + (error as Error).message)
        try { await capture(driver, 'exception') } catch (_) {}
        throw error as Error
      } finally {
        try { await closeTrial(driver) } catch (error) {
          console.error('[ReaderTapZonesTest] closeFailure=' + (error as Error).message)
          if (!failed) throw error as Error
        } finally {
          let restored = true
          const restores: Array<() => Promise<void>> = [
            async (): Promise<void> => { await ReaderPresentationService.setMode(ctx, live.mode) },
            async (): Promise<void> => { await ReaderPresentationService.setDoublePageEnabled(ctx, live.doublePageEnabled) },
            async (): Promise<void> => { await ReaderPresentationService.setTapZoneLayoutPaged(ctx, live.tapZoneLayoutPaged) },
            async (): Promise<void> => { await ReaderPresentationService.setTapZoneInvertPaged(ctx, live.tapZoneInvertPaged) },
            async (): Promise<void> => { await ReaderPresentationService.setTapZoneLayoutContinuous(ctx, live.tapZoneLayoutContinuous) },
            async (): Promise<void> => { await ReaderPresentationService.setTapZoneInvertContinuous(ctx, live.tapZoneInvertContinuous) }
          ]
          for (const restore of restores) { try { await restore() } catch (_) { restored = false } }
          for (const item of saved) {
            try {
              if (item.value === null) await store.executeSql('DELETE FROM reader_settings WHERE key=?', [item.key])
              else await store.executeSql('INSERT INTO reader_settings (key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value', [item.key, item.value])
              expect(await readKey(store, item.key)).assertEqual(item.value)
            } catch (_) { restored = false }
          }
          const state = connectReaderPresentation()
          state.mode = live.mode; state.doublePageEnabled = live.doublePageEnabled
          state.tapZoneLayoutPaged = live.tapZoneLayoutPaged; state.tapZoneInvertPaged = live.tapZoneInvertPaged
          state.tapZoneLayoutContinuous = live.tapZoneLayoutContinuous; state.tapZoneInvertContinuous = live.tapZoneInvertContinuous
          await unchanged()
          console.info('[ReaderTapZonesTest] restored=' + restored + ' exactEntryTextKeys=6 legacyAndColumnReadOnly=true noSyncFlush=true')
          expect(restored).assertTrue()
        }
      }
    })
  })
}
