import { AppStorageV2 } from '@kit.ArkUI'

/** Commands emitted by the root HDS title bar into the retained Downloads page. */
export class DownloadQueueAction {
  static readonly TOGGLE_SEARCH: string = 'toggle_search'
  static readonly OPEN_SORT_MENU: string = 'open_sort_menu'
  static readonly PAUSE_VISIBLE: string = 'pause_visible'
  static readonly RESUME_VISIBLE: string = 'resume_visible'
}

/**
 * Narrow root-to-page command bridge for Downloads.
 *
 * The root shell writes only a command and sequence. DownloadQueuePage owns
 * the query, sort mode, and native menu; it is also the sole writer of
 * searchActive so the HDS action can accurately present its close affordance.
 * AppStorageV2 keeps this bridge attached to the retained root tree only; no
 * field here is queue persistence or account state.
 */
@ObservedV2
export class DownloadQueueActionState {
  @Trace command: string = ''
  @Trace commandSeq: number = 0
  @Trace searchActive: boolean = false
  /** Local title filter shared with the HDS bottomBuilder field. */
  @Trace searchText: string = ''
  /** Counts are a presentation snapshot, never durable queue state. */
  @Trace pausableVisibleCount: number = 0
  @Trace resumableVisibleCount: number = 0
}

const DOWNLOAD_QUEUE_ACTION_KEY: string = 'nextn_download_queue_actions'

export function connectDownloadQueueActions(): DownloadQueueActionState {
  return AppStorageV2.connect(
    DownloadQueueActionState,
    DOWNLOAD_QUEUE_ACTION_KEY,
    (): DownloadQueueActionState => new DownloadQueueActionState(),
  )!
}

/** Root HDS actions may request a page operation without reaching into page state. */
export class DownloadQueueActionBridge {
  static requestPauseVisible(): void {
    DownloadQueueActionBridge.request(DownloadQueueAction.PAUSE_VISIBLE)
  }

  static requestResumeVisible(): void {
    DownloadQueueActionBridge.request(DownloadQueueAction.RESUME_VISIBLE)
  }

  static requestToggleSearch(): void {
    DownloadQueueActionBridge.request(DownloadQueueAction.TOGGLE_SEARCH)
  }

  static requestOpenSortMenu(): void {
    DownloadQueueActionBridge.request(DownloadQueueAction.OPEN_SORT_MENU)
  }

  static reportSearchActive(active: boolean): void {
    connectDownloadQueueActions().searchActive = active
  }

  private static request(command: string): void {
    const state: DownloadQueueActionState = connectDownloadQueueActions()
    state.command = command
    state.commandSeq = state.commandSeq + 1
  }

  /** The page alone knows which local projection the title commands affect. */
  static reportVisibleEligibility(pausable: number, resumable: number): void {
    const state: DownloadQueueActionState = connectDownloadQueueActions()
    state.pausableVisibleCount = Math.max(0, pausable)
    state.resumableVisibleCount = Math.max(0, resumable)
  }
}
