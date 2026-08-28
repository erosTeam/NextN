import { AxiosHttpClient, AxiosTextResponse } from '../network/AxiosHttpClient'
import { ComicProviderHttpError, ComicProviderStageError } from './ComicResponsesClient'

const CONNECT_TIMEOUT_MS: number = 20000
const READ_TIMEOUT_MS: number = 120000
const MAX_RESPONSE_CHARS: number = 8 * 1024 * 1024

class ChatMessage {
  role: string = ''
  content: string = ''
}

class ChatCompletionRequest {
  model: string = ''
  messages: ChatMessage[] = []
  temperature: number = 0.2
  max_tokens: number = 2048
}

class ChatCompletionMessage {
  content: string = ''
}

class ChatCompletionChoice {
  message: ChatCompletionMessage = new ChatCompletionMessage()
}

class ChatCompletionResponse {
  choices: ChatCompletionChoice[] = []
}

export class OpenAiChatCompletionsConfig {
  baseUrl: string = ''
  modelId: string = ''
  apiKey: string = ''
}

/**
 * Small text-only OpenAI-compatible client for the separately-bound comment
 * translation source. It keeps request/response bodies and credentials in the
 * calling frame and returns only a bounded assistant text result.
 */
export class OpenAiChatCompletionsClient {
  static async requestText(
    systemInstruction: string,
    userText: string,
    config: OpenAiChatCompletionsConfig,
  ): Promise<string> {
    const endpoint: string = OpenAiChatCompletionsClient.endpoint(config.baseUrl)
    if (systemInstruction.trim().length === 0 || userText.trim().length === 0 ||
      config.modelId.trim().length === 0 || config.apiKey.length === 0) {
      throw new Error('Comment translation provider is not configured')
    }
    const system: ChatMessage = new ChatMessage()
    system.role = 'system'
    system.content = systemInstruction
    const user: ChatMessage = new ChatMessage()
    user.role = 'user'
    user.content = userText
    const requestBody: ChatCompletionRequest = new ChatCompletionRequest()
    requestBody.model = config.modelId.trim()
    requestBody.messages = [system, user]

    try {
      const response: AxiosTextResponse = await AxiosHttpClient.requestText(
        endpoint,
        'POST',
        {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + config.apiKey,
          'User-Agent': 'NextN comment translation',
        },
        JSON.stringify(requestBody),
        CONNECT_TIMEOUT_MS,
        READ_TIMEOUT_MS,
        MAX_RESPONSE_CHARS,
      )
      const body: string = response.body
      if (body.length > MAX_RESPONSE_CHARS) {
        throw new ComicProviderStageError('protocol', 'response_size')
      }
      if (response.statusCode !== 200) {
        throw new ComicProviderHttpError(response.statusCode, body)
      }
      return OpenAiChatCompletionsClient.extractText(body)
    } catch (error) {
      if (error instanceof ComicProviderHttpError) {
        const rejected: ComicProviderHttpError = error as ComicProviderHttpError
        throw new ComicProviderHttpError(rejected.statusCode, '', rejected.detailCode)
      }
      if (error instanceof ComicProviderStageError) {
        throw error as ComicProviderStageError
      }
      throw OpenAiChatCompletionsClient.stageError(error as Error)
    }
  }

  private static endpoint(baseUrl: string): string {
    const normalized: string = baseUrl.trim().replace(/\/+$/, '')
    if (!normalized.startsWith('https://')) {
      throw new Error('Comment translation provider base URL must use HTTPS')
    }
    return normalized.endsWith('/v1')
      ? normalized + '/chat/completions'
      : normalized + '/v1/chat/completions'
  }

  private static extractText(body: string): string {
    if (body.length === 0) {
      throw new ComicProviderStageError('protocol', 'output_missing')
    }
    try {
      const response: ChatCompletionResponse = JSON.parse(body) as ChatCompletionResponse
      if (!Array.isArray(response.choices) || response.choices.length === 0) {
        throw new Error('choices missing')
      }
      const first: ChatCompletionChoice = response.choices[0]
      const text: string = first !== undefined && first.message !== undefined &&
        typeof first.message.content === 'string'
        ? first.message.content.trim()
        : ''
      if (text.length === 0) {
        throw new Error('output missing')
      }
      return text
    } catch (error) {
      if (error instanceof ComicProviderStageError) {
        throw error as ComicProviderStageError
      }
      throw new ComicProviderStageError('protocol', 'invalid_response')
    }
  }

  private static stageError(error: Error): ComicProviderStageError {
    const message: string = error.message.toLowerCase()
    if (message.includes('timeout')) {
      return new ComicProviderStageError('transport', 'timeout')
    }
    if (message.includes('certificate') || message.includes('tls')) {
      return new ComicProviderStageError('transport', 'tls')
    }
    if (message.includes('dns')) {
      return new ComicProviderStageError('transport', 'dns')
    }
    return new ComicProviderStageError('transport', 'connection')
  }
}
