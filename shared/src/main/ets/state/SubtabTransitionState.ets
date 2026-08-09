import { AppStorageV2 } from '@kit.ArkUI'

/**
 * A pinned HDS selector lives in a different component tree from its retained
 * page host. This one-shot channel carries only the transition intent; the
 * host publishes the semantic selected key after native Swiper settlement.
 */
@ObservedV2
export class SubtabTransitionState {
  @Trace scope: string = ''
  @Trace targetKey: string = ''
  @Trace requestSeq: number = 0
}

export const SUBTAB_TRANSITION_SCOPE_HOME: string = 'nextn_home_source'

const SUBTAB_TRANSITION_STATE_KEY: string = 'nextn_subtab_transition'

export function connectSubtabTransition(): SubtabTransitionState {
  return AppStorageV2.connect(
    SubtabTransitionState,
    SUBTAB_TRANSITION_STATE_KEY,
    () => new SubtabTransitionState(),
  )!
}

export class SubtabTransitionBridge {
  static request(scope: string, targetKey: string): void {
    const state: SubtabTransitionState = connectSubtabTransition()
    state.scope = scope
    state.targetKey = targetKey
    state.requestSeq = state.requestSeq + 1
  }
}
