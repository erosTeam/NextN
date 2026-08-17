import { bundleManager, common, Want } from '@kit.AbilityKit'
import { AdvancedDialogV2Button, CustomContentDialogV2, LengthMetrics } from '@kit.ArkUI'
import {
  AppStrings,
  AppRelease,
  AppReleaseCacheSnapshot,
  AppReleaseService,
  DiagnosticLogger,
  NextNGroupedListSection,
  NextNListRow,
  NextNSectionHeader,
  ReleaseNotesPager,
  SecondaryListScaffold,
  ThemeTokens,
} from 'shared'

@ComponentV2
export struct AboutPage {
  @Local appVersion: string = ''
  @Local updateChecking: boolean = false;
  @Local updateChecked: boolean = false;
  @Local latestVersion: string = '';
  @Local canUpdate: boolean = false;
  @Local releaseHistory: AppRelease[] = [];
  @Local selectedReleaseIndex: number = 0;
  @Param scroller: Scroller = new Scroller()
  private updateDialogId: number = -1;
  private releaseSnapshot: AppReleaseCacheSnapshot = new AppReleaseCacheSnapshot();
  private releaseLoadGeneration: number = 0;

  aboutToAppear(): void {
    bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      .then((info) => {
        this.appVersion = info.versionName
        this.applyReleaseSnapshot(this.releaseSnapshot)
      })
      .catch((error: Error) => {
        DiagnosticLogger.warn('settings', 'about_bundle_info_failed', error.message)
        this.applyReleaseSnapshot(this.releaseSnapshot)
      })
    this.loadReleaseHistory()
  }

  private versionText(): string {
    if (this.appVersion.length > 0) {
      return this.appVersion
    }
    return '1.0.0'
  }

  private updateSubtitle(): string {
    if (this.updateChecked && this.latestVersion.length > 0) {
      if (this.canUpdate) {
        return AppStrings.get('about_update_available').replace('%s', this.latestVersion)
      }
      return AppStrings.get('about_update_latest').replace('%s', this.latestVersion)
    }
    if (this.updateChecking) {
      return AppStrings.get('about_update_checking')
    }
    return AppStrings.get('about_update_hint')
  }

  private ctx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private toast(message: ResourceStr): void {
    this.getUIContext().getPromptAction()
      .openToast({ message: message })
      .catch((_error: Error) => {})
  }

  private loadReleaseHistory(): void {
    const generation: number = this.releaseLoadGeneration + 1
    this.releaseLoadGeneration = generation
    const context: common.UIAbilityContext = this.ctx()
    AppReleaseService.loadCached(context)
      .then((cached: AppReleaseCacheSnapshot) => {
        if (!this.isCurrentReleaseLoad(generation)) {
          return cached
        }
        this.applyReleaseSnapshot(cached)
        this.updateChecking = true
        return AppReleaseService.refresh(context, cached, false)
      })
      .then((snapshot: AppReleaseCacheSnapshot) => {
        if (this.isCurrentReleaseLoad(generation)) {
          this.applyReleaseSnapshot(snapshot)
        }
      })
      .catch((error: Error) => {
        if (this.isCurrentReleaseLoad(generation)) {
          DiagnosticLogger.warn('settings', 'about_release_refresh_failed', error.message)
        }
      })
      .finally(() => {
        if (this.isCurrentReleaseLoad(generation)) {
          this.updateChecking = false
        }
      })
  }

  private loadReleaseHistoryForDialog(): void {
    const generation: number = this.releaseLoadGeneration + 1
    this.releaseLoadGeneration = generation
    this.updateChecking = true
    const context: common.UIAbilityContext = this.ctx()
    AppReleaseService.loadCached(context)
      .then((cached: AppReleaseCacheSnapshot) => {
        if (cached.releases.length > 0) {
          return cached
        }
        return AppReleaseService.refresh(context, cached, true)
      })
      .then((snapshot: AppReleaseCacheSnapshot) => {
        if (!this.isCurrentReleaseLoad(generation)) {
          return
        }
        this.applyReleaseSnapshot(snapshot)
        if (this.releaseHistory.length === 0) {
          throw new Error('release history unavailable')
        }
        this.showUpdateDialog()
      })
      .catch((error: Error) => {
        if (this.isCurrentReleaseLoad(generation)) {
          DiagnosticLogger.warn('settings', 'about_release_open_failed', error.message)
          this.toast(AppStrings.get('about_update_failed') + ': ' + error.message)
        }
      })
      .finally(() => {
        if (this.isCurrentReleaseLoad(generation)) {
          this.updateChecking = false
        }
      })
  }

  private isCurrentReleaseLoad(generation: number): boolean {
    return this.releaseLoadGeneration === generation
  }

  private applyReleaseSnapshot(snapshot: AppReleaseCacheSnapshot): void {
    const copied: AppReleaseCacheSnapshot = snapshot.copy()
    this.releaseSnapshot = copied
    this.releaseHistory = copied.releases
    const latest: AppRelease | null = AppReleaseService.latestStable(copied)
    if (latest === null || latest.version().length === 0) {
      this.latestVersion = ''
      this.canUpdate = false
      this.updateChecked = false
      this.selectedReleaseIndex = 0
      return
    }
    this.latestVersion = latest.version()
    this.canUpdate = AppReleaseService.compareVersions(this.versionText(), this.latestVersion) < 0
    this.updateChecked = true
    this.selectedReleaseIndex = AppReleaseService.indexForVersion(this.releaseHistory, this.versionText())
  }

  private onUpdateRowClick(): void {
    if (this.releaseHistory.length > 0) {
      this.showUpdateDialog()
      return
    }
    this.loadReleaseHistoryForDialog()
  }

  private showUpdateDialog(): void {
    if (this.releaseHistory.length === 0) {
      return
    }
    this.selectedReleaseIndex = AppReleaseService.indexForVersion(this.releaseHistory, this.versionText())
    this.updateDialogId = -1
    this.getUIContext().getPromptAction().openCustomDialog({
      builder: () => {
        this.UpdateDialog()
      },
      autoCancel: true,
      alignment: DialogAlignment.Center,
    })
      .then((dialogId: number) => {
        this.updateDialogId = dialogId
      })
      .catch((error: Error) => {
        DiagnosticLogger.warn('settings', 'about_update_dialog_open_failed', error.message)
        this.toast(AppStrings.get('about_update_failed'))
      })
  }

  private closeUpdateDialog(): void {
    const dialogId: number = this.updateDialogId
    if (dialogId < 0) {
      return
    }
    this.updateDialogId = -1
    try {
      this.getUIContext().getPromptAction().closeCustomDialog(dialogId)
    } catch (_error) {
      // The dialog may already have been dismissed by a system gesture.
    }
  }

  @Builder
  private UpdateDialog() {
    CustomContentDialogV2({
      primaryTitle: this.canUpdate
        ? AppStrings.get('about_update_available').replace('%s', this.latestVersion)
        : AppStrings.get('about_release_notes'),
      contentBuilder: () => {
        this.UpdateDialogContent()
      },
      // The dialog, not the paged body, owns the separation from its fixed action area.
      // Keep the established 24vp horizontal inset and reserve the same bottom inset so
      // a long release-note viewport cannot visually run into the two action buttons
      // when the available height contracts in landscape.
      contentAreaPadding: {
        top: LengthMetrics.vp(0),
        bottom: LengthMetrics.vp(ThemeTokens.SPACE_XL),
        start: LengthMetrics.vp(ThemeTokens.SPACE_XL),
        end: LengthMetrics.vp(ThemeTokens.SPACE_XL),
      },
      buttons: [
        new AdvancedDialogV2Button({
          content: AppStrings.get('common_cancel'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: () => {
            this.closeUpdateDialog()
          },
        }),
        new AdvancedDialogV2Button({
          content: AppStrings.get('about_update_open_release'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: () => {
            this.closeUpdateDialog()
            this.openReleasePage()
          },
        }),
      ],
    })
  }

  @Builder
  private UpdateDialogContent() {
    ReleaseNotesPager({
      releases: this.releaseHistory,
      initialIndex: this.selectedReleaseIndex,
      emptyText: AppStrings.get('about_update_no_notes'),
      focusRailImage: $r('app.media.release_notes_focus_rail'),
      onReleaseChanged: (index: number) => {
        this.selectedReleaseIndex = index
      },
      onLinkClick: (url: string) => {
        this.openReleaseNoteLink(url)
      },
    })
      .width('100%')
  }

  private openReleaseNoteLink(url: string): void {
    if (url.length === 0) {
      return
    }
    const want: Want = { action: 'ohos.want.action.viewData', uri: url }
    this.ctx().startAbility(want).catch((error: Error) => {
      DiagnosticLogger.warn('settings', 'about_update_open_note_link_failed', error.message)
      this.toast(AppStrings.get('about_update_open_failed'))
    })
  }

  private openReleasePage(): void {
    const release: AppRelease | null = this.selectedRelease()
    if (release === null || release.htmlUrl.length === 0) {
      return
    }
    const want: Want = { action: 'ohos.want.action.viewData', uri: release.htmlUrl }
    this.ctx().startAbility(want).catch((error: Error) => {
      DiagnosticLogger.warn('settings', 'about_update_open_release_failed', error.message)
      this.toast(AppStrings.get('about_update_open_failed'))
    })
  }

  private selectedRelease(): AppRelease | null {
    if (this.releaseHistory.length === 0) {
      return null
    }
    const index: number = Math.max(0, Math.min(this.releaseHistory.length - 1, this.selectedReleaseIndex))
    return this.releaseHistory[index]
  }

  @Builder
  AppHeader() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Text(AppStrings.get('EntryAbility_label'))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
      Text(AppStrings.get('about_tagline'))
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
      Text(this.versionText())
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .padding({
      left: ThemeTokens.SPACE_LG,
      right: ThemeTokens.SPACE_LG,
      top: ThemeTokens.SPACE_XL,
      bottom: ThemeTokens.SPACE_LG,
    })
    .borderRadius(ThemeTokens.RADIUS_CARD)
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
  }

  @Builder
  DividerRow() {
    Divider()
      .strokeWidth(0.5)
      .color(ThemeTokens.DIVIDER)
      .margin({ left: ThemeTokens.SPACE_MD })
  }

  @Builder
  AppInfoSection() {
    NextNGroupedListSection() {
      NextNListRow({
        title: AppStrings.get('about_app_name'),
        trailingText: AppStrings.get('EntryAbility_label'),
        showChevron: false,
      })
      this.DividerRow()
      NextNListRow({
        title: AppStrings.get('about_version'),
        trailingText: this.versionText(),
        showChevron: false,
      })
      this.DividerRow()
      NextNListRow({
        title: AppStrings.get('about_check_update'),
        subtitle: this.updateSubtitle(),
        trailingText: this.updateChecking ? AppStrings.get('about_update_checking') : '',
        showChevron: this.releaseHistory.length > 0 || !this.updateChecking,
        isEnabled: this.releaseHistory.length > 0 || !this.updateChecking,
        onAction: () => {
          this.onUpdateRowClick()
        },
      })
      this.DividerRow()
      NextNListRow({
        title: AppStrings.get('about_platform'),
        trailingText: AppStrings.get('about_harmony_platform'),
        showChevron: false,
      })
    }
  }

  @Builder
  LicenseSection() {
    NextNGroupedListSection() {
      NextNListRow({
        title: AppStrings.get('about_source_license'),
        trailingText: 'MIT',
        showChevron: false,
      })
      this.DividerRow()
      Column({ space: ThemeTokens.SPACE_XS }) {
        Text(AppStrings.get('about_unofficial_notice'))
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
        Text(AppStrings.get('about_nh_notice'))
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(ThemeTokens.SPACE_LG)
    }
  }

  build() {
    Column() {
      SecondaryListScaffold({
        scroller: this.scroller,
        bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
        alwaysEnableEdgeSpring: true,
      }) {
        ListItem() {
          this.AppHeader()
        }
        ListItem() {
          NextNSectionHeader({ title: AppStrings.get('about_app_info') })
        }
        .margin({ top: ThemeTokens.SPACE_MD })
        ListItem() {
          this.AppInfoSection()
        }
        ListItem() {
          NextNSectionHeader({ title: AppStrings.get('about_license') })
        }
        .margin({ top: ThemeTokens.SPACE_MD })
        ListItem() {
          this.LicenseSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE_SUB)
  }
}
