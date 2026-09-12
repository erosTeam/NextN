import { common } from '@kit.AbilityKit'
import { HistoryRepository, NhGalleryDetail } from 'shared'

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

  enabled(progressReadWrite: boolean): boolean {
    return progressReadWrite
  }

  async restore(work: string, pageIndex: number, thumbnailEntry: boolean,
    progressReadWrite: boolean): Promise<number> {
    if (!this.enabled(progressReadWrite) || thumbnailEntry) return pageIndex
    const galleryId = Number(work)
    if (!Number.isSafeInteger(galleryId) || galleryId <= 0) return pageIndex
    try {
      return await HistoryRepository.progress(this.context, galleryId)
    } catch (error) {
      console.warn(`[NextNReaderLab] progress_restore_failed gallery=${galleryId} error=${(error as Error).message}`)
      return pageIndex
    }
  }

  save(work: string, progressReadWrite: boolean, pageIndex: number): Promise<void> {
    if (!this.enabled(progressReadWrite)) return Promise.resolve()
    const detail = this.details.progressDetail(work)
    if (detail === null) return Promise.reject(new Error('shared_reader_progress_detail_unavailable'))
    return HistoryRepository.saveProgress(this.context, detail, pageIndex)
  }
}
