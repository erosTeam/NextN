import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import {
  AppStrings,
  ComicTranslationDiagnosticLogger,
  ComicTranslationModelCatalogService,
  ComicTranslationModelService,
  LLM_CONSUMER_MANGA_TRANSLATION,
  LlmConsumerBinding,
  LlmSourceProfile,
  LlmSourceProfileRepository,
  LlmSourceProfilesState,
  MangaRenderingServiceSettings,
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
 * ComicTranslationSettingsPage. NextN supports the manga consumer binding
 * with an inline source/model selector, the local detector, and the
 * self-hosted rendering service; torii and live evaluation are unsupported
 * leaves and stay absent.
 */
@ComponentV2
export struct ComicTranslationSettingsPage {
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

  aboutToAppear(): void {
    this.restoreBinding()
    this.refreshLocalModel()
    this.refreshMangaRenderingService()
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
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
          message: AppStrings.format('comment_translation_models_failed', [error.message]),
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
          message: AppStrings.format('llm_binding_save_failed', [error.message]),
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
          }
        }
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
        if (this.onOpenMangaRenderingService) {
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
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE_SUB)
  }
}
