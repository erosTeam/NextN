import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import {
  connectGalleryDetailTransitionSettings,
  GalleryDetailTransitionMode,
  GalleryDetailTransitionSettingsState,
} from '../state/GalleryDetailTransitionSettingsState'

const LAYOUT_STORE: string = 'nextn_layout'
const DETAIL_MODE_KEY: string = 'gallery_detail_transition_mode'
const LEGACY_DETAIL_ENABLED_KEY: string = 'gallery_detail_transition_enabled'
const READER_THUMBNAIL_ENABLED_KEY: string = 'reader_thumbnail_transition_enabled'

/** Single persistence writer for Gallery Detail and Reader thumbnail transitions. */
export class GalleryDetailTransitionSettings {
  static readonly DEFAULT_MODE: string = GalleryDetailTransitionMode.SEAMLESS

  static normalize(mode: string): string {
    if (
      mode === GalleryDetailTransitionMode.SYSTEM ||
      mode === GalleryDetailTransitionMode.SEAMLESS ||
      mode === GalleryDetailTransitionMode.COVER_EXPAND
    ) {
      return mode
    }
    return GalleryDetailTransitionSettings.DEFAULT_MODE
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, LAYOUT_STORE)
      const state: GalleryDetailTransitionSettingsState = connectGalleryDetailTransitionSettings()
      const storedMode: string = store.getSync(DETAIL_MODE_KEY, '') as string
      if (storedMode.length > 0) {
        state.mode = GalleryDetailTransitionSettings.normalize(storedMode)
      } else {
        const legacyEnabled: boolean = store.getSync(LEGACY_DETAIL_ENABLED_KEY, true) as boolean
        state.mode = legacyEnabled
          ? GalleryDetailTransitionMode.SEAMLESS
          : GalleryDetailTransitionMode.SYSTEM
      }
      state.readerThumbnailEnabled = store.getSync(
        READER_THUMBNAIL_ENABLED_KEY,
        state.mode !== GalleryDetailTransitionMode.SYSTEM,
      ) as boolean
    } catch (_error) {}
  }

  static async setMode(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalized: string = GalleryDetailTransitionSettings.normalize(mode)
    connectGalleryDetailTransitionSettings().mode = normalized
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, LAYOUT_STORE)
      store.putSync(DETAIL_MODE_KEY, normalized)
      store.putSync(LEGACY_DETAIL_ENABLED_KEY, normalized !== GalleryDetailTransitionMode.SYSTEM)
      store.flushSync()
    } catch (_error) {}
  }

  static async setReaderThumbnailEnabled(
    context: common.UIAbilityContext,
    enabled: boolean,
  ): Promise<void> {
    connectGalleryDetailTransitionSettings().readerThumbnailEnabled = enabled
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, LAYOUT_STORE)
      store.putSync(READER_THUMBNAIL_ENABLED_KEY, enabled)
      store.flushSync()
    } catch (_error) {}
  }
}
