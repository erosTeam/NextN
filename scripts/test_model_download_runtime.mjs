import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import vm from 'node:vm'
import crypto from 'node:crypto'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const modelSource = fs.readFileSync(new URL('../shared/src/main/ets/services/ComicTranslationModelService.ets', import.meta.url), 'utf8')
const logger = { warn() {} }
const payload = Buffer.from('verified model fixture')
const sha = crypto.createHash('sha256').update(payload).digest('hex')

function load(source, modules, globals = {}) {
  const context = { exports: {}, require: name => {
    assert.ok(name in modules, `unexpected module ${name}`)
    return modules[name]
  }, Date, setTimeout, clearTimeout, ...globals }
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, context)
  return context.exports
}

function files() {
  return { OpenMode: { READ_ONLY: 0, READ_WRITE: 2, CREATE: 4, TRUNC: 8 },
    statSync: fs.statSync, accessSync: fs.existsSync,
    unlinkSync: fs.unlinkSync, renameSync: fs.renameSync,
    openSync: (file, flags) => ({ fd: fs.openSync(file, flags === 0 ? 'r' : 'w+') }),
    closeSync: file => fs.closeSync(file.fd),
    readSync: (fd, buffer, options) => fs.readSync(fd, Buffer.from(buffer), 0, options.length, null),
    writeSync: (fd, buffer, options) => fs.writeSync(fd, Buffer.from(buffer), 0, buffer.byteLength, options?.offset),
  }
}

function modelFixture(download) {
  return load(modelSource, {
    '@kit.CoreFileKit': { fileIo: files() },
    '@kit.CryptoArchitectureKit': { cryptoFramework: { createMd() {
      const hash = crypto.createHash('sha256')
      return { updateSync: value => hash.update(value.data), digestSync: () => ({ data: hash.digest() }) }
    } } },
    '../diagnostics/DiagnosticLogger': { DiagnosticLogger: logger },
    '../network/StreamingHttpClient': { StreamingHttpClient: { async get(url, headers, connectMs, readMs, maxBytes, sink, keep, stallMs) {
      assert.deepEqual(Object.keys(headers).sort(), ['Accept', 'User-Agent'])
      assert.equal(stallMs, 60000)
      assert.equal(readMs, 45 * 60 * 1000)
      assert.equal(keep(), true)
      const bytes = await download(url)
      const accepted = sink(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength))
      return { statusCode: 200, receivedBytes: bytes.length, sinkRejected: !accepted, limitExceeded: bytes.length > maxBytes }
    } } },
  }).ComicTranslationModelService
}

test('corrupt HTTP 200 body is rejected and the next verified source is installed', async t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'nextn-model-test-'))
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }))
  const attempts = []
  const service = modelFixture(async (...args) => {
    const [url] = args
    attempts.push(url)
    const body = attempts.length === 1 ? Buffer.alloc(payload.length, 120) : payload
    return body
  })
  const destination = path.join(dir, 'model.bin')
  await service.installAssetIfMissing('model.bin', destination, payload.length, sha)
  assert.equal(attempts.length, 2)
  assert.match(attempts[0], /^https:\/\/github.com\//)
  assert.match(attempts[1], /^https:\/\/ghproxy.net\//)
  assert.equal(service.preferredSource, 1)
  assert.deepEqual(fs.readFileSync(destination), payload)
  assert.equal(fs.existsSync(destination + '.part'), false)
  await service.installAssetIfMissing('model.bin', destination, payload.length, sha)
  assert.equal(attempts.length, 2, 'verified installed files do not download again')
})

test('all failures remove partial bytes without replacing the installed file or selecting a bad source', async t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'nextn-model-test-'))
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }))
  const attempts = []
  const service = modelFixture(async (url) => {
    attempts.push(url)
    if (attempts.length % 2) throw new Error('fixture transport failed')
    return Buffer.from('short')
  })
  const destination = path.join(dir, 'model.bin')
  fs.writeFileSync(destination, 'old version')
  service.preferredSource = 2
  await assert.rejects(service.installAssetIfMissing('model.bin', destination, payload.length, sha), /unavailable on all 4 sources/)
  assert.equal(attempts.length, 4)
  assert.equal(new Set(attempts).size, 4)
  assert.equal(service.preferredSource, 2)
  assert.equal(fs.readFileSync(destination, 'utf8'), 'old version')
  assert.equal(fs.existsSync(destination + '.part'), false)
})

