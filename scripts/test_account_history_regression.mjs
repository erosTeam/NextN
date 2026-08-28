#!/usr/bin/env node
/** Non-UI regressions for account ownership and split history sync. */
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import {
  runCfReviewedSubmit,
  runStagedLoginEpoch,
} from './run_arkweb_login_keychain_epoch.mjs'
import {
  classifyNativeRoute,
  resolveSemanticClickPoint,
} from './run_nextn_account_login_cycle.mjs'

const read = (path) => fs.readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
const root = fileURLToPath(new URL('../', import.meta.url))
const listEts = (directory) => fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
  const absolute = path.join(directory, entry.name)
  if (entry.isDirectory()) {
    return entry.name === 'build' || entry.name === 'oh_modules' ? [] : listEts(absolute)
  }
  return entry.isFile() && entry.name.endsWith('.ets') ? [absolute] : []
})
let failures = 0
function ok(name, condition) {
  if (!condition) {
    console.error(`[FAIL] ${name}`)
    failures += 1
  }
}

const session = read('shared/src/main/ets/services/NhAccountSessionService.ets')
const api = read('shared/src/main/ets/network/NhApiClient.ets')
const sessionHttpClient = read('shared/src/main/ets/network/NhSessionHttpClient.ets')
const nhApiHttpTransport = read('shared/src/main/ets/network/NhApiHttpTransport.ets')
const accountState = read('shared/src/main/ets/state/AccountSessionState.ets')
const browserPage = read('feature/user/src/main/ets/pages/BrowserSessionPage.ets')
const accountPage = read('feature/settings/src/main/ets/pages/AccountPage.ets')
const accountList = read('shared/src/main/ets/settings/AccountListSettings.ets')
const accountProfile = read('shared/src/main/ets/services/NhAccountProfileService.ets')
const sessionRepository = read('shared/src/main/ets/storage/AccountSessionRepository.ets')
const entryAbility = read('entry/src/main/ets/entryability/EntryAbility.ets')
const settingsPage = read('feature/settings/src/main/ets/pages/SettingsPage.ets')
const diagnosticsRedactor = read('shared/src/main/ets/diagnostics/DiagnosticsRedactor.ets')
const accountS0Collector = read('scripts/collect_nextn_account_s0.mjs')
const atomicLoginCycle = read('scripts/run_nextn_account_login_cycle.mjs')
const arkWebLoginDriver = read('scripts/drive_arkweb_login_field.mjs')
const arkWebLoginProbe = read('scripts/probe_arkweb_login_state.mjs')
const arkWebCookieShapeProbe = read('scripts/probe_arkweb_cookie_shape.mjs')
const entryIndex = read('entry/src/main/ets/pages/Index.ets')
const galleryCollectionBody = read('shared/src/main/ets/components/GalleryCollectionBody.ets')
const galleryDetailPage = read('feature/gallery/src/main/ets/pages/GalleryDetailPage.ets')
const galleryCommentsPage = read('feature/gallery/src/main/ets/pages/GalleryCommentsPage.ets')
const favoritesPage = read('feature/user/src/main/ets/pages/FavoritesPage.ets')
const cookieAuthority = read('shared/src/main/ets/services/NhCookieAuthority.ets')
const sharedIndex = read('shared/src/main/ets/Index.ets')
const applicationEtsFiles = ['entry', 'feature', 'shared']
  .flatMap((directory) => listEts(path.join(root, directory)))
const directCookieManagerFiles = applicationEtsFiles.filter((file) =>
  /WebCookieManager\./.test(fs.readFileSync(file, 'utf8')))
const arkWebRequestTransportFiles = applicationEtsFiles.filter((file) =>
  /NhArkWebSessionTransport/.test(fs.readFileSync(file, 'utf8')))
  .map((file) => path.relative(root, file)).sort()
const directNhSessionClientFiles = applicationEtsFiles.filter((file) => {
  const relative = path.relative(root, file)
  if (relative === 'shared/src/main/ets/network/NhSessionHttpClient.ets') {
    return false
  }
  return /NhSessionHttpClient\./.test(fs.readFileSync(file, 'utf8'))
}).map((file) => path.relative(root, file)).sort()
const directNhApiTransportFiles = applicationEtsFiles.filter((file) => {
  const relative = path.relative(root, file)
  if (relative === 'shared/src/main/ets/network/NhApiHttpTransport.ets') {
    return false
  }
  return /NhApiHttpTransport\./.test(fs.readFileSync(file, 'utf8'))
}).map((file) => path.relative(root, file)).sort()
const directNhApiOriginFiles = applicationEtsFiles.filter((file) =>
  /https:\/\/nhentai\.net\/api\/v2\//.test(fs.readFileSync(file, 'utf8')))
  .map((file) => path.relative(root, file)).sort()
const refreshTokenSinkCallers = applicationEtsFiles.filter((file) => {
  const relative = path.relative(root, file)
  if (relative === 'shared/src/main/ets/services/NhCookieAuthority.ets') {
    return false
  }
  return /storeRefreshedAuthTokens\(/.test(fs.readFileSync(file, 'utf8'))
}).map((file) => path.relative(root, file)).sort()

ok('account ownership is separate from request authentication',
  /@Trace signedIn: boolean/.test(accountState) &&
  /@Trace authenticationAvailable: boolean/.test(accountState) &&
  /retainedAccountPresent \|\| authenticated/.test(session))
ok('gallery account consumers require usable authentication rather than retained ownership alone',
  [galleryDetailPage, galleryCommentsPage].every((source) => {
    const gate = source.match(/private hasPublishedAccountSession\(\): boolean \{[\s\S]*?\n  \}/)?.[0] ?? ''
    return /accountSession\.initialized/.test(gate) &&
      /accountSession\.signedIn/.test(gate) &&
      /accountSession\.authenticationAvailable/.test(gate) &&
      /!this\.accountSession\.verificationRequired/.test(gate)
  }))
ok('cold start has a durable non-secret ownership marker cleared only by explicit clear',
  /ACCOUNT_PRESENT_KEY: string = 'account\.session\.present'/.test(session) &&
  /loadRetainedAccountMarker\(context\)/.test(session) &&
  /AccountSessionRepository\.clear\(context\)[\s\S]*persistRetainedAccountMarker\(context, false\)/.test(session) &&
  (session.match(/retainedAccountPresent = false/g) || []).length === 1)
const terminal401 = session.match(/private static async recordAuthenticatedTerminal401\([\s\S]*?\n  \}/)?.[0] || ''
const expiryShape = session.match(/private static recordAuthCookieExpiryShape\([\s\S]*?\n  \}/)?.[0] || ''
ok('a conclusive refresh or replay 401 preserves ownership and atomically publishes durable re-verification',
  /recordAuthenticatedReadReplay401[\s\S]*recordAuthenticatedTerminal401/.test(session) &&
  /recordAuthenticatedRefreshToken401[\s\S]*recordAuthenticatedTerminal401/.test(session) &&
  /recordAuthenticatedTerminal401/.test(terminal401) &&
  !/retainedAccountPresent\s*=\s*false/.test(terminal401) &&
  /AccountSessionRepository\.markVerificationRequired/.test(terminal401) &&
  /VERIFICATION_MARKER_PERSIST_FAILED/.test(terminal401) &&
  !/account_verification_marker_persist_failed/.test(terminal401) &&
  /verificationRequiredMarkerPresent\s*=\s*true/.test(terminal401) &&
  /cookieHeader\s*=\s*''/.test(terminal401) &&
  /publishSessionChange/.test(terminal401) &&
  !/AccountSessionRepository\.clear/.test(terminal401) &&
  /recordAuthenticatedReadInitial401/.test(sessionHttpClient) &&
  /recordAuthenticatedReadBrowserRefresh/.test(sessionHttpClient))
ok('current terminal reasons are accepted by the durable verification marker',
  /reasonCode !== 'terminal_401_replay_rejected'/.test(sessionRepository) &&
  /reasonCode !== 'terminal_401_refresh_token_rejected'/.test(sessionRepository) &&
  !/terminal_401_browser_refresh_unsuccessful/.test(sessionRepository) &&
  /verificationSnapshot\.reasonCode === 'terminal_401_refresh_token_rejected'/.test(session) &&
  !/verificationSnapshot\.reasonCode === 'terminal_401_browser_refresh_unsuccessful'/.test(session))
ok('auth lifetime diagnostics expose only fixed coarse access and refresh expiry classes',
  /account_auth_expiry_shape/.test(expiryShape) &&
  /phase=\$\{phase\};/.test(expiryShape) &&
  /access=\$\{NhAccountSessionService\.authCookieExpiryClass\(cookies, 'access_token'\)\}/.test(expiryShape) &&
  /refresh=\$\{NhAccountSessionService\.authCookieExpiryClass\(cookies, 'refresh_token'\)\}/.test(expiryShape) &&
  !/(cookie\.value|expiresDate|cookieHeader|browserUserAgent)/.test(expiryShape) &&
  /return 'absent'/.test(session) && /\? 'session' : 'unknown'/.test(session) &&
  /return 'unknown'/.test(session) && /return 'expired'/.test(session) &&
  /return 'lt_1h'/.test(session) && /return 'lt_24h'/.test(session) &&
  /return 'lt_7d'/.test(session) && /return 'ge_7d'/.test(session) &&
  /recordAuthCookieExpiryShape\('restore', payload\.authCookies\)/.test(session) &&
  /recordAuthCookieExpiryShape\([\s\S]*'initial_401'/.test(session))
ok('a rotated refresh pair gets bounded durable write and readback retries before replay',
  /AUTH_REFRESH_CHECKPOINT_MAX_ATTEMPTS: number = 3/.test(session) &&
  /for \(let attempt: number = 1; attempt <= AUTH_REFRESH_CHECKPOINT_MAX_ATTEMPTS; attempt \+= 1\)/.test(
    session,
  ) &&
  /AccountSessionRepository\.saveVerifiedForAccount\([\s\S]*AccountSessionRepository\.loadForRestore\(context\)/.test(
    session,
  ) &&
  /persisted\.record\.ciphertext !== record\.ciphertext/.test(session) &&
  /account_refresh_checkpoint_retry/.test(session) &&
  /account_refresh_checkpoint_recovered/.test(session) &&
  /account_refresh_checkpoint_failed/.test(session) &&
  /if \(!checkpointed\) \{[\s\S]*return false/.test(session))
ok('all first-party v2 requests share one credential-aware request lifecycle',
  /NhSessionHttpClient\.requestJson/.test(api) &&
  !/requestBrowserResponse/.test(api) &&
  /NhApiHttpTransport\.requestJson\(url, method, body, authorization\)/.test(sessionHttpClient) &&
  /NhAccountSessionService\.authenticatedAuthorization\(readToken\)/.test(sessionHttpClient) &&
  /authenticatedRefreshRequestBody\(readToken\)/.test(sessionHttpClient) &&
  /applyRefreshedApiTokens/.test(sessionHttpClient) &&
  !/syncSealedSessionFromRegularJar/.test(sessionHttpClient) &&
  /NhRequestReplayPolicy\.NEVER/.test(api) &&
  /replayPolicy === NhRequestReplayPolicy\.SAFE_AFTER_REFRESH/.test(sessionHttpClient) &&
  !/http\.createHttp\(\)/.test(api) &&
  !/recoverRegularArkWebCookieJarAfterAuthenticated401/.test(api))
ok('native authentication truth requires one sealed access and exact refresh pair',
  /static isAuthenticated\(\): boolean \{[\s\S]*hasAccessAuthCookie\(NhAccountSessionService\.sealedAuthCookies\)[\s\S]*hasRefreshAuthCookie\(NhAccountSessionService\.sealedAuthCookies\)/.test(session) &&
  !/browserIdentityVerified/.test(session) &&
  !/hasLoginCookies\(NhAccountSessionService\.cookieHeader\) \|\|/.test(session))
ok('NH API v2 has one native wire transport and ArkWeb is not its request path',
  JSON.stringify(directNhApiTransportFiles) === JSON.stringify([
    'shared/src/main/ets/network/NhSessionHttpClient.ets',
  ]) &&
  /AxiosHttpClient\.requestText/.test(nhApiHttpTransport) &&
  /ArkWeb is therefore a visible CAPTCHA host/.test(nhApiHttpTransport) &&
  arkWebRequestTransportFiles.length === 0)
ok('ArkWeb cookies have one native authority and cannot be managed by page or ability code',
  directCookieManagerFiles.length === 1 &&
  path.relative(root, directCookieManagerFiles[0]) ===
    'shared/src/main/ets/services/NhCookieAuthority.ets' &&
  /putAcceptCookieEnabled\(true\)/.test(cookieAuthority) &&
  /putAcceptThirdPartyCookieEnabled\(true\)/.test(cookieAuthority) &&
  /fetchAllAuthCookies\(\)[\s\S]*fetchAllCookies\(false\)/.test(cookieAuthority) &&
  /SDK boolean selects the incognito cookie store/.test(cookieAuthority) &&
  !/fetchAllCookies\(true\)/.test(cookieAuthority) &&
  !/fetchAllCookies\(includeHttpOnly/.test(cookieAuthority) &&
  /configCookieSync/.test(cookieAuthority) &&
  /saveCookieAsync/.test(cookieAuthority))
ok('post-submit Web authentication diagnosis exposes only one fixed renewable-auth boolean',
  /runCookieShape/.test(atomicLoginCycle) &&
  /cookieShape\.renewableAuthPresent === true/.test(atomicLoginCycle) &&
  /stage: 'cookie_shape'/.test(arkWebCookieShapeProbe) &&
  /renewableAuthPresent: accessTokenPresent && refreshTokenPresent/.test(
    arkWebCookieShapeProbe,
  ) &&
  !/firstPartyCookies|firstPartyCookieCount|recognized:|httpOnly:|sameSite:/.test(
    arkWebCookieShapeProbe,
  ))
ok('visible-login candidate diagnostics expose only fixed presence shape',
  /candidate_shape_incomplete/.test(session) &&
  /headerAccess=\$\{headerAccessAvailable \? 1 : 0\};ua=\$\{userAgentAvailable \? 1 : 0\}/.test(session) &&
  /authCount=\$\{authCookies\.length\};authAccess=\$\{authAccessAvailable \? 1 : 0\}/.test(session) &&
  !/candidate_shape_incomplete[\s\S]{0,600}(cookie\.value|normalizedUserAgent|normalized\})/.test(session))
ok('visible-login Cookie metadata cannot strand a verified URL-scoped token pair',
  /VISIBLE_AUTH_COOKIE_SNAPSHOT_TIMEOUT_MS: number = 1500/.test(session) &&
  /captureVisibleCandidateAuthCookies\(normalized\)/.test(session) &&
  /captureFirstPartyAuthCookiesWithinTimeout/.test(session) &&
  /cookieValue\(cookieHeader, 'access_token'\)/.test(session) &&
  /cookieValue\(cookieHeader, 'refresh_token'\)/.test(session) &&
  /candidate_cookie_metadata_fallback/.test(session) &&
  /apiTokenCookie\('access_token', access, false\)/.test(session) &&
  /apiTokenCookie\('refresh_token', refresh, true\)/.test(session))
ok('the app uses the system-selected ArkWeb kernel and records its fixed profile',
  !/setActiveWebEngineVersion\(/.test(entryAbility) &&
  /activeEngine === webview\.ArkWebEngineVersion\.M144 \? 'm144'/.test(entryAbility) &&
  /activeEngine === webview\.ArkWebEngineVersion\.M132 \? 'm132'/.test(entryAbility) &&
  /getActiveWebEngineVersion\(\)/.test(entryAbility) &&
  !/setUserAgent\(|userAgent\(/.test(entryAbility))
ok('the obsolete ArkWeb request transport and hidden root host are absent',
  arkWebRequestTransportFiles.length === 0 &&
  !/NhArkWebSessionTransportHost/.test(entryIndex) &&
  !/NhArkWebSessionTransportHost/.test(sharedIndex) &&
  !/export\s*\{[^}]*NhSessionHttpClient(?:\s|,)/.test(sharedIndex) &&
  !/NhArkWebSessionTransport/.test(browserPage) &&
  !/@kit\.NetworkKit/.test(api))
ok('feature code cannot create a second NH endpoint or session-request path',
  JSON.stringify(directNhSessionClientFiles) === JSON.stringify([
    'shared/src/main/ets/network/NhApiClient.ets',
  ]) &&
  JSON.stringify(directNhApiOriginFiles) === JSON.stringify([
    'shared/src/main/ets/network/NhApiHttpTransport.ets',
    'shared/src/main/ets/network/NhSessionHttpClient.ets',
  ]))
ok('authenticated requests have no root ArkWeb attachment dependency',
  !/CONTROLLER_ATTACH_TIMEOUT_MS|waitForControllerAttach|controller_attach_wait/.test(sessionHttpClient) &&
  !/NhArkWebSessionTransportHost/.test(entryIndex))
ok('401 recovery never replaces the promoted generation from a browser request path',
  !/forceRegularArkWebCookieJarFromSealedSession/.test(session) &&
  !/AUTHENTICATED_READ_SEALED_REPLAY/.test(session) &&
  !/runJavaScript|document\.cookie|credentials:\s*'include'/.test(sessionHttpClient))
ok('401 refresh atomically advances HUKS and the compatibility Cookie sink',
  /return JSON\.stringify\(\{[\s\S]*'refresh_token': refreshValue,[\s\S]*\}\)/.test(session) &&
  !/'refreshToken': refreshValue|'refresh': refreshValue/.test(session) &&
  /auth\/refresh/.test(sessionHttpClient) &&
  /typeof accessValue === 'string' && typeof refreshValue === 'string'/.test(sessionHttpClient) &&
  /NhSessionHttpClient\.validApiToken\(accessValue\)/.test(sessionHttpClient) &&
  /NhSessionHttpClient\.validApiToken\(refreshValue\)/.test(sessionHttpClient) &&
  /responseCookieResult === NhResponseAuthCookieResult\.APPLIED/.test(sessionHttpClient) &&
  /NhAccountSessionService\.applyRefreshedApiTokens/.test(sessionHttpClient) &&
  /const refresh: string = NhAccountSessionService\.safeApiToken\(refreshToken\)/.test(session) &&
  !/priorRefresh|refreshCandidate/.test(session.match(
    /static async applyRefreshedApiTokens\([\s\S]*?\n  \}/,
  )?.[0] ?? '') &&
  /NhApiHttpTransport\.requestJson\([\s\S]*API_USER_URL/.test(sessionHttpClient) &&
  /consumeResponseSetCookies\(verificationResponse, readToken\)/.test(sessionHttpClient) &&
  /AccountSessionRepository\.saveVerifiedForAccount/.test(session) &&
  /NhCookieAuthority\.storeRefreshedAuthTokens/.test(session) &&
  /applyRefreshedApiTokens\(token, access, refresh, true\)/.test(session) &&
  /if \(!responseCookieSinkOwnedByCaller\)[\s\S]*NhCookieAuthority\.storeRefreshedAuthTokens/.test(
    session.match(/static async applyRefreshedApiTokens\([\s\S]*?\n  \}/)?.[0] ?? '',
  ) &&
  /storeFirstPartyResponseCookies[\s\S]*NhCookieAuthority\.NH_ORIGIN,[\s\S]*header,[\s\S]*false,[\s\S]*true,/.test(
    cookieAuthority,
  ) &&
  JSON.stringify(refreshTokenSinkCallers) === JSON.stringify([
    'shared/src/main/ets/services/NhAccountSessionService.ets',
  ]) &&
  /access_token=\$\{access\}; Max-Age=1209600; Path=\/; Secure; SameSite=Lax/.test(cookieAuthority) &&
  /refresh_token=\$\{refresh\}; Max-Age=1209600; Path=\/; Secure; HttpOnly; SameSite=Lax/.test(cookieAuthority))
ok('candidate verification and account profile use the same native request boundary',
  /pendingApiTokenAuthorization\(\)/.test(sessionHttpClient) &&
  /requestCandidateStatus[\s\S]*NhApiHttpTransport\.requestJson\([\s\S]*API_USER_URL[\s\S]*authorization/.test(
    sessionHttpClient,
  ) &&
  /requestCandidateStatus[\s\S]*consumeResponseSetCookies\(response, null\)/.test(sessionHttpClient) &&
  /requestJson\([\s\S]*API_USER_URL[\s\S]*NhRequestScope\.ACCOUNT_OWNED/.test(sessionHttpClient) &&
  /record\['username'\]/.test(sessionHttpClient) &&
  /record\['slug'\]/.test(sessionHttpClient) &&
  /record\['avatar_url'\]/.test(sessionHttpClient) &&
  !/verifyAccountSessionFromVisibleBrowser/.test(api))
ok('account failures use the root notice channel rather than an inline fixed row',
  /accountAuthNotice\.publish\('persistence_failed'\)/.test(browserPage) &&
  /accountAuthNotice\.publish\('unavailable'\)/.test(browserPage) &&
  !/accountActionError/.test(browserPage))
ok('visible login uses the real first-party page and native candidate promotion only',
  /this\.controller\.loadUrl\(NhBrowserSessionBoundary\.loginUrl\(\)\)/.test(browserPage) &&
  /startSessionCaptureTimer\(\)/.test(browserPage) &&
  /captureVisibleBrowserSession/.test(browserPage) &&
  /verifyAccountSession/.test(browserPage) &&
  /confirmPendingVisibleBrowserSession/.test(browserPage) &&
  !/API_CAPTCHA_URL|API_LOGIN_POW_URL|API_LOGIN_URL/.test(sessionHttpClient) &&
  !/prepareApiTokenLogin|loginAndPromoteApiToken/.test(api) &&
  !/access_token|refresh_token/.test(browserPage) &&
  /accountAuthNotice\.publish/.test(browserPage) &&
  /HdsSnackBar/.test(entryIndex))
ok('a visible login transaction cannot be closed by a late old-session revision',
  /if \(this\.isBrowserRequested\) \{[\s\S]*visible login stage=session_revision_deferred/.test(browserPage) &&
  /visible login stage=session_revision_deferred/.test(browserPage) &&
  /this\.accountAuthNotice\.clear\(\)[\s\S]*registerExplicitVisibleLoginAction/.test(browserPage))
ok('production login never extracts credentials or replaces the first-party document',
  !/runJavaScript/.test(browserPage) &&
  !/API_LOGIN_FRAME_PREFIX|API_LOGIN_CHALLENGE_PREFIX|API_LOGIN_SURFACE_URL/.test(browserPage) &&
  !/onInterceptRequest|WebResourceResponse|loadData\(/.test(browserPage) &&
  !/apiLoginHtml|__nextnApiLogin/.test(browserPage))
ok('ArkWeb login resource failures persist only fixed code and target classes',
  /loginResourceTarget/.test(browserPage) &&
  /turnstile_script/.test(browserPage) &&
  /turnstile_pat/.test(browserPage) &&
  /turnstile_challenge_response/.test(browserPage) &&
  /turnstile_iframe/.test(browserPage) &&
  /turnstile_capability_measurement/.test(browserPage) &&
  /turnstile_device_signal/.test(browserPage) &&
  /turnstile_interaction_signal/.test(browserPage) &&
  /turnstile_runtime/.test(browserPage) &&
  /event\.error\.getErrorCode\(\)/.test(browserPage) &&
  /event\.request\.getRequestUrl\(\)/.test(browserPage) &&
  /first_party_challenge/.test(browserPage) &&
  /first_party_favicon/.test(browserPage) &&
  /status=\$\{status\},method=\$\{method\},target=\$\{target\},mainFrame=\$\{mainFrame\}/.test(browserPage) &&
  !/getErrorInfo\(\)/.test(browserPage))
ok('ArkWeb login diagnostics retain only a fixed browser capability shape',
  /browserIdentityProfile/.test(browserPage) &&
  /chromium=\$\{chromiumMajor\},harmony=/.test(browserPage) &&
  !/browser_identity[^\n]*browserSessionUserAgent/.test(browserPage))
ok('visible login restores the proven NextE-compatible UA before first navigation',
  /NhAccountSessionService\.nextECompatibleUserAgent\(nativeUserAgent\)/.test(browserPage) &&
  /static nextECompatibleUserAgent\(nativeUserAgent: string\): string/.test(session) &&
  /Android 10\) AppleWebKit/.test(session) &&
  /this\.controller\.setCustomUserAgent\(nextECompatibleUserAgent\)/.test(browserPage) &&
  !/configuredUserAgentOverride/.test(browserPage))
ok('visible login restores the original online cache mode without clearing cookies',
  /\.cacheMode\(CacheMode\.Online\)/.test(browserPage))
ok('Turnstile console diagnostics retain only a documented fixed client error code',
  /turnstileConsoleErrorCode/.test(browserPage) &&
  /\(\?:100\|102\|103\|104\|105\|106\|110\|200\|300\|400\|600\)\\d\{3\}/.test(browserPage) &&
  /network_http_failure/.test(browserPage) &&
  /turnstile_client_error[\s\S]*code=\$\{errorCode\}/.test(browserPage) &&
  !/turnstile_client_error[\s\S]{0,180}getMessage\(\)/.test(browserPage) &&
  !/turnstile_client_error[\s\S]{0,180}getSourceId\(\)/.test(browserPage))
ok('S0 uses the fixed current-process Favorites outcome when cached cards remain mounted',
  /const AUTHORIZED_TARGET = '192\.168\.50\.237:12345'/.test(accountS0Collector) &&
  !/192\.168\.50\.(?:197|200):12345|56T0225315001128/.test(accountS0Collector) &&
  /collectFavoritesRequestOutcome/.test(accountS0Collector) &&
  /requestOutcome === 'failed'[\s\S]*summary\.error = true[\s\S]*summary\.authenticated = false/.test(accountS0Collector) &&
  /requestOutcome === 'success'[\s\S]*summary\.error = false[\s\S]*summary\.authenticated = true/.test(accountS0Collector))
const credentialPreparation = atomicLoginCycle.indexOf("invokeKeychainHandle('account'")
const visibleLoginRoute = atomicLoginCycle.indexOf(
  'routeVisibleLogin(options, artifactDir, routeLabels)', credentialPreparation)
const stagedCredentialEpoch = atomicLoginCycle.indexOf(
  'runStagedLoginEpoch({', visibleLoginRoute)
const postCredentialCfGate = atomicLoginCycle.indexOf(
  'waitForPostCredentialCfGate(forward.localPort', stagedCredentialEpoch)
const fixedSubmit = atomicLoginCycle.indexOf(
  'runCfReviewedSubmit({', postCredentialCfGate)
const nativePromotion = atomicLoginCycle.indexOf(
  'observeNativePromotion(options, artifactDir', fixedSubmit)
ok('authorized login is one external atomic original-WebView queue with autonomous CF action',
  /const AUTHORIZED_TARGET = '192\.168\.50\.237:12345'/.test(atomicLoginCycle) &&
  !/192\.168\.50\.(?:197|200):12345|56T0225315001128/.test(atomicLoginCycle) &&
  /target === AUTHORIZED_TARGET && lease\.length > 0/.test(atomicLoginCycle) &&
  credentialPreparation >= 0 && visibleLoginRoute > credentialPreparation &&
  stagedCredentialEpoch > visibleLoginRoute && postCredentialCfGate > stagedCredentialEpoch &&
  fixedSubmit > postCredentialCfGate &&
  nativePromotion > fixedSubmit &&
  /CF_READY_TO_SUBMIT_CEILING_MS = 5000/.test(atomicLoginCycle) &&
  /LOGIN_FLOW_CEILING_MS = 120000/.test(atomicLoginCycle) &&
  /VISIBLE_LOGIN_ROUTE_ATTEMPTS = 12/.test(atomicLoginCycle) &&
  /for \(let index = 0; index < VISIBLE_LOGIN_ROUTE_ATTEMPTS; index \+= 1\)/.test(atomicLoginCycle) &&
  /index === 0 && !options\.resumeVisible/.test(atomicLoginCycle) &&
  /bring-nextn-to-foreground-without-hidden-route/.test(atomicLoginCycle) &&
  !/nextn_login_recovery/.test(atomicLoginCycle) &&
  /account_verify_sign_in/.test(atomicLoginCycle) &&
  /nextn-settings-root-account/.test(atomicLoginCycle) &&
  /resolveSemanticClickPoint/.test(atomicLoginCycle) &&
  /nextn-account-list-root/.test(atomicLoginCycle) &&
  /nextn-account-saved-row/.test(atomicLoginCycle) &&
  !/nextn-account-native-root|nextn-account-authenticated-profile|nextn-account-authenticated-sign-out/.test(
    atomicLoginCycle,
  ) &&
  /action: 'blur-active'[\s\S]*editor_exit_not_proven/.test(atomicLoginCycle) &&
  /classifyCaptchaLayout[\s\S]*type \|\| ''\)\.toLowerCase\(\) === 'alert'[\s\S]*成功\|success/.test(atomicLoginCycle) &&
  /type \|\| ''\)\.toLowerCase\(\) === 'checkbox'[\s\S]*真人\|human/.test(atomicLoginCycle) &&
  /captcha\.state === 'needs_click'[\s\S]*activateVisibleCaptcha\(options, artifactDir, captcha\.x, captcha\.y\)/.test(atomicLoginCycle) &&
  /challengeResponsePresent === true[\s\S]*challengeResponseReady === true/.test(atomicLoginCycle) &&
  /captcha_token_not_ready/.test(atomicLoginCycle) &&
  !/CF_DISCOVERY_SETTLE_MS|freshWithoutWidgetSince|waitForPreCredentialCfGate/.test(atomicLoginCycle) &&
  /DEVICE_PROTOCOL_SCRIPT[\s\S]*runProtocol/.test(atomicLoginCycle) &&
  /DEBUG_WEB_DEVTOOLS_PORT = 19222/.test(atomicLoginCycle) &&
  /remoteSocket\.length > 0[\s\S]*localabstract:[\s\S]*tcp:\$\{DEBUG_WEB_DEVTOOLS_PORT\}/.test(atomicLoginCycle) &&
  /'fport', 'rm', `tcp:\$\{forward\.localPort\}`, forward\.remoteEndpoint/.test(atomicLoginCycle) &&
  !/cf_intervention_required/.test(atomicLoginCycle) &&
  !/forceStop|hdcRun|device-lease/.test(atomicLoginCycle) &&
  /flowDeadlineAt = flowStartedAt \+ LOGIN_FLOW_CEILING_MS/.test(atomicLoginCycle) &&
  /Date\.now\(\) < deadlineAt/.test(atomicLoginCycle) &&
  /waitForLoginWebExit\(port, deadlineAt\)/.test(atomicLoginCycle) &&
  /PROMOTION_LAYOUT_ATTEMPTS = 3/.test(atomicLoginCycle) &&
  !/PROMOTION_POLLS|postflight: actions/.test(atomicLoginCycle) &&
  /nativeAuthenticated: accountList && savedAccount && signOutAction && !web/.test(atomicLoginCycle) &&
  /if \(state\.nativeAuthenticated\)/.test(atomicLoginCycle))
const routeLabels = {
  verify: new Set(['Verify again']),
  signOut: new Set(['Sign out of this device']),
}
const retainedVerificationLayout = {
  attributes: { visible: 'true' },
  children: [
    { attributes: { visible: 'true', id: 'nextn-account-list-root' } },
    { attributes: { visible: 'true', id: 'nextn-account-saved-row' } },
    {
      attributes: { visible: 'true', clickable: 'true', enabled: 'true', bounds: '[900,1700][1280,1800]' },
      children: [{ attributes: { visible: 'true', text: 'Verify again' } }],
    },
  ],
}
const authenticatedAccountLayout = {
  attributes: { visible: 'true' },
  children: [
    { attributes: { visible: 'true', id: 'nextn-account-list-root' } },
    { attributes: { visible: 'true', id: 'nextn-account-saved-row' } },
    {
      attributes: { visible: 'true', clickable: 'true', enabled: 'true', bounds: '[100,1500][1220,1650]' },
      children: [{ attributes: { visible: 'true', accessibilityText: 'Sign out of this device' } }],
    },
  ],
}
ok('retained selected account is not native authentication and its normal verification action is semantic',
  classifyNativeRoute(retainedVerificationLayout, routeLabels).nativeAuthenticated === false &&
  JSON.stringify(resolveSemanticClickPoint(retainedVerificationLayout, routeLabels.verify)) ===
    JSON.stringify({ x: 1090, y: 1750 }))
ok('native promotion requires the signed-in-only account action in addition to the retained row',
  classifyNativeRoute(authenticatedAccountLayout, routeLabels).nativeAuthenticated === true)
ok('hidden empty challenge response fields do not manufacture a visible CAPTCHA',
  /const challengeWidgetPresent = challengeFrameDetected \|\| challengeContainerPresent/.test(arkWebLoginProbe) &&
  /const challengeResponsePresent = challengeResponse !== null/.test(arkWebLoginProbe) &&
  /const challengeFramePresent = challengeWidgetPresent && !challengeResponseReady/.test(arkWebLoginProbe) &&
  (arkWebLoginDriver.match(/\(challengeFrameDetected \|\| challengeContainerPresent\) && !challengeResponseReady/g) || []).length >= 2 &&
  (arkWebLoginDriver.match(/challengeResponsePending/g) || []).length >= 4 &&
  !/challengeResponse !== null \|\| challengeFrameDetected \|\| challengeContainerPresent/.test(arkWebLoginProbe + arkWebLoginDriver))
const challengeActions = []
const challengeProbeSequence = [
  { accountFieldFocused: false, accountFieldFilled: false, passwordFieldFocused: false, passwordFieldFilled: false },
  { accountFieldFocused: true, accountFieldFilled: false, passwordFieldFocused: false, passwordFieldFilled: false },
  { accountFieldFocused: false, accountFieldFilled: true, passwordFieldFocused: false, passwordFieldFilled: false },
  { accountFieldFocused: false, accountFieldFilled: true, passwordFieldFocused: true, passwordFieldFilled: false },
  { accountFieldFocused: false, accountFieldFilled: true, passwordFieldFocused: false, passwordFieldFilled: true },
]
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
    passwordFieldPresent: true,
    passwordFieldMasked: true,
    challengeFramePresent: true,
    challengeResponsePresent: true,
    challengeResponseReady: false,
    ...(challengeProbeSequence.shift() || {}),
  }),
  semanticDriver: async (options) => {
    challengeActions.push(options.action)
    return options.action === 'focus-account'
      ? { ok: true, accountFieldFocused: true, actionApplied: true }
      : { ok: true, passwordFieldFocused: true, actionApplied: true }
  },
  secretFill: async (options) => {
    challengeActions.push(`fill-${options.field}`)
    return { ok: true, fieldInputApplied: true }
  },
})
ok('credential staging completes once before the pending CF gate and never submits',
  challengeResult.ok === true && challengeResult.stage === 'credentials_staged' &&
  challengeResult.accountEntered === true && challengeResult.passwordEntered === true &&
  challengeResult.submitIssued === false &&
  challengeActions.join(',') === 'focus-account,fill-account,focus-password,fill-password')
const incompleteChallengeSubmitActions = []
const incompleteChallengeSubmit = await runCfReviewedSubmit({ port: 1, timeoutMs: 500 }, {
  probe: async () => ({
    ok: true,
    loginFormPresent: true,
    accountFieldPresent: true,
    accountFieldFilled: true,
    passwordFieldPresent: true,
    passwordFieldFilled: true,
    passwordFieldMasked: true,
    submitPresent: true,
    submitEnabled: true,
    formValid: true,
    submitEligible: true,
    challengeFramePresent: false,
    challengeResponsePresent: true,
    challengeResponseReady: false,
  }),
  semanticDriver: async (options) => {
    incompleteChallengeSubmitActions.push(options.action)
    return { ok: true }
  },
})
ok('an empty CAPTCHA response blocks the sole submit after both fields are staged',
  incompleteChallengeSubmit.ok === false && incompleteChallengeSubmit.code === 'captcha_token_not_ready' &&
  incompleteChallengeSubmit.accountEntered === true && incompleteChallengeSubmit.passwordEntered === true &&
  incompleteChallengeSubmit.submitIssued === false && incompleteChallengeSubmitActions.length === 0)
ok('empty signed-out account entry goes directly to the visible login page',
  /private openAccountEntry\(\)[\s\S]*accountList\.accounts\.length === 0[\s\S]*!this\.accountSession\.signedIn[\s\S]*this\.pushVisibleLoginSession\(\)/.test(entryIndex) &&
  /private pushVisibleLoginSession\(\)[\s\S]*new BrowserSessionRouteParams\(true\)/.test(entryIndex) &&
  /onOpenAccount:[\s\S]{0,120}this\.openAccountEntry\(\)/.test(entryIndex) &&
  /accessibilityId: 'nextn-settings-root-account'[\s\S]{0,320}if \(this\.onOpenAccount\)[\s\S]{0,120}this\.onOpenAccount\(\)/.test(settingsPage) &&
  !/accessibilityId: 'nextn-settings-root-account'[\s\S]{0,320}if \(this\.isAccountSignedIn && this\.onOpenAccount\)/.test(settingsPage))
ok('AccountPage is the sole native account manager and every login destination starts original Web directly',
  /ForEach\([\s\S]{0,80}this\.accountList\.accounts/.test(accountPage) &&
  /Radio\(\{ value: accountId, group: 'nextn_accounts' \}\)/.test(accountPage) &&
  /AccountListSettings\.switchTo/.test(accountPage) &&
  /nextn-account-list-root/.test(accountPage) &&
  !/onOpenBrowserSession/.test(accountPage) &&
  /private pushBrowserSession\(addAccountMode: boolean = false\)[\s\S]*new BrowserSessionRouteParams\(true, addAccountMode\)/.test(
    entryIndex,
  ) &&
  /onLoginFlowFinished:[\s\S]{0,120}this\.closeBrowserSessionToAccount\(\)/.test(entryIndex) &&
  /private consumeInitialLoginAction\(\): void[\s\S]*this\.requestAddAccountSession\(\)[\s\S]*this\.requestExplicitBrowserSession\(\)/.test(
    browserPage,
  ) &&
  /\bWeb\(\{/.test(browserPage) &&
  !/AccountSection|SecondaryListScaffold|nextn-account-native-root|nextn-account-authenticated-profile|nextn-account-authenticated-sign-out|confirmSignOut/.test(
    browserPage,
  ))
ok('visible login promotion cannot complete without a saved selected account row',
  /recordActive\(context: common\.UIAbilityContext\): Promise<boolean>/.test(accountList) &&
  /if \(!await AccountListSettings\.recordActive\(this\.hostContext\(\)\)\)[\s\S]*closeBrowserAfterPromotionFailure\(\)/.test(browserPage))
ok('retained ownership cannot consume the one-shot return before re-verification promotes',
  /if \(this\.accountSession\.authenticationAvailable &&[\s\S]*!this\.accountSession\.verificationRequired\)[\s\S]*finishLoginFlowToAccount\(\)/.test(
    browserPage,
  ) &&
  !/if \(this\.accountSession\.signedIn\)[\s\S]{0,500}finishLoginFlowToAccount\(\)/.test(browserPage))
ok('visible login promotion stages use the live domain and persistent redacted diagnostics',
  /ACCOUNT_LOG_DOMAIN: number = 0xD001/.test(browserPage) &&
  /DiagnosticLogger\.info\('account-login', 'candidate_captured', 'stage'\)/.test(browserPage) &&
  /DiagnosticLogger\.info\('account-login', 'native_session_promoted', 'stage'\)/.test(browserPage) &&
  /DiagnosticLogger\.error\('account-login', 'active_account_record_failed', 'stage'\)/.test(browserPage))
ok('retained gallery collections never render an inline internal error or retry row',
  !/InlineRetryNotice/.test(galleryCollectionBody) &&
  !/InlineError/.test(galleryCollectionBody) &&
  !/hasInlineError/.test(galleryCollectionBody))
ok('terminal authentication uses one root HDS Snackbar and no retained-list error row',
  /accountVerificationSnackBar: HdsSnackBar/.test(entryIndex) &&
  /handleAccountVerificationRequired/.test(entryIndex) &&
  /this\.safeMode\.restricted\(\) \|\| this\.browserSessionRouteActive\(\)/.test(entryIndex) &&
  /displayedAccountVerificationRevision/.test(entryIndex) &&
  /accountVerificationSnackBarVisible/.test(entryIndex) &&
  /Suppression is not user handling/.test(entryIndex) &&
  /onContentClick:[\s\S]*lastHandledAccountVerificationRevision = verificationRevision/.test(entryIndex) &&
  /onCloseButtonClick:[\s\S]*lastHandledAccountVerificationRevision = verificationRevision/.test(entryIndex) &&
  /didShow:[\s\S]*handleAccountVerificationRequired\(\)[\s\S]*handleAccountAuthNotice\(\)/.test(entryIndex) &&
  /onSafeModeChanged\(\): void[\s\S]*handleAccountVerificationRequired\(\)[\s\S]*handleAccountAuthNotice\(\)/.test(entryIndex) &&
  /private pushVisibleLoginSession\(\)[\s\S]*accountVerificationSnackBar\.dismiss\(\)[\s\S]*accountAuthNoticeSnackBar\.dismiss\(\)[\s\S]*pushPathByName\(ROUTE_BROWSER_SESSION/.test(entryIndex) &&
  /SnackBarOperationType\.TEXT_WITH_CLOSE/.test(entryIndex) &&
  /const style: SnackBarStyleOptions = \{[\s\S]*duration: 0,[\s\S]*\}[\s\S]*accountVerificationSnackBar\.show/.test(entryIndex) &&
  /account_verify_sign_in/.test(entryIndex) &&
  !/account_verify_sign_in/.test(browserPage) &&
  /loadRetainedAccountCacheOnly/.test(favoritesPage) &&
  !/InlineRetryNotice/.test(favoritesPage))
ok('saved-account selection has its own durable key and migrates one unambiguous legacy account',
  /ACTIVE_ACCOUNT_ID_KEY: string = 'account\.list\.activeId'/.test(accountList) &&
  /return ids\.length === 1 \? ids\[0\] : ''/.test(accountList) &&
  /NhAccountSessionService\.setActiveSavedAccountId\(snapshot\.activeAccountId\)/.test(accountList))
ok('account switch persists the selected profile back to the primary profile slot',
  /static async switchTo[\s\S]*AccountProfileRepository\.saveIfCurrent[\s\S]*connectAccountProfile\(\)\.replace\(profile\)/.test(accountProfile) &&
  /profileSwitched: boolean[\s\S]*if \(!profileSwitched\)[\s\S]*return false[\s\S]*ACTIVE_ACCOUNT_ID_KEY/.test(accountList))
ok('refreshed native tokens atomically update both primary and active saved envelopes',
  /saveVerifiedForAccount[\s\S]*SQL_UPSERT_SESSION[\s\S]*accountId\.length > 0[\s\S]*SQL_UPSERT_SESSION/.test(sessionRepository) &&
  /applyRefreshedApiTokens[\s\S]*saveVerifiedForAccount\([\s\S]*activeSavedAccountId/.test(session))
ok('sealed session v3 requires the exact native access and refresh pair',
  /RECOVERABLE_ARKWEB_COOKIE_NAMES[\s\S]*'access_token'[\s\S]*'refresh_token'[\s\S]*'sessionid'/.test(session) &&
  /fetchAllAuthCookies\(\)/.test(session) &&
  !/fetchAllCookies\(false\)/.test(session) &&
  /'version': 3[\s\S]*'authCookies': authCookies/.test(session) &&
  /if \(version === 2\)[\s\S]*legacy_v2_access_only[\s\S]*return payload/.test(session) &&
  /private static hasRefreshAuthCookie\(cookies: SealedAuthCookie\[\]\): boolean \{[\s\S]*cookie\.name === 'refresh_token'[\s\S]*cookie\.value\.length > 0/.test(session) &&
  !/private static hasRefreshAuthCookie[\s\S]{0,300}sessionid/.test(session) &&
  !/private static hasRefreshAuthCookie[\s\S]{0,300}ipb_pass_hash/.test(session) &&
  /!NhAccountSessionService\.hasRefreshAuthCookie\(payload\.authCookies\)[\s\S]*auth_renewal_missing/.test(session) &&
  !/valid_v2/.test(session) &&
  /configCookieSync\([\s\S]*authCookieSetValue\([\s\S]*false,[\s\S]*true/.test(session))
ok('saved-account switching refuses envelopes without refresh authority before deleting live cookies',
  /switchToSaved[\s\S]*!NhAccountSessionService\.hasRefreshAuthCookie\(payload\.authCookies\)[\s\S]*return false[\s\S]*expireVisibleBrowserIdentityCookies\(\)/.test(session))
ok('saving an account snapshots the current sealed native generation, not a browser jar',
  /saveActiveAsSaved[\s\S]*isAuthenticated\(\)[\s\S]*serializeSessionPayload\([\s\S]*sealedAuthCookies[\s\S]*saveVerifiedByKey/.test(session) &&
  !/saveActiveAsSaved[\s\S]{0,900}captureFirstPartyAuthCookies/.test(session))
ok('promotion durably records the selected saved envelope',
  /await AccountListSettings\.recordActive\(this\.hostContext\(\)\)/.test(browserPage) &&
  /saveActiveAsSaved[\s\S]*saveVerifiedByKey/.test(session))
ok('saved-envelope cold recovery is independent of the compatibility ArkWeb jar',
  /if \(restoredPayload === null && savedRecords\.length > 0\)/.test(session) &&
  !/if \(restoredPayload === null && savedRecords\.length > 0 && !regularJarReady\)/.test(session) &&
  /RESTORE_SAVED_ENVELOPE_USED/.test(session))
ok('same-account native refresh checkpoints do not invalidate concurrent reads or publish account revisions',
  /beginDurableSessionTransition\(false\)/.test(session) &&
  /sessionTransitionChangesOwnership/.test(session) &&
  /token\.sessionEpoch === NhAccountSessionService\.sessionEpoch/.test(session) &&
  !/token\.transitionEpoch/.test(session) &&
  /applyRefreshedApiTokens[\s\S]*beginDurableSessionTransition\(false\)/.test(session))
ok('late 401 responses from the preceding credential generation replay without a second refresh',
  /credentialRevision: number = -1/.test(session) &&
  /token\.credentialRevision = NhAccountSessionService\.credentialRevision/.test(session) &&
  /isAuthenticatedReadCredentialCurrent/.test(session) &&
  /credentialRevision \+= 1[\s\S]*token\.credentialRevision = NhAccountSessionService\.credentialRevision/.test(session) &&
  /!NhAccountSessionService\.isAuthenticatedReadCredentialCurrent\(readToken\)[\s\S]*recordAuthenticatedReadStale401AfterRefresh\(\)[\s\S]*NhRefreshAfter401Outcome\.READY/.test(sessionHttpClient) &&
  /adoptCurrentAuthenticatedCredential\(readToken\)/.test(sessionHttpClient))
ok('one session-wide refresh remains single-flight while credentials rotate in place',
  /refreshInFlight: Promise<NhRefreshAfter401Outcome> \| null = null/.test(sessionHttpClient) &&
  /existing !== null[\s\S]*refreshInFlightEpoch === readToken\.sessionEpoch[\s\S]*return await existing/.test(sessionHttpClient) &&
  /afterDiagnostic !== null[\s\S]*refreshInFlightEpoch === readToken\.sessionEpoch[\s\S]*return await afterDiagnostic/.test(sessionHttpClient) &&
  !/refreshInFlightCredentialRevision/.test(sessionHttpClient))
ok('terminal 401 publication rejects a response from a superseded credential generation',
  /recordAuthenticatedTerminal401\([\s\S]*isAuthenticatedReadCredentialCurrent\(token\)/.test(session) &&
  /recordAuthenticatedRefreshToken401\([\s\S]*isAuthenticatedReadCredentialCurrent\(token\)[\s\S]*recordAuthenticatedReadStale401AfterRefresh/.test(session) &&
  /statusCode === 401[\s\S]*!NhAccountSessionService\.isAuthenticatedReadCredentialCurrent\(readToken\)[\s\S]*recordAuthenticatedReadStale401AfterRefresh\(\)[\s\S]*account_session_generation_changed/.test(sessionHttpClient))
ok('all logged-in first-party reads acquire the same account ownership fence without English transition errors',
  /captureRequestToken\(scope\)/.test(sessionHttpClient) &&
  /captureAuthenticatedReadToken\(\)/.test(sessionHttpClient) &&
  /scope === NhRequestScope\.PUBLIC[\s\S]*return null/.test(sessionHttpClient) &&
  /!NhAccountSessionService\.hasRetainedAccount\(\)[\s\S]*scope === NhRequestScope\.ACCOUNT_PREFERRED[\s\S]*account_session_unavailable/.test(sessionHttpClient) &&
  /token === null[\s\S]*scope === NhRequestScope\.ACCOUNT_PREFERRED[\s\S]*account_session_generation_changed/.test(sessionHttpClient) &&
  !/ACCOUNT_OWNED_BEST_EFFORT/.test(sessionHttpClient) &&
  !/ACCOUNT_OWNED_BEST_EFFORT/.test(api) &&
  /requestJsonMutation[\s\S]*NhJsonReadScope\.ACCOUNT_OWNED,[\s\S]*NhRequestReplayPolicy\.NEVER/.test(api) &&
  /account_session_generation_changed/.test(sessionHttpClient) &&
  !/Your account session (?:is changing|changed)/.test(sessionHttpClient))
ok('a successful native response cannot publish authentication from an empty user agent',
  /requestUserAgent[\s\S]*browserUserAgent = userAgent/.test(session) &&
  /sealedAuthCookies = restoredPayload\.authCookies[\s\S]*browserUserAgent = normalizedUserAgent/.test(session))
ok('401 repair stays inside the native refresh and verification transaction',
  /NhApiHttpTransport\.requestJson\([\s\S]*auth\/refresh/.test(sessionHttpClient) &&
  /applyRefreshedApiTokens/.test(sessionHttpClient) &&
  /verificationResponse: NhApiHttpResponse = await NhApiHttpTransport\.requestJson\([\s\S]*API_USER_URL/.test(
    sessionHttpClient,
  ) &&
  /consumeResponseSetCookies\(verificationResponse, readToken\)/.test(sessionHttpClient) &&
  !/loadUrl|runJavaScript|NhArkWebSessionTransport/.test(sessionHttpClient))
ok('concurrent 401 responses join one session-generation refresh transaction',
  /refreshInFlight: Promise<NhRefreshAfter401Outcome> \| null = null/.test(sessionHttpClient) &&
  /refreshInFlightEpoch: number = -1/.test(sessionHttpClient) &&
  /existing !== null[\s\S]*refreshInFlightEpoch === readToken\.sessionEpoch[\s\S]*return await existing/.test(sessionHttpClient) &&
  /performRefreshAfter401\(readToken\)/.test(sessionHttpClient) &&
  /refreshInFlight === task[\s\S]*refreshInFlight = null[\s\S]*refreshInFlightEpoch = -1/.test(sessionHttpClient))
ok('only a refresh 401 or a post-refresh replay 401 publishes terminal verification',
  /enum NhRefreshAfter401Outcome[\s\S]*READY[\s\S]*AUTH_REJECTED[\s\S]*UNAVAILABLE/.test(sessionHttpClient) &&
  /response\.statusCode === 401[\s\S]*NhRefreshAfter401Outcome\.AUTH_REJECTED/.test(sessionHttpClient) &&
  /response\.statusCode === 429[\s\S]*NhRefreshAfter401Outcome\.UNAVAILABLE/.test(sessionHttpClient) &&
  /refreshOutcome === NhRefreshAfter401Outcome\.UNAVAILABLE[\s\S]*account_authenticated_refresh_unavailable/.test(
    sessionHttpClient,
  ) &&
  /recordAuthenticatedRefreshToken401\(readToken\)/.test(sessionHttpClient) &&
  /recordAuthenticatedRefreshToken401[\s\S]*AUTHENTICATED_READ_REFRESH_TOKEN_REJECTED[\s\S]*terminal_401_refresh_token_rejected/.test(
    session,
  ))
ok('cold start and spaced foreground transitions proactively validate a restored account',
  /ACCOUNT_FOREGROUND_PROBE_INTERVAL_MS: number = 5 \* 60 \* 1000/.test(entryAbility) &&
  (entryAbility.match(/probeRestoredAccountSession\(\)/g) || []).length >= 3 &&
  /!NhAccountSessionService\.isAuthenticated\(\)/.test(entryAbility) &&
  /NhApiClient\.validateRestoredAccountSession\(\)/.test(entryAbility) &&
  /validateRestoredAccountSession[\s\S]*validatePromotedSession/.test(api) &&
  /validatePromotedSession[\s\S]*API_USER_URL[\s\S]*NhRequestScope\.ACCOUNT_OWNED/.test(sessionHttpClient))
ok('a failed token refresh has persistent server-directed cooldowns',
  /authenticatedRefreshCooldownRemainingMs\(readToken\)/.test(sessionHttpClient) &&
  /response\.statusCode === 429/.test(sessionHttpClient) &&
  /recordAuthenticatedRefreshCooldown\(readToken, response\.retryAfterMs\)/.test(sessionHttpClient) &&
  /retryAfterMs\(wire\.rawHeader\)/.test(nhApiHttpTransport) &&
  /AUTH_REFRESH_RETRY_AT_KEY: string = 'account\.session\.authRefreshRetryAt'/.test(session) &&
  /recordAuthenticatedRefreshCooldown[\s\S]*store\.putSync\(AUTH_REFRESH_RETRY_AT_KEY/.test(session) &&
  /clearAuthenticatedRefreshCooldown[\s\S]*store\.deleteSync\(AUTH_REFRESH_RETRY_AT_KEY\)/.test(session))
ok('cold restore can hydrate the compatibility Cookie jar without gating native API readiness',
  /ensureRegularArkWebCookieJar\(\)/.test(session) &&
  /NhCookieAuthority/.test(session) &&
  !/ensureRegularArkWebCookieJar/.test(sessionHttpClient))
ok('401 repair verifies and durably checkpoints refreshed native tokens before replay',
  /authenticatedRefreshRequestBody\(readToken\)/.test(sessionHttpClient) &&
  /applyRefreshedApiTokens/.test(sessionHttpClient) &&
  /responseCookieResult === NhResponseAuthCookieResult\.APPLIED/.test(sessionHttpClient) &&
  /verificationResponse: NhApiHttpResponse = await NhApiHttpTransport\.requestJson/.test(sessionHttpClient) &&
  /consumeResponseSetCookies\(verificationResponse, readToken\)/.test(sessionHttpClient) &&
  /clearAuthenticatedRefreshCooldown/.test(sessionHttpClient) &&
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
