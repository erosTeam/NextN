import { common } from '@kit.AbilityKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { systemShare } from '@kit.ShareKit'

const DEFAULT_IMAGE_EXTENSION: string = 'jpg'

/** Portable current-image actions; NH gallery-link sharing remains a separate service. */
export class NhReaderImageActionService {
  static async shareCurrentImage(
    context: common.UIAbilityContext,
    title: string,
    localPath: string,
    remoteUrl: string,
  ): Promise<boolean> {
    try {
      let record: systemShare.SharedRecord
      if (localPath.length > 0) {
        record = {
          utd: utd.UniformDataType.FILE,
          title,
          description: title,
          uri: fileUri.getUriFromPath(localPath),
        }
      } else if (remoteUrl.startsWith('https://')) {
        record = {
          utd: utd.UniformDataType.HYPERLINK,
          title,
          content: remoteUrl,
        }
      } else {
        return false
      }
      const data: systemShare.SharedData = new systemShare.SharedData(record)
      const controller: systemShare.ShareController = new systemShare.ShareController(data)
      await controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT,
      })
      return true
    } catch (_error) {
      return false
    }
  }

  static async saveLocalImageToGallery(
    context: common.UIAbilityContext,
    localPath: string,
    titleSeed: string,
    extension: string,
  ): Promise<void> {
    if (localPath.length === 0 || NhReaderImageActionService.fileSize(localPath) <= 0) {
      throw new Error('Reader image is not available locally')
    }
    const normalizedExtension: string = NhReaderImageActionService.normalizedExtension(extension)
    const title: string = NhReaderImageActionService.safeTitle(titleSeed, normalizedExtension)
    const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)
    const config: photoAccessHelper.PhotoCreationConfig = {
      title,
      fileNameExtension: normalizedExtension,
      photoType: photoAccessHelper.PhotoType.IMAGE,
      subtype: photoAccessHelper.PhotoSubtype.DEFAULT,
    }
    let source: fileIo.File | null = null
    let destination: fileIo.File | null = null
    try {
      const destinationUris: string[] = await helper.showAssetsCreationDialog([localPath], [config])
      if (!destinationUris || destinationUris.length === 0) {
        throw new Error('Reader image save was cancelled')
      }
      source = await fileIo.open(localPath, fileIo.OpenMode.READ_ONLY)
      destination = await fileIo.open(destinationUris[0], fileIo.OpenMode.WRITE_ONLY)
      await fileIo.copyFile(source.fd, destination.fd)
    } finally {
      NhReaderImageActionService.closeFile(source)
      NhReaderImageActionService.closeFile(destination)
    }
  }

  static fileSize(localPath: string): number {
    if (localPath.length === 0) {
      return 0
    }
    try {
      return Math.max(0, fileIo.statSync(localPath).size)
    } catch (_error) {
      return 0
    }
  }

  static formatBytes(bytes: number): string {
    if (!Number.isFinite(bytes) || bytes <= 0) {
      return ''
    }
    if (bytes < 1024) {
      return `${Math.round(bytes)} B`
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`
    }
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  private static normalizedExtension(extension: string): string {
    const value: string = extension.trim().toLowerCase()
    if (value === 'jpg' || value === 'jpeg' || value === 'png' || value === 'webp' ||
      value === 'gif' || value === 'bmp' || value === 'heif') {
      return value
    }
    return DEFAULT_IMAGE_EXTENSION
  }

  private static safeTitle(seed: string, extension: string): string {
    let result: string = ''
    for (let index: number = 0; index < seed.length; index += 1) {
      const character: string = seed.charAt(index)
      const code: number = character.charCodeAt(0)
      const safe: boolean = (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) || (code >= 97 && code <= 122) ||
        character === '-' || character === '_'
      result += safe ? character : '_'
    }
    const suffix: string = `.${extension}`
    if (result.toLowerCase().endsWith(suffix)) {
      result = result.substring(0, result.length - suffix.length)
    }
    result = result.trim()
    if (result.length === 0) {
      result = `nextn-reader-${Date.now()}`
    }
    return result.length > 80 ? result.substring(0, 80) : result
  }

  private static closeFile(file: fileIo.File | null): void {
    if (file === null) {
      return
    }
    try {
      fileIo.closeSync(file)
    } catch (_error) {}
  }
}
