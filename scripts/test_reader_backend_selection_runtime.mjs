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
assert.equal(selected.current(), state.NextNReaderBackend.SHARED,
  'the production default is now the shared reader')
state.captureNextNReaderBackendWant({ parameters: {} }, true)
assert.equal(selected.current(), state.NextNReaderBackend.SHARED,
  'a launch without the override keeps the current (persisted-default) selection')
state.captureNextNReaderBackendWant({ parameters: { nextn_reader_backend: 'shared' } }, true)
assert.equal(selected.current(), state.NextNReaderBackend.SHARED)
assert.equal(selected.version, 0, 're-selecting the current backend is a no-op')
state.captureNextNReaderBackendWant({ parameters: { nextn_reader_backend: 'invalid' } }, true)
assert.equal(selected.current(), state.NextNReaderBackend.SHARED,
  'an invalid debug launch keeps the current selection instead of forcing legacy')
assert.equal(selected.version, 0)
state.captureNextNReaderBackendWant({ parameters: { nextn_reader_backend: 'legacy' } }, true)
assert.equal(selected.current(), state.NextNReaderBackend.LEGACY,
  'an explicit debug Want may route the legacy fallback')
assert.equal(selected.version, 1)
state.captureNextNReaderBackendWant({ parameters: {} }, false)
assert.equal(selected.current(), state.NextNReaderBackend.LEGACY,
  'a release normal launch keeps the in-process selection')
state.captureNextNReaderBackendWant({ parameters: { nextn_reader_backend: 'shared' } }, false)
assert.equal(selected.current(), state.NextNReaderBackend.LEGACY,
  'the debug Want override does not exist in a release build')
selected.selectForRehearsal(state.NextNReaderBackend.SHARED, false)
assert.equal(selected.current(), state.NextNReaderBackend.SHARED,
  'the production settings row may select the shared default in a release build')
selected.selectForRehearsal(state.NextNReaderBackend.LEGACY, false)
assert.equal(selected.current(), state.NextNReaderBackend.LEGACY,
  'the production settings row may select the legacy fallback in a release build')
selected.selectForRehearsal(state.NextNReaderBackend.SHARED, true)
assert.equal(selected.current(), state.NextNReaderBackend.SHARED,
  'one explicit Debug selection may restore the shared backend')

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
  'the Reader destination is admitted after the backdrop, not at open time')
selected.select(state.NextNReaderBackend.LEGACY)
assert.equal(navigation.activeReader.backend, state.NextNReaderBackend.SHARED,
  'an open route must not switch when the process selector changes')

// The shared Reader is admitted by the same checked HDS push as legacy, so it
// inherits the host's own destination transition instead of a hard cut.
assert.equal(navigation.presentPendingReader(sharedEpoch), true)
assert.deepEqual(navigation.stack.paths.map(value => value[0]),
  ['ReaderOverlayBackdrop', `Reader:${sharedEpoch}`],
  'shared Reader must be presented through the host navigation destination')
assert.equal(navigation.stack.paths[1][1].backend, state.NextNReaderBackend.SHARED,
  'the presented HDS destination must still resolve to the shared backend')

navigation.close(false)
assert.deepEqual(navigation.stack.paths.map(value => value[0]), ['ReaderOverlayBackdrop'],
  'closing a shared Reader must pop the same destination legacy uses')
navigation.finishClose()
assert.equal(navigation.visible, false)
assert.equal(navigation.activeReader, null)
const staleEpoch = navigation.open(legacy, false)
const currentEpoch = navigation.open(shared, false)
assert.equal(navigation.mountEpoch, currentEpoch,
  'each admission must expose a distinct host epoch')
await navigation.presentPendingReader(staleEpoch)
assert.deepEqual(navigation.stack.paths.map(value => value[0]), ['ReaderOverlayBackdrop'],
  'a stale frame callback must not present a replacement route')
assert.equal(navigation.activeReader.routeEpoch, currentEpoch,
  'the replacement shared session must own a fresh direct route')
assert.equal(navigation.presentPendingReader(currentEpoch), true)
assert.equal(navigation.stack.paths[1][0], `Reader:${currentEpoch}`,
  'the replacement shared session must present its own HDS destination')

navigation.close(false)
navigation.finishClose()
const legacyEpoch = navigation.open(legacy, false)
await navigation.presentPendingReader(legacyEpoch)
assert.equal(navigation.stack.paths[1][1].backend, state.NextNReaderBackend.LEGACY,
  'legacy Reader must retain the backend selected at open time')
assert.equal(navigation.stack.paths[1][0], `Reader:${legacyEpoch}`,
  'legacy compatibility navigation still uses a session-unique destination')

console.log('PASS debug-only backend selection; both backends share the checked HDS admission')
