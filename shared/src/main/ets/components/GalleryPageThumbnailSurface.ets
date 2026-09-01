import { ThemeTokens } from '../theme/ThemeTokens'

/**
 * Shared request/loading/error surface for one gallery page thumbnail.
 *
 * Parents retain geometry, selection, transition identity, labels and navigation. This leaf owns the
 * duplicated image lifecycle so every page-thumbnail presentation keeps an image-sized placeholder
 * behind its loading/error affordance.
 */
@ComponentV2
export struct GalleryPageThumbnailSurface {
  @Param src: string = ''
  @Param objectFit: ImageFit = ImageFit.Cover
  @Param placeholderColor: ResourceColor = ThemeTokens.COVER_PLACEHOLDER
  @Param indicatorColor: ResourceColor = ThemeTokens.TEXT_TERTIARY
  @Param loadingOpacity: number = 1
  @Param errorOpacity: number = 1
  @Param loadingSize: number = 20
  @Param errorIconSize: number = 26
  @Local loaded: boolean = false
  @Local failed: boolean = false

  aboutToAppear(): void {
    this.resetState()
  }

  @Monitor('src')
  onSourceChanged(): void {
    this.resetState()
  }

  private resetState(): void {
    this.loaded = false
    this.failed = false
  }

  @Builder
  private StateOverlay() {
    if (this.src.length === 0 || this.failed) {
      SymbolGlyph($r('sys.symbol.picture'))
        .fontSize(this.errorIconSize)
        .fontColor([this.indicatorColor])
        .opacity(this.errorOpacity)
    } else if (!this.loaded) {
      LoadingProgress()
        .width(this.loadingSize)
        .height(this.loadingSize)
        .color(this.indicatorColor)
        .opacity(this.loadingOpacity)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.src.length > 0 && !this.failed) {
        Image(this.src)
          .width('100%')
          .height('100%')
          .objectFit(this.objectFit)
          .onComplete((): void => {
            this.loaded = true
            this.failed = false
          })
          .onError((): void => {
            this.loaded = true
            this.failed = true
          })
      }
      this.StateOverlay()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.placeholderColor)
  }
}
