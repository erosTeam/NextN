#!/usr/bin/env node

import { readFile } from 'node:fs/promises'

const ROOT = new URL('../', import.meta.url)

const page = await readFile(new URL('feature/reader/src/main/ets/pages/ReaderPage.ets', ROOT), 'utf8')
const requiredPageTokens = [
  'ReaderVerticalFlow',
  'ReaderPagedFlow',
  'ReaderDoublePagedFlow',
  'ReaderThumbnailStrip',
  'ReaderTapOverlay',
  'ReaderTapZonePreview',
  'ReaderTranslationStatusOverlay',
  'toggleOrStartCurrentReaderTranslation',
  'toggleReaderTranslationAuto',
  'ReaderImageCacheService',
  'ReaderImagePage',
  'ReaderSpreadImageLayer',
  'ImageRecovery',
  'PinchGesture',
  'PanGesture',
  'scheduleReaderPreload',
]

for (const token of requiredPageTokens) {
  if (!page.includes(token)) {
    throw new Error(`feature/reader/src/main/ets/pages/ReaderPage.ets: missing ${token}`)
  }
}

const service = await readFile(new URL('shared/src/main/ets/services/ReaderPresentationService.ets', ROOT), 'utf8')
for (const token of ['setMode', 'setSpreadLayout', 'setPreloadPages', 'setTapZoneLayout', 'setTapZoneInvert']) {
  if (!service.includes(token)) {
    throw new Error(`ReaderPresentationService.ets: missing ${token}`)
  }
}

const cache = await readFile(new URL('shared/src/main/ets/services/ReaderImageCacheService.ets', ROOT), 'utf8')
for (const token of ['load(', 'clear(']) {
  if (!cache.includes(token)) {
    throw new Error(`ReaderImageCacheService.ets: missing ${token}`)
  }
}

console.log('OK reader contract passed (presentation, interaction, translation, cache, preload)')
