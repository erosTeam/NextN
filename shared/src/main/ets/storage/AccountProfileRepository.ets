import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { NhAccountProfile } from '../model/NhAccountProfile'
import { LocalDataStore } from './LocalDataStore'

const PROFILE_KEY: string = 'primary'
const SQL_SELECT_PROFILE: string =
  'SELECT username, user_url, user_id, avatar_url FROM account_profile WHERE key = ? LIMIT 1'
const SQL_UPSERT_PROFILE: string =
  'INSERT INTO account_profile (key, username, user_url, user_id, avatar_url, updated_at) VALUES (?, ?, ?, ?, ?, ?) ' +
  'ON CONFLICT(key) DO UPDATE SET username = excluded.username, user_url = excluded.user_url, ' +
  'user_id = excluded.user_id, avatar_url = excluded.avatar_url, updated_at = excluded.updated_at'
const SQL_DELETE_PROFILE: string = 'DELETE FROM account_profile WHERE key = ?'

/**
 * One display-only snapshot for NextN's deliberately single-account session.
 * It has its own table so profile data can never be confused with the HUKS
 * encrypted credential envelope.
 */
export class AccountProfileRepository {
  private static writeTail: Promise<void> = Promise.resolve()

  static async load(context: common.UIAbilityContext): Promise<NhAccountProfile | null> {
    let rows: relationalStore.ResultSet | null = null
    try {
      await AccountProfileRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql(SQL_SELECT_PROFILE, [PROFILE_KEY])
      if (!rows.goToNextRow()) {
        return null
      }
      const profile: NhAccountProfile = new NhAccountProfile()
      profile.username = AccountProfileRepository.stringColumn(rows, 'username')
      profile.userUrl = AccountProfileRepository.stringColumn(rows, 'user_url')
      profile.userId = AccountProfileRepository.stringColumn(rows, 'user_id')
      profile.avatarUrl = AccountProfileRepository.stringColumn(rows, 'avatar_url')
      return profile.hasIdentity() ? profile : null
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (_error) {}
      }
    }
  }

  /**
   * The caller supplies a session-liveness guard so a profile request that
   * began before sign-out or a newer login cannot re-create a stale snapshot
   * after this repository's serialized clear.
   */
  static saveIfCurrent(
    context: common.UIAbilityContext,
    profile: NhAccountProfile,
    isCurrent: () => boolean,
  ): Promise<boolean> {
    const snapshot: NhAccountProfile = profile.copy()
    return AccountProfileRepository.enqueueWrite(async (): Promise<boolean> => {
      if (!snapshot.hasIdentity() || !isCurrent()) {
        return false
      }
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      if (!isCurrent()) {
        return false
      }
      await store.executeSql(SQL_UPSERT_PROFILE, [
        PROFILE_KEY,
        snapshot.username,
        snapshot.userUrl,
        snapshot.userId,
        snapshot.avatarUrl,
        Date.now(),
      ])
      return isCurrent()
    })
  }

  static clear(context: common.UIAbilityContext): Promise<void> {
    return AccountProfileRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_DELETE_PROFILE, [PROFILE_KEY])
    })
  }

  private static stringColumn(rows: relationalStore.ResultSet, name: string): string {
    try {
      const index: number = rows.getColumnIndex(name)
      return rows.isColumnNull(index) ? '' : rows.getString(index)
    } catch (_error) {
      return ''
    }
  }

  private static enqueueWrite<T>(operation: () => Promise<T>): Promise<T> {
    const queued: Promise<T> = AccountProfileRepository.writeTail.then(
      (): Promise<T> => operation(),
      (): Promise<T> => operation(),
    )
    AccountProfileRepository.writeTail = queued.then(
      (): void => {},
      (): void => {},
    )
    return queued
  }
}
