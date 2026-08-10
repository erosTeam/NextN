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
    const config: LlmSourceRuntimeConfig = await LlmSourceRuntimeResolver.resolveConsumer(
      context,
      LLM_CONSUMER_COMMENT_TRANSLATION,
    )
    if (!supportsCommentTranslation(LlmSourceRuntimeResolver.profile(config.sourceProfileId))) {
      throw new Error('Selected LLM source does not support comment translation')
    }
    return config
  }

  static async resolveManga(
    context: common.UIAbilityContext,
    requireImageInput: boolean = true,
  ): Promise<LlmSourceRuntimeConfig> {
    const config: LlmSourceRuntimeConfig = await LlmSourceRuntimeResolver.resolveConsumer(
      context,
      LLM_CONSUMER_MANGA_TRANSLATION,
    )
    if (!supportsMangaTranslation(
      LlmSourceRuntimeResolver.profile(config.sourceProfileId),
      requireImageInput,
    )) {
      throw new Error('Selected LLM source does not support manga translation')
    }
    return config
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

  private static async resolveConsumer(
    context: common.UIAbilityContext,
    consumerId: string,
  ): Promise<LlmSourceRuntimeConfig> {
    const profiles: LlmSourceProfile[] = LlmSourceProfileRepository.currentProfiles()
    const binding: LlmConsumerBinding = LlmSourceProfileRepository.currentBinding(consumerId)
    const resolution: LlmSourceResolution | null = LlmSourceProfileRepository.resolve(
      profiles,
      binding,
    )
    if (resolution === null) {
      throw new Error('LLM source is not configured')
    }
    return LlmSourceRuntimeResolver.runtimeConfig(context, resolution.profile, resolution.modelId)
  }

  private static async runtimeConfig(
    context: common.UIAbilityContext,
    profile: LlmSourceProfile,
    modelId: string,
  ): Promise<LlmSourceRuntimeConfig> {
    if (profile.sourceType !== LLM_SOURCE_TYPE_OPENAI_COMPATIBLE) {
      throw new Error('Selected LLM source type is not available')
    }
    const apiKey: string = await LlmSourceSecretVault.readApiKey(context, profile.sourceProfileId)
    if (apiKey.length === 0) {
      throw new Error('Selected LLM source API key is missing')
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
