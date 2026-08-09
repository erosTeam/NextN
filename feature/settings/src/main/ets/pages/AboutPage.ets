import { bundleManager } from '@kit.AbilityKit'
import {
  AppStrings,
  NextNGroupedListSection,
  NextNListRow,
  SecondaryListScaffold,
  ThemeTokens,
} from 'shared'

/**
 * A deliberately local About destination. It keeps the compact NextE grouped
 * list hierarchy, but does not imply a release-update service, a browser
 * handoff, or any remote write that NextN has not implemented.
 */
@ComponentV2
export struct AboutPage {
  @Local appVersion: string = AppStrings.get('about_version_unavailable')
  @Param scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
      .then((info) => {
        this.appVersion = `${info.versionName} (${info.versionCode})`
      })
      .catch((): void => {
        this.appVersion = AppStrings.get('about_version_unavailable')
      })
  }

  @Builder
  private AppHeader() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Text(AppStrings.get('EntryAbility_label'))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeTokens.TEXT_PRIMARY)
      Text(AppStrings.get('about_tagline'))
        .fontSize(ThemeTokens.FONT_SIZE_BODY)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
      Text(this.appVersion)
        .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
        .fontColor(ThemeTokens.TEXT_SECONDARY)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .padding({
      left: ThemeTokens.SPACE_LG,
      right: ThemeTokens.SPACE_LG,
      top: ThemeTokens.SPACE_XL,
      bottom: ThemeTokens.SPACE_LG,
    })
    .borderRadius(ThemeTokens.RADIUS_CARD)
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
  }

  @Builder
  private RowDivider() {
    Divider()
      .strokeWidth(0.5)
      .color(ThemeTokens.DIVIDER)
      .margin({ left: ThemeTokens.SPACE_MD })
  }

  @Builder
  private AppInfoSection() {
    NextNGroupedListSection() {
      NextNListRow({
        title: AppStrings.get('about_application'),
        trailingText: AppStrings.get('EntryAbility_label'),
        showChevron: false,
      })
      this.RowDivider()
      NextNListRow({
        title: AppStrings.get('about_version'),
        trailingText: this.appVersion,
        showChevron: false,
      })
      this.RowDivider()
      NextNListRow({
        title: AppStrings.get('about_platform'),
        trailingText: AppStrings.get('about_harmony_platform'),
        showChevron: false,
      })
    }
  }

  build() {
    Column() {
      SecondaryListScaffold({
        scroller: this.scroller,
        bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
        alwaysEnableEdgeSpring: true,
      }) {
        ListItem() {
          this.AppHeader()
        }
        ListItem() {
          Text(AppStrings.get('about_information'))
            .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .width('100%')
            .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
        }
        .margin({ top: ThemeTokens.SPACE_MD })
        ListItem() {
          this.AppInfoSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE_SUB)
  }
}
