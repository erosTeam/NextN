/**
 * Shared with NextE: distinguishes direct user scrolling from programmatic
 * scroller movement so page-level ownership signals stay accurate.
 */
export function isUserScrollSource(source: ScrollSource): boolean {
  return source === ScrollSource.DRAG ||
    source === ScrollSource.FLING ||
    source === ScrollSource.OTHER_USER_INPUT ||
    source === ScrollSource.SCROLL_BAR ||
    source === ScrollSource.SCROLL_BAR_FLING
}

/**
 * Single owner for scroller offset reads. ArkUI can return undefined from
 * currentOffset() while a route is detaching or before the scrollable has
 * attached its Scroller; raw property access crashes layout callbacks.
 * Callers must never read currentOffset() directly.
 */
export function currentScrollOffsetY(scroller: Scroller): number {
  return scroller.currentOffset()?.yOffset ?? 0
}

export function currentScrollOffsetX(scroller: Scroller): number {
  return scroller.currentOffset()?.xOffset ?? 0
}
