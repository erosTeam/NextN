import { AppStorageV2 } from '@kit.ArkUI'

const NH_READ_PROGRESS_STATE_KEY: string = 'nextn_read_progress'

/**
 * In-memory per-gallery reading position with a reactive revision signal.
 *
 * HistoryRepository publishes every saved Reader position here immediately,
 * then serializes the same position to RDB. Gallery Detail freezes a display
 * snapshot while Reader covers it and reveals the final value when Reader
 * starts closing. The RDB remains the durable source and seeds this holder on
 * first detail load. The in-memory page follows NextE's last-call-wins
 * contract; NextN's durable writes are serialized, not debounced.
 */
@ObservedV2
export class NhReadProgressState {
  // Plain Map mutations are not observable; every consumer reads this trace
  // field so a page turn re-renders the subscribing detail surface.
  @Trace revision: number = 0
  private indexByGallery: Map<number, number> = new Map<number, number>()

  /** Establish the reactive dependency and report whether a marker exists. */
  has(galleryId: number): boolean {
    if (this.revision < 0) {
      return false
    }
    return galleryId > 0 && this.indexByGallery.has(galleryId)
  }

  /** Establish the reactive dependency and return the saved zero-based page. */
  index(galleryId: number): number {
    if (this.revision < 0 || galleryId <= 0) {
      return 0
    }
    const value: number | undefined = this.indexByGallery.get(galleryId)
    return value === undefined ? 0 : value
  }

  /** Immediate last-call-wins write; page order is never mutation order. */
  set(galleryId: number, pageIndex: number): void {
    if (galleryId <= 0 || pageIndex < 0) {
      return
    }
    this.indexByGallery.set(galleryId, pageIndex)
    this.revision += 1
  }

  /**
   * Seed from durable storage only before this process has observed a write.
   * Every in-process progress writer publishes through HistoryRepository, so
   * an existing entry is newer than an async detail-load snapshot regardless
   * of whether its page number moved forward or backward.
   */
  seed(galleryId: number, pageIndex: number): void {
    if (galleryId <= 0 || pageIndex < 0) {
      return
    }
    const current: number | undefined = this.indexByGallery.get(galleryId)
    if (current !== undefined) {
      return
    }
    this.indexByGallery.set(galleryId, pageIndex)
    this.revision += 1
  }
}

export function connectNhReadProgress(): NhReadProgressState {
  return AppStorageV2.connect(
    NhReadProgressState,
    NH_READ_PROGRESS_STATE_KEY,
    (): NhReadProgressState => new NhReadProgressState(),
  )!
}
