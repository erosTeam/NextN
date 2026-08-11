import { common } from '@kit.AbilityKit'
import { notificationManager } from '@kit.NotificationKit'
import { AppStrings } from '../i18n/AppStrings'
import { DownloadSettingsService } from './DownloadSettingsService'

const DOWNLOAD_COMPLETE_NOTIFICATION_ID: number = 1301

function completionText(title: string): string {
  const trimmed: string = title.trim()
  const fallback: string = AppStrings.get('settings_download')
  return AppStrings.format('download_notify_complete_body', [
    trimmed.length > 0 ? trimmed : fallback,
  ])
}

/**
 * Default-off system completion notice for the local download queue.
 *
 * Publication deliberately has no queue, task, network, or retry side
 * effects: a disabled permission or a system failure leaves the completed
 * private download exactly as it was after its durable task write.
 */
export class DownloadNotificationService {
  static async requestEnable(context: common.UIAbilityContext): Promise<void> {
    try {
      if (await notificationManager.isNotificationEnabled()) {
        return
      }
      await notificationManager.requestEnableNotification(context)
    } catch (_error) {
      console.warn('NextN completion-notification permission request failed.')
    }
  }

  static async publishDownloadComplete(title: string): Promise<void> {
    if (!DownloadSettingsService.snapshot().notifyOnComplete) {
      return
    }
    try {
      if (!await notificationManager.isNotificationEnabled()) {
        return
      }
      const request: notificationManager.NotificationRequest = {
        id: DOWNLOAD_COMPLETE_NOTIFICATION_ID,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: AppStrings.get('download_notify_complete_title'),
            text: completionText(title),
          },
        },
      }
      await notificationManager.publish(request)
    } catch (_error) {
      console.warn('NextN completion notification publish failed.')
    }
  }
}
