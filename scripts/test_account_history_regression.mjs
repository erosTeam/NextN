#!/usr/bin/env node
/** Non-UI regressions for account ownership and split history sync. */
import fs from 'fs'

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
ok('a terminal replayed 401 records diagnostics without demoting the account',
  /recordAuthenticatedReadReplay401/.test(terminal401) &&
  !/retainedAccountPresent\s*=\s*false/.test(terminal401) &&
  !/cookieHeader\s*=\s*''/.test(terminal401) &&
  !/publishSessionChange/.test(terminal401) &&
  /recordAuthenticatedReadInitial401/.test(api) &&
  /recordAuthenticatedReadBrowserRefresh/.test(api) &&
  /recordAuthenticatedReadSealedRecovery/.test(api))
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
ok('401 browser repair reloads the authenticated root instead of the login page',
  /loadTrustedSessionRefreshPage/.test(arkWebTransport) &&
  /controller\.loadUrl\(`\$\{NhBrowserSessionBoundary\.trustedOrigin\(\)\}\/`\)/.test(arkWebTransport) &&
  !/loadTrustedSessionRefreshPage[\s\S]{0,1800}loginUrl\(\)/.test(arkWebTransport))
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
