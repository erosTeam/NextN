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
