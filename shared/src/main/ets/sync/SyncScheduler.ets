import { common } from '@kit.AbilityKit'
import { WebDavSyncScheduler } from './WebDavSyncScheduler'

export class SyncScheduler {
  /**
   * Backup restore is a local transaction: it must not start a provider run with partially restored
   * settings or publish its snapshot before the user explicitly resumes sync later.
   */
  static suspendAutomaticSync(): void {
    WebDavSyncScheduler.suspendAutomaticSync()
  }

  static resumeAutomaticSync(): void {
    WebDavSyncScheduler.resumeAutomaticSync()
  }

  static rememberContext(context: common.UIAbilityContext): void {
    WebDavSyncScheduler.rememberContext(context)
  }

  static requestAfterLocalWrite(context: common.UIAbilityContext, reason: string): void {
    WebDavSyncScheduler.requestAfterLocalWrite(context, reason)
  }

  static requestAfterForeground(context: common.UIAbilityContext, reason: string): void {
    WebDavSyncScheduler.requestAfterForeground(context, reason)
  }
}
