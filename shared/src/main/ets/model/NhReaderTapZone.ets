/**
 * Reader tap zones are a local presentation preference.  Regions describe
 * physical geometry; actions remain canonical source-page operations so RTL
 * direction is resolved by the Reader controller rather than by mirroring an
 * action at the tap site.
 */
export enum NhReaderTapZoneLayout {
  RIGHT_LEFT = 'rightLeft',
  L_SHAPED = 'lShaped',
  KINDLE = 'kindle',
  EDGE = 'edge',
}

export enum NhReaderTapZoneInvert {
  NONE = 'none',
  HORIZONTAL = 'horizontal',
  VERTICAL = 'vertical',
  BOTH = 'both',
}

export enum NhReaderTapZoneAction {
  MENU = 'menu',
  PREVIOUS = 'previous',
  NEXT = 'next',
  LEFT = 'left',
  RIGHT = 'right',
}

/** A normalized Reader viewport rectangle with its semantic action. */
export class NhReaderTapZoneRegion {
  key: string
  left: number
  top: number
  right: number
  bottom: number
  action: NhReaderTapZoneAction

  constructor(
    key: string,
    left: number,
    top: number,
    right: number,
    bottom: number,
    action: NhReaderTapZoneAction,
  ) {
    this.key = key
    this.left = left
    this.top = top
    this.right = right
    this.bottom = bottom
    this.action = action
  }
}

/**
 * NextE's normalized tap-zone grammar, shared by Reader hit testing and the
 * settings preference boundary. Inversion transforms geometry only; it never
 * changes PREVIOUS/NEXT/LEFT/RIGHT semantic actions.
 */
export class NhReaderTapZoneResolver {
  static normalizeLayout(value: string): NhReaderTapZoneLayout {
    if (value === NhReaderTapZoneLayout.L_SHAPED ||
      value === NhReaderTapZoneLayout.KINDLE ||
      value === NhReaderTapZoneLayout.EDGE ||
      value === NhReaderTapZoneLayout.RIGHT_LEFT) {
      return value as NhReaderTapZoneLayout
    }
    return NhReaderTapZoneLayout.RIGHT_LEFT
  }

  static normalizeInvert(value: string): NhReaderTapZoneInvert {
    if (value === NhReaderTapZoneInvert.HORIZONTAL ||
      value === NhReaderTapZoneInvert.VERTICAL ||
      value === NhReaderTapZoneInvert.BOTH ||
      value === NhReaderTapZoneInvert.NONE) {
      return value as NhReaderTapZoneInvert
    }
    return NhReaderTapZoneInvert.NONE
  }

  static regions(
    layout: NhReaderTapZoneLayout,
    invert: NhReaderTapZoneInvert,
  ): NhReaderTapZoneRegion[] {
    const base: NhReaderTapZoneRegion[] = NhReaderTapZoneResolver.baseRegions(
      NhReaderTapZoneResolver.normalizeLayout(layout),
    )
    const normalizedInvert: NhReaderTapZoneInvert = NhReaderTapZoneResolver.normalizeInvert(invert)
    if (normalizedInvert === NhReaderTapZoneInvert.NONE) {
      return base
    }
    const regions: NhReaderTapZoneRegion[] = []
    for (let index: number = 0; index < base.length; index++) {
      regions.push(NhReaderTapZoneResolver.invertRegion(base[index], normalizedInvert))
    }
    return regions
  }

  static resolve(
    layout: NhReaderTapZoneLayout,
    invert: NhReaderTapZoneInvert,
    x: number,
    y: number,
    width: number,
    height: number,
  ): NhReaderTapZoneAction {
    if (width <= 0 || height <= 0) {
      return NhReaderTapZoneAction.MENU
    }
    const normalizedX: number = NhReaderTapZoneResolver.clamp01(x / width)
    const normalizedY: number = NhReaderTapZoneResolver.clamp01(y / height)
    const regions: NhReaderTapZoneRegion[] = NhReaderTapZoneResolver.regions(layout, invert)
    for (let index: number = 0; index < regions.length; index++) {
      if (NhReaderTapZoneResolver.contains(regions[index], normalizedX, normalizedY)) {
        return regions[index].action
      }
    }
    return NhReaderTapZoneAction.MENU
  }

  private static baseRegions(layout: NhReaderTapZoneLayout): NhReaderTapZoneRegion[] {
    const oneThird: number = 1 / 3
    const twoThirds: number = 2 / 3
    if (layout === NhReaderTapZoneLayout.L_SHAPED) {
      return [
        new NhReaderTapZoneRegion('l-prev-top', 0, 0, 1, oneThird, NhReaderTapZoneAction.PREVIOUS),
        new NhReaderTapZoneRegion('l-prev-left', 0, oneThird, oneThird, twoThirds, NhReaderTapZoneAction.PREVIOUS),
        new NhReaderTapZoneRegion('l-menu', oneThird, oneThird, twoThirds, twoThirds, NhReaderTapZoneAction.MENU),
        new NhReaderTapZoneRegion('l-next-right', twoThirds, oneThird, 1, twoThirds, NhReaderTapZoneAction.NEXT),
        new NhReaderTapZoneRegion('l-next-bottom', 0, twoThirds, 1, 1, NhReaderTapZoneAction.NEXT),
      ]
    }
    if (layout === NhReaderTapZoneLayout.KINDLE) {
      return [
        new NhReaderTapZoneRegion('kindle-menu', 0, 0, 1, oneThird, NhReaderTapZoneAction.MENU),
        new NhReaderTapZoneRegion('kindle-prev', 0, oneThird, oneThird, 1, NhReaderTapZoneAction.PREVIOUS),
        new NhReaderTapZoneRegion('kindle-next', oneThird, oneThird, 1, 1, NhReaderTapZoneAction.NEXT),
      ]
    }
    if (layout === NhReaderTapZoneLayout.EDGE) {
      return [
        new NhReaderTapZoneRegion('edge-next-left', 0, 0, oneThird, 1, NhReaderTapZoneAction.NEXT),
        new NhReaderTapZoneRegion('edge-menu', oneThird, 0, twoThirds, twoThirds, NhReaderTapZoneAction.MENU),
        new NhReaderTapZoneRegion('edge-prev', oneThird, twoThirds, twoThirds, 1, NhReaderTapZoneAction.PREVIOUS),
        new NhReaderTapZoneRegion('edge-next-right', twoThirds, 0, 1, 1, NhReaderTapZoneAction.NEXT),
      ]
    }
    return [
      new NhReaderTapZoneRegion('right-left-left', 0, 0, oneThird, 1, NhReaderTapZoneAction.LEFT),
      new NhReaderTapZoneRegion('right-left-menu', oneThird, 0, twoThirds, 1, NhReaderTapZoneAction.MENU),
      new NhReaderTapZoneRegion('right-left-right', twoThirds, 0, 1, 1, NhReaderTapZoneAction.RIGHT),
    ]
  }

  private static invertRegion(
    region: NhReaderTapZoneRegion,
    invert: NhReaderTapZoneInvert,
  ): NhReaderTapZoneRegion {
    const horizontal: boolean = invert === NhReaderTapZoneInvert.HORIZONTAL || invert === NhReaderTapZoneInvert.BOTH
    const vertical: boolean = invert === NhReaderTapZoneInvert.VERTICAL || invert === NhReaderTapZoneInvert.BOTH
    const left: number = horizontal ? 1 - region.right : region.left
    const right: number = horizontal ? 1 - region.left : region.right
    const top: number = vertical ? 1 - region.bottom : region.top
    const bottom: number = vertical ? 1 - region.top : region.bottom
    return new NhReaderTapZoneRegion(
      `${region.key}-${invert}`,
      left,
      top,
      right,
      bottom,
      region.action,
    )
  }

  private static contains(region: NhReaderTapZoneRegion, x: number, y: number): boolean {
    const withinX: boolean = x >= region.left && (x < region.right || region.right === 1)
    const withinY: boolean = y >= region.top && (y < region.bottom || region.bottom === 1)
    return withinX && withinY
  }

  private static clamp01(value: number): number {
    return Math.min(1, Math.max(0, value))
  }
}
