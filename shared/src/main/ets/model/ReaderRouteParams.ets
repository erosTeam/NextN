/**
 * Typed payload for the private full-window Reader navigation stack.
 *
 * Keeping this in shared lets the entry shell open Reader without retaining
 * its route on the adaptive root navigation stack.
 */
export class ReaderRouteParams {
  galleryId: number = 0
  initialPageIndex: number = -1
  /**
   * Assigned by the overlay owner for every presentation. It is intentionally
   * not a persisted route argument: it only lets a Reader consume a matching
   * in-memory detail snapshot exactly once.
   */
  routeEpoch: number = 0

  constructor(galleryId: number = 0, initialPageIndex: number = -1, routeEpoch: number = 0) {
    this.galleryId = galleryId
    this.initialPageIndex = initialPageIndex >= 0 ? Math.floor(initialPageIndex) : -1
    this.routeEpoch = routeEpoch > 0 ? Math.floor(routeEpoch) : 0
  }
}
