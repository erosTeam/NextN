#!/usr/bin/env node
// Real-call verification for the NextN built-in Home SubTab name fix.
// Loads the ACTUAL post-fix ArkTS modules (types stripped) against an isolated
// in-memory SQLite, then drives HomeSubtabSettings/HomeSubtabRepository and
// SyncLocalDataAdapter.applyEnvelope directly. Not a re-implementation.
const fs = require('node:fs')
const vm = require('node:vm')
const assert = require('node:assert/strict')
const { stripTypeScriptTypes } = require('node:module')
const { DatabaseSync } = require('node:sqlite')

const path = require('node:path')
const product = path.resolve(__dirname, '..')
const read = (p) => fs.readFileSync(path.join(product, p), 'utf8')
const clean = (s) => s
  .replace(/^import\s[\s\S]*?\sfrom\s+['"][^'"]+['"];?\s*$/gm, '')
  .replace(/^\s*@(ObservedV2|Observed|Trace|Local|Param|Event|Builder|BuilderParam|Computed|Provider|Consumer|Require|State|Prop|Link|Provide|Consume)\b/gm, '')
  .replace(/\s@(Trace|Local|Param|Event|ObservedV2|Observed|Builder|BuilderParam|Computed|Require)\b/g, '')
  .replace(/^export\s+/gm, '')

function sqlConst(name) {
  const text = read('shared/src/main/ets/storage/LocalDataStore.ets')
  const start = text.indexOf('const ' + name + ': string =')
  assert(start >= 0, 'missing ' + name)
  const match = /\n(?:const |export class |class )/.exec(text.slice(start + 1))
  const slice = text.slice(start, match ? start + 1 + match.index : undefined)
  return vm.runInNewContext(stripTypeScriptTypes(slice + '\n' + name, { mode: 'transform' }))
}

function setup() {
  const db = new DatabaseSync(':memory:')
  db.exec(sqlConst('SQL_CREATE_HOME_SUBTABS'))
  db.exec(sqlConst('SQL_CREATE_HOME_SUBTAB_SELECTION'))
  const store = {
    beginTransaction() { db.exec('BEGIN') },
    commit() { db.exec('COMMIT') },
    rollBack() { db.exec('ROLLBACK') },
    async executeSql(sql, args) { db.prepare(sql).run(...args) },
    async querySql(sql, args) {
      const st = db.prepare(sql), rows = st.all(...args), cols = st.columns().map((c) => c.name)
      let i = -1
      return {
        goToNextRow() { return ++i < rows.length },
        getColumnIndex(n) { const idx = cols.indexOf(n); assert(idx >= 0, n); return idx },
        isColumnNull(j) { return rows[i][cols[j]] == null },
        getString(j) { return String(rows[i][cols[j]]) },
        getDouble(j) { return Number(rows[i][cols[j]]) },
        close() {},
      }
    },
  }
  const state = { profiles: [], selectedUuid: '', restored: false,
    find(uuid) { return this.profiles.find((p) => p.uuid === uuid) ?? null } }
  const source = { selectedKey: 'latest', presentationOverrideFor() { return null } }
  const sync = []
  const warnings = []
  const ctx = {
    LocalDataStore: { async open() { return store } },
    connectHomeSubtabs: () => state,
    connectHomeSource: () => source,
    HOME_SOURCE_POPULAR: 'popular',
    connectLanguageState: () => ({ effectiveLocale: 'zh-CN' }),
    AppStorageV2: { connect: (_c, _k, factory) => factory() },
    util: { TextEncoder: class { encodeInto(s) { return new TextEncoder().encode(s) } } },
    relationStore: {},
    DiagnosticLogger: { info() {}, warn(...a) { warnings.push(a) } },
    SyncScheduler: { requestAfterLocalWrite(_c, r) { sync.push(r) } },
    SearchConditionParser: {},
  }
  vm.createContext(ctx)
  const files = [
    'model/NhBrowsePresentation', 'model/NhSearchOptions', 'model/NhHomeSubtabProfile',
    'i18n/AppStrings', 'settings/HomeSubtabNames', 'state/HomeSubtabState', 'state/HomeSourceState',
    'storage/HomeSubtabRepository', 'settings/HomeSubtabSettings',
  ]
  for (const p of files) {
    const source2 = read('shared/src/main/ets/' + p + '.ets')
    const names = [...source2.matchAll(/^export\s+(?:class|const|function|enum)\s+(\w+)/gm)].map((m) => m[1])
    Object.assign(ctx, vm.runInContext('(function(){' + stripTypeScriptTypes(clean(source2), { mode: 'transform' }) + '\nreturn {' + names.join(',') + '};})()', ctx))
  }
  const labels = { home_source_latest: '最新', home_source_popular: '热门',
    home_subtab_starter_chinese: '中文', home_subtab_starter_favorited: '收藏 K' }
  const init = (ready = true) => {
    ctx.AppStrings.init({ resourceManager: { getStringByNameSync: (k) => (ready ? (labels[k] ?? k) : k) } })
  }
  return { ctx, db, state, source, sync, warnings, init, labels }
}

const rows = (f) => f.db.prepare('SELECT * FROM home_subtabs ORDER BY position_index, profile_uuid').all().map((r) => ({ ...r }))
const byUuid = (f, uuid) => rows(f).find((r) => r.profile_uuid === uuid)
const count = (f) => f.db.prepare('SELECT COUNT(*) AS n FROM home_subtabs').get().n
const setRow = (f, uuid, name, clock) => f.db.prepare('UPDATE home_subtabs SET name=?, last_edit_time=? WHERE profile_uuid=?').run(name, clock, uuid)

const passed = [];
(async () => {
  // 1. Resources not ready at first seed must not persist blank or key names.
  let f = setup()
  f.init(false)
  await f.ctx.HomeSubtabSettings.restore({})
  assert.equal(count(f), 0, 'no rows while resources are unresolved')
  passed.push('Unresolved resources: first seed persists nothing (no blank/key placeholder)')

  // 2. Once resources are ready, the same process seeds real labels.
  f.init(true)
  await f.ctx.HomeSubtabSettings.restore({})
  const seeded = rows(f)
  assert.equal(seeded.length, 4)
  const latest = byUuid(f, 'builtin-latest')
  assert.equal(latest.name, '最新')
  assert.equal(byUuid(f, 'builtin-popular').name, '热门')
  assert(seeded.every((r) => !r.name.startsWith('home_source_') && !r.name.startsWith('home_subtab_')))
  passed.push('Resource becomes ready: retry seeds real localized labels')

  // 3. An existing custom row with an empty name must not block restore persistence.
  f = setup()
  f.init(true)
  await f.ctx.HomeSubtabSettings.restore({})
  f.db.prepare("INSERT INTO home_subtabs (scope_key,profile_uuid,position_index,kind,name,query_text,language,sort,ignore_local_user_tag_filtering,display_mode,hidden,last_edit_time,deleted_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,0)")
    .run('global', 'custom-empty', 9, 'search', '', 'q', 'ALL', 'RECENT', 0, 'global', 0, 5)
  setRow(f, 'builtin-popular', 'home_source_popular', 7)
  await f.ctx.HomeSubtabSettings.restore({})
  assert.equal(byUuid(f, 'builtin-popular').name, '热门', 'builtin key row repaired')
  assert.equal(byUuid(f, 'custom-empty').name, '', 'custom empty name untouched')
  passed.push('A pre-existing custom empty name does not block restore; the reserved key row is repaired')

  // 4. Repair is idempotent and only the reserved key row changes.
  const before2 = rows(f).filter((r) => r.profile_uuid !== 'builtin-popular')
  await f.ctx.HomeSubtabSettings.restore({})
  const after2 = rows(f).filter((r) => r.profile_uuid !== 'builtin-popular')
  assert.deepEqual(after2, before2)
  passed.push('Repeat restore leaves unrelated rows byte-identical')

  // 5. A reserved key write is refused by the repository guard.
  f = setup()
  f.init(true)
  await f.ctx.HomeSubtabSettings.restore({})
  const tableBefore = rows(f)
  const profiles = await f.ctx.HomeSubtabRepository.loadProfiles({})
  profiles[0].name = 'home_source_latest'
  await assert.rejects(() => f.ctx.HomeSubtabRepository.replaceAll({}, profiles, 'builtin-latest'))
  assert.deepEqual(rows(f), tableBefore)
  passed.push('Repository refuses to persist a raw reserved key (whole write rolls back)')

  // 6. Existing polluted local row is repaired on restore with a clock that beats the merge.
  f = setup()
  f.init(true)
  await f.ctx.HomeSubtabSettings.restore({})
  setRow(f, 'builtin-popular', 'home_source_popular', 1000)
  await f.ctx.HomeSubtabSettings.restore({})
  const repaired = byUuid(f, 'builtin-popular')
  assert.equal(repaired.name, '热门')
  assert(repaired.last_edit_time > 1000)
  passed.push('Restore repairs an existing polluted reserved row and advances its clock')

  await f.ctx.HomeSubtabSettings.restore({})
  const stable = byUuid(f, 'builtin-popular')
  await f.ctx.HomeSubtabSettings.restore({})
  assert.deepEqual(byUuid(f, 'builtin-popular'), stable)
  passed.push('Repair is idempotent (second restore changes nothing)')

  // 7. A newer valid local builtin rename must not be overwritten by an obsolete polluted remote.
  setRow(f, 'builtin-popular', '我的热门', 2000)
  const rec = (uuid, name, time, deletedAt = 0) => {
    const r = new f.ctx.HomeSubtabStorageRecord()
    r.positionIndex = 1
    r.deletedAt = deletedAt
    r.profile.uuid = uuid
    r.profile.kind = 'popular'
    r.profile.name = name
    r.profile.query = ''
    r.profile.language = 'ALL'
    r.profile.sort = 'RECENT'
    r.profile.presentation = 'global'
    r.profile.hidden = false
    r.profile.lastEditTime = time
    return r
  }
  await f.ctx.HomeSubtabRepository.importRecords({}, [rec('builtin-popular', 'home_source_popular', 100)])
  let current = byUuid(f, 'builtin-popular')
  assert.equal(current.name, '我的热门', 'newer custom builtin name preserved')
  assert.equal(current.last_edit_time, 2000)
  passed.push('Obsolete polluted remote cannot override a newer custom builtin name')

  // 8. An accepted (newer) polluted remote is repaired inside the same transaction.
  const future = Date.now() + 100000
  await f.ctx.HomeSubtabRepository.importRecords({}, [rec('builtin-popular', 'home_source_popular', future)])
  current = byUuid(f, 'builtin-popular')
  assert.equal(current.name, '热门', 'inbound key name normalized on apply')
  assert.equal(current.last_edit_time, future, 'inbound apply keeps the conflict clock (does not pre-bump)')
  passed.push('Accepted polluted remote is normalized on import while keeping the conflict clock')

  // 9. A remote tombstone is not resurrected by the repair pass.
  await f.ctx.HomeSubtabRepository.importRecords({}, [rec('builtin-popular', 'home_source_popular', future + 10, future + 20)])
  current = byUuid(f, 'builtin-popular')
  assert.equal(current.deleted_at, future + 20)
  passed.push('A remote tombstone stays deleted and is not repaired/resurrected')

  // 10. A remote reserved key row whose resource is not ready is skipped, not stored as a key,
  //     and does not block other rows; a later ready pass reconciles it.
  f = setup()
  f.init(true)
  await f.ctx.HomeSubtabSettings.restore({})
  const beforeKey = byUuid(f, 'builtin-popular').name
  f.ctx.AppStrings.context = null
  await f.ctx.HomeSubtabRepository.importRecords({}, [
    rec('builtin-popular', 'home_source_popular', future + 30),
    rec('custom-2', '我的自定义', future + 31),
  ])
  assert.equal(byUuid(f, 'builtin-popular').name, beforeKey, 'unresolved remote key row skipped, good value kept')
  assert.equal(byUuid(f, 'custom-2').name, '我的自定义', 'other rows still applied')
  passed.push('Unresolved remote reserved row is skipped without blocking other records')
  f.init(true)
  await f.ctx.HomeSubtabSettings.restore({})
  assert.equal(byUuid(f, 'builtin-popular').name, '热门')
  passed.push('After resources recover, a later restore reconciles the reserved name')

  const result = { status: 'PASS', scope: 'Actual ArkTS modules (types stripped) driven against isolated in-memory SQLite; platform APIs are fixtures. Not an ArkTS build or device run.', passed }
  const outDir = path.join(product, '.hvigor', 'outputs', 'home-subtab-name-verify'); fs.mkdirSync(outDir, { recursive: true })
  fs.writeFileSync(path.join(outDir, 'verification.json'), JSON.stringify(result, null, 2) + '\n')
  console.log(JSON.stringify(result, null, 2))
})().catch((e) => { console.error(e); process.exitCode = 1 })
