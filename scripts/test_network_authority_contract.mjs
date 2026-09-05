#!/usr/bin/env node
/** NH request and session authority boundary. */
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const root = fileURLToPath(new URL('../', import.meta.url))
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8')
const listEts = (directory) => fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
  const absolute = path.join(directory, entry.name)
  if (entry.isDirectory()) {
    return entry.name === 'build' || entry.name === 'oh_modules' ? [] : listEts(absolute)
  }
  return entry.isFile() && entry.name.endsWith('.ets') ? [absolute] : []
})
const files = ['entry', 'feature', 'shared']
  .flatMap((directory) => listEts(path.join(root, directory)))
const relativeMatches = (pattern) => files
  .filter((file) => pattern.test(fs.readFileSync(file, 'utf8')))
  .map((file) => path.relative(root, file)).sort()

let failures = 0
const ok = (name, condition) => {
  if (!condition) {
    console.error(`[FAIL] ${name}`)
    failures += 1
  }
}

const axiosTransport = read('shared/src/main/ets/network/AxiosHttpClient.ets')
const sessionClient = read('shared/src/main/ets/network/NhSessionHttpClient.ets')
const nhApiHttpTransport = read('shared/src/main/ets/network/NhApiHttpTransport.ets')
const responseCookieCodec = read('shared/src/main/ets/network/NhApiResponseCookieCodec.ets')
const refreshResponseCodec = read('shared/src/main/ets/network/NhRefreshResponseCodec.ets')
const sessionService = read('shared/src/main/ets/services/NhAccountSessionService.ets')
const cookieAuthority = read('shared/src/main/ets/services/NhCookieAuthority.ets')
const streamingTransport = read('shared/src/main/ets/network/StreamingHttpClient.ets')
const browserSessionPage = read('feature/user/src/main/ets/pages/BrowserSessionPage.ets')
const ehWebView = read('shared/src/main/ets/components/EhWebView.ets')
const ensureRegularArkWebCookieJar = sessionService.match(
  /static async ensureRegularArkWebCookieJar\(\): Promise<boolean> \{[\s\S]*?\n  \}/,
)?.[0] ?? ''
const apiKeyValidation = sessionClient.match(
  /static async validateAndPromoteApiKey\([\s\S]*?(?=\n  \/\*\*[\s\S]*?validateAndCheckpointApiKeyBrowserSession)/,
)?.[0] ?? ''
const apiKeyRejectionCheck = sessionClient.match(
  /private static async performApiKeyCheckAfterRejection\([\s\S]*?(?=\n  private static async completeResponse)/,
)?.[0] ?? ''
const responseCookieConsumer = sessionClient.match(
  /private static async consumeResponseSetCookies\([\s\S]*?(?=\n  private static responseCookieAuthorityFor)/,
)?.[0] ?? ''

ok('Axios is created only by the bounded base transport',
  JSON.stringify(relativeMatches(/(?:import axios|axios\.request)/)) === JSON.stringify([
    'shared/src/main/ets/network/AxiosHttpClient.ets',
  ]) &&
  /validateStatus: AxiosHttpClient\.acceptStatus/.test(axiosTransport) &&
  /connectTimeout: connectTimeoutMs/.test(axiosTransport) &&
  /readTimeout: readTimeoutMs/.test(axiosTransport) &&
  /interceptorChain: http\.HttpInterceptorChain \| null = null/.test(axiosTransport) &&
  /config\.interceptorChain = interceptorChain/.test(axiosTransport) &&
  /config\.maxRedirects = maxRedirects/.test(axiosTransport))

ok('NetworkKit request ownership is limited to the bounded transports',
  JSON.stringify(relativeMatches(/from '@kit\.NetworkKit'/)) === JSON.stringify([
    'shared/src/main/ets/network/AxiosHttpClient.ets',
    'shared/src/main/ets/network/NhApiHttpTransport.ets',
    'shared/src/main/ets/network/StreamingHttpClient.ets',
  ]) &&
  JSON.stringify(relativeMatches(/http\.createHttp\(\)/)) === JSON.stringify([
    'shared/src/main/ets/network/StreamingHttpClient.ets',
  ]) &&
  /usingCache: boolean = false/.test(axiosTransport) &&
  /Cache-Control'\] = 'no-cache, no-store'/.test(axiosTransport) &&
  /usingCache: false/.test(streamingTransport) &&
  /request\.destroy\(\)/.test(streamingTransport))

ok('ArkWeb cookies have exactly one native authority',
  JSON.stringify(relativeMatches(/WebCookieManager\./)) === JSON.stringify([
    'shared/src/main/ets/services/NhCookieAuthority.ets',
  ]) &&
  /fetchAllAuthCookies\(\)[\s\S]*fetchAllCookies\(false\)/.test(cookieAuthority) &&
  /SDK boolean selects the incognito cookie store/.test(cookieAuthority) &&
  !/fetchAllCookies\(includeHttpOnly/.test(cookieAuthority) &&
  !/fetchAllCookies\(true\)/.test(cookieAuthority) &&
  !/fetchAllCookies\(/.test(sessionService))

ok('NH endpoint facade is the only consumer of the session client',
  JSON.stringify(relativeMatches(/NhSessionHttpClient\./).filter((file) =>
    file !== 'shared/src/main/ets/network/NhSessionHttpClient.ets')) === JSON.stringify([
    'shared/src/main/ets/network/NhApiClient.ets',
  ]))

ok('NH session client is the only consumer of the first-party wire transport',
  JSON.stringify(relativeMatches(/NhApiHttpTransport\./).filter((file) =>
    file !== 'shared/src/main/ets/network/NhApiHttpTransport.ets')) === JSON.stringify([
    'shared/src/main/ets/network/NhSessionHttpClient.ets',
  ]))

ok('first-party API origins cannot be declared outside the fenced transport pair',
  JSON.stringify(relativeMatches(/https:\/\/nhentai\.net\/api\/v2\//)) === JSON.stringify([
    'shared/src/main/ets/network/NhApiHttpTransport.ets',
    'shared/src/main/ets/network/NhSessionHttpClient.ets',
  ]))

ok('API keys use the same fenced transport and never enter the refresh-token endpoint',
  /value\.startsWith\('User '\) \|\| value\.startsWith\('Key '\)/.test(nhApiHttpTransport) &&
  /validateAndPromoteApiKey[\s\S]*API_USER_URL[\s\S]*`Key \$\{apiKey\}`[\s\S]*promoteVerifiedApiKey/.test(
    sessionClient,
  ) &&
  /validatedAccountId\(response\.body\)[\s\S]*promoteVerifiedApiKey\([\s\S]*context,[\s\S]*apiKey,[\s\S]*accountId,[\s\S]*browserSessionOwnedByCandidate/.test(
    sessionClient,
  ) &&
  /promoteVerifiedApiKey\([\s\S]*accountId: string[\s\S]*saveVerifiedForAccount\([\s\S]*normalizedAccountId/.test(
    sessionService,
  ) &&
  /performRefreshAfter401[\s\S]*isApiKeyCredential\(readToken\)[\s\S]*performApiKeyCheckAfterRejection/.test(
    sessionClient,
  ) &&
  /performApiKeyCheckAfterRejection[\s\S]*API_USER_URL[\s\S]*apiKeyCheckDispositionForStatus\(response\.statusCode\)[\s\S]*AUTH_REJECTED/.test(
    sessionClient,
  ) &&
  /CREDENTIAL_VALID_UNCHANGED[\s\S]*do not replay an endpoint-specific rejection/.test(sessionClient) &&
  /terminal_api_key_rejected/.test(sessionService) &&
  /isApiKeyRecoveryReason\(markerReason\)/.test(sessionService) &&
  /if \(!apiKeyRecovery\)[\s\S]*cookieHeader = ''[\s\S]*nativeApiKey = ''/.test(sessionService))

ok('account profile identity is bound to the saved owner and mismatch becomes durable verification',
  /requestAccountProfile[\s\S]*captureAuthenticatedReadToken\(\)/.test(sessionClient) &&
  /authenticatedIdentityMatchesActiveAccount\(userId\)[\s\S]*adoptCurrentAuthenticatedCredential\(ownerToken\)[\s\S]*recordAuthenticatedIdentityMismatch\(ownerToken\)/.test(
    sessionClient,
  ) &&
  /recordAuthenticatedIdentityMismatch[\s\S]*AUTHENTICATED_READ_IDENTITY_MISMATCH/.test(sessionService) &&
  /terminal_api_key_identity_mismatch/.test(sessionService) &&
  /terminal_web_token_identity_mismatch/.test(sessionService) &&
  /isApiKeyRecoveryReason[\s\S]*terminal_api_key_rejected[\s\S]*terminal_api_key_identity_mismatch/.test(
    sessionService,
  ))

ok('official API-key creation stays in first-party WebView and imports without clipboard authority',
  /apiKeySetupMode: boolean = false/.test(browserSessionPage) &&
  /controller\.loadUrl\(NhBrowserSessionBoundary\.apiKeysSettingsUrl\(\)\)/.test(browserSessionPage) &&
  /EhWebView\(\{[\s\S]*documentStartScripts: this\.apiKeySetupMode \? this\.apiKeyScripts : \[\]/.test(browserSessionPage) &&
  /controller\.registerJavaScriptProxy\([\s\S]*API_KEY_CAPTURE_PROXY[\s\S]*\['capture'\]/.test(browserSessionPage) &&
  /API_KEY_NAME_FILL_SCRIPT/.test(browserSessionPage) &&
  /location\.pathname!==\'\/user\/settings\'/.test(browserSessionPage) &&
  /querySelectorAll\('label'\)/.test(browserSessionPage) &&
  /String\(l\.textContent\|\|''\)\.trim\(\)===\'Key Name\'/.test(browserSessionPage) &&
  /document\.getElementById\(id\)/.test(browserSessionPage) &&
  /n instanceof HTMLInputElement/.test(browserSessionPage) &&
  /String\(n\.value\|\|''\)\.trim\(\)\.length>0/.test(browserSessionPage) &&
  /NextN HarmonyOS/.test(browserSessionPage) &&
  /dispatchEvent\(new Event\('input',\{bubbles:true\}\)\)/.test(browserSessionPage) &&
  /new MutationObserver\(function\(\)\{fill\(\);\}\)/.test(browserSessionPage) &&
  /setInterval\(fill,500\)/.test(browserSessionPage) &&
  /onLoadFinished:[\s\S]{0,220}settleApiKeyPageAfterLoad/.test(browserSessionPage) &&
  /settleApiKeyPageAfterLoad\(\): Promise<void>[\s\S]*?handleApiKeyPageKind\(pageKind\)/.test(browserSessionPage) &&
  /handleApiKeyPageKind\(pageKind: string\): void[\s\S]*?pageKind === 'settings'[\s\S]*?fillApiKeyNameAfterLoad\(\)/.test(browserSessionPage) &&
  /scriptRules: \['\*'\]/.test(browserSessionPage) &&
  /x\.pathname==='\/api\/v2\/user\/keys'[\s\S]*POST/.test(browserSessionPage) &&
  /importApiKeyCandidate[\s\S]*adoptCompleteRegularArkWebCookieJar\([\s\S]*this\.browserSessionUserAgent[\s\S]*\)[\s\S]*NhApiClient\.bindApiKey/.test(
    browserSessionPage,
  ) &&
  /NhApiClient\.bindApiKey\([\s\S]*this\.hostContext\(\),[\s\S]*candidate,[\s\S]*browserSessionCaptured,[\s\S]*keyName/.test(browserSessionPage) &&
  /JSON\.stringify\(\{key:v,name:readName\(p\)\}\)/.test(browserSessionPage) &&
  /DiagnosticLogger\.info\('account-api-key', 'candidate_captured', 'stage'\)/.test(browserSessionPage) &&
  /DiagnosticLogger\.info\('account-api-key', 'native_api_key_promoted', 'stage'\)/.test(browserSessionPage) &&
  !/Clipboard|pasteData/.test(browserSessionPage))

ok('official API-key capture retains the exact ArkWeb identity needed for later Web reuse',
  /adoptCompleteRegularArkWebCookieJar\(browserUserAgent: string = ''\)/.test(sessionService) &&
  /const capturedUserAgent: string = NhAccountSessionService\.normalizeUserAgent\(browserUserAgent\)/.test(
    sessionService,
  ) &&
  /browserUserAgent\.length > 0 && capturedUserAgent\.length === 0/.test(sessionService) &&
  /sealedAuthCookies = currentAuthCookies[\s\S]*if \(capturedUserAgent\.length > 0\)[\s\S]*browserUserAgent = capturedUserAgent/.test(
    sessionService,
  ))

ok('all first-party browser surfaces reuse the shared ArkWeb wrapper',
  /javaScriptOnDocumentStart\(this\.documentStartScripts\)/.test(ehWebView) &&
  /fileAccess\(false\)/.test(ehWebView) &&
  /onHttpErrorReceive/.test(ehWebView) &&
  /onConsole/.test(ehWebView) &&
  /EhWebView\(\{[\s\S]*onHttpErrorReceive/.test(browserSessionPage) &&
  !/\bWeb\(\{/.test(browserSessionPage) &&
  JSON.stringify(relativeMatches(/\bWeb\(\{/)) === JSON.stringify([
    'shared/src/main/ets/components/EhWebView.ets',
  ]))

const coldRestoreArkWebReconcile = sessionService.match(
  /const completeWebCompatibilityState: boolean =[\s\S]*?(?=\n    if \(restoredEpoch)/,
)?.[0] ?? ''
ok('cold restore hydrates only a complete owned Web snapshot and leaves an independent Web jar intact',
  /hasCompleteOwnedBrowserSessionSnapshot\([\s\S]*hasLoginCookies\(normalized\)[\s\S]*normalizedUserAgent\.length > 0[\s\S]*hasAccessAuthCookie\(restoredPayload\.authCookies\)[\s\S]*hasRefreshAuthCookie\(restoredPayload\.authCookies\)/.test(
    coldRestoreArkWebReconcile,
  ) &&
  /let hydrated: boolean = !completeWebCompatibilityState[\s\S]*if \(completeWebCompatibilityState\)[\s\S]*ensureRegularArkWebCookieJar\(\)/.test(coldRestoreArkWebReconcile) &&
  !/expireVisibleBrowserIdentityCookies|persistBrowserManagedCookies/.test(coldRestoreArkWebReconcile) &&
  !/adoptCompleteRegularArkWebCookieJar/.test(ensureRegularArkWebCookieJar) &&
  !/readRegularArkWebCookieHeader/.test(ensureRegularArkWebCookieJar))

const refreshApply = sessionService.match(
  /static async applyRefreshedApiTokens\([\s\S]*?\n  \}/,
)?.[0] ?? ''
const userTokenRefreshApply = sessionService.match(
  /static async applyRefreshedUserTokens\([\s\S]*?\n  \}/,
)?.[0] ?? ''
const responseCookieApply = sessionService.match(
  /static async applyResponseAuthSetCookies\([\s\S]*?\n  \}/,
)?.[0] ?? ''
const userTokenMutation = sessionClient.match(
  /static async requestJsonUserTokenMutation\([\s\S]*?(?=\n  static async requestAccountProfile)/,
)?.[0] ?? ''
const apiKeyWebsiteRefresh = sessionClient.match(
  /private static async performApiKeyWebsiteRefreshAfter401\([\s\S]*?(?=\n  private static async recoverAfter401)/,
)?.[0] ?? ''
const responseCookieSink = cookieAuthority.match(
  /static storeFirstPartyResponseCookies\([\s\S]*?\n  \}/,
)?.[0] ?? ''
ok('refresh binds a complete response to the request owner before persisting either credential sink',
  /NhRefreshResponseCodec\.decode\([\s\S]*response\.body,[\s\S]*readToken\.accountId/.test(sessionClient) &&
  /recordAuthenticatedReadRefreshResponseRejected/.test(sessionClient) &&
  /record\['user'\][\s\S]*user\['id'\]/.test(refreshResponseCodec) &&
  /expected\.length > 0 && expected !== accountId/.test(refreshResponseCodec) &&
  /consumeResponseSetCookies\([\s\S]*response,[\s\S]*readToken,[\s\S]*NhResponseCookieAuthority\.WEBSITE_SESSION,[\s\S]*refreshed\.accountId/.test(sessionClient) &&
  /responseCookieResult === NhResponseAuthCookieResult\.APPLIED/.test(sessionClient) &&
  /const refresh: string = NhAccountSessionService\.safeApiToken\(refreshToken\)/.test(refreshApply) &&
  /resolvedOwner: string \| null = NhAccountSessionService\.resolveAuthenticatedReadOwner/.test(refreshApply) &&
  !/priorRefresh|refreshCandidate/.test(refreshApply) &&
  /AccountSessionRepository\.saveVerifiedForAccount\([\s\S]*resolvedOwner/.test(refreshApply) &&
  /NhCookieAuthority\.storeRefreshedAuthTokens/.test(refreshApply) &&
  /responseAccess \?\?[\s\S]*currentAuthCookieValue\('access_token'\)/.test(responseCookieApply) &&
  /responseRefresh \?\?[\s\S]*currentAuthCookieValue\('refresh_token'\)/.test(responseCookieApply) &&
  /applyRefreshedUserTokens\([\s\S]*token,[\s\S]*access,[\s\S]*refresh,[\s\S]*true,[\s\S]*verifiedAccountId/.test(
    responseCookieApply,
  ) &&
  /if \(!responseCookieSinkOwnedByCaller\)[\s\S]*NhCookieAuthority\.storeRefreshedAuthTokens/.test(
    refreshApply,
  ))

ok('comment mutations use the account-owned User token without replacing the native API key',
  /postComment[\s\S]*requestJsonMutation\([\s\S]*'Comment service rejected this post',[\s\S]*true,/.test(
    read('shared/src/main/ets/network/NhApiClient.ets'),
  ) &&
  /requiresUserToken[\s\S]*requestJsonUserTokenMutation\(url, method, extraData\)/.test(
    read('shared/src/main/ets/network/NhApiClient.ets'),
  ) &&
  /authenticatedUserTokenAuthorization\(readToken\)/.test(userTokenMutation) &&
  (userTokenMutation.match(/NhApiHttpTransport\.requestJson/g) ?? []).length === 1 &&
  /response\.statusCode === 401[\s\S]*performApiKeyWebsiteRefreshAfter401\(readToken\)[\s\S]*account_mutation_not_replayed_after_recovery/.test(
    userTokenMutation,
  ) &&
  /authenticatedUserTokenRefreshRequestBody\(readToken\)/.test(apiKeyWebsiteRefresh) &&
  /NhRefreshResponseCodec\.decode\([\s\S]*response\.body,[\s\S]*readToken\.accountId/.test(
    apiKeyWebsiteRefresh,
  ) &&
  /applyRefreshedUserTokens\([\s\S]*refreshed\.accountId/.test(apiKeyWebsiteRefresh) &&
  /NhNativeCredentialKind\.API_KEY,[\s\S]*apiKey,/.test(userTokenRefreshApply) &&
  !/nativeCredentialKind\s*=/.test(userTokenRefreshApply) &&
  !/nativeApiKey\s*=/.test(userTokenRefreshApply))

ok('post-refresh account verification checks owner before accepting response cookies',
  /verificationAccountId: string =[\s\S]*validatedAccountId\(verificationResponse\.body\)/.test(
    sessionClient,
  ) &&
  /verificationAccountId !== refreshed\.accountId[\s\S]*recordAuthenticatedReadRefreshResponseRejected[\s\S]*consumeResponseSetCookies\([\s\S]*verificationResponse,[\s\S]*readToken,[\s\S]*NhResponseCookieAuthority\.WEBSITE_SESSION,[\s\S]*verificationAccountId/.test(
    sessionClient,
  ))

ok('only identity-checked Web-session responses may mutate the shared Cookie authority',
  /class NhApiResponseCookieCapture implements http\.HttpInterceptor/.test(nhApiHttpTransport) &&
  /http\.InterceptorType\.FINAL_RESPONSE/.test(nhApiHttpTransport) &&
  /this\.observed = true/.test(nhApiHttpTransport) &&
  /JSON\.stringify\(response\.header\)/.test(nhApiHttpTransport) &&
  /const rawCookies: string = response\.cookies/.test(nhApiHttpTransport) &&
  /interceptorChain\.addChain\(\[cookieCapture\]\)/.test(nhApiHttpTransport) &&
  /MAX_RESPONSE_BODY_BYTES,[\s\S]*interceptorChain,[\s\S]*0,/.test(nhApiHttpTransport) &&
  /NhApiResponseCookieCodec\.extract\([\s\S]*cookieCapture\.rawHeader,[\s\S]*cookieCapture\.rawCookies,[\s\S]*cookieCapture\.rejected \|\| !cookieCapture\.observed/.test(
    nhApiHttpTransport,
  ) &&
  /!exactSetCookieObserved && rawCookies\.length > 0/.test(responseCookieCodec) &&
  /line\.startsWith\('#HttpOnly_'\)/.test(responseCookieCodec) &&
  /const fields: string\[\] = line\.split\('\\t'\)/.test(responseCookieCodec) &&
  /fields\.length !== 7/.test(responseCookieCodec) &&
  /domain !== 'nhentai\.net'/.test(responseCookieCodec) &&
  /new Date\(expirySeconds \* 1000\)\.toUTCString\(\)/.test(responseCookieCodec) &&
  /response\.setCookieHeaders = responseCookies\.headers/.test(nhApiHttpTransport) &&
  /response\.setCookieHeadersRejected = responseCookies\.rejected/.test(nhApiHttpTransport) &&
  /NH_API_MAX_SET_COOKIE_HEADERS: number = 32/.test(responseCookieCodec) &&
  /NH_API_MAX_SET_COOKIE_HEADER_CHARS: number = 32 \* 1024/.test(responseCookieCodec) &&
  /extraction\.headers\.length >= NH_API_MAX_SET_COOKIE_HEADERS[\s\S]*extraction\.rejected = true/.test(
    responseCookieCodec,
  ) &&
  /private static async consumeResponseSetCookies/.test(sessionClient) &&
  /enum NhResponseCookieAuthority[\s\S]*IGNORE[\s\S]*WEBSITE_SESSION/.test(sessionClient) &&
  /authority !== NhResponseCookieAuthority\.WEBSITE_SESSION[\s\S]*return NhResponseAuthCookieResult\.NONE/.test(
    responseCookieConsumer,
  ) &&
  /readToken !== null && readToken\.credentialKind === NhNativeCredentialKind\.WEB_TOKEN[\s\S]*NhResponseCookieAuthority\.WEBSITE_SESSION[\s\S]*NhResponseCookieAuthority\.IGNORE/.test(
    sessionClient,
  ) &&
  !/consumeResponseSetCookies/.test(apiKeyValidation) &&
  !/consumeResponseSetCookies/.test(apiKeyRejectionCheck) &&
  /requestJsonUserTokenMutation[\s\S]*consumeResponseSetCookies\([\s\S]*NhResponseCookieAuthority\.WEBSITE_SESSION/.test(
    sessionClient,
  ) &&
  /validatedAccountId\(response\.body\)[\s\S]*consumeResponseSetCookies\([\s\S]*NhResponseCookieAuthority\.WEBSITE_SESSION/.test(
    sessionClient,
  ) &&
  /if \(response\.setCookieHeadersRejected\)[\s\S]*recordResponseCookieCheckpoint\([\s\S]*false,[\s\S]*NhResponseAuthCookieResult\.REJECTED/.test(
    sessionClient,
  ) &&
  /NhCookieAuthority\.storeFirstPartyResponseCookies\(response\.setCookieHeaders\)/.test(
    sessionClient,
  ) &&
  /applyResponseAuthSetCookies\([\s\S]*response\.setCookieHeaders/.test(sessionClient) &&
  /recordResponseCookieCheckpoint\(true, authResult\)/.test(sessionClient) &&
  /RESPONSE_COOKIE_STORED = 'account_response_cookie_stored'/.test(sessionService) &&
  /RESPONSE_AUTH_COOKIE_APPLIED = 'account_response_auth_cookie_applied'/.test(sessionService) &&
  /RESPONSE_COOKIE_REJECTED = 'account_response_cookie_rejected'/.test(sessionService) &&
  /static storeFirstPartyResponseCookies\(setCookieHeaders: string\[\]\)/.test(cookieAuthority) &&
  /const headers: string\[\] = setCookieHeaders\.map/.test(responseCookieSink) &&
  /throw new Error\('account_response_cookie_header_rejected'\)/.test(responseCookieSink) &&
  /NhCookieAuthority\.NH_ORIGIN,[\s\S]*header,[\s\S]*false,[\s\S]*true,/.test(
    responseCookieSink,
  ) &&
  !/HttpOnly[^\n]*\.test\(header\)/.test(responseCookieSink) &&
  /applyResponseAuthSetCookies\([\s\S]*storeFirstPartyResponseCookies/.test(sessionClient) &&
  !/storeFirstPartyResponseCookies\([\s\S]*applyResponseAuthSetCookies/.test(sessionClient) &&
  JSON.stringify(relativeMatches(/\.setCookieHeaders/)) === JSON.stringify([
    'shared/src/main/ets/network/NhApiHttpTransport.ets',
    'shared/src/main/ets/network/NhSessionHttpClient.ets',
  ]))

ok('cold restore reconciles ArkWeb only against the sealed request generation',
  /const completeWebCompatibilityState: boolean =[\s\S]*ensureRegularArkWebCookieJar\(\)/.test(
    sessionService,
  ) &&
  /existingMatchesSealed[\s\S]*authCookieSnapshotContains\(existingAuthCookies, sealedAuthCookies\)/.test(
    sessionService,
  ) &&
  /existingComplete && existingMatchesSealed/.test(sessionService))

if (failures > 0) {
  console.error(`[FAIL] network authority contract: ${failures} failure(s)`)
  process.exit(1)
}
console.log('OK network authority contract passed')
