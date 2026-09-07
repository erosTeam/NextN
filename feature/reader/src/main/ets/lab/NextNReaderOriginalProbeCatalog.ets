import { ReaderCatalog, ReaderUnitKey, ReaderUnit, ReaderPage, ReaderCancellation } from '@reader-kit/core'

/** One opted-in trial catalog. Never changes the adapter's objects or cached source metadata. */
export class NextNReaderOriginalProbeCatalog implements ReaderCatalog {
  private inner: ReaderCatalog
  private galleryId: string
  private pageIndex: number

  constructor(inner: ReaderCatalog, galleryId: string, pageIndex: number) {
    this.inner = inner
    this.galleryId = galleryId
    this.pageIndex = pageIndex
  }

  open(key: ReaderUnitKey, cancellation: ReaderCancellation): Promise<ReaderUnit> {
    return this.inner.open(key, cancellation)
  }

  async page(unit: ReaderUnit, index: number, cancellation: ReaderCancellation): Promise<ReaderPage> {
    const page = (await this.inner.page(unit, index, cancellation)).copy()
    if (page.unit.scope === 'nh' && page.unit.work === this.galleryId && page.unit.unit === this.galleryId &&
      page.sourceIndex === this.pageIndex) {
      page.width = 0
      page.height = 0
    }
    return page
  }

  adjacent(unit: ReaderUnit, direction: 'next' | 'previous'): ReaderUnitKey | null {
    return this.inner.adjacent(unit, direction)
  }
}
