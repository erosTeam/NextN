import { common } from '@kit.AbilityKit'
import { http } from '@kit.NetworkKit'
import { LlmSourceRuntimeConfig, LlmSourceRuntimeResolver } from './LlmSourceRuntimeResolver'

const MODEL_CATALOG_CONNECT_TIMEOUT_MS: number = 15000
const MODEL_CATALOG_READ_TIMEOUT_MS: number = 20000
const MODEL_CATALOG_MAX_BODY_CHARS: number = 2 * 1024 * 1024
const MODEL_CATALOG_MAX_ENTRIES: number = 512
const MODEL_IDENTIFIER_MAX_CHARS: number = 160

class ApiModelEntry {
  id: string = ''
}

class ApiModelsEnvelope {
  data: ApiModelEntry[] = []
}

/**
 * Queries the selected OpenAI-compatible source's account-scoped model
 * catalog without inventing a shared static allowlist. Ported from NextE's
 * ComicTranslationModelCatalogService; the Codex branch is absent because
 * NextN has no Codex OAuth service.
 */
export class ComicTranslationModelCatalogService {
  static async fetchSource(
    context: common.UIAbilityContext,
    sourceProfileId: string,
  ): Promise<string[]> {
    const runtime: LlmSourceRuntimeConfig =
      await LlmSourceRuntimeResolver.resolveCatalogSource(context, sourceProfileId)
    const response: http.HttpResponse = await ComicTranslationModelCatalogService.requestApi(runtime)
    const body: string = typeof response.result === 'string' ? response.result : ''
    if (response.responseCode !== 200) {
      throw new Error('OpenAI model catalog failed (HTTP ' + response.responseCode + ')')
    }
    return ComicTranslationModelCatalogService.parseApiModels(body)
  }

  static parseApiModels(rawText: string): string[] {
    ComicTranslationModelCatalogService.requireBoundedBody(rawText)
    const envelope: ApiModelsEnvelope = JSON.parse(rawText) as ApiModelsEnvelope
    if (!Array.isArray(envelope.data)) {
      throw new Error('Model catalog returned no data array')
    }
    ComicTranslationModelCatalogService.requireBoundedEntries(envelope.data.length)
    const models: string[] = []
    for (let index: number = 0; index < envelope.data.length; index++) {
      const item: ApiModelEntry | null = envelope.data[index]
      const id: string = item === null
        ? ''
        : ComicTranslationModelCatalogService.normalizeModelId(item.id)
      if (id.length > 0 && models.indexOf(id) < 0) {
        models.push(id)
      }
    }
    models.sort()
    return models
  }

  private static async requestApi(
    runtime: LlmSourceRuntimeConfig,
  ): Promise<http.HttpResponse> {
    let request: http.HttpRequest | null = null
    try {
      request = http.createHttp()
      return await request.request(
        ComicTranslationModelCatalogService.apiModelsUrl(runtime.baseUrl),
        {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.STRING,
          usingCache: false,
          connectTimeout: MODEL_CATALOG_CONNECT_TIMEOUT_MS,
          readTimeout: MODEL_CATALOG_READ_TIMEOUT_MS,
          header: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ' + runtime.apiKey,
            'User-Agent': 'NextN model catalog',
          },
        },
      )
    } finally {
      if (request !== null) {
        request.destroy()
      }
    }
  }

  private static apiModelsUrl(baseUrl: string): string {
    let normalized: string = baseUrl.trim().replace(/\/+$/, '')
    if (!normalized.toLowerCase().startsWith('https://')) {
      throw new Error('Comic provider base URL must use HTTPS')
    }
    if (normalized.endsWith('/responses')) {
      normalized = normalized.substring(0, normalized.length - '/responses'.length)
    }
    if (normalized.endsWith('/models')) {
      return normalized
    }
    if (normalized.endsWith('/v1')) {
      return normalized + '/models'
    }
    return normalized + '/v1/models'
  }

  private static requireBoundedBody(rawText: string): void {
    if (rawText.length === 0 || rawText.length > MODEL_CATALOG_MAX_BODY_CHARS) {
      throw new Error('Model catalog response size is invalid')
    }
  }

  private static requireBoundedEntries(entryCount: number): void {
    if (entryCount > MODEL_CATALOG_MAX_ENTRIES) {
      throw new Error('Model catalog entry count is invalid')
    }
  }

  private static normalizeModelId(value: string): string {
    const normalized: string = value.trim()
    if (normalized.length === 0 || normalized.length > MODEL_IDENTIFIER_MAX_CHARS) {
      return ''
    }
    for (let index: number = 0; index < normalized.length; index++) {
      const code: number = normalized.charCodeAt(index)
      if (code <= 31 || code === 127) {
        return ''
      }
    }
    return normalized
  }
}
