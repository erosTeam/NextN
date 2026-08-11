import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  ComicTranslationModelService,
  LLM_CONSUMER_COMMENT_TRANSLATION,
  LLM_CONSUMER_MANGA_TRANSLATION,
  LLM_SOURCE_TYPE_OPENAI_COMPATIBLE,
  LlmConsumerBinding,
  LlmSourceProfile,
  LlmSourceProfileRepository,
  LlmSourceProfilesState,
  LlmSourceSecretVault,
  MangaRenderingServiceSettings,
  NextNGroupedListSection,
  NextNListRow,
  PageEmptyState,
  SecondaryListScaffold,
  ThemeTokens,
  connectLlmSourceProfiles,
  generateLlmSourceProfileId,
} from 'shared'

/**
 * Configures the one OpenAI-compatible source currently supported by NextN's
 * translation features. Metadata and each explicit consumer binding stay in
 * the existing profile repository; only the typed key is handed to HUKS.
 */
@ComponentV2
export struct ComicTranslationSourcePage {
  @Local sources: LlmSourceProfilesState = connectLlmSourceProfiles()
  @Local loading: boolean = true
  @Local saving: boolean = false
  @Local sourceProfileId: string = ''
  @Local displayNameDraft: string = ''
  @Local baseUrlDraft: string = ''
  @Local modelIdDraft: string = ''
  @Local apiKeyStored: boolean = false
  @Local errorMessage: string = ''
  @Local useMangaTranslation: boolean = false
  @Local useCommentTranslation: boolean = false
  @Local bindingsConflict: boolean = false
  @Local localModelInstalled: boolean = false
  @Local localModelChanging: boolean = false
  @Local mangaRenderingServiceEnabled: boolean = false
  @Param scroller: Scroller = new Scroller()
  @Param requestedConsumer: string = LLM_CONSUMER_MANGA_TRANSLATION
  @Event onOpenMangaRenderingService?: () => void
  // The key is deliberately not published to AppStorage or any shared state.
  // It exists only while this mounted input is edited and is written directly
  // to the HUKS-backed vault during save.
  private apiKeyDraft: string = ''

  aboutToAppear(): void {
    this.loadSource()
    this.refreshLocalModel()
    this.refreshMangaRenderingService()
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private profileForBinding(binding: LlmConsumerBinding): LlmSourceProfile | null {
    return binding.configured() ? this.sources.findById(binding.sourceProfileId) : null
  }

  private currentBoundProfile(): LlmSourceProfile | null {
    const manga: LlmSourceProfile | null = this.profileForBinding(this.sources.mangaBinding)
    const comment: LlmSourceProfile | null = this.profileForBinding(this.sources.commentBinding)
    this.bindingsConflict = manga !== null && comment !== null &&
      manga.sourceProfileId !== comment.sourceProfileId
    return manga === null ? comment : manga
  }

  private async loadSource(): Promise<void> {
    this.loading = true
    this.errorMessage = ''
    this.apiKeyDraft = ''
    const existing: LlmSourceProfile | null = this.currentBoundProfile()
    this.sourceProfileId = existing === null
      ? generateLlmSourceProfileId()
      : existing.sourceProfileId
    this.displayNameDraft = existing === null
      ? AppStrings.get('settings_translation_source_default_name')
      : existing.displayName
    this.baseUrlDraft = existing === null ? 'https://api.openai.com' : existing.baseUrl
    this.useMangaTranslation = existing !== null && this.sources.mangaBinding.configured() &&
      this.sources.mangaBinding.sourceProfileId === existing.sourceProfileId
    this.useCommentTranslation = existing !== null && this.sources.commentBinding.configured() &&
      this.sources.commentBinding.sourceProfileId === existing.sourceProfileId
    if (existing === null) {
      this.useMangaTranslation = this.requestedConsumer === LLM_CONSUMER_MANGA_TRANSLATION
      this.useCommentTranslation = this.requestedConsumer === LLM_CONSUMER_COMMENT_TRANSLATION
    }
    if (this.useMangaTranslation) {
      this.modelIdDraft = this.sources.mangaBinding.modelId
    } else if (this.useCommentTranslation) {
      this.modelIdDraft = this.sources.commentBinding.modelId
    } else {
      this.modelIdDraft = ''
    }
    if (existing !== null) {
      try {
        this.apiKeyStored = (await LlmSourceSecretVault.readApiKey(
          this.context(),
          existing.sourceProfileId,
        )).length > 0
      } catch (_error) {
        this.apiKeyStored = false
      }
    } else {
      this.apiKeyStored = false
    }
    this.loading = false
  }

  private normalizedBaseUrl(): string {
    return this.baseUrlDraft.trim().replace(/\/+$/, '')
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
      this.mangaRenderingServiceEnabled = (await MangaRenderingServiceSettings.load(this.context())).enabled
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
    this.errorMessage = ''
    try {
      await ComicTranslationModelService.install(this.context())
      this.localModelInstalled = true
    } catch (_error) {
      this.errorMessage = AppStrings.get('settings_translation_local_model_download_failed')
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
    this.errorMessage = ''
    try {
      ComicTranslationModelService.remove(this.context())
      this.localModelInstalled = false
    } catch (_error) {
      this.errorMessage = AppStrings.get('settings_translation_local_model_remove_failed')
    } finally {
      this.localModelChanging = false
    }
  }

  private canSave(): boolean {
    return this.displayNameDraft.trim().length > 0 &&
      this.normalizedBaseUrl().length > 0 &&
      this.modelIdDraft.trim().length > 0 &&
      (this.apiKeyStored || this.apiKeyDraft.trim().length > 0) &&
      (this.useMangaTranslation || this.useCommentTranslation) && !this.bindingsConflict
  }

  private profileCandidate(): LlmSourceProfile {
    const existing: LlmSourceProfile | null = this.sources.findById(this.sourceProfileId)
    const profile: LlmSourceProfile = existing === null ? new LlmSourceProfile() : existing.copy()
    profile.sourceProfileId = this.sourceProfileId
    profile.displayName = this.displayNameDraft.trim()
    profile.sourceType = LLM_SOURCE_TYPE_OPENAI_COMPATIBLE
    profile.baseUrl = this.normalizedBaseUrl()
    profile.capabilities.responses = this.useMangaTranslation
    profile.capabilities.imageInput = this.useMangaTranslation
    profile.capabilities.chatCompletions = this.useCommentTranslation
    return profile
  }

  private binding(consumerId: string, enabled: boolean): LlmConsumerBinding {
    const binding: LlmConsumerBinding = new LlmConsumerBinding()
    binding.consumerId = consumerId
    if (enabled) {
      binding.sourceProfileId = this.sourceProfileId
      binding.modelId = this.modelIdDraft.trim()
    }
    return binding
  }

  private async saveSource(): Promise<void> {
    if (this.saving) {
      return
    }
    if (!this.canSave()) {
      this.errorMessage = this.bindingsConflict
        ? AppStrings.get('settings_translation_source_binding_conflict')
        : AppStrings.get('settings_translation_source_required')
      return
    }
    this.saving = true
    this.errorMessage = ''
    try {
      const profile: LlmSourceProfile = this.profileCandidate()
      const apiKey: string = this.apiKeyDraft.trim()
      // Saving a replacement key first can at worst leave an unreachable HUKS
      // value if metadata persistence fails; it cannot publish a source whose
      // selected secret was never written.
      if (apiKey.length > 0) {
        await LlmSourceSecretVault.saveApiKey(this.context(), profile.sourceProfileId, apiKey)
      }
      await LlmSourceProfileRepository.upsert(this.context(), profile)
      await LlmSourceProfileRepository.saveBinding(
        this.context(),
        this.binding(LLM_CONSUMER_MANGA_TRANSLATION, this.useMangaTranslation),
      )
      await LlmSourceProfileRepository.saveBinding(
        this.context(),
        this.binding(LLM_CONSUMER_COMMENT_TRANSLATION, this.useCommentTranslation),
      )
      this.apiKeyDraft = ''
      this.apiKeyStored = true
    } catch (_error) {
      this.errorMessage = AppStrings.get('settings_translation_source_save_failed')
    } finally {
      this.saving = false
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
  private TextInputRow(label: string, field: string) {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Text(label)
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .width('100%')
      if (field === 'name') {
        TextInput({ text: this.displayNameDraft })
          .type(InputType.Normal)
          .width('100%')
          .height(48)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .backgroundColor(ThemeTokens.SURFACE_SUB)
          .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
          .onChange((value: string): void => {
            this.displayNameDraft = value
            this.errorMessage = ''
          })
      } else if (field === 'baseUrl') {
        TextInput({ text: this.baseUrlDraft, placeholder: 'https://api.openai.com' })
          .type(InputType.Normal)
          .width('100%')
          .height(48)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .backgroundColor(ThemeTokens.SURFACE_SUB)
          .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
          .onChange((value: string): void => {
            this.baseUrlDraft = value
            this.errorMessage = ''
          })
      } else if (field === 'apiKey') {
        TextInput({
          text: this.apiKeyDraft,
          placeholder: this.apiKeyStored
            ? AppStrings.get('settings_translation_source_api_key_saved')
            : '',
        })
          .type(InputType.Password)
          .width('100%')
          .height(48)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .backgroundColor(ThemeTokens.SURFACE_SUB)
          .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
          .onChange((value: string): void => {
            this.apiKeyDraft = value
            this.errorMessage = ''
          })
      } else {
        TextInput({ text: this.modelIdDraft, placeholder: 'gpt-4.1-mini' })
          .type(InputType.Normal)
          .width('100%')
          .height(48)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .backgroundColor(ThemeTokens.SURFACE_SUB)
          .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
          .onChange((value: string): void => {
            this.modelIdDraft = value
            this.errorMessage = ''
          })
      }
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
  private SourceFormGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.cloud'),
        title: AppStrings.get('settings_translation_source_type'),
        trailingText: AppStrings.get('settings_translation_source_type_openai'),
        showChevron: false,
      })
      this.RowDivider()
      this.TextInputRow(AppStrings.get('settings_translation_source_name'), 'name')
      this.RowDivider()
      this.TextInputRow(AppStrings.get('settings_translation_source_base_url'), 'baseUrl')
      this.RowDivider()
      this.TextInputRow(AppStrings.get('settings_translation_source_api_key'), 'apiKey')
      this.RowDivider()
      this.TextInputRow(AppStrings.get('settings_translation_source_model'), 'model')
    }
  }

  @Builder
  private ConsumerGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.picture'),
        title: AppStrings.get('settings_translation_source_reader'),
        subtitle: AppStrings.get('settings_translation_source_reader_hint'),
        hasSwitch: true,
        checked: this.useMangaTranslation,
        showChevron: false,
        onAction: (): void => {
          this.useMangaTranslation = !this.useMangaTranslation
          this.errorMessage = ''
        },
        onSwitchChange: (value: boolean): void => {
          this.useMangaTranslation = value
          this.errorMessage = ''
        },
      })
      this.RowDivider()
      NextNListRow({
        leadingIcon: $r('sys.symbol.translate'),
        title: AppStrings.get('settings_translation_source_comments'),
        subtitle: AppStrings.get('settings_translation_source_comments_hint'),
        hasSwitch: true,
        checked: this.useCommentTranslation,
        showChevron: false,
        onAction: (): void => {
          this.useCommentTranslation = !this.useCommentTranslation
          this.errorMessage = ''
        },
        onSwitchChange: (value: boolean): void => {
          this.useCommentTranslation = value
          this.errorMessage = ''
        },
      })
    }
  }

  @Builder
  private LocalModelGroup() {
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

  /** Follows NextE: self-hosted configuration belongs inside comic translation. */
  @Builder
  private MangaRenderingServiceGroup() {
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

  @Builder
  private SaveGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.checkmark_circle'),
        title: AppStrings.get('settings_translation_source_save'),
        subtitle: AppStrings.get('settings_translation_source_save_hint'),
        trailingText: this.saving ? AppStrings.get('common_loading') : '',
        showChevron: false,
        isEnabled: !this.saving,
        onAction: (): void => {
          this.saveSource()
        },
      })
    }
  }

  build() {
    Column() {
      if (this.loading) {
        PageEmptyState({ message: AppStrings.get('common_loading') })
      } else {
        SecondaryListScaffold({
          scroller: this.scroller,
          bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
          alwaysEnableEdgeSpring: true,
        }) {
          ListItem() {
            this.SourceFormGroup()
          }
          ListItem() {
            this.ConsumerGroup()
          }
          ListItem() {
            this.LocalModelGroup()
          }
          if (this.onOpenMangaRenderingService) {
            ListItem() {
              this.MangaRenderingServiceGroup()
            }
          }
          ListItem() {
            this.SaveGroup()
          }
          if (this.errorMessage.length > 0) {
            ListItem() {
              Text(this.errorMessage)
                .width('100%')
                .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                .fontColor(Color.Red)
                .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
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
