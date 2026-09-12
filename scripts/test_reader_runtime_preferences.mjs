import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const core = require(path.join(root, 'third_party/reader-kit/tests/load-core.cjs'))('ReaderDisplayMap')
const enums = {
  NhReaderMode: { PAGED: 'paged', PAGED_RTL: 'paged_rtl', PAGED_VERTICAL: 'paged_vertical', VERTICAL: 'vertical' },
  NhReaderColumnMode: { ODD_LEFT: 'odd_left', EVEN_LEFT: 'even_left' },
  NhReaderSpreadLayout: { JOINED: 'joined', SPLIT: 'split' },
}

function compile(source, deps) {
  const out = {}
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, { exports: out, require: name => {
    assert.ok(name in deps, name)
    return deps[name]
  } })
  return out
}

let state, column, events
const service = {
  restore: async () => { events.push('restore') },
  snapshot: () => ({ ...state }),
  setMode: async (_context, value) => { state.mode = value; events.push(`mode:${value}`) },
  setDoublePageEnabled: async (_context, value) => { state.doublePageEnabled = value; events.push(`double:${value}`) },
  setSpreadLayout: async (_context, value) => { state.spreadLayoutMode = value; events.push(`spread:${value}`) },
  setCropBordersPaged: async (_context, value) => { state.cropBordersPaged = value; events.push(`crop-paged:${value}`) },
  setCropBordersContinuous: async (_context, value) => { state.cropBordersContinuous = value; events.push(`crop-continuous:${value}`) },
}
const repository = {
  columnMode: async (_context, gallery) => { assert.equal(gallery, 123); events.push('column-read'); return column },
  saveColumnMode: async (_context, gallery, value) => {
    assert.equal(gallery, 123); column = value; events.push(`column:${value}`)
  },
}
const source = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderRuntimePreferences.ets'), 'utf8')
const Runtime = compile(source, {
  '@kit.AbilityKit': {}, '@reader-kit/core': core,
  shared: { ...enums, ReaderPresentationService: service, ReaderSettingsRepository: repository },
}).NextNReaderRuntimePreferences

function reset(extra = {}) {
  state = { mode: 'paged_rtl', doublePageEnabled: true, spreadLayoutMode: 'joined',
    cropBordersPaged: false, cropBordersContinuous: true, ...extra }
  column = 'odd_left'
  events = []
}
function policy(extra = {}) {
  return Object.assign(new core.ReaderDisplayPolicy(), extra)
}

reset()
await Runtime.applyLayout({}, policy({ layout: 'single', pagingAxis: 'vertical', direction: 'ltr' }))
assert.equal(state.mode, 'paged_vertical')
assert.equal(state.doublePageEnabled, true)
assert.deepEqual(events, ['restore', 'mode:paged_vertical'])

reset()
await Runtime.applyLayout({}, policy({ layout: 'continuous', direction: 'ltr' }))
assert.equal(state.mode, 'vertical')
assert.equal(state.doublePageEnabled, true)
assert.deepEqual(events, ['restore', 'mode:vertical'])

reset()
await Runtime.applyLayout({}, policy({ layout: 'single', pagingAxis: 'horizontal', direction: 'ltr' }))
assert.deepEqual([state.mode, state.doublePageEnabled], ['paged', false])
assert.deepEqual(events, ['restore', 'mode:paged', 'double:false'])

reset({ mode: 'paged', doublePageEnabled: false })
await Runtime.applyLayout({}, policy({ layout: 'spread', direction: 'rtl' }))
assert.deepEqual([state.mode, state.doublePageEnabled], ['paged_rtl', true])
assert.deepEqual(events, ['restore', 'mode:paged_rtl', 'double:true'])

reset({ mode: 'paged', doublePageEnabled: true })
await Runtime.applyDirection({}, policy({ layout: 'spread', direction: 'rtl' }))
assert.equal(state.mode, 'paged_rtl')
assert.equal(state.doublePageEnabled, true)
assert.deepEqual(events, ['restore', 'mode:paged_rtl'])

reset({ mode: 'vertical' })
await Runtime.applyDirection({}, policy({ layout: 'continuous', direction: 'rtl' }))
assert.deepEqual(events, [])
assert.equal(state.mode, 'vertical')

reset({ mode: 'paged_vertical' })
await Runtime.applyDirection({}, policy({ layout: 'single', pagingAxis: 'vertical', direction: 'rtl' }))
assert.deepEqual(events, [])
assert.equal(state.mode, 'paged_vertical')

reset()
await Runtime.applySpreadLayout({}, policy({ spreadLayout: 'split' }))
assert.equal(state.spreadLayoutMode, 'split')
assert.deepEqual(events, ['restore', 'spread:split'])

reset()
await Runtime.applyFirstPageAlone({}, 123, policy({ firstPageAlone: true }))
assert.equal(column, 'even_left')
assert.deepEqual(events, ['column-read', 'column:even_left'])

reset()
await Runtime.applyCrop({}, policy({ layout: 'single' }), true)
assert.equal(state.cropBordersPaged, true)
assert.deepEqual(events, ['restore', 'crop-paged:true'])

reset()
await Runtime.applyCrop({}, policy({ layout: 'continuous' }), false)
assert.equal(state.cropBordersContinuous, false)
assert.deepEqual(events, ['restore', 'crop-continuous:false'])

console.log('PASS NextN host runtime preference intent mapping; dormant settings preserved')
