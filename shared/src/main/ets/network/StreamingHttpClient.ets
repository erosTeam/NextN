import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'

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
    return new Promise<StreamingHttpResponse>((resolve, reject): void => {
      const result: StreamingHttpResponse = new StreamingHttpResponse()
      const request: http.HttpRequest = http.createHttp()
      let deadline: number = Date.now() + connectTimeoutMs + readTimeoutMs
      let settled: boolean = false
      let watchdog: number = -1
      // Native destruction is cleanup, not our completion signal. A silent
      // native promise must not pin the cache's in-flight entry or a queue slot.
      const finish = (error?: Error): void => {
        if (settled) {
          return
        }
        settled = true
        clearInterval(watchdog)
        try {
          request.destroy()
        } catch (_error) {
          // Still release our caller if the native handle is already gone.
        }
        if (error !== undefined) {
          reject(error)
        } else {
          resolve(result)
        }
      }
      const canContinue = (): boolean => {
        if (settled) {
          return false
        }
        let active: boolean = false
        try {
          active = shouldContinue()
        } catch (_error) {
          active = false
        }
        if (!active) {
          result.cancelled = true
          finish()
        }
        return active
      }
      watchdog = setInterval((): void => {
        if (canContinue() && Date.now() >= deadline) {
          finish(new Error('Image request timed out'))
        }
      }, Math.min(250, connectTimeoutMs + readTimeoutMs))
      if (!canContinue()) {
        return
      }
      try {
        request.on('dataReceiveProgress', (progress: http.DataReceiveProgressInfo): void => {
          if (!settled && progress.totalSize > maxBytes) {
            result.limitExceeded = true
            finish()
          }
        })
        request.on('dataReceive', (data: ArrayBuffer): void => {
          if (!canContinue()) {
            return
          }
          if (result.receivedBytes + data.byteLength > maxBytes) {
            result.limitExceeded = true
            finish()
            return
          }
          try {
            if (!sink(data)) {
              result.sinkRejected = true
              finish()
              return
            }
            result.receivedBytes += data.byteLength
            if (data.byteLength > 0) {
              // Bound silence, not the total lifetime of a progressing large
              // image. Repeated progress metadata is not evidence of new bytes.
              deadline = Date.now() + readTimeoutMs
            }
          } catch (_error) {
            result.sinkRejected = true
            finish()
          }
        })
        request.requestInStream(url, {
          method: http.RequestMethod.GET,
          usingCache: false,
          connectTimeout: connectTimeoutMs,
          readTimeout: readTimeoutMs,
          header: headers,
        }).then((statusCode: number): void => {
          if (canContinue()) {
            result.statusCode = statusCode
            finish()
          }
        }, (error: BusinessError): void => {
          finish(new Error(error.code === 2300028
            ? 'Image request timed out' : 'Image network request failed'))
        })
      } catch (_error) {
        finish(new Error('Image network request failed'))
      }
    })
  }
}
