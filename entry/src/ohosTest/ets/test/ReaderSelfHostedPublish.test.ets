import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit'
import { AppStrings } from 'shared'

/** NextN self-hosted translation published through the shared surface (isolated endpoint). */
export default function readerSelfHostedPublishTrialTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  const work = args['-s readerLabWork']
  if (args['-s class'] !== 'ReaderSelfHostedPublishTrial' || typeof work !== 'string' || work.length === 0) return
  describe('ReaderSelfHostedPublishTrial', (): void => {
    it('publishesTheSelfHostedTranslationThroughTheSharedSurface', 0, async (): Promise<void> => {
      const driver = Driver.create()
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      const endpoint = (args['-s readerLabSelfHostedEndpoint'] as string) ?? ''
      await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
        parameters: { readerLabWork: work, readerLabChrome: 'true', readerLabPage: '0',
          readerLabEntryLayout: 'single', readerLabEntryDirection: 'ltr',
          readerLabSelfHostedEndpoint: endpoint, readerLabSelfHostedUser: 'nexte_qa',
          readerLabSelfHostedPassword: 'QaSidecar0728' } })
      for (let i = 0; i < 80; i++) {
        const vp = await driver.findComponent(ON.id('rkit-image-viewport'))
        const img = await driver.findComponent(ON.type('Image').within(ON.id('rkit-image-viewport')))
        const load = await driver.findComponent(ON.type('LoadingProgress').within(ON.id('rkit-image-viewport')))
        if (vp !== null && img !== null && load === null) break
        await driver.delayMs(400)
      }
      const showOriginal = AppStrings.get('reader_comic_translation_show_original')
      const failedLabel = AppStrings.get('reader_comic_translation_failed')
      const actionId = 'rkit-host-action-translate-page'
      let applied = false
      let hostOutcome = ''
      const more = await driver.findComponent(ON.id('rkit-more'))
      expect(more !== null).assertTrue()
      await more.click()
      await driver.delayMs(500)
      const action: Component | null = await driver.findComponent(ON.id(actionId))
      expect(action !== null).assertTrue()
      expect(await action.isEnabled()).assertTrue()
      await action.click()
      for (let attempt = 0; attempt < 540; attempt++) {
        const show = await driver.findComponent(ON.text(showOriginal))
        if (show !== null) { applied = true; break }
        const failed = await driver.findComponent(ON.text(failedLabel))
        if (failed !== null) { hostOutcome = failedLabel; break }
        await driver.delayMs(1000)
      }
      delegator.print('[SelfHostedPublish] applied=' + applied + ' hostOutcome=' + hostOutcome)
      expect(applied).assertTrue()
      const close = await driver.findComponent(ON.id('rkit-close'))
      if (close !== null) await close.click()
    })
  })
}
