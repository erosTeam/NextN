export interface ActionFollowTouchState {
  active: boolean
  startX: number
  startY: number
  latestX: number
  latestY: number
  reported: boolean
}

export interface ActionFollowTouchUpdate {
  state: ActionFollowTouchState
  shouldReport: boolean
  reportX: number
}

/** Filters ordinary taps out of the one-shot follow-operation side decision. */
export class ActionFollowTouchTracker {
  static initialState(): ActionFollowTouchState {
    return {
      active: false,
      startX: 0,
      startY: 0,
      latestX: 0,
      latestY: 0,
      reported: false,
    }
  }

  static update(
    state: ActionFollowTouchState,
    type: TouchType,
    x: number,
    y: number,
    verticalThreshold: number,
    verticalDominanceRatio: number,
  ): ActionFollowTouchUpdate {
    if (type === TouchType.Down) {
      return {
        state: { active: true, startX: x, startY: y, latestX: x, latestY: y, reported: false },
        shouldReport: false,
        reportX: 0,
      }
    }
    if (!state.active) {
      return { state, shouldReport: false, reportX: 0 }
    }
    if (type === TouchType.Up || type === TouchType.Cancel) {
      return { state: ActionFollowTouchTracker.initialState(), shouldReport: false, reportX: 0 }
    }
    if (type !== TouchType.Move) {
      return { state, shouldReport: false, reportX: 0 }
    }
    const nextState: ActionFollowTouchState = {
      active: true,
      startX: state.startX,
      startY: state.startY,
      latestX: x,
      latestY: y,
      reported: state.reported,
    }
    if (state.reported) {
      return { state: nextState, shouldReport: false, reportX: 0 }
    }
    const dx: number = x - state.startX
    const dy: number = y - state.startY
    const absDx: number = Math.abs(dx)
    const absDy: number = Math.abs(dy)
    if (absDy < verticalThreshold || absDy < absDx * verticalDominanceRatio) {
      return { state: nextState, shouldReport: false, reportX: 0 }
    }
    nextState.reported = true
    return { state: nextState, shouldReport: true, reportX: state.startX }
  }
}
