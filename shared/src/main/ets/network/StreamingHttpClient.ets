import { http } from '@kit.NetworkKit'

const MAX_STREAM_BYTES: number = 512 * 1024 * 1024

/** Fixed, non-sensitive outcome for one bounded streaming GET. */
export class StreamingHttpResponse {
  statusCode: number = 0
  receivedBytes: number = 0
  limitExceeded: boolean = false
  sinkRejected: boolean = false
  cancelled: boolean = false
}

/**
 * The sole NetworkKit streaming-request owner.
 *
 * Callers own only their destination and atomic promotion policy. Creation,
 * timeouts, response limits, cancellation, status capture and destruction are
 * one transaction here; no service receives or manages an HttpRequest.
 */
export class StreamingHttpClient {
  static async get(
    url: string,
    headers: Record<string, string>,
    connectTimeoutMs: number,
    readTimeoutMs: number,
    maxBytes: number,
    sink: (data: ArrayBuffer) => boolean,
    shouldContinue: () => boolean = (): boolean => true,
  ): Promise<StreamingHttpResponse> {
    if (!url.startsWith('https://') || connectTimeoutMs <= 0 || readTimeoutMs <= 0 ||
      maxBytes <= 0 || maxBytes > MAX_STREAM_BYTES) {
      throw new Error('Streaming HTTP request is invalid')
    }
    const result: StreamingHttpResponse = new StreamingHttpResponse()
    const request: http.HttpRequest = http.createHttp()
    request.on('dataReceiveProgress', (progress: http.DataReceiveProgressInfo): void => {
      if (progress.totalSize > maxBytes) {
        result.limitExceeded = true
        request.destroy()
      }
    })
    request.on('dataReceive', (data: ArrayBuffer): void => {
      if (result.limitExceeded || result.sinkRejected || result.cancelled) {
        return
      }
      let continueRequest: boolean = false
      try {
        continueRequest = shouldContinue()
      } catch (_error) {
        continueRequest = false
      }
      if (!continueRequest) {
        result.cancelled = true
        request.destroy()
        return
      }
      if (result.receivedBytes + data.byteLength > maxBytes) {
        result.limitExceeded = true
        request.destroy()
        return
      }
      try {
        if (!sink(data)) {
          result.sinkRejected = true
          request.destroy()
          return
        }
        result.receivedBytes += data.byteLength
      } catch (_error) {
        result.sinkRejected = true
        request.destroy()
      }
    })
    try {
      result.statusCode = await request.requestInStream(url, {
        method: http.RequestMethod.GET,
        usingCache: false,
        connectTimeout: connectTimeoutMs,
        readTimeout: readTimeoutMs,
        header: headers,
      })
      return result
    } catch (error) {
      if (result.limitExceeded || result.sinkRejected || result.cancelled) {
        return result
      }
      throw error as Error
    } finally {
      request.destroy()
    }
  }
}
