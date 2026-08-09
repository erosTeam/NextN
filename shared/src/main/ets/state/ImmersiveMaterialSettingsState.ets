import { AppStorageV2 } from '@kit.ArkUI'

/** Reactive user intent for HDS immersive-material intensity. */
@ObservedV2
export class ImmersiveMaterialSettingsState {
  @Trace level: string = 'adaptive'
}

const IMMERSIVE_MATERIAL_SETTINGS_STATE_KEY: string = 'nextn_immersive_material_settings'

/** Returns the one app-wide material preference consumed by HDS title and floating-bar surfaces. */
export function connectImmersiveMaterialSettings(): ImmersiveMaterialSettingsState {
  return AppStorageV2.connect(
    ImmersiveMaterialSettingsState,
    IMMERSIVE_MATERIAL_SETTINGS_STATE_KEY,
    () => new ImmersiveMaterialSettingsState(),
  )!
}
