import { common } from '@kit.AbilityKit'
import { NhAccountProfile } from '../model/NhAccountProfile'
import { NhApiClient } from '../network/NhApiClient'
import { AccountProfileState, connectAccountProfile } from '../state/AccountProfileState'
import { connectAccountSession } from '../state/AccountSessionState'
import { AccountProfileRepository } from '../storage/AccountProfileRepository'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { NhAccountSessionService } from './NhAccountSessionService'

/**
 * Coordinates the display-safe account identity separately from the sealed
 * browser session. Its fetch result contains only the four ErosN HTML-derived
 * fields and is guarded against a concurrent sign-out or newer promotion.
 */
export class NhAccountProfileService {
  private static restoreTask: Promise<boolean> | null = null
  private static refreshTask: Promise<boolean> | null = null

  /** Stable non-secret identity of the active account; '' when unknown. */
  static activeAccountId(): string {
    return connectAccountProfile().snapshot().userId
  }

  /** Restores the target account's display snapshot after a session switch. */
  static async switchTo(context: common.UIAbilityContext, accountId: string): Promise<boolean> {
    const sessionRevision: number = connectAccountSession().revision
    try {
      const profile: NhAccountProfile | null = await AccountProfileRepository.loadByKey(context, accountId)
      if (profile !== null && NhAccountProfileService.isCurrentSession(sessionRevision)) {
        const saved: boolean = await AccountProfileRepository.saveIfCurrent(
          context,
          profile,
          (): boolean => NhAccountProfileService.isCurrentSession(sessionRevision),
        )
        if (!saved || !NhAccountProfileService.isCurrentSession(sessionRevision)) {
          return false
        }
        connectAccountProfile().replace(profile)
        return true
      }
    } catch (_error) {
      DiagnosticLogger.warn('account', 'profile_switch_restore_failed', '')
    }
    return NhAccountProfileService.refresh(context)
  }

  static async restore(context: common.UIAbilityContext): Promise<boolean> {
    if (!NhAccountSessionService.hasRetainedAccount()) {
      connectAccountProfile().clear()
      return false
    }
    if (NhAccountProfileService.restoreTask !== null) {
      return await NhAccountProfileService.restoreTask
    }
    const sessionRevision: number = connectAccountSession().revision
    const task: Promise<boolean> = NhAccountProfileService.restoreInternal(context, sessionRevision)
    NhAccountProfileService.restoreTask = task
    try {
      return await task
    } finally {
      if (NhAccountProfileService.restoreTask === task) {
        NhAccountProfileService.restoreTask = null
      }
    }
  }

  static async refresh(context: common.UIAbilityContext): Promise<boolean> {
    if (!NhAccountSessionService.isAuthenticated()) {
      return false
    }
    if (NhAccountProfileService.refreshTask !== null) {
      await NhAccountProfileService.refreshTask.catch((): void => {})
      if (!NhAccountSessionService.isAuthenticated()) {
        return false
      }
    }
    const sessionRevision: number = connectAccountSession().revision
    const task: Promise<boolean> = NhAccountProfileService.refreshInternal(context, sessionRevision)
    NhAccountProfileService.refreshTask = task
    try {
      return await task
    } finally {
      if (NhAccountProfileService.refreshTask === task) {
        NhAccountProfileService.refreshTask = null
      }
    }
  }

  private static async restoreInternal(
    context: common.UIAbilityContext,
    sessionRevision: number,
  ): Promise<boolean> {
    try {
      const profile: NhAccountProfile | null = await AccountProfileRepository.load(context)
      if (!NhAccountProfileService.isCurrentSession(sessionRevision) || profile === null) {
        return false
      }
      connectAccountProfile().replace(profile)
      return true
    } catch (_error) {
      return false
    }
  }

  private static async refreshInternal(
    context: common.UIAbilityContext,
    sessionRevision: number,
  ): Promise<boolean> {
    try {
      const profile: NhAccountProfile = await NhApiClient.accountProfile()
      if (!NhAccountProfileService.isCurrentSession(sessionRevision)) {
        return false
      }
      const saved: boolean = await AccountProfileRepository.saveIfCurrent(
        context,
        profile,
        (): boolean => NhAccountProfileService.isCurrentSession(sessionRevision),
      )
      if (!saved || !NhAccountProfileService.isCurrentSession(sessionRevision)) {
        return false
      }
      connectAccountProfile().replace(profile)
      return true
    } catch (_error) {
      // Profile refresh is deliberately best-effort. A retained trusted
      // snapshot remains visible on transient first-party failures. A 401 is
      // repaired and recorded by NhApiClient without changing account ownership.
      return false
    }
  }

  private static isCurrentSession(sessionRevision: number): boolean {
    return NhAccountSessionService.hasRetainedAccount() &&
      connectAccountSession().revision === sessionRevision
  }
}
