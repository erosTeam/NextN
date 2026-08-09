import { common } from '@kit.AbilityKit'
import { NhReaderMode, NhReaderPresentation } from '../model/NhReaderSettings'
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

  private static async restoreInternal(context: common.UIAbilityContext): Promise<void> {
    const values: [
      NhReaderMode,
      boolean,
      number,
      boolean,
      number,
      boolean,
      boolean,
      NhReaderTapZoneLayout,
      NhReaderTapZoneInvert,
    ] = await Promise.all([
      ReaderSettingsRepository.mode(context),
      ReaderSettingsRepository.keepScreenOn(context),
      ReaderSettingsRepository.preloadPages(context),
      ReaderSettingsRepository.fullscreen(context),
      ReaderSettingsRepository.autoPageSeconds(context),
      ReaderSettingsRepository.volumeKeyTurn(context),
      ReaderSettingsRepository.doublePageEnabled(context),
      ReaderSettingsRepository.tapZoneLayout(context),
      ReaderSettingsRepository.tapZoneInvert(context),
    ])
    const presentation: NhReaderPresentation = new NhReaderPresentation()
    presentation.mode = values[0]
    presentation.keepScreenOn = values[1]
    presentation.preloadPages = values[2]
    presentation.fullscreen = values[3]
    presentation.autoPageSeconds = values[4]
    presentation.volumeKeyTurn = values[5]
    presentation.doublePageEnabled = values[6]
    presentation.tapZoneLayout = values[7]
    presentation.tapZoneInvert = values[8]
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

  private static normalizeAutoPageSeconds(value: number): number {
    if (!Number.isFinite(value)) {
      return 3
    }
    return Math.max(1, Math.min(60, Math.round(value)))
  }
}
