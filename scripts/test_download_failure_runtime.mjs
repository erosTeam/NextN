import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import vm from 'node:vm'
import { test } from 'node:test'

const require = createRequire(import.meta.url)
const ts = require(process.env.NEXTN_TYPESCRIPT_PATH ??
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js')
function load(path, modules = {}) {
  const exports = {}
  const source = readFileSync(new URL(`../shared/src/main/ets/${path}.ets`, import.meta.url), 'utf8')
  const code = ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, experimentalDecorators: true,
  } }).outputText
  vm.runInNewContext(code, { exports, require: name => modules[name] ?? {},
    ObservedV2: value => value, Trace: () => {}, console: { warn() {} }, Date, setTimeout })
  return exports
}
function setup() {
  const model = load('model/NhDownloadTask')
  const task = new model.NhDownloadTask()
  Object.assign(task, { galleryId: 1, pageCount: 2, status: 'queued' })
  const snapshots = []
  const state = { tasks: [task], replace(tasks) {
    this.tasks = tasks
    snapshots.push(tasks.map(t => t.copy()))
  } }
  const repository = { save: async () => {} }
  const { DownloadQueueService: service } = load('services/DownloadQueueService', {
    '../model/NhDownloadTask': model,
    '../state/DownloadQueueState': { connectDownloadQueue: () => state },
    '../storage/DownloadQueueRepository': { DownloadQueueRepository: repository },
  })
  // Replace only external IO/settings. Queue execution/state/token code remains real.
  service.restored = true
  service.maxConcurrentGalleries = () => 1
  service.maxConcurrentPages = () => 2
  service.retryCount = () => 2
  service.requestIntervalSeconds = () => 0
  service.reconcileCompletionJournal = () => {}
  service.completedFileCount = (_context, task) => task.completedPageIndexes.length
  service.pageIsComplete = () => false
  service.writeTaskMetadata = () => {}
  service.delayBytesForSpeedLimit = async () => {}
  service.delay = async () => {}
  return { service, state, snapshots, repository }
}

test('an unexpected worker rejection becomes ERROR and releases its slot', async () => {
  const { service, state } = setup()
  service.reconcileCompletionJournal = () => { throw Error('metadata read failed') }
  service.pump({})
  await service.activeGalleryRuns.get(1)
  assert.equal(state.tasks[0].status, 'error')
  assert.equal(service.activeGalleryIds.size, 0)
  assert.equal(service.activeGalleryRuns.size, 0)
})

test('even failing persistence publishes terminal error and releases its slot', async () => {
  const { service, state, repository } = setup()
  repository.save = async () => { throw Error('storage unavailable') }
  service.pump({})
  await service.activeGalleryRuns.get(1)
  assert.equal(state.tasks[0].status, 'error')
  assert.equal(service.activeGalleryIds.size, 0)
})

test('failed attempts publish retry feedback before exhausting the configured retries', async () => {
  const { service, state, snapshots } = setup()
  let attempts = 0
  service.downloadPageOnce = async () => { attempts++; throw Error('Image request timed out') }
  service.pump({})
  await service.activeGalleryRuns.get(1)
  assert.equal(attempts, 6) // two pages, original attempt plus two retries each
  assert.ok(snapshots.some(tasks => tasks[0].status === 'downloading' && /timed out/.test(tasks[0].errorMessage)))
  assert.equal(state.tasks[0].status, 'error')
  assert.equal(state.tasks[0].completedPages, 0)
})

test('one unexpected page rejection waits for its sibling before releasing the gallery', async () => {
  const { service, state } = setup()
  let releaseSibling
  const sibling = new Promise(resolve => { releaseSibling = resolve })
  service.downloadPage = async (_ctx, _task, page) => {
    if (page === 0) throw Error('page preflight failed')
    return sibling
  }
  service.pump({})
  const run = service.activeGalleryRuns.get(1)
  for (let i = 0; i < 8; i++) await Promise.resolve()
  assert.equal(service.activeGalleryIds.size, 1)
  assert.equal(state.tasks[0].status, 'downloading')
  releaseSibling({ bytes: 0, completed: false, failureMessage: '' })
  await run
  assert.equal(state.tasks[0].status, 'error')
  assert.equal(service.activeGalleryIds.size, 0)
})

test('late worker failure cannot overwrite pause, completion, deletion or a newer execution', async () => {
  for (const status of ['paused', 'complete', 'deleted', 'newer']) {
    const { service, state } = setup()
    service.executionTokens.set(1, status === 'newer' ? 2 : 1)
    state.tasks[0].status = status === 'newer' ? 'downloading' : status
    if (status === 'deleted') state.tasks = []
    await service.failGalleryRun({}, 1, 1, Error('late error'))
    assert.equal(state.tasks[0]?.status, status === 'deleted' ? undefined : status === 'newer' ? 'downloading' : status)
  }
})
