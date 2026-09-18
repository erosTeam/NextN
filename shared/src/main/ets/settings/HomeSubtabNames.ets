import { AppStrings } from '../i18n/AppStrings'
import {
  HOME_SUBTAB_LATEST_UUID,
  HOME_SUBTAB_POPULAR_UUID,
  HOME_SUBTAB_STARTER_CHINESE_UUID,
  HOME_SUBTAB_STARTER_FAVORITED_UUID,
} from '../model/NhHomeSubtabProfile'

/**
 * Built-in Home SubTab labels are presentation resources, not user text.
 * `AppStrings.get()` returns the key itself when the resource manager is not
 * ready or the key is unknown, so a resolved-or-key value must never be
 * persisted as a name. This module is the single place that maps a reserved
 * uuid to its resource key and refuses an unresolved key as a persisted name.
 */
export class HomeSubtabNames {
  static resourceKey(uuid: string): string {
    if (uuid === HOME_SUBTAB_LATEST_UUID) return 'home_source_latest'
    if (uuid === HOME_SUBTAB_POPULAR_UUID) return 'home_source_popular'
    if (uuid === HOME_SUBTAB_STARTER_CHINESE_UUID) return 'home_subtab_starter_chinese'
    if (uuid === HOME_SUBTAB_STARTER_FAVORITED_UUID) return 'home_subtab_starter_favorited'
    return ''
  }

  /** Resolve a required default label; throw instead of storing the raw key. */
  static defaultName(key: string): string {
    const name: string = AppStrings.get(key)
    if (name.length === 0 || name === key) {
      throw new Error('Home subtab name resource unavailable: ' + key)
    }
    return name
  }

  /** Resolve a default label, returning '' when the resource is not ready. */
  static defaultNameOrEmpty(key: string): string {
    try {
      return HomeSubtabNames.defaultName(key)
    } catch (_error) {
      return ''
    }
  }

  /** A reserved uuid whose stored name still equals its own key must be repaired. */
  static isKeyName(uuid: string, name: string): boolean {
    const key: string = HomeSubtabNames.resourceKey(uuid)
    return key.length > 0 && name === key
  }

  /** Repair a stored name only when it is exactly the reserved uuid's key. */
  static repair(uuid: string, name: string): string {
    if (!HomeSubtabNames.isKeyName(uuid, name)) {
      return name
    }
    const resolved: string = HomeSubtabNames.defaultNameOrEmpty(name)
    return resolved.length > 0 ? resolved : name
  }

  /** New writes must never store an unresolved reserved key as the name. */
  static assertPersistable(uuid: string, name: string): void {
    if (HomeSubtabNames.isKeyName(uuid, name)) {
      throw new Error('Unresolved home subtab name resource: ' + name)
    }
  }
}
