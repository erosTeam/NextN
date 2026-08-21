import { AppStorageV2 } from '@kit.ArkUI'

/**
 * Explicit retry signal for gallery covers whose URL does not change across a
 * collection refresh. Successful covers ignore it; failed or still-pending
 * GalleryThumbnail instances restart without changing their source or key.
 */
@ObservedV2
export class GalleryCoverRetryState {
  @Trace epoch: number = 0
}

const GALLERY_COVER_RETRY_KEY: string = 'v2_galleryCoverRetry'

export function connectGalleryCoverRetry(): GalleryCoverRetryState {
  return AppStorageV2.connect(
    GalleryCoverRetryState,
    GALLERY_COVER_RETRY_KEY,
    () => new GalleryCoverRetryState(),
  )!
}

export function requestGalleryCoverRetry(): void {
  const state: GalleryCoverRetryState = connectGalleryCoverRetry()
  state.epoch += 1
}
