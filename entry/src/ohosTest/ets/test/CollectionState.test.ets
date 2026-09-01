import { describe, expect, it } from '@ohos/hypium'
import {
  CollectionFooterState,
  HomeSubtabEditParams,
  HOME_SUBTAB_LATEST_UUID,
  HOME_SUBTAB_POPULAR_UUID,
  NhHomeSubtabKind,
  NhHomeSubtabProfile,
  NhSearchLanguage,
  NhSearchSort,
} from 'shared'

export default function collectionStateTest(): void {
  describe('Retained collection state', () => {
    it('suppresses every settled footer branch while page one refreshes', 0, (done: Function) => {
      expect(CollectionFooterState.canOfferMore(true, true, false, false)).assertEqual(false)
      expect(CollectionFooterState.isComplete(true, false, false, false)).assertEqual(false)
      expect(CollectionFooterState.idleText(true, '2 / 8')).assertEqual('')
      done()
    })

    it('restores the correct footer branch only after refresh settles', 0, (done: Function) => {
      expect(CollectionFooterState.canOfferMore(false, true, false, false)).assertEqual(true)
      expect(CollectionFooterState.isComplete(false, false, false, false)).assertEqual(true)
      expect(CollectionFooterState.canOfferMore(false, true, true, false)).assertEqual(false)
      expect(CollectionFooterState.isComplete(false, false, false, true)).assertEqual(false)
      expect(CollectionFooterState.idleText(false, '2 / 8')).assertEqual('2 / 8')
      done()
    })

    it('normalizes builtin request identity without touching display state', 0, (done: Function) => {
      const latest: NhHomeSubtabProfile = new NhHomeSubtabProfile()
      latest.uuid = HOME_SUBTAB_LATEST_UUID
      latest.kind = NhHomeSubtabKind.SEARCH
      latest.name = 'kept-for-presentation'
      latest.query = 'favorites:>=1000'
      latest.language = NhSearchLanguage.CHINESE
      latest.sort = NhSearchSort.POPULAR_ALL_TIME
      latest.ignoreLocalUserTagFiltering = true
      latest.hidden = true
      latest.presentation = 'waterfall'
      expect(latest.normalizeBuiltinIdentity()).assertEqual(true)
      expect(latest.kind).assertEqual(NhHomeSubtabKind.LATEST)
      expect(latest.query).assertEqual('')
      expect(latest.language).assertEqual(NhSearchLanguage.ALL)
      expect(latest.sort).assertEqual(NhSearchSort.RECENT)
      expect(latest.ignoreLocalUserTagFiltering).assertEqual(false)
      expect(latest.name).assertEqual('kept-for-presentation')
      expect(latest.hidden).assertEqual(true)
      expect(latest.presentation).assertEqual('waterfall')
      expect(latest.normalizeBuiltinIdentity()).assertEqual(false)

      const popular: NhHomeSubtabProfile = new NhHomeSubtabProfile()
      popular.uuid = HOME_SUBTAB_POPULAR_UUID
      popular.kind = NhHomeSubtabKind.SEARCH
      expect(popular.normalizeBuiltinIdentity()).assertEqual(true)
      expect(popular.kind).assertEqual(NhHomeSubtabKind.POPULAR)
      done()
    })

    it('keeps the local tag bypass in custom search identity and edit seeds', 0, (done: Function) => {
      const profile: NhHomeSubtabProfile = new NhHomeSubtabProfile()
      profile.uuid = 'custom-search'
      profile.kind = NhHomeSubtabKind.SEARCH
      profile.query = 'language:chinese'
      const before: string = profile.contentRevision()
      profile.ignoreLocalUserTagFiltering = true
      expect(profile.contentRevision() === before).assertEqual(false)
      expect(profile.copy().ignoreLocalUserTagFiltering).assertEqual(true)

      const edit: HomeSubtabEditParams = new HomeSubtabEditParams(
        '',
        'artist:test',
        NhSearchLanguage.JAPANESE,
        NhSearchSort.POPULAR_WEEK,
        true,
      )
      expect(edit.seedIgnoreLocalUserTagFiltering).assertEqual(true)
      done()
    })
  })
}
