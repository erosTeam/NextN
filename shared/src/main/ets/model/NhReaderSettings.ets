import { NhReaderTapZoneInvert, NhReaderTapZoneLayout } from './NhReaderTapZone'

/**
 * Reader presentation stays wholly on-device. These modes change only how
 * already-authorized reader pages are navigated; they never affect requests,
 * caching policy, history semantics, or remote state.
 */
export enum NhReaderMode {
  VERTICAL = 'vertical',
  /** Legacy persisted value retained as the left-to-right paged default. */
  PAGED = 'paged',
  PAGED_RTL = 'paged_rtl',
  PAGED_VERTICAL = 'paged_vertical',
}

/** Geometry of an eligible two-page Reader spread; page pairing remains separate. */
export enum NhReaderSpreadLayout {
  JOINED = 'joined',
  SPLIT = 'split',
}

/** Final Reader image sampling only; it never changes source or cache identity. */
export enum NhReaderImageScalingQuality {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
}

/** Local Reader canvas palette; Auto follows the effective app theme. */
export enum NhReaderBackgroundMode {
  BLACK = 'black',
  GRAY = 'gray',
  WHITE = 'white',
  AUTO = 'auto',
}

/**
 * The user-selected local enhancement model. The identifiers are durable
 * reader preferences, never model-file paths or a network selection.
 */
export enum NhReaderSuperResolutionModel {
  WAIFU2X_ART_NOISE0_2X = 'waifu2x_art_noise0_2x',
  WAIFU2X_PHOTO_NOISE0_2X = 'waifu2x_photo_noise0_2x',
  REAL_ESRGAN_X2PLUS = 'realesrgan_x2plus',
  SYSTEM_CORE_VISION = 'system_core_vision',
}

/** Bounded local decode choices shared by Settings, persistence, and Reader. */
export const READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT: number = 2000
export const READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT_CHOICES: number[] = [1000, 1500, 2000]

/**
 * One local Reader presentation snapshot.  It is deliberately separate from
 * gallery data and request state: changing one of these values must preserve
 * the current Reader route, source-page index, cache, and history boundary.
 */
export class NhReaderPresentation {
  mode: NhReaderMode = NhReaderMode.VERTICAL
  keepScreenOn: boolean = true
  preloadPages: number = 2
  /** Keep the canonical page range visible while Reader chrome is hidden. */
  showPageNumber: boolean = true
  /** Preserve the existing black Reader canvas for installations without this key. */
  backgroundMode: NhReaderBackgroundMode = NhReaderBackgroundMode.BLACK
  /** Explicitly use Mipmap instead of ArkUI Image's default low sampling. */
  imageScalingQuality: NhReaderImageScalingQuality = NhReaderImageScalingQuality.MEDIUM
  fullscreen: boolean = true
  autoPageSeconds: number = 3
  volumeKeyTurn: boolean = false
  /**
   * This remains a request rather than an effective-layout flag.  A narrow
   * Reader canvas falls back to one page without overwriting the user's
   * preference, so rotating or moving to a wide window can restore spreads.
  */
  doublePageEnabled: boolean = false
  /** Preserve existing ratio-sized spreads unless the user explicitly chooses equal panes. */
  spreadLayoutMode: NhReaderSpreadLayout = NhReaderSpreadLayout.JOINED
  /** Animate only adjacent programmatic Pager moves; direct Swipe stays component-owned. */
  pageTurnAnimation: boolean = true
  tapZoneLayout: NhReaderTapZoneLayout = NhReaderTapZoneLayout.RIGHT_LEFT
  tapZoneInvert: NhReaderTapZoneInvert = NhReaderTapZoneInvert.NONE
  /** Explicit opt-in; the original Reader image always remains available. */
  superResolutionEnabled: boolean = false
  /** Existing installations resolve to the original art model without a migration download. */
  superResolutionModel: NhReaderSuperResolutionModel = NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X
  /** The largest source edge accepted for local enhancement decoding. */
  superResolutionMaxHeight: number = READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT

  copy(): NhReaderPresentation {
    const result: NhReaderPresentation = new NhReaderPresentation()
    result.mode = this.mode
    result.keepScreenOn = this.keepScreenOn
    result.preloadPages = this.preloadPages
    result.showPageNumber = this.showPageNumber
    result.backgroundMode = this.backgroundMode
    result.imageScalingQuality = this.imageScalingQuality
    result.fullscreen = this.fullscreen
    result.autoPageSeconds = this.autoPageSeconds
    result.volumeKeyTurn = this.volumeKeyTurn
    result.doublePageEnabled = this.doublePageEnabled
    result.spreadLayoutMode = this.spreadLayoutMode
    result.pageTurnAnimation = this.pageTurnAnimation
    result.tapZoneLayout = this.tapZoneLayout
    result.tapZoneInvert = this.tapZoneInvert
    result.superResolutionEnabled = this.superResolutionEnabled
    result.superResolutionModel = this.superResolutionModel
    result.superResolutionMaxHeight = this.superResolutionMaxHeight
    return result
  }
}
