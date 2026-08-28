import { AxiosBinaryResponse, AxiosHttpClient } from '../network/AxiosHttpClient'

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
    const rawBody: ArrayBuffer = body.buffer.slice(
      body.byteOffset,
      body.byteOffset + body.byteLength,
    )
    const response: AxiosBinaryResponse = await AxiosHttpClient.requestBinaryWithBody(
      url,
      'POST',
      headers,
      rawBody,
      maxResponseBytes,
      connectTimeoutMs,
      readTimeoutMs,
    )
    const result: MangaRenderingServiceBinaryResponse = new MangaRenderingServiceBinaryResponse()
    result.statusCode = response.statusCode
    if (response.bytes !== null) {
      if (response.bytes.byteLength > maxResponseBytes) {
        throw new Error('Manga rendering service binary response is too large')
      }
      result.body = new Uint8Array(response.bytes)
    }
    return result
  }
}
