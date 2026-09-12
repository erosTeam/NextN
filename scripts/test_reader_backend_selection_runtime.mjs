import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

function compile(source, dependencies = {}, globals = {}) {
  const exports = {}
  const output = ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS,
    target: ts.ScriptTarget.ES2020,
    experimentalDecorators: true,
  } }).outputText
  vm.runInNewContext(output, {
    exports,
    require(name) {
      assert.ok(name in dependencies, name)
      return dependencies[name]
    },
    ...globals,
  })
  return exports
}

let storedState
const state = compile(fs.readFileSync(path.join(root,
  'shared/src/main/ets/state/NextNReaderBackendSelectionState.ets'), 'utf8'), {
  '@kit.AbilityKit': {},
  '@kit.ArkUI': { AppStorageV2: { connect: (_type, _key, create) => storedState ??= create() } },
}, { ObservedV2: value => value, Trace() {} })

const selected = state.connectNextNReaderBackendSelection()
assert.equal(selected.current(), state.NextNReaderBackend.LEGACY)
state.captureNextNReaderBackendWant({ parameters: {} }, true)
assert.equal(selected.current(), state.NextNReaderBackend.LEGACY)
state.captureNextNReaderBackendWant({ parameters: { nextn_reader_backend: 'shared' } }, true)
assert.equal(selected.current(), state.NextNReaderBackend.SHARED)
assert.equal(selected.version, 1)
state.captureNextNReaderBackendWant({ parameters: { nextn_reader_backend: 'invalid' } }, true)
assert.equal(selected.current(), state.NextNReaderBackend.SHARED)
state.captureNextNReaderBackendWant({ parameters: {} }, true)
assert.equal(selected.current(), state.NextNReaderBackend.SHARED)
state.captureNextNReaderBackendWant({ parameters: { nextn_reader_backend: 'legacy' } }, true)
assert.equal(selected.current(), state.NextNReaderBackend.LEGACY)
assert.equal(selected.version, 2)
selected.select(state.NextNReaderBackend.SHARED)
state.captureNextNReaderBackendWant({ parameters: { nextn_reader_backend: 'shared' } }, false)
assert.equal(selected.current(), state.NextNReaderBackend.LEGACY, 'release builds must remain legacy')

const params = compile(fs.readFileSync(path.join(root,
  'shared/src/main/ets/model/ReaderRouteParams.ets'), 'utf8'), {
  '../state/NextNReaderBackendSelectionState': state,
}).ReaderRouteParams
const legacy = new params(123, 2)
assert.equal(legacy.backend, state.NextNReaderBackend.LEGACY)
const shared = new params(123, 2, 0, state.NextNReaderBackend.SHARED)
assert.equal(shared.backend, state.NextNReaderBackend.SHARED)

const overlaySource = fs.readFileSync(path.join(root,
  'shared/src/main/ets/state/ReaderOverlayNavigationState.ets'), 'utf8')
const overlay = compile(overlaySource, {
  '@kit.ArkUI': { AppStorageV2: { connect: (_type, _key, create) => create() } },
  '../model/NhGallery': {},
  '../model/ReaderRouteParams': { ReaderRouteParams: params },
  './ReaderThumbnailTransitionState': { connectReaderThumbnailTransition: () => ({ reset() {} }) },
}, { ObservedV2: value => value, Trace() {}, NavPathStack: class {
  paths = []
  clear() { this.paths = [] }
  pushPathByName(name, value) { this.paths.push([name, value]) }
  getAllPathName() { return this.paths.map(value => value[0]) }
  pop() { this.paths.pop() }
} }).ReaderOverlayNavigationState

const navigation = new overlay()
navigation.open(shared, false)
navigation.presentPendingReader()
assert.equal(navigation.stack.paths[1][1].backend, state.NextNReaderBackend.SHARED,
  'the route must retain the backend selected at open time')
selected.select(state.NextNReaderBackend.LEGACY)
assert.equal(navigation.stack.paths[1][1].backend, state.NextNReaderBackend.SHARED,
  'an open route must not switch when the process selector changes')

console.log('PASS debug-only backend selection and route snapshot; shared body routing remains separate')
