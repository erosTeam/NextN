import { ReaderAsset, ReaderAssetKind, ReaderAssetProvider, ReaderCancellation, ReaderPage } from '@reader-kit/core'

export class NextNReaderProductionFailureFacts {
  galleryId: string = ''
  pageIndex: number = -1
  armed: boolean = false
  consumed: boolean = false
  warmedRealAsset: boolean = false
  injectedDecodeFailure: boolean = false
  retryObserved: boolean = false
  retryForceReload: boolean = false
}

/**
 * Process-local Debug probe for the production NextN adapter boundary.
 *
 * It is deliberately host-owned: reader-kit sees an ordinary failed asset and
 * emits its generic Retry intent, while this probe records whether that Retry
 * returned to the real NextN provider with forceReload enabled.
 */
export class NextNReaderProductionFailureProbe {
  private static facts: NextNReaderProductionFailureFacts = new NextNReaderProductionFailureFacts()

  static arm(galleryId: string, pageIndex: number): void {
    const facts = new NextNReaderProductionFailureFacts()
    facts.galleryId = galleryId
    facts.pageIndex = Number.isSafeInteger(pageIndex) && pageIndex >= 0 ? pageIndex : -1
    facts.armed = galleryId.length > 0 && facts.pageIndex >= 0
    NextNReaderProductionFailureProbe.facts = facts
  }

  static consume(galleryId: string): number {
    const facts = NextNReaderProductionFailureProbe.facts
    if (!facts.armed || facts.consumed || facts.galleryId !== galleryId) return -1
    facts.consumed = true
    return facts.pageIndex
  }

  static markWarm(pageIndex: number): void {
    const facts = NextNReaderProductionFailureProbe.facts
    if (!facts.consumed || facts.pageIndex !== pageIndex) return
    facts.warmedRealAsset = true
    facts.injectedDecodeFailure = true
  }

  static markRetry(pageIndex: number, forceReload: boolean): void {
    const facts = NextNReaderProductionFailureProbe.facts
    if (!facts.consumed || facts.pageIndex !== pageIndex) return
    facts.retryObserved = true
    facts.retryForceReload = forceReload
  }

  static read(): NextNReaderProductionFailureFacts {
    const current = NextNReaderProductionFailureProbe.facts
    const copy = new NextNReaderProductionFailureFacts()
    copy.galleryId = current.galleryId
    copy.pageIndex = current.pageIndex
    copy.armed = current.armed
    copy.consumed = current.consumed
    copy.warmedRealAsset = current.warmedRealAsset
    copy.injectedDecodeFailure = current.injectedDecodeFailure
    copy.retryObserved = current.retryObserved
    copy.retryForceReload = current.retryForceReload
    return copy
  }

  static reset(): void {
    NextNReaderProductionFailureProbe.facts = new NextNReaderProductionFailureFacts()
  }
}

/** Warms one real production asset, then returns one missing decode URI. */
export class NextNReaderProductionFailureProbeProvider implements ReaderAssetProvider {
  cancellationMode: 'consumer-only' | 'transport'
  informationSupported: boolean
  private provider: ReaderAssetProvider
  private galleryId: string
  private pageIndex: number
  private injected: boolean = false

  constructor(provider: ReaderAssetProvider, galleryId: string, pageIndex: number) {
    this.provider = provider
    this.galleryId = galleryId
    this.pageIndex = pageIndex
    this.cancellationMode = provider.cancellationMode
    this.informationSupported = provider.informationSupported === true
  }

  async load(page: ReaderPage, kind: ReaderAssetKind, cancellation: ReaderCancellation,
    forceReload: boolean): Promise<ReaderAsset> {
    if (kind !== 'original' || page.unit.unit !== this.galleryId || page.sourceIndex !== this.pageIndex) {
      return this.provider.load(page, kind, cancellation, forceReload)
    }
    if (this.injected) {
      NextNReaderProductionFailureProbe.markRetry(page.sourceIndex, forceReload)
      console.info(`[NextNReaderProductionFailureProbe] retry source=${page.sourceIndex} force=${forceReload}`)
      return this.provider.load(page, kind, cancellation, forceReload)
    }
    this.injected = true
    cancellation.check()
    const realAsset: ReaderAsset = await this.provider.load(page, kind, cancellation, forceReload)
    if (cancellation.isCancelled()) {
      realAsset.release()
      cancellation.check()
    }
    realAsset.release()
    NextNReaderProductionFailureProbe.markWarm(page.sourceIndex)
    console.info(`[NextNReaderProductionFailureProbe] warm_then_decode_fail source=${page.sourceIndex}`)
    return new ReaderAsset('file:///data/storage/el2/base/cache/rkit-production-probe-missing-original')
  }
}
