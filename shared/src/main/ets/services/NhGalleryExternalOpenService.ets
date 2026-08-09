import { common } from '@kit.AbilityKit'
import { NhBrowserSessionBoundary } from './NhBrowserSessionBoundary'

/**
 * Hands an explicitly requested public gallery link to HarmonyOS' external
 * link resolver. The only value leaving NextN is the canonical HTTPS URL
 * derived from a verified numeric id; ArkWeb navigation and browser state are
 * deliberately not inputs to this operation.
 *
 * `openLink` resolves the URL through the system's App/Deep Link handling. It
 * is not an App Linking declaration for NextN and therefore makes no promise
 * that an external URL can return to this application.
 */
export class NhGalleryExternalOpenService {
  static async openCanonicalGallery(context: common.UIAbilityContext, galleryId: number): Promise<boolean> {
    try {
      await context.openLink(NhBrowserSessionBoundary.canonicalGalleryUrl(galleryId))
      return true
    } catch (_error) {
      return false
    }
  }
}
