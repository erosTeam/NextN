import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  NextNGroupedListSection,
  NextNListRow,
  SecondaryListScaffold,
  SYNC_STATUS_FAILED,
  SYNC_STATUS_OK,
  SyncSettings,
  SyncSettingsSnapshot,
  SyncSettingsState,
  ThemeTokens,
  connectSyncSettings,
} from 'shared'

/**
 * WebDAV sync overview destination, ported from NextE's SyncSettingsPage with
 * Huawei Cloud removed (user scope: WebDAV only, plan section 2.2 / 9). The
 * entry layer owns the destination title bar and route; this page only
 * exposes the WebDAV row action through onOpenWebDavSyncSettings.
 */
@ComponentV2
export struct SyncSettingsPage {
  @Local settings: SyncSettingsState = connectSyncSettings()
  @Param scroller: Scroller = new Scroller()
  @Event onOpenWebDavSyncSettings?: () => void

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private snapshot(): SyncSettingsSnapshot {
    return SyncSettings.current()
  }

  private setDataset(field: string, enabled: boolean): void {
    const snapshot = this.snapshot()
    if (field === 'readProgress') {
      snapshot.datasetReadProgress = enabled
    } else if (field === 'viewedHistory') {
      snapshot.datasetViewedHistory = enabled
    } else if (field === 'searchHistory') {
      snapshot.datasetSearchHistory = enabled
    } else if (field === 'quickSearches') {
      snapshot.datasetQuickSearches = enabled
    } else if (field === 'homeSubtabs') {
      snapshot.datasetHomeSubtabs = enabled
    } else if (field === 'localBlock') {
      snapshot.datasetLocalBlock = enabled
    } else if (field === 'settingsTables') {
      snapshot.datasetSettingsTables = enabled
    }
    SyncSettings.save(this.ctx(), snapshot)
  }

  private webdavStatusText(): string {
    if (this.settings.webdavSyncing) {
      return AppStrings.get('sync_status_running')
    }
    if (!this.settings.webdavEnabled) {
      return AppStrings.get('sync_provider_disabled')
    }
    if (this.settings.webdavUrl.trim().length <= 0) {
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

  @Builder
  private RowDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(ThemeTokens.DIVIDER)
      .margin({ left: ThemeTokens.SPACE_MD })
  }

  @Builder
  private DatasetRow(
    title: string,
    subtitle: string,
    checked: boolean,
    field: string,
  ) {
    NextNListRow({
      title: title,
      subtitle: subtitle,
      showChevron: false,
      hasSwitch: true,
      checked: checked,
      onSwitchChange: (value: boolean) => {
        this.setDataset(field, value)
      },
    })
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
              subtitle: this.webdavStatusText(),
              leadingIcon: $r('sys.symbol.externaldrive'),
              showChevron: true,
              onAction: () => {
                if (this.onOpenWebDavSyncSettings) {
                  this.onOpenWebDavSyncSettings()
                }
              },
            })
          }
        }
        ListItem() {
          NextNGroupedListSection() {
            this.DatasetRow(
              AppStrings.get('sync_dataset_read_progress'),
              AppStrings.get('sync_dataset_read_progress_hint'),
              this.settings.datasetReadProgress,
              'readProgress',
            )
            this.RowDivider()
            this.DatasetRow(
              AppStrings.get('sync_dataset_viewed_history'),
              AppStrings.get('sync_dataset_viewed_history_hint'),
              this.settings.datasetViewedHistory,
              'viewedHistory',
            )
            this.RowDivider()
            this.DatasetRow(
              AppStrings.get('sync_dataset_search_history'),
              AppStrings.get('sync_dataset_search_history_hint'),
              this.settings.datasetSearchHistory,
              'searchHistory',
            )
            this.RowDivider()
            this.DatasetRow(
              AppStrings.get('sync_dataset_quick_searches'),
              AppStrings.get('sync_dataset_quick_searches_hint'),
              this.settings.datasetQuickSearches,
              'quickSearches',
            )
            this.RowDivider()
            this.DatasetRow(
              AppStrings.get('sync_dataset_home_subtabs'),
              AppStrings.get('sync_dataset_home_subtabs_hint'),
              this.settings.datasetHomeSubtabs,
              'homeSubtabs',
            )
            this.RowDivider()
            this.DatasetRow(
              AppStrings.get('sync_dataset_local_block'),
              AppStrings.get('sync_dataset_local_block_hint'),
              this.settings.datasetLocalBlock,
              'localBlock',
            )
            this.RowDivider()
            this.DatasetRow(
              AppStrings.get('sync_dataset_settings_tables'),
              AppStrings.get('sync_dataset_settings_tables_hint'),
              this.settings.datasetSettingsTables,
              'settingsTables',
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
