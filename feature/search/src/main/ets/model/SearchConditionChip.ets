import { NhTagQuery } from 'shared'

export enum SearchConditionKind {
  PLAIN = 'plain',
  TAG = 'tag',
  RANGE = 'range',
  UNKNOWN = 'unknown',
}

export enum SearchConditionRelation {
  INCLUDE = 'include',
  EXCLUDE = 'exclude',
}

/**
 * One structured view of a query token in the search-options sheet. The
 * query text remains the only submitted truth; chips are a reversible
 * projection so each active condition can be read and removed without
 * hand-editing the raw string.
 */
export class SearchConditionChip {
  /** Exact token in the query string, including any -/~ prefix. */
  rawToken: string = ''
  /** Stable position in the canonical token stream. */
  tokenIndex: number = -1
  /** Canonical user-facing title without the relation prefix. */
  title: string = ''
  /** Compatibility alias for existing call sites. */
  label: string = ''
  /** True when the token is one this sheet knows how to rebuild. */
  structured: boolean = false
  kind: SearchConditionKind = SearchConditionKind.UNKNOWN
  relation: SearchConditionRelation = SearchConditionRelation.INCLUDE
  relationEditable: boolean = false
  namespace: string = ''
  rawValue: string = ''
}

/** Editable projection of one numeric NH query namespace. */
export class SearchConditionRange {
  minimumText: string = ''
  maximumText: string = ''
  unit: string = ''
}

export class SearchConditionParser {
  private static readonly OPERATOR_NAMESPACES: string[] = ['pages', 'favorites', 'uploaded']

  static chips(query: string, operatorLabels: (key: string) => string): SearchConditionChip[] {
    const chips: SearchConditionChip[] = []
    SearchConditionParser.tokens(query).forEach((raw: string, tokenIndex: number): void => {
      const chip: SearchConditionChip = new SearchConditionChip()
      chip.rawToken = raw
      chip.tokenIndex = tokenIndex
      let content: string = raw
      if (content.startsWith('-')) {
        chip.relation = SearchConditionRelation.EXCLUDE
        content = content.substring(1)
      }
      // NH's public search contract does not implement NextE/EH's leading
      // tilde as OR. Preserve such manually-entered tokens verbatim instead of
      // presenting or rewriting them as a supported relation.
      if (content.startsWith('~')) {
        chip.title = raw
        chip.label = raw
        chips.push(chip)
        return
      }
      if (SearchConditionParser.isQuoted(content)) {
        const value: string = SearchConditionParser.unquote(content)
        if (value.length > 0) {
          chip.kind = SearchConditionKind.PLAIN
          chip.rawValue = value
          chip.title = SearchConditionParser.formatPlain(value)
          chip.structured = chip.title.length > 0
          chip.relationEditable = chip.structured
        }
      }
      const colon: number = content.indexOf(':')
      if (chip.kind === SearchConditionKind.UNKNOWN && colon > 0) {
        const namespace: string = content.substring(0, colon).trim().toLowerCase()
        let value: string = content.substring(colon + 1).trim()
        if (SearchConditionParser.isQuoted(value)) {
          value = SearchConditionParser.unquote(value)
        }
        if (SearchConditionParser.OPERATOR_NAMESPACES.indexOf(namespace) >= 0) {
          const relation: string = value.startsWith('>=') || value.startsWith('<=') ? value.substring(0, 2) : ''
          const numberText: string = relation.length > 0 ? value.substring(2) : value
          if (/^[0-9]+[hdwmy]?$/.test(numberText)) {
            chip.kind = SearchConditionKind.RANGE
            chip.title = operatorLabels(namespace) + ' ' +
              SearchConditionParser.relationLabel(relation) + ' ' + numberText
            chip.structured = true
          }
        } else if (NhTagQuery.isAutocompleteNamespace(namespace) && value.length > 0) {
          const canonical: string = NhTagQuery.formatExact(namespace, value)
          if (canonical.length > 0) {
            chip.kind = SearchConditionKind.TAG
            chip.namespace = namespace
            chip.rawValue = value
            chip.title = canonical
            chip.structured = true
            chip.relationEditable = true
          }
        }
      }
      if (chip.kind === SearchConditionKind.UNKNOWN && colon < 0 && content.length > 0) {
        chip.kind = SearchConditionKind.PLAIN
        chip.rawValue = content
        chip.title = content
        chip.structured = true
        chip.relationEditable = true
      }
      chip.label = chip.title.length > 0 ? chip.title : raw
      chips.push(chip)
    })
    return chips
  }

  static removeToken(query: string, token: string): string {
    return SearchConditionParser.tokens(query)
      .filter((candidate: string): boolean => candidate !== token)
      .join(' ')
  }

  static removeTokenAt(query: string, tokenIndex: number): string {
    return SearchConditionParser.tokens(query)
      .filter((_candidate: string, index: number): boolean => index !== tokenIndex)
      .join(' ')
  }

  static setExcluded(query: string, tokenIndex: number, excluded: boolean): string {
    return SearchConditionParser.tokens(query)
      .map((candidate: string, index: number): string => {
        if (index !== tokenIndex || candidate.startsWith('~')) {
          return candidate
        }
        const content: string = candidate.startsWith('-') ? candidate.substring(1) : candidate
        return excluded ? `-${content}` : content
      })
      .join(' ')
  }

  static formatPlain(value: string): string {
    const normalized: string = value.trim()
    if (normalized.length === 0 || normalized.includes('"')) {
      return ''
    }
    return /\s/.test(normalized) ? `"${normalized}"` : normalized
  }

  static range(query: string, namespace: string): SearchConditionRange {
    const result: SearchConditionRange = new SearchConditionRange()
    const expected: string = namespace.trim().toLowerCase()
    SearchConditionParser.tokens(query).forEach((raw: string): void => {
      const parsed: SearchConditionRange | null = SearchConditionParser.rangeToken(raw, expected)
      if (parsed === null) {
        return
      }
      if (parsed.minimumText.length > 0) {
        result.minimumText = parsed.minimumText
      }
      if (parsed.maximumText.length > 0) {
        result.maximumText = parsed.maximumText
      }
      if (result.unit.length === 0 && parsed.unit.length > 0) {
        result.unit = parsed.unit
      }
    })
    return result
  }

  static isRangeToken(token: string): boolean {
    for (let index: number = 0; index < SearchConditionParser.OPERATOR_NAMESPACES.length; index++) {
      if (SearchConditionParser.rangeToken(token, SearchConditionParser.OPERATOR_NAMESPACES[index]) !== null) {
        return true
      }
    }
    return false
  }

  static isPlainToken(token: string): boolean {
    let content: string = token.trim()
    if (content.startsWith('-')) {
      content = content.substring(1)
    }
    if (content.startsWith('~')) {
      return false
    }
    if (SearchConditionParser.isQuoted(content)) {
      return true
    }
    return content.indexOf(':') < 1
  }

  static plainText(query: string): string {
    return SearchConditionParser.tokens(query)
      .filter((token: string): boolean => SearchConditionParser.isPlainToken(token))
      .join(' ')
  }

  static replacePlainText(query: string, plainText: string): string {
    const structured: string = SearchConditionParser.tokens(query)
      .filter((token: string): boolean => !SearchConditionParser.isPlainToken(token))
      .join(' ')
    const plain: string = plainText.trim()
    if (plain.length === 0) {
      return structured
    }
    return structured.length > 0 ? `${plain} ${structured}` : plain
  }

  static removeNamespace(query: string, namespace: string): string {
    const expected: string = namespace.trim().toLowerCase()
    return SearchConditionParser.tokens(query)
      .filter((token: string): boolean => SearchConditionParser.tokenNamespace(token) !== expected)
      .join(' ')
  }

  private static tokens(query: string): string[] {
    const rawTokens: string[] = []
    let current: string = ''
    let quoteOpen: boolean = false
    for (let index: number = 0; index < query.length; index++) {
      const character: string = query.charAt(index)
      if (character === '"') {
        quoteOpen = !quoteOpen
        current = `${current}${character}`
      } else if (character === ' ' && !quoteOpen) {
        if (current.length > 0) {
          rawTokens.push(current)
          current = ''
        }
      } else {
        current = `${current}${character}`
      }
    }
    if (current.length > 0) {
      rawTokens.push(current)
    }
    return rawTokens
  }

  private static tokenNamespace(token: string): string {
    let content: string = token.trim()
    if (content.startsWith('-')) {
      content = content.substring(1)
    }
    if (content.startsWith('~')) {
      return ''
    }
    const colon: number = content.indexOf(':')
    return colon > 0 ? content.substring(0, colon).trim().toLowerCase() : ''
  }

  private static rangeToken(token: string, namespace: string): SearchConditionRange | null {
    let content: string = token.trim()
    if (content.startsWith('-') || content.startsWith('~')) {
      return null
    }
    const colon: number = content.indexOf(':')
    if (colon <= 0 || content.substring(0, colon).trim().toLowerCase() !== namespace) {
      return null
    }
    let value: string = content.substring(colon + 1).trim()
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1).trim()
    }
    const relation: string = value.startsWith('>=') || value.startsWith('<=') ? value.substring(0, 2) : ''
    const operand: string = relation.length > 0 ? value.substring(2) : value
    if (!/^[0-9]+[hdwmy]?$/.test(operand)) {
      return null
    }
    const result: SearchConditionRange = new SearchConditionRange()
    const suffix: string = operand.substring(operand.length - 1)
    const hasUnit: boolean = /^[hdwmy]$/.test(suffix)
    const numberText: string = hasUnit ? operand.substring(0, operand.length - 1) : operand
    result.unit = hasUnit ? suffix : ''
    if (relation === '>=') {
      result.minimumText = numberText
    } else if (relation === '<=') {
      result.maximumText = numberText
    } else {
      result.minimumText = numberText
      result.maximumText = numberText
    }
    return result
  }

  private static relationLabel(relation: string): string {
    if (relation === '>=') {
      return '≥'
    }
    if (relation === '<=') {
      return '≤'
    }
    return ''
  }

  private static isQuoted(value: string): boolean {
    return value.length >= 2 && value.startsWith('"') && value.endsWith('"')
  }

  private static unquote(value: string): string {
    return SearchConditionParser.isQuoted(value)
      ? value.substring(1, value.length - 1).trim()
      : value.trim()
  }
}
