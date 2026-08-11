import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

const RENDERING_SERVICE_STORE: string = 'nextn_manga_rendering_service'
const BASE_URL_KEY: string = 'base_url'
const DETECTION_PROFILE_KEY: string = 'detection_profile'
const INPAINTING_PROFILE_KEY: string = 'inpainting_profile'
const ENABLED_KEY: string = 'enabled'

export const MANGA_RENDERING_DETECTION_HIGH_RECALL: string = 'high_recall'
export const MANGA_RENDERING_DETECTION_BALANCED: string = 'balanced'
export const MANGA_RENDERING_INPAINTING_QUALITY: string = 'quality'
export const MANGA_RENDERING_INPAINTING_FAST: string = 'fast'

/** Non-secret endpoint and rendering-profile preference for the optional sidecar. */
export class MangaRenderingServiceSettingsSnapshot {
  baseUrl: string = ''
  detectionProfile: string = MANGA_RENDERING_DETECTION_HIGH_RECALL
  inpaintingProfile: string = MANGA_RENDERING_INPAINTING_QUALITY
  enabled: boolean = false

  configured(): boolean {
    return this.baseUrl.length > 0
  }

  copy(): MangaRenderingServiceSettingsSnapshot {
    const result: MangaRenderingServiceSettingsSnapshot = new MangaRenderingServiceSettingsSnapshot()
    result.baseUrl = this.baseUrl
    result.detectionProfile = this.detectionProfile
    result.inpaintingProfile = this.inpaintingProfile
    result.enabled = this.enabled
    return result
  }
}

export class MangaRenderingServiceSettings {
  static normalizeBaseUrl(value: string): string {
    let result: string = typeof value === 'string' ? value.trim() : ''
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1)
    }
    return result
  }

  static normalizeDetectionProfile(value: string): string {
    return value === MANGA_RENDERING_DETECTION_BALANCED
      ? MANGA_RENDERING_DETECTION_BALANCED
      : MANGA_RENDERING_DETECTION_HIGH_RECALL
  }

  static normalizeInpaintingProfile(value: string): string {
    return value === MANGA_RENDERING_INPAINTING_FAST
      ? MANGA_RENDERING_INPAINTING_FAST
      : MANGA_RENDERING_INPAINTING_QUALITY
  }

  static async load(context: common.UIAbilityContext): Promise<MangaRenderingServiceSettingsSnapshot> {
    const store: preferences.Preferences = await preferences.getPreferences(context, RENDERING_SERVICE_STORE)
    const snapshot: MangaRenderingServiceSettingsSnapshot = new MangaRenderingServiceSettingsSnapshot()
    snapshot.baseUrl = MangaRenderingServiceSettings.normalizeBaseUrl(
      store.getSync(BASE_URL_KEY, '') as string,
    )
    snapshot.detectionProfile = MangaRenderingServiceSettings.normalizeDetectionProfile(
      store.getSync(DETECTION_PROFILE_KEY, MANGA_RENDERING_DETECTION_HIGH_RECALL) as string,
    )
    snapshot.inpaintingProfile = MangaRenderingServiceSettings.normalizeInpaintingProfile(
      store.getSync(INPAINTING_PROFILE_KEY, MANGA_RENDERING_INPAINTING_QUALITY) as string,
    )
    snapshot.enabled = store.getSync(ENABLED_KEY, false) as boolean
    return snapshot
  }

  static async save(
    context: common.UIAbilityContext,
    snapshot: MangaRenderingServiceSettingsSnapshot,
  ): Promise<void> {
    const baseUrl: string = MangaRenderingServiceSettings.normalizeBaseUrl(snapshot.baseUrl)
    const store: preferences.Preferences = await preferences.getPreferences(context, RENDERING_SERVICE_STORE)
    if (baseUrl.length === 0) {
      store.deleteSync(BASE_URL_KEY)
    } else {
      store.putSync(BASE_URL_KEY, baseUrl)
    }
    store.putSync(
      DETECTION_PROFILE_KEY,
      MangaRenderingServiceSettings.normalizeDetectionProfile(snapshot.detectionProfile),
    )
    store.putSync(
      INPAINTING_PROFILE_KEY,
      MangaRenderingServiceSettings.normalizeInpaintingProfile(snapshot.inpaintingProfile),
    )
    store.putSync(ENABLED_KEY, snapshot.enabled === true)
    store.flushSync()
  }
}
