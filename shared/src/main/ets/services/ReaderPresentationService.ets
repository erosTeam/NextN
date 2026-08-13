import { common } from '@kit.AbilityKit'
import {
  NhReaderBackgroundMode,
  NhReaderImageScalingQuality,
  NhReaderMode,
  NhReaderPresentation,
  NhReaderSpreadLayout,
  NhReaderSuperResolutionModel,
  READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT,
  READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT_CHOICES,
} from '../model/NhReaderSettings'
import {
  NhReaderTapZoneInvert,
  NhReaderTapZoneLayout,
  NhReaderTapZoneResolver,
} from '../model/NhReaderTapZone'
import { connectReaderPresentation, ReaderPresentationState } from '../state/ReaderPresentationState'
import { ReaderSettingsRepository } from '../storage/ReaderSettingsRepository'

/**
 * Keeps the durable Reader preference repository and the live presentation
 * signal in one order.  Publication intentionally happens before the queued
 * RDB write, so a sheet choice changes the currently open Reader instead of
 * waiting for that Reader to be reopened.
 */
export class ReaderPresentationService {
  private static restoreTask: Promise<void> | null = null
  private static restored: boolean = false

  static async restore(context: common.UIAbilityContext): Promise<void> {
    if (ReaderPresentationService.restored) {
      return
    }
    if (ReaderPresentationService.restoreTask !== null) {
      await ReaderPresentationService.restoreTask
      return
    }
    const task: Promise<void> = ReaderPresentationService.restoreInternal(context)
    ReaderPresentationService.restoreTask = task
    try {
      await task
      ReaderPresentationService.restored = true
    } finally {
      ReaderPresentationService.restoreTask = null
    }
  }

  static snapshot(): NhReaderPresentation {
    return ReaderPresentationService.state().snapshot()
  }

  static setMode(context: common.UIAbilityContext, mode: NhReaderMode): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.mode = ReaderPresentationService.normalizeMode(mode)
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveMode(context, presentation.mode)
    })
  }

  static setKeepScreenOn(context: common.UIAbilityContext, enabled: boolean): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.keepScreenOn = enabled
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveKeepScreenOn(context, presentation.keepScreenOn)
    })
  }

  static setPreloadPages(context: common.UIAbilityContext, pages: number): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.preloadPages = ReaderPresentationService.normalizePreloadPages(pages)
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.savePreloadPages(context, presentation.preloadPages)
    })
  }

  static setShowPageNumber(context: common.UIAbilityContext, enabled: boolean): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.showPageNumber = enabled
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveShowPageNumber(context, presentation.showPageNumber)
    })
  }

  static setImageScalingQuality(
    context: common.UIAbilityContext,
    quality: NhReaderImageScalingQuality,
  ): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.imageScalingQuality = ReaderPresentationService.normalizeImageScalingQuality(quality)
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveImageScalingQuality(context, presentation.imageScalingQuality)
    })
  }

  static setBackgroundMode(
    context: common.UIAbilityContext,
    mode: NhReaderBackgroundMode,
  ): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.backgroundMode = ReaderPresentationService.normalizeBackgroundMode(mode)
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveBackgroundMode(context, presentation.backgroundMode)
    })
  }

  static setFullscreen(context: common.UIAbilityContext, enabled: boolean): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.fullscreen = enabled
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveFullscreen(context, presentation.fullscreen)
    })
  }

  static setAutoPageSeconds(context: common.UIAbilityContext, seconds: number): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.autoPageSeconds = ReaderPresentationService.normalizeAutoPageSeconds(seconds)
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveAutoPageSeconds(context, presentation.autoPageSeconds)
    })
  }

  static setVolumeKeyTurn(context: common.UIAbilityContext, enabled: boolean): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.volumeKeyTurn = enabled
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveVolumeKeyTurn(context, presentation.volumeKeyTurn)
    })
  }

  static setDoublePageEnabled(context: common.UIAbilityContext, enabled: boolean): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.doublePageEnabled = enabled
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveDoublePageEnabled(context, presentation.doublePageEnabled)
    })
  }

  static setSpreadLayout(
    context: common.UIAbilityContext,
    layout: NhReaderSpreadLayout,
  ): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.spreadLayoutMode = ReaderPresentationService.normalizeSpreadLayout(layout)
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveSpreadLayout(context, presentation.spreadLayoutMode)
    })
  }

  static setPageTurnAnimation(context: common.UIAbilityContext, enabled: boolean): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.pageTurnAnimation = enabled
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.savePageTurnAnimation(context, presentation.pageTurnAnimation)
    })
  }

  static setTapZoneLayout(
    context: common.UIAbilityContext,
    layout: NhReaderTapZoneLayout,
  ): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.tapZoneLayout = NhReaderTapZoneResolver.normalizeLayout(layout)
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveTapZoneLayout(
        context,
        presentation.tapZoneLayout,
      )
    })
  }

  static setTapZoneInvert(
    context: common.UIAbilityContext,
    invert: NhReaderTapZoneInvert,
  ): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.tapZoneInvert = NhReaderTapZoneResolver.normalizeInvert(invert)
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveTapZoneInvert(
        context,
        presentation.tapZoneInvert,
      )
    })
  }

  static setSuperResolutionEnabled(
    context: common.UIAbilityContext,
    enabled: boolean,
  ): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.superResolutionEnabled = enabled
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveSuperResolutionEnabled(
        context,
        presentation.superResolutionEnabled,
      )
    })
  }

  static setSuperResolutionModel(
    context: common.UIAbilityContext,
    model: NhReaderSuperResolutionModel,
  ): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.superResolutionModel = ReaderPresentationService.normalizeSuperResolutionModel(model)
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveSuperResolutionModel(
        context,
        presentation.superResolutionModel,
      )
    })
  }

  static setSuperResolutionMaxHeight(
    context: common.UIAbilityContext,
    height: number,
  ): Promise<NhReaderPresentation> {
    return ReaderPresentationService.update(context, (presentation: NhReaderPresentation): void => {
      presentation.superResolutionMaxHeight = ReaderPresentationService.normalizeSuperResolutionMaxHeight(height)
    }, (presentation: NhReaderPresentation): Promise<void> => {
      return ReaderSettingsRepository.saveSuperResolutionMaxHeight(
        context,
        presentation.superResolutionMaxHeight,
      )
    })
  }

  private static async restoreInternal(context: common.UIAbilityContext): Promise<void> {
    const values: [
      NhReaderMode,
      boolean,
      number,
      boolean,
      NhReaderBackgroundMode,
      NhReaderImageScalingQuality,
      boolean,
      number,
      boolean,
      boolean,
      NhReaderSpreadLayout,
      boolean,
      NhReaderTapZoneLayout,
      NhReaderTapZoneInvert,
      boolean,
      NhReaderSuperResolutionModel,
      number,
    ] = await Promise.all([
      ReaderSettingsRepository.mode(context),
      ReaderSettingsRepository.keepScreenOn(context),
      ReaderSettingsRepository.preloadPages(context),
      ReaderSettingsRepository.showPageNumber(context),
      ReaderSettingsRepository.backgroundMode(context),
      ReaderSettingsRepository.imageScalingQuality(context),
      ReaderSettingsRepository.fullscreen(context),
      ReaderSettingsRepository.autoPageSeconds(context),
      ReaderSettingsRepository.volumeKeyTurn(context),
      ReaderSettingsRepository.doublePageEnabled(context),
      ReaderSettingsRepository.spreadLayout(context),
      ReaderSettingsRepository.pageTurnAnimation(context),
      ReaderSettingsRepository.tapZoneLayout(context),
      ReaderSettingsRepository.tapZoneInvert(context),
      ReaderSettingsRepository.superResolutionEnabled(context),
      ReaderSettingsRepository.superResolutionModel(context),
      ReaderSettingsRepository.superResolutionMaxHeight(context),
    ])
    const presentation: NhReaderPresentation = new NhReaderPresentation()
    presentation.mode = values[0]
    presentation.keepScreenOn = values[1]
    presentation.preloadPages = values[2]
    presentation.showPageNumber = values[3]
    presentation.backgroundMode = values[4]
    presentation.imageScalingQuality = values[5]
    presentation.fullscreen = values[6]
    presentation.autoPageSeconds = values[7]
    presentation.volumeKeyTurn = values[8]
    presentation.doublePageEnabled = values[9]
    presentation.spreadLayoutMode = values[10]
    presentation.pageTurnAnimation = values[11]
    presentation.tapZoneLayout = values[12]
    presentation.tapZoneInvert = values[13]
    presentation.superResolutionEnabled = values[14]
    presentation.superResolutionModel = values[15]
    presentation.superResolutionMaxHeight = values[16]
    ReaderPresentationService.state().replace(presentation)
  }

  private static async update(
    context: common.UIAbilityContext,
    mutate: (presentation: NhReaderPresentation) => void,
    persist: (presentation: NhReaderPresentation) => Promise<void>,
  ): Promise<NhReaderPresentation> {
    await ReaderPresentationService.restore(context)
    const presentation: NhReaderPresentation = ReaderPresentationService.snapshot()
    mutate(presentation)
    ReaderPresentationService.state().replace(presentation)
    await persist(presentation)
    return presentation.copy()
  }

  private static state(): ReaderPresentationState {
    return connectReaderPresentation()
  }

  private static normalizeMode(mode: NhReaderMode): NhReaderMode {
    if (mode === NhReaderMode.PAGED || mode === NhReaderMode.PAGED_RTL || mode === NhReaderMode.PAGED_VERTICAL) {
      return mode
    }
    return NhReaderMode.VERTICAL
  }

  private static normalizePreloadPages(value: number): number {
    if (!Number.isFinite(value)) {
      return 2
    }
    return Math.max(0, Math.min(5, Math.round(value)))
  }

  private static normalizeImageScalingQuality(value: NhReaderImageScalingQuality): NhReaderImageScalingQuality {
    if (value === NhReaderImageScalingQuality.LOW || value === NhReaderImageScalingQuality.HIGH) {
      return value
    }
    return NhReaderImageScalingQuality.MEDIUM
  }

  private static normalizeBackgroundMode(value: NhReaderBackgroundMode): NhReaderBackgroundMode {
    if (value === NhReaderBackgroundMode.GRAY ||
      value === NhReaderBackgroundMode.WHITE ||
      value === NhReaderBackgroundMode.AUTO) {
      return value
    }
    return NhReaderBackgroundMode.BLACK
  }

  private static normalizeSpreadLayout(value: NhReaderSpreadLayout): NhReaderSpreadLayout {
    return value === NhReaderSpreadLayout.SPLIT ? NhReaderSpreadLayout.SPLIT : NhReaderSpreadLayout.JOINED
  }

  private static normalizeAutoPageSeconds(value: number): number {
    if (!Number.isFinite(value)) {
      return 3
    }
    return Math.max(1, Math.min(60, Math.round(value)))
  }

  private static normalizeSuperResolutionMaxHeight(value: number): number {
    const normalized: number = Math.round(value)
    for (let index: number = 0; index < READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT_CHOICES.length; index++) {
      if (normalized === READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT_CHOICES[index]) {
        return normalized
      }
    }
    return READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT
  }

  private static normalizeSuperResolutionModel(value: NhReaderSuperResolutionModel): NhReaderSuperResolutionModel {
    if (value === NhReaderSuperResolutionModel.WAIFU2X_PHOTO_NOISE0_2X ||
      value === NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X ||
      value === NhReaderSuperResolutionModel.REAL_ESRGAN_X2PLUS) {
      return value
    }
    return NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X
  }
}
