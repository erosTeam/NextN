import { ThemeTokens } from '../theme/ThemeTokens'

// ErosN's catalog corner signal is deliberately small: it only marks a
// non-default language and must not become a generic category ribbon.
const LANGUAGE_BADGE_W: number = 38
const LANGUAGE_BADGE_H: number = 28
const LANGUAGE_BADGE_TEXT_W: number = 24
const LANGUAGE_BADGE_TEXT_H: number = 12
const LANGUAGE_BADGE_DEFAULT_TEXT_CENTER_X_RATIO: number = 0.58
const LANGUAGE_BADGE_DEFAULT_TEXT_CENTER_Y_RATIO: number = 0.37
export const LANGUAGE_BADGE_COMPACT_TEXT_CENTER_X_RATIO: number = 0.62
export const LANGUAGE_BADGE_COMPACT_TEXT_CENTER_Y_RATIO: number = 0.35
const LANGUAGE_BADGE_TEXT_SIZE: number = 10
const LANGUAGE_BADGE_TEXT_ANGLE: number =
  Math.atan(LANGUAGE_BADGE_H / LANGUAGE_BADGE_W) * 180 / Math.PI
const LANGUAGE_BADGE_OPACITY: number = 0.8

/**
 * ErosN leaves its default Japanese catalog items unbadged. The v2 summary
 * already derives this value from `tag_ids`, so cards never need a tag-name
 * request merely to render the corner signal.
 */
export function galleryLanguageCornerBadgeText(languageCode: string): string {
  return languageCode === 'JA' ? '' : languageCode
}

/**
 * Shared language-only counterpart of NextE's category corner leaf.
 *
 * NextN has no category colour in its gallery-summary payload. The semantic
 * product emphasis colour is the valid local replacement for ErosN's primary
 * colour; all other geometry follows the same compact rotated-corner leaf.
 */
@ComponentV2
export struct GalleryLanguageCornerBadge {
  @Require @Param languageCode: string
  @Param textCenterXRatio: number = LANGUAGE_BADGE_DEFAULT_TEXT_CENTER_X_RATIO
  @Param textCenterYRatio: number = LANGUAGE_BADGE_DEFAULT_TEXT_CENTER_Y_RATIO

  private textTop(): number {
    return LANGUAGE_BADGE_H * this.textCenterYRatio - LANGUAGE_BADGE_TEXT_H / 2
  }

  private textRight(): number {
    return LANGUAGE_BADGE_W - LANGUAGE_BADGE_W * this.textCenterXRatio - LANGUAGE_BADGE_TEXT_W / 2
  }

  build() {
    if (galleryLanguageCornerBadgeText(this.languageCode).length > 0) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Polygon({ width: LANGUAGE_BADGE_W, height: LANGUAGE_BADGE_H })
          .points([[0, 0], [LANGUAGE_BADGE_W, 0], [LANGUAGE_BADGE_W, LANGUAGE_BADGE_H]])
          .fill(ThemeTokens.BRAND)
          .fillOpacity(LANGUAGE_BADGE_OPACITY)
        Text(galleryLanguageCornerBadgeText(this.languageCode))
          .fontSize(LANGUAGE_BADGE_TEXT_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeTokens.TEXT_ON_BRAND)
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .width(LANGUAGE_BADGE_TEXT_W)
          .height(LANGUAGE_BADGE_TEXT_H)
          .rotate({ angle: LANGUAGE_BADGE_TEXT_ANGLE })
          .position({ right: this.textRight(), top: this.textTop() })
      }
      .width(LANGUAGE_BADGE_W)
      .height(LANGUAGE_BADGE_H)
      .borderRadius({ topRight: ThemeTokens.THUMB_RADIUS })
      .clip(true)
    }
  }
}
