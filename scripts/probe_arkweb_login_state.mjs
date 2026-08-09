#!/usr/bin/env node

import { request as httpRequest } from 'node:http'
import { pathToFileURL } from 'node:url'

const DEFAULT_TIMEOUT_MS = 4000
const MIN_TIMEOUT_MS = 500
const MAX_TIMEOUT_MS = 15000
const MAX_DISCOVERY_BYTES = 1024 * 1024
const MAX_LOCAL_PAGE_TARGETS = 2

// Failure values are deliberately fixed enums. They distinguish a broken
// forwarding/discovery path from an ambiguous ArkWeb target set without
// emitting HTTP details, target metadata, URLs, titles, or page content.
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
  'two_target_login_form_absent',
  'two_target_login_form_ambiguous',
  'two_target_probe_inconclusive',
]

export const SAFE_OUTPUT_KEYS = [
  'ok',
  'stage',
  'loginFormPresent',
  'accountFieldPresent',
  'accountFieldFocused',
  'accountFieldFilled',
  'passwordFieldPresent',
  'passwordFieldFocused',
  'passwordFieldFilled',
  'passwordFieldMasked',
  'submitPresent',
  'submitEnabled',
  'formValid',
  'challengeFramePresent',
  'errorMarkerPresent',
  'submitEligible',
]

// This expression is intentionally read-only. Its returned object has only
// booleans/null, and normalizeProbeSummary independently enforces that shape
// before anything reaches stdout.
const LOGIN_STATE_EXPRESSION = `(() => {
  const isVisible = (element) => {
    try {
      const style = window.getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      return style.display !== 'none' && style.visibility !== 'hidden' &&
        rect.width > 0 && rect.height > 0;
    } catch (_error) {
      return false;
    }
  };
  const visibleInputs = Array.from(document.querySelectorAll('input')).filter(isVisible);
  const passwordField = visibleInputs.find((input) =>
    String(input.type || '').toLowerCase() === 'password') || null;
  const accountField = visibleInputs.find((input) => {
    const type = String(input.type || 'text').toLowerCase();
    return input !== passwordField &&
      (type === '' || type === 'text' || type === 'email' || type === 'tel' || type === 'search');
  }) || null;
  const form = (passwordField && passwordField.form) ||
    (accountField && accountField.form) || null;
  const submitControls = form === null ? [] : Array.from(form.querySelectorAll('button, input'));
  const submit = submitControls.find((control) => {
    const tag = String(control.tagName || '').toLowerCase();
    const type = String(control.getAttribute('type') || '').toLowerCase();
    return (tag === 'button' && (type === '' || type === 'submit')) ||
      (tag === 'input' && type === 'submit');
  }) || null;
  const submitEnabled = submit !== null && !submit.disabled &&
    String(submit.getAttribute('aria-disabled') || '').toLowerCase() !== 'true';
  const formValid = form !== null && typeof form.checkValidity === 'function'
    ? Boolean(form.checkValidity())
    : null;
  const challengeFramePresent = Array.from(document.querySelectorAll('iframe')).some((frame) => {
    const source = String(frame.getAttribute('src') || '').toLowerCase();
    const title = String(frame.getAttribute('title') || '').toLowerCase();
    return source.includes('challenges.cloudflare.com') || title.includes('challenge');
  });
  const errorMarkerPresent = document.querySelector(
    '[role="alert"], [aria-invalid="true"], .error, .errors, .invalid, .validation-error'
  ) !== null;
  const accountFieldFilled = accountField !== null && accountField.value.length > 0;
  const passwordFieldFilled = passwordField !== null && passwordField.value.length > 0;
  const passwordFieldMasked = passwordField !== null &&
    String(passwordField.type || '').toLowerCase() === 'password';
  return {
    loginFormPresent: form !== null && accountField !== null && passwordField !== null,
    accountFieldPresent: accountField !== null,
    accountFieldFocused: accountField !== null && document.activeElement === accountField,
    accountFieldFilled,
    passwordFieldPresent: passwordField !== null,
    passwordFieldFocused: passwordField !== null && document.activeElement === passwordField,
    passwordFieldFilled,
    passwordFieldMasked,
    submitPresent: submit !== null,
    submitEnabled,
    formValid,
    challengeFramePresent,
    errorMarkerPresent,
    submitEligible: accountField !== null && passwordField !== null && submit !== null &&
      accountFieldFilled && passwordFieldFilled && passwordFieldMasked && submitEnabled && formValid === true,
  };
})()`

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}

function strictBoolean(value) {
  return value === true
}

function nullableBoolean(value) {
  if (value === true || value === false) {
    return value
  }
  return null
}

export function createFailure(stage, code) {
  return { ok: false, stage, code }
}

/**
 * Discards every unapproved CDP property, including values, URLs, titles,
 * cookies, and error text. submitEligible is recomputed instead of trusted.
 */
export function normalizeProbeSummary(value) {
  if (!isObject(value)) {
    return createFailure('runtime_evaluate', 'invalid_safe_result')
  }
  const accountFieldPresent = strictBoolean(value.accountFieldPresent)
  const accountFieldFocused = accountFieldPresent && strictBoolean(value.accountFieldFocused)
  const accountFieldFilled = accountFieldPresent && strictBoolean(value.accountFieldFilled)
  const passwordFieldPresent = strictBoolean(value.passwordFieldPresent)
  const passwordFieldFocused = passwordFieldPresent && strictBoolean(value.passwordFieldFocused)
  const passwordFieldFilled = passwordFieldPresent && strictBoolean(value.passwordFieldFilled)
  const passwordFieldMasked = passwordFieldPresent && strictBoolean(value.passwordFieldMasked)
  const submitPresent = strictBoolean(value.submitPresent)
  const submitEnabled = submitPresent && strictBoolean(value.submitEnabled)
  const formValid = nullableBoolean(value.formValid)
  const loginFormPresent = strictBoolean(value.loginFormPresent) &&
    accountFieldPresent && passwordFieldPresent
  const submitEligible = loginFormPresent && accountFieldFilled && passwordFieldFilled &&
    passwordFieldMasked && submitPresent && submitEnabled && formValid === true
  return {
    ok: true,
    stage: 'login_probe',
    loginFormPresent,
    accountFieldPresent,
    accountFieldFocused,
    accountFieldFilled,
    passwordFieldPresent,
    passwordFieldFocused,
    passwordFieldFilled,
    passwordFieldMasked,
    submitPresent,
    submitEnabled,
    formValid,
    challengeFramePresent: strictBoolean(value.challengeFramePresent),
    errorMarkerPresent: strictBoolean(value.errorMarkerPresent),
    submitEligible,
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
  return port === null ? null : { port, timeoutMs }
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
      const remainingTimeoutMs = Math.max(1, timeoutMs - (Date.now() - startedAt))
      return fetchLocalPagesWithNodeHttp(port, remainingTimeoutMs, transport.httpRequestImpl)
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
 * ArkWeb DevTools forwards can reject the Undici fetch transport while still
 * serving the same bounded /json response to a simple HTTP/1.1 request. This
 * fallback is loopback-only, sends Connection: close, preserves the original
 * total timeout budget, and never returns the endpoint body or error text.
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
        if (settled) {
          return
        }
        finish(parseDiscoveredPages(Buffer.concat(chunks).toString('utf8')))
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
    // The probe must not disclose a transport error or leave it as output.
  }
}

async function probeSingleLocalPage(socketUrl, timeoutMs) {
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
      expression: LOGIN_STATE_EXPRESSION,
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
    return normalizeProbeSummary(result.result.value)
  } finally {
    closeQuietly(socket)
  }
}

/**
 * ArkWeb can expose the visible document alongside one auxiliary page target.
 * When there are exactly two local `page` targets, probe both read-only and
 * select only a unique target that independently reports the login form.
 * The raw target metadata and individual probe results remain in-process.
 */
async function probeSelectedPages(socketUrls, timeoutMs) {
  if (socketUrls.length === 1) {
    return probeSingleLocalPage(socketUrls[0], timeoutMs)
  }
  const results = []
  for (const socketUrl of socketUrls) {
    results.push(await probeSingleLocalPage(socketUrl, timeoutMs))
  }
  const loginFormResults = results.filter((result) => result.ok && result.loginFormPresent)
  if (loginFormResults.length === 1) {
    return loginFormResults[0]
  }
  if (loginFormResults.length > 1) {
    return createFailure('page_selection', 'two_target_login_form_ambiguous')
  }
  if (results.some((result) => !result.ok)) {
    return createFailure('page_selection', 'two_target_probe_inconclusive')
  }
  return createFailure('page_selection', 'two_target_login_form_absent')
}

export async function runProbe({ port, timeoutMs }, transport = {}) {
  const discovery = await fetchLocalPages(port, timeoutMs, transport)
  if (!discovery.ok) {
    return createFailure('devtools_discovery', discovery.code)
  }
  const selection = selectLocalPages(discovery.pages, port)
  if (selection.socketUrls === undefined) {
    return createFailure('page_selection', selection.code)
  }
  return probeSelectedPages(selection.socketUrls, timeoutMs)
}

function usage() {
  return 'Usage: node scripts/probe_arkweb_login_state.mjs --port <local-devtools-port> [--timeout-ms 500..15000]'
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
  const result = await runProbe(options)
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
