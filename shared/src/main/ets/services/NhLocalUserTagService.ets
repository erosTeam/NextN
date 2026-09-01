import { common } from '@kit.AbilityKit'
import { NhGallerySummary, NhTag } from '../model/NhGallery'
import {
  NhLocalUserTag,
  NhLocalUserTagContract,
  NhLocalUserTagSettings,
  NhLocalUserTagSnapshot,
} from '../model/NhLocalUserTag'
import { connectLocalUserTags, NhLocalUserTagState } from '../state/NhLocalUserTagState'
import { NhLocalUserTagRepository } from '../storage/NhLocalUserTagRepository'
import { SyncScheduler } from '../sync/SyncScheduler'
import { NhLocalUserTagPresentation } from '../utils/NhLocalUserTagPresentation'
import { NhLocalUserTagRules } from './NhLocalUserTagRules'
import { NhLocalUserTagStore } from './NhLocalUserTagStore'

/** Serialized local writes plus the single runtime index/revision publication path. */
export class NhLocalUserTagService {
  private static writeTail: Promise<void> = Promise.resolve()

  static async restore(context: common.UIAbilityContext): Promise<void> {
    await NhLocalUserTagService.reload(context)
    connectLocalUserTags().isRestored = true
  }

  static async reload(context: common.UIAbilityContext): Promise<void> {
    const snapshot: NhLocalUserTagSnapshot = await NhLocalUserTagRepository.load(context)
    NhLocalUserTagStore.replace(snapshot)
    const state: NhLocalUserTagState = connectLocalUserTags()
    state.revision += 1
  }

  static save(context: common.UIAbilityContext, draft: NhLocalUserTag): Promise<void> {
    return NhLocalUserTagService.enqueueWrite(async (): Promise<void> => {
      if (!NhLocalUserTagContract.isColorCodeValid(draft.colorCode)) {
        throw new Error('Local user tag color must use #RRGGBB')
      }
      await NhLocalUserTagRepository.saveTag(context, draft)
      await NhLocalUserTagService.reload(context)
      SyncScheduler.requestAfterLocalWrite(context, 'local_user_tags')
    })
  }

  static remove(context: common.UIAbilityContext, tagId: number): Promise<void> {
    return NhLocalUserTagService.enqueueWrite(async (): Promise<void> => {
      await NhLocalUserTagRepository.removeTag(context, tagId)
      await NhLocalUserTagService.reload(context)
      SyncScheduler.requestAfterLocalWrite(context, 'local_user_tags')
    })
  }

  static setFilteringThreshold(context: common.UIAbilityContext, value: number): Promise<void> {
    return NhLocalUserTagService.enqueueWrite(async (): Promise<void> => {
      const settings: NhLocalUserTagSettings = new NhLocalUserTagSettings()
      settings.filteringThreshold = NhLocalUserTagContract.normalizeFilteringThreshold(value)
      await NhLocalUserTagRepository.saveSettings(context, settings)
      await NhLocalUserTagService.reload(context)
      SyncScheduler.requestAfterLocalWrite(context, 'local_user_tag_settings')
    })
  }

  static isGalleryFiltered(
    gallery: NhGallerySummary,
    ignoreLocalUserTagFiltering: boolean = false,
  ): boolean {
    return NhLocalUserTagRules.isFiltered(
      gallery.tagIds,
      NhLocalUserTagStore.index(),
      NhLocalUserTagStore.filteringThreshold(),
      ignoreLocalUserTagFiltering,
    )
  }

  static orderedTags(tags: NhTag[]): NhTag[] {
    return NhLocalUserTagPresentation.orderedTags(tags, NhLocalUserTagStore.index())
  }

  static colorCode(tagId: number): string {
    return NhLocalUserTagPresentation.colorCode(tagId, NhLocalUserTagStore.index())
  }

  static readableTextColor(tagId: number): string {
    return NhLocalUserTagPresentation.readableTextColor(NhLocalUserTagService.colorCode(tagId))
  }

  static compactTextColor(tagId: number): string {
    return NhLocalUserTagPresentation.compactTextColor(NhLocalUserTagService.colorCode(tagId))
  }

  static activeTags(): NhLocalUserTag[] {
    return NhLocalUserTagStore.activeTags()
  }

  static filteringThreshold(): number {
    return NhLocalUserTagStore.filteringThreshold()
  }

  private static enqueueWrite(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = NhLocalUserTagService.writeTail.then(operation, operation)
    NhLocalUserTagService.writeTail = queued.catch((): void => {})
    return queued
  }
}
