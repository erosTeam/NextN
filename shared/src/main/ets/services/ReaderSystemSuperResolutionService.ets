import { image } from '@kit.ImageKit'
import { deviceInfo } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { imageSuperResolution, visionBase } from '@kit.CoreVisionKit'

class ReaderSystemDecodedSource {
  pixelMap: image.PixelMap
  width: number = 0
  height: number = 0

  constructor(pixelMap: image.PixelMap, width: number, height: number) {
    this.pixelMap = pixelMap
    this.width = width
    this.height = height
  }
}

class ReaderSystemImageData implements visionBase.ImageData {
  pixelMap: image.PixelMap

  constructor(pixelMap: image.PixelMap) {
    this.pixelMap = pixelMap
  }
}

/**
 * Serial Core Vision image super-resolution backend for Reader pages.
 * The analyzer is reused and requests stay single-flight because the
 * platform capability does not allow concurrent work on one feature.
 */
export class ReaderSystemSuperResolutionService {
  private static queue: Promise<void> = Promise.resolve()
  private static analyzer: imageSuperResolution.ImageSRAnalyzer | null = null
  private static readonly LOG_DOMAIN: number = 0x0000
  private static readonly LOG_TAG: string = 'NextNSystemSR'

  private static describeError(error: Object): string {
    return error instanceof Error ? error.name + ': ' + error.message : JSON.stringify(error)
  }

  static process(sourcePath: string, maxSourceHeight: number): Promise<image.PixelMap | undefined> {
    const task: Promise<image.PixelMap | undefined> = ReaderSystemSuperResolutionService.queue.then(
      (): Promise<image.PixelMap | undefined> => {
        return ReaderSystemSuperResolutionService.processSerial(sourcePath, maxSourceHeight)
      },
    )
    ReaderSystemSuperResolutionService.queue = task.then(
      (): void => {},
      (): void => {},
    )
    return task
  }

  private static async processSerial(
    sourcePath: string,
    maxSourceHeight: number,
  ): Promise<image.PixelMap | undefined> {
    let sourcePixelMap: image.PixelMap | undefined = undefined
    let outputPixelMap: image.PixelMap | undefined = undefined
    try {
      const decoded: ReaderSystemDecodedSource =
        await ReaderSystemSuperResolutionService.decodeSourcePixelMap(sourcePath, maxSourceHeight)
      sourcePixelMap = decoded.pixelMap
      const analyzer: imageSuperResolution.ImageSRAnalyzer =
        await ReaderSystemSuperResolutionService.ensureAnalyzer()
      // Keep the API-26 calls lexically inside direct positive gates: the
      // compatibility checker is lexical and does not follow callers.
      if (deviceInfo.apiAvailable('26.0.0') &&
        canIUse('SystemCapability.AI.Vision.VisionBase')) {
        // Official Core Vision pattern: the request is a typed literal;
        // the runtime export has no callable constructor.
        const request: visionBase.Request = {
          inputData: new ReaderSystemImageData(decoded.pixelMap),
        }
        const response: imageSuperResolution.ISPResponse = await analyzer.process(request)
        outputPixelMap = response.pixelMap
      }
      await sourcePixelMap.release()
      sourcePixelMap = undefined
      return outputPixelMap
    } catch (error) {
      hilog.error(
        ReaderSystemSuperResolutionService.LOG_DOMAIN,
        ReaderSystemSuperResolutionService.LOG_TAG,
        'system super-resolution failed: %{public}s',
        ReaderSystemSuperResolutionService.describeError(error),
      )
      // A failed analyzer may retain a corrupted service session; drop it
      // so the next page lazily rebuilds instead of poisoning the whole app.
      const failedAnalyzer: imageSuperResolution.ImageSRAnalyzer | null =
        ReaderSystemSuperResolutionService.analyzer
      ReaderSystemSuperResolutionService.analyzer = null
      if (failedAnalyzer !== null && deviceInfo.apiAvailable('26.0.0') &&
        canIUse('SystemCapability.AI.Vision.VisionBase')) {
        try {
          await failedAnalyzer.destroy()
        } catch (_destroyError) {}
      }
      if (outputPixelMap !== undefined) {
        try {
          await outputPixelMap.release()
        } catch (_releaseError) {}
      }
      return undefined
    } finally {
      if (sourcePixelMap !== undefined) {
        try {
          await sourcePixelMap.release()
        } catch (_releaseError) {}
      }
    }
  }

  private static async ensureAnalyzer(): Promise<imageSuperResolution.ImageSRAnalyzer> {
    if (ReaderSystemSuperResolutionService.analyzer !== null) {
      return ReaderSystemSuperResolutionService.analyzer
    }
    if (deviceInfo.apiAvailable('26.0.0') &&
      canIUse('SystemCapability.AI.Vision.VisionBase')) {
      const analyzer: imageSuperResolution.ImageSRAnalyzer =
        await imageSuperResolution.ImageSRAnalyzer.create()
      ReaderSystemSuperResolutionService.analyzer = analyzer
      return analyzer
    }
    throw new Error('Reader system super-resolution is unsupported')
  }

  private static async decodeSourcePixelMap(
    sourcePath: string,
    maxSourceHeight: number,
  ): Promise<ReaderSystemDecodedSource> {
    let source: image.ImageSource | undefined = undefined
    let pixelMap: image.PixelMap | undefined = undefined
    try {
      source = image.createImageSource(sourcePath)
      const sourceInfo: image.ImageInfo = await source.getImageInfo()
      const sourceWidth: number = sourceInfo.size.width
      const sourceHeight: number = sourceInfo.size.height
      if (sourceWidth <= 0 || sourceHeight <= 0) {
        throw new Error('Reader system super-resolution decode failed')
      }
      const longestEdge: number = Math.max(sourceWidth, sourceHeight)
      const scale: number = longestEdge > maxSourceHeight ? maxSourceHeight / longestEdge : 1
      const decodeOptions: image.DecodingOptions = {
        editable: false,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
      }
      if (scale < 1) {
        const desiredSize: image.Size = {
          width: Math.max(1, Math.round(sourceWidth * scale)),
          height: Math.max(1, Math.round(sourceHeight * scale)),
        }
        decodeOptions.desiredSize = desiredSize
      }
      pixelMap = await source.createPixelMap(decodeOptions)
      if (pixelMap === undefined) {
        throw new Error('Reader system super-resolution decode failed')
      }
      try {
        const info: image.ImageInfo = await pixelMap.getImageInfo()
        if (info.size.width > maxSourceHeight || info.size.height > maxSourceHeight) {
          throw new Error('Reader system super-resolution decode failed')
        }
        const decoded: ReaderSystemDecodedSource =
          new ReaderSystemDecodedSource(pixelMap, info.size.width, info.size.height)
        pixelMap = undefined
        return decoded
      } finally {
        if (pixelMap !== undefined) {
          try {
            await pixelMap.release()
          } catch (_releaseError) {}
        }
      }
    } finally {
      if (source !== undefined) {
        try {
          await source.release()
        } catch (_error) {}
      }
    }
  }
}
