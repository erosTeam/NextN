import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  NextNGroupedListSection,
  NextNListRow,
  NextNModalScaffold,
  ReaderPresentationService,
  ReaderPresentationState,
  NhReaderSuperResolutionModel,
  ReaderSuperResolutionModelDefinition,
  ReaderSuperResolutionModelService,
  SecondaryListScaffold,
  ThemeTokens,
  connectReaderPresentation,
} from 'shared'

/**
 * Owns explicit private Reader-model downloads. The Reader settings surface
 * owns the selected installed model; this page only manages model files.
 */
@ComponentV2
export struct ReaderSuperResolutionModelsPage {
  @Local readerPresentation: ReaderPresentationState = connectReaderPresentation()
  @Local installedModels: NhReaderSuperResolutionModel[] = []
  @Local modelChanging: string = ''
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
    this.installedModels = await ReaderSuperResolutionModelService.installedModels(this.context())
  }

  private isModelInstalled(model: NhReaderSuperResolutionModel): boolean {
    for (let index: number = 0; index < this.installedModels.length; index++) {
      if (this.installedModels[index] === model) {
        return true
      }
    }
    return false
  }

  private modelTitle(definition: ReaderSuperResolutionModelDefinition): string {
    return AppStrings.get(definition.labelStringKey)
  }

  private modelActionLabel(model: NhReaderSuperResolutionModel): string {
    if (this.modelChanging === model) {
      return AppStrings.get('settings_reader_enhancement_model_downloading')
    }
    return this.isModelInstalled(model)
      ? AppStrings.get('settings_reader_enhancement_model_remove_action')
      : AppStrings.get('settings_reader_enhancement_model_download')
  }

  private notifyModelsChanged(): void {
    if (this.onModelsChanged) {
      this.onModelsChanged()
    }
  }

  private async installModel(model: NhReaderSuperResolutionModel): Promise<void> {
    if (this.modelChanging.length > 0 || this.isModelInstalled(model)) {
      return
    }
    this.modelChanging = model
    this.errorMessage = ''
    try {
      await ReaderSuperResolutionModelService.install(this.context(), model)
      await this.refreshInstallState()
      this.notifyModelsChanged()
    } catch (_error) {
      this.errorMessage = AppStrings.get('settings_reader_enhancement_model_download_failed')
    } finally {
      this.modelChanging = ''
    }
  }

  private confirmRemoveModel(definition: ReaderSuperResolutionModelDefinition): void {
    if (this.modelChanging.length > 0 || !this.isModelInstalled(definition.id)) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('settings_reader_enhancement_model_remove_title'),
      message: AppStrings.format('settings_reader_enhancement_model_remove_message', [
        this.modelTitle(definition),
      ]),
      primaryButton: {
        value: AppStrings.get('common_cancel'),
        action: (): void => {},
      },
      secondaryButton: {
        value: AppStrings.get('settings_reader_enhancement_model_remove_action'),
        fontColor: Color.Red,
        action: (): void => {
          this.removeModel(definition.id).catch((): void => {})
        },
      },
    })
  }

  private async removeModel(model: NhReaderSuperResolutionModel): Promise<void> {
    if (this.modelChanging.length > 0 || !this.isModelInstalled(model)) {
      return
    }
    this.modelChanging = model
    this.errorMessage = ''
    try {
      const installed: NhReaderSuperResolutionModel[] = await ReaderSuperResolutionModelService.installedModels(
        this.context(),
      )
      let replacement: NhReaderSuperResolutionModel | null = null
      for (let index: number = 0; index < installed.length; index++) {
        if (installed[index] !== model) {
          replacement = installed[index]
          break
        }
      }
      if (this.readerPresentation.superResolutionModel === model && replacement !== null) {
        await ReaderPresentationService.setSuperResolutionModel(this.context(), replacement)
      } else if (this.readerPresentation.superResolutionModel === model &&
        this.readerPresentation.superResolutionEnabled) {
        await ReaderPresentationService.setSuperResolutionEnabled(this.context(), false)
      }
      ReaderSuperResolutionModelService.remove(this.context(), model)
      await this.refreshInstallState()
      this.notifyModelsChanged()
    } catch (_error) {
      this.errorMessage = AppStrings.get('settings_reader_enhancement_model_remove_failed')
    } finally {
      this.modelChanging = ''
    }
  }

  @Builder
  private ModelGroup() {
    NextNGroupedListSection() {
      ForEach(
        ReaderSuperResolutionModelService.definitions(),
        (definition: ReaderSuperResolutionModelDefinition, index: number) => {
          NextNListRow({
            leadingIcon: $r('sys.symbol.lightbulb'),
            title: this.modelTitle(definition),
            subtitle: AppStrings.get(definition.hintStringKey),
            trailingActionText: this.modelActionLabel(definition.id),
            showChevron: false,
            isEnabled: this.modelChanging.length === 0,
            trailingActionDestructive: this.isModelInstalled(definition.id),
            accessibilityLabel: AppStrings.format('settings_reader_enhancement_model_a11y', [
              this.modelTitle(definition),
              this.modelActionLabel(definition.id),
            ]),
            onTrailingAction: (): void => {
              if (this.isModelInstalled(definition.id)) {
                this.confirmRemoveModel(definition)
              } else {
                this.installModel(definition.id).catch((): void => {})
              }
            },
          })
          if (index < ReaderSuperResolutionModelService.definitions().length - 1) {
            Divider()
              .strokeWidth(0.5)
              .color(ThemeTokens.DIVIDER)
              .margin({ left: ThemeTokens.SPACE_MD })
          }
        },
        (definition: ReaderSuperResolutionModelDefinition): string => definition.id,
      )
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
