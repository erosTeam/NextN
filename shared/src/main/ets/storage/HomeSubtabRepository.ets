import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import {
  HOME_SUBTAB_PRESENTATION_GLOBAL,
  NhHomeSubtabKind,
  NhHomeSubtabProfile,
} from '../model/NhHomeSubtabProfile'
import { LocalDataStore } from './LocalDataStore'
import { HomeSubtabNames } from '../settings/HomeSubtabNames'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

const SCOPE_GLOBAL: string = 'global'
const SQL_HAS_PROFILES: string = 'SELECT 1 AS has_state FROM home_subtabs WHERE scope_key = ? LIMIT 1'
const SQL_HAS_SELECTION: string = 'SELECT 1 AS has_state FROM home_subtab_selection WHERE scope_key = ? LIMIT 1'
const SQL_SELECT_ACTIVE: string =
  'SELECT profile_uuid, position_index, kind, name, query_text, language, sort, ' +
  'ignore_local_user_tag_filtering, display_mode, hidden, ' +
  'last_edit_time, deleted_at FROM home_subtabs WHERE scope_key = ? AND COALESCE(deleted_at, 0) = 0 ' +
  'ORDER BY position_index ASC, profile_uuid ASC'
const SQL_SELECT_ALL: string =
  'SELECT profile_uuid, position_index, kind, name, query_text, language, sort, ' +
  'ignore_local_user_tag_filtering, display_mode, hidden, ' +
  'last_edit_time, deleted_at FROM home_subtabs WHERE scope_key = ? ORDER BY profile_uuid ASC'
const SQL_SELECT_ONE_CLOCK: string =
  'SELECT last_edit_time, deleted_at FROM home_subtabs WHERE scope_key = ? AND profile_uuid = ? LIMIT 1'
const SQL_UPSERT: string =
  'INSERT INTO home_subtabs (scope_key, profile_uuid, position_index, kind, name, query_text, language, sort, ' +
  'ignore_local_user_tag_filtering, display_mode, hidden, last_edit_time, deleted_at) ' +
  'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0) ' +
  'ON CONFLICT(scope_key, profile_uuid) DO UPDATE SET position_index = excluded.position_index, ' +
  'kind = excluded.kind, name = excluded.name, query_text = excluded.query_text, language = excluded.language, ' +
  'sort = excluded.sort, ignore_local_user_tag_filtering = excluded.ignore_local_user_tag_filtering, ' +
  'display_mode = excluded.display_mode, hidden = excluded.hidden, ' +
  'last_edit_time = excluded.last_edit_time, deleted_at = 0 WHERE excluded.last_edit_time >= ' +
  'CASE WHEN COALESCE(home_subtabs.deleted_at, 0) > COALESCE(home_subtabs.last_edit_time, 0) ' +
  'THEN COALESCE(home_subtabs.deleted_at, 0) ELSE COALESCE(home_subtabs.last_edit_time, 0) END'
const SQL_UPSERT_TOMBSTONE: string =
  'INSERT INTO home_subtabs (scope_key, profile_uuid, position_index, kind, name, query_text, language, sort, ' +
  'ignore_local_user_tag_filtering, display_mode, hidden, last_edit_time, deleted_at) ' +
  'VALUES (?, ?, 0, ?, ?, ?, ?, ?, 0, ?, 1, 0, ?) ' +
  'ON CONFLICT(scope_key, profile_uuid) DO UPDATE SET deleted_at = excluded.deleted_at WHERE ' +
  'excluded.deleted_at >= CASE WHEN COALESCE(home_subtabs.deleted_at, 0) > ' +
  'COALESCE(home_subtabs.last_edit_time, 0) THEN COALESCE(home_subtabs.deleted_at, 0) ' +
  'ELSE COALESCE(home_subtabs.last_edit_time, 0) END'
const SQL_TOMBSTONE_ALL: string =
  'UPDATE home_subtabs SET deleted_at = CASE WHEN COALESCE(last_edit_time, 0) >= ? ' +
  'THEN COALESCE(last_edit_time, 0) + 1 ELSE ? END WHERE scope_key = ? AND COALESCE(deleted_at, 0) = 0'
const SQL_SELECT_SELECTION: string =
  'SELECT selected_uuid, updated_at, deleted_at FROM home_subtab_selection WHERE scope_key = ? LIMIT 1'
const SQL_UPSERT_SELECTION: string =
  'INSERT INTO home_subtab_selection (scope_key, selected_uuid, updated_at, deleted_at) VALUES (?, ?, ?, 0) ' +
  'ON CONFLICT(scope_key) DO UPDATE SET selected_uuid = excluded.selected_uuid, updated_at = excluded.updated_at, ' +
  'deleted_at = 0 WHERE excluded.updated_at >= CASE WHEN COALESCE(home_subtab_selection.deleted_at, 0) > ' +
  'COALESCE(home_subtab_selection.updated_at, 0) THEN COALESCE(home_subtab_selection.deleted_at, 0) ' +
  'ELSE COALESCE(home_subtab_selection.updated_at, 0) END'

export class HomeSubtabStorageRecord {
  profile: NhHomeSubtabProfile = new NhHomeSubtabProfile()
  positionIndex: number = 0
  deletedAt: number = 0
}

export class HomeSubtabSelectionRecord {
  selectedUuid: string = ''
  updatedAt: number = 0
  deletedAt: number = 0
}

class HomeSubtabClock {
  lastEditTime: number = 0
  deletedAt: number = 0
}

export class HomeSubtabRepository {
  static async hasPersistedState(context: common.UIAbilityContext): Promise<boolean> {
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    let rows: relationalStore.ResultSet | null = null
    try {
      rows = await store.querySql(SQL_HAS_PROFILES, [SCOPE_GLOBAL])
      if (rows.goToNextRow()) {
        return true
      }
    } finally {
      if (rows !== null) {
        rows.close()
      }
    }
    try {
      rows = await store.querySql(SQL_HAS_SELECTION, [SCOPE_GLOBAL])
      return rows.goToNextRow()
    } finally {
      if (rows !== null) {
        rows.close()
      }
    }
  }

  static async loadProfiles(context: common.UIAbilityContext): Promise<NhHomeSubtabProfile[]> {
    const records: HomeSubtabStorageRecord[] = await HomeSubtabRepository.readRecords(context, false)
    const profiles: NhHomeSubtabProfile[] = []
    records.forEach((record: HomeSubtabStorageRecord): void => {
      profiles.push(record.profile)
    })
    return profiles
  }

  static exportRecords(context: common.UIAbilityContext): Promise<HomeSubtabStorageRecord[]> {
    return HomeSubtabRepository.readRecords(context, true)
  }

  static async loadSelection(context: common.UIAbilityContext): Promise<HomeSubtabSelectionRecord> {
    const result: HomeSubtabSelectionRecord = new HomeSubtabSelectionRecord()
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const rows: relationalStore.ResultSet = await store.querySql(SQL_SELECT_SELECTION, [SCOPE_GLOBAL])
    try {
      if (rows.goToNextRow()) {
        result.selectedUuid = HomeSubtabRepository.stringColumn(rows, 'selected_uuid')
        result.updatedAt = Math.floor(HomeSubtabRepository.numberColumn(rows, 'updated_at'))
        result.deletedAt = Math.floor(HomeSubtabRepository.numberColumn(rows, 'deleted_at'))
      }
    } finally {
      rows.close()
    }
    return result
  }

  static async saveChanges(
    context: common.UIAbilityContext,
    profiles: NhHomeSubtabProfile[],
    changedUuids: string[],
    selectedUuid: string,
    deletedUuid: string = '',
    selectionChanged: boolean = false,
  ): Promise<void> {
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    store.beginTransaction()
    try {
      for (let changedIndex: number = 0; changedIndex < changedUuids.length; changedIndex++) {
        const uuid: string = changedUuids[changedIndex]
        if (uuid.length === 0 || changedUuids.indexOf(uuid) !== changedIndex) {
          continue
        }
        const profileIndex: number = HomeSubtabRepository.profileIndex(profiles, uuid)
        if (profileIndex < 0) {
          continue
        }
        await HomeSubtabRepository.upsert(store, profiles[profileIndex], profileIndex)
      }
      if (deletedUuid.length > 0) {
        await HomeSubtabRepository.tombstone(store, deletedUuid)
      }
      if (selectionChanged) {
        await HomeSubtabRepository.saveSelectionWithStore(store, selectedUuid)
      }
      store.commit()
    } catch (error) {
      store.rollBack()
      throw error as Error
    }
  }

  static async replaceAll(
    context: common.UIAbilityContext,
    profiles: NhHomeSubtabProfile[],
    selectedUuid: string,
  ): Promise<void> {
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    store.beginTransaction()
    try {
      const now: number = Date.now()
      await store.executeSql(SQL_TOMBSTONE_ALL, [now, now, SCOPE_GLOBAL])
      for (let index: number = 0; index < profiles.length; index++) {
        const profile: NhHomeSubtabProfile = profiles[index]
        profile.lastEditTime = await HomeSubtabRepository.nextClock(store, profile.uuid, profile.lastEditTime)
        await HomeSubtabRepository.upsert(store, profile, index)
      }
      await HomeSubtabRepository.saveSelectionWithStore(store, selectedUuid)
      store.commit()
    } catch (error) {
      store.rollBack()
      throw error as Error
    }
  }

  static async importRecords(
    context: common.UIAbilityContext,
    records: HomeSubtabStorageRecord[],
  ): Promise<void> {
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    store.beginTransaction()
    try {
      for (let index: number = 0; index < records.length; index++) {
        const record: HomeSubtabStorageRecord = records[index]
        if (record.profile.uuid.length === 0) {
          continue
        }
        if (record.deletedAt > record.profile.lastEditTime) {
          await HomeSubtabRepository.upsertTombstone(store, record.profile.uuid, record.deletedAt)
        } else {
          // A remote envelope can carry a reserved uuid whose name is still its
          // raw resource key. Resolve it in-transaction so the merge stores the
          // real label; if the resource is not ready yet, skip only this row
          // (never store the raw key) so one stale polluted row cannot block the
          // rest of the sync. The clock/tombstone decision above is unchanged.
          if (HomeSubtabNames.isKeyName(record.profile.uuid, record.profile.name)) {
            const resolvedName: string = HomeSubtabNames.defaultNameOrEmpty(record.profile.name)
            if (resolvedName.length === 0) {
              DiagnosticLogger.warn('sync', 'home_subtab_remote_key_unresolved',
                `uuid=${record.profile.uuid}`)
              continue
            }
            record.profile.name = resolvedName
          }
          await HomeSubtabRepository.upsert(store, record.profile, record.positionIndex)
        }
      }
      // Repair any reserved-key row already stored locally, in the same transaction.
      await HomeSubtabRepository.repairResourceNamesWithStore(store)
      store.commit()
    } catch (error) {
      store.rollBack()
      throw error as Error
    }
  }

  private static async readRecords(
    context: common.UIAbilityContext,
    includeDeleted: boolean,
  ): Promise<HomeSubtabStorageRecord[]> {
    const records: HomeSubtabStorageRecord[] = []
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const rows: relationalStore.ResultSet = await store.querySql(
      includeDeleted ? SQL_SELECT_ALL : SQL_SELECT_ACTIVE,
      [SCOPE_GLOBAL],
    )
    try {
      while (rows.goToNextRow()) {
        const record: HomeSubtabStorageRecord = new HomeSubtabStorageRecord()
        record.profile.uuid = HomeSubtabRepository.stringColumn(rows, 'profile_uuid')
        record.positionIndex = Math.max(0, Math.floor(HomeSubtabRepository.numberColumn(rows, 'position_index')))
        record.profile.kind = NhHomeSubtabProfile.normalizeKind(HomeSubtabRepository.stringColumn(rows, 'kind'))
        record.profile.name = HomeSubtabRepository.stringColumn(rows, 'name')
        record.profile.query = HomeSubtabRepository.stringColumn(rows, 'query_text')
        record.profile.language = NhHomeSubtabProfile.normalizeLanguage(
          HomeSubtabRepository.stringColumn(rows, 'language'),
        )
        record.profile.sort = NhHomeSubtabProfile.normalizeSort(HomeSubtabRepository.stringColumn(rows, 'sort'))
        record.profile.ignoreLocalUserTagFiltering =
          HomeSubtabRepository.numberColumn(rows, 'ignore_local_user_tag_filtering') !== 0
        const presentation: string = HomeSubtabRepository.stringColumn(rows, 'display_mode')
        record.profile.presentation = NhHomeSubtabProfile.normalizePresentation(presentation) === null
          ? HOME_SUBTAB_PRESENTATION_GLOBAL
          : presentation
        record.profile.hidden = HomeSubtabRepository.numberColumn(rows, 'hidden') !== 0
        record.profile.lastEditTime = Math.floor(HomeSubtabRepository.numberColumn(rows, 'last_edit_time'))
        record.profile.normalizeBuiltinIdentity()
        record.deletedAt = Math.floor(HomeSubtabRepository.numberColumn(rows, 'deleted_at'))
        if (record.profile.uuid.length > 0) {
          records.push(record)
        }
      }
    } finally {
      rows.close()
    }
    if (includeDeleted) {
      return records
    }
    records.sort((left: HomeSubtabStorageRecord, right: HomeSubtabStorageRecord): number => {
      if (left.positionIndex !== right.positionIndex) {
        return left.positionIndex - right.positionIndex
      }
      if (left.profile.uuid < right.profile.uuid) {
        return -1
      }
      return left.profile.uuid === right.profile.uuid ? 0 : 1
    })
    return records
  }

  /**
   * Repair a reserved built-in/starter row whose stored name is still exactly
   * its own resource key (a raw-key write from an older build). Only those
   * exact uuids and exact key names are touched; a custom profile, a genuine
   * rename, order, hidden, query and tombstones are never rewritten. The clock
   * is advanced past any incoming future clock so the repair wins the LWW merge.
   */
  static async repairResourceNames(context: common.UIAbilityContext): Promise<boolean> {
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    store.beginTransaction()
    try {
      const repaired: boolean = await HomeSubtabRepository.repairResourceNamesWithStore(store)
      store.commit()
      return repaired
    } catch (error) {
      store.rollBack()
      throw error as Error
    }
  }

  /** Caller owns the transaction, including a sync apply. */
  static async repairResourceNamesWithStore(store: relationalStore.RdbStore): Promise<boolean> {
    const rows: relationalStore.ResultSet = await store.querySql(SQL_SELECT_ALL, [SCOPE_GLOBAL])
    const targets: NhHomeSubtabProfile[] = []
    try {
      while (rows.goToNextRow()) {
        const uuid: string = HomeSubtabRepository.stringColumn(rows, 'profile_uuid')
        const name: string = HomeSubtabRepository.stringColumn(rows, 'name')
        const deletedAt: number = Math.floor(HomeSubtabRepository.numberColumn(rows, 'deleted_at'))
        if (deletedAt !== 0 || !HomeSubtabNames.isKeyName(uuid, name)) {
          continue
        }
        const profile: NhHomeSubtabProfile = new NhHomeSubtabProfile()
        profile.uuid = uuid
        profile.name = name
        profile.lastEditTime = Math.floor(HomeSubtabRepository.numberColumn(rows, 'last_edit_time'))
        targets.push(profile)
      }
    } finally {
      rows.close()
    }
    let repaired: boolean = false
    for (let index: number = 0; index < targets.length; index++) {
      const target: NhHomeSubtabProfile = targets[index]
      const resolved: string = HomeSubtabNames.defaultNameOrEmpty(target.name)
      if (resolved.length === 0) {
        continue
      }
      const clock: number = Math.max(Date.now(), target.lastEditTime + 1)
      await store.executeSql(
        'UPDATE home_subtabs SET name = ?, last_edit_time = ? ' +
        'WHERE scope_key = ? AND profile_uuid = ? AND name = ? AND COALESCE(deleted_at, 0) = 0 ' +
        'AND COALESCE(last_edit_time, 0) = ?',
        [resolved, clock, SCOPE_GLOBAL, target.uuid, target.name, target.lastEditTime],
      )
      repaired = true
    }
    return repaired
  }

  private static async upsert(
    store: relationalStore.RdbStore,
    profile: NhHomeSubtabProfile,
    positionIndex: number,
  ): Promise<void> {
    if (profile.uuid.length === 0) {
      return
    }
    HomeSubtabNames.assertPersistable(profile.uuid, profile.name)
    await store.executeSql(SQL_UPSERT, [
      SCOPE_GLOBAL,
      profile.uuid,
      positionIndex,
      profile.kind,
      profile.name,
      profile.query.trim(),
      profile.language,
      profile.sort,
      profile.ignoreLocalUserTagFiltering ? 1 : 0,
      profile.presentation,
      profile.hidden ? 1 : 0,
      profile.lastEditTime,
    ])
  }

  private static async tombstone(store: relationalStore.RdbStore, uuid: string): Promise<void> {
    const clock: HomeSubtabClock = await HomeSubtabRepository.readClock(store, uuid)
    const deletedAt: number = Math.max(Date.now(), clock.lastEditTime + 1, clock.deletedAt + 1)
    await HomeSubtabRepository.upsertTombstone(store, uuid, deletedAt)
  }

  private static async upsertTombstone(
    store: relationalStore.RdbStore,
    uuid: string,
    deletedAt: number,
  ): Promise<void> {
    await store.executeSql(SQL_UPSERT_TOMBSTONE, [
      SCOPE_GLOBAL,
      uuid,
      NhHomeSubtabKind.SEARCH,
      '',
      '',
      '',
      '',
      HOME_SUBTAB_PRESENTATION_GLOBAL,
      deletedAt,
    ])
  }

  private static async nextClock(
    store: relationalStore.RdbStore,
    uuid: string,
    requested: number,
  ): Promise<number> {
    const clock: HomeSubtabClock = await HomeSubtabRepository.readClock(store, uuid)
    return Math.max(Date.now(), Math.floor(requested), clock.lastEditTime + 1, clock.deletedAt + 1)
  }

  private static async readClock(
    store: relationalStore.RdbStore,
    uuid: string,
  ): Promise<HomeSubtabClock> {
    const clock: HomeSubtabClock = new HomeSubtabClock()
    const rows: relationalStore.ResultSet = await store.querySql(SQL_SELECT_ONE_CLOCK, [SCOPE_GLOBAL, uuid])
    try {
      if (rows.goToNextRow()) {
        clock.lastEditTime = Math.floor(HomeSubtabRepository.numberColumn(rows, 'last_edit_time'))
        clock.deletedAt = Math.floor(HomeSubtabRepository.numberColumn(rows, 'deleted_at'))
      }
    } finally {
      rows.close()
    }
    return clock
  }

  private static async saveSelectionWithStore(
    store: relationalStore.RdbStore,
    selectedUuid: string,
  ): Promise<void> {
    const current: HomeSubtabSelectionRecord = new HomeSubtabSelectionRecord()
    const rows: relationalStore.ResultSet = await store.querySql(SQL_SELECT_SELECTION, [SCOPE_GLOBAL])
    try {
      if (rows.goToNextRow()) {
        current.updatedAt = Math.floor(HomeSubtabRepository.numberColumn(rows, 'updated_at'))
        current.deletedAt = Math.floor(HomeSubtabRepository.numberColumn(rows, 'deleted_at'))
      }
    } finally {
      rows.close()
    }
    const updatedAt: number = Math.max(Date.now(), current.updatedAt + 1, current.deletedAt + 1)
    await store.executeSql(SQL_UPSERT_SELECTION, [SCOPE_GLOBAL, selectedUuid, updatedAt])
  }

  private static profileIndex(profiles: NhHomeSubtabProfile[], uuid: string): number {
    for (let index: number = 0; index < profiles.length; index++) {
      if (profiles[index].uuid === uuid) {
        return index
      }
    }
    return -1
  }

  private static stringColumn(rows: relationalStore.ResultSet, name: string): string {
    const index: number = rows.getColumnIndex(name)
    return rows.isColumnNull(index) ? '' : rows.getString(index)
  }

  private static numberColumn(rows: relationalStore.ResultSet, name: string): number {
    const index: number = rows.getColumnIndex(name)
    return rows.isColumnNull(index) ? 0 : rows.getDouble(index)
  }
}
