import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  LLM_SOURCE_TYPE_OPENAI_COMPATIBLE,
  LlmSourceProfile,
  LlmSourceProfileRepository,
  LlmSourceProfilesState,
  NextNGroupedListSection,
  NextNListRow,
  SecondaryListScaffold,
  ThemeTokens,
  connectLlmSourceProfiles,
  generateLlmSourceProfileId,
} from 'shared'

/**
 * NextE's LlmSourceManagerPage adapted to NextN: the source list, empty
 * state, and "add source" surface are preserved. The add menu is reduced to
 * OpenAI compatible API only because NextN has no Codex OAuth service.
 */
@ComponentV2
export struct LlmSourceManagerPage {
  @Local sources: LlmSourceProfilesState = connectLlmSourceProfiles()
  @Local creating: boolean = false
  @Param scroller: Scroller = new Scroller()
  @Event onOpenSource?: (sourceProfileId: string) => void

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private sourceTypeText(): string {
    return AppStrings.get('llm_source_type_api')
  }

  private sourceDisplayName(sourceProfileId: string): string {
    const profile: LlmSourceProfile | null = this.sources.findById(sourceProfileId)
    return profile === null ? '' : profile.displayName
  }

  private openSource(sourceProfileId: string): void {
    if (this.onOpenSource) {
      this.onOpenSource(sourceProfileId)
    }
  }

  private createSource(): void {
    if (this.creating) {
      return
    }
    this.creating = true
    const profile: LlmSourceProfile = new LlmSourceProfile()
    profile.sourceProfileId = generateLlmSourceProfileId()
    profile.sourceType = LLM_SOURCE_TYPE_OPENAI_COMPATIBLE
    profile.displayName = AppStrings.get('llm_source_type_api')
    profile.baseUrl = 'https://api.openai.com'
    profile.capabilities.chatCompletions = true
    profile.capabilities.responses = true
    profile.capabilities.imageInput = true
    profile.capabilities.modelCatalog = true
    LlmSourceProfileRepository.upsert(this.context(), profile)
      .then((): void => {
        this.openSource(profile.sourceProfileId)
      })
      .catch((error: Error): void => {
        this.getUIContext().getPromptAction().showToast({
          message: AppStrings.format('llm_source_create_failed', [error.message]),
        })
      })
      .finally((): void => {
        this.creating = false
      })
  }

  @Builder
  private RowDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(ThemeTokens.DIVIDER)
      .margin({ left: ThemeTokens.SPACE_MD })
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
            if (this.sources.profiles.length === 0) {
              NextNListRow({
                leadingIcon: $r('sys.symbol.cloud'),
                title: AppStrings.get('llm_sources_empty'),
                subtitle: AppStrings.get('llm_sources_empty_hint'),
                showChevron: false,
              })
            } else {
              ForEach(
                this.sources.profiles,
                (profile: LlmSourceProfile, index: number) => {
                  if (index > 0) {
                    this.RowDivider()
                  }
                  NextNListRow({
                    leadingIcon: $r('sys.symbol.cloud'),
                    title: this.sourceDisplayName(profile.sourceProfileId),
                    subtitle: this.sourceTypeText(),
                    onAction: (): void => {
                      this.openSource(profile.sourceProfileId)
                    },
                  })
                },
                (profile: LlmSourceProfile) => profile.sourceProfileId,
              )
            }
          }
        }
        ListItem() {
          NextNGroupedListSection() {
            NextNListRow({
              leadingIcon: $r('sys.symbol.plus'),
              title: AppStrings.get('llm_source_add'),
              subtitle: AppStrings.get('llm_source_add_hint'),
              trailingText: this.creating ? AppStrings.get('common_loading') : '',
              showChevron: false,
              isEnabled: !this.creating,
              onAction: (): void => {
                this.createSource()
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
