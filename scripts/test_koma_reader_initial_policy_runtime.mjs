import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
import { createRequire } from 'node:module'
const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const base = new URL('../../Koma/entry/src/main/ets/', import.meta.url)
const read = name => fs.readFileSync(new URL(name, base), 'utf8')
const core = require('../../reader-kit/tests/load-core.cjs')('ReaderDisplayMap')
const content = require('../../reader-kit/tests/load-core.cjs')('ReaderContent')
const cancellation = require('../../reader-kit/tests/load-core.cjs')('ReaderSession')
function compile(source, deps = {}, globals = {}) {
  const out = {}
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, { exports: out, require: name => {
    assert.ok(name in deps, name); return deps[name]
  }, console: { warn() {} }, ...globals })
  return out
}
const models = compile(read('model/ComicModels.ets'), { '../i18n/AppStrings': {} })
const resolve = compile(read('readerLab/KomaReaderInitialPolicy.ets'), {
  '@reader-kit/core': core, '../model/ComicModels': models,
}).KomaReaderInitialPolicy.resolve
const request = { pageIndex: 1, entryLayoutOverride: null, entryDirectionOverride: null }
{
  const prefs = { pageMode: 'double_page', readingDirection: models.ReadingDirection.RIGHT_TO_LEFT, spreadLayoutMode: 'split' }
  const direction = resolve(prefs, 'even_left', { ...request, entryDirectionOverride: 'ltr' })
  assert.equal(direction.direction, 'ltr'); assert.equal(direction.layout, 'spread')
  const layout = resolve(prefs, 'even_left', { ...request, entryLayoutOverride: 'single' })
  assert.equal(layout.layout, 'single'); assert.equal(layout.direction, 'rtl')
}
for (const mode of ['single_page', 'double_page', 'continuous_scroll', 'vertical_page']) {
  for (const direction of Object.values(models.ReadingDirection)) {
    for (const column of ['odd_left', 'even_left']) for (const spread of ['joined', 'split']) {
      const prefs = { pageMode: mode, readingDirection: direction, spreadLayoutMode: spread }
      const p = resolve(prefs, column, request)
      assert.equal(p.layout, mode === 'vertical_page' ? 'single' : mode === 'continuous_scroll' ||
        direction === models.ReadingDirection.WEBTOON ? 'continuous' : mode === 'double_page' ? 'spread' : 'single')
      assert.equal(p.pagingAxis, mode === 'vertical_page' ? 'vertical' : 'horizontal')
      assert.equal(p.direction, direction === models.ReadingDirection.RIGHT_TO_LEFT ? 'rtl' : 'ltr')
      assert.equal(p.spreadLayout, spread); assert.equal(p.firstPageAlone, column === 'even_left')
      for (const override of ['single', 'spread']) {
        const changed = resolve(prefs, column, { ...request, entryLayoutOverride: override, entryDirectionOverride: 'rtl' })
        assert.equal(changed.layout, override); assert.equal(changed.pagingAxis, 'horizontal')
        assert.equal(changed.direction, 'rtl'); assert.equal(changed.firstPageAlone, p.firstPageAlone)
      }
    }
  }
}
function methods(file, names) {
  const tree = ts.createSourceFile('host.ts', read(file).replace(/\bstruct (\w+)/, 'class $1'), ts.ScriptTarget.Latest, true)
  const cls = tree.statements.find(ts.isClassDeclaration)
  return names.map(name => cls.members.find(m => m.name?.getText(tree) === name).getText(tree)).join('\n')
}
const Index = compile(`export class Host { ${methods('pages/Index.ets', ['readReaderLabInitialColumn'])} }`).Host
const index = new Index()
let restored = 0
index.readerSessionStore = { restoreColumnMode(config, fallback) {
  restored++; assert.equal(config.comicId, 'qa-work'); assert.equal(config.chapterId, 'resolved-first')
  assert.equal(fallback, 'odd_left'); return 'even_left'
}, flush() { assert.fail('must not flush') } }
assert.throws(() => index.readReaderLabInitialColumn('qa-work', 'resolved-first'))
assert.equal(restored, 0)
index.readerSessionPersistenceReady = true
assert.equal(index.readReaderLabInitialColumn('qa-work', 'resolved-first'), 'even_left')
assert.equal(restored, 1)
const source = methods('readerLab/KomaReaderLabPage.ets',
  ['aboutToAppear', 'aboutToDisappear', 'initializeSession', 'closeReader', 'switchChapter'])
function fixture() {
  let fulfill, reject
  const promise = new Promise((a, b) => { fulfill = a; reject = b })
  const events = []
  const Host = compile(`export class Host { ${source} }`, {}, {
    ReaderCancellation: cancellation.ReaderCancellation,
    ReaderPreferencesStore: class { load() { events.push('load'); return promise } },
    KomaReaderInitialPolicy: { resolve },
    KomaReaderLabAdapter: class { constructor() { throw Error('library unavailable') } },
  }).Host
  const h = new Host()
  Object.assign(h, { readerClosed: false, initialization: null, request,
    unitKey: { work: 'qa-work', unit: 'resolved-first' },
    getUIContext: () => ({ getHostContext: () => ({ applicationInfo: { debug: true } }) }),
    readInitialColumn: (...args) => { events.push('column'); return index.readReaderLabInitialColumn(...args) },
    syncKeepScreenOn() { events.push('screen') }, syncVolumeKeys() { events.push('volume') },
    volumeKeys: { close() {} }, cancelChapterRequest() {}, onClose() { events.push('close') },
    trialWindow: { close() {} },
  })
  Object.defineProperty(h, 'session', { set(value) { events.push('publish'); this.published = value } })
  const session = { setPolicy(p) { assert.equal(p.layout, 'spread'); assert.equal(p.firstPageAlone, true); events.push('policy') } }
  const task = h.initializeSession({}, session)
  return { h, task, fulfill, reject, events }
}
const prefs = { pageMode: 'double_page', readingDirection: models.ReadingDirection.LEFT_TO_RIGHT, spreadLayoutMode: 'split' }
{
  const f = fixture(); assert.deepEqual(f.events, ['load']); f.fulfill(prefs); await f.task
  assert.deepEqual(f.events, ['load', 'column', 'policy', 'publish', 'screen', 'volume'])
}
for (const reject of [false, true]) {
  const f = fixture(); f.h.closeReader(); reject ? f.reject(Error('load')) : f.fulfill(prefs); await f.task
  assert.equal(f.h.published, undefined); assert.deepEqual(f.events, ['load', 'close'])
}
{
  const f = fixture(); f.h.aboutToDisappear(); f.fulfill(prefs); await f.task
  assert.deepEqual(f.events, ['load']); assert.equal(f.h.published, undefined)
}
{
  const f = fixture(); f.h.initialization.cancel(); f.fulfill(prefs); await f.task
  assert.deepEqual(f.events, ['load']); assert.equal(f.h.published, undefined)
}
{
  const f = fixture(); f.h.request = { ...request, readingChrome: true }
  f.h.aboutToAppear(); f.fulfill(prefs); await f.task
  assert.equal(f.h.published, null)
  assert.equal(f.h.error, 'reader_lab_library_unavailable')
  assert.deepEqual(f.events, ['load', 'publish']) // Only clearing the old session, never publishing pending work.
}
{
  const f = fixture()
  f.h.readInitialColumn = () => { f.h.closeReader(); return 'even_left' }
  f.fulfill(prefs); await f.task
  assert.deepEqual(f.events, ['load', 'close']); assert.equal(f.h.published, undefined)
}
{
  const f = fixture(); f.reject(Error('load')); await f.task
  assert.deepEqual(f.events, ['load', 'close']); assert.equal(f.h.published, undefined)
}
{
  const f = fixture(); index.readerSessionPersistenceReady = false; f.fulfill(prefs); await f.task
  assert.deepEqual(f.events, ['load', 'column', 'close']); assert.equal(f.h.published, undefined)
}
{
  const Host = compile(`export class Host { ${methods('readerLab/KomaReaderLabPage.ets', ['switchChapter'])} }`, {}, {
    ReaderCancellation: cancellation.ReaderCancellation,
  }).Host
  const host = new Host(), sourceKey = new content.ReaderUnitKey('koma-local', 'qa', 'a')
  const target = new content.ReaderUnitKey('koma-local', 'qa', 'b'), events = []
  const runtimePolicy = { layout: 'continuous', direction: 'rtl' }
  host.session = { snapshot: () => ({ phase: 'ready', unit: { key: sourceKey } }),
    open: async key => { assert.ok(key.equals(target)); events.push('open') },
    setPolicy: () => assert.fail('chapter switch must not reset policy'), policy: runtimePolicy }
  host.adapter = { adjacent: () => target, prepare: async () => events.push('prepare') }
  Object.assign(host, { chapterBusy: false, readerClosed: false, routeActive: true, labVisibility: { foreground: true } })
  await host.switchChapter('next', sourceKey)
  assert.deepEqual(events, ['prepare', 'open']); assert.equal(host.session.policy, runtimePolicy)
  assert.equal(host.chapterBusy, false)
}
function chapterDeferred() {
  let resolve
  const promise = new Promise(a => { resolve = a })
  return { promise, resolve }
}
function chapterHost(prepare) {
  const Host = compile(`export class Host { ${methods('readerLab/KomaReaderLabPage.ets',
    ['switchChapter', 'cancelChapterRequest', 'onChapterActivityChanged'])} }`, {}, {
    ReaderCancellation: cancellation.ReaderCancellation,
    Monitor: () => () => {},
    $r: value => value,
  }).Host
  const sourceKey = new content.ReaderUnitKey('koma-local', 'qa', 'a')
  const target = new content.ReaderUnitKey('koma-local', 'qa', 'b')
  const events = []
  let visibleKey = sourceKey
  const host = new Host()
  Object.assign(host, {
    session: {
      snapshot: () => ({ phase: 'ready', unit: { key: visibleKey } }),
      open: async key => { assert.ok(key.equals(target)); events.push('open') },
    },
    adapter: {
      adjacent: () => target,
      prepare: async (...args) => { events.push('prepare'); return prepare(...args) },
    },
    chapterBusy: false,
    chapterRequest: null,
    readerClosed: false,
    routeActive: true,
    labVisibility: { foreground: true },
    getUIContext: () => ({ getPromptAction: () => ({
      showToast: ({ message }) => { events.push(`toast:${message}`) },
    }) }),
  })
  return { host, sourceKey, target, events, setVisibleKey: key => { visibleKey = key } }
}
{
  const f = chapterHost(async () => { throw Error('target unavailable') })
  await f.host.switchChapter('next', f.sourceKey)
  assert.deepEqual(f.events, ['prepare', 'toast:app.string.manga_detail_chapter_pages_load_failed'])
  assert.equal(f.host.chapterBusy, false); assert.equal(f.host.chapterRequest, null)
}
{
  const wait = chapterDeferred(), f = chapterHost(() => wait.promise)
  const first = f.host.switchChapter('next', f.sourceKey)
  const duplicate = f.host.switchChapter('next', f.sourceKey)
  await duplicate
  assert.deepEqual(f.events, ['prepare'])
  wait.resolve(); await first
  assert.deepEqual(f.events, ['prepare', 'open']); assert.equal(f.host.chapterBusy, false)
}
{
  const wait = chapterDeferred(), f = chapterHost(() => wait.promise)
  const task = f.host.switchChapter('next', f.sourceKey)
  f.setVisibleKey(f.target)
  wait.resolve(); await task
  assert.deepEqual(f.events, ['prepare']); assert.equal(f.host.chapterBusy, false)
}
for (const inactive of ['background', 'hidden']) {
  const wait = chapterDeferred(), f = chapterHost(() => wait.promise)
  const task = f.host.switchChapter('next', f.sourceKey)
  if (inactive === 'background') f.host.labVisibility.foreground = false
  else f.host.routeActive = false
  f.host.onChapterActivityChanged()
  wait.resolve(); await task
  assert.deepEqual(f.events, ['prepare']); assert.equal(f.host.chapterBusy, false)
  assert.equal(f.host.chapterRequest, null)
}
{
  const Host = compile(`export class Host { ${methods('readerLab/KomaReaderLabPage.ets',
    ['syncVolumeKeys', 'syncKeepScreenOn'])} }`, {}, { Monitor: () => () => {} }).Host
  const host = new Host(), events = []
  Object.assign(host, { readerClosed: false, request: { readingChrome: true, volumeKeysOverride: null },
    session: null, routeActive: true, labVisibility: { foreground: true },
    readerMode: { hydrated: true, volumeKeyNavigationEnabled: true,
      volumeKeyBehavior: 'up_next_down_previous', keepScreenAwake: true },
    volumeKeys: { setActive: (...args) => events.push(['volume', ...args]) },
    keepScreenOn: { setActive: enabled => events.push(['screen', enabled]) } })
  host.syncVolumeKeys(); host.syncKeepScreenOn()
  assert.deepEqual(events.splice(0), [['volume', false, true], ['screen', false]])
  host.session = {}
  host.syncVolumeKeys(); host.syncKeepScreenOn()
  assert.deepEqual(events.splice(0), [['volume', true, true], ['screen', true]])
  host.readerClosed = true; host.syncVolumeKeys()
  assert.deepEqual(events.splice(0), [['volume', false, true]])
  host.readerClosed = false; host.labVisibility.foreground = false
  host.syncVolumeKeys(); host.syncKeepScreenOn()
  assert.deepEqual(events.splice(0), [['volume', false, true], ['screen', false]])
}
console.log('PASS actual Koma policy mapping, initial lifecycle, chapter success/failure/duplicate/stale/inactive gates and input/screen publication; no build or UI/device acceptance')
