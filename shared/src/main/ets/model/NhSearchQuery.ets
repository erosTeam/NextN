/**
 * Route-local anonymous-search condition formatting.
 *
 * Search keeps the raw query as its only durable and submitted value. These
 * helpers deliberately serialize only the small condition grammar observed in
 * the current anonymous contract probe;
 * they never parse or rewrite terms a user entered directly.
 */
export enum NhSearchRangeRelation {
  EXACT = '',
  MINIMUM = '>=',
  MAXIMUM = '<=',
}

export enum NhSearchUploadedUnit {
  HOUR = 'h',
  DAY = 'd',
  WEEK = 'w',
  MONTH = 'm',
  YEAR = 'y',
}

export class NhSearchQuery {
  static append(query: string, fragment: string): string {
    const trimmedFragment: string = fragment.trim()
    if (trimmedFragment.length === 0) {
      return query
    }
    if (query.length === 0 || /\s$/.test(query)) {
      return `${query}${trimmedFragment}`
    }
    return `${query} ${trimmedFragment}`
  }

  static pages(value: number, relation: NhSearchRangeRelation): string {
    const normalized: number = NhSearchQuery.positiveInteger(value)
    return normalized > 0 ? `pages:${relation}${normalized}` : ''
  }

  static favorites(value: number, relation: NhSearchRangeRelation): string {
    const normalized: number = NhSearchQuery.positiveInteger(value)
    return normalized > 0 ? `favorites:${relation}${normalized}` : ''
  }

  static uploaded(
    value: number,
    unit: NhSearchUploadedUnit,
    relation: NhSearchRangeRelation,
  ): string {
    const normalized: number = NhSearchQuery.positiveInteger(value)
    if (normalized <= 0 || !NhSearchQuery.isUploadedUnit(unit)) {
      return ''
    }
    return `uploaded:${relation}${normalized}${unit}`
  }

  static isOperatorNamespace(namespace: string): boolean {
    const normalized: string = namespace.trim().toLowerCase()
    return normalized === 'pages' || normalized === 'uploaded' || normalized === 'favorites'
  }

  private static positiveInteger(value: number): number {
    if (!Number.isSafeInteger(value) || value <= 0) {
      return 0
    }
    return value
  }

  private static isUploadedUnit(unit: NhSearchUploadedUnit): boolean {
    return unit === NhSearchUploadedUnit.HOUR ||
      unit === NhSearchUploadedUnit.DAY ||
      unit === NhSearchUploadedUnit.WEEK ||
      unit === NhSearchUploadedUnit.MONTH ||
      unit === NhSearchUploadedUnit.YEAR
  }
}
