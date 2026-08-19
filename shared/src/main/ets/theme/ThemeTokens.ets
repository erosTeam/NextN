import { ThemeColorSettings } from '../settings/ThemeColorSettings'

/**
 * NextN's single visual language.
 *
 * This is intentionally a compact counterpart of NextE's ThemeConstants:
 * pages and reusable components consume semantic aliases and scales rather
 * than introducing one-off colours, spacing, or hit-target sizes.  The app
 * resources own the product palette while the system resources preserve the
 * platform light/dark text and surface behaviour.
 */
export class ThemeTokens {
  // Semantic colours
  // ThemeColorSettings owns this global brand token through explicit presets
  // or a user-selected Custom value.
  static get BRAND(): ResourceColor {
    return ThemeColorSettings.currentColor()
  }
  static readonly BRAND_CONTAINER: ResourceColor = $r('sys.color.ohos_id_color_button_normal')
  // Keep page hosts on the system sub-background. HDS material adapts against
  // this semantic color across light/dark modes just as it does in NextE.
  static readonly SURFACE: ResourceColor = $r('sys.color.ohos_id_color_sub_background')
  static readonly SURFACE_CONTAINER: ResourceColor = $r('app.color.surface_container')
  static readonly SURFACE_SUB: ResourceColor = $r('sys.color.ohos_id_color_sub_background')
  static readonly CARD_BACKGROUND: ResourceColor = $r('app.color.surface_container')
  /** NextE cover_placeholder: a dedicated grey distinct from the page surface. */
  static readonly COVER_PLACEHOLDER: ResourceColor = $r('app.color.cover_placeholder')
  static readonly READER_BACKGROUND: ResourceColor = $r('app.color.reader_background')
  static readonly TEXT_PRIMARY: ResourceColor = $r('sys.color.font_primary')
  static readonly TEXT_SECONDARY: ResourceColor = $r('sys.color.font_secondary')
  static readonly TEXT_TERTIARY: ResourceColor = $r('sys.color.font_tertiary')
  static readonly TEXT_LINK: ResourceColor = $r('sys.color.font_emphasize')
  static readonly TEXT_ON_BRAND: ResourceColor = '#FFFFFFFF'
  static readonly DIVIDER: ResourceColor = $r('sys.color.ohos_id_color_list_separator')
  static readonly OVERLAY_SCRIM: ResourceColor = '#99000000'

  // Spacing scale
  static readonly SPACE_XS: number = 4
  static readonly SPACE_SM: number = 8
  static readonly SPACE_MD: number = 12
  static readonly SPACE_LG: number = 16
  static readonly SPACE_XL: number = 24
  static readonly SPACE_XXL: number = 32
  /** Blurred letterbox-fill radius behind an off-aspect cover (NextE parity). */
  static readonly COVER_BG_BLUR_RADIUS: number = 40
  // Type scale
  static readonly FONT_SIZE_TINY: number = 10
  static readonly FONT_SIZE_CAPTION: number = 12
  static readonly FONT_SIZE_META: number = 13
  static readonly FONT_SIZE_BODY: number = 14
  static readonly FONT_SIZE_LIST_ITEM: number = 13
  static readonly FONT_SIZE_TITLE: number = 16
  static readonly FONT_SIZE_HEADING: number = 18
  // Matches NextE ThemeConstants.FONT_SIZE_H2: the release-notes version track
  // and other emphasis typography share this level.
  static readonly FONT_SIZE_H2: number = 22
  static readonly FONT_SIZE_H1: number = 24
  static readonly LINE_HEIGHT_BODY: number = 20
  static readonly LINE_HEIGHT_TITLE: number = 22
  /** Matches NextE ThemeConstants.ANIM_DURATION for shared transition rhythm. */
  static readonly ANIM_DURATION: number = 400
  /** Matches NextE ThemeConstants.LOADING_SIZE for centered page loading indicators. */
  static readonly LOADING_SIZE: number = 32

  // Shape scale
  static readonly RADIUS_XS: number = 4
  // These are separate families, matching NextE rather than one generic
  // Material-style radius progression.
  static readonly RADIUS_SM: number = 4
  static readonly RADIUS_MD: number = 22
  static readonly RADIUS_CARD: number = 24
  static readonly RADIUS_ROUND: number = 999
  static readonly DETAIL_COVER_RADIUS: number = 16
  static readonly THUMB_RADIUS: number = 8
  // Dense collection-card tags are deliberately smaller than the detail-chip
  // family: these mirror NextE's 6vp radius and 3vp vertical padding.
  static readonly LIST_TAG_RADIUS: number = 6
  static readonly LIST_TAG_PADDING_VERTICAL: number = 3
  // Detail tags retain their larger, more comfortable geometry.
  static readonly TAG_RADIUS: number = 8
  // Direct counterparts of NextE's chip rhythm. Keep the visual height in
  // tokens so detail tags cannot drift into a second, hand-tuned chip style.
  static readonly TAG_LINE_HEIGHT: number = 16
  static readonly TAG_PADDING_VERTICAL: number = 4
  // HDS grouped-list grammar, matching the shared row geometry used by NextE.
  static readonly LIST_ROW_RADIUS: number = 19
  /** Matches NextE's Settings identity-card avatar diameter. */
  static readonly ACCOUNT_AVATAR_SIZE: number = 44
  /** 44vp avatar + 9vp leading and 15vp text gap, matching NextE's root row. */
  static readonly ACCOUNT_AVATAR_PREFIX_LEFT_INSET: number = 9
  static readonly ACCOUNT_AVATAR_PREFIX_TEXT_GAP: number = 15
  static readonly LIST_ROW_TEXT_INDENT: number = 8

  // Layout and interaction dimensions. Every tap target is at least 48vp.
  static readonly TITLE_BAR_HEIGHT: number = 56
  static readonly FLOATING_TAB_HEIGHT: number = 56
  // Root lists scroll beneath the HDS floating bar, so their tail must reserve
  // one tab height plus a readable gap rather than only generic page padding.
  static readonly ROOT_FLOATING_TAB_RESERVE: number =
    ThemeTokens.FLOATING_TAB_HEIGHT + ThemeTokens.SPACE_LG
  // Keep the HDS root split shell on the same usable-pane contract as NextE.
  // HDS starts from 320vp for the primary pane, never lets either pane shrink
  // below 320vp, and lets the drag divider expand toward the available width.
  static readonly TABLET_PRIMARY_PANE_WIDTH: number = 320
  static readonly TABLET_PRIMARY_PANE_MIN_WIDTH: number = 320
  static readonly TABLET_DETAIL_MIN_WIDTH: number = 320
  static readonly MIN_TOUCH_TARGET: number = 48
  static readonly ACTION_HEIGHT: number = 46
  static readonly SECONDARY_ACTION_HEIGHT: number = 40
  // Detail action chips: 26vp capsule (radius 13, close to NextE's 28)
  // with a 4vp icon/text gap (user-raised from NextE's 2vp for the link
  // glyph's visual mass). Closed form for the action card:
  //   H(common metadata card) ~= 72.7vp
  //   concentric: R = p + h/2
  //   fit:        2h + g + 2p <= H
  //   even:       g ~= p
  // h=26, R=20 -> p=7, g=6 -> 52+6+14 = 72 <= 72.7; at real H the middle
  // gap becomes ~6.7, giving 7 / 6.7 / 7 (even), R-r = 7 (small), and
  // equal card heights.
  static readonly DETAIL_ACTION_CHIP_HEIGHT: number = 26
  static readonly DETAIL_ACTION_CHIP_GAP: number = 4
  static readonly DETAIL_ACTION_CARD_RADIUS: number = 20
  static readonly DETAIL_ACTION_CHIP_STACK_GAP: number = 6
  // The action card stretches (alignSelf Stretch) to the metadata card's
  // height, so the two cards always align with no measured or hand-tuned
  // height; MIN_HEIGHT is only the intrinsic content floor (two 26vp chips
  // + 6vp gap + 2*7vp padding = 72vp). Chips are distributed with
  // SpaceBetween so all four card margins stay equal at 7vp and the middle
  // gap stays ~6.7vp. Width 112vp leaves 98vp for the chips and 78vp for
  // icon + gap + text, so the two-character labels fit through the 2.67x
  // font scale before ellipsizing.
  static readonly DETAIL_ACTION_CARD_WIDTH: number = 112
  static readonly DETAIL_ACTION_CARD_PADDING: number =
    ThemeTokens.DETAIL_ACTION_CARD_RADIUS - ThemeTokens.DETAIL_ACTION_CHIP_HEIGHT / 2
  static readonly DETAIL_ACTION_CARD_MIN_HEIGHT: number =
    ThemeTokens.DETAIL_ACTION_CHIP_HEIGHT * 2 + ThemeTokens.DETAIL_ACTION_CHIP_STACK_GAP +
    ThemeTokens.DETAIL_ACTION_CARD_PADDING * 2
  static readonly SEARCH_FIELD_HEIGHT: number = 40
  static readonly LIST_HORIZONTAL_PADDING: number = 12
  static readonly LIST_BOTTOM_PADDING: number = 24

  // Default gallery rows use NextE's compact simple-list rhythm. Detail covers
  // and grouped cards have their own shape tokens above.
  static readonly COVER_WIDTH: number = 72
  static readonly COVER_HEIGHT: number = 102
  // Fixed NextE Gallery-header cover slot. It is deliberately distinct from
  // compact list thumbnails so header text can budget its lines correctly.
  static readonly DETAIL_COVER_WIDTH: number = 124
  static readonly DETAIL_COVER_HEIGHT: number = 175
  // NextE's default browse wall is a responsive cover grid, not a list of
  // generic rows. Keep its measured density and card rhythm as named tokens.
  static readonly GALLERY_GRID_MIN_WIDTH: number = 106
  // NextE CoverWall uses a slightly wider cover-first column than the
  // metadata-bearing grid card, keeping the wall from becoming thumbnail-dense.
  static readonly GALLERY_COVER_WALL_MIN_WIDTH: number = 120
  // Regular waterfall shares NextE's 160vp density with the compact mode,
  // but keeps a separate persisted override and an information-below-cover
  // card hierarchy.
  static readonly GALLERY_WATERFALL_MIN_WIDTH: number = 160
  // NextE's compact waterfall intentionally has fewer, wider columns so its
  // image-overlay metadata remains readable without becoming a cover wall.
  static readonly GALLERY_WATERFALL_COMPACT_MIN_WIDTH: number = 160
  // Density controls retain a width rather than an absolute column count.
  // These limits are shared by the HDS Slider and two-finger gesture.
  static readonly GALLERY_COLUMN_WIDTH_FLOOR: number = 80
  static readonly GALLERY_COLUMN_WIDTH_CEILING: number = 300
  static readonly GALLERY_GRID_GAP: number = 6
  static readonly GALLERY_GRID_CARD_RADIUS: number = 16
  static readonly GALLERY_GRID_COVER_RATIO: number = 0.7
  static readonly GALLERY_GRID_INFO_HEIGHT: number = 66
  static readonly GALLERY_GRID_TITLE_HEIGHT: number = 40
  static readonly GALLERY_GRID_META_HEIGHT: number = 18
  static readonly TAB_INDICATOR_SIZE: number = 28
  static readonly STATE_INDICATOR_SIZE: number = 32
  static readonly INLINE_PROGRESS_SIZE: number = 20
  static readonly LIST_FOOTER_MIN_HEIGHT: number = 72
  static readonly SECTION_ICON_SIZE: number = 20
  static readonly SECTION_ICON_CONTAINER_SIZE: number = 40

  // PullRefresh keeps its drag and completion animation separate from any
  // caller-owned initial-load state. These are shared component tokens rather
  // than page literals so List, Grid and WaterFlow settle identically.
  static readonly REFRESH_INDICATOR_SIZE: number = 28
  static readonly REFRESH_BOTTOM_INDICATOR_SIZE: number = 24
  static readonly REFRESH_ANIMATION_DURATION: number = 400
  static readonly REFRESH_STATE_RESET_MS: number = 420
  static readonly REFRESH_DONE_DELAY_MS: number = 200
}
