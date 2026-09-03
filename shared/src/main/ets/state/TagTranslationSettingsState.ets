import { AppStorageV2 } from '@kit.ArkUI'

export const TAG_TRANSLATION_UPDATE_MANUAL: string = 'manual'
export const TAG_TRANSLATION_UPDATE_EVERY_START: string = 'everyStartApp'
export const TAG_INTRO_IMAGE_DISABLE: string = 'disable'
export const TAG_INTRO_IMAGE_NON_H: string = 'nonh'
export const TAG_INTRO_IMAGE_R18: string = 'r18'
export const TAG_INTRO_IMAGE_R18G: string = 'r18g'

/**
 * Durable tag-dictionary policy and display metadata. The dictionary rows
 * themselves stay in the RDB; this state carries only settings plus the
 * status summary shown by the settings page.
 */
@ObservedV2
export class TagTranslationSettingsState {
  @Trace enabled: boolean = false
  @Trace useCdn: boolean = false
  @Trace updateMode: string = TAG_TRANSLATION_UPDATE_MANUAL
  @Trace introImageLevel: string = TAG_INTRO_IMAGE_NON_H
  @Trace version: string = ''
  @Trace rowCount: number = 0
}

const TAG_TRANSLATION_SETTINGS_KEY: string = 'nextn_tag_translation_settings'

export function connectTagTranslationSettings(): TagTranslationSettingsState {
  return AppStorageV2.connect(
    TagTranslationSettingsState,
    TAG_TRANSLATION_SETTINGS_KEY,
    (): TagTranslationSettingsState => new TagTranslationSettingsState(),
  )!
}
