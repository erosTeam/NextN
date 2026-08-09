import { AppStorageV2 } from '@kit.ArkUI'
import { NhDownloadTask } from '../model/NhDownloadTask'

@ObservedV2
export class DownloadQueueState {
  @Trace revision: number = 0
  @Trace tasks: NhDownloadTask[] = []

  replace(tasks: NhDownloadTask[]): void {
    this.tasks = tasks.map((task: NhDownloadTask): NhDownloadTask => task.copy())
    this.revision += 1
  }
}

const DOWNLOAD_QUEUE_STATE_KEY: string = 'nextn_download_queue'
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
