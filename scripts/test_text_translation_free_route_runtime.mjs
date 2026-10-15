import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
import { createRequire } from 'node:module'
const require = createRequire(import.meta.url)
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const source = fs.readFileSync(new URL('../shared/src/main/ets/services/CommentTranslationService.ets', import.meta.url), 'utf8')
function fixture() {
  const state = { freeOnly: false }, calls = [], scopes = [], saves = []
  let configured = false, rejectLlm = false
  const runtime = { baseUrl: 'https://fixture.invalid', modelId: 'fixture', apiKey: 'fixture-secret', reasoningEffort: '', requestIdentity: () => 'fixture-source-r1' }
  const prompt = { promptProfileId: 'fixture-prompt', promptRevision: 2, styleInstructions: 'fixture-style' }
  const modules = {
    './BingTranslationService': { BingTranslationService: { async translate(text, lang) { calls.push({ kind: 'bing', text, lang }); return text } } },
    '../state/CommentTranslationSettingsState': { connectCommentTranslationSettings: () => state },
    '../model/LlmSourceProfile': { LLM_CONSUMER_COMMENT_TRANSLATION: 'comment' },
    '../storage/LlmSourceProfileRepository': { LlmSourceProfileRepository: { currentBinding: () => ({ configured: () => configured }) } },
    './LlmSourceRuntimeResolver': { LlmSourceRuntimeResolver: { resolveComment: async () => ({ ...runtime }) } },
    '../settings/TextTranslationPromptProfileRepository': { TextTranslationPromptProfileRepository: { currentSelection: () => ({ ...prompt }) } },
    './TextTranslationPromptComposer': { TextTranslationPromptComposer: { composeInstructions: () => 'fixture-instructions' } },
    './OpenAiChatCompletionsClient': { OpenAiChatCompletionsConfig: class {}, OpenAiChatCompletionsClient: { async requestText(instructions, text, config) { calls.push({ kind: 'llm', text, config }); if (rejectLlm) throw new Error('fixture LLM failed'); return text } } },
    '../model/TextTranslationPromptProfile': { TEXT_TRANSLATION_CONTENT_COMMENT: 'comment' },
    './ComicTranslationDiagnosticLogger': { ComicTranslationDiagnosticLogger: { info() {}, warn() {} } },
    '../state/AppearanceState': { connectLanguageState: () => ({ effectiveLocale: 'zh-CN' }) },
  }
  const context = { exports: {}, require: name => modules[name] ?? {}, Date }
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText, context)
  const service = context.exports.CommentTranslationService
  service.cacheKey = (scope, text) => { scopes.push(scope); return scope + text }
  service.cached = async () => ''
  service.save = async (_context, key, scope, text) => { saves.push({ key, scope, text }) }
  return { service, state, runtime, calls, scopes, saves, configured: value => { configured = value }, rejectLlm: value => { rejectLlm = value } }
}
test('unbound and explicitly free routes keep comment/title scope separate and restore mentions', async () => {
  const f = fixture(), mention = '@fixture-user', protectedText = f.service.protectMentionText(mention)
  assert.equal(await f.service.translate({}, 'Hello ' + protectedText, 0, 'comment'), 'Hello ' + mention)
  assert.equal(await f.service.translate({}, 'Hello', 0, 'gallery_title'), 'Hello')
  f.state.freeOnly = true
  f.configured(true)
  assert.equal(await f.service.translate({}, 'Hello', 0, 'comment'), 'Hello')
  assert.equal(new Set(f.scopes).size, 3)
  assert.ok(f.calls.every(call => call.kind === 'bing'))
})
test('configured LLM and prompt are retained; only model-default failures use Bing', async () => {
  const f = fixture();f.configured(true)
  await f.service.translate({}, 'Configured')
  assert.equal(f.calls[0].kind, 'llm')
  assert.equal(f.calls[0].config.apiKey, 'fixture-secret')
  f.rejectLlm(true)
  await f.service.translate({}, 'Default failure')
  assert.equal(f.calls.at(-1).kind, 'bing')
  f.runtime.reasoningEffort = 'high'
  await assert.rejects(f.service.translate({}, 'Explicit failure'), /fixture LLM failed/)
  assert.equal(f.calls.at(-1).kind, 'llm')
})
test('route snapshot survives preference changes while the request is queued', async () => {
  const f = fixture();f.configured(true)
  const pending = []
  f.service.scheduler.schedule = task => { pending.push(task) }
  const result = f.service.translate({}, 'Snapshot')
  for (let i = 0; i < 8; i++) await Promise.resolve()
  assert.equal(pending.length, 1)
  f.state.freeOnly = true;f.runtime.modelId = 'changed';f.runtime.reasoningEffort = 'high'
  pending[0].start()
  await result
  assert.equal(f.calls[0].kind, 'llm')
  assert.equal(f.calls[0].config.modelId, 'fixture')
  assert.equal(f.calls[0].config.reasoningEffort, '')
})
