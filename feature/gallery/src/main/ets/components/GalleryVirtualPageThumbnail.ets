import {
  AppStrings,
  GalleryPageThumbnailSurface,
  NhGalleryPage,
  ReaderThumbnailTransitionCoordinator,
  ReaderThumbnailTransitionState,
  ReaderTrialEntryRelay,
  ReaderTrialEntrySource,
  ThemeTokens,
  connectReaderThumbnailTransition,
} from 'shared'

// Keep one stable portrait alignment frame so differently shaped NH thumbnail
// assets cannot move neighbouring page numbers or destabilise Grid rows.
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
  @Param galleryId: number = 0
  @Require @Param page: NhGalleryPage
  @Require @Param pageIndex: number
  @Param transitionSourceId: string = ''
  @Event onOpen?: (pageIndex: number, source: ReaderTrialEntrySource) => void
  @Local measuredWidth: number = 0
  @Local decodedThumbnailWidth: number = 0
  @Local decodedThumbnailHeight: number = 0
  @Local readerTransition: ReaderThumbnailTransitionState = connectReaderThumbnailTransition()
  private sourceMounted: boolean = false
  private sourceMountEpoch: number = 0

  @Monitor('page')
  onThumbnailSourceChanged(): void {
    this.decodedThumbnailWidth = 0
    this.decodedThumbnailHeight = 0
  }

  private pageLabel(): string {
    return AppStrings.format('thumbnails_page_label', [(this.pageIndex + 1).toString()])
  }

  private thumbnailSourceWidth(): number {
    return this.decodedThumbnailWidth > 0
      ? this.decodedThumbnailWidth
      : this.page.thumbnailWidth
  }

  private thumbnailSourceHeight(): number {
    return this.decodedThumbnailHeight > 0
      ? this.decodedThumbnailHeight
      : this.page.thumbnailHeight
  }

  private hasThumbnailSourceSize(): boolean {
    return this.thumbnailSourceWidth() > 0 && this.thumbnailSourceHeight() > 0
  }

  /** NH thumbnail assets are independent crops; full-page dimensions are invalid here. */
  private thumbnailAspect(): number {
    if (!this.hasThumbnailSourceSize()) {
      return 0
    }
    return this.thumbnailSourceHeight() / this.thumbnailSourceWidth()
  }

  /** Contain: fit by height when taller than the frame, else by width. */
  private fitByHeight(): boolean {
    const aspect: number = this.thumbnailAspect()
    return aspect > 0 && aspect > PREVIEW_FRAME_ASPECT
  }

  private frameWidth(): number {
    return this.measuredWidth > 0 ? this.measuredWidth : 112
  }

  private frameHeight(): number {
    return this.frameWidth() * PREVIEW_FRAME_ASPECT
  }

  private fittedWidth(): number {
    const aspect: number = this.thumbnailAspect()
    if (aspect <= 0 || !this.fitByHeight()) {
      return this.frameWidth()
    }
    return this.frameHeight() / aspect
  }

  private fittedHeight(): number {
    const aspect: number = this.thumbnailAspect()
    if (aspect <= 0 || this.fitByHeight()) {
      return this.frameHeight()
    }
    return this.frameWidth() * aspect
  }

  build() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Stack({ alignContent: Alignment.Center }) {
        Stack({ alignContent: Alignment.Center }) {
          Stack({ alignContent: Alignment.Center }) {
            GalleryPageThumbnailSurface({
              src: this.page.thumbnailUrl,
              objectFit: ImageFit.Contain,
              onImageInfo: (width: number, height: number): void => {
                this.decodedThumbnailWidth = width
                this.decodedThumbnailHeight = height
              },
            })
          }
          .id(ReaderThumbnailTransitionCoordinator.sourceSnapshotId(this.transitionSourceId))
          .width('100%')
          .height('100%')
        }
        .width(this.fittedWidth())
        .height(this.fittedHeight())
        .id(this.transitionSourceId)
        .onAppear((): void => { this.sourceMounted = true; this.sourceMountEpoch += 1 })
        .onDisAppear((): void => { this.sourceMounted = false })
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
        const galleryId = this.galleryId
        const pageIndex = this.pageIndex
        const pageNumber = this.page.number
        const sourceId = this.transitionSourceId
        const snapshotId = ReaderThumbnailTransitionCoordinator.sourceSnapshotId(sourceId)
        const thumbnailUrl = this.page.thumbnailUrl
        const mountEpoch = this.sourceMountEpoch
        const source = new ReaderTrialEntrySource(galleryId, pageIndex, sourceId, snapshotId, 'grid', thumbnailUrl)
        source.isCurrent = (): boolean => this.sourceMounted && this.sourceMountEpoch === mountEpoch &&
          this.galleryId === galleryId && this.pageIndex === pageIndex && this.page.number === pageNumber &&
          sourceId.length > 0 && this.transitionSourceId === sourceId &&
          ReaderThumbnailTransitionCoordinator.sourceSnapshotId(this.transitionSourceId) === snapshotId &&
          this.page.thumbnailUrl === thumbnailUrl && !this.readerTransition.sourceHidden(sourceId)
        if (ReaderTrialEntryRelay.tryOpen(source)) return
        this.onOpen(this.pageIndex, source)
      }
    })
  }
}
