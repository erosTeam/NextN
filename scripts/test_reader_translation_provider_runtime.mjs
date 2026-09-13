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
  ...load('ReaderImageInformation') }
const calls = []
let runPromise = null
let probeResultPath = ''
const probeStages = []
const translationProbe = {
  result() { return probeResultPath },
  deliver(_context, _work, sourceIndex, stage, identity) {
    probeStages.push([sourceIndex, stage, identity])
  },
}
let result = {
  renderedPage: {
    localFilePath: '/cache/translated.png',
    identity: {
      targetLanguage: 'zh-CN', translationSourceProfileId: 'profile-1',
      translationSourceRevision: 4, translationModelId: 'model-1',
    },
  },
}
const shared = {
  ReaderPageCropService: { async detect() { return new core.ReaderImageCropBounds() } },
  ComicTranslationReaderPageInput: class {},
  ComicTranslationRuntimeService: {
    async runReaderPage(_context, input) {
      calls.push(input)
      return runPromise === null ? result : runPromise
    },
  },
}
const exports = {}
const source = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderTranslationProvider.ets'), 'utf8')
vm.runInNewContext(ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText, {
  exports,
  require: name => {
    if (name === '@kit.AbilityKit') return {}
    if (name === '@kit.CoreFileKit') return { fileUri: { getUriFromPath: value => `file://${value}` } }
    if (name === '@reader-kit/core') return core
    if (name === '@reader-kit/ui') return { ReaderFileInformation: class { constructor(file, facts) {
      this.file = file; this.facts = facts
    } } }
    if (name === 'shared') return shared
    if (name === './NextNReaderTranslationProbe') {
      return { connectNextNReaderTranslationProbe: () => translationProbe }
    }
    throw new Error(`unexpected import ${name}`)
  },
})
const { NextNReaderTranslationConfiguration, NextNReaderTranslationProvider } = exports
const unit = new core.ReaderUnitKey('nh', '12', '12')
const page = new core.ReaderPage(unit, '12:1', 0)
page.width = 1024; page.height = 1536
let configuration = new NextNReaderTranslationConfiguration(true, 'nh-reader-12-zh-CN', 'zh-CN', 'japanese',
  'profile-1', 4, 'model-1', 0)
const sourceAsset = new core.ReaderAsset('file:///cache/source.jpg')
sourceAsset.originalAvailable = true
let delegated = 0
const backend = {
  cancellationMode: 'consumer-only', informationSupported: true,
  async load() { return sourceAsset },
  async prepareOriginal(value) { return { page: value, async load() { return sourceAsset } } },
  async prepareVariant(value, variant, identity) {
    delegated++
    return { page: value, variant, identity, async load() { return new core.ReaderAsset('enhanced') } }
  },
}
const provider = new NextNReaderTranslationProvider({}, backend, () => configuration)
await provider.load(page, 'original', new core.ReaderCancellation(), false)
const identity = configuration.identity()
const plan = await provider.prepareVariant(page, 'translated', identity, new core.ReaderCancellation())
assert.equal(calls.length, 1)
assert.deepEqual([calls[0].projectId, calls[0].pageIndex, calls[0].imageFilePath,
  calls[0].imageWidth, calls[0].imageHeight, calls[0].sourceLanguage, calls[0].targetLanguage],
['nh-reader-12-zh-CN', 0, '/cache/source.jpg', 1024, 1536, 'japanese', 'zh-CN'])
assert.equal(plan.identity, identity)
const translated = await plan.load(new core.ReaderCancellation(), false)
assert.equal(translated.uri, 'file:///cache/translated.png')
assert.equal(translated.originalAvailable, true)
assert.equal(translated.information.facts.variant, 'translated')
await provider.prepareVariant(page, 'enhanced', 'enhanced:v1', new core.ReaderCancellation())
assert.equal(delegated, 1)

probeStages.length = 0
probeResultPath = '/cache/local-translated.png'
const probePlan = await provider.prepareVariant(page, 'translated', identity, new core.ReaderCancellation())
const probeAsset = await probePlan.load(new core.ReaderCancellation(), false)
assert.equal(probeAsset.uri, 'file:///cache/local-translated.png')
assert.deepEqual(probeStages.map(value => value.slice(0, 2)), [[0, 'prepare'], [0, 'applied']])
assert.equal(calls.length, 1)
probeResultPath = ''

let resolveRun
runPromise = new Promise(resolve => { resolveRun = resolve })
const cancelled = new core.ReaderCancellation()
const pending = provider.prepareVariant(page, 'translated', identity, cancelled)
await Promise.resolve()
cancelled.cancel()
resolveRun(result)
await assert.rejects(pending, /reader_request_cancelled/)

runPromise = null
configuration = new NextNReaderTranslationConfiguration(true, 'nh-reader-12-zh-CN', 'zh-CN', 'japanese',
  'profile-1', 5, 'model-1', 0)
await assert.rejects(provider.prepareVariant(page, 'translated', identity, new core.ReaderCancellation()),
  /reader_translation_configuration_unavailable/)
const currentIdentity = configuration.identity()
result = { renderedPage: { localFilePath: '/cache/stale.png', identity: {
  targetLanguage: 'zh-CN', translationSourceProfileId: 'profile-1',
  translationSourceRevision: 4, translationModelId: 'model-1',
} } }
await assert.rejects(provider.prepareVariant(page, 'translated', currentIdentity, new core.ReaderCancellation()),
  /reader_translation_result_stale/)

console.log('reader translation provider runtime: ok')
