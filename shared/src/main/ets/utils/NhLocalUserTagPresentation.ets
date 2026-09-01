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
}
