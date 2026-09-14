import {
  connectGalleryDetailTransition,
  GalleryDetailTransitionState,
} from '../state/GalleryDetailTransitionState'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'

/**
 * Keeps a virtualized gallery item in layout while the transition proxy owns its visible pixels.
 * Subscribing inside the slot avoids a cached ListItem/GridItem builder missing a visibility update
 * when a rotated destination route becomes active again.
 */
@ComponentV2
export struct GalleryDetailTransitionSourceSlot {
  @Require @Param sourceComponentId: string
  @BuilderParam content: () => void
  @Local transitionState: GalleryDetailTransitionState = connectGalleryDetailTransition()
  @Local layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()

  build() {
    Stack() {
      this.content()
    }
    .width('100%')
    .visibility(
      this.transitionState.hidesSource(this.sourceComponentId, this.layoutSafeArea.rootNavigationSplit)
        ? Visibility.Hidden
        : Visibility.Visible,
    )
  }
}
