/** Stable gallery DTOs for the ErosN v2 API contract. */
export class NhGallerySummary {
  id: number = 0
  mediaId: string = ''
  englishTitle: string = ''
  japaneseTitle: string = ''
  thumbnailUrl: string = ''
  pageCount: number = 0
  thumbnailWidth: number = 0
  thumbnailHeight: number = 0
  tagIds: number[] = []
  /** Resolved public catalog records for `tagIds`; absent names stay absent. */
  tags: NhTag[] = []

  displayTitle(): string {
    if (this.englishTitle.length > 0) {
      return this.englishTitle
    }
    if (this.japaneseTitle.length > 0) {
      return this.japaneseTitle
    }
    return `#${this.id}`
  }

  /**
   * ErosN derives the three catalog language badges directly from v2
   * `tag_ids`. Keep that zero-request enrichment on the summary itself so a
   * NextE-style simple row can expose language without adding a rate-limited
   * tag-name lookup to every catalog page.
   */
  languageCode(): string {
    if (this.tagIds.indexOf(6346) >= 0) {
      return 'JA'
    }
    if (this.tagIds.indexOf(29963) >= 0) {
      return 'ZH'
    }
    if (this.tagIds.indexOf(12227) >= 0) {
      return 'EN'
    }
    return ''
  }
}

export class NhTag {
  id: number = 0
  type: string = ''
  name: string = ''
  /** Optional local-dictionary label; `name` stays the canonical query value. */
  displayName: string = ''
  count: number = 0
}

export class NhGalleryPage {
  number: number = 0
  extension: string = 'jpg'
  width: number = 0
  height: number = 0
  thumbnailUrl: string = ''
}

export class NhGalleryDetail {
  id: number = 0
  mediaId: string = ''
  title: string = ''
  japaneseTitle: string = ''
  prettyTitle: string = ''
  coverUrl: string = ''
  thumbnailUrl: string = ''
  pageCount: number = 0
  favoriteCount: number = 0
  scanlator: string = ''
  uploadDate: number = 0
  tags: NhTag[] = []
  pages: NhGalleryPage[] = []

  displayTitle(): string {
    if (this.prettyTitle.length > 0) {
      return this.prettyTitle
    }
    if (this.title.length > 0) {
      return this.title
    }
    if (this.japaneseTitle.length > 0) {
      return this.japaneseTitle
    }
    return `#${this.id}`
  }
}

/**
 * The verified account-scoped state returned by the v2 gallery favourite
 * endpoint.  `known` remains false when the endpoint cannot safely prove the
 * current value, so UI never treats a missing response as an unfavourited
 * gallery and accidentally turns a retry into a remote write.
 */
export class NhGalleryFavoriteStatus {
  known: boolean = false
  isFavorited: boolean = false
  favoriteCount: number = 0
  hasFavoriteCount: boolean = false
}

export class NhGalleryPageResult {
  galleries: NhGallerySummary[] = []
  totalPages: number = 1
}

/** Persisted local reading state; it never contains account/session information. */
export class NhReadingHistoryItem {
  galleryId: number = 0
  mediaId: string = ''
  title: string = ''
  thumbnailUrl: string = ''
  pageCount: number = 0
  lastReadIndex: number = 0
  /**
   * `lastReadIndex === 0` is also the real first page. Keep this explicit
   * local marker so an opened detail is never presented as an actual resume.
   */
  hasReadProgress: boolean = false
  lastOpenedAt: number = 0

  toSummary(): NhGallerySummary {
    const gallery: NhGallerySummary = new NhGallerySummary()
    gallery.id = this.galleryId
    gallery.mediaId = this.mediaId
    gallery.englishTitle = this.title
    gallery.thumbnailUrl = this.thumbnailUrl
    gallery.pageCount = this.pageCount
    return gallery
  }
}
