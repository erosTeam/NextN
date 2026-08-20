import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { NhBrowsePresentation } from '../model/NhBrowsePresentation'
import { connectBrowsePresentation } from '../state/BrowsePresentationState'
import { clampGalleryColumnWidth, supportsGalleryColumnDensity } from '../utils/GalleryColumns'
import { LocalDataStore } from './LocalDataStore'

const BROWSE_PRESENTATION_KEY: string = 'browse_presentation'
const COVER_GRID_COLUMN_WIDTH_KEY: string = 'browse_presentation_cover_grid_column_width'
const WATERFALL_COLUMN_WIDTH_KEY: string = 'browse_presentation_waterfall_column_width'
const WATERFALL_COMPACT_COLUMN_WIDTH_KEY: string = 'browse_presentation_waterfall_compact_column_width'
const COVER_WALL_COLUMN_WIDTH_KEY: string = 'browse_presentation_cover_wall_column_width'
const THUMBNAIL_COLUMN_WIDTH_KEY: string = 'browse_presentation_thumbnail_column_width'
const SHOW_GALLERY_TAGS_KEY: string = 'browse_presentation_show_gallery_tags'
const SHOW_TRANSLATED_TAG_LABELS_KEY: string = 'browse_presentation_show_translated_tag_labels'
const LIST_CARD_FIXED_HEIGHT_KEY: string = 'browse_presentation_list_card_fixed_height'
const SQL_SELECT_PRESENTATION: string =
  'SELECT value FROM browse_presentation_settings WHERE key = ? LIMIT 1'
const SQL_UPSERT_PRESENTATION: string =
  'INSERT INTO browse_presentation_settings (key, value) VALUES (?, ?) ' +
  'ON CONFLICT(key) DO UPDATE SET value = excluded.value'

/** One local-only state writer shared by Browse and its Settings destination. */
export class BrowsePresentationRepository {
  private static writeTail: Promise<void> = Promise.resolve()

  static normalize(value: string): NhBrowsePresentation {
    if (value === NhBrowsePresentation.LIST) {
      return NhBrowsePresentation.LIST
    }
    if (value === NhBrowsePresentation.SIMPLE_LIST) {
      return NhBrowsePresentation.SIMPLE_LIST
    }
    if (value === NhBrowsePresentation.COVER_GRID) {
      return NhBrowsePresentation.COVER_GRID
    }
    if (value === NhBrowsePresentation.WATERFALL) {
      return NhBrowsePresentation.WATERFALL
    }
    if (value === NhBrowsePresentation.WATERFALL_COMPACT) {
      return NhBrowsePresentation.WATERFALL_COMPACT
    }
    if (value === NhBrowsePresentation.COVER_WALL) {
      return NhBrowsePresentation.COVER_WALL
    }
    if (value === NhBrowsePresentation.THUMBNAIL) {
      return NhBrowsePresentation.THUMBNAIL
    }
    // Waterfall is the out-of-box view for fresh/unknown persisted values.
    // Every saved mode still resolves above; an installed user's saved
    // preference is never migrated.
    return NhBrowsePresentation.WATERFALL
  }

  static async restore(context: common.UIAbilityContext): Promise<NhBrowsePresentation> {
    try {
      await BrowsePresentationRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      const mode: NhBrowsePresentation = BrowsePresentationRepository.normalize(
        await BrowsePresentationRepository.readValue(store, BROWSE_PRESENTATION_KEY),
      )
      const state = connectBrowsePresentation()
      state.mode = mode
      state.setColumnWidthFor(
        NhBrowsePresentation.COVER_GRID,
        BrowsePresentationRepository.normalizeColumnWidth(
          await BrowsePresentationRepository.readValue(store, COVER_GRID_COLUMN_WIDTH_KEY),
        ),
      )
      state.setColumnWidthFor(
        NhBrowsePresentation.WATERFALL,
        BrowsePresentationRepository.normalizeColumnWidth(
          await BrowsePresentationRepository.readValue(store, WATERFALL_COLUMN_WIDTH_KEY),
        ),
      )
      state.setColumnWidthFor(
        NhBrowsePresentation.WATERFALL_COMPACT,
        BrowsePresentationRepository.normalizeColumnWidth(
          await BrowsePresentationRepository.readValue(store, WATERFALL_COMPACT_COLUMN_WIDTH_KEY),
        ),
      )
      state.setColumnWidthFor(
        NhBrowsePresentation.COVER_WALL,
        BrowsePresentationRepository.normalizeColumnWidth(
          await BrowsePresentationRepository.readValue(store, COVER_WALL_COLUMN_WIDTH_KEY),
        ),
      )
      state.setColumnWidthFor(
        NhBrowsePresentation.THUMBNAIL,
        BrowsePresentationRepository.normalizeColumnWidth(
          await BrowsePresentationRepository.readValue(store, THUMBNAIL_COLUMN_WIDTH_KEY),
        ),
      )
      state.showGalleryTags = BrowsePresentationRepository.normalizeBoolean(
        await BrowsePresentationRepository.readValue(store, SHOW_GALLERY_TAGS_KEY),
        true,
      )
      // Earlier NextN builds always used a resolved dictionary label when one
      // existed. An absent key therefore retains that visible behavior for an
      // installed user, while an explicit saved choice always wins.
      state.showTranslatedTagLabels = BrowsePresentationRepository.normalizeBoolean(
        await BrowsePresentationRepository.readValue(store, SHOW_TRANSLATED_TAG_LABELS_KEY),
        true,
      )
      state.listCardFixedHeight = BrowsePresentationRepository.normalizeBoolean(
        await BrowsePresentationRepository.readValue(store, LIST_CARD_FIXED_HEIGHT_KEY),
        true,
      )
      return mode
    } catch (error) {
      throw (error as Error)
    }
  }

  static save(context: common.UIAbilityContext, mode: NhBrowsePresentation): Promise<void> {
    const normalized: NhBrowsePresentation = BrowsePresentationRepository.normalize(mode)
    connectBrowsePresentation().mode = normalized
    return BrowsePresentationRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT_PRESENTATION, [BROWSE_PRESENTATION_KEY, normalized])
    })
  }

  /** Persist only the final local density value; pinch updates stay in memory. */
  static saveColumnWidth(
    context: common.UIAbilityContext,
    mode: NhBrowsePresentation,
    width: number,
  ): Promise<void> {
    if (!supportsGalleryColumnDensity(mode)) {
      return Promise.resolve()
    }
    const normalized: number = clampGalleryColumnWidth(width)
    connectBrowsePresentation().setColumnWidthFor(mode, normalized)
    const key: string = BrowsePresentationRepository.columnWidthKey(mode)
    return BrowsePresentationRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT_PRESENTATION, [key, normalized.toString()])
    })
  }

  static saveShowGalleryTags(context: common.UIAbilityContext, value: boolean): Promise<void> {
    connectBrowsePresentation().showGalleryTags = value
    return BrowsePresentationRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT_PRESENTATION, [SHOW_GALLERY_TAGS_KEY, value ? '1' : '0'])
    })
  }

  static saveShowTranslatedTagLabels(context: common.UIAbilityContext, value: boolean): Promise<void> {
    connectBrowsePresentation().showTranslatedTagLabels = value
    return BrowsePresentationRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT_PRESENTATION, [SHOW_TRANSLATED_TAG_LABELS_KEY, value ? '1' : '0'])
    })
  }

  static saveListCardFixedHeight(context: common.UIAbilityContext, value: boolean): Promise<void> {
    connectBrowsePresentation().listCardFixedHeight = value
    return BrowsePresentationRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT_PRESENTATION, [LIST_CARD_FIXED_HEIGHT_KEY, value ? '1' : '0'])
    })
  }

  private static async readValue(store: relationalStore.RdbStore, key: string): Promise<string> {
    let rows: relationalStore.ResultSet | null = null
    try {
      rows = await store.querySql(SQL_SELECT_PRESENTATION, [key])
      if (!rows.goToNextRow()) {
        return ''
      }
      const column: number = rows.getColumnIndex('value')
      return rows.isColumnNull(column) ? '' : rows.getString(column)
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (_error) {}
      }
    }
  }

  private static normalizeColumnWidth(value: string): number {
    const parsed: number = Number.parseFloat(value)
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return 0
    }
    return clampGalleryColumnWidth(parsed)
  }

  private static normalizeBoolean(value: string, fallback: boolean = false): boolean {
    const normalized: string = value.trim().toLowerCase()
    if (normalized === '1' || normalized === 'true') {
      return true
    }
    if (normalized === '0' || normalized === 'false') {
      return false
    }
    return fallback
  }

  private static columnWidthKey(mode: NhBrowsePresentation): string {
    if (mode === NhBrowsePresentation.COVER_GRID) {
      return COVER_GRID_COLUMN_WIDTH_KEY
    }
    if (mode === NhBrowsePresentation.WATERFALL) {
      return WATERFALL_COLUMN_WIDTH_KEY
    }
    if (mode === NhBrowsePresentation.WATERFALL_COMPACT) {
      return WATERFALL_COMPACT_COLUMN_WIDTH_KEY
    }
    if (mode === NhBrowsePresentation.COVER_WALL) {
      return COVER_WALL_COLUMN_WIDTH_KEY
    }
    if (mode === NhBrowsePresentation.THUMBNAIL) {
      return THUMBNAIL_COLUMN_WIDTH_KEY
    }
    return ''
  }

  private static enqueueWrite(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = BrowsePresentationRepository.writeTail.then(
      (): Promise<void> => operation(),
      (): Promise<void> => operation(),
    )
    BrowsePresentationRepository.writeTail = queued.catch((): void => {})
    return queued
  }

  /** Backup export: whole browse_presentation_settings key-value table. */
  static async exportForBackup(context: common.UIAbilityContext): Promise<Record<string, string>> {
    const out: Record<string, string> = {}
    let rows: relationalStore.ResultSet | null = null
    try {
      await BrowsePresentationRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql('SELECT key, value FROM browse_presentation_settings')
      while (rows.goToNextRow()) {
        const keyColumn: number = rows.getColumnIndex('key')
        const valueColumn: number = rows.getColumnIndex('value')
        if (!rows.isColumnNull(keyColumn) && !rows.isColumnNull(valueColumn)) {
          out[rows.getString(keyColumn)] = rows.getString(valueColumn)
        }
      }
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (_error) {}
      }
    }
    return out
  }

  /** Backup restore: authoritative replacement of the browse_presentation_settings table. */
  static async restoreBackup(context: common.UIAbilityContext, values: Record<string, string>): Promise<void> {
    await BrowsePresentationRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql('DELETE FROM browse_presentation_settings')
      const keys: string[] = Object.keys(values)
      for (let i: number = 0; i < keys.length; i++) {
        await store.executeSql(SQL_UPSERT_PRESENTATION, [keys[i], values[keys[i]]])
      }
    })
  }
}
