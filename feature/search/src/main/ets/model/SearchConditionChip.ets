import { NhTagSuggestionDisplay } from 'shared'

/**
 * One structured view of a query token in the search-options sheet. The
 * query text remains the only submitted truth; chips are a reversible
 * projection so each active condition can be read and removed without
 * hand-editing the raw string.
 */
export class SearchConditionChip {
  /** Exact token in the query string, including any -/~ prefix. */
  rawToken: string = ''
  /** User-facing label, e.g. 标签:全彩 or 页数 ≥ 20. */
  label: string = ''
  /** True when the token is one this sheet knows how to rebuild. */
  structured: boolean = false
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
    SearchConditionParser.tokens(query).forEach((raw: string): void => {
      const chip: SearchConditionChip = new SearchConditionChip()
      chip.rawToken = raw
      let content: string = raw
      let prefix: string = ''
      if (content.startsWith('-') || content.startsWith('~')) {
        prefix = content.substring(0, 1)
        content = content.substring(1)
      }
      const colon: number = content.indexOf(':')
      if (colon > 0) {
        const namespace: string = content.substring(0, colon).trim().toLowerCase()
        let value: string = content.substring(colon + 1).trim()
        if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
          value = value.substring(1, value.length - 1).trim()
        }
        if (SearchConditionParser.OPERATOR_NAMESPACES.indexOf(namespace) >= 0) {
          const relation: string = value.startsWith('>=') || value.startsWith('<=') ? value.substring(0, 2) : ''
          const numberText: string = relation.length > 0 ? value.substring(2) : value
          if (/^[0-9]+[hdwmy]?$/.test(numberText)) {
            chip.label = operatorLabels(namespace) + ' ' + SearchConditionParser.relationLabel(relation) + ' ' + numberText
            chip.structured = true
          }
        } else {
          const display: string = NhTagSuggestionDisplay.namespaceLabel(namespace)
          if (value.length > 0) {
            chip.label = `${prefix}${display}:${value}`
            chip.structured = true
          }
        }
      }
      if (chip.label.length === 0) {
        chip.label = raw
      }
      chips.push(chip)
    })
    return chips
  }

  static removeToken(query: string, token: string): string {
    return SearchConditionParser.tokens(query)
      .filter((candidate: string): boolean => candidate !== token)
      .join(' ')
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
    if (content.startsWith('-') || content.startsWith('~')) {
      content = content.substring(1)
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
    if (content.startsWith('-') || content.startsWith('~')) {
      content = content.substring(1)
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
}
