#!/usr/bin/env node

/**
 * One-process NextN login acceptance cycle.
 *
 * All local preparation, including credential retrieval, happens before the
 * visible login WebView is opened. After that point this process owns the
 * uninterrupted route -> account -> password -> CF -> submit -> native-
 * promotion queue. CAPTCHA is handled only after both field postconditions;
 * the coordinator never pauses for analysis, embeds a test bridge in the App,
 * or kills the App to manufacture an outcome.
 */

import { spawn } from 'node:child_process'
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { createServer } from 'node:net'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import {
  invokeKeychainHandle,
  runCfReviewedSubmit,
  runStagedLoginEpoch,
} from './run_arkweb_login_keychain_epoch.mjs'
import { runDriver } from './drive_arkweb_login_field.mjs'
import { runCookieShape } from './probe_arkweb_cookie_shape.mjs'
import { runProbe } from './probe_arkweb_login_state.mjs'

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)))
const DEVICE_PROTOCOL_SCRIPT = join(ROOT, 'scripts', 'run-device-protocol')
const HDC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
const BUNDLE = 'com.erosteam.nextn'
const DEBUG_WEB_DEVTOOLS_PORT = 19222
// This coordinator belongs to the active 237 login-acceptance lane. A device
// list or a valid lease coordinates access but does not grant authorization.
const AUTHORIZED_TARGET = '192.168.50.237:12345'
const MAX_CAPTURE_BYTES = 1024 * 1024
const CF_GATE_POLL_MS = 100
const CF_READY_TO_SUBMIT_CEILING_MS = 5000
const LOGIN_FLOW_CEILING_MS = 120000
const PROMOTION_WEB_EXIT_POLL_MS = 250
const PROMOTION_LAYOUT_SETTLE_MS = 400
const PROMOTION_LAYOUT_ATTEMPTS = 3
const VISIBLE_LOGIN_ROUTE_ATTEMPTS = 12
const VISIBLE_LOGIN_ROUTE_POLL_MS = 500
const SCREEN_WIDTH = 1320
const SCREEN_HEIGHT = 2120

function safeResult(ok, stage, code = '', extra = {}) {
  return { ok, stage, ...(code.length > 0 ? { code } : {}), ...extra }
}

function parseArguments(argv) {
  let target = ''
  let lease = ''
  let resumeVisible = false
  let resumeStaged = false
  for (let index = 2; index < argv.length; index += 1) {
    if (argv[index] === '--target') {
      target = argv[index + 1] || ''
      index += 1
      continue
    }
    if (argv[index] === '--lease') {
      lease = argv[index + 1] || ''
      index += 1
      continue
    }
    if (argv[index] === '--resume-visible') {
      resumeVisible = true
      continue
    }
    if (argv[index] === '--resume-staged') {
      resumeStaged = true
      continue
    }
    return null
  }
  return target === AUTHORIZED_TARGET && lease.length > 0
    ? { target, lease, resumeVisible, resumeStaged }
    : null
}

function wipe(value) {
  if (value instanceof Uint8Array) {
    value.fill(0)
  }
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds))
}

function run(command, args, timeoutMs = 30000, extraEnv = {}) {
  return new Promise((resolve) => {
    let settled = false
    let stdout = Buffer.alloc(0)
    let stderr = Buffer.alloc(0)
    let child
    const finish = (result) => {
      if (settled) {
        return
      }
      settled = true
      wipe(stdout)
      resolve(result)
    }
    try {
      child = spawn(command, args, {
        stdio: ['ignore', 'pipe', 'pipe'],
        env: { ...process.env, ...extraEnv },
      })
    } catch (_error) {
      finish({ ok: false, output: '' })
      return
    }
    const timeout = setTimeout(() => {
      try {
        child.kill('SIGTERM')
      } catch (_error) {}
      finish({ ok: false, output: '' })
    }, timeoutMs)
    child.stdout.on('data', (chunk) => {
      if (settled) {
        return
      }
      const bytes = Buffer.from(chunk)
      if (stdout.length + bytes.length > MAX_CAPTURE_BYTES) {
        clearTimeout(timeout)
        try {
          child.kill('SIGTERM')
        } catch (_error) {}
        wipe(bytes)
        finish({ ok: false, output: '' })
        return
      }
      stdout = Buffer.concat([stdout, bytes])
      wipe(bytes)
    })
    child.stderr.on('data', (chunk) => {
      if (settled) return
      const bytes = Buffer.from(chunk)
      if (stderr.length + bytes.length <= MAX_CAPTURE_BYTES) {
        stderr = Buffer.concat([stderr, bytes])
      }
      wipe(bytes)
    })
    child.once('error', () => {
      clearTimeout(timeout)
      finish({ ok: false, output: '' })
    })
    child.once('close', (code) => {
      clearTimeout(timeout)
      const output = stdout.toString('utf8')
      const errorOutput = stderr.toString('utf8')
      finish({ ok: code === 0, output, errorOutput })
    })
  })
}

function parseBounds(value) {
  const match = typeof value === 'string'
    ? value.match(/^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/)
    : null
  if (match === null) return null
  const [left, top, right, bottom] = match.slice(1).map(Number)
  return right > left && bottom > top ? { left, top, right, bottom } : null
}

function collectLayoutNodes(root) {
  const nodes = []
  const visit = (node) => {
    if (node === null || typeof node !== 'object') return
    if (node.attributes !== null && typeof node.attributes === 'object') {
      nodes.push(node.attributes)
    }
    if (Array.isArray(node.children)) node.children.forEach(visit)
  }
  visit(root)
  return nodes
}

function classifyCaptchaLayout(root) {
  const nodes = collectLayoutNodes(root).filter((attributes) => attributes.visible !== 'false')
  const text = nodes.map((attributes) => String(
    attributes.text || attributes.originalText || attributes.description || '',
  )).join(' ').toLowerCase()
  if (/失败|过期|expired|error|failed/.test(text)) return { state: 'error' }
  const success = nodes.some((attributes) =>
    String(attributes.type || '').toLowerCase() === 'alert' &&
    /成功|success/i.test(String(attributes.text || attributes.originalText || '')))
  if (success) return { state: 'ready' }
  const checkbox = nodes.find((attributes) =>
    String(attributes.type || '').toLowerCase() === 'checkbox' &&
    /真人|human/i.test(String(attributes.text || attributes.originalText || '')))
  const bounds = parseBounds(checkbox?.bounds || checkbox?.origBounds)
  if (bounds !== null) {
    const x = Math.round(bounds.left + Math.min(38, (bounds.right - bounds.left) / 4))
    const y = Math.round((bounds.top + bounds.bottom) / 2)
    if (x > 0 && x < SCREEN_WIDTH && y > 0 && y < SCREEN_HEIGHT) {
      return { state: 'needs_click', x, y }
    }
  }
  if (/正在|验证中|verifying|checking/.test(text)) return { state: 'verifying' }
  return { state: 'ambiguous' }
}


function protocolAction(name, hdcArgs, options = {}) {
  return {
    name,
    hdcArgs,
    ...(Number.isInteger(options.pauseAfterMs) ? { pauseAfterMs: options.pauseAfterMs } : {}),
    ...(Number.isInteger(options.timeoutSeconds) ? { timeoutSeconds: options.timeoutSeconds } : {}),
  }
}

async function runProtocol(options, artifactDir, name, phases, timeoutMs = 30000) {
  const manifestPath = join(artifactDir, `${name}.json`)
  const protocolArtifactDir = join(artifactDir, `${name}-artifacts`)
  const manifest = {
    schemaVersion: 1,
    name,
    target: options.target,
    authorizedTarget: options.target,
    hdc: HDC,
    artifactDir: protocolArtifactDir,
    display: { widthPx: 1320, heightPx: 2120 },
    context: {
      project: 'NextN',
      codeIdentity: 'external-original-webview-login-coordinator',
      page: name,
      orientation: 'portrait',
      resolution: '1320x2120',
      notes: 'Generated before the atomic login action; contains no credential, Cookie, token or account identity.',
    },
    preflight: phases.preflight || [],
    measurement: {
      actions: Array.isArray(phases.measurement) && phases.measurement.length > 0
        ? phases.measurement
        : [{
          name: 'typed-protocol-boundary-at-noninteractive-corner',
          uiInput: ['click', '1', '1'],
          pauseAfterMs: 100,
          timeoutSeconds: 30,
        }],
    },
    postflight: phases.postflight || [],
  }
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, {
    encoding: 'utf8',
    mode: 0o600,
  })
  const result = await run(DEVICE_PROTOCOL_SCRIPT, [
    '--device', options.target,
    '--lease', options.lease,
    manifestPath,
  ], timeoutMs)
  let metadata = null
  if (result.ok) {
    try {
      metadata = JSON.parse(await readFile(join(protocolArtifactDir, 'run-metadata.json'), 'utf8'))
    } catch (_error) {}
  }
  return { ok: result.ok && metadata !== null, artifactDir: protocolArtifactDir, metadata }
}

function protocolStdout(metadata, name) {
  if (!Array.isArray(metadata?.commands)) {
    return ''
  }
  const record = metadata.commands.find((candidate) =>
    typeof candidate?.name === 'string' && candidate.name === `${name}#1`)
  return typeof record?.stdout === 'string' ? record.stdout : ''
}

function reserveLocalPort() {
  return new Promise((resolve) => {
    const server = createServer()
    server.once('error', () => resolve(0))
    server.listen(0, '127.0.0.1', () => {
      const address = server.address()
      const port = typeof address === 'object' && address !== null ? address.port : 0
      server.close(() => resolve(port))
    })
  })
}

async function routeVisibleLogin(options, artifactDir) {
  for (let index = 0; index < VISIBLE_LOGIN_ROUTE_ATTEMPTS; index += 1) {
    const suffix = String(index).padStart(2, '0')
    const remoteLayout = `/data/local/tmp/nextn-login-cycle-route-${suffix}.json`
    const localLayout = join(artifactDir, `route-layout-${suffix}.json`)
    const preflight = index === 0 && !options.resumeVisible ? [
      protocolAction('open-original-visible-login', [
        'shell', 'aa', 'start', '-b', BUNDLE, '-a', 'EntryAbility',
        '--ps', 'nextn_login_recovery', '1',
      ], { pauseAfterMs: 500 }),
    ] : []
    const result = await runProtocol(options, artifactDir, `route-visible-login-${suffix}`, {
      preflight,
      postflight: [
        protocolAction(`dump-visible-login-route-${suffix}`, [
          'shell', 'uitest', 'dumpLayout', '-p', remoteLayout, '-a',
        ]),
        protocolAction(`receive-visible-login-route-${suffix}`, [
          'file', 'recv', remoteLayout, localLayout,
        ]),
        protocolAction(`remove-visible-login-route-${suffix}`, ['shell', 'rm', remoteLayout]),
      ],
    }, 15000)
    let text = ''
    try {
      if (result.ok) {
        text = await readFile(localLayout, 'utf8')
        if (text.includes(`"bundleName":"${BUNDLE}"`) &&
          /"type":"Web(?:Component)?"/.test(text)) {
          return 'web'
        }
        if (text.includes('nextn-account-list-root') &&
          text.includes('nextn-account-saved-row')) {
          return 'native_authenticated'
        }
      }
    } catch (_error) {
    } finally {
      text = ''
      await rm(localLayout, { force: true })
    }
    if (index + 1 < VISIBLE_LOGIN_ROUTE_ATTEMPTS) {
      await wait(VISIBLE_LOGIN_ROUTE_POLL_MS)
    }
  }
  return 'unavailable'
}

function liveDevtoolsSocket(unixOutput, processId) {
  if (!/^\d+$/.test(processId)) {
    return ''
  }
  const expected = `webview_devtools_remote_${processId}`
  const matches = [...unixOutput.matchAll(/@?(webview_devtools_remote_(\d+))/g)]
    .map((match) => match[1])
    .filter((value) => value === expected)
  return matches.length === 1 ? expected : ''
}

async function createForward(options, artifactDir) {
  const discovery = await runProtocol(options, artifactDir, 'discover-current-webview', {
    postflight: [
      protocolAction('read-nextn-process', ['shell', 'pidof', BUNDLE]),
      protocolAction('read-live-webview-sockets', ['shell', 'cat', '/proc/net/unix']),
      protocolAction('read-existing-forwards', ['fport', 'ls']),
    ],
  }, 15000)
  if (!discovery.ok) {
    return null
  }
  const processId = protocolStdout(discovery.metadata, 'read-nextn-process').trim()
  const remoteSocket = liveDevtoolsSocket(
    protocolStdout(discovery.metadata, 'read-live-webview-sockets'),
    processId,
  )
  const localPort = await reserveLocalPort()
  if (!Number.isInteger(localPort) || localPort <= 0) {
    return null
  }
  const existing = protocolStdout(discovery.metadata, 'read-existing-forwards')
  if (existing.includes(`tcp:${localPort}`)) {
    return null
  }
  const remoteEndpoint = remoteSocket.length > 0
    ? `localabstract:${remoteSocket}`
    : `tcp:${DEBUG_WEB_DEVTOOLS_PORT}`
  const created = await runProtocol(options, artifactDir, 'create-current-webview-forward', {
    postflight: [
      protocolAction('create-current-webview-forward', [
        'fport', `tcp:${localPort}`, remoteEndpoint,
      ]),
      protocolAction('confirm-current-webview-forward', ['fport', 'ls']),
    ],
  }, 15000)
  const table = created.ok
    ? protocolStdout(created.metadata, 'confirm-current-webview-forward')
    : ''
  if (!created.ok || !table.includes(`tcp:${localPort}`) ||
    !table.includes(remoteEndpoint)) {
    return null
  }
  return { localPort, remoteEndpoint }
}

async function cleanupForward(options, artifactDir, forward) {
  if (forward === null) {
    return
  }
  await runProtocol(options, artifactDir, 'cleanup-current-webview-forward', {
    postflight: [
      protocolAction('remove-current-webview-forward', [
        'fport', 'rm', `tcp:${forward.localPort}`, forward.remoteEndpoint,
      ]),
      protocolAction('confirm-current-webview-forward-removed', ['fport', 'ls']),
    ],
  }, 15000)
}

function isStagedLoginForm(probe) {
  return probe?.ok === true && probe.loginFormPresent === true &&
    probe.accountFieldFilled === true && probe.passwordFieldFilled === true &&
    probe.passwordFieldMasked === true && probe.errorMarkerPresent === false
}

async function readCaptchaLayout(options, artifactDir) {
  const remoteLayout = '/data/local/tmp/nextn-login-cycle-post-fields.json'
  const localLayout = join(artifactDir, 'post-fields.json')
  const result = await runProtocol(options, artifactDir, 'read-captcha-layout', {
    postflight: [
      protocolAction('dump-post-fields-layout', [
        'shell', 'uitest', 'dumpLayout', '-p', remoteLayout, '-a',
      ]),
      protocolAction('receive-post-fields-layout', [
        'file', 'recv', remoteLayout, localLayout,
      ]),
      protocolAction('remove-post-fields-layout', ['shell', 'rm', remoteLayout]),
    ],
  }, 20000)
  if (!result.ok) return { state: 'layout_unavailable' }
  try {
    return classifyCaptchaLayout(JSON.parse(await readFile(localLayout, 'utf8')))
  } catch (_error) {
    return { state: 'layout_unavailable' }
  }
}

async function activateVisibleCaptcha(options, artifactDir, x, y) {
  if (!Number.isInteger(x) || !Number.isInteger(y) || x <= 0 || y <= 0 ||
    x >= SCREEN_WIDTH || y >= SCREEN_HEIGHT) {
    return false
  }
  const result = await runProtocol(options, artifactDir, 'activate-visible-captcha', {
    measurement: [{
      name: 'activate-visible-cloudflare-checkbox',
      uiInput: ['click', String(x), String(y)],
      pauseAfterMs: 10,
      timeoutSeconds: 30,
    }],
  }, 15000)
  return result.ok
}

/** Runs only after both credential writes and returns only with a live token. */
async function waitForPostCredentialCfGate(port, deadlineAt) {
  let challengeResponseObserved = false
  while (Date.now() < deadlineAt) {
    const remainingMs = Math.max(500, Math.min(5000, deadlineAt - Date.now()))
    const probe = await runProbe({ port, timeoutMs: remainingMs })
    if (probe?.ok === true && isStagedLoginForm(probe) &&
      probe.challengeResponsePresent === true) {
      challengeResponseObserved = true
    }
    if (probe?.ok === true && isStagedLoginForm(probe) &&
      challengeResponseObserved &&
      probe.challengeResponseReady === true) {
      return { ok: true, readyAt: Date.now() }
    }
    if (Date.now() < deadlineAt) {
      await wait(Math.min(CF_GATE_POLL_MS, deadlineAt - Date.now()))
    }
  }
  return challengeResponseObserved
    ? { ok: false, code: 'captcha_token_not_ready' }
    : { ok: false, code: 'captcha_response_not_observed' }
}

async function waitForLoginWebExit(port, deadlineAt) {
  while (Date.now() < deadlineAt) {
    const timeoutMs = Math.max(500, Math.min(1500, deadlineAt - Date.now()))
    const probe = await runProbe({ port, timeoutMs })
    if (probe?.ok !== true || probe.loginFormPresent !== true) {
      return true
    }
    if (Date.now() < deadlineAt) {
      await wait(Math.min(PROMOTION_WEB_EXIT_POLL_MS, deadlineAt - Date.now()))
    }
  }
  return false
}

async function observeNativePromotion(options, artifactDir, port, deadlineAt) {
  if (!await waitForLoginWebExit(port, deadlineAt)) {
    return false
  }
  for (let index = 0; index < PROMOTION_LAYOUT_ATTEMPTS && Date.now() < deadlineAt; index += 1) {
    const suffix = String(index).padStart(2, '0')
    const remoteLayout = `/data/local/tmp/nextn-login-cycle-promotion-${suffix}.json`
    const localLayout = join(artifactDir, `promotion-${suffix}.json`)
    const result = await runProtocol(options, artifactDir, `observe-native-promotion-${suffix}`, {
      postflight: [
        protocolAction(`dump-native-promotion-${suffix}`, [
          'shell', 'uitest', 'dumpLayout', '-p', remoteLayout, '-a',
        ]),
        protocolAction(`receive-native-promotion-${suffix}`, [
          'file', 'recv', remoteLayout, localLayout,
        ]),
        protocolAction(`remove-native-promotion-${suffix}`, [
          'shell', 'rm', remoteLayout,
        ]),
      ],
    }, Math.max(5000, Math.min(15000, deadlineAt - Date.now())))
    let text = ''
    try {
      if (!result.ok) {
        continue
      }
      text = await readFile(localLayout, 'utf8')
      const accountList = text.includes('nextn-account-list-root')
      const savedAccount = text.includes('nextn-account-saved-row')
      const visibleWeb = /"type"\s*:\s*"Web(?:Component)?"/.test(text)
      if (accountList && savedAccount && !visibleWeb) {
        return true
      }
    } catch (_error) {
    } finally {
      text = ''
      await rm(localLayout, { force: true })
    }
    if (Date.now() < deadlineAt) {
      await wait(Math.min(PROMOTION_LAYOUT_SETTLE_MS, deadlineAt - Date.now()))
    }
  }
  return false
}

async function runCycle(options) {
  let accountSecret = null
  let passwordSecret = null
  let forward = null
  const outputRoot = join(ROOT, '.hvigor', 'outputs')
  await mkdir(outputRoot, { recursive: true })
  const artifactDir = await mkdtemp(join(outputRoot, 'nextn-login-cycle-'))
  let flowStartedAt = 0
  try {
    // Credential retrieval is preparation. A staged resume never reads or
    // writes credentials; it takes over the already-filled visible form.
    if (!options.resumeStaged) {
      const accountResult = await invokeKeychainHandle('account', { reveal: true })
      if (accountResult?.ok !== true || !(accountResult.secretBytes instanceof Uint8Array)) {
        return safeResult(false, 'preparation', 'account_handle_unavailable')
      }
      accountSecret = accountResult.secretBytes
      const passwordResult = await invokeKeychainHandle('password', { reveal: true })
      if (passwordResult?.ok !== true || !(passwordResult.secretBytes instanceof Uint8Array)) {
        return safeResult(false, 'preparation', 'password_handle_unavailable')
      }
      passwordSecret = passwordResult.secretBytes
    }

    flowStartedAt = Date.now()
    const flowDeadlineAt = flowStartedAt + LOGIN_FLOW_CEILING_MS
    if (!options.resumeStaged) {
      const routeState = await routeVisibleLogin(options, artifactDir)
      if (routeState === 'native_authenticated') {
        return safeResult(true, 'native_promotion', '', {
          routeState,
          elapsedMs: Date.now() - flowStartedAt,
        })
      }
      if (routeState !== 'web') {
        return safeResult(false, 'route', 'visible_login_unavailable')
      }
    }
    forward = await createForward(options, artifactDir)
    if (forward === null) {
      return safeResult(false, 'forward', 'devtools_unavailable')
    }
    const staged = options.resumeStaged
      ? await runProbe({ port: forward.localPort, timeoutMs: 5000 })
      : await runStagedLoginEpoch({
        port: forward.localPort,
        timeoutMs: 5000,
        accountSecretBytes: accountSecret,
        passwordSecretBytes: passwordSecret,
      })
    accountSecret = null
    passwordSecret = null
    const stagedReady = options.resumeStaged
      ? isStagedLoginForm(staged)
      : staged?.ok === true && staged.accountEntered === true &&
        staged.passwordEntered === true && staged.submitIssued === false
    if (!stagedReady) {
      return safeResult(false, 's2_s3', 'credential_epoch_failed')
    }
    const blurred = await runDriver({
      port: forward.localPort,
      action: 'blur-active',
      timeoutMs: 5000,
    })
    if (blurred?.ok !== true || blurred.accountFieldFocused === true ||
      blurred.passwordFieldFocused === true) {
      return safeResult(false, 's3_5', 'editor_exit_failed')
    }
    const postBlurProbe = await runProbe({ port: forward.localPort, timeoutMs: 5000 })
    if (!isStagedLoginForm(postBlurProbe) || postBlurProbe.accountFieldFocused === true ||
      postBlurProbe.passwordFieldFocused === true) {
      return safeResult(false, 's3_5', 'editor_exit_not_proven')
    }
    const captcha = await readCaptchaLayout(options, artifactDir)
    if (captcha.state === 'error' || captcha.state === 'ambiguous' ||
      captcha.state === 'layout_unavailable') {
      return safeResult(false, 's3_5', `captcha_${captcha.state}`)
    }
    if (captcha.state === 'needs_click' &&
      !await activateVisibleCaptcha(options, artifactDir, captcha.x, captcha.y)) {
      return safeResult(false, 's3_5', 'captcha_action_failed')
    }
    const gate = await waitForPostCredentialCfGate(forward.localPort, flowDeadlineAt)
    if (gate.ok !== true) {
      return safeResult(false, 's3_5', gate.code || 'cf_gate_failed', {
        captchaState: captcha.state,
      })
    }
    const cfReadyToSubmitMs = Date.now() - gate.readyAt
    if (cfReadyToSubmitMs > CF_READY_TO_SUBMIT_CEILING_MS) {
      return safeResult(false, 's4', 'cf_ready_to_submit_deadline_exceeded', { cfReadyToSubmitMs })
    }
    const submitted = await runCfReviewedSubmit({ port: forward.localPort, timeoutMs: 5000 })
    if (submitted?.ok !== true || submitted.submitIssued !== true) {
      return safeResult(false, 's4', 'submit_failed', { cfReadyToSubmitMs })
    }
    const promoted = Date.now() < flowDeadlineAt &&
      await observeNativePromotion(options, artifactDir, forward.localPort, flowDeadlineAt)
    const elapsedMs = Date.now() - flowStartedAt
    if (!promoted) {
      const cookieShape = await runCookieShape({ port: forward.localPort })
      const webAuthenticated = cookieShape?.ok === true &&
        cookieShape.renewableAuthPresent === true
      return safeResult(false, 's5', webAuthenticated
        ? 'web_authenticated_native_promotion_failed'
        : 'promotion_failed', {
        webAuthenticated,
        cfReadyToSubmitMs,
        elapsedMs,
      })
    }
    if (elapsedMs > LOGIN_FLOW_CEILING_MS) {
      return safeResult(false, 's5', 'promotion_deadline_exceeded', { cfReadyToSubmitMs, elapsedMs })
    }
    return safeResult(true, 'native_promotion', '', {
      captchaState: captcha.state,
      cfReadyToSubmitMs,
      elapsedMs,
    })
  } finally {
    wipe(accountSecret)
    wipe(passwordSecret)
    await cleanupForward(options, artifactDir, forward)
    await rm(artifactDir, { recursive: true, force: true })
  }
}

async function main() {
  if (process.argv.length === 4 && process.argv[2] === '--cf-layout') {
    try {
      const captcha = classifyCaptchaLayout(JSON.parse(await readFile(process.argv[3], 'utf8')))
      process.stdout.write(`${JSON.stringify(safeResult(
        captcha.state !== 'layout_unavailable' && captcha.state !== 'ambiguous',
        'cf_layout',
        captcha.state === 'layout_unavailable' || captcha.state === 'ambiguous'
          ? `captcha_${captcha.state}` : '',
        { captchaState: captcha.state, clickPointAvailable: captcha.state === 'needs_click' },
      ))}\n`)
      return captcha.state === 'layout_unavailable' || captcha.state === 'ambiguous' ? 2 : 0
    } catch (_error) {
      process.stdout.write(`${JSON.stringify(safeResult(false, 'cf_layout', 'layout_unavailable'))}\n`)
      return 2
    }
  }
  const options = parseArguments(process.argv)
  if (options === null) {
    process.stdout.write(`${JSON.stringify(safeResult(false, 'arguments', 'invalid_arguments'))}\n`)
    return 2
  }
  let result
  try {
    result = await runCycle(options)
  } catch (_error) {
    result = safeResult(false, 'cycle', 'unexpected_failure')
  }
  process.stdout.write(`${JSON.stringify(result)}\n`)
  return result.ok ? 0 : 2
}

main().then((code) => {
  process.exitCode = code
})
