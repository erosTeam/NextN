import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { NhTagTranslationStatus } from '../model/NhTagTranslation'
import { ComicTranslationDiagnosticLogger } from '../services/ComicTranslationDiagnosticLogger'
import { TagTranslationUpdateService } from '../services/TagTranslationUpdateService'
import { TagTranslationRepository } from '../storage/TagTranslationRepository'
import {
  TAG_INTRO_IMAGE_DISABLE,
  TAG_INTRO_IMAGE_NON_H,
  TAG_INTRO_IMAGE_R18,
  TAG_INTRO_IMAGE_R18G,
  TAG_TRANSLATION_UPDATE_EVERY_START,
  TAG_TRANSLATION_UPDATE_MANUAL,
  connectTagTranslationSettings,
} from '../state/TagTranslationSettingsState'

const SETTINGS_STORE: string = 'nextn_settings'
const KEY_ENABLED: string = 'tag_translation_enabled'
const KEY_USE_CDN: string = 'tag_translation_use_cdn'
const KEY_UPDATE_MODE: string = 'tag_translation_update_mode'
const KEY_INTRO_IMAGE_LEVEL: string = 'tag_translation_intro_image_level'
const STARTUP_UPDATE_DELAY_MS: number = 10000

/** Preferences-backed tag dictionary policy and status display metadata. */
export class TagTranslationSettings {
  private static statusRefreshEpoch: number = 0

  static async restore(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences =
        await preferences.getPreferences(context, SETTINGS_STORE)
      connectTagTranslationSettings().enabled =
        store.getSync(KEY_ENABLED, false) as boolean
      connectTagTranslationSettings().useCdn =
        store.getSync(KEY_USE_CDN, false) as boolean
      connectTagTranslationSettings().updateMode = TagTranslationSettings.normalizeMode(
        store.getSync(KEY_UPDATE_MODE, TAG_TRANSLATION_UPDATE_MANUAL) as string,
      )
      connectTagTranslationSettings().introImageLevel = TagTranslationSettings.normalizeIntroImageLevel(
        store.getSync(KEY_INTRO_IMAGE_LEVEL, TAG_INTRO_IMAGE_NON_H) as string,
      )
    } catch (error) {
      ComicTranslationDiagnosticLogger.warn(
        'tag-translation',
        'settings_restore_failed',
        (error as Error).message,
      )
    }
    await TagTranslationSettings.refreshStatus(context)
    TagTranslationSettings.scheduleStartupUpdate(context)
  }

  static async setUseCdn(context: common.UIAbilityContext, useCdn: boolean): Promise<void> {
    connectTagTranslationSettings().useCdn = useCdn
    await TagTranslationSettings.saveBoolean(context, KEY_USE_CDN, useCdn)
  }

  static async setEnabled(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
    connectTagTranslationSettings().enabled = enabled
    await TagTranslationSettings.saveBoolean(context, KEY_ENABLED, enabled)
  }

  static async setUpdateMode(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalized: string = TagTranslationSettings.normalizeMode(mode)
    connectTagTranslationSettings().updateMode = normalized
    try {
      const store: preferences.Preferences =
        await preferences.getPreferences(context, SETTINGS_STORE)
      store.putSync(KEY_UPDATE_MODE, normalized)
      store.flushSync()
    } catch (error) {
      ComicTranslationDiagnosticLogger.warn(
        'tag-translation',
        'update_mode_save_failed',
        (error as Error).message,
      )
    }
  }

  static async setIntroImageLevel(context: common.UIAbilityContext, level: string): Promise<void> {
    const normalized: string = TagTranslationSettings.normalizeIntroImageLevel(level)
    connectTagTranslationSettings().introImageLevel = normalized
    try {
      const store: preferences.Preferences =
        await preferences.getPreferences(context, SETTINGS_STORE)
      store.putSync(KEY_INTRO_IMAGE_LEVEL, normalized)
      store.flushSync()
    } catch (error) {
      ComicTranslationDiagnosticLogger.warn(
        'tag-translation',
        'intro_image_level_save_failed',
        (error as Error).message,
      )
    }
  }

  static async refreshStatus(context: common.UIAbilityContext): Promise<void> {
    const epoch: number = TagTranslationSettings.statusRefreshEpoch + 1
    TagTranslationSettings.statusRefreshEpoch = epoch
    let status: NhTagTranslationStatus
    try {
      status = await TagTranslationRepository.status(context)
    } catch (error) {
      ComicTranslationDiagnosticLogger.warn(
        'tag-translation',
        'status_refresh_failed',
        (error as Error).message,
      )
      return
    }
    if (epoch !== TagTranslationSettings.statusRefreshEpoch) {
      return
    }
    connectTagTranslationSettings().version = status.version
    connectTagTranslationSettings().rowCount = status.rowCount
  }

  static async updateNow(context: common.UIAbilityContext): Promise<number> {
    const status: NhTagTranslationStatus = await TagTranslationUpdateService.updateFromPublicRelease(
      context,
      true,
      connectTagTranslationSettings().useCdn,
    )
    await TagTranslationSettings.refreshStatus(context)
    return status.rowCount
  }

  static scheduleStartupUpdate(context: common.UIAbilityContext): void {
    const state = connectTagTranslationSettings()
    if (!state.enabled || state.updateMode !== TAG_TRANSLATION_UPDATE_EVERY_START) {
      return
    }
    setTimeout((): void => {
      TagTranslationSettings.updateNow(context)
        .then((count: number) => {
          ComicTranslationDiagnosticLogger.info(
            'tag-translation',
            'startup_update_done',
            count.toString(),
          )
        })
        .catch((error: Error) => {
          ComicTranslationDiagnosticLogger.warn(
            'tag-translation',
            'startup_update_failed',
            error.message,
          )
        })
    }, STARTUP_UPDATE_DELAY_MS)
  }

  private static normalizeMode(mode: string): string {
    return mode === TAG_TRANSLATION_UPDATE_EVERY_START
      ? TAG_TRANSLATION_UPDATE_EVERY_START
      : TAG_TRANSLATION_UPDATE_MANUAL
  }

  private static normalizeIntroImageLevel(level: string): string {
    switch (level) {
      case TAG_INTRO_IMAGE_DISABLE:
      case TAG_INTRO_IMAGE_R18:
      case TAG_INTRO_IMAGE_R18G:
        return level
      default:
        return TAG_INTRO_IMAGE_NON_H
    }
  }

  private static async saveBoolean(
    context: common.UIAbilityContext,
    key: string,
    value: boolean,
  ): Promise<void> {
    try {
      const store: preferences.Preferences =
        await preferences.getPreferences(context, SETTINGS_STORE)
      store.putSync(key, value)
      store.flushSync()
    } catch (error) {
      ComicTranslationDiagnosticLogger.warn(
        'tag-translation',
        'settings_save_failed',
        (error as Error).message,
      )
    }
  }
}
