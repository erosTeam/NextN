#!/usr/bin/env node

import { readFile } from 'node:fs/promises'

const ROOT = new URL('../', import.meta.url)

const page = await readFile(new URL('feature/reader/src/main/ets/pages/ReaderPage.ets', ROOT), 'utf8')
const apiClient = await readFile(new URL('shared/src/main/ets/network/NhApiClient.ets', ROOT), 'utf8')
const galleryModel = await readFile(new URL('shared/src/main/ets/model/NhGallery.ets', ROOT), 'utf8')
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
  'ReaderImageSurfaceCore',
  'ReaderImagePage',
  'ReaderVerticalImage',
  'ReaderSpreadImageLayer',
  'ImageRecovery',
  'PinchGesture',
  'PanGesture',
  'scheduleReaderPreload',
  'NhReaderColumnMode',
  'readerAdjacentNavigationIndex',
  'turnOnePageInDoublePage',
  'toggleDoublePage',
  'shareCurrentImage',
  'saveReaderImagesAtIndexes',
  'showReaderImageInfo',
  'toggleCropBordersForCurrentMode',
]

for (const token of requiredPageTokens) {
  if (!page.includes(token)) {
    throw new Error(`feature/reader/src/main/ets/pages/ReaderPage.ets: missing ${token}`)
  }
}

function componentSlice(source, name, nextName) {
  const start = source.indexOf(`struct ${name}`)
  const nextStruct = source.indexOf(`struct ${nextName}`, start)
  const nextClass = source.indexOf(`class ${nextName}`, start)
  const end = nextStruct >= 0 ? nextStruct : nextClass
  if (start < 0 || end < 0) {
    throw new Error(`ReaderPage: unable to isolate ${name}`)
  }
  return source.slice(start, end)
}

const imageCore = componentSlice(page, 'ReaderImageSurfaceCore', 'ReaderImagePage')
if (imageCore.includes('fillViewport')) {
  throw new Error('ReaderImageSurfaceCore: paged and continuous geometry must not be switched by fillViewport')
}
if (imageCore.includes('.aspectRatio(')) {
  throw new Error('ReaderImageSurfaceCore: shared image lifecycle must not own mode-specific aspect-ratio geometry')
}

const pagedImage = componentSlice(page, 'ReaderImagePage', 'ReaderVerticalImage')
if (pagedImage.includes('.aspectRatio(') || !pagedImage.includes(".height('100%')")) {
  throw new Error('ReaderImagePage: paged mode must remain a full-viewport surface without an aspect-ratio constraint')
}

const verticalImage = componentSlice(page, 'ReaderVerticalImage', 'ReaderPagedItem')
if (!verticalImage.includes('.aspectRatio(this.imageAspectRatio)') ||
  !verticalImage.includes('onAspectRatioChanged:')) {
  throw new Error('ReaderVerticalImage: continuous mode must own and refresh its intrinsic-ratio geometry')
}

const thumbnailTileStart = page.indexOf('struct ReaderThumbnailTile')
if (thumbnailTileStart < 0) {
  throw new Error('ReaderPage: missing ReaderThumbnailTile')
}
const thumbnailTile = page.slice(thumbnailTileStart)
const thumbnailWidthStart = thumbnailTile.indexOf('private thumbnailWidth(): number')
const thumbnailWidthEnd = thumbnailTile.indexOf('private pageLabel()', thumbnailWidthStart)
const thumbnailWidth = thumbnailTile.slice(thumbnailWidthStart, thumbnailWidthEnd)
if (thumbnailWidth.includes('this.page.width') || thumbnailWidth.includes('this.page.height')) {
  throw new Error('ReaderThumbnailTile: thumbnail geometry must not use full-page dimensions')
}
for (const token of ['decodedThumbnailWidth', 'decodedThumbnailHeight', 'onImageInfo:']) {
  if (!thumbnailTile.includes(token)) {
    throw new Error(`ReaderThumbnailTile: missing decoded-thumbnail geometry contract ${token}`)
  }
}
for (const token of ['this.page.thumbnailWidth', 'this.page.thumbnailHeight']) {
  if (!thumbnailWidth.includes(token)) {
    throw new Error(`ReaderThumbnailTile: missing source-thumbnail geometry contract ${token}`)
  }
}
for (const token of [
  "page.thumbnailWidth = NhApiClient.asNumber(item['thumbnail_width'])",
  "page.thumbnailHeight = NhApiClient.asNumber(item['thumbnail_height'])",
]) {
  if (!apiClient.includes(token)) {
    throw new Error(`NhApiClient: dropped NH page thumbnail geometry ${token}`)
  }
}
for (const token of ['thumbnailWidth: number = 0', 'thumbnailHeight: number = 0']) {
  if (!galleryModel.includes(token)) {
    throw new Error(`NhGalleryPage: missing source thumbnail dimension ${token}`)
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

const loadingStageStart = page.indexOf('struct ReaderLoadingStage')
const loadingStageEnd = page.indexOf('interface ReaderImageLoadEvent', loadingStageStart)
const loadingStage = page.slice(loadingStageStart, loadingStageEnd)
for (const token of [
  '@Param showTransitionBackground: boolean = false',
  'Text(this.hasProgress() ? this.progressPercent() : this.label)',
  'backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)',
  'borderRadius(ThemeTokens.RADIUS_CARD)',
]) {
  if (!loadingStage.includes(token)) {
    throw new Error(`ReaderLoadingStage: missing transition background contract ${token}`)
  }
}
if (loadingStage.includes('READER_TRANSITION_LOADING_PANEL_HEIGHT') ||
  loadingStage.includes("this.hasProgress() ? this.progressPercent() : '0%'")) {
  throw new Error('ReaderLoadingStage: transition background must not reserve a hidden progress row or fixed height')
}
const transitionBackgroundCalls = page.match(
  /showTransitionBackground: this\.readerThumbnailTransition\.readerOpeningProxyVisible\(\)/g,
) ?? []
if (transitionBackgroundCalls.length !== 2) {
  throw new Error('ReaderPage: only the two image-level loading paths may enable the transition background')
}

const service = await readFile(new URL('shared/src/main/ets/services/ReaderPresentationService.ets', ROOT), 'utf8')
for (const token of ['setMode', 'setSpreadLayout', 'setPreloadPages', 'setTapZoneLayout', 'setTapZoneInvert']) {
  if (!service.includes(token)) {
    throw new Error(`ReaderPresentationService.ets: missing ${token}`)
  }
}
if (!service.includes('mode === NhReaderMode.VERTICAL') || !service.includes('return NhReaderMode.PAGED')) {
  throw new Error('ReaderPresentationService: valid continuous mode must survive normalization; missing mode defaults to paged')
}

const settingsModel = await readFile(new URL('shared/src/main/ets/model/NhReaderSettings.ets', ROOT), 'utf8')
const presentationState = await readFile(
  new URL('shared/src/main/ets/state/ReaderPresentationState.ets', ROOT),
  'utf8',
)
for (const [name, source] of [
  ['NhReaderSettings', settingsModel],
  ['ReaderPresentationState', presentationState],
]) {
  if (!source.includes('mode: NhReaderMode = NhReaderMode.PAGED')) {
    throw new Error(`${name}: a new Reader must default to NextE-aligned single-page paging`)
  }
}
if (!settingsModel.includes('export enum NhReaderColumnMode')) {
  throw new Error('NhReaderSettings: missing per-gallery double-page column mode')
}

const settingsRepository = await readFile(
  new URL('shared/src/main/ets/storage/ReaderSettingsRepository.ets', ROOT),
  'utf8',
)
for (const token of [
  'READER_COLUMN_MODE_PREFIX',
  'static async columnMode(',
  'static saveColumnMode(',
  'value === NhReaderMode.VERTICAL',
  'return NhReaderMode.PAGED',
]) {
  if (!settingsRepository.includes(token)) {
    throw new Error(`ReaderSettingsRepository: missing default/pairing contract ${token}`)
  }
}

const spreadResolverStart = page.indexOf('class ReaderSpreadResolver')
const spreadResolverEnd = page.indexOf('struct ReaderImageSurfaceCore', spreadResolverStart)
const spreadResolver = page.slice(spreadResolverStart, spreadResolverEnd)
for (const token of [
  'spreadStarts(columnMode: NhReaderColumnMode',
  'columnMode === NhReaderColumnMode.EVEN_LEFT',
  'result.push(0)',
  'return normalized <= 0 ? 0',
]) {
  if (!spreadResolver.includes(token)) {
    throw new Error(`ReaderSpreadResolver: missing odd/even pairing contract ${token}`)
  }
}
if (page.includes('readerNavigationStep')) {
  throw new Error('ReaderPage: fixed +2 navigation cannot represent the even-left cover singleton')
}
if (!page.includes('private readerProgressStep(): number {\n    return 1')) {
  throw new Error('ReaderPage: progress slider must address every source page before spread normalization')
}

const cache = await readFile(new URL('shared/src/main/ets/services/ReaderImageCacheService.ets', ROOT), 'utf8')
for (const token of ['load(', 'clear(']) {
  if (!cache.includes(token)) {
    throw new Error(`ReaderImageCacheService.ets: missing ${token}`)
  }
}
if (/if \(forceReload\) \{\s*ReaderImageCacheService\.removeIfExists\(filePath\)/s.test(cache)) {
  throw new Error('ReaderImageCacheService: force reload must not delete a file still owned by the current ArkUI Image')
}
if (!/fileIo\.fsyncSync\(file\.fd\)[\s\S]*fileIo\.closeSync\(file\)[\s\S]*ReaderImageCacheService\.removeIfExists\(filePath\)[\s\S]*fileIo\.renameSync\(tmpPath, filePath\)/.test(cache)) {
  throw new Error('ReaderImageCacheService: completed stream must fsync and close before replacing the final file')
}
for (const token of ['familyPath', 'reloadPath(filePath)', 'latestPath(filePath)', 'static retain(',
  'static markPresented(', 'static release(', 'localLeases.get(entries[i].path)']) {
  if (!cache.includes(token)) throw new Error(`ReaderImageCacheService: missing immutable force-reload lifecycle ${token}`)
}
if (!/if \(!lease\.presented\) \{[\s\S]*removeIfExists\(result\.localPath\)[\s\S]*return[\s\S]*maintainAfterStore\(context, result\.bytes\)/.test(cache)) {
  throw new Error('ReaderImageCacheService: never-presented versions must be deleted while presented versions remain immutable')
}
if (!/const latestPath: string = ReaderImageCacheService\.latestPath\(filePath\)[\s\S]*const stageReload: boolean = forceReload &&[\s\S]*downloadAndStore\([\s\S]*storagePath,[\s\S]*!stageReload/.test(cache)) {
  throw new Error('ReaderImageCacheService: force reload must stage beside a live stable cache file')
}

const imageActions = await readFile(
  new URL('shared/src/main/ets/services/NhReaderImageActionService.ets', ROOT),
  'utf8',
)
for (const token of [
  'shareCurrentImage(',
  'UniformDataType.FILE',
  'UniformDataType.HYPERLINK',
  'showAssetsCreationDialog',
  'copyFile',
]) {
  if (!imageActions.includes(token)) {
    throw new Error(`NhReaderImageActionService: missing current-image action contract ${token}`)
  }
}

const thumbnailSurface = await readFile(
  new URL('shared/src/main/ets/components/GalleryPageThumbnailSurface.ets', ROOT),
  'utf8',
)
for (const token of ['@Event onImageInfo?', '.onComplete((event?:', 'this.onImageInfo(event.width, event.height)']) {
  if (!thumbnailSurface.includes(token)) {
    throw new Error(`GalleryPageThumbnailSurface: missing decoded image-size callback ${token}`)
  }
}

for (const locale of ['base', 'en_US', 'zh_CN', 'ja_JP']) {
  const resources = await readFile(
    new URL(`entry/src/main/resources/${locale}/element/string.json`, ROOT),
    'utf8',
  )
  for (const token of [
    'reader_action_share_current_image',
    'reader_action_save_current_image',
    'reader_action_shift_spread_one_page',
    'reader_action_toggle_double_page',
    'reader_image_info_title',
    'reader_spread_save_both',
  ]) {
    if (!resources.includes(`"name": "${token}"`)) {
      throw new Error(`${locale}/string.json: missing Reader parity resource ${token}`)
    }
  }
}

console.log('OK reader contract passed (mode/default, geometry, thumbnails, spread pairing, actions, cache, preload)')
