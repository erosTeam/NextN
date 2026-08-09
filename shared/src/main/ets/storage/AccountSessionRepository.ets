import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { LocalDataStore } from './LocalDataStore'

const SESSION_KEY: string = 'primary'
const SQL_SELECT_SESSION: string =
  'SELECT ciphertext, nonce FROM account_session WHERE key = ? LIMIT 1'
const SQL_UPSERT_SESSION: string =
  'INSERT INTO account_session (key, ciphertext, nonce, updated_at) VALUES (?, ?, ?, ?) ' +
  'ON CONFLICT(key) DO UPDATE SET ciphertext = excluded.ciphertext, nonce = excluded.nonce, ' +
  'updated_at = excluded.updated_at'
const SQL_DELETE_SESSION: string = 'DELETE FROM account_session WHERE key = ?'
const SQL_SELECT_VERIFICATION_REQUIRED: string =
  'SELECT verification_required FROM account_session_verification WHERE key = ? LIMIT 1'
const SQL_UPSERT_VERIFICATION_REQUIRED: string =
  'INSERT INTO account_session_verification (key, verification_required, updated_at) VALUES (?, ?, ?) ' +
  'ON CONFLICT(key) DO UPDATE SET verification_required = excluded.verification_required, ' +
  'updated_at = excluded.updated_at'
const SQL_DELETE_VERIFICATION_REQUIRED: string =
  'DELETE FROM account_session_verification WHERE key = ?'

/** Ciphertext-only persistence for the account-session envelope. */
export class EncryptedAccountSession {
  ciphertext: string = ''
  nonce: string = ''
}

/**
 * Cold restore needs to distinguish a normal empty first-install table from
 * a platform-rebuilt/repaired store that no longer contains the envelope.
 * It carries no account data beyond the existing encrypted record.
 */
export class AccountSessionRestoreSnapshot {
  record: EncryptedAccountSession | null = null
  rebuiltOrRepaired: boolean = false
}

export class AccountSessionRepository {
  private static writeTail: Promise<void> = Promise.resolve()

  static async load(context: common.UIAbilityContext): Promise<EncryptedAccountSession | null> {
    const snapshot: AccountSessionRestoreSnapshot = await AccountSessionRepository.loadForRestore(context)
    return snapshot.record
  }

  /**
   * Reads the encrypted envelope and the RDB rebuild signal from the same
   * opened store. Restore uses this only on a cold/no-runtime-session path.
   */
  static async loadForRestore(context: common.UIAbilityContext): Promise<AccountSessionRestoreSnapshot> {
    let rows: relationalStore.ResultSet | null = null
    try {
      await AccountSessionRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      const snapshot: AccountSessionRestoreSnapshot = new AccountSessionRestoreSnapshot()
      snapshot.rebuiltOrRepaired = store.rebuilt !== relationalStore.RebuildType.NONE
      rows = await store.querySql(SQL_SELECT_SESSION, [SESSION_KEY])
      if (!rows.goToNextRow()) {
        return snapshot
      }
      const ciphertextColumn: number = rows.getColumnIndex('ciphertext')
      const nonceColumn: number = rows.getColumnIndex('nonce')
      if (rows.isColumnNull(ciphertextColumn) || rows.isColumnNull(nonceColumn)) {
        return snapshot
      }
      const record: EncryptedAccountSession = new EncryptedAccountSession()
      record.ciphertext = rows.getString(ciphertextColumn)
      record.nonce = rows.getString(nonceColumn)
      snapshot.record = record
      return snapshot
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (_error) {}
      }
    }
  }

  /**
   * A verified visible-browser promotion replaces the encrypted envelope and
   * clears the non-secret verification gate as one RDB transaction. Either
   * both durable changes commit or neither one does.
   */
  static saveVerified(
    context: common.UIAbilityContext,
    record: EncryptedAccountSession,
  ): Promise<void> {
    return AccountSessionRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      let transactionOpen: boolean = false
      try {
        store.beginTransaction()
        transactionOpen = true
        await store.executeSql(SQL_UPSERT_SESSION, [
          SESSION_KEY,
          record.ciphertext,
          record.nonce,
          Date.now(),
        ])
        await store.executeSql(SQL_DELETE_VERIFICATION_REQUIRED, [SESSION_KEY])
        store.commit()
        transactionOpen = false
      } catch (error) {
        if (transactionOpen) {
          store.rollBack()
        }
        throw error as Error
      }
    })
  }

  /** Persists a non-secret Account recovery gate without touching the envelope. */
  static markVerificationRequired(context: common.UIAbilityContext): Promise<void> {
    return AccountSessionRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT_VERIFICATION_REQUIRED, [SESSION_KEY, 1, Date.now()])
    })
  }

  /**
   * A verification marker is intentionally sufficient to fail closed. If a
   * prior interrupted write left it without an envelope, Account still asks
   * for one explicit visible verification rather than silently opening Web.
   */
  static async isVerificationRequired(context: common.UIAbilityContext): Promise<boolean> {
    let rows: relationalStore.ResultSet | null = null
    try {
      await AccountSessionRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql(SQL_SELECT_VERIFICATION_REQUIRED, [SESSION_KEY])
      if (!rows.goToNextRow()) {
        return false
      }
      const column: number = rows.getColumnIndex('verification_required')
      return !rows.isColumnNull(column) && rows.getLong(column) !== 0
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (_error) {}
      }
    }
  }

  /** Explicit sign-out is the only path that deletes the sealed envelope. */
  static clear(context: common.UIAbilityContext): Promise<void> {
    return AccountSessionRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      let transactionOpen: boolean = false
      try {
        store.beginTransaction()
        transactionOpen = true
        await store.executeSql(SQL_DELETE_SESSION, [SESSION_KEY])
        await store.executeSql(SQL_DELETE_VERIFICATION_REQUIRED, [SESSION_KEY])
        store.commit()
        transactionOpen = false
      } catch (error) {
        if (transactionOpen) {
          store.rollBack()
        }
        throw error as Error
      }
    })
  }

  private static enqueueWrite(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = AccountSessionRepository.writeTail.then(
      (): Promise<void> => operation(),
      (): Promise<void> => operation(),
    )
    AccountSessionRepository.writeTail = queued.catch((): void => {})
    return queued
  }
}
