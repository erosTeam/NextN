import { AppStrings, GalleryPageThumbnailSurface, NhGalleryPage, ThemeTokens } from 'shared'

const READER_CONTROL_TINT: ResourceColor = '#26FFFFFF'
const READER_THUMB_STRIP_HEIGHT: number = 140
const READER_THUMB_IMAGE_HEIGHT: number = 100
const READER_THUMB_FALLBACK_ASPECT: number = 0.72
const READER_THUMB_MIN_WIDTH: number = 64
const READER_THUMB_MAX_WIDTH: number = 152
const READER_THUMB_RAIL_HEAD_TAIL_INSET: number = ThemeTokens.SPACE_MD

/** One canonical source page, retained even while the paged Reader is RTL. */
class ReaderThumbnailItem {
  readonly page: NhGalleryPage
  readonly sourceIndex: number

  constructor(page: NhGalleryPage, sourceIndex: number) {
    this.page = page
    this.sourceIndex = sourceIndex
  }
}

/**
 * The strip is a navigation control rather than a second page source. Keeping
 * canonical source indexes here means a thumbnail always enters the existing
 * vertical/paged/RTL turn path instead of creating an alternate Reader state.
 */
export class ReaderThumbnailDataSource implements IDataSource {
  private items: ReaderThumbnailItem[] = []
  private listeners: DataChangeListener[] = []
  private pages: NhGalleryPage[] | null = null

  syncPages(pages: NhGalleryPage[]): void {
    if (this.pages !== pages) this.setData(pages)
  }

  setData(pages: NhGalleryPage[]): void {
    this.pages = pages
    this.items = pages.map((page: NhGalleryPage, sourceIndex: number): ReaderThumbnailItem => {
      return new ReaderThumbnailItem(page, sourceIndex)
    })
    this.listeners.forEach((listener: DataChangeListener): void => {
      listener.onDatasetChange([{ type: DataOperationType.RELOAD }])
    })
  }

  totalCount(): number {
    return this.items.length
  }

  getData(index: number): ReaderThumbnailItem {
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

/** The original NextN List and tile, with each Reader retaining its own data source and scroller. */
@ComponentV2
export struct ReaderThumbnailStrip {
  @Require @Param pages: NhGalleryPage[]
  @Require @Param dataSource: ReaderThumbnailDataSource
  @Require @Param scroller: Scroller
  @Require @Param initialIndex: number
  @Require @Param pageCount: number
  @Require @Param rtl: boolean
  @Require @Param selectedIndices: number[]
  @Event onSelect: (sourceIndex: number, navigationToken: string) => void = () => {}
  @Param navigationToken: string = ''
  /** New shared route follows the committed source; legacy keeps its original caller-driven scrolling. */
  @Param followIndex: number = -1
  @Param visible: boolean = false
  private scrollTarget: number = -1
  private scrollRtl: boolean = false
  private wasVisible: boolean = false

  aboutToAppear(): void {
    this.dataSource.syncPages(this.pages)
    this.scrollTarget = this.initialIndex
    this.scrollRtl = this.rtl
    this.wasVisible = this.visible
  }

  @Monitor('pages')
  onPagesChanged(): void {
    this.dataSource.syncPages(this.pages)
  }

  @Monitor('followIndex', 'visible', 'rtl')
  onFollowChanged(): void {
    const revealed: boolean = this.visible && !this.wasVisible
    this.wasVisible = this.visible
    if (!this.visible || this.followIndex < 0 || this.followIndex >= this.pageCount) return
    const directionChanged: boolean = this.rtl !== this.scrollRtl
    if (!revealed && !directionChanged && this.followIndex === this.scrollTarget) return
    this.scrollTarget = this.followIndex
    this.scrollRtl = this.rtl
    try {
      this.scroller.scrollToIndex(this.followIndex, !revealed && !directionChanged)
    } catch (error) {
      console.warn(`Unable to follow Reader thumbnail selection: ${(error as Error).message}`)
    }
  }

  private readerThumbnailRailViewportWidth(): string {
    return `calc(100% + ${READER_THUMB_RAIL_HEAD_TAIL_INSET * 2}vp)`
  }

  build() {
    List({
      space: ThemeTokens.SPACE_SM,
      initialIndex: this.initialIndex,
      scroller: this.scroller,
    }) {
      LazyForEach(
        this.dataSource,
        (item: ReaderThumbnailItem, _listIndex: number): void => {
          ListItem() {
            ReaderThumbnailTile({
              page: item.page,
              sourceIndex: item.sourceIndex,
              currentIndex: this.initialIndex,
              selected: this.selectedIndices.includes(item.sourceIndex),
              onSelect: (index: number): void => { this.onSelect(index, this.navigationToken) },
            })
          }
          .margin({
            left: (this.rtl
              ? item.sourceIndex === this.pageCount - 1
              : item.sourceIndex === 0) ? READER_THUMB_RAIL_HEAD_TAIL_INSET : 0,
            right: (this.rtl
              ? item.sourceIndex === 0
              : item.sourceIndex === this.pageCount - 1) ? READER_THUMB_RAIL_HEAD_TAIL_INSET : 0,
          })
        },
        (item: ReaderThumbnailItem): string => `reader_thumbnail_${item.sourceIndex}_${item.page.number}`,
      )
    }
    .listDirection(Axis.Horizontal)
    .direction(this.rtl ? Direction.Rtl : Direction.Ltr)
    .scrollBar(BarState.Off)
    .width(this.readerThumbnailRailViewportWidth())
    .height(READER_THUMB_STRIP_HEIGHT)
    .translate({ x: -READER_THUMB_RAIL_HEAD_TAIL_INSET })
  }
}

/**
 * A fixed-height, aspect-aware Reader navigator tile. It uses only page DTO
 * fields already loaded by the Reader and has no independent image request or
 * account behavior.
 */
@ComponentV2
struct ReaderThumbnailTile {
  @Require @Param page: NhGalleryPage
  @Require @Param sourceIndex: number
  @Require @Param currentIndex: number
  @Param selected: boolean = false
  @Event onSelect?: (sourceIndex: number) => void
  @Local decodedThumbnailWidth: number = 0
  @Local decodedThumbnailHeight: number = 0

  @Monitor('page')
  onThumbnailSourceChanged(): void {
    this.decodedThumbnailWidth = 0
    this.decodedThumbnailHeight = 0
  }

  private thumbnailWidth(): number {
    const sourceWidth: number = this.page.thumbnailWidth > 0
      ? this.page.thumbnailWidth
      : this.decodedThumbnailWidth
    const sourceHeight: number = this.page.thumbnailHeight > 0
      ? this.page.thumbnailHeight
      : this.decodedThumbnailHeight
    const aspect: number = sourceWidth > 0 && sourceHeight > 0
      ? sourceWidth / sourceHeight
      : READER_THUMB_FALLBACK_ASPECT
    const boundedAspect: number = Number.isFinite(aspect)
      ? Math.min(1.4, Math.max(0.45, aspect))
      : READER_THUMB_FALLBACK_ASPECT
    return Math.round(Math.min(
      READER_THUMB_MAX_WIDTH,
      Math.max(READER_THUMB_MIN_WIDTH, READER_THUMB_IMAGE_HEIGHT * boundedAspect),
    ))
  }

  private pageLabel(): string {
    return AppStrings.format('thumbnails_page_label', [(this.sourceIndex + 1).toString()])
  }

  build() {
    Column({ space: ThemeTokens.SPACE_XS }) {
      Stack({ alignContent: Alignment.Center }) {
        GalleryPageThumbnailSurface({
          src: this.page.thumbnailUrl,
          objectFit: ImageFit.Contain,
          placeholderColor: READER_CONTROL_TINT,
          indicatorColor: ThemeTokens.TEXT_ON_BRAND,
          errorOpacity: 0.62,
          errorIconSize: 24,
          onImageInfo: (width: number, height: number): void => {
            this.decodedThumbnailWidth = width
            this.decodedThumbnailHeight = height
          },
        })
      }
      .width(this.thumbnailWidth())
      .height(READER_THUMB_IMAGE_HEIGHT)
      .border({
        width: this.selected ? 2 : 0,
        color: this.selected ? ThemeTokens.BRAND : Color.Transparent,
      })
      .borderRadius(ThemeTokens.THUMB_RADIUS)
      .clip(true)
      Text(this.pageLabel())
        .fontSize(ThemeTokens.FONT_SIZE_META)
        .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.selected ? ThemeTokens.BRAND : ThemeTokens.TEXT_ON_BRAND)
        .opacity(this.selected ? 1 : 0.82)
        .maxLines(1)
        .width(this.thumbnailWidth())
        .textAlign(TextAlign.Center)
    }
    .width(this.thumbnailWidth())
    .height(READER_THUMB_STRIP_HEIGHT)
    .padding({ top: ThemeTokens.SPACE_XS, bottom: ThemeTokens.SPACE_XS })
    .alignItems(HorizontalAlign.Center)
    .accessibilityText(AppStrings.format('reader_thumbnails_open_page_a11y', [(this.sourceIndex + 1).toString()]))
    .onClick((): void => {
      if (this.onSelect) {
        this.onSelect(this.sourceIndex)
      }
    })
}
}
