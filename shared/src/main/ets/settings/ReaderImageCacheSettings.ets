import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

const DEFAULT_LIMIT_MB: number = 1024
const MIN_LIMIT_MB: number = 256
const MAX_LIMIT_MB: number = 2048
const STORE_NAME: string = 'nextn_settings'
const KEY_LIMIT_MB: string = 'reader.image_cache_limit_mb'

/**
 * User-selected disk budget for the private Reader image cache, ported from
 * NextE ReaderImageCacheSettings. The in-memory value is the single source
 * ReaderImageCacheService reads; every write normalizes to the supported
 * 256MB..2GB ladder and persists synchronously.
 */
export class ReaderImageCacheSettings {
  private static currentLimitMb: number = DEFAULT_LIMIT_MB

  static async restore(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME)
      const value: preferences.ValueType = store.getSync(KEY_LIMIT_MB, DEFAULT_LIMIT_MB)
      ReaderImageCacheSettings.currentLimitMb = ReaderImageCacheSettings.normalize(
        typeof value === 'number' ? value : DEFAULT_LIMIT_MB,
      )
    } catch (_error) {
      ReaderImageCacheSettings.currentLimitMb = DEFAULT_LIMIT_MB
    }
  }

  static limitMb(): number {
    return ReaderImageCacheSettings.currentLimitMb
  }

  static limitBytes(): number {
    return ReaderImageCacheSettings.currentLimitMb * 1024 * 1024
  }

  static async setLimitMb(context: common.UIAbilityContext, value: number): Promise<void> {
    const normalized: number = ReaderImageCacheSettings.normalize(value)
    ReaderImageCacheSettings.currentLimitMb = normalized
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_LIMIT_MB, normalized)
      store.flushSync()
    } catch (_error) {
      // The in-memory budget stays authoritative for this session; the next
      // restore falls back to the last persisted ladder value.
    }
  }

  private static normalize(value: number): number {
    if (!Number.isFinite(value)) {
      return DEFAULT_LIMIT_MB
    }
    const rounded: number = Math.round(value)
    if (rounded <= MIN_LIMIT_MB) {
      return MIN_LIMIT_MB
    }
    if (rounded <= 512) {
      return 512
    }
    if (rounded <= 1024) {
      return 1024
    }
    return MAX_LIMIT_MB
  }
}
