/** Persistent, app-private gallery download metadata. No account data is stored here. */
export class NhDownloadTask {
  galleryId: number = 0
  mediaId: string = ''
  title: string = ''
  thumbnailUrl: string = ''
  pageCount: number = 0
  pageExtensions: string[] = []
  completedPages: number = 0
  status: string = NhDownloadTaskStatus.QUEUED
  errorMessage: string = ''
  createdAt: number = 0
  updatedAt: number = 0

  copy(): NhDownloadTask {
    const result: NhDownloadTask = new NhDownloadTask()
    result.galleryId = this.galleryId
    result.mediaId = this.mediaId
    result.title = this.title
    result.thumbnailUrl = this.thumbnailUrl
    result.pageCount = this.pageCount
    result.pageExtensions = this.pageExtensions.slice()
    result.completedPages = this.completedPages
    result.status = this.status
    result.errorMessage = this.errorMessage
    result.createdAt = this.createdAt
    result.updatedAt = this.updatedAt
    return result
  }

  progressText(): string {
    return `${Math.max(0, this.completedPages)} / ${Math.max(0, this.pageCount)}`
  }

  isComplete(): boolean {
    return this.status === NhDownloadTaskStatus.COMPLETE &&
      this.pageCount > 0 && this.completedPages >= this.pageCount
  }
}

/** The queue is local-only; these values deliberately mirror NextE's durable task lifecycle. */
export class NhDownloadTaskStatus {
  static readonly QUEUED: string = 'queued'
  static readonly DOWNLOADING: string = 'downloading'
  static readonly PAUSED: string = 'paused'
  static readonly COMPLETE: string = 'complete'
  static readonly ERROR: string = 'error'
}
