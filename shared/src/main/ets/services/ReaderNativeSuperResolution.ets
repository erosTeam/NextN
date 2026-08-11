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

interface NativeReaderSuperResolution {
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
}

export class ReaderNativeSuperResolutionResult {
  pixels: ArrayBuffer = new ArrayBuffer(0)
  backend: string = ''
  modelLoadMs: number = 0
  inferenceMs: number = 0
  tileCount: number = 0
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
