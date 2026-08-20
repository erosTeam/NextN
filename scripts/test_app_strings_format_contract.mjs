#!/usr/bin/env node

import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const repositoryRoot = dirname(dirname(fileURLToPath(import.meta.url)))
const locales = ['base', 'en_US', 'zh_CN', 'ja_JP']
const etsFiles = execFileSync('rg', ['--files', '-g', '*.ets'], {
  cwd: repositoryRoot,
  encoding: 'utf8',
}).trim().split('\n').filter((value) => value.length > 0)
const formatKeys = new Set()

for (const relativePath of etsFiles) {
  const source = readFileSync(join(repositoryRoot, relativePath), 'utf8')
  for (const match of source.matchAll(/AppStrings\.format\(\s*['"]([^'"]+)['"]/g)) {
    formatKeys.add(match[1])
  }
}

const failures = []
for (const locale of locales) {
  const resourcePath = join(repositoryRoot, 'entry', 'src', 'main', 'resources', locale, 'element', 'string.json')
  const catalog = JSON.parse(readFileSync(resourcePath, 'utf8'))
  const values = new Map((catalog.string ?? []).map((entry) => [entry.name, entry.value]))
  for (const key of [...formatKeys].sort()) {
    const value = values.get(key)
    if (typeof value !== 'string') {
      failures.push(`${locale}:${key}:missing`)
      continue
    }
    if (!value.includes('{0}')) {
      failures.push(`${locale}:${key}:missing-{0}`)
    }
    if (/%(?:\d+\$)?[a-z]/i.test(value)) {
      failures.push(`${locale}:${key}:unsupported-printf-placeholder`)
    }
  }
}

if (failures.length > 0) {
  for (const failure of failures) {
    console.error(`[FAIL] ${failure}`)
  }
  process.exit(1)
}

console.log(`OK AppStrings.format contract (${formatKeys.size} keys across ${locales.length} locales)`)
