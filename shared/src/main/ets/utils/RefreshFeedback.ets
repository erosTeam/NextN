import { promptAction } from '@kit.ArkUI'
import { AppStrings } from '../i18n/AppStrings'

/**
 * Pull-refresh errors are interactive failures. Initial-load errors remain
 * caller-owned page state and must not be routed through this feedback path.
 */
export class RefreshFeedback {
  static notifyRefreshFailed(): void {
    try {
      promptAction.openToast({ message: AppStrings.get('common_refresh_failed') })
        .catch((_error: Error): void => {})
    } catch (_error) {}
  }
}
