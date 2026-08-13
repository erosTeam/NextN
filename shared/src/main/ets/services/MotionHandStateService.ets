import { motion } from '@kit.MultimodalAwarenessKit'
import { ActionAlignmentMode, ActionAlignmentSettings } from '../settings/ActionAlignmentSettings'
import { connectActionAlignment } from '../state/ActionAlignmentState'
import { connectActionHandEdge } from '../state/ActionHandEdgeState'

export type MotionHandEdge = 'left' | 'right'

/**
 * The one resolver from persisted alignment intent to a concrete Detail Read
 * edge. Holding-hand sensing is best-effort: failure leaves the button usable
 * and makes smart grip behave as follow operation.
 */
export class MotionHandStateService {
  private static startAttempted: boolean = false
  private static holdingSubscribed: boolean = false
  private static pendingHoldingEdge: MotionHandEdge | null = null
  private static debounceTimerId: number = 0
  private static lastFollowUpdateAt: number = 0
  private static readonly EDGE_DEBOUNCE_MS: number = 450
  static readonly FOLLOW_OPERATION_SAFE_ZONE_RATIO: number = 0.28
  private static readonly FOLLOW_OPERATION_THROTTLE_MS: number = 260

  private static readonly holdingChanged = (status: motion.HoldingHandStatus): void => {
    MotionHandStateService.handleHoldingStatus(status)
  }

  static start(): void {
    MotionHandStateService.ensureDefaultEdge()
    if (MotionHandStateService.startAttempted) {
      MotionHandStateService.applyAlignmentMode()
      return
    }
    MotionHandStateService.startAttempted = true
    try {
      motion.on('holdingHandChanged', MotionHandStateService.holdingChanged)
      MotionHandStateService.holdingSubscribed = true
      MotionHandStateService.setHoldingHandSupported(true)
    } catch (_error) {
      MotionHandStateService.setHoldingHandSupported(false)
    }
    MotionHandStateService.applyAlignmentMode()
  }

  static stop(): void {
    if (MotionHandStateService.holdingSubscribed) {
      try {
        motion.off('holdingHandChanged', MotionHandStateService.holdingChanged)
      } catch (_error) {}
      MotionHandStateService.holdingSubscribed = false
    }
    MotionHandStateService.cancelPendingEdge()
    MotionHandStateService.startAttempted = false
  }

  static applyAlignmentMode(mode?: string): void {
    const alignment = connectActionAlignment()
    if (mode !== undefined) {
      alignment.alignmentMode = ActionAlignmentSettings.normalizeMode(mode)
    }
    MotionHandStateService.ensureDefaultEdge()
    if (ActionAlignmentSettings.normalizeMode(alignment.alignmentMode) === ActionAlignmentSettings.MODE_UNSET) {
      alignment.alignmentMode = ActionAlignmentSettings.defaultMode(
        MotionHandStateService.isHoldingHandSupported(),
      )
    }
    const effectiveMode: ActionAlignmentMode = MotionHandStateService.effectiveAlignmentMode()
    if (effectiveMode === ActionAlignmentSettings.MODE_FIXED_LEFT) {
      MotionHandStateService.cancelPendingEdge()
      MotionHandStateService.setEdge('left')
      return
    }
    if (effectiveMode === ActionAlignmentSettings.MODE_FIXED_RIGHT) {
      MotionHandStateService.cancelPendingEdge()
      MotionHandStateService.setEdge('right')
      return
    }
    if (effectiveMode !== ActionAlignmentSettings.MODE_SMART_GRIP) {
      MotionHandStateService.cancelPendingEdge()
    }
  }

  static reportFollowOperationX(x: number, width: number): void {
    if (MotionHandStateService.effectiveAlignmentMode() !== ActionAlignmentSettings.MODE_FOLLOW_OPERATION) {
      return
    }
    const nextEdge: MotionHandEdge | null = MotionHandStateService.edgeForFollowOperationX(x, width)
    if (nextEdge === null) {
      return
    }
    const now: number = Date.now()
    if (
      MotionHandStateService.lastFollowUpdateAt > 0 &&
      now - MotionHandStateService.lastFollowUpdateAt < MotionHandStateService.FOLLOW_OPERATION_THROTTLE_MS &&
      connectActionHandEdge().edge !== nextEdge
    ) {
      return
    }
    MotionHandStateService.lastFollowUpdateAt = now
    if (connectActionHandEdge().edge !== nextEdge) {
      MotionHandStateService.setEdge(nextEdge)
    }
  }

  static edgeForFollowOperationX(x: number, width: number): MotionHandEdge | null {
    if (!Number.isFinite(x) || !Number.isFinite(width) || width <= 0) {
      return null
    }
    const safeHalf: number = MotionHandStateService.FOLLOW_OPERATION_SAFE_ZONE_RATIO / 2
    const leftBoundary: number = width * (0.5 - safeHalf)
    const rightBoundary: number = width * (0.5 + safeHalf)
    if (x < leftBoundary) {
      return 'left'
    }
    if (x > rightBoundary) {
      return 'right'
    }
    return null
  }

  private static effectiveAlignmentMode(): ActionAlignmentMode {
    return ActionAlignmentSettings.effectiveMode(
      connectActionAlignment().alignmentMode,
      MotionHandStateService.isHoldingHandSupported(),
    )
  }

  private static isHoldingHandSupported(): boolean {
    return connectActionAlignment().holdingHandSupported
  }

  private static setHoldingHandSupported(supported: boolean): void {
    connectActionAlignment().holdingHandSupported = supported
  }

  private static ensureDefaultEdge(): void {
    const current: string = connectActionHandEdge().edge
    if (current !== 'left' && current !== 'right') {
      MotionHandStateService.setEdge('right')
    }
  }

  private static handleHoldingStatus(status: motion.HoldingHandStatus): void {
    if (MotionHandStateService.effectiveAlignmentMode() !== ActionAlignmentSettings.MODE_SMART_GRIP) {
      return
    }
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
      MotionHandStateService.scheduleHoldingEdge('left')
      return
    }
    if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) {
      MotionHandStateService.scheduleHoldingEdge('right')
    }
  }

  private static scheduleHoldingEdge(edge: MotionHandEdge): void {
    MotionHandStateService.pendingHoldingEdge = edge
    if (MotionHandStateService.debounceTimerId > 0) {
      return
    }
    MotionHandStateService.debounceTimerId = setTimeout((): void => {
      MotionHandStateService.flushPendingEdge()
    }, MotionHandStateService.EDGE_DEBOUNCE_MS)
  }

  private static flushPendingEdge(): void {
    const nextEdge: MotionHandEdge | null = MotionHandStateService.pendingHoldingEdge
    MotionHandStateService.debounceTimerId = 0
    MotionHandStateService.pendingHoldingEdge = null
    if (
      nextEdge !== null &&
      MotionHandStateService.effectiveAlignmentMode() === ActionAlignmentSettings.MODE_SMART_GRIP &&
      connectActionHandEdge().edge !== nextEdge
    ) {
      MotionHandStateService.setEdge(nextEdge)
    }
  }

  private static cancelPendingEdge(): void {
    if (MotionHandStateService.debounceTimerId > 0) {
      clearTimeout(MotionHandStateService.debounceTimerId)
      MotionHandStateService.debounceTimerId = 0
    }
    MotionHandStateService.pendingHoldingEdge = null
  }

  private static setEdge(edge: MotionHandEdge): void {
    connectActionHandEdge().edge = edge
  }
}
