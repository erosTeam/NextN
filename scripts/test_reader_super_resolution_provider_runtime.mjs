import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const ts = require(process.env.READER_KIT_TYPESCRIPT ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const load = require(path.join(root, 'third_party/reader-kit/tests/load-core.cjs'))
const core = { ...load('ReaderContent'), ...load('ReaderSession'), ...load('ReaderImageCrop'),
  ...load('ReaderImageInformation'), ...load('ReaderProcessingCoordinator') }
const released = [], calls = [], probeEvents = [], promoted = []
let processResult = { displayUri: 'file:///cache/enhanced.jpg', applied: true, reason: '' }
let processPromise = null
const shared = {
  ReaderSuperResolutionTaskPriority: { CURRENT: 0, PREFETCH: 1 },
  NhReaderSuperResolutionModel: { WAIFU2X_ART_NOISE0_2X: 'waifu' },
  ReaderPageCropService: { async detect() { return new core.ReaderImageCropBounds() } },
  ReaderSuperResolutionService: {
    async process(...args) { calls.push(args); return processPromise === null ? processResult : processPromise },
    releaseOwner(owner) { released.push(owner) },
    promoteOwner(owner) { promoted.push(owner) },
  },
}
const exports = {}
const source = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderSuperResolutionProvider.ets'), 'utf8')
vm.runInNewContext(ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText, {
  exports,
  require: name => {
    if (name === '@kit.AbilityKit') return {}
    if (name === '@reader-kit/core') return core
    if (name === '@reader-kit/ui') return { ReaderFileInformation: class { constructor(path, facts) {
      this.path = path; this.facts = facts
    } } }
    if (name === 'shared') return shared
    if (name === './NextNReaderSuperResolutionProbe') return {
      connectNextNReaderSuperResolutionProbe: () => ({
        deliver(...args) { probeEvents.push(args) },
        async pauseBeforeProcess() {},
      }),
    }
    throw new Error(`unexpected import ${name}`)
  },
})
const { NextNReaderSuperResolutionConfiguration, NextNReaderSuperResolutionProvider } = exports
const unit = new core.ReaderUnitKey('nh', '12', '12')
const page = new core.ReaderPage(unit, '12:1', 0)
let configuration = new NextNReaderSuperResolutionConfiguration(true, 'waifu', 2000)
const sourceAsset = new core.ReaderAsset('file:///cache/source.jpg')
sourceAsset.saveUri = 'file:///canonical/source.jpg'
sourceAsset.originalAvailable = true
const backend = { cancellationMode: 'consumer-only', informationSupported: true,
  async load() { return sourceAsset }, async prepareOriginal(p) { return { page: p, async load() { return sourceAsset } } } }
const provider = new NextNReaderSuperResolutionProvider({}, backend, () => configuration)
const cancellation = new core.ReaderCancellation()
await provider.load(page, 'original', cancellation, false)
const identity = configuration.identity()
const plan = await provider.prepareVariant(page, 'enhanced', identity, cancellation)
assert.equal(calls.length, 1)
assert.equal(calls[0][1], '/cache/source.jpg')
assert.equal(calls[0][3], true)
assert.equal(calls[0][4], 'waifu')
assert.equal(calls[0][5], 2000)
assert.equal(plan.identity, identity)
const enhanced = await plan.load(new core.ReaderCancellation(), false)
assert.equal(enhanced.uri, 'file:///cache/enhanced.jpg')
assert.equal(enhanced.saveUri, 'file:///canonical/source.jpg')
assert.equal(enhanced.originalAvailable, true)
enhanced.release(); enhanced.release()
assert.equal(released.length, 1)

let resolveProcessing
processPromise = new Promise(resolve => { resolveProcessing = resolve })
const cancelled = new core.ReaderCancellation()
const pending = provider.prepareVariant(page, 'enhanced', identity, cancelled)
await Promise.resolve()
cancelled.cancel()
resolveProcessing(processResult)
await assert.rejects(pending, /reader_request_cancelled/)
assert.ok(released.length >= 2)

processPromise = null
configuration = new NextNReaderSuperResolutionConfiguration(true, 'waifu', 3000)
await assert.rejects(provider.prepareVariant(page, 'enhanced', identity, new core.ReaderCancellation()),
  /reader_variant_unavailable/)
processResult = { displayUri: 'file:///cache/source.jpg', applied: false, reason: 'model_not_installed' }
await assert.rejects(provider.prepareVariant(page, 'enhanced', configuration.identity(), new core.ReaderCancellation()),
  /reader_variant_not_applied:model_not_installed/)
assert.ok(probeEvents.some(event => event[3] === 'prepare'))
assert.ok(probeEvents.some(event => event[3] === 'applied'))
assert.ok(probeEvents.some(event => event[3] === 'cancelled'))
assert.ok(probeEvents.some(event => event[3] === 'unavailable'))

// Common preparation receives a retained source file without mounting a future image.
processResult = { filePath: '/cache/enhanced.jpg', displayUri: 'file:///cache/enhanced.jpg', applied: true, reason: '' }
let sourceReleases = 0
let sourceBlocked = false
const acquire = async () => {
  const asset = new core.ReaderAsset('file:///cache/source.jpg', () => { sourceReleases++ })
  asset.saveUri = 'file:///canonical/source.jpg'
  if (sourceBlocked) asset.notice = { kind: 'blocked' }
  return asset
}
const futureProvider = new NextNReaderSuperResolutionProvider({}, backend, () => configuration, () => '', acquire)
const futurePage = new core.ReaderPage(unit, '12:future', 1)
const futureToken = new core.ReaderProcessingCancellation('prefetch')
const futurePlan = await futureProvider.prepareVariant(futurePage, 'enhanced', configuration.identity(), futureToken)
assert.equal(calls.at(-1)[6], shared.ReaderSuperResolutionTaskPriority.PREFETCH)
assert.equal(sourceReleases, 1)
const preparedOwner = calls.at(-1)[2]
futurePlan.release()
assert.equal(released.includes(preparedOwner), true, 'unused recipe releases its processor owner')
sourceBlocked = true
const beforeBlocked = calls.length
await assert.rejects(futureProvider.prepareVariant(futurePage, 'enhanced', configuration.identity(),
  new core.ReaderProcessingCancellation('prefetch')), /reader_variant_source_unavailable/)
assert.equal(calls.length, beforeBlocked, 'blocked source never enters enhancement')
assert.equal(sourceReleases, 2)
sourceBlocked = false
let finishWarm
processPromise = new Promise(resolve => { finishWarm = resolve })
const warmCancellation = new core.ReaderProcessingCancellation('prefetch')
const beforeWarm = calls.length
const warm = futureProvider.prepareVariant(futurePage, 'enhanced', configuration.identity(), warmCancellation)
for (let step = 0; step < 15 && calls.length === beforeWarm; step++) await Promise.resolve()
assert.equal(calls.length, beforeWarm + 1)
assert.equal(sourceReleases, 2, 'source lease remains alive during native processing')
const warmOwner = calls.at(-1)[2]
warmCancellation.promote()
assert.equal(promoted.at(-1), warmOwner, 'foreground joins and promotes the existing owner')
assert.equal(calls.length, beforeWarm + 1, 'promotion does not start a second request')
warmCancellation.cancel()
finishWarm(processResult)
await assert.rejects(warm, /reader_request_cancelled/)
assert.equal(sourceReleases, 3, 'cancelled preparation retains its source until the processor returns')
processPromise = null

// Late cancellation of an older task cannot release a newer task's owner.
let finishOverlapping
processPromise = new Promise(resolve => { finishOverlapping = resolve })
const olderCancellation = new core.ReaderProcessingCancellation('prefetch')
const overlapCallStart = calls.length
const olderWarm = futureProvider.prepareVariant(futurePage, 'enhanced', configuration.identity(), olderCancellation)
for (let step = 0; step < 15 && calls.length < overlapCallStart + 1; step++) await Promise.resolve()
assert.equal(calls.length, overlapCallStart + 1)
const olderOwner = calls.at(-1)[2]
const newerWarm = futureProvider.prepareVariant(futurePage, 'enhanced', configuration.identity(),
  new core.ReaderProcessingCancellation('prefetch'))
for (let step = 0; step < 15 && calls.length < overlapCallStart + 2; step++) await Promise.resolve()
assert.equal(calls.length, overlapCallStart + 2)
const newerOwner = calls.at(-1)[2]
assert.notEqual(olderOwner, newerOwner)
const beforeOlderCancel = released.length
olderCancellation.cancel()
assert.equal(released[beforeOlderCancel], olderOwner)
assert.equal(released.slice(beforeOlderCancel).includes(newerOwner), false)
finishOverlapping(processResult)
await assert.rejects(olderWarm, /reader_request_cancelled/)
const newerPlan = await newerWarm
assert.equal(released.includes(newerOwner), false, 'ready recipe keeps its owner until adopted or released')
newerPlan.release()
assert.equal(released.includes(newerOwner), true)
processPromise = null

console.log('reader super-resolution provider runtime: ok')
