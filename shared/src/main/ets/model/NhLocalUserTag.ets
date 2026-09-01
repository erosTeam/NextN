export const NH_LOCAL_USER_TAG_SCOPE_GLOBAL: string = 'global'
export const NH_LOCAL_USER_TAG_DEFAULT_WEIGHT: number = 10
export const NH_LOCAL_USER_TAG_MIN_WEIGHT: number = -99
export const NH_LOCAL_USER_TAG_MAX_WEIGHT: number = 99
export const NH_LOCAL_USER_TAG_DEFAULT_FILTERING_THRESHOLD: number = 0
export const NH_LOCAL_USER_TAG_MIN_FILTERING_THRESHOLD: number = -9999

/** One user-owned rule keyed only by the canonical NH numeric tag id. */
export class NhLocalUserTag {
  scopeKey: string = NH_LOCAL_USER_TAG_SCOPE_GLOBAL
  tagId: number = 0
  namespaceSnapshot: string = ''
  nameSnapshot: string = ''
  colorCode: string = ''
  weight: number = NH_LOCAL_USER_TAG_DEFAULT_WEIGHT
  hidden: boolean = false
  updatedAt: number = 0
  deletedAt: number = 0

  copy(): NhLocalUserTag {
    const result: NhLocalUserTag = new NhLocalUserTag()
    result.scopeKey = this.scopeKey
    result.tagId = this.tagId
    result.namespaceSnapshot = this.namespaceSnapshot
    result.nameSnapshot = this.nameSnapshot
    result.colorCode = this.colorCode
    result.weight = this.weight
    result.hidden = this.hidden
    result.updatedAt = this.updatedAt
    result.deletedAt = this.deletedAt
    return result
  }
}

/** Scope-wide soft-filter threshold. The first version uses only `global`. */
export class NhLocalUserTagSettings {
  scopeKey: string = NH_LOCAL_USER_TAG_SCOPE_GLOBAL
  filteringThreshold: number = NH_LOCAL_USER_TAG_DEFAULT_FILTERING_THRESHOLD
  updatedAt: number = 0
  deletedAt: number = 0

  copy(): NhLocalUserTagSettings {
    const result: NhLocalUserTagSettings = new NhLocalUserTagSettings()
    result.scopeKey = this.scopeKey
    result.filteringThreshold = this.filteringThreshold
    result.updatedAt = this.updatedAt
    result.deletedAt = this.deletedAt
    return result
  }
}

export class NhLocalUserTagSnapshot {
  tags: NhLocalUserTag[] = []
  settings: NhLocalUserTagSettings = new NhLocalUserTagSettings()
}

/** Shared normalization contract for local writes, restore, backup and sync. */
export class NhLocalUserTagContract {
  static normalizeWeight(value: number): number {
    if (!Number.isFinite(value)) {
      return NH_LOCAL_USER_TAG_DEFAULT_WEIGHT
    }
    return Math.max(NH_LOCAL_USER_TAG_MIN_WEIGHT, Math.min(NH_LOCAL_USER_TAG_MAX_WEIGHT, Math.round(value)))
  }

  static normalizeFilteringThreshold(value: number): number {
    if (!Number.isFinite(value)) {
      return NH_LOCAL_USER_TAG_DEFAULT_FILTERING_THRESHOLD
    }
    return Math.max(
      NH_LOCAL_USER_TAG_MIN_FILTERING_THRESHOLD,
      Math.min(NH_LOCAL_USER_TAG_DEFAULT_FILTERING_THRESHOLD, Math.round(value)),
    )
  }

  static isColorCodeValid(value: string): boolean {
    const trimmed: string = value.trim()
    return trimmed.length === 0 || /^#?[0-9A-Fa-f]{6}$/.test(trimmed)
  }

  static normalizeColorCode(value: string): string {
    const trimmed: string = value.trim()
    if (trimmed.length === 0 || !NhLocalUserTagContract.isColorCodeValid(trimmed)) {
      return ''
    }
    const digits: string = trimmed.startsWith('#') ? trimmed.slice(1) : trimmed
    return `#${digits.toUpperCase()}`
  }

  static normalizeTag(value: NhLocalUserTag): NhLocalUserTag {
    const result: NhLocalUserTag = value.copy()
    result.scopeKey = NH_LOCAL_USER_TAG_SCOPE_GLOBAL
    result.tagId = Math.floor(result.tagId)
    result.namespaceSnapshot = result.namespaceSnapshot.trim()
    result.nameSnapshot = result.nameSnapshot.trim()
    result.colorCode = NhLocalUserTagContract.normalizeColorCode(result.colorCode)
    result.weight = NhLocalUserTagContract.normalizeWeight(result.weight)
    result.updatedAt = Math.max(0, Math.floor(result.updatedAt))
    result.deletedAt = Math.max(0, Math.floor(result.deletedAt))
    return result
  }

  static normalizeSettings(value: NhLocalUserTagSettings): NhLocalUserTagSettings {
    const result: NhLocalUserTagSettings = value.copy()
    result.scopeKey = NH_LOCAL_USER_TAG_SCOPE_GLOBAL
    result.filteringThreshold = NhLocalUserTagContract.normalizeFilteringThreshold(result.filteringThreshold)
    result.updatedAt = Math.max(0, Math.floor(result.updatedAt))
    result.deletedAt = Math.max(0, Math.floor(result.deletedAt))
    return result
  }
}
