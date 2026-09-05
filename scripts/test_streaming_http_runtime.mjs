import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import vm from 'node:vm'
import { test } from 'node:test'

// Execute the actual non-UI ArkTS owner with a controllable native transport.
// In particular, destroy deliberately does NOT settle requestInStream.
const require = createRequire(import.meta.url)
const ts = require(process.env.NEXTN_TYPESCRIPT_PATH ??
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js')
const code = ts.transpileModule(readFileSync(new URL(
  '../shared/src/main/ets/network/StreamingHttpClient.ets', import.meta.url), 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText

function harness() {
  const events = new Map()
  const timers = new Map()
  let now = 0
  let timerId = 0
  let resolveNative
  let rejectNative
  const nativePromise = new Promise((resolve, reject) => { resolveNative = resolve; rejectNative = reject })
  const request = {
    destroys: 0,
    on(name, callback) { events.set(name, callback) },
    destroy() { this.destroys++ },
    requestInStream() { return nativePromise },
  }
  const exports = {}
  vm.runInNewContext(code, {
    exports,
    require: () => ({ http: { createHttp: () => request, RequestMethod: { GET: 'GET' } } }),
    Date: class extends Date { static now() { return now } },
    setInterval(callback, interval) { timers.set(++timerId, { callback, interval, next: now + interval }); return timerId },
    clearInterval(id) { timers.delete(id) },
  })
  const flush = async () => { for (let i = 0; i < 8; i++) await Promise.resolve() }
  return {
    client: exports.StreamingHttpClient, request, timers,
    emit(name, value) { events.get(name)?.(value) },
    resolveNative, rejectNative, flush,
    async advance(ms) {
      const end = now + ms
      while (true) {
        const due = [...timers.values()].filter(t => t.next <= end).sort((a, b) => a.next - b.next)[0]
        if (!due) break
        now = due.next
        due.next += due.interval
        due.callback()
        await flush()
      }
      now = end
      await flush()
    },
    start(sink = () => true, keep = () => true, maxBytes = 64) {
      const observed = { state: 'pending' }
      this.client.get('https://example.test/image', {}, 1000, 3000, maxBytes, sink, keep)
        .then(value => Object.assign(observed, { state: 'resolved', value }),
          error => Object.assign(observed, { state: 'rejected', error }))
      return observed
    },
  }
}

test('silent native request settles at the application deadline and ignores late data', async () => {
  const h = harness()
  let writes = 0
  const result = h.start(() => { writes++; return true })
  await h.advance(4000)
  assert.equal(result.state, 'rejected')
  assert.match(result.error.message, /timed out/)
  h.emit('dataReceive', new ArrayBuffer(4))
  h.resolveNative(200)
  await h.flush()
  assert.equal(writes, 0)
  assert.equal(h.request.destroys, 1)
  assert.equal(h.timers.size, 0)
})

test('pause cancels a silent stream without waiting for data or native rejection', async () => {
  const h = harness()
  let keep = true
  const result = h.start(undefined, () => keep)
  keep = false
  await h.advance(250)
  assert.equal(result.state, 'resolved')
  assert.equal(result.value.cancelled, true)
  assert.equal(h.request.destroys, 1)
  assert.equal(h.timers.size, 0)
})

test('real byte progress keeps a slow large transfer alive; progress metadata alone does not', async () => {
  const h = harness()
  const result = h.start()
  for (let i = 0; i < 3; i++) {
    await h.advance(2000)
    h.emit('dataReceive', new ArrayBuffer(4))
  }
  assert.equal(result.state, 'pending')
  h.resolveNative(200)
  await h.flush()
  assert.equal(result.state, 'resolved')
  assert.equal(result.value.receivedBytes, 12)

  const silent = harness()
  const stalled = silent.start()
  silent.emit('dataReceive', new ArrayBuffer(4))
  await silent.advance(2000)
  silent.emit('dataReceiveProgress', { totalSize: 32, receiveSize: 4 })
  await silent.advance(1000)
  assert.equal(stalled.state, 'rejected')
})

test('limit and sink aborts settle independently and block late writes', async () => {
  for (const kind of ['size', 'progress', 'sink', 'sinkThrow']) {
    const h = harness()
    let writes = 0
    const result = h.start(() => { writes++; if (kind === 'sinkThrow') throw Error('disk'); return false })
    h.emit(kind === 'progress' ? 'dataReceiveProgress' : 'dataReceive',
      kind === 'progress' ? { totalSize: 65 } : new ArrayBuffer(kind === 'size' ? 65 : 4))
    await h.flush()
    assert.equal(result.state, 'resolved', kind)
    assert.equal(kind === 'size' || kind === 'progress' ? result.value.limitExceeded : result.value.sinkRejected, true)
    const oldWrites = writes
    h.emit('dataReceive', new ArrayBuffer(4))
    h.rejectNative(Error('late native destruction'))
    await h.flush()
    assert.equal(writes, oldWrites)
    assert.equal(h.request.destroys, 1)
    assert.equal(h.timers.size, 0)
  }
})

test('successful transfer retains status and byte count and cleans up once', async () => {
  const h = harness()
  const result = h.start()
  h.emit('dataReceive', new ArrayBuffer(4))
  h.emit('dataReceive', new ArrayBuffer(3))
  h.emit('dataEnd')
  h.resolveNative(200)
  await h.flush()
  assert.equal(result.state, 'resolved')
  assert.equal(result.value.statusCode, 200)
  assert.equal(result.value.receivedBytes, 7)
  assert.equal(h.request.destroys, 1)
  assert.equal(h.timers.size, 0)
})

test('native failure settles and does not leak native URL text to callers', async () => {
  const h = harness()
  const result = h.start()
  h.rejectNative(Object.assign(Error('failed https://private.example/path'), { code: 2300028 }))
  await h.flush()
  assert.equal(result.state, 'rejected')
  assert.match(result.error.message, /timed out/)
  assert.doesNotMatch(result.error.message, /https/)
  assert.equal(h.request.destroys, 1)
})
