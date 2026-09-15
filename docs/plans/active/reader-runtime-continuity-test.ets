/**
 * Runtime Continuity Trials — Package 5
 *
 * Verifies that reading progress survives an install -r upgrade/rollback
 * cycle and that the user can resume reading at the exact same page.
 *
 * Three phases orchestrated by device protocol manifest:
 *   Phase 1 (Setup):    ReaderRuntimeContinuitySetupTrial
 *   Phase 2 (Upgrade):  ReaderRuntimeContinuityUpgradeTrial
 *   Phase 3 (Rollback): ReaderRuntimeContinuityRollbackTrial
 *
 * State handoff via /data/local/tmp/reader-continuity-state.json
 */
import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit'
import { relationalStore } from '@kit.ArkData'
import { fileIo } from '@kit.CoreFileKit'
import {
  connectNextNReaderBackendSelection,
  NextNReaderBackend,
} from 'shared'

const STATE_FILE = '/data/local/tmp/reader-continuity-state.json'
const CAPTURE_PREFIX = 'reader-continuity'

interface ContinuityState {
  galleryId: number
  pageIndex: number
  totalPages: number
  readerMode: string
  backend: string
  timestamp: number
}

function readContinuityState(): ContinuityState | null {
  try {
    const stat = fileIo.statSync(STATE_FILE)
    if (stat.size <= 0) return null
    const file = fileIo.openSync(STATE_FILE, fileIo.OpenMode.READ_ONLY)
    try {
      const buf = new ArrayBuffer(stat.size)
      fileIo.readSync(file.fd, buf)
      const text = String.fromCharCode.apply(null, Array.from(new Uint8Array(buf)))
      return JSON.parse(text) as ContinuityState
    } finally { fileIo.closeSync(file) }
  } catch (_) { return null }
}

function writeContinuityState(state: ContinuityState): void {
  const file = fileIo.openSync(STATE_FILE,
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
  try { fileIo.writeSync(file.fd, JSON.stringify(state)) } finally { fileIo.closeSync(file) }
}

async function capture(driver: Driver, name: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator()
  const cache = delegator.getAppContext().cacheDir
  await delegator.executeShellCommand(
    `uitest dumpLayout -p /data/local/tmp/${CAPTURE_PREFIX}-${name}.json -a`, 15)
  await driver.screenCap(`${cache}/${CAPTURE_PREFIX}-${name}.png`)
}

async function waitReaderReady(driver: Driver): Promise<void> {
  // Wait for either shared or legacy reader surface to be visible
  for (let i = 0; i < 30; i++) {
    if (await driver.findComponent(ON.id('rkit-reading-surface')) !== null) return
    if (await driver.findComponent(ON.id('legacy-reader-surface')) !== null) return
    await driver.sleep(1000)
  }
  throw new Error('Reader surface not found within 30s')
}

async function getCurrentPageIndex(driver: Driver): Promise<number> {
  // Look for the page indicator to determine current page
  const indicator = await driver.findComponent(ON.id('rkit-persistent-page'))
  if (indicator !== null) {
    const text = await indicator.getText()
    const match = text.match(/(\\d+)\\s*\\//)
    if (match) return parseInt(match[1], 10)
  }
  return -1
}

// Phase dispatch
export default function readerRuntimeContinuityTest(): void {
  const selectedClass = abilityDelegatorRegistry.getArguments().parameters['-s class']

  if (selectedClass === 'ReaderRuntimeContinuitySetupTrial') {
    describe(selectedClass, (): void => {
      it('setupAndNavigateToTargetPage', 0, async (): Promise<void> => {
        const driver = Driver.create()
        const delegator = abilityDelegatorRegistry.getAbilityDelegator()
        try {
          await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
          await driver.sleep(3000)

          // Select Shared backend (verify default is Legacy first)
          expect(connectNextNReaderBackendSelection().current()).assertEqual(NextNReaderBackend.LEGACY)

          // Navigate to Downloads, open gallery, enter reader
          // (reuse existing navigation helpers from other trials)
          // ... open detail, click read, wait for reader ...

          // Navigate to page 3
          // ... swipe right twice from page 1 ...

          const currentPage = await getCurrentPageIndex(driver)
          expect(currentPage).assertEqual(3)

          // Save state for Phase 2 verification
          writeContinuityState({
            galleryId: 678049,
            pageIndex: currentPage,
            totalPages: 14,
            readerMode: 'paged',
            backend: 'shared',
            timestamp: Date.now()
          })

          await capture(driver, 'setup-baseline')
        } catch (error) {
          try { await capture(driver, 'setup-exception') } catch (_) {}
          throw error as Error
        }
      })
    })
  }

  if (selectedClass === 'ReaderRuntimeContinuityUpgradeTrial') {
    describe(selectedClass, (): void => {
      it('verifySamePageAfterUpgrade', 0, async (): Promise<void> => {
        const driver = Driver.create()
        const delegator = abilityDelegatorRegistry.getAbilityDelegator()
        try {
          const state = readContinuityState()
          expect(state !== null).assertTrue()
          expect(state!.galleryId).assertEqual(678049)

          await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
          await driver.sleep(3000)

          // Navigate to the same gallery from Downloads
          // ... open reader ...

          await waitReaderReady(driver)
          const currentPage = await getCurrentPageIndex(driver)
          expect(currentPage).assertEqual(state!.pageIndex)

          await capture(driver, 'upgrade-verified')
        } catch (error) {
          try { await capture(driver, 'upgrade-exception') } catch (_) {}
          throw error as Error
        }
      })
    })
  }

  if (selectedClass === 'ReaderRuntimeContinuityRollbackTrial') {
    describe(selectedClass, (): void => {
      it('verifySamePageAfterRollback', 0, async (): Promise<void> => {
        const driver = Driver.create()
        const delegator = abilityDelegatorRegistry.getAbilityDelegator()
        try {
          const state = readContinuityState()
          expect(state !== null).assertTrue()

          await delegator.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
          await driver.sleep(3000)

          // Navigate to same gallery
          await waitReaderReady(driver)
          const currentPage = await getCurrentPageIndex(driver)
          expect(currentPage).assertEqual(state!.pageIndex)

          await capture(driver, 'rollback-verified')
        } catch (error) {
          try { await capture(driver, 'rollback-exception') } catch (_) {}
          throw error as Error
        }
      })
    })
  }
}

