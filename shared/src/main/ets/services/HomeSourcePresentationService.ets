import { common } from '@kit.AbilityKit'
import { NhBrowsePresentation } from '../model/NhBrowsePresentation'
import { HomeSourcePresentationRepository } from '../storage/HomeSourcePresentationRepository'

/** UI-facing boundary for Home-only source overrides; it never touches a gallery request. */
export class HomeSourcePresentationService {
  static restore(context: common.UIAbilityContext): Promise<void> {
    return HomeSourcePresentationRepository.restore(context)
  }

  static setOverride(
    context: common.UIAbilityContext,
    sourceKey: string,
    override: NhBrowsePresentation | null,
  ): Promise<void> {
    return HomeSourcePresentationRepository.save(context, sourceKey, override)
  }
}
