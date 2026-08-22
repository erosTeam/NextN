import {
  AppStrings,
  CatalogPreferencesState,
  HomeSubtabState,
  HomeSourceVisualIndexState,
  HOME_SUBTAB_LATEST_UUID,
  HOME_SUBTAB_POPULAR_UUID,
  HomeSourceBridge,
  NhHomeSubtabProfile,
  NhSearchLanguage,
  NhSearchOptions,
  SafeModeState,
  SubTabBar,
  SubtabTransitionBridge,
  SUBTAB_TRANSITION_SCOPE_HOME,
  TabItem,
  ThemeDisplayState,
  ThemeTokens,
  connectCatalogPreferences,
  connectHomeSubtabs,
  connectHomeSourceVisualIndex,
  connectSafeMode,
  connectThemeDisplay,
} from 'shared'

/**
 * The unified Home source selector, pinned by Index in HDS `bottomBuilder`.
 * It intentionally contains no remote state: RetainedSubtabHost owns the
 * native transition and each retained source page owns its data lifecycle.
 */
@ComponentV2
export struct HomeSourceBar {
  @Local safeMode: SafeModeState = connectSafeMode()
  @Local homeSubtabs: HomeSubtabState = connectHomeSubtabs()
  @Local visual: HomeSourceVisualIndexState = connectHomeSourceVisualIndex()
  @Local catalogPreferences: CatalogPreferencesState = connectCatalogPreferences()
  @Local themeDisplay: ThemeDisplayState = connectThemeDisplay()

  private latestTabTitle(): string {
    const sort: string = NhSearchOptions.sortLabel(this.catalogPreferences.browseSort)
    if (this.catalogPreferences.browseLanguage === NhSearchLanguage.ALL) {
      return sort
    }
    const language: string = NhSearchOptions.languageLabel(this.catalogPreferences.browseLanguage)
    return `${sort}（${language}）`
  }

  private tabs(): TabItem[] {
    const tabs: TabItem[] = []
    this.homeSubtabs.visibleProfiles().forEach((profile: NhHomeSubtabProfile): void => {
      if (profile.uuid === HOME_SUBTAB_LATEST_UUID) {
        tabs.push(new TabItem(profile.uuid, this.latestTabTitle()))
      } else if (profile.uuid === HOME_SUBTAB_POPULAR_UUID) {
        tabs.push(new TabItem(profile.uuid, AppStrings.get('home_source_popular')))
      } else {
        tabs.push(new TabItem(profile.uuid, profile.name))
      }
    })
    return tabs
  }

  private selectedIndex(): number {
    const items: TabItem[] = this.tabs()
    for (let index: number = 0; index < items.length; index++) {
      if (items[index].key === this.homeSubtabs.selectedUuid) {
        return index
      }
    }
    return 0
  }

  /** Keep the cached HDS bottomBuilder subscribed to effective theme changes. */
  private themeTracked(color: ResourceColor): ResourceColor {
    return this.themeDisplay.effectiveDark ? color : color
  }

  build() {
    Row() {
      SubTabBar({
        tabs: this.tabs(),
        visualIndex: this.visual.value,
        selectedIndex: this.selectedIndex(),
        onSelect: (index: number): void => {
          const items: TabItem[] = this.tabs()
          if (index < 0 || index >= items.length || items[index].key === this.homeSubtabs.selectedUuid) {
            return
          }
          SubtabTransitionBridge.request(SUBTAB_TRANSITION_SCOPE_HOME, items[index].key)
        },
      })
        .layoutWeight(1)
      if (!this.safeMode.restricted()) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.list_square'))
            .fontSize(ThemeTokens.FONT_SIZE_TITLE)
            .fontColor([this.themeTracked($r('sys.color.font_secondary'))])
        }
        .width(28)
        .height(28)
        .margin({ left: ThemeTokens.SPACE_XS, right: ThemeTokens.SPACE_SM })
        .backgroundColor(Color.Transparent)
        .alignSelf(ItemAlign.Start)
        .offset({ y: -2 })
        .onClick((): void => {
          HomeSourceBridge.requestManageSubtabs()
        })
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Center)
  }
}

@Builder
export function HomeSourceBarCCBuilder(_arg: Object) {
  HomeSourceBar()
}
