import { ReaderEntryRect } from '@reader-kit/ui'

/** Live geometry checks; the existing root bridge owns the sole source snapshot. */
export class NextNReaderEntryPreviewCapture {
  static rect(uiContext: UIContext, componentId: string): ReaderEntryRect {
    const rect = uiContext.getComponentUtils().getRectangleById(componentId)
    return new ReaderEntryRect(uiContext.px2vp(rect.windowOffset.x), uiContext.px2vp(rect.windowOffset.y),
      uiContext.px2vp(rect.size.width), uiContext.px2vp(rect.size.height))
  }

  static sameRect(left: ReaderEntryRect, right: ReaderEntryRect): boolean {
    return left.valid() && right.valid() && left.x === right.x && left.y === right.y &&
      left.width === right.width && left.height === right.height
  }

}
