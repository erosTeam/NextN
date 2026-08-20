import { AppStorageV2 } from '@kit.ArkUI'
import { NhHomeSubtabProfile } from '../model/NhHomeSubtabProfile'

@ObservedV2
export class HomeSubtabState {
  @Trace profiles: NhHomeSubtabProfile[] = []
  @Trace selectedUuid: string = ''
  @Trace restored: boolean = false

  find(uuid: string): NhHomeSubtabProfile | null {
    for (let index: number = 0; index < this.profiles.length; index++) {
      if (this.profiles[index].uuid === uuid) {
        return this.profiles[index]
      }
    }
    return null
  }

  visibleProfiles(): NhHomeSubtabProfile[] {
    const visible: NhHomeSubtabProfile[] = []
    this.profiles.forEach((profile: NhHomeSubtabProfile): void => {
      if (!profile.hidden) {
        visible.push(profile)
      }
    })
    return visible
  }
}

const HOME_SUBTAB_STATE_KEY: string = 'nextn_home_subtabs'

export function connectHomeSubtabs(): HomeSubtabState {
  return AppStorageV2.connect(
    HomeSubtabState,
    HOME_SUBTAB_STATE_KEY,
    (): HomeSubtabState => new HomeSubtabState(),
  )!
}
