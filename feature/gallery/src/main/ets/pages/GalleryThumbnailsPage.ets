import { NhGalleryPage } from 'shared'
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
  @Event onOpenReader?: (galleryId: number, pageIndex: number) => void

  private openReader(pageIndex: number): void {
    if (this.galleryId <= 0 || pageIndex < 0 || pageIndex >= this.pages.length || !this.onOpenReader) {
      return
    }
    this.onOpenReader(this.galleryId, pageIndex)
  }

  build() {
    GalleryThumbnailGridContent({
      pages: this.pages,
      chrome: this.chrome,
      scroller: this.scroller,
      onOpenPage: (pageIndex: number): void => {
        this.openReader(pageIndex)
      },
    })
  }
}
