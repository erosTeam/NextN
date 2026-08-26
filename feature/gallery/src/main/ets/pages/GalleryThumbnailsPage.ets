import { NhGalleryPage, ReaderThumbnailTransitionCoordinator } from 'shared'
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
  @Param chrome: GalleryThumbnailsChromeState = new GalleryThumbnailsChromeState()
  @Param scroller: Scroller = new Scroller()
  @Event onOpenReader?: (galleryId: number, pageIndex: number, animated: boolean) => void
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
        if (this.onOpenReader) {
          this.onOpenReader(this.galleryId, pageIndex, animated)
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
