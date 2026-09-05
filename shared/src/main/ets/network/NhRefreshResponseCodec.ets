const MAX_API_TOKEN_CHARS: number = 4096

/** Validated fields from the official rotating-token refresh response. */
export class NhRefreshResponse {
  accessToken: string = ''
  refreshToken: string = ''
  accountId: string = ''
}

/**
 * Decodes the official refresh contract before any replacement credential is
 * written. A known request owner must match the response user exactly.
 */
export class NhRefreshResponseCodec {
  static decode(body: string, expectedAccountId: string = ''): NhRefreshResponse | null {
    let record: Record<string, Object>
    try {
      const parsed: Object = JSON.parse(body) as Object
      if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
        return null
      }
      record = parsed as Record<string, Object>
    } catch (_error) {
      return null
    }
    const accessValue: Object | undefined = record['access_token']
    const refreshValue: Object | undefined = record['refresh_token']
    const userValue: Object | undefined = record['user']
    if (typeof accessValue !== 'string' || typeof refreshValue !== 'string' ||
      !NhRefreshResponseCodec.validToken(accessValue as string) ||
      !NhRefreshResponseCodec.validToken(refreshValue as string) ||
      userValue === null || userValue === undefined || Array.isArray(userValue) ||
      typeof userValue !== 'object') {
      return null
    }
    const user: Record<string, Object> = userValue as Record<string, Object>
    const rawId: Object | undefined = user['id']
    if (typeof rawId !== 'number' || !Number.isSafeInteger(rawId as number) || (rawId as number) <= 0) {
      return null
    }
    const accountId: string = `${rawId as number}`
    const expected: string = expectedAccountId.trim()
    if ((expected.length > 0 && !/^[1-9][0-9]*$/.test(expected)) ||
      (expected.length > 0 && expected !== accountId)) {
      return null
    }
    const response: NhRefreshResponse = new NhRefreshResponse()
    response.accessToken = accessValue as string
    response.refreshToken = refreshValue as string
    response.accountId = accountId
    return response
  }

  private static validToken(value: string): boolean {
    return value.length > 0 && value.length <= MAX_API_TOKEN_CHARS &&
      !/[\u0000-\u001F\u007F;,]/.test(value)
  }
}
