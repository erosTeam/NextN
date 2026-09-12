import { common } from '@kit.AbilityKit'
import { ReaderDisplayPolicy } from '@reader-kit/core'
import {
  NhReaderColumnMode,
  NhReaderMode,
  NhReaderSpreadLayout,
  ReaderPresentationService,
  ReaderSettingsRepository,
} from 'shared'

/**
 * NextN-owned persistence adapter for neutral reader-kit menu intents.
 *
 * A policy contains both the active layout and dormant choices. Persist only
 * the field represented by the user's action so switching to vertical or
 * continuous mode does not erase the saved horizontal double-page choice.
 */
export class NextNReaderRuntimePreferences {
  static async applyLayout(context: common.UIAbilityContext, policy: ReaderDisplayPolicy): Promise<void> {
    await ReaderPresentationService.restore(context)
    const current = ReaderPresentationService.snapshot()
    let mode: NhReaderMode
    if (policy.layout === 'continuous') mode = NhReaderMode.VERTICAL
    else if (policy.layout === 'single' && policy.pagingAxis === 'vertical') mode = NhReaderMode.PAGED_VERTICAL
    else mode = policy.direction === 'rtl' ? NhReaderMode.PAGED_RTL : NhReaderMode.PAGED
    if (current.mode !== mode) await ReaderPresentationService.setMode(context, mode)
    if (policy.layout === 'single' && policy.pagingAxis === 'horizontal' && current.doublePageEnabled) {
      await ReaderPresentationService.setDoublePageEnabled(context, false)
    } else if (policy.layout === 'spread' && !current.doublePageEnabled) {
      await ReaderPresentationService.setDoublePageEnabled(context, true)
    }
  }

  static async applyDirection(context: common.UIAbilityContext, policy: ReaderDisplayPolicy): Promise<void> {
    // NextN has no persisted RTL variant for vertical paging. Treat the
    // horizontal direction row as dormant in both vertical renderers rather
    // than silently converting a vertical-paged session to horizontal paging.
    if (policy.layout === 'continuous' || policy.pagingAxis === 'vertical') return
    await ReaderPresentationService.restore(context)
    const mode = policy.direction === 'rtl' ? NhReaderMode.PAGED_RTL : NhReaderMode.PAGED
    if (ReaderPresentationService.snapshot().mode !== mode) {
      await ReaderPresentationService.setMode(context, mode)
    }
  }

  static async applySpreadLayout(context: common.UIAbilityContext, policy: ReaderDisplayPolicy): Promise<void> {
    const layout = policy.spreadLayout === 'split' ? NhReaderSpreadLayout.SPLIT : NhReaderSpreadLayout.JOINED
    await ReaderPresentationService.restore(context)
    if (ReaderPresentationService.snapshot().spreadLayoutMode !== layout) {
      await ReaderPresentationService.setSpreadLayout(context, layout)
    }
  }

  static async applyFirstPageAlone(
    context: common.UIAbilityContext,
    galleryId: number,
    policy: ReaderDisplayPolicy,
  ): Promise<void> {
    const mode = policy.firstPageAlone ? NhReaderColumnMode.EVEN_LEFT : NhReaderColumnMode.ODD_LEFT
    if (await ReaderSettingsRepository.columnMode(context, galleryId) !== mode) {
      await ReaderSettingsRepository.saveColumnMode(context, galleryId, mode)
    }
  }

  static async applyCrop(
    context: common.UIAbilityContext,
    policy: ReaderDisplayPolicy,
    enabled: boolean,
  ): Promise<void> {
    await ReaderPresentationService.restore(context)
    const current = ReaderPresentationService.snapshot()
    if (policy.layout === 'continuous') {
      if (current.cropBordersContinuous !== enabled) {
        await ReaderPresentationService.setCropBordersContinuous(context, enabled)
      }
    } else if (current.cropBordersPaged !== enabled) {
      await ReaderPresentationService.setCropBordersPaged(context, enabled)
    }
  }
}
