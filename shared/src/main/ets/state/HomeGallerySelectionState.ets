import { AppStorageV2 } from '@kit.ArkUI'

/**
 * The selected root-split Gallery entry for Browse's retained primary lists.
 *
 * Index is the sole writer: it derives this ephemeral value from the settled
 * root secondary branch and the HDS-resolved split mode. Home sources only
 * render it, so Search, History, Favorites, Downloads and direct route
 * pushes cannot acquire peer-list replacement behavior through this state.
 */
@ObservedV2
export class HomeGallerySelectionState {
  @Trace selectedGalleryId: number = 0

  setSelectedGalleryId(galleryId: number): void {
    const nextGalleryId: number = Number.isSafeInteger(galleryId) && galleryId > 0
      ? galleryId
      : 0
    if (this.selectedGalleryId !== nextGalleryId) {
      this.selectedGalleryId = nextGalleryId
    }
  }

  clear(): void {
    this.setSelectedGalleryId(0)
  }
}

const HOME_GALLERY_SELECTION_KEY: string = 'nextn_home_gallery_selection'

export function connectHomeGallerySelection(): HomeGallerySelectionState {
  return AppStorageV2.connect(
    HomeGallerySelectionState,
    HOME_GALLERY_SELECTION_KEY,
    () => new HomeGallerySelectionState(),
  )!
}
