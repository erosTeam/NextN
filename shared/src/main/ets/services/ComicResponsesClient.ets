import { http } from '@kit.NetworkKit'
import { ComicTranslationDiagnosticLogger } from './ComicTranslationDiagnosticLogger'
import { ComicResponsesProtocol } from './ComicResponsesProtocol'

const RESPONSES_CONNECT_TIMEOUT_MS: number = 20000
const RESPONSES_READ_TIMEOUT_MS: number = 120000
const RESPONSES_MAX_BODY_CHARS: number = 8 * 1024 * 1024

interface ResponsesInputText {
  type: string
  text: string
}

interface ResponsesInputImage {
  type: string
  image_url: string
  detail: string
}

type ResponsesInputContent = ResponsesInputText | ResponsesInputImage

class ResponsesInputMessage {
  role: string = 'user'
  content: ResponsesInputContent[] = []
}

class PublicResponsesRequestBody {
  model: string = ''
  input: ResponsesInputMessage[] = []
  stream: boolean = false
  store: boolean = false
  max_output_tokens: number = 8192
}

export class ComicResponsesLabeledImage {
  label: string = ''
  imageDataUrl: string = ''
}

/** Fixed failure detail; raw server bodies and transport errors are never retained or logged. */
export class ComicProviderHttpError extends Error {
  readonly statusCode: number
  readonly detailCode: string

  constructor(statusCode: number, responseBody: string) {
    super('Comic provider request failed (HTTP ' + statusCode + ')')
    this.statusCode = statusCode
    this.detailCode = ComicProviderHttpError.classify(responseBody)
  }

  private static classify(responseBody: string): string {
    const body: string = responseBody.toLowerCase()
    if (body.includes('rate limit')) {
      return 'rate_limited'
    }
    if (body.includes('unauthorized') || body.includes('invalid api key')) {
      return 'authentication'
    }
    if (body.includes('unsupported') || body.includes('unrecognized') ||
      body.includes('unknown field') || body.includes('not permitted')) {
      return 'unsupported_request'
    }
    if (body.includes('invalid') || body.includes('required') || body.includes('missing')) {
      return 'invalid_request'
    }
    return 'http_rejected'
  }
}

export class ComicProviderStageError extends Error {
  readonly stageCode: string
  readonly detailCode: string

  constructor(stageCode: string, detailCode: string) {
    super('Comic provider ' + stageCode + ' failed (' + detailCode + ')')
    this.stageCode = stageCode
    this.detailCode = detailCode
  }
}

export class ComicResponsesCallConfig {
  providerId: string = ''
  baseUrl: string = ''
  model: string = ''
  accessToken: string = ''
}

/**
 * A public OpenAI-compatible Responses client. The API key exists only in the config frame while
 * NetworkKit sends this one request; neither response bodies nor headers are logged.
 */
export class ComicResponsesClient {
  static async requestJson(
    prompt: string,
    imageDataUrl: string,
    config: ComicResponsesCallConfig,
    additionalImages: ComicResponsesLabeledImage[] = [],
  ): Promise<string> {
    ComicResponsesClient.validateConfig(config)
    const body: string = ComicResponsesClient.requestBody(
      config.model,
      prompt,
      imageDataUrl,
      additionalImages,
    )
    let request: http.HttpRequest | null = null
    try {
      request = http.createHttp()
      const response: http.HttpResponse = await request.request(
        ComicResponsesClient.responsesUrl(config.baseUrl),
        {
          method: http.RequestMethod.POST,
          extraData: body,
          expectDataType: http.HttpDataType.STRING,
          usingCache: false,
          connectTimeout: RESPONSES_CONNECT_TIMEOUT_MS,
          readTimeout: RESPONSES_READ_TIMEOUT_MS,
          header: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + config.accessToken,
            'User-Agent': 'NextN comic translation',
          },
        },
      )
      const responseBody: string = typeof response.result === 'string' ? response.result : ''
      if (responseBody.length > RESPONSES_MAX_BODY_CHARS) {
        throw new ComicProviderStageError('protocol', 'response_size')
      }
      if (response.responseCode !== 200) {
        throw new ComicProviderHttpError(response.responseCode, responseBody)
      }
      try {
        return ComicResponsesProtocol.extractAssistantJson(responseBody, false)
      } catch (error) {
        throw ComicResponsesClient.stageError('protocol', error as Error)
      }
    } catch (error) {
      if (error instanceof ComicProviderHttpError) {
        const rejected: ComicProviderHttpError = error as ComicProviderHttpError
        throw new ComicProviderHttpError(rejected.statusCode, '')
      }
      if (error instanceof ComicProviderStageError) {
        const staged: ComicProviderStageError = error as ComicProviderStageError
        throw new ComicProviderStageError(staged.stageCode, staged.detailCode)
      }
      ComicTranslationDiagnosticLogger.warn(
        'comic-translation',
        'provider_transport_failed',
        '',
      )
      throw ComicResponsesClient.stageError('transport', error as Error)
    } finally {
      if (request !== null) {
        request.destroy()
      }
    }
  }

  private static requestBody(
    model: string,
    prompt: string,
    imageDataUrl: string,
    additionalImages: ComicResponsesLabeledImage[],
  ): string {
    if (prompt.length === 0 || model.length === 0 ||
      (imageDataUrl.length > 0 && !imageDataUrl.startsWith('data:image/'))) {
      throw new Error('Comic provider request is invalid')
    }
    const message: ResponsesInputMessage = new ResponsesInputMessage()
    message.content.push({ type: 'input_text', text: prompt })
    if (imageDataUrl.length > 0) {
      message.content.push({ type: 'input_image', image_url: imageDataUrl, detail: 'high' })
    }
    if (imageDataUrl.length === 0 && additionalImages.length > 0) {
      throw new Error('Comic provider crops require a full page image')
    }
    for (let index: number = 0; index < additionalImages.length; index++) {
      const image: ComicResponsesLabeledImage = additionalImages[index]
      if (image.label.trim().length === 0 || !image.imageDataUrl.startsWith('data:image/')) {
        throw new Error('Comic provider crop is invalid')
      }
      message.content.push({ type: 'input_text', text: image.label })
      message.content.push({ type: 'input_image', image_url: image.imageDataUrl, detail: 'high' })
    }
    const body: PublicResponsesRequestBody = new PublicResponsesRequestBody()
    body.model = model
    body.input = [message]
    return JSON.stringify(body)
  }

  private static validateConfig(config: ComicResponsesCallConfig): void {
    if (config.providerId.trim().length === 0 || config.model.trim().length === 0 ||
      config.accessToken.length === 0) {
      throw new Error('Comic translation provider is not configured')
    }
    ComicResponsesClient.responsesUrl(config.baseUrl)
  }

  private static responsesUrl(baseUrl: string): string {
    const normalized: string = baseUrl.trim().replace(/\/+$/, '')
    if (!normalized.toLowerCase().startsWith('https://')) {
      throw new Error('Comic provider base URL must use HTTPS')
    }
    if (normalized.endsWith('/responses')) {
      return normalized
    }
    return normalized.endsWith('/v1') ? normalized + '/responses' : normalized + '/v1/responses'
  }

  static stageError(stageCode: string, error: Error): ComicProviderStageError {
    const message: string = error.message.toLowerCase()
    if (stageCode === 'transport') {
      if (message.includes('timeout')) {
        return new ComicProviderStageError(stageCode, 'timeout')
      }
      if (message.includes('certificate') || message.includes('tls')) {
        return new ComicProviderStageError(stageCode, 'tls')
      }
      if (message.includes('dns')) {
        return new ComicProviderStageError(stageCode, 'dns')
      }
      return new ComicProviderStageError(stageCode, 'connection')
    }
    if (message.includes('response size')) {
      return new ComicProviderStageError(stageCode, 'response_size')
    }
    if (message.includes('empty output') || message.includes('no output') ||
      message.includes('no json')) {
      return new ComicProviderStageError(stageCode, 'output_missing')
    }
    return new ComicProviderStageError(stageCode, 'invalid_response')
  }
}
