import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const source = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderProgressWriteGate.ets'), 'utf8')
const output = ts.transpileModule(source, { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
} }).outputText
const exports = {}
vm.runInNewContext(output, { exports })
const Gate = exports.NextNReaderProgressWriteGate

function deferred() {
  let resolve, reject
  const promise = new Promise((yes, no) => { resolve = yes; reject = no })
  return { promise, resolve, reject }
}

const calls = []
const writes = []
const gate = new Gate()
const epoch = gate.open('123', page => {
  calls.push(page)
  const value = deferred()
  writes.push(value)
  return value.promise
})

assert.equal(gate.save(epoch, 'other', 1), false)
assert.equal(gate.save(epoch, '123', -1), false)
assert.equal(gate.save(epoch, '123', 1), true)
assert.deepEqual(calls, [1], 'writer must be invoked immediately for live publication')
assert.equal(gate.save(epoch, '123', 1), false)
assert.equal(gate.save(epoch, '123', 2), true)
assert.deepEqual(calls, [1, 2])
assert.equal(gate.pendingCount(epoch), 2)

writes[0].reject(new Error('old failure'))
await Promise.resolve(); await Promise.resolve()
assert.equal(gate.failurePage(epoch), -1, 'an older failure must not replace the latest position')
writes[1].reject(new Error('latest failure'))
await Promise.resolve(); await Promise.resolve()
assert.equal(gate.failurePage(epoch), 2)
assert.equal(gate.failureMessage(epoch), 'latest failure')
assert.equal(gate.retryLatest(epoch), true)
assert.deepEqual(calls, [1, 2, 2])
writes[2].resolve()
assert.equal(await gate.flush(epoch), true)
assert.equal(gate.pendingCount(epoch), 0)
assert.equal(gate.failurePage(epoch), -1)

gate.seal(epoch)
assert.equal(gate.save(epoch, '123', 3), false)
assert.equal(gate.retryLatest(epoch), false)

const stale = epoch
const nextCalls = []
const next = gate.open('456', page => {
  nextCalls.push(page)
  return Promise.resolve()
})
assert.equal(gate.save(stale, '123', 3), false)
assert.equal(await gate.flush(stale), false)
assert.equal(gate.save(next, '456', 0), true)
assert.equal(await gate.flush(next), true)
assert.deepEqual(nextCalls, [0])

const sync = gate.open('789', () => { throw new Error('sync failure') })
assert.equal(gate.save(sync, '789', 4), true)
assert.equal(gate.failurePage(sync), 4)
assert.equal(gate.failureMessage(sync), 'sync failure')
assert.equal(await gate.flush(sync), false)

const pageSource = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderLabPage.ets'), 'utf8')
assert.match(pageSource, /this\.progressWrites\.open\(this\.request\.work/)
assert.match(pageSource, /this\.progressWrites\.save\(this\.progressEpoch, this\.request\.work, pageIndex\)/)
assert.match(pageSource, /this\.progressWrites\.seal\(this\.progressEpoch\)/)
assert.match(pageSource, /this\.progressWrites\.flush\(this\.progressEpoch\)/)
assert.doesNotMatch(pageSource, /HistoryRepository|saveProgress/)

console.log('PASS immediate progress writer, latest failure retry, stale-session rejection and close flush gate')
