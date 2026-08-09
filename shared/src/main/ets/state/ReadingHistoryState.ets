import { AppStorageV2 } from '@kit.ArkUI'

const READING_HISTORY_STATE_KEY: string = 'nextn_reading_history'

/**
 * Non-sensitive invalidation signal for the local RDB-backed reading history.
 *
 * Rows and cursor state stay page-owned; this bridge carries no gallery data
 * and only tells a retained History surface that a completed local mutation
 * may have changed its bounded query result.
 */
@ObservedV2
export class ReadingHistoryState {
  @Trace revision: number = 0

  publishMutation(): void {
    this.revision += 1
  }
}

export function connectReadingHistory(): ReadingHistoryState {
  return AppStorageV2.connect(
    ReadingHistoryState,
    READING_HISTORY_STATE_KEY,
    (): ReadingHistoryState => new ReadingHistoryState(),
  )!
}
