import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const page = fs.readFileSync(path.join(root,
  'feature/reader/src/main/ets/lab/NextNReaderLabPage.ets'), 'utf8')
const shell = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8')

assert.match(shell, /NextNReaderLabPage\(\{[\s\S]*hostSettingsAvailable: true,[\s\S]*settingsSheetContent:[\s\S]*this\.ReaderSettingsSheet\(dismiss\)/)
assert.match(page, /hostSettings: this\.hostSettingsAvailable[\s\S]*new ReaderHostSettings/)
assert.match(page, /this\.openHostSettings\(\)/)
assert.match(page, /active: this\.hostRouteActive\(\) && this\.labVisibility\.foreground && !this\.readerSettingsSheetShown/)
assert.match(page, /\.bindSheet\([\s\S]*\$\$this\.readerSettingsSheetShown[\s\S]*this\.settingsSheetContent/)

assert.match(page, /externalOpen: this\.request\.productionSources === true[\s\S]*new ReaderExternalOpen/)
assert.match(page, /source\.work !== this\.request\.work/)
assert.match(page, /NhGalleryExternalOpenService\.openCanonicalGallery/)
assert.match(page, /gallery_error_external_open_unavailable/)

assert.match(page, /preferenceSink: new ReaderPreferenceSink\([\s\S]*this\.persistRuntimePolicy\(policy, intent\)/)
assert.match(page, /intent === 'layout'[\s\S]*applyLayout/)
assert.match(page, /intent === 'direction'[\s\S]*applyDirection/)
assert.match(page, /intent === 'spread_layout'[\s\S]*applySpreadLayout/)
assert.match(page, /intent === 'first_page_alone'[\s\S]*applyFirstPageAlone/)
assert.match(page, /this\.persistCrop\(enabled, policy\)/)
assert.match(page, /NextNReaderRuntimePreferences\.applyCrop/)

assert.match(page, /new NextNReaderTranslationProvider\(context, variantProvider/)
assert.match(page, /hostActions: new ReaderHostActions\(this\.translationActions\(\)/)
assert.match(page, /this\.handleTranslationAction\(id, source, navigation, sourceIndex\)/)
assert.match(page, /variantPreferenceResolver:[\s\S]*this\.variantPreference\(sourceIndex\)/)
assert.match(page, /onVariantSelection:[\s\S]*this\.handleVariantSelection\(sourceIndex, preference, result\)/)
assert.match(page, /hostStatus:[\s\S]*translationBusyPage[\s\S]*translationErrorPage[\s\S]*new ReaderHostStatus/)
assert.match(page, /currentTranslationTarget[\s\S]*state\.navigationRevision === navigation/)
assert.match(page, /translationAutoEnabled && sourceIndex === this\.currentSourceIndex/)
assert.match(page, /scheduleNextAutoTranslation\(sourceIndex: number\)[\s\S]*const next = sourceIndex \+ 1/)
assert.match(page, /translationWindowFrame\(next\)[\s\S]*frame\?\.asset\.phase !== 'displayed'/)
assert.match(page, /session\.prepareVariantForSource\(next, state\.unit\.key\.copy\(\), state\.navigationRevision,[\s\S]*'translated', identity\)/)
assert.match(page, /result === 'changed' \|\| result === 'unchanged'[\s\S]*sourceIndex === this\.currentSourceIndex[\s\S]*scheduleNextAutoTranslation\(sourceIndex\)/)
assert.match(page, /result === 'unavailable'[\s\S]*sourceIndex === this\.currentSourceIndex[\s\S]*translationErrorPage = sourceIndex[\s\S]*scheduleNextAutoTranslation\(sourceIndex\)/)

console.log('PASS NextN shared reader host settings, external open, runtime preference and auto-translation wiring')
