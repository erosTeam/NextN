import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { test } from 'node:test'
import vm from 'node:vm'

const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js')
function compiled(path) {
  return ts.transpileModule(readFileSync(new URL(path, import.meta.url), 'utf8'), { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
  } }).outputText
}
const controlCode = compiled('../shared/src/main/ets/navigation/ReaderTrialOriginalProbe.ets')
const providerCode = compiled('../feature/reader/src/main/ets/lab/NextNReaderOriginalProbeProvider.ets')

// Both state machine and provider wrapper are complete actual modules. Only their external asset provider is fake.
function setup(timeoutMs = 1000, deferred = false) {
  const shared = {}
  vm.runInNewContext(controlCode, { exports: shared }, { filename: 'ReaderTrialOriginalProbe.ets' })
  const exports = {}
  vm.runInNewContext(providerCode, {
    exports, require: name => { assert.equal(name, 'shared'); return shared },
    setTimeout, clearTimeout, setInterval, clearInterval,
  }, { filename: 'NextNReaderOriginalProbeProvider.ets' })
  const probe = shared.ReaderTrialOriginalProbe
  const epoch = probe.arm('678049', 0)
  assert.equal(probe.consume('678049', 0), epoch)
  let releases = 0
  let calls = 0
  let finishLoad
  const asset = { uri: 'test-asset', release() { releases++ } }
  const inner = { cancellationMode: 'consumer-only', informationSupported: false,
    async load() {
      calls++
      if (deferred) await new Promise(resolve => { finishLoad = resolve })
      return asset
    },
  }
  const Provider = exports.NextNReaderOriginalProbeProvider
  const provider = new Provider(inner, epoch, '678049', 0, timeoutMs)
  let cancelled = false
  const cancellation = { isCancelled: () => cancelled,
    check() { if (cancelled) throw new Error('cancelled') }, cancel() { cancelled = true } }
  const page = { unit: { unit: '678049' }, sourceIndex: 0 }
  const load = () => provider.load(page, 'original', cancellation, false)
    .then(value => ({ value }), error => ({ error }))
  return { probe, epoch, provider, Provider, inner, page, cancellation, asset, shared, load,
    releases: () => releases, calls: () => calls, finishLoad: () => finishLoad() }
}
const flush = () => new Promise(resolve => setImmediate(resolve))

test('real asset is held until the exact epoch/request releases, then belongs only to the session', async () => {
  const value = setup()
  const pending = value.load()
  await flush()
  const held = value.probe.read()
  assert.equal(held.state, 'held')
  assert.equal(value.calls(), 1)
  assert.equal(value.releases(), 0)
  assert.equal(value.probe.release(held.epoch + 1, held.requestId), false)
  assert.equal(value.probe.release(held.epoch, held.requestId + 1), false)
  assert.equal(value.probe.release(held.epoch, held.requestId), true)
  assert.equal((await pending).value, value.asset)
  assert.equal(value.probe.read().state, 'delivered')
  value.provider.close()
  assert.equal(value.releases(), 0)
  assert.equal(value.probe.read().assetReleased, false)
  value.asset.release()
  assert.equal(value.releases(), 1)
})

test('host cancellation releases its held asset exactly once', async () => {
  const value = setup()
  const pending = value.load()
  await flush()
  value.provider.close()
  assert.ok((await pending).error)
  value.provider.close()
  assert.equal(value.releases(), 1)
  assert.equal(value.probe.read().state, 'cancelled')
  assert.equal(value.probe.read().assetReleased, true)
})

test('consumer cancellation is observed while held', async () => {
  const value = setup()
  const pending = value.load()
  await flush()
  value.cancellation.cancel()
  assert.ok((await pending).error)
  assert.equal(value.releases(), 1)
  assert.equal(value.probe.read().state, 'cancelled')
})

test('cancel between release request and delivery does not transfer the asset', async () => {
  const value = setup()
  const pending = value.load()
  await flush()
  const held = value.probe.read()
  assert.equal(value.probe.release(held.epoch, held.requestId), true)
  value.provider.close()
  assert.ok((await pending).error)
  assert.equal(value.releases(), 1)
  assert.equal(value.probe.read().state, 'cancelled')
})

test('host exit during underlying load releases the real asset when it eventually arrives', async () => {
  const value = setup(1000, true)
  const pending = value.load()
  await flush()
  assert.equal(value.probe.read().state, 'loading')
  value.provider.close()
  value.finishLoad()
  assert.ok((await pending).error)
  assert.equal(value.releases(), 1)
  assert.equal(value.probe.read().state, 'cancelled')
})

test('timeout is a recognizable failure, never a successful release', async () => {
  const value = setup(10)
  const result = await value.load()
  assert.ok(result.error)
  assert.equal(value.probe.read().state, 'failed')
  assert.equal(value.probe.read().failureReason, 'timeout')
  assert.equal(value.probe.read().assetReleased, true)
  assert.equal(value.releases(), 1)
  const state = value.probe.read()
  assert.equal(value.probe.release(state.epoch, state.requestId), false)
})

test('a new epoch cancels the old hold and old releases cannot touch the replacement', async () => {
  const value = setup()
  const pending = value.load()
  await flush()
  const old = value.probe.read()
  const replacement = value.probe.arm('678049', 0)
  assert.ok((await pending).error)
  assert.equal(value.releases(), 1)
  assert.equal(value.probe.release(old.epoch, old.requestId), false)
  value.provider.close()
  assert.equal(value.probe.read().epoch, replacement)
  assert.equal(value.probe.read().state, 'armed')
})

test('gallery/page consumption is exact and one-shot; non-original assets bypass the gate', async () => {
  const value = setup()
  const epoch = value.probe.arm('678049', 0)
  assert.equal(value.probe.consume('678050', 0), 0)
  assert.equal(value.probe.consume('678049', 1), 0)
  assert.equal(value.probe.consume('678049', 0), epoch)
  assert.equal(value.probe.consume('678049', 0), 0)
  const provider = new value.Provider(value.inner, epoch, '678049', 0, 1000)
  assert.equal(await provider.load(value.page, 'thumbnail', value.cancellation, false), value.asset)
  assert.equal(value.probe.read().state, 'consumed')
})

test('reader facts are live detached copies, and retired hosts cannot replace the current owner', () => {
  const value = setup()
  const facts = new value.shared.ReaderTrialOriginalFacts()
  facts.entryId = 12; facts.entryPhase = 'layout'; facts.anchor = 0
  value.probe.bindFacts(value.epoch, () => facts)
  const read = value.probe.read()
  read.reader.entryPhase = 'finished'
  assert.equal(value.probe.read().reader.entryPhase, 'layout')
  facts.entryPhase = 'cancelled'; facts.anchor = 1
  assert.equal(value.probe.read().reader.anchor, 1)
  value.probe.detachFacts(value.epoch)
  facts.anchor = 2
  assert.equal(value.probe.read().reader.anchor, 1)
  const next = value.probe.arm('678049', 0)
  value.probe.bindFacts(value.epoch, () => facts)
  assert.equal(value.probe.read().epoch, next)
  assert.equal(value.probe.read().reader.entryPhase, 'none')
})
