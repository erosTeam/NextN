import { common } from '@kit.AbilityKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileIo } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import { NhReaderSuperResolutionModel } from '../model/NhReaderSettings'
import { connectReaderEnhancementModels } from '../state/ReaderEnhancementModelsState'
import { ReaderNativeSuperResolutionConfig } from './ReaderNativeSuperResolution'

const MODEL_DIRECTORY: string = 'nextn-reader-super-resolution-models'
const MODEL_PACK_RELEASE_BASE: string =
  'https://github.com/erosTeam/NextE-Models/releases/download/model-pack-v1.0.0'
const LEGACY_ACCELERATED_FILE_NAME: string = 'waifu2x-art-noise0-x2-156-fp16.ms'
const CONNECT_TIMEOUT_MS: number = 15000
const READ_TIMEOUT_MS: number = 10 * 60 * 1000
const HASH_CHUNK_BYTES: number = 128 * 1024
const REAL_ESRGAN_SOURCE_PARAM_FILE_NAME: string = 'realesrgan_x2plus.param'
const REAL_ESRGAN_MODEL_FILE_NAME: string = 'realesrgan_x2plus.bin'
const REAL_ESRGAN_SOURCE_PARAM_BYTES: number = 292200
const REAL_ESRGAN_RUNTIME_PARAM_BYTES: number = 288376
const REAL_ESRGAN_SOURCE_MODEL_BYTES: number = 66814128
const REAL_ESRGAN_RUNTIME_MODEL_BYTES: number = 66814088
const REAL_ESRGAN_MODEL_PREFIX_BYTES: number = 40
const REAL_ESRGAN_SOURCE_PARAM_SHA256: string =
  '79cb4938c0465a3b7d66aa21e9dc0e595a2ab2015b453831426f37a536b925b5'
const REAL_ESRGAN_RUNTIME_PARAM_SHA256: string =
  'b17f57a46574e28bbe405ed1d95edc99d6fa2abc777b477a2ba8399ffa3ea4dd'
const REAL_ESRGAN_SOURCE_MODEL_SHA256: string =
  '119cbbcf701a976a016d03fc5c457157e52a94f5e3e929e562e9ec87596d782b'
const REAL_ESRGAN_RUNTIME_MODEL_SHA256: string =
  '80154ed738cd609c639fed031e9d2bc5d612f4895b91b73e623e88fa0c19f8b9'
const REAL_ESRGAN_SOURCE_REVISION: string = '2533a62c56b4f080eb90a039250752bc21e96259'
const REAL_ESRGAN_SOURCE_REPOSITORY: string = 'bpawnzZ/Real-ESRGAN-x2plus-NCNN'

export class ReaderSuperResolutionModelDefinition {
  id: NhReaderSuperResolutionModel = NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X
  directoryName: string = ''
  paramFileName: string = 'noise0_scale2.0x_model.param'
  modelFileName: string = 'noise0_scale2.0x_model.bin'
  paramBytes: number = 0
  modelBytes: number = 0
  paramSha256: string = ''
  modelSha256: string = ''
  paramUrls: string[] = []
  modelUrls: string[] = []
  labelStringKey: string = ''
  hintStringKey: string = ''
  managerTitleStringKey: string = ''
  managerScopeStringKey: string = ''
  managerPerformanceStringKey: string = ''
  managerDetailsStringKey: string = ''
  nativeModelKind: number = 0
  tileSize: number = 142
  prepadding: number = 7
  threads: number = 2
  inputName: string = 'Input1'
  outputName: string = 'Eltwise4'
  effectStrengthPercent: number = 100

  bytes(): number {
    return this.paramBytes + this.modelBytes
  }

  nativeConfig(): ReaderNativeSuperResolutionConfig {
    const config: ReaderNativeSuperResolutionConfig = new ReaderNativeSuperResolutionConfig()
    config.modelKind = this.nativeModelKind
    config.tileSize = this.tileSize
    config.prepadding = this.prepadding
    config.threads = this.threads
    config.inputName = this.inputName
    config.outputName = this.outputName
    config.effectStrengthPercent = this.effectStrengthPercent
    return config
  }
}

export class ReaderSuperResolutionModelPaths {
  paramPath: string = ''
  modelPath: string = ''
}

class ReaderSuperResolutionModelAsset {
  urls: string[] = []
  finalPath: string = ''
  bytes: number = 0
  sha256: string = ''
}

function artDefinition(): ReaderSuperResolutionModelDefinition {
  const definition: ReaderSuperResolutionModelDefinition = new ReaderSuperResolutionModelDefinition()
  definition.id = NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X
  // Keep the established art pair in its original private directory so an
  // existing installation is selected without copying, deleting, or fetching.
  definition.directoryName = ''
  definition.paramBytes = 1047
  definition.modelBytes = 1106248
  definition.paramSha256 = '413195ffde05b4d43807792c6c020c916cecdf25dcf002ee83f5e28d5cc246c6'
  definition.modelSha256 = 'e1d2c4d91be98e72c0d48d08626cbe7d879aa2b80f740133dcc0d860eabb4189'
  definition.paramUrls = [`${MODEL_PACK_RELEASE_BASE}/waifu2x-art-noise0-2x.param`]
  definition.modelUrls = [`${MODEL_PACK_RELEASE_BASE}/waifu2x-art-noise0-2x.bin`]
  definition.labelStringKey = 'settings_reader_enhancement_model_art_title'
  definition.hintStringKey = 'settings_reader_enhancement_model_art_hint'
  definition.managerTitleStringKey = 'settings_reader_enhancement_model_art_manager_title'
  definition.managerScopeStringKey = 'settings_reader_enhancement_model_scope_comics_illustrations'
  definition.managerPerformanceStringKey = 'settings_reader_enhancement_model_performance_seconds'
  definition.managerDetailsStringKey = 'settings_reader_enhancement_model_art_details'
  return definition
}

function photoDefinition(): ReaderSuperResolutionModelDefinition {
  const definition: ReaderSuperResolutionModelDefinition = new ReaderSuperResolutionModelDefinition()
  definition.id = NhReaderSuperResolutionModel.WAIFU2X_PHOTO_NOISE0_2X
  definition.directoryName = 'waifu2x-photo-noise0-2x-ncnn-v1'
  definition.paramBytes = 1047
  definition.modelBytes = 1106248
  definition.paramSha256 = '413195ffde05b4d43807792c6c020c916cecdf25dcf002ee83f5e28d5cc246c6'
  definition.modelSha256 = 'fbfc8d57e4333748c9c6db2ec4d5454c98cd1c6aa53289f2989c3bdb4e84b673'
  definition.paramUrls = [`${MODEL_PACK_RELEASE_BASE}/waifu2x-photo-noise0-2x.param`]
  definition.modelUrls = [`${MODEL_PACK_RELEASE_BASE}/waifu2x-photo-noise0-2x.bin`]
  definition.labelStringKey = 'settings_reader_enhancement_model_photo_title'
  definition.hintStringKey = 'settings_reader_enhancement_model_photo_hint'
  definition.managerTitleStringKey = 'settings_reader_enhancement_model_photo_manager_title'
  definition.managerScopeStringKey = 'settings_reader_enhancement_model_scope_scans_photos'
  definition.managerPerformanceStringKey = 'settings_reader_enhancement_model_performance_seconds'
  definition.managerDetailsStringKey = 'settings_reader_enhancement_model_photo_details'
  return definition
}

/**
 * The upstream x2plus graph has a dynamic PixelUnshuffle prelude that the
 * Harmony ncnn runtime cannot load. Its private installer below transforms
 * only that verified prelude into the equivalent Reorg graph before promotion.
 */
function realEsrganDefinition(): ReaderSuperResolutionModelDefinition {
  const definition: ReaderSuperResolutionModelDefinition = new ReaderSuperResolutionModelDefinition()
  definition.id = NhReaderSuperResolutionModel.REAL_ESRGAN_X2PLUS
  definition.directoryName = 'realesrgan-x2plus-ncnn-fp32-v1'
  definition.paramFileName = 'realesrgan_x2plus.compat.param'
  definition.modelFileName = REAL_ESRGAN_MODEL_FILE_NAME
  definition.paramBytes = REAL_ESRGAN_RUNTIME_PARAM_BYTES
  definition.modelBytes = REAL_ESRGAN_RUNTIME_MODEL_BYTES
  definition.paramSha256 = REAL_ESRGAN_RUNTIME_PARAM_SHA256
  definition.modelSha256 = REAL_ESRGAN_RUNTIME_MODEL_SHA256
  definition.labelStringKey = 'settings_reader_enhancement_model_realesrgan_title'
  definition.hintStringKey = 'settings_reader_enhancement_model_realesrgan_hint'
  definition.managerTitleStringKey = 'settings_reader_enhancement_model_realesrgan_manager_title'
  definition.managerScopeStringKey = 'settings_reader_enhancement_model_scope_photos_textures'
  definition.managerPerformanceStringKey =
    'settings_reader_enhancement_model_performance_device_dependent'
  definition.managerDetailsStringKey = 'settings_reader_enhancement_model_realesrgan_details'
  definition.nativeModelKind = 1
  definition.tileSize = 128
  definition.prepadding = 10
  definition.threads = 4
  definition.inputName = 'input'
  definition.outputName = 'output'
  definition.effectStrengthPercent = 80
  return definition
}

const USER_SELECTABLE_DEFINITIONS: ReaderSuperResolutionModelDefinition[] = [
  artDefinition(),
  photoDefinition(),
  realEsrganDefinition(),
]

/**
 * Owns explicitly downloaded, byte-verified portable Reader enhancement
 * pairs. Reading never downloads assets; the existing art pair stays in
 * place, while every additional pair is isolated in its own private folder.
 */
export class ReaderSuperResolutionModelService {
  private static installTasks: Map<string, Promise<void>> = new Map<string, Promise<void>>()

  static definitions(): ReaderSuperResolutionModelDefinition[] {
    return USER_SELECTABLE_DEFINITIONS
  }

  static definition(model: NhReaderSuperResolutionModel): ReaderSuperResolutionModelDefinition | null {
    for (let index: number = 0; index < USER_SELECTABLE_DEFINITIONS.length; index++) {
      if (USER_SELECTABLE_DEFINITIONS[index].id === model) {
        return USER_SELECTABLE_DEFINITIONS[index]
      }
    }
    return null
  }

  static async isInstalled(
    context: common.UIAbilityContext,
    model: NhReaderSuperResolutionModel = NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X,
  ): Promise<boolean> {
    const definition: ReaderSuperResolutionModelDefinition | null =
      ReaderSuperResolutionModelService.definition(model)
    if (definition === null) {
      return false
    }
    const paths: ReaderSuperResolutionModelPaths =
      ReaderSuperResolutionModelService.paths(context, definition)
    return ReaderSuperResolutionModelService.validateFile(
      paths.paramPath,
      definition.paramBytes,
      definition.paramSha256,
    ) && ReaderSuperResolutionModelService.validateFile(
      paths.modelPath,
      definition.modelBytes,
      definition.modelSha256,
    )
  }

  static async installedModels(context: common.UIAbilityContext): Promise<NhReaderSuperResolutionModel[]> {
    const result: NhReaderSuperResolutionModel[] = []
    const definitions: ReaderSuperResolutionModelDefinition[] = ReaderSuperResolutionModelService.definitions()
    for (let index: number = 0; index < definitions.length; index++) {
      if (await ReaderSuperResolutionModelService.isInstalled(context, definitions[index].id)) {
        result.push(definitions[index].id)
      }
    }
    return result
  }

  static async pathsIfReady(
    context: common.UIAbilityContext,
    model: NhReaderSuperResolutionModel = NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X,
  ): Promise<ReaderSuperResolutionModelPaths | null> {
    const definition: ReaderSuperResolutionModelDefinition | null =
      ReaderSuperResolutionModelService.definition(model)
    if (definition === null || !await ReaderSuperResolutionModelService.isInstalled(context, model)) {
      return null
    }
    return ReaderSuperResolutionModelService.paths(context, definition)
  }

  static nativeConfig(model: NhReaderSuperResolutionModel): ReaderNativeSuperResolutionConfig | null {
    const definition: ReaderSuperResolutionModelDefinition | null =
      ReaderSuperResolutionModelService.definition(model)
    return definition === null ? null : definition.nativeConfig()
  }

  static async install(context: common.UIAbilityContext, model: NhReaderSuperResolutionModel): Promise<void> {
    const definition: ReaderSuperResolutionModelDefinition | null =
      ReaderSuperResolutionModelService.definition(model)
    if (definition === null) {
      throw new Error('Selected Reader enhancement model is unavailable.')
    }
    if (await ReaderSuperResolutionModelService.isInstalled(context, model)) {
      return
    }
    const existing: Promise<void> | undefined = ReaderSuperResolutionModelService.installTasks.get(model)
    if (existing !== undefined) {
      await existing
      return
    }
    const task: Promise<void> = ReaderSuperResolutionModelService.installInternal(context, definition)
    ReaderSuperResolutionModelService.installTasks.set(model, task)
    try {
      await task
      connectReaderEnhancementModels().publishMutation()
    } finally {
      if (ReaderSuperResolutionModelService.installTasks.get(model) === task) {
        ReaderSuperResolutionModelService.installTasks.delete(model)
      }
    }
  }

  static remove(context: common.UIAbilityContext, model: NhReaderSuperResolutionModel): void {
    const definition: ReaderSuperResolutionModelDefinition | null =
      ReaderSuperResolutionModelService.definition(model)
    if (definition === null) {
      return
    }
    const paths: ReaderSuperResolutionModelPaths =
      ReaderSuperResolutionModelService.paths(context, definition)
    ReaderSuperResolutionModelService.removeIfExists(paths.paramPath)
    ReaderSuperResolutionModelService.removeIfExists(paths.modelPath)
    ReaderSuperResolutionModelService.removeIfExists(`${paths.paramPath}.part`)
    ReaderSuperResolutionModelService.removeIfExists(`${paths.modelPath}.part`)
    if (model === NhReaderSuperResolutionModel.REAL_ESRGAN_X2PLUS) {
      const directory: string = ReaderSuperResolutionModelService.definitionDirectory(context, definition)
      ReaderSuperResolutionModelService.removeIfExists(
        `${directory}/${REAL_ESRGAN_SOURCE_PARAM_FILE_NAME}`,
      )
      ReaderSuperResolutionModelService.removeIfExists(
        `${directory}/${REAL_ESRGAN_SOURCE_PARAM_FILE_NAME}.part`,
      )
      ReaderSuperResolutionModelService.removeIfExists(`${paths.modelPath}.source`)
      ReaderSuperResolutionModelService.removeIfExists(`${paths.modelPath}.source.part`)
    }
    if (model === NhReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X) {
      ReaderSuperResolutionModelService.removeIfExists(
        `${ReaderSuperResolutionModelService.modelDirectory(context)}/${LEGACY_ACCELERATED_FILE_NAME}`,
      )
    }
    connectReaderEnhancementModels().publishMutation()
  }

  private static async installInternal(
    context: common.UIAbilityContext,
    definition: ReaderSuperResolutionModelDefinition,
  ): Promise<void> {
    const directory: string = ReaderSuperResolutionModelService.definitionDirectory(context, definition)
    ReaderSuperResolutionModelService.ensureDirectory(directory)
    const paths: ReaderSuperResolutionModelPaths =
      ReaderSuperResolutionModelService.paths(context, definition)
    if (definition.id === NhReaderSuperResolutionModel.REAL_ESRGAN_X2PLUS) {
      await ReaderSuperResolutionModelService.installRealEsrgan(context, definition, paths)
      return
    }
    const param: ReaderSuperResolutionModelAsset = new ReaderSuperResolutionModelAsset()
    param.urls = definition.paramUrls
    param.finalPath = paths.paramPath
    param.bytes = definition.paramBytes
    param.sha256 = definition.paramSha256
    const model: ReaderSuperResolutionModelAsset = new ReaderSuperResolutionModelAsset()
    model.urls = definition.modelUrls
    model.finalPath = paths.modelPath
    model.bytes = definition.modelBytes
    model.sha256 = definition.modelSha256
    await ReaderSuperResolutionModelService.installAsset(param)
    await ReaderSuperResolutionModelService.installAsset(model)
    if (!await ReaderSuperResolutionModelService.isInstalled(context, definition.id)) {
      throw new Error('Reader enhancement model verification failed.')
    }
  }

  /**
   * Keep the source pair and generated runtime pair distinct until both
   * derived artifacts have passed their immutable checksums. The final files
   * are the only paths exposed to the Reader native runtime.
   */
  private static async installRealEsrgan(
    context: common.UIAbilityContext,
    definition: ReaderSuperResolutionModelDefinition,
    paths: ReaderSuperResolutionModelPaths,
  ): Promise<void> {
    if (await ReaderSuperResolutionModelService.isInstalled(context, definition.id)) {
      return
    }
    const directory: string = ReaderSuperResolutionModelService.definitionDirectory(context, definition)
    const sourceParamPath: string = `${directory}/${REAL_ESRGAN_SOURCE_PARAM_FILE_NAME}`
    const sourceModelPath: string = `${paths.modelPath}.source`
    const runtimeParamPart: string = `${paths.paramPath}.part`
    const runtimeModelPart: string = `${paths.modelPath}.part`
    ReaderSuperResolutionModelService.removeIfExists(runtimeParamPart)
    ReaderSuperResolutionModelService.removeIfExists(runtimeModelPart)
    try {
      const sourceParam: ReaderSuperResolutionModelAsset = new ReaderSuperResolutionModelAsset()
      sourceParam.urls = ReaderSuperResolutionModelService.realEsrganAssetUrls(
        REAL_ESRGAN_SOURCE_PARAM_FILE_NAME,
      )
      sourceParam.finalPath = sourceParamPath
      sourceParam.bytes = REAL_ESRGAN_SOURCE_PARAM_BYTES
      sourceParam.sha256 = REAL_ESRGAN_SOURCE_PARAM_SHA256
      await ReaderSuperResolutionModelService.installAsset(sourceParam)

      const sourceModel: ReaderSuperResolutionModelAsset = new ReaderSuperResolutionModelAsset()
      sourceModel.urls = ReaderSuperResolutionModelService.realEsrganAssetUrls(
        REAL_ESRGAN_MODEL_FILE_NAME,
      )
      sourceModel.finalPath = sourceModelPath
      sourceModel.bytes = REAL_ESRGAN_SOURCE_MODEL_BYTES
      sourceModel.sha256 = REAL_ESRGAN_SOURCE_MODEL_SHA256
      await ReaderSuperResolutionModelService.installAsset(sourceModel)

      ReaderSuperResolutionModelService.createRealEsrganRuntimeParam(
        sourceParamPath,
        runtimeParamPart,
      )
      if (!ReaderSuperResolutionModelService.validateFile(
        runtimeParamPart,
        definition.paramBytes,
        definition.paramSha256,
      )) {
        throw new Error('Real-ESRGAN runtime param verification failed.')
      }
      ReaderSuperResolutionModelService.createRealEsrganRuntimeModel(
        sourceModelPath,
        runtimeModelPart,
      )
      if (!ReaderSuperResolutionModelService.validateFile(
        runtimeModelPart,
        definition.modelBytes,
        definition.modelSha256,
      )) {
        throw new Error('Real-ESRGAN runtime model verification failed.')
      }
      ReaderSuperResolutionModelService.removeIfExists(paths.paramPath)
      ReaderSuperResolutionModelService.removeIfExists(paths.modelPath)
      fileIo.renameSync(runtimeParamPart, paths.paramPath)
      fileIo.renameSync(runtimeModelPart, paths.modelPath)
      ReaderSuperResolutionModelService.removeIfExists(sourceParamPath)
      ReaderSuperResolutionModelService.removeIfExists(sourceModelPath)
      if (!await ReaderSuperResolutionModelService.isInstalled(context, definition.id)) {
        throw new Error('Real-ESRGAN runtime promotion failed.')
      }
    } catch (error) {
      ReaderSuperResolutionModelService.removeIfExists(runtimeParamPart)
      ReaderSuperResolutionModelService.removeIfExists(runtimeModelPart)
      ReaderSuperResolutionModelService.removeIfExists(sourceParamPath)
      ReaderSuperResolutionModelService.removeIfExists(sourceModelPath)
      throw error as Error
    }
  }

  private static createRealEsrganRuntimeParam(sourcePath: string, targetPath: string): void {
    const source: string = fileIo.readTextSync(sourcePath)
    const sourceLines: string[] = source.split('\n')
    if (sourceLines.length < 3 || sourceLines[0] !== '7767517' ||
      sourceLines[1] !== '1408 2199') {
      throw new Error('Unsupported Real-ESRGAN source param.')
    }
    let convFirstIndex: number = -1
    for (let index: number = 2; index < sourceLines.length; index++) {
      if (sourceLines[index].startsWith('Convolution') &&
        sourceLines[index].includes('/conv_first/Conv')) {
        convFirstIndex = index
        break
      }
    }
    if (convFirstIndex < 0) {
      throw new Error('Real-ESRGAN source param is incomplete.')
    }
    const runtimeLines: string[] = [
      'Input            input                    0 1 input',
      'Reorg            pixel_unshuffle          1 1 input /Reshape_1_output_0 0=2 1=0',
    ]
    for (let index: number = convFirstIndex; index < sourceLines.length; index++) {
      runtimeLines.push(sourceLines[index])
    }
    const output: string = '7767517\n1371 2154\n' + runtimeLines.join('\n')
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(
        targetPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      fileIo.writeSync(file.fd, output)
    } finally {
      if (file !== null) {
        fileIo.closeSync(file)
      }
    }
  }

  private static createRealEsrganRuntimeModel(sourcePath: string, targetPath: string): void {
    if (ReaderSuperResolutionModelService.fileSize(sourcePath) !== REAL_ESRGAN_SOURCE_MODEL_BYTES) {
      throw new Error('Unexpected Real-ESRGAN source model size.')
    }
    let source: fileIo.File | null = null
    let target: fileIo.File | null = null
    let readOffset: number = REAL_ESRGAN_MODEL_PREFIX_BYTES
    let totalWritten: number = 0
    try {
      source = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY)
      target = fileIo.openSync(
        targetPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      while (totalWritten < REAL_ESRGAN_RUNTIME_MODEL_BYTES) {
        const length: number = Math.min(
          HASH_CHUNK_BYTES,
          REAL_ESRGAN_RUNTIME_MODEL_BYTES - totalWritten,
        )
        const buffer: ArrayBuffer = new ArrayBuffer(length)
        const read: number = fileIo.readSync(
          source.fd,
          buffer,
          { offset: readOffset, length: length },
        )
        if (read !== length) {
          throw new Error('Real-ESRGAN runtime model read failed.')
        }
        const written: number = fileIo.writeSync(target.fd, buffer, { length: read })
        if (written !== read) {
          throw new Error('Real-ESRGAN runtime model write failed.')
        }
        readOffset += read
        totalWritten += written
      }
    } finally {
      if (target !== null) {
        fileIo.closeSync(target)
      }
      if (source !== null) {
        fileIo.closeSync(source)
      }
    }
  }

  private static realEsrganAssetUrls(fileName: string): string[] {
    return [
      `${MODEL_PACK_RELEASE_BASE}/${fileName}`,
      `https://huggingface.co/${REAL_ESRGAN_SOURCE_REPOSITORY}/resolve/` +
        `${REAL_ESRGAN_SOURCE_REVISION}/${fileName}`,
    ]
  }

  private static async installAsset(asset: ReaderSuperResolutionModelAsset): Promise<void> {
    if (ReaderSuperResolutionModelService.validateFile(asset.finalPath, asset.bytes, asset.sha256)) {
      return
    }
    let lastError: Error | null = null
    for (let index: number = 0; index < asset.urls.length; index++) {
      const temporaryPath: string = `${asset.finalPath}.part`
      ReaderSuperResolutionModelService.removeIfExists(temporaryPath)
      let file: fileIo.File | null = null
      let request: http.HttpRequest | null = null
      let written: number = 0
      let failed: boolean = false
      let promoted: boolean = false
      try {
        file = fileIo.openSync(
          temporaryPath,
          fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
        )
        request = http.createHttp()
        request.on('dataReceiveProgress', (progress: http.DataReceiveProgressInfo): void => {
          if (progress.totalSize > asset.bytes) {
            failed = true
            request?.destroy()
          }
        })
        request.on('dataReceive', (data: ArrayBuffer): void => {
          if (file === null || failed || written + data.byteLength > asset.bytes) {
            failed = true
            request?.destroy()
            return
          }
          try {
            const count: number = fileIo.writeSync(file.fd, data)
            if (count !== data.byteLength) {
              failed = true
              request?.destroy()
              return
            }
            written += count
          } catch (_error) {
            failed = true
            request?.destroy()
          }
        })
        const status: number = await request.requestInStream(asset.urls[index], {
          method: http.RequestMethod.GET,
          usingCache: false,
          connectTimeout: CONNECT_TIMEOUT_MS,
          readTimeout: READ_TIMEOUT_MS,
          header: {
            Accept: 'application/octet-stream',
            'User-Agent': 'NextN/1.0.0',
          },
        })
        if (failed || status < 200 || status >= 300 || written !== asset.bytes) {
          throw new Error('Reader enhancement model download failed.')
        }
        request.destroy()
        request = null
        fileIo.closeSync(file)
        file = null
        if (!ReaderSuperResolutionModelService.validateFile(temporaryPath, asset.bytes, asset.sha256)) {
          throw new Error('Reader enhancement model verification failed.')
        }
        ReaderSuperResolutionModelService.removeIfExists(asset.finalPath)
        fileIo.renameSync(temporaryPath, asset.finalPath)
        promoted = true
        return
      } catch (error) {
        lastError = error as Error
      } finally {
        if (request !== null) {
          request.destroy()
        }
        if (file !== null) {
          fileIo.closeSync(file)
        }
        if (!promoted) {
          ReaderSuperResolutionModelService.removeIfExists(temporaryPath)
        }
      }
    }
    throw lastError === null ? new Error('Reader enhancement model download failed.') : lastError
  }

  private static paths(
    context: common.UIAbilityContext,
    definition: ReaderSuperResolutionModelDefinition,
  ): ReaderSuperResolutionModelPaths {
    const directory: string = ReaderSuperResolutionModelService.definitionDirectory(context, definition)
    const paths: ReaderSuperResolutionModelPaths = new ReaderSuperResolutionModelPaths()
    paths.paramPath = `${directory}/${definition.paramFileName}`
    paths.modelPath = `${directory}/${definition.modelFileName}`
    return paths
  }

  private static definitionDirectory(
    context: common.UIAbilityContext,
    definition: ReaderSuperResolutionModelDefinition,
  ): string {
    const root: string = ReaderSuperResolutionModelService.modelDirectory(context)
    return definition.directoryName.length === 0 ? root : `${root}/${definition.directoryName}`
  }

  private static modelDirectory(context: common.UIAbilityContext): string {
    if (context.filesDir.length === 0) {
      throw new Error('Private model storage is unavailable.')
    }
    return `${context.filesDir}/${MODEL_DIRECTORY}`
  }

  private static ensureDirectory(directory: string): void {
    try {
      fileIo.mkdirSync(directory, true)
    } catch (error) {
      if (!fileIo.accessSync(directory)) {
        throw error as Error
      }
    }
  }

  private static validateFile(path: string, bytes: number, sha256: string): boolean {
    return ReaderSuperResolutionModelService.fileSize(path) === bytes &&
      ReaderSuperResolutionModelService.sha256(path) === sha256
  }

  private static fileSize(path: string): number {
    try {
      return fileIo.statSync(path).size
    } catch (_error) {
      return 0
    }
  }

  private static removeIfExists(path: string): void {
    try {
      fileIo.unlinkSync(path)
    } catch (_error) {}
  }

  private static sha256(path: string): string {
    const digest = cryptoFramework.createMd('SHA256')
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
      while (true) {
        const buffer: ArrayBuffer = new ArrayBuffer(HASH_CHUNK_BYTES)
        const read: number = fileIo.readSync(file.fd, buffer, { length: buffer.byteLength })
        if (read <= 0) {
          break
        }
        digest.updateSync({ data: new Uint8Array(buffer, 0, read) })
      }
      const bytes: Uint8Array = new Uint8Array(digest.digestSync().data)
      let output: string = ''
      for (let index: number = 0; index < bytes.length; index++) {
        output += bytes[index].toString(16).padStart(2, '0')
      }
      return output
    } catch (_error) {
      return ''
    } finally {
      if (file !== null) {
        fileIo.closeSync(file)
      }
    }
  }
}
