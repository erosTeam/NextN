import { AppStorageV2 } from '@kit.ArkUI'
import { NhCatalogPreferences } from '../model/NhCatalogPreferences'
import { NhSearchLanguage, NhSearchSort } from '../model/NhSearchOptions'

/**
 * Live catalog preference signal. Per-surface revisions deliberately avoid
 * making an inactive Browse page react to a Search-only choice (and vice
 * versa), while request pages keep their own active snapshots for pagination.
 */
@ObservedV2
export class CatalogPreferencesState {
  @Trace browseLanguage: NhSearchLanguage = NhSearchLanguage.ALL
  @Trace browseSort: NhSearchSort = NhSearchSort.RECENT
  @Trace searchLanguage: NhSearchLanguage = NhSearchLanguage.ALL
  @Trace searchSort: NhSearchSort = NhSearchSort.RECENT
  @Trace browseRevision: number = 0
  @Trace searchRevision: number = 0

  replace(preferences: NhCatalogPreferences): void {
    const normalized: NhCatalogPreferences = NhCatalogPreferences.normalized(preferences)
    const browseChanged: boolean = this.browseLanguage !== normalized.browseLanguage ||
      this.browseSort !== normalized.browseSort
    const searchChanged: boolean = this.searchLanguage !== normalized.searchLanguage ||
      this.searchSort !== normalized.searchSort
    if (browseChanged) {
      this.browseLanguage = normalized.browseLanguage
      this.browseSort = normalized.browseSort
      this.browseRevision += 1
    }
    if (searchChanged) {
      this.searchLanguage = normalized.searchLanguage
      this.searchSort = normalized.searchSort
      this.searchRevision += 1
    }
  }

  snapshot(): NhCatalogPreferences {
    const result: NhCatalogPreferences = new NhCatalogPreferences()
    result.browseLanguage = this.browseLanguage
    result.browseSort = this.browseSort
    result.searchLanguage = this.searchLanguage
    result.searchSort = this.searchSort
    return result
  }
}

const CATALOG_PREFERENCES_STATE_KEY: string = 'nextn_catalog_preferences'
let sharedCatalogPreferencesState: CatalogPreferencesState | null = null

export function connectCatalogPreferences(): CatalogPreferencesState {
  if (sharedCatalogPreferencesState === null) {
    sharedCatalogPreferencesState = AppStorageV2.connect(
      CatalogPreferencesState,
      CATALOG_PREFERENCES_STATE_KEY,
      (): CatalogPreferencesState => new CatalogPreferencesState(),
    )!
  }
  return sharedCatalogPreferencesState
}
