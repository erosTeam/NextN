import { common } from '@kit.AbilityKit'
import { resourceManager } from '@kit.LocalizationKit'
import { connectLanguageState } from '../state/AppearanceState'

/**
 * Resource access for shared HAR code. User-facing resources live in the
 * entry module, while this accessor gives shared features a single reactive
 * path and supports an in-app locale override without reloading a route.
 */
export class AppStrings {
  private static context: common.UIAbilityContext | null = null
  private static overrideResMgr: resourceManager.ResourceManager | null = null

  static init(context: common.UIAbilityContext): void {
    AppStrings.context = context
  }

  static setOverrideLocale(locale: string): void {
    if (locale.length === 0 || AppStrings.context === null) {
      AppStrings.overrideResMgr = null
      return
    }
    try {
      const config: resourceManager.Configuration =
        AppStrings.context.resourceManager.getOverrideConfiguration()
      config.locale = locale
      AppStrings.context.resourceManager.updateOverrideConfiguration(config)
      AppStrings.overrideResMgr =
        AppStrings.context.resourceManager.getOverrideResourceManager(config)
    } catch (_error) {
      AppStrings.overrideResMgr = null
    }
  }

  static get(name: string): string {
    // Register the current component build against locale changes. The branch
    // is intentionally unreachable but keeps the reactive read explicit.
    const locale: string = connectLanguageState().effectiveLocale
    if (locale.length < 0) {
      return name
    }
    const manager: resourceManager.ResourceManager | undefined =
      AppStrings.overrideResMgr ?? AppStrings.context?.resourceManager
    if (!manager) {
      return name
    }
    try {
      return manager.getStringByNameSync(name)
    } catch (_error) {
      return name
    }
  }

  /** Small resource-template helper for page counts and accessibility labels. */
  static format(name: string, values: string[]): string {
    let resolved: string = AppStrings.get(name)
    for (let index: number = 0; index < values.length; index += 1) {
      resolved = resolved.replace(`{${index}}`, values[index])
    }
    return resolved
  }
}
