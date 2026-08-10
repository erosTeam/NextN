import { common } from '@kit.AbilityKit'
import {
  AppStrings,
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
 * Configures the one source currently supported by NextN's Reader comic
 * translation runtime. Metadata and consumer binding stay in the existing
 * profile repository; only the typed key is handed to the existing HUKS vault.
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
  @Param scroller: Scroller = new Scroller()
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

  private currentBoundProfile(): LlmSourceProfile | null {
    const binding: LlmConsumerBinding = this.sources.mangaBinding
    if (!binding.configured()) {
      return null
    }
    return this.sources.findById(binding.sourceProfileId)
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
      ? AppStrings.get('settings_reader_comic_translation_source_default_name')
      : existing.displayName
    this.baseUrlDraft = existing === null ? 'https://api.openai.com' : existing.baseUrl
    this.modelIdDraft = existing === null ? '' : this.sources.mangaBinding.modelId
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

  private canSave(): boolean {
    return this.displayNameDraft.trim().length > 0 &&
      this.normalizedBaseUrl().length > 0 &&
      this.modelIdDraft.trim().length > 0 &&
      (this.apiKeyStored || this.apiKeyDraft.trim().length > 0)
  }

  private profileCandidate(): LlmSourceProfile {
    const profile: LlmSourceProfile = new LlmSourceProfile()
    profile.sourceProfileId = this.sourceProfileId
    profile.displayName = this.displayNameDraft.trim()
    profile.sourceType = LLM_SOURCE_TYPE_OPENAI_COMPATIBLE
    profile.baseUrl = this.normalizedBaseUrl()
    profile.capabilities.responses = true
    profile.capabilities.imageInput = true
    return profile
  }

  private async saveSource(): Promise<void> {
    if (this.saving) {
      return
    }
    if (!this.canSave()) {
      this.errorMessage = AppStrings.get('settings_reader_comic_translation_source_required')
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
      const binding: LlmConsumerBinding = new LlmConsumerBinding()
      binding.consumerId = LLM_CONSUMER_MANGA_TRANSLATION
      binding.sourceProfileId = profile.sourceProfileId
      binding.modelId = this.modelIdDraft.trim()
      await LlmSourceProfileRepository.saveBinding(this.context(), binding)
      this.apiKeyDraft = ''
      this.apiKeyStored = true
    } catch (_error) {
      this.errorMessage = AppStrings.get('settings_reader_comic_translation_source_save_failed')
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
            ? AppStrings.get('settings_reader_comic_translation_source_api_key_saved')
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
        title: AppStrings.get('settings_reader_comic_translation_source_type'),
        trailingText: AppStrings.get('settings_reader_comic_translation_source_type_openai'),
        showChevron: false,
      })
      this.RowDivider()
      this.TextInputRow(AppStrings.get('settings_reader_comic_translation_source_name'), 'name')
      this.RowDivider()
      this.TextInputRow(AppStrings.get('settings_reader_comic_translation_source_base_url'), 'baseUrl')
      this.RowDivider()
      this.TextInputRow(AppStrings.get('settings_reader_comic_translation_source_api_key'), 'apiKey')
      this.RowDivider()
      this.TextInputRow(AppStrings.get('settings_reader_comic_translation_source_model'), 'model')
    }
  }

  @Builder
  private SaveGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.checkmark_circle'),
        title: AppStrings.get('settings_reader_comic_translation_source_save'),
        subtitle: AppStrings.get('settings_reader_comic_translation_source_save_hint'),
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
