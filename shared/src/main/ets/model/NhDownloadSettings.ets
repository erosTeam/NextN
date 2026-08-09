/**
 * Local-only queue policy. These values affect only the app-private GET
 * workers; they never grant export, background transfer, or remote mutation.
 */
export class NhDownloadSettings {
  maxConcurrentGalleries: number = 1
  maxConcurrentPages: number = 3
  retryCount: number = 2

  copy(): NhDownloadSettings {
    const result: NhDownloadSettings = new NhDownloadSettings()
    result.maxConcurrentGalleries = this.maxConcurrentGalleries
    result.maxConcurrentPages = this.maxConcurrentPages
    result.retryCount = this.retryCount
    return result
  }
}
