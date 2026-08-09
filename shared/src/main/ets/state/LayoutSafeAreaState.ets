import { AppStorageV2 } from '@kit.ArkUI'

/**
 * App-wide display and root-navigation metrics.
 *
 * The app deliberately keeps this state small: HDS navigation owns the
 * title/tab chrome while page content consumes only the remaining scroll
 * reserves. EntryAbility publishes window metrics; the root HDS container
 * publishes its resolved physical Split/Stack result. Reader stays out of
 * this contract because its immersive chrome has separate behavior.
 */
@ObservedV2
export class LayoutSafeAreaState {
  // Main-window dimensions are published in px by EntryAbility.  They are a
  // neutral geometry signal for a later tablet-layout phase; no consumer uses
  // them to switch navigation modes in this phase.
  @Trace mainWindowWidthPx: number = 0
  @Trace mainWindowHeightPx: number = 0
  @Trace topAvoidHeight: number = 0
  @Trace bottomAvoidHeight: number = 0
  // Policy can request NavigationMode.Auto, but only HDS knows whether the
  // current root width actually resolved to Split. Destination-level layout
  // must consume this signal instead of inferring physical mode from policy.
  @Trace rootNavigationSplit: boolean = false
  // A GalleryDetail destination can be recreated while its pane width remains
  // stable. Cache one measured width for each resolved root mode so a later
  // wide-detail implementation has a first-frame signal without treating a
  // Stack pane as a Split pane. Zero means unknown.
  @Trace galleryDetailStackContentWidth: number = 0
  @Trace galleryDetailSplitContentWidth: number = 0

  rememberedGalleryDetailContentWidth(rootNavigationSplit: boolean): number {
    return rootNavigationSplit
      ? this.galleryDetailSplitContentWidth
      : this.galleryDetailStackContentWidth
  }
}

const LAYOUT_SAFE_AREA_V2_KEY: string = 'nextn_layout_safe_area'

/** Connect a ComponentV2 consumer to the single app-wide inset state. */
export function connectLayoutSafeArea(): LayoutSafeAreaState {
  return AppStorageV2.connect(
    LayoutSafeAreaState,
    LAYOUT_SAFE_AREA_V2_KEY,
    () => new LayoutSafeAreaState(),
  )!
}

/**
 * EntryAbility owns insets/window geometry; the root HDS container owns its
 * resolved split result. Keeping both publish points here leaves destination
 * pages read-only consumers of one reactive layout state.
 */
export class LayoutSafeAreaBridge {
  static publishMainWindowSizePx(widthPx: number, heightPx: number): void {
    const state: LayoutSafeAreaState = connectLayoutSafeArea()
    const width: number = Math.max(0, widthPx)
    const height: number = Math.max(0, heightPx)
    if (state.mainWindowWidthPx !== width) {
      state.mainWindowWidthPx = width
    }
    if (state.mainWindowHeightPx !== height) {
      state.mainWindowHeightPx = height
    }
  }

  static publishInsets(topAvoidHeight: number, bottomAvoidHeight: number): void {
    const state: LayoutSafeAreaState = connectLayoutSafeArea()
    const top: number = Math.max(0, topAvoidHeight)
    const bottom: number = Math.max(0, bottomAvoidHeight)
    if (state.topAvoidHeight !== top) {
      state.topAvoidHeight = top
    }
    if (state.bottomAvoidHeight !== bottom) {
      state.bottomAvoidHeight = bottom
    }
  }

  static publishRootNavigationSplit(isSplitMode: boolean): void {
    const state: LayoutSafeAreaState = connectLayoutSafeArea()
    if (state.rootNavigationSplit !== isSplitMode) {
      state.rootNavigationSplit = isSplitMode
    }
  }

  static publishGalleryDetailContentWidth(width: number, rootNavigationSplit: boolean): void {
    const state: LayoutSafeAreaState = connectLayoutSafeArea()
    const normalizedWidth: number = Math.max(0, width)
    if (rootNavigationSplit) {
      if (state.galleryDetailSplitContentWidth !== normalizedWidth) {
        state.galleryDetailSplitContentWidth = normalizedWidth
      }
      return
    }
    if (state.galleryDetailStackContentWidth !== normalizedWidth) {
      state.galleryDetailStackContentWidth = normalizedWidth
    }
  }

  static invalidateGalleryDetailContentWidths(): void {
    const state: LayoutSafeAreaState = connectLayoutSafeArea()
    if (state.galleryDetailStackContentWidth !== 0) {
      state.galleryDetailStackContentWidth = 0
    }
    if (state.galleryDetailSplitContentWidth !== 0) {
      state.galleryDetailSplitContentWidth = 0
    }
  }
}
