import { ReaderReadingAnchor } from '@reader-kit/core'

/**
 * Maps a shared-reader visible-original anchor to NextN's canonical zero-based
 * page progress. This debug bridge deliberately owns no persistence.
 */
export class NextNReaderObservedProgress {
  private work: string = ''
  private lastPageIndex: number = -1

  observe(expectedWork: string, pageCount: number, anchor: ReaderReadingAnchor): number {
    if (expectedWork !== this.work) {
      this.work = expectedWork
      this.lastPageIndex = -1
    }
    const galleryId = Number(expectedWork)
    const sourceIndex = anchor.sourceIndexHint
    if (!Number.isSafeInteger(galleryId) || galleryId <= 0 || !Number.isInteger(pageCount) || pageCount <= 0 ||
      anchor.unit.scope !== 'nh' || anchor.unit.work !== expectedWork || anchor.unit.unit !== expectedWork ||
      anchor.pageKey === null || !anchor.pageKey.startsWith(`${expectedWork}:`) ||
      !Number.isInteger(sourceIndex) || sourceIndex < 0 || sourceIndex >= pageCount ||
      sourceIndex === this.lastPageIndex) return -1
    this.lastPageIndex = sourceIndex
    return sourceIndex
  }
}
