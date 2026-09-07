import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import vm from 'node:vm'
import { test } from 'node:test'
const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript/lib/typescript.js')
const source = readFileSync(new URL('../feature/download/src/main/ets/pages/DownloadQueuePage.ets', import.meta.url), 'utf8')
const names = ['deleteSelected', 'publishSelection', 'selectAll', 'setSelected', 'beginSelection', 'selectionTouch', 'handleSelectionClick', 'applyVisibleBatch']
const methods = names.map(name => {
  const match = source.match(new RegExp(`^  private (?:async )?${name}\\(`, 'm'))
  assert(match, name)
  return source.slice(match.index, source.indexOf('\n  }', match.index) + 4)
})
function setup() {
  const service = {}
  const runtime = { DownloadQueueService: service, AppStrings: { get: () => '%1$s/%2$s/%s' }, TouchType: { Down: 0 },
    DownloadBatchResult: class { requestedCount=0; succeededCount=0; failedCount=0; hasPartialSuccess() { return this.succeededCount>0 && this.failedCount>0 } } }
  vm.runInNewContext(ts.transpileModule(`class Page {${methods.join('\n')}};this.Page=Page`, { compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText, runtime)
  const page = new runtime.Page()
  page.titleActions = { selectionMode: true, batchBusy: false }
  page.selectedIds = new Set()
  page.tasks = [{galleryId:1,status:'paused'}, {galleryId:2,status:'queued'}, {galleryId:3,status:'complete'}]
  page.visibleTasks = () => page.tasks
  page.visiblePausableIds = () => page.tasks.filter(t=>t.status==='queued').map(t=>t.galleryId)
  page.visibleResumableIds = () => page.tasks.filter(t=>t.status==='paused').map(t=>t.galleryId)
  page.context = () => ({})
  page.rebuildTaskProjection = () => page.publishSelection()
  page.getUIContext = () => ({ getPromptAction: () => ({ showToast() {} }) })
  page.reportVisibleEligibility = () => {}
  page.batchOutcomeMessage = () => 'batch failed'
  service.snapshot = () => page.tasks
  service.cancelSelectedStarts = () => {}
  return {page,service}
}
test('selection tracks IDs across regrouping and prunes hidden tasks', () => {
  const {page} = setup()
  page.selectAll()
  assert.equal(page.titleActions.selectedCount,3)
  page.tasks = [page.tasks[2],page.tasks[0]]
  page.publishSelection()
  assert.deepEqual(Array.from(page.selectedIds),[1,3])
  assert.equal(page.titleActions.selectedResumable,1)
  page.selectAll()
  assert.equal(page.selectedIds.size,0)
})
test('next touch can deselect the original long-pressed item', () => {
  const {page} = setup()
  page.titleActions.selectionMode=false
  page.closeTaskActionMenu=()=>{}
  page.beginSelection(1)
  assert(page.selectedIds.has(1))
  page.selectionTouch({type:0})
  assert(page.handleSelectionClick(1))
  assert(!page.selectedIds.has(1))
})
test('delete waits sequentially, keeps failed IDs selected and preserves other tasks', async () => {
  const {page,service} = setup()
  let release
  const gate = new Promise(resolve=>{release=resolve})
  const calls=[]
  service.remove = async (_ctx,id) => {
    calls.push(id)
    if(id===1) { await gate; page.tasks=page.tasks.filter(t=>t.galleryId!==1) }
    else throw Error('storage failure')
  }
  const deleting=page.deleteSelected([1,2])
  assert.deepEqual(calls,[1])
  assert(page.titleActions.batchBusy)
  release();await deleting
  assert.deepEqual(calls,[1,2])
  assert.deepEqual(Array.from(page.selectedIds),[2])
  assert(page.tasks.some(t=>t.galleryId===3))
  assert(page.titleActions.selectionMode)
  assert(!page.titleActions.batchBusy)
})
test('batch action sends eligible selected IDs only and releases busy state on restore failure', async () => {
  const {page,service} = setup()
  page.selectedIds=new Set([1,3])
  let called
  service.resumeVisible=async (_ctx,ids)=>{called=Array.from(ids);throw Error('restore failure')}
  await page.applyVisibleBatch(false,true)
  assert.deepEqual(called,[1])
  assert(!page.titleActions.batchBusy)
  assert.equal(page.errorMessage,'batch failed')
})
