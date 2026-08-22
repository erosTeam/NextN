import { common, bundleManager } from '@kit.AbilityKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { CustomContentDialog, SymbolGlyphModifier } from '@kit.ArkUI'
import { pasteboard } from '@kit.BasicServicesKit'
import { systemShare } from '@kit.ShareKit'
import { IconStyleMode } from '@kit.UIDesignKit'
import { ReaderSuperResolutionModelsPage } from './ReaderSuperResolutionModelsPage'
import {
  AppStrings,
  BackupService,
  BackupAppMetadata,
  BackupParseResult,
  BackupPreview,
  AppColorPicker,
  CatalogPreferencesService,
  CatalogPreferencesState,
  CacheStat,
  CommentTranslationService,
  CommentTranslationSettingsState,
  ComicTranslationRuntimeService,
  ImagePipelineService,
  LanguageSettings,
  LanguageState,
  LayoutSafeAreaState,
  NhReaderBackgroundMode,
  NhReaderImageScalingQuality,
  NhReaderMode,
  NhReaderSpreadLayout,
  NhReaderSuperResolutionModel,
  READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT_CHOICES,
  NhReaderTapZoneInvert,
  NhReaderTapZoneLayout,
  NextNGroupedListSection,
  NextNListRow,
  NextNSectionHeader,
  NextNModalScaffold,
  SecondaryListScaffold,
  ClipboardLinkBuildFlag,
  NhPageCacheService,
  ReaderImageCacheSettings,
  ReaderSuperResolutionModelService,
  ReaderEnhancementModelsState,
  ReaderPresentationService,
  ReaderPresentationState,
  DownloadQueueService,
  DownloadRestoreResult,
  DownloadNotificationService,
  DownloadSettingsService,
  DownloadSettingsState,
  DiagnosticLogger,
  DiagnosticsExportFile,
  DiagnosticsFileExport,
  DiagnosticsLogFileInfo,
  DiagnosticsLogFileSink,
  DiagnosticsSettings,
  DiagnosticsState,
  HomeTabAutoHideState,
  HomeTabSettings,
  ImmersiveMaterialOption,
  ImmersiveMaterialSettings,
  ImmersiveMaterialSettingsState,
  NhAccountProfileService,
  AccountSessionState,
  AccountProfileState,
  BrowsePresentationService,
  BrowsePresentationState,
  CoverBackgroundSettings,
  CoverBackgroundState,
  ActionAlignmentSettings,
  ActionAlignmentState,
  ActionAlignmentOption,
  GalleryTitleSettings,
  GalleryTitleState,
  ReadButtonStyleSettings,
  ReadButtonStyleState,
  NhClipboardLinkSettings,
  NhClipboardLinkState,
  ScreenOrientationSettings,
  ScreenOrientationState,
  NhBrowsePresentation,
  NhSearchLanguage,
  NhSearchOptions,
  NhSearchSort,
  TagTranslationSettingsState,
  ThemeTokens,
  ThemeColorOption,
  ThemeColorSettings,
  ThemeColorState,
  ThemeDisplayState,
  ThemeSettings,
  TabletLayoutSettings,
  TabletLayoutState,
  MotionHandStateService,
  SettingsNavigationState,
  SafeModeState,
  SETTINGS_ROOT_BROWSER_SESSION,
  SETTINGS_ROOT_ACCOUNT,
  SETTINGS_ROOT_LAYOUT,
  SETTINGS_ROOT_BROWSE,
  SETTINGS_ROOT_SEARCH,
  SETTINGS_ROOT_READER,
  SETTINGS_ROOT_DOWNLOAD,
  SETTINGS_ROOT_CACHE,
  SETTINGS_ROOT_ADVANCED,
  SETTINGS_ROOT_ABOUT,
  SETTINGS_ROOT_HISTORY,
  galleryBaseMinColumnWidth,
  supportsGalleryColumnDensity,
  connectAccountSession,
  connectAccountProfile,
  connectBrowsePresentation,
  connectCatalogPreferences,
  connectCommentTranslationSettings,
  connectCoverBackground,
  connectActionAlignment,
  connectGalleryTitle,
  connectNhClipboardLink,
  connectReadButtonStyle,
  connectReaderEnhancementModels,
  connectReaderPresentation,
  connectScreenOrientation,
  connectDownloadSettings,
  connectDiagnostics,
  connectHomeTabAutoHide,
  connectImmersiveMaterialSettings,
  connectLanguageState,
  connectLayoutSafeArea,
  connectSettingsNavigation,
  connectSafeMode,
  connectTabletLayout,
  connectTagTranslationSettings,
  connectThemeColor,
  connectThemeDisplay,
  releaseTagTranslationVersionLabel,
} from 'shared'
import { appSheetOptions } from 'shared'
import {
  BackupFilePickerCoordinator,
  BackupImportSelection,
} from '../model/BackupFilePickerCoordinator'

const CATALOG_LANGUAGES: NhSearchLanguage[] = [
  NhSearchLanguage.ALL,
  NhSearchLanguage.JAPANESE,
  NhSearchLanguage.CHINESE,
  NhSearchLanguage.ENGLISH,
  NhSearchLanguage.TRANSLATED,
]

const CATALOG_SORTS: NhSearchSort[] = [
  NhSearchSort.RECENT,
  NhSearchSort.POPULAR_TODAY,
  NhSearchSort.POPULAR_WEEK,
  NhSearchSort.POPULAR_MONTH,
  NhSearchSort.POPULAR_ALL_TIME,
]

/**
 * The Settings tab follows NextE's root-entry model: the tab itself contains
 * only stable navigation choices, and each implemented capability owns a
 * normal HDS destination. This prevents the root tab from becoming a long
 * stack of unrelated configuration cards.
 */
export enum SettingsSurface {
  ROOT,
  LAYOUT,
  BROWSE,
  SEARCH,
  READER,
  DOWNLOAD,
  CACHE,
  ADVANCED,
  ABOUT,
}

/**
 * Settings keeps NextE's grouped native-list grammar: HDS rows carry the
 * hierarchy and actions, while the surrounding sections only explain the
 * capability boundary. No setting here implies an unavailable remote action.
 */
@ComponentV2
export struct SettingsPage {
  @Local safeMode: SafeModeState = connectSafeMode()
  @Local pageCacheStat: CacheStat = new CacheStat()
  @Local imageCacheStat: CacheStat = new CacheStat()
  @Local readerCacheLimitMb: number = 1024
  @Local isLoadingPrivateCache: boolean = false
  @Local isClearingPrivateCache: boolean = false
  @Local privateCacheError: string = ''
  // Backup/restore state (ported from NextE CacheSettingsPage).
  @Local includeSecrets: boolean = false
  @Local exportPwd: string = ''
  @Local exportPwd2: string = ''
  @Local importPwd: string = ''
  @Local busy: boolean = false
  private pendingImportRaw: string = ''
  private appVersion: string = ''
  private appVersionCode: number = 0
  private importPasswordDialogController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: AppStrings.get('backup_encrypted_title'),
      contentBuilder: () => {
        this.ImportPasswordDialogContent()
      },
      buttons: [
        {
          value: AppStrings.get('common_cancel'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: () => {
            this.closeImportPasswordDialog()
          },
        },
        {
          value: AppStrings.get('backup_import'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: () => {
            this.confirmDecryptImport()
          },
        },
      ],
    }),
    autoCancel: true,
    onWillDismiss: (_action: DismissDialogAction) => {
      this.importPwd = ''
      this.pendingImportRaw = ''
    },
    alignment: DialogAlignment.Center,
    customStyle: false,
  });
  private exportDialogController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: AppStrings.get('backup_export'),
      contentBuilder: () => {
        this.ExportDialogContent()
      },
      buttons: [
        {
          value: AppStrings.get('common_cancel'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: () => {
            this.closeExportDialog()
          },
        },
        {
          value: AppStrings.get('backup_export'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: () => {
            this.confirmExport()
          },
        },
      ],
    }),
    autoCancel: true,
    onWillDismiss: (_action: DismissDialogAction) => {
      this.exportPwd = ''
      this.exportPwd2 = ''
    },
    alignment: DialogAlignment.Center,
    customStyle: false,
  });
  @Local commentTranslationCacheStatus: CacheStat = new CacheStat()
  @Local comicTranslationCacheStatus: CacheStat = new CacheStat()
  @Local readerPresentation: ReaderPresentationState = connectReaderPresentation()
  @Local readerEnhancementModels: ReaderEnhancementModelsState = connectReaderEnhancementModels()
  @Local readerModeError: string = ''
  @Local readerEnhancementInstalledModels: NhReaderSuperResolutionModel[] = []
  @Local readerEnhancementModelsShown: boolean = false
  @Local readerSheetPanelWidth: number = 0
  @Local browsePresentationError: string = ''
  @Local browsePreferencesError: string = ''
  @Local searchPreferencesError: string = ''
  @Local downloadSettings: DownloadSettingsState = connectDownloadSettings()
  @Local diagnostics: DiagnosticsState = connectDiagnostics()
  @Local diagnosticsLogCount: number = 0
  @Local diagnosticsLogFiles: DiagnosticsLogFileInfo[] = []
  @Local commentTranslationSettings: CommentTranslationSettingsState = connectCommentTranslationSettings()
  @Local tagTranslationSettings: TagTranslationSettingsState = connectTagTranslationSettings()
  @Local accountSession: AccountSessionState = connectAccountSession()
  @Local accountProfile: AccountProfileState = connectAccountProfile()
  @Local browsePresentation: BrowsePresentationState = connectBrowsePresentation()
  @Local catalogPreferences: CatalogPreferencesState = connectCatalogPreferences()
  @Local tabletLayout: TabletLayoutState = connectTabletLayout()
  @Local screenOrientation: ScreenOrientationState = connectScreenOrientation()
  @Local homeTab: HomeTabAutoHideState = connectHomeTabAutoHide()
  @Local coverBackground: CoverBackgroundState = connectCoverBackground()
  @Local actionAlignment: ActionAlignmentState = connectActionAlignment()
  @Local galleryTitle: GalleryTitleState = connectGalleryTitle()
  @Local clipboardLink: NhClipboardLinkState = connectNhClipboardLink()
  @Local readButtonStyle: ReadButtonStyleState = connectReadButtonStyle()
  @Local immersiveMaterial: ImmersiveMaterialSettingsState = connectImmersiveMaterialSettings()
  @Local themeColor: ThemeColorState = connectThemeColor()
  @Local themeDisplay: ThemeDisplayState = connectThemeDisplay()
  @Local language: LanguageState = connectLanguageState()
  @Local layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local settingsNavigation: SettingsNavigationState = connectSettingsNavigation()
  @Local isAccountSignedIn: boolean = false
  @Local downloadSettingsError: string = ''
  @Local isSavingDownloadSettings: boolean = false
  @Local isRestoringDownloadTasks: boolean = false
  @Local themeColorPickerShown: boolean = false
  @Local draftCustomThemeColor: string = '#0958F7'
  private themeColorBeforePicker: string = ThemeColorSettings.COLOR_GALAXY_BLUE
  private themeColorPreviewActive: boolean = false
  @Local clipboardLinkSaving: boolean = false
  private diagnosticsShareController?: systemShare.ShareController
  @Param scroller: Scroller = new Scroller()
  @Param surface: SettingsSurface = SettingsSurface.ROOT
  /** Reader mounts this same semantic surface inside its private sheet. */
  @Param sheetPresentation: boolean = false
  @Event onClose?: () => void
  @Event onOpenBrowserSession?: () => void
  @Event onOpenAccount?: () => void
  @Event onOpenLayoutSettings?: () => void
  @Event onOpenBrowseSettings?: () => void
  @Event onOpenSearchSettings?: () => void
  @Event onOpenBrowseDensity?: (mode: NhBrowsePresentation) => void
  @Event onOpenReaderSettings?: () => void
  @Event onOpenReaderEnhancementModels?: () => void
  @Event onOpenCommentTranslation?: () => void
  @Event onOpenComicTranslation?: () => void
  @Event onOpenTranslationSource?: () => void
  @Event onOpenDownloadSettings?: () => void
  @Event onOpenCacheSettings?: () => void
  @Event onOpenAdvancedSettings?: () => void
  @Event onOpenAbout?: () => void
  @Event onOpenHistory?: () => void
  @Event onOpenContentFilters?: () => void
  @Event onOpenTagTranslation?: () => void
  @Event onOpenSyncSettings?: () => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void

  aboutToAppear(): void {
    if (this.surface === SettingsSurface.ROOT) {
      this.refreshAccountSession()
      return
    }
    if (this.surface === SettingsSurface.LAYOUT) {
      this.loadLayoutSettings()
      return
    }
    if (this.surface === SettingsSurface.BROWSE || this.surface === SettingsSurface.SEARCH) {
      this.loadCatalogPreferences()
      return
    }
    if (this.surface === SettingsSurface.READER) {
      this.loadReaderPresentation()
      return
    }
    if (this.surface === SettingsSurface.DOWNLOAD) {
      this.loadDownloadSettings()
      return
    }
    if (this.surface === SettingsSurface.CACHE) {
      this.loadAppVersion()
      this.loadPrivateCacheStatus()
      return
    }
    if (this.surface === SettingsSurface.ADVANCED) {
      this.loadAdvancedSettings()
    }
  }

  private isSettingsRootSelected(name: string): boolean {
    return this.settingsNavigation.isRootSelected(name, this.layoutSafeArea.rootNavigationSplit)
  }

  @Monitor('accountSession.revision')
  onAccountSessionChanged(): void {
    if (this.surface === SettingsSurface.ROOT) {
      this.refreshAccountSession()
    }
  }

  @Monitor('readerEnhancementModels.revision')
  onReaderEnhancementModelsChanged(): void {
    if (this.surface === SettingsSurface.READER) {
      this.refreshReaderEnhancementModels().catch((): void => {})
    }
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private async refreshAccountSession(): Promise<void> {
    this.isAccountSignedIn = this.accountSession.initialized && this.accountSession.signedIn
    if (!this.isAccountSignedIn) {
      return
    }
    try {
      // The profile snapshot is intentionally separate from the session
      // owner. Settings may read it for display, but it must never trigger a
      // second RDB/HUKS/ArkWeb restore attempt.
      await NhAccountProfileService.restore(this.context())
    } catch (_error) {
      // A display-profile read failure never changes the published session.
    }
  }

  /**
   * Layout is the one durable display destination, matching NextE's root
   * hierarchy. Keep the restored state local-only: none of these preferences
   * fetches, mutates, or reinterprets a gallery response.
   */
  private async loadLayoutSettings(): Promise<void> {
    this.browsePresentationError = ''
    try {
      await Promise.all([
        ThemeSettings.restore(this.context()),
        LanguageSettings.restore(this.context()),
        ImmersiveMaterialSettings.restore(this.context()),
        BrowsePresentationService.restore(this.context()),
        HomeTabSettings.restore(this.context()),
        CoverBackgroundSettings.restore(this.context()),
        GalleryTitleSettings.restore(this.context()),
        ReadButtonStyleSettings.restore(this.context()),
        ActionAlignmentSettings.restore(this.context()),
        ScreenOrientationSettings.restore(this.context()),
        TabletLayoutSettings.restore(this.context()),
      ])
    } catch (_error) {
      this.browsePresentationError = AppStrings.get('settings_browse_presentation_unavailable')
    }
  }

  /** Browse and Search retain one store but have separate Settings owners. */
  private async loadCatalogPreferences(): Promise<void> {
    this.browsePreferencesError = ''
    this.searchPreferencesError = ''
    try {
      await CatalogPreferencesService.restore(this.context())
    } catch (_error) {
      this.browsePreferencesError = AppStrings.get('settings_browse_preferences_unavailable')
      this.searchPreferencesError = AppStrings.get('settings_search_preferences_unavailable')
    }
  }

  private themeModeLabel(): string {
    if (this.themeDisplay.mode === ThemeSettings.MODE_LIGHT) {
      return AppStrings.get('theme_light')
    }
    if (this.themeDisplay.mode === ThemeSettings.MODE_DARK) {
      return AppStrings.get('theme_dark')
    }
    return AppStrings.get('appearance_follow_system')
  }

  private tagTranslationVersionText(): string {
    const label: string = releaseTagTranslationVersionLabel(this.tagTranslationSettings.version)
    return label.length > 0
      ? label
      : AppStrings.get('settings_tag_translation_no_version')
  }

  private languageModeLabel(): string {
    if (this.language.mode === LanguageSettings.MODE_ZH_CN) {
      return AppStrings.get('language_zh')
    }
    if (this.language.mode === LanguageSettings.MODE_EN) {
      return AppStrings.get('language_en')
    }
    if (this.language.mode === LanguageSettings.MODE_JA) {
      return AppStrings.get('language_ja')
    }
    return AppStrings.get('appearance_follow_system')
  }

  private setTheme(mode: string): void {
    ThemeSettings.setMode(this.context(), mode).catch((): void => {})
  }

  private themeColorLabel(): string {
    return AppStrings.get(ThemeColorSettings.labelKey(this.themeColor.color))
  }

  private setThemeColor(value: string): void {
    ThemeColorSettings.setColor(this.context(), value).catch((): void => {})
  }

  /** Opens the custom picker without persisting or replacing the current accent. */
  private openThemeColorPicker(): void {
    this.themeColorBeforePicker = this.themeColor.color
    this.draftCustomThemeColor = ThemeColorSettings.customSeed(this.themeColorBeforePicker)
    this.themeColorPreviewActive = true
    this.themeColorPickerShown = true
  }

  private closeThemeColorPicker(): void {
    if (this.themeColorPreviewActive) {
      ThemeColorSettings.apply(this.themeColorBeforePicker)
      this.themeColorPreviewActive = false
    }
    this.themeColorPickerShown = false
  }

  private confirmThemeColorPicker(): void {
    this.themeColorPreviewActive = false
    ThemeColorSettings.setColor(this.context(), this.draftCustomThemeColor).catch((): void => {})
    this.themeColorPickerShown = false
  }

  private setImmersiveMaterial(level: string): void {
    ImmersiveMaterialSettings.setLevel(this.context(), level).catch((): void => {})
  }

  private immersiveMaterialLabel(): string {
    const level: string = ImmersiveMaterialSettings.normalizeLevel(this.immersiveMaterial.level)
    if (level === ImmersiveMaterialSettings.LEVEL_EXQUISITE) {
      return AppStrings.get('immersive_material_exquisite')
    }
    if (level === ImmersiveMaterialSettings.LEVEL_GENTLE) {
      return AppStrings.get('immersive_material_gentle')
    }
    if (level === ImmersiveMaterialSettings.LEVEL_SMOOTH) {
      return AppStrings.get('immersive_material_smooth')
    }
    return AppStrings.get('common_auto')
  }

  private setLanguage(mode: string): void {
    LanguageSettings.setMode(this.context(), mode).catch((): void => {})
  }

  private tabletLayoutLabelFor(mode: string): string {
    const normalized: string = TabletLayoutSettings.normalizeMode(mode)
    if (normalized === TabletLayoutSettings.MODE_OFF) {
      return AppStrings.get('common_off')
    }
    if (normalized === TabletLayoutSettings.MODE_LANDSCAPE_ONLY) {
      return AppStrings.get('tablet_layout_landscape_only')
    }
    return AppStrings.get('common_auto')
  }

  private tabletLayoutLabel(): string {
    return this.tabletLayoutLabelFor(this.tabletLayout.mode)
  }

  private setTabletLayout(mode: string): void {
    TabletLayoutSettings.setMode(this.context(), mode).catch((): void => {})
  }

  private screenOrientationLabelFor(mode: string): string {
    return ScreenOrientationSettings.normalizeMode(mode) ===
      ScreenOrientationSettings.MODE_AUTO_ROTATION_UNSPECIFIED
      ? AppStrings.get('screen_orientation_auto_rotation_unspecified')
      : AppStrings.get('screen_orientation_unspecified')
  }

  private screenOrientationLabel(): string {
    return this.screenOrientationLabelFor(this.screenOrientation.mode)
  }

  private setScreenOrientation(mode: string): void {
    ScreenOrientationSettings.setMode(this.context(), mode).catch((): void => {})
  }

  private browsePresentationLabel(): string {
    if (this.browsePresentation.mode === NhBrowsePresentation.LIST) {
      return AppStrings.get('browse_list')
    }
    if (this.browsePresentation.mode === NhBrowsePresentation.WATERFALL) {
      return AppStrings.get('browse_waterfall')
    }
    if (this.browsePresentation.mode === NhBrowsePresentation.WATERFALL_COMPACT) {
      return AppStrings.get('browse_waterfall_compact')
    }
    if (this.browsePresentation.mode === NhBrowsePresentation.COVER_WALL) {
      return AppStrings.get('browse_cover_wall')
    }
    return this.browsePresentation.mode === NhBrowsePresentation.COVER_GRID
      ? AppStrings.get('browse_cover_grid')
      : AppStrings.get('browse_simple_list')
  }

  private async saveBrowsePresentation(mode: NhBrowsePresentation): Promise<void> {
    this.browsePresentationError = ''
    try {
      await BrowsePresentationService.setMode(this.context(), mode)
    } catch (_error) {
      this.browsePresentationError = AppStrings.get('settings_browse_presentation_save_failed')
    }
  }

  private setShowGalleryTags(value: boolean): void {
    this.browsePresentationError = ''
    BrowsePresentationService.setShowGalleryTags(this.context(), value).catch((): void => {
      this.browsePresentationError = AppStrings.get('settings_browse_presentation_save_failed')
    })
  }

  private setListCardFixedHeight(value: boolean): void {
    this.browsePresentationError = ''
    BrowsePresentationService.setListCardFixedHeight(this.context(), value).catch((): void => {
      this.browsePresentationError = AppStrings.get('settings_browse_presentation_save_failed')
    })
  }

  private catalogLanguageLabel(language: NhSearchLanguage): string {
    return NhSearchOptions.languageLabel(language)
  }

  private catalogSortLabel(sort: NhSearchSort): string {
    return NhSearchOptions.sortLabel(sort)
  }

  private setCatalogBrowseLanguage(language: NhSearchLanguage): void {
    this.browsePreferencesError = ''
    CatalogPreferencesService.setBrowseLanguage(this.context(), language).catch((): void => {
      this.browsePreferencesError = AppStrings.get('settings_browse_preferences_save_failed')
    })
  }

  private setCatalogBrowseSort(sort: NhSearchSort): void {
    this.browsePreferencesError = ''
    CatalogPreferencesService.setBrowseSort(this.context(), sort).catch((): void => {
      this.browsePreferencesError = AppStrings.get('settings_browse_preferences_save_failed')
    })
  }

  private setCatalogSearchLanguage(language: NhSearchLanguage): void {
    this.searchPreferencesError = ''
    CatalogPreferencesService.setSearchLanguage(this.context(), language).catch((): void => {
      this.searchPreferencesError = AppStrings.get('settings_search_preferences_save_failed')
    })
  }

  private setCatalogSearchSort(sort: NhSearchSort): void {
    this.searchPreferencesError = ''
    CatalogPreferencesService.setSearchSort(this.context(), sort).catch((): void => {
      this.searchPreferencesError = AppStrings.get('settings_search_preferences_save_failed')
    })
  }

  private setHomeTabAutoHide(autoHide: boolean): void {
    HomeTabSettings.save(this.context(), autoHide).catch((): void => {})
  }

  private setBlurLetterboxBackground(value: boolean): void {
    CoverBackgroundSettings.save(this.context(), value).catch((): void => {})
  }

  private setJapaneseTitlePrimary(value: boolean): void {
    GalleryTitleSettings.save(this.context(), value).catch((): void => {})
  }

  private async loadReaderPresentation(): Promise<void> {
    this.readerModeError = ''
    try {
      await ReaderPresentationService.restore(this.context())
      await this.refreshReaderEnhancementModels()
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_layout_unavailable')
    }
  }

  private hasReaderEnhancementModelInstalled(model: NhReaderSuperResolutionModel): boolean {
    for (let index: number = 0; index < this.readerEnhancementInstalledModels.length; index++) {
      if (this.readerEnhancementInstalledModels[index] === model) {
        return true
      }
    }
    return false
  }

  private selectedReaderEnhancementModelInstalled(): boolean {
    return this.hasReaderEnhancementModelInstalled(this.readerPresentation.superResolutionModel)
  }

  private readerEnhancementModelLabel(): string {
    if (!this.selectedReaderEnhancementModelInstalled()) {
      return AppStrings.get('settings_reader_enhancement_model_none')
    }
    const definition = ReaderSuperResolutionModelService.definition(
      this.readerPresentation.superResolutionModel,
    )
    return definition === null
      ? AppStrings.get('settings_reader_enhancement_model_none')
      : definition.systemModel
        ? AppStrings.get(definition.labelStringKey)
        : definition.canonicalName
  }

  private readerEnhancementModelTitle(model: NhReaderSuperResolutionModel): string {
    const definition = ReaderSuperResolutionModelService.definition(model)
    return definition === null
      ? AppStrings.get('settings_reader_enhancement_model_none')
      : definition.systemModel
        ? AppStrings.get(definition.labelStringKey)
        : definition.canonicalName
  }

  private readerEnhancementMaxHeightLabel(): string {
    return `${this.readerPresentation.superResolutionMaxHeight}px`
  }

  /** Mirrors the reference lifecycle: an externally removed selected model
   * falls back to an installed peer, and an enabled reader has no missing-model
   * state. This is not a download path. */
  private async refreshReaderEnhancementModels(): Promise<void> {
    this.readerEnhancementInstalledModels = await ReaderSuperResolutionModelService.installedModels(
      this.context(),
    )
    if (this.selectedReaderEnhancementModelInstalled()) {
      return
    }
    if (this.readerEnhancementInstalledModels.length > 0) {
      await ReaderPresentationService.setSuperResolutionModel(
        this.context(),
        this.readerEnhancementInstalledModels[0],
      )
      return
    }
    if (this.readerPresentation.superResolutionEnabled) {
      await ReaderPresentationService.setSuperResolutionEnabled(this.context(), false)
    }
  }

  private openReaderEnhancementModels(): void {
    if (this.sheetPresentation) {
      this.getUIContext().animateTo({
        duration: ThemeTokens.ANIM_DURATION,
        curve: Curve.EaseOut,
      }, (): void => {
        this.readerEnhancementModelsShown = true
      })
      return
    }
    if (this.onOpenReaderEnhancementModels) {
      this.onOpenReaderEnhancementModels()
    }
  }

  private async saveReaderEnhancementEnabled(enabled: boolean): Promise<void> {
    if (this.readerPresentation.superResolutionEnabled === enabled ||
      (enabled && !this.selectedReaderEnhancementModelInstalled())) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setSuperResolutionEnabled(this.context(), enabled)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_enhancement_save_failed')
    }
  }

  private async setReaderEnhancementModel(model: NhReaderSuperResolutionModel): Promise<void> {
    if (!this.hasReaderEnhancementModelInstalled(model) ||
      this.readerPresentation.superResolutionModel === model) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setSuperResolutionModel(this.context(), model)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_enhancement_save_failed')
    }
  }

  private async setReaderEnhancementMaxHeight(height: number): Promise<void> {
    if (!this.readerPresentation.superResolutionEnabled ||
      !this.selectedReaderEnhancementModelInstalled() ||
      this.readerPresentation.superResolutionMaxHeight === height) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setSuperResolutionMaxHeight(this.context(), height)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_enhancement_save_failed')
    }
  }

  private readButtonStyleLabel(): string {
    return this.readButtonStyle.style === ReadButtonStyleSettings.STYLE_HDS
      ? AppStrings.get('read_button_style_hds')
      : AppStrings.get('read_button_style_filled')
  }

  private actionAlignmentLabel(): string {
    return ActionAlignmentSettings.modeLabel(
      this.actionAlignment.alignmentMode,
      this.actionAlignment.holdingHandSupported,
    )
  }

  private setActionAlignmentMode(mode: string): void {
    ActionAlignmentSettings.save(this.context(), mode).catch((): void => {})
    MotionHandStateService.applyAlignmentMode(mode)
  }

  private setReadButtonStyle(style: string): void {
    ReadButtonStyleSettings.save(this.context(), style).catch((): void => {})
  }

  private setClipboardLinkEnabled(value: boolean): void {
    if (this.clipboardLinkSaving) {
      return
    }
    this.clipboardLinkSaving = true
    NhClipboardLinkSettings.setEnabled(this.context(), value)
      .then((applied: boolean): void => {
        if (value && !applied) {
          try {
            this.getUIContext().getPromptAction().showToast({
              message: AppStrings.get('clipboard_link_permission_denied'),
            })
          } catch (_error) {}
        }
      })
      .finally((): void => {
        this.clipboardLinkSaving = false
      })
  }

  private browseColumnWidth(): number {
    const mode: NhBrowsePresentation = this.browsePresentation.mode
    const override: number = this.browsePresentation.columnWidthFor(mode)
    return override > 0 ? override : galleryBaseMinColumnWidth(mode)
  }

  private async loadAdvancedSettings(): Promise<void> {
    await NhClipboardLinkSettings.restore(this.context())
    this.refreshDiagnosticsState()
  }

  private refreshDiagnosticsState(): void {
    this.diagnosticsLogCount = DiagnosticsSettings.count()
    this.diagnosticsLogFiles = DiagnosticsLogFileSink.listRetainedLogFiles()
  }

  private updateDiagnosticsEnabled(enabled: boolean): void {
    const snapshot = DiagnosticsSettings.current()
    snapshot.enabled = enabled
    DiagnosticsSettings.save(this.context(), snapshot).catch((): void => {})
  }

  private updateDiagnosticsMinLevel(level: string): void {
    const snapshot = DiagnosticsSettings.current()
    snapshot.minLevel = DiagnosticsSettings.normalizeLevel(level)
    DiagnosticsSettings.save(this.context(), snapshot).catch((): void => {})
  }

  private writeDiagnosticsMarker(): void {
    DiagnosticLogger.info('diagnostics', 'manual_marker', `ts=${Date.now()}`)
    this.refreshDiagnosticsState()
    this.toast(AppStrings.get('advanced_marker_written'))
  }

  private exportCurrentDiagnostics(): void {
    try {
      const file: DiagnosticsExportFile = DiagnosticsFileExport.create(this.context())
      DiagnosticLogger.info('diagnostics', 'export_current_log', `file=${file.fileName} bytes=${file.text.length}`)
      this.shareDiagnosticsFile(file.fileName, file.uri, file.text)
      this.refreshDiagnosticsState()
    } catch (error) {
      DiagnosticLogger.warn('diagnostics', 'export_current_log_failed', (error as Error).message)
      this.toast(AppStrings.get('diagnostics_export_failed'))
    }
  }

  private shareRetainedDiagnostics(file: DiagnosticsLogFileInfo): void {
    DiagnosticLogger.info('diagnostics', 'share_log_file', `file=${file.fileName} current=${file.isCurrent}`)
    this.shareDiagnosticsFile(file.fileName, file.uri, DiagnosticsLogFileSink.readLogFileText(file.fileName))
  }

  private shareDiagnosticsFile(fileName: string, uri: string, fallbackText: string): void {
    try {
      const record: systemShare.SharedRecord = {
        utd: utd.UniformDataType.FILE,
        title: fileName,
        description: 'Redacted NextN diagnostics log',
        uri: uri,
      }
      const data: systemShare.SharedData = new systemShare.SharedData(record)
      this.diagnosticsShareController = new systemShare.ShareController(data)
      this.diagnosticsShareController.show(this.context(), {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT,
      }).then((): void => {
        DiagnosticLogger.info('diagnostics', 'share_log_file_success', `file=${fileName}`)
      }).catch((error: Error): void => {
        DiagnosticLogger.warn('diagnostics', 'share_log_file_failed', `${fileName}: ${error.message}`)
        this.copyDiagnosticsText(fallbackText)
      })
    } catch (error) {
      DiagnosticLogger.warn('diagnostics', 'share_log_file_failed', `${fileName}: ${(error as Error).message}`)
      this.copyDiagnosticsText(fallbackText)
    }
  }

  private copyDiagnosticsText(text: string): void {
    try {
      const fallback: string = text.length > 0 ? text : DiagnosticsSettings.exportText()
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, fallback)
      pasteboard.getSystemPasteboard().setDataSync(data)
      this.toast(AppStrings.get('diagnostics_copied'))
    } catch (error) {
      DiagnosticLogger.warn('diagnostics', 'copy_log_failed', (error as Error).message)
      this.toast(AppStrings.get('diagnostics_share_failed'))
    }
  }

  private clearDiagnosticsMemory(): void {
    DiagnosticsSettings.clearLogs()
    this.refreshDiagnosticsState()
    this.toast(AppStrings.get('diagnostics_boot_records_cleared'))
  }

  private diagnosticsLevelLabel(level: string): string {
    if (level === DiagnosticsSettings.LEVEL_DEBUG) {
      return 'Debug'
    }
    if (level === DiagnosticsSettings.LEVEL_WARN) {
      return 'Warn'
    }
    if (level === DiagnosticsSettings.LEVEL_ERROR) {
      return 'Error'
    }
    return 'Info'
  }

  private retainedDiagnosticsSubtitle(): string {
    if (this.diagnosticsLogFiles.length <= 0) {
      return AppStrings.get('no_local_log_files')
    }
    return AppStrings.format('retained_local_log_files_count_arg', [`${this.diagnosticsLogFiles.length}`])
  }

  private diagnosticsLogTitle(file: DiagnosticsLogFileInfo): string {
    const timestamp: string = this.formatDiagnosticsTimestamp(file.createdAtMs)
    return file.isCurrent
      ? AppStrings.format('current_log_with_time', [timestamp])
      : AppStrings.format('startup_log_with_time', [timestamp])
  }

  private formatDiagnosticsTimestamp(value: number): string {
    if (value <= 0) {
      return AppStrings.get('unknown_time')
    }
    const date = new Date(value)
    const year: string = date.getFullYear().toString().padStart(4, '0')
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0')
    const day: string = date.getDate().toString().padStart(2, '0')
    const hour: string = date.getHours().toString().padStart(2, '0')
    const minute: string = date.getMinutes().toString().padStart(2, '0')
    return `${year}-${month}-${day} ${hour}:${minute}`
  }

  private formatDiagnosticsFileSize(sizeBytes: number): string {
    if (sizeBytes < 1024) {
      return `${Math.max(0, sizeBytes)} B`
    }
    if (sizeBytes < 1024 * 1024) {
      return `${Math.round(sizeBytes / 102.4) / 10} KB`
    }
    return `${Math.round(sizeBytes / 1024 / 102.4) / 10} MB`
  }

  private privateCacheStat(key: string): CacheStat {
    if (key === 'page') {
      return this.pageCacheStat
    }
    if (key === 'image') {
      return this.imageCacheStat
    }
    if (key === 'comment') {
      return this.commentTranslationCacheStatus
    }
    if (key === 'comic') {
      return this.comicTranslationCacheStatus
    }
    return new CacheStat()
  }

  private privateCacheTotalBytes(): number {
    return this.pageCacheStat.bytes + this.imageCacheStat.bytes + this.commentTranslationCacheStatus.bytes +
      this.comicTranslationCacheStatus.bytes
  }

  private privateCacheTotalCount(): number {
    return this.pageCacheStat.count + this.imageCacheStat.count + this.commentTranslationCacheStatus.count +
      this.comicTranslationCacheStatus.count
  }

  private async loadPrivateCacheStatus(): Promise<void> {
    if (this.isClearingPrivateCache) {
      return
    }
    this.isLoadingPrivateCache = true
    this.privateCacheError = ''
    try {
      this.pageCacheStat = await NhPageCacheService.stat(this.context())
      this.imageCacheStat = ImagePipelineService.stat(this.context())
      this.readerCacheLimitMb = ReaderImageCacheSettings.limitMb()
      this.commentTranslationCacheStatus = await CommentTranslationService.stat(this.context())
      this.comicTranslationCacheStatus = await ComicTranslationRuntimeService.statGeneratedCache(this.context())
    } catch (_error) {
      this.privateCacheError = AppStrings.get('settings_private_cache_status_unavailable')
    } finally {
      this.isLoadingPrivateCache = false
    }
  }

  private async loadDownloadSettings(): Promise<void> {
    this.downloadSettingsError = ''
    try {
      await DownloadSettingsService.restore(this.context())
    } catch (_error) {
      this.downloadSettingsError = AppStrings.get('settings_download_settings_unavailable')
    }
  }

  private async saveGalleryConcurrency(value: number): Promise<void> {
    if (this.isSavingDownloadSettings) {
      return
    }
    this.isSavingDownloadSettings = true
    this.downloadSettingsError = ''
    try {
      await DownloadSettingsService.setMaxConcurrentGalleries(this.context(), value)
      await DownloadQueueService.applySettings(this.context())
    } catch (_error) {
      this.downloadSettingsError = AppStrings.get('settings_download_gallery_concurrency_save_failed')
    } finally {
      this.isSavingDownloadSettings = false
    }
  }

  private async savePageConcurrency(value: number): Promise<void> {
    if (this.isSavingDownloadSettings) {
      return
    }
    this.isSavingDownloadSettings = true
    this.downloadSettingsError = ''
    try {
      await DownloadSettingsService.setMaxConcurrentPages(this.context(), value)
      await DownloadQueueService.applySettings(this.context())
    } catch (_error) {
      this.downloadSettingsError = AppStrings.get('settings_download_page_concurrency_save_failed')
    } finally {
      this.isSavingDownloadSettings = false
    }
  }

  private async saveRetryCount(value: number): Promise<void> {
    if (this.isSavingDownloadSettings) {
      return
    }
    this.isSavingDownloadSettings = true
    this.downloadSettingsError = ''
    try {
      await DownloadSettingsService.setRetryCount(this.context(), value)
      await DownloadQueueService.applySettings(this.context())
    } catch (_error) {
      this.downloadSettingsError = AppStrings.get('settings_download_retry_count_save_failed')
    } finally {
      this.isSavingDownloadSettings = false
    }
  }

  private async saveCompletionNotifications(enabled: boolean): Promise<void> {
    if (this.isSavingDownloadSettings) {
      return
    }
    this.isSavingDownloadSettings = true
    this.downloadSettingsError = ''
    try {
      await DownloadSettingsService.setNotifyOnComplete(this.context(), enabled)
      if (enabled) {
        await DownloadNotificationService.requestEnable(this.context())
      }
    } catch (_error) {
      this.downloadSettingsError = AppStrings.get('settings_download_notify_complete_save_failed')
    } finally {
      this.isSavingDownloadSettings = false
    }
  }

  private async saveRequestInterval(seconds: number): Promise<void> {
    if (this.isSavingDownloadSettings) {
      return
    }
    this.isSavingDownloadSettings = true
    this.downloadSettingsError = ''
    try {
      await DownloadSettingsService.setRequestIntervalSeconds(this.context(), seconds)
      await DownloadQueueService.applySettings(this.context())
    } catch (_error) {
      this.downloadSettingsError = AppStrings.get('settings_download_request_interval_save_failed')
    } finally {
      this.isSavingDownloadSettings = false
    }
  }

  private async saveAutoRetryFailed(enabled: boolean): Promise<void> {
    if (this.isSavingDownloadSettings) {
      return
    }
    this.isSavingDownloadSettings = true
    this.downloadSettingsError = ''
    try {
      await DownloadSettingsService.setAutoRetryFailed(this.context(), enabled)
      await DownloadQueueService.applySettings(this.context())
    } catch (_error) {
      this.downloadSettingsError = AppStrings.get('settings_download_auto_retry_failed_save_failed')
    } finally {
      this.isSavingDownloadSettings = false
    }
  }

  private async saveSpeedLimit(kbps: number): Promise<void> {
    if (this.isSavingDownloadSettings) {
      return
    }
    this.isSavingDownloadSettings = true
    this.downloadSettingsError = ''
    try {
      await DownloadSettingsService.setSpeedLimitKbps(this.context(), kbps)
      await DownloadQueueService.applySettings(this.context())
    } catch (_error) {
      this.downloadSettingsError = AppStrings.get('settings_download_speed_limit_save_failed')
    } finally {
      this.isSavingDownloadSettings = false
    }
  }

  /**
   * User-initiated download-directory restore (leaf row mirroring NextE's
   * DownloadSettingsPage): scan the metadata sidecars, merge anything the
   * queue lacks, then report the outcome as a toast.
   */
  private async restoreDownloadTasks(): Promise<void> {
    if (this.isRestoringDownloadTasks) {
      return
    }
    this.isRestoringDownloadTasks = true
    this.downloadSettingsError = ''
    try {
      const result: DownloadRestoreResult =
        await DownloadQueueService.restoreFromDownloadDirectory(this.context())
      if (result.importedCount > 0) {
        this.toast(AppStrings.format('settings_download_restore_done', [result.importedCount.toString()]))
      } else if (result.scannedCount > 0) {
        this.toast(AppStrings.get('settings_download_restore_existing'))
      } else {
        this.toast(AppStrings.get('settings_download_restore_none'))
      }
    } catch (_error) {
      this.toast(AppStrings.get('settings_download_restore_failed'))
    } finally {
      this.isRestoringDownloadTasks = false
    }
  }

  private retryCountLabelFor(count: number): string {
    return count === 1
      ? AppStrings.format('settings_download_retry_one', [count.toString()])
      : AppStrings.format('settings_download_retry_other', [count.toString()])
  }

  private retryCountLabel(): string {
    return this.retryCountLabelFor(this.downloadSettings.retryCount)
  }

  private requestIntervalLabel(seconds: number): string {
    return AppStrings.format('settings_download_request_interval_value', [seconds.toString()])
  }

  private speedLimitLabel(kbps: number): string {
    return kbps <= 0
      ? AppStrings.get('settings_download_speed_limit_off')
      : AppStrings.format('settings_download_speed_limit_value', [kbps.toString()])
  }

  private readerModeLabel(): string {
    if (this.readerPresentation.mode === NhReaderMode.PAGED_RTL) {
      return AppStrings.get('settings_reader_mode_paged_rtl')
    }
    if (this.readerPresentation.mode === NhReaderMode.PAGED_VERTICAL) {
      return AppStrings.get('settings_reader_mode_paged_vertical')
    }
    if (this.readerPresentation.mode === NhReaderMode.PAGED) {
      return AppStrings.get('settings_reader_mode_paged')
    }
    return AppStrings.get('settings_reader_mode_vertical')
  }

  private readerImageScalingQualityLabel(): string {
    if (this.readerPresentation.imageScalingQuality === NhReaderImageScalingQuality.LOW) {
      return AppStrings.get('settings_reader_image_scaling_quality_standard')
    }
    if (this.readerPresentation.imageScalingQuality === NhReaderImageScalingQuality.HIGH) {
      return AppStrings.get('settings_reader_image_scaling_quality_high')
    }
    return AppStrings.get('settings_reader_image_scaling_quality_optimized')
  }

  private readerBackgroundModeLabel(): string {
    return this.readerBackgroundModeLabelFor(this.readerPresentation.backgroundMode)
  }

  private readerSpreadLayoutLabel(): string {
    return this.readerPresentation.spreadLayoutMode === NhReaderSpreadLayout.SPLIT
      ? AppStrings.get('settings_reader_spread_layout_split')
      : AppStrings.get('settings_reader_spread_layout_joined')
  }

  /** Double page and spread layout exist only in the horizontal LTR/RTL Pager modes (NextE doublePageAvailable). */
  private doublePageAvailable(): boolean {
    return this.readerPresentation.mode === NhReaderMode.PAGED ||
      this.readerPresentation.mode === NhReaderMode.PAGED_RTL
  }

  private readerModeIcon(mode: NhReaderMode): Resource {
    if (mode === NhReaderMode.PAGED_RTL) {
      return $r('sys.symbol.arrow_left_and_square')
    }
    if (mode === NhReaderMode.PAGED_VERTICAL) {
      return $r('sys.symbol.single_page_flipping')
    }
    if (mode === NhReaderMode.VERTICAL) {
      return $r('sys.symbol.scroll_vertical')
    }
    return $r('sys.symbol.arrow_right_and_square')
  }

  private readerTapZoneLayoutLabel(): string {
    if (this.readerPresentation.tapZoneLayout === NhReaderTapZoneLayout.L_SHAPED) {
      return AppStrings.get('settings_reader_tap_zone_l_shaped')
    }
    if (this.readerPresentation.tapZoneLayout === NhReaderTapZoneLayout.KINDLE) {
      return AppStrings.get('settings_reader_tap_zone_kindle')
    }
    if (this.readerPresentation.tapZoneLayout === NhReaderTapZoneLayout.EDGE) {
      return AppStrings.get('settings_reader_tap_zone_edge')
    }
    return AppStrings.get('settings_reader_tap_zone_right_left')
  }

  private readerTapZoneInvertLabel(): string {
    if (this.readerPresentation.tapZoneInvert === NhReaderTapZoneInvert.HORIZONTAL) {
      return AppStrings.get('settings_reader_tap_zone_invert_horizontal')
    }
    if (this.readerPresentation.tapZoneInvert === NhReaderTapZoneInvert.VERTICAL) {
      return AppStrings.get('settings_reader_tap_zone_invert_vertical')
    }
    if (this.readerPresentation.tapZoneInvert === NhReaderTapZoneInvert.BOTH) {
      return AppStrings.get('settings_reader_tap_zone_invert_both')
    }
    return AppStrings.get('settings_reader_tap_zone_invert_none')
  }

  @Builder
  private GalleryConcurrencyMenu() {
    Menu() {
      MenuItem({
        content: '1',
        symbolEndIcon: this.downloadSettings.maxConcurrentGalleries === 1
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveGalleryConcurrency(1)
      })
      MenuItem({
        content: '2',
        symbolEndIcon: this.downloadSettings.maxConcurrentGalleries === 2
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveGalleryConcurrency(2)
      })
      MenuItem({
        content: '3',
        symbolEndIcon: this.downloadSettings.maxConcurrentGalleries === 3
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveGalleryConcurrency(3)
      })
      MenuItem({
        content: '4',
        symbolEndIcon: this.downloadSettings.maxConcurrentGalleries === 4
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveGalleryConcurrency(4)
      })
      MenuItem({
        content: '5',
        symbolEndIcon: this.downloadSettings.maxConcurrentGalleries === 5
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveGalleryConcurrency(5)
      })
    }
  }

  @Builder
  private PageConcurrencyMenu() {
    Menu() {
      MenuItem({
        content: '1',
        symbolEndIcon: this.downloadSettings.maxConcurrentPages === 1
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.savePageConcurrency(1)
      })
      MenuItem({
        content: '2',
        symbolEndIcon: this.downloadSettings.maxConcurrentPages === 2
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.savePageConcurrency(2)
      })
      MenuItem({
        content: '3',
        symbolEndIcon: this.downloadSettings.maxConcurrentPages === 3
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.savePageConcurrency(3)
      })
      MenuItem({
        content: '4',
        symbolEndIcon: this.downloadSettings.maxConcurrentPages === 4
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.savePageConcurrency(4)
      })
      MenuItem({
        content: '5',
        symbolEndIcon: this.downloadSettings.maxConcurrentPages === 5
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.savePageConcurrency(5)
      })
    }
  }

  @Builder
  private RetryCountMenu() {
    Menu() {
      MenuItem({
        content: this.retryCountLabelFor(0),
        symbolEndIcon: this.downloadSettings.retryCount === 0
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRetryCount(0)
      })
      MenuItem({
        content: this.retryCountLabelFor(1),
        symbolEndIcon: this.downloadSettings.retryCount === 1
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRetryCount(1)
      })
      MenuItem({
        content: this.retryCountLabelFor(2),
        symbolEndIcon: this.downloadSettings.retryCount === 2
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRetryCount(2)
      })
      MenuItem({
        content: this.retryCountLabelFor(3),
        symbolEndIcon: this.downloadSettings.retryCount === 3
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRetryCount(3)
      })
      MenuItem({
        content: this.retryCountLabelFor(4),
        symbolEndIcon: this.downloadSettings.retryCount === 4
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRetryCount(4)
      })
      MenuItem({
        content: this.retryCountLabelFor(5),
        symbolEndIcon: this.downloadSettings.retryCount === 5
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRetryCount(5)
      })
    }
  }

  @Builder
  private RequestIntervalMenu() {
    Menu() {
      MenuItem({
        content: this.requestIntervalLabel(0),
        symbolEndIcon: this.downloadSettings.requestIntervalSeconds === 0
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRequestInterval(0)
      })
      MenuItem({
        content: this.requestIntervalLabel(1),
        symbolEndIcon: this.downloadSettings.requestIntervalSeconds === 1
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRequestInterval(1)
      })
      MenuItem({
        content: this.requestIntervalLabel(2),
        symbolEndIcon: this.downloadSettings.requestIntervalSeconds === 2
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRequestInterval(2)
      })
      MenuItem({
        content: this.requestIntervalLabel(3),
        symbolEndIcon: this.downloadSettings.requestIntervalSeconds === 3
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRequestInterval(3)
      })
      MenuItem({
        content: this.requestIntervalLabel(5),
        symbolEndIcon: this.downloadSettings.requestIntervalSeconds === 5
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRequestInterval(5)
      })
      MenuItem({
        content: this.requestIntervalLabel(10),
        symbolEndIcon: this.downloadSettings.requestIntervalSeconds === 10
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRequestInterval(10)
      })
    }
  }

  @Builder
  private SpeedLimitMenu() {
    Menu() {
      MenuItem({
        content: this.speedLimitLabel(0),
        symbolEndIcon: this.downloadSettings.speedLimitKbps === 0
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveSpeedLimit(0)
      })
      MenuItem({
        content: this.speedLimitLabel(512),
        symbolEndIcon: this.downloadSettings.speedLimitKbps === 512
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveSpeedLimit(512)
      })
      MenuItem({
        content: this.speedLimitLabel(1024),
        symbolEndIcon: this.downloadSettings.speedLimitKbps === 1024
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveSpeedLimit(1024)
      })
      MenuItem({
        content: this.speedLimitLabel(2048),
        symbolEndIcon: this.downloadSettings.speedLimitKbps === 2048
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveSpeedLimit(2048)
      })
      MenuItem({
        content: this.speedLimitLabel(4096),
        symbolEndIcon: this.downloadSettings.speedLimitKbps === 4096
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveSpeedLimit(4096)
      })
      MenuItem({
        content: this.speedLimitLabel(8192),
        symbolEndIcon: this.downloadSettings.speedLimitKbps === 8192
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveSpeedLimit(8192)
      })
    }
  }

  @Builder
  private ReaderModeMenu() {
    Menu() {
      MenuItem({
        content: AppStrings.get('settings_reader_mode_paged'),
        symbolStartIcon: new SymbolGlyphModifier(this.readerModeIcon(NhReaderMode.PAGED)),
        symbolEndIcon: this.readerPresentation.mode === NhReaderMode.PAGED
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveReaderMode(NhReaderMode.PAGED)
      })
      MenuItem({
        content: AppStrings.get('settings_reader_mode_paged_rtl'),
        symbolStartIcon: new SymbolGlyphModifier(this.readerModeIcon(NhReaderMode.PAGED_RTL)),
        symbolEndIcon: this.readerPresentation.mode === NhReaderMode.PAGED_RTL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveReaderMode(NhReaderMode.PAGED_RTL)
      })
      MenuItem({
        content: AppStrings.get('settings_reader_mode_paged_vertical'),
        symbolStartIcon: new SymbolGlyphModifier(this.readerModeIcon(NhReaderMode.PAGED_VERTICAL)),
        symbolEndIcon: this.readerPresentation.mode === NhReaderMode.PAGED_VERTICAL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveReaderMode(NhReaderMode.PAGED_VERTICAL)
      })
      MenuItem({
        content: AppStrings.get('settings_reader_mode_vertical'),
        symbolStartIcon: new SymbolGlyphModifier(this.readerModeIcon(NhReaderMode.VERTICAL)),
        symbolEndIcon: this.readerPresentation.mode === NhReaderMode.VERTICAL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveReaderMode(NhReaderMode.VERTICAL)
      })
    }
  }

  @Builder
  private ReaderImageScalingQualityMenuItem(quality: NhReaderImageScalingQuality) {
    MenuItem({
      content: this.readerImageScalingQualityLabelFor(quality),
      symbolEndIcon: this.readerPresentation.imageScalingQuality === quality
        ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
        : undefined,
    }).onClick((): void => {
      this.saveReaderImageScalingQuality(quality)
    })
  }

  private readerImageScalingQualityLabelFor(quality: NhReaderImageScalingQuality): string {
    if (quality === NhReaderImageScalingQuality.LOW) {
      return AppStrings.get('settings_reader_image_scaling_quality_standard')
    }
    if (quality === NhReaderImageScalingQuality.HIGH) {
      return AppStrings.get('settings_reader_image_scaling_quality_high')
    }
    return AppStrings.get('settings_reader_image_scaling_quality_optimized')
  }

  private readerBackgroundModeLabelFor(mode: NhReaderBackgroundMode): string {
    if (mode === NhReaderBackgroundMode.GRAY) {
      return AppStrings.get('settings_reader_background_gray')
    }
    if (mode === NhReaderBackgroundMode.WHITE) {
      return AppStrings.get('settings_reader_background_white')
    }
    if (mode === NhReaderBackgroundMode.AUTO) {
      return AppStrings.get('settings_reader_background_auto')
    }
    return AppStrings.get('settings_reader_background_black')
  }

  @Builder
  private ReaderBackgroundModeMenuItem(mode: NhReaderBackgroundMode) {
    MenuItem({
      content: this.readerBackgroundModeLabelFor(mode),
      symbolEndIcon: this.readerPresentation.backgroundMode === mode
        ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
        : undefined,
    }).onClick((): void => {
      this.saveReaderBackgroundMode(mode)
    })
  }

  @Builder
  private ReaderBackgroundModeMenu() {
    Menu() {
      this.ReaderBackgroundModeMenuItem(NhReaderBackgroundMode.BLACK)
      this.ReaderBackgroundModeMenuItem(NhReaderBackgroundMode.GRAY)
      this.ReaderBackgroundModeMenuItem(NhReaderBackgroundMode.WHITE)
      this.ReaderBackgroundModeMenuItem(NhReaderBackgroundMode.AUTO)
    }
  }

  @Builder
  private ReaderImageScalingQualityMenu() {
    Menu() {
      this.ReaderImageScalingQualityMenuItem(NhReaderImageScalingQuality.LOW)
      this.ReaderImageScalingQualityMenuItem(NhReaderImageScalingQuality.MEDIUM)
      this.ReaderImageScalingQualityMenuItem(NhReaderImageScalingQuality.HIGH)
    }
  }

  @Builder
  private ReaderSpreadLayoutMenuItem(layout: NhReaderSpreadLayout) {
    MenuItem({
      content: this.readerSpreadLayoutLabelFor(layout),
      symbolEndIcon: this.readerPresentation.spreadLayoutMode === layout
        ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
        : undefined,
    }).onClick((): void => {
      this.saveReaderSpreadLayout(layout)
    })
  }

  private readerSpreadLayoutLabelFor(layout: NhReaderSpreadLayout): string {
    return layout === NhReaderSpreadLayout.SPLIT
      ? AppStrings.get('settings_reader_spread_layout_split')
      : AppStrings.get('settings_reader_spread_layout_joined')
  }

  @Builder
  private ReaderSpreadLayoutMenu() {
    Menu() {
      this.ReaderSpreadLayoutMenuItem(NhReaderSpreadLayout.JOINED)
      this.ReaderSpreadLayoutMenuItem(NhReaderSpreadLayout.SPLIT)
    }
  }

  @Builder
  private ReaderTapZoneMenuItem(layout: NhReaderTapZoneLayout) {
    MenuItem({
      content: this.readerTapZoneLayoutLabelFor(layout),
      symbolEndIcon: this.readerPresentation.tapZoneLayout === layout
        ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
        : undefined,
    }).onClick((): void => {
      this.saveReaderTapZoneLayout(layout)
    })
  }

  private readerTapZoneLayoutLabelFor(layout: NhReaderTapZoneLayout): string {
    if (layout === NhReaderTapZoneLayout.L_SHAPED) {
      return AppStrings.get('settings_reader_tap_zone_l_shaped')
    }
    if (layout === NhReaderTapZoneLayout.KINDLE) {
      return AppStrings.get('settings_reader_tap_zone_kindle')
    }
    if (layout === NhReaderTapZoneLayout.EDGE) {
      return AppStrings.get('settings_reader_tap_zone_edge')
    }
    return AppStrings.get('settings_reader_tap_zone_right_left')
  }

  @Builder
  private ReaderTapZoneMenu() {
    Menu() {
      this.ReaderTapZoneMenuItem(NhReaderTapZoneLayout.RIGHT_LEFT)
      this.ReaderTapZoneMenuItem(NhReaderTapZoneLayout.L_SHAPED)
      this.ReaderTapZoneMenuItem(NhReaderTapZoneLayout.KINDLE)
      this.ReaderTapZoneMenuItem(NhReaderTapZoneLayout.EDGE)
    }
  }

  @Builder
  private ReaderTapZoneInvertMenuItem(invert: NhReaderTapZoneInvert) {
    MenuItem({
      content: this.readerTapZoneInvertLabelFor(invert),
      symbolEndIcon: this.readerPresentation.tapZoneInvert === invert
        ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
        : undefined,
    }).onClick((): void => {
      this.saveReaderTapZoneInvert(invert)
    })
  }

  private readerTapZoneInvertLabelFor(invert: NhReaderTapZoneInvert): string {
    if (invert === NhReaderTapZoneInvert.HORIZONTAL) {
      return AppStrings.get('settings_reader_tap_zone_invert_horizontal')
    }
    if (invert === NhReaderTapZoneInvert.VERTICAL) {
      return AppStrings.get('settings_reader_tap_zone_invert_vertical')
    }
    if (invert === NhReaderTapZoneInvert.BOTH) {
      return AppStrings.get('settings_reader_tap_zone_invert_both')
    }
    return AppStrings.get('settings_reader_tap_zone_invert_none')
  }

  @Builder
  private ReaderTapZoneInvertMenu() {
    Menu() {
      this.ReaderTapZoneInvertMenuItem(NhReaderTapZoneInvert.NONE)
      this.ReaderTapZoneInvertMenuItem(NhReaderTapZoneInvert.HORIZONTAL)
      this.ReaderTapZoneInvertMenuItem(NhReaderTapZoneInvert.VERTICAL)
      this.ReaderTapZoneInvertMenuItem(NhReaderTapZoneInvert.BOTH)
    }
  }

  @Builder
  private ReadButtonStyleMenu() {
    Menu() {
      MenuItem({
        content: AppStrings.get('read_button_style_filled'),
        symbolEndIcon: this.readButtonStyle.style === ReadButtonStyleSettings.STYLE_FILLED
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setReadButtonStyle(ReadButtonStyleSettings.STYLE_FILLED)
      })
      MenuItem({
        content: AppStrings.get('read_button_style_hds'),
        symbolEndIcon: this.readButtonStyle.style === ReadButtonStyleSettings.STYLE_HDS
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setReadButtonStyle(ReadButtonStyleSettings.STYLE_HDS)
      })
    }
  }

  @Builder
  private ActionAlignmentMenu() {
    Menu() {
      ForEach(
        ActionAlignmentSettings.availableOptions(this.actionAlignment.holdingHandSupported),
        (option: ActionAlignmentOption): void => {
          MenuItem({
            content: option.label,
            symbolEndIcon: ActionAlignmentSettings.effectiveMode(
              this.actionAlignment.alignmentMode,
              this.actionAlignment.holdingHandSupported,
            ) === option.mode
              ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
              : undefined,
          }).onClick((): void => {
            this.setActionAlignmentMode(option.mode)
          })
        },
        (option: ActionAlignmentOption): string => option.mode,
      )
    }
  }

  @Builder
  private TabletLayoutMenu() {
    Menu() {
      MenuItem({
        content: this.tabletLayoutLabelFor(TabletLayoutSettings.MODE_AUTO),
        symbolEndIcon: TabletLayoutSettings.normalizeMode(this.tabletLayout.mode) === TabletLayoutSettings.MODE_AUTO
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setTabletLayout(TabletLayoutSettings.MODE_AUTO)
      })
      MenuItem({
        content: this.tabletLayoutLabelFor(TabletLayoutSettings.MODE_OFF),
        symbolEndIcon: TabletLayoutSettings.normalizeMode(this.tabletLayout.mode) === TabletLayoutSettings.MODE_OFF
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setTabletLayout(TabletLayoutSettings.MODE_OFF)
      })
      MenuItem({
        content: this.tabletLayoutLabelFor(TabletLayoutSettings.MODE_LANDSCAPE_ONLY),
        symbolEndIcon: TabletLayoutSettings.normalizeMode(this.tabletLayout.mode) === TabletLayoutSettings.MODE_LANDSCAPE_ONLY
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setTabletLayout(TabletLayoutSettings.MODE_LANDSCAPE_ONLY)
      })
    }
  }

  @Builder
  private ScreenOrientationMenu() {
    Menu() {
      MenuItem({
        content: this.screenOrientationLabelFor(ScreenOrientationSettings.MODE_UNSPECIFIED),
        symbolEndIcon: ScreenOrientationSettings.normalizeMode(this.screenOrientation.mode) ===
          ScreenOrientationSettings.MODE_UNSPECIFIED
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setScreenOrientation(ScreenOrientationSettings.MODE_UNSPECIFIED)
      })
      MenuItem({
        content: this.screenOrientationLabelFor(
          ScreenOrientationSettings.MODE_AUTO_ROTATION_UNSPECIFIED,
        ),
        symbolEndIcon: ScreenOrientationSettings.normalizeMode(this.screenOrientation.mode) ===
          ScreenOrientationSettings.MODE_AUTO_ROTATION_UNSPECIFIED
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setScreenOrientation(ScreenOrientationSettings.MODE_AUTO_ROTATION_UNSPECIFIED)
      })
    }
  }

  @Builder
  private ReaderPreloadMenuItem(pages: number) {
    MenuItem({
      content: `${pages}`,
      symbolEndIcon: this.readerPresentation.preloadPages === pages
        ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
        : undefined,
    }).onClick((): void => {
      this.saveReaderPreloadPages(pages)
    })
  }

  @Builder
  private ReaderPreloadMenu() {
    Menu() {
      this.ReaderPreloadMenuItem(0)
      this.ReaderPreloadMenuItem(1)
      this.ReaderPreloadMenuItem(2)
      this.ReaderPreloadMenuItem(3)
      this.ReaderPreloadMenuItem(4)
      this.ReaderPreloadMenuItem(5)
    }
  }

  @Builder
  private ReaderAutoPageMenuItem(seconds: number) {
    MenuItem({
      content: AppStrings.format('settings_reader_auto_page_seconds', [seconds.toString()]),
      symbolEndIcon: this.readerPresentation.autoPageSeconds === seconds
        ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
        : undefined,
    }).onClick((): void => {
      this.saveReaderAutoPageSeconds(seconds)
    })
  }

  @Builder
  private ReaderAutoPageMenu() {
    Menu() {
      this.ReaderAutoPageMenuItem(2)
      this.ReaderAutoPageMenuItem(3)
      this.ReaderAutoPageMenuItem(5)
      this.ReaderAutoPageMenuItem(8)
      this.ReaderAutoPageMenuItem(10)
    }
  }

  private async saveReaderMode(mode: NhReaderMode): Promise<void> {
    if (this.readerPresentation.mode === mode) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setMode(this.context(), mode)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_layout_save_failed')
    }
  }

  private async saveReaderKeepScreenOn(enabled: boolean): Promise<void> {
    if (this.readerPresentation.keepScreenOn === enabled) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setKeepScreenOn(this.context(), enabled)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_keep_screen_on_save_failed')
    }
  }

  private async saveReaderPreloadPages(pages: number): Promise<void> {
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setPreloadPages(this.context(), pages)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_preload_save_failed')
    }
  }

  private async saveReaderShowPageNumber(enabled: boolean): Promise<void> {
    if (this.readerPresentation.showPageNumber === enabled) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setShowPageNumber(this.context(), enabled)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_show_page_number_save_failed')
    }
  }

  private async saveReaderImageScalingQuality(quality: NhReaderImageScalingQuality): Promise<void> {
    if (this.readerPresentation.imageScalingQuality === quality) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setImageScalingQuality(this.context(), quality)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_image_scaling_quality_save_failed')
    }
  }

  private async saveReaderBackgroundMode(mode: NhReaderBackgroundMode): Promise<void> {
    if (this.readerPresentation.backgroundMode === mode) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setBackgroundMode(this.context(), mode)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_background_save_failed')
    }
  }

  private async saveReaderFullscreen(enabled: boolean): Promise<void> {
    if (this.readerPresentation.fullscreen === enabled) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setFullscreen(this.context(), enabled)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_fullscreen_save_failed')
    }
  }

  private async saveReaderAutoPageSeconds(seconds: number): Promise<void> {
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setAutoPageSeconds(this.context(), seconds)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_auto_advance_save_failed')
    }
  }

  private async saveReaderVolumeKeyTurn(enabled: boolean): Promise<void> {
    if (this.readerPresentation.volumeKeyTurn === enabled) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setVolumeKeyTurn(this.context(), enabled)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_volume_key_save_failed')
    }
  }

  private async saveReaderDoublePageEnabled(enabled: boolean): Promise<void> {
    if (this.readerPresentation.doublePageEnabled === enabled) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setDoublePageEnabled(this.context(), enabled)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_double_page_save_failed')
    }
  }

  private async saveReaderSpreadLayout(layout: NhReaderSpreadLayout): Promise<void> {
    if (!this.doublePageAvailable()) {
      return
    }
    if (this.readerPresentation.spreadLayoutMode === layout) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setSpreadLayout(this.context(), layout)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_spread_layout_save_failed')
    }
  }

  private async saveReaderPageTurnAnimation(enabled: boolean): Promise<void> {
    if (this.readerPresentation.pageTurnAnimation === enabled) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setPageTurnAnimation(this.context(), enabled)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_page_turn_animation_save_failed')
    }
  }

  private async saveReaderTapZoneLayout(layout: NhReaderTapZoneLayout): Promise<void> {
    if (this.readerPresentation.tapZoneLayout === layout) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setTapZoneLayout(this.context(), layout)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_tap_zone_save_failed')
    }
  }

  private async saveReaderTapZoneInvert(invert: NhReaderTapZoneInvert): Promise<void> {
    if (this.readerPresentation.tapZoneInvert === invert) {
      return
    }
    this.readerModeError = ''
    try {
      await ReaderPresentationService.setTapZoneInvert(this.context(), invert)
    } catch (_error) {
      this.readerModeError = AppStrings.get('settings_reader_tap_zone_save_failed')
    }
  }

  private readerAutoPageLabel(): string {
    return AppStrings.format('settings_reader_auto_page_seconds', [this.readerPresentation.autoPageSeconds.toString()])
  }

  private readerPreloadLabel(): string {
    const pages: number = this.readerPresentation.preloadPages
    return pages === 1
      ? AppStrings.format('settings_reader_preload_page_one', [pages.toString()])
      : AppStrings.format('settings_reader_preload_page_other', [pages.toString()])
  }

  private toggleStateLabel(enabled: boolean): string {
    return AppStrings.get(enabled ? 'settings_toggle_on' : 'settings_toggle_off')
  }

  private cacheSizeLabel(bytes: number): string {
    const normalized: number = Math.max(0, Math.floor(bytes))
    if (normalized < 1024) {
      return AppStrings.format('settings_cache_size_bytes', [normalized.toString()])
    }
    if (normalized < 1024 * 1024) {
      return AppStrings.format('settings_cache_size_kilobytes', [Math.ceil(normalized / 1024).toString()])
    }
    const tenths: number = Math.round((normalized * 10) / (1024 * 1024))
    return AppStrings.format('settings_cache_size_megabytes', [
      Math.floor(tenths / 10).toString(),
      (tenths % 10).toString(),
    ])
  }

  private privateCacheSubtitle(key: string): string {
    if (this.isLoadingPrivateCache) {
      return AppStrings.get('settings_private_cache_calculating')
    }
    const stat: CacheStat = this.privateCacheStat(key)
    return AppStrings.format('settings_private_cache_summary', [
      stat.count.toString(),
      this.cacheSizeLabel(stat.bytes),
    ])
  }

  private privateCacheTitle(key: string): string {
    if (key === 'page') {
      return AppStrings.get('settings_private_cache_pages')
    }
    if (key === 'image') {
      return AppStrings.get('settings_private_cache_image')
    }
    if (key === 'comment') {
      return AppStrings.get('settings_private_cache_comment_translation')
    }
    if (key === 'comic') {
      return AppStrings.get('settings_private_cache_comic_translation')
    }
    return AppStrings.get('settings_private_cache_comic_translation')
  }

  private requestPrivateCacheClear(key: string): void {
    if (this.isClearingPrivateCache || this.privateCacheStat(key).count === 0) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.format('settings_private_cache_clear_title', [this.privateCacheTitle(key)]),
      message: AppStrings.format('settings_private_cache_clear_message', [this.privateCacheTitle(key)]),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('common_clear'),
        fontColor: Color.Red,
        action: (): void => {
          this.performPrivateCacheClear(key)
        },
      },
    })
  }

  private requestAllPrivateCachesClear(): void {
    if (this.isClearingPrivateCache || this.privateCacheTotalCount() === 0) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('settings_private_cache_clear_all_title'),
      message: AppStrings.get('settings_private_cache_clear_all_message'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('common_clear'),
        fontColor: Color.Red,
        action: (): void => {
          this.performPrivateCacheClear('all')
        },
      },
    })
  }

  private readerCacheLimitLabel(): string {
    if (this.readerCacheLimitMb >= 1024) {
      return `${this.readerCacheLimitMb / 1024} GB`
    }
    return `${this.readerCacheLimitMb} MB`
  }

  private setReaderCacheLimit(limitMb: number): void {
    this.readerCacheLimitMb = limitMb
    ReaderImageCacheSettings.setLimitMb(this.context(), limitMb).catch((): void => {})
  }

  @Builder
  private ReaderCacheLimitMenuItem(limitMb: number, label: string) {
    MenuItem({
      content: label,
      symbolEndIcon: this.readerCacheLimitMb === limitMb
        ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
        : undefined,
    }).onClick((): void => {
      this.setReaderCacheLimit(limitMb)
    })
  }

  @Builder
  private ReaderCacheLimitMenu() {
    Menu() {
      this.ReaderCacheLimitMenuItem(256, '256 MB')
      this.ReaderCacheLimitMenuItem(512, '512 MB')
      this.ReaderCacheLimitMenuItem(1024, '1 GB')
      this.ReaderCacheLimitMenuItem(2048, '2 GB')
    }
  }

  @Builder
  private ReaderCacheLimitGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.externaldrive'),
        title: AppStrings.get('settings_reader_image_cache_limit'),
        trailingText: this.readerCacheLimitLabel(),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.ReaderCacheLimitMenu()
        },
        accessibilityLabel: AppStrings.format('settings_reader_image_cache_limit_a11y', [
          this.readerCacheLimitLabel(),
        ]),
      })
    }
  }

  @Builder
  private RootAccountSection() {
    NextNGroupedListSection() {
      if (this.isAccountSignedIn && this.accountProfile.hasSnapshot) {
        NextNListRow({
          useCustomLeading: true,
          customLeading: (): void => {
            this.AccountAvatarPrefix()
          },
          title: this.accountProfile.username,
          subtitle: AppStrings.format('account_profile_id', [this.accountProfile.userId]),
          selected: this.isSettingsRootSelected(SETTINGS_ROOT_ACCOUNT),
          accessibilityLabel: AppStrings.get('account_open_page_a11y'),
          accessibilityId: 'nextn-settings-root-account',
          onAction: (): void => {
            if (this.onOpenAccount) {
              this.onOpenAccount()
            } else if (this.onOpenBrowserSession) {
              this.onOpenBrowserSession()
            }
          },
        })
      } else {
        NextNListRow({
          leadingIcon: $r('sys.symbol.person'),
          title: AppStrings.get('account_title'),
          subtitle: this.isAccountSignedIn
            ? AppStrings.get('account_subtitle_signed_in_device')
            : AppStrings.get('account_subtitle_sign_in'),
          trailingText: this.isAccountSignedIn ? AppStrings.get('account_status_signed_in') : '',
          selected: this.isAccountSignedIn
            ? this.isSettingsRootSelected(SETTINGS_ROOT_ACCOUNT)
            : this.isSettingsRootSelected(SETTINGS_ROOT_BROWSER_SESSION),
          accessibilityLabel: AppStrings.get('account_open_page_a11y'),
          accessibilityId: 'nextn-settings-root-account',
          onAction: (): void => {
            // Let the route owner decide from durable accounts and the live
            // session together. This copied display flag can lag a sign-out.
            if (this.onOpenAccount) {
              this.onOpenAccount()
            } else if (this.onOpenBrowserSession) {
              this.onOpenBrowserSession()
            }
          },
        })
      }
    }
  }

  /** User-directed: History is its own card between the account and settings groups. */
  @Builder
  private RootHistorySection() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.clock'),
        title: AppStrings.get('tab_history'),
        selected: this.isSettingsRootSelected(SETTINGS_ROOT_HISTORY),
        accessibilityLabel: AppStrings.get('tab_history'),
        onAction: (): void => {
          if (this.onOpenHistory) {
            this.onOpenHistory()
          }
        },
      })
    }
  }

  /** Same 44vp circular identity prefix as NextE's Settings root. */
  @Builder
  private AccountAvatar() {
    Stack() {
      if (this.accountProfile.avatarUrl.length > 0) {
        Image(this.accountProfile.avatarUrl)
          .width(ThemeTokens.ACCOUNT_AVATAR_SIZE)
          .height(ThemeTokens.ACCOUNT_AVATAR_SIZE)
          .objectFit(ImageFit.Cover)
      } else {
        SymbolGlyph($r('sys.symbol.person_fill'))
          .fontSize(ThemeTokens.ACCOUNT_AVATAR_SIZE / 2)
          .fontColor([Color.White])
      }
    }
    .width(ThemeTokens.ACCOUNT_AVATAR_SIZE)
    .height(ThemeTokens.ACCOUNT_AVATAR_SIZE)
    .borderRadius(ThemeTokens.ACCOUNT_AVATAR_SIZE / 2)
    .clip(true)
    .backgroundColor(ThemeTokens.BRAND)
  }

  /**
   * HDS custom prefixes have no automatic image-to-text gap. Reserve the same
   * 6 + 44 + 13vp track that NextE's ConciseListRow uses for its account
   * avatar, instead of inheriting the oversized generic PrefixImage track.
   */
  @Builder
  private AccountAvatarPrefix() {
    Row() {
      this.AccountAvatar()
      Blank().width(ThemeTokens.ACCOUNT_AVATAR_PREFIX_TEXT_GAP)
    }
    .padding({ left: ThemeTokens.ACCOUNT_AVATAR_PREFIX_LEFT_INSET })
  }

  /** Directly mirrors the NextE Settings root-list grammar for real NextN capabilities. */
  @Builder
  private RootMainSection() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.paintpalette'),
        title: AppStrings.get('settings_layout'),
        selected: this.isSettingsRootSelected(SETTINGS_ROOT_LAYOUT),
        accessibilityLabel: AppStrings.get('settings_layout'),
        onAction: (): void => {
          if (this.onOpenLayoutSettings) {
            this.onOpenLayoutSettings()
          }
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.square_grid_2x2'),
        title: AppStrings.get('settings_browse'),
        selected: this.isSettingsRootSelected(SETTINGS_ROOT_BROWSE),
        accessibilityLabel: AppStrings.get('settings_browse'),
        onAction: (): void => {
          if (this.onOpenBrowseSettings) {
            this.onOpenBrowseSettings()
          }
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.magnifyingglass'),
        title: AppStrings.get('settings_search'),
        selected: this.isSettingsRootSelected(SETTINGS_ROOT_SEARCH),
        accessibilityLabel: AppStrings.get('settings_search'),
        onAction: (): void => {
          if (this.onOpenSearchSettings) {
            this.onOpenSearchSettings()
          }
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.doc_plaintext'),
        title: AppStrings.get('settings_reader'),
        selected: this.isSettingsRootSelected(SETTINGS_ROOT_READER),
        accessibilityLabel: AppStrings.get('settings_reader'),
        onAction: (): void => {
          if (this.onOpenReaderSettings) {
            this.onOpenReaderSettings()
          }
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.arrow_down_to_line'),
        title: AppStrings.get('settings_download'),
        selected: this.isSettingsRootSelected(SETTINGS_ROOT_DOWNLOAD),
        accessibilityLabel: AppStrings.get('settings_download'),
        onAction: (): void => {
          if (this.onOpenDownloadSettings) {
            this.onOpenDownloadSettings()
          }
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.externaldrive'),
        title: AppStrings.get('settings_cache'),
        selected: this.isSettingsRootSelected(SETTINGS_ROOT_CACHE),
        accessibilityLabel: AppStrings.get('settings_cache'),
        onAction: (): void => {
          if (this.onOpenCacheSettings) {
            this.onOpenCacheSettings()
          }
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.gearshape'),
        title: AppStrings.get('settings_advanced'),
        selected: this.isSettingsRootSelected(SETTINGS_ROOT_ADVANCED),
        accessibilityLabel: AppStrings.get('settings_advanced'),
        onAction: (): void => {
          if (this.onOpenAdvancedSettings) {
            this.onOpenAdvancedSettings()
          }
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.info_circle'),
        title: AppStrings.get('settings_about'),
        selected: this.isSettingsRootSelected(SETTINGS_ROOT_ABOUT),
        accessibilityLabel: AppStrings.get('settings_about'),
        onAction: (): void => {
          if (this.onOpenAbout) {
            this.onOpenAbout()
          }
        },
      })
    }
  }

  private async performPrivateCacheClear(key: string): Promise<void> {
    if (this.isClearingPrivateCache) {
      return
    }
    this.isClearingPrivateCache = true
    this.privateCacheError = ''
    try {
      if (key === 'page') {
        await NhPageCacheService.clearAll(this.context())
      } else if (key === 'image') {
        await ImagePipelineService.clearCache(this.context())
      } else if (key === 'comment') {
        await CommentTranslationService.clear(this.context())
      } else if (key === 'comic') {
        await ComicTranslationRuntimeService.clearGeneratedCache(this.context())
      } else if (key === 'all') {
        await NhPageCacheService.clearAll(this.context())
        await ImagePipelineService.clearCache(this.context())
        await CommentTranslationService.clear(this.context())
        await ComicTranslationRuntimeService.clearGeneratedCache(this.context())
      }
    } catch (_error) {
      this.privateCacheError = AppStrings.get('settings_private_cache_clear_failed')
    } finally {
      this.isClearingPrivateCache = false
      this.loadPrivateCacheStatus()
    }
  }

  @Builder
  private RowDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(ThemeTokens.DIVIDER)
      .margin({ left: ThemeTokens.SPACE_MD })
  }

  @Builder
  private GroupNote(text: string) {
    Text(text)
      .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
      .fontColor(ThemeTokens.TEXT_SECONDARY)
      .maxLines(3)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .width('100%')
      .padding({
        left: ThemeTokens.SPACE_MD,
        right: ThemeTokens.SPACE_MD,
      })
  }

  @Builder
  private DiagnosticsLevelMenu() {
    Menu() {
      this.DiagnosticsLevelMenuItem(DiagnosticsSettings.LEVEL_DEBUG)
      this.DiagnosticsLevelMenuItem(DiagnosticsSettings.LEVEL_INFO)
      this.DiagnosticsLevelMenuItem(DiagnosticsSettings.LEVEL_WARN)
      this.DiagnosticsLevelMenuItem(DiagnosticsSettings.LEVEL_ERROR)
    }
  }

  @Builder
  private DiagnosticsLevelMenuItem(level: string) {
    MenuItem({
      content: this.diagnosticsLevelLabel(level),
      symbolEndIcon: this.diagnostics.minLevel === level
        ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
        : undefined,
    })
      .onClick((): void => {
        this.updateDiagnosticsMinLevel(level)
      })
  }

  @Builder
  private DiagnosticsSettingsGroup() {
    NextNGroupedListSection({ accessibilityId: 'nextn-diagnostics-settings-group' }) {
      NextNListRow({
        leadingIcon: $r('sys.symbol.doc_plaintext'),
        title: AppStrings.get('diagnostics_enabled'),
        subtitle: AppStrings.get('diagnostics_enabled_hint'),
        hasSwitch: true,
        checked: this.diagnostics.enabled,
        showChevron: false,
        onAction: (): void => {
          this.updateDiagnosticsEnabled(!this.diagnostics.enabled)
        },
        onSwitchChange: (value: boolean): void => {
          this.updateDiagnosticsEnabled(value)
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.textformat'),
        title: AppStrings.get('diagnostics_min_level'),
        subtitle: AppStrings.get('diagnostics_min_level_hint'),
        trailingText: this.diagnosticsLevelLabel(this.diagnostics.minLevel),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.DiagnosticsLevelMenu()
        },
      })
    }
  }

  @Builder
  private DiagnosticsActionsGroup() {
    NextNGroupedListSection({ accessibilityId: 'nextn-diagnostics-actions-group' }) {
      NextNListRow({
        leadingIcon: $r('sys.symbol.arrow_clockwise'),
        title: AppStrings.format('diagnostics_current_launch_recent_count', [`${this.diagnosticsLogCount}`]),
        subtitle: this.retainedDiagnosticsSubtitle(),
        showChevron: false,
        onAction: (): void => {
          this.refreshDiagnosticsState()
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.share'),
        title: AppStrings.get('diagnostics_export_current'),
        subtitle: AppStrings.get('diagnostics_export_current_hint'),
        showChevron: false,
        onAction: (): void => {
          this.exportCurrentDiagnostics()
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.square_and_pencil'),
        title: AppStrings.get('advanced_write_marker'),
        subtitle: AppStrings.get('advanced_diagnostics_hint'),
        showChevron: false,
        onAction: (): void => {
          this.writeDiagnosticsMarker()
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.trash'),
        title: AppStrings.get('clear_boot_records'),
        destructive: true,
        showChevron: false,
        onAction: (): void => {
          this.clearDiagnosticsMemory()
        },
      })
    }
  }

  @Builder
  private DiagnosticsFilesGroup() {
    NextNGroupedListSection({ accessibilityId: 'nextn-diagnostics-files-group' }) {
      if (this.diagnosticsLogFiles.length <= 0) {
        NextNListRow({
          leadingIcon: $r('sys.symbol.folder'),
          title: AppStrings.get('no_log_files'),
          subtitle: AppStrings.get('reopen_keeps_logs'),
          showChevron: false,
          onAction: (): void => {
            this.refreshDiagnosticsState()
          },
        })
      } else {
        ForEach(this.diagnosticsLogFiles, (file: DiagnosticsLogFileInfo, index: number): void => {
          NextNListRow({
            leadingIcon: $r('sys.symbol.doc_plaintext'),
            title: this.diagnosticsLogTitle(file),
            subtitle: AppStrings.format('diagnostics_log_file_share_hint', [
              this.formatDiagnosticsFileSize(file.sizeBytes),
            ]),
            showChevron: false,
            onAction: (): void => {
              this.shareRetainedDiagnostics(file)
            },
          })
          if (index < this.diagnosticsLogFiles.length - 1) {
            this.RowDivider()
          }
        }, (file: DiagnosticsLogFileInfo): string => file.fileName)
      }
    }
  }

  @Builder
  private ClipboardLinkGroup() {
    if (ClipboardLinkBuildFlag.CLIPBOARD_LINK_BUILD_ENABLED) {
      NextNGroupedListSection() {
        NextNListRow({
          leadingIcon: $r('sys.symbol.link'),
          title: AppStrings.get('settings_clipboard_link'),
          subtitle: AppStrings.get('settings_clipboard_link_hint'),
          hasSwitch: true,
          checked: this.clipboardLink.enabled,
          showChevron: false,
          accessibilityLabel: AppStrings.format('settings_row_a11y', [
            AppStrings.get('settings_clipboard_link'),
            this.toggleStateLabel(this.clipboardLink.enabled),
          ]),
          onAction: (): void => {
            this.setClipboardLinkEnabled(!this.clipboardLink.enabled)
          },
          onSwitchChange: (value: boolean): void => {
            this.setClipboardLinkEnabled(value)
          },
        })
      }
    }
  }

  // ── Backup/restore (ported from NextE CacheSettingsPage) ─────────────────
  private loadAppVersion(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION,
      )
      this.appVersion = info.versionName
      this.appVersionCode = info.versionCode
    } catch (_error) {
      this.appVersion = '0'
      this.appVersionCode = 0
    }
  }

  private toast(message: ResourceStr): void {
    this.getUIContext().getPromptAction().showToast({ message: message })
  }

  private metadata(): BackupAppMetadata {
    return { appVersion: this.appVersion, appVersionCode: this.appVersionCode }
  }

  private importFailureText(result: BackupParseResult): ResourceStr {
    if (result.code === 'too_large') {
      return AppStrings.get('backup_import_too_large')
    }
    if (result.code === 'not_json') {
      return AppStrings.get('backup_import_not_json')
    }
    if (result.code === 'foreign_backup') {
      return AppStrings.get('backup_import_foreign')
    }
    if (result.code === 'unsupported_version') {
      return AppStrings.get('backup_import_unsupported')
    }
    if (result.code === 'bad_checksum') {
      return AppStrings.get('backup_import_bad_checksum')
    }
    if (result.code === 'malformed') {
      return AppStrings.get('backup_import_malformed')
    }
    return AppStrings.get('backup_import_invalid')
  }

  private localDataCount(preview: BackupPreview): number {
    const counts = preview.counts.localData
    if (counts === undefined) {
      return 0
    }
    return counts.readProgress + counts.viewedHistory + counts.searchHistory +
      counts.quickSearches + counts.localBlockRules + counts.settingsTableGroups
  }

  private restorePreviewMessage(preview: BackupPreview): string {
    const lines: string[] = [
      AppStrings.get('backup_restore_confirm_message'),
      '',
      `${AppStrings.get('backup_restore_preview_version')}: ${preview.appVersion} (${preview.appVersionCode})`,
      `${AppStrings.get('backup_restore_preview_type')}: ${preview.hasSecrets ?
        AppStrings.get('backup_restore_preview_encrypted') :
        AppStrings.get('backup_restore_preview_plain')}`,
      `${AppStrings.get('backup_restore_preview_preferences')}: ${preview.counts.preferences}`,
      `${AppStrings.get('backup_restore_preview_local_data')}: ${this.localDataCount(preview)}`,
    ]
    if (preview.hasSecrets) {
      const secretCount: number = preview.counts.secrets === undefined ? 0 : preview.counts.secrets
      lines.push(`${AppStrings.get('backup_restore_preview_secrets')}: ${secretCount}`)
    }
    return lines.join('\n')
  }

  private timeStamp(): string {
    const d: Date = new Date()
    const p = (n: number): string => (n < 10 ? `0${n}` : `${n}`)
    return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}${p(d.getHours())}${p(d.getMinutes())}`
  }

  private openExport(): void {
    this.includeSecrets = false
    this.exportPwd = ''
    this.exportPwd2 = ''
    this.exportDialogController.open()
  }

  private closeExportDialog(): void {
    try {
      this.exportDialogController.close()
    } catch (_error) {
      // Dialog may already be dismissed by tapping outside.
    }
    this.exportPwd = ''
    this.exportPwd2 = ''
  }

  private confirmExport(): void {
    if (this.busy) {
      return
    }
    if (this.includeSecrets) {
      if (this.exportPwd.length === 0) {
        this.toast(AppStrings.get('backup_password_required'))
        return
      }
      if (this.exportPwd !== this.exportPwd2) {
        this.toast(AppStrings.get('backup_password_mismatch'))
        return
      }
    }
    this.busy = true
    BackupFilePickerCoordinator.exportBackup(
      this.context(),
      this.metadata(),
      { includeSecrets: this.includeSecrets, password: this.exportPwd },
      this.timeStamp(),
    )
      .then(() => {
        this.closeExportDialog()
        this.toast(AppStrings.get('backup_export_done'))
      })
      .catch((error: Error) => {
        if (error.message !== 'save cancelled') {
          this.toast(AppStrings.get('backup_export_failed'))
        }
      })
      .finally(() => {
        this.busy = false
      })
  }

  private startImport(): void {
    if (this.busy) {
      return
    }
    this.busy = true
    BackupFilePickerCoordinator.selectImport(this.context())
      .then((selection: BackupImportSelection) => {
        const result: BackupParseResult = selection.parseResult
        if (result.encrypted === true) {
          this.pendingImportRaw = selection.raw
          this.importPwd = ''
          this.importPasswordDialogController.open()
          return
        }
        if (!result.ok || result.envelope === undefined) {
          this.toast(this.importFailureText(result))
          return
        }
        this.confirmRestore(result)
      })
      .catch((error: Error) => {
        if (error.message === 'backup file is too large') {
          this.toast(AppStrings.get('backup_import_too_large'))
        } else if (error.message !== 'open cancelled') {
          this.toast(AppStrings.get('backup_import_invalid'))
        }
      })
      .finally(() => {
        this.busy = false
      })
  }

  private confirmDecryptImport(): void {
    if (this.busy || this.importPwd.length === 0) {
      return
    }
    this.busy = true
    BackupFilePickerCoordinator.decryptSelected(this.pendingImportRaw, this.importPwd)
      .then((result: BackupParseResult) => {
        if (!result.ok || result.envelope === undefined) {
          this.toast(
            result.code === 'bad_password'
              ? AppStrings.get('backup_bad_password')
              : this.importFailureText(result),
          )
          return
        }
        this.closeImportPasswordDialog()
        this.importPwd = ''
        this.pendingImportRaw = ''
        this.confirmRestore(result)
      })
      .finally(() => {
        this.busy = false
      })
  }

  private closeImportPasswordDialog(): void {
    try {
      this.importPasswordDialogController.close()
    } catch (_error) {
      // Dialog may already be dismissed by tapping outside.
    }
    this.importPwd = ''
    this.pendingImportRaw = ''
  }

  // Restore overwrites the current settings, so confirm first.
  private confirmRestore(result: BackupParseResult): void {
    const envelope = result.envelope
    if (envelope === undefined) {
      return
    }
    const preview: BackupPreview = BackupService.preview(envelope)
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('backup_restore_confirm_title'),
      message: this.restorePreviewMessage(preview),
      primaryButton: { value: AppStrings.get('common_cancel'), action: () => {} },
      secondaryButton: {
        value: AppStrings.get('backup_restore_apply'),
        action: () => {
          this.busy = true
          BackupFilePickerCoordinator.restoreSelected(this.context(), envelope)
            .then(() => {
              this.toast(AppStrings.get('backup_import_done'))
            })
            .catch(() => {
              this.toast(AppStrings.get('backup_import_invalid'))
            })
            .finally(() => {
              this.busy = false
            })
        },
      },
    })
  }

  @Builder
  private SyncGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.cloud'),
        title: AppStrings.get('settings_sync'),
        subtitle: AppStrings.get('settings_sync_hint'),
        onAction: (): void => {
          if (this.onOpenSyncSettings) {
            this.onOpenSyncSettings()
          }
        },
      })
    }
  }

  @Builder
  private BackupGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.cloud_and_arrow_up'),
        title: AppStrings.get('backup_export'),
        subtitle: AppStrings.get('backup_export_subtitle'),
        showChevron: false,
        isEnabled: !this.busy,
        onAction: (): void => {
          this.openExport()
        },
      })
      this.RowDivider()
      NextNListRow({
        title: AppStrings.get('backup_import'),
        leadingIcon: $r('sys.symbol.cloud_and_arrow_down'),
        subtitle: AppStrings.get('backup_import_subtitle'),
        showChevron: false,
        isEnabled: !this.busy,
        onAction: (): void => {
          this.startImport()
        },
      })
    }
  }

  @Builder
  private ExportDialogContent() {
    Column({ space: ThemeTokens.SPACE_MD }) {
      Row({ space: ThemeTokens.SPACE_SM }) {
        Column({ space: ThemeTokens.SPACE_XS }) {
          Text(AppStrings.get('backup_include_secrets'))
            .fontSize(ThemeTokens.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.TEXT_PRIMARY)
            .width('100%')
          Text(AppStrings.get('backup_include_secrets_hint'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.includeSecrets })
          .selectedColor(ThemeTokens.BRAND)
          .onChange((value: boolean) => {
            this.includeSecrets = value
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      if (this.includeSecrets) {
        this.ExportPasswordField(false)
        this.ExportPasswordField(true)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private ImportPasswordDialogContent() {
    Column({ space: ThemeTokens.SPACE_MD }) {
      Text(AppStrings.get('backup_encrypted_hint'))
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .width('100%')
      TextInput({ text: this.importPwd, placeholder: AppStrings.get('backup_password') })
        .type(InputType.Password)
        .defaultFocus(true)
        .width('100%')
        .onChange((value: string) => {
          this.importPwd = value
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private ExportPasswordField(isRepeat: boolean) {
    TextInput({ text: isRepeat ? this.exportPwd2 : this.exportPwd, placeholder: isRepeat ? AppStrings.get('backup_password_repeat') : AppStrings.get('backup_password') })
      .type(InputType.Password)
      .width('100%')
      .onChange((value: string) => {
        if (isRepeat) {
          this.exportPwd2 = value
        } else {
          this.exportPwd = value
        }
      })
  }

  @Builder
  private PrivateCacheTotalSummary() {
    Row({ space: ThemeTokens.SPACE_XS }) {
      Text(AppStrings.get('settings_private_cache_total'))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
      Text(this.isLoadingPrivateCache
        ? AppStrings.get('settings_private_cache_calculating')
        : this.cacheSizeLabel(this.privateCacheTotalBytes()))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
    }
    .width('100%')
    .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
  }

  @Builder
  private CacheClearSuffix(key: string) {
    Button(AppStrings.get('common_clear'))
      .buttonStyle(ButtonStyleMode.NORMAL)
      .backgroundColor(Color.Transparent)
      .fontSize(ThemeTokens.FONT_SIZE_BODY)
      .fontColor(
        this.privateCacheStat(key).count > 0 && !this.isClearingPrivateCache
          ? Color.Red
          : ThemeTokens.TEXT_TERTIARY,
      )
      .enabled(this.privateCacheStat(key).count > 0 && !this.isClearingPrivateCache)
      .padding({ left: ThemeTokens.SPACE_SM, right: ThemeTokens.SPACE_MD })
      .onClick(() => {
        this.requestPrivateCacheClear(key)
      })
  }

  @Builder
  private PrivateCacheGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.doc_text'),
        title: this.privateCacheTitle('page'),
        subtitle: this.privateCacheSubtitle('page'),
        showChevron: false,
        useCustomTrailing: true,
        suffixPaddingRight: 0,
        customTrailing: (): void => {
          this.CacheClearSuffix('page')
        },
        accessibilityLabel: AppStrings.format('settings_private_cache_clear_a11y', [
          this.privateCacheTitle('page'),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.picture'),
        title: this.privateCacheTitle('image'),
        subtitle: this.privateCacheSubtitle('image'),
        showChevron: false,
        useCustomTrailing: true,
        suffixPaddingRight: 0,
        customTrailing: (): void => {
          this.CacheClearSuffix('image')
        },
        accessibilityLabel: AppStrings.format('settings_private_cache_clear_a11y', [
          this.privateCacheTitle('image'),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.translate'),
        title: this.privateCacheTitle('comment'),
        subtitle: this.privateCacheSubtitle('comment'),
        showChevron: false,
        useCustomTrailing: true,
        suffixPaddingRight: 0,
        customTrailing: (): void => {
          this.CacheClearSuffix('comment')
        },
        accessibilityLabel: AppStrings.format('settings_private_cache_clear_a11y', [
          this.privateCacheTitle('comment'),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.text_bubble_left_2'),
        title: this.privateCacheTitle('comic'),
        subtitle: this.privateCacheSubtitle('comic'),
        showChevron: false,
        useCustomTrailing: true,
        suffixPaddingRight: 0,
        customTrailing: (): void => {
          this.CacheClearSuffix('comic')
        },
        accessibilityLabel: AppStrings.format('settings_private_cache_clear_a11y', [
          this.privateCacheTitle('comic'),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.trash'),
        title: AppStrings.get('settings_private_cache_clear_all'),
        showChevron: false,
        destructive: true,
        isEnabled: !this.isClearingPrivateCache,
        accessibilityLabel: AppStrings.get('settings_private_cache_clear_all'),
        onAction: (): void => {
          this.requestAllPrivateCachesClear()
        },
      })
    }
  }

  @Builder
  private DownloadPolicyGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.arrow_down_to_line'),
        title: AppStrings.get('settings_download_gallery_concurrency'),
        trailingText: `${this.downloadSettings.maxConcurrentGalleries}`,
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.GalleryConcurrencyMenu()
        },
        isEnabled: !this.isSavingDownloadSettings,
        accessibilityLabel: AppStrings.format('settings_download_gallery_concurrency_a11y', [
          this.downloadSettings.maxConcurrentGalleries.toString(),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.square_grid_2x2'),
        title: AppStrings.get('settings_download_page_concurrency'),
        trailingText: `${this.downloadSettings.maxConcurrentPages}`,
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.PageConcurrencyMenu()
        },
        isEnabled: !this.isSavingDownloadSettings,
        accessibilityLabel: AppStrings.format('settings_download_page_concurrency_a11y', [
          this.downloadSettings.maxConcurrentPages.toString(),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.clock'),
        title: AppStrings.get('settings_download_request_interval'),
        subtitle: AppStrings.get('settings_download_request_interval_hint'),
        trailingText: this.requestIntervalLabel(this.downloadSettings.requestIntervalSeconds),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.RequestIntervalMenu()
        },
        isEnabled: !this.isSavingDownloadSettings,
        accessibilityLabel: AppStrings.format('settings_download_request_interval_a11y', [
          this.requestIntervalLabel(this.downloadSettings.requestIntervalSeconds),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.list_number'),
        title: AppStrings.get('settings_download_failed_page_retries'),
        trailingText: this.retryCountLabel(),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.RetryCountMenu()
        },
        isEnabled: !this.isSavingDownloadSettings,
        accessibilityLabel: AppStrings.format('settings_download_failed_page_retries_a11y', [
          this.retryCountLabel(),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.repeat'),
        title: AppStrings.get('settings_download_auto_retry_failed'),
        subtitle: AppStrings.get('settings_download_auto_retry_failed_hint'),
        hasSwitch: true,
        checked: this.downloadSettings.autoRetryFailed,
        showChevron: false,
        isEnabled: !this.isSavingDownloadSettings,
        accessibilityLabel: AppStrings.format('settings_download_auto_retry_failed_a11y', [
          this.toggleStateLabel(this.downloadSettings.autoRetryFailed),
        ]),
        onAction: (): void => {
          this.saveAutoRetryFailed(!this.downloadSettings.autoRetryFailed)
        },
        onSwitchChange: (value: boolean): void => {
          this.saveAutoRetryFailed(value)
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.clock'),
        title: AppStrings.get('settings_download_speed_limit'),
        subtitle: AppStrings.get('settings_download_speed_limit_hint'),
        trailingText: this.speedLimitLabel(this.downloadSettings.speedLimitKbps),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.SpeedLimitMenu()
        },
        isEnabled: !this.isSavingDownloadSettings,
        accessibilityLabel: AppStrings.format('settings_download_speed_limit_a11y', [
          this.speedLimitLabel(this.downloadSettings.speedLimitKbps),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.bell'),
        title: AppStrings.get('settings_download_notify_complete'),
        subtitle: AppStrings.get('settings_download_notify_complete_hint'),
        hasSwitch: true,
        checked: this.downloadSettings.notifyOnComplete,
        showChevron: false,
        isEnabled: !this.isSavingDownloadSettings,
        accessibilityLabel: AppStrings.format('settings_download_notify_complete_a11y', [
          this.toggleStateLabel(this.downloadSettings.notifyOnComplete),
        ]),
        onAction: (): void => {
          this.saveCompletionNotifications(!this.downloadSettings.notifyOnComplete)
        },
        onSwitchChange: (value: boolean): void => {
          this.saveCompletionNotifications(value)
        },
      })
    }
  }

  @Builder
  private DownloadRestoreGroup() {
    NextNGroupedListSection() {
      if (this.isRestoringDownloadTasks) {
        NextNListRow({
          leadingIcon: $r('sys.symbol.arrow_clockwise'),
          title: AppStrings.get('settings_download_restore_tasks'),
          subtitle: AppStrings.get('settings_download_restore_tasks_scanning'),
          showChevron: false,
          isEnabled: false,
          useCustomTrailing: true,
          customTrailing: (): void => {
            this.DownloadRestoreBusySuffix()
          },
          accessibilityLabel: AppStrings.get('settings_download_restore_tasks_scanning'),
        })
      } else {
        NextNListRow({
          leadingIcon: $r('sys.symbol.arrow_clockwise'),
          title: AppStrings.get('settings_download_restore_tasks'),
          subtitle: AppStrings.get('settings_download_restore_tasks_hint'),
          showChevron: false,
          isEnabled: !this.isSavingDownloadSettings,
          accessibilityLabel: AppStrings.get('settings_download_restore_tasks_a11y'),
          onAction: (): void => {
            this.restoreDownloadTasks()
          },
        })
      }
    }
  }

  @Builder
  private DownloadRestoreBusySuffix() {
    LoadingProgress()
      .width(22)
      .height(22)
      .color(ThemeTokens.BRAND)
  }

  @Builder
  private ReaderLayoutGroup() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      NextNSectionHeader({ title: AppStrings.get('settings_reader_group_layout') })
      NextNGroupedListSection() {
        NextNListRow({
          title: AppStrings.get('settings_reader_layout'),
          trailingText: this.readerModeLabel(),
          trailingDropdown: true,
          dropdownMenuEnabled: true,
          dropdownMenuBuilder: () => {
            this.ReaderModeMenu()
          },
          accessibilityLabel: AppStrings.format('settings_reader_layout_a11y', [this.readerModeLabel()]),
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_double_page'),
          hasSwitch: true,
          checked: this.doublePageAvailable() && this.readerPresentation.doublePageEnabled,
          isEnabled: this.doublePageAvailable(),
          showChevron: false,
          accessibilityLabel: AppStrings.format('settings_reader_double_page_a11y', [
            this.toggleStateLabel(this.doublePageAvailable() && this.readerPresentation.doublePageEnabled),
          ]),
          onAction: (): void => {
            if (this.doublePageAvailable()) {
              this.saveReaderDoublePageEnabled(!this.readerPresentation.doublePageEnabled)
            }
          },
          onSwitchChange: (value: boolean): void => {
            if (this.doublePageAvailable()) {
              this.saveReaderDoublePageEnabled(value)
            }
          },
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_spread_layout'),
          trailingText: this.readerSpreadLayoutLabel(),
          trailingDropdown: true,
          dropdownMenuEnabled: true,
          dropdownMenuBuilder: () => {
            this.ReaderSpreadLayoutMenu()
          },
          isEnabled: this.doublePageAvailable(),
          accessibilityLabel: AppStrings.format('settings_reader_spread_layout_a11y', [
            this.readerSpreadLayoutLabel(),
          ]),
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_page_turn_animation'),
          hasSwitch: true,
          checked: this.readerPresentation.pageTurnAnimation,
          showChevron: false,
          accessibilityLabel: AppStrings.format('settings_reader_page_turn_animation_a11y', [
            this.toggleStateLabel(this.readerPresentation.pageTurnAnimation),
          ]),
          onAction: (): void => {
            this.saveReaderPageTurnAnimation(!this.readerPresentation.pageTurnAnimation)
          },
          onSwitchChange: (value: boolean): void => {
            this.saveReaderPageTurnAnimation(value)
          },
        })
      }
    }
  }

  @Builder
  private ReaderTapZonesGroup() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      NextNSectionHeader({ title: AppStrings.get('settings_reader_group_tap_zones') })
      NextNGroupedListSection() {
        NextNListRow({
          title: AppStrings.get('settings_reader_tap_zones'),
          trailingText: this.readerTapZoneLayoutLabel(),
          trailingDropdown: true,
          dropdownMenuEnabled: true,
          dropdownMenuBuilder: () => {
            this.ReaderTapZoneMenu()
          },
          accessibilityLabel: AppStrings.format('settings_reader_tap_zones_a11y', [
            this.readerTapZoneLayoutLabel(),
          ]),
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_tap_zone_invert'),
          trailingText: this.readerTapZoneInvertLabel(),
          trailingDropdown: true,
          dropdownMenuEnabled: true,
          dropdownMenuBuilder: () => {
            this.ReaderTapZoneInvertMenu()
          },
          accessibilityLabel: AppStrings.format('settings_reader_tap_zone_invert_a11y', [
            this.readerTapZoneInvertLabel(),
          ]),
        })
      }
    }
  }

  @Builder
  private ReaderDisplayGroup() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      NextNSectionHeader({ title: AppStrings.get('settings_reader_group_display') })
      NextNGroupedListSection() {
        NextNListRow({
          title: AppStrings.get('settings_reader_background'),
          trailingText: this.readerBackgroundModeLabel(),
          trailingDropdown: true,
          dropdownMenuEnabled: true,
          dropdownMenuBuilder: () => {
            this.ReaderBackgroundModeMenu()
          },
          accessibilityLabel: AppStrings.format('settings_reader_background_a11y', [
            this.readerBackgroundModeLabel(),
          ]),
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_image_scaling_quality'),
          subtitle: AppStrings.get('settings_reader_image_scaling_quality_hint'),
          subtitleMaxLines: 3,
          trailingText: this.readerImageScalingQualityLabel(),
          trailingDropdown: true,
          dropdownMenuEnabled: true,
          dropdownMenuBuilder: () => {
            this.ReaderImageScalingQualityMenu()
          },
          accessibilityLabel: AppStrings.format('settings_reader_image_scaling_quality_a11y', [
            this.readerImageScalingQualityLabel(),
          ]),
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_show_page_number'),
          hasSwitch: true,
          checked: this.readerPresentation.showPageNumber,
          showChevron: false,
          accessibilityLabel: AppStrings.format('settings_reader_show_page_number_a11y', [
            this.toggleStateLabel(this.readerPresentation.showPageNumber),
          ]),
          onAction: (): void => {
            this.saveReaderShowPageNumber(!this.readerPresentation.showPageNumber)
          },
          onSwitchChange: (value: boolean): void => {
            this.saveReaderShowPageNumber(value)
          },
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_fullscreen'),
          hasSwitch: true,
          checked: this.readerPresentation.fullscreen,
          showChevron: false,
          accessibilityLabel: AppStrings.format('settings_reader_fullscreen_a11y', [
            this.toggleStateLabel(this.readerPresentation.fullscreen),
          ]),
          onAction: (): void => {
            this.saveReaderFullscreen(!this.readerPresentation.fullscreen)
          },
          onSwitchChange: (value: boolean): void => {
            this.saveReaderFullscreen(value)
          },
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_keep_screen_on'),
          hasSwitch: true,
          checked: this.readerPresentation.keepScreenOn,
          showChevron: false,
          accessibilityLabel: AppStrings.format('settings_reader_keep_screen_on_a11y', [
            this.toggleStateLabel(this.readerPresentation.keepScreenOn),
          ]),
          onAction: (): void => {
            this.saveReaderKeepScreenOn(!this.readerPresentation.keepScreenOn)
          },
          onSwitchChange: (value: boolean): void => {
            this.saveReaderKeepScreenOn(value)
          },
        })
      }
    }
  }

  @Builder
  private ReaderEnhancementGroup() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      NextNSectionHeader({ title: AppStrings.get('settings_reader_group_image_enhancement') })
      NextNGroupedListSection() {
        NextNListRow({
          title: AppStrings.get('settings_reader_enhancement'),
          hasSwitch: true,
          checked: this.readerPresentation.superResolutionEnabled,
          showChevron: false,
          isEnabled: this.selectedReaderEnhancementModelInstalled(),
          accessibilityLabel: AppStrings.format('settings_reader_enhancement_a11y', [
            this.toggleStateLabel(this.readerPresentation.superResolutionEnabled),
          ]),
          onAction: (): void => {
            this.saveReaderEnhancementEnabled(!this.readerPresentation.superResolutionEnabled)
          },
          onSwitchChange: (value: boolean): void => {
            this.saveReaderEnhancementEnabled(value)
          },
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_enhancement_model_selection'),
          trailingText: this.readerEnhancementModelLabel(),
          trailingDropdown: true,
          dropdownMenuEnabled: true,
          dropdownMenuBuilder: () => {
            this.ReaderEnhancementModelMenu()
          },
          isEnabled: this.readerEnhancementInstalledModels.length > 0,
          accessibilityLabel: AppStrings.format('settings_reader_enhancement_model_selection_a11y', [
            this.readerEnhancementModelLabel(),
          ]),
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_enhancement_models'),
          trailingText: this.readerEnhancementInstalledModels.length > 0
            ? AppStrings.get('settings_reader_enhancement_model_ready')
            : AppStrings.get('settings_reader_enhancement_model_download'),
          accessibilityLabel: AppStrings.get('settings_reader_enhancement_models_a11y'),
          onAction: (): void => {
            this.openReaderEnhancementModels()
          },
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_enhancement_max_height'),
          subtitle: AppStrings.get('settings_reader_enhancement_max_height_hint'),
          subtitleMaxLines: 3,
          trailingText: this.readerEnhancementMaxHeightLabel(),
          trailingDropdown: true,
          dropdownMenuEnabled: true,
          dropdownMenuBuilder: () => {
            this.ReaderEnhancementMaxHeightMenu()
          },
          isEnabled: this.readerPresentation.superResolutionEnabled &&
            this.selectedReaderEnhancementModelInstalled(),
          accessibilityLabel: AppStrings.format('settings_reader_enhancement_max_height_a11y', [
            this.readerEnhancementMaxHeightLabel(),
          ]),
        })
      }
    }
  }

  @Builder
  private ReaderControlsGroup() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      NextNSectionHeader({ title: AppStrings.get('settings_reader_group_controls') })
      NextNGroupedListSection() {
        NextNListRow({
          title: AppStrings.get('settings_reader_auto_advance_interval'),
          trailingText: this.readerAutoPageLabel(),
          trailingDropdown: true,
          dropdownMenuEnabled: true,
          dropdownMenuBuilder: () => {
            this.ReaderAutoPageMenu()
          },
          accessibilityLabel: AppStrings.format('settings_reader_auto_advance_interval_a11y', [
            this.readerAutoPageLabel(),
          ]),
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_volume_keys_turn_pages'),
          subtitle: AppStrings.get('settings_reader_volume_keys_turn_pages_hint'),
          subtitleMaxLines: 3,
          hasSwitch: true,
          checked: this.readerPresentation.volumeKeyTurn,
          showChevron: false,
          accessibilityLabel: AppStrings.format('settings_reader_volume_keys_turn_pages_a11y', [
            this.toggleStateLabel(this.readerPresentation.volumeKeyTurn),
          ]),
          onAction: (): void => {
            this.saveReaderVolumeKeyTurn(!this.readerPresentation.volumeKeyTurn)
          },
          onSwitchChange: (value: boolean): void => {
            this.saveReaderVolumeKeyTurn(value)
          },
        })
      }
    }
  }

  @Builder
  private ReaderLoadingGroup() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      NextNSectionHeader({ title: AppStrings.get('settings_reader_group_loading') })
      NextNGroupedListSection() {
        NextNListRow({
          title: AppStrings.get('settings_reader_preload_pages'),
          trailingText: this.readerPreloadLabel(),
          trailingDropdown: true,
          dropdownMenuEnabled: true,
          dropdownMenuBuilder: () => {
            this.ReaderPreloadMenu()
          },
          accessibilityLabel: AppStrings.format('settings_reader_preload_pages_a11y', [this.readerPreloadLabel()]),
        })
      }
    }
  }

  /** Shared content for the routed Settings surface and the Reader-owned sheet. */
  @Builder
  private ReaderPresentationListItems() {
    ListItem() {
      this.ReaderLayoutGroup()
    }
    ListItem() {
      this.ReaderTapZonesGroup()
    }
    ListItem() {
      this.ReaderDisplayGroup()
    }
    ListItem() {
      this.ReaderEnhancementGroup()
    }
    ListItem() {
      this.ReaderControlsGroup()
    }
    ListItem() {
      this.ReaderLoadingGroup()
    }
    if (this.readerModeError.length > 0) {
      ListItem() {
        this.GroupNote(this.readerModeError)
      }
    }
  }

  /**
   * Match NextE's Reader sheet grammar: a modal HDS title owns close while
   * the familiar Reader settings rows remain the single semantic surface.
   */
  @Builder
  private ReaderPresentationSheet() {
    NextNModalScaffold({
      title: AppStrings.get('settings_reader'),
      scroller: this.scroller,
      onClose: (): void => {
        if (this.onClose) {
          this.onClose()
        }
      },
    }) {
      this.ReaderPresentationListItems()
    }
  }

  @Builder
  private ReaderEnhancementModelsSheet() {
    ReaderSuperResolutionModelsPage({
      modal: true,
      modalCloseIcon: $r('sys.media.ohos_ic_compnent_titlebar_back'),
      modalCloseIconStyle: IconStyleMode.NORMAL,
      onClose: (): void => {
        this.loadReaderPresentation()
        this.getUIContext().animateTo({
          duration: ThemeTokens.ANIM_DURATION,
          curve: Curve.EaseOut,
        }, (): void => {
          this.readerEnhancementModelsShown = false
        })
      },
      onModelsChanged: (): void => {
        this.loadReaderPresentation()
      },
    })
  }

  @Builder
  private ReaderSheetPanel() {
    Stack() {
      Column() {
        this.ReaderPresentationSheet()
      }
      .width('100%')
      .height('100%')
      .translate({
        x: this.readerEnhancementModelsShown ? -this.readerSheetPanelWidth : 0,
      })

      Column() {
        this.ReaderEnhancementModelsSheet()
      }
      .width('100%')
      .height('100%')
      .opacity(this.readerSheetPanelWidth > 0 ? 1 : 0)
      .translate({
        x: this.readerEnhancementModelsShown ? 0 : this.readerSheetPanelWidth,
      })
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .onAreaChange((_oldArea: Area, area: Area): void => {
      this.readerSheetPanelWidth = area.width as number
    })
  }

  @Builder
  private ReaderEnhancementModelMenu() {
    Menu() {
      ForEach(
        this.readerEnhancementInstalledModels,
        (model: NhReaderSuperResolutionModel) => {
          MenuItem({
            content: this.readerEnhancementModelTitle(model),
            symbolEndIcon: this.readerPresentation.superResolutionModel === model
              ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
              : undefined,
          }).onClick((): void => {
            this.setReaderEnhancementModel(model).catch((): void => {})
          })
        },
        (model: NhReaderSuperResolutionModel): string => model,
      )
    }
  }

  @Builder
  private ReaderEnhancementMaxHeightMenu() {
    Menu() {
      ForEach(
        READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT_CHOICES,
        (height: number) => {
          MenuItem({
            content: `${height}px`,
            symbolEndIcon: this.readerPresentation.superResolutionMaxHeight === height
              ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
              : undefined,
          }).onClick((): void => {
            this.setReaderEnhancementMaxHeight(height).catch((): void => {})
          })
        },
        (height: number): string => `${height}`,
      )
    }
  }

  @Builder
  private ThemeMenu() {
    Menu() {
      MenuItem({
        content: AppStrings.get('appearance_follow_system'),
        symbolEndIcon: this.themeDisplay.mode === ThemeSettings.MODE_SYSTEM
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setTheme(ThemeSettings.MODE_SYSTEM)
      })
      MenuItem({
        content: AppStrings.get('theme_light'),
        symbolEndIcon: this.themeDisplay.mode === ThemeSettings.MODE_LIGHT
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setTheme(ThemeSettings.MODE_LIGHT)
      })
      MenuItem({
        content: AppStrings.get('theme_dark'),
        symbolEndIcon: this.themeDisplay.mode === ThemeSettings.MODE_DARK
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setTheme(ThemeSettings.MODE_DARK)
      })
    }
  }

  @Builder
  private ThemeColorMenu() {
    Menu() {
      ForEach(
        ThemeColorSettings.options(),
        (option: ThemeColorOption): void => {
          MenuItem({
            content: AppStrings.get(option.labelKey),
            symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.paintpalette_fill'))
              .fontSize(ThemeTokens.FONT_SIZE_BODY)
              .fontColor([option.color]),
            symbolEndIcon: this.themeColor.color === option.value
              ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
              : undefined,
          }).onClick((): void => {
            this.setThemeColor(option.value)
          })
        },
        (option: ThemeColorOption): string => option.value,
      )
      MenuItem({
        content: AppStrings.get('theme_color_custom'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.paintpalette_fill'))
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontColor([
            ThemeColorSettings.isCustom(this.themeColor.color)
              ? ThemeColorSettings.currentColor()
              : ThemeTokens.TEXT_TERTIARY,
          ]),
        symbolEndIcon: ThemeColorSettings.isCustom(this.themeColor.color)
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.openThemeColorPicker()
      })
    }
  }

  @Builder
  private ThemeColorPickerSheet() {
    NextNModalScaffold({
      title: AppStrings.get('theme_color_custom'),
      showConfirmAction: true,
      confirmText: AppStrings.get('common_ok'),
      onClose: (): void => {
        this.closeThemeColorPicker()
      },
      onConfirm: (): void => {
        this.confirmThemeColorPicker()
      },
    }) {
      ListItem() {
        AppColorPicker({
          title: AppStrings.get('settings_theme_color'),
          color: this.draftCustomThemeColor,
          colorChange: (value: string): void => {
            this.draftCustomThemeColor = value
            ThemeColorSettings.apply(value)
          },
        })
        .width('100%')
      }
    }
  }

  @Builder
  private ThemeColorSuffix() {
    Row({ space: ThemeTokens.SPACE_XS }) {
      Stack()
        .width(ThemeTokens.SPACE_LG)
        .height(ThemeTokens.SPACE_LG)
        .borderRadius(ThemeTokens.SPACE_LG / 2)
        .backgroundColor(ThemeColorSettings.colorValue(this.themeColor.color))
      Text(this.themeColorLabel())
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      SymbolGlyph($r('sys.symbol.arrowtriangle_down_fill'))
        .fontSize(ThemeTokens.FONT_SIZE_TITLE)
        .fontColor([ThemeTokens.TEXT_TERTIARY])
        .padding({ left: ThemeTokens.SPACE_XS, right: ThemeTokens.SPACE_MD })
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ImmersiveMaterialMenu() {
    Menu() {
      ForEach(
        ImmersiveMaterialSettings.options(),
        (option: ImmersiveMaterialOption): void => {
          MenuItem({
            content: option.label,
            symbolEndIcon: this.immersiveMaterial.level === option.value
              ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
              : undefined,
          }).onClick((): void => {
            this.setImmersiveMaterial(option.value)
          })
        },
        (option: ImmersiveMaterialOption): string => option.value,
      )
    }
  }

  @Builder
  private LanguageMenu() {
    Menu() {
      MenuItem({
        content: AppStrings.get('appearance_follow_system'),
        symbolEndIcon: this.language.mode === LanguageSettings.MODE_SYSTEM
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setLanguage(LanguageSettings.MODE_SYSTEM)
      })
      MenuItem({
        content: AppStrings.get('language_zh'),
        symbolEndIcon: this.language.mode === LanguageSettings.MODE_ZH_CN
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setLanguage(LanguageSettings.MODE_ZH_CN)
      })
      MenuItem({
        content: AppStrings.get('language_en'),
        symbolEndIcon: this.language.mode === LanguageSettings.MODE_EN
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setLanguage(LanguageSettings.MODE_EN)
      })
      MenuItem({
        content: AppStrings.get('language_ja'),
        symbolEndIcon: this.language.mode === LanguageSettings.MODE_JA
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setLanguage(LanguageSettings.MODE_JA)
      })
    }
  }

  @Builder
  private AppearanceGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.moon'),
        title: AppStrings.get('settings_theme'),
        trailingText: this.themeModeLabel(),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.ThemeMenu()
        },
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_theme'),
          this.themeModeLabel(),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.paintbrush'),
        title: AppStrings.get('settings_theme_color'),
        useCustomTrailing: true,
        customTrailing: (): void => {
          this.ThemeColorSuffix()
        },
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.ThemeColorMenu()
        },
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_theme_color'),
          this.themeColorLabel(),
        ]),
      })
      .bindSheet($$this.themeColorPickerShown, this.ThemeColorPickerSheet(), appSheetOptions({
        detents: [SheetSize.LARGE],
        showClose: false,
        onDisappear: (): void => {
          this.closeThemeColorPicker()
        },
      }))
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.picture'),
        title: AppStrings.get('immersive_material'),
        trailingText: this.immersiveMaterialLabel(),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.ImmersiveMaterialMenu()
        },
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('immersive_material'),
          this.immersiveMaterialLabel(),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.translate'),
        title: AppStrings.get('settings_language'),
        trailingText: this.languageModeLabel(),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.LanguageMenu()
        },
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_language'),
          this.languageModeLabel(),
        ]),
      })
    }
  }

  @Builder
  private BrowsePresentationMenu() {
    Menu() {
      MenuItem({
        content: AppStrings.get('browse_list'),
        symbolEndIcon: this.browsePresentation.mode === NhBrowsePresentation.LIST
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveBrowsePresentation(NhBrowsePresentation.LIST)
      })
      MenuItem({
        content: AppStrings.get('browse_simple_list'),
        symbolEndIcon: this.browsePresentation.mode === NhBrowsePresentation.SIMPLE_LIST
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveBrowsePresentation(NhBrowsePresentation.SIMPLE_LIST)
      })
      MenuItem({
        content: AppStrings.get('browse_cover_grid'),
        symbolEndIcon: this.browsePresentation.mode === NhBrowsePresentation.COVER_GRID
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveBrowsePresentation(NhBrowsePresentation.COVER_GRID)
      })
      MenuItem({
        content: AppStrings.get('browse_waterfall'),
        symbolEndIcon: this.browsePresentation.mode === NhBrowsePresentation.WATERFALL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveBrowsePresentation(NhBrowsePresentation.WATERFALL)
      })
      MenuItem({
        content: AppStrings.get('browse_waterfall_compact'),
        symbolEndIcon: this.browsePresentation.mode === NhBrowsePresentation.WATERFALL_COMPACT
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveBrowsePresentation(NhBrowsePresentation.WATERFALL_COMPACT)
      })
      MenuItem({
        content: AppStrings.get('browse_cover_wall'),
        symbolEndIcon: this.browsePresentation.mode === NhBrowsePresentation.COVER_WALL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveBrowsePresentation(NhBrowsePresentation.COVER_WALL)
      })
    }
  }

  @Builder
  private BrowsePresentationGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.square_grid_2x2'),
        title: AppStrings.get('browse_presentation'),
        trailingText: this.browsePresentationLabel(),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.BrowsePresentationMenu()
        },
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('browse_presentation'),
          this.browsePresentationLabel(),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.doc_plaintext'),
        title: AppStrings.get('settings_gallery_card_tags'),
        subtitle: AppStrings.get('settings_gallery_card_tags_hint'),
        hasSwitch: true,
        checked: this.browsePresentation.showGalleryTags,
        showChevron: false,
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_gallery_card_tags'),
          this.toggleStateLabel(this.browsePresentation.showGalleryTags),
        ]),
        onAction: (): void => {
          this.setShowGalleryTags(!this.browsePresentation.showGalleryTags)
        },
        onSwitchChange: (value: boolean): void => {
          this.setShowGalleryTags(value)
        },
      })
      if (supportsGalleryColumnDensity(this.browsePresentation.mode)) {
        this.RowDivider()
        NextNListRow({
          leadingIcon: $r('sys.symbol.arrowtriangle_2_inward_square'),
          title: AppStrings.get('settings_browse_column_width'),
          subtitle: AppStrings.get('settings_browse_column_width_hint'),
          accessibilityLabel: AppStrings.format('settings_browse_column_width_a11y', [
            this.browsePresentationLabel(),
            this.browseColumnWidth().toString(),
          ]),
          onAction: (): void => {
            if (this.onOpenBrowseDensity) {
              this.onOpenBrowseDensity(this.browsePresentation.mode)
            }
          },
        })
      }
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.rectangle_grid_1x2'),
        title: AppStrings.get('settings_browse_list_fixed_height'),
        hasSwitch: true,
        checked: this.browsePresentation.listCardFixedHeight,
        showChevron: false,
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_browse_list_fixed_height'),
          this.toggleStateLabel(this.browsePresentation.listCardFixedHeight),
        ]),
        onAction: (): void => {
          this.setListCardFixedHeight(!this.browsePresentation.listCardFixedHeight)
        },
        onSwitchChange: (value: boolean): void => {
          this.setListCardFixedHeight(value)
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.picture'),
        title: AppStrings.get('settings_cover_background_blur'),
        subtitle: AppStrings.get('settings_cover_background_blur_hint'),
        hasSwitch: true,
        checked: this.coverBackground.blurLetterboxBackground,
        showChevron: false,
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_cover_background_blur'),
          this.toggleStateLabel(this.coverBackground.blurLetterboxBackground),
        ]),
        onAction: (): void => {
          this.setBlurLetterboxBackground(!this.coverBackground.blurLetterboxBackground)
        },
        onSwitchChange: (value: boolean): void => {
          this.setBlurLetterboxBackground(value)
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.textformat'),
        title: AppStrings.get('settings_gallery_japanese_title_primary'),
        subtitle: AppStrings.get('settings_gallery_japanese_title_primary_hint'),
        hasSwitch: true,
        checked: this.galleryTitle.japaneseTitlePrimary,
        showChevron: false,
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_gallery_japanese_title_primary'),
          this.toggleStateLabel(this.galleryTitle.japaneseTitlePrimary),
        ]),
        onAction: (): void => {
          this.setJapaneseTitlePrimary(!this.galleryTitle.japaneseTitlePrimary)
        },
        onSwitchChange: (value: boolean): void => {
          this.setJapaneseTitlePrimary(value)
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.rectangle_grid_1x2'),
        title: AppStrings.get('settings_home_tab_auto_hide'),
        subtitle: AppStrings.get('settings_home_tab_auto_hide_hint'),
        hasSwitch: true,
        checked: this.homeTab.autoHide,
        showChevron: false,
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_home_tab_auto_hide'),
          this.toggleStateLabel(this.homeTab.autoHide),
        ]),
        onAction: (): void => {
          this.setHomeTabAutoHide(!this.homeTab.autoHide)
        },
        onSwitchChange: (value: boolean): void => {
          this.setHomeTabAutoHide(value)
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.doc_plaintext'),
        title: AppStrings.get('settings_action_alignment'),
        trailingText: this.actionAlignmentLabel(),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.ActionAlignmentMenu()
        },
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_action_alignment'),
          this.actionAlignmentLabel(),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.paintbrush'),
        title: AppStrings.get('settings_read_button_style'),
        subtitle: AppStrings.get('settings_read_button_style_hint'),
        trailingText: this.readButtonStyleLabel(),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.ReadButtonStyleMenu()
        },
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_read_button_style'),
          this.readButtonStyleLabel(),
        ]),
      })
    }
  }

  @Builder
  private TabletLayoutGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.rectangle_split_2x1'),
        title: AppStrings.get('settings_tablet_layout'),
        trailingText: this.tabletLayoutLabel(),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.TabletLayoutMenu()
        },
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_tablet_layout'),
          this.tabletLayoutLabel(),
        ]),
      })
    }
  }

  @Builder
  private ScreenOrientationGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.rectangle_portrait_rotate'),
        title: AppStrings.get('settings_screen_orientation'),
        trailingText: this.screenOrientationLabel(),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.ScreenOrientationMenu()
        },
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_screen_orientation'),
          this.screenOrientationLabel(),
        ]),
      })
    }
  }

  @Builder
  private CatalogBrowseLanguageMenu() {
    Menu() {
      ForEach(CATALOG_LANGUAGES, (language: NhSearchLanguage): void => {
        MenuItem({
          content: this.catalogLanguageLabel(language),
          symbolEndIcon: this.catalogPreferences.browseLanguage === language
            ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
            : undefined,
        }).onClick((): void => {
          this.setCatalogBrowseLanguage(language)
        })
      }, (language: NhSearchLanguage): string => language)
    }
  }

  @Builder
  private CatalogBrowseSortMenu() {
    Menu() {
      ForEach(CATALOG_SORTS, (sort: NhSearchSort): void => {
        MenuItem({
          content: this.catalogSortLabel(sort),
          symbolEndIcon: this.catalogPreferences.browseSort === sort
            ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
            : undefined,
        }).onClick((): void => {
          this.setCatalogBrowseSort(sort)
        })
      }, (sort: NhSearchSort): string => sort)
    }
  }

  @Builder
  private CatalogSearchLanguageMenu() {
    Menu() {
      ForEach(CATALOG_LANGUAGES, (language: NhSearchLanguage): void => {
        MenuItem({
          content: this.catalogLanguageLabel(language),
          symbolEndIcon: this.catalogPreferences.searchLanguage === language
            ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
            : undefined,
        }).onClick((): void => {
          this.setCatalogSearchLanguage(language)
        })
      }, (language: NhSearchLanguage): string => language)
    }
  }

  @Builder
  private CatalogSearchSortMenu() {
    Menu() {
      ForEach(CATALOG_SORTS, (sort: NhSearchSort): void => {
        MenuItem({
          content: this.catalogSortLabel(sort),
          symbolEndIcon: this.catalogPreferences.searchSort === sort
            ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
            : undefined,
        }).onClick((): void => {
          this.setCatalogSearchSort(sort)
        })
      }, (sort: NhSearchSort): string => sort)
    }
  }

  /** Browse defaults mirror their independent public request context. */
  @Builder
  private BrowsePreferencesGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.translate'),
        title: AppStrings.get('settings_catalog_browse_language'),
        trailingText: this.catalogLanguageLabel(this.catalogPreferences.browseLanguage),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.CatalogBrowseLanguageMenu()
        },
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_catalog_browse_language'),
          this.catalogLanguageLabel(this.catalogPreferences.browseLanguage),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.arrow_clockwise'),
        title: AppStrings.get('settings_catalog_browse_sort'),
        trailingText: this.catalogSortLabel(this.catalogPreferences.browseSort),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.CatalogBrowseSortMenu()
        },
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_catalog_browse_sort'),
          this.catalogSortLabel(this.catalogPreferences.browseSort),
        ]),
      })
    }
  }

  /** Search defaults mirror their independent public request context. */
  @Builder
  private SearchPreferencesGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.magnifyingglass'),
        title: AppStrings.get('settings_catalog_search_language'),
        trailingText: this.catalogLanguageLabel(this.catalogPreferences.searchLanguage),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.CatalogSearchLanguageMenu()
        },
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_catalog_search_language'),
          this.catalogLanguageLabel(this.catalogPreferences.searchLanguage),
        ]),
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.rectangle_stack'),
        title: AppStrings.get('settings_catalog_search_sort'),
        trailingText: this.catalogSortLabel(this.catalogPreferences.searchSort),
        trailingDropdown: true,
        dropdownMenuEnabled: true,
        dropdownMenuBuilder: () => {
          this.CatalogSearchSortMenu()
        },
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_catalog_search_sort'),
          this.catalogSortLabel(this.catalogPreferences.searchSort),
        ]),
      })
    }
  }

  @Builder
  private BrowserSessionGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.security_shield'),
        title: AppStrings.get('account_title'),
        subtitle: AppStrings.get('account_subtitle_sign_in'),
        accessibilityLabel: AppStrings.get('account_open_page_a11y'),
        onAction: () => {
          if (this.onOpenBrowserSession) {
            this.onOpenBrowserSession()
          }
        },
      })
    }
  }

  @Builder
  private ContentFiltersGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.eye_slash'),
        title: AppStrings.get('settings_content_filters'),
        subtitle: AppStrings.get('settings_content_filters_subtitle'),
        accessibilityLabel: AppStrings.get('settings_content_filters_a11y'),
        onAction: (): void => {
          if (this.onOpenContentFilters) {
            this.onOpenContentFilters()
          }
        },
      })
    }
  }

  /** NextE keeps four sibling translation entries with their own destinations. */
  @Builder
  private TranslationCapabilitiesGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.translate'),
        title: AppStrings.get('settings_comment_translation'),
        subtitle: AppStrings.get('settings_comment_translation_hint'),
        trailingText: this.toggleStateLabel(this.commentTranslationSettings.enabled),
        accessibilityLabel: AppStrings.get('settings_comment_translation_a11y'),
        onAction: (): void => {
          if (this.onOpenCommentTranslation) {
            this.onOpenCommentTranslation()
          }
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.picture'),
        title: AppStrings.get('settings_reader_comic_translation'),
        subtitle: AppStrings.get('settings_reader_comic_translation_hint'),
        accessibilityLabel: AppStrings.get('settings_reader_comic_translation_a11y'),
        onAction: (): void => {
          if (this.onOpenComicTranslation) {
            this.onOpenComicTranslation()
          }
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.textformat'),
        title: AppStrings.get('settings_tag_translation_title'),
        subtitle: this.tagTranslationVersionText(),
        trailingText: this.toggleStateLabel(this.tagTranslationSettings.enabled),
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_tag_translation_title'),
          this.toggleStateLabel(this.tagTranslationSettings.enabled),
        ]),
        onAction: (): void => {
          if (this.onOpenTagTranslation) {
            this.onOpenTagTranslation()
          }
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.cloud'),
        title: AppStrings.get('llm_sources_title'),
        subtitle: AppStrings.get('llm_sources_hint'),
        accessibilityLabel: AppStrings.get('settings_translation_source_a11y'),
        onAction: (): void => {
          if (this.onOpenTranslationSource) {
            this.onOpenTranslationSource()
          }
        },
      })
    }
  }

  build() {
    if (this.surface === SettingsSurface.READER && this.sheetPresentation) {
      this.ReaderSheetPanel()
    } else {
      Column() {
        SecondaryListScaffold({
        scroller: this.scroller,
        bottomPadding: this.surface === SettingsSurface.ROOT
          ? ThemeTokens.ROOT_FLOATING_TAB_RESERVE
          : ThemeTokens.LIST_BOTTOM_PADDING,
        alwaysEnableEdgeSpring: true,
        onDidScroll: (offset: number, state: ScrollState): void => {
          if (this.onDidScroll) {
            this.onDidScroll(offset, state)
          }
        },
      }) {
        if (this.surface === SettingsSurface.ROOT) {
          if (!this.safeMode.restricted()) {
            ListItem() {
              this.RootAccountSection()
            }
            ListItem() {
              this.RootHistorySection()
            }
          }
          ListItem() {
            this.RootMainSection()
          }
        } else if (this.surface === SettingsSurface.LAYOUT) {
          ListItem() {
            this.AppearanceGroup()
          }
          ListItem() {
            this.ScreenOrientationGroup()
          }
          ListItem() {
            this.TabletLayoutGroup()
          }
          ListItem() {
            this.BrowsePresentationGroup()
          }
          if (this.browsePresentationError.length > 0) {
            ListItem() {
              this.GroupNote(this.browsePresentationError)
            }
          }
        } else if (this.surface === SettingsSurface.BROWSE) {
          ListItem() {
            this.BrowsePreferencesGroup()
          }
          if (this.browsePreferencesError.length > 0) {
            ListItem() {
              this.GroupNote(this.browsePreferencesError)
            }
          }
        } else if (this.surface === SettingsSurface.SEARCH) {
          ListItem() {
            this.SearchPreferencesGroup()
          }
          if (this.searchPreferencesError.length > 0) {
            ListItem() {
              this.GroupNote(this.searchPreferencesError)
            }
          }
        } else if (this.surface === SettingsSurface.READER) {
          this.ReaderPresentationListItems()
        } else if (this.surface === SettingsSurface.DOWNLOAD) {
          ListItem() {
            this.DownloadPolicyGroup()
          }
          ListItem() {
            this.DownloadRestoreGroup()
          }
          if (this.downloadSettingsError.length > 0) {
            ListItem() {
              this.GroupNote(this.downloadSettingsError)
            }
          }
        } else if (this.surface === SettingsSurface.CACHE) {
          ListItem() {
            Column({ space: ThemeTokens.SPACE_MD }) {
              if (!this.safeMode.restricted()) {
                this.SyncGroup()
              }
              this.BackupGroup()
              this.ReaderCacheLimitGroup()
              this.PrivateCacheTotalSummary()
              this.PrivateCacheGroup()
            }
            .width('100%')
          }
          if (this.privateCacheError.length > 0) {
            ListItem() {
              this.GroupNote(this.privateCacheError)
            }
          }
        } else if (this.surface === SettingsSurface.ADVANCED) {
          ListItem() {
            this.ClipboardLinkGroup()
          }
          ListItem() {
            this.TranslationCapabilitiesGroup()
          }
          ListItem() {
            this.ContentFiltersGroup()
          }
          ListItem() {
            this.DiagnosticsSettingsGroup()
          }
          ListItem() {
            this.DiagnosticsActionsGroup()
          }
          ListItem() {
            this.DiagnosticsFilesGroup()
          }
        }
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeTokens.SURFACE_SUB)
    }
  }
}
