import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import {
  AppStrings, ComicTranslationModelCatalogService, connectLlmSourceProfiles, LLM_CONSUMER_MANGA_TRANSLATION,
  LlmConsumerBinding, LlmSourceSecretVault, supportsMangaTranslation,
} from 'shared'

/**
 * Process-local only: the device already stores a capable, keyed manga-capable
 * source; ordinary User Settings own its persisted binding. This derives the
 * binding the shared translation config needs without writing any preference.
 */
async function bindExistingMangaSourceInProcess(): Promise<string> {
  const state = connectLlmSourceProfiles()
  if (state.mangaBinding.configured()) return 'already-bound'
  const comment = state.commentBinding
  let sourceProfileId = ''
  let modelId = ''
  if (comment.configured()) {
    const bound = state.findById(comment.sourceProfileId)
    if (bound !== null && supportsMangaTranslation(bound)) {
      sourceProfileId = bound.sourceProfileId
      modelId = comment.modelId
    }
  }
  if (sourceProfileId.length === 0) {
    for (const profile of state.profiles) {
      if (supportsMangaTranslation(profile) &&
        (await LlmSourceSecretVault.readApiKey(
          abilityDelegatorRegistry.getAbilityDelegator().getAppContext() as common.UIAbilityContext,
          profile.sourceProfileId)).length > 0) {
        sourceProfileId = profile.sourceProfileId
        break
      }
    }
  }
  if (sourceProfileId.length === 0) return 'no-capable-source'
  if (modelId.length === 0) {
    try {
      const models: string[] = await ComicTranslationModelCatalogService.fetchSource(
        abilityDelegatorRegistry.getAbilityDelegator().getAppContext() as common.UIAbilityContext,
        sourceProfileId)
      if (models.length > 0) modelId = models[0]
    } catch (_error) {}
  }
  if (modelId.length === 0) return 'no-model'
  const binding = new LlmConsumerBinding()
  binding.consumerId = LLM_CONSUMER_MANGA_TRANSLATION
  binding.sourceProfileId = sourceProfileId
  binding.modelId = modelId
  state.mangaBinding = binding
  return 'bound-in-process:' + modelId
}

async function waitId(driver: Driver, id: string, attempts: number = 160): Promise<Component> {
  for (let attempt: number = 0; attempt < attempts; attempt++) {
    const component = await driver.findComponent(ON.id(id))
    if (component !== null) return component
    await driver.delayMs(250)
  }
  throw new Error('component unavailable: ' + id)
}

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
      // Drive the ordinary production route: the shared translation config is only
      // built when the host request carries productionSources, so the Lab route can
      // never reach the translate action. The rehearsal endpoint still travels in
      // the Debug Want and is applied in-process without writing any user setting.
      await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
        parameters: { nextn_reader_backend: 'shared', nextn_gallery_id: Number(work),
          readerLabSelfHostedEndpoint: endpoint, readerLabSelfHostedUser: 'nexte_qa',
          readerLabSelfHostedPassword: 'QaSidecar0728' } })
      for (let i = 0; i < 80; i++) {
        const vp = await driver.findComponent(ON.id('rkit-image-viewport'))
        const img = await driver.findComponent(ON.type('Image').within(ON.id('rkit-image-viewport')))
        const load = await driver.findComponent(ON.type('LoadingProgress').within(ON.id('rkit-image-viewport')))
        if (vp !== null && img !== null && load === null) break
        await driver.delayMs(400)
      }
      // Non-secret, derived facts that decide whether the missing action is an
      // environment prerequisite (no bound manga source) or a shared-layer
      // capability mismatch (bound source lacking responses/imageInput).
      try {
        let context: common.UIAbilityContext | null = null
        for (let attempt: number = 0; attempt < 80 && context === null; attempt++) {
          try {
            const ability = await delegator.getCurrentTopAbility()
            if (ability.context.abilityInfo.name === 'EntryAbility') {
              context = ability.context as common.UIAbilityContext
            }
          } catch (_) {}
          if (context === null) await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 100) })
        }
        if (context === null) throw new Error('EntryAbility context unavailable')
        const profiles = connectLlmSourceProfiles()
        const binding = profiles.mangaBinding
        const bound = binding.configured() ? profiles.findById(binding.sourceProfileId) : null
        for (const profile of profiles.profiles) {
          let keyPresent = false
          try { keyPresent = (await LlmSourceSecretVault.readApiKey(context, profile.sourceProfileId)).length > 0 } catch (_) {}
          delegator.print('[SelfHostedPublish] profile id=' + profile.sourceProfileId.substring(0, 8) +
            ' type=' + profile.sourceType +
            ' capsResponses=' + profile.capabilities.responses +
            ' capsImageInput=' + profile.capabilities.imageInput +
            ' capsChatCompletions=' + profile.capabilities.chatCompletions +
            ' capsModelCatalog=' + profile.capabilities.modelCatalog +
            ' keyPresent=' + keyPresent +
            ' revision=' + profile.sourceRevision +
            ' supportsManga=' + supportsMangaTranslation(profile))
        }
        const cb = profiles.commentBinding
        const mb = profiles.mangaBinding
        delegator.print('[SelfHostedPublish] commentBinding configured=' + cb.configured() +
          ' profilePrefix=' + cb.sourceProfileId.substring(0, 8) +
          ' modelId=' + cb.modelId)
        delegator.print('[SelfHostedPublish] mangaBinding configured=' + mb.configured() +
          ' profilePrefix=' + mb.sourceProfileId.substring(0, 8) +
          ' modelId=' + mb.modelId)
        delegator.print('[SelfHostedPublish] profiles=' + profiles.profiles.length +
          ' bindingConfigured=' + binding.configured() +
          ' modelIdSet=' + (binding.modelId.length > 0) +
          ' foundProfile=' + (bound !== null) +
          ' sourceType=' + (bound === null ? 'none' : bound.sourceType) +
          ' capsResponses=' + (bound !== null && bound.capabilities.responses) +
          ' capsImageInput=' + (bound !== null && bound.capabilities.imageInput) +
          ' capsChatCompletions=' + (bound !== null && bound.capabilities.chatCompletions) +
          ' supportsManga=' + (bound !== null && supportsMangaTranslation(bound)))
      } catch (error) {
        delegator.print('[SelfHostedPublish] profileFactsUnavailable=' + String(error))
      }
      await (await waitId(driver, 'gallery-detail-read-action', 160)).click()
      const surface = await waitId(driver, 'rkit-reading-surface', 240)
      // Bind only after the host has restored its own persisted profiles; binding
      // earlier is overwritten by that restore.
      const boundManga = await bindExistingMangaSourceInProcess()
      delegator.print('[SelfHostedPublish] bind=' + boundManga)
      const showOriginal = AppStrings.get('reader_comic_translation_show_original')
      const failedLabel = AppStrings.get('reader_comic_translation_failed')
      const actionId = 'rkit-host-action-translate-page'
      let applied = false
      let hostOutcome = ''
      // Ordinary shared Reader starts immersive; one center tap reveals chrome.
      let more: Component | null = await driver.findComponent(ON.id('rkit-more'))
      if (more === null) {
        const bounds = await surface.getBounds()
        await driver.click(Math.round((bounds.left + bounds.right) / 2),
          Math.round((bounds.top + bounds.bottom) / 2))
        await driver.delayMs(600)
        for (let attempt: number = 0; attempt < 20 && more === null; attempt++) {
          more = await driver.findComponent(ON.id('rkit-more'))
          if (more === null) await driver.delayMs(250)
        }
      }
      expect(more !== null).assertTrue()
      await (more as Component).click()
      await driver.delayMs(500)
      let action: Component | null = null
      for (let attempt: number = 0; attempt < 20 && action === null; attempt++) {
        action = await driver.findComponent(ON.id(actionId))
        if (action !== null) break
        const menuItems = await driver.findComponents(ON.type('MenuItem')) ?? []
        const seen: string[] = []
        for (const item of menuItems) { try { seen.push(await item.getId()) } catch (_) {} }
        delegator.print('[SelfHostedPublish] menu-try=' + attempt + ' items=' + seen.join(','))
        const moreRetry = await driver.findComponent(ON.id('rkit-more'))
        if (moreRetry !== null) { await moreRetry.click(); await driver.delayMs(600) }
      }
      const found: Component | null = action
      if (found === null) {
        delegator.print('[SelfHostedPublish] action-present=false')
        expect(false).assertTrue()
        return
      }
      delegator.print('[SelfHostedPublish] action-present=true enabled=' + String(await found.isEnabled()))
      expect(await found.isEnabled()).assertTrue()
      await found.click()
      for (let attempt = 0; attempt < 1500; attempt++) {
        const show = await driver.findComponent(ON.text(showOriginal))
        if (show !== null) { applied = true; break }
        const failed = await driver.findComponent(ON.text(failedLabel))
        if (failed !== null) { hostOutcome = failedLabel; break }
        await driver.delayMs(1000)
      }
      delegator.print('[SelfHostedPublish] manga=' + boundManga +
        ' applied=' + applied + ' hostOutcome=' + hostOutcome)
      expect(applied).assertTrue()
      const close = await driver.findComponent(ON.id('rkit-close'))
      if (close !== null) await close.click()
    })
  })
}
