import { common } from '@kit.AbilityKit'
import { KeyboardAvoidMode, SymbolGlyphModifier } from '@kit.ArkUI'
import { HdsNavDestination } from '@kit.UIDesignKit'
import {
  AppStrings,
  HomeSubtabEditParams,
  HomeSubtabSettings,
  HomeSubtabState,
  HOME_SUBTAB_PRESENTATION_GLOBAL,
  NextNGroupedListSection,
  NextNListRow,
  NextNSectionHeader,
  NhBrowsePresentation,
  NhHomeSubtabKind,
  NhHomeSubtabProfile,
  NhSearchLanguage,
  NhSearchOptions,
  NhSearchQuery,
  NhSearchRangeRelation,
  NhSearchSort,
  NhSearchUploadedUnit,
  NhTagQuery,
  SecondaryListScaffold,
  ThemeTokens,
  connectHomeSubtabs,
  newHomeSubtabUuid,
  nextNHdsTitleBar,
} from 'shared'
import { appMenuOptions } from 'shared'
import { SearchAdvancedConditionInputs } from '../components/SearchAdvancedConditionInputs'
import { SearchConditionParser } from '../model/SearchConditionChip'

const LANGUAGES: NhSearchLanguage[] = [
  NhSearchLanguage.ALL,
  NhSearchLanguage.JAPANESE,
  NhSearchLanguage.CHINESE,
  NhSearchLanguage.ENGLISH,
  NhSearchLanguage.TRANSLATED,
]
const SORTS: NhSearchSort[] = [
  NhSearchSort.RECENT,
  NhSearchSort.POPULAR_TODAY,
  NhSearchSort.POPULAR_WEEK,
  NhSearchSort.POPULAR_MONTH,
  NhSearchSort.POPULAR_ALL_TIME,
]
const PRESENTATIONS: string[] = [
  HOME_SUBTAB_PRESENTATION_GLOBAL,
  NhBrowsePresentation.LIST,
  NhBrowsePresentation.SIMPLE_LIST,
  NhBrowsePresentation.COVER_GRID,
  NhBrowsePresentation.WATERFALL,
  NhBrowsePresentation.WATERFALL_COMPACT,
  NhBrowsePresentation.COVER_WALL,
]

/** Search-owned editor so it reuses the exact advanced condition component. */
@ComponentV2
export struct HomeSubtabEditPage {
  @Local homeSubtabs: HomeSubtabState = connectHomeSubtabs()
  @Local name: string = ''
  @Local query: string = ''
  @Local language: NhSearchLanguage = NhSearchLanguage.ALL
  @Local sort: NhSearchSort = NhSearchSort.RECENT
  @Local ignoreLocalUserTagFiltering: boolean = false
  @Local presentation: string = HOME_SUBTAB_PRESENTATION_GLOBAL
  @Local tagNamespace: string = 'tag'
  @Local uploadedUnit: NhSearchUploadedUnit = NhSearchUploadedUnit.DAY
  @Local conditionErrorScope: string = ''
  @Local conditionError: string = ''
  @Local languageMenuShown: boolean = false
  @Local sortMenuShown: boolean = false
  @Local presentationMenuShown: boolean = false
  @Local saving: boolean = false
  @Param edit: HomeSubtabEditParams = new HomeSubtabEditParams()
  @Param scroller: Scroller = new Scroller()
  @Param hideBackButton: boolean = false
  @Event onDone?: () => void
  private seeded: boolean = false
  private original: NhHomeSubtabProfile | null = null
  private nameDraft: string = ''

  aboutToAppear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
    this.seed()
  }

  aboutToDisappear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private seed(): void {
    if (this.seeded) {
      return
    }
    this.seeded = true
    const profile: NhHomeSubtabProfile | null = this.edit.profileUuid.length > 0
      ? this.homeSubtabs.find(this.edit.profileUuid)
      : null
    if (profile !== null && profile.isSearch() && !profile.isBuiltin()) {
      this.original = profile.copy()
      this.name = profile.name
      this.nameDraft = profile.name
      this.query = profile.query
      this.language = profile.language
      this.sort = profile.sort
      this.ignoreLocalUserTagFiltering = profile.ignoreLocalUserTagFiltering
      this.presentation = profile.presentation
      return
    }
    this.query = this.edit.seedQuery
    this.language = this.edit.seedLanguage
    this.sort = this.edit.seedSort
    this.ignoreLocalUserTagFiltering = this.edit.seedIgnoreLocalUserTagFiltering
  }

  private isCreate(): boolean {
    return this.original === null
  }

  private titleBar(): Record<string, Object> {
    const action: Record<string, Object> = {
      'label': AppStrings.get('home_subtab_save'),
      'icon': $r('sys.symbol.checkmark'),
      'isEnabled': !this.saving,
      'action': (): void => this.save(),
    }
    const item: Record<string, Object> = { 'content': action }
    const menuItems: Record<string, Object>[] = [item]
    const menu: Record<string, Object> = { 'value': menuItems, 'maxCount': 1 }
    const title: Record<string, Object> = {
      'mainTitle': AppStrings.get(this.isCreate() ? 'home_subtab_create_title' : 'home_subtab_edit_title'),
    }
    return nextNHdsTitleBar({ 'title': title, 'menu': menu })
  }

  private save(): void {
    if (this.saving) {
      return
    }
    const profile: NhHomeSubtabProfile = this.original === null
      ? new NhHomeSubtabProfile()
      : this.original.copy()
    profile.uuid = this.original === null ? newHomeSubtabUuid() : this.original.uuid
    profile.kind = NhHomeSubtabKind.SEARCH
    profile.name = this.nameDraft.trim()
    profile.query = this.query.trim()
    profile.language = this.language
    profile.sort = this.sort
    profile.ignoreLocalUserTagFiltering = this.ignoreLocalUserTagFiltering
    profile.presentation = this.presentation
    if (profile.name.length === 0 || !profile.hasEffectiveSearch()) {
      this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('home_subtab_validation') })
      return
    }
    this.saving = true
    const operation: Promise<boolean> = this.isCreate()
      ? HomeSubtabSettings.add(this.context(), profile)
      : HomeSubtabSettings.update(this.context(), profile)
    operation.then((saved: boolean): void => {
      if (saved && this.onDone) {
        this.onDone()
      }
    }).finally((): void => {
      this.saving = false
    })
  }

  private confirmDelete(): void {
    if (this.original === null || this.original.isBuiltin()) {
      return
    }
    const profileUuid: string = this.original.uuid
    this.getUIContext().showAlertDialog({
      title: $r('app.string.home_subtab_delete_title'),
      message: $r('app.string.home_subtab_delete_message'),
      primaryButton: { value: $r('app.string.common_cancel'), action: (): void => {} },
      secondaryButton: {
        value: $r('app.string.common_delete'),
        fontColor: Color.Red,
        action: (): void => {
          HomeSubtabSettings.remove(this.context(), profileUuid)
            .then((removed: boolean): void => {
              if (removed) {
                if (this.onDone) {
                  this.onDone()
                }
                return
              }
              this.getUIContext().getPromptAction().showToast({
                message: AppStrings.get('home_subtab_last_visible'),
              })
            })
            .catch((): void => {})
        },
      },
    })
  }

  private parsePositive(value: string): number {
    const trimmed: string = value.trim()
    if (!/^[0-9]+$/.test(trimmed)) {
      return 0
    }
    const parsed: number = Number.parseInt(trimmed, 10)
    return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : 0
  }

  private hasUnclosedQuote(value: string): boolean {
    let open: boolean = false
    for (let index: number = 0; index < value.length; index++) {
      if (value.charAt(index) === '"') {
        open = !open
      }
    }
    return open
  }

  private appendFragments(fragments: string[], scope: string): boolean {
    if (this.hasUnclosedQuote(this.query)) {
      this.setConditionError(scope, AppStrings.get('search_advanced_unclosed_quote'))
      return false
    }
    let next: string = this.query
    fragments.forEach((fragment: string): void => {
      next = NhSearchQuery.append(next, fragment)
    })
    if (next === this.query) {
      return false
    }
    this.query = next
    this.clearConditionError(scope)
    return true
  }

  private appendTag(text: string): boolean {
    const fragment: string = NhTagQuery.formatExact(this.tagNamespace, text)
    if (fragment.length === 0) {
      this.setConditionError('tag', AppStrings.get('search_advanced_tag_invalid'))
      return false
    }
    return this.appendFragments([fragment], 'tag')
  }

  private appendSuggestedTag(namespace: string, rawName: string): boolean {
    const fragment: string = NhTagQuery.formatExact(namespace, rawName)
    if (fragment.length === 0) {
      this.setConditionError('tag', AppStrings.get('search_advanced_tag_invalid'))
      return false
    }
    return this.appendFragments([fragment], 'tag')
  }

  private appendPlainCondition(text: string): boolean {
    const fragment: string = SearchConditionParser.formatPlain(text)
    if (fragment.length === 0) {
      this.setConditionError('plain', AppStrings.get('search_condition_plain_invalid'))
      return false
    }
    return this.appendFragments([fragment], 'plain')
  }

  private replaceRange(
    namespace: string,
    minimumText: string,
    maximumText: string,
    unit: NhSearchUploadedUnit = NhSearchUploadedUnit.DAY,
  ): void {
    const minimum: number = this.parsePositive(minimumText)
    const maximum: number = this.parsePositive(maximumText)
    if (minimum > 0 && maximum > 0 && minimum > maximum) {
      this.setConditionError(namespace, AppStrings.get('search_advanced_range_order'))
      return
    }
    const fragments: string[] = []
    if (minimum > 0) {
      fragments.push(this.rangeFragment(namespace, minimum,
        minimum === maximum ? NhSearchRangeRelation.EXACT : NhSearchRangeRelation.MINIMUM, unit))
    }
    if (maximum > 0 && minimum !== maximum) {
      fragments.push(this.rangeFragment(namespace, maximum, NhSearchRangeRelation.MAXIMUM, unit))
    }
    let next: string = SearchConditionParser.removeNamespace(this.query, namespace)
    fragments.forEach((fragment: string): void => {
      next = NhSearchQuery.append(next, fragment)
    })
    this.query = next
    this.clearConditionError(namespace)
  }

  private rangeFragment(
    namespace: string,
    value: number,
    relation: NhSearchRangeRelation,
    unit: NhSearchUploadedUnit,
  ): string {
    if (namespace === 'pages') {
      return NhSearchQuery.pages(value, relation)
    }
    if (namespace === 'favorites') {
      return NhSearchQuery.favorites(value, relation)
    }
    return NhSearchQuery.uploaded(value, unit, relation)
  }

  private setConditionError(scope: string, message: string): void {
    this.conditionErrorScope = scope
    this.conditionError = message
  }

  private clearConditionError(scope: string): void {
    if (this.conditionErrorScope === scope) {
      this.conditionErrorScope = ''
      this.conditionError = ''
    }
  }

  private removeCondition(tokenIndex: number): void {
    if (tokenIndex >= 0 && !this.hasUnclosedQuote(this.query)) {
      this.query = SearchConditionParser.removeTokenAt(this.query, tokenIndex)
    }
  }

  private setConditionExcluded(tokenIndex: number, excluded: boolean): void {
    if (tokenIndex >= 0 && !this.hasUnclosedQuote(this.query)) {
      this.query = SearchConditionParser.setExcluded(this.query, tokenIndex, excluded)
    }
  }

  private presentationLabel(value: string): string {
    if (value === NhBrowsePresentation.LIST) return AppStrings.get('browse_list')
    if (value === NhBrowsePresentation.SIMPLE_LIST) return AppStrings.get('browse_simple_list')
    if (value === NhBrowsePresentation.COVER_GRID) return AppStrings.get('browse_cover_grid')
    if (value === NhBrowsePresentation.WATERFALL) return AppStrings.get('browse_waterfall')
    if (value === NhBrowsePresentation.WATERFALL_COMPACT) return AppStrings.get('browse_waterfall_compact')
    if (value === NhBrowsePresentation.COVER_WALL) return AppStrings.get('browse_cover_wall')
    return AppStrings.get('browse_follow_global')
  }

  @Builder
  private LanguageMenuItem(option: NhSearchLanguage) {
    MenuItem({
      content: NhSearchOptions.languageLabel(option),
      symbolEndIcon: this.language === option ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
    }).onClick((): void => {
      this.language = option
      this.languageMenuShown = false
    })
  }

  @Builder
  private LanguageMenu() {
    Menu() {
      ForEach(LANGUAGES, (option: NhSearchLanguage): void => this.LanguageMenuItem(option),
        (option: NhSearchLanguage): string => option)
    }
  }

  @Builder
  private SortMenuItem(option: NhSearchSort) {
    MenuItem({
      content: NhSearchOptions.sortLabel(option),
      symbolEndIcon: this.sort === option ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
    }).onClick((): void => {
      this.sort = option
      this.sortMenuShown = false
    })
  }

  @Builder
  private SortMenu() {
    Menu() {
      ForEach(SORTS, (option: NhSearchSort): void => this.SortMenuItem(option),
        (option: NhSearchSort): string => option)
    }
  }

  @Builder
  private PresentationMenuItem(option: string) {
    MenuItem({
      content: this.presentationLabel(option),
      symbolEndIcon: this.presentation === option ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
    }).onClick((): void => {
      this.presentation = option
      this.presentationMenuShown = false
    })
  }

  @Builder
  private PresentationMenu() {
    Menu() {
      ForEach(PRESENTATIONS, (option: string): void => this.PresentationMenuItem(option),
        (option: string): string => option)
    }
  }

  @Builder
  private NameSection() {
    NextNGroupedListSection() {
      HomeSubtabInlineEditRow({
        title: AppStrings.get('home_subtab_name'),
        value: this.name,
        placeholder: AppStrings.get('home_subtab_name'),
        onChange: (value: string): void => {
          this.nameDraft = value
        },
      })
      Divider().strokeWidth(0.5).color(ThemeTokens.DIVIDER).margin({ left: ThemeTokens.SPACE_MD })
      NextNListRow({
        title: AppStrings.get('home_subtab_type'),
        trailingText: AppStrings.get('home_subtab_type_search'),
        showChevron: false,
      })
      Divider().strokeWidth(0.5).color(ThemeTokens.DIVIDER).margin({ left: ThemeTokens.SPACE_MD })
      NextNListRow({
        title: AppStrings.get('home_subtab_display'),
        trailingText: this.presentationLabel(this.presentation),
        trailingDropdown: true,
        onAction: (): void => {
          this.presentationMenuShown = true
        },
      })
        .bindMenu(this.presentationMenuShown, this.PresentationMenu, appMenuOptions({
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.presentationMenuShown = false
          },
        }))
    }
  }

  @Builder
  private OptionsSection() {
    NextNGroupedListSection() {
      NextNListRow({
        title: AppStrings.get('home_subtab_language'),
        trailingText: NhSearchOptions.languageLabel(this.language),
        trailingDropdown: true,
        onAction: (): void => {
          this.languageMenuShown = true
        },
      })
        .bindMenu(this.languageMenuShown, this.LanguageMenu, appMenuOptions({
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.languageMenuShown = false
          },
        }))
      Divider().strokeWidth(0.5).color(ThemeTokens.DIVIDER).margin({ left: ThemeTokens.SPACE_MD })
      NextNListRow({
        title: AppStrings.get('home_subtab_order'),
        trailingText: NhSearchOptions.sortLabel(this.sort),
        trailingDropdown: true,
        onAction: (): void => {
          this.sortMenuShown = true
        },
      })
        .bindMenu(this.sortMenuShown, this.SortMenu, appMenuOptions({
          placement: Placement.BottomRight,
          onDisappear: (): void => {
            this.sortMenuShown = false
          },
        }))
      Divider().strokeWidth(0.5).color(ThemeTokens.DIVIDER).margin({ left: ThemeTokens.SPACE_MD })
      NextNListRow({
        title: AppStrings.get('search_ignore_local_user_tag_filtering'),
        subtitle: AppStrings.get('search_ignore_local_user_tag_filtering_desc'),
        hasSwitch: true,
        checked: this.ignoreLocalUserTagFiltering,
        showChevron: false,
        onSwitchChange: (value: boolean): void => {
          this.ignoreLocalUserTagFiltering = value
        },
      })
    }
  }

  @Builder
  private AdvancedConditions() {
    SearchAdvancedConditionInputs({
      activeQuery: this.query,
      tagNamespace: this.tagNamespace,
      showLocalComposer: true,
      uploadedUnit: this.uploadedUnit,
      errorScope: this.conditionErrorScope,
      errorMessage: this.conditionError,
      onNamespaceChange: (value: string): void => {
        this.tagNamespace = value
      },
      onUnitChange: (value: NhSearchUploadedUnit): void => {
        this.uploadedUnit = value
      },
      onPlainAdd: (text: string): boolean => this.appendPlainCondition(text),
      onSuggestedTagAdd: (namespace: string, rawName: string): boolean =>
        this.appendSuggestedTag(namespace, rawName),
      onTagAdd: (text: string): boolean => this.appendTag(text),
      onPagesChange: (minimum: string, maximum: string): void =>
        this.replaceRange('pages', minimum, maximum),
      onFavoritesChange: (minimum: string, maximum: string): void =>
        this.replaceRange('favorites', minimum, maximum),
      onUploadedChange: (
        minimum: string,
        maximum: string,
        unit: NhSearchUploadedUnit,
      ): void => this.replaceRange('uploaded', minimum, maximum, unit),
      onClearError: (scope: string): void => this.clearConditionError(scope),
      onSetConditionExcluded: (tokenIndex: number, excluded: boolean): void =>
        this.setConditionExcluded(tokenIndex, excluded),
      onRemoveCondition: (tokenIndex: number): void => this.removeCondition(tokenIndex),
    })
  }

  build() {
    HdsNavDestination() {
      SecondaryListScaffold({
        scroller: this.scroller,
        bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
        alwaysEnableEdgeSpring: true,
      }) {
        ListItem() {
          Column() {
            NextNSectionHeader({ title: AppStrings.get('home_subtab_basic_section') })
            this.NameSection()
          }
          .alignItems(HorizontalAlign.Start)
        }
        ListItem() {
          Column() {
            NextNSectionHeader({ title: AppStrings.get('home_subtab_search_section') })
            Column({ space: ThemeTokens.SPACE_MD }) {
              this.AdvancedConditions()
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .alignItems(HorizontalAlign.Start)
        }
        ListItem() {
          Column() {
            NextNSectionHeader({ title: AppStrings.get('home_subtab_options_section') })
            this.OptionsSection()
          }
          .alignItems(HorizontalAlign.Start)
        }
        if (!this.isCreate()) {
          ListItem() {
            NextNGroupedListSection() {
              NextNListRow({
                title: AppStrings.get('common_delete'),
                leadingIcon: $r('sys.symbol.trash'),
                destructive: true,
                showChevron: false,
                onAction: (): void => {
                  this.confirmDelete()
                },
              })
            }
          }
          .margin({ top: ThemeTokens.SPACE_LG })
        }
      }
    }
    .titleBar(this.titleBar())
    .hideBackButton(this.hideBackButton)
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}

/** NextE InlineEditRow mirror: the field owns its draft so typing never rebuilds the page row. */
@ComponentV2
struct HomeSubtabInlineEditRow {
  @Param title: string = ''
  @Param value: string = ''
  @Param placeholder: string = ''
  @Event onChange: (value: string) => void = (): void => {}
  @Local fieldText: string = ''

  aboutToAppear(): void {
    this.fieldText = this.value
  }

  @Monitor('value')
  onExternalValueChanged(): void {
    if (this.value !== this.fieldText) {
      this.fieldText = this.value
    }
  }

  @Builder
  private InputSuffix() {
    TextInput({ text: this.fieldText, placeholder: this.placeholder })
      .textAlign(TextAlign.End)
      .fontSize(ThemeTokens.FONT_SIZE_BODY)
      .fontColor(ThemeTokens.TEXT_PRIMARY)
      .placeholderColor(ThemeTokens.TEXT_TERTIARY)
      .backgroundColor(Color.Transparent)
      .height(40)
      .padding({ top: 0, bottom: 0, left: 0, right: 2 })
      .width(200)
      .onChange((next: string): void => {
        this.fieldText = next
        this.onChange(next)
      })
  }

  build() {
    NextNListRow({
      title: this.title,
      showChevron: false,
      useCustomTrailing: true,
      customTrailing: (): void => {
        this.InputSuffix()
      },
    })
  }
}
