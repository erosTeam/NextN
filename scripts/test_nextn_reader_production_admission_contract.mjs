
import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const read = p => fs.readFileSync(path.join(root, p), 'utf8')

// 2026-09-22 197 release defect: NextNReaderLabPage.aboutToAppear returned early
// on every release build, so the production reader destination mounted with a
// null session and an empty body. The guard must match the NextE production-safe
// shape: release + productionSources continues; only lab-only entries bail.
test('production reader session builds on release (guard admits release+production)', () => {
  const source = read('feature/reader/src/main/ets/lab/NextNReaderLabPage.ets')
  assert.ok(
    source.includes(
      'if ((!context.applicationInfo.debug && !production) || (!production && lab === null)) return',
    ),
    'aboutToAppear must keep the production-safe guard from NextEReaderLabPage',
  )
  assert.ok(
    !/if \(!context\.applicationInfo\.debug \|\|/.test(source),
    'release builds must not bail out of session construction unconditionally',
  )
})
