import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { ReaderCancellation } from '@reader-kit/core'
import { NextNProductionReaderDataSource } from 'reader'
import { DownloadQueueService, NhDownloadTask, NhGalleryDetail } from 'shared'

async function productionContext(driver: Driver): Promise<common.UIAbilityContext> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
  for (let attempt: number = 0; attempt < 80; attempt += 1) {
    const ability = await delegator.getCurrentTopAbility()
    if (ability.context.abilityInfo.name === 'EntryAbility') return ability.context
    await driver.delayMs(100)
  }
  throw new Error('EntryAbility context unavailable')
}

export default function readerProductionDownloadSourceTrialTest(): void {
  describe('ReaderProductionDownloadSourceTrial', (): void => {
    it('usesVerifiedCompleteDownloadWithoutNetworkPageMaterial', 0, async (): Promise<void> => {
      const driver = Driver.create()
      const context = await productionContext(driver)
      await DownloadQueueService.restore(context)
      const tasks: NhDownloadTask[] = DownloadQueueService.snapshot().filter(
        (task: NhDownloadTask): boolean => task.isComplete(),
      )
      if (tasks.length === 0) {
        console.info('[ReaderProductionDownloadSourceTrial] sample=none')
        expect(true).assertTrue()
        return
      }
      const task: NhDownloadTask = tasks[0]
      const source = new NextNProductionReaderDataSource(context, null)
      const detail: NhGalleryDetail = await source.openDetail(task.galleryId, new ReaderCancellation())
      expect(detail.id).assertEqual(task.galleryId)
      expect(detail.pages.length).assertEqual(task.pageCount)
      const uri: string = source.localPageUri(detail, 0)
      expect(uri.startsWith('file://')).assertTrue()
      const path: string = uri.substring('file://'.length)
      expect(path.length > 0 && fileIo.accessSync(path)).assertTrue()
      console.info(`[ReaderProductionDownloadSourceTrial] sample=complete pages=${detail.pages.length} local=true`)
    })
  })
}
