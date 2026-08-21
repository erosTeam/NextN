import { common } from '@kit.AbilityKit'
import { KeyboardAvoidMode } from '@kit.ArkUI'
import {
  AppStrings,
  ComicTranslationDiagnosticLogger,
  ComicTranslationModelCatalogService,
  LLM_CONSUMER_COMMENT_TRANSLATION,
  LLM_CONSUMER_MANGA_TRANSLATION,
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
  supportsMangaTranslation,
} from 'shared'

/**
 * NextE's LlmSourceDetailPage adapted to NextN. Drafts persist automatically
 * on disappear (no explicit save button), the model is selected on the
 * consumer pages from a catalog fetched through this source, and the delete
 * flow keeps referenced bindings unconfigured instead of silently rewiring
 * them. The Codex account/catalog branch is absent because NextN has no
 * Codex OAuth service.
 */
@ComponentV2
export struct LlmSourceDetailPage {
  @Local sources: LlmSourceProfilesState = connectLlmSourceProfiles()
  @Local loading: boolean = true
  @Local deleting: boolean = false
  @Local sourceProfileId: string = ''
  @Local displayNameDraft: string = ''
  @Local baseUrlDraft: string = ''
  @Local supportsComments: boolean = false
  @Local supportsManga: boolean = false
  @Local supportsCatalog: boolean = false
  @Local modelCatalogLoading: boolean = false
  @Local modelCatalogCount: number = 0
  @Local secretLoaded: boolean = false
  @Param scroller: Scroller = new Scroller()
  @Param requestedSourceProfileId: string = ''
  @Event onDeleted?: () => void
  // The key exists only while this mounted input is edited and is written
  // directly to the HUKS-backed vault during save.
  private apiKeyDraft: string = ''

  aboutToAppear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
    this.loadSource()
  }

  aboutToDisappear(): void {
    if (!this.deleting) {
      this.persistDrafts(false)
    }
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private profile(): LlmSourceProfile | null {
    return this.sources.findById(this.sourceProfileId)
  }

  private async loadSource(): Promise<void> {
    this.loading = true
    const existing: LlmSourceProfile | null = this.sources.findById(this.requestedSourceProfileId)
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
    this.sourceProfileId = this.requestedSourceProfileId
    this.displayNameDraft = existing.displayName
    this.baseUrlDraft = existing.baseUrl
    this.supportsComments = existing.capabilities.chatCompletions
    this.supportsManga = supportsMangaTranslation(existing)
    this.supportsCatalog = existing.capabilities.modelCatalog
    this.apiKeyDraft = await LlmSourceSecretVault.readApiKey(this.context(), existing.sourceProfileId)
    this.secretLoaded = true
    this.loading = false
  }

  private normalizedBaseUrl(): string {
    return this.baseUrlDraft.trim().replace(/\/+$/, '')
  }

  private apiKeyStateText(): string {
    return this.apiKeyDraft.trim().length > 0
      ? AppStrings.get('llm_source_api_key_saved')
      : AppStrings.get('llm_source_api_key_empty')
  }

  /**
   * Captures every draft synchronously so the write can finish even after
   * this component has disappeared.
   */
  private persistDrafts(showFailureToast: boolean): Promise<boolean> {
    const current: LlmSourceProfile | null = this.profile()
    if (!this.secretLoaded || current === null) {
      return Promise.resolve(false)
    }
    const candidate: LlmSourceProfile = current.copy()
    candidate.displayName = this.displayNameDraft.trim()
    candidate.baseUrl = this.normalizedBaseUrl()
    candidate.capabilities.chatCompletions = this.supportsComments
    candidate.capabilities.responses = this.supportsManga
    candidate.capabilities.imageInput = this.supportsManga
    candidate.capabilities.modelCatalog = this.supportsCatalog
    candidate.capabilities.usage = false
    const apiKey: string = this.apiKeyDraft.trim()
    const sourceProfileId: string = this.sourceProfileId
    const secretLoaded: boolean = this.secretLoaded
    const context: common.UIAbilityContext = this.context()
    if (apiKey.length > 0) {
      candidate.accountIdentityHash = LlmSourceSecretVault.apiKeyIdentityHash(apiKey)
    }
    return LlmSourceProfileRepository.upsert(context, candidate)
      .then(async (): Promise<void> => {
        if (secretLoaded && apiKey.length > 0) {
          await LlmSourceSecretVault.saveApiKey(context, sourceProfileId, apiKey)
        }
      })
      .then((): boolean => {
        return true
      })
      .catch((error: Error): boolean => {
        ComicTranslationDiagnosticLogger.warn(
          'llm-source',
          'profile_save_failed',
          error.message,
        )
        if (showFailureToast) {
          this.getUIContext().getPromptAction().showToast({
            message: AppStrings.get('llm_source_save_failed'),
          })
        }
        return false
      })
  }

  private catalogSubtitle(): string {
    if (this.modelCatalogLoading) {
      return AppStrings.get('comment_translation_fetch_models_loading')
    }
    if (this.modelCatalogCount > 0) {
      return AppStrings.format('llm_source_catalog_count', [this.modelCatalogCount.toString()])
    }
    return AppStrings.get('llm_source_catalog_hint')
  }

  private fetchModels(): void {
    if (this.modelCatalogLoading) {
      return
    }
    this.persistDrafts(true).then((saved: boolean): void => {
      if (!saved) {
        return
      }
      const sourceProfileId: string = this.sourceProfileId
      this.modelCatalogLoading = true
      ComicTranslationModelCatalogService.fetchSource(this.context(), sourceProfileId)
        .then((models: string[]): void => {
          this.modelCatalogCount = models.length
          this.getUIContext().getPromptAction().showToast({
            message: models.length > 0
              ? AppStrings.format('llm_source_catalog_count', [models.length.toString()])
              : AppStrings.get('comment_translation_models_empty'),
          })
        })
        .catch((error: Error): void => {
          ComicTranslationDiagnosticLogger.warn(
            'llm-source',
            'model_catalog_failed',
            error.message,
          )
          this.getUIContext().getPromptAction().showToast({
            message: AppStrings.get('comment_translation_models_failed'),
          })
        })
        .finally((): void => {
          this.modelCatalogLoading = false
        })
    })
  }

  private isBoundTo(consumerId: string, sourceProfileId: string): boolean {
    const binding: LlmConsumerBinding = consumerId === LLM_CONSUMER_COMMENT_TRANSLATION
      ? this.sources.commentBinding
      : this.sources.mangaBinding
    return binding.configured() && binding.sourceProfileId === sourceProfileId
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
    if (this.deleting) {
      return
    }
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
          message: AppStrings.get('llm_source_delete_failed'),
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
          })
      } else {
        TextInput({
          text: this.apiKeyDraft,
          placeholder: this.apiKeyStateText(),
        })
          .type(InputType.Password)
          .width('100%')
          .height(48)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .backgroundColor(ThemeTokens.SURFACE_SUB)
          .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
          .onChange((value: string): void => {
            this.apiKeyDraft = value
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
        trailingText: AppStrings.get('llm_source_type_api'),
        showChevron: false,
      })
      this.RowDivider()
      this.TextInputRow(AppStrings.get('llm_source_name'), 'name')
      this.RowDivider()
      this.TextInputRow(AppStrings.get('llm_source_base_url'), 'baseUrl')
      this.RowDivider()
      this.TextInputRow(AppStrings.get('llm_source_api_key'), 'apiKey')
    }
  }

  @Builder
  private ConsumerGroup() {
    Column({ space: ThemeTokens.SPACE_SM }) {
      NextNGroupedListSection() {
        NextNListRow({
          leadingIcon: $r('sys.symbol.translate'),
          title: AppStrings.get('llm_source_support_comments'),
          hasSwitch: true,
          checked: this.supportsComments,
          showChevron: false,
          onAction: (): void => {
            if (!this.supportsComments && !this.supportsManga) {
              return
            }
            this.supportsComments = !this.supportsComments
          },
          onSwitchChange: (value: boolean): void => {
            if (!value && !this.supportsManga) {
              return
            }
            this.supportsComments = value
          },
        })
        this.RowDivider()
        NextNListRow({
          leadingIcon: $r('sys.symbol.picture'),
          title: AppStrings.get('llm_source_support_manga'),
          hasSwitch: true,
          checked: this.supportsManga,
          showChevron: false,
          onAction: (): void => {
            if (!this.supportsManga && !this.supportsComments) {
              return
            }
            this.supportsManga = !this.supportsManga
          },
          onSwitchChange: (value: boolean): void => {
            if (!value && !this.supportsComments) {
              return
            }
            this.supportsManga = value
          },
        })
        this.RowDivider()
        NextNListRow({
          leadingIcon: $r('sys.symbol.arrow_down_circle'),
          title: AppStrings.get('llm_source_support_catalog'),
          hasSwitch: true,
          checked: this.supportsCatalog,
          showChevron: false,
          onAction: (): void => {
            this.supportsCatalog = !this.supportsCatalog
          },
          onSwitchChange: (value: boolean): void => {
            this.supportsCatalog = value
          },
        })
      }
      Text(AppStrings.get('llm_source_support_manga_hint'))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_TERTIARY)
        .width('100%')
        .padding({
          left: ThemeTokens.SPACE_MD,
          right: ThemeTokens.SPACE_MD,
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private CatalogGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.arrow_down_circle'),
        title: AppStrings.get('llm_source_catalog'),
        subtitle: this.catalogSubtitle(),
        trailingText: this.modelCatalogCount > 0 ? this.modelCatalogCount.toString() : '',
        showChevron: true,
        isEnabled: !this.modelCatalogLoading && this.supportsCatalog &&
          this.apiKeyDraft.trim().length > 0,
        onAction: (): void => {
          this.fetchModels()
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
            this.CatalogGroup()
          }
          ListItem() {
            this.DeleteGroup()
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE_SUB)
  }
}
