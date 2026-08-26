import {
  AppStrings,
  NhGalleryPage,
  ReaderThumbnailTransitionState,
  ThemeTokens,
  connectReaderThumbnailTransition,
} from 'shared'

// NextE keeps a stable portrait preview frame so a wide or malformed source
// thumbnail cannot move neighbouring page numbers or destabilise Grid rows.
const PREVIEW_FRAME_ASPECT: number = 1.4

/**
 * Stable page source for a virtualised thumbnail host. The owner chooses the
 * Grid, Scroller, paging policy, and Reader route; this source only exposes
 * the already-resolved gallery pages without eagerly mounting every tile.
 */
export class GalleryVirtualPageThumbnailDataSource implements IDataSource {
  private items: NhGalleryPage[] = []
  private listeners: DataChangeListener[] = []

  setData(items: NhGalleryPage[]): void {
    this.items = items
    this.listeners.forEach((listener: DataChangeListener): void => {
      listener.onDatasetChange([{ type: DataOperationType.RELOAD }])
    })
  }

  totalCount(): number {
    return this.items.length
  }

  getData(index: number): NhGalleryPage {
    return this.items[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index: number = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }
}

/**
 * One fixed-frame page preview. A failed thumbnail never disables its Reader
 * activation, and the host retains ownership of the actual navigation action.
 */
@ComponentV2
export struct GalleryVirtualPageThumbnailTile {
  @Require @Param page: NhGalleryPage
  @Require @Param pageIndex: number
  @Param transitionSourceId: string = ''
  @Event onOpen?: (pageIndex: number) => void
  @Local isThumbnailLoading: boolean = true
  @Local hasThumbnailError: boolean = false
  @Local measuredWidth: number = 0
  @Local readerTransition: ReaderThumbnailTransitionState = connectReaderThumbnailTransition()

  aboutToAppear(): void {
    this.resetThumbnailState()
  }

  @Monitor('page')
  onPageChanged(): void {
    this.resetThumbnailState()
  }

  private resetThumbnailState(): void {
    this.isThumbnailLoading = this.page.thumbnailUrl.length > 0
    this.hasThumbnailError = false
  }

  private pageLabel(): string {
    return AppStrings.format('thumbnails_page_label', [(this.pageIndex + 1).toString()])
  }

  private hasSourceSize(): boolean {
    return this.page.width > 0 && this.page.height > 0
  }

  private sourceAspect(): number {
    if (!this.hasSourceSize()) {
      return 0
    }
    return this.page.height / this.page.width
  }

  /** Contain: fit by height when taller than the frame, else by width. */
  private fitByHeight(): boolean {
    const aspect: number = this.sourceAspect()
    return aspect > 0 && aspect > PREVIEW_FRAME_ASPECT
  }

  private frameWidth(): number {
    return this.measuredWidth > 0 ? this.measuredWidth : 112
  }

  private frameHeight(): number {
    return this.frameWidth() * PREVIEW_FRAME_ASPECT
  }

  private fittedWidth(): number {
    if (!this.hasSourceSize() || !this.fitByHeight()) {
      return this.frameWidth()
    }
    return (this.frameHeight() * this.page.width) / this.page.height
  }

  private fittedHeight(): number {
    if (!this.hasSourceSize() || this.fitByHeight()) {
      return this.frameHeight()
    }
    return (this.frameWidth() * this.page.height) / this.page.width
  }

  @Builder
  private ThumbnailFallback() {
    if (this.page.thumbnailUrl.length === 0 || this.hasThumbnailError) {
      SymbolGlyph($r('sys.symbol.picture'))
        .fontSize(26)
        .fontColor([ThemeTokens.TEXT_TERTIARY])
    } else if (this.isThumbnailLoading) {
      LoadingProgress()
        .width(20)
        .height(20)
        .color(ThemeTokens.TEXT_TERTIARY)
    }
  }

  build() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Stack({ alignContent: Alignment.Center }) {
        Stack({ alignContent: Alignment.Center }) {
          if (this.page.thumbnailUrl.length > 0 && !this.hasThumbnailError) {
            Image(this.page.thumbnailUrl)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Fill)
              .onComplete((): void => {
                this.isThumbnailLoading = false
              })
              .onError((): void => {
                this.isThumbnailLoading = false
                this.hasThumbnailError = true
              })
          }
          this.ThumbnailFallback()
        }
        .width(this.fittedWidth())
        .height(this.fittedHeight())
        .id(this.transitionSourceId)
        .borderRadius(ThemeTokens.THUMB_RADIUS)
        .clip(true)
        .visibility(
          this.readerTransition.sourceHidden(this.transitionSourceId)
            ? Visibility.Hidden
            : Visibility.Visible,
        )
      }
      .width('100%')
      .aspectRatio(1 / PREVIEW_FRAME_ASPECT)
      .clip(true)
      Text(`${this.pageIndex + 1}`)
        .fontSize(ThemeTokens.FONT_SIZE_TINY)
        .fontColor(ThemeTokens.TEXT_TERTIARY)
        .maxLines(1)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      const parsed: number = Number.parseFloat(`${newValue.width}`)
      if (parsed > 0) {
        this.measuredWidth = parsed
      }
    })
    .accessibilityText(AppStrings.format('thumbnails_open_reader_a11y', [this.pageLabel()]))
    .onClick((): void => {
      if (this.onOpen) {
        this.onOpen(this.pageIndex)
      }
    })
  }
}
