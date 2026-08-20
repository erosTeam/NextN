import { BusinessError, pasteboard } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { NhClipboardLinkSettings } from '../settings/NhClipboardLinkSettings'
import { connectNhClipboardLink } from '../state/NhClipboardLinkState'

const NH_GALLERY_LINK: RegExp = /https?:\/\/(?:www\.)?nhentai\.net\/g\/([1-9]\d*)\/?(?=[\s"'<>)]|$)/ig
// Search accepts only a complete canonical URL. Clipboard probing deliberately
// remains broader because clipboard records can include HTML/text decoration.
const NH_CANONICAL_GALLERY_URL: RegExp = /^https?:\/\/(?:www\.)?nhentai\.net\/g\/([1-9]\d*)(?:\/[1-9]\d*)?\/?$/i

/** Foreground-only probe. It discards clipboard text immediately after strict ID extraction. */
export class NhClipboardLinkService {
  /**
   * Parses one complete public gallery or gallery-page URL without retaining
   * query text, a URL object, or clipboard content. It intentionally rejects
   * arbitrary text containing a URL so normal catalog searches stay normal.
   */
  static canonicalGalleryId(value: string): number {
    const match: RegExpExecArray | null = NH_CANONICAL_GALLERY_URL.exec(value.trim())
    if (match === null || match.length < 2) {
      return 0
    }
    const galleryId: number = Number(match[1])
    return Number.isSafeInteger(galleryId) && galleryId > 0 ? galleryId : 0
  }

  static async probe(context: common.UIAbilityContext): Promise<number> {
    const state = connectNhClipboardLink()
    if (!state.enabled) {
      return 0
    }
    const board = pasteboard.getSystemPasteboard()
    try {
      if (!await board.hasData()) {
        return 0
      }
      const changeCount = board.getChangeCount()
      if (changeCount === state.lastChangeCount) {
        return 0
      }
      const textLike = board.hasDataType(pasteboard.MIMETYPE_TEXT_PLAIN) ||
        board.hasDataType(pasteboard.MIMETYPE_TEXT_URI) ||
        board.hasDataType(pasteboard.MIMETYPE_TEXT_HTML)
      if (!textLike) {
        await NhClipboardLinkSettings.markChangeCount(context, changeCount)
        return 0
      }
      const patterns = await board.detectPatterns([pasteboard.Pattern.URL])
      if (patterns.indexOf(pasteboard.Pattern.URL) < 0) {
        await NhClipboardLinkSettings.markChangeCount(context, changeCount)
        return 0
      }
      const galleryId: number = await NhClipboardLinkService.extractGalleryId(await board.getData())
      await NhClipboardLinkSettings.markChangeCount(context, changeCount)
      if (galleryId > 0) {
        DiagnosticLogger.info('clipboard', 'candidate_found', `kind=gallery changeCount=${changeCount}`)
      }
      return galleryId
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      if (businessError.code === 201) {
        DiagnosticLogger.warn('clipboard', 'read_permission_missing', 'code=201')
        await NhClipboardLinkSettings.disableAfterPermissionFailure(context)
        return 0
      }
      DiagnosticLogger.warn(
        'clipboard',
        'probe_failed',
        `code=${businessError.code ?? 0} message=${businessError.message}`,
      )
      return 0
    }
  }

  private static async extractGalleryId(data: pasteboard.PasteData): Promise<number> {
    const recordCount: number = data.getRecordCount()
    for (let index: number = 0; index < recordCount; index++) {
      const record: pasteboard.PasteDataRecord = data.getRecord(index)
      const candidates: string[] = [
        record.plainText ?? '',
        record.uri ?? '',
        record.htmlText ?? '',
        record.toPlainText() ?? '',
      ]
      for (let candidateIndex: number = 0; candidateIndex < candidates.length; candidateIndex++) {
        const id: number = NhClipboardLinkService.parseGalleryId(candidates[candidateIndex])
        if (id > 0) {
          return id
        }
      }
      const entryTypes: string[] = record.getValidTypes([
        pasteboard.MIMETYPE_TEXT_PLAIN,
        pasteboard.MIMETYPE_TEXT_URI,
        pasteboard.MIMETYPE_TEXT_HTML,
      ])
      for (let typeIndex: number = 0; typeIndex < entryTypes.length; typeIndex++) {
        const value: pasteboard.ValueType = await record.getData(entryTypes[typeIndex])
        const id: number = NhClipboardLinkService.parseGalleryId(
          NhClipboardLinkService.textFromEntryValue(value),
        )
        if (id > 0) {
          return id
        }
      }
    }
    return 0
  }

  private static textFromEntryValue(value: pasteboard.ValueType): string {
    if (typeof value === 'string') {
      return value
    }
    if (value instanceof ArrayBuffer) {
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true })
      return decoder.decodeToString(new Uint8Array(value))
    }
    return ''
  }

  private static parseGalleryId(value: string): number {
    NH_GALLERY_LINK.lastIndex = 0
    const match = NH_GALLERY_LINK.exec(value)
    if (match === null || match.length < 2) {
      return 0
    }
    const galleryId = Number(match[1])
    return Number.isSafeInteger(galleryId) && galleryId > 0 ? galleryId : 0
  }
}
