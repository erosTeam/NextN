import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { util } from '@kit.ArkTS'
import { http } from '@kit.NetworkKit'
import { MangaRenderingServiceCredential } from './MangaRenderingServiceSecretStore'
import { MangaRenderingServiceTextResponse, MangaRenderingServiceTransport } from './MangaRenderingServiceTransport'

const LOGIN_PATH: string = '/auth/login'
const MAX_TOKEN_CHARS: number = 8192
const MAX_RESPONSE_CHARS: number = 64 * 1024
const CONNECT_TIMEOUT_MS: number = 15000
const READ_TIMEOUT_MS: number = 15000

class LoginRequest {
  username: string = ''
  password: string = ''
}

class LoginResponse {
  success: boolean = false
  token: string = ''
  must_change_password: boolean = false
}

class SessionEntry {
  credentialHash: string = ''
  token: string = ''
}

/** In-memory sidecar session cache. Durable storage contains the account only. */
export class MangaRenderingServiceSession {
  private static sessions: Map<string, SessionEntry> = new Map<string, SessionEntry>()
  private static inFlight: Map<string, Promise<string>> = new Map<string, Promise<string>>()

  static async acquire(baseUrl: string, credential: MangaRenderingServiceCredential): Promise<string> {
    if (!credential.configured()) {
      throw new Error('Manga rendering service account is not configured')
    }
    const cacheKey: string = baseUrl + ':' + MangaRenderingServiceSession.digest(credential.username)
    const credentialHash: string = MangaRenderingServiceSession.digest(
      credential.username + '\n' + credential.password,
    )
    const cached: SessionEntry | undefined = MangaRenderingServiceSession.sessions.get(cacheKey)
    if (cached !== undefined && cached.credentialHash === credentialHash) {
      return cached.token
    }
    const existing: Promise<string> | undefined = MangaRenderingServiceSession.inFlight.get(cacheKey)
    if (existing !== undefined) {
      return await existing
    }
    const pending: Promise<string> = MangaRenderingServiceSession.login(
      baseUrl,
      credential,
      credentialHash,
      cacheKey,
    )
    MangaRenderingServiceSession.inFlight.set(cacheKey, pending)
    try {
      return await pending
    } finally {
      if (MangaRenderingServiceSession.inFlight.get(cacheKey) === pending) {
        MangaRenderingServiceSession.inFlight.delete(cacheKey)
      }
    }
  }

  static invalidate(baseUrl: string, credential: MangaRenderingServiceCredential, rejectedToken: string): void {
    const cacheKey: string = baseUrl + ':' + MangaRenderingServiceSession.digest(credential.username)
    const cached: SessionEntry | undefined = MangaRenderingServiceSession.sessions.get(cacheKey)
    if (cached !== undefined && cached.token === rejectedToken) {
      MangaRenderingServiceSession.sessions.delete(cacheKey)
    }
  }

  static clear(): void {
    MangaRenderingServiceSession.sessions.clear()
    MangaRenderingServiceSession.inFlight.clear()
  }

  private static async login(
    baseUrl: string,
    credential: MangaRenderingServiceCredential,
    credentialHash: string,
    cacheKey: string,
  ): Promise<string> {
    const request: LoginRequest = new LoginRequest()
    request.username = credential.username
    request.password = credential.password
    const response: MangaRenderingServiceTextResponse = await MangaRenderingServiceTransport.requestText(
      baseUrl + LOGIN_PATH,
      http.RequestMethod.POST,
      {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'NextN manga translation',
      },
      JSON.stringify(request),
      CONNECT_TIMEOUT_MS,
      READ_TIMEOUT_MS,
      MAX_RESPONSE_CHARS,
    )
    if (response.statusCode !== 200 || response.body.length === 0) {
      throw new Error('Manga rendering service login failed')
    }
    let parsed: LoginResponse
    try {
      parsed = JSON.parse(response.body) as LoginResponse
    } catch (_error) {
      throw new Error('Manga rendering service returned invalid login data')
    }
    if (parsed === null || typeof parsed !== 'object' || parsed.success !== true ||
      typeof parsed.token !== 'string' || parsed.token.length === 0 ||
      parsed.token.length > MAX_TOKEN_CHARS || /[\r\n]/.test(parsed.token) ||
      parsed.must_change_password === true) {
      throw new Error('Manga rendering service login failed')
    }
    const entry: SessionEntry = new SessionEntry()
    entry.credentialHash = credentialHash
    entry.token = parsed.token
    MangaRenderingServiceSession.sessions.set(cacheKey, entry)
    return entry.token
  }

  private static digest(value: string): string {
    const digest = cryptoFramework.createMd('SHA256')
    digest.updateSync({ data: new util.TextEncoder().encodeInto(value) })
    const bytes: Uint8Array = digest.digestSync().data
    let result: string = ''
    for (let index: number = 0; index < bytes.length; index++) {
      result += bytes[index].toString(16).padStart(2, '0')
    }
    return result
  }
}
