import {
  AppSearchField,
  AppStrings,
  FavoritesActionState,
  ThemeTokens,
} from 'shared'

/** Fixed HDS search slot; the retained list reserves this exact same height. */
export const FAVORITES_TITLE_SEARCH_HEIGHT: number = 52

/**
 * Remote Favorites query field owned by the HDS title bar. Text edits remain
 * a draft; only the trailing Search button or IME submit advances the request.
 */
@ComponentV2
export struct FavoritesTitleSearchField {
  @Param state: FavoritesActionState = new FavoritesActionState()
  @Local fieldText: string = ''

  aboutToAppear(): void {
    this.fieldText = this.state.searchDraft
  }

  @Monitor('state.searchDraft')
  onExternalDraftChanged(): void {
    if (this.fieldText !== this.state.searchDraft) {
      this.fieldText = this.state.searchDraft
    }
  }

  build() {
    Row() {
      AppSearchField({
        text: this.fieldText,
        placeholder: AppStrings.get('favorites_search_placeholder'),
        autoFocus: true,
        searchButtonText: AppStrings.get('action_search'),
        useSystemMaterial: true,
        verticalOffset: -ThemeTokens.SPACE_SM,
        onTextChange: (value: string): void => {
          this.fieldText = value
          this.state.searchDraft = value
        },
        onSubmit: (value: string): void => {
          this.fieldText = value
          this.state.searchDraft = value
          this.state.searchSubmitVersion += 1
        },
      })
        .height(ThemeTokens.SEARCH_FIELD_HEIGHT)
        .layoutWeight(1)
    }
    .width('100%')
    .height(FAVORITES_TITLE_SEARCH_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .padding({
      top: ThemeTokens.SPACE_XS,
      bottom: ThemeTokens.SPACE_XS,
      left: ThemeTokens.SPACE_MD,
      right: ThemeTokens.SPACE_MD,
    })
  }
}

@Builder
export function FavoritesTitleSearchFieldCCBuilder(state: FavoritesActionState) {
  FavoritesTitleSearchField({ state: state })
}
