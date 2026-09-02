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
const editor = read('shared/src/main/ets/components/LocalUserTagEditorSheet.ets')
const inlineEditor = read('shared/src/main/ets/components/NextNInlineEditRow.ets')
const listRow = read('shared/src/main/ets/components/NextNListRow.ets')
const subtabEditor = read('feature/search/src/main/ets/pages/HomeSubtabEditPage.ets')
const entryShell = read('entry/src/main/ets/pages/Index.ets')
ok('add local tag remains a NextE-style destination title action instead of a list row',
  /private localUserTagsTitleBar\(\): Record<string, Object>/.test(entryShell) &&
    /'label': AppStrings\.get\('local_user_tag_add'\)[\s\S]*?'icon': \$r\('sys\.symbol\.plus'\)/.test(entryShell) &&
    !/private TagsGroup\(\)[\s\S]*?title: AppStrings\.get\('local_user_tag_add'\)/.test(manager))
ok('selecting a catalog suggestion survives the TextInput programmatic echo',
  /if \(this\.draftTagId > 0 && value\.trim\(\) === selectedQuery\) \{[\s\S]*?return[\s\S]*?this\.draftTagId = 0/.test(manager) &&
    /this\.draftTagId = suggestion\.tagId[\s\S]*this\.draftNamespace = suggestion\.namespace[\s\S]*this\.draftName = suggestion\.rawName/.test(manager))
ok('all local-tag option rows reuse the shared list-row family',
  !/DraftSwitchRow|Toggle\(|TextInput\(/.test(editor) &&
    !/DraftSwitchRow|Toggle\(|TextInput\(/.test(manager) &&
    /NextNListRow\(\{[\s\S]*?hasSwitch: true/.test(editor) &&
    /NextNInlineEditRow\(\{[\s\S]*?title: AppStrings\.get\('local_user_tag_weight'\)/.test(editor) &&
    /NextNInlineEditRow\(\{[\s\S]*?title: AppStrings\.get\('local_user_tag_weight'\)/.test(manager))
ok('local weights accept signed safe integers without a product range or explanatory subtitle',
  !/NH_LOCAL_USER_TAG_(MIN|MAX)_WEIGHT/.test(read('shared/src/main/ets/model/NhLocalUserTag.ets')) &&
    /Number\.isSafeInteger\(parsed\) \? parsed : null/.test(editor) &&
    /Number\.isSafeInteger\(parsed\) \? parsed : null/.test(manager) &&
    !/local_user_tag_weight_desc/.test(editor) &&
    !/local_user_tag_weight_desc/.test(manager))
ok('the Subtab inline editor is shared and keeps the established transparent field',
  /NextNInlineEditRow\(\{/.test(subtabEditor) &&
    !/struct HomeSubtabInlineEditRow/.test(subtabEditor) &&
    /NextNListRow\(\{[\s\S]*?useCustomTrailing: true/.test(inlineEditor) &&
    /\.backgroundColor\(Color\.Transparent\)/.test(inlineEditor))
ok('the shared list row owns one nonzero right inset for every suffix',
  /cardSuffixMargin: this\.suffixPaddingRight/.test(listRow) &&
    !/cardSuffixMargin: 0/.test(listRow))
ok('saved tag rows replace stale ForEach closures after a local-tag revision',
  /@Local displayedTags: NhLocalUserTag\[\]/.test(manager) &&
    /onLocalUserTagsChanged\(\): void \{[\s\S]*?this\.refreshDisplayedTags\(\)/.test(manager) &&
    /local_tag_\$\{this\.localUserTags\.revision\}/.test(manager))
ok('saving closes the sheet before the local-tag mutation publishes a list revision',
  /this\.pendingTagSave = record[\s\S]*?this\.closeSheet\(\)/.test(manager) &&
    /onDisappear: \(\): void => \{[\s\S]*?this\.finishCloseSheet\(\)/.test(manager) &&
    /private finishCloseSheet\(\): void \{[\s\S]*?this\.commitPendingMutation\(\)/.test(manager) &&
    /onSaveRequested: \(updated: NhLocalUserTag\)/.test(manager))

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
const storageStrings = read('entry/src/main/resources/zh_CN/element/string.json')
ok('WebDAV application-settings sync is removed while legacy remote data stays parseable',
  /selection\.settingsTables = false/.test(syncSettings) &&
    /snapshot\.datasetSettingsTables = false/.test(syncSettings) &&
    /settingsTables: boolean = false/.test(syncTypes) &&
    !/DATASET_LOCAL_BLOCK,\s*DATASET_SETTINGS_TABLES,/.test(sync) &&
    /if \(datasetId === DATASET_SETTINGS_TABLES\) \{\s*return false\s*\}/.test(sync) &&
    !/sync_dataset_settings_tables/.test(syncPage) &&
    !/'settingsTables'/.test(syncPage) &&
    !/"settings_sync_hint"[^\n]*应用设置/.test(storageStrings))

if (failures === 0) {
  console.log('OK local user tags contract passed')
  process.exit(0)
}
console.error(`[FAIL] local user tags contract: ${failures} failure(s)`)
process.exit(1)
