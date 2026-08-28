import { MangaRenderingServiceConfig } from './MangaRenderingServiceConfig'
import { MangaRenderingServiceCredential } from './MangaRenderingServiceSecretStore'
import { MangaRenderingServiceSession } from './MangaRenderingServiceSession'
import { MangaRenderingServiceTextResponse, MangaRenderingServiceTransport } from './MangaRenderingServiceTransport'

const OPENAPI_PATH: string = '/openapi.json'
const AUTH_CHECK_PATH: string = '/auth/check'
const EXPORT_PATH: string = '/translate/export/original'
const IMPORT_PATH: string = '/translate/import/json/nexte-load-text-v2'
const MAX_RESPONSE_CHARS: number = 2 * 1024 * 1024
const CONNECT_TIMEOUT_MS: number = 15000
const READ_TIMEOUT_MS: number = 15000

class OpenApiOperation {
  post: Object | null = null
  get: Object | null = null
}

class OpenApiEnvelope {
  paths: Record<string, OpenApiOperation> = {}
}

class AuthCheckEnvelope {
  valid: boolean = false
}

/** Checks the pinned self-hosted protocol before Reader may select it. */
export class MangaRenderingServiceConnection {
  static async check(baseUrl: string, credential: MangaRenderingServiceCredential): Promise<void> {
    const validatedBaseUrl: string = MangaRenderingServiceConfig.validatedBaseUrl(baseUrl)
    const response: MangaRenderingServiceTextResponse = await MangaRenderingServiceTransport.requestText(
      validatedBaseUrl + OPENAPI_PATH,
      'GET',
      { 'Accept': 'application/json', 'User-Agent': 'NextN manga translation' },
      '',
      CONNECT_TIMEOUT_MS,
      READ_TIMEOUT_MS,
      MAX_RESPONSE_CHARS,
    )
    if (response.statusCode !== 200) {
      throw new Error('Manga rendering service capability check failed')
    }
    MangaRenderingServiceConnection.requireCapabilities(response.body)
    const token: string = await MangaRenderingServiceSession.acquire(validatedBaseUrl, credential)
    const auth: MangaRenderingServiceTextResponse = await MangaRenderingServiceTransport.requestText(
      validatedBaseUrl + AUTH_CHECK_PATH,
      'GET',
      {
        'Accept': 'application/json',
        'User-Agent': 'NextN manga translation',
        'X-Session-Token': token,
      },
      '',
      CONNECT_TIMEOUT_MS,
      READ_TIMEOUT_MS,
      MAX_RESPONSE_CHARS,
    )
    if (auth.statusCode === 401) {
      MangaRenderingServiceSession.invalidate(validatedBaseUrl, credential, token)
    }
    MangaRenderingServiceConnection.requireAuthenticated(auth)
  }

  private static requireCapabilities(raw: string): void {
    if (raw.length === 0 || raw.length > MAX_RESPONSE_CHARS) {
      throw new Error('Manga rendering service capability response is invalid')
    }
    let parsed: OpenApiEnvelope
    try {
      parsed = JSON.parse(raw) as OpenApiEnvelope
    } catch (_error) {
      throw new Error('Manga rendering service returned invalid capability data')
    }
    if (parsed === null || typeof parsed !== 'object' || parsed.paths === null ||
      typeof parsed.paths !== 'object' ||
      !MangaRenderingServiceConnection.hasPost(parsed, EXPORT_PATH) ||
      !MangaRenderingServiceConnection.hasPost(parsed, IMPORT_PATH) ||
      !MangaRenderingServiceConnection.hasPost(parsed, '/auth/login') ||
      !MangaRenderingServiceConnection.hasGet(parsed, AUTH_CHECK_PATH)) {
      throw new Error('Manga rendering service does not support the pinned protocol')
    }
  }

  private static requireAuthenticated(response: MangaRenderingServiceTextResponse): void {
    if (response.statusCode !== 200 || response.body.length === 0 ||
      response.body.length > MAX_RESPONSE_CHARS) {
      throw new Error('Manga rendering service authentication check failed')
    }
    let parsed: AuthCheckEnvelope
    try {
      parsed = JSON.parse(response.body) as AuthCheckEnvelope
    } catch (_error) {
      throw new Error('Manga rendering service returned invalid authentication data')
    }
    if (parsed === null || typeof parsed !== 'object' || parsed.valid !== true) {
      throw new Error('Manga rendering service session is invalid')
    }
  }

  private static hasPost(envelope: OpenApiEnvelope, path: string): boolean {
    const item: OpenApiOperation | undefined = envelope.paths[path]
    return item !== undefined && item !== null && typeof item === 'object' &&
      item.post !== null && typeof item.post === 'object'
  }

  private static hasGet(envelope: OpenApiEnvelope, path: string): boolean {
    const item: OpenApiOperation | undefined = envelope.paths[path]
    return item !== undefined && item !== null && typeof item === 'object' &&
      item.get !== null && typeof item.get === 'object'
  }
}
