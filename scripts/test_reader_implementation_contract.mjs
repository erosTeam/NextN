
import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const ts = require(process.env.READER_KIT_TYPESCRIPT ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const read = p => fs.readFileSync(path.join(root, p), 'utf8')

function compileNamed(source, name, deps) {
  const out = {}
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, { exports: out,
    require: n => {
      if (n in deps) return deps[n]
      return {}
    } })
  return out[name]
}

// In-memory RDB shim; one shared store so writes are visible to later reads.
const sharedRows = new Map()
function makeStore() {
  return {
    async executeSql(sql, params) {
      if (sql.includes('ON CONFLICT')) sharedRows.set(params[0], params[1])
    },
    async querySql(sql, params) {
      const key = params[0]
      const has = sharedRows.has(key)
      const value = has ? sharedRows.get(key) : null
      let position = 0
      return {
        goToFirstRow: () => { position = has ? 0 : -1; return has },
        goToNextRow: () => { if (position === 0 && has) { position = 1; return true } return false },
        getColumnIndex: () => 0,
        isColumnNull: () => !has,
        getString: () => value,
        close: () => {},
      }
    },
  }
}

const sharedStore = makeStore()
const kit = { relationalStore: { getRdbStore: async () => sharedStore } }

// The model module is ArkTS; transpile the enum subset the repository needs.
const modelOut = {}
vm.runInNewContext(ts.transpileModule(read('shared/src/main/ets/model/NhReaderSettings.ets'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText, { exports: modelOut, require: () => ({}) })
const ModelModule = {
  NhReaderBackgroundMode: modelOut.NhReaderBackgroundMode,
  NhReaderColumnMode: modelOut.NhReaderColumnMode,
  NhReaderImageScalingQuality: modelOut.NhReaderImageScalingQuality,
  NhReaderMode: modelOut.NhReaderMode,
  NhReaderSpreadLayout: modelOut.NhReaderSpreadLayout,
  NhReaderSuperResolutionModel: modelOut.NhReaderSuperResolutionModel,
  READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT: modelOut.READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT,
  READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT_CHOICES: modelOut.READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT_CHOICES,
}

const repoSource = read('shared/src/main/ets/storage/ReaderSettingsRepository.ets')
const localStoreSource = read('shared/src/main/ets/storage/LocalDataStore.ets')
// LocalDataStore needs @kit.ArkData relationalStore + common; stub both.
const Repo = compileNamed(repoSource, 'ReaderSettingsRepository', {
  '@kit.ArkData': kit,
  '@kit.AbilityKit': {},
  '../model/NhReaderSettings': ModelModule,
  './LocalDataStore': { LocalDataStore: { open: async () => sharedStore } },
})

test('implementation preference defaults to shared and round-trips legacy/shared', async () => {
  const context = {}
  assert.equal(await Repo.readerImplementation(context), 'shared', 'absent key resolves to the shared default')
  await Repo.saveReaderImplementation(context, 'legacy')
  assert.equal(await Repo.readerImplementation(context), 'legacy', 'explicit legacy persists')
  await Repo.saveReaderImplementation(context, 'shared')
  assert.equal(await Repo.readerImplementation(context), 'shared', 'switching back persists shared')
  await Repo.saveReaderImplementation(context, 'bogus')
  assert.equal(await Repo.readerImplementation(context), 'shared', 'unknown values fail closed to shared')
})

// Selection state: compile with a minimal AppStorageV2 stub.
const selectionSource = read('shared/src/main/ets/state/NextNReaderBackendSelectionState.ets')
const Selection = compileNamed(selectionSource.replace(/^\s*@(?:ObservedV2|Trace)\b.*$/gm, ''), 'connectNextNReaderBackendSelection', {
  '@kit.AbilityKit': { Want: class Want {} },
  '@kit.ArkUI': { AppStorageV2: { connect: (cls, _key, factory) => factory() } },
})

test('release no longer fails closed: selection accepts shared and legacy', () => {
  const state = Selection()
  assert.equal(state.current(), 'shared', 'process-local default is shared')
  state.selectForRehearsal('legacy', false)
  assert.equal(state.current(), 'legacy', 'release may select legacy (explicit fallback)')
  state.selectForRehearsal('shared', false)
  assert.equal(state.current(), 'shared', 'release may select shared (default)')
})

test('release Want capture keeps the persisted route; debug Want still overrides', () => {
  const state = Selection()
  const mod = {}
  vm.runInNewContext(ts.transpileModule(
    selectionSource.replace(/^\s*@(?:ObservedV2|Trace)\b.*$/gm, ''), { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, { exports: mod, require: n => n === '@kit.ArkUI'
    ? { AppStorageV2: { connect: (_cls, _k, f) => state } } : {} })
  mod.captureNextNReaderBackendWant({ parameters: {} }, false)
  assert.equal(state.current(), 'shared', 'release normal launch keeps the persisted default')
  mod.captureNextNReaderBackendWant({ parameters: { nextn_reader_backend: 'legacy' } }, true)
  assert.equal(state.current(), 'legacy', 'debug Want overrides to legacy')
  mod.captureNextNReaderBackendWant({ parameters: {} }, true)
  assert.equal(state.current(), 'legacy', 'debug launch without the parameter keeps the current override')
})
