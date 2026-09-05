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
  /** Automatic recovery is exhausted and an explicit visible verification is required. */
  @Trace verificationRequired: boolean = false
  /** Non-secret recovery route: API-key editor or first-party Web login. */
  @Trace verificationRecoveryKind: string = 'web_login'
  /** Non-secret credential class currently selected for native NH requests. */
  @Trace credentialKind: string = 'none'
  /** Redacted identity of the active API key; never contains the complete key. */
  @Trace apiKeyIdentity: string = ''
  /** Display name stored with the active API key. */
  @Trace apiKeyName: string = ''
  @Trace revision: number = 0

  publish(
    initialized: boolean,
    signedIn: boolean,
    authenticationAvailable: boolean,
    verificationRequired: boolean,
    verificationRecoveryKind: string = 'web_login',
    credentialKind: string = 'none',
    apiKeyIdentity: string = '',
    apiKeyName: string = '',
  ): void {
    if (this.initialized === initialized &&
      this.signedIn === signedIn &&
      this.authenticationAvailable === authenticationAvailable &&
      this.verificationRequired === verificationRequired &&
      this.verificationRecoveryKind === verificationRecoveryKind &&
      this.credentialKind === credentialKind &&
      this.apiKeyIdentity === apiKeyIdentity &&
      this.apiKeyName === apiKeyName) {
      return
    }
    this.initialized = initialized
    this.signedIn = signedIn
    this.authenticationAvailable = authenticationAvailable
    this.verificationRequired = verificationRequired
    this.verificationRecoveryKind = verificationRecoveryKind === 'api_key' ? 'api_key' : 'web_login'
    this.credentialKind = credentialKind === 'api_key'
      ? 'api_key'
      : credentialKind === 'web_token'
        ? 'web_token'
        : 'none'
    const retainsApiKeyIdentity: boolean = this.credentialKind === 'api_key' ||
      this.verificationRecoveryKind === 'api_key'
    this.apiKeyIdentity = retainsApiKeyIdentity ? apiKeyIdentity : ''
    this.apiKeyName = retainsApiKeyIdentity ? apiKeyName : ''
    this.revision += 1
  }
}

export function connectAccountSession(): AccountSessionState {
  return AppStorageV2.connect(AccountSessionState, ACCOUNT_SESSION_V2_KEY, () => new AccountSessionState())!
}
