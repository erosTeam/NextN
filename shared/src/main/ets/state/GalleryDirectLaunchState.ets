import { AppStorageV2 } from '@kit.ArkUI'

const GALLERY_DIRECT_LAUNCH_V2_KEY: string = 'v2_galleryDirectLaunch'

/**
 * One-shot handoff from an explicit EntryAbility Want to the root navigator.
 * The numeric gallery id is route state only: it is never persisted and does
 * not carry account, browser, or content data.
 */
@ObservedV2
export class GalleryDirectLaunchState {
  @Trace requestVersion: number = 0
  @Trace pendingGalleryId: number = 0

  request(galleryId: number): void {
    if (!Number.isSafeInteger(galleryId) || galleryId <= 0) {
      return
    }
    this.pendingGalleryId = galleryId
    this.requestVersion += 1
  }

  consume(): number {
    const galleryId: number = this.pendingGalleryId
    this.pendingGalleryId = 0
    return Number.isSafeInteger(galleryId) && galleryId > 0 ? galleryId : 0
  }
}

export function connectGalleryDirectLaunch(): GalleryDirectLaunchState {
  return AppStorageV2.connect(
    GalleryDirectLaunchState,
    GALLERY_DIRECT_LAUNCH_V2_KEY,
    (): GalleryDirectLaunchState => new GalleryDirectLaunchState(),
  )!
}

export function requestGalleryDirectLaunch(galleryId: number): void {
  connectGalleryDirectLaunch().request(galleryId)
}
