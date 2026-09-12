import { common } from '@kit.AbilityKit'
import { ReaderCancellation } from '@reader-kit/core'
import { DownloadQueueService, NhApiClient, NhGalleryDetail, NhGalleryPage } from 'shared'

/**
 * NextN-owned page-material boundary.
 *
 * The shared Reader consumes only ReaderCatalog/ReaderAssetProvider. Selection
 * between a completed download, a route-scoped Detail seed and the NH network
 * remains a host concern behind this interface.
 */
export interface NextNReaderDataSource {
  openDetail(galleryId: number, cancellation: ReaderCancellation): Promise<NhGalleryDetail>
  localPageUri(detail: NhGalleryDetail, pageIndex: number): string
}

/** Debug/Lab behavior: no production route seed and no download ownership. */
export class NextNNetworkReaderDataSource implements NextNReaderDataSource {
  async openDetail(galleryId: number, cancellation: ReaderCancellation): Promise<NhGalleryDetail> {
    cancellation.check()
    const detail: NhGalleryDetail = await NhApiClient.detail(galleryId)
    cancellation.check()
    return detail
  }

  localPageUri(_detail: NhGalleryDetail, _pageIndex: number): string { return '' }
}

/**
 * Production selection order matches the legacy Reader without moving any NH
 * storage or network concern into reader-kit.
 */
export class NextNProductionReaderDataSource implements NextNReaderDataSource {
  private context: common.UIAbilityContext
  private detailSeed: NhGalleryDetail | null

  constructor(context: common.UIAbilityContext, detailSeed: NhGalleryDetail | null) {
    this.context = context
    this.detailSeed = detailSeed === null ? null : detailSeed.copy()
  }

  async openDetail(galleryId: number, cancellation: ReaderCancellation): Promise<NhGalleryDetail> {
    cancellation.check()
    const downloaded: NhGalleryDetail | null = await DownloadQueueService.localReaderDetail(this.context, galleryId)
    cancellation.check()
    if (downloaded !== null && downloaded.id === galleryId && downloaded.pages.length > 0) {
      this.detailSeed = null
      console.info('[NextNReaderDataSource] detail_source=download')
      return downloaded
    }
    const seeded: NhGalleryDetail | null = this.takeSeed(galleryId)
    if (seeded !== null) {
      console.info('[NextNReaderDataSource] detail_source=route_seed')
      return seeded
    }
    console.info('[NextNReaderDataSource] detail_source=network')
    const detail: NhGalleryDetail = await NhApiClient.detail(galleryId)
    cancellation.check()
    return detail
  }

  localPageUri(detail: NhGalleryDetail, pageIndex: number): string {
    if (detail.id <= 0 || pageIndex < 0 || pageIndex >= detail.pages.length) return ''
    const page: NhGalleryPage = detail.pages[pageIndex]
    return DownloadQueueService.localPageUri(this.context, detail.id, pageIndex, page.extension)
  }

  private takeSeed(galleryId: number): NhGalleryDetail | null {
    const seed: NhGalleryDetail | null = this.detailSeed
    this.detailSeed = null
    if (seed === null || seed.id !== galleryId || seed.pages.length === 0) return null
    return seed.copy()
  }
}
