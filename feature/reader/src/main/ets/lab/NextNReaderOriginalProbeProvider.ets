import { ReaderAsset, ReaderAssetKind, ReaderAssetProvider, ReaderCancellation, ReaderPage } from '@reader-kit/core'
import { ReaderTrialOriginalProbe } from 'shared'

/** Delays delivery of a real original asset, never its thumbnail, URI contents or decoder callbacks. */
export class NextNReaderOriginalProbeProvider implements ReaderAssetProvider {
  cancellationMode: 'consumer-only' | 'transport'
  informationSupported: boolean
  private provider: ReaderAssetProvider
  private epoch: number
  private galleryId: string
  private pageIndex: number
  private timeoutMs: number
  private claimed: boolean = false

  constructor(provider: ReaderAssetProvider, epoch: number, galleryId: string, pageIndex: number,
    timeoutMs: number = 30000) {
    this.provider = provider; this.epoch = epoch; this.galleryId = galleryId; this.pageIndex = pageIndex
    this.timeoutMs = timeoutMs
    this.cancellationMode = provider.cancellationMode
    this.informationSupported = provider.informationSupported === true
  }

  close(): void { ReaderTrialOriginalProbe.cancel(this.epoch) }

  async load(page: ReaderPage, kind: ReaderAssetKind, cancellation: ReaderCancellation,
    forceReload: boolean): Promise<ReaderAsset> {
    if (this.claimed || kind !== 'original' || page.unit.unit !== this.galleryId || page.sourceIndex !== this.pageIndex) {
      return this.provider.load(page, kind, cancellation, forceReload)
    }
    this.claimed = true
    const requestId = ReaderTrialOriginalProbe.beginRequest(this.epoch, this.galleryId, this.pageIndex)
    if (requestId === 0) return this.provider.load(page, kind, cancellation, forceReload)
    let owned: ReaderAsset | null = null
    try {
      cancellation.check()
      owned = await this.provider.load(page, kind, cancellation, forceReload)
      if (cancellation.isCancelled()) ReaderTrialOriginalProbe.cancel(this.epoch)
      if (!ReaderTrialOriginalProbe.isState(this.epoch, requestId, 'loading')) throw new Error('reader_original_probe_cancelled')
      const released = await this.waitForRelease(requestId, cancellation)
      if (cancellation.isCancelled()) ReaderTrialOriginalProbe.cancel(this.epoch)
      if (!released || !ReaderTrialOriginalProbe.delivered(this.epoch, requestId)) {
        throw new Error('reader_original_probe_not_delivered')
      }
      const asset = owned
      owned = null // Ownership passes to ReaderSession; host exit must not release it again.
      return asset
    } catch (error) {
      if (owned !== null) {
        owned.release()
        ReaderTrialOriginalProbe.releasedAsset(this.epoch, requestId)
      }
      if (cancellation.isCancelled()) ReaderTrialOriginalProbe.cancel(this.epoch)
      ReaderTrialOriginalProbe.fail(this.epoch, requestId, 'provider')
      throw error as Error
    }
  }

  private waitForRelease(requestId: number, cancellation: ReaderCancellation): Promise<boolean> {
    return new Promise<boolean>((resolve): void => {
      let timeout: number = 0
      let cancellationPoll: number = 0
      const settle = (released: boolean): void => {
        if (timeout !== 0) clearTimeout(timeout)
        if (cancellationPoll !== 0) clearInterval(cancellationPoll)
        resolve(released)
      }
      if (!ReaderTrialOriginalProbe.hold(this.epoch, requestId, settle)) { settle(false); return }
      timeout = setTimeout((): void => {
        ReaderTrialOriginalProbe.fail(this.epoch, requestId, 'timeout')
      }, this.timeoutMs)
      cancellationPoll = setInterval((): void => {
        if (cancellation.isCancelled()) ReaderTrialOriginalProbe.cancel(this.epoch)
      }, 50)
    })
  }
}
