import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import {
  NhReaderBackgroundMode,
  NhReaderImageScalingQuality,
  NhReaderMode,
  NhReaderSpreadLayout,
  NhReaderSuperResolutionModel,
  READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT,
  READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT_CHOICES,
} from '../model/NhReaderSettings'
import {
  NhReaderTapZoneInvert,
  NhReaderTapZoneLayout,
  NhReaderTapZoneResolver,
} from '../model/NhReaderTapZone'
import { LocalDataStore } from './LocalDataStore'

const READER_MODE_KEY: string = 'reader_mode'
const READER_KEEP_SCREEN_ON_KEY: string = 'reader_keep_screen_on'
const READER_PRELOAD_PAGES_KEY: string = 'reader_preload_pages'
const READER_SHOW_PAGE_NUMBER_KEY: string = 'reader_show_page_number'
const READER_BACKGROUND_MODE_KEY: string = 'reader_background_mode'
const READER_IMAGE_SCALING_QUALITY_KEY: string = 'reader_image_scaling_quality'
const READER_FULLSCREEN_KEY: string = 'reader_fullscreen'
const READER_AUTO_PAGE_SECONDS_KEY: string = 'reader_auto_page_seconds'
const READER_VOLUME_KEY_TURN_KEY: string = 'reader_volume_key_turn'
const READER_DOUBLE_PAGE_ENABLED_KEY: string = 'reader_double_page_enabled'
const READER_SPREAD_LAYOUT_KEY: string = 'reader_spread_layout'
const READER_PAGE_TURN_ANIMATION_KEY: string = 'reader_page_turn_animation'
const READER_TAP_ZONE_LAYOUT_KEY: string = 'reader_tap_zone_layout'
const READER_TAP_ZONE_INVERT_KEY: string = 'reader_tap_zone_invert'
const READER_SUPER_RESOLUTION_ENABLED_KEY: string = 'reader_super_resolution_enabled'
const READER_SUPER_RESOLUTION_MODEL_KEY: string = 'reader_super_resolution_model'
const READER_SUPER_RESOLUTION_MAX_HEIGHT_KEY: string = 'reader_super_resolution_max_height'
const SQL_SELECT_MODE: string = 'SELECT value FROM reader_settings WHERE key = ? LIMIT 1'
const SQL_UPSERT_MODE: string =
  'INSERT INTO reader_settings (key, value) VALUES (?, ?) ' +
  'ON CONFLICT(key) DO UPDATE SET value = excluded.value'

/** Small durable preference boundary for reader-only presentation choices. */
export class ReaderSettingsRepository {
  private static writeTail: Promise<void> = Promise.resolve()

  private static normalizeMode(value: string): NhReaderMode {
    if (value === NhReaderMode.PAGED ||
      value === NhReaderMode.PAGED_RTL ||
      value === NhReaderMode.PAGED_VERTICAL) {
      return value as NhReaderMode
    }
    return NhReaderMode.VERTICAL
  }

  private static normalizePreloadPages(value: number): number {
    if (!Number.isFinite(value)) {
      return 2
    }
    return Math.max(0, Math.min(5, Math.round(value)))
  }

  private static normalizeAutoPageSeconds(value: number): number {
    if (!Number.isFinite(value)) {
      return 3
    }
    return Math.max(1, Math.min(60, Math.round(value)))
  }

  private static normalizeImageScalingQuality(value: string): NhReaderImageScalingQuality {
    if (value === NhReaderImageScalingQuality.LOW || value === NhReaderImageScalingQuality.HIGH) {
      return value as NhReaderImageScalingQuality
    }
    return NhReaderImageScalingQuality.MEDIUM
  }

  private static normalizeBackgroundMode(value: string): NhReaderBackgroundMode {
    if (value === NhReaderBackgroundMode.GRAY ||
      value === NhReaderBackgroundMode.WHITE ||
      value === NhReaderBackgroundMode.AUTO) {
      return value as NhReaderBackgroundMode
    }
    return NhReaderBackgroundMode.BLACK
  }

  private static normalizeSpreadLayout(value: string): NhReaderSpreadLayout {
    if (value === NhReaderSpreadLayout.SPLIT) {
      return NhReaderSpreadLayout.SPLIT
    }
    return NhReaderSpreadLayout.JOINED
  }

  private static async value(context: common.UIAbilityContext, key: string): Promise<string | null> {
    let rows: relationalStore.ResultSet | null = null
    try {
      await ReaderSettingsRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql(SQL_SELECT_MODE, [key])
      if (!rows.goToNextRow()) {
        return null
      }
      const column: number = rows.getColumnIndex('value')
      return rows.isColumnNull(column) ? '' : rows.getString(column)
    } catch (error) {
      throw (error as Error)
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (_error) {}
      }
    }
  }

  static async mode(context: common.UIAbilityContext): Promise<NhReaderMode> {
    return ReaderSettingsRepository.normalizeMode(
      (await ReaderSettingsRepository.value(context, READER_MODE_KEY)) ?? '',
    )
  }

  static async keepScreenOn(context: common.UIAbilityContext): Promise<boolean> {
    // Match ErosN's reader-only default while allowing an explicit local opt-out.
    return (await ReaderSettingsRepository.value(context, READER_KEEP_SCREEN_ON_KEY)) !== 'false'
  }

  static async preloadPages(context: common.UIAbilityContext): Promise<number> {
    const stored: string | null = await ReaderSettingsRepository.value(context, READER_PRELOAD_PAGES_KEY)
    return ReaderSettingsRepository.normalizePreloadPages(stored === null ? 2 : Number(stored))
  }

  /** Match the existing Reader page-number default for installations without this key. */
  static async showPageNumber(context: common.UIAbilityContext): Promise<boolean> {
    return (await ReaderSettingsRepository.value(context, READER_SHOW_PAGE_NUMBER_KEY)) !== 'false'
  }

  /** Missing or malformed values preserve NextN's established black Reader canvas. */
  static async backgroundMode(context: common.UIAbilityContext): Promise<NhReaderBackgroundMode> {
    return ReaderSettingsRepository.normalizeBackgroundMode(
      (await ReaderSettingsRepository.value(context, READER_BACKGROUND_MODE_KEY)) ?? '',
    )
  }

  static async imageScalingQuality(context: common.UIAbilityContext): Promise<NhReaderImageScalingQuality> {
    return ReaderSettingsRepository.normalizeImageScalingQuality(
      (await ReaderSettingsRepository.value(context, READER_IMAGE_SCALING_QUALITY_KEY)) ?? '',
    )
  }

  /** Matches NextE: Reader starts as an immersive canvas unless the user opts out locally. */
  static async fullscreen(context: common.UIAbilityContext): Promise<boolean> {
    return (await ReaderSettingsRepository.value(context, READER_FULLSCREEN_KEY)) !== 'false'
  }

  static async autoPageSeconds(context: common.UIAbilityContext): Promise<number> {
    const stored: string | null = await ReaderSettingsRepository.value(context, READER_AUTO_PAGE_SECONDS_KEY)
    return ReaderSettingsRepository.normalizeAutoPageSeconds(stored === null ? 3 : Number(stored))
  }

  /**
   * This stays opt-in: while enabled the official foreground key consumer
   * suppresses the system volume action for the Reader route.
   */
  static async volumeKeyTurn(context: common.UIAbilityContext): Promise<boolean> {
    return (await ReaderSettingsRepository.value(context, READER_VOLUME_KEY_TURN_KEY)) === 'true'
  }

  /**
   * Keep the requested presentation durable even when the current Reader
   * canvas is too narrow to render a spread.  Eligibility is intentionally
   * resolved by ReaderPage from its live local viewport.
   */
  static async doublePageEnabled(context: common.UIAbilityContext): Promise<boolean> {
    return (await ReaderSettingsRepository.value(context, READER_DOUBLE_PAGE_ENABLED_KEY)) === 'true'
  }

  /** Missing or malformed values retain NextN's existing ratio-sized spread geometry. */
  static async spreadLayout(context: common.UIAbilityContext): Promise<NhReaderSpreadLayout> {
    return ReaderSettingsRepository.normalizeSpreadLayout(
      (await ReaderSettingsRepository.value(context, READER_SPREAD_LAYOUT_KEY)) ?? '',
    )
  }

  /** Preserve the existing animated adjacent-turn behavior for installations without this key. */
  static async pageTurnAnimation(context: common.UIAbilityContext): Promise<boolean> {
    return (await ReaderSettingsRepository.value(context, READER_PAGE_TURN_ANIMATION_KEY)) !== 'false'
  }

  static async tapZoneLayout(context: common.UIAbilityContext): Promise<NhReaderTapZoneLayout> {
    return NhReaderTapZoneResolver.normalizeLayout(
      (await ReaderSettingsRepository.value(context, READER_TAP_ZONE_LAYOUT_KEY)) ?? '',
    )
  }

  static async tapZoneInvert(context: common.UIAbilityContext): Promise<NhReaderTapZoneInvert> {
    return NhReaderTapZoneResolver.normalizeInvert(
      (await ReaderSettingsRepository.value(context, READER_TAP_ZONE_INVERT_KEY)) ?? '',
    )
  }

  static async superResolutionEnabled(context: common.UIAbilityContext): Promise<boolean> {
    return (await ReaderSettingsRepository.value(context, READER_SUPER_RESOLUTION_ENABLED_KEY)) === 'true'
  }

  static async superResolutionModel(
    context: common.UIAbilityContext,
  ): Promise<NhReaderSuperResolutionModel> {
    return ReaderSettingsRepository.normalizeSuperResolutionModel(
      (await ReaderSettingsRepository.value(context, READER_SUPER_RESOLUTION_MODEL_KEY)) ?? '',
    )
  }

  static async superResolutionMaxHeight(context: common.UIAbilityContext): Promise<number> {
    const stored: string | null = await ReaderSettingsRepository.value(
      context,
      READER_SUPER_RESOLUTION_MAX_HEIGHT_KEY,
    )
    return ReaderSettingsRepository.normalizeSuperResolutionMaxHeight(
      stored === null ? READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT : Number(stored),
    )
  }

  static saveMode(context: common.UIAbilityContext, mode: NhReaderMode): Promise<void> {
    const normalized: NhReaderMode = ReaderSettingsRepository.normalizeMode(mode)
    return ReaderSettingsRepository.saveValue(context, READER_MODE_KEY, normalized)
  }

  static saveKeepScreenOn(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_KEEP_SCREEN_ON_KEY,
      enabled ? 'true' : 'false',
    )
  }

  static savePreloadPages(context: common.UIAbilityContext, pages: number): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_PRELOAD_PAGES_KEY,
      ReaderSettingsRepository.normalizePreloadPages(pages).toString(),
    )
  }

  static saveShowPageNumber(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_SHOW_PAGE_NUMBER_KEY,
      enabled ? 'true' : 'false',
    )
  }

  static saveBackgroundMode(context: common.UIAbilityContext, mode: NhReaderBackgroundMode): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_BACKGROUND_MODE_KEY,
      ReaderSettingsRepository.normalizeBackgroundMode(mode),
    )
  }

  static saveImageScalingQuality(
    context: common.UIAbilityContext,
    quality: NhReaderImageScalingQuality,
  ): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_IMAGE_SCALING_QUALITY_KEY,
      ReaderSettingsRepository.normalizeImageScalingQuality(quality),
    )
  }

  static saveFullscreen(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_FULLSCREEN_KEY,
      enabled ? 'true' : 'false',
    )
  }

  static saveAutoPageSeconds(context: common.UIAbilityContext, seconds: number): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_AUTO_PAGE_SECONDS_KEY,
      ReaderSettingsRepository.normalizeAutoPageSeconds(seconds).toString(),
    )
  }

  static saveVolumeKeyTurn(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_VOLUME_KEY_TURN_KEY,
      enabled ? 'true' : 'false',
    )
  }

  static saveDoublePageEnabled(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_DOUBLE_PAGE_ENABLED_KEY,
      enabled ? 'true' : 'false',
    )
  }

  static saveSpreadLayout(context: common.UIAbilityContext, layout: NhReaderSpreadLayout): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_SPREAD_LAYOUT_KEY,
      ReaderSettingsRepository.normalizeSpreadLayout(layout),
    )
  }

  static savePageTurnAnimation(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_PAGE_TURN_ANIMATION_KEY,
      enabled ? 'true' : 'false',
    )
  }

  static saveTapZoneLayout(
    context: common.UIAbilityContext,
    layout: NhReaderTapZoneLayout,
  ): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_TAP_ZONE_LAYOUT_KEY,
      NhReaderTapZoneResolver.normalizeLayout(layout),
    )
  }

  static saveTapZoneInvert(
    context: common.UIAbilityContext,
    invert: NhReaderTapZoneInvert,
  ): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_TAP_ZONE_INVERT_KEY,
      NhReaderTapZoneResolver.normalizeInvert(invert),
    )
  }

  static saveSuperResolutionEnabled(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_SUPER_RESOLUTION_ENABLED_KEY,
      enabled ? 'true' : 'false',
    )
  }

  static saveSuperResolutionModel(
    context: common.UIAbilityContext,
    model: NhReaderSuperResolutionModel,
  ): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_SUPER_RESOLUTION_MODEL_KEY,
      ReaderSettingsRepository.normalizeSuperResolutionModel(model),
    )
  }

  static saveSuperResolutionMaxHeight(context: common.UIAbilityContext, height: number): Promise<void> {
    return ReaderSettingsRepository.saveValue(
      context,
      READER_SUPER_RESOLUTION_MAX_HEIGHT_KEY,
      ReaderSettingsRepository.normalizeSuperResolutionMaxHeight(height).toString(),
    )
  }

  private static normalizeSuperResolutionModel(value: string): NhReaderSuperResolutionModel {
    if (value === NhReaderSuperResolutionModel.WAIFU2X_PHOTO_NOISE0_2X ||
      value === NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X ||
      value === NhReaderSuperResolutionModel.REAL_ESRGAN_X2PLUS) {
      return value as NhReaderSuperResolutionModel
    }
    return NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X
  }

  private static normalizeSuperResolutionMaxHeight(value: number): number {
    const normalized: number = Math.round(value)
    for (let index: number = 0; index < READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT_CHOICES.length; index++) {
      if (normalized === READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT_CHOICES[index]) {
        return normalized
      }
    }
    return READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT
  }

  private static saveValue(context: common.UIAbilityContext, key: string, value: string): Promise<void> {
    return ReaderSettingsRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT_MODE, [key, value])
    })
  }

  private static enqueueWrite(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = ReaderSettingsRepository.writeTail.then(
      (): Promise<void> => operation(),
      (): Promise<void> => operation(),
    )
    ReaderSettingsRepository.writeTail = queued.catch((): void => {})
    return queued
  }

  /** Backup export: whole reader_settings key-value table. */
  static async exportForBackup(context: common.UIAbilityContext): Promise<Record<string, string>> {
    const out: Record<string, string> = {}
    let rows: relationalStore.ResultSet | null = null
    try {
      await ReaderSettingsRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql('SELECT key, value FROM reader_settings')
      while (rows.goToNextRow()) {
        const keyColumn: number = rows.getColumnIndex('key')
        const valueColumn: number = rows.getColumnIndex('value')
        if (!rows.isColumnNull(keyColumn) && !rows.isColumnNull(valueColumn)) {
          out[rows.getString(keyColumn)] = rows.getString(valueColumn)
        }
      }
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (_error) {}
      }
    }
    return out
  }

  /** Backup restore: authoritative replacement of the reader_settings table. */
  static async restoreBackup(context: common.UIAbilityContext, values: Record<string, string>): Promise<void> {
    await ReaderSettingsRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql('DELETE FROM reader_settings')
      const keys: string[] = Object.keys(values)
      for (let i: number = 0; i < keys.length; i++) {
        await store.executeSql(SQL_UPSERT_MODE, [keys[i], values[keys[i]]])
      }
    })
  }
}
