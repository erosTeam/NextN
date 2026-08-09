import { common } from '@kit.AbilityKit'
import { NhBrowsePresentation } from '../model/NhBrowsePresentation'
import { connectBrowsePresentation } from '../state/BrowsePresentationState'
import { clampGalleryColumnWidth, supportsGalleryColumnDensity } from '../utils/GalleryColumns'
import { BrowsePresentationRepository } from '../storage/BrowsePresentationRepository'

/**
 * UI-facing boundary for local Browse presentation state. It keeps live
 * Slider/pinch updates in AppStorageV2 and commits only explicit final values
 * through the repository, never touching a gallery request or its cursor.
 */
export class BrowsePresentationService {
  static restore(context: common.UIAbilityContext): Promise<NhBrowsePresentation> {
    return BrowsePresentationRepository.restore(context)
  }

  static setMode(context: common.UIAbilityContext, mode: NhBrowsePresentation): Promise<void> {
    return BrowsePresentationRepository.save(context, mode)
  }

  static setLiveColumnWidth(mode: NhBrowsePresentation, width: number): void {
    if (!supportsGalleryColumnDensity(mode)) {
      return
    }
    connectBrowsePresentation().setColumnWidthFor(mode, clampGalleryColumnWidth(width))
  }

  static setColumnWidth(
    context: common.UIAbilityContext,
    mode: NhBrowsePresentation,
    width: number,
  ): Promise<void> {
    return BrowsePresentationRepository.saveColumnWidth(context, mode, width)
  }
}
