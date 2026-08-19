import { common } from '@kit.AbilityKit'
import { NhGallerySummary } from '../model/NhGallery'
import { connectCloudBlacklist } from '../state/NhCloudBlacklistState'
import { NhCloudBlacklistRepository } from '../storage/NhCloudBlacklistRepository'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

/**
 * Owns the durable cloud tag-blacklist id set used by every gallery list
 * surface. The fetch itself lives in NhApiClient (authenticated v2); this
 * service keeps the state, persistence and the local filter predicate so a
 * transport failure can never block or fail list rendering.
 */
export class NhCloudBlacklistService {
  private static context: common.UIAbilityContext | null = null

  static rememberContext(context: common.UIAbilityContext): void {
    NhCloudBlacklistService.context = context
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    NhCloudBlacklistService.rememberContext(context)
    try {
      const ids: number[] = await NhCloudBlacklistRepository.load(context)
      const state = connectCloudBlacklist()
      state.ids = ids
      state.isRestored = true
      state.revision += 1
    } catch (error) {
      const state = connectCloudBlacklist()
      state.isRestored = true
      DiagnosticLogger.warn('account', 'cloud_blacklist_restore_failed', (error as Error).message)
    }
  }

  /** Applies a freshly fetched id set and persists it best-effort. */
  static applyFreshIds(ids: number[]): void {
    const state = connectCloudBlacklist()
    const normalized: number[] = []
    for (let index: number = 0; index < ids.length; index++) {
      const id: number = Math.floor(ids[index])
      if (id > 0 && normalized.indexOf(id) < 0) {
        normalized.push(id)
      }
    }
    state.ids = normalized
    state.revision += 1
    const context: common.UIAbilityContext | null = NhCloudBlacklistService.context
    if (context !== null) {
      NhCloudBlacklistRepository.save(context, normalized).catch((): void => {})
    }
  }

  static isGalleryCloudBlacklisted(gallery: NhGallerySummary): boolean {
    const state = connectCloudBlacklist()
    if (state.ids.length === 0 || gallery.tagIds.length === 0) {
      return false
    }
    for (let index: number = 0; index < state.ids.length; index++) {
      if (gallery.tagIds.indexOf(state.ids[index]) >= 0) {
        return true
      }
    }
    return false
  }
}
