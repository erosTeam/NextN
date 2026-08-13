import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { NhGalleryDetail, NhGalleryPage, NhTag } from '../model/NhGallery'
import {
  NhGalleryDetailCachePayload,
  NhGalleryDetailCacheRepository,
} from '../storage/NhGalleryDetailCacheRepository'

const DETAIL_CACHE_RECORD_VERSION: number = 1
const MAX_DETAIL_CACHE_PAYLOAD_CHARS: number = 4 * 1024 * 1024
const MAX_RECENT_DETAIL_ENTRIES: number = 8
const DETAIL_CACHE_TTL_MS: number = 6 * 60 * 60 * 1000
const DETAIL_CACHE_LOG_DOMAIN: number = 0x0000
const DETAIL_CACHE_LOG_TAG: string = 'NextNDetailCache'

class NhGalleryDetailCacheRecord {
  version: number = DETAIL_CACHE_RECORD_VERSION
  detail: NhGalleryDetail = new NhGalleryDetail()
}

class RecentDetailEntry {
  detail: NhGalleryDetail = new NhGalleryDetail()
  expiresAt: number = 0
}

/** Public Detail DTO cache. It copies every snapshot so route-local state cannot leak across pages. */
export class NhGalleryDetailCacheService {
  private static recent: Map<number, RecentDetailEntry> = new Map<number, RecentDetailEntry>()
  private static persistTail: Promise<void> = Promise.resolve()

  static getRecent(galleryId: number): NhGalleryDetail | null {
    const normalizedGalleryId: number = NhGalleryDetailCacheService.galleryId(galleryId)
    if (normalizedGalleryId <= 0) {
      return null
    }
    const cached: RecentDetailEntry | undefined = NhGalleryDetailCacheService.recent.get(normalizedGalleryId)
    if (cached === undefined || cached.expiresAt <= Date.now()) {
      NhGalleryDetailCacheService.recent.delete(normalizedGalleryId)
      return null
    }
    try {
      const copy: NhGalleryDetail = NhGalleryDetailCacheService.copyDetail(cached.detail, normalizedGalleryId)
      const refreshed: RecentDetailEntry = new RecentDetailEntry()
      refreshed.detail = copy
      refreshed.expiresAt = cached.expiresAt
      NhGalleryDetailCacheService.recent.delete(normalizedGalleryId)
      NhGalleryDetailCacheService.recent.set(normalizedGalleryId, refreshed)
      // Keep runtime proof finite and non-sensitive: no gallery identity or
      // payload fields leave the process with this cache event.
      hilog.info(DETAIL_CACHE_LOG_DOMAIN, DETAIL_CACHE_LOG_TAG, 'event=%{public}s', 'hit=memory')
      return copy.copy()
    } catch (_error) {
      NhGalleryDetailCacheService.recent.delete(normalizedGalleryId)
      return null
    }
  }

  static async loadPersisted(
    context: common.UIAbilityContext,
    galleryId: number,
  ): Promise<NhGalleryDetail | null> {
    const normalizedGalleryId: number = NhGalleryDetailCacheService.galleryId(galleryId)
    if (normalizedGalleryId <= 0) {
      return null
    }
    let payload: NhGalleryDetailCachePayload | null = null
    try {
      payload = await NhGalleryDetailCacheRepository.load(context, normalizedGalleryId)
    } catch (_error) {
      // A transient RDB failure is not evidence that a previously persisted
      // payload is corrupt. Keep it for a later route or process retry.
      console.warn('Unable to read public gallery detail cache')
      return null
    }
    if (payload === null) {
      return null
    }
    try {
      const detail: NhGalleryDetail = NhGalleryDetailCacheService.decode(payload.payload, normalizedGalleryId)
      NhGalleryDetailCacheService.remember(detail, payload.expiresAt)
      // The persisted event distinguishes an RDB-backed cold entry from a
      // merely fast network response without exposing the cached payload.
      hilog.info(DETAIL_CACHE_LOG_DOMAIN, DETAIL_CACHE_LOG_TAG, 'event=%{public}s', 'hit=persisted')
      return detail.copy()
    } catch (_error) {
      try {
        await NhGalleryDetailCacheRepository.discard(context, normalizedGalleryId)
      } catch (_cleanupError) {
      }
      return null
    }
  }

  static async save(context: common.UIAbilityContext, detail: NhGalleryDetail): Promise<boolean> {
    let snapshot: NhGalleryDetail
    let payload: string
    try {
      snapshot = NhGalleryDetailCacheService.copyDetail(detail, detail.id)
      payload = NhGalleryDetailCacheService.encode(snapshot)
    } catch (_error) {
      // A malformed network DTO must not be retained as a process cache entry.
      console.warn('Unable to prepare public gallery detail cache')
      return false
    }
    NhGalleryDetailCacheService.remember(snapshot, Date.now() + DETAIL_CACHE_TTL_MS)
    try {
      await NhGalleryDetailCacheService.enqueuePersist(context, snapshot.id, payload)
      // This fixed event records only completion of the local write boundary.
      hilog.info(DETAIL_CACHE_LOG_DOMAIN, DETAIL_CACHE_LOG_TAG, 'event=%{public}s', 'stored')
      return true
    } catch (_error) {
      // Cache persistence never invalidates a verified public network response.
      console.warn('Unable to persist public gallery detail cache')
      return false
    }
  }

  private static enqueuePersist(
    context: common.UIAbilityContext,
    galleryId: number,
    payload: string,
  ): Promise<void> {
    const task: Promise<void> = NhGalleryDetailCacheService.persistTail.then(
      async (): Promise<void> => await NhGalleryDetailCacheRepository.save(context, galleryId, payload),
    )
    // A failed cache record must not prevent the next verified Detail from
    // replacing it. The caller still receives this task's own failure.
    NhGalleryDetailCacheService.persistTail = task.catch((): void => {})
    return task
  }

  private static remember(detail: NhGalleryDetail, expiresAt: number): void {
    if (expiresAt <= Date.now()) {
      return
    }
    const snapshot: NhGalleryDetail = NhGalleryDetailCacheService.copyDetail(detail, detail.id)
    const entry: RecentDetailEntry = new RecentDetailEntry()
    entry.detail = snapshot
    entry.expiresAt = expiresAt
    NhGalleryDetailCacheService.recent.delete(snapshot.id)
    NhGalleryDetailCacheService.recent.set(snapshot.id, entry)
    while (NhGalleryDetailCacheService.recent.size > MAX_RECENT_DETAIL_ENTRIES) {
      const oldest: number | undefined = NhGalleryDetailCacheService.recent.keys().next().value
      if (oldest === undefined) {
        break
      }
      NhGalleryDetailCacheService.recent.delete(oldest)
    }
  }

  private static encode(detail: NhGalleryDetail): string {
    const record: NhGalleryDetailCacheRecord = new NhGalleryDetailCacheRecord()
    record.detail = detail.copy()
    const payload: string = JSON.stringify(record)
    if (payload.length === 0 || payload.length > MAX_DETAIL_CACHE_PAYLOAD_CHARS) {
      throw new Error('Gallery detail cache payload is invalid')
    }
    return payload
  }

  private static decode(payload: string, expectedGalleryId: number): NhGalleryDetail {
    if (payload.length === 0 || payload.length > MAX_DETAIL_CACHE_PAYLOAD_CHARS) {
      throw new Error('Gallery detail cache payload is invalid')
    }
    const record: NhGalleryDetailCacheRecord = JSON.parse(payload) as NhGalleryDetailCacheRecord
    if (record === null || typeof record !== 'object' || record.version !== DETAIL_CACHE_RECORD_VERSION ||
      record.detail === undefined || record.detail === null) {
      throw new Error('Gallery detail cache record is invalid')
    }
    return NhGalleryDetailCacheService.copyDetail(record.detail, expectedGalleryId)
  }

  private static copyDetail(source: NhGalleryDetail, expectedGalleryId: number): NhGalleryDetail {
    if (source === null || typeof source !== 'object' ||
      !Array.isArray(source.tags) || !Array.isArray(source.pages) || source.pages.length === 0) {
      throw new Error('Gallery detail cache detail is invalid')
    }
    const detail: NhGalleryDetail = new NhGalleryDetail()
    detail.id = source.id
    detail.mediaId = NhGalleryDetailCacheService.text(source.mediaId)
    detail.title = NhGalleryDetailCacheService.text(source.title)
    detail.japaneseTitle = NhGalleryDetailCacheService.text(source.japaneseTitle)
    detail.prettyTitle = NhGalleryDetailCacheService.text(source.prettyTitle)
    detail.coverUrl = NhGalleryDetailCacheService.text(source.coverUrl)
    detail.thumbnailUrl = NhGalleryDetailCacheService.text(source.thumbnailUrl)
    detail.pageCount = source.pageCount
    detail.favoriteCount = source.favoriteCount
    detail.scanlator = NhGalleryDetailCacheService.text(source.scanlator)
    detail.uploadDate = source.uploadDate
    detail.id = NhGalleryDetailCacheService.galleryId(detail.id)
    if (detail.id <= 0 || detail.id !== NhGalleryDetailCacheService.galleryId(expectedGalleryId)) {
      throw new Error('Gallery detail cache identity is invalid')
    }
    if (!NhGalleryDetailCacheService.isNonNegativeInteger(detail.pageCount) ||
      !NhGalleryDetailCacheService.isNonNegativeInteger(detail.favoriteCount) ||
      !NhGalleryDetailCacheService.isNonNegativeInteger(detail.uploadDate)) {
      throw new Error('Gallery detail cache number is invalid')
    }
    for (let index: number = 0; index < source.tags.length; index++) {
      const sourceTag = source.tags[index]
      if (sourceTag === null || typeof sourceTag !== 'object' ||
        !NhGalleryDetailCacheService.isNonNegativeInteger(sourceTag.id) ||
        !NhGalleryDetailCacheService.isNonNegativeInteger(sourceTag.count)) {
        throw new Error('Gallery detail cache tag is invalid')
      }
      const tag: NhTag = new NhTag()
      tag.id = sourceTag.id
      tag.type = NhGalleryDetailCacheService.text(sourceTag.type)
      tag.name = NhGalleryDetailCacheService.text(sourceTag.name)
      tag.count = sourceTag.count
      // Tag translations are a separate current presentation owner.
      tag.displayName = ''
      detail.tags.push(tag)
    }
    for (let index: number = 0; index < source.pages.length; index++) {
      const sourcePage = source.pages[index]
      if (sourcePage === null || typeof sourcePage !== 'object') {
        throw new Error('Gallery detail cache page is invalid')
      }
      if (!NhGalleryDetailCacheService.isPositiveInteger(sourcePage.number) ||
        !NhGalleryDetailCacheService.isNonNegativeInteger(sourcePage.width) ||
        !NhGalleryDetailCacheService.isNonNegativeInteger(sourcePage.height)) {
        throw new Error('Gallery detail cache page is invalid')
      }
      const page: NhGalleryPage = new NhGalleryPage()
      page.number = sourcePage.number
      page.extension = NhGalleryDetailCacheService.text(sourcePage.extension)
      page.width = sourcePage.width
      page.height = sourcePage.height
      page.thumbnailUrl = NhGalleryDetailCacheService.text(sourcePage.thumbnailUrl)
      detail.pages.push(page)
    }
    return detail
  }

  private static galleryId(value: number): number {
    if (typeof value !== 'number') {
      return 0
    }
    const normalized: number = Math.floor(value)
    return Number.isSafeInteger(normalized) && normalized > 0 ? normalized : 0
  }

  private static isPositiveInteger(value: number): boolean {
    return typeof value === 'number' && Number.isSafeInteger(value) && value > 0
  }

  private static isNonNegativeInteger(value: number): boolean {
    return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0
  }

  private static text(value: string): string {
    if (typeof value !== 'string') {
      throw new Error('Gallery detail cache text is invalid')
    }
    return value
  }
}
