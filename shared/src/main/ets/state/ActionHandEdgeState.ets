import { AppStorageV2 } from '@kit.ArkUI'

/** The resolved side of the floating Detail Read action. MotionHandStateService is its sole writer. */
@ObservedV2
export class ActionHandEdgeState {
  @Trace edge: string = 'right'
}

const ACTION_HAND_EDGE_STATE_KEY: string = 'nextn_action_hand_edge'

export function connectActionHandEdge(): ActionHandEdgeState {
  return AppStorageV2.connect(
    ActionHandEdgeState,
    ACTION_HAND_EDGE_STATE_KEY,
    (): ActionHandEdgeState => new ActionHandEdgeState(),
  )!
}
