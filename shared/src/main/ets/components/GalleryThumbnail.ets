import { ContentTransitionType } from '@ohos/imageknifepro'
import { ThemeTokens } from '../theme/ThemeTokens'
import { EhImageKnifeImage } from './EhImageKnifeImage'
import {
  connectGalleryCoverRetry,
  GalleryCoverRetryState,
} from '../state/GalleryCoverRetryState'
import {
  EH_IMAGE_PRIORITY_LOW,
  EH_THUMBNAIL_CONNECT_TIMEOUT_MS,
  EH_THUMBNAIL_READ_TIMEOUT_MS,
} from '../services/ImagePipelineTypes'

const THUMBNAIL_MAX_RETRIES: number = 1
const THUMBNAIL_RETRY_DELAY_MS: number = 200
const THUMBNAIL_SETTLE_TIMEOUT_MS: number = 8000
const THUMBNAIL_LOADER_SIZE: number = 22
const THUMBNAIL_ERROR_ICON_SIZE: number = 24

/**
 * One foreground-cover loading contract for every gallery-card presentation.
 *
 * Card-specific geometry, fit, background fills and metadata stay with the
 * card. This leaf owns only the shared request transition and mutually
 * exclusive loading/error placeholder state, matching NextE's EhThumbnail.
 */
@ComponentV2
export struct GalleryThumbnail {
  @Param src: string = ''
  @Param objectFit: ImageFit = ImageFit.Cover
  @Param radius: number = 0
  @Param widthValue: Length = '100%'
  @Param heightValue: Length = '100%'
  @Local loaded: boolean = false
  @Local failed: boolean = false
  @Local reloadToken: number = 0
  @Local coverRetryState: GalleryCoverRetryState = connectGalleryCoverRetry()
  @Event onErrorStateChange: (failed: boolean) => void = (_failed: boolean): void => {}

  @Monitor('src')
  onSourceChanged(): void {
    this.loaded = false
    this.failed = false
    this.onErrorStateChange(false)
  }

  @Monitor('coverRetryState.epoch')
  onCoverRetryRequested(): void {
    if (this.loaded && !this.failed) {
      return
    }
    this.loaded = false
    this.failed = false
    this.onErrorStateChange(false)
    this.reloadToken += 1
  }

  private markLoaded(): void {
    this.loaded = true
    this.failed = false
    this.onErrorStateChange(false)
  }

  private markFailed(): void {
    this.loaded = true
    this.failed = true
    this.onErrorStateChange(true)
  }

  @Builder
  private StateOverlay() {
    if (this.src.length === 0 || this.failed) {
      SymbolGlyph($r('sys.symbol.picture'))
        .fontSize(THUMBNAIL_ERROR_ICON_SIZE)
        .fontColor([ThemeTokens.TEXT_TERTIARY])
    } else if (!this.loaded) {
      LoadingProgress()
        .width(THUMBNAIL_LOADER_SIZE)
        .height(THUMBNAIL_LOADER_SIZE)
        .color(ThemeTokens.TEXT_TERTIARY)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.src.length > 0) {
        EhImageKnifeImage({
          src: this.src,
          widthValue: '100%',
          heightValue: '100%',
          objectFit: this.objectFit,
          radius: this.radius,
          contentTransition: ContentTransitionType.OPACITY,
          priority: EH_IMAGE_PRIORITY_LOW,
          maxRetries: THUMBNAIL_MAX_RETRIES,
          retryDelayMs: THUMBNAIL_RETRY_DELAY_MS,
          settleTimeoutMs: THUMBNAIL_SETTLE_TIMEOUT_MS,
          connectTimeoutMs: EH_THUMBNAIL_CONNECT_TIMEOUT_MS,
          readTimeoutMs: EH_THUMBNAIL_READ_TIMEOUT_MS,
          reloadToken: this.reloadToken,
          onComplete: (): void => {
            this.markLoaded()
          },
          onError: (): void => {
            this.markFailed()
          },
        })
      }
      this.StateOverlay()
    }
    .width(this.widthValue)
    .height(this.heightValue)
  }
}
