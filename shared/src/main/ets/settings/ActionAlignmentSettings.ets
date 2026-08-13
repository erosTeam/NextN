import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { AppStrings } from '../i18n/AppStrings'
import { connectActionAlignment } from '../state/ActionAlignmentState'

const LAYOUT_STORE: string = 'nextn_layout'
const ACTION_ALIGNMENT_MODE_KEY: string = 'action_alignment_mode'

export type ActionAlignmentMode = 'smartGrip' | 'followOperation' | 'fixedLeft' | 'fixedRight' | ''

export interface ActionAlignmentOption {
  label: string
  mode: ActionAlignmentMode
}

/**
 * Durable user intent for the Gallery Detail floating Read action. The actual
 * left/right edge stays runtime-only and is resolved by MotionHandStateService.
 */
export class ActionAlignmentSettings {
  static readonly MODE_UNSET: ActionAlignmentMode = ''
  static readonly MODE_SMART_GRIP: ActionAlignmentMode = 'smartGrip'
  static readonly MODE_FOLLOW_OPERATION: ActionAlignmentMode = 'followOperation'
  static readonly MODE_FIXED_LEFT: ActionAlignmentMode = 'fixedLeft'
  static readonly MODE_FIXED_RIGHT: ActionAlignmentMode = 'fixedRight'

  static normalizeMode(mode: string): ActionAlignmentMode {
    const value: string = typeof mode === 'string' ? mode.trim() : ''
    if (
      value === ActionAlignmentSettings.MODE_SMART_GRIP ||
      value === ActionAlignmentSettings.MODE_FOLLOW_OPERATION ||
      value === ActionAlignmentSettings.MODE_FIXED_LEFT ||
      value === ActionAlignmentSettings.MODE_FIXED_RIGHT
    ) {
      return value as ActionAlignmentMode
    }
    return ActionAlignmentSettings.MODE_UNSET
  }

  static defaultMode(smartGripSupported: boolean): ActionAlignmentMode {
    return smartGripSupported
      ? ActionAlignmentSettings.MODE_SMART_GRIP
      : ActionAlignmentSettings.MODE_FOLLOW_OPERATION
  }

  static effectiveMode(mode: string, smartGripSupported: boolean): ActionAlignmentMode {
    const normalized: ActionAlignmentMode = ActionAlignmentSettings.normalizeMode(mode)
    if (normalized === ActionAlignmentSettings.MODE_UNSET) {
      return ActionAlignmentSettings.defaultMode(smartGripSupported)
    }
    if (normalized === ActionAlignmentSettings.MODE_SMART_GRIP && !smartGripSupported) {
      return ActionAlignmentSettings.MODE_FOLLOW_OPERATION
    }
    return normalized
  }

  static availableOptions(smartGripSupported: boolean): ActionAlignmentOption[] {
    const options: ActionAlignmentOption[] = []
    if (smartGripSupported) {
      options.push({
        label: AppStrings.get('smart_grip'),
        mode: ActionAlignmentSettings.MODE_SMART_GRIP,
      })
    }
    options.push({
      label: AppStrings.get('follow_operation'),
      mode: ActionAlignmentSettings.MODE_FOLLOW_OPERATION,
    })
    options.push({
      label: AppStrings.get('fixed_left'),
      mode: ActionAlignmentSettings.MODE_FIXED_LEFT,
    })
    options.push({
      label: AppStrings.get('fixed_right'),
      mode: ActionAlignmentSettings.MODE_FIXED_RIGHT,
    })
    return options
  }

  static modeLabel(mode: string, smartGripSupported: boolean): string {
    const effective: ActionAlignmentMode = ActionAlignmentSettings.effectiveMode(
      mode,
      smartGripSupported,
    )
    if (effective === ActionAlignmentSettings.MODE_SMART_GRIP) {
      return AppStrings.get('smart_grip')
    }
    if (effective === ActionAlignmentSettings.MODE_FIXED_LEFT) {
      return AppStrings.get('fixed_left')
    }
    if (effective === ActionAlignmentSettings.MODE_FIXED_RIGHT) {
      return AppStrings.get('fixed_right')
    }
    return AppStrings.get('follow_operation')
  }

  static apply(mode: string): void {
    connectActionAlignment().alignmentMode = ActionAlignmentSettings.normalizeMode(mode)
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    let mode: string = ActionAlignmentSettings.MODE_UNSET
    try {
      const store = await preferences.getPreferences(context, LAYOUT_STORE)
      mode = store.getSync(ACTION_ALIGNMENT_MODE_KEY, ActionAlignmentSettings.MODE_UNSET) as string
    } catch (_error) {}
    ActionAlignmentSettings.apply(mode)
  }

  static async save(context: common.UIAbilityContext, mode: string): Promise<void> {
    const normalized: ActionAlignmentMode = ActionAlignmentSettings.normalizeMode(mode)
    ActionAlignmentSettings.apply(normalized)
    try {
      const store = await preferences.getPreferences(context, LAYOUT_STORE)
      store.putSync(ACTION_ALIGNMENT_MODE_KEY, normalized)
      store.flushSync()
    } catch (_error) {}
  }
}
