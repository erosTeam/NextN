import { common } from '@kit.AbilityKit'
import { ImageKnifeRequest } from '@ohos/imageknifepro'
import { CacheStat } from './CacheStat'
import { ImageKnifePreloadCallbacks, ImageKnifeProRuntime } from './ImageKnifeProRuntime'
import { ReaderImageCacheService } from './ReaderImageCacheService'
import { EH_IMAGE_PRIORITY_LOW } from './ImagePipelineTypes'

/**
 * Cover-thumbnail pipeline facade for NextN gallery lists. Initialization,
 * preload, statistics and clearing are delegated to ImageKnifeProRuntime;
 * the reader page keeps its existing ReaderImageCacheService owner.
 */
export class ImagePipelineService {
  static initialize(context: common.UIAbilityContext): void {
    ImageKnifeProRuntime.initialize(context)
  }

  static clearOnBackground(): void {
    ImageKnifeProRuntime.clearOnBackground()
  }

  static reloadOnForeground(): void {
    ImageKnifeProRuntime.reloadOnForeground()
  }

  static preloadCover(
    url: string,
    priority: number = EH_IMAGE_PRIORITY_LOW,
    fileCacheOnly: boolean = false,
    callbacks?: ImageKnifePreloadCallbacks,
  ): ImageKnifeRequest | null {
    return ImageKnifeProRuntime.preload(url, priority, fileCacheOnly, callbacks)
  }

  static cancelCoverPreload(request: ImageKnifeRequest): void {
    ImageKnifeProRuntime.cancelPreload(request)
  }

  /**
   * NextE-shaped image-cache aggregate: gallery cover thumbnails
   * (ImageKnifePro) plus reader page files (ReaderImageCacheService) are one
   * clearable/stats row in the storage page, matching NextE's ImagePipelineService.
   */
  static stat(context: common.UIAbilityContext): CacheStat {
    const out: CacheStat = ImageKnifeProRuntime.stat()
    const reader = ReaderImageCacheService.status(context)
    out.count += reader.fileCount
    out.bytes += reader.bytes
    return out
  }

  static async clearCache(context: common.UIAbilityContext): Promise<void> {
    await ImageKnifeProRuntime.clearCache()
    await ReaderImageCacheService.clear(context)
  }
}
