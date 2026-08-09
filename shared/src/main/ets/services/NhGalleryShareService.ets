import { common } from '@kit.AbilityKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { systemShare } from '@kit.ShareKit'
import { NhBrowserSessionBoundary } from './NhBrowserSessionBoundary'

/**
 * Privacy-minimal sender for an explicitly requested public gallery link.
 *
 * The share payload contains only a canonical HTTPS URL derived from the
 * numeric gallery id. It does not inspect ArkWeb state, add a title/thumbnail,
 * or configure a target-app allow-list, so it needs no browser credentials or
 * restricted sharing permission.
 */
export class NhGalleryShareService {
  static async shareCanonicalGallery(context: common.UIAbilityContext, galleryId: number): Promise<boolean> {
    try {
      const sharedData: systemShare.SharedData = new systemShare.SharedData({
        utd: utd.UniformDataType.HYPERLINK,
        content: NhBrowserSessionBoundary.canonicalGalleryUrl(galleryId),
      })
      const controller: systemShare.ShareController = new systemShare.ShareController(sharedData)
      await controller.show(context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE,
      })
      return true
    } catch (_error) {
      return false
    }
  }
}
