import { AppStorageV2 } from '@kit.ArkUI'

const LOGIN_RECOVERY_LAUNCH_V2_KEY: string = 'v2_loginRecoveryLaunch'

/**
 * Process-local, one-shot handoff from EntryAbility's explicit recovery Want
 * to Index. It is not durable account state and is consumed exactly once.
 */
@ObservedV2
export class LoginRecoveryLaunchState {
  @Trace requestVersion: number = 0
  @Trace pending: boolean = false

  request(): void {
    this.pending = true
    this.requestVersion += 1
  }

  consume(): boolean {
    if (!this.pending) {
      return false
    }
    this.pending = false
    return true
  }
}

export function connectLoginRecoveryLaunch(): LoginRecoveryLaunchState {
  return AppStorageV2.connect(
    LoginRecoveryLaunchState,
    LOGIN_RECOVERY_LAUNCH_V2_KEY,
    () => new LoginRecoveryLaunchState(),
  )!
}

export function requestLoginRecoveryLaunch(): void {
  connectLoginRecoveryLaunch().request()
}
