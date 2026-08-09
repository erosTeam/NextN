/**
 * Direct NextE root-tab re-tap bridge. A root list registers its own
 * scroll-to-top + refresh action by Scroller identity; Index owns those
 * Scrollers and dispatches only when the already-active tab is tapped.
 */
export class RootRefreshRegistry {
  private static actions: Map<Scroller, () => void> = new Map<Scroller, () => void>()

  static register(scroller: Scroller, action: () => void): void {
    RootRefreshRegistry.actions.set(scroller, action)
  }

  static unregister(scroller: Scroller): void {
    RootRefreshRegistry.actions.delete(scroller)
  }

  static trigger(scroller: Scroller): void {
    const action: (() => void) | undefined = RootRefreshRegistry.actions.get(scroller)
    if (action !== undefined) {
      action()
    }
  }
}
