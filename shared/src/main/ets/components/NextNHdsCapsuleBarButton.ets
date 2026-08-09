import { hdsMaterial, HdsTabs, HdsTabsController, HdsTabsFloatingStyle } from '@kit.UIDesignKit'
import { ImmersiveMaterialSettings } from '../settings/ImmersiveMaterialSettings'
import {
  connectImmersiveMaterialSettings,
  ImmersiveMaterialSettingsState,
} from '../state/ImmersiveMaterialSettingsState'
import { ThemeTokens } from '../theme/ThemeTokens'

/**
 * The measurable activity box around an HDS capsule. Consumers that reserve
 * scroll space for the same capsule must use this instead of reproducing a
 * local height calculation, otherwise the material press area can be clipped.
 */
export function nextNHdsCapsuleActivityHeight(barHeight: number, activityPadding: number): number {
  return barHeight + activityPadding * 2
}

/**
 * One-action floating HDS material bar, based on NextE's capsule bar pattern.
 *
 * The activity box intentionally exceeds the visible bar so the platform
 * material and press animation are never clipped by a page-level Stack.
 */
@ComponentV2
export struct NextNHdsCapsuleBarButton {
  @Param barWidth: number = 144
  @Param barHeight: number = ThemeTokens.ACTION_HEIGHT
  @Param activityPadding: number = ThemeTokens.SPACE_LG
  @Param controller: HdsTabsController = new HdsTabsController()
  @Param maskColor: ResourceColor = Color.Transparent
  @Param barBottomMargin: number = ThemeTokens.SPACE_LG
  @Param barPosition: BarPosition = BarPosition.End
  @Param barOverlap: boolean = true
  @Event onButtonClick?: () => void
  private immersiveMaterial: ImmersiveMaterialSettingsState = connectImmersiveMaterialSettings()
  @BuilderParam buttonContent: () => void = this.DefaultButton

  @Builder
  DefaultButton() {
    SymbolGlyph($r('sys.symbol.doc_plaintext_fill'))
      .fontSize(18)
      .fontColor([ThemeTokens.BRAND])
  }

  private activityWidth(): number {
    return this.barWidth + this.activityPadding * 2
  }

  private activityHeight(): number {
    return nextNHdsCapsuleActivityHeight(this.barHeight, this.activityPadding)
  }

  private currentMaterialType(): hdsMaterial.MaterialType {
    return ImmersiveMaterialSettings.effect(this.immersiveMaterial.level).materialType
  }

  private currentMaterialLevel(): hdsMaterial.MaterialLevel {
    return ImmersiveMaterialSettings.effect(this.immersiveMaterial.level).materialLevel
  }

  build() {
    Stack() {
      HdsTabs({ controller: this.controller }) {
        TabContent().tabBar(this.buttonContent())
      }
      .barWidth(this.barWidth)
      .barHeight(this.barHeight)
      .barOverlap(this.barOverlap)
      .barPosition(this.barPosition)
      .barFloatingStyle({
        gradientMask: {
          maskColor: this.maskColor,
        },
        barBottomMargin: this.barBottomMargin,
        systemMaterialEffect: {
          materialType: this.currentMaterialType(),
          materialLevel: this.currentMaterialLevel(),
        },
      } as HdsTabsFloatingStyle)
      .onTabBarClick((): void => {
        if (this.onButtonClick) {
          this.onButtonClick()
        }
      })
      .width(this.activityWidth())
      .height(this.activityHeight())
      .clip(false)
    }
    .width(this.activityWidth())
    .height(this.activityHeight())
    .clip(false)
  }
}
