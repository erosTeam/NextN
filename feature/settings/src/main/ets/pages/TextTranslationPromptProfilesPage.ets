import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  NextNGroupedListSection,
  NextNListRow,
  NextNSectionHeader,
  SecondaryListScaffold,
  TextTranslationPromptCatalog,
  TextTranslationPromptProfile,
  TextTranslationPromptProfilesState,
  ThemeTokens,
  connectTextTranslationPromptProfiles,
} from 'shared'

/**
 * Selects the shared AI-translation prompt profile for NextN. Built-ins render
 * read-only (tap opens the read-only detail); custom entries and the "new" row
 * open the editable detail. Selection and creation publish only through the
 * repository, so a failed write keeps the old selection and state mirror.
 */
@ComponentV2
export struct TextTranslationPromptProfilesPage {
  @Local private profiles: TextTranslationPromptProfilesState =
    connectTextTranslationPromptProfiles()
  @Param scroller: Scroller = new Scroller()
  @Event onOpenDetail?: (promptProfileId: string) => void
  @Event onOpenNew?: () => void

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private profileDisplayName(promptProfileId: string): string {
    return this.profiles.findById(promptProfileId)?.displayName ?? ''
  }

  @Builder
  private RowDivider() {
    Divider()
      .color(ThemeTokens.DIVIDER)
      .strokeWidth(0.5)
      .margin({ left: 56, right: 16 })
  }

  @Builder
  private CheckSuffix(profile: TextTranslationPromptProfile) {
    if (this.profiles.selectedPromptProfileId === profile.promptProfileId) {
      SymbolGlyph($r('sys.symbol.checkmark'))
        .fontSize(ThemeTokens.SYMBOL_SIZE_CONTROL)
        .fontColor([ThemeTokens.BRAND])
        .padding({ left: 8, right: 16 })
    }
  }

  @Builder
  private ProfileRow(profile: TextTranslationPromptProfile) {
    NextNListRow({
      title: this.profileDisplayName(profile.promptProfileId),
      leadingIcon: $r('sys.symbol.textformat'),
      showChevron: false,
      suffixPaddingRight: 0,
      useCustomTrailing: true,
      customTrailing: () => {
        this.CheckSuffix(profile)
      },
      onAction: () => {
        if (this.onOpenDetail) {
          this.onOpenDetail(profile.promptProfileId)
        }
      },
    })
  }

  build() {
    Column() {
      SecondaryListScaffold({
        scroller: this.scroller,
        bottomPadding: 24,
        alwaysEnableEdgeSpring: true,
      }) {
        ListItem() {
          NextNSectionHeader({ title: AppStrings.get('text_translation_prompt_builtin_group') })
        }
        .margin({ top: ThemeTokens.SPACE_XS })
        ListItem() {
          NextNGroupedListSection() {
            ForEach(
              TextTranslationPromptCatalog.builtInProfiles(),
              (profile: TextTranslationPromptProfile, index: number) => {
                if (index > 0) {
                  this.RowDivider()
                }
                this.ProfileRow(profile)
              },
              (profile: TextTranslationPromptProfile) => profile.promptProfileId,
            )
          }
        }
        if (this.profiles.customProfiles.length > 0) {
          ListItem() {
            NextNSectionHeader({ title: AppStrings.get('text_translation_prompt_custom_group') })
          }
          .margin({ top: ThemeTokens.SPACE_MD })
          ListItem() {
            NextNGroupedListSection() {
              ForEach(
                this.profiles.customProfiles,
                (profile: TextTranslationPromptProfile, index: number) => {
                  if (index > 0) {
                    this.RowDivider()
                  }
                  this.ProfileRow(profile.copy())
                },
                (profile: TextTranslationPromptProfile) => profile.promptProfileId,
              )
            }
          }
        }
        ListItem() {
          NextNGroupedListSection() {
            NextNListRow({
              title: AppStrings.get('text_translation_prompt_new'),
              leadingIcon: $r('sys.symbol.plus'),
              showChevron: true,
              onAction: () => {
                if (this.onOpenNew) {
                  this.onOpenNew()
                }
              },
            })
          }
        }
        .margin({ top: ThemeTokens.SPACE_MD })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE_SUB)
  }
}

