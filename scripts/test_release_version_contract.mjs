#!/usr/bin/env node
/**
 * Contract: AppScope/app.json5 versionName is the single release version source.
 * The root and every host module (entry, feature/*, shared) oh-package.json5
 * version must equal it. CI names release artifacts and picks the changelog
 * from this version, so a mismatch ships wrong metadata.
 *
 * third_party/* keeps its own library version and is exempt.
 *
 * Run: node scripts/test_release_version_contract.mjs
 */
import { readFileSync, existsSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

function readJson5(p) {
  let s = readFileSync(p, 'utf8')
  s = s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:])\/\/.*$/gm, '$1')
  s = s.replace(/,(\s*[}\]])/g, '$1')
  return JSON.parse(s)
}

const errors = []
const appJson = readJson5(join(ROOT, 'AppScope', 'app.json5'))
const appVersion = appJson.app?.versionName
if (typeof appVersion !== 'string' || appVersion.length === 0) {
  errors.push('AppScope/app.json5 has no app.versionName')
} else {
  const featureDirs = existsSync(join(ROOT, 'feature')) ? readdirSync(join(ROOT, 'feature')) : []
  const targets = ['oh-package.json5', 'entry/oh-package.json5', 'shared/oh-package.json5',
    ...featureDirs.map((d) => `feature/${d}/oh-package.json5`)]
  for (const rel of targets) {
    const p = join(ROOT, rel)
    if (!existsSync(p)) {
      errors.push(`${rel} missing`)
      continue
    }
    const pkg = readJson5(p)
    if (pkg.version !== appVersion) {
      errors.push(`${rel} version ${pkg.version} != app.json5 versionName ${appVersion}`)
    }
  }
}

if (errors.length > 0) {
  console.error('release version contract failed:')
  for (const e of errors) console.error('  ' + e)
  process.exit(1)
}
console.log('release version contract passed: app=' + appVersion)
