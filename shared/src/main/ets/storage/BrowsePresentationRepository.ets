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
const SHOW_GALLERY_TAGS_KEY: string = 'browse_presentation_show_gallery_tags'
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
    // `simple_list` is the pre-LIST persisted value. Unknown and empty values
    // retain the old safe fallback instead of introducing a new preference.
    return NhBrowsePresentation.SIMPLE_LIST
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
      state.showGalleryTags = BrowsePresentationRepository.normalizeBoolean(
        await BrowsePresentationRepository.readValue(store, SHOW_GALLERY_TAGS_KEY),
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

  private static normalizeBoolean(value: string): boolean {
    return value === '1' || value.toLowerCase() === 'true'
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
}
