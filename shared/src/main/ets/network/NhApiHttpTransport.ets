import { AxiosHttpClient, AxiosTextResponse } from './AxiosHttpClient'
import { http } from '@kit.NetworkKit'

const API_V2_PREFIX: string = 'https://nhentai.net/api/v2/'
const CONNECT_TIMEOUT_MS: number = 20000
const READ_TIMEOUT_MS: number = 20000
const MAX_REQUEST_BODY_CHARS: number = 512 * 1024
const MAX_RESPONSE_BODY_BYTES: number = 4 * 1024 * 1024
const MAX_AUTHORIZATION_CHARS: number = 8192
const MAX_RETRY_AFTER_MS: number = 24 * 60 * 60 * 1000
const MAX_SET_COOKIE_HEADERS: number = 32
const MAX_SET_COOKIE_HEADER_CHARS: number = 32 * 1024
const MAX_RESPONSE_HEADER_CHARS: number = 1024 * 1024
const MAX_COOKIE_EXPIRY_SECONDS: number = 253402300799

/** Bounded response metadata exposed to the NH session lifecycle. */
export class NhApiHttpResponse {
  statusCode: number = 0
  body: string = ''
  retryAfterMs: number = 0
  /** First-party response cookie values; never logged or exposed to feature code. */
  setCookieHeaders: string[] = []
  /** The response advertised Set-Cookie metadata that could not be consumed losslessly. */
  setCookieHeadersRejected: boolean = false
}

class NhApiSetCookieExtraction {
  headers: string[] = []
  rejected: boolean = false
}

/**
 * Harmony NetworkKit exposes exact Set-Cookie fields in `HttpResponse.header`
 * and a libcurl/Netscape cookie-jar snapshot in `HttpResponse.cookies`.
 * @ohos/axios 2.2.12 does not forward the latter into AxiosResponse, so one
 * system final-response interceptor retains both bounded values for the sole
 * session boundary. Neither value is logged or returned to feature code.
 */
class NhApiResponseCookieCapture implements http.HttpInterceptor {
  interceptorType: http.InterceptorType = http.InterceptorType.FINAL_RESPONSE
  rawHeader: string = ''
  rawCookies: string = ''
  rejected: boolean = false
  observed: boolean = false

  async interceptorHandle(
    _request: http.HttpRequestContext,
    response: http.HttpResponse,
  ): Promise<http.ChainContinue> {
    this.observed = true
    let rawHeader: string = ''
    try {
      rawHeader = JSON.stringify(response.header)
    } catch (_error) {
      this.rejected = true
      return true
    }
    const rawCookies: string = response.cookies
    if (rawHeader.length > MAX_RESPONSE_HEADER_CHARS ||
      rawCookies.length > MAX_SET_COOKIE_HEADERS * MAX_SET_COOKIE_HEADER_CHARS) {
      this.rejected = true
      this.rawHeader = ''
      this.rawCookies = ''
      return true
    }
    this.rawHeader = rawHeader
    this.rawCookies = rawCookies
    return true
  }
}

/**
 * The sole wire transport for NH API v2 JSON.
 *
 * It has no account state, Cookie storage or retry policy. It does retain the
 * bounded first-party Set-Cookie response values so `NhSessionHttpClient` can
 * feed every response through the sole Cookie/session authority before a
 * caller sees it. ArkWeb is therefore a visible CAPTCHA host, not an HTTP
 * client or credential authority.
 */
export class NhApiHttpTransport {
  static async requestJson(
    url: string,
    method: string,
    body: string = '',
    authorization: string = '',
  ): Promise<NhApiHttpResponse> {
    const normalizedMethod: string = method.toUpperCase()
    if (!url.startsWith(API_V2_PREFIX)) {
      throw new Error('NH API transport is restricted to the first-party API')
    }
    if (normalizedMethod !== 'GET' && normalizedMethod !== 'POST' && normalizedMethod !== 'DELETE') {
      throw new Error('NH API transport received an unsupported method')
    }
    if (body.length > MAX_REQUEST_BODY_CHARS ||
      (normalizedMethod === 'GET' && body.length > 0)) {
      throw new Error('NH API request body is invalid')
    }
    if (!NhApiHttpTransport.isSafeAuthorization(authorization)) {
      throw new Error('NH API authorization is invalid')
    }
    const headers: Record<string, string> = {
      'Accept': 'application/json',
      'Cache-Control': 'no-cache, no-store',
    }
    if (body.length > 0) {
      headers['Content-Type'] = 'application/json'
    }
    if (authorization.length > 0) {
      headers['Authorization'] = authorization
    }
    const cookieCapture: NhApiResponseCookieCapture = new NhApiResponseCookieCapture()
    const interceptorChain: http.HttpInterceptorChain = new http.HttpInterceptorChain()
    if (!interceptorChain.addChain([cookieCapture])) {
      throw new Error('NH API response Cookie interceptor is unavailable')
    }
    const wire: AxiosTextResponse = await AxiosHttpClient.requestText(
      url,
      normalizedMethod,
      headers,
      body,
      CONNECT_TIMEOUT_MS,
      READ_TIMEOUT_MS,
      MAX_RESPONSE_BODY_BYTES,
      interceptorChain,
      // The request URL is first-party-fenced above. Do not let an opaque
      // adapter redirect bypass that origin check or hide an intermediate
      // response Cookie from the sole session lifecycle.
      0,
    )
    const response: NhApiHttpResponse = new NhApiHttpResponse()
    response.statusCode = wire.statusCode
    response.body = wire.body
    response.retryAfterMs = NhApiHttpTransport.retryAfterMs(wire.rawHeader)
    const responseCookies: NhApiSetCookieExtraction = NhApiHttpTransport.setCookieHeaders(
      cookieCapture.rawHeader,
      cookieCapture.rawCookies,
      cookieCapture.rejected || !cookieCapture.observed,
    )
    response.setCookieHeaders = responseCookies.headers
    response.setCookieHeadersRejected = responseCookies.rejected
    return response
  }

  private static isSafeAuthorization(value: string): boolean {
    return value.length === 0 ||
      (value.startsWith('User ') && value.length <= MAX_AUTHORIZATION_CHARS &&
        !/[\u0000-\u001F\u007F;,]/.test(value))
  }

  private static retryAfterMs(rawHeader: string): number {
    if (rawHeader.length === 0) {
      return 0
    }
    try {
      const parsed: Object = JSON.parse(rawHeader) as Object
      if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
        return 0
      }
      const headers: Record<string, Object> = parsed as Record<string, Object>
      let rawValue: string = ''
      Object.keys(headers).forEach((name: string): void => {
        if (name.toLowerCase() === 'retry-after' && typeof headers[name] === 'string') {
          rawValue = headers[name] as string
        }
      })
      if (/^[0-9]+$/.test(rawValue)) {
        return Math.min(MAX_RETRY_AFTER_MS, Number(rawValue) * 1000)
      }
      const deadline: number = Date.parse(rawValue)
      const remaining: number = Number.isFinite(deadline) ? deadline - Date.now() : 0
      return remaining > 0 ? Math.min(MAX_RETRY_AFTER_MS, Math.floor(remaining)) : 0
    } catch (_error) {
      return 0
    }
  }

  /**
   * Preserve exact first-party Set-Cookie fields when NetworkKit exposes them.
   * If that header channel is absent, convert NetworkKit's source-defined libcurl
   * cookie-jar snapshot (domain, tailmatch, path, secure, expiry, name, value)
   * back into bounded Set-Cookie values. A combined exact header is split only
   * before a new cookie-pair, never at the comma inside an Expires attribute.
   */
  private static setCookieHeaders(
    rawHeader: string,
    rawCookies: string,
    captureRejected: boolean,
  ): NhApiSetCookieExtraction {
    const extraction: NhApiSetCookieExtraction = new NhApiSetCookieExtraction()
    extraction.rejected = captureRejected
    if (extraction.rejected || (rawHeader.length === 0 && rawCookies.length === 0)) {
      return extraction
    }
    let exactSetCookieObserved: boolean = false
    const collectHeader = (rawValue: string): void => {
      if (extraction.rejected) {
        return
      }
      rawValue.split(/\r?\n/).forEach((line: string): void => {
        if (extraction.rejected) {
          return
        }
        line.split(/,\s*(?=[!#$%&'*+\-.^_`|~0-9A-Za-z]+=)/)
          .forEach((candidate: string): void => {
            const normalized: string = candidate.trim()
            if (extraction.rejected) {
              return
            }
            if (extraction.headers.length >= MAX_SET_COOKIE_HEADERS || normalized.length === 0 ||
              normalized.length > MAX_SET_COOKIE_HEADER_CHARS ||
              /[\u0000-\u001F\u007F]/.test(normalized)) {
              extraction.rejected = true
              return
            }
            if (extraction.headers.indexOf(normalized) < 0) {
              extraction.headers.push(normalized)
            }
          })
      })
    }
    if (rawHeader.length > 0) {
      try {
        const parsed: Object = JSON.parse(rawHeader) as Object
        if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
          extraction.rejected = true
          return extraction
        }
        const headers: Record<string, Object> = parsed as Record<string, Object>
        Object.keys(headers).forEach((name: string): void => {
          if (name.toLowerCase() !== 'set-cookie' || extraction.rejected) {
            return
          }
          exactSetCookieObserved = true
          const value: Object = headers[name]
          if (typeof value === 'string') {
            collectHeader(value as string)
          } else if (Array.isArray(value)) {
            const values: Object[] = value as Object[]
            if (values.length === 0) {
              extraction.rejected = true
              return
            }
            values.forEach((entry: Object): void => {
              if (typeof entry === 'string') {
                collectHeader(entry as string)
              } else {
                extraction.rejected = true
              }
            })
          } else {
            extraction.rejected = true
          }
        })
      } catch (_error) {
        extraction.rejected = true
      }
    }
    if (!extraction.rejected && !exactSetCookieObserved && rawCookies.length > 0) {
      rawCookies.split(/\r?\n/).forEach((rawLine: string): void => {
        if (extraction.rejected || rawLine.length === 0) {
          return
        }
        let line: string = rawLine
        let httpOnly: boolean = false
        if (line.startsWith('#HttpOnly_')) {
          httpOnly = true
          line = line.slice('#HttpOnly_'.length)
        } else if (line.startsWith('#')) {
          return
        }
        const fields: string[] = line.split('\t')
        if (fields.length !== 7) {
          extraction.rejected = true
          return
        }
        const rawDomain: string = fields[0]
        const includeSubdomains: string = fields[1]
        const path: string = fields[2]
        const secure: string = fields[3]
        const rawExpires: string = fields[4]
        const name: string = fields[5]
        const value: string = fields[6]
        const domain: string = rawDomain.startsWith('.')
          ? rawDomain.slice(1).toLowerCase()
          : rawDomain.toLowerCase()
        const expirySeconds: number = Number(rawExpires)
        if (domain !== 'nhentai.net' ||
          (includeSubdomains !== 'TRUE' && includeSubdomains !== 'FALSE') ||
          (secure !== 'TRUE' && secure !== 'FALSE') ||
          path.length === 0 || !path.startsWith('/') || /[\u0000-\u001F\u007F;]/.test(path) ||
          !/^[0-9]{1,12}$/.test(rawExpires) || !Number.isSafeInteger(expirySeconds) ||
          expirySeconds < 0 || expirySeconds > MAX_COOKIE_EXPIRY_SECONDS ||
          !/^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$/.test(name) ||
          /[\u0000-\u0020\u007F;,"\\]/.test(value)) {
          extraction.rejected = true
          return
        }
        let header: string = `${name}=${value}`
        if (includeSubdomains === 'TRUE') {
          header += '; Domain=.nhentai.net'
        }
        header += `; Path=${path}`
        if (expirySeconds > 0) {
          const expiry: string = new Date(expirySeconds * 1000).toUTCString()
          if (expiry === 'Invalid Date') {
            extraction.rejected = true
            return
          }
          header += `; Expires=${expiry}`
        }
        if (secure === 'TRUE') {
          header += '; Secure'
        }
        if (httpOnly) {
          header += '; HttpOnly'
        }
        collectHeader(header)
      })
    }
    return extraction
  }
}
