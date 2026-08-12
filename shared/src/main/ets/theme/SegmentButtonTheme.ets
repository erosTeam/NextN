import { ColorMetrics } from '@kit.ArkUI'

/** Theme-aware system colors for the shared custom-color picker tabs. */
export class SegmentButtonTheme {
  private static tracked(color: ResourceColor, _effectiveDark: boolean): ColorMetrics {
    return ColorMetrics.resourceColor(color)
  }

  static tabButtonBackground(effectiveDark: boolean): ColorMetrics {
    return SegmentButtonTheme.tracked($r('sys.color.segment_button_v2_tab_button_background'), effectiveDark)
  }

  static tabSelectedItemBackground(effectiveDark: boolean): ColorMetrics {
    return SegmentButtonTheme.tracked(
      $r('sys.color.segment_button_v2_tab_selected_item_background'),
      effectiveDark,
    )
  }

  static itemFont(effectiveDark: boolean): ColorMetrics {
    return SegmentButtonTheme.tracked($r('sys.color.font_secondary'), effectiveDark)
  }

  static tabSelectedItemFont(effectiveDark: boolean): ColorMetrics {
    return SegmentButtonTheme.tracked($r('sys.color.font_primary'), effectiveDark)
  }
}
