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
const MAX_EXPECTED_NAME_LENGTH = 160

export function buildExpression(expectedName) {
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
    const visibleInputs = Array.from(document.querySelectorAll('input')).filter(isVisible);
    const loginFormAbsent = visibleInputs.every((input) =>
      String(input.type || '').toLowerCase() !== 'password');
    const controls = Array.from(document.querySelectorAll(
      'button, a, input[type="button"], input[type="submit"]'
    )).filter(isVisible);
    const actionKind = (control) => {
      const labels = [
        control.getAttribute('aria-label'),
        control.getAttribute('title'),
        control instanceof HTMLInputElement ? control.value : control.textContent,
      ].map(normalized).filter((value) => value.length > 0);
      if (labels.some((value) => /(^|\\b)(revoke|disable)(\\b|$)/.test(value))) {
        return 'revoke';
      }
      if (labels.some((value) => /(^|\\b)(delete|remove)(\\b|$)/.test(value))) {
        return 'delete';
      }
      const form = control.closest('form');
      if (form instanceof HTMLFormElement) {
        try {
          const action = new URL(form.action || location.href, location.href);
          const method = normalized(form.method);
          if (action.origin === location.origin &&
            /^\\/api\\/v2\\/user\\/keys(?:\\/|$)/.test(action.pathname) &&
            (method === 'delete' || method === 'post')) {
            return 'key-action';
          }
        } catch (_error) {}
      }
      return '';
    };
    const candidateControls = controls.map((control) => ({
      control,
      kind: actionKind(control),
    })).filter((candidate) => candidate.kind.length > 0);
    const rowFor = (control) => control.closest(
      'tr, li, [role="row"], form, [data-key-id], [data-api-key-id]'
    ) || control.parentElement;
    const rowHasExpectedName = (control) => {
      const row = rowFor(control);
      return row !== null && expectedName.length > 0 &&
        String(row.textContent || '').includes(expectedName);
    };
    const expectedNameActionCount = candidateControls.filter((candidate) =>
      rowHasExpectedName(candidate.control)).length;
    const expectedNameRows = new Set(candidateControls
      .filter((candidate) => rowHasExpectedName(candidate.control))
      .map((candidate) => rowFor(candidate.control))
      .filter((row) => row !== null));
    const expectedCandidates = candidateControls.filter((candidate) =>
      rowHasExpectedName(candidate.control));
    const expectedControl = expectedNameRows.size === 1 && expectedCandidates.length === 1
      ? expectedCandidates[0].control
      : null;
    const expectedForm = expectedControl === null ? null : expectedControl.closest('form');
    let expectedActionFormPost = false;
    let expectedActionFormKeyEndpoint = false;
    if (expectedForm instanceof HTMLFormElement) {
      expectedActionFormPost = normalized(expectedForm.method) === 'post';
      try {
        const action = new URL(expectedForm.action || location.href, location.href);
        expectedActionFormKeyEndpoint = action.origin === location.origin &&
          /^\\/api\\/v2\\/user\\/keys(?:\\/|$)/.test(action.pathname);
      } catch (_error) {}
    }
    let expectedActionHrefKeyEndpoint = false;
    if (expectedControl instanceof HTMLAnchorElement) {
      try {
        const target = new URL(expectedControl.href, location.href);
        expectedActionHrefKeyEndpoint = target.origin === location.origin &&
          /^\\/api\\/v2\\/user\\/keys(?:\\/|$)/.test(target.pathname);
      } catch (_error) {}
    }
    const expectedActionHasInlineConfirmation = expectedControl !== null && [
      expectedControl.getAttribute('onclick'),
      expectedControl.getAttribute('data-confirm'),
      expectedControl.getAttribute('data-turbo-confirm'),
      expectedControl.getAttribute('hx-confirm'),
    ].some((value) => normalized(value).includes('confirm'));
    return {
      officialSettings: location.origin === 'https://nhentai.net' &&
        location.pathname === '/user/settings',
      loginFormAbsent,
      keyNameFieldPresent: Array.from(document.querySelectorAll('label')).some((label) =>
        normalized(label.textContent) === 'key name'),
      visibleControlCount: controls.length,
      candidateActionCount: candidateControls.length,
      revokeActionCount: candidateControls.filter((candidate) =>
        candidate.kind === 'revoke').length,
      deleteActionCount: candidateControls.filter((candidate) =>
        candidate.kind === 'delete').length,
      structuralKeyActionCount: candidateControls.filter((candidate) =>
        candidate.kind === 'key-action').length,
      expectedNameRowCount: expectedNameRows.size,
      expectedNameActionCount,
      uniqueExpectedNameAction: expectedNameRows.size === 1 && expectedNameActionCount === 1,
      expectedActionIsButton: expectedControl instanceof HTMLButtonElement,
      expectedActionIsLink: expectedControl instanceof HTMLAnchorElement,
      expectedActionTypeSubmit: expectedControl !== null &&
        normalized(expectedControl.getAttribute('type')) === 'submit',
      expectedActionEnabled: expectedControl !== null && !expectedControl.disabled &&
        normalized(expectedControl.getAttribute('aria-disabled')) !== 'true',
      expectedActionInsideForm: expectedForm instanceof HTMLFormElement,
      expectedActionFormPost,
      expectedActionFormKeyEndpoint,
      expectedActionHrefKeyEndpoint,
      expectedActionHasInlineConfirmation,
      confirmationSurfacePresent: Array.from(document.querySelectorAll(
        '[role="dialog"], dialog, [aria-modal="true"]'
      )).some(isVisible),
    };
  })()`
}

export function strictResult(value) {
  if (!isObject(value)) {
    return createFailure('runtime_evaluate', 'invalid_safe_result')
  }
  const count = (field) => Number.isInteger(value[field]) && value[field] >= 0
    ? value[field]
    : 0
  return {
    ok: true,
    officialSettings: value.officialSettings === true,
    loginFormAbsent: value.loginFormAbsent === true,
    keyNameFieldPresent: value.keyNameFieldPresent === true,
    visibleControlCount: count('visibleControlCount'),
    candidateActionCount: count('candidateActionCount'),
    revokeActionCount: count('revokeActionCount'),
    deleteActionCount: count('deleteActionCount'),
    structuralKeyActionCount: count('structuralKeyActionCount'),
    expectedNameRowCount: count('expectedNameRowCount'),
    expectedNameActionCount: count('expectedNameActionCount'),
    uniqueExpectedNameAction: value.uniqueExpectedNameAction === true,
    expectedActionIsButton: value.expectedActionIsButton === true,
    expectedActionIsLink: value.expectedActionIsLink === true,
    expectedActionTypeSubmit: value.expectedActionTypeSubmit === true,
    expectedActionEnabled: value.expectedActionEnabled === true,
    expectedActionInsideForm: value.expectedActionInsideForm === true,
    expectedActionFormPost: value.expectedActionFormPost === true,
    expectedActionFormKeyEndpoint: value.expectedActionFormKeyEndpoint === true,
    expectedActionHrefKeyEndpoint: value.expectedActionHrefKeyEndpoint === true,
    expectedActionHasInlineConfirmation: value.expectedActionHasInlineConfirmation === true,
    confirmationSurfacePresent: value.confirmationSurfacePresent === true,
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
    if (option === '--expected-name' && expectedName.length === 0) {
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
    expectedName.length > 0 && expectedName.length <= MAX_EXPECTED_NAME_LENGTH &&
    Number.isInteger(timeoutMs) && timeoutMs >= MIN_TIMEOUT_MS && timeoutMs <= MAX_TIMEOUT_MS
    ? { port, expectedName, timeoutMs }
    : null
}

export async function runApiKeyManagementProbe({ port, expectedName, timeoutMs }) {
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
    const result = await evaluate(socketUrl, buildExpression(expectedName), timeoutMs)
    states.push(result.ok ? strictResult(result.value) : result)
  }
  const matching = states.filter((state) => state.ok && state.officialSettings)
  if (matching.length !== 1) {
    return createFailure('page_selection', matching.length > 1
      ? 'official_settings_ambiguous'
      : states.some((state) => !state.ok) ? 'page_probe_inconclusive' : 'official_settings_missing')
  }
  return matching[0]
}

function usage() {
  return 'Usage: node scripts/probe_arkweb_api_key_management.mjs --port <local-devtools-port> --expected-name <non-secret-name> [--timeout-ms 500..15000]'
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
  const result = await runApiKeyManagementProbe(options)
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
