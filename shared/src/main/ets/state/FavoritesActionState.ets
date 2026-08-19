import { AppStorageV2 } from '@kit.ArkUI'

/** Commands emitted by the root HDS title bar into the retained Favorites page. */
export class FavoritesAction {
  static readonly TOGGLE_SEARCH: string = 'toggle_search'
  static readonly OPEN_LAYOUT_MENU: string = 'open_layout_menu'
  static readonly OPEN_JUMP_DIALOG: string = 'open_jump_dialog'
}

/**
 * Narrow root-to-page presentation bridge for Favorites.
 *
 * FavoritesPage remains the sole owner of typed and submitted queries. The
 * root title bar only sends repeatable commands. The page publishes both its
 * authenticated action eligibility and whether the local search surface is
 * open, so remote actions cannot leak into the signed-out or restore state.
 */
@ObservedV2
export class FavoritesActionState {
  @Trace command: string = ''
  @Trace commandSeq: number = 0
  @Trace actionsAvailable: boolean = false
  @Trace searchActive: boolean = false
}

const FAVORITES_ACTION_KEY: string = 'nextn_favorites_actions'

export function connectFavoritesActions(): FavoritesActionState {
  return AppStorageV2.connect(
    FavoritesActionState,
    FAVORITES_ACTION_KEY,
    (): FavoritesActionState => new FavoritesActionState(),
  )!
}

export class FavoritesActionBridge {
  static requestToggleSearch(): void {
    const state: FavoritesActionState = connectFavoritesActions()
    if (!state.actionsAvailable) {
      return
    }
    state.command = FavoritesAction.TOGGLE_SEARCH
    state.commandSeq = state.commandSeq + 1
  }

  static requestLayoutMenu(): void {
    const state: FavoritesActionState = connectFavoritesActions()
    if (!state.actionsAvailable) {
      return
    }
    state.command = FavoritesAction.OPEN_LAYOUT_MENU
    state.commandSeq = state.commandSeq + 1
  }

  static requestJumpDialog(): void {
    const state: FavoritesActionState = connectFavoritesActions()
    if (!state.actionsAvailable) {
      return
    }
    state.command = FavoritesAction.OPEN_JUMP_DIALOG
    state.commandSeq = state.commandSeq + 1
  }

  static reportActionsAvailable(available: boolean): void {
    connectFavoritesActions().actionsAvailable = available
  }

  static reportSearchActive(active: boolean): void {
    connectFavoritesActions().searchActive = active
  }
}
