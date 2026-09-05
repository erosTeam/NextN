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
const SQL_INSERT_SESSION_IF_ABSENT: string =
  'INSERT OR IGNORE INTO account_session (key, ciphertext, nonce, updated_at) VALUES (?, ?, ?, ?)'
const SQL_DELETE_SESSION: string = 'DELETE FROM account_session WHERE key = ?'
const SQL_DELETE_ALL_SESSIONS: string = 'DELETE FROM account_session'
const SQL_SELECT_SESSION_OWNER: string =
  'SELECT account_id FROM account_session_owner WHERE key = ? LIMIT 1'
const SQL_UPSERT_SESSION_OWNER: string =
  'INSERT INTO account_session_owner (key, account_id, updated_at) VALUES (?, ?, ?) ' +
  'ON CONFLICT(key) DO UPDATE SET account_id = excluded.account_id, updated_at = excluded.updated_at'
const SQL_DELETE_SESSION_OWNER: string = 'DELETE FROM account_session_owner WHERE key = ?'
const SQL_DELETE_SESSION_OWNER_BY_ACCOUNT: string =
  'DELETE FROM account_session_owner WHERE key = ? AND account_id = ?'
const SQL_DELETE_ALL_SESSION_OWNERS: string = 'DELETE FROM account_session_owner'
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
  primaryOwnerId: string = ''
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
      try {
        rows.close()
      } catch (_error) {}
      rows = null
      rows = await store.querySql(SQL_SELECT_SESSION_OWNER, [SESSION_KEY])
      if (rows.goToNextRow()) {
        const ownerColumn: number = rows.getColumnIndex('account_id')
        if (!rows.isColumnNull(ownerColumn)) {
          snapshot.primaryOwnerId = rows.getString(ownerColumn).trim()
        }
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
   * Resolves the primary envelope's owner from its atomic owner row. Old
   * databases are migrated lazily only when exactly one saved row contains
   * the same encrypted envelope; ambiguous or incomplete state stays ownerless.
   */
  static resolvePrimaryOwner(snapshot: AccountSessionRestoreSnapshot): string {
    if (snapshot.record === null || snapshot.savedKeys.length !== snapshot.savedRecords.length) {
      return ''
    }
    const explicitOwner: string = snapshot.primaryOwnerId.trim()
    if (explicitOwner.length > 0 && snapshot.savedKeys.indexOf(explicitOwner) >= 0) {
      return explicitOwner
    }
    let matchingOwner: string = ''
    let matchingCount: number = 0
    for (let index: number = 0; index < snapshot.savedKeys.length; index += 1) {
      const savedKey: string = snapshot.savedKeys[index].trim()
      const savedRecord: EncryptedAccountSession = snapshot.savedRecords[index]
      if (savedKey.length === 0 || savedKey === SESSION_KEY ||
        savedRecord.ciphertext !== snapshot.record.ciphertext ||
        savedRecord.nonce !== snapshot.record.nonce) {
        continue
      }
      matchingOwner = savedKey
      matchingCount += 1
    }
    return matchingCount === 1 ? matchingOwner : ''
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
          await store.executeSql(SQL_UPSERT_SESSION_OWNER, [
            SESSION_KEY,
            accountId,
            Date.now(),
          ])
        } else {
          await store.executeSql(SQL_DELETE_SESSION_OWNER, [SESSION_KEY])
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
    if (reasonCode !== 'terminal_401_replay_rejected' &&
      reasonCode !== 'terminal_401_refresh_token_rejected' &&
      reasonCode !== 'terminal_api_key_rejected' &&
      reasonCode !== 'terminal_api_key_identity_mismatch' &&
      reasonCode !== 'terminal_web_token_identity_mismatch') {
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
      let transactionOpen: boolean = false
      try {
        store.beginTransaction()
        transactionOpen = true
        await store.executeSql(SQL_DELETE_SESSION, [key])
        await store.executeSql(SQL_DELETE_SESSION_OWNER_BY_ACCOUNT, [SESSION_KEY, key])
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

  static clear(
    context: common.UIAbilityContext,
    savedAccountId: string = '',
  ): Promise<void> {
    return AccountSessionRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      let transactionOpen: boolean = false
      try {
        store.beginTransaction()
        transactionOpen = true
        await store.executeSql(SQL_DELETE_SESSION, [SESSION_KEY])
        if (savedAccountId.length > 0 && savedAccountId !== SESSION_KEY) {
          await store.executeSql(SQL_DELETE_SESSION, [savedAccountId])
        }
        await store.executeSql(SQL_DELETE_SESSION_OWNER, [SESSION_KEY])
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

  /** Replaces or merges the complete cross-device backup set after HUKS re-wrapping. */
  static restoreBackup(
    context: common.UIAbilityContext,
    primary: EncryptedAccountSession | null,
    savedKeys: string[],
    savedRecords: EncryptedAccountSession[],
    replace: boolean,
    preserveExistingPrimary: boolean = false,
    primaryOwnerId: string = '',
  ): Promise<void> {
    if (savedKeys.length !== savedRecords.length) {
      return Promise.reject(new Error('account_session_backup_shape_invalid'))
    }
    return AccountSessionRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      let transactionOpen: boolean = false
      let rows: relationalStore.ResultSet | null = null
      try {
        store.beginTransaction()
        transactionOpen = true
        let retainedPrimary: boolean = false
        if (preserveExistingPrimary) {
          rows = await store.querySql(SQL_SELECT_SESSION, [SESSION_KEY])
          retainedPrimary = rows.goToNextRow()
          try {
            rows.close()
          } catch (_error) {}
          rows = null
        }
        if (replace) {
          await store.executeSql(SQL_DELETE_ALL_SESSIONS)
          await store.executeSql(SQL_DELETE_ALL_SESSION_OWNERS)
          await store.executeSql(SQL_DELETE_VERIFICATION_REQUIRED, [SESSION_KEY])
        }
        let primaryWritten: boolean = false
        if (primary !== null) {
          await store.executeSql(preserveExistingPrimary ? SQL_INSERT_SESSION_IF_ABSENT : SQL_UPSERT_SESSION, [
            SESSION_KEY,
            primary.ciphertext,
            primary.nonce,
            Date.now(),
          ])
          primaryWritten = !preserveExistingPrimary || !retainedPrimary
        }
        for (let i: number = 0; i < savedKeys.length; i++) {
          await store.executeSql(preserveExistingPrimary ? SQL_INSERT_SESSION_IF_ABSENT : SQL_UPSERT_SESSION, [
            savedKeys[i],
            savedRecords[i].ciphertext,
            savedRecords[i].nonce,
            Date.now(),
          ])
        }
        if (primaryWritten) {
          if (primaryOwnerId.length > 0 && primaryOwnerId !== SESSION_KEY) {
            await store.executeSql(SQL_UPSERT_SESSION_OWNER, [
              SESSION_KEY,
              primaryOwnerId,
              Date.now(),
            ])
          } else {
            await store.executeSql(SQL_DELETE_SESSION_OWNER, [SESSION_KEY])
          }
        }
        store.commit()
        transactionOpen = false
      } catch (error) {
        if (transactionOpen) {
          store.rollBack()
        }
        throw error as Error
      } finally {
        if (rows !== null) {
          try {
            rows.close()
          } catch (_error) {}
        }
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
