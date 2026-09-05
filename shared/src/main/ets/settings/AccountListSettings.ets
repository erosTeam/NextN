import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { connectAccountList, AccountListState } from '../state/AccountListState'
import { NhAccountSessionService } from '../services/NhAccountSessionService'
import { NhAccountProfileService } from '../services/NhAccountProfileService'
import { connectAccountProfile } from '../state/AccountProfileState'
import { AccountProfileRepository } from '../storage/AccountProfileRepository'
import {
  AccountSessionRepository,
  AccountSessionRestoreSnapshot,
} from '../storage/AccountSessionRepository'

const ACCOUNT_STORE: string = 'nextn_settings'
const ACCOUNT_IDS_KEY: string = 'account.list.ids'
const ACTIVE_ACCOUNT_ID_KEY: string = 'account.list.activeId'

class AccountListSnapshot {
  ids: string[] = []
  activeAccountId: string = ''
}

/**
 * Persistence for the saved-accounts list, layered ADDITIVELY on top of the
 * single-active NH session: each saved account is one HUKS-sealed session
 * envelope stored under its account id (a non-secret profile user id) in the
 * account_session table. The ACTIVE account is whichever envelope currently
 * lives in the 'primary' row — recording/removing here never changes how the
 * active account logs in or restores, so login persistence can't break.
 * Switching loads a saved envelope into the active row through
 * NhAccountSessionService. This Preferences layer only stores account ids in
 * order; it never contains a cookie, token, or sealed envelope.
 */
export class AccountListSettings {
  private static parseIds(raw: string): string[] {
    const ids: string[] = []
    if (raw.trim().length === 0) {
      return ids
    }
    try {
      const parsed: Object = JSON.parse(raw) as Object
      if (Array.isArray(parsed)) {
        const values: Object[] = parsed as Object[]
        for (let i: number = 0; i < values.length; i++) {
          const value: Object = values[i]
          if (typeof value === 'string' && (value as string).trim().length > 0) {
            ids.push((value as string).trim())
          }
        }
      }
    } catch (_error) {
      DiagnosticLogger.warn('auth', 'account_list_parse_failed', 'invalid ids payload')
    }
    return ids
  }

  private static serializeIds(ids: string[]): string {
    return JSON.stringify(ids)
  }

  private static normalizedActiveAccountId(
    ids: string[],
    value: string,
    primaryOwnerId: string,
    primaryPresent: boolean,
  ): string {
    const retainedOwner: string = primaryOwnerId.trim()
    if (primaryPresent) {
      return retainedOwner.length > 0 && ids.indexOf(retainedOwner) >= 0
        ? retainedOwner
        : ''
    }
    const candidate: string = value.trim()
    if (candidate.length > 0 && ids.indexOf(candidate) >= 0) {
      return candidate
    }
    return ids.length === 1 ? ids[0] : ''
  }

  private static syncState(snapshot: AccountListSnapshot): void {
    const state: AccountListState = connectAccountList()
    state.accounts = snapshot.ids.slice()
    state.activeAccountId = snapshot.activeAccountId
    NhAccountSessionService.setActiveSavedAccountId(snapshot.activeAccountId)
  }

  private static async readSnapshot(context: common.UIAbilityContext): Promise<AccountListSnapshot> {
    const store: preferences.Preferences = await preferences.getPreferences(context, ACCOUNT_STORE)
    const snapshot: AccountListSnapshot = new AccountListSnapshot()
    const rawIds: string = store.getSync(ACCOUNT_IDS_KEY, '') as string
    snapshot.ids = AccountListSettings.parseIds(rawIds)
    const rawActive: string = store.getSync(ACTIVE_ACCOUNT_ID_KEY, '') as string
    const sessionSnapshot: AccountSessionRestoreSnapshot =
      await AccountSessionRepository.loadForRestore(context)
    const primaryPresent: boolean = sessionSnapshot.record !== null
    const primaryOwnerId: string = AccountSessionRepository.resolvePrimaryOwner(sessionSnapshot)
    const savedIds: Set<string> = new Set<string>(sessionSnapshot.savedKeys)
    snapshot.ids = snapshot.ids.filter((id: string): boolean => savedIds.has(id))
    if (primaryOwnerId.length > 0 && savedIds.has(primaryOwnerId) &&
      snapshot.ids.indexOf(primaryOwnerId) < 0) {
      snapshot.ids.push(primaryOwnerId)
    }
    snapshot.activeAccountId = AccountListSettings.normalizedActiveAccountId(
      snapshot.ids,
      rawActive,
      primaryOwnerId,
      primaryPresent,
    )
    const serializedIds: string = AccountListSettings.serializeIds(snapshot.ids)
    let changed: boolean = false
    if (serializedIds !== rawIds) {
      store.putSync(ACCOUNT_IDS_KEY, serializedIds)
      changed = true
    }
    if (snapshot.activeAccountId !== rawActive) {
      if (snapshot.activeAccountId.length > 0) {
        store.putSync(ACTIVE_ACCOUNT_ID_KEY, snapshot.activeAccountId)
      } else {
        store.deleteSync(ACTIVE_ACCOUNT_ID_KEY)
      }
      changed = true
    }
    if (changed) {
      store.flushSync()
    }
    return snapshot
  }

  /** Mirror the persisted list into the reactive state (no mutation). */
  static async load(context: common.UIAbilityContext): Promise<void> {
    try {
      AccountListSettings.syncState(await AccountListSettings.readSnapshot(context))
    } catch (error) {
      DiagnosticLogger.warn('auth', 'account_list_load_failed', (error as Error).message)
    }
  }

  /**
   * Removes restored list projections that have no usable sealed credential.
   * This is called after portable backup import, where legacy rotating Web
   * sessions are intentionally excluded while API-key accounts remain.
   */
  static async reconcileRestoredCredentialIds(
    context: common.UIAbilityContext,
    credentialIds: string[],
    targetPrimaryPresent: boolean = false,
    retainedPrimaryOwnerId: string = '',
  ): Promise<void> {
    const allowed: Set<string> = new Set<string>(credentialIds)
    const before: AccountListSnapshot = await AccountListSettings.readSnapshot(context)
    const ids: string[] = before.ids.filter((id: string): boolean => allowed.has(id))
    credentialIds.forEach((id: string): void => {
      if (ids.indexOf(id) < 0) {
        ids.push(id)
      }
    })
    const activeAccountId: string = AccountListSettings.restoredActiveAccountId(
      ids,
      before.activeAccountId,
      targetPrimaryPresent,
      retainedPrimaryOwnerId,
    )
    const store: preferences.Preferences = await preferences.getPreferences(context, ACCOUNT_STORE)
    store.putSync(ACCOUNT_IDS_KEY, AccountListSettings.serializeIds(ids))
    if (activeAccountId.length > 0) {
      store.putSync(ACTIVE_ACCOUNT_ID_KEY, activeAccountId)
    } else {
      store.deleteSync(ACTIVE_ACCOUNT_ID_KEY)
    }
    store.flushSync()
    const snapshot: AccountListSnapshot = new AccountListSnapshot()
    snapshot.ids = ids
    snapshot.activeAccountId = activeAccountId
    AccountListSettings.syncState(snapshot)
  }

  /** Never infer that an imported owner owns a retained target primary. */
  static restoredActiveAccountId(
    ids: string[],
    currentActiveAccountId: string,
    targetPrimaryPresent: boolean,
    retainedPrimaryOwnerId: string = '',
  ): string {
    const retained: string = retainedPrimaryOwnerId.trim()
    if (targetPrimaryPresent && retained.length > 0 && ids.indexOf(retained) >= 0) {
      return retained
    }
    const current: string = currentActiveAccountId.trim()
    if (current.length > 0 && ids.indexOf(current) >= 0) {
      return current
    }
    return !targetPrimaryPresent && ids.length > 0 ? ids[0] : ''
  }

  /** Insert/refresh the currently-loaded account into the saved list. */
  static async recordActive(context: common.UIAbilityContext): Promise<boolean> {
    if (!NhAccountSessionService.isAuthenticated()) {
      return false
    }
    const accountId: string = NhAccountProfileService.activeAccountId()
    if (accountId.length === 0) {
      // A visible login is authenticated but its display profile has not been
      // fetched yet. Refresh once so the saved record is keyed by a stable
      // non-secret account id, matching NextE's member-id keying.
      const refreshed: boolean = await NhAccountProfileService.refresh(context)
      if (!refreshed) {
        return false
      }
    }
    const finalAccountId: string = NhAccountProfileService.activeAccountId()
    if (finalAccountId.length === 0) {
      return false
    }
    const saved: boolean = await NhAccountSessionService.saveActiveAsSaved(context, finalAccountId)
    if (!saved) {
      return false
    }
    await AccountProfileRepository.saveByKey(context, finalAccountId, connectAccountProfile().snapshot())
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, ACCOUNT_STORE)
      const raw: string = store.getSync(ACCOUNT_IDS_KEY, '') as string
      const ids: string[] = AccountListSettings.parseIds(raw)
      const updated: string[] = []
      let found: boolean = false
      for (let i: number = 0; i < ids.length; i++) {
        if (ids[i] === finalAccountId) {
          updated.push(finalAccountId)
          found = true
        } else {
          updated.push(ids[i])
        }
      }
      if (!found) {
        updated.push(finalAccountId)
      }
      const serialized: string = AccountListSettings.serializeIds(updated)
      if (raw !== serialized) {
        store.putSync(ACCOUNT_IDS_KEY, serialized)
      }
      store.putSync(ACTIVE_ACCOUNT_ID_KEY, finalAccountId)
      store.flushSync()
      const snapshot: AccountListSnapshot = new AccountListSnapshot()
      snapshot.ids = updated
      snapshot.activeAccountId = finalAccountId
      AccountListSettings.syncState(snapshot)
      DiagnosticLogger.info('auth', 'account_recorded', `count=${updated.length}`)
      return true
    } catch (error) {
      DiagnosticLogger.warn('auth', 'account_list_record_failed', (error as Error).message)
      return false
    }
  }

  /** Remove a saved account; returns the remaining account ids (saved order). */
  static async remove(context: common.UIAbilityContext, accountId: string): Promise<string[]> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, ACCOUNT_STORE)
      const before: AccountListSnapshot = await AccountListSettings.readSnapshot(context)
      const ids: string[] = before.ids
      const currentActive: string = before.activeAccountId
      const updated: string[] = ids.filter((id: string): boolean => id !== accountId)
      let nextActive: string = currentActive
      if (currentActive === accountId) {
        if (updated.length > 0) {
          if (!await AccountListSettings.switchTo(context, updated[0])) {
            throw new Error('account_switch_failed')
          }
          nextActive = updated[0]
        } else {
          // Delete the active primary row and its last saved fallback in the
          // same RDB transaction so a crash cannot restore a signed-out account.
          await NhAccountSessionService.clear(context, accountId)
          nextActive = ''
        }
      }
      store.putSync(ACCOUNT_IDS_KEY, AccountListSettings.serializeIds(updated))
      if (nextActive.length > 0) {
        store.putSync(ACTIVE_ACCOUNT_ID_KEY, nextActive)
      } else {
        store.deleteSync(ACTIVE_ACCOUNT_ID_KEY)
      }
      store.flushSync()
      await NhAccountSessionService.removeSaved(context, accountId)
      const snapshot: AccountListSnapshot = new AccountListSnapshot()
      snapshot.ids = updated
      snapshot.activeAccountId = nextActive
      AccountListSettings.syncState(snapshot)
      return updated
    } catch (error) {
      DiagnosticLogger.warn('auth', 'account_list_remove_failed', (error as Error).message)
      throw error as Error
    }
  }

  static async savedAccountIds(context: common.UIAbilityContext): Promise<string[]> {
    return (await AccountListSettings.readSnapshot(context)).ids
  }

  /** Switches the active NH session and profile to a saved account. */
  static async switchTo(context: common.UIAbilityContext, accountId: string): Promise<boolean> {
    const switched: boolean = await NhAccountSessionService.switchToSaved(context, accountId)
    if (!switched) {
      return false
    }
    // The sealed primary row and the selected saved-account id must describe
    // the same owner before any fallible network/profile work begins. A
    // profile outage must not leave account A selected while native requests
    // already use account B's credential generation.
    const store: preferences.Preferences = await preferences.getPreferences(context, ACCOUNT_STORE)
    store.putSync(ACTIVE_ACCOUNT_ID_KEY, accountId)
    store.flushSync()
    await AccountListSettings.load(context)
    const profileSwitched: boolean = await NhAccountProfileService.switchTo(context, accountId)
    if (!profileSwitched) {
      DiagnosticLogger.warn('auth', 'account_switch_profile_failed', 'profile unavailable')
    } else {
      DiagnosticLogger.info('auth', 'account_switch_profile_completed', 'profile persisted')
    }
    DiagnosticLogger.info('auth', 'account_switch_completed', 'selection persisted')
    return true
  }
}
