import { AppStorageV2 } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { ReaderCancellation } from '@reader-kit/core'

/** In-process debug-test observation only; no image, setting or service state is retained. */
@ObservedV2
export class NextNReaderSuperResolutionProbe {
  private epoch: number = 0
  private work: string = ''
  private receiver: ((sourceIndex: number, stage: string, identity: string) => void) | null = null
  private pausedSource: number = -1
  private pausedEpoch: number = 0
  private releasePause: (() => void) | null = null

  arm(work: string, receiver: (sourceIndex: number, stage: string, identity: string) => void,
    pausedSource: number = -1): number {
    this.releaseCurrentPause()
    this.epoch += 1
    this.work = work
    this.receiver = receiver
    this.pausedSource = pausedSource
    return this.epoch
  }

  deliver(context: common.UIAbilityContext, work: string, sourceIndex: number, stage: string, identity: string): void {
    if (!context.applicationInfo.debug || this.work !== work) return
    this.receiver?.(sourceIndex, stage, identity)
  }

  /** Deterministic Debug-only gate used to prove navigation cancels an in-flight processor owner. */
  async pauseBeforeProcess(context: common.UIAbilityContext, work: string, sourceIndex: number,
    cancellation: ReaderCancellation): Promise<void> {
    if (!context.applicationInfo.debug || this.work !== work || this.pausedSource !== sourceIndex) return
    const epoch = this.epoch
    this.pausedSource = -1
    this.pausedEpoch = epoch
    await new Promise<void>((resolve): void => {
      let settled: boolean = false
      let detach: () => void = (): void => {}
      const finish = (): void => {
        if (settled) return
        settled = true
        detach()
        if (this.pausedEpoch === epoch) {
          this.pausedEpoch = 0
          this.releasePause = null
        }
        resolve()
      }
      detach = cancellation.onCancel(finish)
      this.releasePause = finish
    })
  }

  release(epoch: number): void {
    if (epoch !== this.epoch) return
    this.releaseCurrentPause()
  }

  cancel(epoch: number): void {
    if (epoch !== this.epoch) return
    this.releaseCurrentPause()
    this.work = ''
    this.receiver = null
    this.pausedSource = -1
  }

  private releaseCurrentPause(): void {
    const release = this.releasePause
    this.releasePause = null
    this.pausedEpoch = 0
    release?.()
  }
}

export function connectNextNReaderSuperResolutionProbe(): NextNReaderSuperResolutionProbe {
  return AppStorageV2.connect(NextNReaderSuperResolutionProbe, () => new NextNReaderSuperResolutionProbe())!
}
