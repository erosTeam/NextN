import { AppStorageV2 } from '@kit.ArkUI'

/**
 * Detail-page title preference matching NextE's GalleryTitleState.
 * It changes only which already-returned title is primary on Gallery pages.
 */
@ObservedV2
export class GalleryTitleState {
  @Trace japaneseTitlePrimary: boolean = false
}

const GALLERY_TITLE_STATE_KEY: string = 'nextn_gallery_title'

export function connectGalleryTitle(): GalleryTitleState {
  return AppStorageV2.connect(
    GalleryTitleState,
    GALLERY_TITLE_STATE_KEY,
    () => new GalleryTitleState(),
  )!
}
