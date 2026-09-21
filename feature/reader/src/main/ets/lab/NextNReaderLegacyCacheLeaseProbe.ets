import { common } from '@kit.AbilityKit'
import { AppStorageV2 } from '@kit.ArkUI'

export type NextNReaderLegacyCacheLeaseSurface = 'surface' | 'spread'

/**
 * Ephemeral Debug/ohosTest facts for one legacy cache-backed image replacement.
 *
 * This deliberately retains neither the URI nor a file path. The probe only
 * reports the lifecycle counts needed to distinguish a native replacement from
 * a node-removal fallback.
 */
export class NextNReaderLegacyCacheLeaseFacts {
  epoch: number = 0
  armed: boolean = false
  cacheResultCount: number = 0
  forceReloadResultCount: number = 0
  reloadScheduledCount: number = 0
  enhancementSuppressed: boolean = false
  matchingNativeCompletionCount: number = 0
  replacementNativeCompletionCount: number = 0
  releasedRetiredLeaseCount: number = 0
  nodeRemovalReleasedRetiredLeaseCount: number = 0
}

/**
 * One-shot test hook for B1. It can request exactly one force reload only
 * after the selected legacy Image has completed its first cache-backed frame.
 */
@ObservedV2
export class NextNReaderLegacyCacheLeaseProbe {
  private epoch: number = 0
  private expectedPageIndex: number = -1
  private expectedSurface: NextNReaderLegacyCacheLeaseSurface = 'surface'
  private reloadConsumed: boolean = false
  private facts: NextNReaderLegacyCacheLeaseFacts = new NextNReaderLegacyCacheLeaseFacts()

  arm(pageIndex: number, surface: NextNReaderLegacyCacheLeaseSurface = 'surface'): number {
    this.epoch += 1
    this.expectedPageIndex = Number.isSafeInteger(pageIndex) && pageIndex >= 0 ? pageIndex : -1
    this.expectedSurface = surface
    this.reloadConsumed = false
    const facts = new NextNReaderLegacyCacheLeaseFacts()
    facts.epoch = this.epoch
    facts.armed = this.expectedPageIndex >= 0
    this.facts = facts
    return this.epoch
  }

  recordCacheResult(context: common.UIAbilityContext, surface: NextNReaderLegacyCacheLeaseSurface,
    pageIndex: number, forceReload: boolean): void {
    if (!this.accepts(context, surface, pageIndex)) return
    this.facts.cacheResultCount += 1
    if (forceReload) this.facts.forceReloadResultCount += 1
  }

  /** Returns true once, after a matching native completion made the first cache frame visible. */
  consumeReloadAfterMatchingPresentation(context: common.UIAbilityContext,
    surface: NextNReaderLegacyCacheLeaseSurface, pageIndex: number, sourceMatchesActiveLease: boolean): boolean {
    if (!this.accepts(context, surface, pageIndex) || !sourceMatchesActiveLease || this.reloadConsumed ||
      this.facts.forceReloadResultCount > 0) return false
    this.reloadConsumed = true
    this.facts.reloadScheduledCount += 1
    return true
  }

  /** Keeps the B1 test on the cache-backed native Image, without writing a user preference. */
  shouldSuppressEnhancement(context: common.UIAbilityContext, surface: NextNReaderLegacyCacheLeaseSurface,
    pageIndex: number): boolean {
    if (!this.accepts(context, surface, pageIndex)) return false
    this.facts.enhancementSuppressed = true
    return true
  }

  recordNativeCompletion(context: common.UIAbilityContext, surface: NextNReaderLegacyCacheLeaseSurface,
    pageIndex: number, sourceMatchesActiveLease: boolean, retiredLeaseCount: number,
    releasedLeaseCount: number): void {
    if (!this.accepts(context, surface, pageIndex)) return
    if (sourceMatchesActiveLease) this.facts.matchingNativeCompletionCount += 1
    if (retiredLeaseCount <= 0) return
    this.facts.replacementNativeCompletionCount += 1
    this.facts.releasedRetiredLeaseCount += Math.max(0, releasedLeaseCount)
  }

  /** A cleared source can remove the old Image before its replacement is decoded. */
  recordNodeRemoval(context: common.UIAbilityContext, surface: NextNReaderLegacyCacheLeaseSurface,
    pageIndex: number, releasedLeaseCount: number): void {
    if (!this.accepts(context, surface, pageIndex)) return
    this.facts.nodeRemovalReleasedRetiredLeaseCount += Math.max(0, releasedLeaseCount)
  }

  read(): NextNReaderLegacyCacheLeaseFacts {
    const copy = new NextNReaderLegacyCacheLeaseFacts()
    copy.epoch = this.facts.epoch
    copy.armed = this.facts.armed
    copy.cacheResultCount = this.facts.cacheResultCount
    copy.forceReloadResultCount = this.facts.forceReloadResultCount
    copy.reloadScheduledCount = this.facts.reloadScheduledCount
    copy.enhancementSuppressed = this.facts.enhancementSuppressed
    copy.matchingNativeCompletionCount = this.facts.matchingNativeCompletionCount
    copy.replacementNativeCompletionCount = this.facts.replacementNativeCompletionCount
    copy.releasedRetiredLeaseCount = this.facts.releasedRetiredLeaseCount
    copy.nodeRemovalReleasedRetiredLeaseCount = this.facts.nodeRemovalReleasedRetiredLeaseCount
    return copy
  }

  cancel(epoch: number): void {
    if (epoch !== this.epoch) return
    this.expectedPageIndex = -1
    this.reloadConsumed = true
    this.facts.armed = false
  }

  private accepts(context: common.UIAbilityContext, surface: NextNReaderLegacyCacheLeaseSurface,
    pageIndex: number): boolean {
    return context.applicationInfo.debug && this.facts.armed && this.expectedSurface === surface &&
      this.expectedPageIndex === pageIndex
  }
}

export function connectNextNReaderLegacyCacheLeaseProbe(): NextNReaderLegacyCacheLeaseProbe {
  return AppStorageV2.connect(NextNReaderLegacyCacheLeaseProbe,
    (): NextNReaderLegacyCacheLeaseProbe => new NextNReaderLegacyCacheLeaseProbe())!
}
