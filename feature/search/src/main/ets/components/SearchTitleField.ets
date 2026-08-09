import { AppSearchField, AppStrings, ThemeTokens } from 'shared'
import { SearchChromeState } from '../state/SearchChromeState'

/** Height reserved beneath the HDS title for the native search input. */
export const SEARCH_TITLE_FIELD_BOTTOM_HEIGHT: number = ThemeTokens.TITLE_BAR_HEIGHT + ThemeTokens.SPACE_SM

/**
 * Search input hosted by the HDS title bar rather than the scrolling result
 * content. The owning destination reacts to the route-local chrome state.
 */
@ComponentV2
export struct SearchTitleField {
  @Param chrome: SearchChromeState = new SearchChromeState()
  @Local fieldText: string = ''

  aboutToAppear(): void {
    this.fieldText = this.chrome.keyword
  }

  @Monitor('chrome.keyword')
  onKeywordChanged(): void {
    if (this.fieldText !== this.chrome.keyword) {
      this.fieldText = this.chrome.keyword
    }
  }

  build() {
    Row() {
      AppSearchField({
        text: this.fieldText,
        placeholder: AppStrings.get('search_galleries_placeholder'),
        // Blank pushed searches are explicit input intent; action-seeded
        // searches present results first and must not reopen the IME.
        autoFocus: this.chrome.focusOnAppear,
        searchButtonText: AppStrings.get('action_search'),
        useSystemMaterial: true,
        onTextChange: (value: string): void => {
          this.fieldText = value
          this.chrome.keyword = value
        },
        onSubmit: (value: string): void => {
          this.fieldText = value
          this.chrome.keyword = value
          this.chrome.submitVersion += 1
        },
      }).layoutWeight(1)
    }
    .width('100%')
    .height(SEARCH_TITLE_FIELD_BOTTOM_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: ThemeTokens.SPACE_LG,
      right: ThemeTokens.SPACE_LG,
      bottom: ThemeTokens.SPACE_SM,
    })
  }
}

@Builder
export function SearchTitleFieldCCBuilder(chrome: SearchChromeState) {
  SearchTitleField({ chrome: chrome })
}
