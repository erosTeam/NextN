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
    './DownloadSettingsService': { DownloadSettingsService: { restore: async () => {} } },
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


test('batch pause cancels every selected queued start before the first persistence await', async () => {
  const { service, state, repository } = setup()
  const second = state.tasks[0].copy()
  second.galleryId = 2
  const untouched = second.copy()
  untouched.galleryId = 3
  const complete = second.copy()
  complete.galleryId = 4
  complete.status = 'complete'
  complete.completedPages = complete.pageCount
  state.tasks.push(second, untouched, complete)
  let releaseSave
  repository.save = () => new Promise(resolve => { releaseSave = resolve })
  const batch = service.pauseVisible({}, [1, 2, 4])
  for (let i = 0; i < 10; i++) await Promise.resolve()
  assert.deepEqual(Array.from(state.tasks, t => t.status), ['paused', 'paused', 'queued', 'complete'])
  assert.equal(service.nextQueuedTask().galleryId, 3)
  repository.save = async () => {}
  releaseSave()
  const result = await batch
  assert.equal(result.succeededCount, 3)
})

test('batch pause reports partial persistence failure and continues remaining tasks', async () => {
  const { service, state, repository } = setup()
  const second = state.tasks[0].copy()
  second.galleryId = 2
  state.tasks.push(second)
  const saved = []
  repository.save = async (_ctx, task) => {
    saved.push(task.galleryId)
    if (task.galleryId === 1) throw Error('storage unavailable')
  }
  const result = await service.pauseVisible({}, [1, 1, 2])
  assert.deepEqual(saved, [1, 2])
  assert.equal(result.requestedCount, 2)
  assert.equal(result.failedCount, 1)
  assert.equal(result.succeededCount, 1)
})

test('cancelling selected starts invalidates late failure and keeps unrelated work eligible', async () => {
  const { service, state } = setup()
  const second = state.tasks[0].copy()
  second.galleryId = 2
  state.tasks.push(second)
  service.executionTokens.set(1, 1)
  service.cancelSelectedStarts([1])
  await service.failGalleryRun({}, 1, 1, Error('late failure'))
  assert.equal(state.tasks[0].status, 'paused')
  assert.equal(state.tasks[0].errorMessage, '')
  assert.equal(service.nextQueuedTask().galleryId, 2)
})

test('selected resume uses the existing concurrency limit and a queued pause prevents its start', async () => {
  const { service, state } = setup()
  state.tasks[0].status = 'paused'
  const second = state.tasks[0].copy()
  second.galleryId = 2
  const untouched = second.copy()
  untouched.galleryId = 3
  state.tasks.push(second, untouched)
  service.isLegacyTaskDirectory = () => false
  let release
  const gate = new Promise(resolve => { release = resolve })
  const started = []
  service.downloadPageOnce = async (_ctx, task) => { started.push(task.galleryId); await gate; throw Error('fixture request failed') }
  const result = await service.resumeVisible({}, [1, 2])
  assert.equal(result.succeededCount, 2)
  for (let i = 0; i < 20; i++) await Promise.resolve()
  assert.equal(service.activeGalleryIds.size, 1)
  assert(started.every(id => id === 1))
  assert.equal(state.tasks[2].status, 'paused')
  await service.pauseVisible({}, [1, 2])
  release()
  await Promise.all(Array.from(service.activeGalleryRuns.values()))
  assert(started.every(id => id === 1))
  assert.equal(service.activeGalleryIds.size, 0)
  assert(state.tasks.every(task => task.status === 'paused'))
})
