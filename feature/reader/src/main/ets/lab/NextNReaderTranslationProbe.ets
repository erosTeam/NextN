import { AppStorageV2 } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'

/** Debug-test seam for a local translated file; never calls or replaces a configured production service. */
@ObservedV2
export class NextNReaderTranslationProbe {
  private epoch: number = 0
  private work: string = ''
  private localPath: string = ''
  private receiver: ((sourceIndex: number, stage: string, identity: string) => void) | null = null
  private action: ((id: string) => boolean) | null = null
  private unavailableSources: number[] = []

  arm(work: string, localPath: string,
    receiver: (sourceIndex: number, stage: string, identity: string) => void): number {
    this.epoch += 1
    this.work = work
    this.localPath = localPath
    this.receiver = receiver
    this.action = null
    this.unavailableSources = []
    return this.epoch
  }

  setUnavailable(epoch: number, sourceIndex: number, unavailable: boolean): boolean {
    if (epoch !== this.epoch || !Number.isInteger(sourceIndex) || sourceIndex < 0) return false
    if (unavailable && !this.unavailableSources.includes(sourceIndex)) {
      this.unavailableSources = this.unavailableSources.concat([sourceIndex])
    } else if (!unavailable) {
      this.unavailableSources = this.unavailableSources.filter((value: number): boolean => value !== sourceIndex)
    }
    return true
  }

  unavailable(context: common.UIAbilityContext, work: string, sourceIndex: number): boolean {
    return context.applicationInfo.debug && this.work === work && this.unavailableSources.includes(sourceIndex)
  }

  bindAction(context: common.UIAbilityContext, work: string, action: (id: string) => boolean): void {
    if (!context.applicationInfo.debug || this.work !== work) return
    this.action = action
  }

  invoke(epoch: number, id: string): boolean {
    if (epoch !== this.epoch || this.action === null) return false
    return this.action(id)
  }

  result(context: common.UIAbilityContext, work: string): string {
    if (!context.applicationInfo.debug || this.work !== work) return ''
    return this.localPath
  }

  deliver(context: common.UIAbilityContext, work: string, sourceIndex: number,
    stage: string, identity: string): void {
    if (!context.applicationInfo.debug || this.work !== work) return
    this.receiver?.(sourceIndex, stage, identity)
  }

  cancel(epoch: number): void {
    if (epoch !== this.epoch) return
    this.work = ''
    this.localPath = ''
    this.receiver = null
    this.action = null
    this.unavailableSources = []
  }
}

export function connectNextNReaderTranslationProbe(): NextNReaderTranslationProbe {
  return AppStorageV2.connect(NextNReaderTranslationProbe, () => new NextNReaderTranslationProbe())!
}
