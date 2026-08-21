import { NhTag } from './NhGallery'

/**
 * Builds the canonical query fragment used when a gallery tag opens the
 * anonymous search surface. The type aliases mirror ErosN's query contract
 * while keeping navigation out of the shared module.
 */
export class NhTagQuery {
  static format(tag: NhTag): string {
    const type: string = NhTagQuery.canonicalNamespace(tag.type)
    return NhTagQuery.formatParts(type, tag.name)
  }

  /**
   * Formats a suggestion using NH's canonical singular query namespace.
   * EhTagTranslation's `female`, `male`, `mixed`, and `other` buckets are
   * storage-only categories; ErosN collapses all four to NH's `tag:` before a
   * candidate is displayed or committed to the query.
   */
  static formatExact(namespace: string, rawName: string, excluded: boolean = false): string {
    const query: string = NhTagQuery.formatParts(NhTagQuery.canonicalNamespace(namespace), rawName)
    return excluded && query.length > 0 ? `-${query}` : query
  }

  /**
   * Limits autocomplete to the aliases currently mapped by `NhApiClient`'s
   * anonymous suggestion path. Range operators such as `pages:` are therefore
   * not misclassified as a tag namespace and never fan out into remote probes.
   */
  static isAutocompleteNamespace(rawNamespace: string): boolean {
    return NhTagQuery.canonicalNamespace(rawNamespace).length > 0
  }

  /**
   * Single NH namespace map shared by autocomplete, local dictionary
   * adaptation, gallery-tag navigation and query editors. Unknown source
   * buckets are not valid NH query namespaces.
   */
  static canonicalNamespace(rawNamespace: string): string {
    const namespace: string = rawNamespace.trim().toLowerCase()
    switch (namespace) {
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
        return ''
    }
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

}
