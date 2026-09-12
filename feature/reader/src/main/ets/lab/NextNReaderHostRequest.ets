/**
 * NextN-owned input for the shared reader host.
 *
 * The production route and the debug Lab may both satisfy this contract, but
 * neither reader-kit nor the route DTO owns NH settings, progress, cache, or
 * failure-injection semantics.
 */
export interface NextNReaderHostRequest {
  work: string
  pageIndex: number
  readingChrome: boolean
  progressReadWrite: boolean
  thumbnailEntry: boolean
  /** Whether this launch may replace its explicit page with durable history. */
  restoreSavedProgress?: boolean
  entryLayoutOverride: string | null
  entryDirectionOverride: string | null
  cropBorders: boolean
  volumeKeysOverride: boolean | null
  /** Debug-only override; production inherits the live host setting. */
  pageTurnAnimationOverride?: boolean | null
  failurePage: number
  delayedMetricsPage: number
  failureLayout: string
  thumbnailFailurePage: number
  shareProbe: string
  informationProbe: string
  /** Present only for a production overlay route; debug requests stay isolated. */
  productionSources?: boolean
  routeEpoch?: number
}

/** Ordinary NextN route request. Debug probes and layout overrides stay off. */
export class NextNProductionReaderRequest implements NextNReaderHostRequest {
  work: string
  pageIndex: number
  readingChrome: boolean = true
  progressReadWrite: boolean = true
  thumbnailEntry: boolean = false
  restoreSavedProgress: boolean
  entryLayoutOverride: string | null = null
  entryDirectionOverride: string | null = null
  cropBorders: boolean = false
  volumeKeysOverride: boolean | null = null
  failurePage: number = -1
  delayedMetricsPage: number = -1
  failureLayout: string = 'continuous'
  thumbnailFailurePage: number = -1
  shareProbe: string = ''
  informationProbe: string = ''
  productionSources: boolean = true
  routeEpoch: number

  constructor(galleryId: number, initialPageIndex: number, routeEpoch: number) {
    this.work = galleryId > 0 ? galleryId.toString() : ''
    this.restoreSavedProgress = initialPageIndex < 0
    this.pageIndex = initialPageIndex >= 0 ? Math.floor(initialPageIndex) : 0
    this.routeEpoch = routeEpoch > 0 ? Math.floor(routeEpoch) : 0
  }
}
