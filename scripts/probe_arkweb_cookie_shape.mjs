#!/usr/bin/env node

/**
 * Read-only ArkWeb cookie-shape probe.
 *
 * The CDP response is reduced in memory to one fixed renewable-auth boolean.
 * Cookie names, values, attributes, page metadata, URLs and CDP errors are
 * never emitted.
 */

import { request as httpRequest } from 'node:http'
import { pathToFileURL } from 'node:url'

const MAX_DISCOVERY_BYTES = 1024 * 1024
const MAX_PAGE_TARGETS = 2
const FIRST_PARTY_DOMAIN = 'nhentai.net'

function failure(stage, code) {
  return { ok: false, stage, code }
}

function parseArguments(argv) {
  if (argv.length !== 2 || argv[0] !== '--port') {
    return null
  }
  const port = Number(argv[1])
  return Number.isInteger(port) && port > 0 && port <= 65535 ? { port } : null
}

function fetchTargets(port, timeoutMs = 5000) {
  return new Promise((resolve) => {
    let settled = false
    const chunks = []
    let bytes = 0
    const finish = (result) => {
      if (settled) return
      settled = true
      resolve(result)
    }
    const request = httpRequest({
      host: '127.0.0.1',
      port,
      path: '/json',
      method: 'GET',
    }, (response) => {
      if (response.statusCode !== 200) {
        response.resume()
        finish(failure('discovery', 'http_not_ok'))
        return
      }
      response.on('data', (chunk) => {
        bytes += chunk.length
        if (bytes > MAX_DISCOVERY_BYTES) {
          request.destroy()
          finish(failure('discovery', 'body_too_large'))
          return
        }
        chunks.push(chunk)
      })
      response.on('end', () => {
        try {
          const value = JSON.parse(Buffer.concat(chunks).toString('utf8'))
          finish(Array.isArray(value) ? { ok: true, targets: value } : failure('discovery', 'invalid_root'))
        } catch (_error) {
          finish(failure('discovery', 'invalid_json'))
        }
      })
      response.on('error', () => finish(failure('discovery', 'response_failed')))
    })
    request.on('error', () => finish(failure('discovery', 'transport_failed')))
    request.setTimeout(timeoutMs, () => {
      request.destroy()
      finish(failure('discovery', 'timeout'))
    })
    request.end()
  })
}

function localPageSockets(targets, port) {
  const prefix = `ws://127.0.0.1:${port}/`
  return targets
    .filter((target) => target !== null && typeof target === 'object' &&
      target.type === 'page' && typeof target.webSocketDebuggerUrl === 'string' &&
      target.webSocketDebuggerUrl.startsWith(prefix))
    .map((target) => target.webSocketDebuggerUrl)
    .slice(0, MAX_PAGE_TARGETS)
}

function waitForOpen(socket, timeoutMs) {
  return new Promise((resolve) => {
    let settled = false
    const finish = (value) => {
      if (settled) return
      settled = true
      clearTimeout(timeout)
      resolve(value)
    }
    const timeout = setTimeout(() => finish(false), timeoutMs)
    socket.addEventListener('open', () => finish(true), { once: true })
    socket.addEventListener('error', () => finish(false), { once: true })
    socket.addEventListener('close', () => finish(false), { once: true })
  })
}

function send(socket, id, method, timeoutMs) {
  return new Promise((resolve) => {
    let settled = false
    const finish = (value) => {
      if (settled) return
      settled = true
      clearTimeout(timeout)
      socket.removeEventListener('message', onMessage)
      resolve(value)
    }
    const onMessage = (event) => {
      try {
        const message = JSON.parse(String(event.data))
        if (message !== null && typeof message === 'object' && message.id === id) {
          finish(message)
        }
      } catch (_error) {
        finish(null)
      }
    }
    const timeout = setTimeout(() => finish(null), timeoutMs)
    socket.addEventListener('message', onMessage)
    socket.addEventListener('error', () => finish(null), { once: true })
    socket.addEventListener('close', () => finish(null), { once: true })
    try {
      socket.send(JSON.stringify({ id, method, params: {} }))
    } catch (_error) {
      finish(null)
    }
  })
}

function normalizeDomain(domain) {
  const value = typeof domain === 'string' ? domain.toLowerCase().replace(/^\.+/, '') : ''
  return value === FIRST_PARTY_DOMAIN || value.endsWith(`.${FIRST_PARTY_DOMAIN}`)
    ? FIRST_PARTY_DOMAIN
    : ''
}

function safeName(name) {
  return typeof name === 'string' && /^[A-Za-z0-9_.-]{1,64}$/.test(name) ? name : ''
}

function normalizeCookies(cookies) {
  let accessTokenPresent = false
  let refreshTokenPresent = false
  for (const cookie of Array.isArray(cookies) ? cookies : []) {
    if (cookie === null || typeof cookie !== 'object') continue
    const name = safeName(cookie.name)
    const domain = normalizeDomain(cookie.domain)
    if (name.length === 0 || domain.length === 0) continue
    accessTokenPresent ||= name === 'access_token'
    refreshTokenPresent ||= name === 'refresh_token'
  }
  return {
    ok: true,
    stage: 'cookie_shape',
    renewableAuthPresent: accessTokenPresent && refreshTokenPresent,
  }
}

async function probeSocket(socketUrl, timeoutMs = 5000) {
  if (typeof globalThis.WebSocket !== 'function') {
    return failure('cdp', 'websocket_unavailable')
  }
  let socket
  try {
    socket = new globalThis.WebSocket(socketUrl)
  } catch (_error) {
    return failure('cdp', 'open_failed')
  }
  try {
    if (!await waitForOpen(socket, timeoutMs)) {
      return failure('cdp', 'open_failed')
    }
    const response = await send(socket, 1, 'Network.getAllCookies', timeoutMs)
    if (response === null || response.error !== undefined ||
      response.result === null || typeof response.result !== 'object') {
      return failure('cdp', 'cookie_read_failed')
    }
    return normalizeCookies(response.result.cookies)
  } finally {
    try { socket.close() } catch (_error) {}
  }
}

export async function runCookieShape({ port }) {
  const discovery = await fetchTargets(port)
  if (!discovery.ok) return discovery
  const sockets = localPageSockets(discovery.targets, port)
  if (sockets.length === 0) return failure('selection', 'no_local_page')
  for (const socket of sockets) {
    const result = await probeSocket(socket)
    if (result.ok) return result
  }
  return failure('cdp', 'all_page_probes_failed')
}

async function main() {
  const options = parseArguments(process.argv.slice(2))
  return options === null
    ? failure('arguments', 'invalid_arguments')
    : await runCookieShape(options)
}

const invokedPath = process.argv[1] === undefined ? '' : pathToFileURL(process.argv[1]).href
if (import.meta.url === invokedPath) {
  main().then((result) => {
    process.stdout.write(`${JSON.stringify(result)}\n`)
    process.exitCode = result.ok ? 0 : 1
  }).catch(() => {
    process.stdout.write(`${JSON.stringify(failure('runtime', 'unexpected_failure'))}\n`)
    process.exitCode = 1
  })
}
