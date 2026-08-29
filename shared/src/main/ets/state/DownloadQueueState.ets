import { AppStorageV2 } from '@kit.ArkUI'
import { NhDownloadTask } from '../model/NhDownloadTask'

@ObservedV2
export class DownloadQueueState {
  @Trace revision: number = 0
  @Trace tasks: NhDownloadTask[] = []

  replace(tasks: NhDownloadTask[]): void {
    const next: NhDownloadTask[] = []
    for (let index: number = 0; index < tasks.length; index += 1) {
      const source: NhDownloadTask = tasks[index]
      const existing: NhDownloadTask | undefined = this.tasks.find(
        (task: NhDownloadTask): boolean => task.galleryId === source.galleryId,
      )
      if (existing !== undefined) {
        existing.assignFrom(source)
        next.push(existing)
      } else {
        next.push(source.copy())
      }
    }
    this.tasks = next
    this.revision += 1
    publishDownloadQueueChanged()
  }
}

@ObservedV2
export class DownloadQueueSignalState {
  @Trace version: number = 0
}

const DOWNLOAD_QUEUE_STATE_KEY: string = 'nextn_download_queue'
const DOWNLOAD_QUEUE_SIGNAL_KEY: string = 'nextn_download_queue_signal'
let sharedDownloadQueueState: DownloadQueueState | null = null

export function connectDownloadQueue(): DownloadQueueState {
  if (sharedDownloadQueueState === null) {
    sharedDownloadQueueState = AppStorageV2.connect(
      DownloadQueueState,
      DOWNLOAD_QUEUE_STATE_KEY,
      (): DownloadQueueState => new DownloadQueueState(),
    )!
  }
  return sharedDownloadQueueState
}

export function connectDownloadQueueSignal(): DownloadQueueSignalState {
  return AppStorageV2.connect(
    DownloadQueueSignalState,
    DOWNLOAD_QUEUE_SIGNAL_KEY,
    (): DownloadQueueSignalState => new DownloadQueueSignalState(),
  )!
}

export function publishDownloadQueueChanged(): void {
  const signal: DownloadQueueSignalState = connectDownloadQueueSignal()
  signal.version += 1
}
