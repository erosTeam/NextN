import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

export const COMIC_VISUAL_ROUTE_LOCAL: string = 'local'
export const COMIC_VISUAL_ROUTE_SELF_HOSTED: string = 'self_hosted'
export const COMIC_VISUAL_ROUTE_TORII: string = 'torii_whole_page'
export const TORII_FONT_NOTO: string = 'noto'
export const TORII_FONT_WILDWORDS: string = 'wildwords'
export const TORII_FONT_MA_SHAN_ZHENG: string = 'mashanzheng'
export const TORII_MODEL_CATALOG_REVIEWED_AT: string = '2026-07-22'
export const TORII_DEFAULT_MODEL_ID: string = 'gemini-3.1-flash-lite'

const PROVIDER_STORE: string = 'nextn_comic_visual_provider'
const ROUTE_KEY: string = 'visual_route'
const MULTIMODAL_ASSIST_KEY: string = 'multimodal_assist'
const TORII_MODEL_KEY: string = 'torii_model'
const TORII_FONT_KEY: string = 'torii_font'
const LEGACY_BILLING_MODE_KEY: string = 'torii_legacy_billing_mode'
const LEGACY_BYOK_PROVIDER_KEY: string = 'torii_legacy_byok_provider'
const LEGACY_BYOK_SOURCE_PROFILE_KEY: string = 'torii_legacy_byok_source_profile'
const LEGACY_BYOK_MODEL_KEY: string = 'torii_legacy_byok_model'

export class ToriiFontOption {
  fontId: string = ''
  displayName: string = ''

  static create(fontId: string, displayName: string): ToriiFontOption {
    const option: ToriiFontOption = new ToriiFontOption()
    option.fontId = fontId
    option.displayName = displayName
    return option
  }
}

/** Target-aware subset of Torii's published font catalog. */
export class ToriiFontCatalog {
  static forTargetLanguage(targetLanguage: string): ToriiFontOption[] {
    const options: ToriiFontOption[] = [
      ToriiFontOption.create(TORII_FONT_NOTO, 'NotoSans'),
    ]
    if (ToriiFontCatalog.isEnglish(targetLanguage)) {
      options.push(ToriiFontOption.create(TORII_FONT_WILDWORDS, 'WildWords'))
      options.push(ToriiFontOption.create(
        TORII_FONT_MA_SHAN_ZHENG,
        'MaShanZheng',
      ))
    } else if (ToriiFontCatalog.isSimplifiedChinese(targetLanguage)) {
      options.push(ToriiFontOption.create(
        TORII_FONT_MA_SHAN_ZHENG,
        'MaShanZheng',
      ))
    }
    return options
  }

  static supports(fontId: string, targetLanguage: string): boolean {
    const options: ToriiFontOption[] =
      ToriiFontCatalog.forTargetLanguage(targetLanguage)
    for (let index: number = 0; index < options.length; index++) {
      if (options[index].fontId === fontId) {
        return true
      }
    }
    return false
  }

  static effectiveFontId(fontId: string, targetLanguage: string): string {
    return ToriiFontCatalog.supports(fontId, targetLanguage)
      ? fontId
      : TORII_FONT_NOTO
  }

  static displayName(fontId: string): string {
    if (fontId === TORII_FONT_WILDWORDS) {
      return 'WildWords'
    }
    if (fontId === TORII_FONT_MA_SHAN_ZHENG) {
      return 'MaShanZheng'
    }
    return 'NotoSans'
  }

  private static normalizedLanguage(targetLanguage: string): string {
    return targetLanguage.trim().toLowerCase().replace('_', '-')
  }

  private static isEnglish(targetLanguage: string): boolean {
    const normalized: string = ToriiFontCatalog.normalizedLanguage(targetLanguage)
    return normalized === 'en' || normalized.startsWith('en-')
  }

  private static isSimplifiedChinese(targetLanguage: string): boolean {
    const normalized: string = ToriiFontCatalog.normalizedLanguage(targetLanguage)
    return normalized === 'zh' || normalized === 'zh-cn' ||
      normalized === 'zh-hans' || normalized.startsWith('zh-hans-')
  }
}

export class ToriiTranslatorModel {
  modelId: string = ''
  displayName: string = ''
  baseCredits: number = 0

  copy(): ToriiTranslatorModel {
    const value: ToriiTranslatorModel = new ToriiTranslatorModel()
    value.modelId = this.modelId
    value.displayName = this.displayName
    value.baseCredits = this.baseCredits
    return value
  }
}

/** Versioned snapshot of the model IDs published by Torii's official API reference. */
export class ToriiTranslatorModelCatalog {
  static all(): ToriiTranslatorModel[] {
    return [
      ToriiTranslatorModelCatalog.model(
        'gemini-3.1-flash-lite', 'Gemini 3.1 Flash Lite', 1,
      ),
      ToriiTranslatorModelCatalog.model('deepseek', 'DeepSeek V4 Flash', 1),
      ToriiTranslatorModelCatalog.model('grok-4.20', 'Grok 4.20', 1),
      ToriiTranslatorModelCatalog.model('kimi-k2.5', 'Kimi K2.5', 2),
      ToriiTranslatorModelCatalog.model('gpt-5.4', 'GPT-5.4', 2),
      ToriiTranslatorModelCatalog.model('gemini-3-flash', 'Gemini 3 Flash', 2),
      ToriiTranslatorModelCatalog.model(
        'claude-sonnet-4.6', 'Claude Sonnet 4.6', 2,
      ),
      ToriiTranslatorModelCatalog.model(
        'gemini-3.5-flash', 'Gemini 3.5 Flash', 3,
      ),
    ]
  }

  static find(modelId: string): ToriiTranslatorModel | null {
    const models: ToriiTranslatorModel[] = ToriiTranslatorModelCatalog.all()
    for (let index: number = 0; index < models.length; index++) {
      if (models[index].modelId === modelId) {
        return models[index]
      }
    }
    return null
  }

  private static model(
    modelId: string,
    displayName: string,
    baseCredits: number,
  ): ToriiTranslatorModel {
    const model: ToriiTranslatorModel = new ToriiTranslatorModel()
    model.modelId = modelId
    model.displayName = displayName
    model.baseCredits = baseCredits
    return model
  }
}

export class ComicVisualProviderSettingsSnapshot {
  route: string = COMIC_VISUAL_ROUTE_LOCAL
  multimodalTranslationEnabled: boolean = true
  toriiModelId: string = TORII_DEFAULT_MODEL_ID
  toriiFontId: string = TORII_FONT_NOTO

  copy(): ComicVisualProviderSettingsSnapshot {
    const value: ComicVisualProviderSettingsSnapshot =
      new ComicVisualProviderSettingsSnapshot()
    value.route = this.route
    value.multimodalTranslationEnabled = this.multimodalTranslationEnabled
    value.toriiModelId = this.toriiModelId
    value.toriiFontId = this.toriiFontId
    return value
  }

  assertValid(): void {
    if ((this.route !== COMIC_VISUAL_ROUTE_LOCAL &&
      this.route !== COMIC_VISUAL_ROUTE_SELF_HOSTED &&
      this.route !== COMIC_VISUAL_ROUTE_TORII) ||
      ToriiTranslatorModelCatalog.find(this.toriiModelId) === null ||
      (this.toriiFontId !== TORII_FONT_NOTO &&
        this.toriiFontId !== TORII_FONT_WILDWORDS &&
        this.toriiFontId !== TORII_FONT_MA_SHAN_ZHENG)) {
      throw new Error('Comic visual provider settings are invalid')
    }
  }
}

export class ComicVisualProviderSettings {
  private static runtimeRevisionValue: number = 0

  static runtimeRevision(): number {
    return ComicVisualProviderSettings.runtimeRevisionValue
  }

  /** Revalidates imported settings and invalidates any retained runtime backend. */
  static async reapplyAfterBackup(context: common.UIAbilityContext): Promise<void> {
    await ComicVisualProviderSettings.load(context)
    ComicVisualProviderSettings.runtimeRevisionValue++
  }

  static async load(
    context: common.UIAbilityContext,
  ): Promise<ComicVisualProviderSettingsSnapshot> {
    const store: preferences.Preferences = await preferences.getPreferences(
      context,
      PROVIDER_STORE,
    )
    const snapshot: ComicVisualProviderSettingsSnapshot =
      new ComicVisualProviderSettingsSnapshot()
    snapshot.route = store.getSync(ROUTE_KEY, COMIC_VISUAL_ROUTE_LOCAL) as string
    snapshot.multimodalTranslationEnabled = store.getSync(
      MULTIMODAL_ASSIST_KEY,
      true,
    ) as boolean
    snapshot.toriiModelId = store.getSync(
      TORII_MODEL_KEY,
      TORII_DEFAULT_MODEL_ID,
    ) as string
    snapshot.toriiFontId = store.getSync(TORII_FONT_KEY, TORII_FONT_NOTO) as string
    ComicVisualProviderSettings.retireLegacyByokSettings(store)
    try {
      snapshot.assertValid()
      return snapshot
    } catch (_error) {
      return new ComicVisualProviderSettingsSnapshot()
    }
  }

  static async save(
    context: common.UIAbilityContext,
    snapshot: ComicVisualProviderSettingsSnapshot,
  ): Promise<void> {
    snapshot.assertValid()
    const store: preferences.Preferences = await preferences.getPreferences(
      context,
      PROVIDER_STORE,
    )
    store.putSync(ROUTE_KEY, snapshot.route)
    store.putSync(MULTIMODAL_ASSIST_KEY, snapshot.multimodalTranslationEnabled)
    store.putSync(TORII_MODEL_KEY, snapshot.toriiModelId)
    store.putSync(TORII_FONT_KEY, snapshot.toriiFontId)
    ComicVisualProviderSettings.deleteLegacyByokSettings(store)
    store.flushSync()
    ComicVisualProviderSettings.runtimeRevisionValue++
  }

  private static retireLegacyByokSettings(store: preferences.Preferences): void {
    const billingMode: string = store.getSync(LEGACY_BILLING_MODE_KEY, '') as string
    const provider: string = store.getSync(LEGACY_BYOK_PROVIDER_KEY, '') as string
    const sourceProfile: string =
      store.getSync(LEGACY_BYOK_SOURCE_PROFILE_KEY, '') as string
    const model: string = store.getSync(LEGACY_BYOK_MODEL_KEY, '') as string
    if (billingMode.length === 0 && provider.length === 0 &&
      sourceProfile.length === 0 && model.length === 0) {
      return
    }
    ComicVisualProviderSettings.deleteLegacyByokSettings(store)
    store.flushSync()
  }

  private static deleteLegacyByokSettings(store: preferences.Preferences): void {
    store.deleteSync(LEGACY_BILLING_MODE_KEY)
    store.deleteSync(LEGACY_BYOK_PROVIDER_KEY)
    store.deleteSync(LEGACY_BYOK_SOURCE_PROFILE_KEY)
    store.deleteSync(LEGACY_BYOK_MODEL_KEY)
  }
}
