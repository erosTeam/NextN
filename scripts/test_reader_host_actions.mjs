import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const page = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderLabPage.ets'), 'utf8')
const shell = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8')

assert.match(shell, /NextNReaderLabPage\(\{[\s\S]*hostSettingsAvailable: true,[\s\S]*settingsSheetContent:[\s\S]*this\.ReaderSettingsSheet\(dismiss\)/)
assert.match(page, /hostSettingsAvailable: this\.hostSettingsAvailable/)
assert.match(page, /onHostSettings: \(\): void => \{ this\.openHostSettings\(\) \}/)
assert.match(page, /active: this\.hostRouteActive\(\) && this\.labVisibility\.foreground && !this\.readerSettingsSheetShown/)
assert.match(page, /\.bindSheet\([\s\S]*\$\$this\.readerSettingsSheetShown[\s\S]*this\.settingsSheetContent/)

assert.match(page, /externalOpenAvailable: this\.request\.productionSources === true/)
assert.match(page, /source\.work !== this\.request\.work/)
assert.match(page, /NhGalleryExternalOpenService\.openCanonicalGallery/)
assert.match(page, /gallery_error_external_open_unavailable/)

assert.match(page, /onRuntimePolicy: \(policy, intent\): void => \{ this\.persistRuntimePolicy\(policy, intent\) \}/)
assert.match(page, /intent === 'layout'[\s\S]*applyLayout/)
assert.match(page, /intent === 'direction'[\s\S]*applyDirection/)
assert.match(page, /intent === 'spread_layout'[\s\S]*applySpreadLayout/)
assert.match(page, /intent === 'first_page_alone'[\s\S]*applyFirstPageAlone/)
assert.match(page, /onCropChanged: \(enabled, policy\): void => \{ this\.persistCrop\(enabled, policy\) \}/)
assert.match(page, /NextNReaderRuntimePreferences\.applyCrop/)

console.log('PASS NextN shared reader host settings, external open and runtime preference wiring')
