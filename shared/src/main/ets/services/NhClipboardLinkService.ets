import { BusinessError, pasteboard } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
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
      const galleryId = NhClipboardLinkService.extractGalleryId(await board.getData())
      await NhClipboardLinkSettings.markChangeCount(context, changeCount)
      return galleryId
    } catch (error) {
      const businessError = error as BusinessError
      if (businessError.code === 201) {
        await NhClipboardLinkSettings.disableAfterPermissionFailure(context)
      }
      return 0
    }
  }

  private static extractGalleryId(data: pasteboard.PasteData): number {
    for (let index = 0; index < data.getRecordCount(); index++) {
      const record = data.getRecord(index)
      for (const candidate of [record.plainText ?? '', record.uri ?? '', record.htmlText ?? '', record.toPlainText() ?? '']) {
        const id = NhClipboardLinkService.parseGalleryId(candidate)
        if (id > 0) {
          return id
        }
      }
    }
    return 0
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
