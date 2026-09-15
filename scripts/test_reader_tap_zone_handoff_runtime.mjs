import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const read = file => fs.readFileSync(path.resolve(root, file), 'utf8')
const nextERoot = process.env.NEXTE_READER_ROOT || path.resolve(root, '../NextE')
const komaRoot = process.env.KOMA_READER_ROOT || path.resolve(root, '../Koma')
const readNextE = file => fs.readFileSync(path.resolve(nextERoot, file), 'utf8')
const readKoma = file => fs.readFileSync(path.resolve(komaRoot, file), 'utf8')
function compile(source, dependencies = {}, globals = {}) {
  const exports = {}
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, { exports, require(name) {
    assert.ok(name in dependencies, name); return dependencies[name]
  }, ...globals })
  return exports
}
function method(file, name = 'resolveTapZone') {
  const source = read(file)
  const start = source.indexOf(`  private ${name}(`)
  assert.ok(start >= 0, file)
  const end = source.indexOf('\n  }', start)
  assert.ok(end > start, file)
  return source.slice(start, end + 4).replace(`private ${name}`, name)
}
const n = compile(read('shared/src/main/ets/model/NhReaderTapZone.ets'))
const e = compile(readNextE('shared/src/main/ets/utils/ReaderTapZoneResolver.ets'))
const prefs = readKoma('entry/src/main/ets/model/ReaderPreferencesStore.ets')
const parsed = ts.createSourceFile('prefs.ts', prefs, ts.ScriptTarget.Latest, true)
const normalization = parsed.statements.filter(node => ts.isFunctionDeclaration(node) &&
  ['normalizeReaderTapZonePreset', 'normalizeReaderTapZoneInvert'].includes(node.name?.text))
assert.equal(normalization.length, 2)
const kPrefs = compile(normalization.map(node => node.getText(parsed)).join('\n'))
const k = compile(readKoma('entry/src/main/ets/model/ReaderTapZoneGeometry.ets'), {
  './ReaderPreferencesStore': kPrefs,
})
const cases = [
  ['N', 'feature/reader/src/main/ets/lab/NextNReaderLabPage.ets',
    { NhReaderTapZoneResolver: n.NhReaderTapZoneResolver }, n.NhReaderTapZoneResolver.resolve,
    ['rightLeft', 'lShaped', 'kindle', 'edge']],
  ['E', 'feature/reader/src/main/ets/lab/NextEReaderLabPage.ets',
    { ReaderTapZoneResolver: e.ReaderTapZoneResolver }, e.ReaderTapZoneResolver.resolve,
    ['rightLeft', 'lShaped', 'kindle', 'edge']],
  ['K', 'entry/src/main/ets/readerLab/KomaReaderLabPage.ets',
    { ...kPrefs, resolveReaderTapZoneAction: k.resolveReaderTapZoneAction }, k.resolveReaderTapZoneAction,
    ['right_left', 'l_shaped', 'kindle', 'edge', 'wide_edges']],
]
let checks = 0
for (const [name, file, globals, reference, presets] of cases) {
  const source = name === 'N' ? read(file) : name === 'E' ? readNextE(file) : readKoma(file)
  if (name !== 'K') assert.match(source, /tapPolicy:\s*new ReaderTapPolicy\(/)
  const sourceMethod = (methodName = 'resolveTapZone') => {
    const start = source.indexOf(`  private ${methodName}(`)
    assert.ok(start >= 0, file)
    const end = source.indexOf('\n  }', start)
    assert.ok(end > start, file)
    return source.slice(start, end + 4).replace(`private ${methodName}`, methodName)
  }
  const hostMethods = sourceMethod() + (name === 'N' ? sourceMethod('hostRouteActive') : '')
  const Host = compile(`export class Host { ${hostMethods} }`, {}, globals).Host
  const host = new Host()
  const state = { hydrated: true, restoreResult: 'applied', mode: 'paged_rtl' }
  Object.assign(host, { presentationReady: true, volumeDisposed: false, closeRequested: false,
    hostClosing: false, readerClosed: false, routeActive: true, labVisibility: { foreground: true },
    session: {}, readerPresentation: state, readMode: state, readerMode: state })
  for (const layout of ['single', 'spread', 'continuous']) {
    for (const preset of presets) for (const invert of ['none', 'horizontal', 'vertical', 'both']) {
      Object.assign(state, { tapZoneLayoutPaged: 'kindle', tapZoneInvertPaged: 'both',
        tapZoneLayoutContinuous: 'edge', tapZoneInvertContinuous: 'vertical',
        tapZonePreset: preset, tapZoneInvert: invert })
      if (layout === 'continuous') {
        state.tapZoneLayoutContinuous = preset; state.tapZoneInvertContinuous = invert
      } else {
        state.tapZoneLayoutPaged = preset; state.tapZoneInvertPaged = invert
      }
      const before = JSON.stringify(state)
      for (const x of [0.1, 0.5, 0.9]) for (const y of [0.1, 0.5, 0.9]) {
        const normalized = name === 'K' ? kPrefs.normalizeReaderTapZonePreset(preset) : preset
        const expected = reference(normalized, invert, x * 1260, y * 2720, 1260, 2720)
        assert.equal(host.resolveTapZone(x, y, layout), expected, `${name}/${layout}/${preset}/${invert}/${x}/${y}`)
        checks++
      }
      assert.equal(JSON.stringify(state), before, 'resolver must not write settings or saved mode')
    }
  }
  const inactive = name === 'K' ? ['readerClosed'] : ['volumeDisposed', 'closeRequested', 'hostClosing']
  for (const field of inactive) {
    host[field] = true; assert.equal(host.resolveTapZone(0.9, 0.9, 'single'), 'none'); host[field] = false
  }
  host.routeActive = false; assert.equal(host.resolveTapZone(0.9, 0.9, 'single'), 'none'); host.routeActive = true
  host.labVisibility.foreground = false; assert.equal(host.resolveTapZone(0.9, 0.9, 'single'), 'none')
  host.labVisibility.foreground = true
  host.session = null; assert.equal(host.resolveTapZone(0.9, 0.9, 'single'), 'none'); host.session = {}
  if (name === 'N') host.presentationReady = false
  if (name === 'E') state.restoreResult = 'pending'
  if (name === 'K') state.hydrated = false
  assert.equal(host.resolveTapZone(0.9, 0.9, 'single'), 'none')
}
// Reference semantics: presets may emit logical actions, not physical directions.
assert.equal(n.NhReaderTapZoneResolver.resolve('lShaped', 'none', .5, .1, 1, 1), 'previous')
assert.equal(e.ReaderTapZoneResolver.resolve('kindle', 'none', .9, .9, 1, 1), 'next')
assert.equal(k.resolveReaderTapZoneAction('right_left', 'horizontal', .1, .5, 1, 1), 'right')
console.log(`PASS ${checks} actual host/resolver comparisons and lifecycle/no-write assertions; no ArkUI/device acceptance`)
