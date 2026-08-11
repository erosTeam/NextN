import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'

const EXPORT_CACHE_DIRECTORY: string = 'nextn-download-exports'
const EXPORT_MAX_AGE_MS: number = 24 * 60 * 60 * 1000
const EXPORT_FILE_PATTERN: RegExp = /^nextn-gallery-([1-9][0-9]*)-[1-9][0-9]*\.cbz(?:\.part)?$/

/**
 * Owns only the private, cache-backed CBZ handoff artifacts. It has no queue,
 * account, network, or ShareKit dependency so queue removal and cold restore
 * can reclaim exports without creating an import cycle.
 */
export class NhDownloadExportCacheService {
  private static activeGalleryIds: Set<number> = new Set<number>()

  static beginUse(galleryId: number): boolean {
    const normalizedGalleryId: number = NhDownloadExportCacheService.galleryId(galleryId)
    if (normalizedGalleryId <= 0 || NhDownloadExportCacheService.activeGalleryIds.has(normalizedGalleryId)) {
      return false
    }
    NhDownloadExportCacheService.activeGalleryIds.add(normalizedGalleryId)
    return true
  }

  static endUse(galleryId: number): void {
    const normalizedGalleryId: number = NhDownloadExportCacheService.galleryId(galleryId)
    if (normalizedGalleryId > 0) {
      NhDownloadExportCacheService.activeGalleryIds.delete(normalizedGalleryId)
    }
  }

  /** Remove only this task's completed/partial handoff files after task removal. */
  static reclaimGallery(context: common.UIAbilityContext, galleryId: number): void {
    const normalizedGalleryId: number = NhDownloadExportCacheService.galleryId(galleryId)
    if (normalizedGalleryId <= 0 || NhDownloadExportCacheService.activeGalleryIds.has(normalizedGalleryId)) {
      return
    }
    NhDownloadExportCacheService.forEachOwnedFile(context, (name: string, ownerGalleryId: number): void => {
      if (ownerGalleryId === normalizedGalleryId) {
        NhDownloadExportCacheService.removeIfExists(
          `${NhDownloadExportCacheService.directory(context)}/${name}`,
        )
      }
    })
  }

  /** A cold-start pass removes abandoned partials and bounded-age cache handoffs. */
  static pruneExpired(context: common.UIAbilityContext): void {
    const now: number = Date.now()
    NhDownloadExportCacheService.forEachOwnedFile(context, (name: string, galleryId: number): void => {
      if (NhDownloadExportCacheService.activeGalleryIds.has(galleryId)) {
        return
      }
      const path: string = `${NhDownloadExportCacheService.directory(context)}/${name}`
      if (name.endsWith('.part') || NhDownloadExportCacheService.isExpired(path, now)) {
        NhDownloadExportCacheService.removeIfExists(path)
      }
    })
  }

  private static forEachOwnedFile(
    context: common.UIAbilityContext,
    action: (name: string, galleryId: number) => void,
  ): void {
    const directory: string = NhDownloadExportCacheService.directory(context)
    try {
      if (!fileIo.accessSync(directory)) {
        return
      }
      const names: string[] = fileIo.listFileSync(directory)
      for (let index: number = 0; index < names.length; index += 1) {
        const galleryId: number = NhDownloadExportCacheService.ownerGalleryId(names[index])
        if (galleryId > 0) {
          action(names[index], galleryId)
        }
      }
    } catch (_error) {}
  }

  private static directory(context: common.UIAbilityContext): string {
    return `${context.cacheDir}/${EXPORT_CACHE_DIRECTORY}`
  }

  private static ownerGalleryId(name: string): number {
    const match: RegExpMatchArray | null = name.match(EXPORT_FILE_PATTERN)
    return match === null ? 0 : NhDownloadExportCacheService.galleryId(Number(match[1]))
  }

  private static galleryId(value: number): number {
    const normalized: number = Math.floor(value)
    return Number.isSafeInteger(normalized) && normalized > 0 ? normalized : 0
  }

  private static isExpired(path: string, now: number): boolean {
    try {
      const mtime: number = fileIo.statSync(path).mtime
      return mtime <= 0 || now - mtime >= EXPORT_MAX_AGE_MS
    } catch (_error) {
      return true
    }
  }

  private static removeIfExists(path: string): void {
    try {
      fileIo.unlinkSync(path)
    } catch (_error) {}
  }
}
