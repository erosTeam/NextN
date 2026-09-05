import { common } from '@kit.AbilityKit'
import { NhApiClient, NhGalleryDetail, ReaderImageCacheService } from 'shared'
import {
  ReaderCatalog, ReaderAssetProvider, ReaderUnitKey, ReaderUnit, ReaderPage,
  ReaderCancellation, ReaderAsset, ReaderAssetKind,
} from '@reader-kit/core'

export class NextNReaderLabAdapter implements ReaderCatalog, ReaderAssetProvider {
  cancellationMode: 'consumer-only' | 'transport' = 'consumer-only'
  private context: common.UIAbilityContext
  private details: Map<string, NhGalleryDetail> = new Map()

  constructor(context: common.UIAbilityContext) { this.context = context }

  async open(key: ReaderUnitKey, cancellation: ReaderCancellation): Promise<ReaderUnit> {
    cancellation.check()
    const id = Number(key.work)
    if (key.scope !== 'nh' || key.unit !== key.work || !Number.isSafeInteger(id) || id <= 0) {
      throw new Error('invalid_nh_unit')
    }
    const detail = await NhApiClient.detail(id)
    cancellation.check()
    this.details.set(key.unit, detail)
    return new ReaderUnit(key, detail.title, detail.pages.length)
  }

  async page(unit: ReaderUnit, index: number, cancellation: ReaderCancellation): Promise<ReaderPage> {
    cancellation.check()
    const detail = this.details.get(unit.key.unit)
    const source = detail?.pages[index]
    if (source === undefined || detail === undefined) throw new Error('missing_nh_page')
    const page = new ReaderPage(unit.key, `${detail.id}:${source.number}`, index)
    page.width = source.width
    page.height = source.height
    page.thumbnail.width = source.thumbnailWidth
    page.thumbnail.height = source.thumbnailHeight
    return page
  }

  adjacent(_unit: ReaderUnit, _direction: 'next' | 'previous'): ReaderUnitKey | null { return null }

  async load(page: ReaderPage, kind: ReaderAssetKind, cancellation: ReaderCancellation, forceReload: boolean): Promise<ReaderAsset> {
    cancellation.check()
    const detail = this.details.get(page.unit.unit)
    const source = detail?.pages[page.sourceIndex]
    if (detail === undefined || source === undefined) throw new Error('missing_nh_asset')
    if (kind === 'thumbnail') return new ReaderAsset(source.thumbnailUrl)
    const url = NhApiClient.imageUrl(detail.mediaId, page.sourceIndex, source.extension)
    const cacheKey = ReaderImageCacheService.cacheKey(detail.id, detail.mediaId, source.number, source.extension)
    const result = await ReaderImageCacheService.load(this.context, url, cacheKey, forceReload)
    // Core releases a late result; the cache file remains owned by the existing service.
    return new ReaderAsset(result.displayUri)
  }
}
