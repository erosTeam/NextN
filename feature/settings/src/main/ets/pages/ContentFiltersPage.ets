import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import {
  ContentFilterService,
  ContentFilterState,
  AppStrings,
  connectContentFilters,
  NextNGroupedListSection,
  NextNListRow,
  NextNModalScaffold,
  NhContentFilterRule,
  NhContentFilterType,
  PageEmptyState,
  SecondaryListScaffold,
  ThemeTokens,
} from 'shared'
import { appSheetOptions } from 'shared'

/**
 * Direct HDS settings destination for ErosN-derived local display rules.
 * The form is deliberately local: it never edits a query or account state.
 */
@ComponentV2
export struct ContentFiltersPage {
  @Local filters: ContentFilterState = connectContentFilters()
  @Local isRestoring: boolean = true
  @Local errorMessage: string = ''
  @Local editorShown: boolean = false
  @Local editingId: string = ''
  @Local draftType: NhContentFilterType = NhContentFilterType.TITLE
  @Local draftText: string = ''
  @Local draftEnabled: boolean = true
  @Local draftRegex: boolean = false
  @Param scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    if (this.filters.isRestored) {
      this.isRestoring = false
      return
    }
    this.restore()
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private async restore(): Promise<void> {
    this.isRestoring = true
    this.errorMessage = ''
    try {
      await ContentFilterService.restore(this.context())
    } catch (_error) {
      this.errorMessage = AppStrings.get('content_filters_unavailable')
    } finally {
      this.isRestoring = false
    }
  }

  private typeLabel(type: NhContentFilterType): string {
    if (type === NhContentFilterType.COMMENTER) {
      return AppStrings.get('content_filter_type_comment_author')
    }
    if (type === NhContentFilterType.COMMENT) {
      return AppStrings.get('content_filter_type_comment_text')
    }
    return AppStrings.get('content_filter_type_gallery_title')
  }

  private typeIcon(type: NhContentFilterType): Resource {
    if (type === NhContentFilterType.COMMENTER) {
      return $r('sys.symbol.person')
    }
    if (type === NhContentFilterType.COMMENT) {
      return $r('sys.symbol.text_bubble_left_2')
    }
    return $r('sys.symbol.textformat')
  }

  private ruleSubtitle(rule: NhContentFilterRule): string {
    const matcher: string = rule.isRegex
      ? AppStrings.get('content_filter_match_regex')
      : AppStrings.get('content_filter_match_contains')
    return AppStrings.get('content_filter_rule_subtitle')
      .replace('%1$s', this.typeLabel(rule.type))
      .replace('%2$s', matcher)
  }

  private openNewRule(): void {
    this.editingId = ''
    this.draftType = NhContentFilterType.TITLE
    this.draftText = ''
    this.draftEnabled = true
    this.draftRegex = false
    this.editorShown = true
  }

  private openRule(rule: NhContentFilterRule): void {
    this.editingId = rule.id
    this.draftType = rule.type
    this.draftText = rule.text
    this.draftEnabled = rule.enabled
    this.draftRegex = rule.isRegex
    this.editorShown = true
  }

  private draftRegexValid(): boolean {
    return !this.draftRegex || this.draftText.trim().length === 0 || ContentFilterService.isRegexValid(this.draftText.trim())
  }

  private canSaveDraft(): boolean {
    return this.draftText.trim().length > 0 && this.draftRegexValid()
  }

  private async saveDraft(): Promise<void> {
    if (!this.canSaveDraft()) {
      this.errorMessage = AppStrings.get('content_filter_save_validation')
      return
    }
    const rule: NhContentFilterRule = new NhContentFilterRule()
    rule.id = this.editingId
    rule.type = this.draftType
    rule.text = this.draftText
    rule.enabled = this.draftEnabled
    rule.isRegex = this.draftRegex
    this.errorMessage = ''
    try {
      await ContentFilterService.save(this.context(), rule)
      this.editorShown = false
    } catch (_error) {
      this.errorMessage = AppStrings.get('content_filter_save_failed')
    }
  }

  private confirmRemove(): void {
    if (this.editingId.length === 0) {
      return
    }
    const ruleId: string = this.editingId
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('content_filter_remove_title'),
      message: AppStrings.get('content_filter_remove_message'),
      primaryButton: { value: AppStrings.get('common_cancel'), action: (): void => {} },
      secondaryButton: {
        value: AppStrings.get('content_filter_remove_action'),
        fontColor: Color.Red,
        action: (): void => {
          this.removeRule(ruleId)
        },
      },
    })
  }

  private async removeRule(ruleId: string): Promise<void> {
    try {
      await ContentFilterService.remove(this.context(), ruleId)
      this.errorMessage = ''
      this.editorShown = false
    } catch (_error) {
      this.errorMessage = AppStrings.get('content_filter_remove_failed')
    }
  }

  private async setRuleEnabled(rule: NhContentFilterRule, enabled: boolean): Promise<void> {
    try {
      await ContentFilterService.setEnabled(this.context(), rule.id, enabled)
      this.errorMessage = ''
    } catch (_error) {
      this.errorMessage = AppStrings.get('content_filter_update_failed')
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
  private FilterTypeMenu(select: (action: () => void) => void) {
    Menu() {
      this.FilterTypeMenuItem(NhContentFilterType.TITLE, select)
      this.FilterTypeMenuItem(NhContentFilterType.COMMENTER, select)
      this.FilterTypeMenuItem(NhContentFilterType.COMMENT, select)
    }
  }

  @Builder
  private FilterTypeMenuItem(type: NhContentFilterType, select: (action: () => void) => void) {
    MenuItem({
      content: this.typeLabel(type),
      symbolEndIcon: this.draftType === type ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
    }).onClick((): void => {
      select((): void => {
        this.draftType = type
      })
    })
  }

  @Builder
  private RulesGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.plus'),
        title: AppStrings.get('content_filter_add_title'),
        subtitle: AppStrings.get('content_filter_add_subtitle'),
        accessibilityLabel: AppStrings.get('content_filter_add_a11y'),
        onAction: (): void => {
          this.openNewRule()
        },
      })
      if (this.filters.rules.length > 0) {
        this.RowDivider()
        ForEach(this.filters.rules, (rule: NhContentFilterRule, index: number): void => {
          NextNListRow({
            leadingIcon: this.typeIcon(rule.type),
            title: rule.text,
            subtitle: this.ruleSubtitle(rule),
            hasSwitch: true,
            checked: rule.enabled,
            accessibilityLabel: AppStrings.get('content_filter_rule_a11y')
              .replace('%1$s', this.ruleSubtitle(rule))
              .replace('%2$s', rule.enabled
                ? AppStrings.get('content_filter_enabled')
                : AppStrings.get('content_filter_disabled')),
            onAction: (): void => {
              this.openRule(rule)
            },
            onSwitchChange: (enabled: boolean): void => {
              this.setRuleEnabled(rule, enabled)
            },
          })
          if (index < this.filters.rules.length - 1) {
            this.RowDivider()
          }
        }, (rule: NhContentFilterRule): string => rule.id)
      }
    }
  }

  @Builder
  private RulesEditorSheet() {
    NextNModalScaffold({
      title: this.editingId.length > 0
        ? AppStrings.get('content_filter_edit_title')
        : AppStrings.get('content_filter_add_title'),
      showConfirmAction: true,
      confirmText: AppStrings.get('content_filter_save_action'),
      confirmEnabled: this.canSaveDraft(),
      showSecondaryAction: this.editingId.length > 0,
      secondaryText: AppStrings.get('content_filter_remove_local_action'),
      onClose: (): void => {
        this.editorShown = false
      },
      onConfirm: (): void => {
        this.saveDraft()
      },
      onSecondary: (): void => {
        this.confirmRemove()
      },
    }) {
      ListItem() {
        NextNGroupedListSection({ inset: 0 }) {
          NextNListRow({
            leadingIcon: this.typeIcon(this.draftType),
            title: AppStrings.get('content_filter_target_title'),
            trailingText: this.typeLabel(this.draftType),
            trailingDropdown: true,
            dropdownMenuEnabled: true,
            dropdownMenuBuilder: (select: (action: () => void) => void): void => {
              this.FilterTypeMenu(select)
            },
            accessibilityLabel: AppStrings.get('content_filter_target_a11y')
              .replace('%s', this.typeLabel(this.draftType)),
          })
          this.RowDivider()
          NextNListRow({
            leadingIcon: $r('sys.symbol.checkmark_circle'),
            title: AppStrings.get('content_filter_enabled_title'),
            accessibilityLabel: AppStrings.get('content_filter_enabled_title'),
            hasSwitch: true,
            checked: this.draftEnabled,
            showChevron: false,
            onAction: (): void => {
              this.draftEnabled = !this.draftEnabled
            },
            onSwitchChange: (value: boolean): void => {
              this.draftEnabled = value
            },
          })
          this.RowDivider()
          NextNListRow({
            leadingIcon: $r('sys.symbol.textformat'),
            title: AppStrings.get('content_filter_regex_title'),
            subtitle: AppStrings.get('content_filter_regex_subtitle'),
            accessibilityLabel: AppStrings.get('content_filter_regex_title'),
            hasSwitch: true,
            checked: this.draftRegex,
            showChevron: false,
            onAction: (): void => {
              this.draftRegex = !this.draftRegex
            },
            onSwitchChange: (value: boolean): void => {
              this.draftRegex = value
            },
          })
        }
      }
      ListItem() {
        NextNGroupedListSection({ inset: 0 }) {
          Column({ space: ThemeTokens.SPACE_SM }) {
            Text(AppStrings.get('content_filter_text_label'))
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
              .width('100%')
            TextArea({ text: this.draftText, placeholder: AppStrings.get('content_filter_text_placeholder') })
              .width('100%')
              .backgroundColor(Color.Transparent)
              .onChange((value: string): void => {
                this.draftText = value
              })
            if (!this.draftRegexValid()) {
              Text(AppStrings.get('content_filter_regex_invalid'))
                .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                .fontColor(Color.Red)
                .width('100%')
            }
          }
          .padding(ThemeTokens.SPACE_MD)
          .width('100%')
        }
      }
    }
  }

  build() {
    Column() {
      if (this.isRestoring && !this.filters.isRestored) {
        PageEmptyState({ message: AppStrings.get('content_filters_loading') })
      } else {
        SecondaryListScaffold({
          scroller: this.scroller,
          bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
          alwaysEnableEdgeSpring: true,
        }) {
          ListItem() {
            this.RulesGroup()
          }
          if (this.errorMessage.length > 0) {
            ListItem() {
              Text(this.errorMessage)
                .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
                .fontColor(Color.Red)
                .width('100%')
                .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
            }
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE_SUB)
    .bindSheet($$this.editorShown, this.RulesEditorSheet(), appSheetOptions({
      detents: [SheetSize.LARGE],
      showClose: false,
    }))
  }
}
