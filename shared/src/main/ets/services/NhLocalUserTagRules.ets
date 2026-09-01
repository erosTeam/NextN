import {
  NhLocalUserTag,
  NhLocalUserTagContract,
} from '../model/NhLocalUserTag'

export class NhLocalUserTagEvaluation {
  score: number = 0
  hiddenMatched: boolean = false
  filtered: boolean = false
}

/** Pure EH-compatible Hidden and total-weight evaluation. */
export class NhLocalUserTagRules {
  static evaluate(
    tagIds: number[],
    recordsById: Map<number, NhLocalUserTag>,
    filteringThreshold: number,
    ignoreLocalUserTagFiltering: boolean = false,
  ): NhLocalUserTagEvaluation {
    const result: NhLocalUserTagEvaluation = new NhLocalUserTagEvaluation()
    if (ignoreLocalUserTagFiltering) {
      return result
    }
    const seen: Set<number> = new Set<number>()
    for (let index: number = 0; index < tagIds.length; index++) {
      const tagId: number = Math.floor(tagIds[index])
      if (tagId <= 0 || seen.has(tagId)) {
        continue
      }
      seen.add(tagId)
      const record: NhLocalUserTag | undefined = recordsById.get(tagId)
      if (record === undefined || record.deletedAt > 0) {
        continue
      }
      if (record.hidden) {
        result.hiddenMatched = true
      }
      result.score += NhLocalUserTagContract.normalizeWeight(record.weight)
    }
    const threshold: number = NhLocalUserTagContract.normalizeFilteringThreshold(filteringThreshold)
    result.filtered = result.hiddenMatched || result.score < threshold
    return result
  }

  static isFiltered(
    tagIds: number[],
    recordsById: Map<number, NhLocalUserTag>,
    filteringThreshold: number,
    ignoreLocalUserTagFiltering: boolean = false,
  ): boolean {
    return NhLocalUserTagRules.evaluate(
      tagIds,
      recordsById,
      filteringThreshold,
      ignoreLocalUserTagFiltering,
    ).filtered
  }
}
