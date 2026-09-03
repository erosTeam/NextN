import { common } from '@kit.AbilityKit'
import { KeyboardAvoidMode } from '@kit.ArkUI'
import {
  AppStrings,
  DiagnosticLogger,
  NextNGroupedListSection,
  NextNListRow,
  SecondaryListScaffold,
  SettingsTextField,
  SYNC_STATUS_FAILED,
  SYNC_STATUS_OK,
  SyncSettings,
  SyncSettingsSnapshot,
  SyncSettingsState,
  ThemeTokens,
  WebDavSyncConfig,
  WebDavSyncService,
  connectSyncSettings,
} from 'shared'

/**
 * WebDAV sync detail destination, ported from NextE's WebDavSyncSettingsPage.
 * The entry layer owns the destination title bar and route.
 */
@ComponentV2
export struct WebDavSyncSettingsPage {
  @Local settings: SyncSettingsState = connectSyncSettings()
  @Local webdavUrlDraft: string = ''
  @Local webdavUsernameDraft: string = ''
  @Local webdavPasswordDraft: string = ''
  @Param scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
    this.webdavUrlDraft = this.settings.webdavUrl
    this.webdavUsernameDraft = this.settings.webdavUsername
    this.webdavPasswordDraft = this.settings.webdavPassword
  }

  aboutToDisappear(): void {
    SyncSettings.flushWebDavConfig(this.ctx(), this.snapshot())
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
  }

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private snapshot(): SyncSettingsSnapshot {
    const snapshot = SyncSettings.current()
    snapshot.webdavUrl = this.webdavUrlDraft
    snapshot.webdavUsername = this.webdavUsernameDraft
    snapshot.webdavPassword = this.webdavPasswordDraft
    return snapshot
  }

  private saveWebDavConfig(): void {
    SyncSettings.saveWebDavConfig(this.ctx(), this.snapshot())
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message })
  }

  private toggleWebDav(enabled: boolean): void {
    const snapshot = this.snapshot()
    snapshot.webdavEnabled = enabled
    SyncSettings.flushWebDavConfig(this.ctx(), snapshot)
  }

  private canSync(): boolean {
    return !this.settings.webdavSyncing && this.settings.webdavEnabled &&
      this.webdavUrlDraft.trim().length > 0
  }

  private statusText(): string {
    if (this.settings.webdavSyncing) {
      return AppStrings.get('sync_status_running')
    }
    if (!this.settings.webdavEnabled) {
      return AppStrings.get('sync_provider_disabled')
    }
    if (this.webdavUrlDraft.trim().length <= 0) {
      return AppStrings.get('sync_webdav_url_required')
    }
    if (this.settings.lastStatus === SYNC_STATUS_OK) {
      return AppStrings.format('sync_status_success', [this.formatTime(this.settings.lastRunAt)])
    }
    if (this.settings.lastStatus === SYNC_STATUS_FAILED) {
      if (this.settings.lastDetail.length > 0) {
        return `${AppStrings.get('sync_now_failed')}: ${this.settings.lastDetail}`
      }
      return AppStrings.format('sync_status_failed', [this.formatTime(this.settings.lastRunAt)])
    }
    return AppStrings.get('sync_status_never')
  }

  private formatTime(value: number): string {
    if (value <= 0) {
      return AppStrings.get('unknown_time')
    }
    const date = new Date(value)
    const year = date.getFullYear().toString().padStart(4, '0')
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hour = date.getHours().toString().padStart(2, '0')
    const minute = date.getMinutes().toString().padStart(2, '0')
    return `${year}-${month}-${day} ${hour}:${minute}`
  }

  private syncNow(): void {
    if (!this.canSync()) {
      if (this.webdavUrlDraft.trim().length <= 0) {
        this.toast(AppStrings.get('sync_webdav_url_required'))
      }
      return
    }
    SyncSettings.flushWebDavConfig(this.ctx(), this.snapshot())
    const config = new WebDavSyncConfig()
    config.directoryUrl = this.webdavUrlDraft.trim()
    config.username = this.webdavUsernameDraft.trim()
    config.password = this.webdavPasswordDraft
    config.selection = SyncSettings.selection(this.snapshot())
    DiagnosticLogger.info('sync', 'manual_webdav_sync_start', 'provider=webdav')
    WebDavSyncService.syncNow(this.ctx(), config)
      .then(() => {
        SyncSettings.markRun(this.ctx(), SYNC_STATUS_OK)
        DiagnosticLogger.info('sync', 'manual_webdav_sync_success', 'provider=webdav')
        this.toast(AppStrings.get('sync_now_done'))
      })
      .catch((error: Error) => {
        SyncSettings.markRun(this.ctx(), SYNC_STATUS_FAILED)
        DiagnosticLogger.warn('sync', 'manual_webdav_sync_failed', error.message)
        this.toast(AppStrings.get('sync_now_failed'))
      })
  }

  @Builder
  private RowDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(ThemeTokens.DIVIDER)
      .margin({ left: ThemeTokens.SPACE_MD })
  }

  @Builder
  private TextInputRow(
    label: string,
    placeholder: string,
    secret: boolean,
    field: string,
  ) {
    if (field === 'url') {
      SettingsTextField({
        label: label,
        value: this.webdavUrlDraft,
        placeholder: placeholder,
        inputType: secret ? InputType.Password : InputType.Normal,
        onChange: (value: string): void => {
          this.webdavUrlDraft = value
          this.saveWebDavConfig()
        },
      })
    } else if (field === 'username') {
      SettingsTextField({
        label: label,
        value: this.webdavUsernameDraft,
        placeholder: placeholder,
        inputType: secret ? InputType.Password : InputType.Normal,
        onChange: (value: string): void => {
          this.webdavUsernameDraft = value
          this.saveWebDavConfig()
        },
      })
    } else {
      SettingsTextField({
        label: label,
        value: this.webdavPasswordDraft,
        placeholder: placeholder,
        inputType: secret ? InputType.Password : InputType.Normal,
        onChange: (value: string): void => {
          this.webdavPasswordDraft = value
          this.saveWebDavConfig()
        },
      })
    }
  }

  @Builder
  private SyncingSuffix() {
    LoadingProgress()
      .width(22)
      .height(22)
      .color(ThemeTokens.BRAND)
  }

  build() {
    Column() {
      SecondaryListScaffold({
        scroller: this.scroller,
        bottomPadding: ThemeTokens.SPACE_XL,
        alwaysEnableEdgeSpring: true,
      }) {
        ListItem() {
          NextNGroupedListSection() {
            NextNListRow({
              title: AppStrings.get('sync_webdav'),
              subtitle: AppStrings.get('sync_webdav_hint'),
              leadingIcon: $r('sys.symbol.externaldrive'),
              showChevron: false,
              hasSwitch: true,
              checked: this.settings.webdavEnabled,
              onSwitchChange: (value: boolean) => {
                this.toggleWebDav(value)
              },
            })
            this.RowDivider()
            if (this.settings.webdavSyncing) {
              NextNListRow({
                title: AppStrings.get('sync_webdav_now'),
                subtitle: this.statusText(),
                leadingIcon: $r('sys.symbol.arrow_clockwise'),
                showChevron: false,
                isEnabled: false,
                useCustomTrailing: true,
                customTrailing: () => {
                  this.SyncingSuffix()
                },
              })
            } else {
              NextNListRow({
                title: AppStrings.get('sync_webdav_now'),
                subtitle: this.statusText(),
                leadingIcon: $r('sys.symbol.arrow_clockwise'),
                showChevron: false,
                isEnabled: this.canSync(),
                onAction: () => {
                  this.syncNow()
                },
              })
            }
          }
        }
        ListItem() {
          NextNGroupedListSection() {
            this.TextInputRow(
              AppStrings.get('sync_webdav_url'),
              AppStrings.get('sync_webdav_url_hint'),
              false,
              'url',
            )
            this.RowDivider()
            this.TextInputRow(
              AppStrings.get('sync_webdav_username'),
              AppStrings.get('sync_webdav_username_hint'),
              false,
              'username',
            )
            this.RowDivider()
            this.TextInputRow(
              AppStrings.get('sync_webdav_password'),
              AppStrings.get('sync_webdav_password_hint'),
              true,
              'password',
            )
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE_SUB)
  }
}
