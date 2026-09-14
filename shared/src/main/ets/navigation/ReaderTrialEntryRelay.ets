/** Click-time thumbnail facts for the optional Debug reader host, without reader-kit types. */
export class ReaderTrialEntrySource {
  galleryId: number
  pageIndex: number
  sourceComponentId: string
  snapshotComponentId: string
  origin: 'detail' | 'grid'
  thumbnailUrl: string
  thumbnailResourceId: string
  /** Zero means unknown. Never substitute full-page or unverified DTO dimensions. */
  decodedWidth: number = 0
  decodedHeight: number = 0
  objectFit: 'cover' | 'contain'
  originalRelation: 'unknown' = 'unknown'
  /** Live tile identity/mount check. Geometry is still measured by the host. */
  isCurrent: () => boolean = (): boolean => false

  constructor(galleryId: number, pageIndex: number, sourceComponentId: string,
    snapshotComponentId: string, origin: 'detail' | 'grid', thumbnailUrl: string) {
    this.galleryId = galleryId
    this.pageIndex = pageIndex
    this.sourceComponentId = sourceComponentId
    this.snapshotComponentId = snapshotComponentId
    this.origin = origin
    this.thumbnailUrl = thumbnailUrl
    this.thumbnailResourceId = `${galleryId}:${pageIndex}:${thumbnailUrl}`
    this.objectFit = origin === 'detail' ? 'cover' : 'contain'
  }

  sourceScope(): string {
    const suffix = `-page-${this.pageIndex}`
    return this.sourceComponentId.endsWith(suffix)
      ? this.sourceComponentId.substring(0, this.sourceComponentId.length - suffix.length)
      : ''
  }
}

/**
 * Installed only by the Debug host. Normal entries have no handler and retain their old route.
 * A true return claims the entry synchronously; the host then owns async capture or trial fallback.
 * False leaves the production entry available. A successful claim consumes only its own token.
 */
export class ReaderTrialEntryRelay {
  private static serial: number = 0
  private static token: number = 0
  private static workId: string = ''
  private static handler: ((source: ReaderTrialEntrySource) => boolean) | null = null
  private static pendingToken: number = 0
  private static pendingGalleryId: number = 0

  static holdPending(galleryId: number): number {
    if (!Number.isSafeInteger(galleryId) || galleryId <= 0) return 0
    const token = ++ReaderTrialEntryRelay.serial
    ReaderTrialEntryRelay.pendingToken = token
    ReaderTrialEntryRelay.pendingGalleryId = galleryId
    return token
  }

  static releasePending(token: number): void {
    if (token !== ReaderTrialEntryRelay.pendingToken) return
    ReaderTrialEntryRelay.pendingToken = 0
    ReaderTrialEntryRelay.pendingGalleryId = 0
  }

  static install(workId: string, handler: (source: ReaderTrialEntrySource) => boolean): number {
    const token: number = ++ReaderTrialEntryRelay.serial
    ReaderTrialEntryRelay.token = token
    ReaderTrialEntryRelay.workId = workId
    ReaderTrialEntryRelay.handler = handler
    return token
  }

  static clear(token: number): void {
    if (token !== ReaderTrialEntryRelay.token) return
    ReaderTrialEntryRelay.token = 0
    ReaderTrialEntryRelay.workId = ''
    ReaderTrialEntryRelay.handler = null
  }

  static tryOpen(source: ReaderTrialEntrySource): boolean {
    // This guard survives consumption of the one-shot registration, including the same-frame second click.
    if (ReaderTrialEntryRelay.pendingToken !== 0 &&
      ReaderTrialEntryRelay.pendingGalleryId === source.galleryId) return true
    const handler = ReaderTrialEntryRelay.handler
    if (handler === null || source.galleryId <= 0 || !Number.isSafeInteger(source.galleryId) ||
      source.pageIndex < 0 || !Number.isSafeInteger(source.pageIndex) ||
      ReaderTrialEntryRelay.workId !== source.galleryId.toString()) return false
    const token: number = ReaderTrialEntryRelay.token
    if (!handler(source)) return false
    ReaderTrialEntryRelay.clear(token)
    return true
  }
}

/** In-memory facts written only by the host's explicit Debug entry probe; never by the relay itself. */
export class ReaderTrialEntryProbe {
  epoch: number = 0
  accepted: boolean = false
  delayedPreview: boolean = false
  discarded: boolean = false
  navigationChanged: boolean = false
  handoff: boolean = false
  private static latest: ReaderTrialEntryProbe = new ReaderTrialEntryProbe()

  static reset(): void {
    ReaderTrialEntryProbe.latest = new ReaderTrialEntryProbe()
  }

  /** A detached snapshot: readers cannot mutate the host's observed facts. */
  static read(): ReaderTrialEntryProbe {
    const current = ReaderTrialEntryProbe.latest
    const snapshot = new ReaderTrialEntryProbe()
    snapshot.epoch = current.epoch
    snapshot.accepted = current.accepted
    snapshot.delayedPreview = current.delayedPreview
    snapshot.discarded = current.discarded
    snapshot.navigationChanged = current.navigationChanged
    snapshot.handoff = current.handoff
    return snapshot
  }

  static recordAccepted(epoch: number): void {
    ReaderTrialEntryProbe.reset()
    ReaderTrialEntryProbe.latest.epoch = epoch
    ReaderTrialEntryProbe.latest.accepted = true
  }

  static recordDelayedPreview(epoch: number, hasPreview: boolean): void {
    if (ReaderTrialEntryProbe.latest.epoch !== epoch || !ReaderTrialEntryProbe.latest.accepted) return
    ReaderTrialEntryProbe.latest.delayedPreview = hasPreview
  }

  static recordDiscarded(epoch: number, navigationChanged: boolean): void {
    if (ReaderTrialEntryProbe.latest.epoch !== epoch || !ReaderTrialEntryProbe.latest.accepted) return
    ReaderTrialEntryProbe.latest.discarded = true
    ReaderTrialEntryProbe.latest.navigationChanged = navigationChanged
  }

  static recordHandoff(epoch: number): void {
    if (ReaderTrialEntryProbe.latest.epoch !== epoch || !ReaderTrialEntryProbe.latest.accepted) return
    ReaderTrialEntryProbe.latest.handoff = true
  }
}
