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
const core = load('ReaderDisplayMap')
function compile(source, deps = {}, globals = {}) {
  const out = {}
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, experimentalDecorators: true,
  } }).outputText, { exports: out, require: name => {
    assert.ok(name in deps, name); return deps[name]
  }, console: { warn() {}, info() {} }, ...globals })
  return out
}
let launchState
const parser = compile(fs.readFileSync(path.join(kit, 'reader-ui/src/main/ets/ReaderLabLaunch.ets'), 'utf8'), {
  '@kit.ArkUI': { AppStorageV2: { connect: (_type, create) => launchState ??= create() } },
}, { ObservedV2: value => value, Trace() {} })
const enums = { NhReaderMode: { PAGED: 'paged', PAGED_RTL: 'paged_rtl', PAGED_VERTICAL: 'paged_vertical', VERTICAL: 'vertical' },
  NhReaderColumnMode: { ODD_LEFT: 'odd_left', EVEN_LEFT: 'even_left' }, NhReaderSpreadLayout: { JOINED: 'joined', SPLIT: 'split' } }
const resolver = compile(fs.readFileSync(path.join(root, 'feature/reader/src/main/ets/lab/NextNReaderInitialPolicy.ets'), 'utf8'), {
  '@reader-kit/core': core, shared: enums,
}).NextNReaderInitialPolicy
function request(extra = {}) {
  parser.captureReaderLabWant({ parameters: { readerLabWork: '123', readerLabPage: '7', ...extra } }, true)
  return parser.connectReaderLabLaunch().consume()
}
for (const mode of Object.values(enums.NhReaderMode)) for (const doublePageEnabled of [false, true]) {
  for (const column of ['odd_left', 'even_left']) for (const spreadLayoutMode of ['joined', 'split']) {
    const r = request(), index = r.pageIndex
    const p = resolver.resolve({ mode, doublePageEnabled, spreadLayoutMode }, column,
      r.entryLayoutOverride, r.entryDirectionOverride)
    assert.equal(p.layout, mode === 'vertical' ? 'continuous' :
      ['paged', 'paged_rtl'].includes(mode) && doublePageEnabled ? 'spread' : 'single')
    assert.equal(p.pagingAxis, mode === 'paged_vertical' ? 'vertical' : 'horizontal')
    assert.equal(p.direction, mode === 'paged_rtl' ? 'rtl' : 'ltr')
    assert.equal(p.firstPageAlone, column === 'even_left'); assert.equal(p.spreadLayout, spreadLayoutMode)
    assert.equal(r.pageIndex, index)
  }
}
for (const [layout, direction] of [[undefined, undefined], ['bad', 'bad'], ['single', 'ltr'], ['spread', 'rtl'],
  ['continuous', 'ltr']]) {
  const r = request({ readerLabEntryLayout: layout, readerLabEntryDirection: direction })
  const valid = layout === 'single' || layout === 'spread' || layout === 'continuous'
  assert.equal(r.entryLayout, layout === 'spread' ? 'spread' : 'single')
  assert.equal(r.entryDirection, direction === 'rtl' ? 'rtl' : 'ltr')
  assert.equal(r.entryLayoutOverride, valid ? layout : null)
  assert.equal(r.entryDirectionOverride, valid ? direction : null)
  const p = resolver.resolve({ mode: 'paged_rtl', doublePageEnabled: true, spreadLayoutMode: 'split' }, 'even_left',
    r.entryLayoutOverride, r.entryDirectionOverride)
  assert.equal(p.layout, valid ? layout : 'spread'); assert.equal(p.direction, valid ? direction : 'rtl')
  assert.equal(p.pagingAxis, layout === 'continuous' ? 'vertical' : 'horizontal')
}
const pageSource = fs.readFileSync(path.join(root, 'feature/reader/src/main/ets/lab/NextNReaderLabPage.ets'), 'utf8')
const transitionStateSource = fs.readFileSync(path.join(root,
  'shared/src/main/ets/state/ReaderThumbnailTransitionState.ets'), 'utf8')
assert.match(pageSource,
  /canvasBackdropOpacity: this\.readerThumbnailTransition\.backdropOpacity,[\s\S]*?bodyOpacity: this\.readerThumbnailTransition\.readerBodyOpacity\(\),[\s\S]*?input: this\.input, mediaActions: this\.mediaActions/)
assert.match(transitionStateSource,
  /readerBodyOpacity\(\): number \{\s*return this\.closingProxyVisible\(\) \? 0 : 1/)
const hostRequestSource = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderHostRequest.ets'), 'utf8')
const productionRequestSource = hostRequestSource.slice(hostRequestSource.indexOf('export class NextNProductionReaderRequest'))
for (const field of ['failurePage', 'thumbnailFailurePage', 'shareProbe', 'informationProbe',
  'entryLayoutOverride', 'entryDirectionOverride', 'cropBorders', 'pageTurnAnimationOverride']) {
  assert.doesNotMatch(productionRequestSource, new RegExp(`\\b${field}\\b`))
}
assert.match(pageSource, /@Param labRequest: ReaderLabRequest \| null = null/)
assert.match(pageSource, /lab === null \? translationProvider :\s*new ReaderLabAssetProbe/)
assert.match(pageSource, /lab === null \? imageShare : new ReaderLabShareProbe/)
for (const [extra, expectedLayout, expectedDirection, expectedAxis] of [
  [{ readerLabEntryLayout: 'single' }, 'single', 'ltr', 'horizontal'],
  [{ readerLabEntryLayout: 'continuous' }, 'continuous', 'ltr', 'vertical'],
  [{ readerLabEntryDirection: 'rtl' }, 'single', 'rtl', 'vertical'],
]) {
  const r = request(extra)
  const p = resolver.resolve({ mode: 'paged_vertical', doublePageEnabled: true, spreadLayoutMode: 'split' }, 'even_left',
    r.entryLayoutOverride, r.entryDirectionOverride)
  assert.equal(p.layout, expectedLayout); assert.equal(p.direction, expectedDirection); assert.equal(p.pagingAxis, expectedAxis)
}
const tree = ts.createSourceFile('page.ts', pageSource.replace('export struct NextNReaderLabPage', 'export class NextNReaderLabPage'), ts.ScriptTarget.Latest, true)
const cls = tree.statements.find(ts.isClassDeclaration)
const methods = ['initializeSession', 'closeTrial', 'finishProgressWrites', 'hostRouteActive', 'initialCropBorders']
  .map(name => cls.members.find(m => m.name?.getText(tree) === name).getText(tree)).join('\n')
const deferred = () => { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b }); return { promise, resolve, reject } }
const flush = () => new Promise(resolve => setImmediate(resolve))
function fixture() {
  const restore = deferred(), column = deferred(), events = []
  const Host = compile(`export class Host { ${methods} }`, {}, {
    ReaderPresentationService: { restore: () => restore.promise, snapshot: () => ({ mode: 'paged', doublePageEnabled: true }) },
    ReaderSelfHostedRehearsal: { consumeSuperResolutionRecording: () => false },
    ReaderSettingsRepository: { columnMode: (_context, id) => { assert.equal(id, 123); events.push('column'); return column.promise } },
    NextNReaderInitialPolicy: resolver,
    ReaderCloseContext: { from: () => null },
  }).Host
  const host = new Host()
  const labRequest = request()
  Object.assign(host, { request: labRequest, labRequest, volumeDisposed: false, closeRequested: false, hostClosing: false,
    presentationReady: false, managesTrialWindow: false, progressFlush: null, progressEpoch: 1,
    progressPersistence: { restore: (_work, pageIndex) => Promise.resolve(pageIndex) },
    progressWrites: { seal() {}, flush: () => Promise.resolve(true) },
    syncReaderActivity: () => events.push('sync'), onClose: () => events.push('close') })
  Object.defineProperty(host, 'session', {
    get() { return this.published ?? null },
    set(value) { events.push('publish'); this.published = value },
  })
  const session = {
    setPolicy(p) { assert.equal(p.layout, 'spread'); events.push('policy') },
    setRetainedDecisionDiagnostic() {},
  }
  const task = host.initializeSession({}, session)
  return { host, restore, column, events, task }
}
{
  const f = fixture(); assert.deepEqual(f.events, [])
  f.restore.resolve(); await flush(); assert.deepEqual(f.events, ['column']); assert.equal(f.host.presentationReady, false)
  f.column.resolve('even_left'); await f.task
  assert.deepEqual(f.events, ['column', 'policy', 'publish', 'sync']); assert.equal(f.host.presentationReady, true)
}
for (const phase of ['restore', 'column']) {
  const f = fixture()
  if (phase === 'column') { f.restore.resolve(); await flush() }
  f[phase].reject(Error('read failed')); await f.task
  assert.equal(f.host.presentationReady, false); assert.equal(f.host.published, undefined)
  assert.equal(f.events.at(-1), 'close')
}
for (const gate of ['volumeDisposed', 'closeRequested', 'hostClosing']) for (const phase of ['restore', 'column']) {
  for (const rejected of [false, true]) {
    const f = fixture()
    if (phase === 'column') { f.restore.resolve(); await flush() }
    f.host[gate] = true
    rejected ? f[phase].reject(Error('late failure')) : f[phase].resolve('even_left')
    await f.task
    assert.equal(f.host.published, undefined); assert.equal(f.events.includes('close'), false)
  }
}
for (const disposed of [false, true]) {
  const f = fixture(), restoration = deferred()
  // Keep initialization pending; exercise the actual standalone close method separately.
  f.host.managesTrialWindow = true
  f.host.routeActive = false
  f.host.trialWindow = { close: () => { f.events.push('restore-window'); return restoration.promise } }
  f.host.closeTrial(true)
  assert.deepEqual(f.events, ['restore-window'])
  await flush(); assert.equal(f.events.includes('close'), false)
  f.host.volumeDisposed = disposed
  restoration.resolve(); await flush()
  assert.equal(f.events.includes('close'), !disposed)
  f.restore.resolve(); await f.task
  assert.equal(f.host.published, undefined)
}
// Execute the real entry owner: this is a scope fence, not a source-text assertion.
const appear = cls.members.find(m => m.name?.getText(tree) === 'aboutToAppear').getText(tree)
let contextProbeState
const probeModule = compile(fs.readFileSync(path.join(root, 'feature/reader/src/main/ets/lab/NextNReaderLabContextProbe.ets'), 'utf8'), {
  '@kit.ArkUI': { AppStorageV2: { connect: (_type, create) => contextProbeState ??= create() } },
}, { ObservedV2: value => value })
const probe = probeModule.connectNextNReaderLabContextProbe()
assert.equal(probeModule.connectNextNReaderLabContextProbe(), probe)
const debugContext = { applicationInfo: { debug: true } }, productionContext = { applicationInfo: { debug: false } }
let received = []
probe.deliver('123', debugContext)
assert.deepEqual(received, [])
probe.arm('123', value => received.push(value))
probe.deliver('other', debugContext); probe.deliver('123', productionContext)
assert.deepEqual(received, [])
probe.deliver('123', debugContext); probe.deliver('123', debugContext)
assert.deepEqual(received, [debugContext])
const stale = probe.arm('old', () => assert.fail('stale receiver'))
probe.arm('123', value => received.push(value)); probe.cancel(stale)
probe.deliver('123', debugContext)
assert.equal(received.length, 2)
probe.arm('123', () => probe.arm('next', value => received.push(value)))
probe.deliver('123', debugContext); probe.deliver('next', debugContext)
assert.equal(received.length, 3)
const cancelled = probe.arm('123', () => assert.fail('cancelled receiver'))
probe.cancel(cancelled); probe.deliver('123', debugContext)
const NonDebugHost = compile(`export class Host { ${appear} }`, {}, {
  connectNextNReaderLabContextProbe: () => assert.fail('non-debug handoff'),
}).Host
const nonDebugHost = new NonDebugHost()
nonDebugHost.getUIContext = () => ({ getHostContext: () => productionContext })
nonDebugHost.request = { productionSources: false }
nonDebugHost.notifyEntrySettled = () => {}
nonDebugHost.aboutToAppear()
for (const [readingChrome, thumbnailEntry] of [[true, false], [true, true], [false, false]]) {
  const events = [], sessions = []
  class Stub {}
  class Session {
    constructor() { sessions.push(this) }
    setPolicy(policy) { this.policy = policy; events.push('policy') }
    setRetainedDecisionDiagnostic() {}
  }
  const Host = compile(`export class Host { ${appear} }`, {}, {
    connectNextNReaderLabContextProbe: probeModule.connectNextNReaderLabContextProbe,
    connectNextNReaderObservedProgressProbe: () => ({ deliver() {} }),
    NextNReaderProgressPersistence: class { save() { return Promise.resolve() } },
    ReaderKeepScreenOn: Stub, NextNReaderLabAdapter: Stub, NextNReaderImageShareHost: Stub,
    NextNReaderSuperResolutionProvider: Stub, NextNReaderTranslationProvider: Stub,
    connectNextNReaderTranslationProbe: () => ({ bindAction() {} }),
    ReaderLabShareProbe: Stub, ReaderSystemImageSaveHost: Stub, ReaderUnitKey: Stub,
    ReaderMediaActions: class { constructor(...args) { this.args = args } },
    ReaderTrialOriginalProbe: { consume: () => 0 }, ReaderSelfHostedRehearsal: { consumeSuperResolutionRecording: () => false }, ReaderPagedSession: Session,
    ReaderLabAssetProbe: Stub, ReaderDisplayPolicy: core.ReaderDisplayPolicy,
  }).Host
  const host = new Host()
  const labRequest = { ...request(), readingChrome, thumbnailEntry,
    entryLayout: 'spread', entryDirection: 'rtl' }
  Object.assign(host, { request: labRequest, labRequest, managesTrialWindow: false,
    progressWrites: { open: () => 1 },
    notifyEntrySettled: () => {},
    getUIContext: () => ({ getHostContext: () => ({ applicationInfo: { debug: true } }) }),
    restorePresentation: () => { events.push('restore'); return Promise.resolve() },
    initializeSession: (_context, session) => { assert.equal(session, sessions[0]); events.push('initialize'); return Promise.resolve() },
  })
  Object.defineProperty(host, 'session', {
    get() { return host.published ?? null },
    set(value) { host.published = value; events.push('publish') },
  })
  let handoffs = 0
  probe.arm(host.request.work, value => { assert.equal(value.applicationInfo.debug, true); handoffs++ })
  host.aboutToAppear()
  assert.equal(handoffs, 1)
  if (readingChrome) {
    assert.deepEqual(events, ['initialize']); assert.equal(host.published, undefined)
  } else {
    assert.deepEqual(events, ['restore', 'publish']); assert.equal(host.published.policy, undefined)
  }
}
const cropMethod = cls.members.find(m => m.name?.getText(tree) === 'initialCropBorders').getText(tree)
const CropHost = compile(`export class Host { ${cropMethod} }`, {}, { NhReaderMode: enums.NhReaderMode }).Host
for (const [request, labRequest, presentation, expected] of [
  [{ productionSources: true }, { cropBorders: true },
    { mode: 'vertical', cropBordersContinuous: true, cropBordersPaged: true }, true],
  [{ productionSources: true }, { cropBorders: false },
    { mode: 'paged_rtl', cropBordersContinuous: false, cropBordersPaged: true }, true],
  [{ productionSources: false }, { cropBorders: true },
    { mode: 'paged', cropBordersContinuous: false, cropBordersPaged: false }, true],
  [{ productionSources: false }, { cropBorders: false },
    { mode: 'vertical', cropBordersContinuous: true, cropBordersPaged: true }, false],
  [{ productionSources: true }, { cropBorders: false },
    { mode: 'vertical', cropBordersContinuous: true, cropBordersPaged: false }, true],
  [{ productionSources: true }, { cropBorders: false },
    { mode: 'paged_vertical', cropBordersContinuous: true, cropBordersPaged: false }, false],
  [{ productionSources: true }, { cropBorders: false },
    { mode: 'paged_rtl', cropBordersContinuous: false, cropBordersPaged: true }, true],
]) {
  const host = new CropHost()
  Object.assign(host, { request, labRequest, readerPresentation: presentation })
  assert.equal(host.initialCropBorders(), expected)
}
assert.match(pageSource,
  /new ReaderCropPolicy\([\s\S]*?this\.request\.productionSources === true \|\| this\.labRequest\?\.cropBorders === true/,
  'thumbnail entry must not disable the production crop control')
// Compose the real thumbnail entry and initialization methods, with deferred I/O.
for (const [mode, extra, expected] of [
  ['vertical', {}, ['continuous', 'horizontal', 'ltr']],
  ['paged_vertical', { readerLabEntryDirection: 'rtl' }, ['single', 'vertical', 'rtl']],
  ['paged_rtl', {}, ['spread', 'horizontal', 'rtl']],
  ['paged_rtl', { readerLabEntryLayout: 'single' }, ['single', 'horizontal', 'rtl']],
]) for (const ending of ['ready', 'close', 'failure']) {
  const restore = deferred(), column = deferred(), events = []
  class Stub {}
  class Session {
    setPolicy(p) { this.policy = p; events.push('policy') }
    setRetainedDecisionDiagnostic() {}
  }
  const Host = compile(`export class Host { ${appear} ${methods} }`, {}, {
    connectNextNReaderLabContextProbe: probeModule.connectNextNReaderLabContextProbe,
    connectNextNReaderObservedProgressProbe: () => ({ deliver() {} }),
    NextNReaderProgressPersistence: class {
      save() { return Promise.resolve() }
      restore(_work, pageIndex) { return Promise.resolve(pageIndex) }
    },
    ReaderKeepScreenOn: Stub, NextNReaderLabAdapter: Stub, NextNReaderImageShareHost: Stub, ReaderLabShareProbe: Stub,
    NextNReaderSuperResolutionProvider: Stub, NextNReaderTranslationProvider: Stub,
    connectNextNReaderTranslationProbe: () => ({ bindAction() {} }),
    ReaderSystemImageSaveHost: Stub, ReaderMediaActions: class { constructor(...args) { this.args = args } },
    ReaderUnitKey: Stub, ReaderPagedSession: Session,
    ReaderLabAssetProbe: Stub, ReaderTrialOriginalProbe: { consume: () => 0 },
    ReaderSelfHostedRehearsal: { consumeSuperResolutionRecording: () => false },
    ReaderPresentationService: { restore: () => { events.push('restore'); return restore.promise },
      snapshot: () => ({ mode, doublePageEnabled: true, spreadLayoutMode: 'split' }) },
    ReaderSettingsRepository: { columnMode: () => { events.push('column'); return column.promise } },
    NextNReaderInitialPolicy: resolver,
    ReaderCloseContext: { from: () => null },
  }).Host
  const host = new Host(), r = request({ readerLabChrome: true, readerLabThumbnailEntry: true, ...extra })
  // Index replaces the requested page with the actual clicked source before mounting.
  r.pageIndex = 2
  Object.assign(host, { request: r, labRequest: r, closeRequested: false, hostClosing: false, managesTrialWindow: false,
    progressFlush: null, progressWrites: { open: () => 1, seal() {}, flush: () => Promise.resolve(true) },
    notifyEntrySettled: () => {},
    getUIContext: () => ({ getHostContext: () => debugContext }),
    syncReaderActivity: () => events.push('sync'), onClose: () => events.push('close') })
  Object.defineProperty(host, 'session', {
    get() { return this.published ?? null },
    set(s) { this.published = s; events.push('publish') },
  })
  host.aboutToAppear(); assert.deepEqual(events, ['restore']); assert.equal(host.published, undefined)
  restore.resolve(); await flush(); assert.deepEqual(events, ['restore', 'column'])
  assert.equal(host.published, undefined)
  if (ending === 'close') host.closeTrial()
  ending === 'failure' ? column.reject(Error('column unavailable')) : column.resolve('even_left')
  await flush()
  assert.equal(r.pageIndex, 2)
  if (ending !== 'ready') { assert.equal(host.published, undefined); assert.equal(events.at(-1), 'close'); continue }
  const p = host.published.policy
  assert.deepEqual([p.layout, p.pagingAxis, p.direction], expected)
  assert.equal(p.firstPageAlone, true); assert.equal(p.spreadLayout, 'split')
  assert.deepEqual(events, ['restore', 'column', 'policy', 'publish', 'sync'])
}
console.log('PASS actual initial-policy resolver, Want parser and initialization methods; no ArkUI/device acceptance')
