import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  NhApiClient,
  NhTag,
  NhTagQuery,
  NhTagSuggestion,
  NhTagSuggestionDisplay,
  NextNGroupedListSection,
  NextNListRow,
  NhSearchUploadedUnit,
  ThemeTokens,
  TagTranslationRepository,
} from 'shared'
import {
  SearchConditionChip,
  SearchConditionKind,
  SearchConditionParser,
  SearchConditionRange,
  SearchConditionRelation,
} from '../model/SearchConditionChip'
import { appMenuOptions } from 'shared'
import { SymbolGlyphModifier } from '@kit.ArkUI'

const ADVANCED_RANGE_INPUT_WIDTH: number = 84
const ADVANCED_RANGE_INPUT_HEIGHT: number = 36
const ADVANCED_TAG_SUGGESTION_LIMIT: number = 8
const ADVANCED_TAG_SUGGESTION_DELAY_MS: number = 250
const ADVANCED_INPUT_HEIGHT: number = 36

/**
 * Typing must mutate only this leaf's own @Local state. A @Builder function
 * that receives a changing primitive recreates its whole TextInput node on
 * every keystroke, which dismisses the IME mid-word; a dedicated component
 * keeps the node identity stable while the value flows through events.
 */
@ComponentV2
struct AdvancedRangeInput {
  @Param value: string = ''
  @Param placeholder: string = ''
  @Param accessibilityLabel: string = ''
  @Event onValueCommitted: (value: string) => void = (_value: string) => {}
  @Local text: string = ''

  aboutToAppear(): void {
    this.text = this.value
  }

  @Monitor('value')
  onExternalValueChanged(): void {
    if (this.value !== this.text) {
      this.text = this.value
    }
  }

  private commit(): void {
    if (this.text !== this.value) {
      this.onValueCommitted(this.text)
    }
  }

  build() {
    TextInput({
      text: this.text,
      placeholder: this.placeholder,
    })
      .type(InputType.Number)
      .inputFilter('^[0-9]*$')
      .textAlign(TextAlign.Center)
      .width(ADVANCED_RANGE_INPUT_WIDTH)
      .height(ADVANCED_INPUT_HEIGHT)
      .fontSize(ThemeTokens.FONT_SIZE_BODY)
      .backgroundColor(ThemeTokens.SURFACE_SUB)
      .borderRadius(ThemeTokens.RADIUS_MD)
      .accessibilityDescription(this.accessibilityLabel)
      .onChange((value: string): void => {
        this.text = value
      })
      .onSubmit((): void => {
        this.commit()
      })
      .onBlur((): void => {
        this.commit()
      })
  }
}

@ComponentV2
struct AdvancedConditionInput {
  @Param value: string = ''
  @Param placeholder: string = ''
  @Event onValueChanged: (value: string) => void = (_value: string) => {}
  @Event onSubmitted: () => void = () => {}
  @Local text: string = ''

  aboutToAppear(): void {
    this.text = this.value
  }

  @Monitor('value')
  onExternalValueChanged(): void {
    if (this.value !== this.text) {
      this.text = this.value
    }
  }

  build() {
    TextInput({
      text: this.text,
      placeholder: this.placeholder,
    })
      .width('100%')
      .height(44)
      .fontSize(ThemeTokens.FONT_SIZE_BODY)
      .backgroundColor(ThemeTokens.SURFACE_SUB)
      .borderRadius(ThemeTokens.RADIUS_MD)
      .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD, top: 0, bottom: 0 })
      .onChange((value: string): void => {
        this.text = value
        this.onValueChanged(value)
      })
      .onSubmit((): void => {
        if (this.text.trim().length > 0) {
          this.onSubmitted()
        }
      })
  }
}

/**
 * Advanced-search text inputs live in their own component so typing mutates
 * only this local draft state. Keeping them in page-level @Builder + @Local
 * state rebuilt the whole search sheet on every character, which dropped the
 * TextInput focus and dismissed the IME (NextE hosts these controls in the
 * standalone AdvancedSearchControls component).
 */
@ComponentV2
export struct SearchAdvancedConditionInputs {
  @Param activeQuery: string = ''
  @Param tagNamespace: string = 'tag'
  @Param showLocalComposer: boolean = false
  @Param uploadedUnit: NhSearchUploadedUnit = NhSearchUploadedUnit.DAY
  @Param errorScope: string = ''
  @Param errorMessage: string = ''
  @Event onNamespaceChange?: (namespace: string) => void
  @Event onUnitChange?: (unit: NhSearchUploadedUnit) => void
  @Event onPlainAdd?: (text: string) => boolean
  @Event onSuggestedTagAdd?: (namespace: string, rawName: string) => boolean
  @Event onTagAdd?: (text: string) => boolean
  @Event onPagesChange?: (minimumText: string, maximumText: string) => void
  @Event onFavoritesChange?: (minimumText: string, maximumText: string) => void
  @Event onUploadedChange?: (
    minimumText: string,
    maximumText: string,
    unit: NhSearchUploadedUnit,
  ) => void
  @Event onClearError?: (scope: string) => void
  @Event onSetConditionExcluded?: (tokenIndex: number, excluded: boolean) => void
  @Event onRemoveCondition?: (tokenIndex: number) => void
  @Local conditionText: string = ''
  @Local tagText: string = ''
  @Local pageMinimumText: string = ''
  @Local pageMaximumText: string = ''
  @Local favoriteMinimumText: string = ''
  @Local favoriteMaximumText: string = ''
  @Local uploadedMinimumText: string = ''
  @Local uploadedMaximumText: string = ''
  @Local tagNamespaceMenuShown: boolean = false
  @Local uploadedUnitMenuShown: boolean = false
  @Local conditionMatches: NhTagSuggestion[] = []
  @Local isMatchingConditions: boolean = false
  @Local tagMatches: NhTagSuggestion[] = []
  @Local isMatchingTags: boolean = false
  @Local conditionTranslations: Map<string, string> = new Map<string, string>()
  private conditionMatchTimer: number = -1
  private conditionMatchEpoch: number = 0
  private tagMatchTimer: number = -1
  private tagMatchEpoch: number = 0
  private conditionTranslationEpoch: number = 0

  aboutToAppear(): void {
    this.syncRangeDrafts()
    this.loadConditionTranslations()
  }

  @Monitor('activeQuery')
  onActiveQueryChanged(): void {
    this.syncRangeDrafts()
    this.loadConditionTranslations()
  }

  aboutToDisappear(): void {
    this.cancelConditionMatches()
    this.cancelTagMatches()
    this.conditionTranslationEpoch += 1
  }

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

  private relationLabel(excluded: boolean): string {
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

  private clearError(scope: string): void {
    if (this.errorScope === scope && this.errorMessage.length > 0 && this.onClearError) {
      this.onClearError(scope)
    }
  }

  private addTag(): void {
    if (this.onTagAdd && this.onTagAdd(this.tagText)) {
      this.tagText = ''
      this.cancelTagMatches()
    }
  }

  private addPlainCondition(): void {
    if (this.onPlainAdd && this.onPlainAdd(this.conditionText)) {
      this.conditionText = ''
      this.cancelConditionMatches()
    }
  }

  private addSuggestedCondition(suggestion: NhTagSuggestion): void {
    if (this.onSuggestedTagAdd && this.onSuggestedTagAdd(suggestion.namespace, suggestion.rawName)) {
      const context: common.UIAbilityContext =
        this.getUIContext().getHostContext() as common.UIAbilityContext
      TagTranslationRepository.touchSuggestion(context, suggestion.namespace, suggestion.rawName)
        .catch((_error: Error): void => {})
      this.conditionText = ''
      this.cancelConditionMatches()
    }
  }

  private removeCondition(chip: SearchConditionChip): void {
    if (this.onRemoveCondition) {
      this.onRemoveCondition(chip.tokenIndex)
    }
  }

  private setConditionExcluded(chip: SearchConditionChip, excluded: boolean): void {
    if (this.onSetConditionExcluded) {
      this.onSetConditionExcluded(chip.tokenIndex, excluded)
    }
  }

  private operatorLabel(namespace: string): string {
    switch (namespace) {
      case 'pages':
        return AppStrings.get('search_advanced_pages')
      case 'favorites':
        return AppStrings.get('search_advanced_favorites')
      case 'uploaded':
        return AppStrings.get('search_advanced_uploaded')
      default:
        return namespace
    }
  }

  private syncRangeDrafts(): void {
    const pages: SearchConditionRange = SearchConditionParser.range(this.activeQuery, 'pages')
    const favorites: SearchConditionRange = SearchConditionParser.range(this.activeQuery, 'favorites')
    const uploaded: SearchConditionRange = SearchConditionParser.range(this.activeQuery, 'uploaded')
    this.pageMinimumText = pages.minimumText
    this.pageMaximumText = pages.maximumText
    this.favoriteMinimumText = favorites.minimumText
    this.favoriteMaximumText = favorites.maximumText
    this.uploadedMinimumText = uploaded.minimumText
    this.uploadedMaximumText = uploaded.maximumText
    const parsedUnit: NhSearchUploadedUnit | null = this.uploadedUnitFromSuffix(uploaded.unit)
    if (parsedUnit !== null && parsedUnit !== this.uploadedUnit && this.onUnitChange) {
      this.onUnitChange(parsedUnit)
    }
  }

  private uploadedUnitFromSuffix(value: string): NhSearchUploadedUnit | null {
    if (value === NhSearchUploadedUnit.HOUR) return NhSearchUploadedUnit.HOUR
    if (value === NhSearchUploadedUnit.DAY) return NhSearchUploadedUnit.DAY
    if (value === NhSearchUploadedUnit.WEEK) return NhSearchUploadedUnit.WEEK
    if (value === NhSearchUploadedUnit.MONTH) return NhSearchUploadedUnit.MONTH
    if (value === NhSearchUploadedUnit.YEAR) return NhSearchUploadedUnit.YEAR
    return null
  }

  private notifyPagesChanged(): void {
    if (this.onPagesChange) {
      this.onPagesChange(this.pageMinimumText, this.pageMaximumText)
    }
  }

  private notifyFavoritesChanged(): void {
    if (this.onFavoritesChange) {
      this.onFavoritesChange(this.favoriteMinimumText, this.favoriteMaximumText)
    }
  }

  private notifyUploadedChanged(unit: NhSearchUploadedUnit = this.uploadedUnit): void {
    if (this.onUploadedChange) {
      this.onUploadedChange(this.uploadedMinimumText, this.uploadedMaximumText, unit)
    }
  }

  private visibleConditionChips(): SearchConditionChip[] {
    return SearchConditionParser.chips(
      this.activeQuery,
      (namespace: string): string => this.operatorLabel(namespace),
    ).filter((chip: SearchConditionChip): boolean => {
      return !SearchConditionParser.isRangeToken(chip.rawToken)
    })
  }

  private conditionTranslationKey(chip: SearchConditionChip): string {
    if (chip.kind !== SearchConditionKind.TAG) {
      return ''
    }
    const tag: NhTag = new NhTag()
    tag.type = chip.namespace
    tag.name = chip.rawValue
    return TagTranslationRepository.keyFor(tag)
  }

  private conditionSubtitle(chip: SearchConditionChip): string {
    const key: string = this.conditionTranslationKey(chip)
    if (key.length === 0) {
      return ''
    }
    const translated: string | undefined = this.conditionTranslations.get(key)
    if (translated === undefined || translated.trim() === chip.rawValue.trim()) {
      return ''
    }
    return `${NhTagSuggestionDisplay.namespaceLabel(chip.namespace)}:${translated.trim()}`
  }

  private async loadConditionTranslations(): Promise<void> {
    const epoch: number = this.conditionTranslationEpoch + 1
    this.conditionTranslationEpoch = epoch
    const tags: NhTag[] = this.visibleConditionChips()
      .filter((chip: SearchConditionChip): boolean => chip.kind === SearchConditionKind.TAG)
      .map((chip: SearchConditionChip): NhTag => {
        const tag: NhTag = new NhTag()
        tag.type = chip.namespace
        tag.name = chip.rawValue
        return tag
      })
    if (tags.length === 0) {
      this.conditionTranslations = new Map<string, string>()
      return
    }
    try {
      const context: common.UIAbilityContext =
        this.getUIContext().getHostContext() as common.UIAbilityContext
      const translations: Map<string, string> = await TagTranslationRepository.lookup(context, tags)
      if (epoch === this.conditionTranslationEpoch) {
        this.conditionTranslations = translations
      }
    } catch (_error) {
      if (epoch === this.conditionTranslationEpoch) {
        this.conditionTranslations = new Map<string, string>()
      }
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

  private cancelConditionMatches(): void {
    this.conditionMatchEpoch += 1
    if (this.conditionMatchTimer >= 0) {
      clearTimeout(this.conditionMatchTimer)
      this.conditionMatchTimer = -1
    }
    this.isMatchingConditions = false
    this.conditionMatches = []
  }

  private scheduleConditionMatches(query: string): void {
    this.cancelConditionMatches()
    const normalized: string = query.trim()
    if (normalized.length === 0) {
      return
    }
    this.isMatchingConditions = true
    const epoch: number = this.conditionMatchEpoch
    this.conditionMatchTimer = setTimeout((): void => {
      this.conditionMatchTimer = -1
      this.loadConditionMatches(normalized, epoch)
    }, ADVANCED_TAG_SUGGESTION_DELAY_MS)
  }

  private async loadConditionMatches(query: string, epoch: number): Promise<void> {
    try {
      const context: common.UIAbilityContext =
        this.getUIContext().getHostContext() as common.UIAbilityContext
      const matches: NhTagSuggestion[] = await TagTranslationRepository.suggestUnscoped(
        context,
        query,
        ADVANCED_TAG_SUGGESTION_LIMIT,
      )
      if (epoch === this.conditionMatchEpoch) {
        this.conditionMatches = matches
        this.isMatchingConditions = false
      }
    } catch (_error) {
      if (epoch === this.conditionMatchEpoch) {
        this.conditionMatches = []
        this.isMatchingConditions = false
      }
    }
  }

  private cancelTagMatches(): void {
    this.tagMatchEpoch += 1
    if (this.tagMatchTimer >= 0) {
      clearTimeout(this.tagMatchTimer)
      this.tagMatchTimer = -1
    }
    this.isMatchingTags = false
    this.tagMatches = []
  }

  private scheduleTagMatches(prefix: string): void {
    this.cancelTagMatches()
    const normalized: string = prefix.trim()
    if (normalized.length === 0) {
      return
    }
    this.isMatchingTags = true
    const epoch: number = this.tagMatchEpoch
    this.tagMatchTimer = setTimeout((): void => {
      this.tagMatchTimer = -1
      this.loadTagMatches(normalized, epoch)
    }, ADVANCED_TAG_SUGGESTION_DELAY_MS)
  }

  private async loadTagMatches(prefix: string, epoch: number): Promise<void> {
    // This is the explicit NH matcher. Local unscoped discovery lives in the
    // unified condition composer above; keeping the sources separate makes a
    // namespaced server match distinct from an unscoped local translation hit.
    const context: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext
    let matches: NhTagSuggestion[] = []
    try {
      matches = await NhApiClient.tagSuggestions(
        this.tagNamespace,
        prefix,
        ADVANCED_TAG_SUGGESTION_LIMIT,
      )
    } catch (_error) {}
    if (epoch !== this.tagMatchEpoch) {
      return
    }
    const untranslated: NhTag[] = matches
      .filter((item: NhTagSuggestion): boolean => item.displayName.trim().length === 0)
      .map((item: NhTagSuggestion): NhTag => {
        const tag: NhTag = new NhTag()
        tag.type = item.namespace
        tag.name = item.rawName
        return tag
      })
    if (untranslated.length > 0) {
      try {
        const translations: Map<string, string> =
          await TagTranslationRepository.lookup(context, untranslated)
        matches.forEach((item: NhTagSuggestion): void => {
          if (item.displayName.trim().length === 0) {
            const tag: NhTag = new NhTag()
            tag.type = item.namespace
            tag.name = item.rawName
            const label: string | undefined = translations.get(TagTranslationRepository.keyFor(tag))
            if (label !== undefined && label.trim().length > 0) {
              item.displayName = label
            }
          }
        })
      } catch (_error) {}
    }
    if (epoch !== this.tagMatchEpoch) {
      return
    }
    this.tagMatches = matches
    this.isMatchingTags = false
  }

  @Builder
  private SearchOptionDivider() {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.ohos_id_color_list_separator'))
      .margin({ left: ThemeTokens.SPACE_MD })
  }

  @Builder
  private TagNameInputRow() {
    Column() {
      AdvancedConditionInput({
        value: this.tagText,
        placeholder: AppStrings.get('search_advanced_tag_placeholder'),
        onValueChanged: (value: string): void => {
          this.tagText = value
          this.scheduleTagMatches(value)
          this.clearError('tag')
        },
        onSubmitted: (): void => {
          this.addTag()
        },
      })
    }
    .padding({
      left: ThemeTokens.SPACE_MD,
      right: ThemeTokens.SPACE_MD,
      top: ThemeTokens.SPACE_SM,
      bottom: ThemeTokens.SPACE_SM,
    })
  }

  @Builder
  private ConditionComposerInputRow() {
    Column() {
      AdvancedConditionInput({
        value: this.conditionText,
        placeholder: AppStrings.get('search_condition_input_placeholder'),
        onValueChanged: (value: string): void => {
          this.conditionText = value
          this.scheduleConditionMatches(value)
          this.clearError('plain')
        },
        onSubmitted: (): void => {
          this.addPlainCondition()
        },
      })
    }
    .padding({
      left: ThemeTokens.SPACE_MD,
      right: ThemeTokens.SPACE_MD,
      top: ThemeTokens.SPACE_SM,
      bottom: ThemeTokens.SPACE_SM,
    })
  }

  @Builder
  private AddConditionSuffix(action: () => void, accessibilityLabel: string) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(ThemeTokens.FONT_SIZE_TITLE)
        .fontColor([ThemeTokens.BRAND])
    }
    .width(44)
    .height(44)
    .backgroundColor(Color.Transparent)
    .accessibilityText(accessibilityLabel)
    .onClick(action)
  }

  @Builder
  private ConditionComposerMatches() {
    ForEach(this.conditionMatches, (suggestion: NhTagSuggestion): void => {
      NextNListRow({
        title: NhTagQuery.formatExact(suggestion.namespace, suggestion.rawName),
        subtitle: this.suggestionTranslatedLabel(suggestion),
        showChevron: false,
        useCustomTrailing: true,
        suffixPaddingRight: ThemeTokens.SPACE_SM,
        customTrailing: (): void => {
          this.AddConditionSuffix((): void => {
            this.addSuggestedCondition(suggestion)
          }, AppStrings.get('search_advanced_add_tag'))
        },
        accessibilityLabel: NhTagQuery.formatExact(suggestion.namespace, suggestion.rawName),
      })
    }, (suggestion: NhTagSuggestion): string => `${suggestion.namespace}${suggestion.rawName}`)
    if (this.isMatchingConditions) {
      NextNListRow({
        title: AppStrings.get('search_looking_suggestions'),
        showChevron: false,
        isEnabled: false,
      })
    }
    if (this.conditionText.trim().length > 0) {
      NextNListRow({
        title: this.plainCandidate().length > 0
          ? AppStrings.format('search_condition_add_plain', [this.plainCandidate()])
          : this.conditionText.trim(),
        subtitle: AppStrings.get('search_condition_plain_subtitle'),
        showChevron: false,
        useCustomTrailing: this.plainCandidate().length > 0,
        suffixPaddingRight: ThemeTokens.SPACE_SM,
        customTrailing: (): void => {
          this.AddConditionSuffix((): void => {
            this.addPlainCondition()
          }, AppStrings.get('search_condition_add_plain_a11y'))
        },
        isEnabled: this.plainCandidate().length > 0,
      })
    }
  }

  @Builder
  private FavoriteRangeSuffix() {
    Row({ space: ThemeTokens.SPACE_SM }) {
      this.RangeInput(this.favoriteMinimumText, AppStrings.get('search_advanced_favorites_minimum'),
        (value: string): void => {
          this.favoriteMinimumText = value
          this.clearError('favorites')
          this.notifyFavoritesChanged()
        })
      Text('-')
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_TERTIARY)
      this.RangeInput(this.favoriteMaximumText, AppStrings.get('search_advanced_favorites_maximum'),
        (value: string): void => {
          this.favoriteMaximumText = value
          this.clearError('favorites')
          this.notifyFavoritesChanged()
        })
    }
    .alignItems(VerticalAlign.Center)
    .padding({ left: ThemeTokens.SPACE_SM, right: ThemeTokens.SPACE_MD })
  }

  @Builder
  private TagMatchList() {
    ForEach(this.tagMatches, (suggestion: NhTagSuggestion): void => {
      NextNListRow({
        title: NhTagQuery.formatExact(suggestion.namespace, suggestion.rawName),
        subtitle: this.suggestionTranslatedLabel(suggestion),
        showChevron: false,
        useCustomTrailing: true,
        suffixPaddingRight: ThemeTokens.SPACE_SM,
        customTrailing: (): void => {
          this.AddConditionSuffix((): void => {
            if (this.onSuggestedTagAdd &&
              this.onSuggestedTagAdd(suggestion.namespace, suggestion.rawName)) {
              this.tagText = ''
              this.cancelTagMatches()
            }
          }, AppStrings.get('search_advanced_add_tag'))
        },
        accessibilityLabel: NhTagQuery.formatExact(suggestion.namespace, suggestion.rawName),
      })
    }, (suggestion: NhTagSuggestion): string => `${suggestion.namespace}${suggestion.rawName}`)
    if (this.isMatchingTags) {
      NextNListRow({
        title: AppStrings.get('search_looking_suggestions'),
        showChevron: false,
        isEnabled: false,
      })
    }
    if (this.tagText.trim().length > 0) {
      NextNListRow({
        title: this.onlineTagCandidate().length > 0
          ? AppStrings.format('search_condition_add_tag', [this.onlineTagCandidate()])
          : this.tagText.trim(),
        subtitle: AppStrings.get('search_condition_nh_raw_subtitle'),
        showChevron: false,
        useCustomTrailing: this.onlineTagCandidate().length > 0,
        suffixPaddingRight: ThemeTokens.SPACE_SM,
        customTrailing: (): void => {
          this.AddConditionSuffix((): void => {
            this.addTag()
          }, AppStrings.get('search_advanced_add_tag'))
        },
        isEnabled: this.onlineTagCandidate().length > 0,
      })
    }
  }

  private suggestionTranslatedLabel(suggestion: NhTagSuggestion): string {
    const translated: string = suggestion.displayName.trim()
    return translated.length > 0 && translated !== suggestion.rawName
      ? translated
      : ''
  }

  private plainCandidate(): string {
    return SearchConditionParser.formatPlain(this.conditionText)
  }

  private onlineTagCandidate(): string {
    return NhTagQuery.formatExact(this.tagNamespace, this.tagText)
  }

  @Builder
  private RangeInput(value: string, accessibilityLabel: string, onValueCommitted: (value: string) => void) {
    AdvancedRangeInput({
      value: value,
      placeholder: AppStrings.get('filter_any'),
      accessibilityLabel: accessibilityLabel,
      onValueCommitted: onValueCommitted,
    })
  }

  @Builder
  private PageRangeSuffix() {
    Row({ space: ThemeTokens.SPACE_SM }) {
      this.RangeInput(this.pageMinimumText, AppStrings.get('search_advanced_pages_minimum'),
        (value: string): void => {
          this.pageMinimumText = value
          this.clearError('pages')
          this.notifyPagesChanged()
        })
      Text('-')
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_TERTIARY)
      this.RangeInput(this.pageMaximumText, AppStrings.get('search_advanced_pages_maximum'),
        (value: string): void => {
          this.pageMaximumText = value
          this.clearError('pages')
          this.notifyPagesChanged()
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
          this.notifyUploadedChanged()
        })
      Text('-')
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_TERTIARY)
      this.RangeInput(this.uploadedMaximumText, AppStrings.get('search_advanced_uploaded_maximum'),
        (value: string): void => {
          this.uploadedMaximumText = value
          this.clearError('uploaded')
          this.notifyUploadedChanged()
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
  private ConditionActions(chip: SearchConditionChip) {
    Row({ space: ThemeTokens.SPACE_XS }) {
      if (chip.relationEditable) {
        Row({ space: ThemeTokens.SPACE_XS }) {
          Text(this.relationLabel(chip.relation === SearchConditionRelation.EXCLUDE))
            .fontSize(ThemeTokens.FONT_SIZE_BODY)
            .fontColor(chip.relation === SearchConditionRelation.EXCLUDE
              ? Color.Red
              : ThemeTokens.TEXT_SECONDARY)
        }
        .height(44)
        .padding({ left: ThemeTokens.SPACE_SM, right: ThemeTokens.SPACE_SM })
        .alignItems(VerticalAlign.Center)
        .accessibilityText(this.relationLabel(chip.relation === SearchConditionRelation.EXCLUDE))
        .onClick((): void => {
          this.setConditionExcluded(chip, chip.relation !== SearchConditionRelation.EXCLUDE)
        })
      }
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(ThemeTokens.FONT_SIZE_TITLE)
          .fontColor([Color.Red])
      }
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .accessibilityText(AppStrings.format('search_condition_remove_a11y', [chip.title]))
      .onClick((): void => {
        this.removeCondition(chip)
      })
    }
    .alignItems(VerticalAlign.Center)
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
      this.notifyUploadedChanged(unit)
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
      if (this.visibleConditionChips().length > 0) {
        NextNGroupedListSection() {
          Text(AppStrings.get('search_conditions_active'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .width('100%')
            .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD, top: ThemeTokens.SPACE_SM })
          ForEach(
            this.visibleConditionChips(),
            (chip: SearchConditionChip): void => {
              NextNListRow({
                title: chip.title,
                subtitle: this.conditionSubtitle(chip),
                showChevron: false,
                useCustomTrailing: true,
                suffixPaddingRight: ThemeTokens.SPACE_SM,
                customTrailing: (): void => {
                  this.ConditionActions(chip)
                },
                accessibilityLabel: chip.title,
              })
            },
            (chip: SearchConditionChip): string => `${chip.tokenIndex}:${chip.rawToken}`,
          )
        }
      }
      if (this.showLocalComposer) {
        NextNGroupedListSection() {
          this.ConditionComposerInputRow()
          this.ConditionComposerMatches()
        }
        this.ConditionError('plain')
      }
      NextNGroupedListSection() {
        Text(AppStrings.get('search_condition_nh_match'))
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor(ThemeTokens.TEXT_SECONDARY)
          .width('100%')
          .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD, top: ThemeTokens.SPACE_SM })
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
        this.TagNameInputRow()
        this.TagMatchList()
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
      }
      this.ConditionError('pages')

      NextNGroupedListSection() {
        NextNListRow({
          title: AppStrings.get('search_advanced_favorites'),
          showChevron: false,
          useCustomTrailing: true,
          customTrailing: (): void => {
            this.FavoriteRangeSuffix()
          },
          accessibilityLabel: AppStrings.get('search_advanced_favorites'),
        })
      }
      this.ConditionError('favorites')

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
      }
      this.ConditionError('uploaded')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
