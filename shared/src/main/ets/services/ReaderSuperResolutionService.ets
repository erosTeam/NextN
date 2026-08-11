import { common } from '@kit.AbilityKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileIo } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { NhReaderSuperResolutionModel } from '../model/NhReaderSettings'
import {
  ReaderNativeSuperResolution,
  ReaderNativeSuperResolutionConfig,
  ReaderNativeSuperResolutionResult,
} from './ReaderNativeSuperResolution'
import {
  ReaderSuperResolutionModelPaths,
  ReaderSuperResolutionModelService,
} from './ReaderSuperResolutionModelService'

const CACHE_DIRECTORY: string = 'nextn-reader-super-resolution-cache'
const MAX_SOURCE_HEIGHT: number = 2000
const MAX_OUTPUT_EDGE: number = MAX_SOURCE_HEIGHT * 2
const MAX_OUTPUT_BYTES: number = MAX_OUTPUT_EDGE * MAX_OUTPUT_EDGE * 4
const MAX_CACHE_FILES: number = 64
const MAX_CACHE_BYTES: number = 256 * 1024 * 1024

export class ReaderSuperResolutionResult {
  displayUri: string = ''
  applied: boolean = false
  reason: string = ''
}

class CacheEntry {
  path: string = ''
  bytes: number = 0
  mtime: number = 0
}

class InFlightEnhancement {
  requestId: number = 0
  owners: Set<string> = new Set<string>()
  promise: Promise<ReaderSuperResolutionResult> = Promise.resolve(new ReaderSuperResolutionResult())
  sourcePath: string = ''
  startAction: () => Promise<ReaderSuperResolutionResult> =
    (): Promise<ReaderSuperResolutionResult> => Promise.resolve(new ReaderSuperResolutionResult())
  resolveTask: (result: ReaderSuperResolutionResult) => void =
    (_result: ReaderSuperResolutionResult): void => {}
}

/**
 * Converts a verified private Reader page into a private 2× derivative only
 * when the user has enabled enhancement and installed the model. The original
 * local page remains the immediate display and the failure fallback.
 */
export class ReaderSuperResolutionService {
  private static sequence: number = 0
  private static inFlight: Map<string, InFlightEnhancement> = new Map<string, InFlightEnhancement>()
  /**
   * PixelMap decode, RGBA copying, and native 2x output are all memory-heavy.
   * Reader leaf mounting may request more than one page at once, so this is a
   * process-wide single-flight queue rather than relying on the native
   * inference mutex after several decoded pixel buffers already coexist.
   */
  private static pending: InFlightEnhancement[] = []
  private static active: InFlightEnhancement | null = null

  static async process(
    context: common.UIAbilityContext,
    sourcePath: string,
    ownerKey: string,
    enabled: boolean,
    model: NhReaderSuperResolutionModel,
  ): Promise<ReaderSuperResolutionResult> {
    if (!enabled) {
      return ReaderSuperResolutionService.original(sourcePath, 'disabled')
    }
    if (sourcePath.length === 0 || ownerKey.length === 0) {
      return ReaderSuperResolutionService.original(sourcePath, 'source_unavailable')
    }
    const modelPaths: ReaderSuperResolutionModelPaths | null =
      await ReaderSuperResolutionModelService.pathsIfReady(context, model)
    const nativeConfig: ReaderNativeSuperResolutionConfig | null =
      ReaderSuperResolutionModelService.nativeConfig(model)
    if (modelPaths === null || nativeConfig === null) {
      return ReaderSuperResolutionService.original(sourcePath, 'model_not_installed')
    }
    const sourceKey: string = ReaderSuperResolutionService.sha256(sourcePath)
    if (sourceKey.length === 0) {
      return ReaderSuperResolutionService.original(sourcePath, 'source_hash_failed')
    }
    const outputPath: string = ReaderSuperResolutionService.outputPath(context, model, sourceKey)
    if (ReaderSuperResolutionService.fileSize(outputPath) > 0) {
      ReaderSuperResolutionService.touch(outputPath)
      return ReaderSuperResolutionService.applied(outputPath)
    }
    const existing: InFlightEnhancement | undefined = ReaderSuperResolutionService.inFlight.get(outputPath)
    if (existing !== undefined) {
      existing.owners.add(ownerKey)
      return await existing.promise
    }
    const inFlight: InFlightEnhancement = new InFlightEnhancement()
    ReaderSuperResolutionService.sequence += 1
    inFlight.requestId = ReaderSuperResolutionService.sequence
    inFlight.sourcePath = sourcePath
    inFlight.owners.add(ownerKey)
    const task: Promise<ReaderSuperResolutionResult> = new Promise<ReaderSuperResolutionResult>(
      (resolve: (result: ReaderSuperResolutionResult) => void): void => {
        inFlight.resolveTask = resolve
      },
    )
    inFlight.promise = task
    inFlight.startAction = (): Promise<ReaderSuperResolutionResult> => {
      return ReaderSuperResolutionService.processNow(
        context,
        sourcePath,
        outputPath,
        modelPaths,
        nativeConfig,
        inFlight,
      )
    }
    ReaderSuperResolutionService.inFlight.set(outputPath, inFlight)
    ReaderSuperResolutionService.pending.push(inFlight)
    ReaderSuperResolutionService.startNext()
    try {
      return await task
    } finally {
      if (ReaderSuperResolutionService.inFlight.get(outputPath) === inFlight) {
        ReaderSuperResolutionService.inFlight.delete(outputPath)
      }
    }
  }

  static releaseOwner(ownerKey: string): void {
    if (ownerKey.length === 0) {
      return
    }
    for (const inFlight of ReaderSuperResolutionService.inFlight.values()) {
      if (!inFlight.owners.delete(ownerKey)) {
        continue
      }
      if (inFlight.owners.size === 0) {
        ReaderNativeSuperResolution.setRequestActive(inFlight.requestId, false)
      }
    }
  }

  static setInteractionPaused(paused: boolean): void {
    ReaderNativeSuperResolution.setInteractionPaused(paused)
  }

  private static startNext(): void {
    if (ReaderSuperResolutionService.active !== null || ReaderSuperResolutionService.pending.length === 0) {
      return
    }
    const next: InFlightEnhancement = ReaderSuperResolutionService.pending.shift()!
    ReaderSuperResolutionService.active = next
    next.startAction().then((result: ReaderSuperResolutionResult): void => {
      next.resolveTask(result)
      ReaderSuperResolutionService.finish(next)
    }).catch((): void => {
      next.resolveTask(ReaderSuperResolutionService.original(next.sourcePath, 'processing_failed'))
      ReaderSuperResolutionService.finish(next)
    })
  }

  private static finish(task: InFlightEnhancement): void {
    if (ReaderSuperResolutionService.active !== task) {
      return
    }
    ReaderSuperResolutionService.active = null
    ReaderSuperResolutionService.startNext()
  }

  private static async processNow(
    context: common.UIAbilityContext,
    sourcePath: string,
    outputPath: string,
    modelPaths: ReaderSuperResolutionModelPaths,
    nativeConfig: ReaderNativeSuperResolutionConfig,
    inFlight: InFlightEnhancement,
  ): Promise<ReaderSuperResolutionResult> {
    const temporaryPath: string = `${outputPath}.part`
    let source: image.ImageSource | undefined = undefined
    let sourcePixelMap: image.PixelMap | undefined = undefined
    let outputPixelMap: image.PixelMap | undefined = undefined
    let packer: image.ImagePacker | undefined = undefined
    let outputFile: fileIo.File | null = null
    let promoted: boolean = false
    try {
      if (inFlight.owners.size === 0) {
        return ReaderSuperResolutionService.original(sourcePath, 'superseded')
      }
      source = image.createImageSource(sourcePath)
      const info: image.ImageInfo = await source.getImageInfo()
      const width: number = info.size.width
      const height: number = info.size.height
      if (width <= 0 || height <= 0) {
        return ReaderSuperResolutionService.original(sourcePath, 'invalid_dimensions')
      }
      if (height > MAX_SOURCE_HEIGHT || width > MAX_SOURCE_HEIGHT) {
        return ReaderSuperResolutionService.original(sourcePath, 'source_too_large')
      }
      const outputWidth: number = width * 2
      const outputHeight: number = height * 2
      if (outputWidth > MAX_OUTPUT_EDGE || outputHeight > MAX_OUTPUT_EDGE ||
        outputWidth * outputHeight * 4 > MAX_OUTPUT_BYTES) {
        return ReaderSuperResolutionService.original(sourcePath, 'output_too_large')
      }
      const options: image.DecodingOptions = {
        editable: false,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
      }
      sourcePixelMap = await source.createPixelMap(options)
      if (inFlight.owners.size === 0) {
        return ReaderSuperResolutionService.original(sourcePath, 'superseded')
      }
      const decoded: image.ImageInfo = await sourcePixelMap.getImageInfo()
      const pixels: ArrayBuffer = new ArrayBuffer(sourcePixelMap.getPixelBytesNumber())
      await sourcePixelMap.readPixelsToBuffer(pixels)
      const stride: number = Math.max(Math.floor(decoded.stride), width * 4)
      const native: ReaderNativeSuperResolutionResult = await ReaderNativeSuperResolution.upscaleRgba(
        pixels,
        width,
        height,
        stride,
        modelPaths.paramPath,
        modelPaths.modelPath,
        nativeConfig,
        inFlight.requestId,
      )
      if (inFlight.owners.size === 0 || native.pixels.byteLength !== outputWidth * outputHeight * 4) {
        return ReaderSuperResolutionService.original(sourcePath, 'superseded')
      }
      const initialization: image.InitializationOptions = {
        size: { width: outputWidth, height: outputHeight },
        srcPixelFormat: image.PixelMapFormat.RGBA_8888,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: false,
      }
      outputPixelMap = await image.createPixelMap(native.pixels, initialization)
      ReaderSuperResolutionService.ensureDirectory(ReaderSuperResolutionService.cacheDirectory(context))
      ReaderSuperResolutionService.removeIfExists(temporaryPath)
      outputFile = fileIo.openSync(
        temporaryPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      packer = image.createImagePacker()
      await packer.packToFile(outputPixelMap, outputFile.fd, { format: 'image/jpeg', quality: 98 })
      fileIo.closeSync(outputFile)
      outputFile = null
      if (inFlight.owners.size === 0) {
        return ReaderSuperResolutionService.original(sourcePath, 'superseded')
      }
      ReaderSuperResolutionService.removeIfExists(outputPath)
      fileIo.renameSync(temporaryPath, outputPath)
      if (ReaderSuperResolutionService.fileSize(outputPath) <= 0) {
        ReaderSuperResolutionService.removeIfExists(outputPath)
        return ReaderSuperResolutionService.original(sourcePath, 'output_empty')
      }
      promoted = true
      await ReaderSuperResolutionService.prune(context, outputPath)
      return ReaderSuperResolutionService.applied(outputPath)
    } catch (_error) {
      return ReaderSuperResolutionService.original(sourcePath, 'processing_failed')
    } finally {
      if (outputFile !== null) {
        try {
          fileIo.closeSync(outputFile)
        } catch (_error) {}
      }
      if (!promoted) {
        ReaderSuperResolutionService.removeIfExists(temporaryPath)
      }
      if (packer !== undefined) {
        await packer.release()
      }
      if (outputPixelMap !== undefined) {
        await outputPixelMap.release()
      }
      if (sourcePixelMap !== undefined) {
        await sourcePixelMap.release()
      }
      if (source !== undefined) {
        await source.release()
      }
    }
  }

  private static original(sourcePath: string, reason: string): ReaderSuperResolutionResult {
    const result: ReaderSuperResolutionResult = new ReaderSuperResolutionResult()
    result.displayUri = ReaderSuperResolutionService.displayUri(sourcePath)
    result.reason = reason
    return result
  }

  private static applied(path: string): ReaderSuperResolutionResult {
    const result: ReaderSuperResolutionResult = new ReaderSuperResolutionResult()
    result.displayUri = ReaderSuperResolutionService.displayUri(path)
    result.applied = true
    result.reason = 'applied'
    return result
  }

  private static cacheDirectory(context: common.UIAbilityContext): string {
    if (context.cacheDir.length === 0) {
      throw new Error('Private enhancement cache is unavailable.')
    }
    return `${context.cacheDir}/${CACHE_DIRECTORY}`
  }

  private static outputPath(
    context: common.UIAbilityContext,
    model: NhReaderSuperResolutionModel,
    sourceKey: string,
  ): string {
    const directory: string = ReaderSuperResolutionService.cacheDirectory(context)
    ReaderSuperResolutionService.ensureDirectory(directory)
    return `${directory}/${model}_${sourceKey}.jpg`
  }

  private static async prune(context: common.UIAbilityContext, protectedPath: string): Promise<void> {
    const entries: CacheEntry[] = []
    const directory: string = ReaderSuperResolutionService.cacheDirectory(context)
    try {
      const names: string[] = fileIo.listFileSync(directory)
      for (let index: number = 0; index < names.length; index++) {
        const path: string = `${directory}/${names[index]}`
        if (names[index].endsWith('.part')) {
          ReaderSuperResolutionService.removeIfExists(path)
          continue
        }
        if (!names[index].endsWith('.jpg')) {
          continue
        }
        const stat: fileIo.Stat = fileIo.statSync(path)
        if (stat.size > 0) {
          const entry: CacheEntry = new CacheEntry()
          entry.path = path
          entry.bytes = stat.size
          entry.mtime = stat.mtime
          entries.push(entry)
        }
      }
    } catch (_error) {
      return
    }
    entries.sort((left: CacheEntry, right: CacheEntry): number => left.mtime - right.mtime)
    let bytes: number = 0
    for (let index: number = 0; index < entries.length; index++) {
      bytes += entries[index].bytes
    }
    for (let index: number = 0; index < entries.length &&
      (bytes > MAX_CACHE_BYTES || entries.length - index > MAX_CACHE_FILES); index++) {
      if (entries[index].path === protectedPath) {
        continue
      }
      ReaderSuperResolutionService.removeIfExists(entries[index].path)
      bytes -= entries[index].bytes
    }
  }

  private static ensureDirectory(path: string): void {
    try {
      fileIo.mkdirSync(path, true)
    } catch (error) {
      if (!fileIo.accessSync(path)) {
        throw error as Error
      }
    }
  }

  private static fileSize(path: string): number {
    try {
      return fileIo.statSync(path).size
    } catch (_error) {
      return 0
    }
  }

  private static touch(path: string): void {
    try {
      fileIo.utimes(path, Date.now())
    } catch (_error) {}
  }

  private static removeIfExists(path: string): void {
    try {
      fileIo.unlinkSync(path)
    } catch (_error) {}
  }

  private static displayUri(path: string): string {
    if (path.startsWith('file://')) {
      return path
    }
    return path.startsWith('/') ? `file://${path}` : `file:///${path}`
  }

  private static sha256(path: string): string {
    const digest = cryptoFramework.createMd('SHA256')
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
      while (true) {
        const buffer: ArrayBuffer = new ArrayBuffer(128 * 1024)
        const read: number = fileIo.readSync(file.fd, buffer, { length: buffer.byteLength })
        if (read <= 0) {
          break
        }
        digest.updateSync({ data: new Uint8Array(buffer, 0, read) })
      }
      const bytes: Uint8Array = new Uint8Array(digest.digestSync().data)
      let output: string = ''
      for (let index: number = 0; index < bytes.length; index++) {
        output += bytes[index].toString(16).padStart(2, '0')
      }
      return output
    } catch (_error) {
      return ''
    } finally {
      if (file !== null) {
        fileIo.closeSync(file)
      }
    }
  }
}
