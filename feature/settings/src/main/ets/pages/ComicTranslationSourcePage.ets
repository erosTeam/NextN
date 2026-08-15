import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  LLM_CONSUMER_COMMENT_TRANSLATION,
  LLM_CONSUMER_MANGA_TRANSLATION,
  LLM_SOURCE_TYPE_OPENAI_COMPATIBLE,
  LlmConsumerBinding,
  LlmSourceProfile,
  LlmSourceProfileRepository,
  LlmSourceProfilesState,
  LlmSourceSecretVault,
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
  @Param scroller: Scroller = new Scroller()
  @Param requestedConsumer: string = LLM_CONSUMER_MANGA_TRANSLATION
  // The key is deliberately not published to AppStorage or any shared state.
  // It exists only while this mounted input is edited and is written directly
  // to the HUKS-backed vault during save.
  private apiKeyDraft: string = ''

  aboutToAppear(): void {
    this.loadSource()
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
      this.apiKeyStored = await this.hasMatchingStoredApiKey(existing)
    } else {
      this.apiKeyStored = false
    }
    this.loading = false
  }

  private normalizedBaseUrl(): string {
    return this.baseUrlDraft.trim().replace(/\/+$/, '')
  }

  private async hasMatchingStoredApiKey(profile: LlmSourceProfile): Promise<boolean> {
    try {
      const apiKey: string = await LlmSourceSecretVault.readApiKey(
        this.context(),
        profile.sourceProfileId,
      )
      return apiKey.length > 0 &&
        LlmSourceSecretVault.apiKeyMatchesIdentity(apiKey, profile.accountIdentityHash)
    } catch (_error) {
      return false
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
      await LlmSourceProfileRepository.saveConfiguredOpenAiSource(
        this.context(),
        profile,
        apiKey,
        this.binding(LLM_CONSUMER_MANGA_TRANSLATION, this.useMangaTranslation),
        this.binding(LLM_CONSUMER_COMMENT_TRANSLATION, this.useCommentTranslation),
      )
      this.apiKeyDraft = ''
      this.apiKeyStored = true
    } catch (_error) {
      const current: LlmSourceProfile | null = this.sources.findById(this.sourceProfileId)
      if (current === null) {
        this.apiKeyStored = false
      } else {
        this.apiKeyStored = await this.hasMatchingStoredApiKey(current)
      }
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
