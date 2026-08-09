import { AppStorageV2 } from '@kit.ArkUI'

const FAVORITE_MUTATION_STATE_KEY: string = 'nextn_favorite_mutations'

/**
 * Non-sensitive invalidation bridge for an already-confirmed favourite write.
 *
 * The gallery id and resulting boolean are the minimum non-sensitive typed
 * result needed to keep an already-visible Favorites projection stable. It
 * contains no account identity, session state, cookie, URL, title, or other
 * server response fields. Consumers still reconcile through their existing
 * authenticated session and request guards.
 */
@ObservedV2
export class FavoriteMutationState {
  @Trace revision: number = 0
  @Trace galleryId: number = 0
  @Trace isFavorited: boolean = false

  publishConfirmedMutation(galleryId: number, isFavorited: boolean): void {
    const normalizedGalleryId: number = Math.max(0, Math.floor(galleryId))
    if (normalizedGalleryId === 0) {
      return
    }
    this.galleryId = normalizedGalleryId
    this.isFavorited = isFavorited
    this.revision += 1
  }
}

export function connectFavoriteMutations(): FavoriteMutationState {
  return AppStorageV2.connect(
    FavoriteMutationState,
    FAVORITE_MUTATION_STATE_KEY,
    (): FavoriteMutationState => new FavoriteMutationState(),
  )!
}
