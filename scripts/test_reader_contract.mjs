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

const spreadLayerStart = page.indexOf('struct ReaderSpreadImageLayer')
const spreadLayerEnd = page.indexOf('struct ReaderSpreadSurface', spreadLayerStart)
const spreadLayer = page.slice(spreadLayerStart, spreadLayerEnd)
if (!spreadLayer.includes('ReaderLoadingStage({')) {
  throw new Error('ReaderSpreadImageLayer: loading recovery must use the shared ReaderLoadingStage')
}
if (/if \(this\.isRetrying \|\| this\.isLoading\) \{\s*LoadingProgress\(\)/s.test(spreadLayer)) {
  throw new Error('ReaderSpreadImageLayer: bare loading progress regresses the shared loading contract')
}

const rootStackStart = page.indexOf('Stack() {', page.indexOf('export struct ReaderPage'))
const openingProxyIndex = page.indexOf('this.ReaderOpeningTransitionProxy()', rootStackStart)
const readerContentIndex = page.indexOf('this.ReaderContent()', rootStackStart)
if (openingProxyIndex < 0 || readerContentIndex < 0 || openingProxyIndex >= readerContentIndex) {
  throw new Error('ReaderPage: opening proxy must stay below live Reader content and its loading UI')
}
if (!page.includes('private readerContentSurfaceColor(): ResourceColor')) {
  throw new Error('ReaderPage: missing transparent content surface during thumbnail handoff')
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
