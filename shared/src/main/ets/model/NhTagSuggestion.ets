/**
 * A candidate from either the optional on-device dictionary or the public
 * catalog fallback. Its identity stays the exact namespace plus raw name; the
 * display name is never used to build a public search request.
 */
export class NhTagSuggestion {
  namespace: string = ''
  rawName: string = ''
  displayName: string = ''
}
