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
 * NextE's LlmSourceDetailPage adapted to NextN. The source fields, capability
 * switches, and delete flow follow the reference; a model field is retained
 * as a NextN leaf because there is no model-catalog service to populate the
 * reference's model menu.
 */
@ComponentV2
export struct LlmSourceDetailPage {
  @Local sources: LlmSourceProfilesState = connectLlmSourceProfiles()
  @Local loading: boolean = true
  @Local saving: boolean = false
  @Local deleting: boolean = false
  @Local sourceProfileId: string = ''
  @Local isNewSource: boolean = true
  @Local displayNameDraft: string = ''
  @Local baseUrlDraft: string = ''
  @Local modelIdDraft: string = ''
  @Local apiKeyStored: boolean = false
  @Local errorMessage: string = ''
  @Local useMangaTranslation: boolean = false
  @Local useCommentTranslation: boolean = false
  @Param scroller: Scroller = new Scroller()
  @Param requestedSourceProfileId: string = ''
  @Param requestedConsumer: string = LLM_CONSUMER_MANGA_TRANSLATION
  @Event onDeleted?: () => void
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

  private binding(consumerId: string): LlmConsumerBinding {
    return consumerId === LLM_CONSUMER_COMMENT_TRANSLATION
      ? this.sources.commentBinding
      : this.sources.mangaBinding
  }

  private bindingModelId(consumerId: string): string {
    return this.binding(consumerId).modelId
  }

  private isBoundTo(consumerId: string, sourceProfileId: string): boolean {
    const current: LlmConsumerBinding = this.binding(consumerId)
    return current.configured() && current.sourceProfileId === sourceProfileId
  }

  private async loadSource(): Promise<void> {
    this.loading = true
    this.errorMessage = ''
    this.apiKeyDraft = ''
    this.sourceProfileId = this.requestedSourceProfileId
    this.isNewSource = this.sourceProfileId.length === 0
    if (this.isNewSource) {
      this.sourceProfileId = generateLlmSourceProfileId()
      this.displayNameDraft = AppStrings.get('settings_translation_source_default_name')
      this.baseUrlDraft = 'https://api.openai.com'
      this.useMangaTranslation = this.requestedConsumer === LLM_CONSUMER_MANGA_TRANSLATION
      this.useCommentTranslation = this.requestedConsumer === LLM_CONSUMER_COMMENT_TRANSLATION
      this.modelIdDraft = this.bindingModelId(this.requestedConsumer)
      this.apiKeyStored = false
      this.loading = false
      return
    }
    const existing: LlmSourceProfile | null = this.sources.findById(this.sourceProfileId)
    if (existing === null) {
      this.loading = false
      this.getUIContext().getPromptAction().showToast({
        message: AppStrings.get('llm_source_missing'),
      })
      if (this.onDeleted) {
        this.onDeleted()
      }
      return
    }
    this.displayNameDraft = existing.displayName
    this.baseUrlDraft = existing.baseUrl
    this.useMangaTranslation = this.isBoundTo(LLM_CONSUMER_MANGA_TRANSLATION, existing.sourceProfileId)
    this.useCommentTranslation = this.isBoundTo(
      LLM_CONSUMER_COMMENT_TRANSLATION,
      existing.sourceProfileId,
    )
    if (this.useMangaTranslation) {
      this.modelIdDraft = this.sources.mangaBinding.modelId
    } else if (this.useCommentTranslation) {
      this.modelIdDraft = this.sources.commentBinding.modelId
    } else {
      this.modelIdDraft = ''
    }
    this.apiKeyStored = await this.hasMatchingStoredApiKey(existing)
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
      (this.useMangaTranslation || this.useCommentTranslation)
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

  /**
   * Only the consumer binding owned by this source is rewritten. A binding
   * that currently points elsewhere stays untouched, so editing one source
   * never clobbers another source's assignment.
   */
  private nextBinding(consumerId: string, enabled: boolean): LlmConsumerBinding {
    const current: LlmConsumerBinding = this.binding(consumerId)
    if (enabled) {
      const binding: LlmConsumerBinding = new LlmConsumerBinding()
      binding.consumerId = consumerId
      binding.sourceProfileId = this.sourceProfileId
      binding.modelId = this.modelIdDraft.trim()
      return binding
    }
    if (current.sourceProfileId === this.sourceProfileId) {
      const binding: LlmConsumerBinding = new LlmConsumerBinding()
      binding.consumerId = consumerId
      return binding
    }
    return current.copy()
  }

  private async saveSource(): Promise<void> {
    if (this.saving) {
      return
    }
    if (!this.canSave()) {
      this.errorMessage = AppStrings.get('settings_translation_source_required')
      return
    }
    this.saving = true
    this.errorMessage = ''
    try {
      const profile: LlmSourceProfile = this.profileCandidate()
      const apiKey: string = this.apiKeyDraft.trim()
      if (apiKey.length > 0) {
        profile.accountIdentityHash = LlmSourceSecretVault.apiKeyIdentityHash(apiKey)
      }
      await LlmSourceProfileRepository.upsert(this.context(), profile)
      await LlmSourceProfileRepository.saveBinding(
        this.context(),
        this.nextBinding(LLM_CONSUMER_MANGA_TRANSLATION, this.useMangaTranslation),
      )
      await LlmSourceProfileRepository.saveBinding(
        this.context(),
        this.nextBinding(LLM_CONSUMER_COMMENT_TRANSLATION, this.useCommentTranslation),
      )
      if (apiKey.length > 0) {
        await LlmSourceSecretVault.saveApiKey(this.context(), this.sourceProfileId, apiKey)
      }
      this.apiKeyDraft = ''
      this.apiKeyStored = true
      this.isNewSource = false
    } catch (_error) {
      this.errorMessage = AppStrings.get('settings_translation_source_save_failed')
    } finally {
      this.saving = false
    }
  }

  private referencedConsumerNames(): string {
    const names: string[] = []
    if (this.isBoundTo(LLM_CONSUMER_COMMENT_TRANSLATION, this.sourceProfileId)) {
      names.push(AppStrings.get('settings_comment_translation'))
    }
    if (this.isBoundTo(LLM_CONSUMER_MANGA_TRANSLATION, this.sourceProfileId)) {
      names.push(AppStrings.get('settings_reader_comic_translation'))
    }
    return names.join('、')
  }

  private confirmDelete(): void {
    if (this.deleting) {
      return
    }
    const message: string = this.referencedConsumerNames().length > 0
      ? AppStrings.format('llm_source_delete_referenced', [this.referencedConsumerNames()])
      : AppStrings.get('llm_source_delete_confirm')
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('llm_source_delete'),
      message: message,
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('common_delete'),
        action: (): void => {
          this.deleteSource()
        },
      },
    })
  }

  private deleteSource(): void {
    this.deleting = true
    LlmSourceProfileRepository.remove(this.context(), this.sourceProfileId)
      .then((): void => {
        if (this.onDeleted) {
          this.onDeleted()
        }
      })
      .catch((error: Error): void => {
        this.deleting = false
        this.getUIContext().getPromptAction().showToast({
          message: AppStrings.format('llm_source_delete_failed', [error.message]),
        })
      })
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
        title: AppStrings.get('llm_source_type'),
        trailingText: AppStrings.get('settings_translation_source_type_openai'),
        showChevron: false,
      })
      this.RowDivider()
      this.TextInputRow(AppStrings.get('llm_source_name'), 'name')
      this.RowDivider()
      this.TextInputRow(AppStrings.get('llm_source_base_url'), 'baseUrl')
      this.RowDivider()
      this.TextInputRow(AppStrings.get('llm_source_api_key'), 'apiKey')
      this.RowDivider()
      this.TextInputRow(AppStrings.get('settings_translation_source_model'), 'model')
    }
  }

  @Builder
  private ConsumerGroup() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      NextNGroupedListSection() {
        NextNListRow({
          leadingIcon: $r('sys.symbol.translate'),
          title: AppStrings.get('llm_source_support_comments'),
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
        this.RowDivider()
        NextNListRow({
          leadingIcon: $r('sys.symbol.picture'),
          title: AppStrings.get('llm_source_support_manga'),
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
      }
      Text(AppStrings.get('llm_source_support_manga_hint'))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_TERTIARY)
        .width('100%')
        .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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

  @Builder
  private DeleteGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.trash'),
        title: AppStrings.get('llm_source_delete'),
        subtitle: AppStrings.get('llm_source_delete_hint'),
        destructive: true,
        showChevron: false,
        isEnabled: !this.deleting,
        onAction: (): void => {
          this.confirmDelete()
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
          if (!this.isNewSource) {
            ListItem() {
              this.DeleteGroup()
            }
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
