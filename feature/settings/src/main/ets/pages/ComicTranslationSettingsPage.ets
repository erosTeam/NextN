import { common } from '@kit.AbilityKit'
import { KeyboardAvoidMode, SymbolGlyphModifier } from '@kit.ArkUI'
import {
  AppStrings,
  COMIC_VISUAL_ROUTE_LOCAL,
  COMIC_VISUAL_ROUTE_SELF_HOSTED,
  COMIC_VISUAL_ROUTE_TORII,
  ComicTranslationDiagnosticLogger,
  ComicVisualProviderSettings,
  ComicVisualProviderSettingsSnapshot,
  ComicTranslationModelCatalogService,
  ComicTranslationModelService,
  CommentTranslationService,
  LLM_CONSUMER_MANGA_TRANSLATION,
  LlmConsumerBinding,
  LlmSourceProfile,
  LlmSourceProfileRepository,
  LlmSourceProfilesState,
  MangaRenderingServiceSettings,
  ToriiCreditsService,
  ToriiCreditsSnapshot,
  ToriiFontCatalog,
  ToriiFontOption,
  ToriiTranslatorModel,
  ToriiTranslatorModelCatalog,
  ToriiWholePageCredential,
  ToriiWholePageLiveEvaluationReport,
  ToriiWholePageLiveEvaluationService,
  ToriiWholePageSecretStore,
  NextNGroupedListSection,
  NextNListRow,
  SecondaryListScaffold,
  ThemeTokens,
  connectLlmSourceProfiles,
  supportsMangaTranslation,
} from 'shared'
import { appMenuOptions } from 'shared'

/**
 * Dedicated comic-translation destination, matching NextE's
 * ComicTranslationSettingsPage: a route selector (on-device, self-hosted,
 * Torii cloud whole-page) drives conditional groups. The manga consumer
 * binding and local detector serve the staged routes; the Torii group
 * manages the cloud whole-page model, font, API key, and credits.
 */
@ComponentV2
export struct ComicTranslationSettingsPage {
  @Local visualRoute: string = COMIC_VISUAL_ROUTE_LOCAL
  @Local visualRouteMenuShown: boolean = false
  @Local visualSettingsLoaded: boolean = false
  @Local multimodalTranslationEnabled: boolean = true
  @Local toriiModelMenuShown: boolean = false
  @Local toriiFontMenuShown: boolean = false
  @Local toriiModelId: string = ''
  @Local toriiFontId: string = 'noto'
  @Local toriiApiKeyDraft: string = ''
  @Local toriiCredits: ToriiCreditsSnapshot | null = null
  @Local toriiCreditsRefreshing: boolean = false
  @Local toriiLiveEvaluationRunning: boolean = false
  @Local toriiLiveEvaluationReport: ToriiWholePageLiveEvaluationReport | null = null
  private toriiCreditsRefreshTimer: number = -1
  @Local sources: LlmSourceProfilesState = connectLlmSourceProfiles()
  @Local sourceMenuShown: boolean = false
  @Local modelMenuShown: boolean = false
  @Local fetchingModels: boolean = false
  @Local modelOptions: string[] = []
  @Local selectedSourceId: string = ''
  @Local selectedModelId: string = ''
  @Local localModelInstalled: boolean = false
  @Local localModelChanging: boolean = false
  @Local mangaRenderingServiceEnabled: boolean = false
  @Param scroller: Scroller = new Scroller()
  @Event onOpenTranslationSource?: (consumerId: string) => void
  @Event onOpenMangaRenderingService?: () => void
  @Event onOpenToriiLiveEvaluation?: (report: ToriiWholePageLiveEvaluationReport) => void

  aboutToAppear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
    try {
      const credential: ToriiWholePageCredential = ToriiWholePageSecretStore.readSync(
        this.context(),
      )
      this.toriiApiKeyDraft = credential.toriiApiKey
      this.toriiCredits = ToriiCreditsService.cachedSync(
        this.context(),
        credential.toriiApiKey,
      )
    } catch (_error) {
    }
    this.loadVisualSettings()
    this.restoreBinding()
    this.refreshLocalModel()
    this.refreshMangaRenderingService()
  }

  aboutToDisappear(): void {
    if (this.visualSettingsLoaded) {
      this.persistVisualSettings(false)
    }
    if (this.toriiCreditsRefreshTimer >= 0) {
      clearTimeout(this.toriiCreditsRefreshTimer)
      this.toriiCreditsRefreshTimer = -1
    }
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private async loadVisualSettings(): Promise<void> {
    try {
      const snapshot: ComicVisualProviderSettingsSnapshot =
        await ComicVisualProviderSettings.load(this.context())
      const credential: ToriiWholePageCredential =
        await ToriiWholePageSecretStore.read(this.context())
      this.visualRoute = snapshot.route
      this.multimodalTranslationEnabled = snapshot.multimodalTranslationEnabled
      this.toriiModelId = snapshot.toriiModelId
      this.toriiFontId = ToriiFontCatalog.effectiveFontId(
        snapshot.toriiFontId,
        CommentTranslationService.targetLanguage(),
      )
      this.toriiApiKeyDraft = credential.toriiApiKey
      this.toriiCredits = ToriiCreditsService.cachedSync(
        this.context(),
        credential.toriiApiKey,
      )
      this.visualSettingsLoaded = true
      if (snapshot.route === COMIC_VISUAL_ROUTE_TORII &&
        ToriiCreditsService.isStale(this.toriiCredits)) {
        this.refreshToriiCredits()
      }
    } catch (error) {
      ComicTranslationDiagnosticLogger.warn(
        'comic-translation',
        'visual_settings_load_failed',
        (error as Error).message,
      )
    }
  }

  private async persistVisualSettings(showFailureToast: boolean = true): Promise<boolean> {
    const snapshot: ComicVisualProviderSettingsSnapshot =
      new ComicVisualProviderSettingsSnapshot()
    snapshot.route = this.visualRoute
    snapshot.multimodalTranslationEnabled = this.multimodalTranslationEnabled
    snapshot.toriiModelId = this.toriiModelId
    snapshot.toriiFontId = ToriiFontCatalog.effectiveFontId(
      this.toriiFontId,
      CommentTranslationService.targetLanguage(),
    )
    const credential: ToriiWholePageCredential = new ToriiWholePageCredential()
    credential.toriiApiKey = this.toriiApiKeyDraft.trim()
    try {
      await ComicVisualProviderSettings.save(this.context(), snapshot)
      await ToriiWholePageSecretStore.save(this.context(), credential)
      this.toriiApiKeyDraft = credential.toriiApiKey
      return true
    } catch (error) {
      if (showFailureToast) {
        this.showToriiSaveFailedToast()
      }
      return false
    }
  }

  private showToriiSaveFailedToast(): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: AppStrings.get('comic_torii_save_failed'),
      })
    } catch (_error) {}
  }

  private visualRouteText(): string {
    if (this.visualRoute === COMIC_VISUAL_ROUTE_TORII) {
      return AppStrings.get('comic_visual_route_torii')
    }
    if (this.visualRoute === COMIC_VISUAL_ROUTE_SELF_HOSTED) {
      return AppStrings.get('comic_visual_route_self_hosted')
    }
    return AppStrings.get('comic_visual_route_local')
  }

  private selectVisualRoute(route: string): void {
    this.visualRouteMenuShown = false
    if (route === this.visualRoute) {
      return
    }
    if (route === COMIC_VISUAL_ROUTE_TORII) {
      this.getUIContext().showAlertDialog({
        title: AppStrings.get('comic_visual_route_torii_confirm_title'),
        message: AppStrings.get('comic_visual_route_torii_confirm'),
        primaryButton: {
          value: AppStrings.get('common_cancel'),
          action: (): void => {},
        },
        secondaryButton: {
          value: AppStrings.get('common_ok'),
          action: (): void => {
            this.visualRoute = COMIC_VISUAL_ROUTE_TORII
            this.persistVisualSettings(true)
            this.refreshToriiCredits()
          },
        },
      })
      return
    }
    if (route === COMIC_VISUAL_ROUTE_SELF_HOSTED) {
      this.getUIContext().showAlertDialog({
        title: AppStrings.get('comic_visual_route_self_hosted_confirm_title'),
        message: AppStrings.get('comic_visual_route_self_hosted_confirm'),
        primaryButton: {
          value: AppStrings.get('common_cancel'),
          action: (): void => {},
        },
        secondaryButton: {
          value: AppStrings.get('common_ok'),
          action: (): void => {
            this.visualRoute = COMIC_VISUAL_ROUTE_SELF_HOSTED
            this.persistVisualSettings(true)
          },
        },
      })
      return
    }
    this.visualRoute = COMIC_VISUAL_ROUTE_LOCAL
    this.persistVisualSettings(true)
  }

  private toriiModelText(): string {
    const model: ToriiTranslatorModel | null =
      ToriiTranslatorModelCatalog.find(this.toriiModelId)
    if (model === null) {
      return this.toriiModelId
    }
    return `${model.displayName} · ${model.baseCredits}+`
  }

  private selectToriiModel(modelId: string): void {
    this.toriiModelId = modelId
    this.toriiModelMenuShown = false
    this.persistVisualSettings(true)
  }

  private toriiFontText(): string {
    return ToriiFontCatalog.displayName(this.toriiFontId)
  }

  private toriiFonts(): ToriiFontOption[] {
    return ToriiFontCatalog.forTargetLanguage(
      CommentTranslationService.targetLanguage(),
    )
  }

  private selectToriiFont(fontId: string): void {
    if (!ToriiFontCatalog.supports(
      fontId,
      CommentTranslationService.targetLanguage(),
    )) {
      return
    }
    this.toriiFontId = fontId
    this.toriiFontMenuShown = false
    this.persistVisualSettings(true)
  }

  private refreshToriiCredits(): void {
    const apiKey: string = this.toriiApiKeyDraft.trim()
    if (apiKey.length === 0 || this.toriiCreditsRefreshing) {
      return
    }
    this.toriiCreditsRefreshing = true
    ToriiCreditsService.fetch(apiKey)
      .then((snapshot: ToriiCreditsSnapshot): Promise<void> => {
        if (this.toriiApiKeyDraft.trim() !== apiKey) {
          return Promise.resolve()
        }
        this.toriiCredits = snapshot
        return ToriiCreditsService.saveCached(this.context(), apiKey, snapshot)
      })
      .catch((error: Error): void => {
        ComicTranslationDiagnosticLogger.warn(
          'comic-translation',
          'torii_credits_background_failed',
          error.message,
        )
      })
      .finally((): void => {
        this.toriiCreditsRefreshing = false
      })
  }

  private toriiCreditsText(): string {
    if (this.toriiCredits === null) {
      return this.toriiCreditsRefreshing
        ? AppStrings.get('comic_torii_credits_refreshing')
        : '—'
    }
    return this.toriiCredits.credits.toFixed(2).replace(/\.00$/, '')
  }

  private toriiModels(): ToriiTranslatorModel[] {
    return ToriiTranslatorModelCatalog.all()
  }

  private toriiReady(): boolean {
    return this.toriiApiKeyDraft.trim().length > 0
  }

  private toriiLiveEvaluationTrailingText(): string {
    if (this.toriiLiveEvaluationRunning) {
      return AppStrings.get('comic_torii_live_evaluation_running_short')
    }
    if (this.toriiLiveEvaluationReport === null) {
      return AppStrings.get('comic_torii_live_evaluation_pages')
    }
    return this.toriiLiveEvaluationReport.passed()
      ? AppStrings.get('comic_torii_live_evaluation_view')
      : AppStrings.get('comic_torii_live_evaluation_failed_short')
  }

  private toriiLiveEvaluationFailureMessage(
    report: ToriiWholePageLiveEvaluationReport,
  ): string {
    const page: string = report.failedPageIndex >= 0
      ? `P${report.failedPageIndex + 1}`
      : 'setup'
    const detail: string = report.errorDetail.length > 0
      ? `\n${report.errorDetail}`
      : ''
    return `${page} · ${report.errorCode || 'failed'}${detail}`
  }

  private openToriiLiveEvaluation(): void {
    if (this.toriiLiveEvaluationRunning) {
      return
    }
    if (this.toriiLiveEvaluationReport !== null) {
      if (!this.toriiLiveEvaluationReport.passed()) {
        this.showToriiLiveEvaluationFailure(this.toriiLiveEvaluationReport)
        return
      }
      if (this.onOpenToriiLiveEvaluation) {
        this.onOpenToriiLiveEvaluation(this.toriiLiveEvaluationReport)
      }
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('comic_translation_live_evaluation_title'),
      message: AppStrings.get('comic_translation_live_evaluation_confirm'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('comic_translation_live_evaluation_start'),
        action: (): void => {
          this.runToriiLiveEvaluation()
        },
      },
    })
  }

  private async runToriiLiveEvaluation(): Promise<void> {
    if (this.toriiLiveEvaluationRunning || !this.toriiReady()) {
      return
    }
    this.toriiLiveEvaluationRunning = true
    this.toriiLiveEvaluationReport = null
    try {
      if (!await this.persistVisualSettings(true)) {
        return
      }
      const report: ToriiWholePageLiveEvaluationReport =
        await ToriiWholePageLiveEvaluationService.run(this.context())
      this.toriiLiveEvaluationReport = report
      this.refreshToriiCredits()
      if (report.passed()) {
        if (this.onOpenToriiLiveEvaluation) {
          this.onOpenToriiLiveEvaluation(report)
        }
      } else {
        this.showToriiLiveEvaluationFailure(report)
      }
    } catch (error) {
      ComicTranslationDiagnosticLogger.warn(
        'comic-translation',
        'torii_live_evaluation_failed',
        (error as Error).message,
      )
      this.getUIContext().getPromptAction().showToast({
        message: AppStrings.get('comic_translation_live_evaluation_not_passed'),
      })
    } finally {
      this.toriiLiveEvaluationRunning = false
    }
  }

  private showToriiLiveEvaluationFailure(
    report: ToriiWholePageLiveEvaluationReport,
  ): void {
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('comic_torii_live_evaluation_failed_short'),
      message: this.toriiLiveEvaluationFailureMessage(report),
      primaryButton: {
        value: AppStrings.get('common_ok'),
        action: (): void => {},
      },
    })
  }

  private compatibleSources(): LlmSourceProfile[] {
    const profiles: LlmSourceProfile[] = []
    for (let index: number = 0; index < this.sources.profiles.length; index++) {
      const profile: LlmSourceProfile = this.sources.profiles[index]
      if (supportsMangaTranslation(profile)) {
        profiles.push(profile)
      }
    }
    return profiles
  }

  private restoreBinding(): void {
    const binding: LlmConsumerBinding = this.sources.mangaBinding
    const profile: LlmSourceProfile | null = this.sources.findById(binding.sourceProfileId)
    if (profile === null || !supportsMangaTranslation(profile) || !binding.configured()) {
      this.selectedSourceId = ''
      this.selectedModelId = ''
      return
    }
    this.selectedSourceId = binding.sourceProfileId
    this.selectedModelId = binding.modelId
  }

  private selectedSourceText(): string {
    const profile: LlmSourceProfile | null = this.sources.findById(this.selectedSourceId)
    return profile === null
      ? AppStrings.get('llm_binding_not_configured')
      : profile.displayName
  }

  private selectedModelText(): string {
    return this.selectedModelId.length > 0
      ? this.selectedModelId
      : AppStrings.get('llm_binding_not_configured')
  }

  private openSourceSelector(): void {
    if (this.compatibleSources().length === 0) {
      if (this.onOpenTranslationSource) {
        this.onOpenTranslationSource(LLM_CONSUMER_MANGA_TRANSLATION)
      }
      return
    }
    this.sourceMenuShown = true
  }

  private selectSource(sourceProfileId: string): void {
    this.sourceMenuShown = false
    if (sourceProfileId === this.selectedSourceId) {
      return
    }
    this.selectedSourceId = sourceProfileId
    this.selectedModelId = ''
    this.modelOptions = []
    this.fetchModels()
  }

  private fetchModels(): void {
    if (this.fetchingModels || this.selectedSourceId.length === 0) {
      return
    }
    this.fetchingModels = true
    ComicTranslationModelCatalogService.fetchSource(this.context(), this.selectedSourceId)
      .then((models: string[]): void => {
        this.modelOptions = models
        if (models.length === 0) {
          this.getUIContext().getPromptAction().showToast({
            message: AppStrings.get('comment_translation_models_empty'),
          })
          return
        }
        this.modelMenuShown = true
      })
      .catch((error: Error): void => {
        ComicTranslationDiagnosticLogger.warn(
          'comic-translation',
          'model_catalog_failed',
          error.message,
        )
        this.getUIContext().getPromptAction().showToast({
          message: AppStrings.get('comment_translation_models_failed'),
        })
      })
      .finally((): void => {
        this.fetchingModels = false
      })
  }

  private selectModel(modelId: string): void {
    const binding: LlmConsumerBinding = new LlmConsumerBinding()
    binding.consumerId = LLM_CONSUMER_MANGA_TRANSLATION
    binding.sourceProfileId = this.selectedSourceId
    binding.modelId = modelId
    LlmSourceProfileRepository.saveBinding(this.context(), binding)
      .then((): void => {
        this.selectedModelId = modelId
        this.modelMenuShown = false
      })
      .catch((error: Error): void => {
        this.getUIContext().getPromptAction().showToast({
          message: AppStrings.get('llm_binding_save_failed'),
        })
      })
  }

  private async refreshLocalModel(): Promise<void> {
    try {
      this.localModelInstalled = await ComicTranslationModelService.isInstalled(this.context())
    } catch (_error) {
      this.localModelInstalled = false
    }
  }

  private async refreshMangaRenderingService(): Promise<void> {
    try {
      this.mangaRenderingServiceEnabled =
        (await MangaRenderingServiceSettings.load(this.context())).enabled
    } catch (_error) {
      this.mangaRenderingServiceEnabled = false
    }
  }

  private confirmInstallLocalModel(): void {
    if (this.localModelChanging || this.localModelInstalled) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('settings_translation_local_model_install_title'),
      message: AppStrings.get('settings_translation_local_model_install_message'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('settings_translation_local_model_download'),
        action: (): void => {
          this.installLocalModel()
        },
      },
    })
  }

  private async installLocalModel(): Promise<void> {
    if (this.localModelChanging || this.localModelInstalled) {
      return
    }
    this.localModelChanging = true
    try {
      await ComicTranslationModelService.install(this.context())
      this.localModelInstalled = true
      this.getUIContext().getPromptAction().showToast({
        message: AppStrings.get('settings_translation_local_model_installed'),
      })
    } catch (_error) {
      this.getUIContext().getPromptAction().showToast({
        message: AppStrings.get('settings_translation_local_model_download_failed'),
      })
    } finally {
      this.localModelChanging = false
    }
  }

  private confirmRemoveLocalModel(): void {
    if (this.localModelChanging || !this.localModelInstalled) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('settings_translation_local_model_remove_title'),
      message: AppStrings.get('settings_translation_local_model_remove_message'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('settings_translation_local_model_remove'),
        fontColor: Color.Red,
        action: (): void => {
          this.removeLocalModel()
        },
      },
    })
  }

  private removeLocalModel(): void {
    if (this.localModelChanging || !this.localModelInstalled) {
      return
    }
    this.localModelChanging = true
    try {
      ComicTranslationModelService.remove(this.context())
      this.localModelInstalled = false
    } catch (_error) {
      this.getUIContext().getPromptAction().showToast({
        message: AppStrings.get('settings_translation_local_model_remove_failed'),
      })
    } finally {
      this.localModelChanging = false
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
  private VisualRouteMenu() {
    Menu() {
      MenuItem({
        content: AppStrings.get('comic_visual_route_local'),
        symbolEndIcon: this.visualRoute === COMIC_VISUAL_ROUTE_LOCAL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.selectVisualRoute(COMIC_VISUAL_ROUTE_LOCAL)
      })
      MenuItem({
        content: AppStrings.get('comic_visual_route_self_hosted'),
        symbolEndIcon: this.visualRoute === COMIC_VISUAL_ROUTE_SELF_HOSTED
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.selectVisualRoute(COMIC_VISUAL_ROUTE_SELF_HOSTED)
      })
      MenuItem({
        content: AppStrings.get('comic_visual_route_torii'),
        symbolEndIcon: this.visualRoute === COMIC_VISUAL_ROUTE_TORII
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.selectVisualRoute(COMIC_VISUAL_ROUTE_TORII)
      })
    }
  }

  @Builder
  private ToriiModelMenu() {
    Menu() {
      ForEach(
        this.toriiModels(),
        (model: ToriiTranslatorModel): void => {
          MenuItem({
            content: `${model.displayName} · ${model.baseCredits}+`,
            symbolEndIcon: this.toriiModelId === model.modelId
              ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
              : undefined,
          }).onClick((): void => {
            this.selectToriiModel(model.modelId)
          })
        },
        (model: ToriiTranslatorModel): string => model.modelId,
      )
    }
  }

  @Builder
  private ToriiFontMenu() {
    Menu() {
      ForEach(
        this.toriiFonts(),
        (font: ToriiFontOption): void => {
          MenuItem({
            content: font.displayName,
            symbolEndIcon: this.toriiFontId === font.fontId
              ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
              : undefined,
          }).onClick((): void => {
            this.selectToriiFont(font.fontId)
          })
        },
        (font: ToriiFontOption): string => font.fontId,
      )
    }
  }

  @Builder
  private ToriiSecretRow(label: string, placeholder: string) {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Text(label)
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .width('100%')
      TextInput({ text: $$this.toriiApiKeyDraft, placeholder: placeholder })
        .type(InputType.Password)
        .width('100%')
        .height(48)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
        .onChange((): void => {
          this.toriiCredits = null
          if (this.toriiCreditsRefreshTimer >= 0) {
            clearTimeout(this.toriiCreditsRefreshTimer)
            this.toriiCreditsRefreshTimer = -1
          }
          this.toriiCreditsRefreshTimer = setTimeout((): void => {
            this.toriiCreditsRefreshTimer = -1
            this.refreshToriiCredits()
          }, 600)
        })
    }
    .width('100%')
    .padding({
      left: ThemeTokens.SPACE_MD,
      right: ThemeTokens.SPACE_MD,
      top: ThemeTokens.SPACE_SM,
      bottom: ThemeTokens.SPACE_SM,
    })
  }

  @Builder
  private SourceMenu() {
    Menu() {
      ForEach(
        this.compatibleSources(),
        (profile: LlmSourceProfile): void => {
          MenuItem({
            content: profile.displayName,
            symbolEndIcon: this.selectedSourceId === profile.sourceProfileId
              ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
              : undefined,
          }).onClick((): void => {
            this.selectSource(profile.sourceProfileId)
          })
        },
        (profile: LlmSourceProfile) => profile.sourceProfileId,
      )
    }
  }

  @Builder
  private ModelMenu() {
    Menu() {
      ForEach(
        this.modelOptions,
        (model: string): void => {
          MenuItem({
            content: model,
            symbolEndIcon: this.selectedModelId === model
              ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
              : undefined,
          }).onClick((): void => {
            this.selectModel(model)
          })
        },
        (model: string) => model,
      )
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
          NextNGroupedListSection() {
            Column() {
              NextNListRow({
                leadingIcon: $r('sys.symbol.picture'),
                title: AppStrings.get('comic_visual_route'),
                trailingText: this.visualRouteText(),
                trailingDropdown: true,
                accessibilityLabel: AppStrings.get('comic_visual_route'),
                onAction: (): void => {
                  this.visualRouteMenuShown = true
                },
              })
            }
            .bindMenu(this.visualRouteMenuShown, this.VisualRouteMenu, appMenuOptions({
              placement: Placement.BottomRight,
              onDisappear: (): void => {
                this.visualRouteMenuShown = false
              },
            }))
          }
        }
        if (this.visualRoute === COMIC_VISUAL_ROUTE_LOCAL) {
          ListItem() {
            NextNGroupedListSection() {
              NextNListRow({
                leadingIcon: $r('sys.symbol.character_viewfinder'),
                title: AppStrings.get('settings_translation_local_model'),
                trailingText: this.localModelChanging
                  ? AppStrings.get('settings_translation_local_model_downloading')
                  : this.localModelInstalled
                    ? ComicTranslationModelService.displayName()
                    : AppStrings.get('settings_translation_local_model_not_installed'),
                showChevron: false,
                isEnabled: !this.localModelChanging,
                destructive: this.localModelInstalled,
                accessibilityLabel: this.localModelInstalled
                  ? AppStrings.get('settings_translation_local_model_remove_a11y')
                  : AppStrings.get('settings_translation_local_model_download_a11y'),
                onAction: (): void => {
                  if (this.localModelInstalled) {
                    this.confirmRemoveLocalModel()
                  } else {
                    this.confirmInstallLocalModel()
                  }
                },
              })
              Text(AppStrings.get('settings_translation_local_model_notice'))
                .width('100%')
                .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                .fontColor(ThemeTokens.TEXT_SECONDARY)
                .padding({
                  left: ThemeTokens.SPACE_MD,
                  right: ThemeTokens.SPACE_MD,
                  bottom: ThemeTokens.SPACE_SM,
                })
            }
          }
        }
        if (this.visualRoute === COMIC_VISUAL_ROUTE_SELF_HOSTED &&
          this.onOpenMangaRenderingService) {
          ListItem() {
            NextNGroupedListSection() {
              NextNListRow({
                leadingIcon: $r('sys.symbol.cloud'),
                title: AppStrings.get('settings_manga_rendering_service'),
                subtitle: AppStrings.get('settings_manga_rendering_service_hint'),
                trailingText: this.mangaRenderingServiceEnabled
                  ? AppStrings.get('settings_manga_rendering_service_enabled')
                  : AppStrings.get('settings_manga_rendering_service_not_configured'),
                accessibilityLabel: AppStrings.get('settings_manga_rendering_service_a11y'),
                onAction: (): void => {
                  if (this.onOpenMangaRenderingService) {
                    this.onOpenMangaRenderingService()
                  }
                },
              })
            }
          }
        }
        if (this.visualRoute === COMIC_VISUAL_ROUTE_LOCAL ||
          this.visualRoute === COMIC_VISUAL_ROUTE_SELF_HOSTED) {
          ListItem() {
            NextNGroupedListSection() {
              Column() {
                NextNListRow({
                  leadingIcon: $r('sys.symbol.externaldrive'),
                  title: AppStrings.get('llm_binding_source'),
                  subtitle: this.compatibleSources().length === 0
                    ? AppStrings.get('llm_binding_no_compatible_source')
                    : AppStrings.get('llm_binding_source_hint'),
                  trailingText: this.selectedSourceText(),
                  trailingDropdown: this.compatibleSources().length > 0,
                  showChevron: this.compatibleSources().length === 0,
                  accessibilityLabel: AppStrings.get('comic_translation_source_a11y'),
                  onAction: (): void => {
                    this.openSourceSelector()
                  },
                })
              }
              .bindMenu(this.sourceMenuShown, this.SourceMenu, appMenuOptions({
                placement: Placement.BottomRight,
                onDisappear: (): void => {
                  this.sourceMenuShown = false
                },
              }))
              this.RowDivider()
              Column() {
                NextNListRow({
                  leadingIcon: $r('sys.symbol.arrow_down_circle'),
                  title: AppStrings.get('llm_binding_model'),
                  subtitle: this.fetchingModels
                    ? AppStrings.get('comment_translation_fetch_models_loading')
                    : AppStrings.get('llm_binding_model_hint'),
                  trailingText: this.selectedModelText(),
                  trailingDropdown: true,
                  isEnabled: this.selectedSourceId.length > 0 && !this.fetchingModels,
                  accessibilityLabel: AppStrings.get('comic_translation_model_a11y'),
                  onAction: (): void => {
                    this.fetchModels()
                  },
                })
              }
              .bindMenu(this.modelMenuShown, this.ModelMenu, appMenuOptions({
                placement: Placement.BottomRight,
                onDisappear: (): void => {
                  this.modelMenuShown = false
                },
              }))
              this.RowDivider()
              NextNListRow({
                leadingIcon: $r('sys.symbol.picture'),
                title: AppStrings.get('comic_translation_multimodal_assist'),
                hasSwitch: true,
                checked: this.multimodalTranslationEnabled,
                showChevron: false,
                onSwitchChange: (value: boolean): void => {
                  this.multimodalTranslationEnabled = value
                  this.persistVisualSettings(true)
                },
              })
              Text(AppStrings.get('comic_translation_multimodal_assist_notice'))
                .width('100%')
                .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                .fontColor(ThemeTokens.TEXT_SECONDARY)
                .padding({
                  left: ThemeTokens.SPACE_MD,
                  right: ThemeTokens.SPACE_MD,
                  bottom: ThemeTokens.SPACE_SM,
                })
            }
          }
        }
        if (this.visualRoute === COMIC_VISUAL_ROUTE_TORII) {
          ListItem() {
            NextNGroupedListSection() {
              Column() {
                NextNListRow({
                  leadingIcon: $r('sys.symbol.translate'),
                  title: AppStrings.get('comic_torii_model'),
                  trailingText: this.toriiModelText(),
                  trailingDropdown: true,
                  accessibilityLabel: AppStrings.get('comic_torii_model'),
                  onAction: (): void => {
                    this.toriiModelMenuShown = true
                  },
                })
              }
              .bindMenu(this.toriiModelMenuShown, this.ToriiModelMenu, appMenuOptions({
                placement: Placement.BottomRight,
                onDisappear: (): void => {
                  this.toriiModelMenuShown = false
                },
              }))
              this.RowDivider()
              Column() {
                NextNListRow({
                  leadingIcon: $r('sys.symbol.textformat'),
                  title: AppStrings.get('comic_torii_font'),
                  trailingText: this.toriiFontText(),
                  trailingDropdown: true,
                  accessibilityLabel: AppStrings.get('comic_torii_font'),
                  onAction: (): void => {
                    this.toriiFontMenuShown = true
                  },
                })
              }
              .bindMenu(this.toriiFontMenuShown, this.ToriiFontMenu, appMenuOptions({
                placement: Placement.BottomRight,
                onDisappear: (): void => {
                  this.toriiFontMenuShown = false
                },
              }))
              this.RowDivider()
              this.ToriiSecretRow(
                AppStrings.get('comic_torii_api_key'),
                AppStrings.get('comic_torii_api_key_hint'),
              )
              if (this.toriiReady() || this.toriiCredits !== null) {
                this.RowDivider()
                NextNListRow({
                  leadingIcon: $r('sys.symbol.creditcard'),
                  title: AppStrings.get('comic_torii_available_credits'),
                  trailingText: this.toriiCreditsText(),
                  showChevron: false,
                })
              }
              if (this.toriiReady()) {
                this.RowDivider()
                NextNListRow({
                  leadingIcon: $r('sys.symbol.checkmark_circle'),
                  title: AppStrings.get('comic_translation_live_evaluation_title'),
                  trailingText: this.toriiLiveEvaluationTrailingText(),
                  showChevron: this.toriiLiveEvaluationReport !== null &&
                    this.toriiLiveEvaluationReport.passed(),
                  isEnabled: !this.toriiLiveEvaluationRunning,
                  onAction: (): void => {
                    this.openToriiLiveEvaluation()
                  },
                })
              }
            }
          }
          ListItem() {
            Text(AppStrings.get('comic_torii_notice_managed'))
              .width('100%')
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
              .padding({
                left: ThemeTokens.SPACE_MD,
                right: ThemeTokens.SPACE_MD,
              })
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE_SUB)
  }
}
