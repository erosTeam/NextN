import { AppStorageV2 } from '@kit.ArkUI'

/** Persisted user intent plus the current runtime support result for Read-action alignment. */
@ObservedV2
export class ActionAlignmentState {
  @Trace alignmentMode: string = ''
  @Trace holdingHandSupported: boolean = false
}

const ACTION_ALIGNMENT_STATE_KEY: string = 'nextn_action_alignment'

export function connectActionAlignment(): ActionAlignmentState {
  return AppStorageV2.connect(
    ActionAlignmentState,
    ACTION_ALIGNMENT_STATE_KEY,
    (): ActionAlignmentState => new ActionAlignmentState(),
  )!
}
