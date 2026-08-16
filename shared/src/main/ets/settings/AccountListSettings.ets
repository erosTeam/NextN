import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { connectAccountList, AccountListState } from '../state/AccountListState'
import { NhAccountSessionService } from '../services/NhAccountSessionService'
import { NhAccountProfileService } from '../services/NhAccountProfileService'
import { connectAccountProfile } from '../state/AccountProfileState'
import { AccountProfileRepository } from '../storage/AccountProfileRepository'

const ACCOUNT_STORE: string = 'nextn_settings'
const ACCOUNT_IDS_KEY: string = 'account.list.ids'

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

  private static syncState(ids: string[]): void {
    const state: AccountListState = connectAccountList()
    state.accounts = ids.slice()
    state.activeAccountId = NhAccountProfileService.activeAccountId()
  }

  private static async readIds(context: common.UIAbilityContext): Promise<string[]> {
    const store: preferences.Preferences = await preferences.getPreferences(context, ACCOUNT_STORE)
    return AccountListSettings.parseIds(store.getSync(ACCOUNT_IDS_KEY, '') as string)
  }

  /** Mirror the persisted list into the reactive state (no mutation). */
  static async load(context: common.UIAbilityContext): Promise<void> {
    try {
      AccountListSettings.syncState(await AccountListSettings.readIds(context))
    } catch (error) {
      DiagnosticLogger.warn('auth', 'account_list_load_failed', (error as Error).message)
    }
  }

  /** Insert/refresh the currently-loaded account into the saved list. */
  static async recordActive(context: common.UIAbilityContext): Promise<void> {
    if (!NhAccountSessionService.isAuthenticated()) {
      return
    }
    const accountId: string = NhAccountProfileService.activeAccountId()
    if (accountId.length === 0) {
      // A visible login is authenticated but its display profile has not been
      // fetched yet. Refresh once so the saved record is keyed by a stable
      // non-secret account id, matching NextE's member-id keying.
      const refreshed: boolean = await NhAccountProfileService.refresh(context)
      if (!refreshed) {
        return
      }
    }
    const finalAccountId: string = NhAccountProfileService.activeAccountId()
    if (finalAccountId.length === 0) {
      return
    }
    const saved: boolean = await NhAccountSessionService.saveActiveAsSaved(context, finalAccountId)
    if (!saved) {
      return
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
        store.flushSync()
      }
      AccountListSettings.syncState(updated)
      DiagnosticLogger.info('auth', 'account_recorded', `count=${updated.length}`)
    } catch (error) {
      DiagnosticLogger.warn('auth', 'account_list_record_failed', (error as Error).message)
    }
  }

  /** Remove a saved account; returns the remaining account ids (saved order). */
  static async remove(context: common.UIAbilityContext, accountId: string): Promise<string[]> {
    const remaining: string[] = []
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, ACCOUNT_STORE)
      const ids: string[] = AccountListSettings.parseIds(
        store.getSync(ACCOUNT_IDS_KEY, '') as string,
      )
      const updated: string[] = []
      for (let i: number = 0; i < ids.length; i++) {
        if (ids[i] !== accountId) {
          updated.push(ids[i])
          remaining.push(ids[i])
        }
      }
      store.putSync(ACCOUNT_IDS_KEY, AccountListSettings.serializeIds(updated))
      store.flushSync()
      await NhAccountSessionService.removeSaved(context, accountId)
      AccountListSettings.syncState(updated)
    } catch (error) {
      DiagnosticLogger.warn('auth', 'account_list_remove_failed', (error as Error).message)
    }
    return remaining
  }

  static async savedAccountIds(context: common.UIAbilityContext): Promise<string[]> {
    return AccountListSettings.readIds(context)
  }

  /** Switches the active NH session and profile to a saved account. */
  static async switchTo(context: common.UIAbilityContext, accountId: string): Promise<boolean> {
    const switched: boolean = await NhAccountSessionService.switchToSaved(context, accountId)
    if (!switched) {
      return false
    }
    await NhAccountProfileService.switchTo(context, accountId)
    await AccountListSettings.load(context)
    return true
  }
}
