#!/usr/bin/env node
/**
 * Non-UI data and integration contract for configurable retained Home SubTabs.
 * Run: node scripts/test_home_subtab_contract.mjs
 */
import fs from 'fs'

const read = (path) => fs.readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
let failures = 0
function ok(name, condition) {
  if (!condition) {
    console.error(`[FAIL] ${name}`)
    failures += 1
  }
}

const model = read('shared/src/main/ets/model/NhHomeSubtabProfile.ets')
ok('model has stable kinds, stable starter ids and normalized request fields',
  /LATEST = 'latest'/.test(model) && /POPULAR = 'popular'/.test(model) && /SEARCH = 'search'/.test(model) &&
    /HOME_SUBTAB_LATEST_UUID: string = 'builtin-latest'/.test(model) &&
    /HOME_SUBTAB_POPULAR_UUID: string = 'builtin-popular'/.test(model) &&
    /HOME_SUBTAB_STARTER_CHINESE_UUID: string = 'starter-language-chinese'/.test(model) &&
    /HOME_SUBTAB_STARTER_FAVORITED_UUID: string = 'starter-highly-favorited'/.test(model) &&
    /static normalizeLanguage\(/.test(model) && /static normalizeSort\(/.test(model))
ok('request content revision excludes name, order, hidden and presentation',
  /contentRevision\(\): string \{[\s\S]*this\.query\.trim\(\)[\s\S]*this\.language[\s\S]*this\.sort[\s\S]*\}/.test(model) &&
    !/contentRevision\(\): string \{[^}]*this\.name/.test(model) &&
    !/contentRevision\(\): string \{[^}]*this\.hidden/.test(model) &&
    !/contentRevision\(\): string \{[^}]*this\.presentation/.test(model))

const settings = read('shared/src/main/ets/settings/HomeSubtabSettings.ets')
ok('first initialization is latest, popular, Chinese and favorites>=1000',
  /return \[latest, popular, chinese, favorite\]/.test(settings) &&
    /chinese\.language = NhSearchLanguage\.CHINESE/.test(settings) &&
    /favorite\.query = 'favorites:>=1000'/.test(settings))
ok('CRUD validates search content, preserves builtin identity and prevents the last visible item from disappearing',
  /!profile\.hasEffectiveSearch\(\)/.test(settings) &&
    /profile\.isBuiltin\(\)/.test(settings) &&
    /visibleCount\(state\.profiles\) <= 1/.test(settings) &&
    /static async reorder\(/.test(settings) && /static async setHidden\(/.test(settings))
ok('selection falls back to the first visible profile after hide/delete/restore',
  /state\.selectedUuid = HomeSubtabSettings\.firstVisible\(next\)/.test(settings) &&
    /visibleSelection\(profiles: NhHomeSubtabProfile\[\], selectedUuid: string\)/.test(settings))
ok('one-time migration preserves legacy Popular selection and fixed builtin query identities',
  /connectHomeSource\(\)\.selectedKey === HOME_SOURCE_POPULAR[\s\S]*HOME_SUBTAB_POPULAR_UUID/.test(settings) &&
    /normalizeBuiltinIdentity\(\)/.test(settings) &&
    /normalizeBuiltinIdentity\(\): boolean/.test(model))
ok('restore and sync refresh persist canonical builtin fields and selected fallback',
  /ensureBuiltins\(profiles, canonicalized\)/.test(settings) &&
    /advanceEditTimes\(ensured, canonicalized\)/.test(settings) &&
    /ensureBuiltins\(storedProfiles, canonicalized\)/.test(settings) &&
    /HomeSubtabRepository\.saveChanges\([\s\S]*canonicalized[\s\S]*selectionChanged/.test(settings) &&
    /home_subtabs_canonicalized/.test(settings))
ok('builtin names are derived from current resources rather than persisted user text',
  /static displayName\(profile: NhHomeSubtabProfile\)/.test(settings) &&
    /Text\(HomeSubtabSettings\.displayName\(profile\)\)/.test(
      read('feature/home/src/main/ets/pages/HomeSubtabManagerPage.ets'),
    ))

const store = read('shared/src/main/ets/storage/LocalDataStore.ets')
const repository = read('shared/src/main/ets/storage/HomeSubtabRepository.ets')
ok('RDB v22 creates ordered profile and selected-profile tables',
  /SCHEMA_VERSION: number = 22/.test(store) &&
    /CREATE TABLE IF NOT EXISTS home_subtabs/.test(store) &&
    /CREATE TABLE IF NOT EXISTS home_subtab_selection/.test(store) &&
    /idx_home_subtabs_order/.test(store))
ok('profile writes and selected-profile writes use independent LWW clocks',
  /SQL_UPSERT[\s\S]*excluded\.last_edit_time >=/.test(repository) &&
    /SQL_UPSERT_SELECTION[\s\S]*excluded\.updated_at >=/.test(repository))
ok('unknown remote tombstones are persisted with an upsert and dominate older rows',
  /SQL_UPSERT_TOMBSTONE/.test(repository) &&
    /INSERT INTO home_subtabs/.test(repository) &&
    /excluded\.deleted_at >= CASE/.test(repository) &&
    /upsertTombstone\(store, record\.profile\.uuid, record\.deletedAt\)/.test(repository))

const retained = read('feature/home/src/main/ets/components/HomeSearchSubtabPage.ets')
ok('each retained search profile owns request generation, result, paging, scroller, cache and delayed first load',
  /requestGeneration/.test(retained) && /@Local galleries: NhGallerySummary\[\]/.test(retained) &&
    /@Local currentPage: number/.test(retained) && /@Param scroller: Scroller/.test(retained) &&
    /GalleryListCacheRepository/.test(retained) && /if \(!this\.isActive\(\)\)[\s\S]*return/.test(retained))
ok('stale responses are rejected by both generation and content revision',
  /generation === this\.requestGeneration && revision === this\.profileRevision\(\)/.test(retained) &&
    /if \(!this\.isCurrent\(generation, profile\.contentRevision\(\)\)\)/.test(retained))

const latestPage = read('feature/home/src/main/ets/pages/HomePage.ets')
const popularPage = read('feature/home/src/main/ets/pages/PopularPage.ets')
const historyPage = read('feature/user/src/main/ets/pages/HistoryPage.ets')
const collectionBody = read('shared/src/main/ets/components/GalleryCollectionBody.ets')
ok('every retained Home caller propagates page-one refreshing into the shared collection footer',
  /isRefreshing: this\.isRefreshing/.test(latestPage) &&
    /isRefreshing: this\.isRefreshing/.test(popularPage) &&
    /isRefreshing: this\.isRefreshing/.test(retained))
ok('shared collection and History use the same refreshing-aware footer projection',
  /CollectionFooterState\.canOfferMore/.test(collectionBody) &&
    /CollectionFooterState\.isComplete/.test(collectionBody) &&
    /CollectionFooterState\.idleText/.test(collectionBody) &&
    /CollectionFooterState\.canOfferMore/.test(historyPage) &&
    /CollectionFooterState\.isComplete/.test(historyPage))

const conditionParser = read('feature/search/src/main/ets/model/SearchConditionChip.ets')
const conditionInputs = read('feature/search/src/main/ets/components/SearchAdvancedConditionInputs.ets')
const subtabEditor = read('feature/search/src/main/ets/pages/HomeSubtabEditPage.ets')
ok('advanced range tokens hydrate direct fields and can be replaced without duplicate chips',
  /static range\(query: string, namespace: string\)/.test(conditionParser) &&
    /static removeNamespace\(query: string, namespace: string\)/.test(conditionParser) &&
    /SearchConditionParser\.range\(this\.activeQuery, 'favorites'\)/.test(conditionInputs) &&
    /SearchConditionParser\.isRangeToken\(chip\.rawToken\)/.test(conditionInputs))
ok('range inputs keep a local draft and commit only on submit or blur',
  /struct AdvancedRangeInput[\s\S]*@Local text: string = ''/.test(conditionInputs) &&
    /\.onChange\(\(value: string\): void => \{\s*this\.text = value\s*\}\)/.test(conditionInputs) &&
    /\.onSubmit\(\(\): void => \{\s*this\.commit\(\)/.test(conditionInputs) &&
    /\.onBlur\(\(\): void => \{\s*this\.commit\(\)/.test(conditionInputs))
ok('SubTab editor uses one local composer for translated tags and quoted raw conditions',
  /showLocalComposer: true/.test(subtabEditor) &&
    /onPlainAdd:[\s\S]*this\.appendPlainCondition/.test(subtabEditor) &&
    /onSuggestedTagAdd:[\s\S]*this\.appendSuggestedTag/.test(subtabEditor) &&
    /SearchConditionParser\.formatPlain\(text\)/.test(subtabEditor) &&
    /TagTranslationRepository\.suggestUnscoped/.test(conditionInputs))
ok('active conditions use indexed mutation, explicit relation and button-only removal callbacks',
  /static removeTokenAt\(query: string, tokenIndex: number\)/.test(conditionParser) &&
    /static setExcluded\(query: string, tokenIndex: number, excluded: boolean\)/.test(conditionParser) &&
    /onSetConditionExcluded/.test(conditionInputs) &&
    /ConditionActions\(chip\)/.test(conditionInputs) &&
    !/onAction:[\s\S]{0,80}this\.removeCondition\(chip\)/.test(conditionInputs))
ok('NH unsupported tilde is preserved as unknown instead of generated as OR',
  /if \(content\.startsWith\('~'\)\)/.test(conditionParser) &&
    /NH's public search contract does not implement/.test(conditionParser))

const backupTypes = read('shared/src/main/ets/backup/BackupTypes.ets')
const backupAdapter = read('shared/src/main/ets/backup/BackupLocalDataAdapter.ets')
ok('old backup compatibility treats a missing Home SubTab field as supported empty input',
  /homeSubtabs\?: BackupHomeSubtabSection/.test(backupTypes) &&
    /if \(section === undefined\)[\s\S]*return true/.test(backupAdapter))

const syncTypes = read('shared/src/main/ets/sync/SyncTypes.ets')
const syncAdapter = read('shared/src/main/ets/sync/SyncLocalDataAdapter.ets')
const webDav = read('shared/src/main/ets/sync/WebDavSyncService.ets')
const syncFeatures = read('shared/src/main/ets/sync/CloudSyncFeatures.ets')
const syncSettings = read('shared/src/main/ets/settings/SyncSettings.ets')
ok('Home SubTabs are a default-enabled independent sync dataset',
  /homeSubtabs: SyncHomeSubtabRecord\[\] = \[\]/.test(syncTypes) &&
    /homeSubtabs: boolean = true/.test(syncTypes) &&
    /datasetHomeSubtabs: boolean = true/.test(syncSettings) &&
    /KEY_DATASET_HOME_SUBTABS/.test(syncSettings))
ok('old sync envelopes normalize a missing dataset to empty',
  /!Array\.isArray\(data\.homeSubtabs\)[\s\S]*data\.homeSubtabs = \[\]/.test(syncAdapter))
ok('sync roundtrip covers export, LWW merge, apply, shard selection and manifest accounting',
  /readHomeSubtabs\(context\)/.test(syncAdapter) &&
    /mergeHomeSubtabs\(local\.datasets\.homeSubtabs, remote\.datasets\.homeSubtabs\)/.test(syncAdapter) &&
    /applyHomeSubtabs\(context, envelope\.datasets\.homeSubtabs\)/.test(syncAdapter) &&
    /DATASET_HOME_SUBTABS/.test(webDav) && /datasets\.homeSubtabs\.push\(r\)/.test(webDav))
ok('active Home SubTab remains local and legacy cloud selection records are discarded',
  /static async loadSelection\(context/.test(repository) &&
    /saveSelectionWithStore\(store, selectedUuid\)/.test(repository) &&
    !/const selection: HomeSubtabSelectionRecord = await HomeSubtabRepository\.loadSelection/.test(syncAdapter) &&
    !/selection\.selectedUuid = r\.selectedUuid/.test(syncAdapter) &&
    /if \(r\.profileUuid === HOME_SUBTAB_SELECTION_RECORD\) \{[\s\S]*?return/.test(syncAdapter) &&
    /HOME_SUBTABS: string\[\] = \['home_subtabs'\]/.test(syncFeatures) &&
    !syncFeatures.includes("'home_subtab_selection'"))
ok('dataset-specific WebDAV apply cannot replace unselected local datasets with empty arrays',
  /selection: SyncDatasetSelection = new SyncDatasetSelection\(\)/.test(syncAdapter) &&
    /if \(selection\.homeSubtabs\)[\s\S]*applyHomeSubtabs/.test(syncAdapter) &&
    /applyEnvelope\(context, selectedMerged, selection\)/.test(read('shared/src/main/ets/sync/SyncService.ets')))

// Executable LWW sanity check mirrors the repository boundary: a later tombstone wins and an older
// profile cannot resurrect it; a newer edit can intentionally recreate the same stable UUID.
function mergeClock(local, remote) {
  const localClock = Math.max(local.updatedAt, local.deletedAt)
  const remoteClock = Math.max(remote.updatedAt, remote.deletedAt)
  return remoteClock >= localClock ? remote : local
}
const live = { updatedAt: 100, deletedAt: 0 }
const tombstone = { updatedAt: 0, deletedAt: 200 }
ok('LWW behavior keeps the newer tombstone over a stale profile', mergeClock(live, tombstone) === tombstone)
const recreated = { updatedAt: 300, deletedAt: 0 }
ok('LWW behavior permits an explicitly newer profile to supersede a tombstone', mergeClock(tombstone, recreated) === recreated)

if (failures === 0) {
  console.log('OK Home SubTab data contract passed')
  process.exit(0)
}
console.error(`[FAIL] Home SubTab data contract: ${failures} failure(s)`)
process.exit(1)
