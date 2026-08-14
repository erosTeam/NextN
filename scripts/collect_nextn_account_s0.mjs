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
import { chmod, mkdtemp, readFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPOSITORY_ROOT = dirname(dirname(fileURLToPath(import.meta.url)))
const LEASE_SCRIPT = join(REPOSITORY_ROOT, 'scripts', 'device-lease')
const HDC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
const NEXTN_BUNDLE = 'com.erosteam.nextn'
const ENTRY_ABILITY = 'EntryAbility'
const ACCOUNT_ENTRY_ID = 'nextn-settings-root-account'
const FAVORITES_ROOT_ID = 'nextn-favorites-root'
const AUTHORIZED_TARGET = '192.168.50.237:12345'
const RESOURCE_LOCALES = ['base', 'en_US', 'zh_CN', 'ja_JP']
const TEMP_PREFIX = 'nextn-account-s0-'
const REMOTE_PREFIX = '/data/local/tmp/nextn-account-s0-'
const ROOT_SETTLE_MS = 650
const ROOT_STOP_SETTLE_MS = 250
const NAVIGATION_SETTLE_MS = 650
const ANCHOR_POLL_MS = 500
const ANCHOR_POLLS = 4
const FAVORITES_POLL_MS = 800
const FAVORITES_POLLS = 4

class SafeFailure extends Error {
  constructor(code) {
    super(code)
    this.code = code
  }
}

function parseArguments(argv) {
  let target = ''
  let lease = ''
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
    throw new SafeFailure('invalid_arguments')
  }
  if (target !== AUTHORIZED_TARGET || lease.length === 0) {
    throw new SafeFailure('invalid_arguments')
  }
  return { target, lease }
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

function hasLabel(root, labels) {
  let found = false
  walk(root, (node) => {
    if (nodeTextValues(node).some((value) => labels.has(value))) {
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
  const visibleLoginWeb = hasType(root, new Set(['Web', 'WebComponent']))
  const signedIn = hasLabel(root, labels.accountSignedIn)
  const signedOut = hasLabel(root, labels.accountSignedOut)
  const verificationRequired = hasLabel(root, labels.accountVerificationRequired)
  const saveFailed = hasLabel(root, labels.accountSaveFailed)
  const nativeSection = !visibleLoginWeb && hasLabel(root, labels.accountNative) && hasLabel(root, labels.accountAction)
  return { visibleLoginWeb, nativeSection, signedIn, signedOut, verificationRequired, saveFailed }
}

function favoritesSummary(root, labels) {
  const favoritesRoot = uniqueVisibleMarker(root, FAVORITES_ROOT_ID, 'favorites_root_marker_missing', 'favorites_root_marker_ambiguous')
  const nativeStructure = isForegroundNextn(root) && hasSelectedLabel(root, labels.favoritesNative)
  const signInPrompt = hasLabel(favoritesRoot, labels.favoritesSignInPrompt)
  const loading = hasLabel(favoritesRoot, labels.favoritesLoading)
  const error = hasLabel(favoritesRoot, labels.favoritesError)
  const empty = hasLabel(favoritesRoot, labels.favoritesEmpty)
  const collection = hasType(favoritesRoot, new Set(['List', 'Grid', 'WaterFlow']))
  const settledPositive = !signInPrompt && !loading && !error && (empty !== collection)
  const authenticated = nativeStructure && settledPositive
  return { nativeStructure, signInPrompt, loading, error, authenticated }
}

async function observeAccount(target, lease, hostTempDirectory, labels) {
  await startAtRoot(target, lease)
  const root = await collectLayout(target, lease, hostTempDirectory, 'settings-root')
  await tapAnchor(target, lease, root, labels.tabSettings, 'settings_tab_anchor_missing', 'settings_tab_anchor_ambiguous')
  const settings = await waitForAnchorableLayout(target, lease, hostTempDirectory, 'settings', labels.accountEntry, 'account_entry_anchor_missing', 'account_entry_anchor_ambiguous')
  await tapAnchor(target, lease, settings, labels.accountEntry, 'account_entry_anchor_missing', 'account_entry_anchor_ambiguous')
  const account = await collectLayout(target, lease, hostTempDirectory, 'account')
  if (!isForegroundNextn(account)) {
    throw new SafeFailure('foreground_unexpected')
  }
  const summary = accountSummary(account, labels)
  if (!summary.nativeSection || (!summary.signedIn && !summary.signedOut && !summary.verificationRequired && !summary.saveFailed)) {
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
    if (!summary.loading) {
      break
    }
    await sleep(FAVORITES_POLL_MS)
  }
  if (summary === null || !summary.nativeStructure || (!summary.signInPrompt && !summary.loading && !summary.error && !summary.authenticated)) {
    throw new SafeFailure('favorites_summary_incomplete')
  }
  return summary
}

async function main() {
  let hostTempDirectory = ''
  let account = null
  let favorites = null
  try {
    const { target, lease } = parseArguments(process.argv)
    hostTempDirectory = await mkdtemp(join(tmpdir(), TEMP_PREFIX))
    await chmod(hostTempDirectory, 0o700)
    const [
      tabSettings,
      tabFavorites,
      accountNative,
      accountSignedIn,
      accountSignedOut,
      accountVerificationRequired,
      accountSaveFailed,
      accountAction,
      favoritesNative,
      favoritesSignInPrompt,
      favoritesLoading,
      favoritesError,
      favoritesEmpty
    ] = await Promise.all([
      loadLabels(new Set(['tab_settings'])),
      loadLabels(new Set(['tab_favorites'])),
      loadLabels(new Set(['account_title'])),
      loadLabels(new Set(['account_status_signed_in'])),
      loadLabels(new Set(['account_status_not_signed_in'])),
      loadLabels(new Set(['account_status_verification_required'])),
      loadLabels(new Set(['account_save_failed'])),
      loadLabels(new Set(['account_open_browser', 'account_sign_in', 'account_verify_sign_in'])),
      loadLabels(new Set(['tab_favorites'])),
      loadLabels(new Set(['favorites_sign_in_settings'])),
      loadLabels(new Set(['favorites_checking_session', 'favorites_loading'])),
      loadLabels(new Set(['favorites_load_failed', 'favorites_retry_loading', 'common_retry'])),
      loadLabels(new Set(['favorites_empty', 'favorites_search_empty']))
    ])
    const labels = {
      tabSettings,
      tabFavorites,
      accountEntry: new Set([ACCOUNT_ENTRY_ID]),
      accountNative,
      accountSignedIn,
      accountSignedOut,
      accountVerificationRequired,
      accountSaveFailed,
      accountAction,
      favoritesNative,
      favoritesSignInPrompt,
      favoritesLoading,
      favoritesError,
      favoritesEmpty
    }
    account = await observeAccount(target, lease, hostTempDirectory, labels)
    favorites = await observeFavorites(target, lease, hostTempDirectory, labels)
    const sessionAccepted = account.signedIn && !account.signedOut && !account.verificationRequired && !account.saveFailed && !account.visibleLoginWeb && favorites.authenticated
    return { outcome: { ok: true, stage: 's0', account, favorites, sessionAccepted }, exitCode: 0, hostTempDirectory }
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
