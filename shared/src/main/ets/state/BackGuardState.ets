import { AppStorageV2 } from '@kit.ArkUI'

/**
 * Home back-guard (port of NextE BackGuardState): on the home root with an empty route stack the
 * first back press shows a toast; a second press within one second passes through so the system
 * exits the app. Defaults ON. Restored by BackGuardSettings in the EntryAbility startup Promise;
 * the settings row (BackGuardGroup) is the only writer.
 */
@ObservedV2
export class BackGuardState {
  @Trace enabled: boolean = true
}

const BACK_GUARD_STATE_KEY: string = 'v2_backguard'

export function connectBackGuard(): BackGuardState {
  return AppStorageV2.connect(
    BackGuardState,
    BACK_GUARD_STATE_KEY,
    (): BackGuardState => new BackGuardState(),
  )!
}
