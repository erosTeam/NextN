import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { test } from 'node:test'

const adapter = readFileSync(new URL('../feature/reader/src/main/ets/lab/NextNReaderLabAdapter.ets', import.meta.url), 'utf8')
const lab = readFileSync(new URL('../feature/reader/src/main/ets/lab/NextNReaderLabPage.ets', import.meta.url), 'utf8')
const probe = readFileSync(new URL('../feature/reader/src/main/ets/lab/NextNReaderAutoReadSourceProbe.ets', import.meta.url), 'utf8')

function method(source, name) {
  const start = source.indexOf(`  async ${name}(`)
  assert.ok(start >= 0, `missing ${name}`)
  const body = source.indexOf('{', start)
  let depth = 0
  for (let index = body; index < source.length; index += 1) {
    if (source[index] === '{') depth += 1
    if (source[index] === '}' && --depth === 0) return source.slice(start, index + 1)
  }
  throw new Error(`unterminated ${name}`)
}

test('NextN adapter resolves the auto-read target and publishes bodySourceReady without touching thumbnails', () => {
  const prepare = method(adapter, 'prepareAutoReadSource')
  assert.match(prepare, /localPageUri\(detail, page\.sourceIndex\)\.length > 0/)
  assert.match(prepare, /NhApiClient\.imageUrl\(detail\.mediaId, page\.sourceIndex, source\.extension\)/)
  assert.match(prepare, /ReaderImageCacheService\.load\(this\.context, url, cacheKey, false\)/)
  assert.match(prepare, /resolved.bodySourceReady = true/)
  assert.doesNotMatch(prepare, /thumbnail.available/)
  assert.match(prepare, /throw new Error\('missing_nh_auto_read_source'\)/)
})

test('NextN lab wires the source host bridge and source readiness into the shared session', () => {
  assert.match(lab, /const autoReadSourceHost = lab\?\.autoReadSourceProbe === 'delay-once'/)
  assert.match(lab, /new ReaderPagedSession\(catalog, assetProvider, adapter, adapter, autoReadSourceHost\)/)
  assert.match(lab, /new ReaderAutoReadPolicy\(true, this\.readerPresentation\.autoPageSeconds, 'source'\)/)
})

test('the Debug delay-once probe injects once and returns after cancellation for the session fence', () => {
  assert.match(probe, /!this\.injected && this\.mode === 'delay-once'/)
  assert.match(probe, /if \(inject\) this\.injected = true/)
  assert.match(probe, /setTimeout\(resolve, 3000\)/)
  assert.match(probe, /cancelled=\$\{cancellation\.isCancelled\(\)\}/)
})
