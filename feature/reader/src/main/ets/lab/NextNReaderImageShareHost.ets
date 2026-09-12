import { common } from '@kit.AbilityKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { systemShare } from '@kit.ShareKit'
import {
  ReaderCancellation,
  ReaderImageShareHost,
  ReaderImageSharePresentation,
  ReaderImageShareTarget,
} from '@reader-kit/core'
import { ReaderSystemSharePresentation } from '@reader-kit/ui'
import { NhBrowserSessionBoundary } from 'shared'

class NextNReaderFallbackSharePresentation implements ReaderImageSharePresentation {
  private primary: ReaderImageSharePresentation
  private fallback: () => ReaderImageSharePresentation
  private fallbackPresentation: ReaderImageSharePresentation | null = null
  private primaryReleased: boolean = false

  constructor(primary: ReaderImageSharePresentation, fallback: () => ReaderImageSharePresentation) {
    this.primary = primary
    this.fallback = fallback
  }

  async present(): Promise<void> {
    try {
      await this.primary.present()
    } catch (_error) {
      this.primary.release()
      this.primaryReleased = true
      console.info('[NextNReaderShare] primary_present_failed fallback=gallery')
      this.fallbackPresentation = this.fallback()
      await this.fallbackPresentation.present()
    }
  }

  release(): void {
    if (!this.primaryReleased) this.primary.release()
    this.fallbackPresentation?.release()
  }
}

/** Keeps NextN's canonical-gallery fallback outside the neutral reader-kit controller. */
export class NextNReaderImageShareHost implements ReaderImageShareHost {
  private context: common.UIAbilityContext
  private primary: ReaderImageShareHost

  constructor(context: common.UIAbilityContext, primary: ReaderImageShareHost) {
    this.context = context
    this.primary = primary
  }

  private fallback(target: ReaderImageShareTarget): ReaderImageSharePresentation {
    const galleryId = Number(target.unit.key.work)
    if (!Number.isSafeInteger(galleryId) || galleryId <= 0) throw new Error('invalid_nh_share_gallery')
    const data = new systemShare.SharedData({
      utd: utd.UniformDataType.HYPERLINK,
      content: NhBrowserSessionBoundary.canonicalGalleryUrl(galleryId),
    })
    return new ReaderSystemSharePresentation(this.context, data, {
      selectionMode: systemShare.SelectionMode.SINGLE,
      previewMode: systemShare.SharePreviewMode.DEFAULT,
    })
  }

  async prepare(
    target: ReaderImageShareTarget,
    cancellation: ReaderCancellation,
  ): Promise<ReaderImageSharePresentation> {
    let primary: ReaderImageSharePresentation | null = null
    try {
      primary = await this.primary.prepare(target, cancellation)
      cancellation.check()
      const fallbackTarget = target.copy()
      return new NextNReaderFallbackSharePresentation(primary,
        (): ReaderImageSharePresentation => this.fallback(fallbackTarget))
    } catch (error) {
      if (cancellation.isCancelled()) {
        primary?.release()
        throw error as Error
      }
      console.info('[NextNReaderShare] primary_prepare_failed fallback=gallery')
      return this.fallback(target)
    }
  }
}
