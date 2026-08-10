import { AppStorageV2 } from '@kit.ArkUI'

const GALLERY_DIRECT_LAUNCH_V2_KEY: string = 'v2_galleryDirectLaunch'

export class GalleryDirectLaunchRequest {
  galleryId: number
  openComments: boolean

  constructor(galleryId: number = 0, openComments: boolean = false) {
    this.galleryId = galleryId
    this.openComments = openComments
  }
}

/**
 * One-shot handoff from an explicit EntryAbility Want to the root navigator.
 * The numeric gallery id is route state only: it is never persisted and does
 * not carry account, browser, or content data. `openComments` selects the
 * existing native Comments destination without a scroll or coordinate path.
 */
@ObservedV2
export class GalleryDirectLaunchState {
  @Trace requestVersion: number = 0
  @Trace pendingGalleryId: number = 0
  @Trace pendingComments: boolean = false

  request(galleryId: number, openComments: boolean = false): void {
    if (!Number.isSafeInteger(galleryId) || galleryId <= 0) {
      return
    }
    this.pendingGalleryId = galleryId
    this.pendingComments = openComments
    this.requestVersion += 1
  }

  consume(): GalleryDirectLaunchRequest {
    const galleryId: number = this.pendingGalleryId
    const openComments: boolean = this.pendingComments
    this.pendingGalleryId = 0
    this.pendingComments = false
    return new GalleryDirectLaunchRequest(
      Number.isSafeInteger(galleryId) && galleryId > 0 ? galleryId : 0,
      openComments,
    )
  }
}

export function connectGalleryDirectLaunch(): GalleryDirectLaunchState {
  return AppStorageV2.connect(
    GalleryDirectLaunchState,
    GALLERY_DIRECT_LAUNCH_V2_KEY,
    (): GalleryDirectLaunchState => new GalleryDirectLaunchState(),
  )!
}

export function requestGalleryDirectLaunch(galleryId: number, openComments: boolean = false): void {
  connectGalleryDirectLaunch().request(galleryId, openComments)
}
