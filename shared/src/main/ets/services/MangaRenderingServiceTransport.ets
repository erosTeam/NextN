import { http } from '@kit.NetworkKit'

const MAX_RESPONSE_CHARS: number = 2 * 1024 * 1024

export class MangaRenderingServiceTextResponse {
  statusCode: number = 0
  body: string = ''
}

/** Small bounded HTTP transport shared by sidecar session and capability checks. */
export class MangaRenderingServiceTransport {
  static async requestText(
    url: string,
    method: http.RequestMethod,
    headers: Record<string, string>,
    body: string,
    connectTimeoutMs: number,
    readTimeoutMs: number,
    maxChars: number = MAX_RESPONSE_CHARS,
  ): Promise<MangaRenderingServiceTextResponse> {
    if (maxChars <= 0 || maxChars > MAX_RESPONSE_CHARS) {
      throw new Error('Manga rendering service response limit is invalid')
    }
    let request: http.HttpRequest | null = null
    try {
      request = http.createHttp()
      const response: http.HttpResponse = await request.request(url, {
        method: method,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        connectTimeout: connectTimeoutMs,
        readTimeout: readTimeoutMs,
        header: headers,
      })
      const result: MangaRenderingServiceTextResponse = new MangaRenderingServiceTextResponse()
      result.statusCode = response.responseCode
      result.body = typeof response.result === 'string' ? response.result : ''
      if (result.body.length > maxChars) {
        throw new Error('Manga rendering service response is too large')
      }
      return result
    } finally {
      if (request !== null) {
        request.destroy()
      }
    }
  }
}
