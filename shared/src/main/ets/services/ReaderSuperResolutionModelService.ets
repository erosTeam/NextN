import { common } from '@kit.AbilityKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileIo } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'

const MODEL_ID: string = 'waifu2x_art_noise0_2x'
const MODEL_FILE_NAME: string = 'waifu2x-art-noise0-x2-156-fp16.ms'
const MODEL_BYTES: number = 1110528
const MODEL_SHA256: string = '1ee87330e366afb0ad84752ab7e1acecbbcdbc17ee15ed18e546f336fe85bf52'
const MODEL_URL: string =
  'https://github.com/erosTeam/NextE-Models/releases/download/model-pack-v1.0.0/' + MODEL_FILE_NAME
const MODEL_DIRECTORY: string = 'nextn-reader-super-resolution-models'
const CONNECT_TIMEOUT_MS: number = 15000
const READ_TIMEOUT_MS: number = 30000

export class ReaderSuperResolutionModelDefinition {
  id: string = MODEL_ID
  fileName: string = MODEL_FILE_NAME
  bytes: number = MODEL_BYTES
  label: string = 'Waifu2x art 2×'
}

/**
 * Owns one explicit, user-installed 2× Reader model. It never downloads during
 * reading, and a failed update keeps the previous verified model untouched.
 */
export class ReaderSuperResolutionModelService {
  private static installTask: Promise<void> | null = null

  static definition(): ReaderSuperResolutionModelDefinition {
    return new ReaderSuperResolutionModelDefinition()
  }

  static async isInstalled(context: common.UIAbilityContext): Promise<boolean> {
    const path: string = ReaderSuperResolutionModelService.modelPath(context)
    // The SHA-256 verification happens before the atomic .part promotion in
    // installInternal(). This hot path runs for each eligible Reader page, so
    // re-reading the private 1 MiB model synchronously here would stall page
    // presentation without increasing the integrity guarantee of that write.
    return ReaderSuperResolutionModelService.fileSize(path) === MODEL_BYTES
  }

  static async pathIfReady(context: common.UIAbilityContext): Promise<string | null> {
    return await ReaderSuperResolutionModelService.isInstalled(context)
      ? ReaderSuperResolutionModelService.modelPath(context)
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
    ReaderSuperResolutionModelService.removeIfExists(ReaderSuperResolutionModelService.modelPath(context))
  }

  private static async installInternal(context: common.UIAbilityContext): Promise<void> {
    const directory: string = ReaderSuperResolutionModelService.modelDirectory(context)
    const finalPath: string = ReaderSuperResolutionModelService.modelPath(context)
    const temporaryPath: string = `${finalPath}.part`
    ReaderSuperResolutionModelService.ensureDirectory(directory)
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
        if (progress.totalSize > MODEL_BYTES) {
          failed = true
          request?.destroy()
        }
      })
      request.on('dataReceive', (data: ArrayBuffer): void => {
        if (file === null || failed || written + data.byteLength > MODEL_BYTES) {
          failed = true
          request?.destroy()
          return
        }
        try {
          const count: number = fileIo.writeSync(file.fd, data, { offset: written })
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
      const status: number = await request.requestInStream(MODEL_URL, {
        method: http.RequestMethod.GET,
        usingCache: false,
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        header: {
          Accept: 'application/octet-stream',
          'User-Agent': 'NextN/1.0.0',
        },
      })
      if (failed || status < 200 || status >= 300 || written !== MODEL_BYTES) {
        throw new Error('Reader enhancement model download failed.')
      }
      request.destroy()
      request = null
      fileIo.closeSync(file)
      file = null
      if (ReaderSuperResolutionModelService.sha256(temporaryPath) !== MODEL_SHA256) {
        throw new Error('Reader enhancement model verification failed.')
      }
      ReaderSuperResolutionModelService.removeIfExists(finalPath)
      fileIo.renameSync(temporaryPath, finalPath)
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

  private static modelDirectory(context: common.UIAbilityContext): string {
    if (context.filesDir.length === 0) {
      throw new Error('Private model storage is unavailable.')
    }
    return `${context.filesDir}/${MODEL_DIRECTORY}`
  }

  private static modelPath(context: common.UIAbilityContext): string {
    return `${ReaderSuperResolutionModelService.modelDirectory(context)}/${MODEL_FILE_NAME}`
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
