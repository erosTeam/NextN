import { AppStorageV2 } from '@kit.ArkUI'

/**
 * Whether recent/quick search chips show their translated subtitle lines.
 * Mirrors NextE SearchHistoryState.translateEnabled (default on, persisted).
 */
@ObservedV2
export class SearchTranslationState {
  @Trace translateEnabled: boolean = true
}

const SEARCH_TRANSLATION_STATE_KEY: string = 'nextn_search_translation'

export function connectSearchTranslation(): SearchTranslationState {
  return AppStorageV2.connect(
    SearchTranslationState,
    SEARCH_TRANSLATION_STATE_KEY,
    (): SearchTranslationState => new SearchTranslationState(),
  )!
}
