import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import {
  AppStrings,
  COMMENT_TRANSLATION_DISPLAY_BILINGUAL,
  COMMENT_TRANSLATION_DISPLAY_REPLACE,
  ComicTranslationDiagnosticLogger,
  ComicTranslationModelCatalogService,
  CommentTranslationService,
  CommentTranslationSettings,
  CommentTranslationSettingsState,
  LLM_CONSUMER_COMMENT_TRANSLATION,
  LlmConsumerBinding,
  LlmSourceProfile,
  LlmSourceProfileRepository,
  LlmSourceProfilesState,
  NextNGroupedListSection,
  NextNListRow,
  SecondaryListScaffold,
  ThemeTokens,
  connectCommentTranslationSettings,
  connectLlmSourceProfiles,
  supportsCommentTranslation,
} from 'shared'

/**
 * Dedicated comment-translation destination, matching NextE's
 * CommentTranslationSettingsPage: enable, auto-translate, display mode, the
 * comment consumer binding with an inline source/model selector, and the
 * translation cache.
 */
@ComponentV2
export struct CommentTranslationSettingsPage {
  @Local settings: CommentTranslationSettingsState = connectCommentTranslationSettings()
  @Local sources: LlmSourceProfilesState = connectLlmSourceProfiles()
  @Local fetchingModels: boolean = false
  @Local modelOptions: string[] = []
  @Local selectedSourceId: string = ''
  @Local selectedModelId: string = ''
  @Local cacheCount: number = 0
  @Local clearingCache: boolean = false
  @Param scroller: Scroller = new Scroller()
  @Event onOpenTranslationSource?: (consumerId: string) => void

  aboutToAppear(): void {
    this.restoreBinding()
    this.refreshCacheCount()
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private toggleStateLabel(enabled: boolean): string {
    return AppStrings.get(enabled ? 'settings_toggle_on' : 'settings_toggle_off')
  }

  private setEnabled(value: boolean): void {
    CommentTranslationSettings.setEnabled(this.context(), value).catch((): void => {})
  }

  private setAutoTranslate(value: boolean): void {
    CommentTranslationSettings.setAutoTranslate(this.context(), value).catch((): void => {})
  }

  private setDisplayMode(value: string): void {
    CommentTranslationSettings.setDisplayMode(this.context(), value).catch((): void => {})
  }

  private displayModeText(): string {
    return this.settings.displayMode === COMMENT_TRANSLATION_DISPLAY_BILINGUAL
      ? AppStrings.get('comment_translation_display_bilingual')
      : AppStrings.get('comment_translation_display_replace')
  }

  private compatibleSources(): LlmSourceProfile[] {
    const profiles: LlmSourceProfile[] = []
    for (let index: number = 0; index < this.sources.profiles.length; index++) {
      const profile: LlmSourceProfile = this.sources.profiles[index]
      if (supportsCommentTranslation(profile)) {
        profiles.push(profile)
      }
    }
    return profiles
  }

  private restoreBinding(): void {
    const binding: LlmConsumerBinding = this.sources.commentBinding
    const profile: LlmSourceProfile | null = this.sources.findById(binding.sourceProfileId)
    if (profile === null || !supportsCommentTranslation(profile) || !binding.configured()) {
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
        this.onOpenTranslationSource(LLM_CONSUMER_COMMENT_TRANSLATION)
      }
      return
    }
  }

  private selectSource(sourceProfileId: string): void {
    if (sourceProfileId === this.selectedSourceId) {
      return
    }
    this.selectedSourceId = sourceProfileId
    this.selectedModelId = ''
    this.modelOptions = []
    this.fetchModels()
  }

  private fetchModels(openMenu?: () => void): void {
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
        if (openMenu) {
          openMenu()
        }
      })
      .catch((error: Error): void => {
        ComicTranslationDiagnosticLogger.warn(
          'comment-translation',
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
    binding.consumerId = LLM_CONSUMER_COMMENT_TRANSLATION
    binding.sourceProfileId = this.selectedSourceId
    binding.modelId = modelId
    LlmSourceProfileRepository.saveBinding(this.context(), binding)
      .then((): void => {
        this.selectedModelId = modelId
      })
      .catch((error: Error): void => {
        this.getUIContext().getPromptAction().showToast({
          message: AppStrings.get('llm_binding_save_failed'),
        })
      })
  }

  private async refreshCacheCount(): Promise<void> {
    try {
      this.cacheCount = (await CommentTranslationService.stat(this.context())).count
    } catch (_error) {
      this.cacheCount = 0
    }
  }

  private confirmClearCache(): void {
    if (this.clearingCache) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('comment_translation_clear_cache'),
      message: AppStrings.get('comment_translation_clear_cache_confirm'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('common_delete'),
        action: (): void => {
          this.clearCache()
        },
      },
    })
  }

  private async clearCache(): Promise<void> {
    if (this.clearingCache) {
      return
    }
    this.clearingCache = true
    try {
      await CommentTranslationService.clear(this.context())
      this.cacheCount = 0
      this.getUIContext().getPromptAction().showToast({
        message: AppStrings.get('comment_translation_cache_cleared'),
      })
    } catch (_error) {
      this.getUIContext().getPromptAction().showToast({
        message: AppStrings.get('comment_translation_clear_cache_failed'),
      })
    } finally {
      this.clearingCache = false
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
  private DisplayModeMenu() {
    Menu() {
      MenuItem({
        content: AppStrings.get('comment_translation_display_replace'),
        symbolEndIcon: this.settings.displayMode === COMMENT_TRANSLATION_DISPLAY_REPLACE
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setDisplayMode(COMMENT_TRANSLATION_DISPLAY_REPLACE)
      })
      MenuItem({
        content: AppStrings.get('comment_translation_display_bilingual'),
        symbolEndIcon: this.settings.displayMode === COMMENT_TRANSLATION_DISPLAY_BILINGUAL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setDisplayMode(COMMENT_TRANSLATION_DISPLAY_BILINGUAL)
      })
    }
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
            NextNListRow({
              leadingIcon: $r('sys.symbol.translate'),
              title: AppStrings.get('comment_translation_enable'),
              subtitle: AppStrings.get('comment_translation_enable_hint'),
              hasSwitch: true,
              checked: this.settings.enabled,
              showChevron: false,
              accessibilityLabel: AppStrings.format('settings_row_a11y', [
                AppStrings.get('comment_translation_enable'),
                this.toggleStateLabel(this.settings.enabled),
              ]),
              onAction: (): void => {
                this.setEnabled(!this.settings.enabled)
              },
              onSwitchChange: (value: boolean): void => {
                this.setEnabled(value)
              },
            })
            this.RowDivider()
            NextNListRow({
              leadingIcon: $r('sys.symbol.clock'),
              title: AppStrings.get('comment_translation_auto'),
              subtitle: AppStrings.get('comment_translation_auto_hint'),
              hasSwitch: true,
              checked: this.settings.autoTranslate,
              showChevron: false,
              isEnabled: this.settings.enabled,
              accessibilityLabel: AppStrings.format('settings_row_a11y', [
                AppStrings.get('comment_translation_auto'),
                this.toggleStateLabel(this.settings.autoTranslate),
              ]),
              onAction: (): void => {
                this.setAutoTranslate(!this.settings.autoTranslate)
              },
              onSwitchChange: (value: boolean): void => {
                this.setAutoTranslate(value)
              },
            })
            this.RowDivider()
            NextNListRow({
              leadingIcon: $r('sys.symbol.textformat'),
              title: AppStrings.get('comment_translation_display_mode'),
              trailingText: this.displayModeText(),
              trailingDropdown: true,
              dropdownMenuEnabled: true,
              dropdownMenuBuilder: () => {
                this.DisplayModeMenu()
              },
              isEnabled: this.settings.enabled,
              accessibilityLabel: AppStrings.format('settings_row_a11y', [
                AppStrings.get('comment_translation_display_mode'),
                this.displayModeText(),
              ]),
            })
          }
        }
        ListItem() {
          NextNGroupedListSection() {
            NextNListRow({
              leadingIcon: $r('sys.symbol.externaldrive'),
              title: AppStrings.get('llm_binding_source'),
              subtitle: this.compatibleSources().length === 0
                ? AppStrings.get('llm_binding_no_compatible_source')
                : AppStrings.get('llm_binding_source_hint'),
              trailingText: this.selectedSourceText(),
              trailingDropdown: this.compatibleSources().length > 0,
              showChevron: this.compatibleSources().length === 0,
              dropdownMenuEnabled: this.compatibleSources().length > 0,
              dropdownMenuBuilder: () => {
                this.SourceMenu()
              },
              isEnabled: this.settings.enabled,
              accessibilityLabel: AppStrings.get('comment_translation_source_a11y'),
              onAction: (): void => {
                if (this.settings.enabled) {
                  this.openSourceSelector()
                }
              },
            })
            this.RowDivider()
            NextNListRow({
              leadingIcon: $r('sys.symbol.arrow_down_circle'),
              title: AppStrings.get('llm_binding_model'),
              subtitle: this.fetchingModels
                ? AppStrings.get('comment_translation_fetch_models_loading')
                : AppStrings.get('llm_binding_model_hint'),
              trailingText: this.selectedModelText(),
              trailingDropdown: true,
              dropdownMenuEnabled: true,
              dropdownMenuBuilder: () => {
                this.ModelMenu()
              },
              dropdownMenuDeferredOpen: true,
              dropdownMenuOpenAction: (openMenu: () => void): void => {
                this.fetchModels(openMenu)
              },
              isEnabled: this.settings.enabled &&
                this.selectedSourceId.length > 0 && !this.fetchingModels,
              accessibilityLabel: AppStrings.get('comment_translation_model_a11y'),
            })
          }
        }
        ListItem() {
          NextNGroupedListSection() {
            NextNListRow({
              leadingIcon: $r('sys.symbol.trash'),
              title: AppStrings.get('comment_translation_clear_cache'),
              subtitle: AppStrings.format('comment_translation_cache_entries', [this.cacheCount.toString()]),
              destructive: true,
              showChevron: false,
              isEnabled: !this.clearingCache,
              onAction: (): void => {
                this.confirmClearCache()
              },
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
