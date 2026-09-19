import { AppStorageV2 } from '@kit.ArkUI'
import { NhGalleryDetail, NhGalleryPage, NhTag } from '../model/NhGallery'
import { ReaderRouteParams } from '../model/ReaderRouteParams'
import { NextNReaderBackend } from './NextNReaderBackendSelectionState'
import { connectReaderThumbnailTransition } from './ReaderThumbnailTransitionState'

/**
 * Owns Reader's full-window navigation stack independently of the root HDS
 * navigation. The root tab/detail stack stays mounted beneath Reader so close
 * restores the exact originating page rather than reconstructing it.
 */
@ObservedV2
export class ReaderOverlayNavigationState {
  @Trace visible: boolean = false
  @Trace stack: NavPathStack = new NavPathStack()
  /**
   * Live Reader backend trace. Both backends mount through the overlay's HDS
   * destination, so this no longer selects a mount host; the shell uses it only
   * to delegate system Back to the registered shared-Reader controller.
   */
  @Trace activeReader: ReaderRouteParams | null = null
  /** Admission epoch observed by the host before it presents the pending route. */
  @Trace mountEpoch: number = 0
  // Detail observes the start of the exit transition so it can reveal the
  // already-persisted final progress without reacting to live Reader writes.
  @Trace closing: boolean = false
  private pendingReader: ReaderRouteParams | null = null
  private pendingReaderAnimated: boolean = true
  private nextRouteEpoch: number = 0
  // A Gallery stages this only immediately before its own Reader intent.
  // `open` either attaches it to that exact next route or discards it.
  private stagedDetailSeed: NhGalleryDetail | null = null
  private stagedDetailGalleryId: number = 0
  private activeDetailSeed: NhGalleryDetail | null = null
  private activeDetailGalleryId: number = 0
  private activeDetailRouteEpoch: number = 0

  /**
   * The Gallery page has already checked the response identity before it
   * exposes Read. Copy that public DTO so a retained Gallery refresh cannot
   * mutate the short-lived Reader seed after navigation begins.
   */
  stageDetailSeed(detail: NhGalleryDetail): void {
    if (!this.isUsableDetailSeed(detail)) {
      this.clearStagedDetailSeed()
      return
    }
    this.stagedDetailSeed = this.copyDetail(detail)
    this.stagedDetailGalleryId = detail.id
  }

  /**
   * Gallery dispatch is synchronous in the entry shell. If a different host
   * does not open the overlay during that dispatch, remove its staged value
   * instead of leaving it available to a later, unrelated Reader intent.
   */
  discardStagedDetailSeed(galleryId: number): void {
    if (galleryId > 0 && this.stagedDetailGalleryId === galleryId) {
      this.clearStagedDetailSeed()
    }
  }

  /**
   * A Reader may use the seed only for the precise overlay route that was
   * opened from Gallery. Taking it clears the cache before Reader history or
   * image work begins, so a retained/old Reader can never reuse it.
   */
  consumeDetailSeed(galleryId: number, routeEpoch: number): NhGalleryDetail | null {
    if (galleryId <= 0 || routeEpoch <= 0 || this.activeDetailSeed === null ||
      this.activeDetailGalleryId !== galleryId || this.activeDetailSeed.id !== galleryId ||
      this.activeDetailRouteEpoch !== routeEpoch) {
      return null
    }
    const detail: NhGalleryDetail = this.activeDetailSeed
    this.clearActiveDetailSeed()
    return detail
  }

  open(params: ReaderRouteParams, animated: boolean = true): number {
    const routeEpoch: number = this.nextRouteEpoch + 1
    this.nextRouteEpoch = routeEpoch
    const routeParams = new ReaderRouteParams(params.galleryId, params.initialPageIndex, routeEpoch, params.backend)
    this.attachStagedDetailSeed(routeParams)
    this.activeReader = routeParams.backend === NextNReaderBackend.SHARED ? routeParams : null
    // A Reader session owns one private stack. The accepted legacy path already
    // admits with a fresh stack today, so the shared backend joins it unchanged.
    // Open question, not a settled fact: `docs/qa/
    // shared-reader-production-thumbnail-singletons-nextn-20260913.md` records
    // two distinct shared repeated-entry failures. Runs 22-final/23-final lost
    // the second Reader even with new stacks and unique destination names;
    // runs 24-final/25-final were the separate `hostClosing` race observed only
    // after the direct host existed. It is NOT proven that the fresh-stack shape
    // is safe for shared merely because legacy works; shared repeated entry must
    // be re-verified on device before this is treated as closed.
    this.stack = new NavPathStack()
    this.stack.pushPathByName('ReaderOverlayBackdrop', null, false)
    // Both backends are admitted by the same checked HDS push. The shared
    // Reader therefore keeps the host's own destination transition instead of
    // appearing in a single hard-cut frame, and its readerDestination branch is
    // no longer dead code.
    this.pendingReader = routeParams
    this.pendingReaderAnimated = animated
    this.closing = false
    this.mountEpoch = routeEpoch
    this.visible = true
    return routeEpoch
  }

  presentPendingReader(expectedRouteEpoch: number = 0): boolean {
    const params: ReaderRouteParams | null = this.pendingReader
    if (!this.visible || this.closing || params === null ||
      (expectedRouteEpoch > 0 && params.routeEpoch !== expectedRouteEpoch)) {
      return false
    }
    this.pendingReader = null
    const animated: boolean = this.pendingReaderAnimated
    this.pendingReaderAnimated = true
    // Legacy Reader must retain the accepted v1.0.4 synchronous admission
    // path. A shared-host layout waiter must never leave a transparent modal
    // backdrop above the app before the legacy destination is mounted.
    this.stack.pushPathByName(`Reader:${params.routeEpoch}`, params, animated)
    return true
  }

  close(animated: boolean = true): void {
    if (!this.visible || this.closing) {
      return
    }
    this.pendingReader = null
    this.clearStagedDetailSeed()
    this.clearActiveDetailSeed()
    // Both backends pop the same destination so the shared Reader also gets the
    // host's close transition; finishClose runs from the destination's own
    // onDisAppear once the pop has completed.
    if (this.stack.getAllPathName().length === 0) {
      this.finishClose()
      return
    }
    this.closing = true
    this.stack.pop(animated)
  }

  finishClose(): void {
    if (!this.closing) {
      return
    }
    this.closing = false
    this.visible = false
    this.activeReader = null
    this.clearStagedDetailSeed()
    this.clearActiveDetailSeed()
    this.pendingReaderAnimated = true
    connectReaderThumbnailTransition().reset()
  }

  reset(): void {
    this.pendingReader = null
    this.pendingReaderAnimated = true
    this.closing = false
    this.visible = false
    this.activeReader = null
    this.clearStagedDetailSeed()
    this.clearActiveDetailSeed()
    this.stack.clear(false)
    connectReaderThumbnailTransition().reset()
  }

  private attachStagedDetailSeed(params: ReaderRouteParams): void {
    this.clearActiveDetailSeed()
    const stagedDetail: NhGalleryDetail | null = this.stagedDetailSeed
    const stagedGalleryId: number = this.stagedDetailGalleryId
    this.clearStagedDetailSeed()
    if (stagedDetail === null || stagedGalleryId !== params.galleryId ||
      !this.isUsableDetailSeed(stagedDetail) || params.routeEpoch <= 0) {
      return
    }
    this.activeDetailSeed = stagedDetail
    this.activeDetailGalleryId = stagedGalleryId
    this.activeDetailRouteEpoch = params.routeEpoch
  }

  private clearStagedDetailSeed(): void {
    this.stagedDetailSeed = null
    this.stagedDetailGalleryId = 0
  }

  private clearActiveDetailSeed(): void {
    this.activeDetailSeed = null
    this.activeDetailGalleryId = 0
    this.activeDetailRouteEpoch = 0
  }

  private isUsableDetailSeed(detail: NhGalleryDetail): boolean {
    return detail.id > 0 && detail.pages.length > 0
  }

  private copyDetail(detail: NhGalleryDetail): NhGalleryDetail {
    const copy: NhGalleryDetail = new NhGalleryDetail()
    copy.id = detail.id
    copy.mediaId = detail.mediaId
    copy.title = detail.title
    copy.japaneseTitle = detail.japaneseTitle
    copy.prettyTitle = detail.prettyTitle
    copy.coverUrl = detail.coverUrl
    copy.thumbnailUrl = detail.thumbnailUrl
    copy.pageCount = detail.pageCount
    copy.favoriteCount = detail.favoriteCount
    copy.scanlator = detail.scanlator
    copy.uploadDate = detail.uploadDate
    copy.tags = detail.tags.map((tag: NhTag): NhTag => {
      const tagCopy: NhTag = new NhTag()
      tagCopy.id = tag.id
      tagCopy.type = tag.type
      tagCopy.name = tag.name
      tagCopy.count = tag.count
      return tagCopy
    })
    copy.pages = detail.pages.map((page: NhGalleryPage): NhGalleryPage => {
      const pageCopy: NhGalleryPage = new NhGalleryPage()
      pageCopy.number = page.number
      pageCopy.extension = page.extension
      pageCopy.width = page.width
      pageCopy.height = page.height
      pageCopy.thumbnailUrl = page.thumbnailUrl
      pageCopy.thumbnailWidth = page.thumbnailWidth
      pageCopy.thumbnailHeight = page.thumbnailHeight
      return pageCopy
    })
    return copy
  }
}

const READER_OVERLAY_NAVIGATION_KEY: string = 'nextn_readerOverlayNavigation'

export function connectReaderOverlayNavigation(): ReaderOverlayNavigationState {
  return AppStorageV2.connect(
    ReaderOverlayNavigationState,
    READER_OVERLAY_NAVIGATION_KEY,
    (): ReaderOverlayNavigationState => new ReaderOverlayNavigationState(),
  )!
}
