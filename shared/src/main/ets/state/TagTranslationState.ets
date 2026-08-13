import { AppStorageV2 } from '@kit.ArkUI'

const TAG_TRANSLATION_STATE_KEY: string = 'nextn_tag_translation'

/**
 * Non-sensitive display invalidation for the app-private tag dictionary.
 *
 * Gallery data remains page-owned and the dictionary remains RDB-owned. This
 * state carries no tag text, identifiers, or request data; it only tells a
 * mounted presentation that a committed dictionary replacement or clear may
 * require re-labeling tags it has already resolved.
 */
@ObservedV2
export class TagTranslationState {
  @Trace revision: number = 0

  publishMutation(): void {
    this.revision += 1
  }
}

export function connectTagTranslations(): TagTranslationState {
  return AppStorageV2.connect(
    TagTranslationState,
    TAG_TRANSLATION_STATE_KEY,
    (): TagTranslationState => new TagTranslationState(),
  )!
}
