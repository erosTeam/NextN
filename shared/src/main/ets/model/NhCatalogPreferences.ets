import { NhSearchLanguage, NhSearchSort } from './NhSearchOptions'

/**
 * Durable, device-local defaults for the two anonymous public catalog entry
 * points. Browse and Search intentionally keep separate values: changing a
 * search query's ordering must not silently reinterpret the Browse root.
 */
export class NhCatalogPreferences {
  browseLanguage: NhSearchLanguage = NhSearchLanguage.ALL
  browseSort: NhSearchSort = NhSearchSort.RECENT
  searchLanguage: NhSearchLanguage = NhSearchLanguage.ALL
  searchSort: NhSearchSort = NhSearchSort.RECENT
  ignoreLocalUserTagFiltering: boolean = false

  copy(): NhCatalogPreferences {
    const result: NhCatalogPreferences = new NhCatalogPreferences()
    result.browseLanguage = this.browseLanguage
    result.browseSort = this.browseSort
    result.searchLanguage = this.searchLanguage
    result.searchSort = this.searchSort
    result.ignoreLocalUserTagFiltering = this.ignoreLocalUserTagFiltering
    return result
  }

  static normalizeLanguage(value: string): NhSearchLanguage {
    if (value === NhSearchLanguage.JAPANESE) {
      return NhSearchLanguage.JAPANESE
    }
    if (value === NhSearchLanguage.CHINESE) {
      return NhSearchLanguage.CHINESE
    }
    if (value === NhSearchLanguage.ENGLISH) {
      return NhSearchLanguage.ENGLISH
    }
    if (value === NhSearchLanguage.TRANSLATED) {
      return NhSearchLanguage.TRANSLATED
    }
    return NhSearchLanguage.ALL
  }

  static normalizeSort(value: string): NhSearchSort {
    if (value === NhSearchSort.POPULAR_TODAY) {
      return NhSearchSort.POPULAR_TODAY
    }
    if (value === NhSearchSort.POPULAR_WEEK) {
      return NhSearchSort.POPULAR_WEEK
    }
    if (value === NhSearchSort.POPULAR_MONTH) {
      return NhSearchSort.POPULAR_MONTH
    }
    if (value === NhSearchSort.POPULAR_ALL_TIME) {
      return NhSearchSort.POPULAR_ALL_TIME
    }
    return NhSearchSort.RECENT
  }

  static normalized(source: NhCatalogPreferences): NhCatalogPreferences {
    const result: NhCatalogPreferences = new NhCatalogPreferences()
    result.browseLanguage = NhCatalogPreferences.normalizeLanguage(source.browseLanguage)
    result.browseSort = NhCatalogPreferences.normalizeSort(source.browseSort)
    result.searchLanguage = NhCatalogPreferences.normalizeLanguage(source.searchLanguage)
    result.searchSort = NhCatalogPreferences.normalizeSort(source.searchSort)
    result.ignoreLocalUserTagFiltering = source.ignoreLocalUserTagFiltering === true
    return result
  }
}
