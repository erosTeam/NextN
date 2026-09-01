import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import {
  NH_LOCAL_USER_TAG_SCOPE_GLOBAL,
  NhLocalUserTag,
  NhLocalUserTagContract,
  NhLocalUserTagSettings,
  NhLocalUserTagSnapshot,
} from '../model/NhLocalUserTag'
import { LocalDataStore } from './LocalDataStore'

const SQL_SELECT_ACTIVE_TAGS: string =
  'SELECT scope_key, tag_id, namespace_snapshot, name_snapshot, color_code, weight, hidden, updated_at, deleted_at ' +
  'FROM local_user_tags WHERE scope_key = ? AND COALESCE(deleted_at, 0) = 0 ORDER BY tag_id ASC'
const SQL_SELECT_ALL_TAGS: string =
  'SELECT scope_key, tag_id, namespace_snapshot, name_snapshot, color_code, weight, hidden, updated_at, deleted_at ' +
  'FROM local_user_tags WHERE scope_key = ? ORDER BY tag_id ASC'
const SQL_SELECT_TAG_CLOCK: string =
  'SELECT updated_at, deleted_at FROM local_user_tags WHERE scope_key = ? AND tag_id = ? LIMIT 1'
const SQL_SELECT_SETTINGS: string =
  'SELECT scope_key, filtering_threshold, updated_at, deleted_at FROM local_user_tag_settings ' +
  'WHERE scope_key = ? LIMIT 1'
const SQL_UPSERT_TAG: string =
  'INSERT INTO local_user_tags (scope_key, tag_id, namespace_snapshot, name_snapshot, color_code, weight, hidden, ' +
  'updated_at, deleted_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0) ' +
  'ON CONFLICT(scope_key, tag_id) DO UPDATE SET namespace_snapshot = excluded.namespace_snapshot, ' +
  'name_snapshot = excluded.name_snapshot, color_code = excluded.color_code, weight = excluded.weight, ' +
  'hidden = excluded.hidden, updated_at = excluded.updated_at, deleted_at = 0 ' +
  'WHERE excluded.updated_at >= COALESCE(local_user_tags.updated_at, 0) ' +
  'AND excluded.updated_at > COALESCE(local_user_tags.deleted_at, 0)'
const SQL_UPSERT_TAG_TOMBSTONE: string =
  'INSERT INTO local_user_tags (scope_key, tag_id, namespace_snapshot, name_snapshot, color_code, weight, hidden, ' +
  'updated_at, deleted_at) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?) ' +
  'ON CONFLICT(scope_key, tag_id) DO UPDATE SET deleted_at = excluded.deleted_at ' +
  'WHERE excluded.deleted_at >= COALESCE(local_user_tags.updated_at, 0) ' +
  'AND excluded.deleted_at >= COALESCE(local_user_tags.deleted_at, 0)'
const SQL_UPSERT_SETTINGS: string =
  'INSERT INTO local_user_tag_settings (scope_key, filtering_threshold, updated_at, deleted_at) VALUES (?, ?, ?, 0) ' +
  'ON CONFLICT(scope_key) DO UPDATE SET filtering_threshold = excluded.filtering_threshold, ' +
  'updated_at = excluded.updated_at, deleted_at = 0 ' +
  'WHERE excluded.updated_at >= COALESCE(local_user_tag_settings.updated_at, 0) ' +
  'AND excluded.updated_at > COALESCE(local_user_tag_settings.deleted_at, 0)'
const SQL_UPSERT_SETTINGS_TOMBSTONE: string =
  'INSERT INTO local_user_tag_settings (scope_key, filtering_threshold, updated_at, deleted_at) VALUES (?, 0, 0, ?) ' +
  'ON CONFLICT(scope_key) DO UPDATE SET deleted_at = excluded.deleted_at ' +
  'WHERE excluded.deleted_at >= COALESCE(local_user_tag_settings.updated_at, 0) ' +
  'AND excluded.deleted_at >= COALESCE(local_user_tag_settings.deleted_at, 0)'

class LocalUserTagClock {
  updatedAt: number = 0
  deletedAt: number = 0
}

/** Durable owner for active rules, settings and their syncable tombstones. */
export class NhLocalUserTagRepository {
  static load(context: common.UIAbilityContext): Promise<NhLocalUserTagSnapshot> {
    return NhLocalUserTagRepository.readSnapshot(context, false)
  }

  static exportSnapshot(context: common.UIAbilityContext): Promise<NhLocalUserTagSnapshot> {
    return NhLocalUserTagRepository.readSnapshot(context, true)
  }

  static async saveTag(context: common.UIAbilityContext, draft: NhLocalUserTag): Promise<NhLocalUserTag> {
    if (draft.tagId <= 0) {
      throw new Error('Local user tag id must be positive')
    }
    if (!NhLocalUserTagContract.isColorCodeValid(draft.colorCode)) {
      throw new Error('Local user tag color must use #RRGGBB')
    }
    const record: NhLocalUserTag = NhLocalUserTagContract.normalizeTag(draft)
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const clock: LocalUserTagClock = await NhLocalUserTagRepository.readTagClock(store, record.tagId)
    record.updatedAt = Math.max(Date.now(), record.updatedAt, clock.updatedAt + 1, clock.deletedAt + 1)
    record.deletedAt = 0
    await NhLocalUserTagRepository.upsertTag(store, record)
    return record.copy()
  }

  static async removeTag(context: common.UIAbilityContext, tagId: number): Promise<void> {
    const normalizedId: number = Math.floor(tagId)
    if (normalizedId <= 0) {
      return
    }
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const clock: LocalUserTagClock = await NhLocalUserTagRepository.readTagClock(store, normalizedId)
    const deletedAt: number = Math.max(Date.now(), clock.updatedAt + 1, clock.deletedAt + 1)
    await NhLocalUserTagRepository.upsertTagTombstone(store, normalizedId, deletedAt)
  }

  static async saveSettings(
    context: common.UIAbilityContext,
    draft: NhLocalUserTagSettings,
  ): Promise<NhLocalUserTagSettings> {
    const settings: NhLocalUserTagSettings = NhLocalUserTagContract.normalizeSettings(draft)
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const current: NhLocalUserTagSettings = await NhLocalUserTagRepository.readSettings(store)
    settings.updatedAt = Math.max(Date.now(), settings.updatedAt, current.updatedAt + 1, current.deletedAt + 1)
    settings.deletedAt = 0
    await NhLocalUserTagRepository.upsertSettings(store, settings)
    return settings.copy()
  }

  /** LWW import used later by backup and WebDAV without changing their clocks. */
  static async importSnapshot(context: common.UIAbilityContext, snapshot: NhLocalUserTagSnapshot): Promise<void> {
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    store.beginTransaction()
    try {
      for (let index: number = 0; index < snapshot.tags.length; index++) {
        const record: NhLocalUserTag = NhLocalUserTagContract.normalizeTag(snapshot.tags[index])
        if (record.tagId <= 0) {
          continue
        }
        if (record.deletedAt > 0 && record.deletedAt >= record.updatedAt) {
          await NhLocalUserTagRepository.upsertTagTombstone(store, record.tagId, record.deletedAt)
        } else {
          await NhLocalUserTagRepository.upsertTag(store, record)
        }
      }
      const settings: NhLocalUserTagSettings = NhLocalUserTagContract.normalizeSettings(snapshot.settings)
      if (settings.deletedAt > 0 && settings.deletedAt >= settings.updatedAt) {
        await store.executeSql(SQL_UPSERT_SETTINGS_TOMBSTONE, [settings.scopeKey, settings.deletedAt])
      } else if (settings.updatedAt > 0) {
        await NhLocalUserTagRepository.upsertSettings(store, settings)
      }
      store.commit()
    } catch (error) {
      store.rollBack()
      throw error as Error
    }
  }

  private static async readSnapshot(
    context: common.UIAbilityContext,
    includeDeleted: boolean,
  ): Promise<NhLocalUserTagSnapshot> {
    const snapshot: NhLocalUserTagSnapshot = new NhLocalUserTagSnapshot()
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const rows: relationalStore.ResultSet = await store.querySql(
      includeDeleted ? SQL_SELECT_ALL_TAGS : SQL_SELECT_ACTIVE_TAGS,
      [NH_LOCAL_USER_TAG_SCOPE_GLOBAL],
    )
    try {
      while (rows.goToNextRow()) {
        snapshot.tags.push(NhLocalUserTagRepository.readTag(rows))
      }
    } finally {
      rows.close()
    }
    snapshot.settings = await NhLocalUserTagRepository.readSettings(store)
    if (!includeDeleted && snapshot.settings.deletedAt > 0) {
      snapshot.settings = new NhLocalUserTagSettings()
    }
    return snapshot
  }

  private static readTag(rows: relationalStore.ResultSet): NhLocalUserTag {
    const record: NhLocalUserTag = new NhLocalUserTag()
    record.scopeKey = NhLocalUserTagRepository.stringColumn(rows, 'scope_key')
    record.tagId = Math.floor(NhLocalUserTagRepository.numberColumn(rows, 'tag_id'))
    record.namespaceSnapshot = NhLocalUserTagRepository.stringColumn(rows, 'namespace_snapshot')
    record.nameSnapshot = NhLocalUserTagRepository.stringColumn(rows, 'name_snapshot')
    record.colorCode = NhLocalUserTagRepository.stringColumn(rows, 'color_code')
    record.weight = Math.round(NhLocalUserTagRepository.numberColumn(rows, 'weight'))
    record.hidden = NhLocalUserTagRepository.numberColumn(rows, 'hidden') !== 0
    record.updatedAt = Math.floor(NhLocalUserTagRepository.numberColumn(rows, 'updated_at'))
    record.deletedAt = Math.floor(NhLocalUserTagRepository.numberColumn(rows, 'deleted_at'))
    return NhLocalUserTagContract.normalizeTag(record)
  }

  private static async readSettings(store: relationalStore.RdbStore): Promise<NhLocalUserTagSettings> {
    const settings: NhLocalUserTagSettings = new NhLocalUserTagSettings()
    const rows: relationalStore.ResultSet = await store.querySql(
      SQL_SELECT_SETTINGS,
      [NH_LOCAL_USER_TAG_SCOPE_GLOBAL],
    )
    try {
      if (rows.goToNextRow()) {
        settings.scopeKey = NhLocalUserTagRepository.stringColumn(rows, 'scope_key')
        settings.filteringThreshold = Math.round(
          NhLocalUserTagRepository.numberColumn(rows, 'filtering_threshold'),
        )
        settings.updatedAt = Math.floor(NhLocalUserTagRepository.numberColumn(rows, 'updated_at'))
        settings.deletedAt = Math.floor(NhLocalUserTagRepository.numberColumn(rows, 'deleted_at'))
      }
    } finally {
      rows.close()
    }
    return NhLocalUserTagContract.normalizeSettings(settings)
  }

  private static async readTagClock(
    store: relationalStore.RdbStore,
    tagId: number,
  ): Promise<LocalUserTagClock> {
    const clock: LocalUserTagClock = new LocalUserTagClock()
    const rows: relationalStore.ResultSet = await store.querySql(
      SQL_SELECT_TAG_CLOCK,
      [NH_LOCAL_USER_TAG_SCOPE_GLOBAL, tagId],
    )
    try {
      if (rows.goToNextRow()) {
        clock.updatedAt = Math.floor(NhLocalUserTagRepository.numberColumn(rows, 'updated_at'))
        clock.deletedAt = Math.floor(NhLocalUserTagRepository.numberColumn(rows, 'deleted_at'))
      }
    } finally {
      rows.close()
    }
    return clock
  }

  private static async upsertTag(store: relationalStore.RdbStore, record: NhLocalUserTag): Promise<void> {
    await store.executeSql(SQL_UPSERT_TAG, [
      record.scopeKey,
      record.tagId,
      record.namespaceSnapshot,
      record.nameSnapshot,
      record.colorCode,
      record.weight,
      record.hidden ? 1 : 0,
      record.updatedAt,
    ])
  }

  private static async upsertTagTombstone(
    store: relationalStore.RdbStore,
    tagId: number,
    deletedAt: number,
  ): Promise<void> {
    await store.executeSql(SQL_UPSERT_TAG_TOMBSTONE, [
      NH_LOCAL_USER_TAG_SCOPE_GLOBAL,
      tagId,
      '',
      '',
      '',
      10,
      0,
      deletedAt,
    ])
  }

  private static async upsertSettings(
    store: relationalStore.RdbStore,
    settings: NhLocalUserTagSettings,
  ): Promise<void> {
    await store.executeSql(SQL_UPSERT_SETTINGS, [
      settings.scopeKey,
      settings.filteringThreshold,
      settings.updatedAt,
    ])
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
