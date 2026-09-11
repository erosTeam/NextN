import { AppStorageV2 } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'

/** One-shot native-test handoff; never stores a Context or writes reader preferences. */
@ObservedV2
export class NextNReaderLabContextProbe {
  private epoch: number = 0
  private work: string = ''
  private receiver: ((context: common.UIAbilityContext) => void) | null = null

  arm(work: string, receiver: (context: common.UIAbilityContext) => void): number {
    this.epoch += 1
    this.work = work
    this.receiver = receiver
    return this.epoch
  }

  deliver(work: string, context: common.UIAbilityContext): void {
    if (!context.applicationInfo.debug || this.work !== work) return
    const receiver = this.receiver
    this.receiver = null
    this.work = ''
    receiver?.(context)
  }

  cancel(epoch: number): void {
    if (epoch !== this.epoch) return
    this.receiver = null
    this.work = ''
  }
}

export function connectNextNReaderLabContextProbe(): NextNReaderLabContextProbe {
  return AppStorageV2.connect(NextNReaderLabContextProbe, () => new NextNReaderLabContextProbe())!
}
