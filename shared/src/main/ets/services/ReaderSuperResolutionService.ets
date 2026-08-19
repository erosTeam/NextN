import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileIo } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  NhReaderSuperResolutionModel,
  READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT,
  READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT_CHOICES,
} from '../model/NhReaderSettings'
import {
  ReaderNativeSuperResolution,
  ReaderNativeSuperResolutionCapabilities,
  ReaderNativeSuperResolutionConfig,
  ReaderNativeSuperResolutionResult,
} from './ReaderNativeSuperResolution'
import {
  ReaderSuperResolutionModelPaths,
  ReaderSuperResolutionModelService,
} from './ReaderSuperResolutionModelService'

const CACHE_DIRECTORY: string = 'nextn-reader-super-resolution-cache'
const MAX_OUTPUT_EDGE: number = READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT * 2
const MAX_OUTPUT_BYTES: number = MAX_OUTPUT_EDGE * MAX_OUTPUT_EDGE * 4
const MAX_CACHE_FILES: number = 64
const MAX_CACHE_BYTES: number = 256 * 1024 * 1024
const READER_ENHANCEMENT_LOG_DOMAIN: number = 0x0000
const READER_ENHANCEMENT_LOG_TAG: string = 'NextNReaderEnhancement'
// Bump only when native decode/upscale/output semantics change. Model asset
// and native-config changes are included separately by the model service.
const DERIVATIVE_OUTPUT_PIPELINE_VERSION: string = 'native-rgba-jpeg-v1'
// Vulkan 1.3 is the conservative interaction-safety boundary used by NextE.
const INTERACTION_SAFE_VULKAN_API_VERSION: number = 0x00403000

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
}

/**
 * Converts a verified private Reader page into a private 2× derivative only
 * when the user has enabled enhancement and installed the model. The original
 * local page remains the immediate display and the failure fallback.
 */
export class ReaderSuperResolutionService {
  private static sequence: number = 0
  private static inFlight: Map<string, InFlightEnhancement> = new Map<string, InFlightEnhancement>()
  /** Fixed outcome codes for mounted Reader owners; never file paths or image data. */
  private static ownerOutcomeReasons: Map<string, string> = new Map<string, string>()
  private static interactionPauseRequested: boolean = false
  private static interactionPaused: boolean = false
  private static interactionProtectionRequired: boolean = true

  static clearOwnerOutcome(ownerKey: string): void {
    if (ownerKey.length > 0) {
      ReaderSuperResolutionService.ownerOutcomeReasons.delete(ownerKey)
    }
  }

  static ownerOutcomeReason(ownerKey: string): string {
    return ownerKey.length === 0
      ? ''
      : (ReaderSuperResolutionService.ownerOutcomeReasons.get(ownerKey) ?? '')
  }

  static async process(
    context: common.UIAbilityContext,
    sourcePath: string,
    ownerKey: string,
    enabled: boolean,
    model: NhReaderSuperResolutionModel,
    maxSourceHeight: number,
  ): Promise<ReaderSuperResolutionResult> {
    ReaderSuperResolutionService.clearOwnerOutcome(ownerKey)
    if (!enabled) {
      return ReaderSuperResolutionService.rememberOwnerOutcome(
        ownerKey,
        ReaderSuperResolutionService.original(sourcePath, 'disabled'),
      )
    }
    if (sourcePath.length === 0 || ownerKey.length === 0) {
      return ReaderSuperResolutionService.rememberOwnerOutcome(
        ownerKey,
        ReaderSuperResolutionService.original(sourcePath, 'source_unavailable'),
      )
    }
    const modelPaths: ReaderSuperResolutionModelPaths | null =
      await ReaderSuperResolutionModelService.pathsIfReady(context, model)
    const nativeConfig: ReaderNativeSuperResolutionConfig | null =
      ReaderSuperResolutionModelService.nativeConfig(model)
    if (modelPaths === null || nativeConfig === null) {
      return ReaderSuperResolutionService.rememberOwnerOutcome(
        ownerKey,
        ReaderSuperResolutionService.original(sourcePath, 'model_not_installed'),
      )
    }
    const normalizedMaxSourceHeight: number = ReaderSuperResolutionService.normalizeMaxSourceHeight(maxSourceHeight)
    const sourceKey: string = ReaderSuperResolutionService.sha256(sourcePath)
    if (sourceKey.length === 0) {
      return ReaderSuperResolutionService.rememberOwnerOutcome(
        ownerKey,
        ReaderSuperResolutionService.original(sourcePath, 'source_hash_failed'),
      )
    }
    const outputPath: string = ReaderSuperResolutionService.outputPath(
      context,
      ReaderSuperResolutionService.derivativeCacheIdentity(
        model,
        normalizedMaxSourceHeight,
        sourceKey,
      ),
    )
    if (ReaderSuperResolutionService.fileSize(outputPath) > 0) {
      ReaderSuperResolutionService.touch(outputPath)
      return ReaderSuperResolutionService.rememberOwnerOutcome(
        ownerKey,
        ReaderSuperResolutionService.applied(outputPath),
      )
    }
    const existing: InFlightEnhancement | undefined = ReaderSuperResolutionService.inFlight.get(outputPath)
    if (existing !== undefined) {
      existing.owners.add(ownerKey)
      return ReaderSuperResolutionService.rememberOwnerOutcome(ownerKey, await existing.promise)
    }
    const inFlight: InFlightEnhancement = new InFlightEnhancement()
    ReaderSuperResolutionService.sequence += 1
    inFlight.requestId = ReaderSuperResolutionService.sequence
    inFlight.owners.add(ownerKey)
    const task: Promise<ReaderSuperResolutionResult> = ReaderSuperResolutionService.processNow(
      context,
      sourcePath,
      sourceKey,
      outputPath,
      modelPaths,
      nativeConfig,
      normalizedMaxSourceHeight,
      inFlight,
    )
    inFlight.promise = task
    ReaderSuperResolutionService.inFlight.set(outputPath, inFlight)
    try {
      return ReaderSuperResolutionService.rememberOwnerOutcome(ownerKey, await task)
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
    ReaderSuperResolutionService.clearOwnerOutcome(ownerKey)
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
    ReaderSuperResolutionService.interactionPauseRequested = paused
    ReaderSuperResolutionService.applyInteractionPause()
  }

  private static configureInteractionProtection(backend: string): void {
    let gpuName: string = ''
    let vulkanApiVersion: number = 0
    try {
      const capabilities: ReaderNativeSuperResolutionCapabilities =
        ReaderNativeSuperResolution.capabilities()
      gpuName = capabilities.gpuName.trim()
      vulkanApiVersion = capabilities.vulkanApiVersion
    } catch (_error) {
      gpuName = ''
      vulkanApiVersion = 0
    }
    const supportsConcurrentVulkanInteraction: boolean = backend === 'vulkan' &&
      vulkanApiVersion >= INTERACTION_SAFE_VULKAN_API_VERSION
    ReaderSuperResolutionService.setInteractionProtectionRequired(!supportsConcurrentVulkanInteraction)
    hilog.info(
      READER_ENHANCEMENT_LOG_DOMAIN,
      READER_ENHANCEMENT_LOG_TAG,
      'interaction_policy backend=%{public}s gpu=%{public}s pauseDuringInteraction=%{public}s',
      backend,
      gpuName.length > 0 ? gpuName : 'unknown',
      String(!supportsConcurrentVulkanInteraction),
    )
  }

  private static setInteractionProtectionRequired(required: boolean): void {
    ReaderSuperResolutionService.interactionProtectionRequired = required
    ReaderSuperResolutionService.applyInteractionPause()
  }

  private static applyInteractionPause(): void {
    const effectivePaused: boolean = ReaderSuperResolutionService.interactionPauseRequested &&
      ReaderSuperResolutionService.interactionProtectionRequired
    if (ReaderSuperResolutionService.interactionPaused === effectivePaused) {
      return
    }
    ReaderSuperResolutionService.interactionPaused = effectivePaused
    ReaderNativeSuperResolution.setInteractionPaused(effectivePaused)
  }

  private static rememberOwnerOutcome(
    ownerKey: string,
    result: ReaderSuperResolutionResult,
  ): ReaderSuperResolutionResult {
    if (ownerKey.length > 0) {
      ReaderSuperResolutionService.ownerOutcomeReasons.set(ownerKey, result.reason)
    }
    return result
  }

  private static async processNow(
    context: common.UIAbilityContext,
    sourcePath: string,
    sourceKey: string,
    outputPath: string,
    modelPaths: ReaderSuperResolutionModelPaths,
    nativeConfig: ReaderNativeSuperResolutionConfig,
    maxSourceHeight: number,
    inFlight: InFlightEnhancement,
  ): Promise<ReaderSuperResolutionResult> {
    const temporaryPath: string = `${outputPath}.part`
    let outputPixelMap: image.PixelMap | undefined = undefined
    let packer: image.ImagePacker | undefined = undefined
    let outputFile: fileIo.File | null = null
    let promoted: boolean = false
    let processingStage: string = 'native_decode'
    try {
      const decoded = await ReaderNativeSuperResolution.decodeImageRgba(sourcePath, maxSourceHeight)
      // A forced Reader retry can atomically replace this path while native
      // decode is pending; never promote decoded bytes under the earlier key.
      const decodedSourceKey: string = ReaderSuperResolutionService.sha256(sourcePath)
      if (decodedSourceKey.length === 0) {
        return ReaderSuperResolutionService.original(sourcePath, 'source_hash_failed')
      }
      if (decodedSourceKey !== sourceKey) {
        return ReaderSuperResolutionService.original(sourcePath, 'source_changed')
      }
      const width: number = decoded.width
      const height: number = decoded.height
      if (width <= 0 || height <= 0) {
        return ReaderSuperResolutionService.original(sourcePath, 'invalid_dimensions')
      }
      if (height > maxSourceHeight || width > maxSourceHeight) {
        return ReaderSuperResolutionService.original(sourcePath, 'source_too_large')
      }
      const outputWidth: number = width * 2
      const outputHeight: number = height * 2
      if (outputWidth > MAX_OUTPUT_EDGE || outputHeight > MAX_OUTPUT_EDGE ||
        outputWidth * outputHeight * 4 > MAX_OUTPUT_BYTES) {
        return ReaderSuperResolutionService.original(sourcePath, 'output_too_large')
      }
      processingStage = 'native_upscale'
      const native: ReaderNativeSuperResolutionResult = await ReaderNativeSuperResolution.upscaleRgba(
        decoded.pixels,
        width,
        height,
        decoded.stride,
        modelPaths.paramPath,
        modelPaths.modelPath,
        nativeConfig,
        inFlight.requestId,
      )
      if (inFlight.owners.size === 0 || native.pixels.byteLength !== outputWidth * outputHeight * 4) {
        return ReaderSuperResolutionService.original(sourcePath, 'superseded')
      }
      ReaderSuperResolutionService.configureInteractionProtection(native.backend)
      const initialization: image.InitializationOptions = {
        size: { width: outputWidth, height: outputHeight },
        srcPixelFormat: image.PixelMapFormat.RGBA_8888,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: false,
      }
      processingStage = 'output_pixel_map'
      outputPixelMap = await image.createPixelMap(native.pixels, initialization)
      ReaderSuperResolutionService.ensureDirectory(ReaderSuperResolutionService.cacheDirectory(context))
      ReaderSuperResolutionService.removeIfExists(temporaryPath)
      processingStage = 'output_file'
      outputFile = fileIo.openSync(
        temporaryPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      packer = image.createImagePacker()
      processingStage = 'output_pack'
      await packer.packToFile(outputPixelMap, outputFile.fd, { format: 'image/jpeg', quality: 98 })
      fileIo.closeSync(outputFile)
      outputFile = null
      if (inFlight.owners.size === 0) {
        return ReaderSuperResolutionService.original(sourcePath, 'superseded')
      }
      processingStage = 'output_promote'
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
      ReaderSuperResolutionService.recordProcessingFailure(processingStage)
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
        try {
          await packer.release()
        } catch (_error) {
          ReaderSuperResolutionService.recordProcessingFailure('output_packer_release')
        }
      }
      if (outputPixelMap !== undefined) {
        try {
          await outputPixelMap.release()
        } catch (_error) {
          ReaderSuperResolutionService.recordProcessingFailure('output_pixel_map_release')
        }
      }
    }
  }

  /** Emits a fixed stage only; image paths, page bytes, and model data never enter logs. */
  private static recordProcessingFailure(stage: string): void {
    try {
      hilog.warn(
        READER_ENHANCEMENT_LOG_DOMAIN,
        READER_ENHANCEMENT_LOG_TAG,
        'reader enhancement failed at stage=%{public}s',
        stage,
      )
    } catch (_error) {}
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
      throw new Error('Private enhancement cache is unavailable')
    }
    return `${context.cacheDir}/${CACHE_DIRECTORY}`
  }

  private static derivativeCacheIdentity(
    model: NhReaderSuperResolutionModel,
    maxSourceHeight: number,
    sourceKey: string,
  ): string {
    return JSON.stringify([
      DERIVATIVE_OUTPUT_PIPELINE_VERSION,
      ReaderSuperResolutionModelService.derivativeCacheIdentity(model),
      `${maxSourceHeight}`,
      sourceKey,
    ])
  }

  private static outputPath(context: common.UIAbilityContext, identity: string): string {
    const directory: string = ReaderSuperResolutionService.cacheDirectory(context)
    ReaderSuperResolutionService.ensureDirectory(directory)
    return `${directory}/${ReaderSuperResolutionService.hashText(identity)}.jpg`
  }

  private static normalizeMaxSourceHeight(value: number): number {
    const normalized: number = Math.round(value)
    for (let index: number = 0; index < READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT_CHOICES.length; index++) {
      if (normalized === READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT_CHOICES[index]) {
        return normalized
      }
    }
    return READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT
  }

  private static async prune(context: common.UIAbilityContext, protectedPath: string): Promise<void> {
    const entries: CacheEntry[] = []
    const directory: string = ReaderSuperResolutionService.cacheDirectory(context)
    try {
      const names: string[] = fileIo.listFileSync(directory)
      for (let index: number = 0; index < names.length; index++) {
        const path: string = `${directory}/${names[index]}`
        if (names[index].endsWith('.part')) {
          const finalPath: string = path.substring(0, path.length - '.part'.length)
          if (!ReaderSuperResolutionService.inFlight.has(finalPath)) {
            ReaderSuperResolutionService.removeIfExists(path)
          }
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

  private static hashText(value: string): string {
    const digest = cryptoFramework.createMd('SHA256')
    digest.updateSync({ data: new util.TextEncoder().encodeInto(value) })
    const bytes: Uint8Array = new Uint8Array(digest.digestSync().data)
    let output: string = ''
    for (let index: number = 0; index < bytes.length; index++) {
      output += bytes[index].toString(16).padStart(2, '0')
    }
    return output
  }
}
