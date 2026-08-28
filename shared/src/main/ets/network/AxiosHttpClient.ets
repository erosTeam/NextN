import axios, { AxiosRequestConfig, AxiosResponse } from '@ohos/axios'
import { http } from '@kit.NetworkKit'

export class AxiosTextResponse {
  statusCode: number = 0
  body: string = ''
  rawHeader: string = ''
  etag: string = ''
}

export class AxiosBinaryResponse {
  statusCode: number = 0
  body: string = ''
  bytes: ArrayBuffer | null = null
  rawHeader: string = ''
}

export class AxiosHttpClient {
  static async requestText(
    url: string,
    method: string,
    headers: Record<string, string>,
    body: string,
    connectTimeoutMs: number,
    readTimeoutMs: number,
    maxResponseBytes: number = -1,
    interceptorChain: http.HttpInterceptorChain | null = null,
    maxRedirects: number = -1,
    usingCache: boolean = false,
  ): Promise<AxiosTextResponse> {
    const config: AxiosRequestConfig<string> = {
      url: url,
      method: method,
      headers: AxiosHttpClient.requestHeaders(headers, usingCache),
      responseType: 'string',
      connectTimeout: connectTimeoutMs,
      readTimeout: readTimeoutMs,
      timeout: readTimeoutMs,
      maxContentLength: maxResponseBytes,
      validateStatus: AxiosHttpClient.acceptStatus,
    }
    if (interceptorChain !== null) {
      config.interceptorChain = interceptorChain
    }
    if (maxRedirects >= 0) {
      config.maxRedirects = maxRedirects
    }
    if (body.length > 0) {
      config.data = body
    }
    const resp: AxiosResponse<string, string> =
      await axios.request<string, AxiosResponse<string, string>, string>(config)
    const out: AxiosTextResponse = new AxiosTextResponse()
    out.statusCode = resp.status
    out.body = typeof resp.data === 'string' ? resp.data : ''
    out.rawHeader = JSON.stringify(resp.headers)
    out.etag = AxiosHttpClient.responseEtag(out.rawHeader)
    return out
  }

  static async requestBinary(
    url: string,
    headers: Record<string, string>,
    maxBytes: number,
    connectTimeoutMs: number,
    readTimeoutMs: number,
    usingCache: boolean = false,
  ): Promise<AxiosBinaryResponse> {
    const config: AxiosRequestConfig<string> = {
      url: url,
      method: 'GET',
      headers: AxiosHttpClient.requestHeaders(headers, usingCache),
      responseType: 'array_buffer',
      maxContentLength: maxBytes,
      connectTimeout: connectTimeoutMs,
      readTimeout: readTimeoutMs,
      timeout: readTimeoutMs,
      validateStatus: AxiosHttpClient.acceptStatus,
    }
    const resp: AxiosResponse<ArrayBuffer, string> =
      await axios.request<ArrayBuffer, AxiosResponse<ArrayBuffer, string>, string>(config)
    const out: AxiosBinaryResponse = new AxiosBinaryResponse()
    out.statusCode = resp.status
    out.rawHeader = JSON.stringify(resp.headers)
    if (resp.data instanceof ArrayBuffer) {
      out.bytes = resp.data
    } else {
      out.body = JSON.stringify(resp.data)
    }
    return out
  }

  static async requestBinaryWithBody(
    url: string,
    method: string,
    headers: Record<string, string>,
    body: ArrayBuffer,
    maxResponseBytes: number,
    connectTimeoutMs: number,
    readTimeoutMs: number,
    usingCache: boolean = false,
  ): Promise<AxiosBinaryResponse> {
    const config: AxiosRequestConfig<ArrayBuffer> = {
      url: url,
      method: method,
      headers: AxiosHttpClient.requestHeaders(headers, usingCache),
      data: body,
      responseType: 'array_buffer',
      maxContentLength: maxResponseBytes,
      maxBodyLength: body.byteLength,
      connectTimeout: connectTimeoutMs,
      readTimeout: readTimeoutMs,
      timeout: readTimeoutMs,
      validateStatus: AxiosHttpClient.acceptStatus,
    }
    const resp: AxiosResponse<ArrayBuffer, ArrayBuffer> =
      await axios.request<ArrayBuffer, AxiosResponse<ArrayBuffer, ArrayBuffer>, ArrayBuffer>(config)
    const out: AxiosBinaryResponse = new AxiosBinaryResponse()
    out.statusCode = resp.status
    out.rawHeader = JSON.stringify(resp.headers)
    if (resp.data instanceof ArrayBuffer) {
      out.bytes = resp.data
    } else {
      out.body = JSON.stringify(resp.data)
    }
    return out
  }

  private static acceptStatus(status: number): boolean {
    return status >= 100 && status <= 599
  }

  /**
   * The bundled Harmony Axios adapter does not forward NetworkKit's
   * `usingCache` option. Preserve the callers' explicit non-cache contract at
   * the HTTP boundary instead of silently falling back to NetworkKit's
   * cache-enabled default. A caller that deliberately wants the platform
   * cache opts in and keeps its original headers unchanged.
   */
  private static requestHeaders(
    headers: Record<string, string>,
    usingCache: boolean,
  ): Record<string, string> {
    const result: Record<string, string> = {}
    const names: string[] = Object.keys(headers)
    let hasCacheControl: boolean = false
    for (let index: number = 0; index < names.length; index++) {
      const name: string = names[index]
      result[name] = headers[name]
      if (name.toLowerCase() === 'cache-control') {
        hasCacheControl = true
      }
    }
    if (!usingCache && !hasCacheControl) {
      result['Cache-Control'] = 'no-cache, no-store'
    }
    return result
  }

  private static responseEtag(rawHeader: string): string {
    const match: RegExpExecArray | null = /"etag"\s*:\s*"((?:\\.|[^"\\])*)"/i.exec(rawHeader)
    if (match === null || match[1].length === 0) {
      return ''
    }
    try {
      return JSON.parse('"' + match[1] + '"') as string
    } catch (_error) {
      return ''
    }
  }
}
