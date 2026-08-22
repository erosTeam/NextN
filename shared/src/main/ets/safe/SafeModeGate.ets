import { connectSafeMode } from '../state/SafeModeState'

export class SafeModeGate {
  static restricted(): boolean {
    return connectSafeMode().restricted()
  }

  static routeAllowed(name: string): boolean {
    if (!SafeModeGate.restricted()) {
      return true
    }
    if (name === 'search' ||
      name === 'homeSubtabManager' ||
      name === 'homeSubtabEdit' ||
      name === 'popular' ||
      name === 'galleryWeb' ||
      name === 'comments' ||
      name === 'browserSession' ||
      name === 'account' ||
      name === 'syncSettings' ||
      name === 'webDavSyncSettings' ||
      name === 'history' ||
      name === 'llmSourceManager' ||
      name === 'llmSourceDetail' ||
      name === 'mangaRenderingService' ||
      name === 'tagTranslationSettings' ||
      name === 'commentTranslationSettings' ||
      name === 'comicTranslationSettings' ||
      name === 'toriiWholePageLiveEvaluation') {
      return false
    }
    return true
  }
}
