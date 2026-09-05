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
import { runApiKeyManagementProbe } from './probe_arkweb_api_key_management.mjs'

const DEFAULT_TIMEOUT_MS = 8000
const MIN_TIMEOUT_MS = 500
const MAX_TIMEOUT_MS = 15000
const MAX_NAME_LENGTH = 120
const POST_ACTION_SETTLE_MS = 1800
const CLICK_TRACE_KEY = '__nextNApiKeyRevokeClickTrace'

function buildClickTraceInstallExpression(expectedName) {
  const expectedNameLiteral = JSON.stringify(expectedName)
  const traceKeyLiteral = JSON.stringify(CLICK_TRACE_KEY)
  return `(() => {
    const expectedName = ${expectedNameLiteral};
    const traceKey = ${traceKeyLiteral};
    const normalized = (value) => String(value || '').trim().toLowerCase().replace(/\\s+/g, ' ');
    const controls = Array.from(document.querySelectorAll(
      'button, a, input[type="button"], input[type="submit"]'
    )).filter((control) => {
      const labels = [
        control.getAttribute('aria-label'),
        control.getAttribute('title'),
        control instanceof HTMLInputElement ? control.value : control.textContent,
      ].map(normalized).filter((value) => value.length > 0);
      return labels.some((value) => /(^|\\b)(revoke|disable)(\\b|$)/.test(value));
    });
    const rowFor = (control) => control.closest(
      'tr, li, [role="row"], form, [data-key-id], [data-api-key-id]'
    ) || control.parentElement;
    const expectedControls = controls.filter((control) => {
      const row = rowFor(control);
      return row !== null && String(row.textContent || '').includes(expectedName);
    });
    const control = expectedControls.length === 1 ? expectedControls[0] : null;
    if (!(control instanceof HTMLButtonElement)) {
      return { installed: false };
    }
    const previous = window[traceKey];
    if (previous && typeof previous.cleanup === 'function') {
      previous.cleanup();
    }
    const trace = {
      clickSeen: false,
      clickTrusted: false,
      clickTargetMatches: false,
      clickDefaultPrevented: false,
      cleanup: null,
    };
    const handler = (event) => {
      trace.clickSeen = true;
      trace.clickTrusted = event.isTrusted === true;
      trace.clickTargetMatches = event.target === control || control.contains(event.target);
      trace.clickDefaultPrevented = event.defaultPrevented === true;
    };
    trace.cleanup = () => document.removeEventListener('click', handler, true);
    document.addEventListener('click', handler, true);
    window[traceKey] = trace;
    return { installed: true };
  })()`
}

const CLICK_TRACE_READ_EXPRESSION = `(() => {
  const trace = window[${JSON.stringify(CLICK_TRACE_KEY)}];
  const result = {
    clickSeen: trace?.clickSeen === true,
    clickTrusted: trace?.clickTrusted === true,
    clickTargetMatches: trace?.clickTargetMatches === true,
    clickDefaultPrevented: trace?.clickDefaultPrevented === true,
  };
  if (trace && typeof trace.cleanup === 'function') {
    trace.cleanup();
  }
  delete window[${JSON.stringify(CLICK_TRACE_KEY)}];
  return result;
})()`

export function buildRevokeActionExpression(expectedName) {
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
    const controls = Array.from(document.querySelectorAll(
      'button, a, input[type="button"], input[type="submit"]'
    )).filter(isVisible);
    const revokeControls = controls.filter((control) => {
      const labels = [
        control.getAttribute('aria-label'),
        control.getAttribute('title'),
        control instanceof HTMLInputElement ? control.value : control.textContent,
      ].map(normalized).filter((value) => value.length > 0);
      return labels.some((value) => /(^|\\b)(revoke|disable)(\\b|$)/.test(value));
    });
    const rowFor = (control) => control.closest(
      'tr, li, [role="row"], form, [data-key-id], [data-api-key-id]'
    ) || control.parentElement;
    const expectedControls = revokeControls.filter((control) => {
      const row = rowFor(control);
      return row !== null && String(row.textContent || '').includes(expectedName);
    });
    const expectedRows = new Set(expectedControls.map(rowFor).filter((row) => row !== null));
    const control = expectedRows.size === 1 && expectedControls.length === 1
      ? expectedControls[0]
      : null;
    const loginFormAbsent = Array.from(document.querySelectorAll('input')).filter(isVisible)
      .every((input) => String(input.type || '').toLowerCase() !== 'password');
    const confirmationSurfacePresent = Array.from(document.querySelectorAll(
      '[role="dialog"], dialog, [aria-modal="true"]'
    )).some(isVisible);
    const enabled = control !== null && !control.disabled &&
      normalized(control.getAttribute('aria-disabled')) !== 'true';
    const officialSettings = location.origin === 'https://nhentai.net' &&
      location.pathname === '/user/settings';
    const uniqueExpectedNameAction = expectedRows.size === 1 && expectedControls.length === 1;
    const actionIsButton = control instanceof HTMLButtonElement;
    const structurallyEligible = officialSettings && loginFormAbsent &&
      !confirmationSurfacePresent && actionIsButton && enabled;
    if (structurallyEligible) {
      control.scrollIntoView({ block: 'center', inline: 'center' });
    }
    const actionRect = control === null ? null : control.getBoundingClientRect();
    const actionCenterX = actionRect === null ? null : actionRect.left + actionRect.width / 2;
    const actionCenterY = actionRect === null ? null : actionRect.top + actionRect.height / 2;
    const actionCenterInViewport = Number.isFinite(actionCenterX) && Number.isFinite(actionCenterY) &&
      actionCenterX > 0 && actionCenterY > 0 &&
      actionCenterX < window.innerWidth && actionCenterY < window.innerHeight;
    const actionHitTarget = actionCenterInViewport
      ? document.elementFromPoint(actionCenterX, actionCenterY)
      : null;
    const actionHitTestMatches = control !== null && actionHitTarget !== null &&
      (actionHitTarget === control || control.contains(actionHitTarget));
    const eligible = structurallyEligible && actionCenterInViewport && actionHitTestMatches;
    return {
      officialSettings,
      loginFormAbsent,
      uniqueExpectedNameAction,
      actionIsButton,
      actionEnabled: enabled,
      confirmationSurfacePresent,
      actionCenterInViewport,
      actionHitTestMatches,
      eligible,
      actionCenterX,
      actionCenterY,
    };
  })()`
}

const DOM_CONFIRMATION_STATE_EXPRESSION = `(() => {
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
  const dialogs = Array.from(document.querySelectorAll(
    '[role="dialog"], dialog, [aria-modal="true"]'
  )).filter(isVisible);
  const dialog = dialogs.length === 1 ? dialogs[0] : null;
  const controls = dialog === null ? [] : Array.from(dialog.querySelectorAll(
    'button, a, input[type="button"], input[type="submit"]'
  )).filter(isVisible);
  const affirmativeControls = controls.filter((control) => {
    const labels = [
      control.getAttribute('aria-label'),
      control.getAttribute('title'),
      control instanceof HTMLInputElement ? control.value : control.textContent,
    ].map(normalized).filter((value) => value.length > 0);
    const negative = labels.some((value) => /(^|\\b)(cancel|no|close|back)(\\b|$)/.test(value));
    return !negative && labels.some((value) =>
      /(^|\\b)(confirm|yes|revoke|disable|delete)(\\b|$)/.test(value));
  });
  return {
    officialSettings: location.origin === 'https://nhentai.net' &&
      location.pathname === '/user/settings',
    dialogUnique: dialogs.length === 1,
    affirmativeControlUnique: affirmativeControls.length === 1,
    affirmativeControlEnabled: affirmativeControls.length === 1 &&
      !affirmativeControls[0].disabled &&
      normalized(affirmativeControls[0].getAttribute('aria-disabled')) !== 'true',
  };
})()`

const DOM_CONFIRMATION_ACTION_EXPRESSION = `(() => {
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
  const dialogs = Array.from(document.querySelectorAll(
    '[role="dialog"], dialog, [aria-modal="true"]'
  )).filter(isVisible);
  const dialog = dialogs.length === 1 ? dialogs[0] : null;
  const controls = dialog === null ? [] : Array.from(dialog.querySelectorAll(
    'button, a, input[type="button"], input[type="submit"]'
  )).filter(isVisible);
  const affirmativeControls = controls.filter((control) => {
    const labels = [
      control.getAttribute('aria-label'),
      control.getAttribute('title'),
      control instanceof HTMLInputElement ? control.value : control.textContent,
    ].map(normalized).filter((value) => value.length > 0);
    const negative = labels.some((value) => /(^|\\b)(cancel|no|close|back)(\\b|$)/.test(value));
    return !negative && labels.some((value) =>
      /(^|\\b)(confirm|yes|revoke|disable|delete)(\\b|$)/.test(value));
  });
  const control = affirmativeControls.length === 1 ? affirmativeControls[0] : null;
  const eligible = location.origin === 'https://nhentai.net' &&
    location.pathname === '/user/settings' && dialogs.length === 1 &&
    control !== null && !control.disabled &&
    normalized(control.getAttribute('aria-disabled')) !== 'true';
  let clickScheduled = false;
  if (eligible) {
    window.setTimeout(() => control.click(), 0);
    clickScheduled = true;
  }
  return { eligible, clickScheduled };
})()`

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds))
}

async function evaluateOnSocket(socket, id, expression, timeoutMs) {
  const evaluated = await sendCdp(socket, id, 'Runtime.evaluate', {
    expression,
    awaitPromise: true,
    returnByValue: true,
  }, timeoutMs)
  if (evaluated.kind !== 'message' || !isObject(evaluated.message) ||
    evaluated.message.error !== undefined) {
    return createFailure('runtime_evaluate', 'failed')
  }
  const result = evaluated.message.result
  if (!isObject(result) || result.exceptionDetails !== undefined || !isObject(result.result)) {
    return createFailure('runtime_evaluate', 'exception_or_missing_result')
  }
  return { ok: true, value: result.result.value }
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
    if (enabled.kind !== 'message' || !isObject(enabled.message) ||
      enabled.message.error !== undefined) {
      return createFailure('runtime_enable', 'failed')
    }
    return evaluateOnSocket(socket, 2, expression, timeoutMs)
  } finally {
    closeQuietly(socket)
  }
}

async function openUniqueEligiblePage(port, expectedName, timeoutMs) {
  const discovery = await fetchLocalPages(port, timeoutMs)
  if (!discovery.ok) {
    return createFailure('devtools_discovery', discovery.code)
  }
  const selection = selectLocalPages(discovery.pages, port)
  if (selection.socketUrls === undefined) {
    return createFailure('page_selection', selection.code)
  }
  const eligibleSockets = []
  let probeInconclusive = false
  for (const socketUrl of selection.socketUrls) {
    let socket
    try {
      socket = new globalThis.WebSocket(socketUrl)
    } catch (_error) {
      probeInconclusive = true
      continue
    }
    if (!await waitForSocketOpen(socket, timeoutMs)) {
      probeInconclusive = true
      closeQuietly(socket)
      continue
    }
    const enabled = await sendCdp(socket, 1, 'Runtime.enable', {}, timeoutMs)
    const state = enabled.kind === 'message' && isObject(enabled.message) &&
      enabled.message.error === undefined
      ? await evaluateOnSocket(
          socket,
          2,
          buildRevokeActionExpression(expectedName),
          timeoutMs,
        )
      : createFailure('runtime_enable', 'failed')
    if (state.ok && isObject(state.value) && state.value.eligible === true) {
      eligibleSockets.push({
        socket,
        actionCenterX: state.value.actionCenterX,
        actionCenterY: state.value.actionCenterY,
      })
    } else {
      probeInconclusive ||= !state.ok
      closeQuietly(socket)
    }
  }
  if (eligibleSockets.length === 0 && probeInconclusive) {
    return createFailure('page_selection', 'revoke_page_probe_inconclusive')
  }
  if (eligibleSockets.length !== 1) {
    for (const selected of eligibleSockets) {
      closeQuietly(selected.socket)
    }
    return createFailure('page_selection', eligibleSockets.length > 1
      ? 'revoke_page_ambiguous'
      : 'revoke_page_missing')
  }
  return { ok: true, selected: eligibleSockets[0] }
}

async function dispatchTrustedClick(socket, firstId, x, y, timeoutMs) {
  if (!Number.isFinite(x) || !Number.isFinite(y) || x <= 0 || y <= 0) {
    return createFailure('input_precondition', 'invalid_target_center')
  }
  const moved = await sendCdp(socket, firstId, 'Input.dispatchMouseEvent', {
    type: 'mouseMoved',
    x,
    y,
  }, timeoutMs)
  const pressed = await sendCdp(socket, firstId + 1, 'Input.dispatchMouseEvent', {
    type: 'mousePressed',
    x,
    y,
    button: 'left',
    buttons: 1,
    clickCount: 1,
  }, timeoutMs)
  const released = await sendCdp(socket, firstId + 2, 'Input.dispatchMouseEvent', {
    type: 'mouseReleased',
    x,
    y,
    button: 'left',
    buttons: 0,
    clickCount: 1,
  }, timeoutMs)
  const accepted = [moved, pressed, released].every((result) =>
    result.kind === 'message' && isObject(result.message) && result.message.error === undefined)
  return accepted
    ? { ok: true, trustedClickDispatched: true }
    : createFailure('input_dispatch', 'trusted_click_outcome_unknown_do_not_retry')
}

async function dispatchRevoke(selected, expectedName, timeoutMs) {
  const socket = selected.socket
  let javascriptDialogCount = 0
  let javascriptDialogHandled = false
  let dialogCommandId = 9000
  let matchingRequestCount = 0
  let matchingMutationRequestCount = 0
  let response2xx = false
  let response4xx = false
  let response5xx = false
  const matchingRequestIds = new Set()
  const onMessage = (event) => {
    try {
      const message = JSON.parse(String(event.data))
      if (message?.method === 'Page.javascriptDialogOpening') {
        javascriptDialogCount += 1
        if (javascriptDialogCount === 1) {
          dialogCommandId += 1
          socket.send(JSON.stringify({
            id: dialogCommandId,
            method: 'Page.handleJavaScriptDialog',
            params: { accept: true },
          }))
        }
      } else if (message?.id === dialogCommandId && message.error === undefined) {
        javascriptDialogHandled = true
      } else if (message?.method === 'Network.requestWillBeSent') {
        const request = message.params?.request
        try {
          const target = new URL(String(request?.url || ''))
          if (target.origin === 'https://nhentai.net' &&
            /^\/api\/v2\/user\/keys(?:\/|$)/.test(target.pathname)) {
            matchingRequestCount += 1
            const method = String(request?.method || '').toUpperCase()
            if (method === 'POST' || method === 'PUT' || method === 'PATCH' || method === 'DELETE') {
              matchingMutationRequestCount += 1
            }
            const requestId = String(message.params?.requestId || '')
            if (requestId.length > 0) {
              matchingRequestIds.add(requestId)
            }
          }
        } catch (_error) {}
      } else if (message?.method === 'Network.responseReceived') {
        const requestId = String(message.params?.requestId || '')
        if (matchingRequestIds.has(requestId)) {
          const status = Number(message.params?.response?.status || 0)
          response2xx ||= status >= 200 && status < 300
          response4xx ||= status >= 400 && status < 500
          response5xx ||= status >= 500 && status < 600
        }
      }
    } catch (_error) {}
  }
  try {
    const pageEnabled = await sendCdp(socket, 3, 'Page.enable', {}, timeoutMs)
    const networkEnabled = await sendCdp(socket, 4, 'Network.enable', {}, timeoutMs)
    const broughtToFront = await sendCdp(socket, 5, 'Page.bringToFront', {}, timeoutMs)
    const traceInstalled = await evaluateOnSocket(
      socket,
      6,
      buildClickTraceInstallExpression(expectedName),
      timeoutMs,
    )
    if (pageEnabled.kind !== 'message' || networkEnabled.kind !== 'message' ||
      broughtToFront.kind !== 'message' || !isObject(pageEnabled.message) ||
      !isObject(networkEnabled.message) || !isObject(broughtToFront.message) ||
      pageEnabled.message.error !== undefined || networkEnabled.message.error !== undefined ||
      broughtToFront.message.error !== undefined || !traceInstalled.ok ||
      !isObject(traceInstalled.value) || traceInstalled.value.installed !== true) {
      return createFailure('cdp_enable', 'failed')
    }
    socket.addEventListener('message', onMessage)
    const action = await dispatchTrustedClick(
      socket,
      10,
      selected.actionCenterX,
      selected.actionCenterY,
      timeoutMs,
    )
    if (!action.ok) {
      return createFailure('action_postcondition', 'revoke_not_dispatched_do_not_retry')
    }
    await sleep(POST_ACTION_SETTLE_MS)
    const clickTrace = await evaluateOnSocket(socket, 20, CLICK_TRACE_READ_EXPRESSION, timeoutMs)
    const trace = clickTrace.ok && isObject(clickTrace.value) ? clickTrace.value : {}
    return {
      ok: true,
      clickDispatched: true,
      clickSeen: trace.clickSeen === true,
      clickTrusted: trace.clickTrusted === true,
      clickTargetMatches: trace.clickTargetMatches === true,
      clickDefaultPrevented: trace.clickDefaultPrevented === true,
      matchingRequestCount,
      matchingMutationRequestCount,
      response2xx,
      response4xx,
      response5xx,
      javascriptDialogSeen: javascriptDialogCount === 1,
      javascriptDialogHandled: javascriptDialogCount === 0 || javascriptDialogHandled,
      javascriptDialogAmbiguous: javascriptDialogCount > 1,
    }
  } finally {
    socket.removeEventListener('message', onMessage)
    closeQuietly(socket)
  }
}

async function handleDomConfirmationOnce(port, timeoutMs) {
  const discovery = await fetchLocalPages(port, timeoutMs)
  if (!discovery.ok) {
    return createFailure('devtools_discovery', discovery.code)
  }
  const selection = selectLocalPages(discovery.pages, port)
  if (selection.socketUrls === undefined) {
    return createFailure('page_selection', selection.code)
  }
  const matching = []
  for (const socketUrl of selection.socketUrls) {
    const state = await evaluate(socketUrl, DOM_CONFIRMATION_STATE_EXPRESSION, timeoutMs)
    if (state.ok && isObject(state.value) && state.value.officialSettings === true &&
      state.value.dialogUnique === true && state.value.affirmativeControlUnique === true &&
      state.value.affirmativeControlEnabled === true) {
      matching.push(socketUrl)
    }
  }
  if (matching.length === 0) {
    return { ok: true, confirmationPresent: false, confirmationDispatched: false }
  }
  if (matching.length > 1) {
    return createFailure('confirmation', 'confirmation_page_ambiguous')
  }
  const action = await evaluate(matching[0], DOM_CONFIRMATION_ACTION_EXPRESSION, timeoutMs)
  return action.ok && isObject(action.value) && action.value.eligible === true &&
    action.value.clickScheduled === true
    ? { ok: true, confirmationPresent: true, confirmationDispatched: true }
    : createFailure('confirmation', 'confirmation_not_dispatched_do_not_retry')
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
    expectedName.length > 0 && expectedName.length <= MAX_NAME_LENGTH &&
    Number.isInteger(timeoutMs) && timeoutMs >= MIN_TIMEOUT_MS && timeoutMs <= MAX_TIMEOUT_MS
    ? { port, expectedName, timeoutMs }
    : null
}

export async function runApiKeyRevokeOnce({ port, expectedName, timeoutMs }) {
  const selected = await openUniqueEligiblePage(port, expectedName, timeoutMs)
  if (!selected.ok) {
    return selected
  }
  const dispatched = await dispatchRevoke(selected.selected, expectedName, timeoutMs)
  if (!dispatched.ok || dispatched.javascriptDialogAmbiguous ||
    !dispatched.javascriptDialogHandled) {
    return createFailure('action_postcondition', 'revoke_outcome_unknown_do_not_retry')
  }
  await sleep(POST_ACTION_SETTLE_MS)
  let observed = await runApiKeyManagementProbe({ port, expectedName, timeoutMs })
  let domConfirmationPresent = false
  let domConfirmationDispatched = false
  if (observed.ok && observed.expectedNameActionCount > 0) {
    const confirmation = await handleDomConfirmationOnce(port, timeoutMs)
    if (!confirmation.ok) {
      return confirmation
    }
    domConfirmationPresent = confirmation.confirmationPresent
    domConfirmationDispatched = confirmation.confirmationDispatched
    if (domConfirmationDispatched) {
      await sleep(POST_ACTION_SETTLE_MS)
      observed = await runApiKeyManagementProbe({ port, expectedName, timeoutMs })
    }
  }
  if (!observed.ok || observed.expectedNameActionCount !== 0 ||
    observed.expectedNameRowCount !== 0) {
    return {
      ok: false,
      stage: 'action_postcondition',
      code: 'revoke_outcome_unknown_do_not_retry',
      clickSeen: dispatched.clickSeen,
      clickTrusted: dispatched.clickTrusted,
      clickTargetMatches: dispatched.clickTargetMatches,
      clickDefaultPrevented: dispatched.clickDefaultPrevented,
      matchingRequestCount: dispatched.matchingRequestCount,
      matchingMutationRequestCount: dispatched.matchingMutationRequestCount,
      response2xx: dispatched.response2xx,
      response4xx: dispatched.response4xx,
      response5xx: dispatched.response5xx,
    }
  }
  return {
    ok: true,
    stage: 'api_key_revoke',
    preconditionsMet: true,
    revokeDispatched: true,
    clickSeen: dispatched.clickSeen,
    clickTrusted: dispatched.clickTrusted,
    clickTargetMatches: dispatched.clickTargetMatches,
    matchingRequestCount: dispatched.matchingRequestCount,
    matchingMutationRequestCount: dispatched.matchingMutationRequestCount,
    response2xx: dispatched.response2xx,
    response4xx: dispatched.response4xx,
    response5xx: dispatched.response5xx,
    javascriptDialogHandled: dispatched.javascriptDialogSeen,
    domConfirmationPresent,
    domConfirmationDispatched,
    expectedRowAbsent: true,
  }
}

function usage() {
  return 'Usage: node scripts/revoke_arkweb_api_key_once.mjs --port <local-devtools-port> --expected-name <non-secret-name> [--timeout-ms 500..15000]'
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
  const result = await runApiKeyRevokeOnce(options)
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
