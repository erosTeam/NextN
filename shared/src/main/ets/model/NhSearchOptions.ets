import { AppStrings } from '../i18n/AppStrings'

/**
 * The anonymous v2 search options supported by ErosN's request contract.
 * These values are intentionally small and explicit: they never imply an
 * account scope, and their wire values are kept separate from UI labels.
 */
export enum NhSearchLanguage {
  ALL = 'all',
  JAPANESE = 'japanese',
  CHINESE = 'chinese',
  ENGLISH = 'english',
  TRANSLATED = 'translated',
}

export enum NhSearchSort {
  RECENT = 'recent',
  POPULAR_TODAY = 'popular-today',
  POPULAR_WEEK = 'popular-week',
  POPULAR_MONTH = 'popular-month',
  POPULAR_ALL_TIME = 'popular',
}

export class NhSearchOptions {
  static languageLabel(option: NhSearchLanguage): string {
    switch (option) {
      case NhSearchLanguage.JAPANESE:
        return AppStrings.get('search_language_japanese')
      case NhSearchLanguage.CHINESE:
        return AppStrings.get('search_language_chinese')
      case NhSearchLanguage.ENGLISH:
        return AppStrings.get('search_language_english')
      case NhSearchLanguage.TRANSLATED:
        return AppStrings.get('search_language_translated')
      default:
        return AppStrings.get('search_language_all')
    }
  }

  static sortLabel(option: NhSearchSort): string {
    switch (option) {
      case NhSearchSort.POPULAR_TODAY:
        return AppStrings.get('search_sort_popular_today')
      case NhSearchSort.POPULAR_WEEK:
        return AppStrings.get('search_sort_popular_week')
      case NhSearchSort.POPULAR_MONTH:
        return AppStrings.get('search_sort_popular_month')
      case NhSearchSort.POPULAR_ALL_TIME:
        return AppStrings.get('search_sort_popular_all_time')
      default:
        return AppStrings.get('search_sort_recent')
    }
  }

  static queryWithLanguage(query: string, language: NhSearchLanguage): string {
    const trimmed: string = query.trim()
    if (trimmed.length === 0 || language === NhSearchLanguage.ALL) {
      return trimmed
    }
    // Match ErosN's v2 grammar: the language selector is part of the public
    // search expression, while sorting stays a separate API parameter.
    return `${trimmed} language:${language}`
  }

  static sortValue(sort: NhSearchSort): string {
    return sort === NhSearchSort.RECENT ? '' : sort
  }
}
