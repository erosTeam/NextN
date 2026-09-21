import { AppStorageV2 } from '@kit.ArkUI'
import {
  NhReaderBackgroundMode,
  NhReaderImageScalingQuality,
  NhReaderMode,
  NhReaderPresentation,
  NhReaderImplementation,
  NhReaderSpreadLayout,
  NhReaderSuperResolutionModel,
  READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT,
} from '../model/NhReaderSettings'
import { NhReaderTapZoneInvert, NhReaderTapZoneLayout } from '../model/NhReaderTapZone'
import { ReaderPageCropStrength } from '../model/ReaderPageCropBounds'

/**
 * The live, app-private Reader presentation signal.  Repository reads and
 * writes remain the durable boundary; this state only lets an already-open
 * Reader and its settings sheet react to the same local choice immediately.
 */
@ObservedV2
export class ReaderPresentationState {
  @Trace mode: NhReaderMode = NhReaderMode.PAGED
  @Trace keepScreenOn: boolean = true
  @Trace preloadPages: number = 2
  @Trace showPageNumber: boolean = true
  @Trace backgroundMode: NhReaderBackgroundMode = NhReaderBackgroundMode.BLACK
  @Trace imageScalingQuality: NhReaderImageScalingQuality = NhReaderImageScalingQuality.MEDIUM
  @Trace fullscreen: boolean = true
  @Trace autoPageSeconds: number = 3
  @Trace volumeKeyTurn: boolean = false
  @Trace doublePageEnabled: boolean = false
  @Trace spreadLayoutMode: NhReaderSpreadLayout = NhReaderSpreadLayout.JOINED
  @Trace pageTurnAnimation: boolean = true
  @Trace tapZoneLayoutPaged: NhReaderTapZoneLayout = NhReaderTapZoneLayout.RIGHT_LEFT
  @Trace tapZoneInvertPaged: NhReaderTapZoneInvert = NhReaderTapZoneInvert.NONE
  @Trace tapZoneLayoutContinuous: NhReaderTapZoneLayout = NhReaderTapZoneLayout.RIGHT_LEFT
  @Trace tapZoneInvertContinuous: NhReaderTapZoneInvert = NhReaderTapZoneInvert.NONE
  @Trace cropBordersPaged: boolean = false
  @Trace cropBordersContinuous: boolean = false
  @Trace cropStrengthPaged: string = ReaderPageCropStrength.STANDARD
  @Trace cropStrengthContinuous: string = ReaderPageCropStrength.STANDARD
  @Trace superResolutionEnabled: boolean = false
  @Trace superResolutionModel: NhReaderSuperResolutionModel =
    NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X
  @Trace superResolutionMaxHeight: number = READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT
  @Trace readerImplementation: NhReaderImplementation = NhReaderImplementation.SHARED

  replace(presentation: NhReaderPresentation): void {
    this.mode = presentation.mode
    this.keepScreenOn = presentation.keepScreenOn
    this.preloadPages = presentation.preloadPages
    this.showPageNumber = presentation.showPageNumber
    this.backgroundMode = presentation.backgroundMode
    this.imageScalingQuality = presentation.imageScalingQuality
    this.fullscreen = presentation.fullscreen
    this.autoPageSeconds = presentation.autoPageSeconds
    this.volumeKeyTurn = presentation.volumeKeyTurn
    this.doublePageEnabled = presentation.doublePageEnabled
    this.spreadLayoutMode = presentation.spreadLayoutMode
    this.pageTurnAnimation = presentation.pageTurnAnimation
    this.tapZoneLayoutPaged = presentation.tapZoneLayoutPaged
    this.tapZoneInvertPaged = presentation.tapZoneInvertPaged
    this.tapZoneLayoutContinuous = presentation.tapZoneLayoutContinuous
    this.tapZoneInvertContinuous = presentation.tapZoneInvertContinuous
    this.cropBordersPaged = presentation.cropBordersPaged
    this.cropBordersContinuous = presentation.cropBordersContinuous
    this.cropStrengthPaged = presentation.cropStrengthPaged
    this.cropStrengthContinuous = presentation.cropStrengthContinuous
    this.superResolutionEnabled = presentation.superResolutionEnabled
    this.superResolutionModel = presentation.superResolutionModel
    this.superResolutionMaxHeight = presentation.superResolutionMaxHeight
    this.readerImplementation = presentation.readerImplementation
  }

  snapshot(): NhReaderPresentation {
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
    result.tapZoneLayoutPaged = this.tapZoneLayoutPaged
    result.tapZoneInvertPaged = this.tapZoneInvertPaged
    result.tapZoneLayoutContinuous = this.tapZoneLayoutContinuous
    result.tapZoneInvertContinuous = this.tapZoneInvertContinuous
    result.cropBordersPaged = this.cropBordersPaged
    result.cropBordersContinuous = this.cropBordersContinuous
    result.cropStrengthPaged = this.cropStrengthPaged
    result.cropStrengthContinuous = this.cropStrengthContinuous
    result.superResolutionEnabled = this.superResolutionEnabled
    result.superResolutionModel = this.superResolutionModel
    result.superResolutionMaxHeight = this.superResolutionMaxHeight
    result.readerImplementation = this.readerImplementation
    return result
  }

  activeTapZoneLayout(): NhReaderTapZoneLayout {
    return this.mode === NhReaderMode.VERTICAL ? this.tapZoneLayoutContinuous : this.tapZoneLayoutPaged
  }

  activeTapZoneInvert(): NhReaderTapZoneInvert {
    return this.mode === NhReaderMode.VERTICAL ? this.tapZoneInvertContinuous : this.tapZoneInvertPaged
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
