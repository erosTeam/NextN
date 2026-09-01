import { describe, expect, it } from '@ohos/hypium'
import {
  SyncEnvelopeV1,
  SyncLocalDataAdapter,
  SyncLocalUserTagRecord,
  SyncLocalUserTagSettingsRecord,
} from 'shared'

function tag(tagId: number, weight: number, updatedAt: number, deletedAt: number = 0): SyncLocalUserTagRecord {
  const record: SyncLocalUserTagRecord = new SyncLocalUserTagRecord()
  record.scopeKey = 'global'
  record.tagId = tagId
  record.nameSnapshot = `tag-${tagId}`
  record.weight = weight
  record.updatedAt = updatedAt
  record.deletedAt = deletedAt
  return record
}

function settings(threshold: number, updatedAt: number): SyncLocalUserTagSettingsRecord {
  const record: SyncLocalUserTagSettingsRecord = new SyncLocalUserTagSettingsRecord()
  record.scopeKey = 'global'
  record.filteringThreshold = threshold
  record.updatedAt = updatedAt
  return record
}

export default function nhLocalUserTagSyncTest(): void {
  describe('NH local user tag sync', () => {
    it('merges whole records by effective LWW clock and preserves independent settings', 0, (done: Function) => {
      const local: SyncEnvelopeV1 = new SyncEnvelopeV1()
      const remote: SyncEnvelopeV1 = new SyncEnvelopeV1()
      local.datasets.localUserTags = [tag(1, -4, 10), tag(2, 20, 30)]
      remote.datasets.localUserTags = [tag(1, 50, 20), tag(2, 0, 0, 40)]
      local.datasets.localUserTagSettings = [settings(-5, 50)]
      remote.datasets.localUserTagSettings = [settings(-9, 45)]

      const merged: SyncEnvelopeV1 = SyncLocalDataAdapter.mergeEnvelopes(local, remote)
      const first: SyncLocalUserTagRecord | undefined =
        merged.datasets.localUserTags.find((value: SyncLocalUserTagRecord): boolean => value.tagId === 1)
      const second: SyncLocalUserTagRecord | undefined =
        merged.datasets.localUserTags.find((value: SyncLocalUserTagRecord): boolean => value.tagId === 2)
      expect(first === undefined ? 0 : first.weight).assertEqual(50)
      expect(second === undefined ? 0 : second.deletedAt).assertEqual(40)
      expect(merged.datasets.localUserTagSettings[0].filteringThreshold).assertEqual(-5)
      done()
    })
  })
}
