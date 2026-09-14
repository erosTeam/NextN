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
assert.equal(selected.current(), state.NextNReaderBackend.LEGACY,
  'an invalid debug launch must fail closed to the production-safe backend')
assert.equal(selected.version, 2)
state.captureNextNReaderBackendWant({ parameters: { nextn_reader_backend: 'shared' } }, true)
assert.equal(selected.current(), state.NextNReaderBackend.SHARED)
state.captureNextNReaderBackendWant({ parameters: {} }, true)
assert.equal(selected.current(), state.NextNReaderBackend.LEGACY,
  'a normal launch must retire a shared rehearsal left by an interrupted test')
state.captureNextNReaderBackendWant({ parameters: { nextn_reader_backend: 'legacy' } }, true)
assert.equal(selected.current(), state.NextNReaderBackend.LEGACY)
assert.equal(selected.version, 4)
selected.select(state.NextNReaderBackend.SHARED)
state.captureNextNReaderBackendWant({ parameters: { nextn_reader_backend: 'shared' } }, false)
assert.equal(selected.current(), state.NextNReaderBackend.LEGACY, 'release builds must remain legacy')
selected.selectForRehearsal(state.NextNReaderBackend.SHARED, true)
assert.equal(selected.current(), state.NextNReaderBackend.SHARED,
  'the in-app Debug rehearsal may select the shared backend without a Want')
selected.selectForRehearsal(state.NextNReaderBackend.SHARED, false)
assert.equal(selected.current(), state.NextNReaderBackend.LEGACY,
  'the same in-app request must fail closed in a release build')
selected.selectForRehearsal(state.NextNReaderBackend.LEGACY, true)
assert.equal(selected.current(), state.NextNReaderBackend.LEGACY,
  'one explicit Debug selection must restore the legacy backend')

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
  './NextNReaderBackendSelectionState': state,
  './ReaderThumbnailTransitionState': { connectReaderThumbnailTransition: () => ({ reset() {} }) },
}, { ObservedV2: value => value, Trace() {}, NavPathStack: class {
  paths = []
  clear() { this.paths = [] }
  pushPathByName(name, value) { this.paths.push([name, value]) }
  async pushDestinationByName(name, value) { this.paths.push([name, value]) }
  getAllPathName() { return this.paths.map(value => value[0]) }
  pop() { this.paths.pop() }
} }).ReaderOverlayNavigationState

const navigation = new overlay()
const sharedEpoch = navigation.open(shared, false)
assert.equal(navigation.mountEpoch, sharedEpoch)
assert.equal(navigation.activeReader.backend, state.NextNReaderBackend.SHARED,
  'shared Reader must be exposed directly to the shell host')
assert.equal(navigation.activeReader.routeEpoch, sharedEpoch,
  'the direct shared route must retain its admission identity')
assert.deepEqual(navigation.stack.paths.map(value => value[0]), ['ReaderOverlayBackdrop'],
  'shared Reader must not be coupled to an HDS destination')
selected.select(state.NextNReaderBackend.LEGACY)
assert.equal(navigation.activeReader.backend, state.NextNReaderBackend.SHARED,
  'an open route must not switch when the process selector changes')

navigation.close(false)
assert.equal(navigation.visible, false)
assert.equal(navigation.activeReader, null)
assert.deepEqual(navigation.stack.paths.map(value => value[0]), ['ReaderOverlayBackdrop'],
  'closing direct Reader must leave legacy adapter state isolated')
const staleEpoch = navigation.open(legacy, false)
const currentEpoch = navigation.open(shared, false)
assert.equal(navigation.mountEpoch, currentEpoch,
  'each admission must expose a distinct host epoch')
await navigation.presentPendingReader(staleEpoch)
assert.deepEqual(navigation.stack.paths.map(value => value[0]), ['ReaderOverlayBackdrop'],
  'a stale frame callback must not present a replacement route')
assert.equal(navigation.activeReader.routeEpoch, currentEpoch,
  'the replacement shared session must own a fresh direct route')

navigation.close(false)
const legacyEpoch = navigation.open(legacy, false)
await navigation.presentPendingReader(legacyEpoch)
assert.equal(navigation.stack.paths[1][1].backend, state.NextNReaderBackend.LEGACY,
  'legacy Reader must retain the backend selected at open time')
assert.equal(navigation.stack.paths[1][0], `Reader:${legacyEpoch}`,
  'legacy compatibility navigation still uses a session-unique destination')

console.log('PASS debug-only backend selection; shared direct host and legacy adapter remain separate')
