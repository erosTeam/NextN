#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)))
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8')
let failures = 0

function ok(name, condition) {
  if (!condition) {
    console.error(`[FAIL] ${name}`)
    failures += 1
  }
}

const settings = read('shared/src/main/ets/settings/GalleryDetailTransitionSettings.ets')
const settingsPage = read('feature/settings/src/main/ets/pages/SettingsPage.ets')
ok('detail mode and Reader thumbnail switch are independent durable settings',
  /DETAIL_MODE_KEY: string = 'gallery_detail_transition_mode'/.test(settings) &&
    /READER_THUMBNAIL_ENABLED_KEY: string = 'reader_thumbnail_transition_enabled'/.test(settings) &&
    /setMode\(context/.test(settings) && /setReaderThumbnailEnabled\([\s\S]*?context/.test(settings) &&
    /GalleryDetailTransitionMenu/.test(settingsPage) && /readerThumbnailEnabled/.test(settingsPage))

const collection = read('shared/src/main/ets/components/GalleryCollectionBody.ets')
const cardFiles = [
  'shared/src/main/ets/components/GalleryWaterfallCard.ets',
  'shared/src/main/ets/components/GalleryWaterfallCompactCard.ets',
  'shared/src/main/ets/components/GalleryCoverWallCard.ets',
  'shared/src/main/ets/components/GalleryMediumCard.ets',
  'shared/src/main/ets/components/GalleryListItem.ets',
]
const gridCard = read('shared/src/main/ets/components/GalleryGridCard.ets')
const galleryThumbnail = read('shared/src/main/ets/components/GalleryThumbnail.ets')
ok('all six browse presentations expose the real cover node to the transition',
  cardFiles.every((file) => {
    const source = read(file)
    return /@Param transitionCoverId: string = ''/.test(source) && /\.id\(this\.transitionCoverId\)/.test(source)
  }) &&
    /@Param transitionCoverId: string = ''/.test(gridCard) &&
    /surfaceId: this\.transitionCoverId/.test(gridCard) &&
    /@Param surfaceId: string = ''/.test(galleryThumbnail) &&
    /\.id\(this\.surfaceId\)/.test(galleryThumbnail) &&
    /GalleryDetailTransitionCoordinator\.open/.test(collection) &&
    /\.visibility\(this\.galleryVisibility\(gallery\)\)/.test(collection))

const history = read('feature/user/src/main/ets/pages/HistoryPage.ets')
ok('history uses the same card and cover ownership contract',
  /GalleryDetailTransitionCoordinator\.open/.test(history) &&
    /transitionCoverId: this\.galleryDetailSourceCoverId\(item\)/.test(history) &&
    /\.id\(this\.galleryDetailSourceId\(item\)\)/.test(history))

const galleryState = read('shared/src/main/ets/state/GalleryDetailTransitionState.ets')
const galleryCoordinator = read('shared/src/main/ets/navigation/GalleryDetailTransitionCoordinator.ets')
const index = read('entry/src/main/ets/pages/Index.ets')
ok('seamless transition owns geometry and spatially-timed card/detail crossfade',
  /customNavContentTransition/.test(index) &&
    /GALLERY_DETAIL_OPEN_CARD_EXIT_END_PROGRESS: number = 0\.55/.test(index) &&
    /GALLERY_DETAIL_CLOSE_CARD_ENTRY_START_PROGRESS: number = 0\.55/.test(index) &&
    /crossfadeToDetail/.test(index) && /crossfadeToCard/.test(index))
ok('cover-expand transition keeps a rounded expanding card and separate cover flight',
  /GalleryDetailSourceCardRemainder/.test(index) &&
    /coverFlightVisible/.test(index) && /fallbackCoverVisible/.test(index) &&
    /\.borderRadius\(this\.galleryDetailTransition\.radius\)/.test(index) &&
    /prepareCoverPop/.test(index) && /syncDetailCoverTarget/.test(galleryCoordinator) &&
    /coverMaskVisible/.test(galleryState))
ok('cover-expand pop snapshots detail before native navigation unmount and masks its cover',
  /getSync\('nextn-root-navigation'/.test(index) &&
    /GalleryDetailSnapshotRemainder/.test(index) &&
    /detailSnapshotVisible/.test(galleryState) &&
    /detailSnapshot\.release/.test(galleryState))

const detail = read('feature/gallery/src/main/ets/pages/GalleryDetailPage.ets')
const thumbnailPage = read('feature/gallery/src/main/ets/pages/GalleryThumbnailsPage.ets')
const thumbnailGrid = read('feature/gallery/src/main/ets/components/GalleryThumbnailGridContent.ets')
const virtualThumbnail = read('feature/gallery/src/main/ets/components/GalleryVirtualPageThumbnail.ets')
const compactThumbnail = read('feature/gallery/src/main/ets/components/GalleryCompactPreviewTile.ets')
ok('detail compact preview, detail grid, and all-thumbnails page share Reader transition scopes',
  /ReaderThumbnailTransitionCoordinator\.open/.test(detail) &&
    /transitionScope: this\.readerTransitionScope/.test(detail) &&
    /ReaderThumbnailTransitionCoordinator\.open/.test(thumbnailPage) &&
    /transitionScope: this\.transitionScope/.test(thumbnailPage) &&
    /ReaderThumbnailTransitionCoordinator\.sourceId/.test(thumbnailGrid) &&
    /sourceHidden\(this\.transitionSourceId\)/.test(virtualThumbnail) &&
    /sourceHidden\(this\.transitionSourceId\)/.test(compactThumbnail))

const readerState = read('shared/src/main/ets/state/ReaderThumbnailTransitionState.ets')
const readerCoordinator = read('shared/src/main/ets/navigation/ReaderThumbnailTransitionCoordinator.ets')
const reader = read('feature/reader/src/main/ets/pages/ReaderPage.ets')
ok('Reader can reverse an opening flight and closes only the image proxy',
  /reverseOpening\(/.test(readerCoordinator) && /openingCanReverse\(\)/.test(readerState) &&
    /ReaderCloseTransitionProxy/.test(reader) && /backdropOpacity/.test(reader) &&
    /closingProxyVisible/.test(reader) && /\.backgroundColor\(Color\.Transparent\)/.test(reader))
ok('Reader close reveals the retained Gallery surface below a root-owned image proxy',
  /rootProxyVisible\(\)/.test(readerState) &&
    /this\.overlayOpacity = 0/.test(readerState) &&
    /this\.state\.rootProxyVisible\(\)/.test(index) &&
    /this\.state\.readerSnapshot/.test(index) &&
    /this\.state\.closeTargetSnapshot/.test(index))
ok('Reader full-image decode does not block its background, loading affordance, or navigation surface',
  /ReaderOpeningLoadingOverlay/.test(reader) &&
    /readerOpeningProxyVisible/.test(reader) &&
    /ReaderTapOverlay/.test(reader) &&
    /notifyReaderImageReady/.test(reader))
ok('Reader return tracks the current page and captures that page for the visible thumbnail target',
  /readerThumbnailTransition\.updateCurrent/.test(reader) &&
    /readerPageSnapshotId\(pageIndex\)/.test(reader) &&
    /sourceId\(\s*transition\.sourceScope,\s*currentIndex/.test(readerCoordinator))

const loadReaderBlock = reader.slice(reader.indexOf('private async loadReader()'), reader.indexOf('private visiblePageText'))
const closeBlock = reader.slice(reader.indexOf('private requestReaderClose()'), reader.indexOf('private isCurrentRequest'))
ok('initial progress is never published at click, route request, or close',
  !/HistoryRepository\.saveProgress/.test(loadReaderBlock) &&
    !/persistProgress/.test(closeBlock) &&
    /publishInitialProgressIfSettled/.test(reader) &&
    /presentationSettledFor/.test(reader))

if (failures === 0) {
  console.log('OK gallery and Reader transition contract passed')
  process.exit(0)
}
console.error(`[FAIL] gallery and Reader transition contract: ${failures} failure(s)`)
process.exit(1)
