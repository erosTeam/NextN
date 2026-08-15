import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import {
  AppStrings,
  COMMENT_TRANSLATION_DISPLAY_BILINGUAL,
  COMMENT_TRANSLATION_DISPLAY_REPLACE,
  CommentTranslationService,
  CommentTranslationSettings,
  CommentTranslationSettingsState,
  LLM_CONSUMER_COMMENT_TRANSLATION,
  LlmSourceProfile,
  LlmSourceProfilesState,
  NextNGroupedListSection,
  NextNListRow,
  SecondaryListScaffold,
  ThemeTokens,
  connectCommentTranslationSettings,
  connectLlmSourceProfiles,
  supportsCommentTranslation,
} from 'shared'
import { appMenuOptions } from 'shared'

/**
 * Dedicated comment-translation destination, matching NextE's
 * CommentTranslationSettingsPage: enable, auto-translate, display mode, the
 * comment consumer binding, and the translation cache.
 */
@ComponentV2
export struct CommentTranslationSettingsPage {
  @Local settings: CommentTranslationSettingsState = connectCommentTranslationSettings()
  @Local sources: LlmSourceProfilesState = connectLlmSourceProfiles()
  @Local displayMenuShown: boolean = false
  @Local cacheCount: number = 0
  @Local clearingCache: boolean = false
  @Param scroller: Scroller = new Scroller()
  @Event onOpenTranslationSource?: (consumerId: string) => void

  aboutToAppear(): void {
    this.refreshCacheCount()
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private toggleStateLabel(enabled: boolean): string {
    return AppStrings.get(enabled ? 'settings_toggle_on' : 'settings_toggle_off')
  }

  private setEnabled(value: boolean): void {
    CommentTranslationSettings.setEnabled(this.context(), value).catch((): void => {})
  }

  private setAutoTranslate(value: boolean): void {
    CommentTranslationSettings.setAutoTranslate(this.context(), value).catch((): void => {})
  }

  private setDisplayMode(value: string): void {
    CommentTranslationSettings.setDisplayMode(this.context(), value).catch((): void => {})
    this.displayMenuShown = false
  }

  private displayModeText(): string {
    return this.settings.displayMode === COMMENT_TRANSLATION_DISPLAY_BILINGUAL
      ? AppStrings.get('comment_translation_display_bilingual')
      : AppStrings.get('comment_translation_display_replace')
  }

  private commentSource(): LlmSourceProfile | null {
    const binding = this.sources.commentBinding
    if (!binding.configured()) {
      return null
    }
    const profile: LlmSourceProfile | null = this.sources.findById(binding.sourceProfileId)
    return profile !== null && supportsCommentTranslation(profile) ? profile : null
  }

  private selectedSourceText(): string {
    const profile: LlmSourceProfile | null = this.commentSource()
    return profile === null
      ? AppStrings.get('settings_translation_source_not_configured')
      : profile.displayName
  }

  private selectedModelText(): string {
    const binding = this.sources.commentBinding
    return binding.configured() && binding.modelId.length > 0
      ? binding.modelId
      : AppStrings.get('settings_translation_source_not_configured')
  }

  private async refreshCacheCount(): Promise<void> {
    try {
      this.cacheCount = (await CommentTranslationService.stat(this.context())).count
    } catch (_error) {
      this.cacheCount = 0
    }
  }

  private confirmClearCache(): void {
    if (this.clearingCache) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('comment_translation_clear_cache'),
      message: AppStrings.get('comment_translation_clear_cache_confirm'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('common_delete'),
        action: (): void => {
          this.clearCache()
        },
      },
    })
  }

  private async clearCache(): Promise<void> {
    if (this.clearingCache) {
      return
    }
    this.clearingCache = true
    try {
      await CommentTranslationService.clear(this.context())
      this.cacheCount = 0
      this.getUIContext().getPromptAction().showToast({
        message: AppStrings.get('comment_translation_cache_cleared'),
      })
    } catch (_error) {
      this.getUIContext().getPromptAction().showToast({
        message: AppStrings.get('comment_translation_clear_cache_failed'),
      })
    } finally {
      this.clearingCache = false
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
  private DisplayModeMenu() {
    Menu() {
      MenuItem({
        content: AppStrings.get('comment_translation_display_replace'),
        symbolEndIcon: this.settings.displayMode === COMMENT_TRANSLATION_DISPLAY_REPLACE
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setDisplayMode(COMMENT_TRANSLATION_DISPLAY_REPLACE)
      })
      MenuItem({
        content: AppStrings.get('comment_translation_display_bilingual'),
        symbolEndIcon: this.settings.displayMode === COMMENT_TRANSLATION_DISPLAY_BILINGUAL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick((): void => {
        this.setDisplayMode(COMMENT_TRANSLATION_DISPLAY_BILINGUAL)
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
              leadingIcon: $r('sys.symbol.translate'),
              title: AppStrings.get('comment_translation_enable'),
              subtitle: AppStrings.get('comment_translation_enable_hint'),
              hasSwitch: true,
              checked: this.settings.enabled,
              showChevron: false,
              accessibilityLabel: AppStrings.format('settings_row_a11y', [
                AppStrings.get('comment_translation_enable'),
                this.toggleStateLabel(this.settings.enabled),
              ]),
              onAction: (): void => {
                this.setEnabled(!this.settings.enabled)
              },
              onSwitchChange: (value: boolean): void => {
                this.setEnabled(value)
              },
            })
            this.RowDivider()
            NextNListRow({
              leadingIcon: $r('sys.symbol.clock'),
              title: AppStrings.get('comment_translation_auto'),
              subtitle: AppStrings.get('comment_translation_auto_hint'),
              hasSwitch: true,
              checked: this.settings.autoTranslate,
              showChevron: false,
              isEnabled: this.settings.enabled,
              accessibilityLabel: AppStrings.format('settings_row_a11y', [
                AppStrings.get('comment_translation_auto'),
                this.toggleStateLabel(this.settings.autoTranslate),
              ]),
              onAction: (): void => {
                this.setAutoTranslate(!this.settings.autoTranslate)
              },
              onSwitchChange: (value: boolean): void => {
                this.setAutoTranslate(value)
              },
            })
            this.RowDivider()
            Column() {
              NextNListRow({
                leadingIcon: $r('sys.symbol.textformat'),
                title: AppStrings.get('comment_translation_display_mode'),
                trailingText: this.displayModeText(),
                trailingDropdown: true,
                isEnabled: this.settings.enabled,
                accessibilityLabel: AppStrings.format('settings_row_a11y', [
                  AppStrings.get('comment_translation_display_mode'),
                  this.displayModeText(),
                ]),
                onAction: (): void => {
                  if (this.settings.enabled) {
                    this.displayMenuShown = true
                  }
                },
              })
            }
            .bindMenu(this.displayMenuShown, this.DisplayModeMenu, appMenuOptions({
              placement: Placement.BottomRight,
              onDisappear: (): void => {
                this.displayMenuShown = false
              },
            }))
          }
        }
        ListItem() {
          NextNGroupedListSection() {
            NextNListRow({
              leadingIcon: $r('sys.symbol.externaldrive'),
              title: AppStrings.get('settings_translation_source'),
              trailingText: this.selectedSourceText(),
              isEnabled: this.settings.enabled,
              accessibilityLabel: AppStrings.get('comment_translation_source_a11y'),
              onAction: (): void => {
                if (this.settings.enabled && this.onOpenTranslationSource) {
                  this.onOpenTranslationSource(LLM_CONSUMER_COMMENT_TRANSLATION)
                }
              },
            })
            this.RowDivider()
            NextNListRow({
              leadingIcon: $r('sys.symbol.arrow_down_circle'),
              title: AppStrings.get('settings_translation_source_model'),
              trailingText: this.selectedModelText(),
              isEnabled: this.settings.enabled,
              accessibilityLabel: AppStrings.get('comment_translation_model_a11y'),
              onAction: (): void => {
                if (this.settings.enabled && this.onOpenTranslationSource) {
                  this.onOpenTranslationSource(LLM_CONSUMER_COMMENT_TRANSLATION)
                }
              },
            })
          }
        }
        ListItem() {
          NextNGroupedListSection() {
            NextNListRow({
              leadingIcon: $r('sys.symbol.trash'),
              title: AppStrings.get('comment_translation_clear_cache'),
              subtitle: AppStrings.format('comment_translation_cache_entries', [this.cacheCount.toString()]),
              destructive: true,
              showChevron: false,
              isEnabled: !this.clearingCache,
              onAction: (): void => {
                this.confirmClearCache()
              },
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
