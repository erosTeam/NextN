import { fileIo } from '@kit.CoreFileKit'
import { StreamingHttpClient } from 'shared'

/** Exact captured URI -> host-owned temporary path; no cache lookup or promotion. */
export class NextNReaderImageSaveDownload {
  static async download(uri: string, path: string): Promise<void> {
    if (!uri.startsWith('https://') || path.length === 0) throw new Error('Invalid Reader save source')
    let file: fileIo.File | null = null
    let written: number = 0
    let writeFailed: boolean = false
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      const headers: Record<string, string> = { 'Accept': 'image/*', 'User-Agent': 'NextN/1.0.0' }
      const response = await StreamingHttpClient.get(uri, headers, 10000, 30000, 512 * 1024 * 1024,
        (data: ArrayBuffer): boolean => {
          if (file === null || writeFailed) return false
          try {
            const count = fileIo.writeSync(file.fd, data)
            if (count !== data.byteLength) { writeFailed = true; return false }
            written += count
            return true
          } catch (_) { writeFailed = true; return false }
        })
      // A range/partial response is not a complete image save.
      if (response.statusCode !== 200 || response.limitExceeded || response.sinkRejected ||
        response.cancelled || writeFailed || written <= 0 || written !== response.receivedBytes) {
        throw new Error('Reader save download incomplete')
      }
    } finally {
      if (file !== null) fileIo.closeSync(file)
    }
  }
}
