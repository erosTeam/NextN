import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  ComicTranslationModelService,
  LLM_CONSUMER_MANGA_TRANSLATION,
  LlmSourceProfile,
  LlmSourceProfilesState,
  MangaRenderingServiceSettings,
  NextNGroupedListSection,
  NextNListRow,
  SecondaryListScaffold,
  ThemeTokens,
  connectLlmSourceProfiles,
  supportsMangaTranslation,
} from 'shared'

/**
 * Dedicated comic-translation destination, matching NextE's
 * ComicTranslationSettingsPage. NextN supports the local detector, the
 * self-hosted rendering service, and the manga consumer binding; torii and
 * live evaluation are unsupported leaves and stay absent.
 */
@ComponentV2
export struct ComicTranslationSettingsPage {
  @Local sources: LlmSourceProfilesState = connectLlmSourceProfiles()
  @Local localModelInstalled: boolean = false
  @Local localModelChanging: boolean = false
  @Local mangaRenderingServiceEnabled: boolean = false
  @Param scroller: Scroller = new Scroller()
  @Event onOpenTranslationSource?: (consumerId: string) => void
  @Event onEditTranslationModel?: (consumerId: string) => void
  @Event onOpenMangaRenderingService?: () => void

  aboutToAppear(): void {
    this.refreshLocalModel()
    this.refreshMangaRenderingService()
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private mangaSource(): LlmSourceProfile | null {
    const binding = this.sources.mangaBinding
    if (!binding.configured()) {
      return null
    }
    const profile: LlmSourceProfile | null = this.sources.findById(binding.sourceProfileId)
    return profile !== null && supportsMangaTranslation(profile) ? profile : null
  }

  private selectedSourceText(): string {
    const profile: LlmSourceProfile | null = this.mangaSource()
    return profile === null
      ? AppStrings.get('settings_translation_source_not_configured')
      : profile.displayName
  }

  private selectedModelText(): string {
    const binding = this.sources.mangaBinding
    return binding.configured() && binding.modelId.length > 0
      ? binding.modelId
      : AppStrings.get('settings_translation_source_not_configured')
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

  build() {
    Column() {
      SecondaryListScaffold({
        scroller: this.scroller,
        bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
        alwaysEnableEdgeSpring: true,
      }) {
        ListItem() {
          NextNGroupedListSection() {
            NextNListRow({
              leadingIcon: $r('sys.symbol.cloud'),
              title: AppStrings.get('llm_binding_source'),
              trailingText: this.selectedSourceText(),
              accessibilityLabel: AppStrings.get('comic_translation_source_a11y'),
              onAction: (): void => {
                if (this.onOpenTranslationSource) {
                  this.onOpenTranslationSource(LLM_CONSUMER_MANGA_TRANSLATION)
                }
              },
            })
            this.RowDivider()
            NextNListRow({
              leadingIcon: $r('sys.symbol.arrow_down_circle'),
              title: AppStrings.get('llm_binding_model'),
              trailingText: this.selectedModelText(),
              accessibilityLabel: AppStrings.get('comic_translation_model_a11y'),
              onAction: (): void => {
                if (this.onEditTranslationModel) {
                  this.onEditTranslationModel(LLM_CONSUMER_MANGA_TRANSLATION)
                }
              },
            })
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
