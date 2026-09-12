import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

class Cancellation {
  cancelled = false
  cancel() { this.cancelled = true }
  check() { if (this.cancelled) throw new Error('reader_request_cancelled') }
}

function detail(id, marker) {
  return {
    id,
    marker,
    pages: [{ extension: 'jpg' }, { extension: 'png' }],
    copy() { return detail(this.id, this.marker) },
  }
}

let downloaded = null
let remote = null
const calls = []
const shared = {
  DownloadQueueService: {
    async localReaderDetail(context, galleryId) {
      calls.push(`download:${context.name}:${galleryId}`)
      return downloaded
    },
    localPageUri(context, galleryId, pageIndex, extension) {
      calls.push(`local:${context.name}:${galleryId}:${pageIndex}:${extension}`)
      return `file:///download/${galleryId}/${pageIndex}.${extension}`
    },
  },
  NhApiClient: {
    async detail(galleryId) {
      calls.push(`network:${galleryId}`)
      return remote
    },
  },
  NhGalleryDetail: class {},
  NhGalleryPage: class {},
}

const output = ts.transpileModule(
  fs.readFileSync(path.join(root, 'feature/reader/src/main/ets/lab/NextNReaderDataSource.ets'), 'utf8'),
  { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } },
).outputText
const exports = {}
vm.runInNewContext(output, {
  exports,
  require(name) {
    if (name === '@kit.AbilityKit') return { common: {} }
    if (name === '@reader-kit/core') return { ReaderCancellation: Cancellation }
    if (name === 'shared') return shared
    assert.fail(`unexpected module ${name}`)
  },
})

const { NextNProductionReaderDataSource: Production, NextNNetworkReaderDataSource: Network } = exports
const context = { name: 'ctx' }

downloaded = detail(42, 'download')
remote = detail(42, 'network')
calls.length = 0
let source = new Production(context, detail(42, 'seed'))
assert.equal((await source.openDetail(42, new Cancellation())).marker, 'download')
assert.deepEqual(calls, ['download:ctx:42'])

downloaded = null
calls.length = 0
source = new Production(context, detail(42, 'seed'))
assert.equal((await source.openDetail(42, new Cancellation())).marker, 'seed')
assert.deepEqual(calls, ['download:ctx:42'])
// The route seed is one-shot; a second open must not retain it.
assert.equal((await source.openDetail(42, new Cancellation())).marker, 'network')
assert.deepEqual(calls, ['download:ctx:42', 'download:ctx:42', 'network:42'])

calls.length = 0
source = new Production(context, detail(7, 'wrong-seed'))
assert.equal((await source.openDetail(42, new Cancellation())).marker, 'network')
assert.deepEqual(calls, ['download:ctx:42', 'network:42'])

calls.length = 0
assert.equal(source.localPageUri(detail(42, 'page'), 1), 'file:///download/42/1.png')
assert.equal(source.localPageUri(detail(42, 'page'), -1), '')
assert.equal(source.localPageUri(detail(42, 'page'), 2), '')
assert.deepEqual(calls, ['local:ctx:42:1:png'])

calls.length = 0
const network = new Network()
assert.equal((await network.openDetail(42, new Cancellation())).marker, 'network')
assert.equal(network.localPageUri(detail(42, 'page'), 0), '')
assert.deepEqual(calls, ['network:42'])

downloaded = detail(42, 'download')
const cancelled = new Cancellation()
shared.DownloadQueueService.localReaderDetail = async () => {
  cancelled.cancel()
  return downloaded
}
await assert.rejects(() => new Production(context, null).openDetail(42, cancelled), /reader_request_cancelled/)

const adapterSource = fs.readFileSync(
  path.join(root, 'feature/reader/src/main/ets/lab/NextNReaderLabAdapter.ets'),
  'utf8',
)
assert.ok(adapterSource.indexOf('this.source.localPageUri(detail, page.sourceIndex)') <
  adapterSource.indexOf("if (kind === 'thumbnail')"), 'verified downloads must precede remote thumbnails')
assert.ok(adapterSource.indexOf('this.source.localPageUri(detail, target.sourceIndex)') <
  adapterSource.indexOf('ReaderImageCacheService.cacheKey(detail.id, detail.mediaId, source.number, source.extension)'),
  'verified downloads must precede network/cache share preparation')
assert.match(adapterSource, /\[NextNReaderShare\] source=download/)
assert.match(adapterSource, /function readerShareImageUtd\(extension: string\): string/)
assert.match(adapterSource, /utd: readerShareImageUtd\(source\.extension\), label: 'IMAGE'/)
assert.match(adapterSource, /this\.source\.openDetail\(id, cancellation\)/)

console.log('PASS production Reader data source order, one-shot Detail seed, cancellation and local-page precedence')
