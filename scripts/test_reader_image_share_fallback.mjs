import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const load = require(path.join(root, 'third_party/reader-kit/tests/load-core.cjs'))
const core = { ...load('ReaderContent'), ...load('ReaderSession'), ...load('ReaderPagedSession'),
  ...load('ReaderImageShare') }
const source = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderImageShareHost.ets'), 'utf8')
const output = {}
let fallbackPresentations = []
class SystemPresentation {
  constructor(_context, data) {
    this.data = data
    this.presentCount = 0
    this.releaseCount = 0
    fallbackPresentations.push(this)
  }
  async present() { this.presentCount++ }
  release() { this.releaseCount++ }
}
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
} }).outputText, { exports: output, console, require: name => {
  if (name === '@kit.AbilityKit') return {}
  if (name === '@kit.ArkData') return { uniformTypeDescriptor: { UniformDataType: { HYPERLINK: 'hyperlink' } } }
  if (name === '@kit.ShareKit') return { systemShare: {
    SharedData: class { constructor(record) { this.record = record } },
    SelectionMode: { SINGLE: 'single' }, SharePreviewMode: { DEFAULT: 'default' },
  } }
  if (name === '@reader-kit/core') return core
  if (name === '@reader-kit/ui') return { ReaderSystemSharePresentation: SystemPresentation }
  if (name === 'shared') return { NhBrowserSessionBoundary: {
    canonicalGalleryUrl: id => `https://example.invalid/g/${id}`,
  } }
  assert.fail(name)
} })
const Host = output.NextNReaderImageShareHost

function target() {
  const unitKey = new core.ReaderUnitKey('nh', '123', '123')
  return new core.ReaderImageShareTarget(new core.ReaderUnit(unitKey, 'Gallery', 3), 1, 2)
}
function presentation(fail = false) {
  return { presentCount: 0, releaseCount: 0,
    async present() { this.presentCount++; if (fail) throw new Error('present failed') },
    release() { this.releaseCount++ },
  }
}

fallbackPresentations = []
let primaryPresentation = presentation()
let host = new Host({}, { prepare: async () => primaryPresentation })
let wrapped = await host.prepare(target(), new core.ReaderCancellation())
await wrapped.present(); wrapped.release()
assert.equal(primaryPresentation.presentCount, 1)
assert.equal(primaryPresentation.releaseCount, 1)
assert.equal(fallbackPresentations.length, 0)

fallbackPresentations = []
primaryPresentation = presentation(true)
host = new Host({}, { prepare: async () => primaryPresentation })
wrapped = await host.prepare(target(), new core.ReaderCancellation())
await wrapped.present(); wrapped.release()
assert.equal(primaryPresentation.releaseCount, 1)
assert.equal(fallbackPresentations.length, 1)
assert.equal(fallbackPresentations[0].data.record.content, 'https://example.invalid/g/123')
assert.deepEqual([fallbackPresentations[0].presentCount, fallbackPresentations[0].releaseCount], [1, 1])

fallbackPresentations = []
host = new Host({}, { prepare: async () => { throw new Error('prepare failed') } })
wrapped = await host.prepare(target(), new core.ReaderCancellation())
await wrapped.present(); wrapped.release()
assert.equal(fallbackPresentations.length, 1)
assert.equal(fallbackPresentations[0].data.record.utd, 'hyperlink')

fallbackPresentations = []
const cancellation = new core.ReaderCancellation(); cancellation.cancel()
await assert.rejects(() => host.prepare(target(), cancellation))
assert.equal(fallbackPresentations.length, 0)

fallbackPresentations = []
primaryPresentation = presentation()
const cancelledDuringPrepare = new core.ReaderCancellation()
host = new Host({}, { prepare: async () => { cancelledDuringPrepare.cancel(); return primaryPresentation } })
await assert.rejects(() => host.prepare(target(), cancelledDuringPrepare))
assert.equal(primaryPresentation.releaseCount, 1)
assert.equal(fallbackPresentations.length, 0)

console.log('PASS NextN current-image share falls back to canonical gallery without changing reader-kit')
