import { AppStorageV2 } from '@kit.ArkUI'

export const READ_BUTTON_STYLE_FILLED: string = 'filled'
export const READ_BUTTON_STYLE_HDS: string = 'hds'

/** Reactive visual style for Gallery's primary Read action. */
@ObservedV2
export class ReadButtonStyleState {
  @Trace style: string = READ_BUTTON_STYLE_FILLED
}

const READ_BUTTON_STYLE_STATE_KEY: string = 'nextn_read_button_style'

export function connectReadButtonStyle(): ReadButtonStyleState {
  return AppStorageV2.connect(
    ReadButtonStyleState,
    READ_BUTTON_STYLE_STATE_KEY,
    () => new ReadButtonStyleState(),
  )!
}
