import { AxiosHttpClient, AxiosTextResponse } from '../network/AxiosHttpClient'

const MAX_RESPONSE_CHARS: number = 2 * 1024 * 1024

export class MangaRenderingServiceTextResponse {
  statusCode: number = 0
  body: string = ''
}

/** Small bounded HTTP transport shared by sidecar session and capability checks. */
export class MangaRenderingServiceTransport {
  static async requestText(
    url: string,
    method: string,
    headers: Record<string, string>,
    body: string,
    connectTimeoutMs: number,
    readTimeoutMs: number,
    maxChars: number = MAX_RESPONSE_CHARS,
  ): Promise<MangaRenderingServiceTextResponse> {
    if (maxChars <= 0 || maxChars > MAX_RESPONSE_CHARS) {
      throw new Error('Manga rendering service response limit is invalid')
    }
    const response: AxiosTextResponse = await AxiosHttpClient.requestText(
      url,
      method,
      headers,
      body,
      connectTimeoutMs,
      readTimeoutMs,
      maxChars,
    )
    const result: MangaRenderingServiceTextResponse = new MangaRenderingServiceTextResponse()
    result.statusCode = response.statusCode
    result.body = response.body
    if (result.body.length > maxChars) {
      throw new Error('Manga rendering service response is too large')
    }
    return result
  }
}
