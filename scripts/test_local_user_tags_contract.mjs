#!/usr/bin/env node
/** Static integration guard for the local-user-tag ownership and UI wiring. */
import fs from 'fs'

const read = (path) => fs.readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
let failures = 0
function ok(name, condition) {
  if (!condition) {
    console.error(`[FAIL] ${name}`)
    failures += 1
  }
}

const manager = read('feature/settings/src/main/ets/pages/LocalUserTagsPage.ets')
ok('selecting a catalog suggestion survives the TextInput programmatic echo',
  /if \(this\.draftTagId > 0 && value\.trim\(\) === selectedQuery\) \{[\s\S]*?return[\s\S]*?this\.draftTagId = 0/.test(manager) &&
    /this\.draftTagId = suggestion\.tagId[\s\S]*this\.draftNamespace = suggestion\.namespace[\s\S]*this\.draftName = suggestion\.rawName/.test(manager))
ok('editor draft switches have one mutation path so a switch tap cannot be applied twice',
  /private DraftSwitchRow\([\s\S]*?onSwitchChange: \(value: boolean\): void => onChange\(value\),[\s\S]*?\n      \}\)[\s\S]*?\n  \}/.test(manager) &&
    !/private DraftSwitchRow\([\s\S]*?onAction: \(\): void => onChange\(!checked\)[\s\S]*?\n  \}/.test(manager))

const rules = read('shared/src/main/ets/services/NhLocalUserTagRules.ets')
ok('soft filtering sums every unique matched weight and uses strict threshold comparison',
  /seen\.has\(tagId\)/.test(rules) &&
    /result\.score \+= NhLocalUserTagContract\.normalizeWeight\(record\.weight\)/.test(rules) &&
    /result\.filtered = result\.hiddenMatched \|\| result\.score < threshold/.test(rules))
ok('explicit Hidden remains an independent unconditional rule',
  /if \(record\.hidden\) \{[\s\S]*?result\.hiddenMatched = true/.test(rules))

const sync = read('shared/src/main/ets/sync/WebDavSyncService.ets')
ok('WebDAV keeps local user tags as an independent dataset',
  /DATASET_LOCAL_USER_TAGS: string = 'local-user-tags'/.test(sync) &&
    /out\.localUserTags = datasetId === DATASET_LOCAL_USER_TAGS/.test(sync))

const syncSettings = read('shared/src/main/ets/settings/SyncSettings.ets')
const syncTypes = read('shared/src/main/ets/sync/SyncTypes.ets')
const syncPage = read('feature/settings/src/main/ets/pages/SyncSettingsPage.ets')
ok('WebDAV application-settings sync is removed while legacy remote data stays parseable',
  /selection\.settingsTables = false/.test(syncSettings) &&
    /snapshot\.datasetSettingsTables = false/.test(syncSettings) &&
    /settingsTables: boolean = false/.test(syncTypes) &&
    !/DATASET_LOCAL_BLOCK,\s*DATASET_SETTINGS_TABLES,/.test(sync) &&
    /if \(datasetId === DATASET_SETTINGS_TABLES\) \{\s*return false\s*\}/.test(sync) &&
    !/sync_dataset_settings_tables/.test(syncPage) &&
    !/'settingsTables'/.test(syncPage))

if (failures === 0) {
  console.log('OK local user tags contract passed')
  process.exit(0)
}
console.error(`[FAIL] local user tags contract: ${failures} failure(s)`)
process.exit(1)
