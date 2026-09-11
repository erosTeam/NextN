import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { connectNextNReaderLabContextProbe } from 'reader'
import { ReaderPresentationService, ReaderSettingsRepository, NhReaderMode, NhReaderColumnMode,
  NhReaderSpreadLayout, connectReaderPresentation } from 'shared'

class InitialSetting {
  key: string
  value: string | null
  constructor(key: string, value: string | null) { this.key = key; this.value = value }
}

class InitialContextHolder {
  context: common.UIAbilityContext | null = null
}

async function initialValue(store: relationalStore.RdbStore, key: string): Promise<string | null> {
  const rows = await store.querySql('SELECT value FROM reader_settings WHERE key = ? LIMIT 1', [key])
  try { return rows.goToFirstRow() ? rows.getString(0) : null } finally { rows.close() }
}

async function initialCapture(driver: Driver, name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  const cache = delegator.getAppContext().cacheDir
  if (typeof driver.dumpLayout === 'function') expect(await driver.dumpLayout(`${cache}/rkit-initial-${name}.json`)).assertTrue()
  else expect((await delegator.executeShellCommand(`uitest dumpLayout -p /data/local/tmp/rkit-initial-${name}.json`, 15)).exitCode).assertEqual(0)
  expect(await driver.screenCap(`${cache}/rkit-initial-${name}.png`)).assertTrue()
}

async function initialWait(driver: Driver, id: string): Promise<void> {
  for (let attempt = 0; attempt < 60; attempt++) {
    if (await driver.findComponent(ON.id(id)) !== null) return
    await driver.delayMs(250)
  }
  expect(await driver.findComponent(ON.id(id)) !== null).assertTrue()
}

async function initialClose(driver: Driver): Promise<void> {
  if (await driver.findComponent(ON.id('rkit-vertical-paged')) !== null) {
    await driver.pressBack(); await driver.delayMs(300)
  }
  const close = await driver.findComponent(ON.id('rkit-close'))
  if (close !== null) await close.click()
  await driver.delayMs(600)
  expect(await driver.findComponent(ON.id('rkit-chrome-page'))).assertNull()
}

async function initialPage(driver: Driver): Promise<number> {
  return Number((await (await driver.findComponent(ON.id('rkit-chrome-page'))).getText()).split('/')[0].trim())
}

async function initialBody(driver: Driver, container: string): Promise<void> {
  for (let attempt = 0; attempt < 60; attempt++) {
    if (await driver.findComponent(ON.type('Image').within(ON.id(container))) !== null &&
      await driver.findComponent(ON.type('LoadingProgress').within(ON.id(container))) === null) return
    await driver.delayMs(300)
  }
  expect(false).assertTrue()
}

/** Real entry handoff. Only four declared local preference keys are temporarily changed. */
export default function readerInitialPolicyTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  const work = args['-s readerLabWork']
  const selectedCase = args['-s readerInitialCase']
  if (args['-s class'] !== 'ReaderInitialPolicyTrial' || typeof work !== 'string') return
  describe('ReaderInitialPolicyTrial', (): void => {
    it('savedPolicyBeforeFirstSurfaceAndExplicitOverride', 0, async (): Promise<void> => {
      const gallery = Number(work)
      expect(Number.isSafeInteger(gallery) && gallery > 0).assertTrue()
      expect(selectedCase === undefined || selectedCase === '3').assertTrue()
      const driver = Driver.create(), delegator = abilityDelegatorRegistry.getAbilityDelegator()
      const holder = new InitialContextHolder()
      const probe = connectNextNReaderLabContextProbe()
      const epoch = probe.arm(work, (received: common.UIAbilityContext): void => { holder.context = received })
      try {
        await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility', parameters: {
          readerLabWork: work, readerLabPage: '2', readerLabChrome: 'true', readerLabVolumeKeys: 'false' } })
        for (let attempt = 0; attempt < 60 && holder.context === null; attempt++) await driver.delayMs(250)
        expect(holder.context !== null).assertTrue()
        if (holder.context === null) throw new Error('No actual Lab context received')
        console.info(`[ReaderInitialPolicyTest] actualHostDir=${holder.context.databaseDir}`)
        expect(holder.context.databaseDir.endsWith('/entry')).assertTrue()
        await initialWait(driver, 'rkit-close')
      } finally {
        probe.cancel(epoch)
        await initialClose(driver)
      }
      const context = holder.context
      if (context === null) throw new Error('No actual Lab context received')
      console.info(`[ReaderInitialPolicyTest] bound_database=${context.databaseDir}`)
      await ReaderPresentationService.restore(context)
      const live = ReaderPresentationService.snapshot()
      const durableMode = await ReaderSettingsRepository.mode(context)
      const durableDouble = await ReaderSettingsRepository.doublePageEnabled(context)
      const durableSpread = await ReaderSettingsRepository.spreadLayout(context)
      console.info(`[ReaderInitialPolicyTest] entry_baseline durable=${durableMode},${durableDouble},${durableSpread} live=${live.mode},${live.doublePageEnabled},${live.spreadLayoutMode}`)
      expect(live.mode).assertEqual(durableMode)
      expect(live.doublePageEnabled).assertEqual(durableDouble)
      expect(live.spreadLayoutMode).assertEqual(durableSpread)
      const originalColumn = await ReaderSettingsRepository.columnMode(context, gallery)
      const store = await relationalStore.getRdbStore(context,
        { name: 'NextN.db', securityLevel: relationalStore.SecurityLevel.S3 })
      const saved: InitialSetting[] = []
      for (const key of ['reader_mode', 'reader_double_page_enabled', 'reader_spread_layout', `reader_column_mode:${gallery}`]) {
        saved.push(new InitialSetting(key, await initialValue(store, key)))
      }
      console.info(`[ReaderInitialPolicyTest] baseline mode=${live.mode} double=${live.doublePageEnabled} spread=${live.spreadLayoutMode} column=${originalColumn}`)
      let primaryFailure = false
      try {
        for (let index = selectedCase === '3' ? 3 : 0; index < (selectedCase === '3' ? 4 : 6); index++) {
          const mode = index === 1 ? NhReaderMode.PAGED_VERTICAL : index === 2 ? NhReaderMode.VERTICAL :
            index === 3 || index === 5 ? NhReaderMode.PAGED_RTL : NhReaderMode.PAGED
          const doublePage = index !== 0
          const spread = index === 3 || index === 5 ? NhReaderSpreadLayout.SPLIT : NhReaderSpreadLayout.JOINED
          const column = index === 3 ? NhReaderColumnMode.EVEN_LEFT : NhReaderColumnMode.ODD_LEFT
          await ReaderPresentationService.setMode(context, mode)
          await ReaderPresentationService.setDoublePageEnabled(context, doublePage)
          await ReaderPresentationService.setSpreadLayout(context, spread)
          await ReaderSettingsRepository.saveColumnMode(context, gallery, column)
          expect(await ReaderSettingsRepository.mode(context)).assertEqual(mode)
          expect(await ReaderSettingsRepository.doublePageEnabled(context)).assertEqual(doublePage)
          expect(await ReaderSettingsRepository.spreadLayout(context)).assertEqual(spread)
          expect(await ReaderSettingsRepository.columnMode(context, gallery)).assertEqual(column)
          console.info(`[ReaderInitialPolicyTest] saved_column gallery=${gallery} databaseDir=${context.databaseDir} column=${await ReaderSettingsRepository.columnMode(context, gallery)}`)
          if (index === 5) {
            await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility', parameters: {
              readerLabWork: work, readerLabPage: '2', readerLabChrome: 'true', readerLabVolumeKeys: 'false',
              readerLabEntryLayout: 'single', readerLabEntryDirection: 'ltr' } })
          } else {
            await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility', parameters: {
              readerLabWork: work, readerLabPage: '2', readerLabChrome: 'true', readerLabVolumeKeys: 'false' } })
          }
          await initialWait(driver, 'rkit-chrome-page')
          const initial = await initialPage(driver)
          console.info(`[ReaderInitialPolicyTest] case=${index} initialPage=${initial} sourceIndex=2`)
          expect(initial).assertEqual(3)
          const total = Number((await (await driver.findComponent(ON.id('rkit-chrome-page'))).getText()).split('/')[1].trim())
          expect(total >= 6).assertTrue()
          if (index === 2) {
            await initialWait(driver, 'rkit-continuous-list')
            await initialWait(driver, 'rkit-continuous-page-2')
            expect(await driver.findComponent(ON.id('rkit-native-pager'))).assertNull()
          } else {
            await initialWait(driver, 'rkit-native-pager')
            await initialWait(driver, 'rkit-part-2-whole')
            if (index === 3 || index === 4) {
              const other = index === 3 ? 1 : 3
              await initialWait(driver, `rkit-part-${other}-whole`)
              const a = await (await driver.findComponent(ON.id('rkit-part-2-whole').within(ON.id('rkit-image-viewport')))).getBounds()
              const b = await (await driver.findComponent(ON.id(`rkit-part-${other}-whole`).within(ON.id('rkit-image-viewport')))).getBounds()
              expect(a.left < b.left).assertTrue()
              const viewport = await (await driver.findComponent(ON.id('rkit-image-viewport'))).getBounds()
              if (index === 3) expect(Math.abs((a.right - a.left) * 2 - (viewport.right - viewport.left)) < 3).assertTrue()
              console.info(`[ReaderInitialPolicyTest] case=${index} part2=${a.left},${a.top},${a.right},${a.bottom} other=${other}:${b.left},${b.top},${b.right},${b.bottom}`)
            } else {
              expect(await driver.findComponent(ON.id('rkit-part-1-whole').within(ON.id('rkit-image-viewport')))).assertNull()
              expect(await driver.findComponent(ON.id('rkit-part-3-whole').within(ON.id('rkit-image-viewport')))).assertNull()
            }
          }
          await initialBody(driver, index === 2 ? 'rkit-continuous-page-2' : 'rkit-image-viewport')
          await initialCapture(driver, `case-${index}-initial`)
          if (index !== 2) {
            const b = await (await driver.findComponent(ON.id('rkit-image-viewport'))).getBounds()
            const x = Math.round((b.left + b.right) / 2), y = Math.round((b.top + b.bottom) / 2)
            const vertical = index === 1, rtl = index === 3
            const offset = Math.round((vertical ? b.bottom - b.top : b.right - b.left) * 0.31) * (rtl ? -1 : 1)
            await driver.swipe(vertical ? x : x + offset, vertical ? y + offset : y,
              vertical ? x : x - offset, vertical ? y - offset : y, 700)
            await driver.delayMs(700)
            const after = await initialPage(driver)
            console.info(`[ReaderInitialPolicyTest] case=${index} afterSwipePage=${after}`)
            expect(after).assertEqual(index === 3 ? 4 : index === 4 ? 5 : 4)
            await initialCapture(driver, `case-${index}-after`)
          }
          await initialClose(driver)
        }
      } catch (error) {
        primaryFailure = true
        console.error(`[ReaderInitialPolicyTest] failure=${(error as Error).message}`)
        try { await initialCapture(driver, 'exception') } catch (_) {}
        throw error as Error
      } finally {
        try { await initialClose(driver) } catch (error) {
          console.error(`[ReaderInitialPolicyTest] close_failure=${(error as Error).message}`)
          if (!primaryFailure) { primaryFailure = true; throw error as Error }
        } finally {
          try {
            await ReaderPresentationService.setMode(context, live.mode)
            await ReaderPresentationService.setDoublePageEnabled(context, live.doublePageEnabled)
            await ReaderPresentationService.setSpreadLayout(context, live.spreadLayoutMode)
            await ReaderSettingsRepository.saveColumnMode(context, gallery, originalColumn)
          } finally {
            let rawRestored = true
            for (const item of saved) {
              try {
                if (item.value === null) await store.executeSql('DELETE FROM reader_settings WHERE key = ?', [item.key])
                else await store.executeSql('INSERT INTO reader_settings (key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value', [item.key, item.value])
                expect(await initialValue(store, item.key)).assertEqual(item.value)
              } catch (error) {
                rawRestored = false
                console.error(`[ReaderInitialPolicyTest] restore_failed key=${item.key} error=${(error as Error).message}`)
              }
            }
            connectReaderPresentation().mode = live.mode
            connectReaderPresentation().doublePageEnabled = live.doublePageEnabled
            connectReaderPresentation().spreadLayoutMode = live.spreadLayoutMode
            console.info(`[ReaderInitialPolicyTest] restored mode=${live.mode} double=${live.doublePageEnabled} spread=${live.spreadLayoutMode} column=${originalColumn} exactRawKeys=${rawRestored ? 4 : 0}`)
            expect(rawRestored).assertTrue()
          }
        }
      }
    })
  })
}
