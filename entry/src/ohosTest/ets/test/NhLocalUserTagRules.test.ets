import { describe, expect, it } from '@ohos/hypium'
import {
  NhLocalUserTag,
  NhLocalUserTagContract,
  NhLocalUserTagEvaluation,
  NhLocalUserTagPresentation,
  NhLocalUserTagRules,
  NhTag,
} from 'shared'

function rule(tagId: number, weight: number, hidden: boolean = false, colorCode: string = ''): NhLocalUserTag {
  const result: NhLocalUserTag = new NhLocalUserTag()
  result.tagId = tagId
  result.weight = weight
  result.hidden = hidden
  result.colorCode = colorCode
  return result
}

function tag(tagId: number, name: string): NhTag {
  const result: NhTag = new NhTag()
  result.id = tagId
  result.name = name
  return result
}

export default function nhLocalUserTagRulesTest(): void {
  describe('NH local user tag rules', () => {
    it('uses total matched weight with a strict less-than threshold', 0, (done: Function) => {
      const records: Map<number, NhLocalUserTag> = new Map<number, NhLocalUserTag>()
      records.set(1, rule(1, -8))
      records.set(2, rule(2, 5))
      records.set(3, rule(3, 3))
      records.set(4, rule(4, 2))

      expect(NhLocalUserTagRules.isFiltered([1], records, -5)).assertEqual(true)
      expect(NhLocalUserTagRules.isFiltered([1, 2], records, -5)).assertEqual(false)
      expect(NhLocalUserTagRules.isFiltered([1, 3], records, -5)).assertEqual(false)
      expect(NhLocalUserTagRules.isFiltered([1, 4], records, -5)).assertEqual(true)
      done()
    })

    it('deduplicates ids and lets Hidden override any positive score', 0, (done: Function) => {
      const records: Map<number, NhLocalUserTag> = new Map<number, NhLocalUserTag>()
      records.set(1, rule(1, -3))
      records.set(2, rule(2, 99, true))
      const duplicate: NhLocalUserTagEvaluation = NhLocalUserTagRules.evaluate([1, 1], records, -5)
      expect(duplicate.score).assertEqual(-3)
      expect(duplicate.filtered).assertEqual(false)
      const hidden: NhLocalUserTagEvaluation = NhLocalUserTagRules.evaluate([1, 2], records, -9999)
      expect(hidden.score).assertEqual(96)
      expect(hidden.hiddenMatched).assertEqual(true)
      expect(hidden.filtered).assertEqual(true)
      done()
    })

    it('gives unconfigured ids zero weight and keeps the default threshold neutral', 0, (done: Function) => {
      const records: Map<number, NhLocalUserTag> = new Map<number, NhLocalUserTag>()
      expect(NhLocalUserTagRules.evaluate([404], records, 0).score).assertEqual(0)
      expect(NhLocalUserTagRules.isFiltered([404], records, 0)).assertEqual(false)
      done()
    })

    it('bypasses only the local evaluation when explicitly requested', 0, (done: Function) => {
      const records: Map<number, NhLocalUserTag> = new Map<number, NhLocalUserTag>()
      records.set(1, rule(1, -99, true))
      const evaluation: NhLocalUserTagEvaluation = NhLocalUserTagRules.evaluate([1], records, 0, true)
      expect(evaluation.score).assertEqual(0)
      expect(evaluation.hiddenMatched).assertEqual(false)
      expect(evaluation.filtered).assertEqual(false)
      done()
    })

    it('keeps unrestricted integer weights and canonical colors', 0, (done: Function) => {
      expect(NhLocalUserTagContract.normalizeWeight(-1000)).assertEqual(-1000)
      expect(NhLocalUserTagContract.normalizeWeight(1000)).assertEqual(1000)
      expect(NhLocalUserTagContract.normalizeFilteringThreshold(-10000)).assertEqual(-9999)
      expect(NhLocalUserTagContract.normalizeFilteringThreshold(5)).assertEqual(0)
      expect(NhLocalUserTagContract.normalizeColorCode('1a2b3c')).assertEqual('#1A2B3C')
      expect(NhLocalUserTagContract.normalizeColorCode('#abcdef')).assertEqual('#ABCDEF')
      done()
    })

    it('stably moves colored tags before plain tags prior to truncation', 0, (done: Function) => {
      const records: Map<number, NhLocalUserTag> = new Map<number, NhLocalUserTag>()
      records.set(2, rule(2, 10, false, '#112233'))
      records.set(4, rule(4, 10, false, '#445566'))
      records.set(11, rule(11, 10, false, '#778899'))
      const tags: NhTag[] = []
      for (let index: number = 1; index <= 11; index++) {
        tags.push(tag(index, `tag-${index}`))
      }
      const ordered: NhTag[] = NhLocalUserTagPresentation.orderedTags(tags, records)
      expect(ordered.map((value: NhTag): number => value.id).join(','))
        .assertEqual('2,4,11,1,3,5,6,7,8,9,10')
      expect(ordered.slice(0, 8).some((value: NhTag): boolean => value.id === 11)).assertEqual(true)
      done()
    })

    it('derives readable chip text and NextE compact text colors', 0, (done: Function) => {
      expect(NhLocalUserTagPresentation.readableTextColor('#000000')).assertEqual('#FFFFFF')
      expect(NhLocalUserTagPresentation.readableTextColor('#FFFFFF')).assertEqual('#000000')
      expect(NhLocalUserTagPresentation.compactTextColor('#000000')).assertEqual('#333333')
      expect(NhLocalUserTagPresentation.compactTextColor('#FFFFFF')).assertEqual('#FFFFFF')
      expect(NhLocalUserTagPresentation.compactTextColor('invalid')).assertEqual('')
      done()
    })
  })
}
