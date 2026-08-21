#!/usr/bin/env node

/**
 * Prevent internal exception text from becoming product copy.
 *
 * Diagnostics and classifiers may inspect Error.message, but page-facing
 * state, Toasts and persisted sync summaries must use localized UI strings.
 * This source guard supplements physical UI acceptance; it does not claim
 * that a branch is visually correct or reachable on device.
 */
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)))
const SOURCE_ROOTS = ['entry', 'feature', 'shared']
const failures = []

function walk(directory) {
  const result = []
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name)
    if (entry.isDirectory()) {
      if (entry.name !== 'build' && entry.name !== 'oh_modules') {
        result.push(...walk(absolute))
      }
    } else if (entry.isFile() && entry.name.endsWith('.ets')) {
      result.push(absolute)
    }
  }
  return result
}

const visibleErrorPatterns = [
  {
    name: 'page error state receives an exception message',
    pattern: /(?:errorMessage|loadMoreErrorMessage|commentSubmitError|accountActionError)\s*=\s*[^\n;]*(?:error|_error|err)[^\n;]*\.message/g,
  },
  {
    name: 'localized Toast template receives an exception message',
    pattern: /message:\s*AppStrings\.format\([^\n]*\[\s*(?:error|_error|err)\.message\s*\]/g,
  },
  {
    name: 'Toast helper receives an exception message',
    pattern: /(?:this\.)?(?:toast|show[A-Za-z0-9]*Toast)\([^\n;]*(?:error|_error|err)[^\n;]*\.message/g,
  },
  {
    name: 'failed sync summary persists an exception message',
    pattern: /SyncSettings\.markRun\([^\n;]*SYNC_STATUS_FAILED[^\n;]*(?:error|_error|err)\.message/g,
  },
]

for (const sourceRoot of SOURCE_ROOTS) {
  for (const file of walk(path.join(ROOT, sourceRoot))) {
    const text = fs.readFileSync(file, 'utf8')
    for (const rule of visibleErrorPatterns) {
      rule.pattern.lastIndex = 0
      if (rule.pattern.test(text)) {
        failures.push(`${path.relative(ROOT, file)}: ${rule.name}`)
      }
    }
  }
}

const resourceFiles = [
  'entry/src/main/resources/base/element/string.json',
  'entry/src/main/resources/en_US/element/string.json',
  'entry/src/main/resources/zh_CN/element/string.json',
  'entry/src/main/resources/ja_JP/element/string.json',
]
const genericFailureKeys = new Set([
  'llm_source_create_failed',
  'llm_source_save_failed',
  'llm_source_delete_failed',
  'llm_binding_save_failed',
  'comment_translation_models_failed',
  'comic_torii_save_failed',
])
for (const relative of resourceFiles) {
  const resource = JSON.parse(fs.readFileSync(path.join(ROOT, relative), 'utf8'))
  for (const item of resource.string) {
    if (genericFailureKeys.has(item.name) && /\{\d+\}/.test(item.value)) {
      failures.push(`${relative}: ${item.name} still accepts raw detail`)
    }
  }
}

if (failures.length > 0) {
  for (const failure of failures) {
    console.error(`[FAIL] ${failure}`)
  }
  process.exitCode = 1
} else {
  console.log('[PASS] user-visible error boundary rejects raw exception text')
}
