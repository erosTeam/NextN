import { common } from '@kit.AbilityKit'
import { AppStrings } from '../i18n/AppStrings'
import { NhLocalUserTag, NhLocalUserTagContract } from '../model/NhLocalUserTag'
import { NhTag } from '../model/NhGallery'
import { NhLocalUserTagService } from '../services/NhLocalUserTagService'
import { TagTranslationRepository } from '../storage/TagTranslationRepository'
import { ThemeTokens } from '../theme/ThemeTokens'
import { NhTagSuggestionDisplay } from '../utils/NhTagSuggestionDisplay'
import { AppColorPicker } from './AppColorPicker'
import { NextNGroupedListSection } from './NextNGroupedListSection'
import { NextNInlineEditRow } from './NextNInlineEditRow'
import { NextNListRow } from './NextNListRow'
import { NextNModalScaffold } from './NextNModalScaffold'

const LOCAL_TAG_DEFAULT_COLOR: string = '#3377FF'

/** Shared known-NH-tag editor used by Settings and Gallery tag details. */
@ComponentV2
export struct LocalUserTagEditorSheet {
  @Require @Param tag: NhTag
  @Param allowDelete: boolean = true
  @Event onClose?: () => void
  @Event onSaveRequested?: (record: NhLocalUserTag) => void
  @Event onDeleteRequested?: (tagId: number) => void
  @Local saving: boolean = false
  @Local existing: boolean = false
  @Local draftWeight: string = '10'
  @Local draftHidden: boolean = false
  @Local draftDefaultColor: boolean = true
  @Local draftColor: string = LOCAL_TAG_DEFAULT_COLOR
  @Local displayTitle: string = ''
  @Local errorMessage: string = ''
  private translationEpoch: number = 0

  aboutToAppear(): void {
    this.resetDraft()
    this.loadTranslation()
  }

  @Monitor('tag')
  private onTagChanged(): void {
    this.resetDraft()
    this.loadTranslation()
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private currentRecord(): NhLocalUserTag | null {
    const records: NhLocalUserTag[] = NhLocalUserTagService.activeTags()
    for (let index: number = 0; index < records.length; index++) {
      if (records[index].tagId === this.tag.id) {
        return records[index]
      }
    }
    return null
  }

  private resetDraft(): void {
    const record: NhLocalUserTag | null = this.currentRecord()
    this.existing = record !== null
    this.draftWeight = record !== null ? `${record.weight}` : '10'
    this.draftHidden = record !== null ? record.hidden : false
    this.draftDefaultColor = record === null || record.colorCode.length === 0
    this.draftColor = record !== null && record.colorCode.length > 0
      ? record.colorCode
      : LOCAL_TAG_DEFAULT_COLOR
    this.displayTitle = this.tag.name
    this.errorMessage = ''
    this.saving = false
  }

  private async loadTranslation(): Promise<void> {
    const epoch: number = this.translationEpoch + 1
    this.translationEpoch = epoch
    try {
      const labels: Map<string, string> = await TagTranslationRepository.lookup(this.context(), [this.tag])
      if (epoch !== this.translationEpoch) {
        return
      }
      const translated: string = labels.get(TagTranslationRepository.keyFor(this.tag)) ?? ''
      if (translated.trim().length > 0 && translated.trim() !== this.tag.name) {
        const prefix: string = NhTagSuggestionDisplay.namespaceLabel(this.tag.type)
        this.displayTitle = prefix.length > 0 ? `${prefix}:${translated.trim()}` : translated.trim()
      }
    } catch (_error) {}
  }

  private rawIdentity(): string {
    return this.tag.type.trim().length > 0 ? `${this.tag.type}:${this.tag.name}` : this.tag.name
  }

  private parsedWeight(): number | null {
    const value: string = this.draftWeight.trim()
    if (!/^-?\d+$/.test(value)) {
      return null
    }
    const parsed: number = Number(value)
    return Number.isSafeInteger(parsed) ? parsed : null
  }

  private canSave(): boolean {
    return !this.saving && this.tag.id > 0 && this.tag.name.trim().length > 0 &&
      this.parsedWeight() !== null &&
      (this.draftDefaultColor || NhLocalUserTagContract.isColorCodeValid(this.draftColor))
  }

  private close(): void {
    if (this.onClose) {
      this.onClose()
    }
  }

  private save(): void {
    const weight: number | null = this.parsedWeight()
    if (!this.canSave() || weight === null) {
      this.errorMessage = AppStrings.get('local_user_tag_invalid')
      return
    }
    const record: NhLocalUserTag = new NhLocalUserTag()
    record.tagId = this.tag.id
    record.namespaceSnapshot = this.tag.type
    record.nameSnapshot = this.tag.name
    record.weight = weight
    record.hidden = this.draftHidden
    record.colorCode = this.draftDefaultColor ? '' : this.draftColor
    this.saving = true
    this.errorMessage = ''
    if (this.onSaveRequested) {
      this.onSaveRequested(record)
    }
    this.close()
  }

  private confirmDelete(): void {
    if (!this.existing || this.tag.id <= 0) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('local_user_tag_delete_title'),
      message: AppStrings.get('local_user_tag_delete_message'),
      primaryButton: { value: AppStrings.get('common_cancel'), action: (): void => {} },
      secondaryButton: {
        value: AppStrings.get('common_delete'),
        fontColor: Color.Red,
        action: (): void => {
          this.requestDelete()
        },
      },
    })
  }

  private requestDelete(): void {
    this.saving = true
    if (this.onDeleteRequested) {
      this.onDeleteRequested(this.tag.id)
    }
    this.close()
  }

  @Builder
  private RowDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(ThemeTokens.DIVIDER)
      .margin({ left: ThemeTokens.SPACE_MD })
  }

  build() {
    NextNModalScaffold({
      title: AppStrings.get(this.existing ? 'local_user_tag_edit_title' : 'local_user_tag_add_title'),
      contentBackgroundColor: ThemeTokens.SURFACE_SUB,
      showConfirmAction: true,
      confirmText: AppStrings.get('local_user_tag_save'),
      confirmEnabled: this.canSave(),
      confirmLoading: this.saving,
      showSecondaryAction: this.allowDelete && this.existing,
      secondaryText: AppStrings.get('common_delete'),
      onClose: (): void => this.close(),
      onConfirm: (): void => { this.save() },
      onSecondary: (): void => this.confirmDelete(),
    }) {
      ListItem() {
        NextNGroupedListSection() {
          NextNListRow({
            title: this.displayTitle,
            subtitle: this.rawIdentity(),
            trailingText: `#${this.tag.id}`,
            showChevron: false,
          })
          this.RowDivider()
          NextNListRow({
            title: AppStrings.get('local_user_tag_hidden'),
            subtitle: AppStrings.get('local_user_tag_hidden_desc'),
            hasSwitch: true,
            checked: this.draftHidden,
            showChevron: false,
            isEnabled: !this.saving,
            onSwitchChange: (value: boolean): void => { this.draftHidden = value },
          })
          this.RowDivider()
          NextNInlineEditRow({
            title: AppStrings.get('local_user_tag_weight'),
            value: this.draftWeight,
            placeholder: '10',
            isEnabled: !this.saving,
            onChange: (value: string): void => { this.draftWeight = value },
          })
          this.RowDivider()
          NextNListRow({
            title: AppStrings.get('local_user_tag_default_color'),
            subtitle: AppStrings.get('local_user_tag_default_color_desc'),
            hasSwitch: true,
            checked: this.draftDefaultColor,
            showChevron: false,
            isEnabled: !this.saving,
            onSwitchChange: (value: boolean): void => { this.draftDefaultColor = value },
          })
        }
      }
      if (!this.draftDefaultColor) {
        ListItem() {
          AppColorPicker({
            title: AppStrings.get('local_user_tag_color'),
            color: this.draftColor,
            disabled: this.saving,
            colorChange: (value: string): void => {
              this.draftColor = value
              this.draftDefaultColor = false
            },
          })
        }
      }
      if (this.errorMessage.length > 0) {
        ListItem() {
          Text(this.errorMessage)
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(Color.Red)
            .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
            .width('100%')
        }
      }
    }
  }
}
