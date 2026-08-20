import { AppStorageV2 } from '@kit.ArkUI'

const DIAGNOSTICS_STATE_KEY: string = 'v2_diagnostics'

@ObservedV2
export class DiagnosticsState {
  @Trace enabled: boolean = true
  @Trace minLevel: string = 'info'
}

export function connectDiagnostics(): DiagnosticsState {
  return AppStorageV2.connect(
    DiagnosticsState,
    DIAGNOSTICS_STATE_KEY,
    (): DiagnosticsState => new DiagnosticsState(),
  )!
}
