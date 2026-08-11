import { common } from '@kit.AbilityKit'
import { CommentTranslationService } from './CommentTranslationService'

/**
 * Gallery-title boundary over the existing private text translation pipeline.
 * It deliberately has no independent source, cache, or request policy.
 */
export class GalleryTitleTranslationService {
  static translate(context: common.UIAbilityContext, sourceTitle: string): Promise<string> {
    return CommentTranslationService.translate(context, sourceTitle)
  }
}
