/**
 * Local-only queue policy. These values affect only the app-private GET
 * workers; they never grant export, background transfer, or remote mutation.
 */
export class NhDownloadSettings {
  maxConcurrentGalleries: number = 1
  maxConcurrentPages: number = 3
  retryCount: number = 2
  notifyOnComplete: boolean = false
  /** Keep downloaded gallery pages out of media-library scans via `.nomedia`. */
  hideFromMediaLibrary: boolean = true
  /** Minimum pause between page batches, in seconds. 0 disables the pause. */
  requestIntervalSeconds: number = 0
  /** Resume ERROR tasks automatically on cold start. PAUSED tasks never auto-resume. */
  autoRetryFailed: boolean = true
  /** Average queue speed cap in KB/s. 0 disables the cap. */
  speedLimitKbps: number = 0

  copy(): NhDownloadSettings {
    const result: NhDownloadSettings = new NhDownloadSettings()
    result.maxConcurrentGalleries = this.maxConcurrentGalleries
    result.maxConcurrentPages = this.maxConcurrentPages
    result.retryCount = this.retryCount
    result.notifyOnComplete = this.notifyOnComplete
    result.hideFromMediaLibrary = this.hideFromMediaLibrary
    result.requestIntervalSeconds = this.requestIntervalSeconds
    result.autoRetryFailed = this.autoRetryFailed
    result.speedLimitKbps = this.speedLimitKbps
    return result
  }
}
