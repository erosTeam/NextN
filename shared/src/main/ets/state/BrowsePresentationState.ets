import { AppStorageV2 } from '@kit.ArkUI'
import { NhBrowsePresentation } from '../model/NhBrowsePresentation'

@ObservedV2
export class BrowsePresentationState {
  // Keep the existing compact-row default for already-installed users. LIST is
  // an opt-in medium-list presentation and is not a migration of simple_list.
  @Trace mode: NhBrowsePresentation = NhBrowsePresentation.SIMPLE_LIST
  // Grid-like presentations store a minimum comfortable column width rather
  // than a fixed count. A zero preserves the corresponding NextE base token
  // so rotation, folding, and split width always derive a fresh column count.
  @Trace coverGridMinColumnWidth: number = 0
  @Trace waterfallMinColumnWidth: number = 0
  @Trace waterfallCompactMinColumnWidth: number = 0
  @Trace coverWallMinColumnWidth: number = 0

  columnWidthFor(mode: NhBrowsePresentation): number {
    if (mode === NhBrowsePresentation.COVER_GRID) {
      return this.coverGridMinColumnWidth
    }
    if (mode === NhBrowsePresentation.WATERFALL) {
      return this.waterfallMinColumnWidth
    }
    if (mode === NhBrowsePresentation.WATERFALL_COMPACT) {
      return this.waterfallCompactMinColumnWidth
    }
    if (mode === NhBrowsePresentation.COVER_WALL) {
      return this.coverWallMinColumnWidth
    }
    return 0
  }

  setColumnWidthFor(mode: NhBrowsePresentation, width: number): void {
    if (mode === NhBrowsePresentation.COVER_GRID) {
      this.coverGridMinColumnWidth = width
      return
    }
    if (mode === NhBrowsePresentation.WATERFALL) {
      this.waterfallMinColumnWidth = width
      return
    }
    if (mode === NhBrowsePresentation.WATERFALL_COMPACT) {
      this.waterfallCompactMinColumnWidth = width
      return
    }
    if (mode === NhBrowsePresentation.COVER_WALL) {
      this.coverWallMinColumnWidth = width
    }
  }
}

const BROWSE_PRESENTATION_STATE_KEY: string = 'nextn_browse_presentation'

export function connectBrowsePresentation(): BrowsePresentationState {
  return AppStorageV2.connect(
    BrowsePresentationState,
    BROWSE_PRESENTATION_STATE_KEY,
    (): BrowsePresentationState => new BrowsePresentationState(),
  )!
}
