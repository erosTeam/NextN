import { common } from '@kit.AbilityKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { fileUri } from '@kit.CoreFileKit'
import { systemShare } from '@kit.ShareKit'
import { ReaderSystemSharePresentation, ReaderFileInformation } from '@reader-kit/ui'
import { NhApiClient, NhGalleryDetail, ReaderImageCacheService, ReaderPageCropService } from 'shared'
import {
  ReaderCatalog, ReaderAssetProvider, ReaderUnitKey, ReaderUnit, ReaderPage,
  ReaderCancellation, ReaderAsset, ReaderAssetKind, ReaderImageShareHost,
  ReaderImageShareTarget, ReaderImageSharePresentation,
  ReaderImageInformation, ReaderImageCropBounds, ReaderImageCropSource,
} from '@reader-kit/core'

class NextNReaderCropSource implements ReaderImageCropSource {
  private static sequence: number = 0
  private path: string
  private identity: string
  constructor(path: string) {
    this.path = path
    this.identity = `reader-lab-asset:${++NextNReaderCropSource.sequence}`
  }
  async read(): Promise<ReaderImageCropBounds> {
    const bounds = await ReaderPageCropService.detect(this.path, this.identity)
    return new ReaderImageCropBounds(bounds.left, bounds.top, bounds.right, bounds.bottom)
  }
}

export class NextNReaderLabAdapter implements ReaderCatalog, ReaderAssetProvider, ReaderImageShareHost {
  cancellationMode: 'consumer-only' | 'transport' = 'consumer-only'
  informationSupported: boolean = true
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

  async prepare(target: ReaderImageShareTarget, cancellation: ReaderCancellation): Promise<ReaderImageSharePresentation> {
    cancellation.check()
    const detail = this.details.get(target.unit.key.unit)
    const source = detail?.pages[target.sourceIndex]
    if (detail === undefined || source === undefined) throw new Error('missing_nh_share_page')
    const url = NhApiClient.imageUrl(detail.mediaId, target.sourceIndex, source.extension)
    const key = ReaderImageCacheService.cacheKey(detail.id, detail.mediaId, source.number, source.extension)
    const result = await ReaderImageCacheService.load(this.context, url, key, false)
    cancellation.check()
    const title = `${target.unit.title} ${target.sourceIndex + 1}`
    let record: systemShare.SharedRecord
    if (result.localPath.length > 0 && result.bytes > 0) {
      record = { utd: utd.UniformDataType.FILE, title, description: title,
        uri: fileUri.getUriFromPath(result.localPath) }
    } else {
      record = { utd: utd.UniformDataType.HYPERLINK, title, content: url }
    }
    return new ReaderSystemSharePresentation(this.context, new systemShare.SharedData(record), {
      selectionMode: systemShare.SelectionMode.SINGLE, previewMode: systemShare.SharePreviewMode.DEFAULT,
    })
  }

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
    const facts = new ReaderImageInformation()
    facts.bytes = result.bytes
    facts.variant = 'source'
    const asset = new ReaderAsset(result.displayUri, () => {}, new ReaderFileInformation(result.localPath, facts))
    if (result.localPath.length > 0) asset.crop = new NextNReaderCropSource(result.localPath)
    return asset
  }
}
