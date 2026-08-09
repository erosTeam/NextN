/**
 * Route-local HDS commands for the full thumbnail overview. The entry shell
 * owns the title-bar actions while the retained page owns its Scroller and
 * jump editor, so commands are represented only as monotonic intent versions.
 */
@ObservedV2
export class GalleryThumbnailsChromeState {
  @Trace firstPageRequestVersion: number = 0
  @Trace jumpPageRequestVersion: number = 0
}
