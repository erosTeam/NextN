import { NhBrowsePresentation } from '../model/NhBrowsePresentation'
import { ThemeTokens } from '../theme/ThemeTokens'

/** Grid-like Browse presentations support a local responsive density override. */
export function supportsGalleryColumnDensity(mode: NhBrowsePresentation): boolean {
  return mode === NhBrowsePresentation.COVER_GRID ||
    mode === NhBrowsePresentation.WATERFALL ||
    mode === NhBrowsePresentation.WATERFALL_COMPACT ||
    mode === NhBrowsePresentation.COVER_WALL ||
    mode === NhBrowsePresentation.THUMBNAIL
}

/** Built-in comfortable minimum width for each native gallery arrangement. */
export function galleryBaseMinColumnWidth(mode: NhBrowsePresentation): number {
  if (mode === NhBrowsePresentation.COVER_GRID) {
    return ThemeTokens.GALLERY_GRID_MIN_WIDTH
  }
  if (mode === NhBrowsePresentation.WATERFALL_COMPACT) {
    return ThemeTokens.GALLERY_WATERFALL_COMPACT_MIN_WIDTH
  }
  if (mode === NhBrowsePresentation.WATERFALL) {
    return ThemeTokens.GALLERY_WATERFALL_MIN_WIDTH
  }
  if (mode === NhBrowsePresentation.THUMBNAIL) {
    return 112
  }
  return ThemeTokens.GALLERY_COVER_WALL_MIN_WIDTH
}

/** Clamp local slider and pinch writes to the same predictable vp range. */
export function clampGalleryColumnWidth(width: number): number {
  const rounded: number = Math.round(width)
  return Math.min(
    ThemeTokens.GALLERY_COLUMN_WIDTH_CEILING,
    Math.max(ThemeTokens.GALLERY_COLUMN_WIDTH_FLOOR, rounded),
  )
}

/**
 * One source of truth for derived native Grid/WaterFlow column count.
 * `measuredWidth` is the scaffold width before its horizontal padding.
 */
export function galleryColumnCount(
  measuredWidth: number,
  minColumnWidth: number,
  gap: number,
  horizontalPadding: number,
): number {
  if (measuredWidth <= 0) {
    return 2
  }
  const normalizedWidth: number = Math.max(1, minColumnWidth)
  const contentWidth: number = Math.max(
    normalizedWidth,
    measuredWidth - horizontalPadding * 2,
  )
  const count: number = Math.floor((contentWidth + gap) / (normalizedWidth + gap))
  return Math.max(1, count)
}

/**
 * A pinch is allowed to move only to the immediately adjacent column count.
 * This makes a fast two-finger gesture deterministic instead of allowing it
 * to jump from, for example, three columns straight to five.
 */
export function constrainGalleryColumnWidthToOneStep(
  measuredWidth: number,
  startColumnCount: number,
  desiredWidth: number,
  gap: number,
  horizontalPadding: number,
): number {
  const desired: number = clampGalleryColumnWidth(desiredWidth)
  if (measuredWidth <= 0 || startColumnCount <= 0) {
    return desired
  }
  const desiredCount: number = galleryColumnCount(
    measuredWidth,
    desired,
    gap,
    horizontalPadding,
  )
  if (Math.abs(desiredCount - startColumnCount) <= 1) {
    return desired
  }

  const targetCount: number = startColumnCount + (desiredCount > startColumnCount ? 1 : -1)
  let closest: number = desired
  let closestDistance: number = Number.MAX_VALUE
  for (
    let width: number = ThemeTokens.GALLERY_COLUMN_WIDTH_FLOOR;
    width <= ThemeTokens.GALLERY_COLUMN_WIDTH_CEILING;
    width += 1
  ) {
    if (galleryColumnCount(measuredWidth, width, gap, horizontalPadding) !== targetCount) {
      continue
    }
    const distance: number = Math.abs(width - desired)
    if (distance < closestDistance) {
      closest = width
      closestDistance = distance
    }
  }
  return closestDistance === Number.MAX_VALUE ? desired : closest
}
