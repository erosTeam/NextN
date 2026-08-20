import {
  AppSearchField,
  AppStrings,
  DownloadQueueActionState,
  ThemeTokens,
  connectDownloadQueueActions,
} from 'shared'
import {
  DOWNLOAD_PINNED_GROUP_HEADER_HEIGHT,
  DownloadPinnedGroupHeader,
  DownloadPinnedGroupHeaderState,
  connectDownloadPinnedGroupHeader,
} from './DownloadPinnedGroupHeader'

/** Exact fixed search/selector slot height inherited from NextE DownloadTypeBar. */
export const DOWNLOAD_TITLE_SEARCH_HEIGHT: number = 52

/**
 * NextE-shaped Download title-bar owner. The local search field lives above
 * the existing pinned lifecycle header and filters immediately as text changes.
 */
@ComponentV2
export struct DownloadTitleBar {
  @Local private actions: DownloadQueueActionState = connectDownloadQueueActions()
  @Local private pinnedGroup: DownloadPinnedGroupHeaderState = connectDownloadPinnedGroupHeader()
  @Local private fieldText: string = ''

  aboutToAppear(): void {
    this.fieldText = this.actions.searchText
  }

  @Monitor('actions.searchText')
  onExternalSearchChanged(): void {
    if (this.fieldText !== this.actions.searchText) {
      this.fieldText = this.actions.searchText
    }
  }

  private updateSearchBottom(area: Area): void {
    this.pinnedGroup.pinSurfaceTopY =
      (area.globalPosition.y as number) + (area.height as number)
  }

  build() {
    Column() {
      if (this.actions.searchActive) {
        Row() {
          AppSearchField({
            text: this.fieldText,
            placeholder: AppStrings.get('download_search_placeholder'),
            autoFocus: true,
            useSystemMaterial: true,
            verticalOffset: -ThemeTokens.SPACE_SM,
            onTextChange: (value: string): void => {
              this.fieldText = value
              this.actions.searchText = value
            },
            onSubmit: (value: string): void => {
              this.fieldText = value
              this.actions.searchText = value
            },
          })
            .height(ThemeTokens.SEARCH_FIELD_HEIGHT)
            .layoutWeight(1)
        }
        .width('100%')
        .height(DOWNLOAD_TITLE_SEARCH_HEIGHT)
        .alignItems(VerticalAlign.Center)
        .padding({
          top: ThemeTokens.SPACE_XS,
          bottom: ThemeTokens.SPACE_XS,
          left: ThemeTokens.SPACE_MD,
          right: ThemeTokens.SPACE_MD,
        })
        .onAreaChange((_oldValue: Area, newValue: Area): void => {
          this.updateSearchBottom(newValue)
        })
      }
      if (this.pinnedGroup.visible) {
        DownloadPinnedGroupHeader({ state: this.pinnedGroup })
      }
    }
    .width('100%')
    .height((this.actions.searchActive ? DOWNLOAD_TITLE_SEARCH_HEIGHT : 0) +
      (this.pinnedGroup.visible ? DOWNLOAD_PINNED_GROUP_HEADER_HEIGHT : 0))
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      if (!this.actions.searchActive) {
        this.pinnedGroup.pinSurfaceTopY = newValue.globalPosition.y as number
      }
    })
  }
}

@Builder
export function DownloadTitleBarCCBuilder(_arg: Object) {
  DownloadTitleBar()
}
