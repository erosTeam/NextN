import {
  NH_LOCAL_USER_TAG_DEFAULT_FILTERING_THRESHOLD,
  NhLocalUserTag,
  NhLocalUserTagContract,
  NhLocalUserTagSnapshot,
} from '../model/NhLocalUserTag'

/** Process-local O(1) index. Reactive consumers subscribe to NhLocalUserTagState.revision. */
export class NhLocalUserTagStore {
  private static recordsById: Map<number, NhLocalUserTag> = new Map<number, NhLocalUserTag>()
  private static threshold: number = NH_LOCAL_USER_TAG_DEFAULT_FILTERING_THRESHOLD

  static replace(snapshot: NhLocalUserTagSnapshot): void {
    const next: Map<number, NhLocalUserTag> = new Map<number, NhLocalUserTag>()
    for (let index: number = 0; index < snapshot.tags.length; index++) {
      const record: NhLocalUserTag = NhLocalUserTagContract.normalizeTag(snapshot.tags[index])
      if (record.tagId > 0 && record.deletedAt <= 0) {
        next.set(record.tagId, record)
      }
    }
    NhLocalUserTagStore.recordsById = next
    NhLocalUserTagStore.threshold = snapshot.settings.deletedAt > 0
      ? NH_LOCAL_USER_TAG_DEFAULT_FILTERING_THRESHOLD
      : NhLocalUserTagContract.normalizeFilteringThreshold(snapshot.settings.filteringThreshold)
  }

  /** Callers must treat this map as immutable; writes replace the complete reference. */
  static index(): Map<number, NhLocalUserTag> {
    return NhLocalUserTagStore.recordsById
  }

  static get(tagId: number): NhLocalUserTag | undefined {
    return NhLocalUserTagStore.recordsById.get(tagId)
  }

  static filteringThreshold(): number {
    return NhLocalUserTagStore.threshold
  }

  static activeTags(): NhLocalUserTag[] {
    const result: NhLocalUserTag[] = []
    NhLocalUserTagStore.recordsById.forEach((record: NhLocalUserTag): void => {
      result.push(record.copy())
    })
    return result
  }
}
