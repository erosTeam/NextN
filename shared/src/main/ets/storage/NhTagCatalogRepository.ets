import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { NhTag } from '../model/NhGallery'
import { LocalDataStore } from './LocalDataStore'

const LOOKUP_BATCH_SIZE: number = 200
const SQL_SELECT_PREFIX: string =
  'SELECT id, type, name, count, updated_at FROM nh_tag_catalog WHERE id IN ('
const SQL_UPSERT: string =
  'INSERT INTO nh_tag_catalog (id, type, name, count, updated_at) VALUES (?, ?, ?, ?, ?) ' +
  'ON CONFLICT(id) DO UPDATE SET type = excluded.type, name = excluded.name, ' +
  'count = excluded.count, updated_at = excluded.updated_at'
const SQL_INSERT_DETAIL_FALLBACK: string =
  'INSERT INTO nh_tag_catalog (id, type, name, count, updated_at) VALUES (?, ?, ?, ?, 0) ' +
  'ON CONFLICT(id) DO NOTHING'

export class NhTagCatalogResolution {
  tags: Map<number, NhTag> = new Map<number, NhTag>()
  detailFallbackIds: Set<number> = new Set<number>()
}

/**
 * Private durable cache for public NH tag records. It never owns a gallery
 * request, account state, translation preference, or user-generated data.
 */
export class NhTagCatalogRepository {
  static async findByIds(
    context: common.UIAbilityContext,
    rawIds: number[],
  ): Promise<Map<number, NhTag>> {
    return (await NhTagCatalogRepository.resolveByIds(context, rawIds)).tags
  }

  /**
   * Detail-supplied fallback names stay renderable, but the next id-only list
   * may replace them with an ordinary catalog response.
   */
  static async resolveByIds(
    context: common.UIAbilityContext,
    rawIds: number[],
  ): Promise<NhTagCatalogResolution> {
    const ids: number[] = NhTagCatalogRepository.uniqueIds(rawIds)
    const result: NhTagCatalogResolution = new NhTagCatalogResolution()
    if (ids.length === 0) {
      return result
    }
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    for (let start: number = 0; start < ids.length; start += LOOKUP_BATCH_SIZE) {
      const batch: number[] = ids.slice(start, start + LOOKUP_BATCH_SIZE)
      await NhTagCatalogRepository.lookupBatch(store, batch, result)
    }
    return result
  }

  static async upsert(
    context: common.UIAbilityContext,
    rawTags: NhTag[],
  ): Promise<void> {
    const tags: NhTag[] = NhTagCatalogRepository.usableTags(rawTags)
    if (tags.length === 0) {
      return
    }
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    let transactionOpen: boolean = false
    try {
      store.beginTransaction()
      transactionOpen = true
      const updatedAt: number = Date.now()
      for (let index: number = 0; index < tags.length; index++) {
        const tag: NhTag = tags[index]
        await store.executeSql(SQL_UPSERT, [tag.id, tag.type, tag.name, tag.count, updatedAt])
      }
      store.commit()
      transactionOpen = false
    } catch (error) {
      if (transactionOpen) {
        store.rollBack()
      }
      throw error as Error
    }
  }

  /**
   * Learns records supplied by an optional cached Detail response as fallback
   * names, without replacing a catalog item learned from a collection request.
   */
  static async insertDetailFallbacks(
    context: common.UIAbilityContext,
    rawTags: NhTag[],
  ): Promise<void> {
    const tags: NhTag[] = NhTagCatalogRepository.usableTags(rawTags)
    if (tags.length === 0) {
      return
    }
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    let transactionOpen: boolean = false
    try {
      store.beginTransaction()
      transactionOpen = true
      for (let index: number = 0; index < tags.length; index++) {
        const tag: NhTag = tags[index]
        await store.executeSql(SQL_INSERT_DETAIL_FALLBACK, [tag.id, tag.type, tag.name, tag.count])
      }
      store.commit()
      transactionOpen = false
    } catch (error) {
      if (transactionOpen) {
        store.rollBack()
      }
      throw error as Error
    }
  }

  private static async lookupBatch(
    store: relationalStore.RdbStore,
    ids: number[],
    result: NhTagCatalogResolution,
  ): Promise<void> {
    if (ids.length === 0) {
      return
    }
    const placeholders: string[] = []
    const args: relationalStore.ValueType[] = []
    for (let index: number = 0; index < ids.length; index++) {
      placeholders.push('?')
      args.push(ids[index])
    }
    let rows: relationalStore.ResultSet | null = null
    try {
      rows = await store.querySql(`${SQL_SELECT_PREFIX}${placeholders.join(',')})`, args)
      while (rows.goToNextRow()) {
        const tag: NhTag = new NhTag()
        tag.id = NhTagCatalogRepository.numberColumn(rows, 'id')
        tag.type = NhTagCatalogRepository.stringColumn(rows, 'type')
        tag.name = NhTagCatalogRepository.stringColumn(rows, 'name')
        tag.count = NhTagCatalogRepository.numberColumn(rows, 'count')
        if (tag.id > 0 && tag.name.length > 0) {
          result.tags.set(tag.id, tag)
          if (NhTagCatalogRepository.numberColumn(rows, 'updated_at') <= 0) {
            result.detailFallbackIds.add(tag.id)
          }
        }
      }
    } finally {
      if (rows !== null) {
        rows.close()
      }
    }
  }

  private static usableTags(rawTags: NhTag[]): NhTag[] {
    const result: NhTag[] = []
    const seen: Set<number> = new Set<number>()
    for (let index: number = 0; index < rawTags.length; index++) {
      const source: NhTag = rawTags[index]
      const id: number = Math.floor(source.id)
      const name: string = source.name.trim()
      if (id <= 0 || name.length === 0 || seen.has(id)) {
        continue
      }
      seen.add(id)
      const tag: NhTag = new NhTag()
      tag.id = id
      tag.type = source.type.trim()
      tag.name = name
      tag.count = Math.max(0, Math.floor(source.count))
      result.push(tag)
    }
    return result
  }

  private static uniqueIds(rawIds: number[]): number[] {
    const ids: number[] = []
    const seen: Set<number> = new Set<number>()
    for (let index: number = 0; index < rawIds.length; index++) {
      const id: number = Math.floor(rawIds[index])
      if (id > 0 && !seen.has(id)) {
        seen.add(id)
        ids.push(id)
      }
    }
    return ids
  }

  private static numberColumn(rows: relationalStore.ResultSet, name: string): number {
    const column: number = rows.getColumnIndex(name)
    return column < 0 || rows.isColumnNull(column) ? 0 : rows.getLong(column)
  }

  private static stringColumn(rows: relationalStore.ResultSet, name: string): string {
    const column: number = rows.getColumnIndex(name)
    return column < 0 || rows.isColumnNull(column) ? '' : rows.getString(column)
  }
}
