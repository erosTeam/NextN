import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import {
  AppStrings, ComicTranslationModelCatalogService, connectLlmSourceProfiles, LLM_CONSUMER_MANGA_TRANSLATION,
  ComicResponsesCallConfig, ComicResponsesClient, ComicTranslationErrorClassifier,
  ComicTranslationRuntimeService, LlmConsumerBinding, LlmSourceRuntimeResolver, LlmSourceSecretVault,
  supportsMangaTranslation,
} from 'shared'

/**
 * Process-local only: the device already stores a capable, keyed manga-capable
 * source; ordinary User Settings own its persisted binding. This derives the
 * binding the shared translation config needs without writing any preference.
 */
async function bindExistingMangaSourceInProcess(modelOverride: string): Promise<string> {
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
  if (modelOverride.length === 0) {
    try {
      const catalog: string[] = await ComicTranslationModelCatalogService.fetchSource(
        abilityDelegatorRegistry.getAbilityDelegator().getAppContext() as common.UIAbilityContext,
        sourceProfileId)
      abilityDelegatorRegistry.getAbilityDelegator().print(
        '[SelfHostedPublish] catalog=' + catalog.slice(0, 12).join('|'))
    } catch (error) {
      abilityDelegatorRegistry.getAbilityDelegator().print(
        '[SelfHostedPublish] catalogUnavailable=' + String(error))
    }
  }
  if (modelId.length === 0) {
    try {
      const models: string[] = await ComicTranslationModelCatalogService.fetchSource(
        abilityDelegatorRegistry.getAbilityDelegator().getAppContext() as common.UIAbilityContext,
        sourceProfileId)
      if (models.length > 0) modelId = models[0]
    } catch (_error) {}
  }
  if (modelOverride.length > 0) modelId = modelOverride
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
  const selectedClass = args['-s class']
  if (typeof work !== 'string' || work.length === 0) return
  if (selectedClass !== 'ReaderSelfHostedPublishTrial' &&
    selectedClass !== 'ReaderLegacySelfHostedPublishTrial' &&
    selectedClass !== 'ReaderSelfHostedProviderProbeTrial') return
  if (selectedClass === 'ReaderSelfHostedPublishTrial') {
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
      const modelOverride = (args['-s readerLabTranslationModel'] as string) ?? ''
      const boundManga = await bindExistingMangaSourceInProcess(modelOverride)
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
      // The applied label is a menu item, so poll it by reopening the shared
      // overflow menu; the failure copy surfaces in the Reader host status strip
      // and is visible without opening the menu.
      for (let attempt = 0; attempt < 1500; attempt++) {
        const failed = await driver.findComponent(ON.text(failedLabel))
        if (failed !== null) { hostOutcome = failedLabel; break }
        if (attempt % 15 === 0) {
          const reopen = await driver.findComponent(ON.id('rkit-more'))
          if (reopen !== null) {
            await reopen.click()
            await driver.delayMs(400)
            if (await driver.findComponent(ON.text(showOriginal)) !== null) { applied = true; break }
            await driver.pressBack()
            await driver.delayMs(200)
          }
        }
        await driver.delayMs(1000)
      }
      delegator.print('[SelfHostedPublish] manga=' + boundManga +
        ' applied=' + applied + ' hostOutcome=' + hostOutcome)
      expect(applied).assertTrue()
      const close = await driver.findComponent(ON.id('rkit-close'))
      if (close !== null) await close.click()
    })
  })
  return
  }
  if (selectedClass === 'ReaderSelfHostedProviderProbeTrial') {
    describe('ReaderSelfHostedProviderProbeTrial', (): void => {
      it('classifiesTheBoundMangaSourceTextCall', 0, async (): Promise<void> => {
        const delegator = abilityDelegatorRegistry.getAbilityDelegator()
        // The host restores its persisted LLM profiles on EntryAbility create, so
        // the app must be running before the binding can be derived in-process.
        await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
        for (let attempt: number = 0; attempt < 80; attempt++) {
          if (connectLlmSourceProfiles().profiles.length > 0) break
          await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 250) })
        }
        // The Reader reads the secret vault through its UIAbility context; an app
        // context cannot read the same key, so the probe must match the Reader.
        let context: common.UIAbilityContext | null = null
        for (let attempt: number = 0; attempt < 80 && context === null; attempt++) {
          try {
            const ability = await delegator.getCurrentTopAbility()
            if (ability.context.abilityInfo.name === 'EntryAbility') {
              context = ability.context as common.UIAbilityContext
            }
          } catch (_) {}
          if (context === null) await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 250) })
        }
        if (context === null) throw new Error('EntryAbility context unavailable')
        const boundManga = await bindExistingMangaSourceInProcess('')
        delegator.print('[ProviderProbe] bind=' + boundManga)
        // Read-only, non-secret classification of the bound source's own text
        // call. It reuses the exact resolver and client the Reader uses, with a
        // tiny text-only prompt, so the recorded code identifies whether the
        // host LLM 5xx is an endpoint/credential condition rather than a
        // manga-payload condition. No user setting is written.
        try {
          const runtime = await LlmSourceRuntimeResolver.resolveManga(context, false)
          delegator.print('[ProviderProbe] source=' + runtime.sourceProfileId.substring(0, 8) +
            ' type=' + runtime.sourceType + ' model=' + runtime.modelId +
            ' baseScheme=' + (runtime.baseUrl.indexOf('https://') === 0 ? 'https' : 'other'))
          const config = new ComicResponsesCallConfig()
          config.providerId = runtime.providerId()
          config.baseUrl = runtime.baseUrl
          config.model = runtime.modelId
          config.accessToken = runtime.apiKey
          const startedAt = Date.now()
          await ComicResponsesClient.requestJson('Reply with the single JSON object {"ok":true}.', '', config)
          delegator.print('[ProviderProbe] textOnly=ok ms=' + (Date.now() - startedAt))
        } catch (error) {
          delegator.print('[ProviderProbe] textOnly=failed code=' +
            ComicTranslationErrorClassifier.classify(error as Error))
        }
      })
    })
    return
  }
  describe('ReaderLegacySelfHostedPublishTrial', (): void => {
    it('publishesTheSelfHostedTranslationThroughTheLegacyReader', 0, async (): Promise<void> => {
      const driver = Driver.create()
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      const endpoint = (args['-s readerLabSelfHostedEndpoint'] as string) ?? ''
      // Legacy-entry counterpart of ReaderSelfHostedPublishTrial. Same process,
      // same gallery/page and the same in-process manga binding; the only change
      // is that the ordinary reader entry is the legacy backend. That isolates
      // whether the host LLM text-translation 5xx belongs to the shared
      // migration or is an existing host/external condition.
      await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
        parameters: { nextn_reader_backend: 'legacy', nextn_gallery_id: Number(work) } })
      // The gallery Want lands on Detail; the legacy Reader is only reached
      // through the same ordinary Read action the shared entry uses.
      await (await waitId(driver, 'gallery-detail-read-action', 160)).click()
      const surface = await waitId(driver, 'legacy-reader-surface', 240)
      let context: common.UIAbilityContext | null = null
      for (let attempt: number = 0; attempt < 80 && context === null; attempt++) {
        try {
          const ability = await delegator.getCurrentTopAbility()
          if (ability.context.abilityInfo.name === 'EntryAbility') {
            context = ability.context as common.UIAbilityContext
          }
        } catch (_) {}
        if (context === null) await driver.delayMs(100)
      }
      if (context === null) throw new Error('EntryAbility context unavailable')
      // Bind only after the host has restored its own persisted profiles; binding
      // earlier is overwritten by that restore.
      const modelOverride = (args['-s readerLabTranslationModel'] as string) ?? ''
      const boundManga = await bindExistingMangaSourceInProcess(modelOverride)
      delegator.print('[LegacySelfHostedPublish] bind=' + boundManga)
      // Reuse the same isolated endpoint the shared entry uses, in-process only.
      if (endpoint.length > 0) {
        ComicTranslationRuntimeService.setSelfHostedRuntimeOverrideForRehearsal(
          context, endpoint, 'nexte_qa', 'QaSidecar0728')
      }
      const actionLabel = AppStrings.get('reader_comic_translation_action')
      const showOriginal = AppStrings.get('reader_comic_translation_show_original')
      const failedLabel = AppStrings.get('reader_comic_translation_failed')
      const runningLabel = AppStrings.get('reader_comic_translation_running')
      let menu: Component | null = null
      const legacyMore = async (): Promise<Component | null> => {
        const buttons = await driver.findComponents(
          ON.type('Button').within(ON.id('legacy-reader-surface'))) ?? []
        let best: Component | null = null
        let bestLeft: number = -1
        for (const button of buttons) {
          let left: number = -1
          let inHeader: boolean = false
          try {
            const bounds = await button.getBounds()
            left = bounds.left
            inHeader = bounds.top < 400 && bounds.right > bounds.left && bounds.bottom > bounds.top
          } catch (_) { continue }
          if (inHeader && left > bestLeft) { best = button; bestLeft = left }
        }
        return best
      }
      for (let attempt: number = 0; attempt < 20 && menu === null; attempt++) {
        menu = await legacyMore()
        if (menu === null) {
          const bounds = await surface.getBounds()
          await driver.click(Math.round((bounds.left + bounds.right) / 2),
            Math.round((bounds.top + bounds.bottom) / 2))
          await driver.delayMs(700)
        }
      }
      if (menu === null) { delegator.print('[LegacySelfHostedPublish] action-present=false'); expect(false).assertTrue(); return }
      await menu.click()
      await driver.delayMs(600)
      let action: Component | null = await driver.findComponent(ON.text(actionLabel))
      if (action === null) action = await driver.findComponent(ON.text(showOriginal))
      if (action === null) { delegator.print('[LegacySelfHostedPublish] action-present=false'); expect(false).assertTrue(); return }
      delegator.print('[LegacySelfHostedPublish] action-present=true enabled=' + String(await action.isEnabled()))
      expect(await action.isEnabled()).assertTrue()
      await action.click()
      let sawRunning = false
      let applied = false
      let hostOutcome = ''
      for (let attempt = 0; attempt < 900; attempt++) {
        if (await driver.findComponent(ON.text(runningLabel)) !== null) sawRunning = true
        if (await driver.findComponent(ON.text(failedLabel)) !== null) { hostOutcome = failedLabel; break }
        if (attempt % 15 === 0) {
          const reopen = await legacyMore()
          if (reopen !== null) {
            await reopen.click()
            await driver.delayMs(500)
            if (await driver.findComponent(ON.text(showOriginal)) !== null) { applied = true; break }
            await driver.pressBack()
            await driver.delayMs(200)
          }
        }
        await driver.delayMs(1000)
      }
      delegator.print('[LegacySelfHostedPublish] manga=' + boundManga +
        ' sawRunning=' + sawRunning + ' applied=' + applied + ' hostOutcome=' + hostOutcome)
      // Paired-comparison method (same as the P14 old-vs-new runs): assert only
      // that the legacy entry dispatched the host translation action, and record
      // the outcome. A shared-side-only failure must stay visible as a finding
      // rather than being hidden by an applied assertion.
      expect(sawRunning || applied || hostOutcome.length > 0).assertTrue()
      await driver.pressBack()
    })
  })
}
