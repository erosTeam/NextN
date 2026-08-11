import { AppStorageV2 } from '@kit.ArkUI'
import { NhDownloadSettings } from '../model/NhDownloadSettings'

@ObservedV2
export class DownloadSettingsState {
  @Trace maxConcurrentGalleries: number = 1
  @Trace maxConcurrentPages: number = 3
  @Trace retryCount: number = 2
  @Trace notifyOnComplete: boolean = false

  replace(settings: NhDownloadSettings): void {
    this.maxConcurrentGalleries = settings.maxConcurrentGalleries
    this.maxConcurrentPages = settings.maxConcurrentPages
    this.retryCount = settings.retryCount
    this.notifyOnComplete = settings.notifyOnComplete
  }

  snapshot(): NhDownloadSettings {
    const result: NhDownloadSettings = new NhDownloadSettings()
    result.maxConcurrentGalleries = this.maxConcurrentGalleries
    result.maxConcurrentPages = this.maxConcurrentPages
    result.retryCount = this.retryCount
    result.notifyOnComplete = this.notifyOnComplete
    return result
  }
}

const DOWNLOAD_SETTINGS_STATE_KEY: string = 'nextn_download_settings'
let sharedDownloadSettingsState: DownloadSettingsState | null = null

export function connectDownloadSettings(): DownloadSettingsState {
  if (sharedDownloadSettingsState === null) {
    sharedDownloadSettingsState = AppStorageV2.connect(
      DownloadSettingsState,
      DOWNLOAD_SETTINGS_STATE_KEY,
      (): DownloadSettingsState => new DownloadSettingsState(),
    )!
  }
  return sharedDownloadSettingsState
}
