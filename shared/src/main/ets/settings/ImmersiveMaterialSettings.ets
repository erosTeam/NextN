import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { hdsMaterial } from '@kit.UIDesignKit'
import { connectImmersiveMaterialSettings } from '../state/ImmersiveMaterialSettingsState'

const APPEARANCE_STORE: string = 'nextn_appearance'
const IMMERSIVE_MATERIAL_LEVEL_KEY: string = 'immersive_material_level'
const LEVEL_ADAPTIVE: string = 'adaptive'
const LEVEL_EXQUISITE: string = 'exquisite'
const LEVEL_GENTLE: string = 'gentle'
const LEVEL_SMOOTH: string = 'smooth'

export interface ImmersiveMaterialOption {
  label: ResourceStr
  value: string
}

export interface ImmersiveMaterialEffect {
  materialType: hdsMaterial.MaterialType
  materialLevel: hdsMaterial.MaterialLevel
}

/**
 * NextE-compatible HDS material preference. Custom grades are only presented
 * when the running device reports IMMERSIVE support; a saved grade still
 * degrades to the official ADAPTIVE pair on unsupported hardware.
 */
export class ImmersiveMaterialSettings {
  static readonly LEVEL_ADAPTIVE: string = LEVEL_ADAPTIVE
  static readonly LEVEL_EXQUISITE: string = LEVEL_EXQUISITE
  static readonly LEVEL_GENTLE: string = LEVEL_GENTLE
  static readonly LEVEL_SMOOTH: string = LEVEL_SMOOTH
  static readonly DEFAULT_LEVEL: string = LEVEL_ADAPTIVE

  static options(): ImmersiveMaterialOption[] {
    const options: ImmersiveMaterialOption[] = [
      { label: $r('app.string.common_auto'), value: LEVEL_ADAPTIVE },
    ]
    if (ImmersiveMaterialSettings.immersiveSupported()) {
      options.push(
        { label: $r('app.string.immersive_material_exquisite'), value: LEVEL_EXQUISITE },
        { label: $r('app.string.immersive_material_gentle'), value: LEVEL_GENTLE },
        { label: $r('app.string.immersive_material_smooth'), value: LEVEL_SMOOTH },
      )
    }
    return options
  }

  static immersiveSupported(): boolean {
    try {
      const types: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes()
      for (let index = 0; index < types.length; index += 1) {
        if (types[index] === hdsMaterial.MaterialType.IMMERSIVE) {
          return true
        }
      }
      return false
    } catch (_error) {
      // Match NextE's forward-compatible behavior for a platform probe that
      // is present at the compatible SDK level but temporarily unavailable.
      return true
    }
  }

  static normalizeLevel(level: string): string {
    const value: string = (level || '').trim()
    if (value === LEVEL_EXQUISITE || value === LEVEL_GENTLE || value === LEVEL_SMOOTH) {
      return value
    }
    return LEVEL_ADAPTIVE
  }

  static apply(level: string): void {
    connectImmersiveMaterialSettings().level = ImmersiveMaterialSettings.normalizeLevel(level)
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    let level: string = ImmersiveMaterialSettings.DEFAULT_LEVEL
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, APPEARANCE_STORE)
      level = store.getSync(
        IMMERSIVE_MATERIAL_LEVEL_KEY,
        ImmersiveMaterialSettings.DEFAULT_LEVEL,
      ) as string
    } catch (_error) {}
    ImmersiveMaterialSettings.apply(level)
  }

  static async setLevel(context: common.UIAbilityContext, level: string): Promise<void> {
    const normalized: string = ImmersiveMaterialSettings.normalizeLevel(level)
    ImmersiveMaterialSettings.apply(normalized)
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, APPEARANCE_STORE)
      store.putSync(IMMERSIVE_MATERIAL_LEVEL_KEY, normalized)
      store.flushSync()
    } catch (_error) {}
  }

  static label(level: string): ResourceStr {
    const normalized: string = ImmersiveMaterialSettings.normalizeLevel(level)
    if (normalized === LEVEL_EXQUISITE) {
      return $r('app.string.immersive_material_exquisite')
    }
    if (normalized === LEVEL_GENTLE) {
      return $r('app.string.immersive_material_gentle')
    }
    if (normalized === LEVEL_SMOOTH) {
      return $r('app.string.immersive_material_smooth')
    }
    return $r('app.string.common_auto')
  }

  static effect(level: string): ImmersiveMaterialEffect {
    const normalized: string = ImmersiveMaterialSettings.normalizeLevel(level)
    if (!ImmersiveMaterialSettings.immersiveSupported()) {
      return {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
      }
    }
    if (normalized === LEVEL_EXQUISITE) {
      return {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.EXQUISITE,
      }
    }
    if (normalized === LEVEL_GENTLE) {
      return {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.GENTLE,
      }
    }
    if (normalized === LEVEL_SMOOTH) {
      return {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.SMOOTH,
      }
    }
    return {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
    }
  }
}
