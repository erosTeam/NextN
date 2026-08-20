import { AppStorageV2 } from '@kit.ArkUI'
import {
  AppStrings,
  NhDownloadTaskProjection,
  ThemeTokens,
} from 'shared'

/**
 * Keep the HDS mirror the same height as the lifecycle header rendered by the
 * queue ListItemGroup. The mirror is passive and does not change queue state.
 */
export const DOWNLOAD_PINNED_GROUP_HEADER_HEIGHT: number =
  ThemeTokens.FONT_SIZE_BODY + ThemeTokens.SPACE_MD + ThemeTokens.SPACE_XS

const DOWNLOAD_PINNED_GROUP_HEADER_KEY: string = 'nextn_download_pinned_group_header'

/** One localized label source for both the scrolling and pinned group header. */
export function downloadTaskGroupTitle(group: number): string {
  if (group === NhDownloadTaskProjection.PAUSED) {
    return AppStrings.get('download_status_paused')
  }
  if (group === NhDownloadTaskProjection.RETRY) {
    return AppStrings.get('download_group_failed')
  }
  if (group === NhDownloadTaskProjection.COMPLETE) {
    return AppStrings.get('download_status_complete')
  }
  return AppStrings.get('download_status_downloading')
}

/** UI-only bridge between Downloads List geometry and the root HDS slot. */
@ObservedV2
export class DownloadPinnedGroupHeaderState {
  @Trace group: number = -1
  @Trace count: number = 0
  @Trace visible: boolean = false
  /** Window Y of the title surface below which a crossed group is mirrored. */
  @Trace pinSurfaceTopY: number = -1
}

export function connectDownloadPinnedGroupHeader(): DownloadPinnedGroupHeaderState {
  return AppStorageV2.connect(
    DownloadPinnedGroupHeaderState,
    DOWNLOAD_PINNED_GROUP_HEADER_KEY,
    (): DownloadPinnedGroupHeaderState => new DownloadPinnedGroupHeaderState(),
  )!
}

@ComponentV2
export struct DownloadPinnedGroupHeader {
  @Param state: DownloadPinnedGroupHeaderState = new DownloadPinnedGroupHeaderState()

  build() {
    Column() {
      if (this.state.visible) {
        Row({ space: ThemeTokens.SPACE_XS }) {
          Text(downloadTaskGroupTitle(this.state.group))
            .fontSize(ThemeTokens.FONT_SIZE_BODY)
            .fontColor(ThemeTokens.BRAND)
            .fontWeight(FontWeight.Medium)
          Text(`${this.state.count}`)
            .fontSize(ThemeTokens.FONT_SIZE_TINY)
            .fontColor(ThemeTokens.TEXT_ON_BRAND)
            .fontWeight(FontWeight.Medium)
            .padding({
              left: ThemeTokens.SPACE_XS,
              right: ThemeTokens.SPACE_XS,
              top: ThemeTokens.SPACE_XS / 2,
              bottom: ThemeTokens.SPACE_XS / 2,
            })
            .borderRadius(ThemeTokens.RADIUS_ROUND)
            .backgroundColor(ThemeTokens.BRAND)
        }
        .width('100%')
        .height('100%')
        .padding({
          left: ThemeTokens.LIST_HORIZONTAL_PADDING + ThemeTokens.SPACE_SM,
          right: ThemeTokens.LIST_HORIZONTAL_PADDING + ThemeTokens.SPACE_SM,
        })
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .height(DOWNLOAD_PINNED_GROUP_HEADER_HEIGHT)
  }
}

@Builder
export function DownloadPinnedGroupHeaderCCBuilder(state: DownloadPinnedGroupHeaderState) {
  DownloadPinnedGroupHeader({ state: state })
}
