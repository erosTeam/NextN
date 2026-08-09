import { AppStorageV2 } from '@kit.ArkUI'

/** Persisted user intent for a future adaptive large-screen shell. */
export const TABLET_LAYOUT_AUTO: string = 'auto'
export const TABLET_LAYOUT_OFF: string = 'off'
export const TABLET_LAYOUT_LANDSCAPE_ONLY: string = 'landscapeOnly'

@ObservedV2
export class TabletLayoutState {
  @Trace mode: string = TABLET_LAYOUT_AUTO
}

const TABLET_LAYOUT_STATE_KEY: string = 'nextn_tablet_layout'

/** Returns the single reactive tablet-layout policy shared by future consumers. */
export function connectTabletLayout(): TabletLayoutState {
  return AppStorageV2.connect(
    TabletLayoutState,
    TABLET_LAYOUT_STATE_KEY,
    () => new TabletLayoutState(),
  )!
}
