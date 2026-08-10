import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  NextNGroupedListSection,
  NextNListRow,
  NextNModalScaffold,
  ReaderPresentationService,
  ReaderPresentationState,
  ReaderSuperResolutionModelService,
  SecondaryListScaffold,
  ThemeTokens,
  connectReaderPresentation,
} from 'shared'

/**
 * Owns the one user-downloadable Reader enhancement model. The Reader settings
 * surface selects whether enhancement is active; this page owns only the
 * private model file and its destructive removal confirmation.
 */
@ComponentV2
export struct ReaderSuperResolutionModelsPage {
  @Local readerPresentation: ReaderPresentationState = connectReaderPresentation()
  @Local modelInstalled: boolean = false
  @Local modelChanging: boolean = false
  @Local errorMessage: string = ''
  @Param modal: boolean = false
  @Param scroller: Scroller = new Scroller()
  @Event onClose?: () => void
  @Event onModelsChanged?: () => void

  aboutToAppear(): void {
    this.refreshInstallState()
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private async refreshInstallState(): Promise<void> {
    this.modelInstalled = await ReaderSuperResolutionModelService.isInstalled(this.context())
  }

  private notifyModelsChanged(): void {
    if (this.onModelsChanged) {
      this.onModelsChanged()
    }
  }

  private async installModel(): Promise<void> {
    if (this.modelChanging || this.modelInstalled) {
      return
    }
    this.modelChanging = true
    this.errorMessage = ''
    try {
      await ReaderSuperResolutionModelService.install(this.context())
      this.modelInstalled = true
      this.notifyModelsChanged()
    } catch (_error) {
      this.errorMessage = AppStrings.get('settings_reader_enhancement_model_download_failed')
    } finally {
      this.modelChanging = false
    }
  }

  private confirmRemoveModel(): void {
    if (this.modelChanging || !this.modelInstalled) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('settings_reader_enhancement_model_remove_title'),
      message: AppStrings.get('settings_reader_enhancement_model_remove_message'),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('settings_reader_enhancement_model_remove_action'),
        fontColor: Color.Red,
        action: (): void => {
          this.removeModel()
        },
      },
    })
  }

  private async removeModel(): Promise<void> {
    if (this.modelChanging || !this.modelInstalled) {
      return
    }
    this.modelChanging = true
    this.errorMessage = ''
    try {
      if (this.readerPresentation.superResolutionEnabled) {
        await ReaderPresentationService.setSuperResolutionEnabled(this.context(), false)
      }
      ReaderSuperResolutionModelService.remove(this.context())
      this.modelInstalled = false
      this.notifyModelsChanged()
    } catch (_error) {
      this.errorMessage = AppStrings.get('settings_reader_enhancement_model_remove_failed')
    } finally {
      this.modelChanging = false
    }
  }

  @Builder
  private ModelGroup() {
    NextNGroupedListSection() {
      NextNListRow({
        leadingIcon: $r('sys.symbol.lightbulb'),
        title: AppStrings.get('settings_reader_enhancement_model_title'),
        subtitle: AppStrings.get('settings_reader_enhancement_model_hint'),
        trailingText: this.modelChanging
          ? AppStrings.get('settings_reader_enhancement_model_downloading')
          : this.modelInstalled
            ? AppStrings.get('settings_reader_enhancement_model_remove_action')
            : AppStrings.get('settings_reader_enhancement_model_download'),
        showChevron: false,
        isEnabled: !this.modelChanging,
        destructive: this.modelInstalled,
        accessibilityLabel: this.modelInstalled
          ? AppStrings.get('settings_reader_enhancement_model_remove_a11y')
          : AppStrings.get('settings_reader_enhancement_model_a11y'),
        onAction: (): void => {
          if (this.modelInstalled) {
            this.confirmRemoveModel()
          } else {
            this.installModel()
          }
        },
      })
    }
  }

  @Builder
  private ModelListItems() {
    ListItem() {
      this.ModelGroup()
    }
    if (this.errorMessage.length > 0) {
      ListItem() {
        Text(this.errorMessage)
          .width('100%')
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
      }
    }
  }

  build() {
    if (this.modal) {
      NextNModalScaffold({
        title: AppStrings.get('settings_reader_enhancement_models'),
        onClose: (): void => {
          if (this.onClose) {
            this.onClose()
          }
        },
      }) {
        this.ModelListItems()
      }
    } else {
      SecondaryListScaffold({
        scroller: this.scroller,
        bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
        alwaysEnableEdgeSpring: true,
      }) {
        this.ModelListItems()
      }
    }
  }
}
