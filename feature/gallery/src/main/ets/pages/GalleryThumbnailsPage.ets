import {
  NhGalleryDetail,
  NhGalleryPage,
  ReaderOverlayNavigationState,
  ReaderThumbnailTransitionCoordinator,
  connectReaderOverlayNavigation,
} from 'shared'
import { GalleryThumbnailGridContent } from '../components/GalleryThumbnailGridContent'
import { GalleryThumbnailsChromeState } from '../state/GalleryThumbnailsChromeState'

/**
 * Standalone full-thumbnail destination. HDS owns its title and Back chrome;
 * the reusable content owner keeps Grid, First/Jump, and Reader-index
 * semantics identical to the wide Gallery Detail companion pane.
 */
@ComponentV2
export struct GalleryThumbnailsPage {
  @Require @Param galleryId: number
  @Param pages: NhGalleryPage[] = []
  @Param detailSeed: NhGalleryDetail = new NhGalleryDetail()
  @Param chrome: GalleryThumbnailsChromeState = new GalleryThumbnailsChromeState()
  @Param scroller: Scroller = new Scroller()
  @Event onOpenReader?: (galleryId: number, pageIndex: number, animated: boolean) => void
  @Local readerOverlay: ReaderOverlayNavigationState = connectReaderOverlayNavigation()
  private transitionScope: string = ReaderThumbnailTransitionCoordinator.allocateScope('all-thumbnails')

  private openReader(pageIndex: number): void {
    if (this.galleryId <= 0 || pageIndex < 0 || pageIndex >= this.pages.length || !this.onOpenReader) {
      return
    }
    const page: NhGalleryPage = this.pages[pageIndex]
    ReaderThumbnailTransitionCoordinator.open(
      this.getUIContext(),
      this.transitionScope,
      this.galleryId.toString(),
      pageIndex,
      page,
      (animated: boolean): void => {
        if (this.detailSeed.id === this.galleryId) {
          this.readerOverlay.stageDetailSeed(this.detailSeed)
        }
        try {
          if (this.onOpenReader) {
            this.onOpenReader(this.galleryId, pageIndex, animated)
          }
        } finally {
          this.readerOverlay.discardStagedDetailSeed(this.galleryId)
        }
      },
    )
  }

  build() {
    GalleryThumbnailGridContent({
      pages: this.pages,
      chrome: this.chrome,
      scroller: this.scroller,
      transitionScope: this.transitionScope,
      onOpenPage: (pageIndex: number): void => {
        this.openReader(pageIndex)
      },
    })
  }
}
