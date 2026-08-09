import { common } from '@kit.AbilityKit'
import { NhAccountProfile } from '../model/NhAccountProfile'
import { NhApiClient } from '../network/NhApiClient'
import { AccountProfileState, connectAccountProfile } from '../state/AccountProfileState'
import { connectAccountSession } from '../state/AccountSessionState'
import { AccountProfileRepository } from '../storage/AccountProfileRepository'
import { NhAccountSessionService } from './NhAccountSessionService'

/**
 * Coordinates the display-safe account identity separately from the sealed
 * browser session. Its fetch result contains only the four ErosN HTML-derived
 * fields and is guarded against a concurrent sign-out or newer promotion.
 */
export class NhAccountProfileService {
  private static restoreTask: Promise<boolean> | null = null
  private static refreshTask: Promise<boolean> | null = null

  static async restore(context: common.UIAbilityContext): Promise<boolean> {
    if (!NhAccountSessionService.isAuthenticated()) {
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
      // snapshot remains visible on transient first-party failures; a 401 is
      // handled by NhApiClient and clears the session/profile boundary.
      return false
    }
  }

  private static isCurrentSession(sessionRevision: number): boolean {
    return NhAccountSessionService.isAuthenticated() &&
      connectAccountSession().revision === sessionRevision
  }
}
