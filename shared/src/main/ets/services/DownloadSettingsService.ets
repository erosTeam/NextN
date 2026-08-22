import { common } from '@kit.AbilityKit'
import { NhDownloadSettings } from '../model/NhDownloadSettings'
import { connectDownloadSettings, DownloadSettingsState } from '../state/DownloadSettingsState'
import { DownloadSettingsRepository } from '../storage/DownloadSettingsRepository'

const MIN_GALLERY_CONCURRENCY: number = 1
const MAX_GALLERY_CONCURRENCY: number = 5
const MIN_PAGE_CONCURRENCY: number = 1
const MAX_PAGE_CONCURRENCY: number = 5
const MIN_RETRY_COUNT: number = 0
const MAX_RETRY_COUNT: number = 5
const MAX_REQUEST_INTERVAL_SECONDS: number = 10
const MAX_SPEED_LIMIT_KBPS: number = 8192
const SPEED_LIMIT_STEP_KBPS: number = 256

/**
 * NextE-style state plus durable policy writer for NextN's small private
 * queue. Values are capped so a deliberate user choice remains bounded.
 */
export class DownloadSettingsService {
  private static restoreTask: Promise<void> | null = null
  private static restored: boolean = false

  static async restore(context: common.UIAbilityContext): Promise<void> {
    if (DownloadSettingsService.restored) {
      return
    }
    if (DownloadSettingsService.restoreTask !== null) {
      await DownloadSettingsService.restoreTask
      return
    }
    const task: Promise<void> = DownloadSettingsService.restoreInternal(context)
    DownloadSettingsService.restoreTask = task
    try {
      await task
      DownloadSettingsService.restored = true
    } finally {
      DownloadSettingsService.restoreTask = null
    }
  }

  static snapshot(): NhDownloadSettings {
    return DownloadSettingsService.state().snapshot()
  }

  static async save(context: common.UIAbilityContext, settings: NhDownloadSettings): Promise<NhDownloadSettings> {
    await DownloadSettingsService.restore(context)
    const normalized: NhDownloadSettings = DownloadSettingsService.normalize(settings)
    await DownloadSettingsRepository.save(context, normalized)
    DownloadSettingsService.state().replace(normalized)
    return normalized.copy()
  }

  static async setMaxConcurrentGalleries(context: common.UIAbilityContext, value: number): Promise<NhDownloadSettings> {
    await DownloadSettingsService.restore(context)
    const settings: NhDownloadSettings = DownloadSettingsService.snapshot()
    settings.maxConcurrentGalleries = value
    return DownloadSettingsService.save(context, settings)
  }

  static async setMaxConcurrentPages(context: common.UIAbilityContext, value: number): Promise<NhDownloadSettings> {
    await DownloadSettingsService.restore(context)
    const settings: NhDownloadSettings = DownloadSettingsService.snapshot()
    settings.maxConcurrentPages = value
    return DownloadSettingsService.save(context, settings)
  }

  static async setRetryCount(context: common.UIAbilityContext, value: number): Promise<NhDownloadSettings> {
    await DownloadSettingsService.restore(context)
    const settings: NhDownloadSettings = DownloadSettingsService.snapshot()
    settings.retryCount = value
    return DownloadSettingsService.save(context, settings)
  }

  static async setNotifyOnComplete(
    context: common.UIAbilityContext,
    enabled: boolean,
  ): Promise<NhDownloadSettings> {
    await DownloadSettingsService.restore(context)
    const settings: NhDownloadSettings = DownloadSettingsService.snapshot()
    settings.notifyOnComplete = enabled
    return DownloadSettingsService.save(context, settings)
  }

  /** Minimum pause between page batches, clamped to 0 through 10 seconds. */
  static async setRequestIntervalSeconds(
    context: common.UIAbilityContext,
    seconds: number,
  ): Promise<NhDownloadSettings> {
    await DownloadSettingsService.restore(context)
    const settings: NhDownloadSettings = DownloadSettingsService.snapshot()
    settings.requestIntervalSeconds = seconds
    return DownloadSettingsService.save(context, settings)
  }

  /** Whether failed (ERROR) tasks resume automatically on cold start. PAUSED stays manual. */
  static async setAutoRetryFailed(
    context: common.UIAbilityContext,
    enabled: boolean,
  ): Promise<NhDownloadSettings> {
    await DownloadSettingsService.restore(context)
    const settings: NhDownloadSettings = DownloadSettingsService.snapshot()
    settings.autoRetryFailed = enabled
    return DownloadSettingsService.save(context, settings)
  }

  /** Average queue speed cap in KB/s; rounded to the 256 KB step, 0 disables. */
  static async setSpeedLimitKbps(
    context: common.UIAbilityContext,
    kbps: number,
  ): Promise<NhDownloadSettings> {
    await DownloadSettingsService.restore(context)
    const settings: NhDownloadSettings = DownloadSettingsService.snapshot()
    settings.speedLimitKbps = kbps
    return DownloadSettingsService.save(context, settings)
  }

  static minGalleryConcurrency(): number {
    return MIN_GALLERY_CONCURRENCY
  }

  static maxGalleryConcurrency(): number {
    return MAX_GALLERY_CONCURRENCY
  }

  static minPageConcurrency(): number {
    return MIN_PAGE_CONCURRENCY
  }

  static maxPageConcurrency(): number {
    return MAX_PAGE_CONCURRENCY
  }

  static minRetryCount(): number {
    return MIN_RETRY_COUNT
  }

  static maxRetryCount(): number {
    return MAX_RETRY_COUNT
  }

  static async restoreFromBackup(context: common.UIAbilityContext): Promise<void> {
    if (DownloadSettingsService.restoreTask !== null) {
      await DownloadSettingsService.restoreTask
    }
    DownloadSettingsService.restored = false
    await DownloadSettingsService.restore(context)
  }

  private static async restoreInternal(context: common.UIAbilityContext): Promise<void> {
    DownloadSettingsService.state().replace(
      DownloadSettingsService.normalize(await DownloadSettingsRepository.load(context)),
    )
  }

  private static state(): DownloadSettingsState {
    return connectDownloadSettings()
  }

  private static normalize(settings: NhDownloadSettings): NhDownloadSettings {
    const normalized: NhDownloadSettings = settings.copy()
    normalized.maxConcurrentGalleries = DownloadSettingsService.clamp(
      normalized.maxConcurrentGalleries,
      MIN_GALLERY_CONCURRENCY,
      MAX_GALLERY_CONCURRENCY,
    )
    normalized.maxConcurrentPages = DownloadSettingsService.clamp(
      normalized.maxConcurrentPages,
      MIN_PAGE_CONCURRENCY,
      MAX_PAGE_CONCURRENCY,
    )
    normalized.retryCount = DownloadSettingsService.clamp(
      normalized.retryCount,
      MIN_RETRY_COUNT,
      MAX_RETRY_COUNT,
    )
    normalized.requestIntervalSeconds = DownloadSettingsService.clamp(
      normalized.requestIntervalSeconds,
      0,
      MAX_REQUEST_INTERVAL_SECONDS,
    )
    normalized.speedLimitKbps = DownloadSettingsService.roundSpeedLimit(
      normalized.speedLimitKbps,
    )
    return normalized
  }

  private static roundSpeedLimit(kbps: number): number {
    const rounded: number = Math.round(kbps / SPEED_LIMIT_STEP_KBPS) * SPEED_LIMIT_STEP_KBPS
    return DownloadSettingsService.clamp(rounded, 0, MAX_SPEED_LIMIT_KBPS)
  }

  private static clamp(value: number, minimum: number, maximum: number): number {
    const rounded: number = Math.round(value)
    if (!Number.isFinite(rounded)) {
      return minimum
    }
    return Math.min(maximum, Math.max(minimum, rounded))
  }
}
