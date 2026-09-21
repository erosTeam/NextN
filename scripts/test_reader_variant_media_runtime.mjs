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
const core = { ...load('ReaderContent'), ...load('ReaderSession'), ...load('ReaderImageInformation'),
  ...load('ReaderImageCrop'), ...load('ReaderImageShare') }

const readableFiles = new Map([['/generated/translated-old.png', 64]])
const cacheLoads = []
class Presentation {
  constructor(_context, data, options) { this.data = data; this.options = options }
  async present() {}
  release() {}
}
const shared = {
  NhApiClient: { imageUrl: (mediaId, index, extension) => `https://image.invalid/${mediaId}/${index}.${extension}` },
  ReaderImageCacheService: {
    cacheKey: (...parts) => parts.join(':'),
    async load(_context, url, key) {
      cacheLoads.push([url, key])
      return { localPath: '/cache/canonical.jpg', displayUri: 'file:///cache/canonical.jpg', bytes: 88 }
    },
    retain(result) { return result }, release() {}, markPresented() {},
  },
  ReaderPageCropService: { async detect() { return new core.ReaderImageCropBounds() } },
  DiagnosticLogger: { info() {} },
}
const output = {}
const source = fs.readFileSync(path.join(root, 'feature/reader/src/main/ets/lab/NextNReaderLabAdapter.ets'), 'utf8')
vm.runInNewContext(ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText, { exports: output, console, require: name => {
  if (name === '@kit.AbilityKit') return { common: {} }
  if (name === '@kit.ArkData') return { uniformTypeDescriptor: { UniformDataType: {
    JPEG: 'jpeg', PNG: 'png', GIF: 'gif', BMP: 'bmp', IMAGE: 'image', HYPERLINK: 'hyperlink',
  } } }
  if (name === '@kit.CoreFileKit') return {
    fileIo: { statSync: file => {
      const size = readableFiles.get(file)
      if (size === undefined) throw new Error('missing_file')
      return { size }
    } },
    fileUri: { getUriFromPath: file => `file://${file}` },
  }
  if (name === '@kit.ShareKit') return { systemShare: {
    SharedData: class { constructor(record) { this.record = record } },
    SelectionMode: { SINGLE: 'single' }, SharePreviewMode: { DEFAULT: 'default' },
  } }
  if (name === '@reader-kit/core') return core
  if (name === '@reader-kit/ui') return { ReaderSystemSharePresentation: Presentation,
    ReaderFileInformation: class { constructor() {} } }
  if (name === 'shared') return shared
  if (name === './NextNReaderFailure') return { NextNReaderFailure: { from: () => ({}) } }
  if (name === './NextNReaderProgressPersistence') return {}
  if (name === './NextNReaderDataSource') return { NextNNetworkReaderDataSource: class {} }
  assert.fail(`unexpected import ${name}`)
} })

const Adapter = output.NextNReaderLabAdapter
const detail = { id: 12, title: 'Gallery', mediaId: 'media', pages: [{
  number: 1, extension: 'jpg', width: 100, height: 200, thumbnailWidth: 10, thumbnailHeight: 20,
}] }
const sourceHost = { async openDetail() { return detail }, localPageUri() { return '' } }
const adapter = new Adapter({}, sourceHost)
const key = new core.ReaderUnitKey('nh', '12', '12')
const unit = await adapter.open(key, new core.ReaderCancellation())

const translated = new core.ReaderImageShareTarget(unit, 0, 4, 'translated',
  'file:///generated/translated-old.png', 73)
const translatedPresentation = await adapter.prepare(translated, new core.ReaderCancellation())
assert.equal(translatedPresentation.data.record.uri, 'file:///generated/translated-old.png')
assert.equal(translatedPresentation.data.record.utd, 'png')
assert.equal(cacheLoads.length, 0)

const enhanced = new core.ReaderImageShareTarget(unit, 0, 4, 'enhanced',
  'file:///generated/enhanced.png', 74)
const enhancedPresentation = await adapter.prepare(enhanced, new core.ReaderCancellation())
assert.equal(enhancedPresentation.data.record.uri, 'file:///cache/canonical.jpg')
assert.equal(cacheLoads.length, 1)

const defaultTarget = new core.ReaderImageShareTarget(unit, 0, 4, 'default',
  'file:///generated/default.png', 75)
const defaultPresentation = await adapter.prepare(defaultTarget, new core.ReaderCancellation())
assert.equal(defaultPresentation.data.record.uri, 'file:///cache/canonical.jpg')
assert.equal(cacheLoads.length, 2)

const missingTranslated = new core.ReaderImageShareTarget(unit, 0, 4, 'translated',
  'file:///generated/translated-missing.png', 76)
await assert.rejects(() => adapter.prepare(missingTranslated, new core.ReaderCancellation()),
  /missing_nh_translated_share_file/)
assert.equal(cacheLoads.length, 2)

console.log('PASS NextN translated share freezes its displayed file and fails closed; enhanced/default use canonical source')
