import { AppStorageV2 } from '@kit.ArkUI'

/**
 * Controls the optional background behind a gallery cover that deliberately
 * uses ImageFit.Contain.  It is presentation-only: it never changes a cover
 * URL, gallery summary, or image request.
 */
@ObservedV2
export class CoverBackgroundState {
  @Trace blurLetterboxBackground: boolean = false
}

const COVER_BACKGROUND_STATE_KEY: string = 'nextn_cover_background'

export function connectCoverBackground(): CoverBackgroundState {
  return AppStorageV2.connect(
    CoverBackgroundState,
    COVER_BACKGROUND_STATE_KEY,
    () => new CoverBackgroundState(),
  )!
}
