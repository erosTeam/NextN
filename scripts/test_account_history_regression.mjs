#!/usr/bin/env node
/** Non-UI regressions for account ownership and split history sync. */
import fs from 'fs'
import { runStagedLoginEpoch } from './run_arkweb_login_keychain_epoch.mjs'

const read = (path) => fs.readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
let failures = 0
function ok(name, condition) {
  if (!condition) {
    console.error(`[FAIL] ${name}`)
    failures += 1
  }
}

const session = read('shared/src/main/ets/services/NhAccountSessionService.ets')
const api = read('shared/src/main/ets/network/NhApiClient.ets')
const accountState = read('shared/src/main/ets/state/AccountSessionState.ets')
const browserPage = read('feature/user/src/main/ets/pages/BrowserSessionPage.ets')
const accountList = read('shared/src/main/ets/settings/AccountListSettings.ets')
const accountProfile = read('shared/src/main/ets/services/NhAccountProfileService.ets')
const sessionRepository = read('shared/src/main/ets/storage/AccountSessionRepository.ets')
const arkWebTransport = read('shared/src/main/ets/services/NhArkWebSessionTransport.ets')
const entryAbility = read('entry/src/main/ets/entryability/EntryAbility.ets')
const settingsPage = read('feature/settings/src/main/ets/pages/SettingsPage.ets')
const diagnosticsRedactor = read('shared/src/main/ets/diagnostics/DiagnosticsRedactor.ets')
const accountS0Collector = read('scripts/collect_nextn_account_s0.mjs')
const atomicLoginCycle = read('scripts/run_nextn_account_login_cycle.mjs')
const entryIndex = read('entry/src/main/ets/pages/Index.ets')
const galleryCollectionBody = read('shared/src/main/ets/components/GalleryCollectionBody.ets')

ok('account ownership is separate from request authentication',
  /@Trace signedIn: boolean/.test(accountState) &&
  /@Trace authenticationAvailable: boolean/.test(accountState) &&
  /retainedAccountPresent \|\| authenticated/.test(session))
ok('cold start has a durable non-secret ownership marker cleared only by explicit clear',
  /ACCOUNT_PRESENT_KEY: string = 'account\.session\.present'/.test(session) &&
  /loadRetainedAccountMarker\(context\)/.test(session) &&
  /AccountSessionRepository\.clear\(context\)[\s\S]*persistRetainedAccountMarker\(context, false\)/.test(session) &&
  (session.match(/retainedAccountPresent = false/g) || []).length === 1)

const terminal401 = session.match(/static async recordAuthenticatedReadReplay401\([\s\S]*?\n  \}/)?.[0] || ''
const syncSealedSessionStart = session.indexOf('static async syncSealedSessionFromRegularJar')
const syncSealedSessionEnd = session.indexOf('static async clear(', syncSealedSessionStart)
const syncSealedSession = syncSealedSessionStart >= 0 && syncSealedSessionEnd > syncSealedSessionStart
  ? session.slice(syncSealedSessionStart, syncSealedSessionEnd)
  : ''
ok('a terminal replayed 401 records diagnostics without demoting the account',
  /recordAuthenticatedReadReplay401/.test(terminal401) &&
  !/retainedAccountPresent\s*=\s*false/.test(terminal401) &&
  !/cookieHeader\s*=\s*''/.test(terminal401) &&
  !/publishSessionChange/.test(terminal401) &&
  /recordAuthenticatedReadInitial401/.test(api) &&
  /recordAuthenticatedReadBrowserRefresh/.test(api))
ok('all first-party v2 JSON requests share the browser-managed cookie response chain',
  /private static async requestBrowserResponse/.test(api) &&
  /NhArkWebSessionTransport\.requestJson\(url, method, body\)/.test(api) &&
  /refreshSessionAfter401/.test(api) &&
  /persistBrowserManagedCookies/.test(api) &&
  !/http\.createHttp\(\)/.test(api) &&
  !/recoverRegularArkWebCookieJarAfterAuthenticated401/.test(api))
ok('401 recovery never overwrites the live browser jar with a sealed access token',
  !/forceRegularArkWebCookieJarFromSealedSession/.test(session) &&
  !/AUTHENTICATED_READ_SEALED_REPLAY/.test(session) &&
  /credentials:\s*'include'/.test(arkWebTransport) &&
  /document\.cookie/.test(arkWebTransport))
ok('S0 uses the fixed current-process Favorites outcome when cached cards remain mounted',
  /collectFavoritesRequestOutcome/.test(accountS0Collector) &&
  /requestOutcome === 'failed'[\s\S]*summary\.error = true[\s\S]*summary\.authenticated = false/.test(accountS0Collector) &&
  /requestOutcome === 'success'[\s\S]*summary\.error = false[\s\S]*summary\.authenticated = true/.test(accountS0Collector))
const credentialPreparation = atomicLoginCycle.indexOf("invokeKeychainHandle('account'")
const visibleLoginRoute = atomicLoginCycle.indexOf('routeVisibleLogin(options.target, options.lease)')
const preCredentialCfGate = atomicLoginCycle.indexOf('waitForPreCredentialCfGate(forward.localPort')
const stagedCredentialEpoch = atomicLoginCycle.indexOf('runStagedLoginEpoch({')
const fixedSubmit = atomicLoginCycle.indexOf('runCfReviewedSubmit({')
const nativePromotion = atomicLoginCycle.indexOf('observeNativePromotion(options.target')
ok('authorized login is one atomic post-WebView queue and pauses only for CF',
  credentialPreparation >= 0 && visibleLoginRoute > credentialPreparation &&
  preCredentialCfGate > visibleLoginRoute && stagedCredentialEpoch > preCredentialCfGate &&
  fixedSubmit > stagedCredentialEpoch &&
  nativePromotion > fixedSubmit &&
  /CF_READY_TO_FILL_CEILING_MS = 5000/.test(atomicLoginCycle) &&
  /challengeFramePresent === true[\s\S]*cf_intervention_required[\s\S]*runStagedLoginEpoch/.test(atomicLoginCycle) &&
  /cf_intervention_required/.test(atomicLoginCycle) &&
  /result\.code !== 'cf_intervention_required'[\s\S]*forceStop/.test(atomicLoginCycle) &&
  /flowDeadlineAt = flowStartedAt \+ LOGIN_FLOW_CEILING_MS/.test(atomicLoginCycle) &&
  /Date\.now\(\) < deadlineAt/.test(atomicLoginCycle) &&
  /nativeAccount \|\| accountList/.test(atomicLoginCycle))
const challengeActions = []
const challengeResult = await runStagedLoginEpoch({
  port: 1,
  timeoutMs: 500,
  accountSecretBytes: new Uint8Array([1]),
  passwordSecretBytes: new Uint8Array([2]),
}, {
  probe: async () => ({
    ok: true,
    loginFormPresent: true,
    accountFieldPresent: true,
    accountFieldFocused: false,
    accountFieldFilled: false,
    passwordFieldPresent: true,
    passwordFieldFocused: false,
    passwordFieldFilled: false,
    passwordFieldMasked: true,
    challengeFramePresent: true,
  }),
  semanticDriver: async (options) => {
    challengeActions.push(options.action)
    return { ok: true }
  },
  secretFill: async (options) => {
    challengeActions.push(`fill-${options.field}`)
    return { ok: true }
  },
})
ok('a pending CF challenge blocks focus and both credential writes',
  challengeResult.ok === false && challengeResult.code === 'challenge_present' &&
  challengeResult.accountEntered === false && challengeResult.passwordEntered === false &&
  challengeResult.submitIssued === false && challengeActions.length === 0)
ok('empty signed-out account entry goes directly to the visible login page',
  /private openAccountEntry\(\)[\s\S]*accountList\.accounts\.length === 0[\s\S]*!this\.accountSession\.signedIn[\s\S]*this\.pushVisibleLoginSession\(\)/.test(entryIndex) &&
  /private pushVisibleLoginSession\(\)[\s\S]*new BrowserSessionRouteParams\(true\)/.test(entryIndex) &&
  /onOpenAccount:[\s\S]{0,120}this\.openAccountEntry\(\)/.test(entryIndex) &&
  /accessibilityId: 'nextn-settings-root-account'[\s\S]{0,320}if \(this\.onOpenAccount\)[\s\S]{0,120}this\.onOpenAccount\(\)/.test(settingsPage) &&
  !/accessibilityId: 'nextn-settings-root-account'[\s\S]{0,320}if \(this\.isAccountSignedIn && this\.onOpenAccount\)/.test(settingsPage))
ok('visible login promotion cannot complete without a saved selected account row',
  /recordActive\(context: common\.UIAbilityContext\): Promise<boolean>/.test(accountList) &&
  /if \(!await AccountListSettings\.recordActive\(this\.hostContext\(\)\)\)[\s\S]*closeBrowserAfterPromotionFailure\(\)/.test(browserPage))
ok('visible login promotion stages use the live domain and persistent redacted diagnostics',
  /ACCOUNT_LOG_DOMAIN: number = 0xE001/.test(browserPage) &&
  /DiagnosticLogger\.info\('account-login', 'candidate_captured', 'stage'\)/.test(browserPage) &&
  /DiagnosticLogger\.info\('account-login', 'native_session_promoted', 'stage'\)/.test(browserPage) &&
  /DiagnosticLogger\.error\('account-login', 'active_account_record_failed', 'stage'\)/.test(browserPage))
ok('retained gallery collections never render an inline internal error or retry row',
  !/InlineRetryNotice/.test(galleryCollectionBody) &&
  !/InlineError/.test(galleryCollectionBody) &&
  !/hasInlineError/.test(galleryCollectionBody))
ok('the obsolete re-verify account option is absent from runtime UI',
  !/VERIFICATION_RETRY_REQUIRED/.test(browserPage) &&
  !/account_verify_sign_in/.test(browserPage))
ok('saved-account selection has its own durable key and migrates one unambiguous legacy account',
  /ACTIVE_ACCOUNT_ID_KEY: string = 'account\.list\.activeId'/.test(accountList) &&
  /return ids\.length === 1 \? ids\[0\] : ''/.test(accountList) &&
  /NhAccountSessionService\.setActiveSavedAccountId\(snapshot\.activeAccountId\)/.test(accountList))
ok('account switch persists the selected profile back to the primary profile slot',
  /static async switchTo[\s\S]*AccountProfileRepository\.saveIfCurrent[\s\S]*connectAccountProfile\(\)\.replace\(profile\)/.test(accountProfile) &&
  /profileSwitched: boolean[\s\S]*if \(!profileSwitched\)[\s\S]*return false[\s\S]*ACTIVE_ACCOUNT_ID_KEY/.test(accountList))
ok('rotated browser tokens atomically update both primary and active saved envelopes',
  /saveVerifiedForAccount[\s\S]*SQL_UPSERT_SESSION[\s\S]*accountId\.length > 0[\s\S]*SQL_UPSERT_SESSION/.test(sessionRepository) &&
  /syncSealedSessionFromRegularJar[\s\S]*saveVerifiedForAccount\([\s\S]*activeSavedAccountId/.test(session))
ok('sealed session v3 preserves the complete first-party renewal chain',
  /RECOVERABLE_ARKWEB_COOKIE_NAMES[\s\S]*'access_token'[\s\S]*'refresh_token'[\s\S]*'sessionid'/.test(session) &&
  /fetchAllCookies\(false\)/.test(session) &&
  /'version': 3[\s\S]*'authCookies': authCookies/.test(session) &&
  /configCookieSync\([\s\S]*authCookieSetValue\([\s\S]*false,[\s\S]*true/.test(session))
ok('saved-account switching refuses legacy access-only envelopes before deleting live cookies',
  /switchToSaved[\s\S]*!NhAccountSessionService\.hasRenewalAuthCookie\(payload\.authCookies\)[\s\S]*return false[\s\S]*expireVisibleBrowserIdentityCookies\(\)/.test(session))
ok('saving an account checkpoints the current browser renewal cookies first',
  /saveActiveAsSaved[\s\S]*captureFirstPartyAuthCookies\(\)[\s\S]*hasRenewalAuthCookie\(currentAuthCookies\)[\s\S]*serializeSessionPayload\([\s\S]*currentAuthCookies[\s\S]*saveVerifiedByKey/.test(session))
ok('promotion and first authenticated read durably upgrade the selected saved envelope',
  /await AccountListSettings\.recordActive\(this\.hostContext\(\)\)/.test(browserPage) &&
  /needsSavedAccountCheckpoint[\s\S]*saveVerifiedForAccount\([\s\S]*activeSavedAccountId/.test(session) &&
  /lastSavedAccountCheckpointId\s*=\s*NhAccountSessionService\.activeSavedAccountId/.test(session))
ok('same-account cookie checkpoints do not invalidate concurrent reads or publish account revisions',
  /beginDurableSessionTransition\(false\)/.test(session) &&
  /sessionTransitionChangesOwnership/.test(session) &&
  /token\.sessionEpoch === NhAccountSessionService\.sessionEpoch/.test(session) &&
  !/token\.transitionEpoch/.test(session) &&
  syncSealedSession.length > 0 &&
  !/publishSessionChange\(\)/.test(syncSealedSession))
ok('all logged-in first-party reads acquire the same account ownership fence without English transition errors',
  /const readToken:[\s\S]*accountOwned[\s\S]*captureAuthenticatedReadToken\(\)/.test(api) &&
  /accountOwned && readToken === null[\s\S]*account_session_generation_changed/.test(api) &&
  !/Your account session (?:is changing|changed)/.test(api))
ok('a successful browser response cannot re-seal a session with an empty user agent',
  /requestUserAgent[\s\S]*browserUserAgent = userAgent/.test(session) &&
  /jarToken\.length > 0 && NhAccountSessionService\.browserUserAgent\.length > 0/.test(session) &&
  /sealedAuthCookies = restoredPayload\.authCookies[\s\S]*browserUserAgent = normalizedUserAgent/.test(session))
ok('401 browser repair reloads the authenticated root instead of the login page',
  /loadTrustedSessionRefreshPage/.test(arkWebTransport) &&
  /controller\.loadUrl\(`\$\{NhBrowserSessionBoundary\.trustedOrigin\(\)\}\/`\)/.test(arkWebTransport) &&
  !/loadTrustedSessionRefreshPage[\s\S]{0,1800}loginUrl\(\)/.test(arkWebTransport))
ok('a failed token refresh has process and persistent server-directed cooldowns',
  /AUTH_REFRESH_FAILURE_COOLDOWN_MS: number = 60 \* 1000/.test(arkWebTransport) &&
  /lastBrowserIdentityRefreshFailureAtMs/.test(arkWebTransport) &&
  /Date\.now\(\) - NhArkWebSessionTransport\.lastBrowserIdentityRefreshFailureAtMs/.test(arkWebTransport) &&
  /authenticatedRefreshCooldownRemainingMs\(token\)/.test(arkWebTransport) &&
  /response\.headers\.get\('Retry-After'\)/.test(arkWebTransport) &&
  /AUTH_REFRESH_RETRY_AT_KEY: string = 'account\.session\.authRefreshRetryAt'/.test(session) &&
  /recordAuthenticatedRefreshCooldown[\s\S]*store\.putSync\(AUTH_REFRESH_RETRY_AT_KEY/.test(session) &&
  /clearAuthenticatedRefreshCooldown[\s\S]*store\.deleteSync\(AUTH_REFRESH_RETRY_AT_KEY\)/.test(session))
ok('cold restore retries sealed-cookie hydration after a trusted ArkWeb page exists',
  /await ready[\s\S]*ensureRegularArkWebCookieJar\(\)[\s\S]*recordRestoreHydrationAfterPage/.test(arkWebTransport) &&
  /account_restore_hydration_ready_after_page/.test(session) &&
  /after_page_ready_hydration/.test(arkWebTransport))
ok('401 repair hydrates, verifies the account endpoint, and forces a durable checkpoint before replay',
  /after_refresh_hydration/.test(arkWebTransport) &&
  /AUTH_REFRESH_URL: string = `\$\{API_PREFIX\}auth\/refresh`/.test(arkWebTransport) &&
  /authenticatedRefreshRequestBody\(token\)/.test(arkWebTransport) &&
  /requestStatusWithBodyFromCurrentDocument[\s\S]*'POST'/.test(arkWebTransport) &&
  /requestStatusFromCurrentDocument\([\s\S]*`\$\{API_PREFIX\}user`/.test(arkWebTransport) &&
  /syncSealedSessionFromRegularJar\(null, true\)/.test(arkWebTransport) &&
  /forceCheckpoint: boolean = false/.test(session) &&
  /authenticatedRefreshRequestBody[\s\S]*cookie\.name === 'refresh_token'[\s\S]*JSON\.stringify/.test(session))
ok('restore diagnostics distinguish modern and legacy renewal cookie names without values',
  /refresh=\$\{NhAccountSessionService\.hasNamedAuthCookie\(payload\.authCookies, 'refresh_token'\)/.test(session) &&
  /session=\$\{NhAccountSessionService\.hasNamedAuthCookie\(payload\.authCookies, 'sessionid'\)/.test(session) &&
  /legacy=\$\{NhAccountSessionService\.hasNamedAuthCookie\(payload\.authCookies, 'ipb_pass_hash'\)/.test(session))
ok('persistent diagnostics are initialized for every process and exposed in Advanced settings',
  /DiagnosticLogger\.initializePersistentSink\(this\.context\)/.test(entryAbility) &&
  /DiagnosticsSettings\.restore\(this\.context\)/.test(entryAbility) &&
  /DiagnosticLogger\.closePersistentSink\(\)/.test(entryAbility) &&
  /DiagnosticLogger\.info\('account-session', stage, 'stage'\)/.test(session) &&
  /DiagnosticsSettingsGroup/.test(settingsPage) &&
  /DiagnosticsFilesGroup/.test(settingsPage) &&
  /exportCurrentDiagnostics/.test(settingsPage))
ok('persistent diagnostics redact complete URLs before memory and file retention',
  /<redacted-url>/.test(diagnosticsRedactor) &&
  /\(\?:https\?\|socks5\)/.test(diagnosticsRedactor))

const sync = read('shared/src/main/ets/sync/SyncLocalDataAdapter.ets')
ok('dataset-specific history apply receives selection and seeds from local rows',
  /applyReadingHistory\(context, envelope, selection\)/.test(sync) &&
  /const local: NhReadingHistoryItem\[\] = await HistoryRepository\.exportForBackup\(context\)/.test(sync) &&
  /if \(selection\.viewedHistory\)/.test(sync) &&
  /if \(selection\.readProgress\)/.test(sync))
ok('GID-only rows are not uploaded as viewed-history snapshots',
  /item\.galleryId <= 0 \|\| SyncLocalDataAdapter\.isDisplayMetadataMissing\(item\)/.test(sync))

function clone(row) {
  return { ...row }
}
function find(rows, id) {
  return rows.find((row) => row.galleryId === id)
}
function applyHistory(local, viewed, progress, selection) {
  const items = selection.viewedHistory
    ? viewed.filter((row) => row.galleryId > 0 && row.deletedAt <= 0).map((row) => {
      const previous = find(local, row.galleryId)
      return {
        galleryId: row.galleryId,
        mediaId: row.mediaId || previous?.mediaId || '',
        title: row.title || previous?.title || '',
        thumbnailUrl: row.thumbnailUrl || previous?.thumbnailUrl || '',
        pageCount: row.pageCount > 0 ? row.pageCount : previous?.pageCount || 0,
        lastReadIndex: previous?.lastReadIndex || 0,
        hasReadProgress: previous?.hasReadProgress || false,
        lastOpenedAt: row.viewedAt,
      }
    })
    : local.map(clone)
  if (selection.readProgress) {
    for (const row of progress) {
      let item = find(items, row.galleryId)
      if (row.deletedAt > 0) {
        if (item) {
          item.hasReadProgress = false
          item.lastReadIndex = 0
        }
        continue
      }
      if (!item) {
        item = { galleryId: row.galleryId, mediaId: '', title: '', thumbnailUrl: '', pageCount: 0,
          lastReadIndex: 0, hasReadProgress: false, lastOpenedAt: row.updatedAt }
        items.push(item)
      }
      item.hasReadProgress = true
      item.lastReadIndex = row.pageIndex
      item.lastOpenedAt = Math.max(item.lastOpenedAt, row.updatedAt)
    }
  }
  return items
}

const original = [{ galleryId: 42, mediaId: 'm42', title: 'visible title', thumbnailUrl: 'cover',
  pageCount: 20, lastReadIndex: 3, hasReadProgress: true, lastOpenedAt: 100 }]
const afterProgress = applyHistory(original, [], [{ galleryId: 42, pageIndex: 8, updatedAt: 200, deletedAt: 0 }],
  { readProgress: true, viewedHistory: false })
ok('progress-only apply preserves title and cover while updating progress',
  afterProgress[0].title === 'visible title' && afterProgress[0].thumbnailUrl === 'cover' &&
  afterProgress[0].lastReadIndex === 8)

const afterViewed = applyHistory(afterProgress, [{ galleryId: 42, mediaId: 'm42', title: 'visible title',
  thumbnailUrl: 'cover', pageCount: 20, viewedAt: 100, deletedAt: 0 }], [],
  { readProgress: false, viewedHistory: true })
ok('viewed-history apply preserves the independently synced progress half',
  afterViewed[0].title === 'visible title' && afterViewed[0].lastReadIndex === 8 &&
  afterViewed[0].hasReadProgress)

if (failures === 0) {
  console.log('OK account ownership and history sync regressions passed')
  process.exit(0)
}
console.error(`[FAIL] account/history regressions: ${failures} failure(s)`)
process.exit(1)
