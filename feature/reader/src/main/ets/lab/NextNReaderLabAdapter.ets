import { common } from '@kit.AbilityKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { systemShare } from '@kit.ShareKit'
import { ReaderSystemSharePresentation, ReaderFileInformation } from '@reader-kit/ui'
import {
  NhApiClient, NhGalleryDetail, ReaderImageCacheLease, ReaderImageCacheService, ReaderPageCropService,
} from 'shared'
import {
  ReaderCatalog, ReaderAssetProvider, ReaderPreloadHost, ReaderUnitKey, ReaderUnit, ReaderPage,
  ReaderCancellation, ReaderAsset, ReaderAssetKind, ReaderImageShareHost,
  ReaderImageShareTarget, ReaderImageSharePresentation,
  ReaderImageInformation, ReaderImageCropBounds, ReaderImageCropSource,
} from '@reader-kit/core'
import { NextNReaderProgressDetailProvider } from './NextNReaderProgressPersistence'
import { NextNNetworkReaderDataSource, NextNReaderDataSource } from './NextNReaderDataSource'

const LOCAL_FIXTURE_WORK: string = '__rkit_local_fixture__'
const LOCAL_FIXTURE_PAGE_COUNT: number = 3
const LOCAL_FIXTURE_WIDTH: number = 1024
const LOCAL_FIXTURE_HEIGHT: number = 1536

function readerShareImageUtd(extension: string): string {
  const normalized: string = extension.trim().toLowerCase()
  if (normalized === 'jpg' || normalized === 'jpeg') return utd.UniformDataType.JPEG
  if (normalized === 'png') return utd.UniformDataType.PNG
  if (normalized === 'gif') return utd.UniformDataType.GIF
  if (normalized === 'bmp') return utd.UniformDataType.BMP
  return utd.UniformDataType.IMAGE
}

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

export class NextNReaderLabAdapter implements ReaderCatalog, ReaderAssetProvider, ReaderPreloadHost, ReaderImageShareHost,
  NextNReaderProgressDetailProvider {
  cancellationMode: 'consumer-only' | 'transport' = 'consumer-only'
  informationSupported: boolean = true
  private context: common.UIAbilityContext
  private details: Map<string, NhGalleryDetail> = new Map()
  private source: NextNReaderDataSource

  constructor(context: common.UIAbilityContext, source?: NextNReaderDataSource) {
    this.context = context
    this.source = source ?? new NextNNetworkReaderDataSource()
  }

  /** Current unit metadata for the optional host progress adapter only. */
  progressDetail(work: string): NhGalleryDetail | null {
    return this.details.get(work) ?? null
  }

  async open(key: ReaderUnitKey, cancellation: ReaderCancellation): Promise<ReaderUnit> {
    cancellation.check()
    if (key.scope === 'nh' && key.unit === key.work && key.work === LOCAL_FIXTURE_WORK) {
      console.info('[NextNReaderLabFixture] open')
      return new ReaderUnit(key, 'Reader local fixture', LOCAL_FIXTURE_PAGE_COUNT)
    }
    const id = Number(key.work)
    if (key.scope !== 'nh' || key.unit !== key.work || !Number.isSafeInteger(id) || id <= 0) {
      throw new Error('invalid_nh_unit')
    }
    const detail = await this.source.openDetail(id, cancellation)
    cancellation.check()
    if (detail.id !== id || detail.pages.length === 0) throw new Error('invalid_nh_detail')
    this.details.set(key.unit, detail)
    return new ReaderUnit(key, detail.title, detail.pages.length)
  }

  async page(unit: ReaderUnit, index: number, cancellation: ReaderCancellation): Promise<ReaderPage> {
    cancellation.check()
    if (unit.key.work === LOCAL_FIXTURE_WORK) {
      console.info(`[NextNReaderLabFixture] page source=${index}`)
      if (index < 0 || index >= LOCAL_FIXTURE_PAGE_COUNT) throw new Error('missing_reader_fixture_page')
      const fixture = new ReaderPage(unit.key, `fixture:${index}`, index)
      fixture.width = LOCAL_FIXTURE_WIDTH
      fixture.height = LOCAL_FIXTURE_HEIGHT
      fixture.thumbnail.width = LOCAL_FIXTURE_WIDTH
      fixture.thumbnail.height = LOCAL_FIXTURE_HEIGHT
      return fixture
    }
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

  async preload(page: ReaderPage, cancellation: ReaderCancellation): Promise<void> {
    cancellation.check()
    if (page.unit.work === LOCAL_FIXTURE_WORK) return
    const detail = this.details.get(page.unit.unit)
    const source = detail?.pages[page.sourceIndex]
    if (detail === undefined || source === undefined) throw new Error('missing_nh_preload_asset')
    if (this.source.localPageUri(detail, page.sourceIndex).length > 0) return
    const url = NhApiClient.imageUrl(detail.mediaId, page.sourceIndex, source.extension)
    const cacheKey = ReaderImageCacheService.cacheKey(detail.id, detail.mediaId, source.number, source.extension)
    await ReaderImageCacheService.load(this.context, url, cacheKey, false)
    cancellation.check()
  }

  async prepare(target: ReaderImageShareTarget, cancellation: ReaderCancellation): Promise<ReaderImageSharePresentation> {
    cancellation.check()
    const detail = this.details.get(target.unit.key.unit)
    const source = detail?.pages[target.sourceIndex]
    if (detail === undefined || source === undefined) throw new Error('missing_nh_share_page')
    const title = `${target.unit.title} ${target.sourceIndex + 1}`
    let record: systemShare.SharedRecord
    const downloadedUri: string = this.source.localPageUri(detail, target.sourceIndex)
    if (downloadedUri.length > 0) {
      cancellation.check()
      const downloadedPath: string = downloadedUri.startsWith('file://')
        ? downloadedUri.substring('file://'.length)
        : downloadedUri
      console.info('[NextNReaderShare] source=download')
      record = { utd: readerShareImageUtd(source.extension), label: 'IMAGE', title, description: title,
        uri: fileUri.getUriFromPath(downloadedPath) }
    } else {
      const url = NhApiClient.imageUrl(detail.mediaId, target.sourceIndex, source.extension)
      const key = ReaderImageCacheService.cacheKey(detail.id, detail.mediaId, source.number, source.extension)
      const result = await ReaderImageCacheService.load(this.context, url, key, false)
      cancellation.check()
      if (result.localPath.length > 0 && result.bytes > 0) {
        console.info('[NextNReaderShare] source=cache')
        record = { utd: readerShareImageUtd(source.extension), label: 'IMAGE', title, description: title,
          uri: fileUri.getUriFromPath(result.localPath) }
      } else {
        console.info('[NextNReaderShare] source=hyperlink')
        record = { utd: utd.UniformDataType.HYPERLINK, title, content: url }
      }
    }
    return new ReaderSystemSharePresentation(this.context, new systemShare.SharedData(record), {
      selectionMode: systemShare.SelectionMode.SINGLE, previewMode: systemShare.SharePreviewMode.DEFAULT,
    })
  }

  async load(page: ReaderPage, kind: ReaderAssetKind, cancellation: ReaderCancellation, forceReload: boolean): Promise<ReaderAsset> {
    cancellation.check()
    if (page.unit.work === LOCAL_FIXTURE_WORK) {
      console.info(`[NextNReaderLabFixture] load source=${page.sourceIndex} kind=${kind}`)
      return this.loadFixture(page, cancellation)
    }
    const detail = this.details.get(page.unit.unit)
    const source = detail?.pages[page.sourceIndex]
    if (detail === undefined || source === undefined) throw new Error('missing_nh_asset')
    const localUri: string = this.source.localPageUri(detail, page.sourceIndex)
    if (localUri.length > 0) {
      const localPath: string = localUri.startsWith('file://') ? localUri.substring('file://'.length) : localUri
      const facts = new ReaderImageInformation()
      facts.variant = 'source'
      const asset = new ReaderAsset(localUri, () => {}, new ReaderFileInformation(localPath, facts))
      if (localPath.length > 0) asset.crop = new NextNReaderCropSource(localPath)
      return asset
    }
    if (kind === 'thumbnail') return new ReaderAsset(source.thumbnailUrl)
    const url = NhApiClient.imageUrl(detail.mediaId, page.sourceIndex, source.extension)
    const cacheKey = ReaderImageCacheService.cacheKey(detail.id, detail.mediaId, source.number, source.extension)
    const result = await ReaderImageCacheService.load(this.context, url, cacheKey, forceReload)
    // Core releases a late result; the cache file remains owned by the existing service.
    const facts = new ReaderImageInformation()
    facts.bytes = result.bytes
    facts.variant = 'source'
    const lease: ReaderImageCacheLease = ReaderImageCacheService.retain(result)
    const asset = new ReaderAsset(result.displayUri,
      (): void => { ReaderImageCacheService.release(this.context, lease) },
      new ReaderFileInformation(result.localPath, facts),
      (): void => { ReaderImageCacheService.markPresented(lease) })
    if (result.localPath.length > 0) asset.crop = new NextNReaderCropSource(result.localPath)
    return asset
  }

  private async loadFixture(page: ReaderPage, cancellation: ReaderCancellation): Promise<ReaderAsset> {
    const rawFile = page.sourceIndex % 2 === 0 ? 'comic_translation_live_eval_page_01.jpg' :
      'comic_translation_live_eval_page_02.jpg'
    let bytes: Uint8Array
    try {
      bytes = await this.context.resourceManager.getRawFileContent(rawFile)
    } catch (error) {
      console.error(`[NextNReaderLabFixture] rawfile_failed source=${page.sourceIndex} error=${String(error)}`)
      throw error as Error
    }
    cancellation.check()
    const path = `${this.context.cacheDir}/rkit-local-fixture-${page.sourceIndex}.jpg`
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      const written = fileIo.writeSync(file.fd, bytes.buffer, { length: bytes.byteLength })
      if (written !== bytes.byteLength) throw new Error('reader_fixture_write_incomplete')
    } finally {
      if (file !== null) fileIo.closeSync(file)
    }
    cancellation.check()
    console.info(`[NextNReaderLabFixture] ready source=${page.sourceIndex} bytes=${bytes.byteLength}`)
    const facts = new ReaderImageInformation()
    facts.bytes = bytes.byteLength
    facts.width = LOCAL_FIXTURE_WIDTH
    facts.height = LOCAL_FIXTURE_HEIGHT
    facts.variant = 'source'
    return new ReaderAsset(`file://${path}`, () => {}, new ReaderFileInformation(path, facts))
  }
}
