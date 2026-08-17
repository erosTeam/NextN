import { ImageKnifeRequest } from '@ohos/imageknifepro'
import { NhGallerySummary } from '../model/NhGallery'
import { ImageKnifePreloadCallbacks } from './ImageKnifeProRuntime'
import { ImagePipelineService } from './ImagePipelineService'
import { EH_IMAGE_PRIORITY_LOW } from './ImagePipelineTypes'

/**
 * Offscreen cover preload for NextN's ForEach-backed gallery collections.
 *
 * NextE routes this through BasicPrefetcher on its LazyForEach data sources;
 * NextN's shared GalleryCollectionBody renders caller-owned arrays with
 * ForEach, so the equivalent visible-area contract is applied at the shared
 * onScrollIndex boundary: covers just past the visible range are requested
 * into the ImageKnife FILE cache at low priority, and the visible cards then
 * hit that cache instead of showing a blank tile while a fresh network load
 * runs.
 */
const GALLERY_COVER_PREFETCH_AHEAD: number = 10
const GALLERY_COVER_PREFETCH_GUARD_MS: number = 15000
const GALLERY_COVER_PREFETCH_MAX_TICKETS: number = 96

class GalleryCoverPrefetchTicket {
  readonly url: string
  request: ImageKnifeRequest | null = null
  started: boolean = false
  private settled: boolean = false
  private guardTimerId: number = 0

  constructor(url: string) {
    this.url = url
  }

  armGuard(onExpired: () => void): void {
    if (this.settled || this.guardTimerId > 0) {
      return
    }
    this.guardTimerId = setTimeout((): void => {
      this.guardTimerId = 0
      onExpired()
    }, GALLERY_COVER_PREFETCH_GUARD_MS)
  }

  markStarted(): void {
    this.started = true
  }

  finish(): void {
    if (this.settled) {
      return
    }
    this.settled = true
    if (this.guardTimerId > 0) {
      clearTimeout(this.guardTimerId)
      this.guardTimerId = 0
    }
  }

  isSettled(): boolean {
    return this.settled
  }
}

/**
 * One small LRU-ish ticket map keyed by cover URL. A request becomes
 * non-cancellable once ImageKnife starts it, so direction changes only
 * remove work still queued in ImageKnife's own pool.
 */
export class GalleryCoverPrefetcher {
  private readonly tickets: Map<string, GalleryCoverPrefetchTicket> = new Map()

  /** Feed normalized gallery indexes from the shared collection scroll hooks. */
  schedule(galleries: NhGallerySummary[], visibleStart: number, visibleEnd: number): void {
    const total: number = galleries.length
    if (total <= 0) {
      return
    }
    const lo: number = Math.max(0, Math.min(visibleStart, total - 1))
    const hi: number = Math.max(0, Math.min(visibleEnd, total - 1))
    if (lo > hi) {
      return
    }
    const first: number = hi + 1
    const last: number = Math.min(total - 1, hi + GALLERY_COVER_PREFETCH_AHEAD)
    for (let index: number = first; index <= last; index += 1) {
      const url: string = galleries[index].thumbnailUrl
      if (url.length === 0 || this.tickets.has(url)) {
        continue
      }
      this.startTicket(url)
    }
    this.pruneSettledTickets()
  }

  cancelAll(): void {
    const entries: [string, GalleryCoverPrefetchTicket][] = []
    this.tickets.forEach((ticket: GalleryCoverPrefetchTicket, url: string): void => {
      entries.push([url, ticket])
    })
    entries.forEach((entry: [string, GalleryCoverPrefetchTicket]): void => {
      this.finishTicket(entry[0], entry[1], true)
    })
  }

  private startTicket(url: string): void {
    const ticket: GalleryCoverPrefetchTicket = new GalleryCoverPrefetchTicket(url)
    this.tickets.set(url, ticket)
    ticket.armGuard((): void => {
      this.finishTicket(url, ticket, true)
    })
    const callbacks: ImageKnifePreloadCallbacks = new ImageKnifePreloadCallbacks()
    callbacks.onStart = (): void => {
      ticket.markStarted()
    }
    callbacks.onSettled = (): void => {
      this.finishTicket(url, ticket, false)
    }
    ticket.request = ImagePipelineService.preloadCover(url, EH_IMAGE_PRIORITY_LOW, true, callbacks)
    if (ticket.request === null) {
      this.finishTicket(url, ticket, false)
    }
  }

  private pruneSettledTickets(): void {
    if (this.tickets.size <= GALLERY_COVER_PREFETCH_MAX_TICKETS) {
      return
    }
    const stale: string[] = []
    this.tickets.forEach((ticket: GalleryCoverPrefetchTicket, url: string): void => {
      if (ticket.isSettled()) {
        stale.push(url)
      }
    })
    stale.forEach((url: string): void => {
      this.tickets.delete(url)
    })
  }

  private finishTicket(
    url: string,
    ticket: GalleryCoverPrefetchTicket,
    cancelQueued: boolean,
  ): void {
    const current: GalleryCoverPrefetchTicket | undefined = this.tickets.get(url)
    if (current !== ticket) {
      return
    }
    this.tickets.delete(url)
    ticket.finish()
    if (cancelQueued && !ticket.started && ticket.request !== null) {
      ImagePipelineService.cancelCoverPreload(ticket.request)
    }
  }
}
