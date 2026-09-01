import { util } from '@kit.ArkTS'
import { NhBrowsePresentation } from './NhBrowsePresentation'
import { NhSearchLanguage, NhSearchSort } from './NhSearchOptions'

export enum NhHomeSubtabKind {
  LATEST = 'latest',
  POPULAR = 'popular',
  SEARCH = 'search',
}

export const HOME_SUBTAB_LATEST_UUID: string = 'builtin-latest'
export const HOME_SUBTAB_POPULAR_UUID: string = 'builtin-popular'
export const HOME_SUBTAB_STARTER_CHINESE_UUID: string = 'starter-language-chinese'
export const HOME_SUBTAB_STARTER_FAVORITED_UUID: string = 'starter-highly-favorited'
export const HOME_SUBTAB_PRESENTATION_GLOBAL: string = 'global'

function revisionPart(value: string): string {
  return `${value.length}:${value}`
}

/** One durable retained Home source. Only SEARCH profiles own request fields. */
export class NhHomeSubtabProfile {
  uuid: string = ''
  kind: NhHomeSubtabKind = NhHomeSubtabKind.SEARCH
  name: string = ''
  query: string = ''
  language: NhSearchLanguage = NhSearchLanguage.ALL
  sort: NhSearchSort = NhSearchSort.RECENT
  ignoreLocalUserTagFiltering: boolean = false
  presentation: string = HOME_SUBTAB_PRESENTATION_GLOBAL
  hidden: boolean = false
  lastEditTime: number = 0

  isBuiltin(): boolean {
    return this.uuid === HOME_SUBTAB_LATEST_UUID || this.uuid === HOME_SUBTAB_POPULAR_UUID
  }

  isSearch(): boolean {
    return this.kind === NhHomeSubtabKind.SEARCH
  }

  /**
   * Built-in UUIDs are the authority for their request identity. Sync and old
   * storage may carry stale editable fields, but those fields must never turn a
   * built-in page into a search request or change its fixed query semantics.
   * Presentation, visibility, position, clock and localized display name stay
   * outside this normalization boundary.
   */
  normalizeBuiltinIdentity(): boolean {
    let expectedKind: NhHomeSubtabKind
    if (this.uuid === HOME_SUBTAB_LATEST_UUID) {
      expectedKind = NhHomeSubtabKind.LATEST
    } else if (this.uuid === HOME_SUBTAB_POPULAR_UUID) {
      expectedKind = NhHomeSubtabKind.POPULAR
    } else {
      return false
    }
    const changed: boolean = this.kind !== expectedKind || this.query.length > 0 ||
      this.language !== NhSearchLanguage.ALL || this.sort !== NhSearchSort.RECENT ||
      this.ignoreLocalUserTagFiltering
    this.kind = expectedKind
    this.query = ''
    this.language = NhSearchLanguage.ALL
    this.sort = NhSearchSort.RECENT
    this.ignoreLocalUserTagFiltering = false
    return changed
  }

  hasEffectiveSearch(): boolean {
    return this.query.trim().length > 0 ||
      this.language !== NhSearchLanguage.ALL ||
      this.sort !== NhSearchSort.RECENT ||
      this.ignoreLocalUserTagFiltering
  }

  /** Stable identity for request/cache invalidation; display-only edits are excluded. */
  contentRevision(): string {
    if (this.kind !== NhHomeSubtabKind.SEARCH) {
      return revisionPart(this.kind)
    }
    return revisionPart(this.kind) +
      revisionPart(this.query.trim()) +
      revisionPart(this.language) +
      revisionPart(this.sort) +
      revisionPart(this.ignoreLocalUserTagFiltering ? '1' : '0')
  }

  presentationOverride(): NhBrowsePresentation | null {
    return NhHomeSubtabProfile.normalizePresentation(this.presentation)
  }

  copy(): NhHomeSubtabProfile {
    const copy: NhHomeSubtabProfile = new NhHomeSubtabProfile()
    copy.uuid = this.uuid
    copy.kind = this.kind
    copy.name = this.name
    copy.query = this.query
    copy.language = this.language
    copy.sort = this.sort
    copy.ignoreLocalUserTagFiltering = this.ignoreLocalUserTagFiltering
    copy.presentation = this.presentation
    copy.hidden = this.hidden
    copy.lastEditTime = this.lastEditTime
    return copy
  }

  static normalizeKind(value: string): NhHomeSubtabKind {
    if (value === NhHomeSubtabKind.LATEST) {
      return NhHomeSubtabKind.LATEST
    }
    if (value === NhHomeSubtabKind.POPULAR) {
      return NhHomeSubtabKind.POPULAR
    }
    return NhHomeSubtabKind.SEARCH
  }

  static normalizeLanguage(value: string): NhSearchLanguage {
    if (value === NhSearchLanguage.JAPANESE) {
      return NhSearchLanguage.JAPANESE
    }
    if (value === NhSearchLanguage.CHINESE) {
      return NhSearchLanguage.CHINESE
    }
    if (value === NhSearchLanguage.ENGLISH) {
      return NhSearchLanguage.ENGLISH
    }
    if (value === NhSearchLanguage.TRANSLATED) {
      return NhSearchLanguage.TRANSLATED
    }
    return NhSearchLanguage.ALL
  }

  static normalizeSort(value: string): NhSearchSort {
    if (value === NhSearchSort.POPULAR_TODAY) {
      return NhSearchSort.POPULAR_TODAY
    }
    if (value === NhSearchSort.POPULAR_WEEK) {
      return NhSearchSort.POPULAR_WEEK
    }
    if (value === NhSearchSort.POPULAR_MONTH) {
      return NhSearchSort.POPULAR_MONTH
    }
    if (value === NhSearchSort.POPULAR_ALL_TIME) {
      return NhSearchSort.POPULAR_ALL_TIME
    }
    return NhSearchSort.RECENT
  }

  static normalizePresentation(value: string): NhBrowsePresentation | null {
    if (value === NhBrowsePresentation.LIST) {
      return NhBrowsePresentation.LIST
    }
    if (value === NhBrowsePresentation.SIMPLE_LIST) {
      return NhBrowsePresentation.SIMPLE_LIST
    }
    if (value === NhBrowsePresentation.COVER_GRID) {
      return NhBrowsePresentation.COVER_GRID
    }
    if (value === NhBrowsePresentation.WATERFALL) {
      return NhBrowsePresentation.WATERFALL
    }
    if (value === NhBrowsePresentation.WATERFALL_COMPACT) {
      return NhBrowsePresentation.WATERFALL_COMPACT
    }
    if (value === NhBrowsePresentation.COVER_WALL) {
      return NhBrowsePresentation.COVER_WALL
    }
    return null
  }
}

export class HomeSubtabEditParams {
  profileUuid: string = ''
  seedQuery: string = ''
  seedLanguage: NhSearchLanguage = NhSearchLanguage.ALL
  seedSort: NhSearchSort = NhSearchSort.RECENT
  seedIgnoreLocalUserTagFiltering: boolean = false

  constructor(
    profileUuid: string = '',
    seedQuery: string = '',
    seedLanguage: NhSearchLanguage = NhSearchLanguage.ALL,
    seedSort: NhSearchSort = NhSearchSort.RECENT,
    seedIgnoreLocalUserTagFiltering: boolean = false,
  ) {
    this.profileUuid = profileUuid
    this.seedQuery = seedQuery
    this.seedLanguage = seedLanguage
    this.seedSort = seedSort
    this.seedIgnoreLocalUserTagFiltering = seedIgnoreLocalUserTagFiltering
  }
}

export function newHomeSubtabUuid(): string {
  return util.generateRandomUUID(true)
}
