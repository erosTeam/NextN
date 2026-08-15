import nativeSuperResolution from 'libnextn_super_resolution.so'

interface NativePrepareResult {
  backend: string
  modelLoadMs: number
}

interface NativeUpscaleResult extends NativePrepareResult {
  pixels: ArrayBuffer
  inferenceMs: number
  tileCount: number
}

interface NativeDecodedImage {
  pixels: ArrayBuffer
  width: number
  height: number
  stride: number
}

interface NativeReaderSuperResolutionCapabilities {
  vulkanAvailable: boolean
  gpuCount: number
  vulkanApiVersion: number
  gpuName: string
  ncnnVersion: string
}

interface NativeReaderSuperResolution {
  decodeImageRgba(sourcePath: string, maxEdge: number): Promise<NativeDecodedImage>
  prepareModel(
    paramPath: string,
    modelPath: string,
    modelKind: number,
    backendPreference: number,
    tileSize: number,
    prepadding: number,
    threads: number,
    inputName: string,
    outputName: string,
  ): Promise<NativePrepareResult>
  upscaleRgba(
    pixels: ArrayBuffer,
    width: number,
    height: number,
    stride: number,
    paramPath: string,
    modelPath: string,
    modelKind: number,
    backendPreference: number,
    tileSize: number,
    prepadding: number,
    threads: number,
    inputName: string,
    outputName: string,
    requestId: number,
    effectStrengthPercent: number,
  ): Promise<NativeUpscaleResult>
  prepareMindSporeModel(
    modelPath: string,
    modelKind: number,
  ): Promise<NativePrepareResult>
  upscaleMindSporeRgba(
    pixels: ArrayBuffer,
    width: number,
    height: number,
    stride: number,
    modelPath: string,
    modelKind: number,
    requestId: number,
    effectStrengthPercent: number,
  ): Promise<NativeUpscaleResult>
  setRequestActive(requestId: number, active: boolean): void
  setInteractionPaused(paused: boolean): void
  getCapabilities(): NativeReaderSuperResolutionCapabilities
}

export class ReaderNativeDecodedImage {
  pixels: ArrayBuffer = new ArrayBuffer(0)
  width: number = 0
  height: number = 0
  stride: number = 0
}

export class ReaderNativeSuperResolutionResult {
  pixels: ArrayBuffer = new ArrayBuffer(0)
  backend: string = ''
  modelLoadMs: number = 0
  inferenceMs: number = 0
  tileCount: number = 0
}

export class ReaderNativeSuperResolutionCapabilities {
  vulkanAvailable: boolean = false
  gpuCount: number = 0
  vulkanApiVersion: number = 0
  gpuName: string = ''
  ncnnVersion: string = ''
}

/** Fixed portable waifu2x ncnn runtime contract shared with the model store. */
export class ReaderNativeSuperResolutionConfig {
  modelKind: number = 0
  backendPreference: number = 0
  tileSize: number = 142
  prepadding: number = 7
  threads: number = 2
  inputName: string = 'Input1'
  outputName: string = 'Eltwise4'
  effectStrengthPercent: number = 100
}

const nativeRuntime: NativeReaderSuperResolution = nativeSuperResolution as NativeReaderSuperResolution

/** Narrow ArkTS boundary for NextN's portable ncnn Reader-enhancement runtime. */
export class ReaderNativeSuperResolution {
  static capabilities(): ReaderNativeSuperResolutionCapabilities {
    const native: NativeReaderSuperResolutionCapabilities = nativeRuntime.getCapabilities()
    const result: ReaderNativeSuperResolutionCapabilities = new ReaderNativeSuperResolutionCapabilities()
    result.vulkanAvailable = native.vulkanAvailable
    result.gpuCount = native.gpuCount
    result.vulkanApiVersion = native.vulkanApiVersion
    result.gpuName = native.gpuName
    result.ncnnVersion = native.ncnnVersion
    return result
  }

  static async decodeImageRgba(sourcePath: string, maxEdge: number): Promise<ReaderNativeDecodedImage> {
    const native: NativeDecodedImage = await nativeRuntime.decodeImageRgba(sourcePath, maxEdge)
    const result: ReaderNativeDecodedImage = new ReaderNativeDecodedImage()
    result.pixels = native.pixels
    result.width = native.width
    result.height = native.height
    result.stride = native.stride
    return result
  }

  static async prepareModel(
    paramPath: string,
    modelPath: string,
    config: ReaderNativeSuperResolutionConfig,
  ): Promise<void> {
    await nativeRuntime.prepareModel(
      paramPath,
      modelPath,
      config.modelKind,
      config.backendPreference,
      config.tileSize,
      config.prepadding,
      config.threads,
      config.inputName,
      config.outputName,
    )
  }

  static async upscaleRgba(
    pixels: ArrayBuffer,
    width: number,
    height: number,
    stride: number,
    paramPath: string,
    modelPath: string,
    config: ReaderNativeSuperResolutionConfig,
    requestId: number,
  ): Promise<ReaderNativeSuperResolutionResult> {
    const native: NativeUpscaleResult = await nativeRuntime.upscaleRgba(
      pixels,
      width,
      height,
      stride,
      paramPath,
      modelPath,
      config.modelKind,
      config.backendPreference,
      config.tileSize,
      config.prepadding,
      config.threads,
      config.inputName,
      config.outputName,
      requestId,
      config.effectStrengthPercent,
    )
    const result: ReaderNativeSuperResolutionResult = new ReaderNativeSuperResolutionResult()
    result.pixels = native.pixels
    result.backend = native.backend
    result.modelLoadMs = native.modelLoadMs
    result.inferenceMs = native.inferenceMs
    result.tileCount = native.tileCount
    return result
  }

  static async prepareMindSporeModel(modelPath: string, modelKind: number): Promise<void> {
    await nativeRuntime.prepareMindSporeModel(modelPath, modelKind)
  }

  static async upscaleMindSporeRgba(
    pixels: ArrayBuffer,
    width: number,
    height: number,
    stride: number,
    modelPath: string,
    modelKind: number,
    requestId: number,
    effectStrengthPercent: number = 100,
  ): Promise<ReaderNativeSuperResolutionResult> {
    const native: NativeUpscaleResult = await nativeRuntime.upscaleMindSporeRgba(
      pixels,
      width,
      height,
      stride,
      modelPath,
      modelKind,
      requestId,
      effectStrengthPercent,
    )
    const result: ReaderNativeSuperResolutionResult = new ReaderNativeSuperResolutionResult()
    result.pixels = native.pixels
    result.backend = native.backend
    result.modelLoadMs = native.modelLoadMs
    result.inferenceMs = native.inferenceMs
    result.tileCount = native.tileCount
    return result
  }

  static setRequestActive(requestId: number, active: boolean): void {
    if (requestId > 0) {
      nativeRuntime.setRequestActive(requestId, active)
    }
  }

  static setInteractionPaused(paused: boolean): void {
    nativeRuntime.setInteractionPaused(paused)
  }
}
