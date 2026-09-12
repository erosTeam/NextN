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
  'feature/reader/src/main/ets/lab/NextNReaderProgressPersistence.ets'), 'utf8')
const calls = []
const history = {
  progress: async (_context, galleryId) => { calls.push(['restore', galleryId]); return 4 },
  saveProgress: async (_context, detail, pageIndex) => { calls.push(['save', detail.id, pageIndex]) },
}
const output = ts.transpileModule(source, { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
} }).outputText
const exports = {}
vm.runInNewContext(output, { exports, require: name => {
  if (name === 'shared') return { HistoryRepository: history }
  return {}
}, console: { warn() {} } })

const Persistence = exports.NextNReaderProgressPersistence
const sentinel = exports.NEXTN_READER_PROGRESS_READWRITE_UNIT
const detail = { id: 123 }
const adapter = { progressDetail: work => work === '123' ? detail : null }
const persistence = new Persistence({}, adapter)
const request = { work: '123', unit: '', pageIndex: 2, thumbnailEntry: false }

assert.equal(persistence.enabled(request), false)
assert.equal(await persistence.restore(request), 2)
await persistence.save(request, 3)
assert.deepEqual(calls, [])

request.unit = sentinel
assert.equal(persistence.enabled(request), true)
assert.equal(await persistence.restore(request), 4)
assert.deepEqual(calls, [['restore', 123]])
await persistence.save(request, 3)
assert.deepEqual(calls, [['restore', 123], ['save', 123, 3]])

request.thumbnailEntry = true
assert.equal(await persistence.restore(request), 2, 'explicit thumbnail entry must beat stored progress')
request.thumbnailEntry = false
request.work = 'bad'
assert.equal(await persistence.restore(request), 2)
await assert.rejects(persistence.save(request, 1), /shared_reader_progress_detail_unavailable/)

const failing = new Persistence({}, adapter)
history.progress = async () => { throw new Error('read failed') }
request.work = '123'
assert.equal(await failing.restore(request), 2, 'restore failure retains the explicit request fallback')

const pageSource = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderLabPage.ets'), 'utf8')
assert.match(pageSource, /this\.progressPersistence\?\.save\(this\.request, pageIndex\)/)
assert.match(pageSource, /this\.progressPersistence\?\.restore\(this\.request\)/)
assert.match(pageSource, /const progressFlush = this\.finishProgressWrites\(\)/)
assert.match(pageSource, /const saved = await progressFlush/)

console.log('PASS explicit readwrite sentinel, thumbnail precedence, fallback restore, save and close-flush wiring')
