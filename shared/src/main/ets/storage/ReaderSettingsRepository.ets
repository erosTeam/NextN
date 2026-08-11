import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { NhReaderMode, NhReaderSuperResolutionModel } from '../model/NhReaderSettings'
import {
  NhReaderTapZoneInvert,
  NhReaderTapZoneLayout,
  NhReaderTapZoneResolver,
} from '../model/NhReaderTapZone'
import { LocalDataStore } from './LocalDataStore'

const READER_MODE_KEY: string = 'reader_mode'
const READER_KEEP_SCREEN_ON_KEY: string = 'reader_keep_screen_on'
const READER_PRELOAD_PAGES_KEY: string = 'reader_preload_pages'
const READER_FULLSCREEN_KEY: string = 'reader_fullscreen'
const READER_AUTO_PAGE_SECONDS_KEY: string = 'reader_auto_page_seconds'
const READER_VOLUME_KEY_TURN_KEY: string = 'reader_volume_key_turn'
const READER_DOUBLE_PAGE_ENABLED_KEY: string = 'reader_double_page_enabled'
const READER_TAP_ZONE_LAYOUT_KEY: string = 'reader_tap_zone_layout'
const READER_TAP_ZONE_INVERT_KEY: string = 'reader_tap_zone_invert'
const READER_SUPER_RESOLUTION_ENABLED_KEY: string = 'reader_super_resolution_enabled'
const READER_SUPER_RESOLUTION_MODEL_KEY: string = 'reader_super_resolution_model'
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

  private static normalizeSuperResolutionModel(value: string): NhReaderSuperResolutionModel {
    if (value === NhReaderSuperResolutionModel.WAIFU2X_PHOTO_NOISE0_2X ||
      value === NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X) {
      return value as NhReaderSuperResolutionModel
    }
    return NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X
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
}
