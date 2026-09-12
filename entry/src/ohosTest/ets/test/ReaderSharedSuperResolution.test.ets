import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import {
  AppStrings, NhReaderMode, NhReaderSpreadLayout, NhReaderSuperResolutionModel,
  ReaderPresentationService, ReaderSettingsRepository, ReaderSuperResolutionModelService,
} from 'shared'

const FIXTURE: string = '__rkit_local_fixture__'

async function entryContext(driver: Driver): Promise<common.UIAbilityContext> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
  for (let attempt = 0; attempt < 80; attempt++) {
    try {
      const ability = await delegator.getCurrentTopAbility()
      if (ability.context.abilityInfo.name === 'EntryAbility') return ability.context
    } catch (_) {}
    await driver.delayMs(100)
  }
  throw new Error('EntryAbility context unavailable')
}

async function waitImage(driver: Driver): Promise<void> {
  for (let attempt = 0; attempt < 60; attempt++) {
    if (await driver.findComponent(ON.type('Image').within(ON.id('rkit-image-viewport'))) !== null &&
      await driver.findComponent(ON.type('LoadingProgress').within(ON.id('rkit-image-viewport'))) === null) return
    await driver.delayMs(500)
  }
  expect(false).assertTrue()
}

async function waitApplied(single: boolean): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  for (let attempt = 0; attempt < 120; attempt++) {
    const result = await delegator.executeShellCommand(
      "hilog -x | grep -F '[NextNSharedSuperResolution] applied source=' | tail -40",
      10,
    )
    const output = result.stdResult ?? ''
    if (single ? output.includes('applied source=0') :
      output.includes('applied source=1') && output.includes('applied source=2')) return
    await new Promise<void>((resolve): void => { setTimeout(resolve, 500) })
  }
  expect(false).assertTrue()
}

async function capture(driver: Driver, name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  const cache = delegator.getAppContext().cacheDir
  const screen = `${cache}/rkit-shared-super-resolution-${name}.png`
  if (fileIo.accessSync(screen)) fileIo.unlinkSync(screen)
  expect((await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/rkit-shared-super-resolution-${name}.json`, 15)).exitCode).assertEqual(0)
  expect(await driver.screenCap(screen)).assertTrue()
}

async function assertEnhancedInformation(driver: Driver): Promise<void> {
  await (await driver.findComponent(ON.id('rkit-more'))).click()
  await driver.delayMs(300)
  await (await driver.findComponent(ON.id('rkit-image-info'))).click()
  await driver.delayMs(500)
  const expected = AppStrings.get('rkit_info_enhanced')
  const texts = await driver.findComponents(ON.type('Text'))
  let found: boolean = false
  for (const text of texts) {
    if ((await text.getText()).includes(expected)) { found = true; break }
  }
  expect(found).assertTrue()
  await capture(driver, 'single-info')
  const ok = await driver.findComponent(ON.text(AppStrings.get('rkit_ok')))
  if (ok !== null) await ok.click()
}

export default function readerSharedSuperResolutionTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  if (args['-s class'] !== 'ReaderSharedSuperResolutionTrial') return
  const spread = args['-s readerSharedSuperResolutionLayout'] === 'spread'
  describe('ReaderSharedSuperResolutionTrial', (): void => {
    it('hostPreparedDerivativeKeepsTheSharedReaderContract', 0, async (): Promise<void> => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      const driver = Driver.create()
      const context: common.UIAbilityContext = await entryContext(driver)
      const originalMode = await ReaderSettingsRepository.mode(context)
      const originalDouble = await ReaderSettingsRepository.doublePageEnabled(context)
      const originalSpread = await ReaderSettingsRepository.spreadLayout(context)
      const originalEnabled = await ReaderSettingsRepository.superResolutionEnabled(context)
      const originalModel = await ReaderSettingsRepository.superResolutionModel(context)
      const originalMaxHeight = await ReaderSettingsRepository.superResolutionMaxHeight(context)
      const models: NhReaderSuperResolutionModel[] = await ReaderSuperResolutionModelService.installedModels(context)
      expect(models.length > 0).assertTrue()
      const model = models.includes(originalModel) ? originalModel : models[0]
      try {
        await ReaderPresentationService.setMode(context, spread ? NhReaderMode.PAGED_RTL : NhReaderMode.PAGED)
        await ReaderPresentationService.setDoublePageEnabled(context, spread)
        await ReaderPresentationService.setSpreadLayout(context, NhReaderSpreadLayout.SPLIT)
        await ReaderPresentationService.setSuperResolutionModel(context, model)
        await ReaderPresentationService.setSuperResolutionMaxHeight(context, 2000)
        await ReaderPresentationService.setSuperResolutionEnabled(context, true)
        await delegator.startAbility({
          bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
          parameters: { readerLabWork: FIXTURE, readerLabChrome: 'true', readerLabPage: spread ? '1' : '0',
            readerLabVolumeKeys: 'false' },
        })
        await waitImage(driver)
        await waitApplied(!spread)
        await waitImage(driver)
        await capture(driver, spread ? 'spread' : 'single')
        if (!spread) await assertEnhancedInformation(driver)
        const close = await driver.findComponent(ON.id('rkit-close'))
        if (close !== null) await close.click()
        await driver.delayMs(500)
        expect(await driver.findComponent(ON.id('rkit-trial-navigation'))).assertNull()
      } finally {
        try { await ReaderPresentationService.setSuperResolutionEnabled(context, originalEnabled) } catch (_) {}
        try { await ReaderPresentationService.setSuperResolutionModel(context, originalModel) } catch (_) {}
        try { await ReaderPresentationService.setSuperResolutionMaxHeight(context, originalMaxHeight) } catch (_) {}
        try { await ReaderPresentationService.setMode(context, originalMode) } catch (_) {}
        try { await ReaderPresentationService.setDoublePageEnabled(context, originalDouble) } catch (_) {}
        try { await ReaderPresentationService.setSpreadLayout(context, originalSpread) } catch (_) {}
      }
    })
  })
}
