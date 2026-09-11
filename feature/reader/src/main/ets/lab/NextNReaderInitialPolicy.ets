import { ReaderDisplayPolicy } from '@reader-kit/core'
import { ReaderLabRequest } from '@reader-kit/ui'
import { NhReaderColumnMode, NhReaderMode, NhReaderPresentation, NhReaderSpreadLayout } from 'shared'

/** Host enum mapping only. The shared session remains the pairing/anchor owner. */
export class NextNReaderInitialPolicy {
  static resolve(presentation: NhReaderPresentation, column: NhReaderColumnMode,
    request: ReaderLabRequest): ReaderDisplayPolicy {
    const policy = new ReaderDisplayPolicy()
    const horizontal = presentation.mode === NhReaderMode.PAGED || presentation.mode === NhReaderMode.PAGED_RTL
    policy.layout = presentation.mode === NhReaderMode.VERTICAL ? 'continuous' :
      horizontal && presentation.doublePageEnabled ? 'spread' : 'single'
    policy.pagingAxis = presentation.mode === NhReaderMode.PAGED_VERTICAL ? 'vertical' : 'horizontal'
    policy.direction = presentation.mode === NhReaderMode.PAGED_RTL ? 'rtl' : 'ltr'
    policy.spreadLayout = presentation.spreadLayoutMode === NhReaderSpreadLayout.SPLIT ? 'split' : 'joined'
    policy.firstPageAlone = column === NhReaderColumnMode.EVEN_LEFT
    if (request.entryLayoutOverride === 'single' || request.entryLayoutOverride === 'spread') {
      policy.layout = request.entryLayoutOverride
      policy.pagingAxis = 'horizontal'
    }
    if (request.entryDirectionOverride === 'ltr' || request.entryDirectionOverride === 'rtl') {
      policy.direction = request.entryDirectionOverride
    }
    return policy
  }
}
