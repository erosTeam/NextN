#!/usr/bin/env node
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)))
const read = (name) => fs.readFileSync(path.join(root, name), 'utf8')
const lab = read('feature/reader/src/main/ets/lab/NextNReaderLabPage.ets')
const index = read('entry/src/main/ets/pages/Index.ets')
const handoff = read('third_party/reader-kit/reader-ui/src/main/ets/ReaderRootEntryHandoff.ets')

function wired(labSource, indexSource, handoffSource) {
  const close = labSource.slice(labSource.indexOf('private closeTrial('), labSource.indexOf('private finishProgressWrites('))
  const host = indexSource.slice(indexSource.indexOf('private sharedReaderBody('),
    indexSource.indexOf('private readerRouteShown('))
  const request = close.indexOf('this.rootEntryHandoff.requestReverse(')
  const deferred = close.indexOf('this.onPrepareClose(')
  const reverse = host.indexOf('onTryReverseOpening:')
  const normal = host.indexOf('onPrepareClose:')
  return request >= 0 && deferred > request && reverse >= 0 && normal > reverse &&
    host.slice(reverse, normal).includes('ReaderThumbnailTransitionCoordinator.reverseOpening(') &&
    handoffSource.includes('this.reverseRequested = true') &&
    handoffSource.includes("entry?.cancel('back-reverse-claimed')") &&
    handoffSource.includes('if (entry === null || !active || this.reverseRequested) return')
}

assert.equal(wired(lab, index, handoff), true, 'production shared Back must claim reverse before async close')
assert.equal(wired(lab.replace('this.rootEntryHandoff.requestReverse(', 'this.rootEntryHandoff.noReverse('),
  index, handoff), false, 'removing the Lab wiring must fail this contract')
assert.equal(wired(lab, index.replaceAll('ReaderThumbnailTransitionCoordinator.reverseOpening(this.getUIContext(),',
  'ReaderThumbnailTransitionCoordinator.noReverse(this.getUIContext(),'), handoff), false,
  'removing the host reverse action must fail this contract')
console.log('OK NextN production shared reverse wiring and negative controls')
