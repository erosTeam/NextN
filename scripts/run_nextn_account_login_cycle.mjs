#!/usr/bin/env node

/**
 * One-process NextN login acceptance cycle.
 *
 * All local preparation, including credential retrieval, happens before the
 * visible login WebView is opened. After that point this process owns the
 * uninterrupted route -> CF gate -> fill -> submit -> native-promotion queue.
 * A pending CF widget terminates before either field is focused or written;
 * the preserved page can be resumed after the challenge is completed.
 */

import { spawn } from 'node:child_process'
import { mkdtemp, readFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import {
  invokeKeychainHandle,
  runCfReviewedSubmit,
  runStagedLoginEpoch,
} from './run_arkweb_login_keychain_epoch.mjs'
import { runProbe } from './probe_arkweb_login_state.mjs'

const ROOT = dirname(dirname(fileURLToPath(import.meta.url)))
const LEASE_SCRIPT = join(ROOT, 'scripts', 'device-lease')
const ROUTE_SCRIPT = join(ROOT, 'scripts', 'collect_nextn_account_s0.mjs')
const HDC = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
const DEVTOOLS_HELPER =
  '/Users/honjow/.codex/skills/harmony-next/scripts/device_evidence_bundle.py'
const DEVECO_APP = '/Applications/DevEco-Studio.app'
const BUNDLE = 'com.erosteam.nextn'
const AUTHORIZED_TARGETS = new Set([
  '192.168.50.200:12345',
  '192.168.50.197:12345',
  '192.168.50.237:12345',
  '56T0225315001128',
])
const MAX_CAPTURE_BYTES = 1024 * 1024
const CF_DISCOVERY_SETTLE_MS = 3000
const CF_GATE_POLL_MS = 250
const CF_READY_TO_FILL_CEILING_MS = 5000
const LOGIN_FLOW_CEILING_MS = 60000
const PROMOTION_POLL_MS = 500
const PROMOTION_POLLS = 40

function safeResult(ok, stage, code = '', extra = {}) {
  return { ok, stage, ...(code.length > 0 ? { code } : {}), ...extra }
}

function parseArguments(argv) {
  let target = ''
  let lease = ''
  let resumeVisible = false
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
    return null
  }
  return AUTHORIZED_TARGETS.has(target) && lease.length > 0
    ? { target, lease, resumeVisible }
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

function run(command, args, timeoutMs = 30000) {
  return new Promise((resolve) => {
    let settled = false
    let stdout = Buffer.alloc(0)
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
      child = spawn(command, args, { stdio: ['ignore', 'pipe', 'ignore'] })
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
    child.once('error', () => {
      clearTimeout(timeout)
      finish({ ok: false, output: '' })
    })
    child.once('close', (code) => {
      clearTimeout(timeout)
      const output = stdout.toString('utf8')
      finish({ ok: code === 0, output })
    })
  })
}

function leaseRun(target, lease, command, timeoutMs = 30000) {
  return run(LEASE_SCRIPT, [
    '--device', target,
    'run',
    '--lease', lease,
    '--wait', '30',
    '--',
    ...command,
  ], timeoutMs)
}

function hdcRun(target, lease, args, timeoutMs = 30000) {
  return leaseRun(target, lease, [HDC, '-t', target, ...args], timeoutMs)
}

function parseJson(output) {
  try {
    return JSON.parse(output.trim())
  } catch (_error) {
    const start = output.indexOf('{')
    const end = output.lastIndexOf('}')
    if (start < 0 || end <= start) {
      return null
    }
    try {
      return JSON.parse(output.slice(start, end + 1))
    } catch (_nestedError) {
      return null
    }
  }
}

async function routeVisibleLogin(target, lease) {
  const result = await run(process.execPath, [
    ROUTE_SCRIPT,
    '--target', target,
    '--lease', lease,
    '--route-login',
  ], 30000)
  const payload = parseJson(result.output)
  return result.ok && payload?.ok === true && payload?.visibleLoginWeb === true
}

async function createForward(target, lease, artifactDir) {
  const result = await leaseRun(target, lease, [
    'python3', DEVTOOLS_HELPER,
    'webview-devtools',
    '--deveco-app', DEVECO_APP,
    '--target', target,
    '--artifact-dir', artifactDir,
    '--keep-forward',
    '--json',
  ], 15000)
  const payload = parseJson(result.output)
  const localPort = payload?.localPort
  const remoteSocket = payload?.remoteSocket
  if (!result.ok || !Number.isInteger(localPort) || localPort <= 0 ||
    typeof remoteSocket !== 'string' || remoteSocket.length === 0) {
    return null
  }
  return { localPort, remoteSocket }
}

async function cleanupForward(target, lease, forward) {
  if (forward === null) {
    return
  }
  const remoteEndpoint = forward.remoteSocket.startsWith('localabstract:')
    ? forward.remoteSocket
    : `localabstract:${forward.remoteSocket}`
  await hdcRun(target, lease, [
    'fport', 'rm', `tcp:${forward.localPort}`, remoteEndpoint,
  ], 5000)
}

async function forceStop(target, lease) {
  await hdcRun(target, lease, ['shell', 'aa', 'force-stop', BUNDLE], 5000)
}

function isFreshLoginForm(probe) {
  return probe?.ok === true && probe.loginFormPresent === true &&
    probe.accountFieldFilled === false && probe.passwordFieldFilled === false &&
    probe.passwordFieldMasked === true && probe.errorMarkerPresent === false
}

/** No credential control is focused or written until this gate succeeds. */
async function waitForPreCredentialCfGate(port, deadlineAt) {
  let freshWithoutWidgetSince = 0
  while (Date.now() < deadlineAt) {
    const remainingMs = Math.max(500, Math.min(5000, deadlineAt - Date.now()))
    const probe = await runProbe({ port, timeoutMs: remainingMs })
    if (probe?.ok !== true) {
      freshWithoutWidgetSince = 0
    } else if (probe.challengeFramePresent === true) {
      return { ok: false, code: 'cf_intervention_required' }
    } else if (isFreshLoginForm(probe) && probe.challengeResponseReady === true) {
      return { ok: true, readyAt: Date.now() }
    } else if (isFreshLoginForm(probe) && probe.challengeWidgetPresent === false) {
      if (freshWithoutWidgetSince === 0) {
        freshWithoutWidgetSince = Date.now()
      }
      if (Date.now() - freshWithoutWidgetSince >= CF_DISCOVERY_SETTLE_MS) {
        return { ok: true, readyAt: Date.now() }
      }
    } else {
      freshWithoutWidgetSince = 0
    }
    if (Date.now() < deadlineAt) {
      await wait(Math.min(CF_GATE_POLL_MS, deadlineAt - Date.now()))
    }
  }
  return { ok: false, code: 'cf_gate_timeout' }
}

async function observeNativePromotion(target, lease, tempDirectory, deadlineAt) {
  const remoteLayout = '/data/local/tmp/nextn-login-cycle-promotion.json'
  const localLayout = join(tempDirectory, 'promotion.json')
  try {
    for (let index = 0; index < PROMOTION_POLLS && Date.now() < deadlineAt; index += 1) {
      const dumpTimeoutMs = Math.max(500, Math.min(5000, deadlineAt - Date.now()))
      const dump = await hdcRun(target, lease, [
        'shell', 'uitest', 'dumpLayout', '-p', remoteLayout,
      ], dumpTimeoutMs)
      if (dump.ok) {
        if (Date.now() >= deadlineAt) {
          return false
        }
        const receiveTimeoutMs = Math.max(500, Math.min(5000, deadlineAt - Date.now()))
        const receive = await hdcRun(target, lease, [
          'file', 'recv', remoteLayout, localLayout,
        ], receiveTimeoutMs)
        if (receive.ok) {
          let text = ''
          try {
            text = await readFile(localLayout, 'utf8')
          } catch (_error) {}
          const nativeAccount = text.includes('nextn-account-native-root')
          const accountList = text.includes('nextn-account-list-root')
          const savedAccount = text.includes('nextn-account-saved-row')
          const visibleWeb = /"type"\s*:\s*"Web(?:Component)?"/.test(text)
          text = ''
          await rm(localLayout, { force: true })
          if ((nativeAccount || accountList) && savedAccount && !visibleWeb) {
            return true
          }
        }
      }
      if (Date.now() < deadlineAt) {
        await wait(Math.min(PROMOTION_POLL_MS, deadlineAt - Date.now()))
      }
    }
    return false
  } finally {
    await hdcRun(target, lease, ['shell', 'rm', '-f', remoteLayout], 5000)
    await rm(localLayout, { force: true })
  }
}

async function runCycle(options) {
  let accountSecret = null
  let passwordSecret = null
  let forward = null
  const artifactDir = await mkdtemp(join(tmpdir(), 'nextn-login-cycle-'))
  let flowStartedAt = 0
  try {
    // Credential retrieval is preparation. The WebView is still closed.
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

    flowStartedAt = Date.now()
    const flowDeadlineAt = flowStartedAt + LOGIN_FLOW_CEILING_MS
    if (!options.resumeVisible && !await routeVisibleLogin(options.target, options.lease)) {
      return safeResult(false, 'route', 'visible_login_unavailable')
    }
    forward = await createForward(options.target, options.lease, artifactDir)
    if (forward === null) {
      return safeResult(false, 'forward', 'devtools_unavailable')
    }
    const gate = await waitForPreCredentialCfGate(forward.localPort, flowDeadlineAt)
    if (gate.ok !== true && gate.code === 'cf_intervention_required') {
      return safeResult(false, 'cf', 'cf_intervention_required')
    }
    if (gate.ok !== true) {
      return safeResult(false, 'cf', gate.code || 'cf_gate_failed')
    }
    const cfReadyToFillMs = Date.now() - gate.readyAt
    if (cfReadyToFillMs > CF_READY_TO_FILL_CEILING_MS) {
      return safeResult(false, 's1', 'cf_ready_to_fill_deadline_exceeded', { cfReadyToFillMs })
    }
    const staged = await runStagedLoginEpoch({
      port: forward.localPort,
      timeoutMs: 5000,
      accountSecretBytes: accountSecret,
      passwordSecretBytes: passwordSecret,
    })
    accountSecret = null
    passwordSecret = null
    if (staged?.code === 'challenge_present') {
      return safeResult(false, 'cf', 'cf_intervention_required', { cfReadyToFillMs })
    }
    if (staged?.ok !== true || staged.accountEntered !== true ||
      staged.passwordEntered !== true || staged.submitIssued !== false) {
      return safeResult(false, 's2_s3', 'credential_epoch_failed', { cfReadyToFillMs })
    }
    const submitted = await runCfReviewedSubmit({ port: forward.localPort, timeoutMs: 5000 })
    if (submitted?.ok !== true || submitted.submitIssued !== true) {
      return safeResult(false, 's4', 'submit_failed', { cfReadyToFillMs })
    }
    const promoted = Date.now() < flowDeadlineAt &&
      await observeNativePromotion(options.target, options.lease, artifactDir, flowDeadlineAt)
    const elapsedMs = Date.now() - flowStartedAt
    if (!promoted) {
      return safeResult(false, 's5', 'promotion_failed', { cfReadyToFillMs, elapsedMs })
    }
    if (elapsedMs > LOGIN_FLOW_CEILING_MS) {
      return safeResult(false, 's5', 'promotion_deadline_exceeded', { cfReadyToFillMs, elapsedMs })
    }
    return safeResult(true, 'native_promotion', '', { cfReadyToFillMs, elapsedMs })
  } finally {
    wipe(accountSecret)
    wipe(passwordSecret)
    await cleanupForward(options.target, options.lease, forward)
    await rm(artifactDir, { recursive: true, force: true })
  }
}

async function main() {
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
  if (!result.ok && result.code !== 'cf_intervention_required') {
    await forceStop(options.target, options.lease)
  }
  process.stdout.write(`${JSON.stringify(result)}\n`)
  return result.ok ? 0 : 2
}

main().then((code) => {
  process.exitCode = code
})
