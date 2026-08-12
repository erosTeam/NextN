import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { connectAppColorFavorites } from '../state/AppColorFavoritesState'

const APPEARANCE_STORE: string = 'nextn_appearance'
const FAVORITES_KEY: string = 'theme_color_favorites'
const MAX_APP_COLOR_FAVORITES: number = 36

/** Separate durable owner for custom-picker favourites. */
export class AppColorFavoritesSettings {
  static async restore(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, APPEARANCE_STORE)
      const raw: string = store.getSync(FAVORITES_KEY, '') as string
      const colors: string[] | null = AppColorFavoritesSettings.parse(raw)
      if (colors !== null) {
        connectAppColorFavorites().colors = colors
      }
    } catch (_error) {}
  }

  static async persist(context: common.UIAbilityContext, colors: string[]): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, APPEARANCE_STORE)
      store.putSync(FAVORITES_KEY, JSON.stringify(AppColorFavoritesSettings.clean(colors)))
      store.flushSync()
    } catch (_error) {}
  }

  private static parse(raw: string): string[] | null {
    if (raw.length === 0) {
      return null
    }
    try {
      const parsed: Object = JSON.parse(raw) as Object
      return Array.isArray(parsed) ? AppColorFavoritesSettings.clean(parsed as string[]) : null
    } catch (_error) {
      return null
    }
  }

  private static clean(colors: string[]): string[] {
    const next: string[] = []
    colors.forEach((color: string): void => {
      const normalized: string = AppColorFavoritesSettings.normalizedHex(color)
      if (normalized.length > 0 && next.indexOf(normalized) < 0 && next.length < MAX_APP_COLOR_FAVORITES) {
        next.push(normalized)
      }
    })
    return next
  }

  private static normalizedHex(color: string): string {
    let value: string = color.trim()
    if (value.startsWith('#')) {
      value = value.substring(1)
    }
    if (value.length !== 6) {
      return ''
    }
    for (let index: number = 0; index < value.length; index += 1) {
      const code: number = value.charCodeAt(index)
      if (!((code >= 48 && code <= 57) || (code >= 65 && code <= 70) || (code >= 97 && code <= 102))) {
        return ''
      }
    }
    return `#${value.toUpperCase()}`
  }
}
