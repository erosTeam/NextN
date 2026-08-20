import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { LocalDataStore } from './LocalDataStore'

const SESSION_KEY: string = 'primary'
const SQL_SELECT_SESSION: string =
  'SELECT ciphertext, nonce FROM account_session WHERE key = ? LIMIT 1'
const SQL_SELECT_SAVED_SESSIONS: string =
  'SELECT key, ciphertext, nonce FROM account_session WHERE key != ?'
const SQL_UPSERT_SESSION: string =
  'INSERT INTO account_session (key, ciphertext, nonce, updated_at) VALUES (?, ?, ?, ?) ' +
  'ON CONFLICT(key) DO UPDATE SET ciphertext = excluded.ciphertext, nonce = excluded.nonce, ' +
  'updated_at = excluded.updated_at'
const SQL_DELETE_SESSION: string = 'DELETE FROM account_session WHERE key = ?'
const SQL_SELECT_VERIFICATION_REQUIRED: string =
  'SELECT verification_required, reason_code FROM account_session_verification WHERE key = ? LIMIT 1'
const SQL_UPSERT_VERIFICATION_REQUIRED: string =
  'INSERT INTO account_session_verification (key, verification_required, reason_code, updated_at) VALUES (?, ?, ?, ?) ' +
  'ON CONFLICT(key) DO UPDATE SET verification_required = excluded.verification_required, ' +
  'reason_code = excluded.reason_code, updated_at = excluded.updated_at'
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
  savedRecords: EncryptedAccountSession[] = []
  savedKeys: string[] = []
}

/** Durable non-secret verification state with a finite transition origin. */
export class AccountSessionVerificationSnapshot {
  required: boolean = false
  reasonCode: string = ''
}

export class AccountSessionRepository {
  private static writeTail: Promise<void> = Promise.resolve()

  static async load(context: common.UIAbilityContext): Promise<EncryptedAccountSession | null> {
    return AccountSessionRepository.loadByKey(context, SESSION_KEY)
  }

  /** Reads one saved account's sealed envelope by its non-secret account id. */
  static async loadByKey(context: common.UIAbilityContext, key: string): Promise<EncryptedAccountSession | null> {
    let rows: relationalStore.ResultSet | null = null
    try {
      await AccountSessionRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql(SQL_SELECT_SESSION, [key])
      if (!rows.goToNextRow()) {
        return null
      }
      const ciphertextColumn: number = rows.getColumnIndex('ciphertext')
      const nonceColumn: number = rows.getColumnIndex('nonce')
      if (rows.isColumnNull(ciphertextColumn) || rows.isColumnNull(nonceColumn)) {
        return null
      }
      const record: EncryptedAccountSession = new EncryptedAccountSession()
      record.ciphertext = rows.getString(ciphertextColumn)
      record.nonce = rows.getString(nonceColumn)
      return record
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (_error) {}
      }
    }
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
      if (rows.goToNextRow()) {
        const ciphertextColumn: number = rows.getColumnIndex('ciphertext')
        const nonceColumn: number = rows.getColumnIndex('nonce')
        if (!rows.isColumnNull(ciphertextColumn) && !rows.isColumnNull(nonceColumn)) {
          const record: EncryptedAccountSession = new EncryptedAccountSession()
          record.ciphertext = rows.getString(ciphertextColumn)
          record.nonce = rows.getString(nonceColumn)
          snapshot.record = record
        }
      }
      try {
        rows.close()
      } catch (_error) {}
      rows = null
      rows = await store.querySql(SQL_SELECT_SAVED_SESSIONS, [SESSION_KEY])
      while (rows.goToNextRow()) {
        const savedKeyColumn: number = rows.getColumnIndex('key')
        const savedCiphertextColumn: number = rows.getColumnIndex('ciphertext')
        const savedNonceColumn: number = rows.getColumnIndex('nonce')
        if (rows.isColumnNull(savedKeyColumn) ||
          rows.isColumnNull(savedCiphertextColumn) ||
          rows.isColumnNull(savedNonceColumn)) {
          continue
        }
        const savedKey: string = rows.getString(savedKeyColumn).trim()
        if (savedKey.length === 0 || savedKey === SESSION_KEY) {
          continue
        }
        const savedRecord: EncryptedAccountSession = new EncryptedAccountSession()
        savedRecord.ciphertext = rows.getString(savedCiphertextColumn)
        savedRecord.nonce = rows.getString(savedNonceColumn)
        snapshot.savedKeys.push(savedKey)
        snapshot.savedRecords.push(savedRecord)
      }
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
    return AccountSessionRepository.saveVerifiedForAccount(context, record, '')
  }

  /**
   * Atomically advances the active envelope and, when known, the matching
   * saved-account envelope. A rotated access token must never leave the
   * account switcher pointing at an older login-time snapshot.
   */
  static saveVerifiedForAccount(
    context: common.UIAbilityContext,
    record: EncryptedAccountSession,
    accountId: string,
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
        if (accountId.length > 0 && accountId !== SESSION_KEY) {
          await store.executeSql(SQL_UPSERT_SESSION, [
            accountId,
            record.ciphertext,
            record.nonce,
            Date.now(),
          ])
        }
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
  static markVerificationRequired(
    context: common.UIAbilityContext,
    reasonCode: string,
  ): Promise<void> {
    if (reasonCode !== 'terminal_401_browser_refresh_unsuccessful') {
      return Promise.reject(new Error('account_verification_reason_invalid'))
    }
    return AccountSessionRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT_VERIFICATION_REQUIRED, [
        SESSION_KEY,
        1,
        reasonCode,
        Date.now(),
      ])
    })
  }

  /**
   * A verification marker is intentionally sufficient to fail closed. If a
   * prior interrupted write left it without an envelope, Account still asks
   * for one explicit visible verification rather than silently opening Web.
   */
  static async loadVerificationSnapshot(
    context: common.UIAbilityContext,
  ): Promise<AccountSessionVerificationSnapshot> {
    let rows: relationalStore.ResultSet | null = null
    try {
      await AccountSessionRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql(SQL_SELECT_VERIFICATION_REQUIRED, [SESSION_KEY])
      const snapshot: AccountSessionVerificationSnapshot = new AccountSessionVerificationSnapshot()
      if (!rows.goToNextRow()) {
        return snapshot
      }
      const requiredColumn: number = rows.getColumnIndex('verification_required')
      snapshot.required = !rows.isColumnNull(requiredColumn) && rows.getLong(requiredColumn) !== 0
      const reasonColumn: number = rows.getColumnIndex('reason_code')
      if (!rows.isColumnNull(reasonColumn)) {
        snapshot.reasonCode = rows.getString(reasonColumn)
      }
      return snapshot
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (_error) {}
      }
    }
  }

  static async isVerificationRequired(context: common.UIAbilityContext): Promise<boolean> {
    return (await AccountSessionRepository.loadVerificationSnapshot(context)).required
  }

  /**
   * Clears a stale durable verification marker. Used only when a live regular
   * ArkWeb cookie jar has already proven the browser identity, so a previous
   * terminal-401 record must not force a fake "tap to reverify" step.
   */
  static clearVerificationRequired(context: common.UIAbilityContext): Promise<void> {
    return AccountSessionRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_DELETE_VERIFICATION_REQUIRED, [SESSION_KEY])
    })
  }

  /** Explicit sign-out is the only path that deletes the sealed envelope. */
  /** Writes one saved account's sealed envelope under its account id. */
  static saveVerifiedByKey(
    context: common.UIAbilityContext,
    key: string,
    record: EncryptedAccountSession,
  ): Promise<void> {
    return AccountSessionRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT_SESSION, [
        key,
        record.ciphertext,
        record.nonce,
        Date.now(),
      ])
    })
  }

  /** Removes one saved account's sealed envelope; never touches the active row. */
  static deleteByKey(context: common.UIAbilityContext, key: string): Promise<void> {
    return AccountSessionRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_DELETE_SESSION, [key])
    })
  }

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
