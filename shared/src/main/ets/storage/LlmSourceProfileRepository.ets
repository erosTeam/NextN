import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import {
  LLM_CONSUMER_COMMENT_TRANSLATION,
  LLM_CONSUMER_MANGA_TRANSLATION,
  LLM_SOURCE_PROFILE_SCHEMA_VERSION,
  LlmConsumerBinding,
  LlmSourceProfile,
  LlmSourceResolution,
} from '../model/LlmSourceProfile'
import { LlmSourceProfileCodec } from '../services/LlmSourceProfileCodec'
import {
  LlmSourceProfileContract,
  MAX_LLM_MODEL_ID_CHARS,
  MAX_LLM_SOURCE_ID_CHARS,
  MAX_LLM_SOURCE_NAME_CHARS,
  MAX_LLM_SOURCE_URL_CHARS,
} from '../services/LlmSourceProfileContract'
import { connectLlmSourceProfiles, LlmSourceProfilesState } from '../state/LlmSourceProfilesState'

const LLM_SOURCE_STORE: string = 'nextn_llm_sources'
const LLM_SOURCE_PROFILES_KEY: string = 'profiles'
const COMMENT_SOURCE_KEY: string = 'comment_source'
const COMMENT_MODEL_KEY: string = 'comment_model'
const MANGA_SOURCE_KEY: string = 'manga_source'
const MANGA_MODEL_KEY: string = 'manga_model'

/** The only durable owner of non-secret LLM source metadata and consumer bindings. */
export class LlmSourceProfileRepository {
  private static writeTail: Promise<void> = Promise.resolve()
  private static restoreTask: Promise<void> | null = null
  private static restored: boolean = false

  static async restore(context: common.UIAbilityContext): Promise<void> {
    if (LlmSourceProfileRepository.restored) {
      return
    }
    if (LlmSourceProfileRepository.restoreTask !== null) {
      await LlmSourceProfileRepository.restoreTask
      return
    }
    const task: Promise<void> = LlmSourceProfileRepository.restoreInternal(context)
    LlmSourceProfileRepository.restoreTask = task
    try {
      await task
      LlmSourceProfileRepository.restored = true
    } finally {
      LlmSourceProfileRepository.restoreTask = null
    }
  }

  static currentProfiles(): LlmSourceProfile[] {
    return LlmSourceProfileCodec.copyProfiles(connectLlmSourceProfiles().profiles)
  }

  static currentBinding(consumerId: string): LlmConsumerBinding {
    const state: LlmSourceProfilesState = connectLlmSourceProfiles()
    if (consumerId === LLM_CONSUMER_COMMENT_TRANSLATION) {
      return state.commentBinding.copy()
    }
    if (consumerId === LLM_CONSUMER_MANGA_TRANSLATION) {
      return state.mangaBinding.copy()
    }
    throw new Error('Unknown LLM consumer')
  }

  static upsert(
    context: common.UIAbilityContext,
    candidate: LlmSourceProfile,
  ): Promise<void> {
    const isolated: LlmSourceProfile = candidate.copy()
    return LlmSourceProfileRepository.enqueue(async (): Promise<void> => {
      const store: preferences.Preferences =
        await preferences.getPreferences(context, LLM_SOURCE_STORE)
      const profiles: LlmSourceProfile[] = LlmSourceProfileRepository.readProfiles(store)
      const index: number = LlmSourceProfileRepository.indexOf(profiles, isolated.sourceProfileId)
      const existing: LlmSourceProfile | null = index < 0 ? null : profiles[index]
      const next: LlmSourceProfile = LlmSourceProfileRepository.prepareForUpsert(
        existing,
        isolated,
        Date.now(),
      )
      if (index < 0) {
        profiles.push(next)
      } else {
        profiles[index] = next
      }
      store.putSync(LLM_SOURCE_PROFILES_KEY, LlmSourceProfileCodec.encode(profiles))
      store.flushSync()
      LlmSourceProfileRepository.applyProfiles(profiles)
    })
  }

  /**
   * Bindings intentionally survive removal and resolve as unconfigured until
   * their owning caller explicitly selects a replacement source.
   */
  static remove(context: common.UIAbilityContext, sourceProfileId: string): Promise<void> {
    const canonicalId: string = LlmSourceProfileContract.canonicalText(
      sourceProfileId,
      MAX_LLM_SOURCE_ID_CHARS,
    )
    if (canonicalId.length === 0 || canonicalId !== sourceProfileId) {
      return Promise.reject(new Error('LLM source profile ID is invalid'))
    }
    return LlmSourceProfileRepository.enqueue(async (): Promise<void> => {
      const store: preferences.Preferences =
        await preferences.getPreferences(context, LLM_SOURCE_STORE)
      const profiles: LlmSourceProfile[] = LlmSourceProfileRepository.readProfiles(store)
      const remaining: LlmSourceProfile[] = []
      for (let index: number = 0; index < profiles.length; index++) {
        if (profiles[index].sourceProfileId !== canonicalId) {
          remaining.push(profiles[index])
        }
      }
      if (remaining.length === profiles.length) {
        return
      }
      if (remaining.length === 0) {
        store.deleteSync(LLM_SOURCE_PROFILES_KEY)
      } else {
        store.putSync(LLM_SOURCE_PROFILES_KEY, LlmSourceProfileCodec.encode(remaining))
      }
      store.flushSync()
      LlmSourceProfileRepository.applyProfiles(remaining)
    })
  }

  static saveBinding(
    context: common.UIAbilityContext,
    candidate: LlmConsumerBinding,
  ): Promise<void> {
    const binding: LlmConsumerBinding = candidate.copy()
    LlmSourceProfileContract.validateBinding(binding)
    return LlmSourceProfileRepository.enqueue(async (): Promise<void> => {
      const store: preferences.Preferences =
        await preferences.getPreferences(context, LLM_SOURCE_STORE)
      const profiles: LlmSourceProfile[] = LlmSourceProfileRepository.readProfiles(store)
      if (binding.configured() &&
        LlmSourceProfileRepository.indexOf(profiles, binding.sourceProfileId) < 0) {
        throw new Error('LLM source binding references a missing profile')
      }
      const keys: string[] = LlmSourceProfileRepository.bindingKeys(binding.consumerId)
      if (binding.configured()) {
        store.putSync(keys[0], binding.sourceProfileId)
        store.putSync(keys[1], binding.modelId)
      } else {
        store.deleteSync(keys[0])
        store.deleteSync(keys[1])
      }
      store.flushSync()
      LlmSourceProfileRepository.applyBinding(binding)
    })
  }

  static resolve(
    profiles: LlmSourceProfile[],
    binding: LlmConsumerBinding,
  ): LlmSourceResolution | null {
    try {
      LlmSourceProfileContract.validateProfiles(profiles)
      LlmSourceProfileContract.validateBinding(binding)
    } catch (_error) {
      return null
    }
    if (!binding.configured()) {
      return null
    }
    const index: number = LlmSourceProfileRepository.indexOf(profiles, binding.sourceProfileId)
    if (index < 0) {
      return null
    }
    const value: LlmSourceResolution = new LlmSourceResolution()
    value.profile = profiles[index].copy()
    value.modelId = binding.modelId
    return value
  }

  static prepareForUpsert(
    existing: LlmSourceProfile | null,
    candidate: LlmSourceProfile,
    now: number,
  ): LlmSourceProfile {
    if (!LlmSourceProfileContract.nonNegativeInteger(now)) {
      throw new Error('LLM source update time is invalid')
    }
    const next: LlmSourceProfile = candidate.copy()
    next.schemaVersion = LLM_SOURCE_PROFILE_SCHEMA_VERSION
    next.sourceProfileId = LlmSourceProfileContract.canonicalText(
      next.sourceProfileId,
      MAX_LLM_SOURCE_ID_CHARS,
    )
    next.displayName = LlmSourceProfileContract.canonicalText(
      next.displayName,
      MAX_LLM_SOURCE_NAME_CHARS,
    )
    next.baseUrl = LlmSourceProfileContract.canonicalText(next.baseUrl, MAX_LLM_SOURCE_URL_CHARS)
    next.accountIdentityHash = next.accountIdentityHash.trim().toLowerCase()
    if (existing === null) {
      next.sourceRevision = 1
      next.createdAt = now
      next.updatedAt = now
    } else {
      LlmSourceProfileContract.validateProfile(existing)
      next.sourceRevision = existing.requestIdentity() === next.requestIdentity()
        ? existing.sourceRevision
        : existing.sourceRevision + 1
      next.createdAt = existing.createdAt
      next.updatedAt = Math.max(now, existing.updatedAt + 1)
    }
    LlmSourceProfileContract.validateProfile(next)
    return next
  }

  private static async restoreInternal(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences =
        await preferences.getPreferences(context, LLM_SOURCE_STORE)
      LlmSourceProfileRepository.applyState(
        LlmSourceProfileRepository.readProfiles(store),
        LlmSourceProfileRepository.readBinding(store, LLM_CONSUMER_COMMENT_TRANSLATION),
        LlmSourceProfileRepository.readBinding(store, LLM_CONSUMER_MANGA_TRANSLATION),
      )
    } catch (_error) {
      LlmSourceProfileRepository.applyState(
        [],
        LlmSourceProfileRepository.emptyBinding(LLM_CONSUMER_COMMENT_TRANSLATION),
        LlmSourceProfileRepository.emptyBinding(LLM_CONSUMER_MANGA_TRANSLATION),
      )
    }
  }

  private static readProfiles(store: preferences.Preferences): LlmSourceProfile[] {
    return LlmSourceProfileCodec.decode(
      store.getSync(LLM_SOURCE_PROFILES_KEY, '') as string,
    )
  }

  private static readBinding(
    store: preferences.Preferences,
    consumerId: string,
  ): LlmConsumerBinding {
    const keys: string[] = LlmSourceProfileRepository.bindingKeys(consumerId)
    const binding: LlmConsumerBinding = new LlmConsumerBinding()
    binding.consumerId = consumerId
    binding.sourceProfileId = LlmSourceProfileContract.canonicalText(
      store.getSync(keys[0], '') as string,
      MAX_LLM_SOURCE_ID_CHARS,
    )
    binding.modelId = LlmSourceProfileContract.canonicalText(
      store.getSync(keys[1], '') as string,
      MAX_LLM_MODEL_ID_CHARS,
    )
    try {
      LlmSourceProfileContract.validateBinding(binding)
      return binding
    } catch (_error) {
      return LlmSourceProfileRepository.emptyBinding(consumerId)
    }
  }

  private static bindingKeys(consumerId: string): string[] {
    if (consumerId === LLM_CONSUMER_COMMENT_TRANSLATION) {
      return [COMMENT_SOURCE_KEY, COMMENT_MODEL_KEY]
    }
    if (consumerId === LLM_CONSUMER_MANGA_TRANSLATION) {
      return [MANGA_SOURCE_KEY, MANGA_MODEL_KEY]
    }
    throw new Error('Unknown LLM consumer')
  }

  private static indexOf(profiles: LlmSourceProfile[], sourceProfileId: string): number {
    for (let index: number = 0; index < profiles.length; index++) {
      if (profiles[index].sourceProfileId === sourceProfileId) {
        return index
      }
    }
    return -1
  }

  private static applyState(
    profiles: LlmSourceProfile[],
    commentBinding: LlmConsumerBinding,
    mangaBinding: LlmConsumerBinding,
  ): void {
    const state: LlmSourceProfilesState = connectLlmSourceProfiles()
    state.profiles = LlmSourceProfileCodec.copyProfiles(profiles)
    state.commentBinding = commentBinding.copy()
    state.mangaBinding = mangaBinding.copy()
  }

  private static applyProfiles(profiles: LlmSourceProfile[]): void {
    connectLlmSourceProfiles().profiles = LlmSourceProfileCodec.copyProfiles(profiles)
  }

  private static applyBinding(binding: LlmConsumerBinding): void {
    const state: LlmSourceProfilesState = connectLlmSourceProfiles()
    if (binding.consumerId === LLM_CONSUMER_COMMENT_TRANSLATION) {
      state.commentBinding = binding.copy()
      return
    }
    state.mangaBinding = binding.copy()
  }

  private static emptyBinding(consumerId: string): LlmConsumerBinding {
    const value: LlmConsumerBinding = new LlmConsumerBinding()
    value.consumerId = consumerId
    return value
  }

  private static enqueue(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = LlmSourceProfileRepository.writeTail.then(
      (): Promise<void> => operation(),
      (): Promise<void> => operation(),
    )
    LlmSourceProfileRepository.writeTail = queued.catch((): void => {})
    return queued
  }
}
