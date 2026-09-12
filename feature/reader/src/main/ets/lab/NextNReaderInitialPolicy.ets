import { ReaderDisplayPolicy } from '@reader-kit/core'
import { NhReaderColumnMode, NhReaderMode, NhReaderPresentation, NhReaderSpreadLayout } from 'shared'

/** Host enum mapping only. The shared session remains the pairing/anchor owner. */
export class NextNReaderInitialPolicy {
  static resolve(presentation: NhReaderPresentation, column: NhReaderColumnMode,
    layoutOverride: string | null = null, directionOverride: string | null = null): ReaderDisplayPolicy {
    const policy = new ReaderDisplayPolicy()
    const horizontal = presentation.mode === NhReaderMode.PAGED || presentation.mode === NhReaderMode.PAGED_RTL
    policy.layout = presentation.mode === NhReaderMode.VERTICAL ? 'continuous' :
      horizontal && presentation.doublePageEnabled ? 'spread' : 'single'
    policy.pagingAxis = presentation.mode === NhReaderMode.PAGED_VERTICAL ? 'vertical' : 'horizontal'
    policy.direction = presentation.mode === NhReaderMode.PAGED_RTL ? 'rtl' : 'ltr'
    policy.spreadLayout = presentation.spreadLayoutMode === NhReaderSpreadLayout.SPLIT ? 'split' : 'joined'
    policy.firstPageAlone = column === NhReaderColumnMode.EVEN_LEFT
    if (layoutOverride === 'continuous') {
      policy.layout = 'continuous'
      policy.pagingAxis = 'vertical'
    } else if (layoutOverride === 'single' || layoutOverride === 'spread') {
      policy.layout = layoutOverride
      policy.pagingAxis = 'horizontal'
    }
    if (directionOverride === 'ltr' || directionOverride === 'rtl') {
      policy.direction = directionOverride
    }
    return policy
  }
}
