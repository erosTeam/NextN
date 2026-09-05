#!/usr/bin/env node

import { pathToFileURL } from 'node:url'
import {
  closeQuietly,
  createFailure,
  fetchLocalPages,
  isObject,
  selectLocalPages,
  sendCdp,
  waitForSocketOpen,
} from './probe_arkweb_login_state.mjs'

const DEFAULT_TIMEOUT_MS = 8000
const MIN_TIMEOUT_MS = 500
const MAX_TIMEOUT_MS = 15000

// The expression uses only public, non-secret form structure. It never returns
// DOM text, field values, challenge values, URLs, cookies or response content.
// The Key Name label, capture bridge and ready challenge must all belong to the
// current official settings document before the sole Create Key control is
// considered eligible.
const API_KEY_CREATE_STATE_EXPRESSION = `(() => {
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
  const labels = Array.from(document.querySelectorAll('label')).filter((label) =>
    String(label.textContent || '').trim() === 'Key Name');
  const label = labels.length === 1 ? labels[0] : null;
  const labelFor = label === null ? '' : String(label.getAttribute('for') || '');
  const field = labelFor.length === 0 ? null : document.getElementById(labelFor);
  const fieldReady = field instanceof HTMLInputElement && isVisible(field) &&
    String(field.value || '').trim().length > 0;
  const challenge = document.querySelector(
    'input[name="cf-turnstile-response"], textarea[name="cf-turnstile-response"]'
  );
  const challengeReady = challenge !== null &&
    String(challenge.value || '').trim().length > 0;
  const buttons = Array.from(document.querySelectorAll('button, input[type="submit"]')).filter((control) => {
    if (!isVisible(control)) {
      return false;
    }
    const labelText = control instanceof HTMLInputElement
      ? String(control.value || '')
      : String(control.textContent || '');
    return labelText.trim().toLowerCase() === 'create key';
  });
  const button = buttons.length === 1 ? buttons[0] : null;
  const buttonEnabled = button !== null && !button.disabled &&
    String(button.getAttribute('aria-disabled') || '').toLowerCase() !== 'true';
  const loginFormAbsent = Array.from(document.querySelectorAll('input')).filter(isVisible)
    .every((input) => String(input.type || '').toLowerCase() !== 'password');
  const officialSettings = location.origin === 'https://nhentai.net' &&
    location.pathname === '/user/settings';
  const bridgeInstalled = window.__nextNApiKeyCaptureInstalled === true;
  return {
    officialSettings,
    loginFormAbsent,
    keyNameLabelUnique: labels.length === 1,
    keyNameFieldReady: fieldReady,
    challengeReady,
    createControlUnique: buttons.length === 1,
    createControlEnabled: buttonEnabled,
    bridgeInstalled,
    eligible: officialSettings && loginFormAbsent && labels.length === 1 &&
      fieldReady && challengeReady && buttons.length === 1 && buttonEnabled && bridgeInstalled,
  };
})()`

const API_KEY_CREATE_ACTION_EXPRESSION = `(() => {
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
  const labels = Array.from(document.querySelectorAll('label')).filter((label) =>
    String(label.textContent || '').trim() === 'Key Name');
  const label = labels.length === 1 ? labels[0] : null;
  const labelFor = label === null ? '' : String(label.getAttribute('for') || '');
  const field = labelFor.length === 0 ? null : document.getElementById(labelFor);
  const fieldReady = field instanceof HTMLInputElement && isVisible(field) &&
    String(field.value || '').trim().length > 0;
  const challenge = document.querySelector(
    'input[name="cf-turnstile-response"], textarea[name="cf-turnstile-response"]'
  );
  const challengeReady = challenge !== null &&
    String(challenge.value || '').trim().length > 0;
  const buttons = Array.from(document.querySelectorAll('button, input[type="submit"]')).filter((control) => {
    if (!isVisible(control)) {
      return false;
    }
    const labelText = control instanceof HTMLInputElement
      ? String(control.value || '')
      : String(control.textContent || '');
    return labelText.trim().toLowerCase() === 'create key';
  });
  const button = buttons.length === 1 ? buttons[0] : null;
  const buttonEnabled = button !== null && !button.disabled &&
    String(button.getAttribute('aria-disabled') || '').toLowerCase() !== 'true';
  const loginFormAbsent = Array.from(document.querySelectorAll('input')).filter(isVisible)
    .every((input) => String(input.type || '').toLowerCase() !== 'password');
  const eligible = location.origin === 'https://nhentai.net' &&
    location.pathname === '/user/settings' && loginFormAbsent && labels.length === 1 &&
    fieldReady && challengeReady && buttons.length === 1 && buttonEnabled &&
    window.__nextNApiKeyCaptureInstalled === true;
  const rect = eligible ? button.getBoundingClientRect() : null;
  return {
    eligible,
    x: rect === null ? null : rect.left + rect.width / 2,
    y: rect === null ? null : rect.top + rect.height / 2,
  };
})()`

function strictState(value) {
  if (!isObject(value)) {
    return createFailure('runtime_evaluate', 'invalid_safe_result')
  }
  return {
    ok: true,
    officialSettings: value.officialSettings === true,
    loginFormAbsent: value.loginFormAbsent === true,
    keyNameLabelUnique: value.keyNameLabelUnique === true,
    keyNameFieldReady: value.keyNameFieldReady === true,
    challengeReady: value.challengeReady === true,
    createControlUnique: value.createControlUnique === true,
    createControlEnabled: value.createControlEnabled === true,
    bridgeInstalled: value.bridgeInstalled === true,
    eligible: value.eligible === true,
  }
}

async function evaluate(socketUrl, expression, timeoutMs) {
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
    return { ok: true, value: result.result.value }
  } finally {
    closeQuietly(socket)
  }
}

async function dispatchSemanticCreateClick(socketUrl, timeoutMs) {
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
      expression: API_KEY_CREATE_ACTION_EXPRESSION,
      awaitPromise: true,
      returnByValue: true,
    }, timeoutMs)
    const protocolResult = evaluated.kind === 'message' && isObject(evaluated.message)
      ? evaluated.message.result : undefined
    const payload = isObject(protocolResult) && isObject(protocolResult.result)
      ? protocolResult.result.value : undefined
    if (!isObject(payload) || payload.eligible !== true || !Number.isFinite(payload.x) ||
      !Number.isFinite(payload.y) || payload.x < 0 || payload.y < 0 ||
      payload.x > 10000 || payload.y > 10000) {
      return createFailure('action_precondition', 'api_key_create_not_eligible')
    }
    const moved = await sendCdp(socket, 3, 'Input.dispatchMouseEvent', {
      type: 'mouseMoved',
      x: payload.x,
      y: payload.y,
    }, timeoutMs)
    const pressed = await sendCdp(socket, 4, 'Input.dispatchMouseEvent', {
      type: 'mousePressed',
      x: payload.x,
      y: payload.y,
      button: 'left',
      buttons: 1,
      clickCount: 1,
    }, timeoutMs)
    const released = await sendCdp(socket, 5, 'Input.dispatchMouseEvent', {
      type: 'mouseReleased',
      x: payload.x,
      y: payload.y,
      button: 'left',
      buttons: 0,
      clickCount: 1,
    }, timeoutMs)
    const accepted = [moved, pressed, released].every((result) =>
      result.kind === 'message' && isObject(result.message) && result.message.error === undefined)
    return accepted
      ? { ok: true, submitDispatched: true }
      : createFailure('action_postcondition', 'submit_outcome_unknown_do_not_retry')
  } finally {
    closeQuietly(socket)
  }
}

function parseArguments(argv) {
  let port = null
  let timeoutMs = DEFAULT_TIMEOUT_MS
  for (let index = 0; index < argv.length; index += 1) {
    const option = argv[index]
    if (option === '--port' && /^\d+$/.test(argv[index + 1] || '') && port === null) {
      port = Number(argv[index + 1])
      index += 1
      continue
    }
    if (option === '--timeout-ms' && /^\d+$/.test(argv[index + 1] || '')) {
      timeoutMs = Number(argv[index + 1])
      index += 1
      continue
    }
    return null
  }
  return Number.isInteger(port) && port >= 1 && port <= 65535 &&
    Number.isInteger(timeoutMs) && timeoutMs >= MIN_TIMEOUT_MS && timeoutMs <= MAX_TIMEOUT_MS
    ? { port, timeoutMs }
    : null
}

export async function runApiKeyCreateOnce({ port, timeoutMs }) {
  const discovery = await fetchLocalPages(port, timeoutMs)
  if (!discovery.ok) {
    return createFailure('devtools_discovery', discovery.code)
  }
  const selection = selectLocalPages(discovery.pages, port)
  if (selection.socketUrls === undefined) {
    return createFailure('page_selection', selection.code)
  }
  const states = []
  for (const socketUrl of selection.socketUrls) {
    const result = await evaluate(socketUrl, API_KEY_CREATE_STATE_EXPRESSION, timeoutMs)
    states.push(result.ok ? strictState(result.value) : result)
  }
  const matchingIndexes = states.flatMap((state, index) => state.ok && state.eligible ? [index] : [])
  if (matchingIndexes.length !== 1) {
    return createFailure('action_precondition', matchingIndexes.length > 1
      ? 'api_key_page_ambiguous'
      : states.some((state) => !state.ok) ? 'page_probe_inconclusive' : 'api_key_create_not_eligible')
  }
  const action = await dispatchSemanticCreateClick(
    selection.socketUrls[matchingIndexes[0]],
    timeoutMs,
  )
  if (!action.ok) {
    // A navigation can close the transport after dispatch. The caller must
    // inspect product-redacted promotion evidence and must never retry.
    return createFailure('action_postcondition', 'submit_outcome_unknown_do_not_retry')
  }
  const applied = action.submitDispatched === true
  return applied
    ? { ok: true, stage: 'api_key_create', preconditionsMet: true, submitDispatched: true }
    : createFailure('action_postcondition', 'submit_not_dispatched_do_not_retry')
}

function usage() {
  return 'Usage: node scripts/submit_arkweb_api_key_once.mjs --port <local-devtools-port> [--timeout-ms 500..15000]'
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
  const result = await runApiKeyCreateOnce(options)
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
