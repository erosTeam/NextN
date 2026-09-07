/** Debug-only observation values. No reader-kit objects, URLs or durable reader state. */
export class ReaderTrialOriginalFacts {
  entryId: number = 0
  entryPhase: string = 'none'
  layoutReady: boolean = false
  decodedReady: boolean = false
  sessionPhase: string = 'idle'
  anchor: number = -1
  navigationRevision: number = 0
  selectionId: number = 0
  slotId: number = 0
  assetRequestId: number = 0
  assetPhase: string = 'idle'
  originalWidth: number = 0
  originalHeight: number = 0
  hostActive: boolean = false

  copy(): ReaderTrialOriginalFacts {
    const value = new ReaderTrialOriginalFacts()
    value.entryId = this.entryId; value.entryPhase = this.entryPhase
    value.layoutReady = this.layoutReady; value.decodedReady = this.decodedReady
    value.sessionPhase = this.sessionPhase; value.anchor = this.anchor
    value.navigationRevision = this.navigationRevision; value.selectionId = this.selectionId
    value.slotId = this.slotId; value.assetRequestId = this.assetRequestId
    value.assetPhase = this.assetPhase; value.hostActive = this.hostActive
    value.originalWidth = this.originalWidth; value.originalHeight = this.originalHeight
    return value
  }
}

export type ReaderTrialOriginalState = 'idle' | 'armed' | 'consumed' | 'loading' | 'held' |
  'release-requested' | 'delivered' | 'cancelled' | 'failed'

export class ReaderTrialOriginalSnapshot {
  epoch: number = 0
  galleryId: string = ''
  pageIndex: number = -1
  requestId: number = 0
  state: ReaderTrialOriginalState = 'idle'
  failureReason: '' | 'timeout' | 'provider' = ''
  assetReleased: boolean = false
  unknownMetrics: boolean = false
  reader: ReaderTrialOriginalFacts = new ReaderTrialOriginalFacts()

  copy(): ReaderTrialOriginalSnapshot {
    const value = new ReaderTrialOriginalSnapshot()
    value.epoch = this.epoch; value.galleryId = this.galleryId; value.pageIndex = this.pageIndex
    value.requestId = this.requestId; value.state = this.state; value.failureReason = this.failureReason
    value.assetReleased = this.assetReleased; value.reader = this.reader.copy()
    value.unknownMetrics = this.unknownMetrics
    return value
  }
}

/** One matching Debug Want, one original request. Only the owning provider can deliver an asset. */
export class ReaderTrialOriginalProbe {
  private static serial: number = 0
  private static requestSerial: number = 0
  private static current: ReaderTrialOriginalSnapshot = new ReaderTrialOriginalSnapshot()
  private static control: ((release: boolean) => void) | null = null
  private static facts: (() => ReaderTrialOriginalFacts) | null = null

  static arm(galleryId: string, pageIndex: number, unknownMetrics: boolean = false): number {
    ReaderTrialOriginalProbe.cancel(ReaderTrialOriginalProbe.current.epoch)
    ReaderTrialOriginalProbe.facts = null
    const value = new ReaderTrialOriginalSnapshot()
    value.epoch = ++ReaderTrialOriginalProbe.serial
    value.galleryId = galleryId; value.pageIndex = pageIndex; value.state = 'armed'
    value.unknownMetrics = unknownMetrics
    ReaderTrialOriginalProbe.current = value
    return value.epoch
  }

  static consume(galleryId: string, pageIndex: number): number {
    const value = ReaderTrialOriginalProbe.current
    if (value.state !== 'armed' || value.galleryId !== galleryId || value.pageIndex !== pageIndex) return 0
    value.state = 'consumed'
    return value.epoch
  }

  static bindFacts(epoch: number, facts: () => ReaderTrialOriginalFacts): void {
    if (epoch === ReaderTrialOriginalProbe.current.epoch) ReaderTrialOriginalProbe.facts = facts
  }

  static detachFacts(epoch: number): void {
    if (epoch !== ReaderTrialOriginalProbe.current.epoch) return
    ReaderTrialOriginalProbe.refreshFacts()
    ReaderTrialOriginalProbe.facts = null
  }

  private static refreshFacts(): void {
    const facts = ReaderTrialOriginalProbe.facts
    if (facts !== null) ReaderTrialOriginalProbe.current.reader = facts().copy()
  }

  static read(): ReaderTrialOriginalSnapshot {
    ReaderTrialOriginalProbe.refreshFacts()
    return ReaderTrialOriginalProbe.current.copy()
  }

  static beginRequest(epoch: number, galleryId: string, pageIndex: number): number {
    const value = ReaderTrialOriginalProbe.current
    if (value.epoch !== epoch || value.state !== 'consumed' ||
      value.galleryId !== galleryId || value.pageIndex !== pageIndex) return 0
    value.requestId = ++ReaderTrialOriginalProbe.requestSerial
    value.state = 'loading'
    return value.requestId
  }

  static isState(epoch: number, requestId: number, state: ReaderTrialOriginalState): boolean {
    const value = ReaderTrialOriginalProbe.current
    return value.epoch === epoch && value.requestId === requestId && value.state === state
  }

  static hold(epoch: number, requestId: number, control: (release: boolean) => void): boolean {
    if (!ReaderTrialOriginalProbe.isState(epoch, requestId, 'loading')) return false
    ReaderTrialOriginalProbe.control = control
    ReaderTrialOriginalProbe.current.state = 'held'
    return true
  }

  static release(epoch: number, requestId: number): boolean {
    if (!ReaderTrialOriginalProbe.isState(epoch, requestId, 'held')) return false
    ReaderTrialOriginalProbe.current.state = 'release-requested'
    ReaderTrialOriginalProbe.resolve(true)
    return true
  }

  static delivered(epoch: number, requestId: number): boolean {
    if (!ReaderTrialOriginalProbe.isState(epoch, requestId, 'release-requested')) return false
    ReaderTrialOriginalProbe.current.state = 'delivered'
    return true
  }

  static cancel(epoch: number): void {
    const value = ReaderTrialOriginalProbe.current
    if (epoch !== value.epoch || value.state === 'idle' || value.state === 'delivered' ||
      value.state === 'cancelled' || value.state === 'failed') return
    value.state = 'cancelled'
    ReaderTrialOriginalProbe.resolve(false)
  }

  static fail(epoch: number, requestId: number, reason: 'timeout' | 'provider'): void {
    const value = ReaderTrialOriginalProbe.current
    if (value.epoch !== epoch || value.requestId !== requestId || value.state === 'delivered' ||
      value.state === 'cancelled' || value.state === 'failed') return
    value.state = 'failed'; value.failureReason = reason
    ReaderTrialOriginalProbe.resolve(false)
  }

  static releasedAsset(epoch: number, requestId: number): void {
    const value = ReaderTrialOriginalProbe.current
    if (value.epoch === epoch && value.requestId === requestId && value.state !== 'delivered') value.assetReleased = true
  }

  private static resolve(release: boolean): void {
    const control = ReaderTrialOriginalProbe.control
    ReaderTrialOriginalProbe.control = null
    control?.(release)
  }
}
