import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { NhDownloadTask, NhDownloadTaskStatus } from '../model/NhDownloadTask'
import { LocalDataStore } from './LocalDataStore'

const SQL_SELECT_ALL: string =
  'SELECT gallery_id, media_id, title, thumbnail_url, page_count, page_extensions, completed_page_indexes, storage_directory, completed_pages, status, error_message, created_at, updated_at ' +
  'FROM download_queue ORDER BY updated_at DESC, gallery_id DESC'
const SQL_UPSERT: string =
  'INSERT INTO download_queue (gallery_id, media_id, title, thumbnail_url, page_count, page_extensions, completed_page_indexes, storage_directory, completed_pages, status, error_message, created_at, updated_at) ' +
  'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(gallery_id) DO UPDATE SET ' +
  'media_id = excluded.media_id, title = excluded.title, thumbnail_url = excluded.thumbnail_url, page_count = excluded.page_count, ' +
  'page_extensions = excluded.page_extensions, completed_page_indexes = excluded.completed_page_indexes, ' +
  'storage_directory = excluded.storage_directory, ' +
  'completed_pages = excluded.completed_pages, status = excluded.status, ' +
  'error_message = excluded.error_message, updated_at = excluded.updated_at'
const SQL_DELETE_ONE: string = 'DELETE FROM download_queue WHERE gallery_id = ?'

/** Serial RDB boundary for device-local download task metadata. */
export class DownloadQueueRepository {
  private static writeTail: Promise<void> = Promise.resolve()

  static async loadAll(context: common.UIAbilityContext): Promise<NhDownloadTask[]> {
    const tasks: NhDownloadTask[] = []
    let rows: relationalStore.ResultSet | null = null
    try {
      await DownloadQueueRepository.writeTail
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      rows = await store.querySql(SQL_SELECT_ALL)
      while (rows.goToNextRow()) {
        const task: NhDownloadTask = new NhDownloadTask()
        task.galleryId = DownloadQueueRepository.numberColumn(rows, 'gallery_id')
        task.mediaId = DownloadQueueRepository.stringColumn(rows, 'media_id')
        task.title = DownloadQueueRepository.stringColumn(rows, 'title')
        task.thumbnailUrl = DownloadQueueRepository.stringColumn(rows, 'thumbnail_url')
        task.pageCount = DownloadQueueRepository.numberColumn(rows, 'page_count')
        task.pageExtensions = DownloadQueueRepository.extensions(rows, 'page_extensions')
        const completedIndexesColumn: number = rows.getColumnIndex('completed_page_indexes')
        task.completionJournalPresent = !rows.isColumnNull(completedIndexesColumn)
        task.completedPageIndexes = task.completionJournalPresent
          ? DownloadQueueRepository.completedPageIndexes(rows.getString(completedIndexesColumn), task.pageCount)
          : []
        task.storageDirectory = DownloadQueueRepository.stringColumn(rows, 'storage_directory')
        task.completedPages = DownloadQueueRepository.numberColumn(rows, 'completed_pages')
        task.status = DownloadQueueRepository.normalizedStatus(DownloadQueueRepository.stringColumn(rows, 'status'))
        task.errorMessage = DownloadQueueRepository.stringColumn(rows, 'error_message')
        task.createdAt = DownloadQueueRepository.numberColumn(rows, 'created_at')
        task.updatedAt = DownloadQueueRepository.numberColumn(rows, 'updated_at')
        if (task.galleryId > 0 && task.mediaId.length > 0 && task.pageCount > 0 &&
          task.pageExtensions.length === task.pageCount) {
          task.completedPages = Math.min(task.pageCount, Math.max(0, task.completedPages))
          tasks.push(task)
        }
      }
    } catch (error) {
      throw error as Error
    } finally {
      if (rows !== null) {
        try {
          rows.close()
        } catch (error) {
          throw error as Error
        }
      }
    }
    return tasks
  }

  static save(context: common.UIAbilityContext, task: NhDownloadTask): Promise<void> {
    if (task.galleryId <= 0 || task.mediaId.length === 0 || task.pageCount <= 0 ||
      task.pageExtensions.length !== task.pageCount) {
      return Promise.reject(new Error('Download task is incomplete'))
    }
    const snapshot: NhDownloadTask = task.copy()
    return DownloadQueueRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_UPSERT, [
        snapshot.galleryId,
        snapshot.mediaId,
        snapshot.title,
        snapshot.thumbnailUrl,
        snapshot.pageCount,
        JSON.stringify(snapshot.pageExtensions),
        snapshot.completionJournalPresent ? JSON.stringify(snapshot.completedPageIndexes) : null,
        snapshot.storageDirectory,
        snapshot.completedPages,
        DownloadQueueRepository.normalizedStatus(snapshot.status),
        snapshot.errorMessage,
        snapshot.createdAt,
        snapshot.updatedAt,
      ])
    })
  }

  static remove(context: common.UIAbilityContext, galleryId: number): Promise<void> {
    if (galleryId <= 0) {
      return Promise.resolve()
    }
    return DownloadQueueRepository.enqueueWrite(async (): Promise<void> => {
      const store: relationalStore.RdbStore = await LocalDataStore.open(context)
      await store.executeSql(SQL_DELETE_ONE, [galleryId])
    })
  }

  private static enqueueWrite(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = DownloadQueueRepository.writeTail.then(operation, operation)
    DownloadQueueRepository.writeTail = queued.catch((): void => {})
    return queued
  }

  private static extensions(rows: relationalStore.ResultSet, name: string): string[] {
    const raw: string = DownloadQueueRepository.stringColumn(rows, name)
    try {
      const values: Object = JSON.parse(raw) as Object
      if (!Array.isArray(values)) {
        return []
      }
      const extensions: string[] = []
      for (let index: number = 0; index < values.length; index++) {
        if (typeof values[index] !== 'string') {
          return []
        }
        const extension: string = DownloadQueueRepository.normalizedExtension(values[index] as string)
        if (extension.length === 0) {
          return []
        }
        extensions.push(extension)
      }
      return extensions
    } catch (_error) {
      return []
    }
  }

  private static normalizedExtension(value: string): string {
    const extension: string = value.toLowerCase().replace('.', '').trim()
    return /^[a-z0-9]{1,8}$/.test(extension) ? extension : ''
  }

  private static completedPageIndexes(raw: string, pageCount: number): number[] {
    try {
      const values: Object = JSON.parse(raw) as Object
      if (!Array.isArray(values)) {
        return []
      }
      const out: number[] = []
      for (let index: number = 0; index < values.length; index += 1) {
        if (typeof values[index] !== 'number') {
          continue
        }
        const pageIndex: number = Math.floor(values[index] as number)
        if (!Number.isSafeInteger(pageIndex) ||
          pageIndex < 0 || pageIndex >= pageCount || out.indexOf(pageIndex) >= 0) {
          continue
        }
        out.push(pageIndex)
      }
      out.sort((left: number, right: number): number => left - right)
      return out
    } catch (_error) {
      return []
    }
  }

  private static normalizedStatus(value: string): string {
    if (value === NhDownloadTaskStatus.DOWNLOADING || value === NhDownloadTaskStatus.PAUSED ||
      value === NhDownloadTaskStatus.COMPLETE || value === NhDownloadTaskStatus.ERROR) {
      return value
    }
    return NhDownloadTaskStatus.QUEUED
  }

  private static stringColumn(rows: relationalStore.ResultSet, name: string): string {
    const index: number = rows.getColumnIndex(name)
    return rows.isColumnNull(index) ? '' : rows.getString(index)
  }

  private static numberColumn(rows: relationalStore.ResultSet, name: string): number {
    const index: number = rows.getColumnIndex(name)
    return rows.isColumnNull(index) ? 0 : Math.floor(rows.getDouble(index))
  }
}
