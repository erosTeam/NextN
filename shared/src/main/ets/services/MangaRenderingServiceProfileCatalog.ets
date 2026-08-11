import {
  MANGA_RENDERING_DETECTION_BALANCED,
  MANGA_RENDERING_DETECTION_HIGH_RECALL,
  MANGA_RENDERING_INPAINTING_FAST,
  MANGA_RENDERING_INPAINTING_QUALITY,
} from '../settings/MangaRenderingServiceSettings'

export const MANGA_RENDERING_SERVICE_BACKEND_ID: string = 'manga-translator-ui'
export const MANGA_RENDERING_SERVICE_PROTOCOL_REVISION: number = 5
export const MANGA_RENDERING_SERVICE_PROFILE_ID: string =
  'manga-translator-ui-v1.9.9-nextn-load-text-v2-recall-v2-geometry-v2'
export const MANGA_RENDERING_SERVICE_NON_JAPANESE_PROFILE_ID: string =
  'manga-translator-ui-v1.9.9-nextn-load-text-v2-non-japanese-v1-geometry-v2'

const JAPANESE_HIGH_RECALL_QUALITY_JSON: string =
  '{"translator":{"translator":"original","target_lang":"CHS"},' +
    '"detector":{"detector":"default","detection_size":2048,"text_threshold":0.5,' +
    '"det_rotate":false,"det_auto_rotate":false,"det_invert":false,' +
    '"det_gamma_correct":false,"box_threshold":0.5,"unclip_ratio":2.5,' +
    '"use_yolo_obb":true,"yolo_obb_conf":0.4,"yolo_obb_iou":0.6,' +
    '"yolo_obb_overlap_threshold":0.1,"min_box_area_ratio":0},' +
    '"ocr":{"ocr":"48px","use_hybrid_ocr":true,"secondary_ocr":"mocr",' +
    '"min_text_length":0,"ignore_bubble":0,"prob":0.1}}'
const NON_JAPANESE_HIGH_RECALL_QUALITY_JSON: string =
  '{"translator":{"translator":"original","target_lang":"CHS"},' +
    '"detector":{"detector":"default","detection_size":2048,"text_threshold":0.5,' +
    '"det_rotate":false,"det_auto_rotate":false,"det_invert":false,' +
    '"det_gamma_correct":false,"box_threshold":0.5,"unclip_ratio":2.5,' +
    '"use_yolo_obb":true,"yolo_obb_conf":0.4,"yolo_obb_iou":0.6,' +
    '"yolo_obb_overlap_threshold":0.1,"min_box_area_ratio":0},' +
    '"ocr":{"ocr":"48px","use_hybrid_ocr":false,"secondary_ocr":"48px",' +
    '"min_text_length":0,"ignore_bubble":0,"prob":0.1}}'

/** Fixed, source-proven manga-translator-ui profiles for the Chinese Reader route. */
export class MangaRenderingServiceProfileCatalog {
  static configJson(
    sourceLanguage: string,
    detectionProfile: string = MANGA_RENDERING_DETECTION_HIGH_RECALL,
    inpaintingProfile: string = MANGA_RENDERING_INPAINTING_QUALITY,
  ): string {
    MangaRenderingServiceProfileCatalog.assertOptions(detectionProfile, inpaintingProfile)
    const japaneseProfile: boolean = MangaRenderingServiceProfileCatalog.usesJapaneseOcr(sourceLanguage)
    if (detectionProfile === MANGA_RENDERING_DETECTION_HIGH_RECALL &&
      inpaintingProfile === MANGA_RENDERING_INPAINTING_QUALITY) {
      return japaneseProfile
        ? JAPANESE_HIGH_RECALL_QUALITY_JSON
        : NON_JAPANESE_HIGH_RECALL_QUALITY_JSON
    }
    return '{"translator":{"translator":"original","target_lang":"CHS"},' +
      MangaRenderingServiceProfileCatalog.detectorJson(detectionProfile) + ',' +
      MangaRenderingServiceProfileCatalog.ocrJson(japaneseProfile) +
      MangaRenderingServiceProfileCatalog.inpainterJson(inpaintingProfile) + '}'
  }

  static profileId(
    sourceLanguage: string,
    detectionProfile: string = MANGA_RENDERING_DETECTION_HIGH_RECALL,
    inpaintingProfile: string = MANGA_RENDERING_INPAINTING_QUALITY,
  ): string {
    MangaRenderingServiceProfileCatalog.assertOptions(detectionProfile, inpaintingProfile)
    let result: string = MangaRenderingServiceProfileCatalog.usesJapaneseOcr(sourceLanguage)
      ? MANGA_RENDERING_SERVICE_PROFILE_ID
      : MANGA_RENDERING_SERVICE_NON_JAPANESE_PROFILE_ID
    if (detectionProfile === MANGA_RENDERING_DETECTION_BALANCED) {
      result = result + '-balanced-v1'
    }
    if (inpaintingProfile === MANGA_RENDERING_INPAINTING_FAST) {
      result = result + '-aot-v1'
    }
    return result
  }

  static assertOptions(detectionProfile: string, inpaintingProfile: string): void {
    if ((detectionProfile !== MANGA_RENDERING_DETECTION_HIGH_RECALL &&
      detectionProfile !== MANGA_RENDERING_DETECTION_BALANCED) ||
      (inpaintingProfile !== MANGA_RENDERING_INPAINTING_QUALITY &&
        inpaintingProfile !== MANGA_RENDERING_INPAINTING_FAST)) {
      throw new Error('Manga rendering service profile options are invalid')
    }
  }

  private static usesJapaneseOcr(sourceLanguage: string): boolean {
    const normalized: string = sourceLanguage.trim().toLowerCase()
    return normalized === 'auto' || normalized === 'ja' || normalized === 'jp' ||
      normalized === 'jpn' || normalized === 'japanese'
  }

  private static detectorJson(detectionProfile: string): string {
    if (detectionProfile === MANGA_RENDERING_DETECTION_HIGH_RECALL) {
      return '"detector":{"detector":"default","detection_size":2048,' +
        '"text_threshold":0.5,"det_rotate":false,"det_auto_rotate":false,' +
        '"det_invert":false,"det_gamma_correct":false,"box_threshold":0.5,' +
        '"unclip_ratio":2.5,"use_yolo_obb":true,"yolo_obb_conf":0.4,' +
        '"yolo_obb_iou":0.6,"yolo_obb_overlap_threshold":0.1,' +
        '"min_box_area_ratio":0}'
    }
    return '"detector":{"detector":"default","detection_size":2048,' +
      '"text_threshold":0.5,"det_rotate":false,"det_auto_rotate":false,' +
      '"det_invert":false,"det_gamma_correct":false,"box_threshold":0.7,' +
      '"unclip_ratio":2.3,"use_yolo_obb":true,"yolo_obb_conf":0.4,' +
      '"yolo_obb_iou":0.6,"yolo_obb_overlap_threshold":0.1,' +
      '"min_box_area_ratio":0.0009}'
  }

  private static ocrJson(japaneseProfile: boolean): string {
    return japaneseProfile
      ? '"ocr":{"ocr":"48px","use_hybrid_ocr":true,"secondary_ocr":"mocr",' +
        '"min_text_length":0,"ignore_bubble":0,"prob":0.1}'
      : '"ocr":{"ocr":"48px","use_hybrid_ocr":false,"secondary_ocr":"48px",' +
        '"min_text_length":0,"ignore_bubble":0,"prob":0.1}'
  }

  private static inpainterJson(inpaintingProfile: string): string {
    return inpaintingProfile === MANGA_RENDERING_INPAINTING_FAST
      ? ',"inpainter":{"inpainter":"default","inpainting_size":2048}'
      : ''
  }
}
