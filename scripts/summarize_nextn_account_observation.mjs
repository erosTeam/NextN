#!/usr/bin/env node

/**
 * Privacy-bounded offline summary for a checked NextN Account/Favorites run.
 *
 * Raw layouts and diagnostics may contain user data. This parser returns only
 * fixed booleans, counts, and allowlisted diagnostic stage names. It never
 * echoes paths, arbitrary text, command output, Cookie data, URLs, or account
 * values.
 */

import { readFile, readdir } from 'node:fs/promises'
import { basename, dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPOSITORY_ROOT = dirname(dirname(fileURLToPath(import.meta.url)))
const AUTHORIZED_TARGET = '192.168.50.237:12345'
const NEXTN_BUNDLE = 'com.erosteam.nextn'
const ENTRY_ABILITY = 'EntryAbility'
const RESOURCE_LOCALES = ['base', 'en_US', 'zh_CN', 'ja_JP']
const ACCOUNT_LIST_ROOT_ID = 'nextn-account-list-root'
const ACCOUNT_SAVED_ROW_ID = 'nextn-account-saved-row'
const FAVORITES_ROOT_ID = 'nextn-favorites-root'
const WEB_TYPES = new Set(['Web', 'WebComponent'])
const COLLECTION_TYPES = new Set(['List', 'Grid', 'WaterFlow'])
const DIALOG_TYPES = new Set(['Dialog'])
const SYMBOL_TYPES = new Set(['SymbolGlyph'])
const DIAGNOSTIC_LOG_PATTERN = /^nextn-log-\d{8}-\d{6}(?:-\d+)?\.txt$/
const DIAGNOSTIC_LINE_TIMESTAMP_PATTERN =
  /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3})(?:\s|$)/
const AUTH_EXPIRY_SHAPE_PATTERN =
  /account_auth_expiry_shape[^\r\n]*?phase=(restore|initial_401|refresh_checkpoint|promotion);access=(absent|session|unknown|expired|lt_1h|lt_24h|lt_7d|ge_7d);refresh=(absent|session|unknown|expired|lt_1h|lt_24h|lt_7d|ge_7d)/g

const DIAGNOSTIC_STAGES = Object.freeze([
  'session_start',
  'account_restore_not_observed',
  'account_restore_record_absent',
  'account_restore_rdb_rebuilt_record_absent',
  'account_restore_rdb_read_failed',
  'account_restore_huks_key_check_failed',
  'account_restore_huks_key_absent',
  'account_restore_huks_decrypt_failed',
  'account_restore_payload_invalid',
  'account_restore_payload_shape',
  'account_restore_arkweb_jar_ready',
  'account_restore_ready',
  'account_restore_hydration_deferred',
  'account_restore_hydration_ready_after_page',
  'account_restore_hydration_unavailable_after_page',
  'account_restore_saved_envelope_used',
  'account_restore_saved_envelope_exhausted',
  'account_restore_cookie_store_retry',
  'account_restore_verification_required',
  'account_restore_verification_required_after_browser_refresh_failure',
  'account_auth_expiry_shape',
  'account_browser_cookie_shape',
  'account_browser_cookie_shape_unavailable',
  'account_authenticated_read_initial_401',
  'account_authenticated_read_stale_401_after_refresh',
  'account_authenticated_read_browser_refresh_ready',
  'account_authenticated_read_browser_refresh_unavailable',
  'account_authenticated_read_refresh_endpoint_status',
  'account_authenticated_read_refresh_endpoint_ready',
  'account_authenticated_read_refresh_endpoint_unavailable',
  'account_authenticated_read_refresh_token_rejected',
  'account_authenticated_read_refresh_cooldown_recorded',
  'account_refresh_checkpoint_retry',
  'account_refresh_checkpoint_recovered',
  'account_refresh_checkpoint_failed',
  'account_authenticated_read_browser_replay_recovered',
  'account_authenticated_read_browser_replay_401',
  'account_authenticated_read_terminal_401_after_restore',
  'account_authenticated_read_terminal_401_after_promotion',
  'account_response_cookie_stored',
  'account_response_auth_cookie_applied',
  'account_response_cookie_rejected',
  'account_verification_marker_persist_failed',
  'account_profile_snapshot_clear_failed',
  'account_arkweb_transport_main_frame_load_failed',
  'favorites_request_success',
  'favorites_request_failed',
])

class SafeFailure extends Error {
  constructor(code) {
    super(code)
    this.code = code
  }
}

function attributes(node) {
  if (node !== null && typeof node === 'object' &&
    node.attributes !== null && typeof node.attributes === 'object') {
    return node.attributes
  }
  return {}
}

function children(node) {
  if (node !== null && typeof node === 'object' && Array.isArray(node.children)) {
    return node.children
  }
  return []
}

function isVisible(node) {
  return String(attributes(node).visible ?? 'true').toLowerCase() !== 'false'
}

function nodeType(node) {
  const attrs = attributes(node)
  return String(attrs.type ?? node?.type ?? '')
}

function walk(node, visitor) {
  if (node === null || typeof node !== 'object' || !isVisible(node)) {
    return
  }
  visitor(node)
  for (const child of children(node)) {
    walk(child, visitor)
  }
}

function nodeTextValues(node) {
  const attrs = attributes(node)
  return ['id', 'text', 'originalText', 'description', 'accessibilityText',
    'accessibilityId', 'hint', 'content', 'value']
    .map((key) => attrs[key])
    .filter((value) => typeof value === 'string')
    .map((value) => value.trim())
    .filter((value) => value.length > 0)
}

function countVisibleMarker(root, marker) {
  let count = 0
  walk(root, (node) => {
    const attrs = attributes(node)
    if (String(attrs.id ?? '') === marker || String(attrs.accessibilityId ?? '') === marker) {
      count += 1
    }
  })
  return count
}

function firstVisibleMarker(root, marker) {
  let result = null
  walk(root, (node) => {
    if (result !== null) {
      return
    }
    const attrs = attributes(node)
    if (String(attrs.id ?? '') === marker || String(attrs.accessibilityId ?? '') === marker) {
      result = node
    }
  })
  return result
}

function hasType(root, types) {
  let found = false
  walk(root, (node) => {
    if (types.has(nodeType(node))) {
      found = true
    }
  })
  return found
}

function hasKnownLabel(root, labels) {
  let found = false
  walk(root, (node) => {
    if (nodeTextValues(node).some((value) => labels.has(value))) {
      found = true
    }
  })
  return found
}

function isClickable(node) {
  return String(attributes(node).clickable ?? '').toLowerCase() === 'true'
}

function verificationSnackBarSummary(root, titleLabels, messageLabels, actionLabels) {
  const surfaces = []
  walk(root, (node) => {
    if (DIALOG_TYPES.has(nodeType(node)) &&
      hasKnownLabel(node, titleLabels) &&
      hasKnownLabel(node, messageLabels) &&
      hasKnownLabel(node, actionLabels)) {
      surfaces.push(node)
    }
  })

  let reverifyActionVisible = false
  let closeActionVisible = false
  for (const surface of surfaces) {
    walk(surface, (node) => {
      if (node === surface || !isClickable(node)) {
        return
      }
      if (hasKnownLabel(node, actionLabels)) {
        reverifyActionVisible = true
        return
      }
      if (hasType(node, SYMBOL_TYPES)) {
        closeActionVisible = true
      }
    })
  }

  return {
    surfaceCount: surfaces.length,
    visible: surfaces.length > 0,
    reverifyActionVisible,
    closeActionVisible,
  }
}

function isForegroundNextn(root) {
  const rootAttrs = attributes(root)
  const windows = String(rootAttrs.abilityName ?? '').length > 0
    ? [root]
    : children(root).filter((node) => isVisible(node) &&
      String(attributes(node).hostWindowId ?? '').length > 0)
  const focused = windows.filter((node) =>
    String(attributes(node).focused ?? '').toLowerCase() === 'true')
  return focused.length === 1 &&
    String(attributes(focused[0]).bundleName ?? '') === NEXTN_BUNDLE &&
    String(attributes(focused[0]).abilityName ?? '') === ENTRY_ABILITY
}

function selectedRadioCount(root) {
  let count = 0
  walk(root, (node) => {
    const attrs = attributes(node)
    if (nodeType(node) === 'Radio' &&
      String(attrs.checked ?? attrs.selected ?? '').toLowerCase() === 'true') {
      count += 1
    }
  })
  return count
}

async function readJson(path, failureCode) {
  try {
    return JSON.parse(await readFile(path, 'utf8'))
  } catch {
    throw new SafeFailure(failureCode)
  }
}

async function loadLabels(keys) {
  const labels = new Set()
  for (const locale of RESOURCE_LOCALES) {
    const catalog = await readJson(
      join(REPOSITORY_ROOT, 'entry', 'src', 'main', 'resources', locale, 'element', 'string.json'),
      'resource_catalog_invalid',
    )
    for (const entry of catalog.string ?? []) {
      if (keys.has(entry.name) && typeof entry.value === 'string' && entry.value.trim().length > 0) {
        labels.add(entry.value.trim())
      }
    }
  }
  if (labels.size === 0) {
    throw new SafeFailure('resource_label_missing')
  }
  return labels
}

function countStage(content, stage) {
  const pattern = new RegExp(`(^|[^a-z0-9_])${stage}($|[^a-z0-9_])`, 'gim')
  return [...content.matchAll(pattern)].length
}

function diagnosticEventSequence(content) {
  const events = []
  for (const line of content.split(/\r?\n/)) {
    const matches = []
    for (const stage of DIAGNOSTIC_STAGES) {
      const index = line.indexOf(stage)
      if (index >= 0) {
        const before = index === 0 ? '' : line[index - 1]
        const afterIndex = index + stage.length
        const after = afterIndex >= line.length ? '' : line[afterIndex]
        if (!/[a-z0-9_]/i.test(before) && !/[a-z0-9_]/i.test(after)) {
          matches.push({ stage, index })
        }
      }
    }
    matches.sort((left, right) => left.index - right.index || right.stage.length - left.stage.length)
    for (const match of matches) {
      events.push(match.stage)
    }
  }
  return events
}

function authExpiryShapes(content) {
  return [...content.matchAll(AUTH_EXPIRY_SHAPE_PATTERN)].map((match) => ({
    phase: match[1],
    access: match[2],
    refresh: match[3],
  }))
}

function diagnosticLineTimestamp(line) {
  const match = DIAGNOSTIC_LINE_TIMESTAMP_PATTERN.exec(line)
  if (match === null) {
    return null
  }
  const parts = match.slice(1).map((value) => Number(value))
  const date = new Date(parts[0], parts[1] - 1, parts[2], parts[3], parts[4], parts[5], parts[6])
  if (date.getFullYear() !== parts[0] || date.getMonth() !== parts[1] - 1 ||
    date.getDate() !== parts[2] || date.getHours() !== parts[3] ||
    date.getMinutes() !== parts[4] || date.getSeconds() !== parts[5] ||
    date.getMilliseconds() !== parts[6]) {
    return null
  }
  return date.getTime()
}

function diagnosticWindow(manifest, metadata) {
  const rawStart = String(manifest?.context?.diagnosticWindowStart ?? '')
  const rawEnd = String(metadata?.endedAt ?? '')
  const start = Date.parse(rawStart)
  const end = Date.parse(rawEnd)
  if (rawStart.length === 0 || rawEnd.length === 0 || !Number.isFinite(start) ||
    !Number.isFinite(end) || start > end) {
    return null
  }
  return { start, end }
}

async function diagnosticsSummary(artifactDirectory, manifest, metadata) {
  const window = diagnosticWindow(manifest, metadata)
  let names = []
  try {
    names = await readdir(join(artifactDirectory, 'diagnostics'))
  } catch {
    return {
      logPresent: false,
      selectedLog: null,
      scannedLogCount: 0,
      windowed: window !== null,
      stages: [],
      terminal401: false,
      responseCookieStored: false,
      responseAuthCookieApplied: false,
      responseCookieRejected: false,
      favoritesSuccess: false,
      favoritesFailed: false,
      authExpiryShapes: [],
      eventSequence: [],
    }
  }
  const logs = names.filter((name) => DIAGNOSTIC_LOG_PATTERN.test(name)).sort()
  if (logs.length === 0) {
    return {
      logPresent: false,
      selectedLog: null,
      scannedLogCount: 0,
      windowed: window !== null,
      stages: [],
      terminal401: false,
      responseCookieStored: false,
      responseAuthCookieApplied: false,
      responseCookieRejected: false,
      favoritesSuccess: false,
      favoritesFailed: false,
      authExpiryShapes: [],
      eventSequence: [],
    }
  }
  const selectedLog = logs.at(-1)
  const logsToRead = window === null ? [selectedLog] : logs
  const windowedLines = []
  for (const logName of logsToRead) {
    let logContent = ''
    try {
      logContent = await readFile(join(artifactDirectory, 'diagnostics', logName), 'utf8')
    } catch {
      throw new SafeFailure('diagnostic_log_unreadable')
    }
    if (window === null) {
      windowedLines.push({ timestamp: 0, line: logContent })
      continue
    }
    for (const line of logContent.split(/\r?\n/)) {
      const timestamp = diagnosticLineTimestamp(line)
      if (timestamp !== null && timestamp >= window.start && timestamp <= window.end) {
        windowedLines.push({ timestamp, line })
      }
    }
  }
  windowedLines.sort((left, right) => left.timestamp - right.timestamp)
  const content = windowedLines.map(({ line }) => line).join('\n')
  const stageCounts = new Map()
  for (const stage of DIAGNOSTIC_STAGES) {
    const count = countStage(content, stage)
    if (count > 0) {
      stageCounts.set(stage, count)
    }
  }
  const stages = [...stageCounts.entries()].map(([stage, count]) => ({ stage, count }))
  const has = (stage) => stageCounts.has(stage)
  return {
    logPresent: true,
    selectedLog: basename(selectedLog),
    scannedLogCount: logsToRead.length,
    windowed: window !== null,
    stages,
    terminal401: has('account_authenticated_read_terminal_401_after_restore') ||
      has('account_authenticated_read_terminal_401_after_promotion'),
    responseCookieStored: has('account_response_cookie_stored'),
    responseAuthCookieApplied: has('account_response_auth_cookie_applied'),
    responseCookieRejected: has('account_response_cookie_rejected'),
    favoritesSuccess: has('favorites_request_success'),
    favoritesFailed: has('favorites_request_failed'),
    authExpiryShapes: authExpiryShapes(content),
    eventSequence: diagnosticEventSequence(content),
  }
}

export async function summarizeArtifact(inputDirectory) {
  const artifactDirectory = resolve(inputDirectory)
  const [metadata, manifest, favoritesLayout, accountLayout, labels] = await Promise.all([
    readJson(join(artifactDirectory, 'run-metadata.json'), 'run_metadata_invalid'),
    readJson(join(artifactDirectory, 'protocol-manifest.json'), 'protocol_manifest_invalid'),
    readJson(join(artifactDirectory, 'favorites.json'), 'favorites_layout_invalid'),
    readJson(join(artifactDirectory, 'account.json'), 'account_layout_invalid'),
    Promise.all([
      loadLabels(new Set(['favorites_sign_in_settings'])),
      loadLabels(new Set(['favorites_checking_session', 'favorites_loading'])),
      loadLabels(new Set(['common_retry'])),
      loadLabels(new Set(['favorites_empty', 'favorites_search_empty'])),
      loadLabels(new Set(['account_sign_in'])),
      loadLabels(new Set(['account_status_verification_required'])),
      loadLabels(new Set(['account_subtitle_verification_required'])),
      loadLabels(new Set(['account_verify_sign_in'])),
      loadLabels(new Set(['account_save_failed'])),
    ]),
  ])
  const [favoritesSignIn, favoritesLoading, favoritesError, favoritesEmpty,
    accountSignIn, accountVerification, accountVerificationMessage,
    accountVerificationAction, accountSaveFailed] = labels

  const commands = Array.isArray(metadata.commands) ? metadata.commands : []
  const accountListRootCount = countVisibleMarker(accountLayout, ACCOUNT_LIST_ROOT_ID)
  const accountRoot = firstVisibleMarker(accountLayout, ACCOUNT_LIST_ROOT_ID) ?? accountLayout
  const savedAccountCount = countVisibleMarker(accountRoot, ACCOUNT_SAVED_ROW_ID)
  const selectedSavedAccountCount = selectedRadioCount(accountRoot)
  const accountWebVisible = hasType(accountLayout, WEB_TYPES)
  const accountSignInPrompt = hasKnownLabel(accountRoot, accountSignIn)
  const verificationRequired = hasKnownLabel(accountRoot, accountVerification)
  const saveFailed = hasKnownLabel(accountRoot, accountSaveFailed)

  const favoritesRootCount = countVisibleMarker(favoritesLayout, FAVORITES_ROOT_ID)
  const favoritesRoot = firstVisibleMarker(favoritesLayout, FAVORITES_ROOT_ID) ?? favoritesLayout
  const favoritesWebVisible = hasType(favoritesLayout, WEB_TYPES)
  const favoritesSignInPrompt = hasKnownLabel(favoritesRoot, favoritesSignIn)
  const favoritesIsLoading = hasKnownLabel(favoritesRoot, favoritesLoading)
  const favoritesHasError = hasKnownLabel(favoritesRoot, favoritesError)
  const favoritesIsEmpty = hasKnownLabel(favoritesRoot, favoritesEmpty)
  const favoritesHasCollection = hasType(favoritesRoot, COLLECTION_TYPES)
  const favoritesForegroundNextn = isForegroundNextn(favoritesLayout)
  const accountForegroundNextn = isForegroundNextn(accountLayout)
  const favoritesVerificationSnackBar = verificationSnackBarSummary(
    favoritesLayout,
    accountVerification,
    accountVerificationMessage,
    accountVerificationAction,
  )
  const accountVerificationSnackBar = verificationSnackBarSummary(
    accountLayout,
    accountVerification,
    accountVerificationMessage,
    accountVerificationAction,
  )

  return {
    schemaVersion: 1,
    artifact: {
      metadataTargetMatches237: metadata.target === AUTHORIZED_TARGET,
      manifestTargetMatches237: manifest.target === AUTHORIZED_TARGET,
      authorizedTargetMatches237: manifest.authorizedTarget === AUTHORIZED_TARGET,
      runCompleted: metadata.status === 'completed' && commands.length > 0 &&
        commands.every((command) => command?.exitCode === 0),
      commandCount: commands.length,
    },
    favorites: {
      foregroundNextn: favoritesForegroundNextn,
      rootCount: favoritesRootCount,
      webVisible: favoritesWebVisible,
      collectionPresent: favoritesHasCollection,
      signInPrompt: favoritesSignInPrompt,
      loading: favoritesIsLoading,
      error: favoritesHasError,
      empty: favoritesIsEmpty,
      verificationSnackBar: favoritesVerificationSnackBar,
      authenticatedLayoutCandidate: favoritesForegroundNextn && favoritesRootCount === 1 &&
        !favoritesWebVisible && !favoritesSignInPrompt && !favoritesIsLoading &&
        !favoritesHasError && !favoritesVerificationSnackBar.visible &&
        (favoritesHasCollection || favoritesIsEmpty),
    },
    account: {
      foregroundNextn: accountForegroundNextn,
      listRootCount: accountListRootCount,
      savedAccountCount,
      selectedSavedAccountCount,
      webVisible: accountWebVisible,
      signInPrompt: accountSignInPrompt,
      verificationRequired,
      verificationSnackBar: accountVerificationSnackBar,
      saveFailed,
      authenticatedLayoutCandidate: accountForegroundNextn && accountListRootCount === 1 && savedAccountCount > 0 &&
        selectedSavedAccountCount === 1 && !accountWebVisible && !accountSignInPrompt &&
        !verificationRequired && !accountVerificationSnackBar.visible && !saveFailed,
    },
    diagnostics: await diagnosticsSummary(artifactDirectory, manifest, metadata),
  }
}

async function main() {
  if (process.argv.length !== 3) {
    throw new SafeFailure('invalid_arguments')
  }
  const summary = await summarizeArtifact(process.argv[2])
  process.stdout.write(`${JSON.stringify({ ok: true, summary }, null, 2)}\n`)
}

if (process.argv[1] !== undefined &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    const code = error instanceof SafeFailure ? error.code : 'summary_failed'
    process.stdout.write(`${JSON.stringify({ ok: false, error: code })}\n`)
    process.exitCode = 1
  })
}
