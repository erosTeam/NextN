/**
 * NextN-owned input for the shared reader host.
 *
 * The production route and the Debug Lab share only these session inputs.
 * Probe and override fields stay on the separate ReaderLabRequest.
 */
export interface NextNReaderHostRequest {
  work: string
  pageIndex: number
  readingChrome: boolean
  progressReadWrite: boolean
  /** Whether this launch may replace its explicit page with durable history. */
  restoreSavedProgress?: boolean
  /** Present only for a production overlay route; debug requests stay isolated. */
  productionSources?: boolean
  routeEpoch?: number
}

/** Ordinary NextN route request. Debug probes are supplied through a separate Lab input. */
export class NextNProductionReaderRequest implements NextNReaderHostRequest {
  work: string
  pageIndex: number
  readingChrome: boolean = true
  progressReadWrite: boolean = true
  restoreSavedProgress: boolean
  productionSources: boolean = true
  routeEpoch: number

  constructor(galleryId: number, initialPageIndex: number, routeEpoch: number) {
    this.work = galleryId > 0 ? galleryId.toString() : ''
    this.restoreSavedProgress = initialPageIndex < 0
    this.pageIndex = initialPageIndex >= 0 ? Math.floor(initialPageIndex) : 0
    this.routeEpoch = routeEpoch > 0 ? Math.floor(routeEpoch) : 0
  }
}
