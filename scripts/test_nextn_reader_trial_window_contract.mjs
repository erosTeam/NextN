
import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const read = p => fs.readFileSync(path.join(root, p), 'utf8')

// 2026-09-22 defect #2: the production shared-reader route passed
// managesTrialWindow:false, which disabled the trial-window status-bar
// prepare/publish path — chrome visibility and the system status bar were no
// longer applied atomically, producing the top-bar jump the user recorded.
test('production shared-reader route manages the trial window (status-bar atomic path)', () => {
  const index = read('entry/src/main/ets/pages/Index.ets')
  const sharedBody = index.slice(
    index.indexOf('private sharedReaderBody'),
    index.indexOf('readerOverlayRouter'),
  )
  assert.ok(sharedBody.includes('NextNReaderLabPage'), 'production body mounts the lab page')
  assert.ok(
    !/managesTrialWindow:\s*false/.test(sharedBody),
    'production route must not disable the trial window',
  )
})

test('lab page keeps the status-bar prepare gate inside prepareChromeShow', () => {
  const lab = read('feature/reader/src/main/ets/lab/NextNReaderLabPage.ets')
  assert.match(lab, /prepareStatusBarVisible\(\)/, 'status-bar prepare must stay gated')
  assert.match(lab, /ReaderTrialLayoutCommit\.wait/, 'layout commit must stay gated')
})
