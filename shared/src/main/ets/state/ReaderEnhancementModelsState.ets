import { AppStorageV2 } from '@kit.ArkUI'

const READER_ENHANCEMENT_MODELS_STATE_KEY: string = 'nextn_reader_enhancement_models'

/**
 * Non-sensitive invalidation signal for the app-private Reader enhancement
 * model files. The model manager owns file mutations; Settings owns the
 * installed-model projection and selection menu.
 */
@ObservedV2
export class ReaderEnhancementModelsState {
  @Trace revision: number = 0

  publishMutation(): void {
    this.revision += 1
  }
}

export function connectReaderEnhancementModels(): ReaderEnhancementModelsState {
  return AppStorageV2.connect(
    ReaderEnhancementModelsState,
    READER_ENHANCEMENT_MODELS_STATE_KEY,
    (): ReaderEnhancementModelsState => new ReaderEnhancementModelsState(),
  )!
}
