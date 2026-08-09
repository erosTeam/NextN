import { AppStorageV2 } from '@kit.ArkUI'

/** Opt-in foreground clipboard-link state. Clipboard text never enters this state. */
@ObservedV2
export class NhClipboardLinkState {
  @Trace enabled: boolean = false
  @Trace lastChangeCount: number = -1
  @Trace candidateRevision: number = 0
  @Trace candidateGalleryId: number = 0
}

const CLIPBOARD_LINK_STATE_KEY: string = 'nextn_clipboard_link'

export function connectNhClipboardLink(): NhClipboardLinkState {
  return AppStorageV2.connect(
    NhClipboardLinkState,
    CLIPBOARD_LINK_STATE_KEY,
    () => new NhClipboardLinkState(),
  )!
}

export function publishNhClipboardGalleryCandidate(galleryId: number): void {
  if (!Number.isSafeInteger(galleryId) || galleryId <= 0) {
    return
  }
  const state = connectNhClipboardLink()
  state.candidateGalleryId = galleryId
  state.candidateRevision += 1
}

export function clearNhClipboardGalleryCandidate(): void {
  connectNhClipboardLink().candidateGalleryId = 0
}
