import { common } from '@kit.AbilityKit'
import { taskpool, util } from '@kit.ArkTS'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { systemShare } from '@kit.ShareKit'
import { NhDownloadTask } from '../model/NhDownloadTask'
import { DownloadQueueService } from './DownloadQueueService'
import { NhDownloadExportCacheService } from './NhDownloadExportCacheService'

const EXPORT_CACHE_DIRECTORY: string = 'nextn-download-exports'
const EXPORT_EXTENSION: string = 'cbz'
const FILE_CHUNK_BYTES: number = 256 * 1024
const MAX_PAGE_BYTES: number = 64 * 1024 * 1024
const MAX_ARCHIVE_BYTES: number = 2 * 1024 * 1024 * 1024
const MAX_ZIP_ENTRY_COUNT: number = 0xffff
const ZIP_MIN_BYTES: number = 22

class CbzSourceEntry {
  entryName: string = ''
  sourcePath: string = ''
  byteSize: number = 0
}

class CbzTaskPayloadEntry {
  entryName: string = ''
  sourcePath: string = ''
}

/**
 * This is the same no-compression ZIP container strategy used by NextE's
 * normal gallery export. A `.cbz` is a ZIP whose entries stay in reading
 * order; keeping source images stored avoids a second image transform.
 */
@Concurrent
function writeCbzStoreTask(filePath: string, entriesJson: string): string {
  const fileChunkBytes: number = 256 * 1024
  const zipMinBytes: number = 22
  const rawEntries: Record<string, string>[] = JSON.parse(entriesJson) as Record<string, string>[]
  const crcTable: number[] = []

  const ensureCrcTable = (): void => {
    if (crcTable.length > 0) {
      return
    }
    for (let index: number = 0; index < 256; index += 1) {
      let crc: number = index
      for (let bit: number = 0; bit < 8; bit += 1) {
        crc = (crc & 1) !== 0 ? (0xedb88320 ^ (crc >>> 1)) : (crc >>> 1)
      }
      crcTable.push(crc >>> 0)
    }
  }

  const updateCrc = (seed: number, bytes: Uint8Array): number => {
    ensureCrcTable()
    let crc: number = seed
    for (let index: number = 0; index < bytes.byteLength; index += 1) {
      crc = crcTable[(crc ^ bytes[index]) & 0xff] ^ (crc >>> 8)
    }
    return crc
  }

  const writeBytes = (file: fileIo.File, bytes: Uint8Array): void => {
    if (bytes.byteOffset === 0 && bytes.byteLength === bytes.buffer.byteLength) {
      fileIo.writeSync(file.fd, bytes.buffer)
      return
    }
    fileIo.writeSync(file.fd, bytes.slice(0, bytes.byteLength).buffer)
  }

  const put16 = (bytes: Uint8Array, offset: number, value: number): void => {
    bytes[offset] = value & 0xff
    bytes[offset + 1] = (value >>> 8) & 0xff
  }

  const put32 = (bytes: Uint8Array, offset: number, value: number): void => {
    bytes[offset] = value & 0xff
    bytes[offset + 1] = (value >>> 8) & 0xff
    bytes[offset + 2] = (value >>> 16) & 0xff
    bytes[offset + 3] = (value >>> 24) & 0xff
  }

  const localHeader = (name: Uint8Array, crc: number, size: number): Uint8Array => {
    const bytes: Uint8Array = new Uint8Array(30 + name.byteLength)
    put32(bytes, 0, 0x04034b50)
    put16(bytes, 4, 20)
    put16(bytes, 6, 0x0800)
    put16(bytes, 8, 0)
    put16(bytes, 10, 0)
    put16(bytes, 12, 0)
    put32(bytes, 14, crc)
    put32(bytes, 18, size)
    put32(bytes, 22, size)
    put16(bytes, 26, name.byteLength)
    put16(bytes, 28, 0)
    bytes.set(name, 30)
    return bytes
  }

  const centralHeader = (name: Uint8Array, crc: number, size: number, offset: number): Uint8Array => {
    const bytes: Uint8Array = new Uint8Array(46 + name.byteLength)
    put32(bytes, 0, 0x02014b50)
    put16(bytes, 4, 20)
    put16(bytes, 6, 20)
    put16(bytes, 8, 0x0800)
    put16(bytes, 10, 0)
    put16(bytes, 12, 0)
    put16(bytes, 14, 0)
    put32(bytes, 16, crc)
    put32(bytes, 20, size)
    put32(bytes, 24, size)
    put16(bytes, 28, name.byteLength)
    put16(bytes, 30, 0)
    put16(bytes, 32, 0)
    put16(bytes, 34, 0)
    put16(bytes, 36, 0)
    put32(bytes, 38, 0)
    put32(bytes, 42, offset)
    bytes.set(name, 46)
    return bytes
  }

  const endRecord = (count: number, centralSize: number, centralOffset: number): Uint8Array => {
    const bytes: Uint8Array = new Uint8Array(zipMinBytes)
    put32(bytes, 0, 0x06054b50)
    put16(bytes, 4, 0)
    put16(bytes, 6, 0)
    put16(bytes, 8, count)
    put16(bytes, 10, count)
    put32(bytes, 12, centralSize)
    put32(bytes, 16, centralOffset)
    put16(bytes, 20, 0)
    return bytes
  }

  const sourceStats = (path: string): number[] => {
    let source: fileIo.File | null = null
    try {
      source = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
      const buffer: ArrayBuffer = new ArrayBuffer(fileChunkBytes)
      let crc: number = 0xffffffff
      let byteSize: number = 0
      while (true) {
        const read: number = fileIo.readSync(source.fd, buffer, { length: fileChunkBytes })
        if (read <= 0) {
          break
        }
        crc = updateCrc(crc, new Uint8Array(buffer, 0, read))
        byteSize += read
      }
      if (byteSize <= 0) {
        throw new Error('A local gallery page is empty.')
      }
      return [(crc ^ 0xffffffff) >>> 0, byteSize]
    } finally {
      if (source !== null) {
        fileIo.closeSync(source)
      }
    }
  }

  const copySource = (output: fileIo.File, sourcePath: string, expectedSize: number): void => {
    let source: fileIo.File | null = null
    try {
      source = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY)
      const buffer: ArrayBuffer = new ArrayBuffer(fileChunkBytes)
      let copied: number = 0
      while (true) {
        const read: number = fileIo.readSync(source.fd, buffer, { length: fileChunkBytes })
        if (read <= 0) {
          break
        }
        const written: number = fileIo.writeSync(output.fd, buffer, { length: read })
        if (written !== read) {
          throw new Error('The CBZ archive could not write a complete page.')
        }
        copied += written
      }
      if (copied !== expectedSize) {
        throw new Error('A local gallery page changed during export.')
      }
    } finally {
      if (source !== null) {
        fileIo.closeSync(source)
      }
    }
  }

  let output: fileIo.File | null = null
  try {
    output = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
    let localOffset: number = 0
    const centralRecords: Uint8Array[] = []
    for (let index: number = 0; index < rawEntries.length; index += 1) {
      const sourcePath: string = rawEntries[index].sourcePath
      const name: Uint8Array = new util.TextEncoder().encodeInto(rawEntries[index].entryName)
      const stats: number[] = sourceStats(sourcePath)
      const crc: number = stats[0]
      const size: number = stats[1]
      writeBytes(output, localHeader(name, crc, size))
      copySource(output, sourcePath, size)
      centralRecords.push(centralHeader(name, crc, size, localOffset))
      localOffset += 30 + name.byteLength + size
    }
    const centralOffset: number = localOffset
    let centralSize: number = 0
    for (let index: number = 0; index < centralRecords.length; index += 1) {
      writeBytes(output, centralRecords[index])
      centralSize += centralRecords[index].byteLength
    }
    writeBytes(output, endRecord(rawEntries.length, centralSize, centralOffset))
  } finally {
    if (output !== null) {
      fileIo.closeSync(output)
    }
  }
  return ''
}

/**
 * Exports one fully verified app-private gallery as a cache-backed CBZ and
 * hands only that local file URI to the system share sheet. It performs no
 * HTTP operation, account operation, or queue persistence.
 */
export class NhDownloadCbzExportService {
  static async exportAndShare(context: common.UIAbilityContext, task: NhDownloadTask): Promise<boolean> {
    if (!task.isComplete() || task.galleryId <= 0 ||
      !NhDownloadExportCacheService.beginUse(task.galleryId)) {
      return false
    }
    let filePath: string = ''
    try {
      const entries: CbzSourceEntry[] = NhDownloadCbzExportService.verifiedEntries(context, task)
      filePath = await NhDownloadCbzExportService.createArchive(context, task.galleryId, entries)
      const record: systemShare.SharedRecord = {
        utd: utd.UniformDataType.FILE,
        title: NhDownloadCbzExportService.fileName(task.galleryId),
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
      if (filePath.length > 0) {
        NhDownloadCbzExportService.removeIfExists(filePath)
      }
      return false
    } finally {
      NhDownloadExportCacheService.endUse(task.galleryId)
    }
  }

  private static verifiedEntries(context: common.UIAbilityContext, task: NhDownloadTask): CbzSourceEntry[] {
    if (task.pageCount <= 0 || task.pageCount > MAX_ZIP_ENTRY_COUNT ||
      task.pageExtensions.length !== task.pageCount) {
      throw new Error('This local download cannot be exported.')
    }
    const paths: string[] = DownloadQueueService.completeLocalPagePaths(context, task)
    if (paths.length !== task.pageCount) {
      throw new Error('The complete local page set is unavailable.')
    }
    let totalBytes: number = ZIP_MIN_BYTES
    const entries: CbzSourceEntry[] = []
    for (let index: number = 0; index < paths.length; index += 1) {
      const extension: string = task.pageExtensions[index].toLowerCase().trim()
      if (!/^[a-z0-9]{1,8}$/.test(extension)) {
        throw new Error('A local gallery page format is unavailable.')
      }
      const byteSize: number = NhDownloadCbzExportService.fileSize(paths[index])
      if (byteSize <= 0 || byteSize > MAX_PAGE_BYTES) {
        throw new Error('A local gallery page is unavailable.')
      }
      const entry: CbzSourceEntry = new CbzSourceEntry()
      entry.entryName = `page-${(index + 1).toString().padStart(4, '0')}.${extension}`
      entry.sourcePath = paths[index]
      entry.byteSize = byteSize
      totalBytes += byteSize + 76 + (entry.entryName.length * 2)
      if (totalBytes > MAX_ARCHIVE_BYTES) {
        throw new Error('The local gallery is too large to export.')
      }
      entries.push(entry)
    }
    return entries
  }

  private static async createArchive(
    context: common.UIAbilityContext,
    galleryId: number,
    entries: CbzSourceEntry[],
  ): Promise<string> {
    const directory: string = NhDownloadCbzExportService.exportDirectory(context)
    NhDownloadCbzExportService.ensureDirectory(directory)
    const filePath: string = `${directory}/${NhDownloadCbzExportService.fileName(galleryId, Date.now())}`
    const temporaryPath: string = `${filePath}.part`
    NhDownloadCbzExportService.removeIfExists(temporaryPath)
    let promoted: boolean = false
    try {
      const taskEntries: CbzTaskPayloadEntry[] = []
      for (let index: number = 0; index < entries.length; index += 1) {
        const entry: CbzTaskPayloadEntry = new CbzTaskPayloadEntry()
        entry.entryName = entries[index].entryName
        entry.sourcePath = entries[index].sourcePath
        taskEntries.push(entry)
      }
      const payload: string = JSON.stringify(taskEntries)
      await taskpool.execute<[string, string], string>(writeCbzStoreTask, temporaryPath, payload)
      const expectedSize: number = NhDownloadCbzExportService.expectedArchiveBytes(entries)
      if (NhDownloadCbzExportService.fileSize(temporaryPath) !== expectedSize) {
        throw new Error('The local CBZ archive did not verify.')
      }
      fileIo.renameSync(temporaryPath, filePath)
      if (NhDownloadCbzExportService.fileSize(filePath) !== expectedSize) {
        NhDownloadCbzExportService.removeIfExists(filePath)
        throw new Error('The local CBZ archive did not promote.')
      }
      promoted = true
      return filePath
    } finally {
      if (!promoted) {
        NhDownloadCbzExportService.removeIfExists(temporaryPath)
      }
    }
  }

  private static expectedArchiveBytes(entries: CbzSourceEntry[]): number {
    let bytes: number = ZIP_MIN_BYTES
    for (let index: number = 0; index < entries.length; index += 1) {
      bytes += entries[index].byteSize + 76 + (entries[index].entryName.length * 2)
    }
    return bytes
  }

  private static exportDirectory(context: common.UIAbilityContext): string {
    if (context.cacheDir.length === 0) {
      throw new Error('Private export storage is unavailable.')
    }
    return `${context.cacheDir}/${EXPORT_CACHE_DIRECTORY}`
  }

  private static fileName(galleryId: number, nonce: number = 0): string {
    const suffix: string = nonce > 0 ? `-${nonce}` : ''
    return `nextn-gallery-${galleryId}${suffix}.${EXPORT_EXTENSION}`
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
      return Math.max(0, Math.floor(fileIo.statSync(path).size))
    } catch (_error) {
      return 0
    }
  }
}
