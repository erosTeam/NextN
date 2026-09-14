import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const kit = path.resolve(root, 'third_party/reader-kit')
const load = require(path.join(kit, 'tests/load-core.cjs'))
const core = { ...load('ReaderContent'), ...load('ReaderDisplayMap') }
const sourcePath = path.join(root, 'feature/reader/src/main/ets/lab/NextNReaderObservedProgress.ets')
const source = fs.readFileSync(sourcePath, 'utf8')
const output = ts.transpileModule(source, { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
} }).outputText
const exports = {}
vm.runInNewContext(output, { exports, require: name => {
  assert.equal(name, '@reader-kit/core')
  return core
} })
const Progress = exports.NextNReaderObservedProgress

function anchor(work = '123', page = 1, key = `${work}:${page + 20}`, fragment = 'whole') {
  return new core.ReaderReadingAnchor(new core.ReaderUnitKey('nh', work, work), key, page, 0.5, 0, fragment)
}

const relay = new Progress()
assert.equal(relay.observe('123', 5, anchor()), 1)
assert.equal(relay.observe('123', 5, anchor('123', 1, '123:21', 'left')), -1)
assert.equal(relay.observe('123', 5, anchor('123', 1, '123:21', 'right')), -1)
assert.equal(relay.observe('123', 5, anchor('123', 2)), 2)
assert.equal(relay.observe('123', 5, anchor('123', 1)), 1)

for (const invalid of [
  new core.ReaderReadingAnchor(new core.ReaderUnitKey('eh', '123', '123'), '123:21', 1),
  new core.ReaderReadingAnchor(new core.ReaderUnitKey('nh', 'other', 'other'), '123:21', 1),
  new core.ReaderReadingAnchor(new core.ReaderUnitKey('nh', '123', 'other'), '123:21', 1),
  anchor('123', 1, null),
  anchor('123', 1, 'other:21'),
  anchor('123', -1),
  anchor('123', 5),
]) assert.equal(relay.observe('123', 5, invalid), -1)
assert.equal(relay.observe('123', Number.NaN, anchor('123', 3)), -1)
assert.equal(relay.observe('123', 0, anchor('123', 0)), -1)

assert.equal(relay.observe('__rkit_local_fixture__', 3, anchor('__rkit_local_fixture__', 0)), -1)
assert.equal(relay.observe('456', 3, anchor('456', 0)), 0)

const pageSource = fs.readFileSync(path.join(root, 'feature/reader/src/main/ets/lab/NextNReaderLabPage.ets'), 'utf8')
assert.match(pageSource, /observation: new ReaderObservationSink\([\s\S]*this\.observeReaderPosition\(anchor\)/)
assert.match(pageSource, /this\.observedProgress\.observe\(this\.request\.work, pageCount, anchor\)/)
assert.match(pageSource, /this\.progressWrites\.save\(this\.progressEpoch, this\.request\.work, pageIndex\)/)
assert.doesNotMatch(pageSource, /HistoryRepository|saveProgress/)

let probeState
const probeSource = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderObservedProgressProbe.ets'), 'utf8')
const probeOutput = ts.transpileModule(probeSource, { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, experimentalDecorators: true,
} }).outputText
const probeExports = {}
vm.runInNewContext(probeOutput, {
  exports: probeExports,
  require: name => {
    assert.equal(name, '@kit.ArkUI')
    return { AppStorageV2: { connect: (_type, create) => probeState ??= create() } }
  },
  ObservedV2: value => value,
})
const probe = probeExports.connectNextNReaderObservedProgressProbe()
const delivered = []
const first = probe.arm('123', page => delivered.push(page))
probe.deliver('other', 1); probe.deliver('123', 1); probe.deliver('123', 2)
assert.deepEqual(delivered, [1, 2])
const second = probe.arm('456', page => delivered.push(page))
probe.cancel(first); probe.deliver('456', 0)
assert.deepEqual(delivered, [1, 2, 0])
probe.cancel(second); probe.deliver('456', 1)
assert.deepEqual(delivered, [1, 2, 0])

console.log('PASS actual shared-anchor to NextN page-progress mapping; no persistence or device acceptance')
