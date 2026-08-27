#!/usr/bin/env node

/**
 * Privacy-bounded S0 reader for the NextN account acceptance protocol.
 *
 * It never writes layouts, screenshots, logs, text, bounds, or account data
 * into the repository. Raw inspector layouts exist only in a 0700 host temp
 * directory during parsing and are deleted, together with the exact remote
 * dump file, before this process exits.
 */

import { spawn } from 'node:child_process'
import { randomUUID } from 'node:crypto'
import { chmod, mkdir, mkdtemp, readFile, readdir, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPOSITORY_ROOT = dirname(dirname(fileURLToPath(import.meta.url)))
const LEASE_SCRIPT = join(REPOSITORY_ROOT, 'scripts', 'device-lease')
const HDC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
const NEXTN_BUNDLE = 'com.erosteam.nextn'
const ENTRY_ABILITY = 'EntryAbility'
const ACCOUNT_ENTRY_ID = 'nextn-settings-root-account'
const ACCOUNT_NATIVE_ROOT_ID = 'nextn-account-native-root'
const ACCOUNT_LIST_ROOT_ID = 'nextn-account-list-root'
const ACCOUNT_SAVED_ROW_ID = 'nextn-account-saved-row'
const FAVORITES_ROOT_ID = 'nextn-favorites-root'
const DIAGNOSTICS_SETTINGS_GROUP_ID = 'nextn-diagnostics-settings-group'
const DIAGNOSTICS_ACTIONS_GROUP_ID = 'nextn-diagnostics-actions-group'
const DIAGNOSTICS_FILES_GROUP_ID = 'nextn-diagnostics-files-group'
const LEGACY_ACCOUNT_VERIFICATION_LABELS = new Set([
  'Verification needed',
  '需要重新验证',
  '再確認が必要です'
])
// The active account-acceptance lane is explicitly scoped to device 237.
// Connection discovery and lease ownership cannot expand this authority.
const AUTHORIZED_TARGET = '192.168.50.237:12345'
const RESOURCE_LOCALES = ['base', 'en_US', 'zh_CN', 'ja_JP']
const TEMP_PREFIX = 'nextn-account-s0-'
const REMOTE_PREFIX = '/data/local/tmp/nextn-account-s0-'
const REMOTE_DIAGNOSTICS_DIR =
  '/data/app/el2/100/base/com.erosteam.nextn/haps/entry/files/diagnostics_logs'
const ROOT_SETTLE_MS = 650
const ROOT_STOP_SETTLE_MS = 250
const NAVIGATION_SETTLE_MS = 650
const ANCHOR_POLL_MS = 500
const ANCHOR_POLLS = 4
const FAVORITES_POLL_MS = 800
const FAVORITES_POLLS = 8
const ACCOUNT_POLL_MS = 800
const ACCOUNT_POLLS = 4

class SafeFailure extends Error {
  constructor(code) {
    super(code)
    this.code = code
  }
}

function parseArguments(argv) {
  let target = ''
  let lease = ''
  let routeLogin = false
  let includeDiagnostics = false
  let accountOnly = false
  for (let index = 2; index < argv.length; index += 1) {
    const argument = argv[index]
    if (argument === '--target') {
      target = argv[index + 1] ?? ''
      index += 1
      continue
    }
    if (argument === '--lease') {
      lease = argv[index + 1] ?? ''
      index += 1
      continue
    }
    if (argument === '--route-login') {
      routeLogin = true
      continue
    }
    if (argument === '--include-diagnostics') {
      includeDiagnostics = true
      continue
    }
    if (argument === '--account-only') {
      accountOnly = true
      continue
    }
    throw new SafeFailure('invalid_arguments')
  }
  if (target !== AUTHORIZED_TARGET || lease.length === 0) {
    throw new SafeFailure('invalid_arguments')
  }
  if (accountOnly && (routeLogin || includeDiagnostics)) {
    throw new SafeFailure('invalid_arguments')
  }
  return { target, lease, routeLogin, includeDiagnostics, accountOnly }
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds))
}

function run(command, args, timeoutMs = 30_000) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: 'ignore' })
    const timeout = setTimeout(() => {
      child.kill('SIGTERM')
      reject(new SafeFailure('command_timeout'))
    }, timeoutMs)
    child.once('error', () => {
      clearTimeout(timeout)
      reject(new SafeFailure('command_failed'))
    })
    child.once('exit', (code) => {
      clearTimeout(timeout)
      if (code === 0) {
        resolve()
      } else {
        reject(new SafeFailure('command_failed'))
      }
    })
  })
}

async function leaseCommand(target, lease, hdcArguments, failureCode = 'command_failed') {
  try {
    await run(LEASE_SCRIPT, [
      '--device', target,
      'run',
      '--lease', lease,
      '--wait', '30',
      '--',
      HDC,
      '-t', target,
      ...hdcArguments
    ])
  } catch {
    throw new SafeFailure(failureCode)
  }
}

function attributes(node) {
  if (node !== null && typeof node === 'object' && node.attributes !== null && typeof node.attributes === 'object') {
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

function nodeTextValues(node) {
  const attrs = attributes(node)
  const keys = ['id', 'text', 'originalText', 'description', 'accessibilityText', 'accessibilityId', 'hint', 'content', 'value']
  return keys
    .map((key) => attrs[key])
    .filter((value) => typeof value === 'string')
    .map((value) => value.trim())
    .filter((value) => value.length > 0)
}

function walk(node, visitor, ancestors = []) {
  if (node === null || typeof node !== 'object' || !isVisible(node)) {
    return
  }
  visitor(node, ancestors)
  const nextAncestors = [...ancestors, node]
  for (const child of children(node)) {
    walk(child, visitor, nextAncestors)
  }
}

function isForegroundNextn(root) {
  const declaredRoot = attributes(root)
  const windows = String(declaredRoot.abilityName ?? '').length > 0
    ? [root]
    : children(root).filter((node) => isVisible(node) && String(attributes(node).hostWindowId ?? '').length > 0)
  const focusedWindows = windows.filter((node) => String(attributes(node).focused ?? '').toLowerCase() === 'true')
  return focusedWindows.length === 1 &&
    String(attributes(focusedWindows[0]).bundleName ?? '') === NEXTN_BUNDLE &&
    String(attributes(focusedWindows[0]).abilityName ?? '') === ENTRY_ABILITY &&
    parseBounds(attributes(focusedWindows[0]).bounds ?? attributes(focusedWindows[0]).bound) !== null
}

function foregroundWindowBounds(root) {
  const declaredRoot = attributes(root)
  const windows = String(declaredRoot.abilityName ?? '').length > 0
    ? [root]
    : children(root).filter((node) => isVisible(node) && String(attributes(node).hostWindowId ?? '').length > 0)
  const focused = windows.filter((node) => String(attributes(node).focused ?? '').toLowerCase() === 'true')
  if (focused.length !== 1) {
    return null
  }
  return parseBounds(attributes(focused[0]).bounds ?? attributes(focused[0]).bound)
}

function hasLabel(root, labels) {
  let found = false
  walk(root, (node) => {
    if (nodeTextValues(node).some((value) => labels.has(value))) {
      found = true
    }
  })
  return found
}

function hasLabelSuffix(root, labels) {
  let found = false
  walk(root, (node) => {
    if (nodeTextValues(node).some((value) => [...labels].some((label) =>
      value === label || value.endsWith(`. ${label}`)))) {
      found = true
    }
  })
  return found
}

function hasLabelPrefix(root, labels) {
  let found = false
  walk(root, (node) => {
    if (nodeTextValues(node).some((value) => [...labels].some((label) =>
      value === label || value.startsWith(`${label}. `)))) {
      found = true
    }
  })
  return found
}

function hasSelectedLabel(root, labels) {
  let found = false
  walk(root, (node, ancestors) => {
    if (!nodeTextValues(node).some((value) => labels.has(value))) {
      return
    }
    if ([...ancestors, node].some((candidate) => String(attributes(candidate).selected ?? '').toLowerCase() === 'true')) {
      found = true
    }
  })
  return found
}

function escapeRegularExpression(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

function hasFormattedTemplate(root, templates, replacementPattern) {
  const patterns = [...templates].map((template) => {
    const escaped = escapeRegularExpression(template)
    return new RegExp(`^${escaped.replace('\\{0\\}', `(?:${replacementPattern})`)}$`)
  })
  let found = false
  walk(root, (node) => {
    if (nodeTextValues(node).some((value) => patterns.some((pattern) => pattern.test(value)))) {
      found = true
    }
  })
  return found
}

function hasMalformedTemplateText(root) {
  let found = false
  walk(root, (node) => {
    if (nodeTextValues(node).some((value) =>
      /%\d+\$[a-z]/i.test(value) || /\{\d+\}/.test(value) || /(?:^|[\s·：:])\d+%(?:$|[\s·])/i.test(value))) {
      found = true
    }
  })
  return found
}

function uniqueVisibleMarker(root, markerId, missingCode, ambiguousCode) {
  const matches = []
  walk(root, (node) => {
    const attrs = attributes(node)
    if (String(attrs.id ?? '') === markerId || String(attrs.accessibilityId ?? '') === markerId) {
      matches.push(node)
    }
  })
  if (matches.length === 0) {
    throw new SafeFailure(missingCode)
  }
  if (matches.length !== 1) {
    throw new SafeFailure(ambiguousCode)
  }
  return matches[0]
}

function hasType(root, expectedTypes) {
  let found = false
  walk(root, (node) => {
    if (expectedTypes.has(nodeType(node))) {
      found = true
    }
  })
  return found
}

function accountRadioSummary(root) {
  let savedAccountCount = 0
  let selectedSavedAccountCount = 0
  walk(root, (node) => {
    const attrs = attributes(node)
    const hasCheckedState = attrs.checked !== undefined &&
      (String(attrs.checked).toLowerCase() === 'true' || String(attrs.checked).toLowerCase() === 'false')
    if (nodeType(node) !== 'Radio' && !hasCheckedState) {
      return
    }
    savedAccountCount += 1
    const selected = String(attrs.checked ?? attrs.selected ?? '').toLowerCase() === 'true'
    if (selected) {
      selectedSavedAccountCount += 1
    }
  })
  return {
    savedAccountCount,
    selectedSavedAccountCount,
    selectionPresent: selectedSavedAccountCount === 1,
  }
}

function visibleMarkerCount(root, markerId) {
  let count = 0
  walk(root, (node) => {
    const attrs = attributes(node)
    if (String(attrs.id ?? '') === markerId || String(attrs.accessibilityId ?? '') === markerId) {
      count += 1
    }
  })
  return count
}

function parseBounds(value) {
  const match = /^\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]$/.exec(String(value ?? ''))
  if (match === null) {
    return null
  }
  const left = Number.parseInt(match[1], 10)
  const top = Number.parseInt(match[2], 10)
  const right = Number.parseInt(match[3], 10)
  const bottom = Number.parseInt(match[4], 10)
  if (right <= left || bottom <= top) {
    return null
  }
  return { left, top, right, bottom }
}

function clickableBounds(node) {
  const attrs = attributes(node)
  if (String(attrs.clickable ?? '').toLowerCase() !== 'true' || String(attrs.enabled ?? 'true').toLowerCase() === 'false') {
    return null
  }
  return parseBounds(attrs.bounds ?? attrs.bound)
}

function clickableDescendantBounds(node) {
  const candidates = new Map()
  walk(node, (candidate) => {
    const bounds = clickableBounds(candidate)
    if (bounds !== null) {
      candidates.set(`${bounds.left}:${bounds.top}:${bounds.right}:${bounds.bottom}`, bounds)
    }
  })
  return candidates
}

function resolveClickableAnchor(root, labels) {
  const candidates = new Map()
  walk(root, (node, ancestors) => {
    if (!nodeTextValues(node).some((value) => labels.has(value))) {
      return
    }
    const path = [...ancestors, node]
    for (let index = path.length - 1; index >= 0; index -= 1) {
      const bounds = clickableBounds(path[index])
      if (bounds !== null) {
        const key = `${bounds.left}:${bounds.top}:${bounds.right}:${bounds.bottom}`
        candidates.set(key, bounds)
        return
      }
    }
    const descendants = clickableDescendantBounds(node)
    if (descendants.size === 1) {
      const bounds = [...descendants.values()][0]
      const key = `${bounds.left}:${bounds.top}:${bounds.right}:${bounds.bottom}`
      candidates.set(key, bounds)
    }
  })
  if (candidates.size === 0) {
    throw new SafeFailure('anchor_missing')
  }
  if (candidates.size !== 1) {
    throw new SafeFailure('anchor_ambiguous')
  }
  return [...candidates.values()][0]
}

function resolveTitleBarTrailingAction(root) {
  const windowBounds = foregroundWindowBounds(root)
  if (windowBounds === null) {
    throw new SafeFailure('foreground_bounds_missing')
  }
  const candidates = new Map()
  walk(root, (node) => {
    const bounds = clickableBounds(node)
    if (bounds === null) {
      return
    }
    const centerX = (bounds.left + bounds.right) / 2
    const centerY = (bounds.top + bounds.bottom) / 2
    const rightThreshold = windowBounds.left + (windowBounds.right - windowBounds.left) * 0.65
    const titleBottom = windowBounds.top + (windowBounds.bottom - windowBounds.top) * 0.16
    if (centerX >= rightThreshold && centerY <= titleBottom) {
      candidates.set(`${bounds.left}:${bounds.top}:${bounds.right}:${bounds.bottom}`, bounds)
    }
  })
  if (candidates.size === 0) {
    throw new SafeFailure('login_action_anchor_missing')
  }
  return [...candidates.values()].sort((left, right) => {
    const leftArea = (left.right - left.left) * (left.bottom - left.top)
    const rightArea = (right.right - right.left) * (right.bottom - right.top)
    if (leftArea !== rightArea) {
      return rightArea - leftArea
    }
    return right.right - left.right
  })[0]
}

function centerOf(bounds) {
  return {
    x: Math.floor((bounds.left + bounds.right) / 2),
    y: Math.floor((bounds.top + bounds.bottom) / 2)
  }
}

async function loadLabels(keys) {
  const labels = new Set()
  for (const locale of RESOURCE_LOCALES) {
    const resourcePath = join(REPOSITORY_ROOT, 'entry', 'src', 'main', 'resources', locale, 'element', 'string.json')
    let resource
    try {
      resource = JSON.parse(await readFile(resourcePath, 'utf8'))
    } catch {
      throw new SafeFailure('resource_catalog_invalid')
    }
    for (const entry of resource.string ?? []) {
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

async function collectLayout(target, lease, hostTempDirectory, label) {
  const suffix = randomUUID()
  const remotePath = `${REMOTE_PREFIX}${suffix}.json`
  const localPath = join(hostTempDirectory, `${label}-${suffix}.json`)
  let result = null
  let primaryFailure = null
  try {
    await leaseCommand(target, lease, ['shell', 'uitest', 'dumpLayout', '-p', remotePath], 'layout_dump_failed')
    await leaseCommand(target, lease, ['file', 'recv', remotePath, localPath], 'layout_receive_failed')
    result = JSON.parse(await readFile(localPath, 'utf8'))
  } catch (error) {
    primaryFailure = error instanceof SafeFailure ? error : new SafeFailure('layout_capture_failed')
  }
  const cleanupResults = await Promise.allSettled([
    rm(localPath, { force: true }),
    leaseCommand(target, lease, ['shell', 'rm', '-f', remotePath], 'layout_cleanup_failed')
  ])
  if (cleanupResults.some((cleanup) => cleanup.status === 'rejected')) {
    throw new SafeFailure('layout_cleanup_failed')
  }
  if (primaryFailure !== null) {
    throw primaryFailure
  }
  return result
}

/**
 * Reads only the last fixed Favorites outcome event from the current process
 * log. The redacted file is received into the existing 0700 temp directory,
 * never printed, and deleted with that directory before exit.
 */
async function collectFavoritesRequestOutcome(target, lease, hostTempDirectory) {
  const receivedRoot = join(hostTempDirectory, `favorites-log-${randomUUID()}`)
  try {
    await mkdir(receivedRoot, { recursive: true, mode: 0o700 })
    await leaseCommand(
      target,
      lease,
      ['file', 'recv', REMOTE_DIAGNOSTICS_DIR, receivedRoot],
      'diagnostics_receive_failed',
    )
    const directory = join(receivedRoot, 'diagnostics_logs')
    const names = (await readdir(directory))
      .filter((name) => /^nextn-log-\d{8}-\d{6}(?:-\d+)?\.txt$/.test(name))
      .sort()
      .reverse()
    if (names.length === 0) {
      return ''
    }
    const text = await readFile(join(directory, names[0]), 'utf8')
    const successIndex = text.lastIndexOf('favorites-session.favorites_request_success')
    const failedIndex = text.lastIndexOf('favorites-session.favorites_request_failed')
    if (successIndex < 0 && failedIndex < 0) {
      return ''
    }
    return successIndex > failedIndex ? 'success' : 'failed'
  } catch {
    return ''
  } finally {
    await rm(receivedRoot, { recursive: true, force: true })
  }
}

async function startAtRoot(target, lease) {
  await leaseCommand(target, lease, ['shell', 'aa', 'force-stop', NEXTN_BUNDLE], 'root_stop_failed')
  await sleep(ROOT_STOP_SETTLE_MS)
  await leaseCommand(target, lease, ['shell', 'aa', 'start', '-b', NEXTN_BUNDLE, '-a', ENTRY_ABILITY], 'root_start_failed')
  await sleep(ROOT_SETTLE_MS)
}

async function tapAnchor(target, lease, root, labels, missingCode, ambiguousCode) {
  if (!isForegroundNextn(root)) {
    throw new SafeFailure('foreground_unexpected')
  }
  let point
  try {
    point = centerOf(resolveClickableAnchor(root, labels))
  } catch (error) {
    if (error instanceof SafeFailure && error.code === 'anchor_missing') {
      throw new SafeFailure(missingCode)
    }
    if (error instanceof SafeFailure && error.code === 'anchor_ambiguous') {
      throw new SafeFailure(ambiguousCode)
    }
    throw error
  }
  await leaseCommand(target, lease, ['shell', 'uitest', 'uiInput', 'click', String(point.x), String(point.y)], 'input_failed')
  await sleep(NAVIGATION_SETTLE_MS)
}

async function swipePageUp(target, lease, root) {
  const bounds = foregroundWindowBounds(root)
  if (bounds === null) {
    throw new SafeFailure('foreground_bounds_missing')
  }
  const x = Math.floor((bounds.left + bounds.right) / 2)
  const startY = Math.floor(bounds.top + (bounds.bottom - bounds.top) * 0.78)
  const endY = Math.floor(bounds.top + (bounds.bottom - bounds.top) * 0.28)
  await leaseCommand(
    target,
    lease,
    ['shell', 'uitest', 'uiInput', 'swipe', String(x), String(startY), String(x), String(endY), '600'],
    'input_failed',
  )
  await sleep(NAVIGATION_SETTLE_MS)
}

async function waitForAnchorableLayout(target, lease, hostTempDirectory, label, labels, missingCode, ambiguousCode) {
  for (let index = 0; index < ANCHOR_POLLS; index += 1) {
    const layout = await collectLayout(target, lease, hostTempDirectory, `${label}-${index}`)
    if (!isForegroundNextn(layout)) {
      throw new SafeFailure('foreground_unexpected')
    }
    try {
      resolveClickableAnchor(layout, labels)
      return layout
    } catch (error) {
      if (!(error instanceof SafeFailure) || error.code !== 'anchor_missing') {
        if (error instanceof SafeFailure && error.code === 'anchor_ambiguous') {
          throw new SafeFailure(ambiguousCode)
        }
        throw error
      }
      if (index + 1 < ANCHOR_POLLS) {
        await sleep(ANCHOR_POLL_MS)
      }
    }
  }
  throw new SafeFailure(missingCode)
}

function accountSummary(root, labels) {
  const nativeRootCount = visibleMarkerCount(root, ACCOUNT_NATIVE_ROOT_ID)
  const accountListRootCount = visibleMarkerCount(root, ACCOUNT_LIST_ROOT_ID)
  const visibleLoginWeb = hasType(root, new Set(['Web', 'WebComponent']))
  if (nativeRootCount + accountListRootCount === 0 && visibleLoginWeb) {
    return {
      visibleLoginWeb: true,
      nativeSection: false,
      loginCandidatePage: false,
      accountListPage: false,
      signedIn: false,
      signedOut: true,
      verificationRequired: false,
      saveFailed: false,
      savedAccountCount: 0,
      selectedSavedAccountCount: 0,
      selectionPresent: false,
    }
  }
  if (nativeRootCount + accountListRootCount !== 1) {
    throw new SafeFailure('account_summary_incomplete')
  }
  const accountRoot = accountListRootCount === 1
    ? uniqueVisibleMarker(root, ACCOUNT_LIST_ROOT_ID, 'account_summary_incomplete', 'account_summary_incomplete')
    : root
  const visibleNativeLoginWeb = hasType(accountRoot, new Set(['Web', 'WebComponent']))
  const signedInLabel = hasLabelSuffix(accountRoot, labels.accountSignedIn)
  const signedOut = hasLabel(accountRoot, labels.accountSignedOut) ||
    hasLabelPrefix(accountRoot, labels.accountSignIn)
  const verificationRequired = hasLabel(accountRoot, labels.accountVerificationRequired)
  const saveFailed = hasLabel(accountRoot, labels.accountSaveFailed)
  const nativeSection = !visibleNativeLoginWeb
  const radioSummary = accountRadioSummary(accountRoot)
  const savedRowCount = visibleMarkerCount(accountRoot, ACCOUNT_SAVED_ROW_ID)
  const savedAccountCount = accountListRootCount === 1
    ? savedRowCount
    : 0
  const selectedSavedAccountCount = accountListRootCount === 1
    ? Math.min(savedRowCount, radioSummary.selectedSavedAccountCount)
    : 0
  const selectionPresent = selectedSavedAccountCount === 1
  // Settings opens AccountPage only for durable account ownership. On that
  // page the active Radio is the safe, non-PII proof of the selected owner;
  // the signed-in status string belongs to the preceding Settings row.
  const signedIn = signedInLabel || (accountListRootCount === 1 && selectionPresent)
  return {
    visibleLoginWeb: visibleNativeLoginWeb,
    nativeSection,
    loginCandidatePage: nativeRootCount === 1,
    accountListPage: accountListRootCount === 1,
    signedIn,
    signedOut,
    verificationRequired,
    saveFailed,
    savedAccountCount,
    selectedSavedAccountCount,
    selectionPresent,
  }
}

function favoritesSummary(root, labels) {
  const favoritesRoot = uniqueVisibleMarker(root, FAVORITES_ROOT_ID, 'favorites_root_marker_missing', 'favorites_root_marker_ambiguous')
  const nativeStructure = isForegroundNextn(root) && hasSelectedLabel(root, labels.favoritesNative)
  const collection = hasType(favoritesRoot, new Set(['List', 'Grid', 'WaterFlow']))
  // A retained Favorites page can mount cached cards and an inline request
  // error at the same time. Cached collection structure is never proof of a
  // successful current authenticated request.
  const primaryState = !collection
  const signInPrompt = primaryState && hasLabel(favoritesRoot, labels.favoritesSignInPrompt)
  const loading = primaryState && hasLabel(favoritesRoot, labels.favoritesLoading)
  const error = hasLabel(favoritesRoot, labels.favoritesError)
  const empty = primaryState && hasLabel(favoritesRoot, labels.favoritesEmpty)
  const authenticated = nativeStructure && !error &&
    (collection || (!signInPrompt && !loading && empty))
  return { nativeStructure, signInPrompt, loading, error, authenticated }
}

function diagnosticsSummary(root, labels) {
  const settingsGroup = visibleMarkerCount(root, DIAGNOSTICS_SETTINGS_GROUP_ID) === 1
  const actionsGroup = visibleMarkerCount(root, DIAGNOSTICS_ACTIONS_GROUP_ID) === 1
  const filesGroup = visibleMarkerCount(root, DIAGNOSTICS_FILES_GROUP_ID) === 1
  const enabledAction = hasLabel(root, labels.diagnosticsEnabled)
  const exportAction = hasLabel(root, labels.diagnosticsExport)
  const markerAction = hasLabel(root, labels.diagnosticsMarker)
  const noFiles = hasLabel(root, labels.diagnosticsNoFiles)
  const persistentLogPresent = filesGroup && !noFiles
  const currentLaunchCountFormatted = hasFormattedTemplate(root, labels.diagnosticsCurrentLaunchCount, '\\d+')
  const retainedFileCountFormatted = hasFormattedTemplate(root, labels.diagnosticsRetainedFileCount, '\\d+')
  const logTitleFormatted = hasFormattedTemplate(
    root,
    new Set([...labels.diagnosticsCurrentLogTitle, ...labels.diagnosticsStartupLogTitle]),
    '\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}',
  )
  const logShareHintFormatted = hasFormattedTemplate(
    root,
    labels.diagnosticsLogShareHint,
    '\\d+(?:\\.\\d+)? (?:B|KB|MB)',
  )
  const malformedTemplateAbsent = !hasMalformedTemplateText(root)
  return {
    settingsGroup,
    actionsGroup,
    filesGroup,
    enabledAction,
    exportAction,
    markerAction,
    persistentLogPresent,
    currentLaunchCountFormatted,
    retainedFileCountFormatted,
    logTitleFormatted,
    logShareHintFormatted,
    malformedTemplateAbsent,
  }
}

async function observeAccount(target, lease, hostTempDirectory, labels) {
  await startAtRoot(target, lease)
  const root = await collectLayout(target, lease, hostTempDirectory, 'settings-root')
  await tapAnchor(target, lease, root, labels.tabSettings, 'settings_tab_anchor_missing', 'settings_tab_anchor_ambiguous')
  const settings = await waitForAnchorableLayout(target, lease, hostTempDirectory, 'settings', labels.accountEntry, 'account_entry_anchor_missing', 'account_entry_anchor_ambiguous')
  await tapAnchor(target, lease, settings, labels.accountEntry, 'account_entry_anchor_missing', 'account_entry_anchor_ambiguous')
  let summary = null
  for (let index = 0; index < ACCOUNT_POLLS; index += 1) {
    const account = await collectLayout(target, lease, hostTempDirectory, `account-${index}`)
    if (!isForegroundNextn(account)) {
      throw new SafeFailure('foreground_unexpected')
    }
    summary = accountSummary(account, labels)
    if (summary.visibleLoginWeb || (summary.nativeSection &&
      (summary.signedIn || summary.signedOut || summary.verificationRequired || summary.saveFailed ||
        summary.savedAccountCount > 0))) {
      break
    }
    await sleep(ACCOUNT_POLL_MS)
  }
  if (summary === null || (!summary.visibleLoginWeb && (!summary.nativeSection ||
    (!summary.signedIn && !summary.signedOut && !summary.verificationRequired && !summary.saveFailed &&
      summary.savedAccountCount <= 0)))) {
    throw new SafeFailure('account_summary_incomplete')
  }
  return summary
}

async function observeFavorites(target, lease, hostTempDirectory, labels) {
  await startAtRoot(target, lease)
  const root = await collectLayout(target, lease, hostTempDirectory, 'favorites-root')
  await tapAnchor(target, lease, root, labels.tabFavorites, 'favorites_tab_anchor_missing', 'favorites_tab_anchor_ambiguous')
  let summary = null
  for (let index = 0; index < FAVORITES_POLLS; index += 1) {
    const favorites = await collectLayout(target, lease, hostTempDirectory, `favorites-${index}`)
    if (!isForegroundNextn(favorites)) {
      throw new SafeFailure('foreground_unexpected')
    }
    summary = favoritesSummary(favorites, labels)
    if (summary.signInPrompt || summary.error || (!summary.loading && !summary.authenticated)) {
      break
    }
    if (index + 1 < FAVORITES_POLLS) {
      await sleep(FAVORITES_POLL_MS)
    }
  }
  if (summary === null || !summary.nativeStructure || (!summary.signInPrompt && !summary.loading && !summary.error && !summary.authenticated)) {
    throw new SafeFailure('favorites_summary_incomplete')
  }
  const requestOutcome = await collectFavoritesRequestOutcome(target, lease, hostTempDirectory)
  if (requestOutcome === 'failed') {
    summary.error = true
    summary.authenticated = false
  } else if (requestOutcome === 'success') {
    summary.error = false
    summary.authenticated = true
  }
  return summary
}

async function observeDiagnostics(target, lease, hostTempDirectory, labels) {
  await startAtRoot(target, lease)
  const root = await collectLayout(target, lease, hostTempDirectory, 'diagnostics-root')
  await tapAnchor(target, lease, root, labels.tabSettings, 'settings_tab_anchor_missing', 'settings_tab_anchor_ambiguous')
  const settings = await waitForAnchorableLayout(
    target,
    lease,
    hostTempDirectory,
    'diagnostics-settings',
    labels.settingsAdvanced,
    'advanced_settings_anchor_missing',
    'advanced_settings_anchor_ambiguous',
  )
  await tapAnchor(
    target,
    lease,
    settings,
    labels.settingsAdvanced,
    'advanced_settings_anchor_missing',
    'advanced_settings_anchor_ambiguous',
  )
  const summary = {
    settingsGroup: false,
    actionsGroup: false,
    filesGroup: false,
    enabledAction: false,
    exportAction: false,
    markerAction: false,
    persistentLogPresent: false,
    currentLaunchCountFormatted: false,
    retainedFileCountFormatted: false,
    logTitleFormatted: false,
    logShareHintFormatted: false,
    malformedTemplateAbsent: true,
  }
  for (let index = 0; index < 6; index += 1) {
    const advanced = await collectLayout(target, lease, hostTempDirectory, `diagnostics-advanced-${index}`)
    if (!isForegroundNextn(advanced)) {
      throw new SafeFailure('foreground_unexpected')
    }
    const observed = diagnosticsSummary(advanced, labels)
    summary.settingsGroup = summary.settingsGroup || observed.settingsGroup
    summary.actionsGroup = summary.actionsGroup || observed.actionsGroup
    summary.filesGroup = summary.filesGroup || observed.filesGroup
    summary.enabledAction = summary.enabledAction || observed.enabledAction
    summary.exportAction = summary.exportAction || observed.exportAction
    summary.markerAction = summary.markerAction || observed.markerAction
    summary.persistentLogPresent = summary.persistentLogPresent || observed.persistentLogPresent
    summary.currentLaunchCountFormatted = summary.currentLaunchCountFormatted || observed.currentLaunchCountFormatted
    summary.retainedFileCountFormatted = summary.retainedFileCountFormatted || observed.retainedFileCountFormatted
    summary.logTitleFormatted = summary.logTitleFormatted || observed.logTitleFormatted
    summary.logShareHintFormatted = summary.logShareHintFormatted || observed.logShareHintFormatted
    summary.malformedTemplateAbsent = summary.malformedTemplateAbsent && observed.malformedTemplateAbsent
    if (summary.settingsGroup && summary.actionsGroup && summary.filesGroup &&
      summary.enabledAction && summary.exportAction && summary.markerAction && summary.persistentLogPresent &&
      summary.currentLaunchCountFormatted && summary.retainedFileCountFormatted && summary.logTitleFormatted &&
      summary.logShareHintFormatted && summary.malformedTemplateAbsent) {
      break
    }
    await swipePageUp(target, lease, advanced)
  }
  if (!summary.settingsGroup || !summary.actionsGroup || !summary.filesGroup ||
    !summary.enabledAction || !summary.exportAction || !summary.markerAction || !summary.persistentLogPresent ||
    !summary.currentLaunchCountFormatted || !summary.retainedFileCountFormatted || !summary.logTitleFormatted ||
    !summary.logShareHintFormatted || !summary.malformedTemplateAbsent) {
    throw new SafeFailure('diagnostics_summary_incomplete')
  }
  return summary
}

async function main() {
  let hostTempDirectory = ''
  let account = null
  let favorites = null
  let diagnostics = null
  try {
    const { target, lease, routeLogin, includeDiagnostics, accountOnly } = parseArguments(process.argv)
    hostTempDirectory = await mkdtemp(join(tmpdir(), TEMP_PREFIX))
    await chmod(hostTempDirectory, 0o700)
    const [
      tabSettings,
      tabFavorites,
      accountSignedIn,
      accountSignedOut,
      accountSignIn,
      accountAdd,
      accountWebLogin,
      accountSaveFailed,
      favoritesNative,
      favoritesSignInPrompt,
      favoritesLoading,
      favoritesError,
      favoritesEmpty,
      settingsAdvanced,
      diagnosticsEnabled,
      diagnosticsExport,
      diagnosticsMarker,
      diagnosticsNoFiles,
      diagnosticsCurrentLaunchCount,
      diagnosticsRetainedFileCount,
      diagnosticsCurrentLogTitle,
      diagnosticsStartupLogTitle,
      diagnosticsLogShareHint
    ] = await Promise.all([
      loadLabels(new Set(['tab_me'])),
      loadLabels(new Set(['tab_favorites'])),
      loadLabels(new Set(['account_status_signed_in'])),
      loadLabels(new Set(['account_status_not_signed_in'])),
      loadLabels(new Set(['account_sign_in'])),
      loadLabels(new Set(['settings_add_account'])),
      loadLabels(new Set(['account_web_login'])),
      loadLabels(new Set(['account_save_failed'])),
      loadLabels(new Set(['tab_favorites'])),
      loadLabels(new Set(['favorites_sign_in_settings'])),
      loadLabels(new Set(['favorites_checking_session', 'favorites_loading'])),
      loadLabels(new Set(['common_retry'])),
      loadLabels(new Set(['favorites_empty', 'favorites_search_empty'])),
      loadLabels(new Set(['settings_advanced'])),
      loadLabels(new Set(['diagnostics_enabled'])),
      loadLabels(new Set(['diagnostics_export_current'])),
      loadLabels(new Set(['advanced_write_marker'])),
      loadLabels(new Set(['no_log_files'])),
      loadLabels(new Set(['diagnostics_current_launch_recent_count'])),
      loadLabels(new Set(['retained_local_log_files_count_arg'])),
      loadLabels(new Set(['current_log_with_time'])),
      loadLabels(new Set(['startup_log_with_time'])),
      loadLabels(new Set(['diagnostics_log_file_share_hint']))
    ])
    const labels = {
      tabSettings,
      tabFavorites,
      accountEntry: new Set([ACCOUNT_ENTRY_ID]),
      accountSignedIn,
      accountSignedOut,
      accountSignIn,
      accountAdd,
      accountWebLogin,
      accountVerificationRequired: LEGACY_ACCOUNT_VERIFICATION_LABELS,
      accountSaveFailed,
      favoritesNative,
      favoritesSignInPrompt,
      favoritesLoading,
      favoritesError,
      favoritesEmpty,
      settingsAdvanced,
      diagnosticsEnabled,
      diagnosticsExport,
      diagnosticsMarker,
      diagnosticsNoFiles,
      diagnosticsCurrentLaunchCount,
      diagnosticsRetainedFileCount,
      diagnosticsCurrentLogTitle,
      diagnosticsStartupLogTitle,
      diagnosticsLogShareHint
    }
    account = await observeAccount(target, lease, hostTempDirectory, labels)
    if (accountOnly) {
      return {
        outcome: { ok: true, stage: 'account_only', account },
        exitCode: 0,
        hostTempDirectory,
      }
    }
    if (routeLogin) {
      if (account.visibleLoginWeb) {
        return {
          outcome: { ok: true, stage: 's1_route', visibleLoginWeb: true },
          exitCode: 0,
          hostTempDirectory,
        }
      }
      let accountLayout = await collectLayout(target, lease, hostTempDirectory, 'account-login-route')
      const loginActions = new Set([...labels.accountSignIn, ...labels.accountAdd])
      try {
        await tapAnchor(
          target,
          lease,
          accountLayout,
          loginActions,
          'login_action_anchor_missing',
          'login_action_anchor_ambiguous',
        )
      } catch (error) {
        if (!(error instanceof SafeFailure) || error.code !== 'login_action_anchor_missing') {
          throw error
        }
        const point = centerOf(resolveTitleBarTrailingAction(accountLayout))
        await leaseCommand(
          target,
          lease,
          ['shell', 'uitest', 'uiInput', 'click', String(point.x), String(point.y)],
          'input_failed',
        )
        await sleep(NAVIGATION_SETTLE_MS)
      }
      let visibleLoginWeb = false
      for (let index = 0; index < ACCOUNT_POLLS; index += 1) {
        const loginLayout = await collectLayout(target, lease, hostTempDirectory, `login-route-${index}`)
        visibleLoginWeb = isForegroundNextn(loginLayout) && hasType(loginLayout, new Set(['Web', 'WebComponent']))
        if (visibleLoginWeb) {
          break
        }
        if (index === 0) {
          const browserActions = new Set([...labels.accountWebLogin, ...labels.accountSignIn])
          await tapAnchor(
            target,
            lease,
            loginLayout,
            browserActions,
            'browser_login_action_missing',
            'browser_login_action_ambiguous',
          )
        }
        await sleep(ACCOUNT_POLL_MS)
      }
      return {
        outcome: { ok: visibleLoginWeb, stage: 's1_route', visibleLoginWeb },
        exitCode: visibleLoginWeb ? 0 : 2,
        hostTempDirectory,
      }
    }
    favorites = await observeFavorites(target, lease, hostTempDirectory, labels)
    if (includeDiagnostics) {
      diagnostics = await observeDiagnostics(target, lease, hostTempDirectory, labels)
    }
    const sessionAccepted = account.signedIn && account.selectionPresent && !account.signedOut &&
      !account.verificationRequired && !account.saveFailed && !account.visibleLoginWeb && favorites.authenticated
    return {
      outcome: includeDiagnostics
        ? { ok: true, stage: 's0', account, favorites, diagnostics, sessionAccepted }
        : { ok: true, stage: 's0', account, favorites, sessionAccepted },
      exitCode: 0,
      hostTempDirectory,
    }
  } catch (error) {
    const code = error instanceof SafeFailure ? error.code : 'unexpected_failure'
    const outcome = account === null
      ? { ok: false, stage: 's0', code }
      : { ok: false, stage: 's0', code, account }
    return { outcome, exitCode: 2, hostTempDirectory }
  }
}

async function runMain() {
  const result = await main()
  let outcome = result.outcome
  let exitCode = result.exitCode
  if (result.hostTempDirectory !== undefined && result.hostTempDirectory.length > 0) {
    try {
      await rm(result.hostTempDirectory, { recursive: true, force: true })
    } catch {
      outcome = { ok: false, stage: 's0', code: 'layout_cleanup_failed' }
      exitCode = 2
    }
  } else if (outcome.ok) {
    // The successful path still owns a private temp directory.
    outcome = { ok: false, stage: 's0', code: 'layout_cleanup_failed' }
    exitCode = 2
  }
  process.stdout.write(`${JSON.stringify(outcome)}\n`)
  process.exitCode = exitCode
}

await runMain()
