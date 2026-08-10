import { ComicPageDocument } from '../model/ComicTranslation'
import {
  ComicBackendTemplate,
  ComicRenderedPage,
  ComicRenderedPageIdentity,
  ComicTranslationBatch,
} from '../model/ComicVisualTranslation'
import { ComicVisualPageSource } from './ComicVisualTranslationBackend'

/**
 * Explicit diagnostic records for an injected in-memory sink. No file-backed recorder is
 * provided here: full source pages, OCR text, masks, and translated text must not be retained
 * unless a later, separately authorized developer workflow supplies its own sink.
 */
export class ComicLocalVisualAnalysisTimings {
  detectorMs: number = 0
  systemOcrMs: number = 0
  proposalMaskMs: number = 0
  supplementalOcrMs: number = 0
  layoutMs: number = 0
  totalMs: number = 0
  tileCount: number = 0
  blockCount: number = 0

  copy(): ComicLocalVisualAnalysisTimings {
    const value: ComicLocalVisualAnalysisTimings = new ComicLocalVisualAnalysisTimings()
    value.detectorMs = this.detectorMs
    value.systemOcrMs = this.systemOcrMs
    value.proposalMaskMs = this.proposalMaskMs
    value.supplementalOcrMs = this.supplementalOcrMs
    value.layoutMs = this.layoutMs
    value.totalMs = this.totalMs
    value.tileCount = this.tileCount
    value.blockCount = this.blockCount
    return value
  }
}

export class ComicLocalVisualRenderTimings {
  decodeMs: number = 0
  maskMs: number = 0
  layoutMs: number = 0
  inpaintMs: number = 0
  drawMs: number = 0
  encodeMs: number = 0
  finalizeMs: number = 0
  totalMs: number = 0
  inpaintCallCount: number = 0
  inpaintNativeCallMs: number = 0
  inpaintModelLoadMs: number = 0
  inpaintPreprocessingMs: number = 0
  inpaintInferenceMs: number = 0
  inpaintPostprocessingMs: number = 0
  drawableGroupCount: number = 0
  skippedGroupCount: number = 0
  horizontalFontCap: number = 0
  layoutProfileId: string = ''
}

export class ComicLocalVisualRecordedRect {
  left: number = 0
  top: number = 0
  right: number = 0
  bottom: number = 0
  shapeConstrained: boolean = false
  containerConfidence: number = 0
  containerRawCoverage: number = 0
  containerSolidity: number = 0
  containerAreaRatio: number = 0
  containerLuminanceStd: number = 0
  containerProbeOutcome: string = ''
  rectBorderLeftScore: number = 0
  rectBorderRightScore: number = 0
  rectBorderTopScore: number = 0
  rectBorderBottomScore: number = 0
  rectBorderTopLeftCornerScore: number = 0
  rectBorderTopRightCornerScore: number = 0
  rectBorderBottomLeftCornerScore: number = 0
  rectBorderBottomRightCornerScore: number = 0
  rectBorderProbeOutcome: string = ''
}

export class ComicLocalVisualRecordedColor {
  red: number = 0
  green: number = 0
  blue: number = 0
}

export class ComicLocalVisualRecordedSourceBlock {
  left: number = 0
  top: number = 0
  right: number = 0
  bottom: number = 0
  styleHint: string = ''
  sourceText: string = ''
  textLength: number = 0
  tileIndex: number = 0
  detectorRegionIndexes: number[] = []
  sourceGroupIndexes: number[] = []
  detectorLabels: string[] = []
  preserveSource: boolean = false
  lineWidthScale: number = 0
  lineHeightScale: number = 0
}

export class ComicLocalVisualGroupingStages {
  grouped: ComicLocalVisualRecordedSourceBlock[] = []
  verticalMerged: ComicLocalVisualRecordedSourceBlock[] = []
  horizontalMerged: ComicLocalVisualRecordedSourceBlock[] = []
  output: ComicLocalVisualRecordedSourceBlock[] = []

  copy(): ComicLocalVisualGroupingStages {
    const value: ComicLocalVisualGroupingStages = new ComicLocalVisualGroupingStages()
    value.grouped = this.grouped.slice()
    value.verticalMerged = this.verticalMerged.slice()
    value.horizontalMerged = this.horizontalMerged.slice()
    value.output = this.output.slice()
    return value
  }
}

export class ComicLocalVisualRecordedLayout {
  blockIds: string[] = []
  sourceRects: ComicLocalVisualRecordedRect[] = []
  treatmentRects: ComicLocalVisualRecordedRect[] = []
  textRect: ComicLocalVisualRecordedRect = new ComicLocalVisualRecordedRect()
  writingMode: string = ''
  fontSize: number = 0
  outlineWidth: number = 0
  rotationDegrees: number = 0
  translatedTextLength: number = 0
  containerLabel: number = 0
  fillColor: ComicLocalVisualRecordedColor = new ComicLocalVisualRecordedColor()
  textColor: ComicLocalVisualRecordedColor = new ComicLocalVisualRecordedColor()
}

export class ComicLocalVisualAnalysisRecording {
  source: ComicVisualPageSource = new ComicVisualPageSource()
  backendId: string = ''
  profileId: string = ''
  regionRevision: number = 0
  document: ComicPageDocument = new ComicPageDocument()
  adapterTemplate: ComicBackendTemplate = new ComicBackendTemplate()
  timings: ComicLocalVisualAnalysisTimings = new ComicLocalVisualAnalysisTimings()
  groupingStages: ComicLocalVisualGroupingStages = new ComicLocalVisualGroupingStages()
}

export class ComicLocalVisualRenderRecording {
  source: ComicVisualPageSource = new ComicVisualPageSource()
  document: ComicPageDocument = new ComicPageDocument()
  translations: ComicTranslationBatch = new ComicTranslationBatch()
  identity: ComicRenderedPageIdentity = new ComicRenderedPageIdentity()
  renderedPage: ComicRenderedPage = new ComicRenderedPage()
  textMask: Uint8Array | null = null
  containerMask: Uint8Array | null = null
  containerLabels: Uint8Array | null = null
  layouts: ComicLocalVisualRecordedLayout[] = []
  timings: ComicLocalVisualRenderTimings = new ComicLocalVisualRenderTimings()
}

export interface ComicLocalVisualRecordingSink {
  recordAnalysis(recording: ComicLocalVisualAnalysisRecording): void

  recordRender(recording: ComicLocalVisualRenderRecording): void
}
