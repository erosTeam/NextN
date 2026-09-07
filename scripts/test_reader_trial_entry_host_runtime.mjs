import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { test } from 'node:test'
import vm from 'node:vm'

const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js')
const read = path => readFileSync(new URL(path, import.meta.url), 'utf8')

function compile(source, filename) {
  const result = ts.transpileModule(source, { fileName: filename, reportDiagnostics: true,
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } })
  const errors = result.diagnostics.filter(value => value.category === ts.DiagnosticCategory.Error)
  if (errors.length) throw new Error(ts.formatDiagnosticsWithColorAndContext(errors, {
    getCanonicalFileName: value => value, getCurrentDirectory: () => '', getNewLine: () => '\n',
  }))
  return result.outputText
}

function section(source, start, end) {
  const first = source.indexOf(start)
  const last = source.indexOf(end, first + start.length)
  if (first < 0 || last < 0) throw new Error(`Cannot load source section: ${start}`)
  return source.slice(first, last)
}

// Load contiguous real host methods, including its actual install handler. Omit only the
// unrelated ArkUI builders/rest of Index; no method body is copied or rewritten here.
const index = read('../entry/src/main/ets/pages/Index.ets')
const hostSource = section(index, 'struct Index {', '\n  @Builder')
  .replace('struct Index {', 'export class Index {') +
  section(index, "  @Monitor('readerLabLaunch.version')", '\n  private stack:') + '\n}'
const hostCode = compile(hostSource.replace(/@Local\s+/g, '').replace(/@Monitor\([^\n]*\)\s*/g, ''), 'Index.ets')
const claimCode = compile('export ' + section(index, 'class ReaderEntryClaim {', '/** Pending feedback'), 'Index.ets')
const relayCode = compile(read('../shared/src/main/ets/navigation/ReaderTrialEntryRelay.ets'), 'ReaderTrialEntryRelay.ets')
const rectCode = compile(section(read('../../reader-kit/reader-ui/src/main/ets/ReaderEntryTransition.ets'),
  'export class ReaderEntryRect {', 'export class ReaderEntryTarget {'), 'ReaderEntryTransition.ets')

function moduleExports(code, globals = {}, filename = 'runtime.ets') {
  const exports = {}
  vm.runInNewContext(code, { exports, ...globals }, { filename })
  return exports
}

function setup() {
  const shared = moduleExports(relayCode, {}, 'ReaderTrialEntryRelay.ets')
  const { ReaderEntryRect } = moduleExports(rectCode, {}, 'ReaderEntryTransition.ets')
  const { ReaderEntryClaim } = moduleExports(claimCode, {}, 'Index.ets')
  const visibility = { foreground: true }
  const safeMode = { restricted: () => false }
  let nextRequest = null
  let measurements = 0
  let windowOpens = 0
  let windowCloses = 0
  const context = { applicationInfo: { debug: true } }
  const uiContext = {
    getHostContext: () => context,
    getComponentUtils: () => ({ getRectangleById() {
      measurements++
      throw new Error('platform rectangle unavailable for this live source')
    } }),
    // Geometry-free fallback must not request a snapshot or synthesize a target.
    getComponentSnapshot() { throw new Error('unexpected snapshot request') },
  }
  class NavPathStack {
    clears = 0
    clear() { this.clears++ }
  }
  class ReaderTrialWindow {
    open() { windowOpens++ }
    close() { windowCloses++ }
  }
  const { Index } = moduleExports(hostCode, {
    ...shared, ReaderEntryRect, ReaderEntryClaim, NavPathStack, ReaderTrialWindow,
    connectReaderLabLaunch: () => ({ consume() { const value = nextRequest; nextRequest = null; return value } }),
    connectReaderLabVisibility: () => visibility,
    connectSafeMode: () => safeMode,
  }, 'Index.ets')
  const host = new Index()
  // Ambient owners outside the extracted reader-entry lane, not replacement host methods.
  host.rootNavigationEpoch = 0
  host.readerOverlay = { visible: false }
  host.safeMode = safeMode
  host.getUIContext = () => uiContext
  host.context = () => context
  host.pushGallery = () => {}
  const source = new shared.ReaderTrialEntrySource(678049, 0, 'source-frame', 'source-snapshot',
    'detail', 'https://example.invalid/thumbnail.jpg')
  source.isCurrent = () => true
  function arm() {
    const request = { work: '678049', pageIndex: 0, thumbnailEntry: true, readingChrome: true, entryProbe: '' }
    nextRequest = request
    host.handleReaderLabLaunch()
    return request
  }
  return { host, source, arm, relay: shared.ReaderTrialEntryRelay, ReaderEntryClaim, ReaderEntryRect,
    measurements: () => measurements, windowOpens: () => windowOpens, windowCloses: () => windowCloses }
}

test('live source measurement failure holds the real relay through fallback and same-frame repeat until close', async () => {
  const value = setup()
  const request = value.arm()
  assert.equal(value.relay.tryOpen(value.source), true)
  const trialEpoch = value.host.readerTrialEpoch
  const token = value.host.readerTrialEntryGuardToken
  assert.ok(token > 0)
  assert.equal(value.host.readerTrialRequest, request)
  assert.equal(value.host.readerEntryClaim, null)
  assert.equal(value.host.readerEntryTransition, null)
  assert.equal(value.host.readerEntryPreview, null)
  assert.equal(value.measurements(), 1)
  assert.equal(value.windowOpens(), 1)
  // Deliberately no await/render opportunity between these two actual relay clicks.
  assert.equal(value.relay.tryOpen(value.source), true)
  assert.equal(value.host.readerTrialEpoch, trialEpoch)
  assert.equal(value.host.readerTrialEntryGuardToken, token)
  assert.equal(value.measurements(), 1)
  assert.equal(value.windowOpens(), 1)
  await Promise.resolve()
  value.host.closeReaderTrial()
  assert.equal(value.host.readerTrialRequest, null)
  assert.equal(value.host.readerTrialEntryGuardToken, 0)
  assert.equal(value.windowCloses(), 1)
  assert.equal(value.relay.tryOpen(value.source), false)
})

test('new host intent retires fallback but an old token cannot release its replacement', () => {
  const value = setup()
  value.arm()
  assert.equal(value.relay.tryOpen(value.source), true)
  const oldToken = value.host.readerTrialEntryGuardToken
  const replacement = value.arm()
  assert.equal(value.host.readerTrialRequest, null)
  assert.equal(value.host.readerTrialEntryGuardToken, 0)
  assert.equal(value.windowCloses(), 1)
  assert.equal(value.relay.tryOpen(value.source), true)
  const newToken = value.host.readerTrialEntryGuardToken
  assert.notEqual(newToken, oldToken)
  value.relay.releasePending(oldToken)
  assert.equal(value.relay.tryOpen(value.source), true)
  assert.equal(value.host.readerTrialRequest, replacement)
  assert.equal(value.host.readerTrialEntryGuardToken, newToken)
  assert.equal(value.windowOpens(), 2)
  value.host.closeReaderTrial()
  assert.equal(value.relay.tryOpen(value.source), false)
})

test('clearing an existing source claim clears feedback ownership but retains the trial click guard', () => {
  const value = setup()
  value.arm()
  assert.equal(value.relay.tryOpen(value.source), true)
  const token = value.host.readerTrialEntryGuardToken
  // Seed an already-held claim as input state; capture/layout execution is not under test.
  value.host.readerEntryClaim = new value.ReaderEntryClaim(value.host.readerEntryEpoch,
    value.host.rootNavigationEpoch, value.source, new value.ReaderEntryRect(1, 2, 30, 40),
    new value.ReaderEntryRect(0, 0, 100, 200))
  value.host.releaseReaderEntryClaim()
  assert.equal(value.host.readerEntryClaim, null)
  assert.equal(value.host.readerTrialEntryGuardToken, token)
  assert.equal(value.relay.tryOpen(value.source), true)
  value.host.closeReaderTrial()
  assert.equal(value.relay.tryOpen(value.source), false)
})
