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
const sessionService = read('shared/src/main/ets/services/NhAccountSessionService.ets')
const cookieAuthority = read('shared/src/main/ets/services/NhCookieAuthority.ets')
const streamingTransport = read('shared/src/main/ets/network/StreamingHttpClient.ets')

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
  /result\.limitExceeded \|\| result\.sinkRejected \|\| result\.cancelled/.test(streamingTransport))

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

const refreshApply = sessionService.match(
  /static async applyRefreshedApiTokens\([\s\S]*?\n  \}/,
)?.[0] ?? ''
const responseCookieApply = sessionService.match(
  /static async applyResponseAuthSetCookies\([\s\S]*?\n  \}/,
)?.[0] ?? ''
const responseCookieSink = cookieAuthority.match(
  /static storeFirstPartyResponseCookies\([\s\S]*?\n  \}/,
)?.[0] ?? ''
ok('refresh accepts only a complete JSON or fenced Set-Cookie pair and persists it atomically',
  /typeof accessValue === 'string' && typeof refreshValue === 'string'/.test(sessionClient) &&
  /NhSessionHttpClient\.validApiToken\(accessValue\)/.test(sessionClient) &&
  /NhSessionHttpClient\.validApiToken\(refreshValue\)/.test(sessionClient) &&
  /responseCookieResult === NhResponseAuthCookieResult\.APPLIED/.test(sessionClient) &&
  /const refresh: string = NhAccountSessionService\.safeApiToken\(refreshToken\)/.test(refreshApply) &&
  !/priorRefresh|refreshCandidate/.test(refreshApply) &&
  /AccountSessionRepository\.saveVerifiedForAccount/.test(refreshApply) &&
  /NhCookieAuthority\.storeRefreshedAuthTokens/.test(refreshApply) &&
  /responseAccess \?\?[\s\S]*currentAuthCookieValue\('access_token'\)/.test(responseCookieApply) &&
  /responseRefresh \?\?[\s\S]*currentAuthCookieValue\('refresh_token'\)/.test(responseCookieApply) &&
  /applyRefreshedApiTokens\(token, access, refresh, true\)/.test(responseCookieApply) &&
  /if \(!responseCookieSinkOwnedByCaller\)[\s\S]*NhCookieAuthority\.storeRefreshedAuthTokens/.test(
    refreshApply,
  ))

ok('every bounded first-party Set-Cookie response crosses one global persistence boundary',
  /class NhApiResponseCookieCapture implements http\.HttpInterceptor/.test(nhApiHttpTransport) &&
  /http\.InterceptorType\.FINAL_RESPONSE/.test(nhApiHttpTransport) &&
  /this\.observed = true/.test(nhApiHttpTransport) &&
  /JSON\.stringify\(response\.header\)/.test(nhApiHttpTransport) &&
  /const rawCookies: string = response\.cookies/.test(nhApiHttpTransport) &&
  /interceptorChain\.addChain\(\[cookieCapture\]\)/.test(nhApiHttpTransport) &&
  /MAX_RESPONSE_BODY_BYTES,[\s\S]*interceptorChain,[\s\S]*0,/.test(nhApiHttpTransport) &&
  /NhApiHttpTransport\.setCookieHeaders\([\s\S]*cookieCapture\.rawHeader,[\s\S]*cookieCapture\.rawCookies,[\s\S]*cookieCapture\.rejected \|\| !cookieCapture\.observed/.test(
    nhApiHttpTransport,
  ) &&
  /!exactSetCookieObserved && rawCookies\.length > 0/.test(nhApiHttpTransport) &&
  /line\.startsWith\('#HttpOnly_'\)/.test(nhApiHttpTransport) &&
  /const fields: string\[\] = line\.split\('\\t'\)/.test(nhApiHttpTransport) &&
  /fields\.length !== 7/.test(nhApiHttpTransport) &&
  /domain !== 'nhentai\.net'/.test(nhApiHttpTransport) &&
  /new Date\(expirySeconds \* 1000\)\.toUTCString\(\)/.test(nhApiHttpTransport) &&
  /response\.setCookieHeaders = responseCookies\.headers/.test(nhApiHttpTransport) &&
  /response\.setCookieHeadersRejected = responseCookies\.rejected/.test(nhApiHttpTransport) &&
  /MAX_SET_COOKIE_HEADERS: number = 32/.test(nhApiHttpTransport) &&
  /MAX_SET_COOKIE_HEADER_CHARS: number = 32 \* 1024/.test(nhApiHttpTransport) &&
  /extraction\.headers\.length >= MAX_SET_COOKIE_HEADERS[\s\S]*extraction\.rejected = true/.test(
    nhApiHttpTransport,
  ) &&
  /private static async consumeResponseSetCookies/.test(sessionClient) &&
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
  /let hydrated: boolean = false[\s\S]*ensureRegularArkWebCookieJar\(\)/.test(sessionService) &&
  /existingMatchesSealed[\s\S]*authCookieSnapshotContains\(existingAuthCookies, sealedAuthCookies\)/.test(
    sessionService,
  ) &&
  /existingComplete && existingMatchesSealed/.test(sessionService))

if (failures > 0) {
  console.error(`[FAIL] network authority contract: ${failures} failure(s)`)
  process.exit(1)
}
console.log('OK network authority contract passed')
