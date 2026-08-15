import { AppStorageV2 } from '@kit.ArkUI'
import { NhBrowsePresentation } from '../model/NhBrowsePresentation'

@ObservedV2
export class BrowsePresentationState {
  // Waterfall is the out-of-box view: it is the only list surface that can
  // show translated tags next to covers. Installed users keep their saved
  // mode; this default applies only to fresh or unknown persisted values.
  @Trace mode: NhBrowsePresentation = NhBrowsePresentation.WATERFALL
  // Grid-like presentations store a minimum comfortable column width rather
  // than a fixed count. A zero preserves the corresponding NextE base token
  // so rotation, folding, and split width always derive a fresh column count.
  @Trace coverGridMinColumnWidth: number = 0
  @Trace waterfallMinColumnWidth: number = 0
  @Trace waterfallCompactMinColumnWidth: number = 0
  @Trace coverWallMinColumnWidth: number = 0
  /**
   * Keep resolved labels visible by default. An explicit saved false still lets
   * the user hide tags, but an absent legacy key must not suppress the only
   * list surface that can show translated labels.
   */
  @Trace showGalleryTags: boolean = true
  /** Keep raw tag query values separate from the optional translated display label. */
  @Trace showTranslatedTagLabels: boolean = true
  /** Preserve the current fixed LIST row height by default; the user can opt into adaptive height globally. */
  @Trace listCardFixedHeight: boolean = true

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
