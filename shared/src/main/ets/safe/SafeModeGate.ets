import { NhGallerySummary, NhTag } from '../model/NhGallery'
import { connectSafeMode } from '../state/SafeModeState'

export const SAFE_MODE_QUERY: string = 'tag:non-h'
const SAFE_MODE_TAG_FRAGMENT: string = 'non-h'

export class SafeModeGate {
  static restricted(): boolean {
    return connectSafeMode().restricted()
  }

  /**
   * Preserve the selected Home subtab's request identity while intersecting
   * its anonymous NH query with the review-safe tag.
   */
  static safeQuery(query: string): string {
    const trimmed: string = query.trim()
    if (!SafeModeGate.restricted()) {
      return trimmed
    }
    if (trimmed.toLowerCase().split(/\s+/).indexOf(SAFE_MODE_QUERY) >= 0) {
      return trimmed
    }
    return trimmed.length === 0 ? SAFE_MODE_QUERY : `${trimmed} ${SAFE_MODE_QUERY}`
  }

  /** Fail closed if an endpoint or stale cache returns a row outside Non-H. */
  static safeRows(rows: NhGallerySummary[]): NhGallerySummary[] {
    if (!SafeModeGate.restricted()) {
      return rows
    }
    return rows.filter((gallery: NhGallerySummary): boolean =>
      gallery.tags.some((tag: NhTag): boolean =>
        tag.name.trim().toLowerCase().indexOf(SAFE_MODE_TAG_FRAGMENT) >= 0),
    )
  }

  static safeCacheScope(value: string): string {
    return SafeModeGate.restricted() ? `${value}:safe-mode-non-h` : value
  }

  static routeAllowed(name: string): boolean {
    if (!SafeModeGate.restricted()) {
      return true
    }
    if (name === 'search' ||
      name === 'homeSubtabManager' ||
      name === 'homeSubtabEdit' ||
      name === 'popular' ||
      name === 'galleryWeb' ||
      name === 'comments' ||
      name === 'browserSession' ||
      name === 'account' ||
      name === 'syncSettings' ||
      name === 'webDavSyncSettings' ||
      name === 'history' ||
      name === 'llmSourceManager' ||
      name === 'llmSourceDetail' ||
      name === 'mangaRenderingService' ||
      name === 'tagTranslationSettings' ||
      name === 'commentTranslationSettings' ||
      name === 'comicTranslationSettings' ||
      name === 'toriiWholePageLiveEvaluation') {
      return false
    }
    return true
  }
}
