import { AppStorageV2 } from '@kit.ArkUI'

const ACCOUNT_SESSION_V2_KEY: string = 'v2_accountSession'

/**
 * The only page-facing account-session state. It deliberately carries no
 * session material: pages receive a settled lifecycle result from Entry and
 * never re-read, decrypt, hydrate, or clear the durable browser session.
 */
@ObservedV2
export class AccountSessionState {
  @Trace initialized: boolean = false
  @Trace signedIn: boolean = false
  @Trace verificationRequired: boolean = false
  @Trace revision: number = 0

  publish(
    initialized: boolean,
    signedIn: boolean,
    verificationRequired: boolean,
  ): void {
    if (this.initialized === initialized &&
      this.signedIn === signedIn &&
      this.verificationRequired === verificationRequired) {
      return
    }
    this.initialized = initialized
    this.signedIn = signedIn
    this.verificationRequired = verificationRequired
    this.revision += 1
  }
}

export function connectAccountSession(): AccountSessionState {
  return AppStorageV2.connect(AccountSessionState, ACCOUNT_SESSION_V2_KEY, () => new AccountSessionState())!
}
