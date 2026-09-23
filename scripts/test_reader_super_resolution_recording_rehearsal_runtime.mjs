import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const source = fs.readFileSync(path.join(root,
  'shared/src/main/ets/state/ReaderSelfHostedRehearsal.ets'), 'utf8')
const exports = {}
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
  module: ts.ModuleKind.CommonJS,
  target: ts.ScriptTarget.ES2020,
} }).outputText, {
  exports,
  require(name) { assert.equal(name, '@kit.AbilityKit'); return {} },
})

const rehearsal = exports.ReaderSelfHostedRehearsal
const base = {
  readerLabSuperResolutionRecording: 'off-on-once',
  readerLabWork: '__rkit_local_fixture__',
  readerLabChrome: 'true',
  readerLabPage: '2',
}

rehearsal.capture({ parameters: base }, true)
assert.equal(rehearsal.consumeSuperResolutionRecording(), true, 'the exact Debug local-fixture request arms once')
assert.equal(rehearsal.consumeSuperResolutionRecording(), false, 'consumption is one-shot')
for (const parameters of [
  { ...base, readerLabSuperResolutionRecording: 'invalid' },
  { ...base, readerLabWork: '123' },
  { ...base, readerLabChrome: 'false' },
  { ...base, readerLabPage: '1' },
]) {
  rehearsal.capture({ parameters }, true)
  assert.equal(rehearsal.consumeSuperResolutionRecording(), false, 'a non-exact Debug Want fails closed')
}
rehearsal.capture({ parameters: base }, false)
assert.equal(rehearsal.consumeSuperResolutionRecording(), false, 'release builds cannot arm the rehearsal')
rehearsal.capture({ parameters: base }, true)
rehearsal.capture({ parameters: {} }, true)
assert.equal(rehearsal.consumeSuperResolutionRecording(), false, 'a normal launch clears an interrupted rehearsal')
const production = { nextn_gallery_id: 678049, readerProductionSuperResolutionPage: 2,
  readerProductionSuperResolutionScenario: 'delay-once' }
rehearsal.capture({ parameters: production }, true)
assert.equal(rehearsal.consumeProductionSuperResolutionScenario('678049', 1), '', 'other pages cannot consume')
assert.equal(rehearsal.consumeProductionSuperResolutionScenario('678049', 2), 'delay-once', 'production gate is exact')
assert.equal(rehearsal.consumeProductionSuperResolutionScenario('678049', 2), '', 'production gate is one-shot')
rehearsal.capture({ parameters: { ...production, readerProductionSuperResolutionScenario: 'fail-once' } }, true)
assert.equal(rehearsal.consumeProductionSuperResolutionScenario('678049', 2), 'fail-once')
rehearsal.capture({ parameters: production }, false)
assert.equal(rehearsal.consumeProductionSuperResolutionScenario('678049', 2), '', 'release cannot arm production gate')
rehearsal.capture({ parameters: production }, true)
rehearsal.capture({ parameters: {} }, true)
assert.equal(rehearsal.consumeProductionSuperResolutionScenario('678049', 2), '', 'normal launch clears production gate')

const pageSource = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderLabPage.ets'), 'utf8')
assert.match(pageSource, /@Local private superResolutionRehearsalDiagnostic: boolean = false/,
  'the restricted F2 diagnostic starts disabled for every normal Reader entry')
assert.match(pageSource,
  /const superResolutionRecording = ReaderSelfHostedRehearsal\.consumeSuperResolutionRecording\(\)[\s\S]*?this\.superResolutionRehearsalDiagnostic = superResolutionRecording/,
  'only the consumed exact Debug Want enables retained-projection telemetry')
assert.match(pageSource, /retainedProjectionDiagnostic: this\.superResolutionRehearsalDiagnostic/,
  'the exact Debug diagnostic flag reaches the shared reader surface')
const tree = ts.createSourceFile('page.ts',
  pageSource.replace('export struct NextNReaderLabPage', 'export class NextNReaderLabPage'), ts.ScriptTarget.Latest, true)
const cls = tree.statements.find(statement => ts.isClassDeclaration(statement) &&
  statement.name?.text === 'NextNReaderLabPage')
const windowMethod = cls.members.find(member => member.name?.getText(tree) === 'logSuperResolutionRehearsalWindow').getText(tree)
const method = cls.members.find(member => member.name?.getText(tree) === 'runSuperResolutionRecordingRehearsal').getText(tree)
const timers = []
const transitions = []
const rehearsalLogs = []
const Host = (() => {
  const output = {}
  vm.runInNewContext(ts.transpileModule(`export class Host { ${windowMethod} ${method} }`, { compilerOptions: {
    module: ts.ModuleKind.CommonJS,
    target: ts.ScriptTarget.ES2020,
  } }).outputText, {
    exports: output,
    ReaderPresentationService: {
      snapshot: () => ({ superResolutionEnabled: true }),
      setSuperResolutionEnabled: (_context, enabled) => { transitions.push(enabled); return Promise.resolve() },
    },
    setTimeout: callback => { timers.push(callback); return timers.length },
    Promise,
    console: { info(message) { rehearsalLogs.push(message) }, warn() {} },
  })
  return output.Host
})()
const host = new Host()
Object.assign(host, { request: { pageIndex: 2 }, volumeDisposed: false, closeRequested: false, hostClosing: false,
  session: { snapshot: () => ({ phase: 'ready', anchor: { sourceIndexHint: 2 }, frames: [{
    part: { sourceIndex: 2 }, asset: {
      variant: 'enhanced', phase: 'displayed', assetRequestId: 7,
      retainedUri: '', retainedAssetRequestId: 0,
    },
  }] }) } })
const task = host.runSuperResolutionRecordingRehearsal({})
await Promise.resolve()
assert.equal(timers.length, 1, 'the recording keeps an initial ON observation window')
let completed = false
void task.then(() => { completed = true })
while (!completed) {
  assert.ok(timers.length > 0, 'the bounded rehearsal schedules every observation window explicitly')
  timers.shift()()
  await new Promise(resolve => setImmediate(resolve))
}
await task
assert.deepEqual(transitions, [false, true], 'finally restores the original ON state through the same service')
assert.ok(rehearsalLogs.some(message => /frame window=off sample=0 .*asset_phase=displayed variant=enhanced/.test(message)),
  'the Debug rehearsal records its first bounded OFF-window snapshot')
assert.ok(rehearsalLogs.some(message => /frame window=on sample=12 .*retained_request=0/.test(message)),
  'the Debug rehearsal records the bounded ON-window tail too')
assert.match(rehearsalLogs.at(-1), /gate precondition=enhanced source=2 enabled=true; phase=off source=2 enabled=false; phase=on source=2 enabled=true/,
  'the final surviving log line summarizes every completed rehearsal phase')

const probeSource = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderSuperResolutionProbe.ets'), 'utf8')
const probeExports = {}
vm.runInNewContext(ts.transpileModule(probeSource, { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
} }).outputText, {
  exports: probeExports,
  require: name => name === '@kit.ArkUI' ? { AppStorageV2: {} } : {},
  ObservedV2: target => target, Promise, setTimeout, clearTimeout, console: { info() {} },
})
const probe = new probeExports.NextNReaderSuperResolutionProbe()
const debugContext = { applicationInfo: { debug: true } }
const releaseContext = { applicationInfo: { debug: false } }
const live = { onCancel: () => () => {}, check() {} }
let probeEpoch = probe.armReplacement('678049', 2, 'fail-once')
await probe.pauseBeforeProcess(releaseContext, '678049', 2, live)
await assert.rejects(probe.pauseBeforeProcess(debugContext, '678049', 2, live), /reader_debug_variant_failure_once/)
await probe.pauseBeforeProcess(debugContext, '678049', 2, live)
probe.cancel(probeEpoch)
probeEpoch = probe.armReplacement('678049', 2, 'delay-once')
let cancelled = false
let cancelGate = () => {}
const pending = probe.pauseBeforeProcess(debugContext, '678049', 2, {
  onCancel: callback => { cancelGate = callback; return () => {} },
  check: () => { if (cancelled) throw new Error('reader_request_cancelled') },
})
cancelled = true
cancelGate()
await assert.rejects(pending, /reader_request_cancelled/)
probe.cancel(probeEpoch)

console.log('PASS restricted one-shot Debug F2 rehearsal Want')
