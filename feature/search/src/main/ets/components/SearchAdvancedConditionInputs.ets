import {
  AppStrings,
  NextNGroupedListSection,
  NextNListRow,
  NhSearchUploadedUnit,
  ThemeTokens,
} from 'shared'
import { appMenuOptions } from 'shared'
import { SymbolGlyphModifier } from '@kit.ArkUI'

const ADVANCED_RANGE_INPUT_WIDTH: number = 84
const ADVANCED_RANGE_INPUT_HEIGHT: number = 36

/**
 * Advanced-search text inputs live in their own component so typing mutates
 * only this local draft state. Keeping them in page-level @Builder + @Local
 * state rebuilt the whole search sheet on every character, which dropped the
 * TextInput focus and dismissed the IME (NextE hosts these controls in the
 * standalone AdvancedSearchControls component).
 */
@ComponentV2
export struct SearchAdvancedConditionInputs {
  @Param tagNamespace: string = 'tag'
  @Param tagExcluded: boolean = false
  @Param uploadedUnit: NhSearchUploadedUnit = NhSearchUploadedUnit.DAY
  @Param errorScope: string = ''
  @Param errorMessage: string = ''
  @Event onNamespaceChange?: (namespace: string) => void
  @Event onExcludedChange?: (excluded: boolean) => void
  @Event onUnitChange?: (unit: NhSearchUploadedUnit) => void
  @Event onTagAdd?: (text: string) => boolean
  @Event onPagesAdd?: (minimumText: string, maximumText: string) => boolean
  @Event onUploadedAdd?: (minimumText: string, maximumText: string) => boolean
  @Event onClearError?: (scope: string) => void
  @Local tagText: string = ''
  @Local pageMinimumText: string = ''
  @Local pageMaximumText: string = ''
  @Local uploadedMinimumText: string = ''
  @Local uploadedMaximumText: string = ''
  @Local tagNamespaceMenuShown: boolean = false
  @Local tagModeMenuShown: boolean = false
  @Local uploadedUnitMenuShown: boolean = false

  private tagNamespaceLabel(namespace: string): string {
    switch (namespace) {
      case 'parody':
        return AppStrings.get('search_advanced_type_parody')
      case 'character':
        return AppStrings.get('search_advanced_type_character')
      case 'artist':
        return AppStrings.get('search_advanced_type_artist')
      case 'group':
        return AppStrings.get('search_advanced_type_group')
      case 'category':
        return AppStrings.get('search_advanced_type_category')
      default:
        return AppStrings.get('search_advanced_type_tag')
    }
  }

  private tagModeLabel(excluded: boolean): string {
    return excluded
      ? AppStrings.get('search_advanced_exclude')
      : AppStrings.get('search_advanced_include')
  }

  private uploadedUnitLabel(unit: NhSearchUploadedUnit): string {
    switch (unit) {
      case NhSearchUploadedUnit.HOUR:
        return AppStrings.get('search_advanced_unit_hour')
      case NhSearchUploadedUnit.WEEK:
        return AppStrings.get('search_advanced_unit_week')
      case NhSearchUploadedUnit.MONTH:
        return AppStrings.get('search_advanced_unit_month')
      case NhSearchUploadedUnit.YEAR:
        return AppStrings.get('search_advanced_unit_year')
      default:
        return AppStrings.get('search_advanced_unit_day')
    }
  }

  private parsePositive(value: string): number {
    const trimmed: string = value.trim()
    if (!/^[0-9]+$/.test(trimmed)) {
      return 0
    }
    const parsed: number = Number.parseInt(trimmed, 10)
    return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : 0
  }

  private hasRange(minimumText: string, maximumText: string): boolean {
    return this.parsePositive(minimumText) > 0 || this.parsePositive(maximumText) > 0
  }

  private clearError(scope: string): void {
    if (this.errorScope === scope && this.errorMessage.length > 0 && this.onClearError) {
      this.onClearError(scope)
    }
  }

  private addTag(): void {
    if (this.onTagAdd && this.onTagAdd(this.tagText)) {
      this.tagText = ''
    }
  }

  private addPages(): void {
    if (this.onPagesAdd && this.onPagesAdd(this.pageMinimumText, this.pageMaximumText)) {
      this.pageMinimumText = ''
      this.pageMaximumText = ''
    }
  }

  private addUploaded(): void {
    if (this.onUploadedAdd && this.onUploadedAdd(this.uploadedMinimumText, this.uploadedMaximumText)) {
      this.uploadedMinimumText = ''
      this.uploadedMaximumText = ''
    }
  }

  @Builder
  private ConditionError(scope: string) {
    if (this.errorScope === scope && this.errorMessage.length > 0) {
      Text(this.errorMessage)
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(Color.Red)
        .width('100%')
    }
  }

  @Builder
  private SearchOptionDivider() {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.ohos_id_color_list_separator'))
      .margin({ left: ThemeTokens.SPACE_MD })
  }

  @Builder
  private TagNameInput() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Text(AppStrings.get('search_advanced_tag_name'))
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
        .width('100%')
      TextInput({
        text: this.tagText,
        placeholder: AppStrings.get('search_advanced_tag_placeholder'),
      })
        .width('100%')
        .height(44)
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .backgroundColor(ThemeTokens.CARD_BACKGROUND)
        .borderRadius(ThemeTokens.LIST_ROW_RADIUS)
        .onChange((value: string): void => {
          this.tagText = value
          this.clearError('tag')
        })
        .onSubmit((): void => {
          this.addTag()
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: ThemeTokens.SPACE_MD,
      right: ThemeTokens.SPACE_MD,
      top: ThemeTokens.SPACE_SM,
      bottom: ThemeTokens.SPACE_SM,
    })
  }

  @Builder
  private RangeInput(value: string, accessibilityLabel: string, onChange: (value: string) => void) {
    TextInput({
      text: value,
      placeholder: AppStrings.get('filter_any'),
    })
      .type(InputType.Number)
      .inputFilter('^[0-9]*$')
      .textAlign(TextAlign.Center)
      .width(ADVANCED_RANGE_INPUT_WIDTH)
      .height(ADVANCED_RANGE_INPUT_HEIGHT)
      .fontSize(ThemeTokens.FONT_SIZE_BODY)
      .backgroundColor(ThemeTokens.SURFACE_SUB)
      .borderRadius(ThemeTokens.RADIUS_MD)
      .accessibilityDescription(accessibilityLabel)
      .onChange(onChange)
  }

  @Builder
  private PageRangeSuffix() {
    Row({ space: ThemeTokens.SPACE_SM }) {
      this.RangeInput(this.pageMinimumText, AppStrings.get('search_advanced_pages_minimum'),
        (value: string): void => {
          this.pageMinimumText = value
          this.clearError('pages')
        })
      Text('-')
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_TERTIARY)
      this.RangeInput(this.pageMaximumText, AppStrings.get('search_advanced_pages_maximum'),
        (value: string): void => {
          this.pageMaximumText = value
          this.clearError('pages')
        })
    }
    .alignItems(VerticalAlign.Center)
    .padding({ left: ThemeTokens.SPACE_SM, right: ThemeTokens.SPACE_MD })
  }

  @Builder
  private UploadedRangeSuffix() {
    Row({ space: ThemeTokens.SPACE_SM }) {
      this.RangeInput(this.uploadedMinimumText, AppStrings.get('search_advanced_uploaded_minimum'),
        (value: string): void => {
          this.uploadedMinimumText = value
          this.clearError('uploaded')
        })
      Text('-')
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_TERTIARY)
      this.RangeInput(this.uploadedMaximumText, AppStrings.get('search_advanced_uploaded_maximum'),
        (value: string): void => {
          this.uploadedMaximumText = value
          this.clearError('uploaded')
        })
    }
    .alignItems(VerticalAlign.Center)
    .padding({ left: ThemeTokens.SPACE_SM, right: ThemeTokens.SPACE_MD })
  }

  @Builder
  private TagNamespaceMenuItem(namespace: string) {
    MenuItem({
      content: this.tagNamespaceLabel(namespace),
      symbolEndIcon: this.tagNamespace === namespace
        ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
        : undefined,
    }).onClick((): void => {
      if (this.onNamespaceChange) {
        this.onNamespaceChange(namespace)
      }
      this.tagNamespaceMenuShown = false
    })
  }

  @Builder
  private TagNamespaceMenu() {
    Menu() {
      this.TagNamespaceMenuItem('tag')
      this.TagNamespaceMenuItem('parody')
      this.TagNamespaceMenuItem('character')
      this.TagNamespaceMenuItem('artist')
      this.TagNamespaceMenuItem('group')
      this.TagNamespaceMenuItem('category')
    }
  }

  @Builder
  private TagModeMenuItem(excluded: boolean) {
    MenuItem({
      content: this.tagModeLabel(excluded),
      symbolEndIcon: this.tagExcluded === excluded
        ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
        : undefined,
    }).onClick((): void => {
      if (this.onExcludedChange) {
        this.onExcludedChange(excluded)
      }
      this.tagModeMenuShown = false
    })
  }

  @Builder
  private TagModeMenu() {
    Menu() {
      this.TagModeMenuItem(false)
      this.TagModeMenuItem(true)
    }
  }

  @Builder
  private UploadedUnitMenuItem(unit: NhSearchUploadedUnit) {
    MenuItem({
      content: this.uploadedUnitLabel(unit),
      symbolEndIcon: this.uploadedUnit === unit
        ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
        : undefined,
    }).onClick((): void => {
      if (this.onUnitChange) {
        this.onUnitChange(unit)
      }
      this.uploadedUnitMenuShown = false
    })
  }

  @Builder
  private UploadedUnitMenu() {
    Menu() {
      this.UploadedUnitMenuItem(NhSearchUploadedUnit.HOUR)
      this.UploadedUnitMenuItem(NhSearchUploadedUnit.DAY)
      this.UploadedUnitMenuItem(NhSearchUploadedUnit.WEEK)
      this.UploadedUnitMenuItem(NhSearchUploadedUnit.MONTH)
      this.UploadedUnitMenuItem(NhSearchUploadedUnit.YEAR)
    }
  }

  build() {
    Column({ space: ThemeTokens.SPACE_MD }) {
      NextNGroupedListSection() {
        NextNListRow({
          title: AppStrings.get('search_advanced_type'),
          trailingText: this.tagNamespaceLabel(this.tagNamespace),
          trailingDropdown: true,
          accessibilityLabel: AppStrings.get('search_advanced_type'),
          onAction: (): void => {
            this.tagNamespaceMenuShown = true
          },
        })
          .bindMenu(this.tagNamespaceMenuShown, this.TagNamespaceMenu, appMenuOptions({
            placement: Placement.BottomRight,
            onDisappear: (): void => {
              this.tagNamespaceMenuShown = false
            },
          }))
        this.SearchOptionDivider()
        NextNListRow({
          title: AppStrings.get('search_advanced_match'),
          trailingText: this.tagModeLabel(this.tagExcluded),
          trailingDropdown: true,
          accessibilityLabel: AppStrings.get('search_advanced_match'),
          onAction: (): void => {
            this.tagModeMenuShown = true
          },
        })
          .bindMenu(this.tagModeMenuShown, this.TagModeMenu, appMenuOptions({
            placement: Placement.BottomRight,
            onDisappear: (): void => {
              this.tagModeMenuShown = false
            },
          }))
        this.SearchOptionDivider()
        this.TagNameInput()
        this.SearchOptionDivider()
        NextNListRow({
          title: AppStrings.get('search_advanced_add_tag'),
          trailingActionText: AppStrings.get('search_advanced_add'),
          showChevron: false,
          accessibilityLabel: AppStrings.get('search_advanced_add_tag'),
          onAction: (): void => {
            this.addTag()
          },
          onTrailingAction: (): void => {
            this.addTag()
          },
        })
      }
      this.ConditionError('tag')

      NextNGroupedListSection() {
        NextNListRow({
          title: AppStrings.get('search_advanced_pages'),
          showChevron: false,
          useCustomTrailing: true,
          customTrailing: (): void => {
            this.PageRangeSuffix()
          },
          accessibilityLabel: AppStrings.get('search_advanced_pages'),
        })
        this.SearchOptionDivider()
        NextNListRow({
          title: AppStrings.get('search_advanced_add_pages'),
          trailingActionText: AppStrings.get('search_advanced_add'),
          showChevron: false,
          isEnabled: this.hasRange(this.pageMinimumText, this.pageMaximumText),
          accessibilityLabel: AppStrings.get('search_advanced_add_pages'),
          onAction: (): void => {
            this.addPages()
          },
          onTrailingAction: (): void => {
            this.addPages()
          },
        })
      }
      this.ConditionError('pages')

      NextNGroupedListSection() {
        NextNListRow({
          title: AppStrings.get('search_advanced_unit'),
          trailingText: this.uploadedUnitLabel(this.uploadedUnit),
          trailingDropdown: true,
          accessibilityLabel: AppStrings.get('search_advanced_unit'),
          onAction: (): void => {
            this.uploadedUnitMenuShown = true
          },
        })
          .bindMenu(this.uploadedUnitMenuShown, this.UploadedUnitMenu, appMenuOptions({
            placement: Placement.BottomRight,
            onDisappear: (): void => {
              this.uploadedUnitMenuShown = false
            },
          }))
        this.SearchOptionDivider()
        NextNListRow({
          title: AppStrings.get('search_advanced_uploaded'),
          showChevron: false,
          useCustomTrailing: true,
          customTrailing: (): void => {
            this.UploadedRangeSuffix()
          },
          accessibilityLabel: AppStrings.get('search_advanced_uploaded'),
        })
        this.SearchOptionDivider()
        NextNListRow({
          title: AppStrings.get('search_advanced_add_uploaded'),
          trailingActionText: AppStrings.get('search_advanced_add'),
          showChevron: false,
          isEnabled: this.hasRange(this.uploadedMinimumText, this.uploadedMaximumText),
          accessibilityLabel: AppStrings.get('search_advanced_add_uploaded'),
          onAction: (): void => {
            this.addUploaded()
          },
          onTrailingAction: (): void => {
            this.addUploaded()
          },
        })
      }
      this.ConditionError('uploaded')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
