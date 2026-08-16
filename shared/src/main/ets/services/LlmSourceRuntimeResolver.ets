import { common } from '@kit.AbilityKit'
import {
  LLM_CONSUMER_COMMENT_TRANSLATION,
  LLM_CONSUMER_MANGA_TRANSLATION,
  LLM_SOURCE_TYPE_OPENAI_COMPATIBLE,
  LlmConsumerBinding,
  LlmSourceProfile,
  LlmSourceResolution,
  supportsCommentTranslation,
  supportsMangaTranslation,
} from '../model/LlmSourceProfile'
import { LlmSourceProfileRepository } from '../storage/LlmSourceProfileRepository'
import { LlmSourceSecretVault } from './LlmSourceSecretVault'

export class LlmSourceRuntimeConfig {
  sourceProfileId: string = ''
  sourceRevision: number = 0
  sourceType: string = ''
  baseUrl: string = ''
  modelId: string = ''
  apiKey: string = ''

  requestIdentity(): string {
    return JSON.stringify([
      this.sourceProfileId,
      this.sourceRevision,
      this.sourceType,
      this.modelId,
    ])
  }

  providerId(): string {
    return 'llm-source:' + this.sourceProfileId + ':r' + this.sourceRevision
  }
}

/** Resolves an explicitly bound, capability-checked source for one request. */
export class LlmSourceRuntimeResolver {
  static async resolveComment(
    context: common.UIAbilityContext,
  ): Promise<LlmSourceRuntimeConfig> {
    return LlmSourceRuntimeResolver.resolveConsumer(
      context,
      LLM_CONSUMER_COMMENT_TRANSLATION,
      (profile: LlmSourceProfile): boolean => supportsCommentTranslation(profile),
    )
  }

  static async resolveManga(
    context: common.UIAbilityContext,
    requireImageInput: boolean = true,
  ): Promise<LlmSourceRuntimeConfig> {
    return LlmSourceRuntimeResolver.resolveConsumer(
      context,
      LLM_CONSUMER_MANGA_TRANSLATION,
      (profile: LlmSourceProfile): boolean => supportsMangaTranslation(profile, requireImageInput),
    )
  }

  static profile(sourceProfileId: string): LlmSourceProfile {
    const profiles: LlmSourceProfile[] = LlmSourceProfileRepository.currentProfiles()
    for (let index: number = 0; index < profiles.length; index++) {
      if (profiles[index].sourceProfileId === sourceProfileId) {
        return profiles[index].copy()
      }
    }
    throw new Error('Selected LLM source is missing')
  }

  static async resolveCatalogSource(
    context: common.UIAbilityContext,
    sourceProfileId: string,
  ): Promise<LlmSourceRuntimeConfig> {
    const profile: LlmSourceProfile = LlmSourceRuntimeResolver.profile(sourceProfileId)
    if (profile.sourceType !== LLM_SOURCE_TYPE_OPENAI_COMPATIBLE ||
      !profile.capabilities.modelCatalog) {
      throw new Error('Selected LLM source does not support model catalog')
    }
    const apiKey: string = await LlmSourceSecretVault.readApiKey(context, sourceProfileId)
    if (apiKey.length === 0) {
      throw new Error('Selected LLM source API key is missing')
    }
    if (!LlmSourceSecretVault.apiKeyMatchesIdentity(apiKey, profile.accountIdentityHash)) {
      throw new Error('Selected LLM source API key does not match its stored identity')
    }
    return LlmSourceRuntimeResolver.runtimeConfig(profile, '', apiKey)
  }

  private static async resolveConsumer(
    context: common.UIAbilityContext,
    consumerId: string,
    supports: (profile: LlmSourceProfile) => boolean,
  ): Promise<LlmSourceRuntimeConfig> {
    const resolution: LlmSourceResolution = LlmSourceRuntimeResolver.currentResolution(consumerId)
    if (!supports(resolution.profile)) {
      throw new Error('Selected LLM source does not support this translation')
    }
    const apiKey: string = await LlmSourceSecretVault.readApiKey(
      context,
      resolution.profile.sourceProfileId,
    )
    if (apiKey.length === 0) {
      throw new Error('Selected LLM source API key is missing')
    }
    const current: LlmSourceResolution = LlmSourceRuntimeResolver.currentResolution(consumerId)
    if (!LlmSourceRuntimeResolver.sameResolution(resolution, current)) {
      throw new Error('Selected LLM source changed while resolving')
    }
    if (!supports(current.profile)) {
      throw new Error('Selected LLM source does not support this translation')
    }
    if (!LlmSourceSecretVault.apiKeyMatchesIdentity(apiKey, current.profile.accountIdentityHash)) {
      throw new Error('Selected LLM source API key does not match its stored identity')
    }
    return LlmSourceRuntimeResolver.runtimeConfig(current.profile, current.modelId, apiKey)
  }

  private static currentResolution(consumerId: string): LlmSourceResolution {
    const profiles: LlmSourceProfile[] = LlmSourceProfileRepository.currentProfiles()
    const binding: LlmConsumerBinding = LlmSourceProfileRepository.currentBinding(consumerId)
    const resolution: LlmSourceResolution | null = LlmSourceProfileRepository.resolve(profiles, binding)
    if (resolution === null) {
      throw new Error('LLM source is not configured')
    }
    return resolution
  }

  private static sameResolution(
    first: LlmSourceResolution,
    second: LlmSourceResolution,
  ): boolean {
    return first.profile.sourceProfileId === second.profile.sourceProfileId &&
      first.profile.sourceRevision === second.profile.sourceRevision &&
      first.profile.requestIdentity() === second.profile.requestIdentity() &&
      first.modelId === second.modelId
  }

  private static runtimeConfig(
    profile: LlmSourceProfile,
    modelId: string,
    apiKey: string,
  ): LlmSourceRuntimeConfig {
    if (profile.sourceType !== LLM_SOURCE_TYPE_OPENAI_COMPATIBLE) {
      throw new Error('Selected LLM source type is not available')
    }
    const config: LlmSourceRuntimeConfig = new LlmSourceRuntimeConfig()
    config.sourceProfileId = profile.sourceProfileId
    config.sourceRevision = profile.sourceRevision
    config.sourceType = profile.sourceType
    config.baseUrl = profile.baseUrl
    config.modelId = modelId
    config.apiKey = apiKey
    return config
  }
}
