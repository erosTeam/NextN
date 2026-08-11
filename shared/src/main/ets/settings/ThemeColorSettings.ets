import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { connectThemeColor } from '../state/AppearanceState'

const APPEARANCE_STORE: string = 'nextn_appearance'
const THEME_COLOR_KEY: string = 'theme_color'

export interface ThemeColorOption {
  value: string
  labelKey: string
  color: ResourceColor
}

/**
 * The global accent owner. The system value is intentionally the default so
 * adding this capability preserves the app's existing Harmony appearance.
 */
export class ThemeColorSettings {
  static readonly COLOR_SYSTEM: string = 'system'
  static readonly COLOR_GALAXY_BLUE: string = 'galaxyBlue'
  static readonly COLOR_ORANGE_YELLOW: string = 'orangeYellow'
  static readonly COLOR_CAT_BLUE: string = 'catBlue'
  static readonly COLOR_HUAWEI_RED: string = 'huaweiRed'
  static readonly COLOR_ELEGANT_PURPLE: string = 'elegantPurple'
  static readonly COLOR_BILIBILI_PINK: string = 'bilibiliPink'
  static readonly COLOR_GRASS_GREEN: string = 'grassGreen'

  static options(): ThemeColorOption[] {
    return [
      {
        value: ThemeColorSettings.COLOR_SYSTEM,
        labelKey: 'appearance_follow_system',
        color: $r('sys.color.font_emphasize'),
      },
      {
        value: ThemeColorSettings.COLOR_GALAXY_BLUE,
        labelKey: 'theme_color_galaxy_blue',
        color: '#0958F7',
      },
      {
        value: ThemeColorSettings.COLOR_ORANGE_YELLOW,
        labelKey: 'theme_color_orange_yellow',
        color: '#FE9925',
      },
      {
        value: ThemeColorSettings.COLOR_CAT_BLUE,
        labelKey: 'theme_color_cat_blue',
        color: '#345483',
      },
      {
        value: ThemeColorSettings.COLOR_HUAWEI_RED,
        labelKey: 'theme_color_huawei_red',
        color: '#D9323B',
      },
      {
        value: ThemeColorSettings.COLOR_ELEGANT_PURPLE,
        labelKey: 'theme_color_elegant_purple',
        color: '#8143D6',
      },
      {
        value: ThemeColorSettings.COLOR_BILIBILI_PINK,
        labelKey: 'theme_color_bilibili_pink',
        color: '#FB80A5',
      },
      {
        value: ThemeColorSettings.COLOR_GRASS_GREEN,
        labelKey: 'theme_color_grass_green',
        color: '#8ED931',
      },
    ]
  }

  static normalize(value: string): string {
    for (const option of ThemeColorSettings.options()) {
      if (option.value === value) {
        return option.value
      }
    }
    return ThemeColorSettings.COLOR_SYSTEM
  }

  static labelKey(value: string): string {
    const normalized: string = ThemeColorSettings.normalize(value)
    for (const option of ThemeColorSettings.options()) {
      if (option.value === normalized) {
        return option.labelKey
      }
    }
    return 'appearance_follow_system'
  }

  static colorValue(value: string): ResourceColor {
    const normalized: string = ThemeColorSettings.normalize(value)
    for (const option of ThemeColorSettings.options()) {
      if (option.value === normalized) {
        return option.color
      }
    }
    return $r('sys.color.font_emphasize')
  }

  static currentColor(): ResourceColor {
    return ThemeColorSettings.colorValue(connectThemeColor().color)
  }

  static apply(value: string): void {
    connectThemeColor().color = ThemeColorSettings.normalize(value)
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    let color: string = ThemeColorSettings.COLOR_SYSTEM
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, APPEARANCE_STORE)
      color = store.getSync(THEME_COLOR_KEY, ThemeColorSettings.COLOR_SYSTEM) as string
    } catch (_error) {}
    ThemeColorSettings.apply(color)
  }

  static async setColor(context: common.UIAbilityContext, value: string): Promise<void> {
    const normalized: string = ThemeColorSettings.normalize(value)
    ThemeColorSettings.apply(normalized)
    const store: preferences.Preferences = await preferences.getPreferences(context, APPEARANCE_STORE)
    store.putSync(THEME_COLOR_KEY, normalized)
    store.flushSync()
  }
}
