import { common } from '@kit.AbilityKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileIo } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'

const MODEL_ID: string = 'waifu2x_art_noise0_2x'
const MODEL_LABEL: string = 'Waifu2x art 2×'
const MODEL_DIRECTORY: string = 'nextn-reader-super-resolution-models'
const PARAM_FILE_NAME: string = 'noise0_scale2.0x_model.param'
const MODEL_FILE_NAME: string = 'noise0_scale2.0x_model.bin'
const PARAM_BYTES: number = 1047
const MODEL_BYTES: number = 1106248
const PARAM_SHA256: string = '413195ffde05b4d43807792c6c020c916cecdf25dcf002ee83f5e28d5cc246c6'
const MODEL_SHA256: string = 'e1d2c4d91be98e72c0d48d08626cbe7d879aa2b80f740133dcc0d860eabb4189'
const MODEL_PACK_RELEASE_BASE: string =
  'https://github.com/erosTeam/NextE-Models/releases/download/model-pack-v1.0.0'
const PARAM_URL: string = `${MODEL_PACK_RELEASE_BASE}/waifu2x-art-noise0-2x.param`
const MODEL_URL: string = `${MODEL_PACK_RELEASE_BASE}/waifu2x-art-noise0-2x.bin`
const LEGACY_ACCELERATED_FILE_NAME: string = 'waifu2x-art-noise0-x2-156-fp16.ms'
const CONNECT_TIMEOUT_MS: number = 15000
const READ_TIMEOUT_MS: number = 30000

export class ReaderSuperResolutionModelDefinition {
  id: string = MODEL_ID
  fileName: string = MODEL_FILE_NAME
  bytes: number = PARAM_BYTES + MODEL_BYTES
  label: string = MODEL_LABEL
}

export class ReaderSuperResolutionModelPaths {
  paramPath: string = ''
  modelPath: string = ''
}

class ReaderSuperResolutionModelAsset {
  url: string = ''
  finalPath: string = ''
  bytes: number = 0
  sha256: string = ''
}

/**
 * Owns the portable waifu2x ncnn pair used by Reader. Installation is explicit;
 * reading never fetches assets and a partial or failed update never qualifies as
 * an installed runtime. The historical optional NNRT asset is left untouched
 * until the user explicitly removes Reader models.
 */
export class ReaderSuperResolutionModelService {
  private static installTask: Promise<void> | null = null

  static definition(): ReaderSuperResolutionModelDefinition {
    return new ReaderSuperResolutionModelDefinition()
  }

  static async isInstalled(context: common.UIAbilityContext): Promise<boolean> {
    const paths: ReaderSuperResolutionModelPaths = ReaderSuperResolutionModelService.paths(context)
    return ReaderSuperResolutionModelService.fileSize(paths.paramPath) === PARAM_BYTES &&
      ReaderSuperResolutionModelService.fileSize(paths.modelPath) === MODEL_BYTES
  }

  static async pathsIfReady(context: common.UIAbilityContext): Promise<ReaderSuperResolutionModelPaths | null> {
    return await ReaderSuperResolutionModelService.isInstalled(context)
      ? ReaderSuperResolutionModelService.paths(context)
      : null
  }

  static async install(context: common.UIAbilityContext): Promise<void> {
    if (ReaderSuperResolutionModelService.installTask !== null) {
      return await ReaderSuperResolutionModelService.installTask
    }
    const task: Promise<void> = ReaderSuperResolutionModelService.installInternal(context)
    ReaderSuperResolutionModelService.installTask = task
    try {
      await task
    } finally {
      if (ReaderSuperResolutionModelService.installTask === task) {
        ReaderSuperResolutionModelService.installTask = null
      }
    }
  }

  static remove(context: common.UIAbilityContext): void {
    const paths: ReaderSuperResolutionModelPaths = ReaderSuperResolutionModelService.paths(context)
    ReaderSuperResolutionModelService.removeIfExists(paths.paramPath)
    ReaderSuperResolutionModelService.removeIfExists(paths.modelPath)
    ReaderSuperResolutionModelService.removeIfExists(`${paths.paramPath}.part`)
    ReaderSuperResolutionModelService.removeIfExists(`${paths.modelPath}.part`)
    ReaderSuperResolutionModelService.removeIfExists(
      `${ReaderSuperResolutionModelService.modelDirectory(context)}/${LEGACY_ACCELERATED_FILE_NAME}`,
    )
  }

  private static async installInternal(context: common.UIAbilityContext): Promise<void> {
    const paths: ReaderSuperResolutionModelPaths = ReaderSuperResolutionModelService.paths(context)
    ReaderSuperResolutionModelService.ensureDirectory(ReaderSuperResolutionModelService.modelDirectory(context))
    const param: ReaderSuperResolutionModelAsset = new ReaderSuperResolutionModelAsset()
    param.url = PARAM_URL
    param.finalPath = paths.paramPath
    param.bytes = PARAM_BYTES
    param.sha256 = PARAM_SHA256
    const model: ReaderSuperResolutionModelAsset = new ReaderSuperResolutionModelAsset()
    model.url = MODEL_URL
    model.finalPath = paths.modelPath
    model.bytes = MODEL_BYTES
    model.sha256 = MODEL_SHA256
    await ReaderSuperResolutionModelService.installAsset(param)
    await ReaderSuperResolutionModelService.installAsset(model)
    if (!await ReaderSuperResolutionModelService.isInstalled(context)) {
      throw new Error('Reader enhancement runtime verification failed.')
    }
  }

  private static async installAsset(asset: ReaderSuperResolutionModelAsset): Promise<void> {
    if (ReaderSuperResolutionModelService.fileSize(asset.finalPath) === asset.bytes &&
      ReaderSuperResolutionModelService.sha256(asset.finalPath) === asset.sha256) {
      return
    }
    const temporaryPath: string = `${asset.finalPath}.part`
    ReaderSuperResolutionModelService.removeIfExists(temporaryPath)
    let file: fileIo.File | null = null
    let request: http.HttpRequest | null = null
    let written: number = 0
    let failed: boolean = false
    let promoted: boolean = false
    try {
      file = fileIo.openSync(
        temporaryPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      request = http.createHttp()
      request.on('dataReceiveProgress', (progress: http.DataReceiveProgressInfo): void => {
        if (progress.totalSize > asset.bytes) {
          failed = true
          request?.destroy()
        }
      })
      request.on('dataReceive', (data: ArrayBuffer): void => {
        if (file === null || failed || written + data.byteLength > asset.bytes) {
          failed = true
          request?.destroy()
          return
        }
        try {
          // Each callback buffer appends at the current pointer; `offset`
          // would be relative to that pointer rather than absolute.
          const count: number = fileIo.writeSync(file.fd, data)
          if (count !== data.byteLength) {
            failed = true
            request?.destroy()
            return
          }
          written += count
        } catch (_error) {
          failed = true
          request?.destroy()
        }
      })
      const status: number = await request.requestInStream(asset.url, {
        method: http.RequestMethod.GET,
        usingCache: false,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        header: {
          Accept: 'application/octet-stream',
          'User-Agent': 'NextN/1.0.0',
        },
      })
      if (failed || status < 200 || status >= 300 || written !== asset.bytes) {
        throw new Error('Reader enhancement model download failed.')
      }
      request.destroy()
      request = null
      fileIo.closeSync(file)
      file = null
      if (ReaderSuperResolutionModelService.sha256(temporaryPath) !== asset.sha256) {
        throw new Error('Reader enhancement model verification failed.')
      }
      ReaderSuperResolutionModelService.removeIfExists(asset.finalPath)
      fileIo.renameSync(temporaryPath, asset.finalPath)
      promoted = true
    } finally {
      if (request !== null) {
        request.destroy()
      }
      if (file !== null) {
        fileIo.closeSync(file)
      }
      if (!promoted) {
        ReaderSuperResolutionModelService.removeIfExists(temporaryPath)
      }
    }
  }

  private static paths(context: common.UIAbilityContext): ReaderSuperResolutionModelPaths {
    const directory: string = ReaderSuperResolutionModelService.modelDirectory(context)
    const paths: ReaderSuperResolutionModelPaths = new ReaderSuperResolutionModelPaths()
    paths.paramPath = `${directory}/${PARAM_FILE_NAME}`
    paths.modelPath = `${directory}/${MODEL_FILE_NAME}`
    return paths
  }

  private static modelDirectory(context: common.UIAbilityContext): string {
    if (context.filesDir.length === 0) {
      throw new Error('Private model storage is unavailable.')
    }
    return `${context.filesDir}/${MODEL_DIRECTORY}`
  }

  private static ensureDirectory(directory: string): void {
    try {
      fileIo.mkdirSync(directory, true)
    } catch (error) {
      if (!fileIo.accessSync(directory)) {
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

  private static removeIfExists(path: string): void {
    try {
      fileIo.unlinkSync(path)
    } catch (_error) {}
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
