#!/usr/bin/env node

import { spawn } from 'node:child_process'
import { pathToFileURL } from 'node:url'

import { runDriver, runSecretFieldFill } from './drive_arkweb_login_field.mjs'
import { runProbe } from './probe_arkweb_login_state.mjs'

// This is a host-only, fixed Keychain handle contract. The labels identify
// automation slots, not the user account. They are deliberately closed: the
// CLI never accepts a service name, Keychain account label, file path, secret,
// FD, environment variable, or arbitrary command.
export const KEYCHAIN_SECURITY_TOOL = '/usr/bin/security'
export const NEXTN_KEYCHAIN_SERVICE_LABEL = 'com.erosteam.nextn.acceptance.login.v1'
export const NEXTN_KEYCHAIN_HANDLE_SLOTS = Object.freeze({
  account: Object.freeze({ service: NEXTN_KEYCHAIN_SERVICE_LABEL, account: 'account' }),
  password: Object.freeze({ service: NEXTN_KEYCHAIN_SERVICE_LABEL, account: 'password' }),
})

const DEFAULT_TIMEOUT_MS = 4000
const MIN_TIMEOUT_MS = 500
const MAX_TIMEOUT_MS = 15000
const KEYCHAIN_TIMEOUT_MS = 4000
const MAX_KEYCHAIN_SECRET_BYTES = 4096

export const SAFE_KEYCHAIN_PRESENCE_OUTPUT_KEYS = [
  'ok',
  'stage',
  'accountHandleAvailable',
  'passwordHandleAvailable',
]

export const SAFE_EPOCH_OUTPUT_KEYS = [
  'ok',
  'stage',
  'accountEntered',
  'passwordEntered',
  'submitIssued',
]

export const SAFE_EPOCH_FAILURE_CODES = [
  'invalid_arguments',
  'login_probe_unavailable',
  'login_form_not_ready',
  'account_focus_not_current',
  'field_not_empty',
  'captcha_token_not_ready',
  'keychain_handle_unavailable',
  'keychain_security_unavailable',
  'keychain_lookup_timeout',
  'keychain_secret_invalid',
  'account_input_not_confirmed',
  'account_fill_not_verified',
  'password_focus_not_confirmed',
  'password_input_not_confirmed',
  'password_fill_not_verified',
  'submit_not_eligible',
  'submit_outcome_inconclusive',
]

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}

function parsePort(value) {
  if (!/^\d+$/.test(value)) {
    return null
  }
  const port = Number(value)
  return Number.isInteger(port) && port >= 1 && port <= 65535 ? port : null
}

function parseTimeout(value) {
  if (!/^\d+$/.test(value)) {
    return null
  }
  const timeoutMs = Number(value)
  return Number.isInteger(timeoutMs) && timeoutMs >= MIN_TIMEOUT_MS && timeoutMs <= MAX_TIMEOUT_MS
    ? timeoutMs
    : null
}

function handleForSlot(slot) {
  return Object.prototype.hasOwnProperty.call(NEXTN_KEYCHAIN_HANDLE_SLOTS, slot)
    ? NEXTN_KEYCHAIN_HANDLE_SLOTS[slot]
    : null
}

/**
 * Builds only a fixed, non-secret Keychain lookup argv. The no-reveal form is
 * the presence diagnostic; the reveal form is used only inside the in-process
 * epoch and directs stdout to a private pipe, never inherited terminal output.
 */
export function keychainCommandForHandle(slot, reveal = false) {
  const handle = handleForSlot(slot)
  if (handle === null || typeof reveal !== 'boolean') {
    return null
  }
  return {
    file: KEYCHAIN_SECURITY_TOOL,
    args: [
      'find-generic-password',
      '-s', handle.service,
      '-a', handle.account,
      ...(reveal ? ['-w'] : []),
    ],
  }
}

function wipeBuffers(buffers) {
  for (const value of buffers) {
    if (value instanceof Uint8Array) {
      value.fill(0)
    }
  }
}

function normalizeKeychainSecret(raw) {
  if (!(raw instanceof Uint8Array) || raw.length === 0 || raw.length > MAX_KEYCHAIN_SECRET_BYTES) {
    wipeBuffers([raw])
    return null
  }
  let end = raw.length
  // `security -w` may add a terminal line delimiter. Provisioned values must
  // not themselves end in CR/LF, so stripping exactly one terminal delimiter
  // never silently changes a valid contracted value.
  if (raw[end - 1] === 0x0a) {
    end -= 1
  }
  if (end > 0 && raw[end - 1] === 0x0d) {
    end -= 1
  }
  const normalized = Buffer.from(raw.subarray(0, end))
  wipeBuffers([raw])
  if (normalized.length === 0 || normalized.length > MAX_KEYCHAIN_SECRET_BYTES || normalized.includes(0x00) ||
    normalized[normalized.length - 1] === 0x0a || normalized[normalized.length - 1] === 0x0d) {
    wipeBuffers([normalized])
    return null
  }
  return normalized
}

/**
 * Invokes the exact `/usr/bin/security` command with non-secret argv. In
 * presence mode all child stdio is ignored. In reveal mode only stdout is a
 * private pipe; it is bounded, never decoded here, never logged, and cleared
 * on every return path.
 */
export function invokeKeychainHandle(slot, {
  reveal = false,
  timeoutMs = KEYCHAIN_TIMEOUT_MS,
  spawnImpl = spawn,
} = {}) {
  const command = keychainCommandForHandle(slot, reveal)
  if (command === null || !Number.isInteger(timeoutMs) || timeoutMs < MIN_TIMEOUT_MS || timeoutMs > MAX_TIMEOUT_MS ||
    typeof spawnImpl !== 'function') {
    return Promise.resolve({ ok: false, code: 'security_unavailable' })
  }
  return new Promise((resolve) => {
    let settled = false
    let child
    let timeoutId = null
    const chunks = []
    let byteLength = 0
    const finish = (result) => {
      if (settled) {
        return
      }
      settled = true
      if (timeoutId !== null) {
        clearTimeout(timeoutId)
      }
      wipeBuffers(chunks)
      resolve(result)
    }
    try {
      child = spawnImpl(command.file, command.args, {
        stdio: reveal ? ['ignore', 'pipe', 'ignore'] : ['ignore', 'ignore', 'ignore'],
        windowsHide: true,
      })
    } catch (_error) {
      finish({ ok: false, code: 'security_unavailable' })
      return
    }
    if (!isObject(child) || typeof child.once !== 'function' ||
      (reveal && (!isObject(child.stdout) || typeof child.stdout.on !== 'function'))) {
      finish({ ok: false, code: 'security_unavailable' })
      return
    }
    if (reveal) {
      child.stdout.on('data', (chunk) => {
        if (settled) {
          return
        }
        const bytes = Buffer.from(chunk)
        if (chunk instanceof Uint8Array) {
          chunk.fill(0)
        }
        byteLength += bytes.length
        if (byteLength > MAX_KEYCHAIN_SECRET_BYTES + 2) {
          wipeBuffers([bytes])
          try {
            child.kill('SIGTERM')
          } catch (_error) {
            // The fixed timeout/oversize result below is sufficient.
          }
          finish({ ok: false, code: 'secret_invalid' })
          return
        }
        chunks.push(bytes)
      })
    }
    child.once('error', () => finish({ ok: false, code: 'security_unavailable' }))
    child.once('close', (code) => {
      if (settled) {
        return
      }
      if (code !== 0) {
        finish({ ok: false, code: 'handle_unavailable' })
        return
      }
      if (!reveal) {
        finish({ ok: true })
        return
      }
      const raw = Buffer.concat(chunks)
      // `finish` clears chunks, while this independent concat copy transfers
      // ownership to the caller only if it passes the bounded normalizer.
      const secretBytes = normalizeKeychainSecret(raw)
      if (secretBytes === null) {
        finish({ ok: false, code: 'secret_invalid' })
        return
      }
      finish({ ok: true, secretBytes })
    })
    timeoutId = setTimeout(() => {
      try {
        child.kill('SIGTERM')
      } catch (_error) {
        // A timeout remains a timeout even if the child already exited.
      }
      finish({ ok: false, code: 'lookup_timeout' })
    }, timeoutMs)
  })
}

function presenceResult(accountResult, passwordResult) {
  const results = [accountResult, passwordResult]
  if (results.some((result) => result?.code === 'security_unavailable')) {
    return { ok: false, stage: 'keychain_presence', code: 'security_unavailable' }
  }
  if (results.some((result) => result?.code === 'lookup_timeout')) {
    return { ok: false, stage: 'keychain_presence', code: 'lookup_timeout' }
  }
  return {
    ok: true,
    stage: 'keychain_presence',
    accountHandleAvailable: accountResult?.ok === true,
    passwordHandleAvailable: passwordResult?.ok === true,
  }
}

/**
 * Presence-only check: it never requests `-w`, never reads child stdout or
 * stderr, and returns fixed booleans only. Do not run it until the external
 * Keychain provisioning precondition is intended to be checked.
 */
export async function runKeychainPresenceDiagnostic({
  timeoutMs = KEYCHAIN_TIMEOUT_MS,
  invoke = invokeKeychainHandle,
} = {}) {
  if (!Number.isInteger(timeoutMs) || timeoutMs < MIN_TIMEOUT_MS || timeoutMs > MAX_TIMEOUT_MS ||
    typeof invoke !== 'function') {
    return { ok: false, stage: 'keychain_presence', code: 'invalid_arguments' }
  }
  const [accountResult, passwordResult] = await Promise.all([
    invoke('account', { reveal: false, timeoutMs }),
    invoke('password', { reveal: false, timeoutMs }),
  ])
  return presenceResult(accountResult, passwordResult)
}

function createEpochResult(epoch, ok, stage, code = null) {
  const result = {
    ok,
    stage,
    accountEntered: epoch.accountEntered,
    passwordEntered: epoch.passwordEntered,
    submitIssued: epoch.submitIssued,
  }
  if (code !== null) {
    result.code = code
  }
  return result
}

function mapKeychainFailure(result) {
  if (result?.code === 'security_unavailable') {
    return 'keychain_security_unavailable'
  }
  if (result?.code === 'lookup_timeout') {
    return 'keychain_lookup_timeout'
  }
  if (result?.code === 'secret_invalid') {
    return 'keychain_secret_invalid'
  }
  return 'keychain_handle_unavailable'
}

function currentProbeFailure(epoch, stage, result) {
  if (result?.ok !== true) {
    return createEpochResult(epoch, false, stage, 'login_probe_unavailable')
  }
  return null
}

function initialS2Failure(epoch, probe) {
  if (!probe.loginFormPresent || !probe.accountFieldPresent || !probe.passwordFieldPresent ||
    !probe.passwordFieldMasked) {
    return createEpochResult(epoch, false, 's2_account_precondition', 'login_form_not_ready')
  }
  if (!probe.accountFieldFocused) {
    return createEpochResult(epoch, false, 's2_account_precondition', 'account_focus_not_current')
  }
  if (probe.accountFieldFilled || probe.passwordFieldFilled) {
    return createEpochResult(epoch, false, 's2_account_precondition', 'field_not_empty')
  }
  return null
}

function accountFilledFailure(epoch, probe) {
  if (!probe.loginFormPresent || !probe.accountFieldPresent || !probe.passwordFieldPresent ||
    !probe.passwordFieldMasked || !probe.accountFieldFilled || probe.passwordFieldFilled) {
    return createEpochResult(epoch, false, 's2_account_verify', 'account_fill_not_verified')
  }
  return null
}

function passwordFocusedFailure(epoch, probe) {
  if (!probe.loginFormPresent || !probe.accountFieldFilled || !probe.passwordFieldFocused ||
    probe.passwordFieldFilled || !probe.passwordFieldMasked) {
    return createEpochResult(epoch, false, 's3_password_precondition', 'password_focus_not_confirmed')
  }
  return null
}

function passwordFilledFailure(epoch, probe) {
  if (!probe.loginFormPresent || !probe.accountFieldFilled || !probe.passwordFieldFilled ||
    !probe.passwordFieldMasked) {
    return createEpochResult(epoch, false, 's3_password_verify', 'password_fill_not_verified')
  }
  return null
}

function submitEligibilityFailure(epoch, probe) {
  if (probe.challengeResponsePresent !== true || probe.challengeResponseReady !== true ||
    probe.challengeFramePresent) {
    return createEpochResult(epoch, false, 's4_submit_precondition', 'captcha_token_not_ready')
  }
  if (!probe.submitPresent || !probe.submitEnabled || probe.formValid !== true ||
    probe.submitEligible !== true) {
    return createEpochResult(epoch, false, 's4_submit_precondition', 'submit_not_eligible')
  }
  return null
}

/**
 * Executes exactly one in-memory S2--S4 epoch. It begins by re-proving the
 * current S2 focus and empty fields, gets each fixed Keychain secret only when
 * needed through a child-process pipe, and emits only state-machine booleans.
 * It deliberately does not continue into S5/S6; those require native safe
 * readers in the repository protocol.
 */
export async function runKeychainLoginEpoch({ port, timeoutMs }, dependencies = {}) {
  // This record is intentionally process-local and never written to a file.
  // Mark each input immediately before dispatch so transport ambiguity can
  // never enable a blind retry in the same epoch.
  const epoch = {
    accountEntered: false,
    passwordEntered: false,
    submitIssued: false,
  }
  if (!Number.isInteger(port) || !Number.isInteger(timeoutMs) || timeoutMs < MIN_TIMEOUT_MS ||
    timeoutMs > MAX_TIMEOUT_MS) {
    return createEpochResult(epoch, false, 'arguments', 'invalid_arguments')
  }
  const probe = dependencies.probe || runProbe
  const semanticDriver = dependencies.semanticDriver || runDriver
  const secretFill = dependencies.secretFill || runSecretFieldFill
  const retrieveSecret = dependencies.retrieveSecret || ((slot) => invokeKeychainHandle(slot, {
    reveal: true,
    timeoutMs: Math.min(timeoutMs, KEYCHAIN_TIMEOUT_MS),
  }))
  if (typeof probe !== 'function' || typeof semanticDriver !== 'function' || typeof secretFill !== 'function' ||
    typeof retrieveSecret !== 'function') {
    return createEpochResult(epoch, false, 'arguments', 'invalid_arguments')
  }
  let accountSecret = null
  let passwordSecret = null
  try {
    const initialProbe = await probe({ port, timeoutMs })
    const initialProbeError = currentProbeFailure(epoch, 's2_account_precondition', initialProbe)
    if (initialProbeError !== null) {
      return initialProbeError
    }
    const initialStateError = initialS2Failure(epoch, initialProbe)
    if (initialStateError !== null) {
      return initialStateError
    }

    const accountResult = await retrieveSecret('account')
    if (accountResult?.ok !== true || !(accountResult.secretBytes instanceof Uint8Array)) {
      return createEpochResult(epoch, false, 's2_account_secret', mapKeychainFailure(accountResult))
    }
    accountSecret = accountResult.secretBytes
    epoch.accountEntered = true
    const accountFill = await secretFill({
      port,
      field: 'account',
      secretBytes: accountSecret,
      timeoutMs,
    })
    // Keep the mutable reference until `finally` so an injected/test driver
    // cannot accidentally weaken the epoch's zeroization guarantee.
    if (accountFill?.ok !== true || accountFill.fieldInputApplied !== true) {
      return createEpochResult(epoch, false, 's2_account_input', 'account_input_not_confirmed')
    }

    const afterAccountProbe = await probe({ port, timeoutMs })
    const afterAccountProbeError = currentProbeFailure(epoch, 's2_account_verify', afterAccountProbe)
    if (afterAccountProbeError !== null) {
      return afterAccountProbeError
    }
    const accountStateError = accountFilledFailure(epoch, afterAccountProbe)
    if (accountStateError !== null) {
      return accountStateError
    }

    const passwordFocus = await semanticDriver({ port, action: 'focus-password', timeoutMs })
    if (passwordFocus?.ok !== true || passwordFocus.passwordFieldFocused !== true ||
      passwordFocus.actionApplied !== true) {
      return createEpochResult(epoch, false, 's3_password_focus', 'password_focus_not_confirmed')
    }
    const passwordFocusProbe = await probe({ port, timeoutMs })
    const passwordFocusProbeError = currentProbeFailure(epoch, 's3_password_precondition', passwordFocusProbe)
    if (passwordFocusProbeError !== null) {
      return passwordFocusProbeError
    }
    const passwordFocusStateError = passwordFocusedFailure(epoch, passwordFocusProbe)
    if (passwordFocusStateError !== null) {
      return passwordFocusStateError
    }

    const passwordResult = await retrieveSecret('password')
    if (passwordResult?.ok !== true || !(passwordResult.secretBytes instanceof Uint8Array)) {
      return createEpochResult(epoch, false, 's3_password_secret', mapKeychainFailure(passwordResult))
    }
    passwordSecret = passwordResult.secretBytes
    epoch.passwordEntered = true
    const passwordFill = await secretFill({
      port,
      field: 'password',
      secretBytes: passwordSecret,
      timeoutMs,
    })
    // See the account branch: `finally` owns the final wipe even if a caller
    // replaces the imported driver in a contract test.
    if (passwordFill?.ok !== true || passwordFill.fieldInputApplied !== true) {
      return createEpochResult(epoch, false, 's3_password_input', 'password_input_not_confirmed')
    }

    const afterPasswordProbe = await probe({ port, timeoutMs })
    const afterPasswordProbeError = currentProbeFailure(epoch, 's3_password_verify', afterPasswordProbe)
    if (afterPasswordProbeError !== null) {
      return afterPasswordProbeError
    }
    const passwordStateError = passwordFilledFailure(epoch, afterPasswordProbe)
    if (passwordStateError !== null) {
      return passwordStateError
    }
    const submitStateError = submitEligibilityFailure(epoch, afterPasswordProbe)
    if (submitStateError !== null) {
      return submitStateError
    }

    epoch.submitIssued = true
    const submitResult = await semanticDriver({ port, action: 'submit', timeoutMs })
    if (submitResult?.ok !== true || submitResult.submitDispatched !== true || submitResult.actionApplied !== true) {
      return createEpochResult(epoch, false, 's4_submit', 'submit_outcome_inconclusive')
    }
    return createEpochResult(epoch, true, 's4_submit_dispatched')
  } catch (_error) {
    // Do not expose an exception message; an unclassified failure after a
    // credential dispatch is deliberately terminal for this epoch.
    return createEpochResult(epoch, false, 'epoch_runtime', 'login_probe_unavailable')
  } finally {
    wipeBuffers([accountSecret, passwordSecret])
  }
}

/**
 * Executes the whole credential-writing portion of a login recovery as one
 * uninterrupted process.  Unlike the legacy Keychain entrypoint, this API
 * receives two already-staged mutable byte buffers from its coordinator.  It
 * deliberately has no CLI form: secrets cannot become argv, environment,
 * file, stdout, or log data.
 *
 * This function owns only the one account write followed by the one password
 * write. The caller must run the CAPTCHA gate only after this function returns
 * `credentials_staged`; this function never submits.
 */
export async function runStagedLoginEpoch({
  port,
  timeoutMs,
  accountSecretBytes,
  passwordSecretBytes,
}, dependencies = {}) {
  const epoch = {
    accountEntered: false,
    passwordEntered: false,
    submitIssued: false,
  }
  const accountSecret = accountSecretBytes instanceof Uint8Array ? accountSecretBytes : null
  const passwordSecret = passwordSecretBytes instanceof Uint8Array ? passwordSecretBytes : null
  if (!Number.isInteger(port) || !Number.isInteger(timeoutMs) || timeoutMs < MIN_TIMEOUT_MS ||
    timeoutMs > MAX_TIMEOUT_MS || accountSecret === null || passwordSecret === null ||
    accountSecret.length === 0 || passwordSecret.length === 0 ||
    accountSecret.length > MAX_KEYCHAIN_SECRET_BYTES || passwordSecret.length > MAX_KEYCHAIN_SECRET_BYTES) {
    wipeBuffers([accountSecretBytes, passwordSecretBytes])
    return createEpochResult(epoch, false, 'arguments', 'invalid_arguments')
  }
  const probe = dependencies.probe || runProbe
  const semanticDriver = dependencies.semanticDriver || runDriver
  const secretFill = dependencies.secretFill || runSecretFieldFill
  if (typeof probe !== 'function' || typeof semanticDriver !== 'function' || typeof secretFill !== 'function') {
    wipeBuffers([accountSecret, passwordSecret])
    return createEpochResult(epoch, false, 'arguments', 'invalid_arguments')
  }
  try {
    const preFocusProbe = await probe({ port, timeoutMs })
    const preFocusProbeError = currentProbeFailure(epoch, 's2_account_precondition', preFocusProbe)
    if (preFocusProbeError !== null) {
      return preFocusProbeError
    }
    if (!preFocusProbe.loginFormPresent || !preFocusProbe.accountFieldPresent ||
      !preFocusProbe.passwordFieldPresent || !preFocusProbe.passwordFieldMasked ||
      preFocusProbe.accountFieldFilled || preFocusProbe.passwordFieldFilled) {
      return createEpochResult(epoch, false, 's2_account_precondition', 'login_form_not_ready')
    }
    const accountFocus = await semanticDriver({ port, action: 'focus-account', timeoutMs })
    if (accountFocus?.ok !== true || accountFocus.accountFieldFocused !== true || accountFocus.actionApplied !== true) {
      return createEpochResult(epoch, false, 's2_account_focus', 'account_focus_not_current')
    }
    const initialProbe = await probe({ port, timeoutMs })
    const initialProbeError = currentProbeFailure(epoch, 's2_account_precondition', initialProbe)
    if (initialProbeError !== null) {
      return initialProbeError
    }
    const initialStateError = initialS2Failure(epoch, initialProbe)
    if (initialStateError !== null) {
      return initialStateError
    }

    epoch.accountEntered = true
    const accountFill = await secretFill({
      port,
      field: 'account',
      secretBytes: accountSecret,
      timeoutMs,
    })
    if (accountFill?.ok !== true || accountFill.fieldInputApplied !== true) {
      return createEpochResult(epoch, false, 's2_account_input', 'account_input_not_confirmed')
    }
    const afterAccountProbe = await probe({ port, timeoutMs })
    const afterAccountProbeError = currentProbeFailure(epoch, 's2_account_verify', afterAccountProbe)
    if (afterAccountProbeError !== null) {
      return afterAccountProbeError
    }
    const accountStateError = accountFilledFailure(epoch, afterAccountProbe)
    if (accountStateError !== null) {
      return accountStateError
    }

    const passwordFocus = await semanticDriver({ port, action: 'focus-password', timeoutMs })
    if (passwordFocus?.ok !== true || passwordFocus.passwordFieldFocused !== true ||
      passwordFocus.actionApplied !== true) {
      return createEpochResult(epoch, false, 's3_password_focus', 'password_focus_not_confirmed')
    }
    const passwordFocusProbe = await probe({ port, timeoutMs })
    const passwordFocusProbeError = currentProbeFailure(epoch, 's3_password_precondition', passwordFocusProbe)
    if (passwordFocusProbeError !== null) {
      return passwordFocusProbeError
    }
    const passwordFocusStateError = passwordFocusedFailure(epoch, passwordFocusProbe)
    if (passwordFocusStateError !== null) {
      return passwordFocusStateError
    }

    epoch.passwordEntered = true
    const passwordFill = await secretFill({
      port,
      field: 'password',
      secretBytes: passwordSecret,
      timeoutMs,
    })
    if (passwordFill?.ok !== true || passwordFill.fieldInputApplied !== true) {
      return createEpochResult(epoch, false, 's3_password_input', 'password_input_not_confirmed')
    }
    const afterPasswordProbe = await probe({ port, timeoutMs })
    const afterPasswordProbeError = currentProbeFailure(epoch, 's3_password_verify', afterPasswordProbe)
    if (afterPasswordProbeError !== null) {
      return afterPasswordProbeError
    }
    const passwordStateError = passwordFilledFailure(epoch, afterPasswordProbe)
    if (passwordStateError !== null) {
      return passwordStateError
    }
    return createEpochResult(epoch, true, 'credentials_staged')
  } catch (_error) {
    return createEpochResult(epoch, false, 'epoch_runtime', 'login_probe_unavailable')
  } finally {
    wipeBuffers([accountSecret, passwordSecret])
  }
}

/**
 * Fixed completion branch. It contains no credential write and no model
 * decision: the caller staged both fields, completed CAPTCHA in the same
 * process, and this branch rechecks the current token before the sole submit.
 */
export async function runCfReviewedSubmit({ port, timeoutMs }, dependencies = {}) {
  const epoch = {
    accountEntered: true,
    passwordEntered: true,
    submitIssued: false,
  }
  if (!Number.isInteger(port) || !Number.isInteger(timeoutMs) || timeoutMs < MIN_TIMEOUT_MS ||
    timeoutMs > MAX_TIMEOUT_MS) {
    return createEpochResult(epoch, false, 'arguments', 'invalid_arguments')
  }
  const probe = dependencies.probe || runProbe
  const semanticDriver = dependencies.semanticDriver || runDriver
  if (typeof probe !== 'function' || typeof semanticDriver !== 'function') {
    return createEpochResult(epoch, false, 'arguments', 'invalid_arguments')
  }
  try {
    const afterSnapshotProbe = await probe({ port, timeoutMs })
    const probeError = currentProbeFailure(epoch, 'cf_submit_precondition', afterSnapshotProbe)
    if (probeError !== null) {
      return probeError
    }
    const passwordStateError = passwordFilledFailure(epoch, afterSnapshotProbe)
    if (passwordStateError !== null) {
      return passwordStateError
    }
    const submitStateError = submitEligibilityFailure(epoch, afterSnapshotProbe)
    if (submitStateError !== null) {
      return createEpochResult(epoch, false, 'cf_submit_precondition',
        afterSnapshotProbe.challengeResponseReady !== true ||
          afterSnapshotProbe.challengeFramePresent === true
          ? 'captcha_token_not_ready' : 'submit_not_eligible')
    }
    epoch.submitIssued = true
    const submitResult = await semanticDriver({ port, action: 'submit', timeoutMs })
    if (submitResult?.ok !== true || submitResult.submitDispatched !== true || submitResult.actionApplied !== true) {
      return createEpochResult(epoch, false, 's4_submit', 'submit_outcome_inconclusive')
    }
    return createEpochResult(epoch, true, 's4_submit_dispatched')
  } catch (_error) {
    return createEpochResult(epoch, false, 'epoch_runtime', 'login_probe_unavailable')
  }
}

/**
 * Retrieves both fixed Keychain entries before the form sequence begins, then
 * delegates the entire account/password write sequence to one uninterrupted
 * staged epoch. The later same-process CAPTCHA gate and submit are separate,
 * credential-free phases by design.
 */
export async function runKeychainStagedLoginEpoch({ port, timeoutMs }, dependencies = {}) {
  const epoch = {
    accountEntered: false,
    passwordEntered: false,
    submitIssued: false,
  }
  if (!Number.isInteger(port) || !Number.isInteger(timeoutMs) || timeoutMs < MIN_TIMEOUT_MS ||
    timeoutMs > MAX_TIMEOUT_MS) {
    return createEpochResult(epoch, false, 'arguments', 'invalid_arguments')
  }
  const retrieveSecret = dependencies.retrieveSecret || ((slot) => invokeKeychainHandle(slot, {
    reveal: true,
    timeoutMs: Math.min(timeoutMs, KEYCHAIN_TIMEOUT_MS),
  }))
  if (typeof retrieveSecret !== 'function') {
    return createEpochResult(epoch, false, 'arguments', 'invalid_arguments')
  }
  let accountSecret = null
  let passwordSecret = null
  try {
    const accountResult = await retrieveSecret('account')
    if (accountResult?.ok !== true || !(accountResult.secretBytes instanceof Uint8Array)) {
      return createEpochResult(epoch, false, 's2_account_secret', mapKeychainFailure(accountResult))
    }
    accountSecret = accountResult.secretBytes
    const passwordResult = await retrieveSecret('password')
    if (passwordResult?.ok !== true || !(passwordResult.secretBytes instanceof Uint8Array)) {
      return createEpochResult(epoch, false, 's3_password_secret', mapKeychainFailure(passwordResult))
    }
    passwordSecret = passwordResult.secretBytes
    return await runStagedLoginEpoch({
      port,
      timeoutMs,
      accountSecretBytes: accountSecret,
      passwordSecretBytes: passwordSecret,
    }, dependencies)
  } catch (_error) {
    return createEpochResult(epoch, false, 'epoch_runtime', 'login_probe_unavailable')
  } finally {
    wipeBuffers([accountSecret, passwordSecret])
  }
}

export function parseArguments(argv) {
  if (argv.length === 1 && argv[0] === '--diagnose-keychain') {
    return { mode: 'diagnose-keychain' }
  }
  let port = null
  let timeoutMs = DEFAULT_TIMEOUT_MS
  let completeCf = false
  for (let index = 0; index < argv.length; index += 1) {
    const option = argv[index]
    if (option === '--complete-cf') {
      if (completeCf) {
        return null
      }
      completeCf = true
      continue
    }
    if (option === '--port') {
      const parsed = parsePort(argv[index + 1] || '')
      if (parsed === null || port !== null) {
        return null
      }
      port = parsed
      index += 1
      continue
    }
    if (option === '--timeout-ms') {
      const parsed = parseTimeout(argv[index + 1] || '')
      if (parsed === null) {
        return null
      }
      timeoutMs = parsed
      index += 1
      continue
    }
    return null
  }
  return port === null ? null : { mode: completeCf ? 'cf-submit' : 'staged-epoch', port, timeoutMs }
}

function usage() {
  return 'Usage: node scripts/run_arkweb_login_keychain_epoch.mjs --diagnose-keychain | --port <local-devtools-port> [--complete-cf] [--timeout-ms 500..15000]'
}

async function runCli() {
  if (process.argv.slice(2).length === 1 && process.argv[2] === '--help') {
    process.stdout.write(`${usage()}\n`)
    return 0
  }
  const options = parseArguments(process.argv.slice(2))
  if (options === null) {
    process.stdout.write(`${JSON.stringify({ ok: false, stage: 'arguments', code: 'invalid_arguments' })}\n`)
    return 1
  }
  const result = options.mode === 'diagnose-keychain'
    ? await runKeychainPresenceDiagnostic()
    : options.mode === 'cf-submit'
      ? await runCfReviewedSubmit(options)
      : await runKeychainStagedLoginEpoch(options)
  process.stdout.write(`${JSON.stringify(result)}\n`)
  return result.ok ? 0 : 1
}

const invokedPath = process.argv[1] === undefined ? '' : pathToFileURL(process.argv[1]).href
if (import.meta.url === invokedPath) {
  runCli().then((exitCode) => {
    process.exitCode = exitCode
  }).catch(() => {
    process.stdout.write(`${JSON.stringify({ ok: false, stage: 'epoch_runtime', code: 'login_probe_unavailable' })}\n`)
    process.exitCode = 1
  })
}
