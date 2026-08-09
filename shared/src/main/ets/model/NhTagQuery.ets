import { NhTag } from './NhGallery'

/**
 * Builds the canonical query fragment used when a gallery tag opens the
 * anonymous search surface. The type aliases mirror ErosN's query contract
 * while keeping navigation out of the shared module.
 */
export class NhTagQuery {
  static format(tag: NhTag): string {
    const type: string = NhTagQuery.normalizeType(tag.type)
    return NhTagQuery.formatParts(type, tag.name)
  }

  /**
   * Formats a dictionary suggestion without collapsing its source namespace.
   * This keeps `female`, `male`, `mixed`, and `other` distinct from generic
   * tags while preserving the existing gallery-tag compatibility mapping.
   */
  static formatExact(namespace: string, rawName: string): string {
    return NhTagQuery.formatParts(NhTagQuery.exactNamespace(namespace), rawName)
  }

  private static formatParts(type: string, rawName: string): string {
    const name: string = rawName.trim()
    // ErosN has no proven escaping rule for a quote inside a tag name. Do not
    // manufacture a query with different semantics; leave that tag visible
    // but non-navigable until its syntax is verified.
    if (type.length === 0 || name.length === 0 || name.includes('"')) {
      return ''
    }
    const term: string = name.includes(' ') ? `"${name}"` : name
    return `${type}:${term}`
  }

  private static normalizeType(rawType: string): string {
    const type: string = rawType.trim().toLowerCase()
    switch (type) {
      case 'tag':
      case 'tags':
      case 'female':
      case 'male':
      case 'mixed':
      case 'other':
        return 'tag'
      case 'parody':
      case 'parodies':
        return 'parody'
      case 'character':
      case 'characters':
        return 'character'
      case 'artist':
      case 'artists':
      case 'cosplayer':
        return 'artist'
      case 'group':
      case 'groups':
        return 'group'
      case 'language':
      case 'languages':
        return 'language'
      case 'category':
      case 'categories':
      case 'reclass':
        return 'category'
      default:
        return type
    }
  }

  private static exactNamespace(rawNamespace: string): string {
    const namespace: string = rawNamespace.trim().toLowerCase()
    return /^[a-z][a-z0-9_-]{0,31}$/.test(namespace) ? namespace : ''
  }
}
