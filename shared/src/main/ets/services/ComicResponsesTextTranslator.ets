import { common } from '@kit.AbilityKit'
import { LLM_SOURCE_TYPE_OPENAI_COMPATIBLE } from '../model/LlmSourceProfile'
import {
  ComicTextTranslationRequest,
  ComicTextTranslationResult,
  ComicTextTranslator,
} from './ComicVisualTranslationBackend'
import {
  ComicResponsesCallConfig,
  ComicResponsesClient,
  ComicResponsesLabeledImage,
} from './ComicResponsesClient'
import { ComicResponsesImagePayload } from './ComicResponsesImagePayload'
import {
  ComicResponsesRegionImage,
  ComicResponsesRegionImagePayload,
} from './ComicResponsesRegionImagePayload'
import {
  COMIC_TEXT_TRANSLATION_INPUT_MULTIMODAL,
  COMIC_TEXT_TRANSLATION_INPUT_TEXT_ONLY,
  ComicResponsesTextTranslationProtocol,
} from './ComicResponsesTextTranslationProtocol'
import { LlmSourceRuntimeConfig, LlmSourceRuntimeResolver } from './LlmSourceRuntimeResolver'

export const COMIC_RESPONSES_TEXT_TRANSLATION_PROMPT_VERSION: string =
  'comic-text-responses-v8'
export const COMIC_RESPONSES_TEXT_ONLY_TRANSLATION_PROMPT_VERSION: string =
  'comic-text-responses-text-only-v1'

/** Resolves a source per run so profile edits cannot silently reuse a stale credential. */
export class OpenAiResponsesComicTextTranslator implements ComicTextTranslator {
  private readonly config: ComicResponsesCallConfig
  private readonly revision: number
  private readonly inputMode: string

  constructor(
    runtime: LlmSourceRuntimeConfig,
    inputMode: string = COMIC_TEXT_TRANSLATION_INPUT_MULTIMODAL,
  ) {
    ComicResponsesTextTranslationProtocol.validateInputMode(inputMode)
    this.config = new ComicResponsesCallConfig()
    this.config.providerId = runtime.providerId()
    this.config.baseUrl = runtime.baseUrl
    this.config.model = runtime.modelId
    this.config.accessToken = runtime.apiKey
    this.revision = runtime.sourceRevision
    this.inputMode = inputMode
  }

  sourceProfileId(): string {
    return this.config.providerId
  }

  sourceRevision(): number {
    return this.revision
  }

  modelId(): string {
    return this.config.model
  }

  promptVersion(): string {
    return this.inputMode === COMIC_TEXT_TRANSLATION_INPUT_TEXT_ONLY
      ? COMIC_RESPONSES_TEXT_ONLY_TRANSLATION_PROMPT_VERSION
      : COMIC_RESPONSES_TEXT_TRANSLATION_PROMPT_VERSION
  }

  contextFingerprint(request: ComicTextTranslationRequest): string {
    return ComicResponsesTextTranslationProtocol.contextFingerprint(request, this.inputMode)
  }

  async translate(request: ComicTextTranslationRequest): Promise<ComicTextTranslationResult> {
    const startedAt: number = Date.now()
    const prompt: string = ComicResponsesTextTranslationProtocol.buildPrompt(request, this.inputMode)
    let pageImage: string = ''
    let crops: ComicResponsesRegionImage[] = []
    if (this.inputMode === COMIC_TEXT_TRANSLATION_INPUT_MULTIMODAL) {
      pageImage = ComicResponsesImagePayload.dataUrl(
        request.source.imageFilePath,
        request.source.imageHash,
      )
      crops = await ComicResponsesRegionImagePayload.build(request)
    }
    const labeled: ComicResponsesLabeledImage[] = []
    let cropBytes: number = 0
    for (let index: number = 0; index < crops.length; index++) {
      const input: ComicResponsesLabeledImage = new ComicResponsesLabeledImage()
      input.label = 'Region crop blockId=' + crops[index].blockId
      input.imageDataUrl = crops[index].dataUrl
      labeled.push(input)
      cropBytes += crops[index].byteLength
    }
    const payloadPreparedAt: number = Date.now()
    const output: string = await ComicResponsesClient.requestJson(
      prompt,
      pageImage,
      this.config,
      labeled,
    )
    const providerCompletedAt: number = Date.now()
    const result: ComicTextTranslationResult = ComicResponsesTextTranslationProtocol.parse(
      request,
      output,
      this.sourceProfileId(),
      this.sourceRevision(),
      this.modelId(),
      this.promptVersion(),
      this.inputMode,
    )
    const finishedAt: number = Date.now()
    result.diagnostics.inputMode = this.inputMode
    result.diagnostics.promptChars = prompt.length
    result.diagnostics.fullImageDataUrlChars = pageImage.length
    result.diagnostics.regionCropCount = crops.length
    result.diagnostics.regionCropBytes = cropBytes
    result.diagnostics.prepareMs = payloadPreparedAt - startedAt
    result.diagnostics.providerMs = providerCompletedAt - payloadPreparedAt
    result.diagnostics.parseMs = finishedAt - providerCompletedAt
    result.diagnostics.totalMs = finishedAt - startedAt
    return result
  }
}

export class ComicTextTranslatorFactory {
  static async create(
    context: common.UIAbilityContext,
    inputMode: string = COMIC_TEXT_TRANSLATION_INPUT_MULTIMODAL,
  ): Promise<ComicTextTranslator> {
    const runtime: LlmSourceRuntimeConfig = await LlmSourceRuntimeResolver.resolveManga(
      context,
      inputMode === COMIC_TEXT_TRANSLATION_INPUT_MULTIMODAL,
    )
    if (runtime.sourceType !== LLM_SOURCE_TYPE_OPENAI_COMPATIBLE) {
      throw new Error('Selected LLM source type is not available')
    }
    return new OpenAiResponsesComicTextTranslator(runtime, inputMode)
  }
}
