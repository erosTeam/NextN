import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON, MatchPattern } from '@kit.TestKit'
import { window } from '@kit.ArkUI'
import { fileIo } from '@kit.CoreFileKit'
import {
  connectBrowsePresentation, connectGalleryDetailTransition,
  connectGalleryDetailTransitionSettings, connectLayoutSafeArea, connectTabletLayout,
  GalleryDetailTransitionPhase, NhBrowsePresentation,
} from 'shared'

async function capture(driver: Driver, name: string): Promise<void> {
  const cache = abilityDelegatorRegistry.getAbilityDelegator().getAppContext().cacheDir
  for (const suffix of ['json', 'png']) {
    const path = `${cache}/gallery-split-${name}.${suffix}`
    if (fileIo.accessSync(path)) fileIo.unlinkSync(path)
    expect(suffix === 'json' ? await driver.dumpLayout(path) : await driver.screenCap(path)).assertTrue()
  }
}

async function waitSplit(driver: Driver, split: boolean): Promise<void> {
  for (let i = 0; i < 40; i++) {
    if (connectLayoutSafeArea().rootNavigationSplit === split) {
      await driver.delayMs(600)
      return
    }
    await driver.delayMs(200)
  }
  expect(connectLayoutSafeArea().rootNavigationSplit).assertEqual(split)
}

async function openCard(driver: Driver, source: string): Promise<void> {
  await (await driver.findComponent(ON.id(`${source}-cover`))).click()
  const state = connectGalleryDetailTransition()
  for (let i = 0; i < 40; i++) {
    if (state.phase === GalleryDetailTransitionPhase.OPEN && state.sourceComponentId === source) return
    await driver.delayMs(200)
  }
  expect(state.sourceComponentId).assertEqual(source)
  expect(state.phase).assertEqual(GalleryDetailTransitionPhase.OPEN)
}

async function assertCard(driver: Driver, source: string): Promise<void> {
  const cover = await driver.findComponent(ON.id(`${source}-cover`))
  expect(cover !== null).assertTrue()
  const rect = await cover.getBounds()
  expect(rect.right > rect.left && rect.bottom > rect.top).assertTrue()
  const images = await driver.findComponents(ON.type('Image').within(ON.id(`${source}-cover`)))
  expect(images.length > 0).assertTrue()
  const labels = await driver.findComponents(ON.type('Text').within(ON.id(source)))
  expect(labels.length > 0).assertTrue()
}

/** Real Home card input and physical window rotation; snapshots require independent visual review. */
export default function gallerySplitTransitionTest(): void {
  if (abilityDelegatorRegistry.getArguments().parameters['-s class'] !== 'GallerySplitTransitionTrial') return
  describe('GallerySplitTransitionTrial', (): void => {
    it('retainsVisibleSourcesAcrossSplitBackReplacementAndStackReturn', 0, async (): Promise<void> => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator()
      const driver = Driver.create()
      await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
      await driver.delayMs(1500)
      const ability = await delegator.getCurrentTopAbility()
      const mainWindow = await window.getLastWindow(ability.context)
      const orientation = mainWindow.getPreferredOrientation()
      const tablet = connectTabletLayout(), presentation = connectBrowsePresentation()
      const settings = connectGalleryDetailTransitionSettings()
      const originalTablet = tablet.mode, originalPresentation = presentation.mode, originalTransition = settings.mode
      let checkpoint = 'start'
      try {
        tablet.mode = 'landscapeOnly'
        presentation.mode = NhBrowsePresentation.WATERFALL
        await mainWindow.setPreferredOrientation(window.Orientation.PORTRAIT)
        await waitSplit(driver, false)
        // Current Home precondition is established by the leased discovery capture.
        let sources: string[] = []
        for (let i = 0; i < 30 && sources.length < 2; i++) {
          sources = []
          const cards = await driver.findComponents(ON.id('^gallery-list-collection-[0-9]+-waterfall-[0-9]+$', MatchPattern.REG_EXP))
          for (const card of cards) {
            const rect = await card.getBounds()
            if (rect.top > 300 && rect.bottom < 2100 && rect.right > rect.left) sources.push(await card.getId())
            if (sources.length === 2) break
          }
          if (sources.length < 2) await driver.delayMs(500)
        }
        expect(sources.length).assertEqual(2)
        const a = sources[0], b = sources[1]
        console.info(`[GallerySplitTrial] sources=${a},${b}`)
        for (const mode of ['coverExpand', 'seamless']) {
          settings.mode = mode
          checkpoint = `${mode}-source`
          await assertCard(driver, a); await capture(driver, checkpoint)
          await openCard(driver, a)
          expect(connectGalleryDetailTransition().mode).assertEqual(mode)
          await mainWindow.setPreferredOrientation(window.Orientation.LANDSCAPE)
          await waitSplit(driver, true)
          checkpoint = `${mode}-split`
          await assertCard(driver, a); await capture(driver, checkpoint)
          // Preserve the return context across a round trip in orientation.
          await mainWindow.setPreferredOrientation(window.Orientation.PORTRAIT)
          await waitSplit(driver, false)
          await driver.pressBack(); await driver.delayMs(1000)
          expect(connectGalleryDetailTransition().eligible).assertFalse()
          await assertCard(driver, a)
          checkpoint = `${mode}-stack-return`; await capture(driver, checkpoint)
          await openCard(driver, a)
          await mainWindow.setPreferredOrientation(window.Orientation.LANDSCAPE)
          await waitSplit(driver, true)
          await driver.pressBack(); await driver.delayMs(800)
          expect(connectGalleryDetailTransition().eligible).assertFalse()
          checkpoint = `${mode}-split-back`
          await assertCard(driver, a); await capture(driver, checkpoint)
          await mainWindow.setPreferredOrientation(window.Orientation.PORTRAIT)
          await waitSplit(driver, false)
          await openCard(driver, a)
          await mainWindow.setPreferredOrientation(window.Orientation.LANDSCAPE)
          await waitSplit(driver, true)
          await assertCard(driver, a)
          await (await driver.findComponent(ON.id(`${b}-cover`))).click()
          await driver.delayMs(1000)
          checkpoint = `${mode}-replaced`
          expect(connectGalleryDetailTransition().eligible).assertFalse()
          await assertCard(driver, a); await capture(driver, checkpoint)
          await mainWindow.setPreferredOrientation(window.Orientation.PORTRAIT)
          await waitSplit(driver, false)
          await driver.pressBack(); await driver.delayMs(1000)
          checkpoint = `${mode}-replacement-return`
          await assertCard(driver, a); await capture(driver, checkpoint)
          await openCard(driver, a)
          await driver.pressBack(); await driver.delayMs(1000)
          expect(connectGalleryDetailTransition().eligible).assertFalse()
          await assertCard(driver, a)
          console.info(`[GallerySplitTrial] accepted-functional mode=${mode} split/back/replace/stack/reopen`)
        }
      } catch (error) {
        console.error(`[GallerySplitTrial] failed checkpoint=${checkpoint} error=${error}`)
        await capture(driver, 'failure')
        throw new Error(`${error}`)
      } finally {
        tablet.mode = originalTablet
        presentation.mode = originalPresentation
        settings.mode = originalTransition
        await mainWindow.setPreferredOrientation(orientation)
        console.info(`[GallerySplitTrial] restored preferences orientation=${orientation}`)
      }
    })
  })
}
