import { UIContext } from '@kit.ArkUI'
import { HdsTabsController } from '@kit.UIDesignKit'
import { AppStrings, NextNHdsCapsuleBarButton, ThemeTokens } from 'shared'

export const VERTICAL_READ_WIDTH: number = ThemeTokens.ACTION_HEIGHT
const TEXT_WIDTH: number = VERTICAL_READ_WIDTH - ThemeTokens.SPACE_XS * 2
const CONTENT_GAP: number = ThemeTokens.SPACE_XS
const CONTENT_PADDING: number = ThemeTokens.SPACE_MD

export function verticalReadTextHeight(uiContext: UIContext, label: string): number {
  const size: SizeOptions | undefined = uiContext.getMeasureUtils().measureTextSize({
    textContent: label,
    constraintWidth: TEXT_WIDTH,
    fontSize: ThemeTokens.FONT_SIZE_BODY,
    fontWeight: FontWeight.Medium,
    textAlign: TextAlign.Center,
  })
  return Math.ceil(uiContext.px2vp((size?.height ?? 0) as number))
}

export function verticalReadHeight(uiContext: UIContext, label: string): number {
  const iconHeight: number = uiContext.px2vp(uiContext.fp2px(ThemeTokens.FONT_SIZE_HEADING))
  return Math.max(
    VERTICAL_READ_WIDTH + ThemeTokens.SPACE_XL + ThemeTokens.SPACE_LG,
    iconHeight + CONTENT_GAP + verticalReadTextHeight(uiContext, label) + CONTENT_PADDING * 2,
  )
}

/** Fixed thickness in both materials. Text wraps vertically at its original size, including resume pages. */
@ComponentV2
export struct GalleryVerticalReadButton {
  @Param label: string = AppStrings.get('gallery_action_read');
  @Param usesHdsMaterial: boolean = true;
  @Event action: () => void = () => {};
  private materialController: HdsTabsController = new HdsTabsController();

  @Builder
  private Content() {
    Column({ space: CONTENT_GAP }) {
      SymbolGlyph(this.usesHdsMaterial ? $r('sys.symbol.doc_plaintext_fill') : $r('sys.symbol.doc_plaintext'))
        .fontSize(ThemeTokens.FONT_SIZE_HEADING)
        .fontColor([this.usesHdsMaterial ? ThemeTokens.BRAND : ThemeTokens.TEXT_ON_BRAND])
      Text(this.label)
        .width(TEXT_WIDTH)
        .height(verticalReadTextHeight(this.getUIContext(), this.label))
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.usesHdsMaterial ? ThemeTokens.BRAND : ThemeTokens.TEXT_ON_BRAND)
        .textAlign(TextAlign.Center)
    }
    .width(VERTICAL_READ_WIDTH)
    .height(verticalReadHeight(this.getUIContext(), this.label))
    .justifyContent(FlexAlign.Center)
  }

  build() {
    if (this.usesHdsMaterial) {
      NextNHdsCapsuleBarButton({
        controller: this.materialController,
        barWidth: VERTICAL_READ_WIDTH,
        barHeight: verticalReadHeight(this.getUIContext(), this.label),
        activityPadding: ThemeTokens.SPACE_LG,
        barBottomMargin: ThemeTokens.SPACE_LG,
        onButtonClick: this.action,
      }) {
        Column() { this.Content() }
          .translate({ y: -ThemeTokens.SPACE_XS })
      }
    } else {
      Button({ type: ButtonType.Capsule }) { this.Content() }
        .width(VERTICAL_READ_WIDTH)
        .height(verticalReadHeight(this.getUIContext(), this.label))
        .backgroundColor(ThemeTokens.BRAND)
        .shadow(ShadowStyle.OUTER_DEFAULT_MD)
        .accessibilityText(this.label)
        .onClick(() => { this.action() })
    }
  }
}
