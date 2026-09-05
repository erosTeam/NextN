import { describe, expect, it } from '@ohos/hypium'
import {
  apiKeyCheckDispositionForStatus,
  AccountListSettings,
  AccountSessionRepository,
  AccountSessionRestoreSnapshot,
  BackupPreferencesAdapter,
  EncryptedAccountSession,
  NhAccountSessionService,
  NhApiKeyCheckDisposition,
  NhApiResponseCookieCodec,
  NhApiResponseCookieExtraction,
  NhBrowserSessionBoundary,
  NhRefreshResponse,
  NhRefreshResponseCodec,
} from 'shared'

function encryptedRecord(ciphertext: string, nonce: string): EncryptedAccountSession {
  const record: EncryptedAccountSession = new EncryptedAccountSession()
  record.ciphertext = ciphertext
  record.nonce = nonce
  return record
}

class AuthCookieFixture {
  name: string = ''
  value: string = ''
  domain: string = '.nhentai.net'
  path: string = '/'
  expiresDate: string = ''
  isHttpOnly: boolean = true
  isSecure: boolean = true
  isSessionCookie: boolean = true
  sameSitePolicy: number = 1
}

class SessionEnvelopeFixture {
  version: number = 4
  credentialKind: string = ''
  apiKey: string = ''
  cookieHeader: string = ''
  browserUserAgent: string = ''
  authCookies: AuthCookieFixture[] = []
}

class RefreshUserFixture {
  id: number = 0
}

class RefreshResponseFixture {
  access_token: string = ''
  refresh_token: string = ''
  user: RefreshUserFixture = new RefreshUserFixture()
}

class RefreshTokensOnlyFixture {
  access_token: string = ''
  refresh_token: string = ''
}

function refreshResponse(accountId: number): string {
  const fixture: RefreshResponseFixture = new RefreshResponseFixture()
  fixture.access_token = 'rotated-access'
  fixture.refresh_token = 'rotated-refresh'
  fixture.user.id = accountId
  return JSON.stringify(fixture)
}

function authCookie(name: string, value: string): AuthCookieFixture {
  const cookie: AuthCookieFixture = new AuthCookieFixture()
  cookie.name = name
  cookie.value = value
  return cookie
}

function sessionEnvelope(credentialKind: string, apiKey: string): SessionEnvelopeFixture {
  const envelope: SessionEnvelopeFixture = new SessionEnvelopeFixture()
  envelope.credentialKind = credentialKind
  envelope.apiKey = apiKey
  envelope.cookieHeader =
    'access_token=local-access; refresh_token=local-refresh; sessionid=local-session'
  envelope.browserUserAgent = 'local-browser-agent'
  envelope.authCookies = [
    authCookie('access_token', 'local-access'),
    authCookie('refresh_token', 'local-refresh'),
  ]
  return envelope
}

export default function nhBrowserSessionOwnershipTest(): void {
  describe('NH browser-session ownership', () => {
    it('retains a complete Web snapshot for the same saved account', 0, (done: Function) => {
      expect(NhBrowserSessionBoundary.browserSessionMatchesValidatedAccount(
        '101',
        '101',
        false,
      )).assertEqual(true)
      done()
    })

    it('drops the active account Web snapshot when manual binding resolves another account', 0,
      (done: Function) => {
        expect(NhBrowserSessionBoundary.browserSessionMatchesValidatedAccount(
          '101',
          '202',
          false,
        )).assertEqual(false)
        done()
      })

    it('accepts the snapshot captured by the current official API-key flow', 0, (done: Function) => {
      expect(NhBrowserSessionBoundary.browserSessionMatchesValidatedAccount(
        '101',
        '202',
        true,
      )).assertEqual(true)
      done()
    })

    it('rejects an invalid validated account even when capture is claimed', 0, (done: Function) => {
      expect(NhBrowserSessionBoundary.browserSessionMatchesValidatedAccount(
        '101',
        '',
        true,
      )).assertEqual(false)
      expect(NhBrowserSessionBoundary.browserSessionMatchesValidatedAccount(
        '101',
        'account-202',
        true,
      )).assertEqual(false)
      done()
    })

    it('hydrates ArkWeb only from a complete account-owned browser snapshot', 0, (done: Function) => {
      expect(NhBrowserSessionBoundary.hasCompleteOwnedBrowserSessionSnapshot(
        true,
        true,
        true,
        true,
      )).assertTrue()
      expect(NhBrowserSessionBoundary.hasCompleteOwnedBrowserSessionSnapshot(
        true,
        true,
        true,
        false,
      )).assertFalse()
      expect(NhBrowserSessionBoundary.hasCompleteOwnedBrowserSessionSnapshot(
        false,
        false,
        false,
        false,
      )).assertFalse()
      done()
    })

    it('preserves the target primary session during portable merge restore', 0, (done: Function) => {
      expect(NhAccountSessionService.backupRestorePreservesExistingPrimary(true, false)).assertEqual(true)
      done()
    })

    it('writes the backed-up primary directly outside a portable merge', 0, (done: Function) => {
      expect(NhAccountSessionService.backupRestorePreservesExistingPrimary(false, true)).assertEqual(false)
      expect(NhAccountSessionService.backupRestorePreservesExistingPrimary(true, true)).assertEqual(false)
      done()
    })

    it('strips every Web-session field from a portable API-key envelope', 0, (done: Function) => {
      const portable: string | null = NhAccountSessionService.portableApiKeyPayload(
        JSON.stringify(sessionEnvelope('api_key', 'test-api-key')),
      )
      expect(portable !== null).assertTrue()
      const record: Record<string, Object> = JSON.parse(portable as string) as Record<string, Object>
      expect(record['version']).assertEqual(4)
      expect(record['credentialKind']).assertEqual('api_key')
      expect(record['apiKey']).assertEqual('test-api-key')
      expect(record['cookieHeader']).assertEqual('')
      expect(record['browserUserAgent']).assertEqual('')
      expect((record['authCookies'] as Object[]).length).assertEqual(0)
      done()
    })

    it('does not export a valid Web-token envelope as a portable credential', 0, (done: Function) => {
      const portable: string | null = NhAccountSessionService.portableApiKeyPayload(
        JSON.stringify(sessionEnvelope('web_token', '')),
      )
      expect(portable === null).assertTrue()
      done()
    })

    it('admits only stripped API-key payloads during portable restore', 0, (done: Function) => {
      const sanitized: string | null = NhAccountSessionService.portableApiKeyPayload(
        JSON.stringify(sessionEnvelope('api_key', 'test-api-key')),
      )
      expect(sanitized !== null).assertTrue()
      expect(NhAccountSessionService.isPortableBackupSessionPayload(sanitized as string)).assertTrue()
      expect(NhAccountSessionService.isPortableBackupSessionPayload(
        JSON.stringify(sessionEnvelope('api_key', 'test-api-key')),
      )).assertFalse()
      expect(NhAccountSessionService.isPortableBackupSessionPayload(
        JSON.stringify(sessionEnvelope('web_token', '')),
      )).assertFalse()
      done()
    })

    it('never adopts the source active id while a target primary is retained', 0, (done: Function) => {
      expect(BackupPreferencesAdapter.mergeKeepsCurrentActiveAccount(
        'nextn_settings',
        'account.list.activeId',
        true,
      )).assertEqual(true)
      expect(BackupPreferencesAdapter.mergeKeepsCurrentActiveAccount(
        'nextn_settings',
        'account.list.activeId',
        false,
      )).assertEqual(false)
      expect(BackupPreferencesAdapter.mergeKeepsCurrentActiveAccount(
        'nextn_settings',
        'account.list.ids',
        true,
      )).assertEqual(false)
      done()
    })

    it('keeps target account order and appends portable owners once', 0, (done: Function) => {
      expect(BackupPreferencesAdapter.mergeAccountIdLists(
        '["101","303"]',
        '["202","101"]',
        '101',
      )).assertEqual('["101","303","202"]')
      expect(BackupPreferencesAdapter.mergeAccountIdLists(
        '',
        '["202"]',
        '101',
      )).assertEqual('["101","202"]')
      done()
    })

    it('does not assign an imported owner to an owner-unknown retained primary', 0, (done: Function) => {
      expect(AccountListSettings.restoredActiveAccountId(['202'], '', true)).assertEqual('')
      expect(AccountListSettings.restoredActiveAccountId(['101', '202'], '', true, '101')).assertEqual('101')
      expect(AccountListSettings.restoredActiveAccountId(['101', '202'], '202', true, '101')).assertEqual('101')
      expect(AccountListSettings.restoredActiveAccountId(['202'], '', false)).assertEqual('202')
      done()
    })

    it('uses the atomic primary owner even when restore re-wraps the saved envelope', 0, (done: Function) => {
      const snapshot: AccountSessionRestoreSnapshot = new AccountSessionRestoreSnapshot()
      snapshot.record = encryptedRecord('primary-ciphertext', 'primary-nonce')
      snapshot.primaryOwnerId = '202'
      snapshot.savedKeys = ['101', '202']
      snapshot.savedRecords = [
        encryptedRecord('saved-101', 'nonce-101'),
        encryptedRecord('independently-wrapped-202', 'nonce-202'),
      ]
      expect(AccountSessionRepository.resolvePrimaryOwner(snapshot)).assertEqual('202')
      done()
    })

    it('migrates one exact legacy primary owner but refuses an ambiguous match', 0, (done: Function) => {
      const unique: AccountSessionRestoreSnapshot = new AccountSessionRestoreSnapshot()
      unique.record = encryptedRecord('same', 'same-nonce')
      unique.savedKeys = ['101', '202']
      unique.savedRecords = [
        encryptedRecord('old', 'old-nonce'),
        encryptedRecord('same', 'same-nonce'),
      ]
      expect(AccountSessionRepository.resolvePrimaryOwner(unique)).assertEqual('202')

      const ambiguous: AccountSessionRestoreSnapshot = new AccountSessionRestoreSnapshot()
      ambiguous.record = encryptedRecord('same', 'same-nonce')
      ambiguous.savedKeys = ['101', '202']
      ambiguous.savedRecords = [
        encryptedRecord('same', 'same-nonce'),
        encryptedRecord('same', 'same-nonce'),
      ]
      expect(AccountSessionRepository.resolvePrimaryOwner(ambiguous)).assertEqual('')
      done()
    })

    it('does not trust a stale owner row without its saved credential', 0, (done: Function) => {
      const snapshot: AccountSessionRestoreSnapshot = new AccountSessionRestoreSnapshot()
      snapshot.record = encryptedRecord('primary', 'nonce')
      snapshot.primaryOwnerId = '202'
      snapshot.savedKeys = ['101']
      snapshot.savedRecords = [encryptedRecord('saved', 'saved-nonce')]
      expect(AccountSessionRepository.resolvePrimaryOwner(snapshot)).assertEqual('')
      done()
    })

    it('rejects an API key only after the fixed account probe returns 401 or 403', 0, (done: Function) => {
      expect(apiKeyCheckDispositionForStatus(401))
        .assertEqual(NhApiKeyCheckDisposition.AUTH_REJECTED)
      expect(apiKeyCheckDispositionForStatus(403))
        .assertEqual(NhApiKeyCheckDisposition.AUTH_REJECTED)
      done()
    })

    it('keeps the API key on account-probe transport, rate-limit and server failures', 0, (done: Function) => {
      expect(apiKeyCheckDispositionForStatus(0))
        .assertEqual(NhApiKeyCheckDisposition.UNAVAILABLE)
      expect(apiKeyCheckDispositionForStatus(429))
        .assertEqual(NhApiKeyCheckDisposition.UNAVAILABLE)
      expect(apiKeyCheckDispositionForStatus(500))
        .assertEqual(NhApiKeyCheckDisposition.UNAVAILABLE)
      done()
    })

    it('keeps an API key when the fixed account probe still accepts it', 0, (done: Function) => {
      expect(apiKeyCheckDispositionForStatus(200))
        .assertEqual(NhApiKeyCheckDisposition.VALID_UNCHANGED)
      expect(apiKeyCheckDispositionForStatus(204))
        .assertEqual(NhApiKeyCheckDisposition.VALID_UNCHANGED)
      done()
    })

    it('preserves exact Set-Cookie rotation and deletion fields', 0, (done: Function) => {
      const exactAccess: string =
        'access_token=rotated-access; Path=/; Expires=Wed, 21 Oct 2037 07:28:00 GMT; Secure; SameSite=Lax'
      const exactRefreshDelete: string =
        'refresh_token=; Path=/; Max-Age=0; Secure; HttpOnly; SameSite=Lax'
      const fallback: string =
        '#HttpOnly_.nhentai.net\tTRUE\t/\tTRUE\t2147483647\trefresh_token\tstale-fallback'
      const extracted: NhApiResponseCookieExtraction = NhApiResponseCookieCodec.extract(
        JSON.stringify({ 'set-cookie': [exactAccess, exactRefreshDelete] }),
        fallback,
        false,
      )
      expect(extracted.rejected).assertFalse()
      expect(extracted.headers.length).assertEqual(2)
      expect(extracted.headers[0]).assertEqual(exactAccess)
      expect(extracted.headers[1]).assertEqual(exactRefreshDelete)
      done()
    })

    it('decodes the NetworkKit libcurl cookie-list fallback', 0, (done: Function) => {
      const extracted: NhApiResponseCookieExtraction = NhApiResponseCookieCodec.extract(
        '{}',
        '#HttpOnly_.nhentai.net\tTRUE\t/\tTRUE\t2147483647\trefresh_token\trotated-refresh\n' +
          'nhentai.net\tFALSE\t/api\tFALSE\t0\taccess_token\trotated-access',
        false,
      )
      expect(extracted.rejected).assertFalse()
      expect(extracted.headers.length).assertEqual(2)
      expect(extracted.headers[0]).assertEqual(
        'refresh_token=rotated-refresh; Domain=.nhentai.net; Path=/; ' +
          'Expires=Tue, 19 Jan 2038 03:14:07 GMT; Secure; HttpOnly',
      )
      expect(extracted.headers[1]).assertEqual('access_token=rotated-access; Path=/api')
      done()
    })

    it('rejects a malformed or foreign cookie-list batch atomically', 0, (done: Function) => {
      const extracted: NhApiResponseCookieExtraction = NhApiResponseCookieCodec.extract(
        '{}',
        'nhentai.net\tFALSE\t/\tTRUE\t0\taccess_token\taccepted-before-rejection\n' +
          '.example.com\tTRUE\t/\tTRUE\t0\trefresh_token\tforeign',
        false,
      )
      expect(extracted.rejected).assertTrue()
      done()
    })

    it('accepts an official refresh response only for its request owner', 0, (done: Function) => {
      const decoded: NhRefreshResponse | null = NhRefreshResponseCodec.decode(
        refreshResponse(202),
        '202',
      )
      expect(decoded !== null).assertTrue()
      expect((decoded as NhRefreshResponse).accountId).assertEqual('202')
      done()
    })

    it('rejects a refresh response owned by another saved account', 0, (done: Function) => {
      expect(NhRefreshResponseCodec.decode(refreshResponse(202), '101') === null).assertTrue()
      done()
    })

    it('rejects replacement tokens without the required response user', 0, (done: Function) => {
      const fixture: RefreshTokensOnlyFixture = new RefreshTokensOnlyFixture()
      fixture.access_token = 'rotated-access'
      fixture.refresh_token = 'rotated-refresh'
      expect(NhRefreshResponseCodec.decode(JSON.stringify(fixture), '202') === null).assertTrue()
      done()
    })
  })
}
