import { common } from '@kit.AbilityKit'
import {
  AppStrings,
  BrowsePresentationService,
  BrowsePresentationState,
  NhBrowsePresentation,
  SecondaryListScaffold,
  ThemeTokens,
  clampGalleryColumnWidth,
  galleryBaseMinColumnWidth,
  galleryColumnCount,
  supportsGalleryColumnDensity,
  connectBrowsePresentation,
} from 'shared'

const PREVIEW_HEIGHT: number = 220

/**
 * A local-only density destination modelled on NextE's ColumnDensityPage.
 * It deliberately renders neutral placeholders: this screen previews native
 * geometry only and never loads covers, account state, or gallery content.
 */
@ComponentV2
export struct BrowseDensitySettingsPage {
  @Param targetPresentation: NhBrowsePresentation = NhBrowsePresentation.COVER_GRID
  @Param scroller: Scroller = new Scroller()
  @Local browsePresentation: BrowsePresentationState = connectBrowsePresentation()
  @Local previewWidth: number = 0
  private previewCells: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private effectivePresentation(): NhBrowsePresentation {
    return supportsGalleryColumnDensity(this.targetPresentation)
      ? this.targetPresentation
      : NhBrowsePresentation.COVER_GRID
  }

  private presentationLabel(): string {
    if (this.effectivePresentation() === NhBrowsePresentation.WATERFALL) {
      return AppStrings.get('browse_waterfall')
    }
    if (this.effectivePresentation() === NhBrowsePresentation.WATERFALL_COMPACT) {
      return AppStrings.get('browse_waterfall_compact')
    }
    if (this.effectivePresentation() === NhBrowsePresentation.COVER_WALL) {
      return AppStrings.get('browse_cover_wall')
    }
    return AppStrings.get('browse_cover_grid')
  }

  private effectiveColumnWidth(): number {
    const override: number = this.browsePresentation.columnWidthFor(this.effectivePresentation())
    return override > 0 ? override : galleryBaseMinColumnWidth(this.effectivePresentation())
  }

  private currentColumns(): number {
    return galleryColumnCount(
      this.previewWidth,
      this.effectiveColumnWidth(),
      ThemeTokens.GALLERY_GRID_GAP,
      ThemeTokens.GALLERY_GRID_GAP,
    )
  }

  private gridPreviewTemplate(): string {
    return `repeat(auto-fit, ${this.effectiveColumnWidth()}vp)`
  }

  private waterFlowPreviewSections(): WaterFlowSections {
    const sections: WaterFlowSections = new WaterFlowSections()
    sections.splice(0, 0, [{
      itemsCount: this.previewCells.length,
      crossCount: this.currentColumns(),
      columnsGap: ThemeTokens.GALLERY_GRID_GAP,
      rowsGap: ThemeTokens.GALLERY_GRID_GAP,
    }])
    return sections
  }

  private isWaterfallPreview(): boolean {
    return this.effectivePresentation() === NhBrowsePresentation.WATERFALL ||
      this.effectivePresentation() === NhBrowsePresentation.WATERFALL_COMPACT ||
      this.effectivePresentation() === NhBrowsePresentation.COVER_WALL
  }

  private previewAspectRatio(cell: number): number {
    if (this.effectivePresentation() === NhBrowsePresentation.COVER_GRID) {
      return ThemeTokens.GALLERY_GRID_COVER_RATIO
    }
    if (this.effectivePresentation() === NhBrowsePresentation.WATERFALL_COMPACT) {
      return cell % 3 === 0 ? 0.62 : cell % 3 === 1 ? 0.84 : 0.72
    }
    if (this.effectivePresentation() === NhBrowsePresentation.WATERFALL) {
      return cell % 3 === 0 ? 0.58 : cell % 3 === 1 ? 0.86 : 0.7
    }
    return cell % 3 === 0 ? 0.58 : cell % 3 === 1 ? 0.9 : 0.72
  }

  @Builder
  private PreviewCell(cell: number) {
    Column() {}
      .width('100%')
      .aspectRatio(this.previewAspectRatio(cell))
      .borderRadius(this.isWaterfallPreview() ? ThemeTokens.RADIUS_CARD : ThemeTokens.GALLERY_GRID_CARD_RADIUS)
      .backgroundColor(ThemeTokens.COVER_PLACEHOLDER)
  }

  @Builder
  private Preview() {
    Column() {
      if (this.isWaterfallPreview()) {
        WaterFlow({
          sections: this.waterFlowPreviewSections(),
          layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW,
        }) {
          ForEach(this.previewCells, (cell: number): void => {
            FlowItem() {
              this.PreviewCell(cell)
            }
            .width('100%')
          }, (cell: number): string => cell.toString())
        }
        .columnsGap(ThemeTokens.GALLERY_GRID_GAP)
        .rowsGap(ThemeTokens.GALLERY_GRID_GAP)
        .enableScrollInteraction(false)
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      } else {
        Grid() {
          ForEach(this.previewCells, (cell: number): void => {
            GridItem() {
              this.PreviewCell(cell)
            }
          }, (cell: number): string => cell.toString())
        }
        .columnsTemplate(this.gridPreviewTemplate())
        .columnsGap(ThemeTokens.GALLERY_GRID_GAP)
        .rowsGap(ThemeTokens.GALLERY_GRID_GAP)
        .enableScrollInteraction(false)
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height(PREVIEW_HEIGHT)
    .padding({
      left: ThemeTokens.GALLERY_GRID_GAP,
      right: ThemeTokens.GALLERY_GRID_GAP,
    })
    .clip(true)
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      const width: number = Number.parseFloat(`${newValue.width}`)
      if (width > 0 && Math.abs(width - this.previewWidth) > 0.5) {
        this.previewWidth = width
      }
    })
  }

  private updateWidth(value: number, mode: SliderChangeMode): void {
    const width: number = clampGalleryColumnWidth(value)
    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
      BrowsePresentationService.setColumnWidth(
        this.context(),
        this.effectivePresentation(),
        width,
      ).catch((): void => {})
      return
    }
    BrowsePresentationService.setLiveColumnWidth(this.effectivePresentation(), width)
  }

  build() {
    SecondaryListScaffold({
      scroller: this.scroller,
      horizontalPadding: 0,
      bottomPadding: ThemeTokens.LIST_BOTTOM_PADDING,
      alwaysEnableEdgeSpring: true,
    }) {
      ListItem() {
        Column({ space: ThemeTokens.SPACE_MD }) {
          this.Preview()
          Column({ space: ThemeTokens.SPACE_SM }) {
            Text(AppStrings.get('settings_browse_column_width_hint'))
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontColor(ThemeTokens.TEXT_SECONDARY)
              .width('100%')
            Slider({
              value: this.effectiveColumnWidth(),
              min: ThemeTokens.GALLERY_COLUMN_WIDTH_FLOOR,
              max: ThemeTokens.GALLERY_COLUMN_WIDTH_CEILING,
              step: 1,
              style: SliderStyle.InSet,
            })
              .width('100%')
              .selectedColor(ThemeTokens.BRAND)
              .accessibilityText(AppStrings.format('settings_browse_column_width_a11y', [
                this.presentationLabel(),
                this.effectiveColumnWidth().toString(),
              ]))
              .onChange((value: number, mode: SliderChangeMode): void => {
                this.updateWidth(value, mode)
              })
          }
          .width('100%')
          .padding({ left: ThemeTokens.SPACE_MD, right: ThemeTokens.SPACE_MD })
        }
        .width('100%')
      }
    }
  }
}
