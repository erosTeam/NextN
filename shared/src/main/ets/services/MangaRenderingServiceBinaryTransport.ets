import { http } from '@kit.NetworkKit'

const MAX_BINARY_RESPONSE_BYTES: number = 80 * 1024 * 1024

export class MangaRenderingServiceBinaryResponse {
  statusCode: number = 0
  body: Uint8Array = new Uint8Array(0)
}

/** Bounded binary POST transport for the pinned sidecar export/import protocol. */
export class MangaRenderingServiceBinaryTransport {
  static async post(
    url: string,
    headers: Record<string, string>,
    body: Uint8Array,
    maxResponseBytes: number,
    connectTimeoutMs: number,
    readTimeoutMs: number,
  ): Promise<MangaRenderingServiceBinaryResponse> {
    if (body.length <= 0 || body.length > MAX_BINARY_RESPONSE_BYTES ||
      maxResponseBytes <= 0 || maxResponseBytes > MAX_BINARY_RESPONSE_BYTES) {
      throw new Error('Manga rendering service binary request is invalid')
    }
    let request: http.HttpRequest | null = null
    try {
      request = http.createHttp()
      const rawBody: ArrayBuffer = body.buffer.slice(
        body.byteOffset,
        body.byteOffset + body.byteLength,
      )
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.POST,
        extraData: rawBody,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        connectTimeout: connectTimeoutMs,
        readTimeout: readTimeoutMs,
        header: headers,
      })
      const result: MangaRenderingServiceBinaryResponse = new MangaRenderingServiceBinaryResponse()
      result.statusCode = response.responseCode
      if (response.result instanceof ArrayBuffer) {
        if (response.result.byteLength > maxResponseBytes) {
          throw new Error('Manga rendering service binary response is too large')
        }
        result.body = new Uint8Array(response.result)
      }
      return result
    } finally {
      if (request !== null) {
        request.destroy()
      }
    }
  }
}
