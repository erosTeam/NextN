import { AppStorageV2 } from '@kit.ArkUI'

/** In-process debug-test observation only; no reader setting or history storage. */
@ObservedV2
export class NextNReaderObservedProgressProbe {
  private epoch: number = 0
  private work: string = ''
  private receiver: ((pageIndex: number) => void) | null = null

  arm(work: string, receiver: (pageIndex: number) => void): number {
    this.epoch += 1
    this.work = work
    this.receiver = receiver
    return this.epoch
  }

  deliver(work: string, pageIndex: number): void {
    if (this.work === work) this.receiver?.(pageIndex)
  }

  cancel(epoch: number): void {
    if (epoch !== this.epoch) return
    this.work = ''
    this.receiver = null
  }
}

export function connectNextNReaderObservedProgressProbe(): NextNReaderObservedProgressProbe {
  return AppStorageV2.connect(NextNReaderObservedProgressProbe, () => new NextNReaderObservedProgressProbe())!
}
