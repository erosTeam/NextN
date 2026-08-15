import { AppStorageV2 } from '@kit.ArkUI'

export const COMMENT_TRANSLATION_DISPLAY_REPLACE: string = 'replace'
export const COMMENT_TRANSLATION_DISPLAY_BILINGUAL: string = 'bilingual'

/**
 * Non-sensitive comment translation policy. The LLM source binding itself
 * stays in LlmSourceProfilesState; this state only carries the on/off,
 * auto-translate, and display-mode choices owned by the settings page.
 */
@ObservedV2
export class CommentTranslationSettingsState {
  @Trace enabled: boolean = false
  @Trace autoTranslate: boolean = false
  @Trace displayMode: string = COMMENT_TRANSLATION_DISPLAY_REPLACE
}

const COMMENT_TRANSLATION_SETTINGS_KEY: string = 'nextn_comment_translation_settings'

export function connectCommentTranslationSettings(): CommentTranslationSettingsState {
  return AppStorageV2.connect(
    CommentTranslationSettingsState,
    COMMENT_TRANSLATION_SETTINGS_KEY,
    (): CommentTranslationSettingsState => new CommentTranslationSettingsState(),
  )!
}
