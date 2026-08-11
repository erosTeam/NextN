import { common } from '@kit.AbilityKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { systemShare } from '@kit.ShareKit'

const TORRENT_EXPORT_DIRECTORY: string = 'nextn-torrent-exports'
const MAX_TORRENT_BYTES: number = 10 * 1024 * 1024
const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 30000

/**
 * Downloads a freshly issued torrent capability into NextN's private cache,
 * then gives that file URI to HarmonyOS' system share sheet.
 *
 * The signed URL is deliberately never persisted, logged, opened externally,
 * or passed to another application. Only the resulting `.torrent` file is
 * shared, after the user explicitly selected Export torrent file.
 */
export class NhTorrentFileExportService {
  static async downloadAndShare(
    context: common.UIAbilityContext,
    galleryId: number,
    issuedUrl: string,
  ): Promise<boolean> {
    const normalizedGalleryId: number = Math.max(0, Math.floor(galleryId))
    if (normalizedGalleryId <= 0 || !NhTorrentFileExportService.isSafeIssuedUrl(issuedUrl)) {
      return false
    }
    try {
      const filePath: string = await NhTorrentFileExportService.downloadIssuedFile(
        context,
        normalizedGalleryId,
        issuedUrl.trim(),
      )
      const record: systemShare.SharedRecord = {
        utd: utd.UniformDataType.FILE,
        title: `gallery-${normalizedGalleryId}.torrent`,
        description: 'NextN torrent file',
        uri: fileUri.getUriFromPath(filePath),
      }
      const data: systemShare.SharedData = new systemShare.SharedData(record)
      const controller: systemShare.ShareController = new systemShare.ShareController(data)
      await controller.show(context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE,
      })
      return true
    } catch (_error) {
      return false
    }
  }

  private static async downloadIssuedFile(
    context: common.UIAbilityContext,
    galleryId: number,
    issuedUrl: string,
  ): Promise<string> {
    const directory: string = NhTorrentFileExportService.exportDirectory(context)
    const filePath: string = `${directory}/gallery-${galleryId}.torrent`
    const temporaryPath: string = `${filePath}.part`
    NhTorrentFileExportService.ensureDirectory(directory)
    NhTorrentFileExportService.removeIfExists(temporaryPath)

    let file: fileIo.File | null = null
    let request: http.HttpRequest | null = null
    let written: number = 0
    let tooLarge: boolean = false
    let writeFailure: boolean = false
    let promoted: boolean = false
    try {
      file = fileIo.openSync(
        temporaryPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      request = http.createHttp()
      request.on('dataReceiveProgress', (info: http.DataReceiveProgressInfo): void => {
        if (info.totalSize > MAX_TORRENT_BYTES) {
          tooLarge = true
          request?.destroy()
        }
      })
      request.on('dataReceive', (data: ArrayBuffer): void => {
        if (file === null || tooLarge || writeFailure) {
          return
        }
        try {
          if (written + data.byteLength > MAX_TORRENT_BYTES) {
            tooLarge = true
            request?.destroy()
            return
          }
          // `offset` is relative to the current pointer; ordinary streamed
          // chunks must append directly at that pointer.
          const count: number = fileIo.writeSync(file.fd, data)
          if (count !== data.byteLength) {
            throw new Error('Torrent file write was incomplete.')
          }
          written += count
        } catch (_error) {
          writeFailure = true
          request?.destroy()
        }
      })
      const status: number = await request.requestInStream(issuedUrl, {
        method: http.RequestMethod.GET,
        header: {
          Accept: 'application/x-bittorrent, application/octet-stream;q=0.9',
          'User-Agent': 'NextN/1.0.0',
        },
        connectTimeout: CONNECT_TIMEOUT_MS,
        readTimeout: READ_TIMEOUT_MS,
        usingCache: false,
      })
      if (tooLarge) {
        throw new Error('Torrent file exceeds the private export limit.')
      }
      if (writeFailure) {
        throw new Error('Unable to save torrent file.')
      }
      if (status < 200 || status >= 300 || written <= 0) {
        throw new Error('Torrent download was unavailable.')
      }
      request.destroy()
      request = null
      fileIo.closeSync(file)
      file = null
      NhTorrentFileExportService.removeIfExists(filePath)
      fileIo.renameSync(temporaryPath, filePath)
      if (NhTorrentFileExportService.fileSize(filePath) !== written) {
        NhTorrentFileExportService.removeIfExists(filePath)
        throw new Error('Torrent file verification failed.')
      }
      promoted = true
      return filePath
    } finally {
      if (request !== null) {
        request.destroy()
      }
      if (file !== null) {
        fileIo.closeSync(file)
      }
      if (!promoted) {
        NhTorrentFileExportService.removeIfExists(temporaryPath)
      }
    }
  }

  private static exportDirectory(context: common.UIAbilityContext): string {
    if (context.cacheDir.length === 0) {
      throw new Error('Private export storage is unavailable.')
    }
    return `${context.cacheDir}/${TORRENT_EXPORT_DIRECTORY}`
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

  private static removeIfExists(path: string): void {
    try {
      fileIo.unlinkSync(path)
    } catch (_error) {}
  }

  private static fileSize(path: string): number {
    try {
      return fileIo.statSync(path).size
    } catch (_error) {
      return 0
    }
  }

  private static isSafeIssuedUrl(value: string): boolean {
    const url: string = value.trim()
    return url.length > 0 && url.length <= 4096 &&
      /^https:\/\/[A-Za-z0-9.-]+(?::[0-9]{1,5})?(?:[/?#]|$)/.test(url) &&
      !/[\s\\]/.test(url)
  }
}
