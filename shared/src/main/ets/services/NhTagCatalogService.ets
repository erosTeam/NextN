import { common } from '@kit.AbilityKit'
import { NhGallerySummary, NhTag } from '../model/NhGallery'
import { NhTagCatalogRepository } from '../storage/NhTagCatalogRepository'

const FETCH_BATCH_SIZE: number = 100

/**
 * Enriches a loaded public list in one serialized, deduplicated catalog pass.
 * A catalog miss is non-fatal: the original gallery list stays usable and its
 * cards simply retain their no-tag leaves until a later successful load.
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
    let catalog: Map<number, NhTag>
    try {
      catalog = await NhTagCatalogRepository.findByIds(context, ids)
    } catch (_error) {
      return
    }
    const missing: number[] = ids.filter((id: number): boolean => !catalog.has(id))
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
        try {
          await NhTagCatalogRepository.upsert(context, fetched)
          catalog = await NhTagCatalogRepository.findByIds(context, ids)
        } catch (_error) {
          // Keep the already-loaded gallery list if cache persistence fails.
        }
      }
    }
    for (let galleryIndex: number = 0; galleryIndex < galleries.length; galleryIndex++) {
      const gallery: NhGallerySummary = galleries[galleryIndex]
      gallery.tags = NhTagCatalogService.tagsFor(gallery.tagIds, catalog)
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

  private static tagsFor(ids: number[], catalog: Map<number, NhTag>): NhTag[] {
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
      tag.count = found.count
      result.push(tag)
    }
    return result
  }
}
