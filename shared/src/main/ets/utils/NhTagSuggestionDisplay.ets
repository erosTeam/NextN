import { AppStrings } from '../i18n/AppStrings'
import { NhTagSuggestion } from '../model/NhTagSuggestion'

/** Shared presentation policy for tag suggestions across search and history surfaces. */
export class NhTagSuggestionDisplay {
  static namespaceLabel(namespace: string): string {
    const ns: string = namespace.trim().toLowerCase()
    switch (ns) {
      case 'parody':
      case 'parodies':
        return AppStrings.get('gallery_tag_namespace_parodies')
      case 'character':
      case 'characters':
        return AppStrings.get('gallery_tag_namespace_characters')
      case 'artist':
      case 'artists':
        return AppStrings.get('gallery_tag_namespace_artists')
      case 'group':
      case 'groups':
        return AppStrings.get('gallery_tag_namespace_groups')
      case 'language':
      case 'languages':
        return AppStrings.get('gallery_tag_namespace_languages')
      case 'category':
      case 'categories':
        return AppStrings.get('gallery_tag_namespace_categories')
      case 'tag':
      case 'tags':
        return AppStrings.get('gallery_tag_namespace_tags')
      case 'female':
        return AppStrings.get('tag_ns_female')
      case 'male':
        return AppStrings.get('tag_ns_male')
      case 'mixed':
        return AppStrings.get('tag_ns_mixed')
      case 'other':
        return AppStrings.get('tag_ns_other')
      case 'cosplayer':
        return AppStrings.get('tag_ns_cosplayer')
      default:
        return ns
    }
  }

  /** Returns the localized namespace plus translated tag body, or an empty string without a translation. */
  static localizedTitle(suggestion: NhTagSuggestion): string {
    if (suggestion.displayName.trim().length === 0) {
      return ''
    }
    return NhTagSuggestionDisplay.namespaceLabel(suggestion.namespace) + ':' + suggestion.displayName
  }
}
