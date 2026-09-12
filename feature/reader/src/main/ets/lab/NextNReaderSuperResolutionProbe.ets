import { AppStorageV2 } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'

/** In-process debug-test observation only; no image, setting or service state is retained. */
@ObservedV2
export class NextNReaderSuperResolutionProbe {
  private epoch: number = 0
  private work: string = ''
  private receiver: ((sourceIndex: number, stage: string, identity: string) => void) | null = null

  arm(work: string, receiver: (sourceIndex: number, stage: string, identity: string) => void): number {
    this.epoch += 1
    this.work = work
    this.receiver = receiver
    return this.epoch
  }

  deliver(context: common.UIAbilityContext, work: string, sourceIndex: number, stage: string, identity: string): void {
    if (!context.applicationInfo.debug || this.work !== work) return
    this.receiver?.(sourceIndex, stage, identity)
  }

  cancel(epoch: number): void {
    if (epoch !== this.epoch) return
    this.work = ''
    this.receiver = null
  }
}

export function connectNextNReaderSuperResolutionProbe(): NextNReaderSuperResolutionProbe {
  return AppStorageV2.connect(NextNReaderSuperResolutionProbe, () => new NextNReaderSuperResolutionProbe())!
}
