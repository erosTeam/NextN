import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const read = (relativePath) => readFileSync(new URL(`../${relativePath}`, import.meta.url), 'utf8')

const state = read('shared/src/main/ets/state/DownloadQueueState.ets')
const sharedIndex = read('shared/src/main/ets/Index.ets')
const page = read('feature/download/src/main/ets/pages/DownloadQueuePage.ets')
const service = read('shared/src/main/ets/services/DownloadQueueService.ets')
const task = read('shared/src/main/ets/model/NhDownloadTask.ets')

assert.match(task, /@ObservedV2\s+export class NhDownloadTask/)
for (const field of ['completedPages', 'pageCount', 'status', 'updatedAt']) {
  assert.match(task, new RegExp(`@Trace ${field}:`))
}
assert.match(task, /assignFrom\(source: NhDownloadTask\): void \{[\s\S]*?this\.completedPages = source\.completedPages[\s\S]*?this\.status = source\.status/)

assert.match(state, /export class DownloadQueueSignalState[\s\S]*?@Trace version: number = 0/)
assert.match(state, /replace\(tasks: NhDownloadTask\[\]\): void \{[\s\S]*?existing\.assignFrom\(source\)[\s\S]*?this\.revision \+= 1\s+publishDownloadQueueChanged\(\)/)
assert.match(state, /export function connectDownloadQueueSignal\(\): DownloadQueueSignalState/)
assert.match(state, /export function publishDownloadQueueChanged\(\): void \{[\s\S]*?signal\.version \+= 1/)

for (const exportedName of [
  'DownloadQueueSignalState',
  'connectDownloadQueueSignal',
  'publishDownloadQueueChanged',
]) {
  assert.match(sharedIndex, new RegExp(`\\b${exportedName}\\b`))
}

assert.match(page, /@Local queueSignal: DownloadQueueSignalState = connectDownloadQueueSignal\(\)/)
assert.match(page, /@Local queueProjectionTick: number = 0/)
assert.match(page, /@Monitor\('queueSignal\.version'\)\s+onQueueChanged\(\): void \{[\s\S]*?this\.projectQueueSnapshot\(\)/)
assert.match(page, /private projectQueueSnapshot\(\): void \{[\s\S]*?this\.tasks = this\.queue\.tasks\.slice\(\)[\s\S]*?this\.queueProjectionTick \+= 1/)
assert.match(page, /private taskProgressText\(task: NhDownloadTask\): string \{\s+if \(this\.queueProjectionTick < 0\)/)
assert.match(page, /private taskProgressPercent\(task: NhDownloadTask\): number \{\s+if \(this\.queueProjectionTick < 0\)/)
assert.doesNotMatch(page, /@Monitor\('queue\.revision'\)/)

assert.match(service, /current\.completedPages = DownloadQueueService\.completedFileCount\(context, current\)[\s\S]*?await DownloadQueueService\.persist\(context, current\)/)
assert.match(service, /private static activePageWritePaths: Set<string> = new Set<string>\(\)/)
assert.match(service, /DownloadQueueService\.activePageWritePaths\.add\(finalPath\)[\s\S]*?finally \{[\s\S]*?DownloadQueueService\.activePageWritePaths\.delete\(finalPath\)/)
assert.match(service, /task\.completedPages === pageCount && task\.status !== NhDownloadTaskStatus\.DOWNLOADING/)
assert.match(service, /return journalAllowsPage && !DownloadQueueService\.activePageWritePaths\.has\(path\) &&\s+DownloadQueueService\.fileSize\(path\) > 0/)

console.log('Download queue progress publication contract passed.')
