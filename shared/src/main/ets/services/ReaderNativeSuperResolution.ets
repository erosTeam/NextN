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
  prepareModel(modelPath: string): Promise<NativePrepareResult>
  upscaleRgba(
    pixels: ArrayBuffer,
    width: number,
    height: number,
    stride: number,
    modelPath: string,
    requestId: number,
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

const nativeRuntime: NativeReaderSuperResolution = nativeSuperResolution as NativeReaderSuperResolution

/** Narrow ArkTS boundary for NextN's isolated MindSpore reader-enhancement module. */
export class ReaderNativeSuperResolution {
  static async prepareModel(modelPath: string): Promise<void> {
    await nativeRuntime.prepareModel(modelPath)
  }

  static async upscaleRgba(
    pixels: ArrayBuffer,
    width: number,
    height: number,
    stride: number,
    modelPath: string,
    requestId: number,
  ): Promise<ReaderNativeSuperResolutionResult> {
    const native: NativeUpscaleResult = await nativeRuntime.upscaleRgba(
      pixels,
      width,
      height,
      stride,
      modelPath,
      requestId,
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
