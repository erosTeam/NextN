import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Component, Driver, ON } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { fileIo } from '@kit.CoreFileKit'
import { connectNextNReaderLabContextProbe } from 'reader'
import { ReaderSettingsRepository, ReaderPresentationService, NhReaderMode } from 'shared'

class HostContext { value: common.UIAbilityContext | null = null }
class InspectorNode {
  $type: string = ''
  $ID: number = -1
  $attrs: Record<string, string | number> = {}
  $children: InspectorNode[] = []
}
class ImageEvidence {
  nodeId: number = -1
  attributeKeys: string[] = []
  candidateKeys: string[] = []
  candidateValues: string[] = []
}
class SamplingEvidence {
  sourceIndex: number = -1
  windowId: number = -1
  width: number = 0
  height: number = 0
  canonical: string = ''
  images: ImageEvidence[] = []
  samplingVerified: boolean = false
}
async function waitId(d: Driver, id: string): Promise<Component> {
  for (let i = 0; i < 60; i++) {
    const c = await d.findComponent(ON.id(id))
    if (c !== null) return c
    await d.delayMs(250)
  }
  throw new Error('interpolation missing:' + id)
}
async function body(d: Driver, index: number): Promise<void> {
  for (let i = 0; i < 60; i++) {
    const image = await d.findComponent(ON.type('Image').within(ON.id('rkit-part-' + index + '-whole')))
    if (image !== null && await d.findComponent(ON.type('LoadingProgress').within(ON.id('rkit-part-' + index + '-whole'))) === null) {
      const b = await image.getBounds()
      if (b.right > b.left && b.bottom > b.top) {
        console.info('[ReaderInterpolationTest] source=' + index + ' bounds=' + JSON.stringify(b))
        return
      }
    }
    await d.delayMs(250)
  }
  throw new Error('interpolation body unavailable:' + index)
}
async function center(d: Driver): Promise<void> {
  await waitId(d, 'rkit-image-viewport')
  const a = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()
  const w = await window.getLastWindow(a.context)
  const r = w.getUIContext().getComponentUtils().getRectangleById('rkit-image-viewport')
  expect(r.size.width > 0 && r.size.height > 0).assertTrue()
  console.info('[ReaderInterpolationTest] window=' + w.getWindowProperties().id + ' rect=' + JSON.stringify(r))
  await d.click(Math.round(r.windowOffset.x + r.size.width / 2), Math.round(r.windowOffset.y + r.size.height / 2))
  await d.delayMs(700)
}
async function closeTrial(d: Driver): Promise<void> {
  if (await d.findComponent(ON.id('rkit-trial-navigation')) === null &&
    await d.findComponent(ON.id('rkit-phase')) === null &&
    await d.findComponent(ON.id('rkit-reading-surface')) === null) return
  let close = await d.findComponent(ON.id('rkit-close'))
  if (close === null) { await center(d); close = await d.findComponent(ON.id('rkit-close')) }
  if (close !== null) await close.click()
  else await d.pressBack()
  for (let i = 0; i < 60; i++) {
    if (await d.findComponent(ON.id('rkit-trial-navigation')) === null &&
      await d.findComponent(ON.id('rkit-phase')) === null &&
      await d.findComponent(ON.id('rkit-reading-surface')) === null) return
    await d.delayMs(250)
  }
  throw new Error('interpolation trial exit unconfirmed')
}
async function assertHost(): Promise<void> {
  const a = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()
  expect(a.context.abilityInfo.name).assertEqual('EntryAbility')
  expect(a.context.applicationInfo.name).assertEqual('com.erosteam.nextn')
  const w = await window.getLastWindow(a.context)
  const r = w.getUIContext().getComponentUtils().getRectangleById('nextn-root-navigation')
  expect(r.size.width > 0 && r.size.height > 0).assertTrue()
  console.info('[ReaderInterpolationTest] exitHost=NextN window=' + w.getWindowProperties().id + ' root=' + JSON.stringify(r))
}
async function launch(d: Driver): Promise<void> {
  await abilityDelegatorRegistry.getAbilityDelegator().startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility',
    parameters: { readerLabWork: '678049', readerLabPage: '2', readerLabChrome: 'true', readerLabVolumeKeys: 'false' } })
  await waitId(d, 'rkit-close'); await body(d, 2)
}

function safeValue(value: string | number | undefined): string | null {
  if (typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 3) return String(value)
  if (typeof value !== 'string') return null
  const allowed = ['none', 'low', 'medium', 'high', 'None', 'Low', 'Medium', 'High',
    'ImageInterpolation.None', 'ImageInterpolation.Low', 'ImageInterpolation.Medium', 'ImageInterpolation.High', '0', '1', '2', '3']
  return allowed.includes(value) ? value : null
}
function inspect(node: InspectorNode, result: ImageEvidence[], depth: number): void {
  if (depth > 24 || result.length > 8) throw new Error('inspector scoped tree exceeds diagnostic bound')
  if (node.$type === 'Image') {
    const e = new ImageEvidence()
    if (typeof node.$ID === 'number' && Number.isFinite(node.$ID)) e.nodeId = node.$ID
    if (node.$attrs !== undefined && node.$attrs !== null) {
      e.attributeKeys = Object.keys(node.$attrs).filter((key: string): boolean => /^[A-Za-z0-9_$.-]{1,80}$/.test(key)).slice(0,160)
      const interpolation = safeValue(node.$attrs.interpolation)
      if (interpolation !== null) { e.candidateKeys.push('interpolation'); e.candidateValues.push(interpolation) }
      const imageInterpolation = safeValue(node.$attrs.imageInterpolation)
      if (imageInterpolation !== null) { e.candidateKeys.push('imageInterpolation'); e.candidateValues.push(imageInterpolation) }
      const sampling = safeValue(node.$attrs.sampling)
      if (sampling !== null) { e.candidateKeys.push('sampling'); e.candidateValues.push(sampling) }
    }
    result.push(e)
  }
  if (Array.isArray(node.$children)) for (const child of node.$children) inspect(child, result, depth + 1)
}
function matches(e: ImageEvidence, canonical: string): boolean {
  // Numeric values are evidence only until the Inspector's numeric representation is established.
  for (let i = 0; i < e.candidateKeys.length; i++) {
    if (e.candidateKeys[i] !== 'interpolation' && e.candidateKeys[i] !== 'imageInterpolation') continue
    const value = e.candidateValues[i].replace('ImageInterpolation.', '').toLowerCase()
    if (value === canonical) return true
  }
  return false
}
async function sample(d: Driver, index: number, canonical: string, name: string): Promise<boolean> {
  await body(d, index)
  const id = 'rkit-part-' + index + '-whole'
  expect((await d.findComponents(ON.id(id))).length).assertEqual(1)
  const a = abilityDelegatorRegistry.getAbilityDelegator()
  const win = await window.getLastWindow((await a.getCurrentTopAbility()).context)
  const ui = win.getUIContext(), rect = ui.getComponentUtils().getRectangleById(id)
  expect(rect.size.width > 0 && rect.size.height > 0).assertTrue()
  // Only this actual source subtree; never serialize or log the returned raw Inspector string.
  // Omit filters so test-only Image attributes such as interpolation remain available.
  // The raw tree is never serialized or logged; only attribute names and whitelisted
  // interpolation enum values are retained below.
  const node = JSON.parse(ui.getFilteredInspectorTreeById(id, 0)) as InspectorNode
  const evidence = new SamplingEvidence()
  evidence.sourceIndex = index; evidence.windowId = win.getWindowProperties().id
  evidence.width = rect.size.width; evidence.height = rect.size.height; evidence.canonical = canonical
  inspect(node, evidence.images, 0)
  evidence.samplingVerified = evidence.images.length > 0 && evidence.images.every((image: ImageEvidence): boolean => matches(image, canonical))
  const safe = JSON.stringify(evidence)
  const path = a.getAppContext().cacheDir + '/rkit-interpolation-' + name + '.json'
  const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
  try { fileIo.writeSync(file.fd, safe) } finally { fileIo.closeSync(file) }
  console.info('[ReaderInterpolationTest] sample=' + name + ' evidence=' + safe)
  expect(await d.screenCap(a.getAppContext().cacheDir + '/rkit-interpolation-' + name + '.png')).assertTrue()
  return evidence.samplingVerified
}
export default function readerInterpolationTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  if (args['-s class'] !== 'ReaderInterpolationTrial') return
  describe('ReaderInterpolationTrial', (): void => {
    it('readOnlyScopedInspectorSampling', 0, async (): Promise<void> => {
      expect(args['-s readerLabWork']).assertEqual('678049')
      const d = Driver.create(), holder = new HostContext(), probe = connectNextNReaderLabContextProbe()
      const epoch = probe.arm('678049', (ctx: common.UIAbilityContext): void => { holder.value = ctx })
      let failed = false
      try {
        await launch(d)
        for (let i = 0; i < 60 && holder.value === null; i++) await d.delayMs(250)
        const ctx = holder.value
        if (ctx === null) throw new Error('interpolation actual context unavailable')
        expect(ctx.databaseDir.endsWith('/entry')).assertTrue()
        const state = ReaderPresentationService.snapshot(), signature = JSON.stringify(state)
        expect(state.imageScalingQuality).assertEqual(await ReaderSettingsRepository.imageScalingQuality(ctx))
        expect(state.mode === NhReaderMode.PAGED || state.mode === NhReaderMode.PAGED_RTL).assertTrue()
        expect(state.doublePageEnabled).assertFalse()
        const first = await sample(d, 2, state.imageScalingQuality, 'ordinary')
        await center(d)
        expect(await d.findComponent(ON.id('rkit-chrome-page'))).assertNull()
        const a = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility()
        const w = await window.getLastWindow(a.context)
        const r = w.getUIContext().getComponentUtils().getRectangleById('rkit-image-viewport')
        const left = Math.round(r.windowOffset.x + r.size.width * 0.19), right = Math.round(r.windowOffset.x + r.size.width * 0.81)
        const y = Math.round(r.windowOffset.y + r.size.height / 2), rtl = state.mode === NhReaderMode.PAGED_RTL
        await d.swipe(rtl ? left : right, y, rtl ? right : left, y, 700)
        await d.delayMs(700); await body(d, 3)
        const second = await sample(d, 3, state.imageScalingQuality, 'turned')
        expect(JSON.stringify(ReaderPresentationService.snapshot())).assertEqual(signature)
        expect(await ReaderSettingsRepository.imageScalingQuality(ctx)).assertEqual(state.imageScalingQuality)
        await closeTrial(d); await assertHost()
        expect(JSON.stringify(ReaderPresentationService.snapshot())).assertEqual(signature)
        console.info('[ReaderInterpolationTest] readonlySignatureUnchanged=true samplingVerified=' + (first && second))
        if (!first || !second) throw new Error('samplingUNVERIFIED: scoped Inspector does not expose a confirmed matching interpolation field')
      } catch (error) {
        failed = true
        // Do not stringify framework errors: they may contain resource URIs.
        console.error('[ReaderInterpolationTest] trialFailed=true')
        throw error as Error
      } finally {
        probe.cancel(epoch)
        try {
          await closeTrial(d); await assertHost()
          const a = abilityDelegatorRegistry.getAbilityDelegator()
          expect(await d.screenCap(a.getAppContext().cacheDir + '/rkit-interpolation-exit.png')).assertTrue()
          console.info('[ReaderInterpolationTest] capture=exit')
        } catch (error) { if (!failed) throw error as Error }
      }
    })
  })
}
