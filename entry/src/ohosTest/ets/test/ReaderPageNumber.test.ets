import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { relationalStore } from '@kit.ArkData'
import { connectNextNReaderLabContextProbe } from 'reader'
import { AppStrings, ReaderSettingsRepository, ReaderPresentationService, NhReaderMode } from 'shared'

class HostContext { value: common.UIAbilityContext | null = null }
async function waitId(d: Driver, id: string): Promise<Component> {
  for (let i = 0; i < 60; i++) {
    const c = await d.findComponent(ON.id(id))
    if (c !== null) return c
    await d.delayMs(250)
  }
  throw new Error('pageNumber missing:' + id)
}
async function capture(d: Driver, name: string): Promise<void> {
  const a = abilityDelegatorRegistry.getAbilityDelegator()
  expect((await a.executeShellCommand('uitest dumpLayout -p /data/local/tmp/rkit-page-number-' + name + '.json -a', 15)).exitCode).assertEqual(0)
  expect(await d.screenCap(a.getAppContext().cacheDir + '/rkit-page-number-' + name + '.png')).assertTrue()
  console.info('[ReaderPageNumberTest] capture=' + name)
}
async function body(d: Driver, index: number): Promise<void> {
  for (let i = 0; i < 60; i++) {
    const image = await d.findComponent(ON.type('Image').within(ON.id('rkit-part-' + index + '-whole')))
    if (image !== null && await d.findComponent(ON.type('LoadingProgress').within(ON.id('rkit-part-' + index + '-whole'))) === null) {
      const b = await image.getBounds()
      if (b.right > b.left && b.bottom > b.top) {
        console.info('[ReaderPageNumberTest] source=' + index + ' bounds=' + JSON.stringify(b))
        return
      }
    }
    await d.delayMs(250)
  }
  throw new Error('pageNumber body unavailable:' + index)
}
async function center(d: Driver): Promise<void> {
  await waitId(d, 'rkit-image-viewport')
  const a = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()
  const w = await window.getLastWindow(a.context)
  const r = w.getUIContext().getComponentUtils().getRectangleById('rkit-image-viewport')
  expect(r.size.width > 0 && r.size.height > 0).assertTrue()
  console.info('[ReaderPageNumberTest] window=' + w.getWindowProperties().id + ' rect=' + JSON.stringify(r))
  await d.click(Math.round(r.windowOffset.x + r.size.width / 2), Math.round(r.windowOffset.y + r.size.height / 2))
  await d.delayMs(700)
}
async function closeTrial(d: Driver): Promise<void> {
  if (await d.findComponent(ON.id('rkit-trial-navigation')) === null &&
    await d.findComponent(ON.id('rkit-phase')) === null &&
    await d.findComponent(ON.id('rkit-reading-surface')) === null) return
  let close = await d.findComponent(ON.id('rkit-close'))
  if (close === null) { await center(d); close = await d.findComponent(ON.id('rkit-close')) }
  if (close !== null) await close.click()
  else await d.pressBack()
  for (let i = 0; i < 60; i++) {
    if (await d.findComponent(ON.id('rkit-trial-navigation')) === null &&
      await d.findComponent(ON.id('rkit-phase')) === null &&
      await d.findComponent(ON.id('rkit-reading-surface')) === null) return
    await d.delayMs(250)
  }
  throw new Error('pageNumber trial exit unconfirmed')
}
async function assertHost(): Promise<void> {
  const a = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()
  expect(a.context.abilityInfo.name).assertEqual('EntryAbility')
  expect(a.context.applicationInfo.name).assertEqual('com.erosteam.nextn')
  const w = await window.getLastWindow(a.context)
  const r = w.getUIContext().getComponentUtils().getRectangleById('nextn-root-navigation')
  expect(r.size.width > 0 && r.size.height > 0).assertTrue()
  console.info('[ReaderPageNumberTest] exitHost=NextN window=' + w.getWindowProperties().id + ' root=' + JSON.stringify(r))
}
async function launch(d: Driver): Promise<void> {
  await abilityDelegatorRegistry.getAbilityDelegator().startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
    parameters: { readerLabWork: '678049', readerLabPage: '2', readerLabChrome: 'true', readerLabVolumeKeys: 'false' } })
  await waitId(d, 'rkit-close'); await body(d, 2)
}
async function title(d: Driver, key: string): Promise<Component> {
  const selector = ON.text(AppStrings.get(key))
  let found = await d.findComponent(selector)
  if (found === null) {
    const owners = await d.findComponents(ON.type('List'))
    expect(owners.length).assertEqual(1)
    found = await owners[0].scrollSearch(selector, true)
  }
  if (found === null) throw new Error('pageNumber settings title unavailable:' + key)
  expect((await d.findComponents(selector)).length).assertEqual(1)
  return found
}
async function readingSettings(d: Driver): Promise<void> {
  if (await d.findComponent(ON.text(AppStrings.get('settings_reader_show_page_number'))) !== null) return
  const me = await d.findComponent(ON.text(AppStrings.get('tab_me')))
  if (me !== null) await me.click()
  await (await title(d, 'settings_reader')).click()
  await title(d, 'settings_reader_show_page_number')
}
async function setFromUi(d: Driver, ctx: common.UIAbilityContext, enabled: boolean): Promise<void> {
  await readingSettings(d)
  if (await ReaderSettingsRepository.showPageNumber(ctx) !== enabled) {
    await (await title(d, 'settings_reader_show_page_number')).click()
  }
  for (let i = 0; i < 60; i++) {
    if (await ReaderSettingsRepository.showPageNumber(ctx) === enabled &&
      ReaderPresentationService.snapshot().showPageNumber === enabled) return
    await d.delayMs(100)
  }
  throw new Error('pageNumber normal UI save unconfirmed')
}
async function raw(store: relationalStore.RdbStore): Promise<string | null> {
  const r = await store.querySql('SELECT value,typeof(value) FROM reader_settings WHERE key=?', ['reader_show_page_number'])
  try {
    if (!r.goToFirstRow()) return null
    expect(r.getString(1)).assertEqual('text')
    const value = r.getString(0)
    expect(r.goToNextRow()).assertFalse()
    return value
  } finally { r.close() }
}
async function exercise(d: Driver, enabled: boolean, rtl: boolean, name: string): Promise<void> {
  await launch(d)
  expect(Number((await (await waitId(d, 'rkit-chrome-page')).getText()).split('/')[0].trim())).assertEqual(3)
  await center(d)
  expect(await d.findComponent(ON.id('rkit-chrome-page'))).assertNull()
  expect(await d.findComponent(ON.id('rkit-persistent-page')) !== null).assertEqual(enabled)
  await body(d, 2); await capture(d, name + '-hidden')
  const a = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()
  const w = await window.getLastWindow(a.context)
  const r = w.getUIContext().getComponentUtils().getRectangleById('rkit-image-viewport')
  const left = Math.round(r.windowOffset.x + r.size.width * 0.19)
  const right = Math.round(r.windowOffset.x + r.size.width * 0.81)
  const y = Math.round(r.windowOffset.y + r.size.height * 0.5)
  await d.swipe(rtl ? left : right, y, rtl ? right : left, y, 700)
  await d.delayMs(700); await body(d, 3)
  expect(await d.findComponent(ON.id('rkit-persistent-page')) !== null).assertEqual(enabled)
  await capture(d, name + '-turned')
  await center(d)
  expect(Number((await (await waitId(d, 'rkit-chrome-page')).getText()).split('/')[0].trim())).assertEqual(4)
  await body(d, 3); await capture(d, name + '-chrome')
  await closeTrial(d)
}
/** Normal settings UI only; no direct preference or history mutation. */
export default function readerPageNumberTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  if (args['-s class'] !== 'ReaderPageNumberTrial') return
  describe('ReaderPageNumberTrial', (): void => {
    it('normalUiSavedPageNumber', 0, async (): Promise<void> => {
      expect(args['-s readerLabWork']).assertEqual('678049')
      const d = Driver.create(), holder = new HostContext(), probe = connectNextNReaderLabContextProbe()
      const epoch = probe.arm('678049', (ctx: common.UIAbilityContext): void => { holder.value = ctx })
      try {
        await launch(d)
        for (let i = 0; i < 60 && holder.value === null; i++) await d.delayMs(250)
      } finally { probe.cancel(epoch); await closeTrial(d) }
      const ctx = holder.value
      if (ctx === null) throw new Error('pageNumber actual context missing')
      expect(ctx.databaseDir.endsWith('/entry')).assertTrue()
      const saved = ReaderPresentationService.snapshot()
      expect(saved.showPageNumber).assertEqual(await ReaderSettingsRepository.showPageNumber(ctx))
      expect(saved.mode === NhReaderMode.PAGED || saved.mode === NhReaderMode.PAGED_RTL).assertTrue()
      expect(saved.doublePageEnabled).assertFalse()
      const store = await relationalStore.getRdbStore(ctx, { name: 'NextN.db', securityLevel: relationalStore.SecurityLevel.S3 })
      const original = await raw(store)
      if (original !== null) expect(original === 'true' || original === 'false').assertTrue()
      let failed = false, mayWrite = false
      try {
        if (original === null) {
          console.info('[ReaderPageNumberTest] matrix=OPEN reason=originalKeyAbsent readonly=true')
          await exercise(d, saved.showPageNumber, saved.mode === NhReaderMode.PAGED_RTL, 'readonly')
        } else {
          mayWrite = true
          await setFromUi(d, ctx, false)
          await exercise(d, false, saved.mode === NhReaderMode.PAGED_RTL, 'false')
          await setFromUi(d, ctx, true)
          await exercise(d, true, saved.mode === NhReaderMode.PAGED_RTL, 'true')
        }
      } catch (error) {
        failed = true
        try { await capture(d, 'exception') } catch (_) {}
        throw error as Error
      } finally {
        try { await closeTrial(d) } catch (error) { if (!failed) throw error as Error }
        finally {
          if (mayWrite) await setFromUi(d, ctx, saved.showPageNumber)
          expect(await raw(store)).assertEqual(original)
          expect(ReaderPresentationService.snapshot().showPageNumber).assertEqual(saved.showPageNumber)
          console.info('[ReaderPageNumberTest] restored=true exactPresence=true normalUiOnly=true')
          await assertHost()
          await capture(d, 'exit')
        }
      }
    })
  })
}
