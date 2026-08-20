/**
 * Browser account-session signals. These values never carry URLs, cookies,
 * credentials, or tokens into UI state.
 */
export enum NhBrowserSessionPhase {
  NOT_STARTED = 'not_started',
  BROWSER_READY = 'browser_ready',
  LOGIN_REQUIRED = 'login_required',
  AUTHENTICATED = 'authenticated',
  TRUSTED_REDIRECT_OBSERVED = 'trusted_redirect_observed',
  UNAVAILABLE = 'unavailable',
}

/**
 * A fixed, non-sensitive result of the same-document account probe. It never
 * carries a status code, URL, cookie, profile, or any other browser value into
 * ArkUI state.
 */
export enum NhBrowserSessionVerificationOutcome {
  VERIFIED = 'verified',
  RETRY_SCHEDULED = 'retry_scheduled',
  RETRY_EXHAUSTED = 'retry_exhausted',
  REJECTED = 'rejected',
}

export class NhBrowserSessionStatus {
  phase: NhBrowserSessionPhase = NhBrowserSessionPhase.NOT_STARTED
  cookieAccessAllowed: boolean = false

  canOpenBrowserSession(): boolean {
    return this.cookieAccessAllowed && this.phase !== NhBrowserSessionPhase.UNAVAILABLE
  }

  hasAuthenticatedSession(): boolean {
    return this.phase === NhBrowserSessionPhase.AUTHENTICATED
  }
}
