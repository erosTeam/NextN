import { AppStorageV2 } from '@kit.ArkUI'

/** App-wide presentation signals owned only by ThemeSettings and LanguageSettings. */
@ObservedV2
export class ThemeDisplayState {
  @Trace mode: string = 'system'
  @Trace effectiveDark: boolean = false
}

const THEME_DISPLAY_KEY: string = 'nextn_theme_display'

export function connectThemeDisplay(): ThemeDisplayState {
  return AppStorageV2.connect(
    ThemeDisplayState,
    THEME_DISPLAY_KEY,
    (): ThemeDisplayState => new ThemeDisplayState(),
  )!
}

/** Language state makes resource-backed computed labels update without an app restart. */
@ObservedV2
export class LanguageState {
  @Trace mode: string = 'system'
  @Trace effectiveLocale: string = ''
}

const LANGUAGE_STATE_KEY: string = 'nextn_language_state'

export function connectLanguageState(): LanguageState {
  return AppStorageV2.connect(
    LanguageState,
    LANGUAGE_STATE_KEY,
    (): LanguageState => new LanguageState(),
  )!
}
