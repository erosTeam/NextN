import { NhTag } from '../model/NhGallery'
import { NhLocalUserTag } from '../model/NhLocalUserTag'

/** Pure render-only lookup and stable colored/plain partition. */
export class NhLocalUserTagPresentation {
  static orderedTags(tags: NhTag[], recordsById: Map<number, NhLocalUserTag>): NhTag[] {
    const colored: NhTag[] = []
    const plain: NhTag[] = []
    for (let index: number = 0; index < tags.length; index++) {
      const tag: NhTag = tags[index]
      if (tag.name.trim().length === 0 && tag.displayName.trim().length === 0) {
        continue
      }
      const record: NhLocalUserTag | undefined = recordsById.get(tag.id)
      if (record !== undefined && record.deletedAt <= 0 && record.colorCode.length > 0) {
        colored.push(tag)
      } else {
        plain.push(tag)
      }
    }
    return colored.concat(plain)
  }

  static colorCode(tagId: number, recordsById: Map<number, NhLocalUserTag>): string {
    const record: NhLocalUserTag | undefined = recordsById.get(tagId)
    return record === undefined || record.deletedAt > 0 ? '' : record.colorCode
  }

  /** Black/white foreground chosen from the custom chip background luminance. */
  static readableTextColor(colorCode: string): string {
    const rgb: number | undefined = NhLocalUserTagPresentation.parseRgb(colorCode)
    if (rgb === undefined) {
      return ''
    }
    const red: number = (rgb >> 16) & 255
    const green: number = (rgb >> 8) & 255
    const blue: number = rgb & 255
    const luminance: number = red * 0.299 + green * 0.587 + blue * 0.114
    return luminance >= 150 ? '#000000' : '#FFFFFF'
  }

  /** NextE compact-card treatment: move a configured color 20% toward white. */
  static compactTextColor(colorCode: string): string {
    const rgb: number | undefined = NhLocalUserTagPresentation.parseRgb(colorCode)
    if (rgb === undefined) {
      return ''
    }
    const red: number = NhLocalUserTagPresentation.lightenChannel((rgb >> 16) & 255)
    const green: number = NhLocalUserTagPresentation.lightenChannel((rgb >> 8) & 255)
    const blue: number = NhLocalUserTagPresentation.lightenChannel(rgb & 255)
    return `#${NhLocalUserTagPresentation.channelHex(red)}` +
      `${NhLocalUserTagPresentation.channelHex(green)}` +
      `${NhLocalUserTagPresentation.channelHex(blue)}`
  }

  private static parseRgb(colorCode: string): number | undefined {
    if (!/^#[0-9A-Fa-f]{6}$/.test(colorCode)) {
      return undefined
    }
    const rgb: number = Number.parseInt(colorCode.substring(1), 16)
    return Number.isNaN(rgb) ? undefined : rgb
  }

  private static lightenChannel(value: number): number {
    return Math.round(value + (255 - value) * 0.2)
  }

  private static channelHex(value: number): string {
    return Math.max(0, Math.min(255, value)).toString(16).toUpperCase().padStart(2, '0')
  }
}
