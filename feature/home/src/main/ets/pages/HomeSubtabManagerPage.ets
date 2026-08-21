import { common } from '@kit.AbilityKit'
import { HdsNavDestination } from '@kit.UIDesignKit'
import {
  AppStrings,
  HomeSubtabSettings,
  HomeSubtabState,
  NhHomeSubtabKind,
  NhHomeSubtabProfile,
  SecondaryListScaffold,
  ThemeTokens,
  connectHomeSubtabs,
  nextNHdsTitleBar,
} from 'shared'

/** NextE parent tree: native destination -> secondary list -> grouped rows. */
@ComponentV2
export struct HomeSubtabManagerPage {
  @Local homeSubtabs: HomeSubtabState = connectHomeSubtabs()
  @Local visibilityRevision: number = 0
  @Param scroller: Scroller = new Scroller()
  @Param hideBackButton: boolean = false
  @Event onCreate?: () => void
  @Event onEdit?: (uuid: string) => void

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private titleBar(): Record<string, Object> {
    const action: Record<string, Object> = {
      'label': AppStrings.get('home_subtab_create_title'),
      'icon': $r('sys.symbol.plus'),
      'isEnabled': true,
      'action': (): void => {
        if (this.onCreate) {
          this.onCreate()
        }
      },
    }
    const item: Record<string, Object> = { 'content': action }
    const menuItems: Record<string, Object>[] = [item]
    const menu: Record<string, Object> = { 'value': menuItems, 'maxCount': 1 }
    const title: Record<string, Object> = { 'mainTitle': AppStrings.get('home_subtabs_manage_title') }
    return nextNHdsTitleBar({ 'title': title, 'menu': menu })
  }

  private typeLabel(profile: NhHomeSubtabProfile): string {
    if (profile.kind === NhHomeSubtabKind.LATEST) {
      return AppStrings.get('home_subtab_type_latest')
    }
    if (profile.kind === NhHomeSubtabKind.POPULAR) {
      return AppStrings.get('home_subtab_type_popular')
    }
    const query: string = profile.query.trim()
    return query.length > 0
      ? `${AppStrings.get('home_subtab_type_search')} · ${query}`
      : AppStrings.get('home_subtab_type_search')
  }

  private typeIcon(profile: NhHomeSubtabProfile): Resource {
    if (profile.kind === NhHomeSubtabKind.LATEST) {
      return $r('sys.symbol.square_grid_2x2')
    }
    if (profile.kind === NhHomeSubtabKind.POPULAR) {
      return $r('sys.symbol.star')
    }
    return $r('sys.symbol.magnifyingglass')
  }

  private setVisible(profile: NhHomeSubtabProfile, visible: boolean): void {
    HomeSubtabSettings.setHidden(this.context(), profile.uuid, !visible)
      .then((saved: boolean): void => {
        if (!saved) {
          // A Toggle updates its internal visual state optimistically. Remount
          // the rows when the settings layer rejects hiding the final visible
          // profile so the switch immediately reflects the unchanged model.
          this.visibilityRevision += 1
          this.getUIContext().getPromptAction().showToast({
            message: AppStrings.get('home_subtab_last_visible'),
          })
        }
      })
      .catch((): void => {})
  }

  private confirmDelete(profile: NhHomeSubtabProfile): void {
    this.getUIContext().showAlertDialog({
      title: $r('app.string.home_subtab_delete_title'),
      message: $r('app.string.home_subtab_delete_message'),
      primaryButton: { value: $r('app.string.common_cancel'), action: (): void => {} },
      secondaryButton: {
        value: $r('app.string.common_delete'),
        fontColor: Color.Red,
        action: (): void => {
          HomeSubtabSettings.remove(this.context(), profile.uuid)
            .then((removed: boolean): void => {
              if (!removed) {
                this.getUIContext().getPromptAction().showToast({
                  message: AppStrings.get('home_subtab_last_visible'),
                })
              }
            })
            .catch((): void => {})
        },
      },
    })
  }

  @Builder
  private DeleteAction(profile: NhHomeSubtabProfile) {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(ThemeTokens.FONT_SIZE_TITLE)
          .fontColor([Color.White])
      }
      .width(48)
      .height(40)
      .backgroundColor(Color.Red)
      .onClick((): void => this.confirmDelete(profile))
    }
    .height('100%')
    .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ProfileRow(profile: NhHomeSubtabProfile) {
    Row({ space: ThemeTokens.SPACE_MD }) {
      SymbolGlyph(this.typeIcon(profile))
        .fontSize(22)
        .fontColor([$r('sys.color.font_secondary')])
      Column({ space: 2 }) {
        Row({ space: ThemeTokens.SPACE_SM }) {
          Text(HomeSubtabSettings.displayName(profile))
            .fontSize(ThemeTokens.FONT_SIZE_BODY)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (profile.isBuiltin()) {
            Text($r('app.string.home_subtab_builtin_badge'))
              .fontSize(ThemeTokens.FONT_SIZE_TINY)
              .fontColor($r('sys.color.font_tertiary'))
              .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
              .borderRadius(ThemeTokens.RADIUS_SM)
              .padding({ left: 6, right: 6, top: 1, bottom: 1 })
          }
        }
        Text(this.typeLabel(profile))
          .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: !profile.hidden })
        .selectedColor(ThemeTokens.BRAND)
        .onChange((visible: boolean): void => this.setVisible(profile, visible))
    }
    .width('100%')
    .padding(ThemeTokens.SPACE_MD)
    .borderRadius(ThemeTokens.RADIUS_CARD)
    .backgroundColor(ThemeTokens.CARD_BACKGROUND)
    .alignItems(VerticalAlign.Center)
    .opacity(profile.hidden ? 0.45 : 1)
  }

  @Builder
  private ProfileRows() {
    ForEach(
      this.homeSubtabs.profiles,
      (profile: NhHomeSubtabProfile, index: number): void => {
        ListItem() {
          this.ProfileRow(profile)
        }
        .swipeAction({
          end: profile.isBuiltin()
            ? undefined
            : (): void => {
                this.DeleteAction(profile)
              },
        })
        .onClick((): void => {
          if (!profile.isBuiltin() && this.onEdit) {
            this.onEdit(profile.uuid)
          }
        })
      },
      (profile: NhHomeSubtabProfile, index: number): string =>
        `${this.visibilityRevision}_${index}_${profile.uuid}_${profile.lastEditTime}`,
    )
      .onMove((from: number, to: number): void => {
        HomeSubtabSettings.reorder(this.context(), from, to).catch((): void => {})
      })
  }

  build() {
    HdsNavDestination() {
      SecondaryListScaffold({
        scroller: this.scroller,
        listSpace: ThemeTokens.SPACE_SM,
        alwaysEnableEdgeSpring: true,
      }) {
        this.ProfileRows()
      }
    }
    .titleBar(this.titleBar())
    .hideBackButton(this.hideBackButton)
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
