import { AppStorageV2 } from '@kit.ArkUI'

const ACCOUNT_AUTH_NOTICE_V2_KEY: string = 'v2_accountAuthNotice'

/** Root-owned, non-secret authentication notice event for the HDS SnackBar. */
@ObservedV2
export class AccountAuthNoticeState {
  @Trace code: string = ''
  @Trace revision: number = 0

  publish(code: string): void {
    const normalized: string = [
      'invalid_input',
      'challenge_unavailable',
      'challenge_invalid',
      'rate_limited',
      'rejected',
      'token_response_invalid',
      'candidate_rejected',
      'verification_rejected',
      'verification_failed',
      'persistence_failed',
      'request_failed',
      'unavailable',
    ].includes(code) ? code : 'unavailable'
    this.code = normalized
    this.revision += 1
  }

  clear(): void {
    this.code = ''
  }
}

export function connectAccountAuthNotice(): AccountAuthNoticeState {
  return AppStorageV2.connect(
    AccountAuthNoticeState,
    ACCOUNT_AUTH_NOTICE_V2_KEY,
    () => new AccountAuthNoticeState(),
  )!
}
