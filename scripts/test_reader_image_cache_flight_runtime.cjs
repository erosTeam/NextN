const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const Module = require('node:module')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

const source = path.resolve(__dirname, '../shared/src/main/ets/services/ReaderImageCacheService.ets')

// The architecture record requires the NextN adapter to prove real cancellation
// and retry de-duplication semantics rather than only "attaches to the same
// ReaderSurface": one stream per cache key, a user Retry that waits for the
// current flight instead of racing its .part file, and a failed stream that
// settles cleanly so the next attempt can start fresh.
function setup() {
  const files = new Map()
  const gets = []
  const io = {
    OpenMode: { READ_WRITE: 1, CREATE: 2, TRUNC: 4 },
    mkdirSync: () => {},
    accessSync: (p) => files.has(p) || files.has(`${p}/`),
    openSync: (p) => {
      files.set(p, files.get(p) ?? new Uint8Array(0))
      return { fd: p }
    },
    writeSync: (fd, data) => {
      const chunk = new Uint8Array(data)
      const previous = files.get(fd) ?? new Uint8Array(0)
      const merged = new Uint8Array(previous.length + chunk.length)
      merged.set(previous, 0)
      merged.set(chunk, previous.length)
      files.set(fd, merged)
      return chunk.length
    },
    fsyncSync: () => {},
    closeSync: () => {},
    renameSync: (from, to) => {
      const value = files.get(from)
      if (value === undefined) throw new Error('missing source')
      files.set(to, value)
      files.delete(from)
    },
    unlinkSync: (p) => { files.delete(p) },
    statSync: (p) => {
      const value = files.get(p)
      if (value === undefined) throw new Error('missing')
      return { size: value.length, mtime: 1 }
    },
    listFileSync: (directory) => {
      return Array.from(files.keys())
        .filter((name) => name.startsWith(`${directory}/`))
        .map((name) => name.substring(directory.length + 1))
    },
    utimes: () => {},
  }
  const stream = {
    // Each call is a distinct GET. Tests decide when it settles.
    get: (url, headers, connect, read, limit, sink) => {
      let settle
      const pending = new Promise((resolve) => { settle = resolve })
      const entry = { url, sink, settle: (outcome) => settle(outcome) }
      gets.push(entry)
      return pending
    },
  }
  const settings = { limitBytes: () => 64 * 1024 * 1024 }
  const mod = new Module(source, module)
  mod.require = (name) => name === '@kit.AbilityKit' ? { common: {} }
    : name === '@kit.CoreFileKit' ? { fileIo: io }
      : name === '../network/StreamingHttpClient' ? { StreamingHttpClient: stream }
        : name === '../settings/ReaderImageCacheSettings' ? { ReaderImageCacheSettings: settings }
          : require(name)
  mod._compile(ts.transpileModule(fs.readFileSync(source, 'utf8'), { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, source)
  return { service: mod.exports.ReaderImageCacheService, gets, files }
}

function complete(entry, bytes, statusCode = 200) {
  const accepted = entry.sink(new Uint8Array(bytes).buffer)
  entry.settle({ statusCode, receivedBytes: bytes, limitExceeded: false, sinkRejected: !accepted, cancelled: false })
}

test('concurrent loads of one key share a single stream and do not duplicate a GET', async () => {
  const { service, gets } = setup()
  const load = service.load
  const context = { cacheDir: '/cache' }
  const first = load(context, 'https://host/1.jpg', 'reader:v2:1:media:1:jpg', false)
  const second = load(context, 'https://host/1.jpg', 'reader:v2:1:media:1:jpg', false)
  assert.equal(gets.length, 1, 'a second plain load must join the existing flight')
  complete(gets[0], 8)
  const results = await Promise.all([first, second])
  assert.equal(gets.length, 1)
  assert.equal(results[0].localPath, results[1].localPath)
  assert.equal(results[0].fromCache, false)
})

test('a user Retry waits for the current flight and then issues exactly one new GET', async () => {
  const { service, gets } = setup()
  const load = service.load
  const context = { cacheDir: '/cache' }
  const ordinary = load(context, 'https://host/2.jpg', 'reader:v2:1:media:2:jpg', false)
  const retry = load(context, 'https://host/2.jpg', 'reader:v2:1:media:2:jpg', true)
  assert.equal(gets.length, 1, 'the retry must not race the existing .part stream')
  complete(gets[0], 8)
  const stable = await ordinary
  for (let attempt = 0; attempt < 20 && gets.length < 2; attempt += 1) {
    await new Promise((resolve) => setTimeout(resolve, 1))
  }
  assert.equal(gets.length, 2, 'the retry issues exactly one fresh GET after the first settles')
  complete(gets[1], 12)
  const reloaded = await retry
  assert.equal(reloaded.localPath === stable.localPath, false)
  assert.equal(reloaded.familyPath, stable.localPath, 'the immutable version keeps the stable family path')
})

test('a failed stream leaves no flight behind so the next attempt retries cleanly', async () => {
  const { service, gets } = setup()
  const load = service.load
  const context = { cacheDir: '/cache' }
  const failing = load(context, 'https://host/3.jpg', 'reader:v2:1:media:3:jpg', false)
  assert.equal(gets.length, 1)
  gets[0].settle({ statusCode: 404, receivedBytes: 0, limitExceeded: false, sinkRejected: false, cancelled: false })
  await assert.rejects(failing)
  const retried = load(context, 'https://host/3.jpg', 'reader:v2:1:media:3:jpg', false)
  assert.equal(gets.length, 2, 'a settled failure must not block a fresh request')
  complete(gets[1], 16)
  const result = await retried
  assert.equal(result.bytes, 16)
})

test('a later ordinary load reuses the completed file without another GET', async () => {
  const { service, gets } = setup()
  const load = service.load
  const context = { cacheDir: '/cache' }
  const first = load(context, 'https://host/4.jpg', 'reader:v2:1:media:4:jpg', false)
  complete(gets[0], 8)
  const stored = await first
  const cached = await load(context, 'https://host/4.jpg', 'reader:v2:1:media:4:jpg', false)
  assert.equal(gets.length, 1)
  assert.equal(cached.fromCache, true)
  assert.equal(cached.localPath, stored.localPath)
})

test('a presented force-reload version starts maintenance only after its lease is retired', async () => {
  const { service, gets, files } = setup()
  const context = { cacheDir: '/cache' }
  const load = service.load
  const initial = load(context, 'https://host/5.jpg', 'reader:v2:1:media:5:jpg', false)
  complete(gets[0], 8)
  await initial
  assert.equal(service.maintenanceWritesSincePrune, 0)

  const reloading = load(context, 'https://host/5.jpg', 'reader:v2:1:media:5:jpg', true)
  complete(gets[1], 12)
  const reloaded = await reloading
  assert.equal(reloaded.familyPath.length > 0, true)
  assert.equal(service.maintenanceWritesSincePrune, 0,
    'a staged reload defers maintenance until its consumer retires the native Image')

  const lease = service.retain(reloaded)
  service.markPresented(lease)
  service.release(context, lease)
  assert.equal(files.has(reloaded.localPath), true, 'a presented immutable version remains selectable')
  assert.equal(service.maintenanceWritesSincePrune, 1,
    'retiring the presented lease completes the deferred cache-maintenance chain')
})
