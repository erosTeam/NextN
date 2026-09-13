import { Want } from '@kit.AbilityKit'
import { AppStorageV2 } from '@kit.ArkUI'

export enum NextNReaderBackend {
  LEGACY = 'legacy',
  SHARED = 'shared',
}

/**
 * Process-local replacement rehearsal selector.
 *
 * This is deliberately not a Reader setting: it is not persisted, backed up,
 * or interpreted by reader-kit. The NextN navigation host snapshots it into a
 * route so an already-open Reader cannot switch implementation underneath the
 * user.
 */
@ObservedV2
export class NextNReaderBackendSelectionState {
  @Trace version: number = 0
  private backend: NextNReaderBackend = NextNReaderBackend.LEGACY

  current(): NextNReaderBackend {
    return this.backend
  }

  select(backend: NextNReaderBackend): void {
    if (this.backend === backend) return
    this.backend = backend
    this.version += 1
  }
}

const NEXTN_READER_BACKEND_SELECTION_KEY: string = 'nextn_reader_backend_selection'

export function connectNextNReaderBackendSelection(): NextNReaderBackendSelectionState {
  return AppStorageV2.connect(
    NextNReaderBackendSelectionState,
    NEXTN_READER_BACKEND_SELECTION_KEY,
    (): NextNReaderBackendSelectionState => new NextNReaderBackendSelectionState(),
  )!
}

/**
 * Explicit debug Want only.
 *
 * A normal launch is also an explicit return to the production-safe backend.
 * This prevents a failed or interrupted device rehearsal from leaking the
 * shared backend into later ordinary Reader entries in the same process.
 */
export function captureNextNReaderBackendWant(want: Want, debugBuild: boolean): void {
  const state: NextNReaderBackendSelectionState = connectNextNReaderBackendSelection()
  if (!debugBuild) {
    state.select(NextNReaderBackend.LEGACY)
    return
  }
  const value: Object | undefined = want.parameters?.['nextn_reader_backend']
  if (value === NextNReaderBackend.SHARED) {
    state.select(NextNReaderBackend.SHARED)
  } else {
    state.select(NextNReaderBackend.LEGACY)
  }
}
