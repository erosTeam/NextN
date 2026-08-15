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

/** Global accent owner for the explicit NextE-aligned preset and Custom values. */
export class ThemeColorSettings {
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

  static isCustom(value: string): boolean {
    return /^#[0-9a-fA-F]{6}$/.test(value.trim())
  }

  static normalize(value: string): string {
    const candidate: string = value.trim()
    if (ThemeColorSettings.isCustom(candidate)) {
      return candidate.toUpperCase()
    }
    for (const option of ThemeColorSettings.options()) {
      if (option.value === candidate) {
        return option.value
      }
    }
    return ThemeColorSettings.COLOR_GALAXY_BLUE
  }

  static labelKey(value: string): string {
    const normalized: string = ThemeColorSettings.normalize(value)
    if (ThemeColorSettings.isCustom(normalized)) {
      return 'theme_color_custom'
    }
    for (const option of ThemeColorSettings.options()) {
      if (option.value === normalized) {
        return option.labelKey
      }
    }
    return 'theme_color_galaxy_blue'
  }

  static colorValue(value: string): ResourceColor {
    const normalized: string = ThemeColorSettings.normalize(value)
    if (ThemeColorSettings.isCustom(normalized)) {
      return normalized
    }
    for (const option of ThemeColorSettings.options()) {
      if (option.value === normalized) {
        return option.color
      }
    }
    return '#0958F7'
  }

  /** Uses the active explicit accent as the Custom picker seed. */
  static customSeed(value: string): string {
    const normalized: string = ThemeColorSettings.normalize(value)
    if (ThemeColorSettings.isCustom(normalized)) {
      return normalized
    }
    for (const option of ThemeColorSettings.options()) {
      if (option.value === normalized && typeof option.color === 'string') {
        return option.color
      }
    }
    return '#0958F7'
  }

  static currentColor(): ResourceColor {
    return ThemeColorSettings.colorValue(connectThemeColor().color)
  }

  static apply(value: string): void {
    connectThemeColor().color = ThemeColorSettings.normalize(value)
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    let color: string = ThemeColorSettings.COLOR_GALAXY_BLUE
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, APPEARANCE_STORE)
      const storedColor: string = store.getSync(
        THEME_COLOR_KEY,
        ThemeColorSettings.COLOR_GALAXY_BLUE,
      ) as string
      color = ThemeColorSettings.normalize(storedColor)
      if (color !== storedColor) {
        store.putSync(THEME_COLOR_KEY, color)
        store.flushSync()
      }
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
