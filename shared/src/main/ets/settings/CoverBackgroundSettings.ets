import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { connectCoverBackground } from '../state/CoverBackgroundState'

const LAYOUT_STORE: string = 'nextn_layout'
const COVER_BACKGROUND_BLUR_KEY: string = 'cover_background_blur'

/** Durable NextE-style opt-in blur for contain-fitted gallery cover gaps. */
export class CoverBackgroundSettings {
  static readonly DEFAULT_BLUR_LETTERBOX_BACKGROUND: boolean = false

  static apply(blurLetterboxBackground: boolean): void {
    connectCoverBackground().blurLetterboxBackground = blurLetterboxBackground
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    let blurLetterboxBackground: boolean = CoverBackgroundSettings.DEFAULT_BLUR_LETTERBOX_BACKGROUND
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, LAYOUT_STORE)
      blurLetterboxBackground = store.getSync(
        COVER_BACKGROUND_BLUR_KEY,
        CoverBackgroundSettings.DEFAULT_BLUR_LETTERBOX_BACKGROUND,
      ) as boolean
    } catch (_error) {}
    CoverBackgroundSettings.apply(blurLetterboxBackground)
  }

  static async save(context: common.UIAbilityContext, blurLetterboxBackground: boolean): Promise<void> {
    CoverBackgroundSettings.apply(blurLetterboxBackground)
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, LAYOUT_STORE)
      store.putSync(COVER_BACKGROUND_BLUR_KEY, blurLetterboxBackground)
      store.flushSync()
    } catch (_error) {}
  }
}
