import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { connectReadButtonStyle, READ_BUTTON_STYLE_FILLED, READ_BUTTON_STYLE_HDS } from '../state/ReadButtonStyleState'

const LAYOUT_STORE: string = 'nextn_layout'
const READ_BUTTON_STYLE_KEY: string = 'read_button_style'

/** Durable NextE-compatible visual choice; it never changes Reader routing or data. */
export class ReadButtonStyleSettings {
  static readonly STYLE_FILLED: string = READ_BUTTON_STYLE_FILLED
  static readonly STYLE_HDS: string = READ_BUTTON_STYLE_HDS

  static normalize(style: string): string {
    return style === READ_BUTTON_STYLE_HDS ? READ_BUTTON_STYLE_HDS : READ_BUTTON_STYLE_FILLED
  }

  static apply(style: string): void {
    connectReadButtonStyle().style = ReadButtonStyleSettings.normalize(style)
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    let style = READ_BUTTON_STYLE_FILLED
    try {
      const store = await preferences.getPreferences(context, LAYOUT_STORE)
      style = store.getSync(READ_BUTTON_STYLE_KEY, READ_BUTTON_STYLE_FILLED) as string
    } catch (_error) {}
    ReadButtonStyleSettings.apply(style)
  }

  static async save(context: common.UIAbilityContext, style: string): Promise<void> {
    const normalized = ReadButtonStyleSettings.normalize(style)
    ReadButtonStyleSettings.apply(normalized)
    try {
      const store = await preferences.getPreferences(context, LAYOUT_STORE)
      store.putSync(READ_BUTTON_STYLE_KEY, normalized)
      store.flushSync()
    } catch (_error) {}
  }
}
