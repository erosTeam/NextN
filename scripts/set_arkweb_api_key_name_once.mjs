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
const MAX_NAME_LENGTH = 120

function buildStateExpression(expectedName) {
  const expectedNameLiteral = JSON.stringify(expectedName)
  return `(() => {
    const expectedName = ${expectedNameLiteral};
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
    const normalized = (value) => String(value || '').trim().toLowerCase().replace(/\\s+/g, ' ');
    const labels = Array.from(document.querySelectorAll('label')).filter((label) =>
      normalized(label.textContent) === 'key name');
    const label = labels.length === 1 ? labels[0] : null;
    const labelFor = label === null ? '' : String(label.getAttribute('for') || '');
    const field = labelFor.length === 0 ? null : document.getElementById(labelFor);
    const controls = Array.from(document.querySelectorAll(
      'button, a, input[type="button"], input[type="submit"]'
    )).filter(isVisible);
    const revokeControls = controls.filter((control) => {
      const texts = [
        control.getAttribute('aria-label'),
        control.getAttribute('title'),
        control instanceof HTMLInputElement ? control.value : control.textContent,
      ].map(normalized).filter((value) => value.length > 0);
      return texts.some((value) => /(^|\\b)(revoke|disable|delete|remove)(\\b|$)/.test(value));
    });
    const rowFor = (control) => control.closest(
      'tr, li, [role="row"], form, [data-key-id], [data-api-key-id]'
    ) || control.parentElement;
    const expectedRows = new Set(revokeControls.map(rowFor).filter((row) =>
      row !== null && String(row.textContent || '').includes(expectedName)));
    const visibleInputs = Array.from(document.querySelectorAll('input')).filter(isVisible);
    const loginFormAbsent = visibleInputs.every((input) =>
      String(input.type || '').toLowerCase() !== 'password');
    const officialSettings = location.origin === 'https://nhentai.net' &&
      location.pathname === '/user/settings';
    const fieldReady = field instanceof HTMLInputElement && isVisible(field) &&
      field.form === null;
    return {
      officialSettings,
      loginFormAbsent,
      keyNameLabelUnique: labels.length === 1,
      keyNameFieldReady: fieldReady,
      expectedNameAlreadyApplied: fieldReady && String(field.value || '').trim() === expectedName,
      existingExpectedNameRowAbsent: expectedRows.size === 0,
      eligible: officialSettings && loginFormAbsent && labels.length === 1 && fieldReady &&
        expectedRows.size === 0,
    };
  })()`
}

function buildActionExpression(expectedName) {
  const expectedNameLiteral = JSON.stringify(expectedName)
  return `(() => {
    const expectedName = ${expectedNameLiteral};
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
      String(label.textContent || '').trim().toLowerCase().replace(/\\s+/g, ' ') === 'key name');
    const label = labels.length === 1 ? labels[0] : null;
    const labelFor = label === null ? '' : String(label.getAttribute('for') || '');
    const field = labelFor.length === 0 ? null : document.getElementById(labelFor);
    const eligible = location.origin === 'https://nhentai.net' &&
      location.pathname === '/user/settings' && labels.length === 1 &&
      field instanceof HTMLInputElement && isVisible(field) && field.form === null &&
      Array.from(document.querySelectorAll('input')).filter(isVisible).every((input) =>
        String(input.type || '').toLowerCase() !== 'password');
    let applied = false;
    if (eligible) {
      const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')?.set;
      if (typeof setter === 'function') {
        setter.call(field, expectedName);
        field.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText' }));
        field.dispatchEvent(new Event('change', { bubbles: true }));
        field.blur();
        applied = String(field.value || '').trim() === expectedName;
      }
    }
    return { eligible, applied };
  })()`
}

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
    expectedNameAlreadyApplied: value.expectedNameAlreadyApplied === true,
    existingExpectedNameRowAbsent: value.existingExpectedNameRowAbsent === true,
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

function parseArguments(argv) {
  let port = null
  let expectedName = ''
  let timeoutMs = DEFAULT_TIMEOUT_MS
  for (let index = 0; index < argv.length; index += 1) {
    const option = argv[index]
    if (option === '--port' && /^\d+$/.test(argv[index + 1] || '') && port === null) {
      port = Number(argv[index + 1])
      index += 1
      continue
    }
    if (option === '--name' && expectedName.length === 0) {
      expectedName = String(argv[index + 1] || '').trim()
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
    expectedName.length > 0 && expectedName.length <= MAX_NAME_LENGTH &&
    Number.isInteger(timeoutMs) && timeoutMs >= MIN_TIMEOUT_MS && timeoutMs <= MAX_TIMEOUT_MS
    ? { port, expectedName, timeoutMs }
    : null
}

export async function runSetApiKeyNameOnce({ port, expectedName, timeoutMs }) {
  const discovery = await fetchLocalPages(port, timeoutMs)
  if (!discovery.ok) {
    return createFailure('devtools_discovery', discovery.code)
  }
  const selection = selectLocalPages(discovery.pages, port)
  if (selection.socketUrls === undefined) {
    return createFailure('page_selection', selection.code)
  }
  const states = []
  const expression = buildStateExpression(expectedName)
  for (const socketUrl of selection.socketUrls) {
    const result = await evaluate(socketUrl, expression, timeoutMs)
    states.push(result.ok ? strictState(result.value) : result)
  }
  const matchingIndexes = states.flatMap((state, index) => state.ok && state.eligible ? [index] : [])
  if (matchingIndexes.length !== 1) {
    return createFailure('action_precondition', matchingIndexes.length > 1
      ? 'api_key_page_ambiguous'
      : states.some((state) => !state.ok) ? 'page_probe_inconclusive' : 'api_key_name_not_eligible')
  }
  const selectedIndex = matchingIndexes[0]
  if (!states[selectedIndex].expectedNameAlreadyApplied) {
    const action = await evaluate(
      selection.socketUrls[selectedIndex],
      buildActionExpression(expectedName),
      timeoutMs,
    )
    if (!action.ok || !isObject(action.value) || action.value.eligible !== true ||
      action.value.applied !== true) {
      return createFailure('action_postcondition', 'name_not_applied')
    }
  }
  await new Promise((resolve) => setTimeout(resolve, 250))
  const verified = await evaluate(selection.socketUrls[selectedIndex], expression, timeoutMs)
  if (!verified.ok) {
    return createFailure('action_postcondition', 'name_stability_unknown')
  }
  const state = strictState(verified.value)
  return state.ok && state.eligible && state.expectedNameAlreadyApplied
    ? {
        ok: true,
        stage: 'api_key_name',
        preconditionsMet: true,
        nameApplied: true,
        nameStable: true,
        existingExpectedNameRowAbsent: state.existingExpectedNameRowAbsent,
      }
    : createFailure('action_postcondition', 'name_not_stable')
}

function usage() {
  return 'Usage: node scripts/set_arkweb_api_key_name_once.mjs --port <local-devtools-port> --name <non-secret-name> [--timeout-ms 500..15000]'
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
  const result = await runSetApiKeyNameOnce(options)
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
