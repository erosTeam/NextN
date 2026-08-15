import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { ReaderSuperResolutionModelsPage } from './ReaderSuperResolutionModelsPage'
import {
  AppStrings,
  AppColorPicker,
  CatalogPreferencesService,
  CatalogPreferencesState,
  CacheStat,
  CommentTranslationService,
  ComicTranslationRuntimeService,
  LanguageSettings,
  LanguageState,
  LayoutSafeAreaState,
  LLM_CONSUMER_COMMENT_TRANSLATION,
  LLM_CONSUMER_MANGA_TRANSLATION,
  NhTagTranslationStatus,
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
  ReaderImageCacheService,
  ReaderImageCacheStatus,
  ReaderSuperResolutionModelService,
  ReaderEnhancementModelsState,
  ReaderPresentationService,
  ReaderPresentationState,
  DownloadQueueService,
  DownloadNotificationService,
  DownloadSettingsService,
  DownloadSettingsState,
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
  TagTranslationRepository,
  TagDictionaryUpdateAttempt,
  TagDictionaryUpdateFailure,
  TagTranslationUpdateService,
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
  SETTINGS_ROOT_BROWSER_SESSION,
  SETTINGS_ROOT_LAYOUT,
  SETTINGS_ROOT_BROWSE,
  SETTINGS_ROOT_SEARCH,
  SETTINGS_ROOT_READER,
  SETTINGS_ROOT_DOWNLOAD,
  SETTINGS_ROOT_CACHE,
  SETTINGS_ROOT_ADVANCED,
  SETTINGS_ROOT_ABOUT,
  galleryBaseMinColumnWidth,
  supportsGalleryColumnDensity,
  connectAccountSession,
  connectAccountProfile,
  connectBrowsePresentation,
  connectCatalogPreferences,
  connectCoverBackground,
  connectActionAlignment,
  connectGalleryTitle,
  connectNhClipboardLink,
  connectReadButtonStyle,
  connectReaderEnhancementModels,
  connectReaderPresentation,
  connectScreenOrientation,
  connectDownloadSettings,
  connectHomeTabAutoHide,
  connectImmersiveMaterialSettings,
  connectLanguageState,
  connectLayoutSafeArea,
  connectSettingsNavigation,
  connectTabletLayout,
  connectThemeColor,
  connectThemeDisplay,
} from 'shared'

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
 * Presentation-only failure codes. TagTranslationUpdateService deliberately
 * keeps its transport and parsing failures raw for diagnostics; Settings
 * maps the user-visible result at this boundary instead of treating protocol
 * text as localized copy.
 */
class TagDictionaryUiErrorCode {
  static readonly DICTIONARY_ASSET: string = 'dictionary_asset'
  static readonly CONTENT_VALIDATION: string = 'content_validation'
  static readonly LOCAL_STORAGE: string = 'local_storage'
}

/**
 * Settings keeps NextE's grouped native-list grammar: HDS rows carry the
 * hierarchy and actions, while the surrounding sections only explain the
 * capability boundary. No setting here implies an unavailable remote action.
 */
@ComponentV2
export struct SettingsPage {
  @Local tagDictionaryStatus: NhTagTranslationStatus = new NhTagTranslationStatus()
  @Local tagDictionaryRowCount: number = 0
  @Local tagDictionaryStatusKnown: boolean = false
  @Local isUpdatingTagDictionary: boolean = false
  @Local tagDictionaryError: string = ''
  @Local readerCacheStatus: ReaderImageCacheStatus = new ReaderImageCacheStatus()
  @Local isLoadingPrivateCache: boolean = false
  @Local isClearingPrivateCache: boolean = false
  @Local privateCacheError: string = ''
  @Local commentTranslationCacheStatus: CacheStat = new CacheStat()
  @Local comicTranslationCacheStatus: CacheStat = new CacheStat()
  @Local tagDictionaryCacheStatus: CacheStat = new CacheStat()
  @Local readerPresentation: ReaderPresentationState = connectReaderPresentation()
  @Local readerEnhancementModels: ReaderEnhancementModelsState = connectReaderEnhancementModels()
  @Local readerModeError: string = ''
  @Local readerEnhancementInstalledModels: NhReaderSuperResolutionModel[] = []
  @Local readerEnhancementModelsShown: boolean = false
  @Local browsePresentationError: string = ''
  @Local browsePreferencesError: string = ''
  @Local searchPreferencesError: string = ''
  @Local readerModeMenuShown: boolean = false
  @Local readerSpreadLayoutMenuShown: boolean = false
  @Local readerBackgroundMenuShown: boolean = false
  @Local readerImageScalingQualityMenuShown: boolean = false
  @Local readerPreloadMenuShown: boolean = false
  @Local readerAutoPageMenuShown: boolean = false
  @Local readerTapZoneMenuShown: boolean = false
  @Local readerTapZoneInvertMenuShown: boolean = false
  @Local readerEnhancementModelMenuShown: boolean = false
  @Local readerEnhancementMaxHeightMenuShown: boolean = false
  @Local downloadSettings: DownloadSettingsState = connectDownloadSettings()
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
  @Local galleryConcurrencyMenuShown: boolean = false
  @Local pageConcurrencyMenuShown: boolean = false
  @Local retryCountMenuShown: boolean = false
  @Local themeMenuShown: boolean = false
  @Local themeColorMenuShown: boolean = false
  @Local themeColorPickerShown: boolean = false
  @Local draftCustomThemeColor: string = '#0958F7'
  private themeColorBeforePicker: string = ThemeColorSettings.COLOR_GALAXY_BLUE
  private themeColorPreviewActive: boolean = false
  @Local immersiveMaterialMenuShown: boolean = false
  @Local languageMenuShown: boolean = false
  @Local browsePresentationMenuShown: boolean = false
  @Local catalogBrowseLanguageMenuShown: boolean = false
  @Local catalogBrowseSortMenuShown: boolean = false
  @Local catalogSearchLanguageMenuShown: boolean = false
  @Local catalogSearchSortMenuShown: boolean = false
  @Local screenOrientationMenuShown: boolean = false
  @Local tabletLayoutMenuShown: boolean = false
  @Local clipboardLinkSaving: boolean = false
  @Local readButtonStyleMenuShown: boolean = false
  @Local actionAlignmentMenuShown: boolean = false
  @Param scroller: Scroller = new Scroller()
  @Param surface: SettingsSurface = SettingsSurface.ROOT
  /** Reader mounts this same semantic surface inside its private sheet. */
  @Param sheetPresentation: boolean = false
  @Event onClose?: () => void
  @Event onOpenBrowserSession?: () => void
  @Event onOpenLayoutSettings?: () => void
  @Event onOpenBrowseSettings?: () => void
  @Event onOpenSearchSettings?: () => void
  @Event onOpenBrowseDensity?: (mode: NhBrowsePresentation) => void
  @Event onOpenReaderSettings?: () => void
  @Event onOpenReaderEnhancementModels?: () => void
  @Event onOpenTranslationSource?: (consumerId: string) => void
  @Event onOpenDownloadSettings?: () => void
  @Event onOpenCacheSettings?: () => void
  @Event onOpenAdvancedSettings?: () => void
  @Event onOpenAbout?: () => void
  @Event onOpenContentFilters?: () => void
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
    this.themeMenuShown = false
    ThemeSettings.setMode(this.context(), mode).catch((): void => {})
  }

  private themeColorLabel(): string {
    return AppStrings.get(ThemeColorSettings.labelKey(this.themeColor.color))
  }

  private setThemeColor(value: string): void {
    this.themeColorMenuShown = false
    ThemeColorSettings.setColor(this.context(), value).catch((): void => {})
  }

  /** Opens the custom picker without persisting or replacing the current accent. */
  private openThemeColorPicker(): void {
    this.themeColorMenuShown = false
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
    this.immersiveMaterialMenuShown = false
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
    this.languageMenuShown = false
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
    this.tabletLayoutMenuShown = false
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
    this.screenOrientationMenuShown = false
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

  private setShowTranslatedTagLabels(value: boolean): void {
    this.browsePresentationError = ''
    BrowsePresentationService.setShowTranslatedTagLabels(this.context(), value).catch((): void => {
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
    this.catalogBrowseLanguageMenuShown = false
    this.browsePreferencesError = ''
    CatalogPreferencesService.setBrowseLanguage(this.context(), language).catch((): void => {
      this.browsePreferencesError = AppStrings.get('settings_browse_preferences_save_failed')
    })
  }

  private setCatalogBrowseSort(sort: NhSearchSort): void {
    this.catalogBrowseSortMenuShown = false
    this.browsePreferencesError = ''
    CatalogPreferencesService.setBrowseSort(this.context(), sort).catch((): void => {
      this.browsePreferencesError = AppStrings.get('settings_browse_preferences_save_failed')
    })
  }

  private setCatalogSearchLanguage(language: NhSearchLanguage): void {
    this.catalogSearchLanguageMenuShown = false
    this.searchPreferencesError = ''
    CatalogPreferencesService.setSearchLanguage(this.context(), language).catch((): void => {
      this.searchPreferencesError = AppStrings.get('settings_search_preferences_save_failed')
    })
  }

  private setCatalogSearchSort(sort: NhSearchSort): void {
    this.catalogSearchSortMenuShown = false
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
      : AppStrings.get(definition.labelStringKey)
  }

  private readerEnhancementModelTitle(model: NhReaderSuperResolutionModel): string {
    const definition = ReaderSuperResolutionModelService.definition(model)
    return definition === null
      ? AppStrings.get('settings_reader_enhancement_model_none')
      : AppStrings.get(definition.labelStringKey)
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
      this.readerEnhancementModelsShown = true
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
    this.readerEnhancementModelMenuShown = false
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
    this.readerEnhancementMaxHeightMenuShown = false
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
    this.actionAlignmentMenuShown = false
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

  private async loadTagDictionaryStatus(): Promise<void> {
    this.tagDictionaryStatusKnown = false
    try {
      this.applyTagDictionaryStatus(await TagTranslationRepository.status(this.context()))
    } catch (_error) {
      this.tagDictionaryError = AppStrings.get('settings_tag_translation_status_unavailable')
    }
  }

  private async loadAdvancedSettings(): Promise<void> {
    await Promise.all([
      this.loadTagDictionaryStatus(),
      NhClipboardLinkSettings.restore(this.context()),
    ])
  }

  private async updateTagDictionary(): Promise<void> {
    if (this.isUpdatingTagDictionary) {
      return
    }
    this.isUpdatingTagDictionary = true
    this.tagDictionaryError = ''
    try {
      this.applyTagDictionaryStatus(await TagTranslationUpdateService.updateFromPublicRelease(this.context()))
    } catch (error) {
      this.tagDictionaryError = this.tagDictionaryErrorMessage(error as Error)
    } finally {
      this.isUpdatingTagDictionary = false
    }
  }

  private tagDictionaryErrorMessage(error: Error): string {
    if (!(error instanceof TagDictionaryUpdateFailure)) {
      return AppStrings.get('settings_tag_translation_error_update')
    }
    const failure: TagDictionaryUpdateFailure = error as TagDictionaryUpdateFailure
    const phase: string = this.tagDictionaryPhaseLabel(failure.phase)
    const attempts: string = this.tagDictionaryAttemptsLabel(failure.attempts)
    const retained: string = failure.dictionaryRetained
      ? AppStrings.get('settings_tag_translation_error_retained')
      : ''
    if (attempts.length === 0) {
      return AppStrings.format('settings_tag_translation_error_details_without_attempts', [phase, retained]).trim()
    }
    return AppStrings.format('settings_tag_translation_error_details', [phase, attempts, retained]).trim()
  }

  private tagDictionaryPhaseLabel(phase: string): string {
    switch (phase) {
      case TagDictionaryUiErrorCode.DICTIONARY_ASSET:
        return AppStrings.get('settings_tag_translation_error_phase_asset')
      case TagDictionaryUiErrorCode.CONTENT_VALIDATION:
        return AppStrings.get('settings_tag_translation_error_phase_content')
      case TagDictionaryUiErrorCode.LOCAL_STORAGE:
        return AppStrings.get('settings_tag_translation_error_phase_local')
      default:
        return AppStrings.get('settings_tag_translation_error_phase_update')
    }
  }

  private tagDictionaryAttemptsLabel(attempts: TagDictionaryUpdateAttempt[]): string {
    const labels: string[] = []
    for (let index: number = 0; index < attempts.length; index++) {
      const label: string = this.tagDictionaryAttemptLabel(attempts[index])
      if (label.length > 0 && labels.indexOf(label) < 0) {
        labels.push(label)
      }
    }
    return labels.join(AppStrings.get('settings_tag_translation_error_separator'))
  }

  private tagDictionaryAttemptLabel(attempt: TagDictionaryUpdateAttempt): string {
    const source: string = attempt.source === 'direct'
      ? AppStrings.get('settings_tag_translation_error_source_direct')
      : attempt.source === 'mirror'
        ? AppStrings.get('settings_tag_translation_error_source_mirror')
        : ''
    if (attempt.outcome === 'http' && attempt.httpStatus > 0) {
      return source.length > 0
        ? AppStrings.format('settings_tag_translation_error_http', [source, attempt.httpStatus.toString()])
        : AppStrings.format('settings_tag_translation_error_http_unknown', [attempt.httpStatus.toString()])
    }
    if (attempt.outcome === 'transport') {
      return source.length > 0
        ? AppStrings.format('settings_tag_translation_error_transport', [source])
        : AppStrings.get('settings_tag_translation_error_transport_unknown')
    }
    return source.length > 0
      ? AppStrings.format('settings_tag_translation_error_invalid', [source])
      : AppStrings.get('settings_tag_translation_error_invalid_unknown')
  }

  private applyTagDictionaryStatus(status: NhTagTranslationStatus): void {
    this.tagDictionaryStatus = status
    this.tagDictionaryRowCount = status.rowCount
    this.tagDictionaryStatusKnown = true
  }

  private tagDictionaryStatusText(): string {
    if (this.isUpdatingTagDictionary) {
      return AppStrings.get('settings_tag_translation_updating')
    }
    if (!this.tagDictionaryStatusKnown) {
      return ''
    }
    return this.tagDictionaryRowCount > 0
      ? this.tagDictionaryRowCount.toString()
      : AppStrings.get('settings_tag_translation_not_installed')
  }

  private readerPageCacheStat(): CacheStat {
    const result: CacheStat = new CacheStat()
    result.count = this.readerCacheStatus.fileCount
    result.bytes = this.readerCacheStatus.bytes
    return result
  }

  private privateCacheStat(key: string): CacheStat {
    if (key === 'reader') {
      return this.readerPageCacheStat()
    }
    if (key === 'comment') {
      return this.commentTranslationCacheStatus
    }
    if (key === 'comic') {
      return this.comicTranslationCacheStatus
    }
    return this.tagDictionaryCacheStatus
  }

  private privateCacheTotalBytes(): number {
    return this.readerPageCacheStat().bytes + this.commentTranslationCacheStatus.bytes +
      this.comicTranslationCacheStatus.bytes + this.tagDictionaryCacheStatus.bytes
  }

  private privateCacheTotalCount(): number {
    return this.readerPageCacheStat().count + this.commentTranslationCacheStatus.count +
      this.comicTranslationCacheStatus.count + this.tagDictionaryCacheStatus.count
  }

  private async loadPrivateCacheStatus(): Promise<void> {
    if (this.isClearingPrivateCache) {
      return
    }
    this.isLoadingPrivateCache = true
    this.privateCacheError = ''
    try {
      this.readerCacheStatus = ReaderImageCacheService.status(this.context())
      this.commentTranslationCacheStatus = await CommentTranslationService.stat(this.context())
      this.comicTranslationCacheStatus = await ComicTranslationRuntimeService.statGeneratedCache(this.context())
      this.tagDictionaryCacheStatus = await TagTranslationRepository.stat(this.context())
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

  private retryCountLabelFor(count: number): string {
    return count === 1
      ? AppStrings.format('settings_download_retry_one', [count.toString()])
      : AppStrings.format('settings_download_retry_other', [count.toString()])
  }

  private retryCountLabel(): string {
    return this.retryCountLabelFor(this.downloadSettings.retryCount)
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

  /** Spreads exist only in the horizontal LTR/RTL Pager modes. */
  private supportsReaderSpreadLayout(): boolean {
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
        this.galleryConcurrencyMenuShown = false
      })
      MenuItem({
        content: '2',
        symbolEndIcon: this.downloadSettings.maxConcurrentGalleries === 2
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveGalleryConcurrency(2)
        this.galleryConcurrencyMenuShown = false
      })
      MenuItem({
        content: '3',
        symbolEndIcon: this.downloadSettings.maxConcurrentGalleries === 3
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveGalleryConcurrency(3)
        this.galleryConcurrencyMenuShown = false
      })
      MenuItem({
        content: '4',
        symbolEndIcon: this.downloadSettings.maxConcurrentGalleries === 4
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveGalleryConcurrency(4)
        this.galleryConcurrencyMenuShown = false
      })
      MenuItem({
        content: '5',
        symbolEndIcon: this.downloadSettings.maxConcurrentGalleries === 5
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveGalleryConcurrency(5)
        this.galleryConcurrencyMenuShown = false
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
        this.pageConcurrencyMenuShown = false
      })
      MenuItem({
        content: '2',
        symbolEndIcon: this.downloadSettings.maxConcurrentPages === 2
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.savePageConcurrency(2)
        this.pageConcurrencyMenuShown = false
      })
      MenuItem({
        content: '3',
        symbolEndIcon: this.downloadSettings.maxConcurrentPages === 3
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.savePageConcurrency(3)
        this.pageConcurrencyMenuShown = false
      })
      MenuItem({
        content: '4',
        symbolEndIcon: this.downloadSettings.maxConcurrentPages === 4
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.savePageConcurrency(4)
        this.pageConcurrencyMenuShown = false
      })
      MenuItem({
        content: '5',
        symbolEndIcon: this.downloadSettings.maxConcurrentPages === 5
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.savePageConcurrency(5)
        this.pageConcurrencyMenuShown = false
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
        this.retryCountMenuShown = false
      })
      MenuItem({
        content: this.retryCountLabelFor(1),
        symbolEndIcon: this.downloadSettings.retryCount === 1
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRetryCount(1)
        this.retryCountMenuShown = false
      })
      MenuItem({
        content: this.retryCountLabelFor(2),
        symbolEndIcon: this.downloadSettings.retryCount === 2
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRetryCount(2)
        this.retryCountMenuShown = false
      })
      MenuItem({
        content: this.retryCountLabelFor(3),
        symbolEndIcon: this.downloadSettings.retryCount === 3
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveRetryCount(3)
        this.retryCountMenuShown = false
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
        this.readerModeMenuShown = false
      })
      MenuItem({
        content: AppStrings.get('settings_reader_mode_paged_rtl'),
        symbolStartIcon: new SymbolGlyphModifier(this.readerModeIcon(NhReaderMode.PAGED_RTL)),
        symbolEndIcon: this.readerPresentation.mode === NhReaderMode.PAGED_RTL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveReaderMode(NhReaderMode.PAGED_RTL)
        this.readerModeMenuShown = false
      })
      MenuItem({
        content: AppStrings.get('settings_reader_mode_paged_vertical'),
        symbolStartIcon: new SymbolGlyphModifier(this.readerModeIcon(NhReaderMode.PAGED_VERTICAL)),
        symbolEndIcon: this.readerPresentation.mode === NhReaderMode.PAGED_VERTICAL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveReaderMode(NhReaderMode.PAGED_VERTICAL)
        this.readerModeMenuShown = false
      })
      MenuItem({
        content: AppStrings.get('settings_reader_mode_vertical'),
        symbolStartIcon: new SymbolGlyphModifier(this.readerModeIcon(NhReaderMode.VERTICAL)),
        symbolEndIcon: this.readerPresentation.mode === NhReaderMode.VERTICAL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveReaderMode(NhReaderMode.VERTICAL)
        this.readerModeMenuShown = false
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
      this.readerImageScalingQualityMenuShown = false
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
      this.readerBackgroundMenuShown = false
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
      this.readerSpreadLayoutMenuShown = false
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
      this.readerTapZoneMenuShown = false
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
      this.readerTapZoneInvertMenuShown = false
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
        this.readButtonStyleMenuShown = false
      })
      MenuItem({
        content: AppStrings.get('read_button_style_hds'),
        symbolEndIcon: this.readButtonStyle.style === ReadButtonStyleSettings.STYLE_HDS
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setReadButtonStyle(ReadButtonStyleSettings.STYLE_HDS)
        this.readButtonStyleMenuShown = false
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
      this.readerPreloadMenuShown = false
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
      this.readerAutoPageMenuShown = false
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
    if (!this.supportsReaderSpreadLayout()) {
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
    if (key === 'reader') {
      return AppStrings.get('settings_private_cache_reader_pages')
    }
    if (key === 'comment') {
      return AppStrings.get('settings_private_cache_comment_translation')
    }
    if (key === 'comic') {
      return AppStrings.get('settings_private_cache_comic_translation')
    }
    return AppStrings.get('settings_private_cache_tag_dictionary')
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
          selected: this.isSettingsRootSelected(SETTINGS_ROOT_BROWSER_SESSION),
          accessibilityLabel: AppStrings.get('account_open_page_a11y'),
          accessibilityId: 'nextn-settings-root-account',
          onAction: (): void => {
            if (this.onOpenBrowserSession) {
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
          selected: this.isSettingsRootSelected(SETTINGS_ROOT_BROWSER_SESSION),
          accessibilityLabel: AppStrings.get('account_open_page_a11y'),
          accessibilityId: 'nextn-settings-root-account',
          onAction: (): void => {
            if (this.onOpenBrowserSession) {
              this.onOpenBrowserSession()
            }
          },
        })
      }
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
      if (key === 'reader') {
        await ReaderImageCacheService.clear(this.context())
      } else if (key === 'comment') {
        await CommentTranslationService.clear(this.context())
      } else if (key === 'comic') {
        await ComicTranslationRuntimeService.clearGeneratedCache(this.context())
      } else if (key === 'tag') {
        await TagTranslationRepository.clear(this.context())
      } else if (key === 'all') {
        await ReaderImageCacheService.clear(this.context())
        await CommentTranslationService.clear(this.context())
        await ComicTranslationRuntimeService.clearGeneratedCache(this.context())
        await TagTranslationRepository.clear(this.context())
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
  private TagDictionaryRows() {
    NextNListRow({
      leadingIcon: $r('sys.symbol.textformat'),
      title: AppStrings.get('settings_tag_translation_local_title'),
      trailingText: this.tagDictionaryStatusText(),
      showChevron: false,
    })
    this.RowDivider()
    NextNListRow({
      leadingIcon: $r('sys.symbol.arrow_clockwise'),
      title: AppStrings.get('settings_tag_translation_update'),
      subtitle: AppStrings.get('settings_tag_translation_update_hint'),
      trailingText: this.isUpdatingTagDictionary ? AppStrings.get('settings_tag_translation_updating') : '',
      showChevron: false,
      isEnabled: !this.isUpdatingTagDictionary,
      onAction: () => {
        this.updateTagDictionary()
      },
    })
  }

  @Builder
  private ClipboardLinkGroup() {
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
  private PrivateCacheGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.doc_text'),
        title: this.privateCacheTitle('reader'),
        subtitle: this.privateCacheSubtitle('reader'),
        trailingText: this.isClearingPrivateCache ? AppStrings.get('settings_private_cache_wait') :
          AppStrings.get('common_clear'),
        showChevron: false,
        isEnabled: !this.isClearingPrivateCache && this.privateCacheStat('reader').count > 0,
        accessibilityLabel: AppStrings.format('settings_private_cache_clear_a11y', [
          this.privateCacheTitle('reader'),
        ]),
        onAction: (): void => {
          this.requestPrivateCacheClear('reader')
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.translate'),
        title: this.privateCacheTitle('comment'),
        subtitle: this.privateCacheSubtitle('comment'),
        trailingText: this.isClearingPrivateCache ? AppStrings.get('settings_private_cache_wait') :
          AppStrings.get('common_clear'),
        showChevron: false,
        isEnabled: !this.isClearingPrivateCache && this.privateCacheStat('comment').count > 0,
        accessibilityLabel: AppStrings.format('settings_private_cache_clear_a11y', [
          this.privateCacheTitle('comment'),
        ]),
        onAction: (): void => {
          this.requestPrivateCacheClear('comment')
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.text_bubble_left_2'),
        title: this.privateCacheTitle('comic'),
        subtitle: this.privateCacheSubtitle('comic'),
        trailingText: this.isClearingPrivateCache ? AppStrings.get('settings_private_cache_wait') :
          AppStrings.get('common_clear'),
        showChevron: false,
        isEnabled: !this.isClearingPrivateCache && this.privateCacheStat('comic').count > 0,
        accessibilityLabel: AppStrings.format('settings_private_cache_clear_a11y', [
          this.privateCacheTitle('comic'),
        ]),
        onAction: (): void => {
          this.requestPrivateCacheClear('comic')
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.textformat'),
        title: this.privateCacheTitle('tag'),
        subtitle: this.privateCacheSubtitle('tag'),
        trailingText: this.isClearingPrivateCache ? AppStrings.get('settings_private_cache_wait') :
          AppStrings.get('common_clear'),
        showChevron: false,
        isEnabled: !this.isClearingPrivateCache && this.privateCacheStat('tag').count > 0,
        accessibilityLabel: AppStrings.format('settings_private_cache_clear_a11y', [
          this.privateCacheTitle('tag'),
        ]),
        onAction: (): void => {
          this.requestPrivateCacheClear('tag')
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.trash'),
        title: AppStrings.get('settings_private_cache_clear_all'),
        trailingText: this.isClearingPrivateCache ? AppStrings.get('settings_private_cache_wait') : '',
        showChevron: false,
        destructive: true,
        isEnabled: !this.isClearingPrivateCache && this.privateCacheTotalCount() > 0,
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
        leadingIcon: $r('sys.symbol.rectangle_stack'),
        title: AppStrings.get('settings_download_gallery_concurrency'),
        trailingText: `${this.downloadSettings.maxConcurrentGalleries}`,
        isEnabled: !this.isSavingDownloadSettings,
        accessibilityLabel: AppStrings.format('settings_download_gallery_concurrency_a11y', [
          this.downloadSettings.maxConcurrentGalleries.toString(),
        ]),
        onAction: (): void => {
          this.galleryConcurrencyMenuShown = true
        },
      })
      .bindMenu(this.galleryConcurrencyMenuShown, this.GalleryConcurrencyMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.galleryConcurrencyMenuShown = false
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.square_grid_2x2'),
        title: AppStrings.get('settings_download_page_concurrency'),
        trailingText: `${this.downloadSettings.maxConcurrentPages}`,
        isEnabled: !this.isSavingDownloadSettings,
        accessibilityLabel: AppStrings.format('settings_download_page_concurrency_a11y', [
          this.downloadSettings.maxConcurrentPages.toString(),
        ]),
        onAction: (): void => {
          this.pageConcurrencyMenuShown = true
        },
      })
      .bindMenu(this.pageConcurrencyMenuShown, this.PageConcurrencyMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.pageConcurrencyMenuShown = false
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.arrow_clockwise'),
        title: AppStrings.get('settings_download_failed_page_retries'),
        trailingText: this.retryCountLabel(),
        isEnabled: !this.isSavingDownloadSettings,
        accessibilityLabel: AppStrings.format('settings_download_failed_page_retries_a11y', [
          this.retryCountLabel(),
        ]),
        onAction: (): void => {
          this.retryCountMenuShown = true
        },
      })
      .bindMenu(this.retryCountMenuShown, this.RetryCountMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.retryCountMenuShown = false
        },
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
  private ReaderLayoutGroup() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      NextNSectionHeader({ title: AppStrings.get('settings_reader_group_layout') })
      NextNGroupedListSection() {
        NextNListRow({
          title: AppStrings.get('settings_reader_layout'),
          trailingText: this.readerModeLabel(),
          trailingDropdown: true,
          accessibilityLabel: AppStrings.format('settings_reader_layout_a11y', [this.readerModeLabel()]),
          onAction: (): void => {
            this.readerModeMenuShown = true
          },
        })
        .bindMenu(this.readerModeMenuShown, this.ReaderModeMenu, {
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.readerModeMenuShown = false
          },
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_double_page'),
          hasSwitch: true,
          checked: this.readerPresentation.doublePageEnabled,
          showChevron: false,
          accessibilityLabel: AppStrings.format('settings_reader_double_page_a11y', [
            this.toggleStateLabel(this.readerPresentation.doublePageEnabled),
          ]),
          onAction: (): void => {
            this.saveReaderDoublePageEnabled(!this.readerPresentation.doublePageEnabled)
          },
          onSwitchChange: (value: boolean): void => {
            this.saveReaderDoublePageEnabled(value)
          },
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_spread_layout'),
          trailingText: this.readerSpreadLayoutLabel(),
          trailingDropdown: true,
          isEnabled: this.supportsReaderSpreadLayout(),
          accessibilityLabel: AppStrings.format('settings_reader_spread_layout_a11y', [
            this.readerSpreadLayoutLabel(),
          ]),
          onAction: (): void => {
            if (!this.supportsReaderSpreadLayout()) {
              return
            }
            this.readerSpreadLayoutMenuShown = true
          },
        })
        .bindMenu(this.readerSpreadLayoutMenuShown, this.ReaderSpreadLayoutMenu, {
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.readerSpreadLayoutMenuShown = false
          },
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
          accessibilityLabel: AppStrings.format('settings_reader_tap_zones_a11y', [
            this.readerTapZoneLayoutLabel(),
          ]),
          onAction: (): void => {
            this.readerTapZoneMenuShown = true
          },
        })
        .bindMenu(this.readerTapZoneMenuShown, this.ReaderTapZoneMenu, {
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.readerTapZoneMenuShown = false
          },
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_tap_zone_invert'),
          trailingText: this.readerTapZoneInvertLabel(),
          trailingDropdown: true,
          accessibilityLabel: AppStrings.format('settings_reader_tap_zone_invert_a11y', [
            this.readerTapZoneInvertLabel(),
          ]),
          onAction: (): void => {
            this.readerTapZoneInvertMenuShown = true
          },
        })
        .bindMenu(this.readerTapZoneInvertMenuShown, this.ReaderTapZoneInvertMenu, {
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.readerTapZoneInvertMenuShown = false
          },
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
          accessibilityLabel: AppStrings.format('settings_reader_background_a11y', [
            this.readerBackgroundModeLabel(),
          ]),
          onAction: (): void => {
            this.readerBackgroundMenuShown = true
          },
        })
        .bindMenu(this.readerBackgroundMenuShown, this.ReaderBackgroundModeMenu, {
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.readerBackgroundMenuShown = false
          },
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('settings_reader_image_scaling_quality'),
          subtitle: AppStrings.get('settings_reader_image_scaling_quality_hint'),
          subtitleMaxLines: 3,
          trailingText: this.readerImageScalingQualityLabel(),
          trailingDropdown: true,
          accessibilityLabel: AppStrings.format('settings_reader_image_scaling_quality_a11y', [
            this.readerImageScalingQualityLabel(),
          ]),
          onAction: (): void => {
            this.readerImageScalingQualityMenuShown = true
          },
        })
        .bindMenu(this.readerImageScalingQualityMenuShown, this.ReaderImageScalingQualityMenu, {
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.readerImageScalingQualityMenuShown = false
          },
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
          isEnabled: this.readerEnhancementInstalledModels.length > 0,
          accessibilityLabel: AppStrings.format('settings_reader_enhancement_model_selection_a11y', [
            this.readerEnhancementModelLabel(),
          ]),
          onAction: (): void => {
            if (this.readerEnhancementInstalledModels.length > 0) {
              this.readerEnhancementModelMenuShown = true
            }
          },
        })
        .bindMenu(this.readerEnhancementModelMenuShown, this.ReaderEnhancementModelMenu, {
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.readerEnhancementModelMenuShown = false
          },
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
          isEnabled: this.readerPresentation.superResolutionEnabled &&
            this.selectedReaderEnhancementModelInstalled(),
          accessibilityLabel: AppStrings.format('settings_reader_enhancement_max_height_a11y', [
            this.readerEnhancementMaxHeightLabel(),
          ]),
          onAction: (): void => {
            if (this.readerPresentation.superResolutionEnabled &&
              this.selectedReaderEnhancementModelInstalled()) {
              this.readerEnhancementMaxHeightMenuShown = true
            }
          },
        })
        .bindMenu(this.readerEnhancementMaxHeightMenuShown, this.ReaderEnhancementMaxHeightMenu, {
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.readerEnhancementMaxHeightMenuShown = false
          },
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
          accessibilityLabel: AppStrings.format('settings_reader_auto_advance_interval_a11y', [
            this.readerAutoPageLabel(),
          ]),
          onAction: (): void => {
            this.readerAutoPageMenuShown = true
          },
        })
        .bindMenu(this.readerAutoPageMenuShown, this.ReaderAutoPageMenu, {
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.readerAutoPageMenuShown = false
          },
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
          accessibilityLabel: AppStrings.format('settings_reader_preload_pages_a11y', [this.readerPreloadLabel()]),
          onAction: (): void => {
            this.readerPreloadMenuShown = true
          },
        })
        .bindMenu(this.readerPreloadMenuShown, this.ReaderPreloadMenu, {
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.readerPreloadMenuShown = false
          },
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
      onClose: (): void => {
        this.readerEnhancementModelsShown = false
        this.loadReaderPresentation()
      },
      onModelsChanged: (): void => {
        this.loadReaderPresentation()
      },
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
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_theme'),
          this.themeModeLabel(),
        ]),
        onAction: (): void => {
          this.themeMenuShown = true
        },
      })
      .bindMenu(this.themeMenuShown, this.ThemeMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.themeMenuShown = false
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.paintbrush'),
        title: AppStrings.get('settings_theme_color'),
        useCustomTrailing: true,
        customTrailing: (): void => {
          this.ThemeColorSuffix()
        },
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_theme_color'),
          this.themeColorLabel(),
        ]),
        onAction: (): void => {
          this.themeColorMenuShown = true
        },
      })
      .bindMenu(this.themeColorMenuShown, this.ThemeColorMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.themeColorMenuShown = false
        },
      })
      .bindSheet($$this.themeColorPickerShown, this.ThemeColorPickerSheet(), {
        detents: [SheetSize.LARGE],
        showClose: false,
        onDisappear: (): void => {
          this.closeThemeColorPicker()
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.picture'),
        title: AppStrings.get('immersive_material'),
        trailingText: this.immersiveMaterialLabel(),
        trailingDropdown: true,
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('immersive_material'),
          this.immersiveMaterialLabel(),
        ]),
        onAction: (): void => {
          this.immersiveMaterialMenuShown = true
        },
      })
      .bindMenu(this.immersiveMaterialMenuShown, this.ImmersiveMaterialMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.immersiveMaterialMenuShown = false
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.translate'),
        title: AppStrings.get('settings_language'),
        trailingText: this.languageModeLabel(),
        trailingDropdown: true,
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_language'),
          this.languageModeLabel(),
        ]),
        onAction: (): void => {
          this.languageMenuShown = true
        },
      })
      .bindMenu(this.languageMenuShown, this.LanguageMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.languageMenuShown = false
        },
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
        this.browsePresentationMenuShown = false
      })
      MenuItem({
        content: AppStrings.get('browse_simple_list'),
        symbolEndIcon: this.browsePresentation.mode === NhBrowsePresentation.SIMPLE_LIST
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveBrowsePresentation(NhBrowsePresentation.SIMPLE_LIST)
        this.browsePresentationMenuShown = false
      })
      MenuItem({
        content: AppStrings.get('browse_cover_grid'),
        symbolEndIcon: this.browsePresentation.mode === NhBrowsePresentation.COVER_GRID
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveBrowsePresentation(NhBrowsePresentation.COVER_GRID)
        this.browsePresentationMenuShown = false
      })
      MenuItem({
        content: AppStrings.get('browse_waterfall'),
        symbolEndIcon: this.browsePresentation.mode === NhBrowsePresentation.WATERFALL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveBrowsePresentation(NhBrowsePresentation.WATERFALL)
        this.browsePresentationMenuShown = false
      })
      MenuItem({
        content: AppStrings.get('browse_waterfall_compact'),
        symbolEndIcon: this.browsePresentation.mode === NhBrowsePresentation.WATERFALL_COMPACT
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveBrowsePresentation(NhBrowsePresentation.WATERFALL_COMPACT)
        this.browsePresentationMenuShown = false
      })
      MenuItem({
        content: AppStrings.get('browse_cover_wall'),
        symbolEndIcon: this.browsePresentation.mode === NhBrowsePresentation.COVER_WALL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.saveBrowsePresentation(NhBrowsePresentation.COVER_WALL)
        this.browsePresentationMenuShown = false
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
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('browse_presentation'),
          this.browsePresentationLabel(),
        ]),
        onAction: (): void => {
          this.browsePresentationMenuShown = true
        },
      })
      .bindMenu(this.browsePresentationMenuShown, this.BrowsePresentationMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.browsePresentationMenuShown = false
        },
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
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.translate'),
        title: AppStrings.get('settings_gallery_tag_translations'),
        hasSwitch: true,
        checked: this.browsePresentation.showTranslatedTagLabels,
        showChevron: false,
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_gallery_tag_translations'),
          this.toggleStateLabel(this.browsePresentation.showTranslatedTagLabels),
        ]),
        onAction: (): void => {
          this.setShowTranslatedTagLabels(!this.browsePresentation.showTranslatedTagLabels)
        },
        onSwitchChange: (value: boolean): void => {
          this.setShowTranslatedTagLabels(value)
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
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_action_alignment'),
          this.actionAlignmentLabel(),
        ]),
        onAction: (): void => {
          this.actionAlignmentMenuShown = true
        },
      })
      .bindMenu(this.actionAlignmentMenuShown, this.ActionAlignmentMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.actionAlignmentMenuShown = false
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.paintbrush'),
        title: AppStrings.get('settings_read_button_style'),
        subtitle: AppStrings.get('settings_read_button_style_hint'),
        trailingText: this.readButtonStyleLabel(),
        trailingDropdown: true,
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_read_button_style'),
          this.readButtonStyleLabel(),
        ]),
        onAction: (): void => {
          this.readButtonStyleMenuShown = true
        },
      })
      .bindMenu(this.readButtonStyleMenuShown, this.ReadButtonStyleMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.readButtonStyleMenuShown = false
        },
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
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_tablet_layout'),
          this.tabletLayoutLabel(),
        ]),
        onAction: (): void => {
          this.tabletLayoutMenuShown = true
        },
      })
      .bindMenu(this.tabletLayoutMenuShown, this.TabletLayoutMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.tabletLayoutMenuShown = false
        },
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
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_screen_orientation'),
          this.screenOrientationLabel(),
        ]),
        onAction: (): void => {
          this.screenOrientationMenuShown = true
        },
      })
      .bindMenu(this.screenOrientationMenuShown, this.ScreenOrientationMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.screenOrientationMenuShown = false
        },
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
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_catalog_browse_language'),
          this.catalogLanguageLabel(this.catalogPreferences.browseLanguage),
        ]),
        onAction: (): void => {
          this.catalogBrowseLanguageMenuShown = true
        },
      })
      .bindMenu(this.catalogBrowseLanguageMenuShown, this.CatalogBrowseLanguageMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.catalogBrowseLanguageMenuShown = false
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.arrow_clockwise'),
        title: AppStrings.get('settings_catalog_browse_sort'),
        trailingText: this.catalogSortLabel(this.catalogPreferences.browseSort),
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_catalog_browse_sort'),
          this.catalogSortLabel(this.catalogPreferences.browseSort),
        ]),
        onAction: (): void => {
          this.catalogBrowseSortMenuShown = true
        },
      })
      .bindMenu(this.catalogBrowseSortMenuShown, this.CatalogBrowseSortMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.catalogBrowseSortMenuShown = false
        },
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
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_catalog_search_language'),
          this.catalogLanguageLabel(this.catalogPreferences.searchLanguage),
        ]),
        onAction: (): void => {
          this.catalogSearchLanguageMenuShown = true
        },
      })
      .bindMenu(this.catalogSearchLanguageMenuShown, this.CatalogSearchLanguageMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.catalogSearchLanguageMenuShown = false
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.rectangle_stack'),
        title: AppStrings.get('settings_catalog_search_sort'),
        trailingText: this.catalogSortLabel(this.catalogPreferences.searchSort),
        accessibilityLabel: AppStrings.format('settings_row_a11y', [
          AppStrings.get('settings_catalog_search_sort'),
          this.catalogSortLabel(this.catalogPreferences.searchSort),
        ]),
        onAction: (): void => {
          this.catalogSearchSortMenuShown = true
        },
      })
      .bindMenu(this.catalogSearchSortMenuShown, this.CatalogSearchSortMenu, {
        placement: Placement.BottomRight,
        onDisappear: (): void => {
          this.catalogSearchSortMenuShown = false
        },
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

  /** Translation capabilities share one reference-owned Advanced Settings surface. */
  @Builder
  private TranslationCapabilitiesGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.translate'),
        title: AppStrings.get('settings_comment_translation'),
        accessibilityLabel: AppStrings.get('settings_comment_translation_a11y'),
        onAction: (): void => {
          if (this.onOpenTranslationSource) {
            this.onOpenTranslationSource(LLM_CONSUMER_COMMENT_TRANSLATION)
          }
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.picture'),
        title: AppStrings.get('settings_reader_comic_translation'),
        accessibilityLabel: AppStrings.get('settings_reader_comic_translation_a11y'),
        onAction: (): void => {
          if (this.onOpenTranslationSource) {
            this.onOpenTranslationSource(LLM_CONSUMER_MANGA_TRANSLATION)
          }
        },
      })
      this.RowDivider()
      this.TagDictionaryRows()
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.cloud'),
        title: AppStrings.get('settings_translation_source'),
        onAction: (): void => {
          if (this.onOpenTranslationSource) {
            this.onOpenTranslationSource(LLM_CONSUMER_MANGA_TRANSLATION)
          }
        },
      })
    }
  }

  build() {
    if (this.surface === SettingsSurface.READER && this.sheetPresentation) {
      if (this.readerEnhancementModelsShown) {
        this.ReaderEnhancementModelsSheet()
      } else {
        this.ReaderPresentationSheet()
      }
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
          ListItem() {
            this.RootAccountSection()
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
          if (this.downloadSettingsError.length > 0) {
            ListItem() {
              this.GroupNote(this.downloadSettingsError)
            }
          }
        } else if (this.surface === SettingsSurface.CACHE) {
          ListItem() {
            this.PrivateCacheTotalSummary()
          }
          ListItem() {
            this.PrivateCacheGroup()
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
          if (this.tagDictionaryError.length > 0) {
            ListItem() {
              this.GroupNote(this.tagDictionaryError)
            }
          }
          ListItem() {
            this.ContentFiltersGroup()
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
