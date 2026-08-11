const MAX_BASE_URL_CHARS: number = 2048

/** Validates the non-secret endpoint before any self-hosted sidecar request. */
export class MangaRenderingServiceConfig {
  static validatedBaseUrl(baseUrl: string): string {
    const value: string = typeof baseUrl === 'string' ? baseUrl.trim() : ''
    if (value.length <= 0 || value.length > MAX_BASE_URL_CHARS || value !== baseUrl ||
      /[\r\n\t ]/.test(value)) {
      throw new Error('Manga rendering service base URL is invalid')
    }
    const match: RegExpExecArray | null = /^(https?):\/\/([^/?#]+)(\/[^?#]*)?$/.exec(value)
    if (match === null || match[2].includes('@')) {
      throw new Error('Manga rendering service base URL is invalid')
    }
    MangaRenderingServiceConfig.validateAuthority(match[2])
    if (match[1] === 'http' && !MangaRenderingServiceConfig.isPrivateAuthority(match[2])) {
      throw new Error('Public manga rendering services require HTTPS')
    }
    let result: string = value
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1)
    }
    return result
  }

  private static validateAuthority(authority: string): void {
    const hostAndPort: string[] = MangaRenderingServiceConfig.hostAndPort(authority)
    const host: string = hostAndPort[0]
    if (host.length <= 0 || /[^a-zA-Z0-9.:[\]-]/.test(host)) {
      throw new Error('Manga rendering service host is invalid')
    }
    if (hostAndPort[1].length > 0) {
      const port: number = Number.parseInt(hostAndPort[1], 10)
      if (!/^\d+$/.test(hostAndPort[1]) || port <= 0 || port > 65535) {
        throw new Error('Manga rendering service port is invalid')
      }
    }
  }

  private static isPrivateAuthority(authority: string): boolean {
    const host: string = MangaRenderingServiceConfig.hostAndPort(authority)[0].toLowerCase()
    if (host === 'localhost' || host.endsWith('.localhost') || host === '[::1]') {
      return true
    }
    const match: RegExpExecArray | null = /^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$/.exec(host)
    if (match === null) {
      return false
    }
    const first: number = Number.parseInt(match[1], 10)
    const second: number = Number.parseInt(match[2], 10)
    const third: number = Number.parseInt(match[3], 10)
    const fourth: number = Number.parseInt(match[4], 10)
    if (first > 255 || second > 255 || third > 255 || fourth > 255) {
      return false
    }
    return first === 10 || first === 127 ||
      (first === 172 && second >= 16 && second <= 31) ||
      (first === 192 && second === 168) ||
      (first === 169 && second === 254)
  }

  private static hostAndPort(authority: string): string[] {
    if (authority.startsWith('[')) {
      const close: number = authority.indexOf(']')
      if (close <= 1 || (close + 1 < authority.length && authority.charAt(close + 1) !== ':')) {
        throw new Error('Manga rendering service IPv6 host is invalid')
      }
      const result: string[] = [authority.substring(0, close + 1), '']
      if (close + 1 < authority.length) {
        result[1] = authority.substring(close + 2)
      }
      return result
    }
    const firstColon: number = authority.indexOf(':')
    const lastColon: number = authority.lastIndexOf(':')
    if (firstColon !== lastColon) {
      throw new Error('Manga rendering service IPv6 host must use brackets')
    }
    if (lastColon < 0) {
      return [authority, '']
    }
    return [authority.substring(0, lastColon), authority.substring(lastColon + 1)]
  }
}
