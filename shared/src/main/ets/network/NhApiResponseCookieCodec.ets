export const NH_API_MAX_SET_COOKIE_HEADERS: number = 32
export const NH_API_MAX_SET_COOKIE_HEADER_CHARS: number = 32 * 1024

const MAX_COOKIE_EXPIRY_SECONDS: number = 253402300799

/** Bounded first-party response Cookie extraction result. */
export class NhApiResponseCookieExtraction {
  headers: string[] = []
  rejected: boolean = false
}

/**
 * Converts the two response Cookie representations exposed by NetworkKit into
 * the exact values consumed by the NH session authority.
 *
 * `HttpResponse.header` retains each original Set-Cookie field. NetworkKit's
 * `HttpResponse.cookies` is a libcurl/Netscape cookie-list snapshot and is
 * used only when the exact header channel is absent.
 */
export class NhApiResponseCookieCodec {
  static extract(
    rawHeader: string,
    rawCookies: string,
    captureRejected: boolean,
  ): NhApiResponseCookieExtraction {
    const extraction: NhApiResponseCookieExtraction = new NhApiResponseCookieExtraction()
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
            if (extraction.headers.length >= NH_API_MAX_SET_COOKIE_HEADERS || normalized.length === 0 ||
              normalized.length > NH_API_MAX_SET_COOKIE_HEADER_CHARS ||
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
