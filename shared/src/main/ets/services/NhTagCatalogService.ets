import { common } from '@kit.AbilityKit'
import { NhGallerySummary, NhTag } from '../model/NhGallery'
import { NhTagCatalogRepository, NhTagCatalogResolution } from '../storage/NhTagCatalogRepository'
import { TagTranslationRepository } from '../storage/TagTranslationRepository'

const FETCH_BATCH_SIZE: number = 100

/**
 * Enriches a loaded public list in one serialized, deduplicated catalog pass.
 * A catalog miss is non-fatal: the original gallery list stays usable, while
 * any names returned by this request remain available even if the optional
 * durable cache is temporarily unavailable.
 */
export class NhTagCatalogService {
  private static context: common.UIAbilityContext | null = null
  private static resolutionTail: Promise<void> = Promise.resolve()

  static initialize(context: common.UIAbilityContext): void {
    NhTagCatalogService.context = context
  }

  static enrich(
    galleries: NhGallerySummary[],
    fetchTags: (ids: number[]) => Promise<NhTag[]>,
  ): Promise<void> {
    if (galleries.length === 0 || NhTagCatalogService.context === null) {
      return Promise.resolve()
    }
    const queued: Promise<void> = NhTagCatalogService.resolutionTail.then(
      (): Promise<void> => NhTagCatalogService.enrichInternal(galleries, fetchTags),
      (): Promise<void> => NhTagCatalogService.enrichInternal(galleries, fetchTags),
    )
    NhTagCatalogService.resolutionTail = queued.catch((): void => {})
    return queued
  }

  /**
   * A successfully parsed Detail response already carries canonical public
   * tag records.
   * Learn those records for a later tag-id-only collection without delaying
   * the Detail response or adding another network request.
   */
  static rememberDetailTags(tags: NhTag[]): void {
    const context: common.UIAbilityContext | null = NhTagCatalogService.context
    const snapshot: NhTag[] = NhTagCatalogService.catalogSnapshot(tags)
    if (context === null || snapshot.length === 0) {
      return
    }
    const queued: Promise<void> = NhTagCatalogService.resolutionTail.then(
      (): Promise<void> => NhTagCatalogService.rememberInternal(context, snapshot),
      (): Promise<void> => NhTagCatalogService.rememberInternal(context, snapshot),
    )
    NhTagCatalogService.resolutionTail = queued.catch((): void => {})
  }

  /**
   * A Detail response accepted after an explicit page refresh did not use the
   * current process's NetworkKit transport cache. Promote its complete public
   * tags only after the page has verified that the response still belongs to
   * its current Gallery route.
   */
  static promoteAcceptedFreshDetailTags(tags: NhTag[]): void {
    const context: common.UIAbilityContext | null = NhTagCatalogService.context
    const snapshot: NhTag[] = NhTagCatalogService.catalogSnapshot(tags)
    if (context === null || snapshot.length === 0) {
      return
    }
    const queued: Promise<void> = NhTagCatalogService.resolutionTail.then(
      (): Promise<void> => NhTagCatalogService.promoteInternal(context, snapshot),
      (): Promise<void> => NhTagCatalogService.promoteInternal(context, snapshot),
    )
    NhTagCatalogService.resolutionTail = queued.catch((): void => {})
  }

  /**
   * Re-labels already resolved gallery tags after a committed local-dictionary
   * change. This path is strictly local: it never reads the tag catalog or
   * starts an API request, and unresolved tag ids stay unresolved.
   */
  static async refreshLocalDisplayLabels(galleries: NhGallerySummary[]): Promise<NhGallerySummary[]> {
    const context: common.UIAbilityContext | null = NhTagCatalogService.context
    if (galleries.length === 0 || context === null) {
      return galleries.slice()
    }
    const tags: NhTag[] = NhTagCatalogService.collectResolvedTags(galleries)
    if (tags.length === 0) {
      return galleries.slice()
    }
    let translations: Map<string, string>
    try {
      translations = await TagTranslationRepository.lookup(context, tags)
    } catch (_error) {
      // Do not replace an existing displayed label with a raw fallback when
      // the optional dictionary itself cannot be read.
      return galleries.slice()
    }
    return galleries.map((gallery: NhGallerySummary): NhGallerySummary =>
      NhTagCatalogService.copyGalleryWithDisplayLabels(gallery, translations))
  }

  private static async enrichInternal(
    galleries: NhGallerySummary[],
    fetchTags: (ids: number[]) => Promise<NhTag[]>,
  ): Promise<void> {
    const context: common.UIAbilityContext | null = NhTagCatalogService.context
    if (context === null) {
      return
    }
    const ids: number[] = NhTagCatalogService.collectIds(galleries)
    if (ids.length === 0) {
      return
    }
    let resolution: NhTagCatalogResolution = new NhTagCatalogResolution()
    try {
      resolution = await NhTagCatalogRepository.resolveByIds(context, ids)
    } catch (_error) {
      // A private catalog read is optional. Continue with a transient catalog
      // so a successful current public response can still reach this page.
    }
    const catalog: Map<number, NhTag> = resolution.tags
    const missing: number[] = ids.filter((id: number): boolean =>
      !catalog.has(id) || resolution.detailFallbackIds.has(id))
    if (missing.length > 0) {
      const fetched: NhTag[] = []
      for (let start: number = 0; start < missing.length; start += FETCH_BATCH_SIZE) {
        try {
          const batch: NhTag[] = await fetchTags(missing.slice(start, start + FETCH_BATCH_SIZE))
          fetched.push(...batch)
        } catch (_error) {
          // A public tag catalog failure must never reject the list payload.
        }
      }
      if (fetched.length > 0) {
        NhTagCatalogService.mergeCatalog(catalog, fetched)
        try {
          await NhTagCatalogRepository.upsert(context, fetched)
        } catch (_error) {
          // The current response remains enough for this page; persistence is
          // an optimization and must not discard names we already received.
        }
      }
    }
    const translations: Map<string, string> = await NhTagCatalogService.localDisplayLabels(context, catalog)
    for (let galleryIndex: number = 0; galleryIndex < galleries.length; galleryIndex++) {
      const gallery: NhGallerySummary = galleries[galleryIndex]
      gallery.tags = NhTagCatalogService.tagsFor(gallery.tagIds, catalog, translations)
    }
  }

  private static async rememberInternal(
    context: common.UIAbilityContext,
    tags: NhTag[],
  ): Promise<void> {
    try {
      await NhTagCatalogRepository.insertDetailFallbacks(context, tags)
    } catch (_error) {
      // Detail data remains valid if the optional local catalog is unavailable.
    }
  }

  private static async promoteInternal(
    context: common.UIAbilityContext,
    tags: NhTag[],
  ): Promise<void> {
    try {
      await NhTagCatalogRepository.upsert(context, tags)
    } catch (_error) {
      // The accepted Detail response remains valid if this optional catalog
      // promotion cannot be persisted.
    }
  }

  /** The optional dictionary is local-only; an unavailable lookup preserves raw public names. */
  private static async localDisplayLabels(
    context: common.UIAbilityContext,
    catalog: Map<number, NhTag>,
  ): Promise<Map<string, string>> {
    const tags: NhTag[] = []
    catalog.forEach((tag: NhTag): void => {
      tags.push(tag)
    })
    if (tags.length === 0) {
      return new Map<string, string>()
    }
    try {
      return await TagTranslationRepository.lookup(context, tags)
    } catch (_error) {
      return new Map<string, string>()
    }
  }

  private static collectIds(galleries: NhGallerySummary[]): number[] {
    const ids: number[] = []
    const seen: Set<number> = new Set<number>()
    for (let galleryIndex: number = 0; galleryIndex < galleries.length; galleryIndex++) {
      const tagIds: number[] = galleries[galleryIndex].tagIds
      for (let tagIndex: number = 0; tagIndex < tagIds.length; tagIndex++) {
        const id: number = Math.floor(tagIds[tagIndex])
        if (id > 0 && !seen.has(id)) {
          seen.add(id)
          ids.push(id)
        }
      }
    }
    return ids
  }

  private static collectResolvedTags(galleries: NhGallerySummary[]): NhTag[] {
    const tags: NhTag[] = []
    const seen: Set<number> = new Set<number>()
    for (let galleryIndex: number = 0; galleryIndex < galleries.length; galleryIndex++) {
      const galleryTags: NhTag[] = galleries[galleryIndex].tags
      for (let tagIndex: number = 0; tagIndex < galleryTags.length; tagIndex++) {
        const tag: NhTag = galleryTags[tagIndex]
        if (tag.id > 0 && tag.name.trim().length > 0 && !seen.has(tag.id)) {
          seen.add(tag.id)
          tags.push(tag)
        }
      }
    }
    return tags
  }

  private static catalogSnapshot(rawTags: NhTag[]): NhTag[] {
    const result: NhTag[] = []
    for (let index: number = 0; index < rawTags.length; index++) {
      const source: NhTag = rawTags[index]
      const tag: NhTag = new NhTag()
      tag.id = source.id
      tag.type = source.type
      tag.name = source.name
      tag.count = source.count
      result.push(tag)
    }
    return result
  }

  private static mergeCatalog(catalog: Map<number, NhTag>, tags: NhTag[]): void {
    for (let index: number = 0; index < tags.length; index++) {
      const source: NhTag = tags[index]
      if (source.id <= 0 || source.name.trim().length === 0) {
        continue
      }
      const tag: NhTag = new NhTag()
      tag.id = source.id
      tag.type = source.type
      tag.name = source.name
      tag.count = source.count
      catalog.set(tag.id, tag)
    }
  }

  private static copyGalleryWithDisplayLabels(
    source: NhGallerySummary,
    translations: Map<string, string>,
  ): NhGallerySummary {
    const gallery: NhGallerySummary = new NhGallerySummary()
    gallery.id = source.id
    gallery.mediaId = source.mediaId
    gallery.englishTitle = source.englishTitle
    gallery.japaneseTitle = source.japaneseTitle
    gallery.thumbnailUrl = source.thumbnailUrl
    gallery.pageCount = source.pageCount
    gallery.thumbnailWidth = source.thumbnailWidth
    gallery.thumbnailHeight = source.thumbnailHeight
    gallery.tagIds = source.tagIds.slice()
    gallery.tags = source.tags.map((sourceTag: NhTag): NhTag => {
      const tag: NhTag = new NhTag()
      tag.id = sourceTag.id
      tag.type = sourceTag.type
      tag.name = sourceTag.name
      tag.displayName = translations.get(TagTranslationRepository.keyFor(sourceTag)) ?? sourceTag.name
      tag.count = sourceTag.count
      return tag
    })
    return gallery
  }

  private static tagsFor(
    ids: number[],
    catalog: Map<number, NhTag>,
    translations: Map<string, string>,
  ): NhTag[] {
    const result: NhTag[] = []
    for (let index: number = 0; index < ids.length; index++) {
      const found: NhTag | undefined = catalog.get(ids[index])
      if (found === undefined) {
        continue
      }
      const tag: NhTag = new NhTag()
      tag.id = found.id
      tag.type = found.type
      tag.name = found.name
      tag.displayName = translations.get(TagTranslationRepository.keyFor(found)) ?? found.name
      tag.count = found.count
      result.push(tag)
    }
    return result
  }
}
