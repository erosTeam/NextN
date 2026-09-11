import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const base = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../NextE/shared/src/main/ets')
function fixture(options = {}) {
  const cache = new Map(), states = new Map(), events = []
  const store = {
    getSync(key, fallback) {
      if (options.readFailure) throw Error('read')
      return key === 'reading_progress' ? (options.legacy ?? '') : fallback
    },
    deleteSync() { events.push('delete'); if (options.deleteFailure) throw Error('delete') },
    flushSync() { events.push('flush') },
  }
  const repo = {
    async load() { events.push('load'); if (options.loadHook) await options.loadHook(); if (options.loadFailure) throw Error('load'); return options.entries ?? [] },
    async hasPersistedState() { return false },
    async saveAll() { events.push('save'); if (options.saveFailure) throw Error('save') },
  }
  function load(relative) {
    const filename = path.resolve(base, relative)
    if (cache.has(filename)) return cache.get(filename)
    const exports = {}; cache.set(filename, exports)
    const source = fs.readFileSync(filename + '.ets', 'utf8')
    const code = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2020, experimentalDecorators: true } }).outputText
    vm.runInNewContext(code, { exports, ObservedV2: x => x, Trace() {}, console, setTimeout, clearTimeout,
      require(name) {
        if (name === '@kit.ArkUI') return { AppStorageV2: { connect(type, keyOrCreate, factory) { const create = factory ?? keyOrCreate; if (!states.has(type)) states.set(type, create()); return states.get(type) } } }
        if (name === '@kit.ArkData') return { preferences: { async getPreferences() { if (options.preferenceFailure) throw Error('preferences'); return store } } }
        if (name.endsWith('/DiagnosticLogger')) return { DiagnosticLogger: { warn() { events.push('warn') } } }
        if (name.endsWith('/ReadProgressRepository')) return { ReadProgressRepository: repo }
        if (name.endsWith('/SyncScheduler')) return { SyncScheduler: {} }
        assert.ok(name.startsWith('.'), name)
        return load(path.relative(base, path.resolve(path.dirname(filename), name)))
      },
    }, { filename })
    return exports
  }
  const mode = load('settings/ReadModeSettings').ReadModeSettings
  const gallery = load('settings/GalleryReadProgressSettings').GalleryReadProgressSettings
  const modeState = load('state/ReadModeState').connectReadMode()
  const galleryState = load('state/GalleryReadProgressState').connectGalleryReadProgress()
  const keys = load('constants/StorageKeys').StorageKeys
  // Use the actual key rather than assuming the persisted spelling.
  const get = store.getSync
  store.getSync = (key, fallback) => key === keys.READING_PROGRESS && !options.readFailure ? (options.legacy ?? '') : get(key, fallback)
  return { mode, gallery, modeState, galleryState, events, options }
}
for (const kind of ['mode', 'gallery']) {
  const f = fixture(), state = f[kind + 'State']
  assert.equal(state.restoreResult, 'notStarted'); assert.equal(state.hadSuccessfulRestore, false)
  const pending = f[kind].restore({}); assert.equal(state.restoreResult, 'pending'); await pending
  assert.equal(state.restoreResult, 'applied'); assert.equal(state.hadSuccessfulRestore, true)
  f.options.preferenceFailure = true; await f[kind].restore({})
  assert.equal(state.restoreResult, 'failed'); assert.equal(state.hadSuccessfulRestore, true)
  const failed = fixture({ preferenceFailure: true }); await failed[kind].restore({})
  assert.equal(failed[kind + 'State'].restoreResult, 'failed'); assert.equal(failed[kind + 'State'].hadSuccessfulRestore, false)
}
const legacy = JSON.stringify([{ g: 'sample', i: 4, t: 1, c: 'evenLeft' }])
{
  const f = fixture({ entries: [{ g: 'sample', i: 4, t: 1, c: 'evenLeft' }] })
  await f.gallery.restore({})
  assert.equal(f.galleryState.restoreResult, 'applied')
  assert.equal(f.galleryState.getIndex('sample'), 4)
  assert.equal(f.galleryState.getColumnMode('sample'), 'evenLeft')
}
for (const [options, expected] of [[{}, true], [{ legacy }, true], [{ legacy, saveFailure: true }, false]]) {
  const f = fixture(options)
  assert.equal(await f.gallery.migrateLegacyPreferences({}), expected)
}
{
  const f = fixture({ legacy, deleteFailure: true })
  await assert.rejects(f.gallery.migrateLegacyPreferences({}), /delete/)
}
for (const scenario of [{}, { legacy }, { legacy, saveFailure: true }, { legacy, deleteFailure: true }, { loadFailure: true }]) {
  const f = fixture(scenario), oldRevision = f.galleryState.revision
  await f.gallery.restore({})
  const failed = scenario.saveFailure || scenario.deleteFailure || scenario.loadFailure
  assert.equal(f.galleryState.restoreResult, failed ? 'failed' : 'applied')
  assert.equal(f.galleryState.hadSuccessfulRestore, !failed)
  if (scenario.saveFailure) {
    assert.ok(f.events.includes('save')); assert.ok(f.events.includes('load'))
    assert.ok(!f.events.includes('delete'))
    assert.equal(f.galleryState.revision, oldRevision + 1, 'old empty replacement behavior retained')
  }
  if (scenario.deleteFailure) assert.ok(!f.events.includes('load'))
}
{
  const f = fixture()
  f.options.loadHook = async () => f.galleryState.setIndex('newer', 9, 2)
  await f.gallery.restore({})
  assert.equal(f.galleryState.restoreResult, 'superseded'); assert.equal(f.galleryState.hadSuccessfulRestore, false)
  assert.equal(f.galleryState.getIndex('newer'), 9)
}
{
  const f = fixture({ legacy })
  // Actual migration's queued closure sees the newer revision and must preserve legacy.
  const pending = f.gallery.restore({})
  f.galleryState.setIndex('newer', 9, 2)
  await pending
  assert.equal(f.galleryState.restoreResult, 'superseded')
  assert.ok(!f.events.includes('save')); assert.ok(!f.events.includes('delete')); assert.ok(f.events.includes('load'))
}
function compile(source, globals = {}, dependencies = {}) {
  const exports = {}
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS,
    target: ts.ScriptTarget.ES2020 } }).outputText, { exports, console, ...globals,
    require: name => { assert.ok(name in dependencies, name); return dependencies[name] } })
  return exports
}
const core = require('../../reader-kit/tests/load-core.cjs')('ReaderDisplayMap')
const enums = { ReadMode: { LTR: 'ltr', RTL: 'rtl', TOP_TO_BOTTOM: 'topToBottom', VERTICAL: 'vertical' },
  ReadColumnMode: { EVEN_LEFT: 'evenLeft', ODD_LEFT: 'oddLeft' }, ReadSpreadLayout: { SPLIT: 'split', JOINED: 'joined' } }
const lab = path.resolve(base, '../../../../feature/reader/src/main/ets/lab')
const helper = compile(fs.readFileSync(path.join(lab, 'NextEReaderInitialPolicy.ets'), 'utf8'), {}, {
  '@reader-kit/core': core, shared: enums,
}).NextEReaderInitialPolicy
for (const mode of Object.values(enums.ReadMode)) for (const doublePageEnabled of [false, true]) {
  for (const column of ['oddLeft', 'evenLeft']) for (const spreadLayoutMode of ['joined', 'split']) {
    const request = { pageIndex: 7 }, p = helper.resolve({ mode, doublePageEnabled, spreadLayoutMode }, column, request)
    assert.equal(p.layout, mode === 'vertical' ? 'continuous' : ['ltr', 'rtl'].includes(mode) && doublePageEnabled ? 'spread' : 'single')
    assert.equal(p.pagingAxis, mode === 'topToBottom' ? 'vertical' : 'horizontal')
    assert.equal(p.direction, mode === 'rtl' ? 'rtl' : 'ltr')
    assert.equal(p.firstPageAlone, column === 'evenLeft'); assert.equal(p.spreadLayout, spreadLayoutMode)
    assert.equal(request.pageIndex, 7)
  }
}
for (const [override, layout, direction, axis] of [
  [{}, 'single', 'ltr', 'vertical'], [{ entryLayoutOverride: 'single' }, 'single', 'ltr', 'horizontal'],
  [{ entryDirectionOverride: 'rtl' }, 'single', 'rtl', 'vertical'],
  [{ entryLayoutOverride: 'bad', entryDirectionOverride: 'bad' }, 'single', 'ltr', 'vertical'],
]) {
  const p = helper.resolve({ mode: 'topToBottom', doublePageEnabled: true }, 'oddLeft', override)
  assert.equal(p.layout, layout); assert.equal(p.direction, direction); assert.equal(p.pagingAxis, axis)
}
const source = fs.readFileSync(path.join(lab, 'NextEReaderLabPage.ets'), 'utf8')
const tree = ts.createSourceFile('host.ts', source.replace('export struct NextEReaderLabPage', 'export class NextEReaderLabPage'), ts.ScriptTarget.Latest, true)
const cls = tree.statements.find(ts.isClassDeclaration)
const method = name => cls.members.find(m => m.name?.getText(tree) === name).getText(tree)
function hostFixture(modeResult = 'applied', galleryResult = 'applied') {
  const events = []
  const Host = compile(`export class Host { ${method('initializeSession')} ${method('closeTrial')} }`, {
    NextEReaderInitialPolicy: helper,
    connectGalleryReadProgress: () => ({ restoreResult: galleryResult, hadSuccessfulRestore: true,
      getColumnMode: () => { events.push('column'); return 'evenLeft' } }),
  }).Host
  const host = new Host()
  Object.assign(host, { readMode: { restoreResult: modeResult, hadSuccessfulRestore: true, mode: 'rtl', doublePageEnabled: true },
    request: { work: '7' }, volumeDisposed: false, closeRequested: false, hostClosing: false,
    managesTrialWindow: false, routeActive: false, onClose: () => events.push('close') })
  Object.defineProperty(host, 'session', { set(value) { events.push('publish'); host.published = value } })
  const session = { setPolicy(p) { assert.equal(p.layout, 'spread'); assert.equal(p.firstPageAlone, true); events.push('policy') } }
  return { host, session, events }
}
{
  const f = hostFixture(); f.host.initializeSession(f.session)
  assert.deepEqual(f.events, ['column', 'policy', 'publish'])
}
for (const result of ['notStarted', 'pending', 'failed', 'superseded']) for (const owner of ['mode', 'gallery']) {
  const f = hostFixture(owner === 'mode' ? result : 'applied', owner === 'gallery' ? result : 'applied')
  f.host.initializeSession(f.session); assert.deepEqual(f.events, ['close']); assert.equal(f.host.published, undefined)
}
for (const gate of ['volumeDisposed', 'closeRequested', 'hostClosing']) {
  const f = hostFixture(); f.host[gate] = true; f.host.initializeSession(f.session); assert.deepEqual(f.events, [])
}
for (const disposed of [false, true]) {
  const f = hostFixture(); let release
  f.host.managesTrialWindow = true
  f.host.trialWindow = { close: () => new Promise(resolve => { release = resolve }) }
  f.host.closeTrial(true); assert.deepEqual(f.events, [])
  f.host.volumeDisposed = disposed; release(); await Promise.resolve(); await Promise.resolve()
  assert.deepEqual(f.events, disposed ? [] : ['close'])
}
let probeState
const probeModule = compile(fs.readFileSync(path.join(lab, 'NextEReaderLabContextProbe.ets'), 'utf8'),
  { ObservedV2: value => value }, { '@kit.ArkUI': { AppStorageV2: {
    connect: (_type, create) => probeState ??= create(),
  } } })
const probe = probeModule.connectNextEReaderLabContextProbe()
assert.equal(probeModule.connectNextEReaderLabContextProbe(), probe)
const debugContext = { applicationInfo: { debug: true } }, productionContext = { applicationInfo: { debug: false } }
let received = []
probe.deliver('7', debugContext); assert.deepEqual(received, [])
probe.arm('7', value => received.push(value))
probe.deliver('other', debugContext); probe.deliver('7', productionContext)
assert.deepEqual(received, [])
probe.deliver('7', debugContext); probe.deliver('7', debugContext)
assert.deepEqual(received, [debugContext])
const stale = probe.arm('old', () => assert.fail('stale receiver'))
probe.arm('7', value => received.push(value)); probe.cancel(stale); probe.deliver('7', debugContext)
assert.equal(received.length, 2)
probe.arm('7', () => probe.arm('next', value => received.push(value)))
probe.deliver('7', debugContext); probe.deliver('next', debugContext)
assert.equal(received.length, 3)
const cancelled = probe.arm('7', () => assert.fail('cancelled receiver'))
probe.cancel(cancelled); probe.deliver('7', debugContext)
for (const [readingChrome, thumbnailEntry, debug] of [[true, false, true], [true, true, true], [false, false, true], [true, false, false]]) {
  const events = []
  class Stub {}
  class Session { setPolicy(p) { assert.equal(p.layout, 'spread'); assert.equal(p.direction, 'rtl'); events.push('policy') } }
  const Host = compile(`export class Host { ${method('aboutToAppear')} }`, {
    connectNextEReaderLabContextProbe: () => { assert.equal(debug, true, 'non-debug must not access probe'); return probe },
    ReaderKeepScreenOn: Stub, ReaderUnitKey: Stub, NextEReaderLabAdapter: Stub,
    ReaderLabShareProbe: Stub, ReaderSystemImageSaveHost: Stub, ReaderPagedSession: Session,
    ReaderLabAssetProbe: Stub, ReaderDisplayPolicy: core.ReaderDisplayPolicy,
  }).Host
  const host = new Host()
  Object.assign(host, { request: { readingChrome, thumbnailEntry, work: '7', entryLayout: 'spread', entryDirection: 'rtl' },
    entrySite: 'eh', managesTrialWindow: false,
    getUIContext: () => ({ getHostContext: () => ({ applicationInfo: { debug } }) }),
    initializeSession: () => events.push('initialize') })
  Object.defineProperty(host, 'session', { set() { events.push('publish') } })
  let handoffs = 0
  const epoch = probe.arm('7', value => { assert.equal(value.applicationInfo.debug, true); handoffs++ })
  host.aboutToAppear()
  assert.equal(handoffs, debug ? 1 : 0)
  if (!debug) { probe.deliver('7', debugContext); assert.equal(handoffs, 1) }
  probe.cancel(epoch)
  assert.deepEqual(events, !debug ? [] : thumbnailEntry ? ['policy', 'publish'] : readingChrome ? ['initialize'] : ['publish'])
}
console.log('PASS actual NextE restore/migrate, initial-policy and initialization methods; mocked storage, no UI/device acceptance')
