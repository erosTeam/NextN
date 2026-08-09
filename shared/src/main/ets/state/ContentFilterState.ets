import { AppStorageV2 } from '@kit.ArkUI'
import { NhContentFilterRule } from '../model/NhContentFilter'

@ObservedV2
export class ContentFilterState {
  @Trace rules: NhContentFilterRule[] = []
  @Trace revision: number = 0
  @Trace isRestored: boolean = false
}

const CONTENT_FILTER_STATE_KEY: string = 'nextn_content_filters'

export function connectContentFilters(): ContentFilterState {
  return AppStorageV2.connect(
    ContentFilterState,
    CONTENT_FILTER_STATE_KEY,
    (): ContentFilterState => new ContentFilterState(),
  )!
}
