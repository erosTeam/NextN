import {
  AppStrings,
  HomeSourceState,
  HomeSourceVisualIndexState,
  HOME_SOURCE_LATEST,
  HOME_SOURCE_POPULAR,
  HomeSourceBridge,
  SubTabBar,
  SubtabTransitionBridge,
  SUBTAB_TRANSITION_SCOPE_HOME,
  TabItem,
  connectHomeSource,
  connectHomeSourceVisualIndex,
} from 'shared'

/**
 * The two-source Browse selector, pinned by Index in HDS `bottomBuilder`.
 * It intentionally contains no remote state: RetainedSubtabHost owns the
 * native transition and each retained source page owns its data lifecycle.
 */
@ComponentV2
export struct HomeSourceBar {
  @Local homeSource: HomeSourceState = connectHomeSource()
  @Local visual: HomeSourceVisualIndexState = connectHomeSourceVisualIndex()

  private tabs(): TabItem[] {
    return [
      new TabItem(HOME_SOURCE_LATEST, AppStrings.get('home_source_latest')),
      new TabItem(HOME_SOURCE_POPULAR, AppStrings.get('home_source_popular')),
    ]
  }

  private selectedIndex(): number {
    return this.homeSource.selectedKey === HOME_SOURCE_POPULAR ? 1 : 0
  }

  build() {
    Row() {
      SubTabBar({
        tabs: this.tabs(),
        visualIndex: this.visual.value,
        selectedIndex: this.selectedIndex(),
        onSelect: (index: number): void => {
          const items: TabItem[] = this.tabs()
          if (index < 0 || index >= items.length || items[index].key === this.homeSource.selectedKey) {
            return
          }
          SubtabTransitionBridge.request(SUBTAB_TRANSITION_SCOPE_HOME, items[index].key)
        },
      })
        .layoutWeight(1)
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
