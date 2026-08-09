import { AppStorageV2 } from '@kit.ArkUI'
import { NhAccountProfile } from '../model/NhAccountProfile'

const ACCOUNT_PROFILE_V2_KEY: string = 'nextn_accountProfile'

/**
 * Reactive, display-safe single-account snapshot. Session state intentionally
 * remains in AccountSessionState; this holder never contains a cookie, token,
 * password, or browser document.
 */
@ObservedV2
export class AccountProfileState {
  @Trace username: string = ''
  @Trace userUrl: string = ''
  @Trace userId: string = ''
  @Trace avatarUrl: string = ''
  @Trace hasSnapshot: boolean = false
  @Trace revision: number = 0

  replace(profile: NhAccountProfile): void {
    this.username = profile.username
    this.userUrl = profile.userUrl
    this.userId = profile.userId
    this.avatarUrl = profile.avatarUrl
    this.hasSnapshot = profile.hasIdentity()
    this.revision += 1
  }

  clear(): void {
    this.username = ''
    this.userUrl = ''
    this.userId = ''
    this.avatarUrl = ''
    this.hasSnapshot = false
    this.revision += 1
  }

  snapshot(): NhAccountProfile {
    const result: NhAccountProfile = new NhAccountProfile()
    result.username = this.username
    result.userUrl = this.userUrl
    result.userId = this.userId
    result.avatarUrl = this.avatarUrl
    return result
  }
}

export function connectAccountProfile(): AccountProfileState {
  return AppStorageV2.connect(
    AccountProfileState,
    ACCOUNT_PROFILE_V2_KEY,
    (): AccountProfileState => new AccountProfileState(),
  )!
}
