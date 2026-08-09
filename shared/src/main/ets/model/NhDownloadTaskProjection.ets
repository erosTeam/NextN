import { NhDownloadTask, NhDownloadTaskStatus } from './NhDownloadTask'
import { NhDownloadSortMode } from './NhDownloadSortMode'

/**
 * Local-only task projection for the Downloads root.
 *
 * ErosN and NextE both keep one durable queue but present it by lifecycle
 * state. Keeping that projection separate from DownloadQueueService ensures
 * grouping cannot alter scheduling, retry, or app-private file ownership.
 */
export class NhDownloadTaskProjection {
  static readonly ACTIVE: number = 0
  static readonly PAUSED: number = 1
  static readonly RETRY: number = 2
  static readonly COMPLETE: number = 3
  static readonly GROUP_COUNT: number = 4

  groups: NhDownloadTask[][] = [[], [], [], []]

  static build(
    tasks: NhDownloadTask[],
    searchText: string = '',
    sortMode: string = NhDownloadSortMode.ADDED_DESC,
  ): NhDownloadTaskProjection {
    const projection: NhDownloadTaskProjection = new NhDownloadTaskProjection()
    const query: string = searchText.trim().toLowerCase()
    for (let index: number = 0; index < tasks.length; index += 1) {
      const task: NhDownloadTask = tasks[index]
      if (!NhDownloadTaskProjection.matchesSearch(task, query)) {
        continue
      }
      projection.groups[NhDownloadTaskProjection.groupFor(task)].push(task)
    }
    for (let group: number = 0; group < NhDownloadTaskProjection.GROUP_COUNT; group += 1) {
      projection.groups[group].sort((left: NhDownloadTask, right: NhDownloadTask): number => {
        return NhDownloadTaskProjection.compareTasks(left, right, group, sortMode)
      })
    }
    return projection
  }

  tasksForGroup(group: number): NhDownloadTask[] {
    if (group < 0 || group >= NhDownloadTaskProjection.GROUP_COUNT) {
      return []
    }
    return this.groups[group]
  }

  static groupFor(task: NhDownloadTask): number {
    if (task.isComplete() || task.status === NhDownloadTaskStatus.COMPLETE) {
      return NhDownloadTaskProjection.COMPLETE
    }
    if (task.status === NhDownloadTaskStatus.ERROR) {
      return NhDownloadTaskProjection.RETRY
    }
    if (task.status === NhDownloadTaskStatus.PAUSED) {
      return NhDownloadTaskProjection.PAUSED
    }
    return NhDownloadTaskProjection.ACTIVE
  }

  private static matchesSearch(task: NhDownloadTask, query: string): boolean {
    if (query.length === 0) {
      return true
    }
    // Match ErosN's Downloads semantics exactly: a local title or visible
    // gallery ID match. media IDs, URLs, files, and task errors remain out of
    // search so this view never exposes worker or storage internals.
    return task.title.toLowerCase().includes(query) || task.galleryId.toString().includes(query)
  }

  private static compareTasks(
    left: NhDownloadTask,
    right: NhDownloadTask,
    group: number,
    sortMode: string,
  ): number {
    // ErosN keeps truly downloading work ahead of queued work inside the
    // shared active section, independent of the selected presentation order.
    if (group === NhDownloadTaskProjection.ACTIVE) {
      const leftPriority: number = left.status === NhDownloadTaskStatus.DOWNLOADING ? 0 : 1
      const rightPriority: number = right.status === NhDownloadTaskStatus.DOWNLOADING ? 0 : 1
      if (leftPriority !== rightPriority) {
        return leftPriority - rightPriority
      }
    }
    if (sortMode === NhDownloadSortMode.ADDED_ASC) {
      return NhDownloadTaskProjection.compareAdded(left, right, true)
    }
    if (sortMode === NhDownloadSortMode.TITLE_ASC) {
      return NhDownloadTaskProjection.compareTitle(left, right, true)
    }
    if (sortMode === NhDownloadSortMode.TITLE_DESC) {
      return NhDownloadTaskProjection.compareTitle(left, right, false)
    }
    return NhDownloadTaskProjection.compareAdded(left, right, false)
  }

  private static compareAdded(left: NhDownloadTask, right: NhDownloadTask, ascending: boolean): number {
    if (left.createdAt !== right.createdAt) {
      return ascending ? left.createdAt - right.createdAt : right.createdAt - left.createdAt
    }
    if (left.galleryId !== right.galleryId) {
      return ascending ? left.galleryId - right.galleryId : right.galleryId - left.galleryId
    }
    return 0
  }

  private static compareTitle(left: NhDownloadTask, right: NhDownloadTask, ascending: boolean): number {
    const leftTitle: string = NhDownloadTaskProjection.displayTitle(left)
    const rightTitle: string = NhDownloadTaskProjection.displayTitle(right)
    if (leftTitle < rightTitle) {
      return ascending ? -1 : 1
    }
    if (leftTitle > rightTitle) {
      return ascending ? 1 : -1
    }
    // Keep title ties deterministic without changing the task itself.
    return NhDownloadTaskProjection.compareAdded(left, right, false)
  }

  private static displayTitle(task: NhDownloadTask): string {
    return task.title.length > 0 ? task.title : `#${task.galleryId}`
  }

}
