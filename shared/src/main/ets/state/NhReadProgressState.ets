import { AppStorageV2 } from '@kit.ArkUI'

const NH_READ_PROGRESS_STATE_KEY: string = 'nextn_read_progress'

/**
 * In-memory per-gallery reading position with a reactive revision signal.
 *
 * The Reader writes every page turn here immediately (the RDB flush stays
 * debounced); the gallery detail page reads `has`/`index` inside build(), so
 * returning from the Reader refreshes the Read button without re-querying
 * storage. The RDB remains the durable source and seeds this holder on first
 * detail load. This mirrors NextE GalleryReadProgressState's two-tier memory
 * first / disk debounced design.
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

  /** Immediate page-turn write; the caller still owns the durable flush. */
  set(galleryId: number, pageIndex: number): void {
    if (galleryId <= 0 || pageIndex < 0) {
      return
    }
    this.indexByGallery.set(galleryId, pageIndex)
    this.revision += 1
  }

  /**
   * Seed from durable storage without overwriting a newer in-memory turn.
   * Called only when the RDB reports a real marker for this gallery.
   */
  seed(galleryId: number, pageIndex: number): void {
    if (galleryId <= 0 || pageIndex < 0) {
      return
    }
    const current: number | undefined = this.indexByGallery.get(galleryId)
    if (current !== undefined && current > pageIndex) {
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
