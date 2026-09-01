import { common } from '@kit.AbilityKit'
import { NhCatalogPreferences } from '../model/NhCatalogPreferences'
import { NhSearchLanguage, NhSearchSort } from '../model/NhSearchOptions'
import { CatalogPreferencesRepository } from '../storage/CatalogPreferencesRepository'
import { CatalogPreferencesState, connectCatalogPreferences } from '../state/CatalogPreferencesState'

/**
 * One restore/write boundary for anonymous catalog defaults. It publishes the
 * current local choice to reactive surfaces before its serialized save, so a
 * rapid language+sort edit cannot overwrite the first choice with a stale
 * snapshot. It never changes v2 request grammar, histories, account state,
 * or the standalone Popular route.
 */
export class CatalogPreferencesService {
  private static restoreTask: Promise<void> | null = null
  private static restored: boolean = false

  static async restore(context: common.UIAbilityContext): Promise<void> {
    if (CatalogPreferencesService.restored) {
      return
    }
    if (CatalogPreferencesService.restoreTask !== null) {
      await CatalogPreferencesService.restoreTask
      return
    }
    const task: Promise<void> = CatalogPreferencesService.restoreInternal(context)
    CatalogPreferencesService.restoreTask = task
    try {
      await task
      CatalogPreferencesService.restored = true
    } finally {
      CatalogPreferencesService.restoreTask = null
    }
  }

  static snapshot(): NhCatalogPreferences {
    return CatalogPreferencesService.state().snapshot()
  }

  static async setBrowseLanguage(
    context: common.UIAbilityContext,
    language: NhSearchLanguage,
  ): Promise<NhCatalogPreferences> {
    await CatalogPreferencesService.restore(context)
    const preferences: NhCatalogPreferences = CatalogPreferencesService.snapshot()
    preferences.browseLanguage = language
    return CatalogPreferencesService.saveAfterRestore(context, preferences)
  }

  static async setBrowseSort(
    context: common.UIAbilityContext,
    sort: NhSearchSort,
  ): Promise<NhCatalogPreferences> {
    await CatalogPreferencesService.restore(context)
    const preferences: NhCatalogPreferences = CatalogPreferencesService.snapshot()
    preferences.browseSort = sort
    return CatalogPreferencesService.saveAfterRestore(context, preferences)
  }

  static async setSearchLanguage(
    context: common.UIAbilityContext,
    language: NhSearchLanguage,
  ): Promise<NhCatalogPreferences> {
    await CatalogPreferencesService.restore(context)
    const preferences: NhCatalogPreferences = CatalogPreferencesService.snapshot()
    preferences.searchLanguage = language
    return CatalogPreferencesService.saveAfterRestore(context, preferences)
  }

  static async setSearchSort(
    context: common.UIAbilityContext,
    sort: NhSearchSort,
  ): Promise<NhCatalogPreferences> {
    await CatalogPreferencesService.restore(context)
    const preferences: NhCatalogPreferences = CatalogPreferencesService.snapshot()
    preferences.searchSort = sort
    return CatalogPreferencesService.saveAfterRestore(context, preferences)
  }

  static async setSearchIgnoreLocalUserTagFiltering(
    context: common.UIAbilityContext,
    ignore: boolean,
  ): Promise<NhCatalogPreferences> {
    await CatalogPreferencesService.restore(context)
    const preferences: NhCatalogPreferences = CatalogPreferencesService.snapshot()
    preferences.ignoreLocalUserTagFiltering = ignore
    return CatalogPreferencesService.saveAfterRestore(context, preferences)
  }

  static async restoreFromBackup(context: common.UIAbilityContext): Promise<void> {
    if (CatalogPreferencesService.restoreTask !== null) {
      await CatalogPreferencesService.restoreTask
    }
    CatalogPreferencesService.restored = false
    await CatalogPreferencesService.restore(context)
  }

  private static async restoreInternal(context: common.UIAbilityContext): Promise<void> {
    CatalogPreferencesService.state().replace(await CatalogPreferencesRepository.load(context))
  }

  private static async saveAfterRestore(
    context: common.UIAbilityContext,
    preferences: NhCatalogPreferences,
  ): Promise<NhCatalogPreferences> {
    const normalized: NhCatalogPreferences = NhCatalogPreferences.normalized(preferences)
    CatalogPreferencesService.state().replace(normalized)
    // Capture the state after publication. A following tap therefore begins
    // from this choice, and the repository's write tail commits the final
    // combined snapshot instead of dropping one of the two edits.
    await CatalogPreferencesRepository.save(context, CatalogPreferencesService.snapshot())
    return normalized.copy()
  }

  private static state(): CatalogPreferencesState {
    return connectCatalogPreferences()
  }
}
