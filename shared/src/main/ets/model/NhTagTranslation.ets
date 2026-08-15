/** A display-only row from the optional on-device tag dictionary. */
export class NhTagTranslationEntry {
  namespace: string = ''
  rawName: string = ''
  displayName: string = ''
}

/** Metadata for the optional dictionary without exposing its content. */
export class NhTagTranslationStatus {
  rowCount: number = 0
  version: string = ''
  source: string = ''
  updatedAt: number = 0

  isAvailable(): boolean {
    return this.rowCount > 0
  }
}

/**
 * User-facing label for a persisted tag-dictionary version. Only the
 * structured release descriptor (release:<tag>\u001f<publishedAt>...) is
 * meaningful; legacy internal fingerprints (bytes-*, fnv1a-*) must never
 * reach settings copy, so they render as an empty label.
 */
export function releaseTagTranslationVersionLabel(version: string): string {
  if (!version.startsWith('release:')) {
    return ''
  }
  const parts: string[] = version.split('\u001f')
  if (parts.length < 2) {
    return ''
  }
  const tag: string = parts[0].substring('release:'.length).trim()
  const publishedAt: string = parts[1].trim()
  if (tag.length === 0 || publishedAt.length === 0) {
    return ''
  }
  return `${tag} ${publishedAt}`
}
