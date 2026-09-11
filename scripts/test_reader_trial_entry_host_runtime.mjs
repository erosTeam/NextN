import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { test } from 'node:test'
import vm from 'node:vm'
const drainClose = () => new Promise(resolve => setImmediate(resolve))
function chromeHost() {
  const v = setup({ deferRestore: true })
  v.arm(); v.relay.tryOpen(v.source)
  return v
}
test('chrome preparation waits for window then live layout readiness', async () => {
  const v = chromeHost(); let completed = false
  const ready = v.host.prepareReaderTrialChrome(() => true).then(value => { completed = true; return value })
  assert.equal(v.host.testPreparations.length, 1); assert.equal(v.layouts.length, 0)
  v.host.testPreparations[0].resolve(true); await drainClose()
  assert.equal(completed, false); assert.equal(v.layouts.length, 1)
  assert.equal(v.layouts[0].measure(), '')
  v.host.layoutSafeArea.topAvoidHeight = 24
  assert.equal(v.layouts[0].measure(), '24:0')
  assert.equal(v.layouts[0].current(), true)
  v.layouts[0].resolve(true); assert.equal(await ready, true)
})
test('window preparation false does not schedule layout or report readiness', async () => {
  const v = chromeHost()
  const ready = v.host.prepareReaderTrialChrome(() => true)
  v.host.testPreparations[0].resolve(false)
  assert.equal(await ready, false); assert.equal(v.layouts.length, 0)
})
test('stale lease, request, epoch or caller cancels before layout scheduling', async () => {
  for (const changed of ['lease', 'request', 'epoch', 'caller']) {
    const v = chromeHost(); let current = true
    const ready = v.host.prepareReaderTrialChrome(() => current)
    if (changed === 'lease') v.host.readerTrialWindow = {}
    if (changed === 'request') v.host.readerTrialRequest = {}
    if (changed === 'epoch') v.host.readerTrialEpoch++
    if (changed === 'caller') current = false
    v.host.testPreparations[0].resolve(true)
    assert.equal(await ready, false, changed); assert.equal(v.layouts.length, 0)
  }
})
test('closing synchronously cancels chrome preparation before Surface Param propagation', async () => {
  const v = chromeHost(); const lease = v.host.readerTrialWindow
  assert.equal(v.host.readerTrialCloseRequested, false)
  const ready = v.host.prepareReaderTrialChrome(() => true)
  const close = v.host.closeReaderTrial()
  assert.equal(v.host.readerTrialCloseRequested, true)
  v.host.testPreparations[0].resolve(true)
  assert.equal(await ready, false); assert.equal(v.layouts.length, 0)
  v.restores.shift()(); await close
  v.arm(); v.relay.tryOpen(v.source)
  assert.equal(v.host.readerTrialCloseRequested, false)
})
test('layout scheduler sees lease/request/epoch/close invalidation while pending', async () => {
  for (const changed of ['lease', 'request', 'epoch', 'close']) {
    const v = chromeHost()
    const ready = v.host.prepareReaderTrialChrome(() => true)
    v.host.testPreparations[0].resolve(true); await drainClose()
    if (changed === 'lease') v.host.readerTrialWindow = {}
    if (changed === 'request') v.host.readerTrialRequest = {}
    if (changed === 'epoch') v.host.readerTrialEpoch++
    if (changed === 'close') v.host.readerTrialCloseRequested = true
    assert.equal(v.layouts[0].current(), false, changed)
    v.layouts[0].resolve(false); assert.equal(await ready, false)
  }
})

test('ready close waits for actual host layout promise and duplicate close shares it', async () => {
  const v = setup({ readiness: 'ready', deferRestore: true })
  v.arm(); v.relay.tryOpen(v.source)
  const request = v.host.readerTrialRequest, clears = v.host.readerTrialStack.clears
  const lease = v.host.readerTrialWindow
  const close = v.host.closeReaderTrial()
  assert.equal(v.host.closeReaderTrial(), close)
  await drainClose()
  assert.notEqual(lease.colorsStarted, true)
  assert.equal(v.layouts.length, 1)
  assert.equal(v.layouts[0].current(), true)
  assert.equal(v.host.readerTrialRequest, request)
  assert.equal(v.host.readerTrialStack.clears, clears)
  assert.equal(v.host.closeReaderTrial(), close)
  v.layouts[0].resolve(true); await drainClose()
  assert.equal(lease.callbackResult, true)
  assert.equal(lease.colorsStarted, true); assert.notEqual(lease.colorsCompleted, true)
  assert.equal(v.host.readerTrialRequest, request)
  assert.equal(v.host.readerTrialStack.clears, clears)
  v.restores.shift()(); await close
  assert.equal(lease.colorsCompleted, true)
  assert.equal(v.host.readerTrialRequest, null)
  assert.equal(v.host.readerTrialStack.clears, clears + 1)
  assert.ok(v.logs.includes('[ReaderTrialHost] close_layout_ready=true'))
})

test('destroy or replace while layout is pending rejects late clear', async () => {
  for (const action of ['destroy', 'replace']) {
    const v = setup({ readiness: 'ready', deferRestore: true })
    v.arm(); v.relay.tryOpen(v.source)
    const lease = v.host.readerTrialWindow
    const close = v.host.closeReaderTrial()
    await drainClose()
    const clears = v.host.readerTrialStack.clears
    if (action === 'destroy') v.host.aboutToDisappear()
    else { v.host.readerTrialRequest = { work: 'replacement' }; v.host.readerTrialEpoch++ }
    const retained = v.host.readerTrialRequest
    assert.equal(v.layouts[0].current(), false)
    v.layouts[0].resolve(false); await drainClose()
    assert.equal(lease.callbackResult, false)
    assert.equal(lease.colorsStarted, true); assert.notEqual(lease.colorsCompleted, true)
    assert.equal(v.host.readerTrialRequest, retained)
    v.restores.shift()(); await close
    assert.equal(lease.colorsCompleted, true)
    assert.equal(v.host.readerTrialRequest, retained)
    assert.equal(v.host.readerTrialStack.clears, clears)
    assert.equal(v.logs.includes('[ReaderTrialHost] close_layout_ready=true'), false)
  }
})

test('failed and not-required restoration never report layout readiness', async () => {
  for (const readiness of ['failed', 'not-required', 'already-visible']) {
    const v = setup({ readiness, deferRestore: true })
    v.arm(); v.relay.tryOpen(v.source)
    const close = v.host.closeReaderTrial()
    v.restores.shift()(); await close
    assert.equal(v.layouts.length, 0)
    assert.equal(v.logs.some(message => message.includes('close_layout_ready=')), false)
    assert.equal(v.host.readerTrialRequest, null)
  }
})

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
  section(index, "  @Monitor('readerLabLaunch.version')", '\n  private stack:') +
  section(index, '  aboutToDisappear(): void {', "  @Monitor('homeTab.autoHide')") + '\n}'
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

function setup({ deferRestore = false, readiness = 'not-required' } = {}) {
  const layouts = [], logs = [], preparations = []
  const shared = moduleExports(relayCode, {}, 'ReaderTrialEntryRelay.ets')
  const { ReaderEntryRect } = moduleExports(rectCode, {}, 'ReaderEntryTransition.ets')
  const { ReaderEntryClaim } = moduleExports(claimCode, {}, 'Index.ets')
  const visibility = { foreground: true }
  const safeMode = { restricted: () => false }
  let nextRequest = null
  let measurements = 0
  let windowOpens = 0
  let windowCloses = 0
  const restores = []
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
    prepareStatusBarVisible() {
      return new Promise(resolve => preparations.push({ lease: this, resolve }))
    }
    getCloseSystemAvoidAreaResult() { return readiness }
    open() { windowOpens++ }
    close(beforeRestoreColors = null) {
      windowCloses++
      if (!this.closing) {
        const colors = deferRestore ? new Promise(resolve => restores.push(resolve)) : Promise.resolve()
        // Schedule the host callback after area readiness, before deferred colors.
        this.closing = Promise.resolve().then(async () => {
          if ((readiness === 'ready' || readiness === 'already-visible') && beforeRestoreColors !== null) {
            this.callbackResult = await beforeRestoreColors()
          }
          this.colorsStarted = true
          await colors
          this.colorsCompleted = true
        })
      }
      return this.closing
    }
  }
  const { Index } = moduleExports(hostCode, {
    ...shared, ReaderEntryRect, ReaderEntryClaim, NavPathStack, ReaderTrialWindow,
    console: { info: message => logs.push(message) },
    ReaderTrialLayoutCommit: { wait(context, measure, current) {
      return new Promise(resolve => layouts.push({ measure, current, resolve }))
    } },
    connectReaderLabLaunch: () => ({ consume() { const value = nextRequest; nextRequest = null; return value } }),
    connectReaderLabVisibility: () => visibility,
    connectSafeMode: () => safeMode,
  }, 'Index.ets')
  const host = new Index()
  host.layoutSafeArea = { topAvoidHeight: 0, bottomAvoidHeight: 0 }
  host.testPreparations = preparations
  // Ambient owners outside the extracted reader-entry lane, not replacement host methods.
  host.rootNavigationEpoch = 0
  host.readerOverlay = { visible: false }
  host.safeMode = safeMode
  host.getUIContext = () => uiContext
  host.context = () => context
  host.pushGallery = () => {}
  host.cancelRandomGalleryRequest = () => {}
  host.clearHomeTabAnimationGuardTimer = () => {}
  const source = new shared.ReaderTrialEntrySource(678049, 0, 'source-frame', 'source-snapshot',
    'detail', 'https://example.invalid/thumbnail.jpg')
  source.isCurrent = () => true
  function arm(overrides = {}) {
    const request = { work: '678049', pageIndex: 0, thumbnailEntry: true, readingChrome: true, entryProbe: '', ...overrides }
    nextRequest = request
    host.handleReaderLabLaunch()
    return request
  }
  return { host, source, arm, restores, layouts, logs, relay: shared.ReaderTrialEntryRelay, ReaderEntryClaim, ReaderEntryRect,
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
  await value.host.closeReaderTrial()
  assert.equal(value.host.readerTrialRequest, null)
  assert.equal(value.host.readerTrialEntryGuardToken, 0)
  assert.equal(value.windowCloses(), 1)
  assert.equal(value.relay.tryOpen(value.source), false)
})

test('new host intent retires fallback but an old token cannot release its replacement', async () => {
  const value = setup()
  value.arm()
  assert.equal(value.relay.tryOpen(value.source), true)
  const oldToken = value.host.readerTrialEntryGuardToken
  const replacement = value.arm()
  await value.host.readerTrialClosing
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
  await value.host.closeReaderTrial()
  assert.equal(value.relay.tryOpen(value.source), false)
})

test('clearing an existing source claim clears feedback ownership but retains the trial click guard', async () => {
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
  await value.host.closeReaderTrial()
  assert.equal(value.relay.tryOpen(value.source), false)
})

test('visible trial and preview remain until restoration settles; repeated Back shares one close', async () => {
  const value = setup({ deferRestore: true })
  const request = value.arm()
  value.relay.tryOpen(value.source)
  let cancels = 0
  const entry = { phase: 'waiting', cancel() { cancels++; this.phase = 'cancelled' } }
  const preview = { marker: 'same owned preview' }
  value.host.readerEntryTransition = entry
  value.host.readerEntryPreview = preview
  const clears = value.host.readerTrialStack.clears
  const closing = value.host.closeReaderTrial()
  assert.equal(value.host.closeReaderTrial(), closing)
  assert.equal(value.host.readerTrialRequest, request)
  assert.equal(value.host.readerEntryTransition, entry)
  assert.equal(value.host.readerEntryPreview, preview)
  assert.equal(cancels, 0)
  assert.equal(value.host.readerTrialStack.clears, clears)
  assert.equal(value.windowCloses(), 1)
  assert.equal(value.host.readerTrialWindow, null)
  value.host.syncReaderTrialWindow()
  assert.equal(value.windowOpens(), 1)
  value.restores.shift()()
  await closing
  assert.equal(value.host.readerTrialRequest, null)
  assert.equal(value.host.readerEntryPreview, null)
  assert.equal(value.host.readerTrialStack.clears, clears + 1)
  assert.equal(cancels, 1)
})

test('hidden layout cancels synchronously without acquiring or waiting for window colors', () => {
  const value = setup({ deferRestore: true })
  const request = value.arm()
  value.host.readerTrialRequest = request
  value.host.readerEntryTransition = { phase: 'layout', cancel() {
    assert.equal(value.host.readerTrialRequest, null)
    this.phase = 'cancelled'
  } }
  value.host.prepareReaderTrialWindow()
  assert.equal(value.windowOpens(), 0)
  assert.equal(value.host.closeReaderTrial(), null)
  assert.equal(value.host.readerTrialRequest, null)
  assert.equal(value.host.readerEntryTransition, null)
  assert.equal(value.windowOpens(), 0)
})

test('two replacement intents while A restores admit only latest C after A is removed', async () => {
  const value = setup({ deferRestore: true })
  const first = value.arm()
  value.relay.tryOpen(value.source)
  value.arm({ pageIndex: 1, thumbnailEntry: false })
  const closing = value.host.readerTrialClosing
  const latest = value.arm({ pageIndex: 2, thumbnailEntry: false })
  assert.equal(value.host.readerTrialRequest, first)
  assert.equal(value.windowOpens(), 1)
  value.restores.shift()()
  await closing
  await Promise.resolve()
  assert.equal(value.host.readerTrialRequest, latest)
  assert.equal(value.windowOpens(), 1)
  // Standalone full-reader destinations acquire their window only after onShown.
  value.host.readerTrialDestinationShown = true
  value.host.syncReaderTrialWindow()
  assert.equal(value.windowOpens(), 2)
  assert.equal(value.windowCloses(), 1)
  assert.equal(value.host.readerTrialClosing, null)
})

test('destruction retires late close and queued launch without changing the destroyed host tree', async () => {
  const value = setup({ deferRestore: true })
  const first = value.arm()
  value.relay.tryOpen(value.source)
  value.arm({ thumbnailEntry: false })
  const closing = value.host.readerTrialClosing
  const clears = value.host.readerTrialStack.clears
  value.host.aboutToDisappear()
  value.restores.shift()()
  await closing
  await Promise.resolve()
  assert.equal(value.host.readerTrialRequest, first)
  assert.equal(value.host.readerTrialStack.clears, clears)
  assert.equal(value.windowOpens(), 1)
  assert.equal(value.host.readerTrialHostAlive, false)
})

test('queued launch rechecks foreground after restoration', async () => {
  const value = setup({ deferRestore: true })
  value.arm()
  value.relay.tryOpen(value.source)
  value.arm({ thumbnailEntry: false })
  const closing = value.host.readerTrialClosing
  value.host.readerEntryVisibility.foreground = false
  value.restores.shift()()
  await closing
  await Promise.resolve()
  assert.equal(value.host.readerTrialRequest, null)
  assert.equal(value.windowOpens(), 1)
})

test('initial Want remains admitted; its window waits for both foreground and destination shown', () => {
  const value = setup()
  value.host.readerEntryVisibility.foreground = false
  const request = value.arm({ thumbnailEntry: false })
  assert.equal(value.host.readerTrialRequest, request)
  assert.equal(value.windowOpens(), 0)
  value.host.readerEntryVisibility.foreground = true
  value.host.syncReaderTrialWindow()
  assert.equal(value.windowOpens(), 0)
  value.host.readerTrialDestinationShown = true
  value.host.syncReaderTrialWindow()
  assert.equal(value.windowOpens(), 1)
})
