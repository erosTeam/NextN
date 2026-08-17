import { common } from '@kit.AbilityKit'
import { ImageKnifeRequest } from '@ohos/imageknifepro'
import { CacheStat } from './CacheStat'
import { ImageKnifePreloadCallbacks, ImageKnifeProRuntime } from './ImageKnifeProRuntime'
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

  static stat(): CacheStat {
    return ImageKnifeProRuntime.stat()
  }

  static async clearCache(): Promise<void> {
    await ImageKnifeProRuntime.clearCache()
  }
}
