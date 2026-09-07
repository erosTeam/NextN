import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { test } from 'node:test'
import vm from 'node:vm'

const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js')
const source = readFileSync(new URL('../shared/src/main/ets/navigation/ReaderTrialEntryRelay.ets', import.meta.url), 'utf8')
const code = ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2020,
  module: ts.ModuleKind.CommonJS,
} }).outputText

// Execute the complete production source in a fresh VM so registrations cannot leak between tests.
function setup() {
  const exports = {}
  vm.runInNewContext(code, { exports }, { filename: 'ReaderTrialEntryRelay.ets' })
  const { ReaderTrialEntryRelay: relay, ReaderTrialEntrySource: Source } = exports
  const entry = (galleryId = 678049, pageIndex = 0, origin = 'detail') => new Source(
    galleryId, pageIndex, 'source-frame', 'source-snapshot', origin, 'https://example.invalid/thumbnail.jpg',
  )
  return { relay, entry }
}

test('normal entry is not intercepted without a registration', () => {
  const { relay, entry } = setup()
  assert.equal(relay.tryOpen(entry()), false)
})

test('matching registration receives the source and is consumed once', () => {
  const { relay, entry } = setup()
  const source = entry()
  const received = []
  relay.install('678049', value => { received.push(value); return true })
  assert.equal(relay.tryOpen(source), true)
  assert.equal(relay.tryOpen(source), false)
  assert.deepEqual(received, [source])
})

test('another gallery cannot invoke or consume the registration', () => {
  const { relay, entry } = setup()
  let calls = 0
  relay.install('678049', () => { calls += 1; return true })
  assert.equal(relay.tryOpen(entry(677618)), false)
  assert.equal(calls, 0)
  assert.equal(relay.tryOpen(entry()), true)
  assert.equal(calls, 1)
})

test('false preserves registration and allows the production route', () => {
  const { relay, entry } = setup()
  let accept = false
  let calls = 0
  relay.install('678049', () => { calls += 1; return accept })
  assert.equal(relay.tryOpen(entry()), false)
  accept = true
  assert.equal(relay.tryOpen(entry()), true)
  assert.equal(relay.tryOpen(entry()), false)
  assert.equal(calls, 2)
})

test('successful handler cannot clear a new token installed during its call', () => {
  const { relay, entry } = setup()
  const calls = []
  let secondToken = 0
  const firstToken = relay.install('678049', () => {
    calls.push('first')
    secondToken = relay.install('677618', () => { calls.push('second'); return true })
    return true
  })
  assert.equal(relay.tryOpen(entry()), true)
  assert.notEqual(secondToken, firstToken)
  assert.equal(relay.tryOpen(entry()), false)
  assert.equal(relay.tryOpen(entry(677618)), true)
  assert.equal(relay.tryOpen(entry(677618)), false)
  assert.deepEqual(calls, ['first', 'second'])
})

test('stale clear leaves a replacement registration intact', () => {
  const { relay, entry } = setup()
  let oldCalls = 0
  let newCalls = 0
  const oldToken = relay.install('678049', () => { oldCalls += 1; return true })
  const newToken = relay.install('678049', () => { newCalls += 1; return true })
  assert.notEqual(newToken, oldToken)
  relay.clear(oldToken)
  assert.equal(relay.tryOpen(entry()), true)
  assert.equal(oldCalls, 0)
  assert.equal(newCalls, 1)
})

test('owner clear disarms its registration', () => {
  const { relay, entry } = setup()
  let calls = 0
  const token = relay.install('678049', () => { calls += 1; return true })
  relay.clear(token)
  assert.equal(relay.tryOpen(entry()), false)
  assert.equal(calls, 0)
})

test('source retains independent thumbnail identity without inferring decoded size or original mapping', () => {
  const { entry } = setup()
  for (const origin of ['detail', 'grid']) {
    const source = entry(678049, 13, origin)
    assert.equal(source.galleryId, 678049)
    assert.equal(source.pageIndex, 13)
    assert.equal(source.sourceComponentId, 'source-frame')
    assert.equal(source.snapshotComponentId, 'source-snapshot')
    assert.equal(source.origin, origin)
    assert.equal(source.thumbnailUrl, 'https://example.invalid/thumbnail.jpg')
    assert.equal(source.thumbnailResourceId, '678049:13:https://example.invalid/thumbnail.jpg')
    assert.equal(source.objectFit, origin === 'detail' ? 'cover' : 'contain')
    assert.equal(source.decodedWidth, 0)
    assert.equal(source.decodedHeight, 0)
    assert.equal(source.originalRelation, 'unknown')
  }
})
