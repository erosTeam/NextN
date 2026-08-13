import { AppStorageV2 } from '@kit.ArkUI'

const MANGA_RENDERING_SERVICE_STATE_KEY: string = 'nextn_manga_rendering_service'

/**
 * Non-secret selection state for the optional self-hosted Reader renderer.
 * The endpoint and account remain in Preferences/HUKS; Reader only consumes
 * a restored availability flag, credential generation, and local epoch.
 */
@ObservedV2
export class MangaRenderingServiceState {
  @Trace initialized: boolean = false
  @Trace enabled: boolean = false
  @Trace credentialRevision: number = 1
  @Trace selectionEpoch: number = 0

  publishSnapshot(enabled: boolean, credentialRevision: number): void {
    this.initialized = true
    this.enabled = enabled === true
    this.credentialRevision = Number.isFinite(credentialRevision) && credentialRevision > 0 &&
      Math.floor(credentialRevision) === credentialRevision &&
      credentialRevision <= Number.MAX_SAFE_INTEGER
      ? credentialRevision
      : 1
    this.selectionEpoch += 1
  }
}

export function connectMangaRenderingService(): MangaRenderingServiceState {
  return AppStorageV2.connect(
    MangaRenderingServiceState,
    MANGA_RENDERING_SERVICE_STATE_KEY,
    (): MangaRenderingServiceState => new MangaRenderingServiceState(),
  )!
}
