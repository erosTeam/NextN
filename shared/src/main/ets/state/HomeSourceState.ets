import { AppStorageV2 } from '@kit.ArkUI'
import { NhBrowsePresentation } from '../model/NhBrowsePresentation'

/** The only two public NH sources proven by the current v2 contract. */
export const HOME_SOURCE_LATEST: string = 'latest'
export const HOME_SOURCE_POPULAR: string = 'popular'
/** Mirrors NextE profile display-mode semantics: resolve through the shared Browse preference. */
export const HOME_SOURCE_PRESENTATION_FOLLOW_GLOBAL: string = 'global'

/**
 * The HDS bottomBuilder height, its source pages' top reserve, and the
 * selector component all consume this one value. Keeping them coupled avoids
 * a title-bar canyon or content hidden beneath the selector.
 */
export const HOME_SOURCE_SELECTOR_HEIGHT: number = 38

/** Settled semantic source selection plus page-owned command delivery. */
@ObservedV2
export class HomeSourceState {
  @Trace selectedKey: string = HOME_SOURCE_LATEST
  // NextE's active CustomProfile owns its display-mode override. NextN has
  // two fixed public sources, so retain the same ownership explicitly per
  // source instead of leaking a Home choice into Search/Favorites/History.
  @Trace latestPresentationOverride: string = HOME_SOURCE_PRESENTATION_FOLLOW_GLOBAL
  @Trace popularPresentationOverride: string = HOME_SOURCE_PRESENTATION_FOLLOW_GLOBAL
  // The title-bar action is outside the retained page tree. A sequence keeps
  // repeated requests observable without making it part of source selection.
  @Trace browseOptionsRequestSeq: number = 0
  // Latest supports server-side page numbers; the title-bar jump action is
  // delivered into the retained page exactly like browse options.
  @Trace jumpDialogRequestSeq: number = 0
  // The layout action is likewise owned by the HDS title bar, while its Menu
  // must be anchored inside the retained Home host. Keep it independent from
  // the selected source: layout is a shared presentation preference, not a
  // Latest-only query option.
  @Trace layoutMenuRequestSeq: number = 0
  @Trace manageSubtabsRequestSeq: number = 0
  @Trace editSubtabRequestSeq: number = 0
  @Trace editSubtabUuid: string = ''

  /** `null` is the rendering boundary for the durable follow-global sentinel. */
  presentationOverrideFor(sourceKey: string): NhBrowsePresentation | null {
    const override: string = sourceKey === HOME_SOURCE_POPULAR
      ? this.popularPresentationOverride
      : this.latestPresentationOverride
    return HomeSourceState.normalizePresentationOverride(override)
  }

  setPresentationOverride(sourceKey: string, override: NhBrowsePresentation | null): void {
    const stored: string = override === null ? HOME_SOURCE_PRESENTATION_FOLLOW_GLOBAL : override
    if (sourceKey === HOME_SOURCE_POPULAR) {
      this.popularPresentationOverride = stored
      return
    }
    this.latestPresentationOverride = stored
  }

  /** Unknown persisted values must fall back rather than become a new renderer. */
  static normalizePresentationOverride(value: string): NhBrowsePresentation | null {
    if (value === NhBrowsePresentation.LIST) {
      return NhBrowsePresentation.LIST
    }
    if (value === NhBrowsePresentation.SIMPLE_LIST) {
      return NhBrowsePresentation.SIMPLE_LIST
    }
    if (value === NhBrowsePresentation.COVER_GRID) {
      return NhBrowsePresentation.COVER_GRID
    }
    if (value === NhBrowsePresentation.WATERFALL) {
      return NhBrowsePresentation.WATERFALL
    }
    if (value === NhBrowsePresentation.WATERFALL_COMPACT) {
      return NhBrowsePresentation.WATERFALL_COMPACT
    }
    if (value === NhBrowsePresentation.COVER_WALL) {
      return NhBrowsePresentation.COVER_WALL
    }
    return null
  }
}

/** High-frequency Swiper position stays separate from settled source identity. */
@ObservedV2
export class HomeSourceVisualIndexState {
  @Trace value: number = 0
}

const HOME_SOURCE_STATE_KEY: string = 'nextn_home_source'
const HOME_SOURCE_VISUAL_INDEX_KEY: string = 'nextn_home_source_visual_index'

export function connectHomeSource(): HomeSourceState {
  return AppStorageV2.connect(
    HomeSourceState,
    HOME_SOURCE_STATE_KEY,
    () => new HomeSourceState(),
  )!
}

export function connectHomeSourceVisualIndex(): HomeSourceVisualIndexState {
  return AppStorageV2.connect(
    HomeSourceVisualIndexState,
    HOME_SOURCE_VISUAL_INDEX_KEY,
    () => new HomeSourceVisualIndexState(),
  )!
}

/** Single writer for fixed public-source selection and title-bar commands. */
export class HomeSourceBridge {
  static select(key: string): void {
    const state: HomeSourceState = connectHomeSource()
    if (key.length > 0) {
      state.selectedKey = key
    }
  }

  static requestBrowseOptions(): void {
    const state: HomeSourceState = connectHomeSource()
    state.browseOptionsRequestSeq = state.browseOptionsRequestSeq + 1
  }

  static requestJumpDialog(): void {
    const state: HomeSourceState = connectHomeSource()
    state.jumpDialogRequestSeq = state.jumpDialogRequestSeq + 1
  }

  static requestLayoutMenu(): void {
    const state: HomeSourceState = connectHomeSource()
    state.layoutMenuRequestSeq = state.layoutMenuRequestSeq + 1
  }

  static requestManageSubtabs(): void {
    const state: HomeSourceState = connectHomeSource()
    state.manageSubtabsRequestSeq = state.manageSubtabsRequestSeq + 1
  }

  static requestEditSubtab(uuid: string): void {
    if (uuid.length === 0) {
      return
    }
    const state: HomeSourceState = connectHomeSource()
    state.editSubtabUuid = uuid
    state.editSubtabRequestSeq = state.editSubtabRequestSeq + 1
  }
}
