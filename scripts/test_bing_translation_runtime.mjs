import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const source = fs.readFileSync(new URL('../shared/src/main/ets/services/BingTranslationService.ets', import.meta.url), 'utf8')
const ticketPage = 'params_AbusePreventionHelper = [123,"fixture-ticket",3600000]; IG:"abcdef";'
const translated = '你好，世界。'
const response = JSON.stringify([{ translations: [{ text: translated, to: 'zh-Hans' }] }])

function fixture(postReplies = []) {
  const calls = []
  let freeOnly = true
  const context = { exports: {}, Date, setTimeout, clearTimeout, require: name => {
    if (name === '../network/AxiosHttpClient') return { AxiosHttpClient: { async requestText(url, method, headers, body) {
      calls.push({ url, method, headers, body })
      return method === 'GET' ? { statusCode: 200, body: ticketPage }
        : (postReplies.shift() ?? { statusCode: 200, body: response })
    } } }
    if (name === './ComicTranslationDiagnosticLogger') return { ComicTranslationDiagnosticLogger: { info() {}, warn() {} } }
    if (name === '../constants/EhConstants') return { EhConstants: { USER_AGENT: 'fixture-agent', ACCEPT_LANGUAGE: 'en' } }
    if (name === '../diagnostics/DiagnosticLogger') return { DiagnosticLogger: { info() {}, warn() {}, ownerHash: () => 'fixture' } }
    if (name === '../settings/CommentTranslationSettings') return { CommentTranslationSettings: { current: () => ({ useGoogleOnly: freeOnly }) } }
    return {}
  } }
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
  } }).outputText, context)
  return { service: context.exports.BingTranslationService, calls, setFreeOnly: value => { freeOnly = value } }
}

test('actual Bing array response is parsed and malformed or empty translations are rejected', () => {
  const { service } = fixture()
  assert.equal(service.parseBingBody(response), translated)
  for (const body of ['invalid JSON', 'null', '[]', '[null]', '[42]', '[{}]', '[{"translations":[]}]', '[{"translations":[null]}]', '[{"translations":[{"text":42}]}]']) {
    assert.equal(service.parseBingBody(body), '', body)
  }
})

test('anonymous ticket + POST preserve text, use the Chinese language code and reuse a valid ticket', async () => {
  const { service, calls } = fixture()
  assert.equal(await service.translate('A & B + C.', 'zh-CN'), translated)
  assert.equal(await service.translate('Hello again.', 'zh-CN'), translated)
  assert.deepEqual(calls.map(call => call.method), ['GET', 'POST', 'POST'])
  const post = calls[1]
  assert.match(post.url, /^https:\/\/cn\.bing\.com\/ttranslatev3\?/)
  const form = new URLSearchParams(post.body)
  assert.equal(form.get('text'), 'A & B + C.')
  assert.equal(form.get('to'), 'zh-Hans')
  assert.equal(post.headers['X-Requested-With'], 'XMLHttpRequest')
  assert.ok(calls.every(call => !Object.hasOwn(call.headers, 'Cookie')))
})

test('a failed translation refreshes the ticket once and then surfaces persistent failure', async () => {
  const recovered = fixture([{ statusCode: 429, body: '' }])
  assert.equal(await recovered.service.translate('Hello.', 'zh-CN'), translated)
  assert.deepEqual(recovered.calls.map(call => call.method), ['GET', 'POST', 'GET', 'POST'])
  const failed = fixture([{ statusCode: 429, body: '' }, { statusCode: 429, body: '' }])
  await assert.rejects(failed.service.translate('Hello.', 'zh-CN'), /Bing Translate HTTP 429/)
  assert.equal(failed.calls.length, 4)
})

