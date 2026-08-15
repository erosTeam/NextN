import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ComicTranslationDiagnosticLogger } from '../services/ComicTranslationDiagnosticLogger'
import {
  COMMENT_TRANSLATION_DISPLAY_BILINGUAL,
  COMMENT_TRANSLATION_DISPLAY_REPLACE,
  connectCommentTranslationSettings,
} from '../state/CommentTranslationSettingsState'

const SETTINGS_STORE: string = 'nextn_settings'
const KEY_ENABLED: string = 'comment_translation_enabled'
const KEY_AUTO: string = 'comment_translation_auto'
const KEY_DISPLAY_MODE: string = 'comment_translation_display_mode'

/** Preferences-backed comment translation policy, matching the NextE page leafs. */
export class CommentTranslationSettings {
  static normalizeDisplayMode(mode: string): string {
    return mode === COMMENT_TRANSLATION_DISPLAY_BILINGUAL
      ? COMMENT_TRANSLATION_DISPLAY_BILINGUAL
      : COMMENT_TRANSLATION_DISPLAY_REPLACE
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences =
        await preferences.getPreferences(context, SETTINGS_STORE)
      connectCommentTranslationSettings().enabled =
        store.getSync(KEY_ENABLED, true) as boolean
      connectCommentTranslationSettings().autoTranslate =
        store.getSync(KEY_AUTO, false) as boolean
      connectCommentTranslationSettings().displayMode = CommentTranslationSettings.normalizeDisplayMode(
        store.getSync(KEY_DISPLAY_MODE, COMMENT_TRANSLATION_DISPLAY_REPLACE) as string,
      )
    } catch (error) {
      ComicTranslationDiagnosticLogger.warn(
        'comment-translation',
        'settings_restore_failed',
        (error as Error).message,
      )
    }
  }

  static async setEnabled(context: common.UIAbilityContext, enabled: boolean): Promise<void> {
    connectCommentTranslationSettings().enabled = enabled
    await CommentTranslationSettings.saveBoolean(context, KEY_ENABLED, enabled)
  }

  static async setAutoTranslate(context: common.UIAbilityContext, auto: boolean): Promise<void> {
    connectCommentTranslationSettings().autoTranslate = auto
    await CommentTranslationSettings.saveBoolean(context, KEY_AUTO, auto)
  }

  static async setDisplayMode(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalized: string = CommentTranslationSettings.normalizeDisplayMode(mode)
    connectCommentTranslationSettings().displayMode = normalized
    try {
      const store: preferences.Preferences =
        await preferences.getPreferences(context, SETTINGS_STORE)
      store.putSync(KEY_DISPLAY_MODE, normalized)
      store.flushSync()
    } catch (error) {
      ComicTranslationDiagnosticLogger.warn(
        'comment-translation',
        'display_mode_save_failed',
        (error as Error).message,
      )
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
        'comment-translation',
        'settings_save_failed',
        (error as Error).message,
      )
    }
  }
}
