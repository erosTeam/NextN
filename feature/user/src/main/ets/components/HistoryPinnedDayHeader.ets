import { AppStorageV2 } from '@kit.ArkUI'
import { AppStrings, ThemeTokens } from 'shared'

/**
 * The HDS title bar needs the same physical height as the ordinary date row it
 * mirrors.  The root list already owns an outer 12vp inset, and the regular
 * group header adds another 12vp locally, so the pinned mirror keeps that
 * combined 24vp alignment without inventing a second page gutter.
 */
export const HISTORY_PINNED_DAY_HEADER_HEIGHT: number =
  ThemeTokens.FONT_SIZE_CAPTION + ThemeTokens.SPACE_MD + ThemeTokens.SPACE_XS

const HISTORY_PINNED_DAY_HEADER_KEY: string = 'nextn_history_pinned_day_header'
const HISTORY_DAY_BEFORE_YESTERDAY: number = 2

/** Stable local-calendar identity; human-facing strings are never persisted. */
export function historyLocalDayStart(timestamp: number): number {
  if (timestamp <= 0) {
    return 0
  }
  const date: Date = new Date(timestamp)
  return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()
}

/** Resolve the same local day label used by the scrolling ListItemGroup headers. */
export function historyDayLabel(dayStart: number, currentDayStart: number): string {
  if (dayStart <= 0) {
    return AppStrings.get('history_earlier')
  }
  const dayDelta: number = Math.round((currentDayStart - dayStart) / 86400000)
  if (dayDelta === 0) {
    return AppStrings.get('history_today')
  }
  if (dayDelta === 1) {
    return AppStrings.get('history_yesterday')
  }
  if (dayDelta === HISTORY_DAY_BEFORE_YESTERDAY) {
    return AppStrings.get('history_day_before_yesterday')
  }
  const date: Date = new Date(dayStart)
  const year: string = `${date.getFullYear()}`
  const month: string = `${date.getMonth() + 1}`.padStart(2, '0')
  const day: string = `${date.getDate()}`.padStart(2, '0')
  return `${year}-${month}-${day}`
}

/**
 * App-wide UI-only bridge between HistoryPage's List geometry and the root
 * HDS title slot.  None of these fields are history persistence or account
 * data; they are reset whenever the list ceases to provide a pin target.
 */
@ObservedV2
export class HistoryPinnedDayHeaderState {
  @Trace dayStart: number = 0
  @Trace currentDayStart: number = historyLocalDayStart(Date.now())
  @Trace visible: boolean = false
  // Window Y of the HDS bottom-builder surface. List group rects are relative
  // to the List viewport, so HistoryPage converts this through its List area.
  @Trace pinSurfaceTopY: number = -1
}

export function connectHistoryPinnedDayHeader(): HistoryPinnedDayHeaderState {
  return AppStorageV2.connect(
    HistoryPinnedDayHeaderState,
    HISTORY_PINNED_DAY_HEADER_KEY,
    (): HistoryPinnedDayHeaderState => new HistoryPinnedDayHeaderState(),
  )!
}

/**
 * Passive HDS mirror: it has no action and only renders when HistoryPage has
 * proved that the matching ListItemGroup header passed underneath this slot.
 */
@ComponentV2
export struct HistoryPinnedDayHeader {
  @Param state: HistoryPinnedDayHeaderState = new HistoryPinnedDayHeaderState()

  build() {
    Column() {
      if (this.state.visible) {
        Row() {
          Text(historyDayLabel(this.state.dayStart, this.state.currentDayStart))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
        }
        .width('100%')
        .height('100%')
        .padding({
          left: ThemeTokens.LIST_HORIZONTAL_PADDING + ThemeTokens.SPACE_MD,
          right: ThemeTokens.LIST_HORIZONTAL_PADDING + ThemeTokens.SPACE_MD,
        })
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .height(HISTORY_PINNED_DAY_HEADER_HEIGHT)
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      this.state.pinSurfaceTopY = newValue.globalPosition.y as number
    })
  }
}

@Builder
export function HistoryPinnedDayHeaderCCBuilder(state: HistoryPinnedDayHeaderState) {
  HistoryPinnedDayHeader({ state: state })
}
