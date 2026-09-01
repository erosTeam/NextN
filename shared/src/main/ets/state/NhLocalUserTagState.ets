import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class NhLocalUserTagState {
  @Trace revision: number = 0
  @Trace isRestored: boolean = false
}

const LOCAL_USER_TAG_STATE_KEY: string = 'nextn_local_user_tags'

export function connectLocalUserTags(): NhLocalUserTagState {
  return AppStorageV2.connect(
    NhLocalUserTagState,
    LOCAL_USER_TAG_STATE_KEY,
    (): NhLocalUserTagState => new NhLocalUserTagState(),
  )!
}
