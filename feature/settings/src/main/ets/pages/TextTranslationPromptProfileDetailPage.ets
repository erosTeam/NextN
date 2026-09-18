import { common } from '@kit.AbilityKit'
import { KeyboardAvoidMode } from '@kit.ArkUI'
import { util } from '@kit.ArkTS'
import {
  AppStrings,
  DiagnosticLogger,
  MAX_TEXT_TRANSLATION_CUSTOM_PROFILES,
  MAX_TEXT_TRANSLATION_PROMPT_NAME_CHARS,
  MAX_TEXT_TRANSLATION_STYLE_CHARS,
  NextNGroupedListSection,
  NextNListRow,
  NextNSectionHeader,
  SecondaryListScaffold,
  SettingsTextField,
  TextTranslationPromptContract,
  TextTranslationPromptProfile,
  TextTranslationPromptProfileRepository,
  TextTranslationPromptProfilesState,
  ThemeTokens,
  connectTextTranslationPromptProfiles,
} from 'shared'

/**
 * One detail destination for all profile modes in NextN:
 * - built-in detail: read-only presentation card + styled prompt block + "use"/"copy" actions;
 * - custom detail / new: aligned settings form inputs + styled multi-line prompt + save/delete actions.
 * The draft is a local copy only; V2 state is never touched until the repository write succeeds.
 */
@ComponentV2
export struct TextTranslationPromptProfileDetailPage {
  @Local private profiles: TextTranslationPromptProfilesState =
    connectTextTranslationPromptProfiles()
  @Local private promptProfileId: string = ''
  @Local private builtIn: boolean = false
  @Local private sourceIsCustom: boolean = false
  @Local private titleKey: string = 'text_translation_prompt_detail_custom'
  @Local private primaryLabelKey: string = 'common_save'
  @Local private nameDraft: string = ''
  @Local private styleDraft: string = ''
  @Local private loaded: boolean = false
  @Local private saving: boolean = false
  @Local private deleting: boolean = false
  @Param scroller: Scroller = new Scroller()
  @Param requestedPromptProfileId: string = ''
  @Event onSaved?: () => void
  @Event onDeleted?: () => void

  aboutToAppear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
    this.load(this.requestedPromptProfileId)
  }

  aboutToDisappear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message })
  }

  private load(rawId: string): void {
    if (rawId.length === 0) {
      this.promptProfileId = ''
      this.builtIn = false
      this.sourceIsCustom = false
      this.titleKey = 'text_translation_prompt_detail_new'
      this.primaryLabelKey = 'text_translation_prompt_create'
      this.nameDraft = ''
      this.styleDraft = ''
      this.loaded = true
      return
    }
    const found: TextTranslationPromptProfile | null = this.profiles.findById(rawId)
    if (found === null) {
      this.toast(AppStrings.get('llm_source_missing'))
      if (this.onDeleted) {
        this.onDeleted()
      }
      return
    }
    this.promptProfileId = found.promptProfileId
    this.builtIn = found.builtIn
    this.sourceIsCustom = !found.builtIn
    this.nameDraft = found.displayName
    this.styleDraft = found.styleInstructions
    if (found.builtIn) {
      this.titleKey = 'text_translation_prompt_detail_built_in'
      this.primaryLabelKey = 'text_translation_prompt_use'
    } else {
      this.titleKey = 'text_translation_prompt_detail_custom'
      this.primaryLabelKey = 'common_save'
    }
    this.loaded = true
  }

  private candidateFromDrafts(): TextTranslationPromptProfile | null {
    const name: string = this.nameDraft.trim()
    const style: string = this.styleDraft.trim()
    if (name.length === 0 || style.length === 0) {
      this.toast(AppStrings.get('text_translation_prompt_fields_required'))
      return null
    }
    if (name.length > MAX_TEXT_TRANSLATION_PROMPT_NAME_CHARS) {
      this.toast(AppStrings.get('text_translation_prompt_name_too_long'))
      return null
    }
    if (style.length > MAX_TEXT_TRANSLATION_STYLE_CHARS) {
      this.toast(AppStrings.get('text_translation_prompt_style_too_long'))
      return null
    }
    const value: TextTranslationPromptProfile = new TextTranslationPromptProfile()
    value.promptProfileId = this.promptProfileId
    value.displayName = name
    value.styleInstructions = TextTranslationPromptContract.normalizeLineEndings(style)
    value.builtIn = false
    if (this.promptProfileId.length === 0) {
      value.promptProfileId = util.generateRandomUUID(true)
      value.promptRevision = 1
      const now: number = Date.now()
      value.createdAt = now
      value.updatedAt = now
    } else {
      const existing: TextTranslationPromptProfile | null =
        this.profiles.findById(this.promptProfileId)
      if (existing !== null) {
        value.promptRevision = existing.promptRevision
        value.createdAt = existing.createdAt
        value.updatedAt = existing.updatedAt
      }
    }
    return value
  }

  private async save(): Promise<void> {
    if (this.builtIn) {
      this.useCurrentAsSelection()
      return
    }
    if (this.saving) {
      return
    }
    const candidate: TextTranslationPromptProfile | null = this.candidateFromDrafts()
    if (candidate === null) {
      return
    }
    this.saving = true
    try {
      await TextTranslationPromptProfileRepository.upsertCustom(this.context(), candidate)
      await TextTranslationPromptProfileRepository.select(this.context(), candidate.promptProfileId)
      this.toast(AppStrings.get('text_translation_prompt_saved'))
      if (this.onSaved) {
        this.onSaved()
      }
    } catch (error) {
      DiagnosticLogger.warn('text-translation-prompt', 'profile_save_failed', (error as Error).message)
      this.toast(AppStrings.format('text_translation_prompt_save_failed', [(error as Error).message]))
    } finally {
      this.saving = false
    }
  }

  private useCurrentAsSelection(): void {
    TextTranslationPromptProfileRepository.select(this.context(), this.promptProfileId)
      .then(() => {
        this.toast(AppStrings.get('text_translation_prompt_selected'))
        if (this.onSaved) {
          this.onSaved()
        }
      })
      .catch((error: Error) => {
        DiagnosticLogger.warn('text-translation-prompt', 'profile_select_failed', error.message)
        this.toast(AppStrings.format('text_translation_prompt_save_failed', [error.message]))
      })
  }

  private confirmDelete(): void {
    if (this.deleting || this.promptProfileId.length === 0) {
      return
    }
    const isCurrentSelection: boolean =
      this.profiles.selectedPromptProfileId === this.promptProfileId
    const message: string = isCurrentSelection
      ? AppStrings.get('text_translation_prompt_delete_current_confirm')
      : AppStrings.get('text_translation_prompt_delete_confirm')
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('common_delete'),
      message: message,
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: AppStrings.get('common_delete'),
        action: () => {
          this.deleteCustom()
        },
      },
    })
  }

  private deleteCustom(): void {
    this.deleting = true
    TextTranslationPromptProfileRepository.removeCustom(this.context(), this.promptProfileId)
      .then(() => {
        if (this.onDeleted) {
          this.onDeleted()
        }
      })
      .catch((error: Error) => {
        this.deleting = false
        DiagnosticLogger.warn('text-translation-prompt', 'profile_delete_failed', error.message)
        this.toast(AppStrings.format('text_translation_prompt_delete_failed', [error.message]))
      })
  }

  private copyAsCustom(): void {
    if (this.profiles.customProfiles.length >= MAX_TEXT_TRANSLATION_CUSTOM_PROFILES) {
      this.toast(AppStrings.get('text_translation_prompt_limit_reached'))
      return
    }
    const source: TextTranslationPromptProfile | null = this.profiles.findById(this.promptProfileId)
    if (source === null) {
      this.toast(AppStrings.get('llm_source_missing'))
      if (this.onDeleted) {
        this.onDeleted()
      }
      return
    }
    const newId: string = util.generateRandomUUID(true)
    const copyName: string = source.displayName + ' ' + AppStrings.get('text_translation_prompt_copy_suffix')
    const draft: TextTranslationPromptProfile =
      TextTranslationPromptProfileRepository.copyAsCustom(source, newId, copyName, Date.now())
    this.promptProfileId = draft.promptProfileId
    this.builtIn = false
    this.sourceIsCustom = true
    this.titleKey = 'text_translation_prompt_detail_new'
    this.primaryLabelKey = 'text_translation_prompt_create'
    this.nameDraft = draft.displayName
    this.styleDraft = draft.styleInstructions
  }

  @Builder
  private RowDivider() {
    Divider()
      .color(ThemeTokens.DIVIDER)
      .strokeWidth(0.5)
      .margin({ left: 56, right: 16 })
  }

  @Builder
  private BuiltInView() {
    ListItem() {
      NextNSectionHeader({ title: AppStrings.get('text_translation_prompt_detail_built_in') })
    }
    .margin({ top: ThemeTokens.SPACE_XS })
    ListItem() {
      NextNGroupedListSection() {
        NextNListRow({
          leadingIcon: $r('sys.symbol.doc_plaintext'),
          title: AppStrings.get('llm_source_name'),
          trailingText: this.nameDraft,
          showChevron: false,
        })
      }
    }
    ListItem() {
      NextNSectionHeader({ title: AppStrings.get('text_translation_prompt_style_label') })
    }
    .margin({ top: ThemeTokens.SPACE_MD })
    ListItem() {
      NextNGroupedListSection({ inset: 0 }) {
        Text(this.styleDraft)
          .fontSize(ThemeTokens.FONT_SIZE_BODY)
          .fontColor(ThemeTokens.TEXT_PRIMARY)
          .lineHeight(22)
          .width('100%')
          .padding(ThemeTokens.SPACE_LG)
          .copyOption(CopyOptions.LocalDevice)
      }
    }
    ListItem() {
      NextNGroupedListSection() {
        NextNListRow({
          title: AppStrings.get(this.primaryLabelKey),
          leadingIcon: $r('sys.symbol.checkmark_circle'),
          showChevron: false,
          isEnabled: !this.saving,
          onAction: () => {
            this.useCurrentAsSelection()
          },
        })
        this.RowDivider()
        NextNListRow({
          title: AppStrings.get('text_translation_prompt_copy_as_custom'),
          subtitle: AppStrings.get('text_translation_prompt_copy_as_custom_hint'),
          leadingIcon: $r('sys.symbol.square_and_pencil'),
          showChevron: false,
          onAction: () => {
            this.copyAsCustom()
          },
        })
      }
    }
    .margin({ top: ThemeTokens.SPACE_MD })
  }

  @Builder
  private CustomEditView() {
    ListItem() {
      NextNSectionHeader({
        title: AppStrings.get(this.promptProfileId.length > 0
          ? 'text_translation_prompt_detail_custom'
          : 'text_translation_prompt_detail_new')
      })
    }
    .margin({ top: ThemeTokens.SPACE_XS })
    ListItem() {
      NextNGroupedListSection({ inset: 0 }) {
        SettingsTextField({
          label: AppStrings.get('llm_source_name'),
          value: this.nameDraft,
          placeholder: AppStrings.get('text_translation_prompt_name_placeholder'),
          onChange: (value: string) => {
            this.nameDraft = value
          },
        })
      }
    }
    ListItem() {
      NextNSectionHeader({ title: AppStrings.get('text_translation_prompt_style_label') })
    }
    .margin({ top: ThemeTokens.SPACE_MD })
    ListItem() {
      NextNGroupedListSection({ inset: 0 }) {
        Column({ space: ThemeTokens.SPACE_XS }) {
          TextArea({
            text: this.styleDraft,
            placeholder: AppStrings.get('text_translation_prompt_style_placeholder'),
          })
            .width('100%')
            .height(180)
            .fontSize(ThemeTokens.FONT_SIZE_BODY)
            .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
            .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
            .padding(ThemeTokens.SPACE_SM)
            .onChange((value: string) => {
              this.styleDraft = value
            })
          Row() {
            Blank()
            Text(`${this.styleDraft.length} / ${MAX_TEXT_TRANSLATION_STYLE_CHARS}`)
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontColor(ThemeTokens.TEXT_TERTIARY)
          }
          .width('100%')
          .padding({ right: ThemeTokens.SPACE_XS, top: ThemeTokens.SPACE_XS })
        }
        .padding({
          left: ThemeTokens.SPACE_MD,
          right: ThemeTokens.SPACE_MD,
          top: ThemeTokens.SPACE_SM,
          bottom: ThemeTokens.SPACE_SM,
        })
        .width('100%')
      }
    }
    ListItem() {
      NextNGroupedListSection() {
        NextNListRow({
          title: AppStrings.get(this.primaryLabelKey),
          leadingIcon: $r('sys.symbol.checkmark_circle'),
          showChevron: false,
          isEnabled: !this.saving && !this.deleting,
          onAction: () => {
            this.save()
          },
        })
        if (this.sourceIsCustom && this.promptProfileId.length > 0) {
          this.RowDivider()
          NextNListRow({
            title: AppStrings.get('common_delete'),
            leadingIcon: $r('sys.symbol.trash'),
            destructive: true,
            showChevron: false,
            isEnabled: !this.saving && !this.deleting,
            onAction: () => {
              this.confirmDelete()
            },
          })
        }
      }
    }
    .margin({ top: ThemeTokens.SPACE_MD })
  }

  build() {
    Column() {
      SecondaryListScaffold({
        scroller: this.scroller,
        bottomPadding: 24,
        alwaysEnableEdgeSpring: true,
      }) {
        if (this.loaded) {
          if (this.builtIn) {
            this.BuiltInView()
          } else {
            this.CustomEditView()
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE_SUB)
  }
}

