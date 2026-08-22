#!/usr/bin/env node
import fs from 'node:fs'

const read = (path) => fs.readFileSync(new URL(`../${path}`, import.meta.url), 'utf8')
let failures = 0

function ok(name, condition) {
  if (!condition) {
    console.error(`[FAIL] ${name}`)
    failures += 1
  }
}

const flag = read('shared/src/main/ets/safe/SafeModeBuildFlag.ets')
ok('normal source default keeps safe mode disabled',
  flag.includes('SAFE_MODE_BUILD_ENABLED: boolean = false'))

const build = read('scripts/build-hvigor-signed.sh')
ok('signed build exposes a temporary NEXTN_SAFE_MODE flag',
  build.includes('NEXTN_SAFE_MODE') &&
    build.includes('SAFE_MODE_BUILD_ENABLED: boolean = true') &&
    build.includes('trap restore_safe_flag EXIT'))

const state = read('shared/src/main/ets/state/SafeModeState.ets')
ok('restricted state requires a safe build that has not been unlocked',
  /return this\.buildEnabled && !this\.unlocked/.test(state))

const settings = read('shared/src/main/ets/settings/SafeModeSettings.ets')
ok('unlock state is restored from a default-false device-local preference',
  /getSync\(SAFE_MODE_UNLOCKED_KEY, false\)/.test(settings) &&
    /state\.buildEnabled = SAFE_MODE_BUILD_ENABLED/.test(settings) &&
    /state\.unlocked = SAFE_MODE_BUILD_ENABLED && unlocked/.test(settings))

const gate = read('shared/src/main/ets/safe/SafeModeGate.ets')
for (const blocked of [
  'search',
  'homeSubtabManager',
  'galleryWeb',
  'comments',
  'browserSession',
  'account',
  'syncSettings',
  'history',
]) {
  ok(`route gate blocks ${blocked}`, gate.includes(`name === '${blocked}'`))
}

const entry = read('entry/src/main/ets/entryability/EntryAbility.ets')
ok('ability restores safe mode before first content mount',
  entry.indexOf('SafeModeSettings.restore(this.context)') >= 0 &&
    entry.indexOf('SafeModeSettings.restore(this.context)') < entry.indexOf('windowStage.loadContent'))
ok('ability rejects external launch and clipboard entry points while restricted',
  /onNewWant[\s\S]*connectSafeMode\(\)\.restricted\(\)/.test(entry) &&
    /CLIPBOARD_LINK_BUILD_ENABLED \|\| connectSafeMode\(\)\.restricted\(\)/.test(entry))

const index = read('entry/src/main/ets/pages/Index.ets')
ok('restricted root projects Browse, Downloads, and Settings only',
  /return this\.safeMode\.restricted\(\) \? 3 : 4/.test(index) &&
    /if \(!this\.safeMode\.restricted\(\)\) \{[\s\S]*FavoritesPage/.test(index))
ok('static router map enforces the route gate',
  /if \(!SafeModeGate\.routeAllowed\(name\)\)/.test(index))

const home = read('feature/home/src/main/ets/pages/HomePage.ets')
ok('restricted Browse does not mount the retained NH request owner',
  /if \(this\.safeMode\.restricted\(\)\)[\s\S]*safe_mode_browse_message[\s\S]*else[\s\S]*RetainedSubtabHost/.test(home))

const about = read('feature/settings/src/main/ets/pages/AboutPage.ets')
ok('About version has a persisted five-tap lock toggle',
  /safeModeTapCount < 5/.test(about) &&
    /SafeModeSettings\.lock/.test(about) &&
    /SafeModeSettings\.unlock/.test(about))

const backup = read('shared/src/main/ets/backup/BackupPreferencesAdapter.ets')
ok('device-local unlock marker is excluded from backup',
  backup.includes("'nextn_settings.safeMode.unlocked'"))

for (const locale of ['base', 'zh_CN', 'en_US', 'ja_JP']) {
  const strings = JSON.parse(read(`entry/src/main/resources/${locale}/element/string.json`))
  const keys = new Set(strings.string.map((item) => item.name))
  ok(`${locale} contains all safe-mode messages`,
    keys.has('safe_mode_unlocked') &&
      keys.has('safe_mode_locked') &&
      keys.has('safe_mode_browse_message'))
}

if (failures > 0) {
  process.exit(1)
}
console.log('OK safe mode contract passed')
