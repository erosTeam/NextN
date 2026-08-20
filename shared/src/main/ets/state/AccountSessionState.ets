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
  /** Durable account ownership; false only after explicit sign-out/removal. */
  @Trace signedIn: boolean = false
  /** Whether the current ArkWeb identity can issue authenticated requests now. */
  @Trace authenticationAvailable: boolean = false
  @Trace revision: number = 0

  publish(
    initialized: boolean,
    signedIn: boolean,
    authenticationAvailable: boolean,
  ): void {
    if (this.initialized === initialized &&
      this.signedIn === signedIn &&
      this.authenticationAvailable === authenticationAvailable) {
      return
    }
    this.initialized = initialized
    this.signedIn = signedIn
    this.authenticationAvailable = authenticationAvailable
    this.revision += 1
  }
}

export function connectAccountSession(): AccountSessionState {
  return AppStorageV2.connect(AccountSessionState, ACCOUNT_SESSION_V2_KEY, () => new AccountSessionState())!
}
