/** Persistent gallery-download metadata. No account data is stored here. */
@ObservedV2
export class NhDownloadTask {
  @Trace galleryId: number = 0
  @Trace mediaId: string = ''
  @Trace title: string = ''
  @Trace thumbnailUrl: string = ''
  @Trace pageCount: number = 0
  @Trace pageExtensions: string[] = []
  /** Device-local directory that owns this task's metadata and promoted pages. */
  @Trace storageDirectory: string = ''
  @Trace completedPages: number = 0
  @Trace status: string = NhDownloadTaskStatus.QUEUED
  @Trace errorMessage: string = ''
  @Trace createdAt: number = 0
  @Trace updatedAt: number = 0

  copy(): NhDownloadTask {
    const result: NhDownloadTask = new NhDownloadTask()
    result.galleryId = this.galleryId
    result.mediaId = this.mediaId
    result.title = this.title
    result.thumbnailUrl = this.thumbnailUrl
    result.pageCount = this.pageCount
    result.pageExtensions = this.pageExtensions.slice()
    result.storageDirectory = this.storageDirectory
    result.completedPages = this.completedPages
    result.status = this.status
    result.errorMessage = this.errorMessage
    result.createdAt = this.createdAt
    result.updatedAt = this.updatedAt
    return result
  }

  assignFrom(source: NhDownloadTask): void {
    this.galleryId = source.galleryId
    this.mediaId = source.mediaId
    this.title = source.title
    this.thumbnailUrl = source.thumbnailUrl
    this.pageCount = source.pageCount
    this.pageExtensions = source.pageExtensions.slice()
    this.storageDirectory = source.storageDirectory
    this.completedPages = source.completedPages
    this.status = source.status
    this.errorMessage = source.errorMessage
    this.createdAt = source.createdAt
    this.updatedAt = source.updatedAt
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
