import { AppStrings } from '../i18n/AppStrings'
import { NhBrowsePresentation } from '../model/NhBrowsePresentation'
import { NhGallerySummary } from '../model/NhGallery'
import { BrowsePresentationState, connectBrowsePresentation } from '../state/BrowsePresentationState'
import { ThemeTokens } from '../theme/ThemeTokens'
import { galleryCoverWallReuseId, GalleryCoverWallCard } from './GalleryCoverWallCard'
import { GalleryGridCard } from './GalleryGridCard'
import { GalleryListItem } from './GalleryListItem'
import { GalleryMediumCard } from './GalleryMediumCard'
import { galleryWaterfallCompactReuseId, GalleryWaterfallCompactCard } from './GalleryWaterfallCompactCard'
import { galleryWaterfallReuseId, GalleryWaterfallCard } from './GalleryWaterfallCard'
import { InlineRetryNotice } from './InlineRetryNotice'
import { LoadingFooter } from './LoadingFooter'
import { PageEmptyState, PageErrorState, PageLoadingState } from './PageStates'
import { NextNPullRefreshController } from './PullRefresh'
import { PullRefreshGridScaffold } from './PullRefreshGridScaffold'
import { PullRefreshListScaffold } from './PullRefreshListScaffold'
import { PullRefreshWaterFlowScaffold } from './PullRefreshWaterFlowScaffold'

/**
 * One NextE-shaped gallery collection parent tree for NextN browse-like
 * surfaces.  A caller owns request generations and filters; this component
 * owns only the common visual state, one top refresh owner, safe-area
 * reserves, density branch and pagination tail.
 *
 * It deliberately contains no source, query, account-bound, or Gallery-route
 * policy.  Those remain leaf data/action boundaries when callers migrate.
 */
@ComponentV2
export struct GalleryCollectionBody {
  @Require @Param galleries: NhGallerySummary[]
  /** Home sources may pin a renderer; all other collection callers follow the shared setting. */
  @Param presentationOverride: NhBrowsePresentation | null = null
  /** A Home split peer may mark one loaded card; all other callers leave this at zero. */
  @Param selectedGalleryId: number = 0
  @Param isInitialLoading: boolean = false
  /** Page-one refresh keeps rows mounted; its footer must not imply a settled cursor. */
  @Param isRefreshing: boolean = false
  @Param isLoadingMore: boolean = false
  /** Request state is caller-owned; a visible length never proves another page exists. */
  @Param canLoadMore: boolean = false
  @Param errorMessage: string = ''
  @Param loadMoreErrorMessage: string = ''
  @Param emptyMessage: string = AppStrings.get('common_nothing_to_show')
  @Param loadingMessage: string = AppStrings.get('common_loading')
  /** Callers retain source-specific tail wording rather than being restyled by this host. */
  @Param footerLoadingText: string = AppStrings.get('footer_loading_more')
  @Param footerAvailableText: string = AppStrings.get('footer_more_available')
  @Param footerCompleteText: string = AppStrings.get('footer_up_to_date')
  @Param footerIdleText: string = ''
  @Param footerRetryLabel: string = AppStrings.get('footer_try_again')
  @Param bottomPadding: number = ThemeTokens.LIST_BOTTOM_PADDING
  @Param topPadding: number = 0
  /**
   * A destination may retain a small, source-owned result-context row before
   * the common retry notice and gallery cards (for example Search's committed
   * language/sort snapshot). The collection still owns all gallery-card,
   * footer and refresh branches; this is only a leaf insertion boundary.
   */
  @Param leadingItemCount: number = 0
  @BuilderParam leadingContent: () => void = this.EmptyLeadingContent
  @Param scroller: Scroller = new Scroller()
  @Param controller: NextNPullRefreshController = new NextNPullRefreshController()
  @Param refreshEnabled: boolean = true
  @Param backToTop: boolean = true
  @Event onRefresh?: () => Promise<void>
  @Event onRetry?: () => void
  @Event onLoadMore?: () => void
  /** Separate footer retry preserves callers that gate tail reach-end after an error. */
  @Event onRetryLoadMore?: () => void
  @Event onOpenGallery?: (galleryId: number, seed?: NhGallerySummary) => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void
  @Event onUserScroll?: () => void
  /** Supplied only by the shared List host for adaptive medium-card cover sizing. */
  @Local listContentWidth: number = 0
  browsePresentation: BrowsePresentationState = connectBrowsePresentation()

  private effectivePresentation(): NhBrowsePresentation {
    return this.presentationOverride === null ? this.browsePresentation.mode : this.presentationOverride
  }

  private hasInlineError(): boolean {
    return this.errorMessage.length > 0 && this.galleries.length > 0
  }

  private isGallerySelected(gallery: NhGallerySummary): boolean {
    return this.selectedGalleryId > 0 && gallery.id === this.selectedGalleryId
  }

  private normalizedLeadingItemCount(): number {
    const callerLeadingCount: number = this.leadingItemCount > 0 ? this.leadingItemCount : 0
    return callerLeadingCount + (this.hasInlineError() ? 1 : 0)
  }

  /** Includes the optional inline error item and this parent's single footer. */
  private contentItemCount(): number {
    return this.normalizedLeadingItemCount() + this.galleries.length + 1
  }

  private fullRowContentIndexes(): number[] {
    const indexes: number[] = []
    const leading: number = this.normalizedLeadingItemCount()
    for (let index: number = 0; index < leading; index += 1) {
      indexes.push(index)
    }
    indexes.push(this.contentItemCount() - 1)
    return indexes
  }

  private requestRetry(): void {
    if (this.onRetry) {
      this.onRetry()
    }
  }

  private requestLoadMore(): void {
    if (this.onLoadMore) {
      this.onLoadMore()
    }
  }

  private requestRetryLoadMore(): void {
    if (this.onRetryLoadMore) {
      this.onRetryLoadMore()
      return
    }
    this.requestLoadMore()
  }

  private openGallery(galleryId: number, seed?: NhGallerySummary): void {
    if (galleryId > 0 && this.onOpenGallery) {
      this.onOpenGallery(galleryId, seed)
    }
  }

  /** List indexes are already normalized by PullRefreshListScaffold. */
  private onListVisibleRange(end: number): void {
    this.onGalleryVisibleRange(end - this.normalizedLeadingItemCount())
  }

  /** Grid/WaterFlow indexes include their shared top-reserve item at index zero. */
  private onSurfaceVisibleRange(end: number): void {
    this.onGalleryVisibleRange(end - 1 - this.normalizedLeadingItemCount())
  }

  private onGalleryVisibleRange(galleryEnd: number): void {
    if (this.galleries.length === 0 || galleryEnd < this.galleries.length - 1) {
      return
    }
    this.requestLoadMore()
  }

  @Builder
  private InlineError() {
    if (this.hasInlineError()) {
      InlineRetryNotice({
        message: this.errorMessage,
        onRetry: (): void => {
          this.requestRetry()
        },
      })
    }
  }

  @Builder
  private EmptyLeadingContent() {}

  @Builder
  private CollectionFooter() {
    LoadingFooter({
      isLoading: this.isLoadingMore,
      isError: this.loadMoreErrorMessage.length > 0,
      canLoadMore: !this.isRefreshing && this.canLoadMore && !this.isLoadingMore && this.loadMoreErrorMessage.length === 0,
      isComplete: this.isComplete(),
      loadingText: this.footerLoadingText,
      errorMessage: this.loadMoreErrorMessage,
      availableText: this.footerAvailableText,
      completeText: this.footerCompleteText,
      // Page-one refresh may replace both the cursor and item count. Avoid
      // showing stale page progress while the caller still owns that request.
      idleText: this.isRefreshing ? '' : this.footerIdleText,
      retryLabel: this.footerRetryLabel,
      onRetry: (): void => {
        this.requestRetryLoadMore()
      },
      onLoadMore: (): void => {
        this.requestLoadMore()
      },
    })
  }

  private isComplete(): boolean {
    return !this.isRefreshing && !this.canLoadMore && !this.isLoadingMore && this.loadMoreErrorMessage.length === 0
  }

  @Builder
  private ListCards() {
    this.leadingContent()
    this.InlineError()
    ForEach(this.galleries, (gallery: NhGallerySummary): void => {
      ListItem() {
        if (this.effectivePresentation() === NhBrowsePresentation.LIST) {
          GalleryMediumCard({
            gallery: gallery,
            selected: this.isGallerySelected(gallery),
            listContentWidth: this.listContentWidth,
            onOpen: (galleryId: number): void => {
              this.openGallery(gallery.id, gallery)
            },
          })
        } else {
          GalleryListItem({
            gallery: gallery,
            selected: this.isGallerySelected(gallery),
            onOpen: (galleryId: number): void => {
              this.openGallery(gallery.id, gallery)
            },
          })
        }
      }
    }, (gallery: NhGallerySummary): string => gallery.id.toString())
    ListItem() {
      this.CollectionFooter()
    }
  }

  @Builder
  private GridCards() {
    this.leadingContent()
    if (this.hasInlineError()) {
      GridItem() {
        this.InlineError()
      }
    }
    ForEach(this.galleries, (gallery: NhGallerySummary): void => {
      GridItem() {
        GalleryGridCard({
          gallery: gallery,
          selected: this.isGallerySelected(gallery),
          onOpen: (galleryId: number): void => {
            this.openGallery(gallery.id, gallery)
          },
        })
      }
    }, (gallery: NhGallerySummary): string => gallery.id.toString())
    GridItem() {
      this.CollectionFooter()
    }
  }

  @Builder
  private WaterfallCards(mode: NhBrowsePresentation) {
    this.leadingContent()
    if (this.hasInlineError()) {
      FlowItem() {
        this.InlineError()
      }
    }
    ForEach(this.galleries, (gallery: NhGallerySummary): void => {
      FlowItem() {
        if (mode === NhBrowsePresentation.WATERFALL) {
          GalleryWaterfallCard({
            gallery: gallery,
            selected: this.isGallerySelected(gallery),
            onOpen: (galleryId: number): void => {
              this.openGallery(gallery.id, gallery)
            },
          }).reuse({ reuseId: () => galleryWaterfallReuseId(gallery) })
        } else if (mode === NhBrowsePresentation.WATERFALL_COMPACT) {
          GalleryWaterfallCompactCard({
            gallery: gallery,
            selected: this.isGallerySelected(gallery),
            onOpen: (galleryId: number): void => {
              this.openGallery(gallery.id, gallery)
            },
          }).reuse({ reuseId: () => galleryWaterfallCompactReuseId(gallery) })
        } else {
          GalleryCoverWallCard({
            gallery: gallery,
            selected: this.isGallerySelected(gallery),
            onOpen: (galleryId: number): void => {
              this.openGallery(gallery.id, gallery)
            },
          }).reuse({ reuseId: () => galleryCoverWallReuseId(gallery) })
        }
      }
      .width('100%')
    }, (gallery: NhGallerySummary): string => gallery.id.toString())
    FlowItem() {
      this.CollectionFooter()
    }
  }

  @Builder
  private CollectionContent() {
    if (this.effectivePresentation() === NhBrowsePresentation.WATERFALL) {
      PullRefreshWaterFlowScaffold({
        scroller: this.scroller,
        controller: this.controller,
        refreshEnabled: this.refreshEnabled,
        minColumnWidth: ThemeTokens.GALLERY_WATERFALL_MIN_WIDTH,
        densityMode: NhBrowsePresentation.WATERFALL,
        densityEnabled: true,
        gap: ThemeTokens.GALLERY_GRID_GAP,
        horizontalPadding: ThemeTokens.GALLERY_GRID_GAP,
        topPadding: this.topPadding,
        bottomPadding: this.bottomPadding,
        contentItemCount: this.contentItemCount(),
        fullRowContentIndexes: this.fullRowContentIndexes(),
        backToTop: this.backToTop,
        onRefresh: async (): Promise<void> => {
          if (this.onRefresh) {
            await this.onRefresh()
          }
        },
        onReachEnd: (): void => {
          this.requestLoadMore()
        },
        onScrollIndex: (_start: number, end: number): void => {
          this.onSurfaceVisibleRange(end)
        },
        onDidScroll: (offset: number, state: ScrollState): void => {
          if (this.onDidScroll) {
            this.onDidScroll(offset, state)
          }
        },
        onUserScroll: (): void => {
          if (this.onUserScroll) {
            this.onUserScroll()
          }
        },
      }) {
        this.WaterfallCards(NhBrowsePresentation.WATERFALL)
      }
    } else if (this.effectivePresentation() === NhBrowsePresentation.WATERFALL_COMPACT) {
      PullRefreshWaterFlowScaffold({
        scroller: this.scroller,
        controller: this.controller,
        refreshEnabled: this.refreshEnabled,
        minColumnWidth: ThemeTokens.GALLERY_WATERFALL_COMPACT_MIN_WIDTH,
        densityMode: NhBrowsePresentation.WATERFALL_COMPACT,
        densityEnabled: true,
        gap: ThemeTokens.GALLERY_GRID_GAP,
        horizontalPadding: ThemeTokens.GALLERY_GRID_GAP,
        topPadding: this.topPadding,
        bottomPadding: this.bottomPadding,
        contentItemCount: this.contentItemCount(),
        fullRowContentIndexes: this.fullRowContentIndexes(),
        backToTop: this.backToTop,
        onRefresh: async (): Promise<void> => {
          if (this.onRefresh) {
            await this.onRefresh()
          }
        },
        onReachEnd: (): void => {
          this.requestLoadMore()
        },
        onScrollIndex: (_start: number, end: number): void => {
          this.onSurfaceVisibleRange(end)
        },
        onDidScroll: (offset: number, state: ScrollState): void => {
          if (this.onDidScroll) {
            this.onDidScroll(offset, state)
          }
        },
        onUserScroll: (): void => {
          if (this.onUserScroll) {
            this.onUserScroll()
          }
        },
      }) {
        this.WaterfallCards(NhBrowsePresentation.WATERFALL_COMPACT)
      }
    } else if (this.effectivePresentation() === NhBrowsePresentation.COVER_WALL) {
      PullRefreshWaterFlowScaffold({
        scroller: this.scroller,
        controller: this.controller,
        refreshEnabled: this.refreshEnabled,
        minColumnWidth: ThemeTokens.GALLERY_COVER_WALL_MIN_WIDTH,
        densityMode: NhBrowsePresentation.COVER_WALL,
        densityEnabled: true,
        gap: ThemeTokens.GALLERY_GRID_GAP,
        horizontalPadding: ThemeTokens.GALLERY_GRID_GAP,
        topPadding: this.topPadding,
        bottomPadding: this.bottomPadding,
        contentItemCount: this.contentItemCount(),
        fullRowContentIndexes: this.fullRowContentIndexes(),
        backToTop: this.backToTop,
        onRefresh: async (): Promise<void> => {
          if (this.onRefresh) {
            await this.onRefresh()
          }
        },
        onReachEnd: (): void => {
          this.requestLoadMore()
        },
        onScrollIndex: (_start: number, end: number): void => {
          this.onSurfaceVisibleRange(end)
        },
        onDidScroll: (offset: number, state: ScrollState): void => {
          if (this.onDidScroll) {
            this.onDidScroll(offset, state)
          }
        },
        onUserScroll: (): void => {
          if (this.onUserScroll) {
            this.onUserScroll()
          }
        },
      }) {
        this.WaterfallCards(NhBrowsePresentation.COVER_WALL)
      }
    } else if (this.effectivePresentation() === NhBrowsePresentation.COVER_GRID) {
      PullRefreshGridScaffold({
        scroller: this.scroller,
        controller: this.controller,
        refreshEnabled: this.refreshEnabled,
        minColumnWidth: ThemeTokens.GALLERY_GRID_MIN_WIDTH,
        densityMode: NhBrowsePresentation.COVER_GRID,
        densityEnabled: true,
        gap: ThemeTokens.GALLERY_GRID_GAP,
        horizontalPadding: ThemeTokens.GALLERY_GRID_GAP,
        topPadding: this.topPadding,
        bottomPadding: this.bottomPadding,
        contentItemCount: this.contentItemCount(),
        fullRowContentIndexes: this.fullRowContentIndexes(),
        backToTop: this.backToTop,
        onRefresh: async (): Promise<void> => {
          if (this.onRefresh) {
            await this.onRefresh()
          }
        },
        onReachEnd: (): void => {
          this.requestLoadMore()
        },
        onScrollIndex: (_start: number, end: number): void => {
          this.onSurfaceVisibleRange(end)
        },
        onDidScroll: (offset: number, state: ScrollState): void => {
          if (this.onDidScroll) {
            this.onDidScroll(offset, state)
          }
        },
        onUserScroll: (): void => {
          if (this.onUserScroll) {
            this.onUserScroll()
          }
        },
      }) {
        this.GridCards()
      }
    } else {
      PullRefreshListScaffold({
        scroller: this.scroller,
        controller: this.controller,
        refreshEnabled: this.refreshEnabled,
        listSpace: this.effectivePresentation() === NhBrowsePresentation.LIST
          ? ThemeTokens.SPACE_SM
          : 0,
        topPadding: this.topPadding,
        bottomPadding: this.bottomPadding,
        itemCount: this.contentItemCount(),
        normalizeContentIndexes: true,
        backToTop: this.backToTop,
        onRefresh: async (): Promise<void> => {
          if (this.onRefresh) {
            await this.onRefresh()
          }
        },
        onReachEnd: (): void => {
          this.requestLoadMore()
        },
        onScrollIndex: (_start: number, end: number, _center: number): void => {
          this.onListVisibleRange(end)
        },
        onContentWidth: (contentWidth: number): void => {
          this.listContentWidth = contentWidth
        },
        onDidScroll: (offset: number, state: ScrollState): void => {
          if (this.onDidScroll) {
            this.onDidScroll(offset, state)
          }
        },
        onUserScroll: (): void => {
          if (this.onUserScroll) {
            this.onUserScroll()
          }
        },
      }) {
        this.ListCards()
      }
    }
  }

  build() {
    Column() {
      if (this.isInitialLoading && this.galleries.length === 0) {
        PageLoadingState({ text: this.loadingMessage })
      } else if (this.errorMessage.length > 0 && this.galleries.length === 0) {
        PageErrorState({
          message: this.errorMessage,
          onRetry: (): void => {
            this.requestRetry()
          },
        })
      } else if (this.galleries.length === 0) {
        PageEmptyState({ message: this.emptyMessage })
      } else {
        this.CollectionContent()
      }
    }
    .width('100%')
    .height('100%')
  }
}
