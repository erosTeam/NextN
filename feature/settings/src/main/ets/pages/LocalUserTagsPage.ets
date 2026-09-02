import { common } from '@kit.AbilityKit'
import {
  AppColorPicker,
  AppStrings,
  LocalUserTagEditorSheet,
  NextNGroupedListSection,
  NextNInlineEditRow,
  NextNListRow,
  NextNModalScaffold,
  NhLocalUserTag,
  NhLocalUserTagContract,
  NhLocalUserTagService,
  NhLocalUserTagState,
  NhTag,
  NhTagSuggestion,
  NhTagSuggestionDisplay,
  NhTagSuggestionService,
  PageEmptyState,
  SecondaryListScaffold,
  TagTranslationRepository,
  ThemeTokens,
  connectLocalUserTags,
} from 'shared'
import { appSheetOptions } from 'shared'

const LOCAL_TAG_SHEET_ADD: string = 'add'
const LOCAL_TAG_SHEET_EDIT: string = 'edit'
const LOCAL_TAG_SHEET_THRESHOLD: string = 'threshold'
const LOCAL_TAG_SUGGEST_DELAY_MS: number = 300
const LOCAL_TAG_SUGGEST_LIMIT: number = 10
const LOCAL_TAG_DEFAULT_COLOR: string = '#3377FF'

/** NextE My Tags parent tree with NH numeric ids and the local RDB as its leaf owner. */
@ComponentV2
export struct LocalUserTagsPage {
  @Local localUserTags: NhLocalUserTagState = connectLocalUserTags()
  @Local isRestoring: boolean = true
  @Local errorMessage: string = ''
  @Local pageSheetShown: boolean = false
  @Local anchoredSheetShown: boolean = false
  @Local sheetKind: string = ''
  @Local editingTagId: number = 0
  @Local saving: boolean = false
  @Local draftQuery: string = ''
  @Local draftTagId: number = 0
  @Local draftNamespace: string = ''
  @Local draftName: string = ''
  @Local draftWeight: string = '10'
  @Local draftHidden: boolean = false
  @Local draftDefaultColor: boolean = true
  @Local draftColor: string = LOCAL_TAG_DEFAULT_COLOR
  @Local draftThreshold: string = '0'
  @Local suggestions: NhTagSuggestion[] = []
  @Local isSuggesting: boolean = false
  @Local translationLabels: Map<number, string> = new Map<number, string>()
  @Local displayedTags: NhLocalUserTag[] = []
  @Local pendingTagSave: NhLocalUserTag | null = null
  @Local pendingTagDeleteId: number = 0
  @Local pendingThresholdSave: number | null = null
  @Param scroller: Scroller = new Scroller()
  @Param addRequestVersion: number = 0
  private suggestEpoch: number = 0
  private suggestTimer: number = -1

  aboutToAppear(): void {
    if (this.localUserTags.isRestored) {
      this.isRestoring = false
      this.refreshDisplayedTags()
      this.refreshTranslationLabels()
      return
    }
    this.restore()
  }

  aboutToDisappear(): void {
    this.cancelSuggestions()
    this.forceCloseSheet()
  }

  @Monitor('localUserTags.revision')
  onLocalUserTagsChanged(): void {
    this.refreshDisplayedTags()
    this.refreshTranslationLabels()
  }

  @Monitor('addRequestVersion')
  onAddRequested(): void {
    if (this.addRequestVersion > 0) {
      this.openAdd()
    }
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private async restore(): Promise<void> {
    this.isRestoring = true
    this.errorMessage = ''
    try {
      await NhLocalUserTagService.restore(this.context())
      this.refreshDisplayedTags()
      await this.refreshTranslationLabels()
    } catch (_error) {
      this.errorMessage = AppStrings.get('local_user_tags_unavailable')
    } finally {
      this.isRestoring = false
    }
  }

  private configuredTags(): NhLocalUserTag[] {
    return this.displayedTags
  }

  private refreshDisplayedTags(): void {
    const tags: NhLocalUserTag[] = NhLocalUserTagService.activeTags()
    tags.sort((left: NhLocalUserTag, right: NhLocalUserTag): number => left.tagId - right.tagId)
    this.displayedTags = tags
  }

  private thresholdLabel(): string {
    const revision: number = this.localUserTags.revision
    return `${revision >= 0 ? NhLocalUserTagService.filteringThreshold() : 0}`
  }

  private async refreshTranslationLabels(): Promise<void> {
    const records: NhLocalUserTag[] = NhLocalUserTagService.activeTags()
    if (records.length === 0) {
      this.translationLabels = new Map<number, string>()
      return
    }
    const tags: NhTag[] = records.map((record: NhLocalUserTag): NhTag => {
      const tag: NhTag = new NhTag()
      tag.id = record.tagId
      tag.type = record.namespaceSnapshot
      tag.name = record.nameSnapshot
      return tag
    })
    try {
      const labels: Map<string, string> = await TagTranslationRepository.lookup(this.context(), tags)
      const next: Map<number, string> = new Map<number, string>()
      for (let index: number = 0; index < tags.length; index++) {
        const label: string = labels.get(TagTranslationRepository.keyFor(tags[index])) ?? ''
        if (label.trim().length > 0 && label.trim() !== tags[index].name) {
          next.set(tags[index].id, label.trim())
        }
      }
      this.translationLabels = next
    } catch (_error) {
      this.translationLabels = new Map<number, string>()
    }
  }

  private tagTitle(record: NhLocalUserTag): string {
    const translated: string | undefined = this.translationLabels.get(record.tagId)
    if (translated === undefined) {
      return record.nameSnapshot
    }
    const prefix: string = NhTagSuggestionDisplay.namespaceLabel(record.namespaceSnapshot)
    return prefix.length > 0 ? `${prefix}:${translated}` : translated
  }

  private tagSubtitle(record: NhLocalUserTag): string {
    const raw: string = record.namespaceSnapshot.length > 0
      ? `${record.namespaceSnapshot}:${record.nameSnapshot}`
      : record.nameSnapshot
    return AppStrings.format('local_user_tag_identity', [raw, `${record.tagId}`])
  }

  private rowKey(record: NhLocalUserTag): string {
    return `local_tag_${this.localUserTags.revision}_${record.tagId}_${record.updatedAt}`
  }

  private openAdd(): void {
    this.resetDraft()
    this.sheetKind = LOCAL_TAG_SHEET_ADD
    this.pageSheetShown = true
  }

  private openEdit(record: NhLocalUserTag): void {
    this.resetDraft()
    this.sheetKind = LOCAL_TAG_SHEET_EDIT
    this.editingTagId = record.tagId
    this.draftTagId = record.tagId
    this.draftNamespace = record.namespaceSnapshot
    this.draftName = record.nameSnapshot
    this.draftQuery = this.tagSubtitle(record)
    this.draftWeight = `${record.weight}`
    this.draftHidden = record.hidden
    this.draftDefaultColor = record.colorCode.length === 0
    this.draftColor = record.colorCode.length > 0 ? record.colorCode : LOCAL_TAG_DEFAULT_COLOR
    this.anchoredSheetShown = true
  }

  private openThreshold(): void {
    this.resetDraft()
    this.sheetKind = LOCAL_TAG_SHEET_THRESHOLD
    this.draftThreshold = `${NhLocalUserTagService.filteringThreshold()}`
    this.pageSheetShown = true
  }

  private closeSheet(): void {
    this.cancelSuggestions()
    this.pageSheetShown = false
    this.anchoredSheetShown = false
  }

  private finishCloseSheet(): void {
    this.sheetKind = ''
    this.editingTagId = 0
    this.commitPendingMutation()
  }

  private forceCloseSheet(): void {
    this.pageSheetShown = false
    this.anchoredSheetShown = false
    this.finishCloseSheet()
  }

  private resetDraft(): void {
    this.cancelSuggestions()
    this.errorMessage = ''
    this.editingTagId = 0
    this.draftQuery = ''
    this.draftTagId = 0
    this.draftNamespace = ''
    this.draftName = ''
    this.draftWeight = '10'
    this.draftHidden = false
    this.draftDefaultColor = true
    this.draftColor = LOCAL_TAG_DEFAULT_COLOR
    this.draftThreshold = `${NhLocalUserTagService.filteringThreshold()}`
  }

  private cancelSuggestions(): void {
    if (this.suggestTimer >= 0) {
      clearTimeout(this.suggestTimer)
      this.suggestTimer = -1
    }
    this.suggestEpoch += 1
    this.suggestions = []
    this.isSuggesting = false
  }

  private updateAddQuery(value: string): void {
    const selectedQuery: string = this.draftNamespace.length > 0
      ? `${this.draftNamespace}:${this.draftName}`
      : this.draftName
    if (this.draftTagId > 0 && value.trim() === selectedQuery) {
      this.draftQuery = value
      this.cancelSuggestions()
      return
    }
    this.draftQuery = value
    this.draftTagId = 0
    this.draftNamespace = ''
    this.draftName = ''
    this.cancelSuggestions()
    const query: string = value.trim()
    if (query.length === 0 || query.length > 128) {
      return
    }
    const epoch: number = this.suggestEpoch + 1
    this.suggestEpoch = epoch
    this.suggestTimer = setTimeout((): void => {
      this.suggestTimer = -1
      this.loadSuggestions(query, epoch)
    }, LOCAL_TAG_SUGGEST_DELAY_MS)
  }

  private async loadSuggestions(query: string, epoch: number): Promise<void> {
    this.isSuggesting = true
    try {
      const result: NhTagSuggestion[] = await NhTagSuggestionService.suggestVerified(
        this.context(),
        '',
        query,
        LOCAL_TAG_SUGGEST_LIMIT,
      )
      if (epoch !== this.suggestEpoch || this.sheetKind !== LOCAL_TAG_SHEET_ADD) {
        return
      }
      this.suggestions = result.filter((suggestion: NhTagSuggestion): boolean => suggestion.tagId > 0)
    } catch (_error) {
      if (epoch === this.suggestEpoch) {
        this.suggestions = []
      }
    } finally {
      if (epoch === this.suggestEpoch) {
        this.isSuggesting = false
      }
    }
  }

  private selectSuggestion(suggestion: NhTagSuggestion): void {
    if (suggestion.tagId <= 0) {
      return
    }
    this.draftTagId = suggestion.tagId
    this.draftNamespace = suggestion.namespace
    this.draftName = suggestion.rawName
    this.draftQuery = `${suggestion.namespace}:${suggestion.rawName}`
    this.cancelSuggestions()
  }

  private parsedWeight(): number | null {
    const value: string = this.draftWeight.trim()
    if (!/^-?\d+$/.test(value)) {
      return null
    }
    const parsed: number = Number(value)
    return Number.isSafeInteger(parsed) ? parsed : null
  }

  private parsedThreshold(): number | null {
    const value: string = this.draftThreshold.trim()
    if (!/^-?\d+$/.test(value)) {
      return null
    }
    const parsed: number = Number.parseInt(value, 10)
    return parsed < -9999 || parsed > 0 ? null : parsed
  }

  private duplicateDraftTag(): boolean {
    return this.sheetKind === LOCAL_TAG_SHEET_ADD && this.draftTagId > 0 &&
      NhLocalUserTagService.activeTags().some(
        (record: NhLocalUserTag): boolean => record.tagId === this.draftTagId,
      )
  }

  private canSaveEditor(): boolean {
    return !this.saving && this.draftTagId > 0 && this.draftName.trim().length > 0 &&
      this.parsedWeight() !== null && !this.duplicateDraftTag() &&
      (this.draftDefaultColor || NhLocalUserTagContract.isColorCodeValid(this.draftColor))
  }

  private canSaveThreshold(): boolean {
    return !this.saving && this.parsedThreshold() !== null
  }

  private saveEditor(): void {
    const weight: number | null = this.parsedWeight()
    if (!this.canSaveEditor() || weight === null) {
      this.errorMessage = this.duplicateDraftTag()
        ? AppStrings.get('local_user_tag_already_exists')
        : AppStrings.get('local_user_tag_invalid')
      return
    }
    const record: NhLocalUserTag = new NhLocalUserTag()
    record.tagId = this.draftTagId
    record.namespaceSnapshot = this.draftNamespace
    record.nameSnapshot = this.draftName
    record.weight = weight
    record.hidden = this.draftHidden
    record.colorCode = this.draftDefaultColor ? '' : this.draftColor
    this.saving = true
    this.errorMessage = ''
    this.pendingTagSave = record
    this.closeSheet()
  }

  private saveThreshold(): void {
    const threshold: number | null = this.parsedThreshold()
    if (threshold === null) {
      this.errorMessage = AppStrings.get('local_user_tag_threshold_invalid')
      return
    }
    this.saving = true
    this.errorMessage = ''
    this.pendingThresholdSave = threshold
    this.closeSheet()
  }

  private confirmDelete(): void {
    if (this.editingTagId <= 0) {
      return
    }
    const tagId: number = this.editingTagId
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('local_user_tag_delete_title'),
      message: AppStrings.get('local_user_tag_delete_message'),
      primaryButton: { value: AppStrings.get('common_cancel'), action: (): void => {} },
      secondaryButton: {
        value: AppStrings.get('common_delete'),
        fontColor: Color.Red,
        action: (): void => {
          this.deleteTag(tagId)
        },
      },
    })
  }

  private deleteTag(tagId: number): void {
    this.saving = true
    this.pendingTagDeleteId = tagId
    this.closeSheet()
  }

  private queueKnownTagSave(record: NhLocalUserTag): void {
    this.saving = true
    this.errorMessage = ''
    this.pendingTagSave = record
  }

  private queueKnownTagDelete(tagId: number): void {
    this.saving = true
    this.errorMessage = ''
    this.pendingTagDeleteId = tagId
  }

  private async commitPendingMutation(): Promise<void> {
    const pendingSave: NhLocalUserTag | null = this.pendingTagSave
    const pendingDeleteId: number = this.pendingTagDeleteId
    const pendingThreshold: number | null = this.pendingThresholdSave
    this.pendingTagSave = null
    this.pendingTagDeleteId = 0
    this.pendingThresholdSave = null
    try {
      if (pendingSave !== null) {
        await NhLocalUserTagService.save(this.context(), pendingSave)
      } else if (pendingDeleteId > 0) {
        await NhLocalUserTagService.remove(this.context(), pendingDeleteId)
      } else if (pendingThreshold !== null) {
        await NhLocalUserTagService.setFilteringThreshold(this.context(), pendingThreshold)
      }
      this.saving = false
    } catch (_error) {
      this.errorMessage = pendingDeleteId > 0
        ? AppStrings.get('local_user_tag_delete_failed')
        : AppStrings.get('local_user_tag_save_failed')
      this.saving = false
    }
  }

  @Builder
  private RowDivider() {
    Divider().strokeWidth(0.5).color(ThemeTokens.DIVIDER).margin({ left: ThemeTokens.SPACE_MD })
  }

  @Builder
  private TagStatusPrefix(record: NhLocalUserTag) {
    Row() {
      SymbolGlyph(record.hidden ? $r('sys.symbol.xmark_circle_fill') : $r('sys.symbol.dot_circle'))
        .fontSize(24)
        .fontColor([record.hidden ? Color.Red : ThemeTokens.TEXT_TERTIARY])
    }
    .width(36)
    .justifyContent(FlexAlign.Center)
    .padding({ left: ThemeTokens.SPACE_SM })
  }

  @Builder
  private WeightBadge(record: NhLocalUserTag) {
    Text(`${record.weight}`)
      .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
      .fontWeight(FontWeight.Medium)
      .fontColor(record.colorCode.length > 0
        ? NhLocalUserTagService.readableTextColor(record.tagId)
        : ThemeTokens.TEXT_PRIMARY)
      .constraintSize({ minWidth: 36 })
      .textAlign(TextAlign.Center)
      .padding({ left: ThemeTokens.SPACE_SM, right: ThemeTokens.SPACE_SM,
        top: ThemeTokens.SPACE_XS, bottom: ThemeTokens.SPACE_XS })
      .backgroundColor(record.colorCode.length > 0 ? record.colorCode : ThemeTokens.BRAND_CONTAINER)
      .borderRadius(ThemeTokens.RADIUS_ROUND)
  }

  @Builder
  private TagRow(record: NhLocalUserTag) {
    Column() {
      NextNListRow({
        title: this.tagTitle(record),
        subtitle: this.tagSubtitle(record),
        useCustomLeading: true,
        customLeading: (): void => this.TagStatusPrefix(record),
        useCustomTrailing: true,
        customTrailing: (): void => this.WeightBadge(record),
        suffixPaddingRight: ThemeTokens.SPACE_SM,
        onAction: (): void => this.openEdit(record),
      })
    }
    .width('100%')
    .bindSheet(
      this.anchoredSheetShown && this.editingTagId === record.tagId,
      this.KnownTagEditor(record),
      appSheetOptions({
        detents: [SheetSize.LARGE],
        showClose: false,
        onDisappear: (): void => {
          if (this.editingTagId === record.tagId) {
            this.finishCloseSheet()
          }
        },
      }),
    )
  }

  private tagForRecord(record: NhLocalUserTag): NhTag {
    const tag: NhTag = new NhTag()
    tag.id = record.tagId
    tag.type = record.namespaceSnapshot
    tag.name = record.nameSnapshot
    return tag
  }

  @Builder
  private KnownTagEditor(record: NhLocalUserTag) {
    LocalUserTagEditorSheet({
      tag: this.tagForRecord(record),
      allowDelete: true,
      onClose: (): void => this.closeSheet(),
      onSaveRequested: (updated: NhLocalUserTag): void => this.queueKnownTagSave(updated),
      onDeleteRequested: (tagId: number): void => this.queueKnownTagDelete(tagId),
    })
  }

  @Builder
  private ThresholdGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.list_number'),
        title: AppStrings.get('local_user_tag_threshold'),
        subtitle: AppStrings.get('local_user_tag_threshold_desc'),
        trailingText: this.thresholdLabel(),
        onAction: (): void => this.openThreshold(),
      })
    }
  }

  @Builder
  private TagsGroup() {
    NextNGroupedListSection() {
      if (this.configuredTags().length > 0) {
        ForEach(this.configuredTags(), (record: NhLocalUserTag, index: number): void => {
          this.TagRow(record)
          if (index < this.configuredTags().length - 1) {
            this.RowDivider()
          }
        }, (record: NhLocalUserTag): string => this.rowKey(record))
      }
    }
  }

  @Builder
  private Suggestions() {
    if (this.isSuggesting || this.suggestions.length > 0) {
      NextNGroupedListSection() {
        if (this.isSuggesting && this.suggestions.length === 0) {
          NextNListRow({
            title: AppStrings.get('local_user_tag_suggesting'),
            showChevron: false,
          })
        }
        ForEach(this.suggestions, (suggestion: NhTagSuggestion, index: number): void => {
          NextNListRow({
            title: NhTagSuggestionDisplay.localizedTitle(suggestion).length > 0
              ? NhTagSuggestionDisplay.localizedTitle(suggestion)
              : suggestion.rawName,
            subtitle: `${suggestion.namespace}:${suggestion.rawName}`,
            trailingText: `#${suggestion.tagId}`,
            onAction: (): void => this.selectSuggestion(suggestion),
          })
          if (index < this.suggestions.length - 1) {
            this.RowDivider()
          }
        }, (suggestion: NhTagSuggestion): string => `${suggestion.tagId}`)
      }
    }
  }

  @Builder
  private EditorSheet() {
    NextNModalScaffold({
      title: AppStrings.get(this.sheetKind === LOCAL_TAG_SHEET_EDIT
        ? 'local_user_tag_edit_title'
        : 'local_user_tag_add_title'),
      showConfirmAction: true,
      confirmText: AppStrings.get('local_user_tag_save'),
      confirmEnabled: this.canSaveEditor(),
      showSecondaryAction: this.sheetKind === LOCAL_TAG_SHEET_EDIT,
      secondaryText: AppStrings.get('common_delete'),
      onClose: (): void => this.closeSheet(),
      onConfirm: (): void => {
        this.saveEditor()
      },
      onSecondary: (): void => this.confirmDelete(),
    }) {
      ListItem() {
        NextNGroupedListSection() {
          if (this.sheetKind === LOCAL_TAG_SHEET_ADD) {
            NextNInlineEditRow({
              title: AppStrings.get('local_user_tag_search_label'),
              subtitle: this.draftTagId > 0
                ? AppStrings.format('local_user_tag_selected_id', [`${this.draftTagId}`])
                : '',
              value: this.draftQuery,
              placeholder: AppStrings.get('local_user_tag_search_placeholder'),
              isEnabled: !this.saving,
              onChange: (value: string): void => this.updateAddQuery(value),
            })
          } else {
            NextNListRow({
              title: this.draftName,
              subtitle: this.draftNamespace.length > 0
                ? `${this.draftNamespace}:${this.draftName}`
                : this.draftName,
              trailingText: `#${this.draftTagId}`,
              showChevron: false,
            })
          }
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
      if (this.sheetKind === LOCAL_TAG_SHEET_ADD) {
        ListItem() {
          this.Suggestions()
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

  @Builder
  private ThresholdSheet() {
    NextNModalScaffold({
      title: AppStrings.get('local_user_tag_threshold'),
      showConfirmAction: true,
      confirmText: AppStrings.get('local_user_tag_save'),
      confirmEnabled: this.canSaveThreshold(),
      onClose: (): void => this.closeSheet(),
      onConfirm: (): void => {
        this.saveThreshold()
      },
    }) {
      ListItem() {
        NextNGroupedListSection() {
          NextNInlineEditRow({
            title: AppStrings.get('local_user_tag_threshold'),
            subtitle: AppStrings.get('local_user_tag_threshold_help'),
            value: this.draftThreshold,
            placeholder: '0',
            numeric: true,
            isEnabled: !this.saving,
            onChange: (value: string): void => { this.draftThreshold = value },
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

  @Builder
  private PageSheet() {
    if (this.sheetKind === LOCAL_TAG_SHEET_THRESHOLD) {
      this.ThresholdSheet()
    } else {
      this.EditorSheet()
    }
  }

  build() {
    Column() {
      if (this.isRestoring && !this.localUserTags.isRestored) {
        PageEmptyState({ message: AppStrings.get('local_user_tags_loading') })
      } else {
        SecondaryListScaffold({
          scroller: this.scroller,
          bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
          alwaysEnableEdgeSpring: true,
        }) {
          ListItem() { this.ThresholdGroup() }
          ListItem() { this.TagsGroup() }
          if (this.configuredTags().length === 0) {
            ListItem() {
              PageEmptyState({ message: AppStrings.get('local_user_tags_empty') })
            }
          }
          if (this.errorMessage.length > 0 && !this.pageSheetShown && !this.anchoredSheetShown) {
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
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE_SUB)
    .bindSheet($$this.pageSheetShown, this.PageSheet(), appSheetOptions({
      detents: [this.sheetKind === LOCAL_TAG_SHEET_THRESHOLD ? SheetSize.MEDIUM : SheetSize.LARGE],
      showClose: false,
      onDisappear: (): void => this.finishCloseSheet(),
    }))
  }
}
