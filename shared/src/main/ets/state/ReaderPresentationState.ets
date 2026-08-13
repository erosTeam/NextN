import { AppStorageV2 } from '@kit.ArkUI'
import {
  NhReaderMode,
  NhReaderPresentation,
  NhReaderSuperResolutionModel,
  READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT,
} from '../model/NhReaderSettings'
import { NhReaderTapZoneInvert, NhReaderTapZoneLayout } from '../model/NhReaderTapZone'

/**
 * The live, app-private Reader presentation signal.  Repository reads and
 * writes remain the durable boundary; this state only lets an already-open
 * Reader and its settings sheet react to the same local choice immediately.
 */
@ObservedV2
export class ReaderPresentationState {
  @Trace mode: NhReaderMode = NhReaderMode.VERTICAL
  @Trace keepScreenOn: boolean = true
  @Trace preloadPages: number = 2
  @Trace showPageNumber: boolean = true
  @Trace fullscreen: boolean = true
  @Trace autoPageSeconds: number = 3
  @Trace volumeKeyTurn: boolean = false
  @Trace doublePageEnabled: boolean = false
  @Trace tapZoneLayout: NhReaderTapZoneLayout = NhReaderTapZoneLayout.RIGHT_LEFT
  @Trace tapZoneInvert: NhReaderTapZoneInvert = NhReaderTapZoneInvert.NONE
  @Trace superResolutionEnabled: boolean = false
  @Trace superResolutionModel: NhReaderSuperResolutionModel =
    NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X
  @Trace superResolutionMaxHeight: number = READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT

  replace(presentation: NhReaderPresentation): void {
    this.mode = presentation.mode
    this.keepScreenOn = presentation.keepScreenOn
    this.preloadPages = presentation.preloadPages
    this.showPageNumber = presentation.showPageNumber
    this.fullscreen = presentation.fullscreen
    this.autoPageSeconds = presentation.autoPageSeconds
    this.volumeKeyTurn = presentation.volumeKeyTurn
    this.doublePageEnabled = presentation.doublePageEnabled
    this.tapZoneLayout = presentation.tapZoneLayout
    this.tapZoneInvert = presentation.tapZoneInvert
    this.superResolutionEnabled = presentation.superResolutionEnabled
    this.superResolutionModel = presentation.superResolutionModel
    this.superResolutionMaxHeight = presentation.superResolutionMaxHeight
  }

  snapshot(): NhReaderPresentation {
    const result: NhReaderPresentation = new NhReaderPresentation()
    result.mode = this.mode
    result.keepScreenOn = this.keepScreenOn
    result.preloadPages = this.preloadPages
    result.showPageNumber = this.showPageNumber
    result.fullscreen = this.fullscreen
    result.autoPageSeconds = this.autoPageSeconds
    result.volumeKeyTurn = this.volumeKeyTurn
    result.doublePageEnabled = this.doublePageEnabled
    result.tapZoneLayout = this.tapZoneLayout
    result.tapZoneInvert = this.tapZoneInvert
    result.superResolutionEnabled = this.superResolutionEnabled
    result.superResolutionModel = this.superResolutionModel
    result.superResolutionMaxHeight = this.superResolutionMaxHeight
    return result
  }
}

const READER_PRESENTATION_STATE_KEY: string = 'nextn_reader_presentation'

/** Returns the one local presentation signal shared by Reader and Settings. */
export function connectReaderPresentation(): ReaderPresentationState {
  return AppStorageV2.connect(
    ReaderPresentationState,
    READER_PRESENTATION_STATE_KEY,
    (): ReaderPresentationState => new ReaderPresentationState(),
  )!
}
