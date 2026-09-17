import { ReaderAssetFailure } from '@reader-kit/core'
import { AppStrings } from 'shared'

/** NextN owns network semantics and localized copy; reader-kit only carries this presentation value. */
export class NextNReaderFailure {
  static from(_error: Error): ReaderAssetFailure {
    return new ReaderAssetFailure('imageUnavailable', AppStrings.get('reader_error_image_unavailable'),
      AppStrings.get('reader_retry_connection'))
  }
}
