import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { connectGalleryTitle } from '../state/GalleryTitleState'

const LAYOUT_STORE: string = 'nextn_layout'
const GALLERY_TITLE_JAPANESE_PRIMARY_KEY: string = 'gallery_title_japanese_primary'

/** Durable display preference; no gallery request or record is changed. */
export class GalleryTitleSettings {
  static readonly DEFAULT_JAPANESE_TITLE_PRIMARY: boolean = false

  static apply(japaneseTitlePrimary: boolean): void {
    connectGalleryTitle().japaneseTitlePrimary = japaneseTitlePrimary
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    let japaneseTitlePrimary: boolean = GalleryTitleSettings.DEFAULT_JAPANESE_TITLE_PRIMARY
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, LAYOUT_STORE)
      japaneseTitlePrimary = store.getSync(
        GALLERY_TITLE_JAPANESE_PRIMARY_KEY,
        GalleryTitleSettings.DEFAULT_JAPANESE_TITLE_PRIMARY,
      ) as boolean
    } catch (_error) {}
    GalleryTitleSettings.apply(japaneseTitlePrimary)
  }

  static async save(context: common.UIAbilityContext, japaneseTitlePrimary: boolean): Promise<void> {
    GalleryTitleSettings.apply(japaneseTitlePrimary)
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, LAYOUT_STORE)
      store.putSync(GALLERY_TITLE_JAPANESE_PRIMARY_KEY, japaneseTitlePrimary)
      store.flushSync()
    } catch (_error) {}
  }
}
