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
  'feature/reader/src/main/ets/lab/NextNReaderFailure.ets'), 'utf8')
const labels = new Map([
  ['reader_error_image_unavailable', 'Image unavailable'], ['reader_retry_connection', 'Check network'],
])
const context = { exports: {}, require: name => {
  if (name === 'shared') return { AppStrings: { get: key => labels.get(key) ?? key } }
  if (name === '@reader-kit/core') return { ReaderAssetFailure: class {
    constructor(code, title = '', hint = '') { Object.assign(this, { code, title, hint }) }
  } }
  return {}
} }
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
} }).outputText, context)

const classify = message => ({ ...context.exports.NextNReaderFailure.from(new Error(message)) })
assert.deepEqual(classify('socket closed'),
  { code: 'imageUnavailable', title: 'Image unavailable', hint: 'Check network' })
assert.deepEqual(classify('HTTP 503'),
  { code: 'imageUnavailable', title: 'Image unavailable', hint: 'Check network' })

const adapter = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderLabAdapter.ets'), 'utf8')
assert.ok(adapter.includes('ReaderAssetFailureClassifier'))
assert.ok(adapter.includes('classify(error: Error): ReaderAssetFailure'))
assert.ok(adapter.includes('NextNReaderFailure.from(error)'))

const host = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderLabPage.ets'), 'utf8')
assert.ok(host.includes('new ReaderPagedSession(catalog, assetProvider, adapter, adapter)'))

console.log('PASS NextN host failure classification and session wiring')
