import { common } from '@kit.AbilityKit'
import { ReaderLabRequest } from '@reader-kit/ui'
import { HistoryRepository, NhGalleryDetail } from 'shared'

export const NEXTN_READER_PROGRESS_READWRITE_UNIT: string = '__nextn_progress_readwrite__'

export interface NextNReaderProgressDetailProvider {
  progressDetail(work: string): NhGalleryDetail | null
}

/** Explicit debug-only adapter to NextN's existing progress repository. */
export class NextNReaderProgressPersistence {
  private context: common.UIAbilityContext
  private details: NextNReaderProgressDetailProvider

  constructor(context: common.UIAbilityContext, details: NextNReaderProgressDetailProvider) {
    this.context = context
    this.details = details
  }

  enabled(request: ReaderLabRequest): boolean {
    return request.unit === NEXTN_READER_PROGRESS_READWRITE_UNIT
  }

  async restore(request: ReaderLabRequest): Promise<number> {
    if (!this.enabled(request) || request.thumbnailEntry) return request.pageIndex
    const galleryId = Number(request.work)
    if (!Number.isSafeInteger(galleryId) || galleryId <= 0) return request.pageIndex
    try {
      return await HistoryRepository.progress(this.context, galleryId)
    } catch (error) {
      console.warn(`[NextNReaderLab] progress_restore_failed gallery=${galleryId} error=${(error as Error).message}`)
      return request.pageIndex
    }
  }

  save(request: ReaderLabRequest, pageIndex: number): Promise<void> {
    if (!this.enabled(request)) return Promise.resolve()
    const detail = this.details.progressDetail(request.work)
    if (detail === null) return Promise.reject(new Error('shared_reader_progress_detail_unavailable'))
    return HistoryRepository.saveProgress(this.context, detail, pageIndex)
  }
}
