import { AppStorageV2 } from '@kit.ArkUI'

/**
 * The account's cloud tag-blacklist ids, restored from the durable local
 * snapshot and refreshed from the authenticated v2 endpoint. The ids share
 * the catalog id space with gallery `tag_ids`, so list surfaces can enforce
 * the site's own blacklist locally (ErosN semantics) without depending on a
 * per-gallery server marker.
 */
@ObservedV2
export class NhCloudBlacklistState {
  @Trace ids: number[] = []
  @Trace revision: number = 0
  @Trace isRestored: boolean = false
}

const CLOUD_BLACKLIST_STATE_KEY: string = 'nextn_cloud_blacklist'

export function connectCloudBlacklist(): NhCloudBlacklistState {
  return AppStorageV2.connect(
    NhCloudBlacklistState,
    CLOUD_BLACKLIST_STATE_KEY,
    (): NhCloudBlacklistState => new NhCloudBlacklistState(),
  )!
}
