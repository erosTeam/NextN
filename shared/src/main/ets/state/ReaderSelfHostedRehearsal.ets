import { Want } from '@kit.AbilityKit'

/**
 * Debug-only, process-local self-hosted Reader translation rehearsal config.
 * Parsed straight from the Debug Want by the host entry; never persisted and
 * never a user setting. Empty by default so ordinary launches are unaffected.
 */
export class ReaderSelfHostedRehearsal {
  private static endpoint: string = ''
  private static user: string = ''
  private static password: string = ''

  static capture(want: Want, debugBuild: boolean): void {
    ReaderSelfHostedRehearsal.clear()
    if (!debugBuild || want.parameters === undefined) return
    const endpoint = want.parameters['readerLabSelfHostedEndpoint']
    const user = want.parameters['readerLabSelfHostedUser']
    const password = want.parameters['readerLabSelfHostedPassword']
    ReaderSelfHostedRehearsal.endpoint = typeof endpoint === 'string' ? endpoint : ''
    ReaderSelfHostedRehearsal.user = typeof user === 'string' ? user : ''
    ReaderSelfHostedRehearsal.password = typeof password === 'string' ? password : ''
  }

  static clear(): void {
    ReaderSelfHostedRehearsal.endpoint = ''
    ReaderSelfHostedRehearsal.user = ''
    ReaderSelfHostedRehearsal.password = ''
  }

  static active(): boolean {
    return ReaderSelfHostedRehearsal.endpoint.length > 0 &&
      ReaderSelfHostedRehearsal.user.length > 0 && ReaderSelfHostedRehearsal.password.length > 0
  }

  static currentEndpoint(): string { return ReaderSelfHostedRehearsal.endpoint }
  static currentUser(): string { return ReaderSelfHostedRehearsal.user }
  static currentPassword(): string { return ReaderSelfHostedRehearsal.password }
}
