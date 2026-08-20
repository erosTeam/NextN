#!/usr/bin/env node

import { request as httpRequest } from 'node:http'
import { pathToFileURL } from 'node:url'

// The public CLI deliberately has no credential-entry capability. It only
// performs the non-secret semantic focus/submit actions needed by the durable
// account-login protocol. The separately reviewed Keychain epoch orchestrator
// may import `runSecretFieldFill()` in-process, but no CLI form of this driver
// accepts a secret argument, environment variable, file, fixture, or log.
const DEFAULT_TIMEOUT_MS = 4000
const MIN_TIMEOUT_MS = 500
const MAX_TIMEOUT_MS = 15000
const MAX_DISCOVERY_BYTES = 1024 * 1024
const MAX_LOCAL_PAGE_TARGETS = 2
const MAX_SECRET_BYTES = 4096

const ALLOWED_ACTIONS = new Set([
  'focus-account',
  'focus-password',
  'submit',
])

const SECRET_FIELDS = new Set([
  'account',
  'password',
])

// Failure values intentionally disclose only a fixed stage/code pair. They
// never contain page metadata, field selectors, URLs, titles, DOM text,
// cookies, form values, or transport error text.
export const SAFE_DISCOVERY_FAILURE_CODES = [
  'http_not_ok',
  'declared_body_too_large',
  'body_too_large',
  'invalid_json',
  'unexpected_root',
  'timeout',
  'connection_refused',
  'connection_reset',
  'transport_failed',
  'response_read_failed',
]

export const SAFE_PAGE_SELECTION_FAILURE_CODES = [
  'no_local_page',
  'too_many_local_pages',
  'login_form_absent',
  'login_form_ambiguous',
  'page_probe_inconclusive',
]

export const SAFE_ACTION_FAILURE_CODES = [
  'login_form_not_unique_or_missing',
  'focus_not_confirmed',
  'submit_not_eligible',
  'submit_dispatch_not_confirmed',
]

// Secret-fill results are deliberately narrower than the read-only probe.
// They never report a value, length, selector, label, URL, title, cookie, or
// secret-handle identifier. The caller must use the separate read-only probe
// for the S2/S3 filled-field postconditions.
export const SAFE_SECRET_FILL_FAILURE_CODES = [
  'invalid_secret_bytes',
  'login_form_not_unique_or_missing',
  'field_focus_not_current',
  'secret_input_not_confirmed',
]

// A successful output is a fixed safe shape. `stage` is fixed and `formValid`
// is nullable because focus actions do not invoke validation. No action name
// is echoed: it is already the caller's fixed CLI choice and need not become
// retained acceptance evidence.
export const SAFE_DRIVER_OUTPUT_KEYS = [
  'ok',
  'stage',
  'loginFormPresent',
  'accountFieldPresent',
  'accountFieldFocused',
  'passwordFieldPresent',
  'passwordFieldFocused',
  'passwordFieldMasked',
  'submitPresent',
  'submitEnabled',
  'formValid',
  'challengeFramePresent',
  'actionApplied',
  'submitDispatched',
]

export const SAFE_SECRET_FILL_OUTPUT_KEYS = [
  'ok',
  'stage',
  'loginFormPresent',
  'accountFieldPresent',
  'accountFieldFocused',
  'passwordFieldPresent',
  'passwordFieldFocused',
  'passwordFieldMasked',
  'fieldInputApplied',
]

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}

function strictBoolean(value) {
  return value === true
}

function nullableBoolean(value) {
  return value === true || value === false ? value : null
}

export function createFailure(stage, code) {
  return { ok: false, stage, code }
}

/**
 * Keep only the fixed structural booleans returned by the first, read-only
 * selection evaluation. In particular, this never reads input values or
 * exposes raw CDP data to a caller.
 */
function normalizeLoginFormSelection(value) {
  if (!isObject(value)) {
    return { ok: false }
  }
  const accountFieldPresent = strictBoolean(value.accountFieldPresent)
  const passwordFieldPresent = strictBoolean(value.passwordFieldPresent)
  const passwordFieldMasked = passwordFieldPresent && strictBoolean(value.passwordFieldMasked)
  const submitPresent = strictBoolean(value.submitPresent)
  return {
    ok: strictBoolean(value.loginFormPresent) && accountFieldPresent && passwordFieldPresent &&
      passwordFieldMasked && submitPresent,
  }
}

/**
 * Discards every unapproved CDP property. The action output intentionally has
 * no filled/length fields so this driver cannot inspect a credential value.
 */
export function normalizeDriverSummary(value) {
  if (!isObject(value)) {
    return createFailure('runtime_evaluate', 'invalid_safe_result')
  }
  const accountFieldPresent = strictBoolean(value.accountFieldPresent)
  const passwordFieldPresent = strictBoolean(value.passwordFieldPresent)
  const passwordFieldMasked = passwordFieldPresent && strictBoolean(value.passwordFieldMasked)
  const submitPresent = strictBoolean(value.submitPresent)
  const loginFormPresent = strictBoolean(value.loginFormPresent) && accountFieldPresent &&
    passwordFieldPresent && passwordFieldMasked && submitPresent
  const accountFieldFocused = accountFieldPresent && strictBoolean(value.accountFieldFocused)
  const passwordFieldFocused = passwordFieldPresent && strictBoolean(value.passwordFieldFocused)
  const submitEnabled = submitPresent && strictBoolean(value.submitEnabled)
  return {
    ok: true,
    stage: 'login_field_action',
    loginFormPresent,
    accountFieldPresent,
    accountFieldFocused,
    passwordFieldPresent,
    passwordFieldFocused,
    passwordFieldMasked,
    submitPresent,
    submitEnabled,
    formValid: nullableBoolean(value.formValid),
    challengeFramePresent: strictBoolean(value.challengeFramePresent),
    actionApplied: strictBoolean(value.actionApplied),
    submitDispatched: strictBoolean(value.submitDispatched),
  }
}

function decodeSecretBytes(secretBytes) {
  if (!(secretBytes instanceof Uint8Array) || secretBytes.length === 0 ||
    secretBytes.length > MAX_SECRET_BYTES) {
    return null
  }
  const copy = Buffer.from(secretBytes)
  try {
    const decoded = new TextDecoder('utf-8', { fatal: true }).decode(copy)
    // NUL cannot be represented by the target form path safely. A terminal
    // CR/LF is rejected by the Keychain provisioning contract rather than
    // silently changing a supplied secret during transport.
    if (decoded.length === 0 || decoded.includes('\u0000') || decoded.endsWith('\n') || decoded.endsWith('\r')) {
      return null
    }
    return decoded
  } catch (_error) {
    return null
  } finally {
    copy.fill(0)
  }
}

function wipeSecretBytes(secretBytes) {
  if (secretBytes instanceof Uint8Array) {
    secretBytes.fill(0)
  }
}

/**
 * Keeps only fixed structural/action booleans from the one secret-bearing CDP
 * evaluation. The secret itself is never included in the returned object.
 */
export function normalizeSecretFillSummary(value) {
  if (!isObject(value)) {
    return createFailure('secret_field_action', 'invalid_safe_result')
  }
  const accountFieldPresent = strictBoolean(value.accountFieldPresent)
  const passwordFieldPresent = strictBoolean(value.passwordFieldPresent)
  const passwordFieldMasked = passwordFieldPresent && strictBoolean(value.passwordFieldMasked)
  const loginFormPresent = strictBoolean(value.loginFormPresent) && accountFieldPresent &&
    passwordFieldPresent && passwordFieldMasked
  return {
    ok: true,
    stage: 'secret_field_action',
    loginFormPresent,
    accountFieldPresent,
    accountFieldFocused: accountFieldPresent && strictBoolean(value.accountFieldFocused),
    passwordFieldPresent,
    passwordFieldFocused: passwordFieldPresent && strictBoolean(value.passwordFieldFocused),
    passwordFieldMasked,
    fieldInputApplied: strictBoolean(value.fieldInputApplied),
  }
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

export function parseArguments(argv) {
  let port = null
  let action = null
  let timeoutMs = DEFAULT_TIMEOUT_MS
  for (let index = 0; index < argv.length; index += 1) {
    const option = argv[index]
    if (option === '--port') {
      const parsed = parsePort(argv[index + 1] || '')
      if (parsed === null || port !== null) {
        return null
      }
      port = parsed
      index += 1
      continue
    }
    if (option === '--action') {
      const parsed = argv[index + 1] || ''
      if (!ALLOWED_ACTIONS.has(parsed) || action !== null) {
        return null
      }
      action = parsed
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
  return port === null || action === null ? null : { port, action, timeoutMs }
}

function localDevtoolsUrl(port) {
  return `http://127.0.0.1:${port}/json`
}

function isLocalDebuggerSocket(value, port) {
  if (typeof value !== 'string') {
    return false
  }
  try {
    const parsed = new URL(value)
    return parsed.protocol === 'ws:' &&
      (parsed.hostname === '127.0.0.1' || parsed.hostname === 'localhost') &&
      parsed.port === String(port)
  } catch (_error) {
    return false
  }
}

function classifyNodeHttpTransportError(error) {
  if (error?.code === 'ECONNREFUSED') {
    return 'connection_refused'
  }
  if (error?.code === 'ECONNRESET') {
    return 'connection_reset'
  }
  if (error?.code === 'ETIMEDOUT') {
    return 'timeout'
  }
  return 'transport_failed'
}

function parseDiscoveredPages(raw) {
  if (raw.length > MAX_DISCOVERY_BYTES) {
    return { ok: false, code: 'body_too_large' }
  }
  let pages
  try {
    pages = JSON.parse(raw)
  } catch (_error) {
    return { ok: false, code: 'invalid_json' }
  }
  if (!Array.isArray(pages)) {
    return { ok: false, code: 'unexpected_root' }
  }
  return { ok: true, pages }
}

/**
 * This is intentionally the same loopback-only bounded HTTP fallback used by
 * the read-only probe. It holds raw discovery data only in-process long enough
 * to select a locally forwarded page, and never returns it to stdout.
 */
function fetchLocalPagesWithNodeHttp(port, timeoutMs, requestImpl = httpRequest) {
  return new Promise((resolve) => {
    let settled = false
    const finish = (result) => {
      if (settled) {
        return
      }
      settled = true
      resolve(result)
    }
    const request = requestImpl({
      host: '127.0.0.1',
      port,
      path: '/json',
      method: 'GET',
      headers: {
        Accept: 'application/json',
        Connection: 'close',
      },
    }, (response) => {
      const declaredLength = Number(response.headers['content-length'] || '0')
      if (!Number.isInteger(response.statusCode) || response.statusCode < 200 || response.statusCode >= 300) {
        response.resume()
        finish({ ok: false, code: 'http_not_ok' })
        return
      }
      if (Number.isFinite(declaredLength) && declaredLength > MAX_DISCOVERY_BYTES) {
        response.resume()
        finish({ ok: false, code: 'declared_body_too_large' })
        return
      }
      const chunks = []
      let totalBytes = 0
      response.on('data', (chunk) => {
        if (settled) {
          return
        }
        const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)
        totalBytes += bytes.length
        if (totalBytes > MAX_DISCOVERY_BYTES) {
          response.destroy()
          finish({ ok: false, code: 'body_too_large' })
          return
        }
        chunks.push(bytes)
      })
      response.once('error', (error) => finish({
        ok: false,
        code: classifyNodeHttpTransportError(error),
      }))
      response.once('end', () => {
        if (!settled) {
          finish(parseDiscoveredPages(Buffer.concat(chunks).toString('utf8')))
        }
      })
    })
    request.once('error', (error) => finish({
      ok: false,
      code: classifyNodeHttpTransportError(error),
    }))
    request.setTimeout(timeoutMs, () => {
      request.destroy()
      finish({ ok: false, code: 'timeout' })
    })
    request.end()
  })
}

async function fetchLocalPages(port, timeoutMs, transport = {}) {
  const startedAt = Date.now()
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs)
  try {
    let response
    try {
      response = await (transport.fetchImpl || globalThis.fetch)(localDevtoolsUrl(port), {
        signal: controller.signal,
      })
    } catch (_error) {
      if (controller.signal.aborted) {
        return { ok: false, code: 'timeout' }
      }
      return fetchLocalPagesWithNodeHttp(
        port,
        Math.max(1, timeoutMs - (Date.now() - startedAt)),
        transport.httpRequestImpl,
      )
    }
    const contentLength = Number(response.headers.get('content-length') || '0')
    if (!response.ok) {
      return { ok: false, code: 'http_not_ok' }
    }
    if (Number.isFinite(contentLength) && contentLength > MAX_DISCOVERY_BYTES) {
      return { ok: false, code: 'declared_body_too_large' }
    }
    let raw
    try {
      raw = await response.text()
    } catch (_error) {
      return {
        ok: false,
        code: controller.signal.aborted ? 'timeout' : 'response_read_failed',
      }
    }
    return parseDiscoveredPages(raw)
  } finally {
    clearTimeout(timeoutId)
  }
}

function selectLocalPages(pages, port) {
  const candidates = pages.filter((page) => isObject(page) && page.type === 'page' &&
    isLocalDebuggerSocket(page.webSocketDebuggerUrl, port))
  if (candidates.length === 0) {
    return { code: 'no_local_page' }
  }
  if (candidates.length > MAX_LOCAL_PAGE_TARGETS) {
    return { code: 'too_many_local_pages' }
  }
  return { socketUrls: candidates.map((candidate) => candidate.webSocketDebuggerUrl) }
}

function waitForSocketOpen(socket, timeoutMs) {
  return new Promise((resolve) => {
    let settled = false
    const finish = (result) => {
      if (settled) {
        return
      }
      settled = true
      clearTimeout(timeoutId)
      resolve(result)
    }
    const timeoutId = setTimeout(() => finish(false), timeoutMs)
    socket.addEventListener('open', () => finish(true), { once: true })
    socket.addEventListener('error', () => finish(false), { once: true })
    socket.addEventListener('close', () => finish(false), { once: true })
  })
}

function sendCdp(socket, id, method, params, timeoutMs) {
  return new Promise((resolve) => {
    let settled = false
    const finish = (result) => {
      if (settled) {
        return
      }
      settled = true
      clearTimeout(timeoutId)
      socket.removeEventListener('message', onMessage)
      socket.removeEventListener('error', onError)
      socket.removeEventListener('close', onClose)
      resolve(result)
    }
    const onMessage = (event) => {
      try {
        const message = JSON.parse(String(event.data))
        if (isObject(message) && message.id === id) {
          finish({ kind: 'message', message })
        }
      } catch (_error) {
        finish({ kind: 'invalid_message' })
      }
    }
    const onError = () => finish({ kind: 'socket_error' })
    const onClose = () => finish({ kind: 'socket_closed' })
    const timeoutId = setTimeout(() => finish({ kind: 'timeout' }), timeoutMs)
    socket.addEventListener('message', onMessage)
    socket.addEventListener('error', onError, { once: true })
    socket.addEventListener('close', onClose, { once: true })
    try {
      socket.send(JSON.stringify({ id, method, params }))
    } catch (_error) {
      finish({ kind: 'send_failed' })
    }
  })
}

function closeQuietly(socket) {
  try {
    socket.close()
  } catch (_error) {
    // A close error must never become a diagnostic containing transport data.
  }
}

async function evaluateSingleLocalPage(socketUrl, expression, timeoutMs) {
  if (typeof globalThis.WebSocket !== 'function') {
    return createFailure('cdp_connect', 'websocket_unavailable')
  }
  let socket
  try {
    socket = new globalThis.WebSocket(socketUrl)
  } catch (_error) {
    return createFailure('cdp_connect', 'open_failed')
  }
  try {
    if (!await waitForSocketOpen(socket, timeoutMs)) {
      return createFailure('cdp_connect', 'open_failed_or_timeout')
    }
    const enabled = await sendCdp(socket, 1, 'Runtime.enable', {}, timeoutMs)
    if (enabled.kind !== 'message' || !isObject(enabled.message) || enabled.message.error !== undefined) {
      return createFailure('runtime_enable', 'failed')
    }
    const evaluated = await sendCdp(socket, 2, 'Runtime.evaluate', {
      expression,
      awaitPromise: true,
      returnByValue: true,
    }, timeoutMs)
    if (evaluated.kind !== 'message' || !isObject(evaluated.message) || evaluated.message.error !== undefined) {
      return createFailure('runtime_evaluate', 'failed')
    }
    const result = evaluated.message.result
    if (!isObject(result) || result.exceptionDetails !== undefined || !isObject(result.result)) {
      return createFailure('runtime_evaluate', 'exception_or_missing_result')
    }
    // This is the CDP protocol envelope, not a DOM-field read. The expression
    // below returns only a whitelisted boolean object before this point.
    return { ok: true, safePayload: result.result.value }
  } finally {
    closeQuietly(socket)
  }
}

// The selection expression is read-only. It selects only a page with one
// visible text-like account field, one visible password field in the same
// form, and one visible semantic submit control. It never reads any field
// value, length, label, placeholder, DOM text, URL, title, cookie, or token.
const LOGIN_FORM_SELECTION_EXPRESSION = `(() => {
  const isVisible = (element) => {
    try {
      const style = window.getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      return style.display !== 'none' && style.visibility !== 'hidden' &&
        element.getAttribute('aria-hidden') !== 'true' && rect.width > 0 && rect.height > 0;
    } catch (_error) {
      return false;
    }
  };
  const visibleInputs = Array.from(document.querySelectorAll('input')).filter(isVisible);
  const passwordFields = visibleInputs.filter((input) =>
    String(input.type || '').toLowerCase() === 'password');
  const accountFields = visibleInputs.filter((input) => {
    const type = String(input.type || 'text').toLowerCase();
    return type === '' || type === 'text' || type === 'email' || type === 'tel' || type === 'search';
  });
  const accountField = accountFields.length === 1 ? accountFields[0] : null;
  const passwordField = passwordFields.length === 1 ? passwordFields[0] : null;
  const form = accountField !== null && passwordField !== null && accountField.form !== null &&
    accountField.form === passwordField.form ? accountField.form : null;
  const submitControls = form === null ? [] : Array.from(form.querySelectorAll('button, input')).filter(isVisible);
  const submitControlsSemantic = submitControls.filter((control) => {
    const tag = String(control.tagName || '').toLowerCase();
    const type = String(control.getAttribute('type') || '').toLowerCase();
    return (tag === 'button' && (type === '' || type === 'submit')) ||
      (tag === 'input' && type === 'submit');
  });
  return {
    loginFormPresent: form !== null && submitControlsSemantic.length === 1,
    accountFieldPresent: accountField !== null,
    passwordFieldPresent: passwordField !== null,
    passwordFieldMasked: passwordField !== null && String(passwordField.type || '').toLowerCase() === 'password',
    submitPresent: submitControlsSemantic.length === 1,
  };
})()`

// Internal-only submit activation point. It returns no DOM text, selector,
// value, URL, title, cookie, or account data. The transient coordinates are
// consumed immediately by CDP Input and never cross the driver's safe result.
const SUBMIT_ACTIVATION_EXPRESSION = `(() => {
  const isVisible = (element) => {
    try {
      const style = window.getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      return style.display !== 'none' && style.visibility !== 'hidden' &&
        element.getAttribute('aria-hidden') !== 'true' && rect.width > 0 && rect.height > 0;
    } catch (_error) {
      return false;
    }
  };
  const visibleInputs = Array.from(document.querySelectorAll('input')).filter(isVisible);
  const passwordFields = visibleInputs.filter((input) =>
    String(input.type || '').toLowerCase() === 'password');
  const accountFields = visibleInputs.filter((input) => {
    const type = String(input.type || 'text').toLowerCase();
    return type === '' || type === 'text' || type === 'email' || type === 'tel' || type === 'search';
  });
  const accountField = accountFields.length === 1 ? accountFields[0] : null;
  const passwordField = passwordFields.length === 1 ? passwordFields[0] : null;
  const form = accountField !== null && passwordField !== null && accountField.form !== null &&
    accountField.form === passwordField.form ? accountField.form : null;
  const submitControls = form === null ? [] : Array.from(form.querySelectorAll('button, input')).filter(isVisible);
  const submits = submitControls.filter((control) => {
    const tag = String(control.tagName || '').toLowerCase();
    const type = String(control.getAttribute('type') || '').toLowerCase();
    return (tag === 'button' && (type === '' || type === 'submit')) ||
      (tag === 'input' && type === 'submit');
  });
  const submit = submits.length === 1 ? submits[0] : null;
  const submitEnabled = submit !== null && !submit.disabled &&
    String(submit.getAttribute('aria-disabled') || '').toLowerCase() !== 'true';
  const challengeFramePresent = Array.from(document.querySelectorAll('iframe')).some((frame) => {
    const source = String(frame.getAttribute('src') || '').toLowerCase();
    const title = String(frame.getAttribute('title') || '').toLowerCase();
    return isVisible(frame) && (source.includes('challenges.cloudflare.com') || title.includes('challenge'));
  });
  const formValid = form !== null && typeof form.checkValidity === 'function' ? Boolean(form.checkValidity()) : false;
  const eligible = submit !== null && submitEnabled && formValid && !challengeFramePresent;
  const rect = eligible ? submit.getBoundingClientRect() : null;
  return {
    eligible,
    x: rect === null ? null : rect.left + rect.width / 2,
    y: rect === null ? null : rect.top + rect.height / 2,
  };
})()`

async function dispatchSemanticSubmitClick(socketUrl, timeoutMs) {
  if (typeof globalThis.WebSocket !== 'function') {
    return createFailure('cdp_connect', 'websocket_unavailable')
  }
  let socket
  try {
    socket = new globalThis.WebSocket(socketUrl)
  } catch (_error) {
    return createFailure('cdp_connect', 'open_failed')
  }
  try {
    if (!await waitForSocketOpen(socket, timeoutMs)) {
      return createFailure('cdp_connect', 'open_failed_or_timeout')
    }
    const enabled = await sendCdp(socket, 1, 'Runtime.enable', {}, timeoutMs)
    if (enabled.kind !== 'message' || !isObject(enabled.message) || enabled.message.error !== undefined) {
      return createFailure('runtime_enable', 'failed')
    }
    const evaluated = await sendCdp(socket, 2, 'Runtime.evaluate', {
      expression: SUBMIT_ACTIVATION_EXPRESSION,
      awaitPromise: true,
      returnByValue: true,
    }, timeoutMs)
    if (evaluated.kind !== 'message' || !isObject(evaluated.message) || evaluated.message.error !== undefined) {
      return createFailure('runtime_evaluate', 'failed')
    }
    const protocolResult = evaluated.message.result
    const payload = isObject(protocolResult) && isObject(protocolResult.result)
      ? protocolResult.result.value
      : null
    if (!isObject(payload) || payload.eligible !== true || !Number.isFinite(payload.x) ||
      !Number.isFinite(payload.y) || payload.x < 0 || payload.y < 0 ||
      payload.x > 10000 || payload.y > 10000) {
      return createFailure('action_precondition', 'submit_not_eligible')
    }
    const pressed = await sendCdp(socket, 3, 'Input.dispatchMouseEvent', {
      type: 'mousePressed',
      x: payload.x,
      y: payload.y,
      button: 'left',
      clickCount: 1,
    }, timeoutMs)
    if (pressed.kind !== 'message' || !isObject(pressed.message) || pressed.message.error !== undefined) {
      return createFailure('action_postcondition', 'submit_dispatch_not_confirmed')
    }
    const released = await sendCdp(socket, 4, 'Input.dispatchMouseEvent', {
      type: 'mouseReleased',
      x: payload.x,
      y: payload.y,
      button: 'left',
      clickCount: 1,
    }, timeoutMs)
    if (released.kind !== 'message' || !isObject(released.message) || released.message.error !== undefined) {
      return createFailure('action_postcondition', 'submit_dispatch_not_confirmed')
    }
    return {
      ok: true,
      stage: 'login_field_action',
      loginFormPresent: true,
      accountFieldPresent: true,
      accountFieldFocused: false,
      passwordFieldPresent: true,
      passwordFieldFocused: false,
      passwordFieldMasked: true,
      submitPresent: true,
      submitEnabled: true,
      formValid: true,
      challengeFramePresent: false,
      actionApplied: true,
      submitDispatched: true,
    }
  } finally {
    closeQuietly(socket)
  }
}

function actionExpression(action) {
  // The action string is never interpolated into page JavaScript. These are
  // fixed local statements selected from the parser's closed enum.
  const fixedAction = action === 'focus-account'
    ? 'actionApplied = focusCurrentField(accountField);'
    : action === 'focus-password'
      ? 'actionApplied = focusCurrentField(passwordField);'
      : `if (typeof form.requestSubmit === 'function') {
          form.requestSubmit(submit);
        } else {
          submit.click();
        }
        actionApplied = true;
        submitDispatched = true;`
  const isSubmit = action === 'submit'
  return `(() => {
  const isVisible = (element) => {
    try {
      const style = window.getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      return style.display !== 'none' && style.visibility !== 'hidden' &&
        element.getAttribute('aria-hidden') !== 'true' && rect.width > 0 && rect.height > 0;
    } catch (_error) {
      return false;
    }
  };
  const focusCurrentField = (field) => {
    try {
      field.focus({ preventScroll: true });
    } catch (_error) {
      try {
        field.focus();
      } catch (_fallbackError) {
        return false;
      }
    }
    return document.activeElement === field;
  };
  const visibleInputs = Array.from(document.querySelectorAll('input')).filter(isVisible);
  const passwordFields = visibleInputs.filter((input) =>
    String(input.type || '').toLowerCase() === 'password');
  const accountFields = visibleInputs.filter((input) => {
    const type = String(input.type || 'text').toLowerCase();
    return type === '' || type === 'text' || type === 'email' || type === 'tel' || type === 'search';
  });
  const accountField = accountFields.length === 1 ? accountFields[0] : null;
  const passwordField = passwordFields.length === 1 ? passwordFields[0] : null;
  const form = accountField !== null && passwordField !== null && accountField.form !== null &&
    accountField.form === passwordField.form ? accountField.form : null;
  const submitControls = form === null ? [] : Array.from(form.querySelectorAll('button, input')).filter(isVisible);
  const submitControlsSemantic = submitControls.filter((control) => {
    const tag = String(control.tagName || '').toLowerCase();
    const type = String(control.getAttribute('type') || '').toLowerCase();
    return (tag === 'button' && (type === '' || type === 'submit')) ||
      (tag === 'input' && type === 'submit');
  });
  const submit = submitControlsSemantic.length === 1 ? submitControlsSemantic[0] : null;
  const submitEnabled = submit !== null && !submit.disabled &&
    String(submit.getAttribute('aria-disabled') || '').toLowerCase() !== 'true';
  const challengeFramePresent = Array.from(document.querySelectorAll('iframe')).some((frame) => {
    const source = String(frame.getAttribute('src') || '').toLowerCase();
    const title = String(frame.getAttribute('title') || '').toLowerCase();
    return isVisible(frame) && (source.includes('challenges.cloudflare.com') || title.includes('challenge'));
  });
  const loginFormPresent = form !== null && submit !== null;
  let formValid = null;
  let actionApplied = false;
  let submitDispatched = false;
  if (loginFormPresent) {
    ${isSubmit ? "formValid = typeof form.checkValidity === 'function' ? Boolean(form.checkValidity()) : null;" : ''}
    const canRun = ${isSubmit
      ? 'submitEnabled && formValid === true && !challengeFramePresent'
      : 'true'};
    if (canRun) {
      try {
        ${fixedAction}
      } catch (_error) {
        actionApplied = false;
        submitDispatched = false;
      }
    }
  }
  return {
    loginFormPresent,
    accountFieldPresent: accountField !== null,
    accountFieldFocused: accountField !== null && document.activeElement === accountField,
    passwordFieldPresent: passwordField !== null,
    passwordFieldFocused: passwordField !== null && document.activeElement === passwordField,
    passwordFieldMasked: passwordField !== null && String(passwordField.type || '').toLowerCase() === 'password',
    submitPresent: submit !== null,
    submitEnabled,
    formValid,
    challengeFramePresent,
    actionApplied,
    submitDispatched,
  };
})()`
}

/**
 * This expression is reachable only through the imported, in-process secret
 * API below. `field` is selected from a closed local enum and `secretText` is
 * JSON-quoted before it enters the CDP payload, so it cannot alter the fixed
 * semantic action. The returned object intentionally omits every value-derived
 * field; the separate read-only probe owns filled-state evidence.
 */
function secretFillExpression(field, secretText) {
  const targetField = field === 'account' ? 'accountField' : 'passwordField'
  const secretLiteral = JSON.stringify(secretText)
  return `(() => {
  const isVisible = (element) => {
    try {
      const style = window.getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      return style.display !== 'none' && style.visibility !== 'hidden' &&
        element.getAttribute('aria-hidden') !== 'true' && rect.width > 0 && rect.height > 0;
    } catch (_error) {
      return false;
    }
  };
  const visibleInputs = Array.from(document.querySelectorAll('input')).filter(isVisible);
  const passwordFields = visibleInputs.filter((input) =>
    String(input.type || '').toLowerCase() === 'password');
  const accountFields = visibleInputs.filter((input) => {
    const type = String(input.type || 'text').toLowerCase();
    return type === '' || type === 'text' || type === 'email' || type === 'tel' || type === 'search';
  });
  const accountField = accountFields.length === 1 ? accountFields[0] : null;
  const passwordField = passwordFields.length === 1 ? passwordFields[0] : null;
  const form = accountField !== null && passwordField !== null && accountField.form !== null &&
    accountField.form === passwordField.form ? accountField.form : null;
  const loginFormPresent = form !== null;
  const targetField = ${targetField};
  let fieldInputApplied = false;
  if (loginFormPresent && targetField !== null && document.activeElement === targetField &&
    targetField.value.length === 0) {
    try {
      const descriptor = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
      const nativeSetter = descriptor && typeof descriptor.set === 'function' ? descriptor.set : null;
      if (nativeSetter !== null) {
        nativeSetter.call(targetField, '');
        targetField.dispatchEvent(new Event('input', { bubbles: true }));
        if (targetField.value.length === 0) {
          nativeSetter.call(targetField, ${secretLiteral});
          targetField.dispatchEvent(new Event('input', { bubbles: true }));
          targetField.dispatchEvent(new Event('change', { bubbles: true }));
          fieldInputApplied = targetField.value.length > 0;
        }
      }
    } catch (_error) {
      fieldInputApplied = false;
    }
  }
  return {
    loginFormPresent,
    accountFieldPresent: accountField !== null,
    accountFieldFocused: accountField !== null && document.activeElement === accountField,
    passwordFieldPresent: passwordField !== null,
    passwordFieldFocused: passwordField !== null && document.activeElement === passwordField,
    passwordFieldMasked: passwordField !== null && String(passwordField.type || '').toLowerCase() === 'password',
    fieldInputApplied,
  };
})()`
}

async function selectUniqueLoginFormPage(socketUrls, timeoutMs) {
  const results = []
  for (const socketUrl of socketUrls) {
    const evaluated = await evaluateSingleLocalPage(socketUrl, LOGIN_FORM_SELECTION_EXPRESSION, timeoutMs)
    if (!evaluated.ok) {
      results.push({ ok: false })
      continue
    }
    results.push({ ok: true, loginForm: normalizeLoginFormSelection(evaluated.safePayload).ok })
  }
  const matchingIndexes = results.flatMap((result, index) => result.ok && result.loginForm ? [index] : [])
  if (matchingIndexes.length === 1) {
    return { ok: true, socketUrl: socketUrls[matchingIndexes[0]] }
  }
  if (matchingIndexes.length > 1) {
    return createFailure('page_selection', 'login_form_ambiguous')
  }
  if (results.some((result) => !result.ok)) {
    return createFailure('page_selection', 'page_probe_inconclusive')
  }
  return createFailure('page_selection', 'login_form_absent')
}

function actionPostcondition(action, summary) {
  if (!summary.loginFormPresent) {
    return createFailure('action_precondition', 'login_form_not_unique_or_missing')
  }
  if (action === 'focus-account' && (!summary.actionApplied || !summary.accountFieldFocused)) {
    return createFailure('action_postcondition', 'focus_not_confirmed')
  }
  if (action === 'focus-password' && (!summary.actionApplied || !summary.passwordFieldFocused)) {
    return createFailure('action_postcondition', 'focus_not_confirmed')
  }
  if (action === 'submit') {
    if (!summary.submitEnabled || summary.formValid !== true || summary.challengeFramePresent) {
      return createFailure('action_precondition', 'submit_not_eligible')
    }
    if (!summary.actionApplied || !summary.submitDispatched) {
      return createFailure('action_postcondition', 'submit_dispatch_not_confirmed')
    }
  }
  return summary
}

function secretFillPostcondition(field, summary) {
  if (!summary.loginFormPresent) {
    return createFailure('secret_field_precondition', 'login_form_not_unique_or_missing')
  }
  const focused = field === 'account' ? summary.accountFieldFocused : summary.passwordFieldFocused
  if (!focused) {
    return createFailure('secret_field_precondition', 'field_focus_not_current')
  }
  if (!summary.fieldInputApplied) {
    return createFailure('secret_field_postcondition', 'secret_input_not_confirmed')
  }
  return summary
}

/**
 * Selects a unique current login document using a read-only CDP evaluation,
 * then reconnects to that page and executes exactly one fixed non-secret
 * action. It creates no forwarding and never accepts or returns credentials.
 */
export async function runDriver({ port, action, timeoutMs }, transport = {}) {
  if (!Number.isInteger(port) || !ALLOWED_ACTIONS.has(action) ||
    !Number.isInteger(timeoutMs) || timeoutMs < MIN_TIMEOUT_MS || timeoutMs > MAX_TIMEOUT_MS) {
    return createFailure('arguments', 'invalid_arguments')
  }
  const discovery = await fetchLocalPages(port, timeoutMs, transport)
  if (!discovery.ok) {
    return createFailure('devtools_discovery', discovery.code)
  }
  const selection = selectLocalPages(discovery.pages, port)
  if (selection.socketUrls === undefined) {
    return createFailure('page_selection', selection.code)
  }
  const selected = await selectUniqueLoginFormPage(selection.socketUrls, timeoutMs)
  if (!selected.ok) {
    return selected
  }
  // `submit` deliberately does not establish credential-fill state: doing so
  // would require inspecting DOM values. Its caller must therefore first use
  // the separate read-only probe's `submitEligible=true` result in the same
  // volatile protocol epoch, then treat any post-dispatch transport loss as a
  // possible issued submit rather than retrying.
  if (action === 'submit') {
    return await dispatchSemanticSubmitClick(selected.socketUrl, timeoutMs)
  }
  const evaluated = await evaluateSingleLocalPage(selected.socketUrl, actionExpression(action), timeoutMs)
  if (!evaluated.ok) {
    return evaluated
  }
  const summary = normalizeDriverSummary(evaluated.safePayload)
  if (!summary.ok) {
    return summary
  }
  return actionPostcondition(action, summary)
}

/**
 * Imported-only secret path used by the Keychain epoch orchestrator. It has no
 * CLI parser or raw-secret argument. Ownership of `secretBytes` transfers to
 * this function; it clears the caller-owned byte buffer before returning.
 */
export async function runSecretFieldFill({ port, field, secretBytes, timeoutMs }, transport = {}) {
  if (!Number.isInteger(port) || !SECRET_FIELDS.has(field) ||
    !Number.isInteger(timeoutMs) || timeoutMs < MIN_TIMEOUT_MS || timeoutMs > MAX_TIMEOUT_MS) {
    wipeSecretBytes(secretBytes)
    return createFailure('arguments', 'invalid_arguments')
  }
  let secretText = decodeSecretBytes(secretBytes)
  if (secretText === null) {
    wipeSecretBytes(secretBytes)
    return createFailure('secret_handle', 'invalid_secret_bytes')
  }
  try {
    const discovery = await fetchLocalPages(port, timeoutMs, transport)
    if (!discovery.ok) {
      return createFailure('devtools_discovery', discovery.code)
    }
    const selection = selectLocalPages(discovery.pages, port)
    if (selection.socketUrls === undefined) {
      return createFailure('page_selection', selection.code)
    }
    const selected = await selectUniqueLoginFormPage(selection.socketUrls, timeoutMs)
    if (!selected.ok) {
      return selected
    }
    const evaluated = await evaluateSingleLocalPage(
      selected.socketUrl,
      secretFillExpression(field, secretText),
      timeoutMs,
    )
    if (!evaluated.ok) {
      return evaluated
    }
    const summary = normalizeSecretFillSummary(evaluated.safePayload)
    if (!summary.ok) {
      return summary
    }
    return secretFillPostcondition(field, summary)
  } finally {
    // JavaScript strings cannot be synchronously zeroized, but this is the
    // last reference held by this driver and it is never serialized, logged,
    // persisted, or returned. The mutable source bytes are cleared exactly
    // here even on CDP failure.
    secretText = ''
    wipeSecretBytes(secretBytes)
  }
}

function usage() {
  return 'Usage: node scripts/drive_arkweb_login_field.mjs --port <local-devtools-port> --action <focus-account|focus-password|submit> [--timeout-ms 500..15000]'
}

async function runCli() {
  if (process.argv.slice(2).length === 1 && process.argv[2] === '--help') {
    process.stdout.write(`${usage()}\n`)
    return 0
  }
  const options = parseArguments(process.argv.slice(2))
  if (options === null) {
    process.stdout.write(`${JSON.stringify(createFailure('arguments', 'invalid_arguments'))}\n`)
    return 1
  }
  const result = await runDriver(options)
  process.stdout.write(`${JSON.stringify(result)}\n`)
  return result.ok ? 0 : 1
}

const invokedPath = process.argv[1] === undefined ? '' : pathToFileURL(process.argv[1]).href
if (import.meta.url === invokedPath) {
  runCli().then((exitCode) => {
    process.exitCode = exitCode
  }).catch(() => {
    process.stdout.write(`${JSON.stringify(createFailure('runtime', 'unexpected_failure'))}\n`)
    process.exitCode = 1
  })
}
