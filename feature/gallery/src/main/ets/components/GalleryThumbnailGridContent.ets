import {
  AppStrings,
  NextNModalScaffold,
  NhGalleryPage,
  PageEmptyState,
  PullRefreshGridScaffold,
  ThemeTokens,
} from 'shared'
import { appSheetOptions } from 'shared'
import {
  GalleryVirtualPageThumbnailDataSource,
  GalleryVirtualPageThumbnailTile,
} from './GalleryVirtualPageThumbnail'
import { GalleryThumbnailsChromeState } from '../state/GalleryThumbnailsChromeState'

/**
 * Reusable full-thumbnail content owner. The host supplies route chrome and
 * Reader navigation; this component owns one virtual Grid, its safe-area
 * scaffold, and the bounded First/Jump commands used by both the standalone
 * overview and Gallery Detail's wide preview pane.
 */
@ComponentV2
export struct GalleryThumbnailGridContent {
  @Param pages: NhGalleryPage[] = []
  @Param chrome: GalleryThumbnailsChromeState = new GalleryThumbnailsChromeState()
  @Param scroller: Scroller = new Scroller()
  @Param bottomPadding: number = ThemeTokens.SPACE_XL
  @Event onOpenPage?: (pageIndex: number) => void
  /** Detail's wide pane may observe only its actual Grid scroll surface. */
  @Event onScrollTouch?: (event: TouchEvent) => void
  @Local itemCount: number = 0
  @Local jumpSheetShown: boolean = false
  @Local jumpPageText: string = ''
  @Local jumpError: string = ''
  private dataSource: GalleryVirtualPageThumbnailDataSource = new GalleryVirtualPageThumbnailDataSource()
  private jumpSheetScroller: Scroller = new Scroller()

  @Monitor('chrome.firstPageRequestVersion')
  onFirstPageRequested(): void {
    if (this.chrome.firstPageRequestVersion <= 0 || this.itemCount === 0) {
      return
    }
    this.jumpSheetShown = false
    this.scroller.scrollToIndex(0)
  }

  @Monitor('chrome.jumpPageRequestVersion')
  onJumpPageRequested(): void {
    if (this.chrome.jumpPageRequestVersion <= 0 || this.itemCount === 0) {
      return
    }
    this.jumpPageText = ''
    this.jumpError = ''
    this.jumpSheetShown = true
  }

  private normalizeJumpInput(value: string): string {
    return (value || '').replace(/[^0-9]/g, '')
  }

  private jumpRangeLabel(): string {
    return AppStrings.format('thumbnails_jump_range', [this.itemCount.toString()])
  }

  private confirmJump(): void {
    const pageNumber: number = Number.parseInt(this.jumpPageText, 10)
    if (Number.isNaN(pageNumber) || pageNumber <= 0 || pageNumber > this.itemCount) {
      this.jumpError = AppStrings.format('thumbnails_jump_invalid', [this.itemCount.toString()])
      return
    }
    const sourceIndex: number = pageNumber - 1
    // PullRefreshGridScaffold emits its safe/title spacer at Grid index zero.
    // Keep Reader's source index canonical, then map it to the next Grid item.
    const gridIndex: number = sourceIndex + 1
    this.jumpSheetShown = false
    this.scroller.scrollToIndex(gridIndex)
  }

  // Reader is an entry-owned overlay over the retained root destination. A
  // return from that overlay can invoke this lifecycle hook without changing
  // this route's page payload, so retain a value snapshot rather than issuing
  // a virtual-grid RELOAD solely because the content became visible again.
  private appliedPages: NhGalleryPage[] = []
  private hasAppliedPages: boolean = false

  aboutToAppear(): void {
    this.syncPages(this.pages)
  }

  @Monitor('pages')
  onPagesChanged(): void {
    this.syncPages(this.pages)
  }

  /**
   * Route recreation must still initialise the virtual Grid, while retained
   * Reader-overlay reentry must leave its source and scroll position intact.
   * Compare all render-relevant page fields so an explicit Detail/route page
   * update still reaches the IDataSource as one deliberate reload.
   */
  private syncPages(pages: NhGalleryPage[]): void {
    if (this.matchesAppliedPages(pages)) {
      return
    }
    this.setPages(pages)
    this.appliedPages = this.copyPages(pages)
    this.hasAppliedPages = true
  }

  private matchesAppliedPages(pages: NhGalleryPage[]): boolean {
    if (!this.hasAppliedPages || this.appliedPages.length !== pages.length) {
      return false
    }
    for (let index: number = 0; index < pages.length; index += 1) {
      if (!this.samePageData(this.appliedPages[index], pages[index])) {
        return false
      }
    }
    return true
  }

  private samePageData(left: NhGalleryPage, right: NhGalleryPage): boolean {
    return left.number === right.number &&
      left.extension === right.extension &&
      left.width === right.width &&
      left.height === right.height &&
      left.thumbnailUrl === right.thumbnailUrl
  }

  private copyPages(pages: NhGalleryPage[]): NhGalleryPage[] {
    return pages.map((page: NhGalleryPage): NhGalleryPage => {
      const copy: NhGalleryPage = new NhGalleryPage()
      copy.number = page.number
      copy.extension = page.extension
      copy.width = page.width
      copy.height = page.height
      copy.thumbnailUrl = page.thumbnailUrl
      return copy
    })
  }

  private setPages(pages: NhGalleryPage[]): void {
    // The source-array index is the Reader's canonical zero-based page index.
    this.dataSource.setData(pages.slice())
    this.itemCount = pages.length
    if (pages.length === 0) {
      this.jumpSheetShown = false
    }
  }

  @Builder
  private JumpSheet() {
    NextNModalScaffold({
      title: AppStrings.get('thumbnails_jump_page'),
      scroller: this.jumpSheetScroller,
      showConfirmAction: true,
      confirmText: AppStrings.get('thumbnails_jump_page'),
      confirmEnabled: this.jumpPageText.length > 0,
      onClose: (): void => {
        this.jumpSheetShown = false
      },
      onConfirm: (): void => {
        this.confirmJump()
      },
    }) {
      ListItem() {
        Column({ space: ThemeTokens.SPACE_SM }) {
          Text(this.jumpRangeLabel())
            .fontSize(ThemeTokens.FONT_SIZE_BODY)
            .fontColor(ThemeTokens.TEXT_SECONDARY)
            .width('100%')
          TextInput({
            text: this.jumpPageText,
            placeholder: this.jumpRangeLabel(),
          })
            .type(InputType.Number)
            .inputFilter('^[0-9]*$')
            .defaultFocus(true)
            .width('100%')
            .onChange((value: string): void => {
              this.jumpPageText = this.normalizeJumpInput(value)
              this.jumpError = ''
            })
            .onSubmit((): void => {
              this.confirmJump()
            })
          if (this.jumpError.length > 0) {
            Text(this.jumpError)
              .fontSize(ThemeTokens.FONT_SIZE_CAPTION)
              .fontColor(Color.Red)
              .width('100%')
          }
        }
        .width('100%')
        .padding({ top: ThemeTokens.SPACE_SM })
      }
    }
  }

  private openPage(pageIndex: number): void {
    if (pageIndex < 0 || pageIndex >= this.itemCount || !this.onOpenPage) {
      return
    }
    this.onOpenPage(pageIndex)
  }

  @Builder
  private ThumbnailGrid() {
    Column() {
      PullRefreshGridScaffold({
        scroller: this.scroller,
        minColumnWidth: 112,
        densityEnabled: false,
        gap: ThemeTokens.SPACE_SM,
        rowGap: ThemeTokens.SPACE_MD,
        horizontalPadding: ThemeTokens.SPACE_MD,
        bottomPadding: this.bottomPadding,
        contentItemCount: this.itemCount,
        refreshEnabled: false,
        onScrollTouch: (event: TouchEvent): void => {
          if (this.onScrollTouch) {
            this.onScrollTouch(event)
          }
        },
      }) {
        LazyForEach(
          this.dataSource,
          (page: NhGalleryPage, index: number): void => {
            GridItem() {
              GalleryVirtualPageThumbnailTile({
                page: page,
                pageIndex: index,
                onOpen: (pageIndex: number): void => {
                  this.openPage(pageIndex)
                },
              })
            }
          },
          (page: NhGalleryPage, index: number): string => `thumbnail_${index}_${page.number}`,
        )
      }
    }
    .layoutWeight(1)
    .width('100%')
  }

  build() {
    Column() {
      if (this.itemCount === 0) {
        PageEmptyState({ message: AppStrings.get('thumbnails_empty') })
      } else {
        this.ThumbnailGrid()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeTokens.SURFACE)
    .bindSheet($$this.jumpSheetShown, this.JumpSheet(), appSheetOptions({
      detents: [SheetSize.MEDIUM],
      showClose: false,
    }))
  }
}
