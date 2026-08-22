import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import {
  AppStrings,
  NextNGroupedListSection,
  NextNListRow,
  NhTagTranslationStatus,
  SecondaryListScaffold,
  TAG_TRANSLATION_UPDATE_EVERY_START,
  TAG_TRANSLATION_UPDATE_MANUAL,
  TagTranslationSettings,
  TagTranslationSettingsState,
  TagDictionaryUpdateAttempt,
  TagDictionaryUpdateFailure,
  TagTranslationRepository,
  ThemeTokens,
  connectTagTranslationSettings,
  releaseTagTranslationVersionLabel,
} from 'shared'

/**
 * Presentation-only failure codes. TagTranslationUpdateService deliberately
 * keeps its transport and parsing failures raw for diagnostics; this page
 * maps the user-visible result at this boundary instead of treating protocol
 * text as localized copy.
 */
class TagDictionaryUiErrorCode {
  static readonly DICTIONARY_ASSET: string = 'dictionary_asset'
  static readonly CONTENT_VALIDATION: string = 'content_validation'
  static readonly LOCAL_STORAGE: string = 'local_storage'
}

/**
 * NextE keeps the tag-translation capability under its own 标签翻译
 * destination: the enable switch, the installed 翻译数据库 status, and the
 * 立即更新 action share one surface instead of being flattened into
 * Advanced beside unrelated translation consumers.
 */
@ComponentV2
export struct TagTranslationSettingsPage {
  @Local tagDictionaryStatus: NhTagTranslationStatus = new NhTagTranslationStatus()
  @Local tagDictionaryRowCount: number = 0
  @Local tagDictionaryStatusKnown: boolean = false
  @Local isUpdatingTagDictionary: boolean = false
  @Local isDeletingTagDictionary: boolean = false
  @Local tagDictionaryError: string = ''
  @Local tagSettings: TagTranslationSettingsState = connectTagTranslationSettings()
  @Param scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.loadTagDictionaryStatus()
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private toggleStateLabel(enabled: boolean): string {
    return AppStrings.get(enabled ? 'settings_toggle_on' : 'settings_toggle_off')
  }

  private setEnabled(value: boolean): void {
    TagTranslationSettings.setEnabled(this.context(), value)
      .then((): void => {
        if (value && this.tagDictionaryRowCount <= 0) {
          this.updateTagDictionary()
        }
      })
      .catch((): void => {})
  }

  private async loadTagDictionaryStatus(): Promise<void> {
    this.tagDictionaryStatusKnown = false
    try {
      this.applyTagDictionaryStatus(await TagTranslationRepository.status(this.context()))
    } catch (_error) {
      this.tagDictionaryError = AppStrings.get('settings_tag_translation_status_unavailable')
    }
  }

  private async updateTagDictionary(): Promise<void> {
    if (this.isUpdatingTagDictionary) {
      return
    }
    this.isUpdatingTagDictionary = true
    this.tagDictionaryError = ''
    try {
      const count: number = await TagTranslationSettings.updateNow(this.context())
      this.tagDictionaryRowCount = count
      this.tagDictionaryStatusKnown = true
    } catch (error) {
      this.tagDictionaryError = this.tagDictionaryErrorMessage(error as Error)
    } finally {
      this.isUpdatingTagDictionary = false
    }
  }

  private requestDeleteTagDictionary(): void {
    if (this.isDeletingTagDictionary || this.isUpdatingTagDictionary || this.tagDictionaryRowCount <= 0) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('settings_tag_translation_delete_confirm_title'),
      message: AppStrings.get('settings_tag_translation_delete_confirm_message'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('common_delete'),
        fontColor: Color.Red,
        action: (): void => {
          this.deleteTagDictionary()
        },
      },
    })
  }

  private async deleteTagDictionary(): Promise<void> {
    if (this.isDeletingTagDictionary) {
      return
    }
    this.isDeletingTagDictionary = true
    this.tagDictionaryError = ''
    try {
      await TagTranslationRepository.clear(this.context())
      await this.loadTagDictionaryStatus()
    } catch (_error) {
      this.tagDictionaryError = AppStrings.get('settings_tag_translation_error_update')
    } finally {
      this.isDeletingTagDictionary = false
    }
  }

  private tagDictionaryErrorMessage(error: Error): string {
    if (!(error instanceof TagDictionaryUpdateFailure)) {
      return AppStrings.get('settings_tag_translation_error_update')
    }
    const failure: TagDictionaryUpdateFailure = error as TagDictionaryUpdateFailure
    const phase: string = this.tagDictionaryPhaseLabel(failure.phase)
    const attempts: string = this.tagDictionaryAttemptsLabel(failure.attempts)
    const retained: string = failure.dictionaryRetained
      ? AppStrings.get('settings_tag_translation_error_retained')
      : ''
    if (attempts.length === 0) {
      return AppStrings.format('settings_tag_translation_error_details_without_attempts', [phase, retained]).trim()
    }
    return AppStrings.format('settings_tag_translation_error_details', [phase, attempts, retained]).trim()
  }

  private tagDictionaryPhaseLabel(phase: string): string {
    switch (phase) {
      case TagDictionaryUiErrorCode.DICTIONARY_ASSET:
        return AppStrings.get('settings_tag_translation_error_phase_asset')
      case TagDictionaryUiErrorCode.CONTENT_VALIDATION:
        return AppStrings.get('settings_tag_translation_error_phase_content')
      case TagDictionaryUiErrorCode.LOCAL_STORAGE:
        return AppStrings.get('settings_tag_translation_error_phase_local')
      default:
        return AppStrings.get('settings_tag_translation_error_phase_update')
    }
  }

  private tagDictionaryAttemptsLabel(attempts: TagDictionaryUpdateAttempt[]): string {
    const labels: string[] = []
    for (let index: number = 0; index < attempts.length; index++) {
      const label: string = this.tagDictionaryAttemptLabel(attempts[index])
      if (label.length > 0 && labels.indexOf(label) < 0) {
        labels.push(label)
      }
    }
    return labels.join(AppStrings.get('settings_tag_translation_error_separator'))
  }

  private tagDictionaryAttemptLabel(attempt: TagDictionaryUpdateAttempt): string {
    const source: string = attempt.source === 'direct'
      ? AppStrings.get('settings_tag_translation_error_source_direct')
      : attempt.source === 'mirror'
        ? AppStrings.get('settings_tag_translation_error_source_mirror')
        : ''
    if (attempt.outcome === 'http' && attempt.httpStatus > 0) {
      return source.length > 0
        ? AppStrings.format('settings_tag_translation_error_http', [source, attempt.httpStatus.toString()])
        : AppStrings.format('settings_tag_translation_error_http_unknown', [attempt.httpStatus.toString()])
    }
    if (attempt.outcome === 'transport') {
      return source.length > 0
        ? AppStrings.format('settings_tag_translation_error_transport', [source])
        : AppStrings.get('settings_tag_translation_error_transport_unknown')
    }
    return source.length > 0
      ? AppStrings.format('settings_tag_translation_error_invalid', [source])
      : AppStrings.get('settings_tag_translation_error_invalid_unknown')
  }

  private applyTagDictionaryStatus(status: NhTagTranslationStatus): void {
    this.tagDictionaryStatus = status
    this.tagDictionaryRowCount = status.rowCount
    this.tagSettings.version = status.version
    this.tagDictionaryStatusKnown = true
  }

  private versionText(): string {
    const display: string = releaseTagTranslationVersionLabel(this.tagSettings.version)
    return display.length > 0
      ? display
      : AppStrings.get('settings_tag_translation_no_version')
  }

  private updateModeText(): string {
    return this.tagSettings.updateMode === TAG_TRANSLATION_UPDATE_EVERY_START
      ? AppStrings.get('settings_tag_translation_update_every_start')
      : AppStrings.get('settings_tag_translation_update_manual')
  }

  private setUseCdn(value: boolean): void {
    TagTranslationSettings.setUseCdn(this.context(), value).catch((): void => {})
  }

  private setUpdateMode(mode: string): void {
    TagTranslationSettings.setUpdateMode(this.context(), mode).catch((): void => {})
  }

  private tagDictionaryStatusText(): string {
    if (this.isUpdatingTagDictionary) {
      return AppStrings.get('settings_tag_translation_updating')
    }
    if (!this.tagDictionaryStatusKnown) {
      return ''
    }
    return this.tagDictionaryRowCount > 0
      ? this.tagDictionaryRowCount.toString()
      : AppStrings.get('settings_tag_translation_not_installed')
  }

  @Builder
  private RowDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(ThemeTokens.DIVIDER)
      .margin({ left: ThemeTokens.SPACE_MD })
  }

  @Builder
  private UpdateModeMenu() {
    Menu() {
      MenuItem({
        content: AppStrings.get('settings_tag_translation_update_manual'),
        symbolEndIcon: this.tagSettings.updateMode === TAG_TRANSLATION_UPDATE_MANUAL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setUpdateMode(TAG_TRANSLATION_UPDATE_MANUAL)
      })
      MenuItem({
        content: AppStrings.get('settings_tag_translation_update_every_start'),
        symbolEndIcon: this.tagSettings.updateMode === TAG_TRANSLATION_UPDATE_EVERY_START
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setUpdateMode(TAG_TRANSLATION_UPDATE_EVERY_START)
      })
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
              leadingIcon: $r('sys.symbol.textformat'),
              title: AppStrings.get('settings_tag_translation_enable'),
              subtitle: AppStrings.get('settings_tag_translation_enable_hint'),
              hasSwitch: true,
              checked: this.tagSettings.enabled,
              showChevron: false,
              accessibilityLabel: AppStrings.format('settings_row_a11y', [
                AppStrings.get('settings_tag_translation_enable'),
                this.toggleStateLabel(this.tagSettings.enabled),
              ]),
              onAction: (): void => {
                this.setEnabled(!this.tagSettings.enabled)
              },
              onSwitchChange: (value: boolean): void => {
                this.setEnabled(value)
              },
            })
            this.RowDivider()
            NextNListRow({
              leadingIcon: $r('sys.symbol.externaldrive'),
              title: AppStrings.get('settings_tag_translation_local_title'),
              subtitle: this.versionText(),
              trailingText: this.tagDictionaryStatusText(),
              showChevron: false,
            })
            this.RowDivider()
            NextNListRow({
              leadingIcon: $r('sys.symbol.arrow_clockwise'),
              title: AppStrings.get('settings_tag_translation_update'),
              subtitle: AppStrings.get('settings_tag_translation_update_hint'),
              trailingText: this.isUpdatingTagDictionary ? AppStrings.get('settings_tag_translation_updating') : '',
              showChevron: false,
              isEnabled: !this.isUpdatingTagDictionary,
              onAction: (): void => {
                this.updateTagDictionary()
              },
            })
            this.RowDivider()
            NextNListRow({
              leadingIcon: $r('sys.symbol.trash'),
              title: AppStrings.get('settings_tag_translation_delete'),
              subtitle: AppStrings.get('settings_tag_translation_delete_hint'),
              showChevron: false,
              destructive: true,
              isEnabled: !this.isDeletingTagDictionary &&
                !this.isUpdatingTagDictionary &&
                this.tagDictionaryRowCount > 0,
              onAction: (): void => {
                this.requestDeleteTagDictionary()
              },
            })
          }
        }
        ListItem() {
          NextNGroupedListSection() {
            NextNListRow({
              leadingIcon: $r('sys.symbol.cloud'),
              title: AppStrings.get('settings_tag_translation_cdn'),
              subtitle: AppStrings.get('settings_tag_translation_cdn_hint'),
              hasSwitch: true,
              checked: this.tagSettings.useCdn,
              showChevron: false,
              accessibilityLabel: AppStrings.format('settings_row_a11y', [
                AppStrings.get('settings_tag_translation_cdn'),
                this.toggleStateLabel(this.tagSettings.useCdn),
              ]),
              onAction: (): void => {
                this.setUseCdn(!this.tagSettings.useCdn)
              },
              onSwitchChange: (value: boolean): void => {
                this.setUseCdn(value)
              },
            })
            this.RowDivider()
            NextNListRow({
              leadingIcon: $r('sys.symbol.clock'),
              title: AppStrings.get('settings_tag_translation_update_mode'),
              trailingText: this.updateModeText(),
              trailingDropdown: true,
              dropdownMenuEnabled: true,
              dropdownMenuBuilder: () => {
                this.UpdateModeMenu()
              },
              accessibilityLabel: AppStrings.format('settings_row_a11y', [
                AppStrings.get('settings_tag_translation_update_mode'),
                this.updateModeText(),
              ]),
            })
          }
        }
        if (this.tagDictionaryError.length > 0) {
          ListItem() {
            Text(this.tagDictionaryError)
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .padding({
                left: ThemeTokens.SPACE_MD,
                right: ThemeTokens.SPACE_MD,
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
