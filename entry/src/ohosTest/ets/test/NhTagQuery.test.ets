import { describe, expect, it } from '@ohos/hypium'
import { NhTagQuery } from 'shared'

export default function nhTagQueryTest(): void {
  describe('NH tag query namespaces', () => {
    it('collapses only EhTagTranslation attribute buckets to tag', 0, (done: Function) => {
      expect(NhTagQuery.formatExact('female', 'glasses')).assertEqual('tag:glasses')
      expect(NhTagQuery.formatExact('male', 'glasses')).assertEqual('tag:glasses')
      expect(NhTagQuery.formatExact('mixed', 'glasses')).assertEqual('tag:glasses')
      expect(NhTagQuery.formatExact('other', 'full color')).assertEqual('tag:"full color"')
      done()
    })

    it('retains each canonical NH namespace', 0, (done: Function) => {
      expect(NhTagQuery.formatExact('tag', 'stockings')).assertEqual('tag:stockings')
      expect(NhTagQuery.formatExact('artist', 'john doe')).assertEqual('artist:"john doe"')
      expect(NhTagQuery.formatExact('group', 'example group')).assertEqual('group:"example group"')
      expect(NhTagQuery.formatExact('parody', 'example work')).assertEqual('parody:"example work"')
      expect(NhTagQuery.formatExact('character', 'example character')).assertEqual('character:"example character"')
      expect(NhTagQuery.formatExact('language', 'chinese')).assertEqual('language:chinese')
      expect(NhTagQuery.formatExact('category', 'doujinshi')).assertEqual('category:doujinshi')
      done()
    })

    it('normalizes plural aliases, exclusion and rejects unknown namespaces', 0, (done: Function) => {
      expect(NhTagQuery.formatExact('artists', 'john doe', true)).assertEqual('-artist:"john doe"')
      expect(NhTagQuery.formatExact('groups', 'example group')).assertEqual('group:"example group"')
      expect(NhTagQuery.formatExact('parodies', 'example work')).assertEqual('parody:"example work"')
      expect(NhTagQuery.formatExact('rows', 'full color')).assertEqual('')
      done()
    })
  })
}
