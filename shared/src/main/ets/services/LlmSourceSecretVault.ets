import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { util } from '@kit.ArkTS'
import { huks } from '@kit.UniversalKeystoreKit'
import {
  LlmSourceProfileContract,
  MAX_LLM_SOURCE_ID_CHARS,
} from './LlmSourceProfileContract'

const SECRET_STORE: string = 'nextn_llm_secrets'
const SECRET_ENVELOPE_KEY: string = 'api_keys_v1'
const KEY_ALIAS: string = 'com.erosteam.nextn.llm-source-secrets.v1'
const ASSOCIATED_DATA: string = 'com.erosteam.nextn.llm-source-secrets'
const NONCE_BYTES: number = 12
const AUTH_TAG_BYTES: number = 16
const MAX_API_KEY_CHARS: number = 8192
const MAX_SECRET_MAP_CHARS: number = 256 * 1024

class LlmSecretEnvelope {
  version: number = 1
  ciphertext: string = ''
  nonce: string = ''
}

class RawLlmSecretEnvelope {
  version: number = 0
  ciphertext: string = ''
  nonce: string = ''
}

/**
 * HUKS-backed API-key storage. Plaintext exists only in the active method
 * frame; callers must never place it in reactive state or diagnostics.
 */
export class LlmSourceSecretVault {
  private static writeTail: Promise<void> = Promise.resolve()
  private static keyReadyTask: Promise<void> | null = null

  static async readApiKey(
    context: common.UIAbilityContext,
    sourceProfileId: string,
  ): Promise<string> {
    const sourceId: string = LlmSourceSecretVault.sourceId(sourceProfileId)
    await LlmSourceSecretVault.writeTail
    const values: Map<string, string> = await LlmSourceSecretVault.readValues(context)
    const value: string | undefined = values.get(sourceId)
    return value === undefined ? '' : value
  }

  static saveApiKey(
    context: common.UIAbilityContext,
    sourceProfileId: string,
    apiKey: string,
  ): Promise<void> {
    const sourceId: string = LlmSourceSecretVault.sourceId(sourceProfileId)
    const canonicalKey: string = LlmSourceSecretVault.apiKey(apiKey)
    return LlmSourceSecretVault.enqueue(async (): Promise<void> => {
      const values: Map<string, string> = await LlmSourceSecretVault.readValues(context)
      values.set(sourceId, canonicalKey)
      await LlmSourceSecretVault.writeValues(context, values)
    })
  }

  /**
   * A non-secret source identity for cache invalidation. The API key itself
   * remains only inside this vault and request-local runtime configs.
   */
  static apiKeyIdentityHash(apiKey: string): string {
    const canonical: string = LlmSourceSecretVault.apiKey(apiKey)
    const digest = cryptoFramework.createMd('SHA256')
    digest.updateSync({ data: new util.TextEncoder().encodeInto(canonical) })
    return LlmSourceSecretVault.hex(digest.digestSync().data)
  }

  /** Empty hashes are retained only for pre-identity legacy source records. */
  static apiKeyMatchesIdentity(apiKey: string, identityHash: string): boolean {
    if (identityHash.length === 0) {
      return true
    }
    return /^[a-f0-9]{64}$/.test(identityHash) &&
      LlmSourceSecretVault.apiKeyIdentityHash(apiKey) === identityHash
  }

  static removeApiKey(
    context: common.UIAbilityContext,
    sourceProfileId: string,
  ): Promise<void> {
    const sourceId: string = LlmSourceSecretVault.sourceId(sourceProfileId)
    return LlmSourceSecretVault.enqueue(async (): Promise<void> => {
      const values: Map<string, string> = await LlmSourceSecretVault.readValues(context)
      if (!values.delete(sourceId)) {
        return
      }
      await LlmSourceSecretVault.writeValues(context, values)
    })
  }

  private static async readValues(context: common.UIAbilityContext): Promise<Map<string, string>> {
    const store: preferences.Preferences =
      await preferences.getPreferences(context, SECRET_STORE)
    const raw: string = store.getSync(SECRET_ENVELOPE_KEY, '') as string
    if (raw.length === 0) {
      return new Map<string, string>()
    }
    const envelope: LlmSecretEnvelope = LlmSourceSecretVault.decodeEnvelope(raw)
    const plaintext: string = await LlmSourceSecretVault.decryptWithExistingKey(envelope)
    return LlmSourceSecretVault.decodeValues(plaintext)
  }

  private static async writeValues(
    context: common.UIAbilityContext,
    values: Map<string, string>,
  ): Promise<void> {
    const store: preferences.Preferences =
      await preferences.getPreferences(context, SECRET_STORE)
    if (values.size === 0) {
      store.deleteSync(SECRET_ENVELOPE_KEY)
      store.flushSync()
      return
    }
    const envelope: LlmSecretEnvelope =
      await LlmSourceSecretVault.encrypt(LlmSourceSecretVault.encodeValues(values))
    store.putSync(SECRET_ENVELOPE_KEY, JSON.stringify(envelope))
    store.flushSync()
  }

  private static decodeEnvelope(raw: string): LlmSecretEnvelope {
    if (raw.length > MAX_SECRET_MAP_CHARS) {
      throw new Error('LLM secret envelope is too large')
    }
    const parsed: RawLlmSecretEnvelope = JSON.parse(raw) as RawLlmSecretEnvelope
    if (parsed === null || typeof parsed !== 'object' || parsed.version !== 1 ||
      typeof parsed.ciphertext !== 'string' || typeof parsed.nonce !== 'string' ||
      parsed.ciphertext.length === 0 || parsed.nonce.length === 0) {
      throw new Error('LLM secret envelope is invalid')
    }
    const result: LlmSecretEnvelope = new LlmSecretEnvelope()
    result.ciphertext = parsed.ciphertext
    result.nonce = parsed.nonce
    return result
  }

  private static encodeValues(values: Map<string, string>): string {
    const record: Record<string, string> = {}
    values.forEach((value: string, key: string): void => {
      record[key] = value
    })
    const encoded: string = JSON.stringify(record)
    if (encoded.length > MAX_SECRET_MAP_CHARS) {
      throw new Error('LLM secret envelope is too large')
    }
    return encoded
  }

  private static decodeValues(raw: string): Map<string, string> {
    if (raw.length > MAX_SECRET_MAP_CHARS) {
      throw new Error('LLM secret payload is too large')
    }
    const parsed: Object = JSON.parse(raw) as Object
    if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
      throw new Error('LLM secret payload is invalid')
    }
    const values: Map<string, string> = new Map<string, string>()
    const record: Record<string, Object> = parsed as Record<string, Object>
    const keys: string[] = Object.keys(record)
    for (let index: number = 0; index < keys.length; index++) {
      const sourceId: string = LlmSourceSecretVault.sourceId(keys[index])
      const value: Object = record[sourceId]
      if (typeof value !== 'string') {
        throw new Error('LLM secret payload is invalid')
      }
      values.set(sourceId, LlmSourceSecretVault.apiKey(value as string))
    }
    return values
  }

  private static sourceId(value: string): string {
    const canonical: string = LlmSourceProfileContract.canonicalText(
      value,
      MAX_LLM_SOURCE_ID_CHARS,
    )
    if (canonical.length === 0 || canonical !== value) {
      throw new Error('LLM source profile ID is invalid')
    }
    return canonical
  }

  private static apiKey(value: string): string {
    if (typeof value !== 'string') {
      throw new Error('LLM API key is invalid')
    }
    const canonical: string = value.trim()
    if (canonical.length === 0 || canonical.length > MAX_API_KEY_CHARS) {
      throw new Error('LLM API key is invalid')
    }
    for (let index: number = 0; index < canonical.length; index++) {
      const code: number = canonical.charCodeAt(index)
      if (code <= 31 || code === 127) {
        throw new Error('LLM API key is invalid')
      }
    }
    return canonical
  }

  private static hex(bytes: Uint8Array): string {
    const output: string[] = []
    for (let index: number = 0; index < bytes.length; index++) {
      output.push(bytes[index].toString(16).padStart(2, '0'))
    }
    return output.join('')
  }

  private static async encrypt(plaintext: string): Promise<LlmSecretEnvelope> {
    await LlmSourceSecretVault.ensureKey()
    const nonce: Uint8Array =
      cryptoFramework.createRandom().generateRandomSync(NONCE_BYTES).data
    const options: huks.HuksOptions = {
      properties: LlmSourceSecretVault.cryptoProperties(
        huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT,
        nonce,
      ),
      inData: new util.TextEncoder().encodeInto(plaintext),
    }
    const handle: huks.HuksSessionHandle = await huks.initSession(KEY_ALIAS, options)
    const result: huks.HuksReturnResult = await huks.finishSession(handle.handle, options)
    const sealed: Uint8Array = result.outData ?? new Uint8Array()
    if (sealed.length <= AUTH_TAG_BYTES) {
      throw new Error('LLM secret encryption output is invalid')
    }
    const envelope: LlmSecretEnvelope = new LlmSecretEnvelope()
    envelope.ciphertext = new util.Base64Helper().encodeToStringSync(sealed)
    envelope.nonce = new util.Base64Helper().encodeToStringSync(nonce)
    return envelope
  }

  private static async decryptWithExistingKey(envelope: LlmSecretEnvelope): Promise<string> {
    const emptyOptions: huks.HuksOptions = { properties: [] }
    if (!await huks.hasKeyItem(KEY_ALIAS, emptyOptions)) {
      throw new Error('LLM secret key is unavailable')
    }
    const sealed: Uint8Array = new util.Base64Helper().decodeSync(envelope.ciphertext)
    const nonce: Uint8Array = new util.Base64Helper().decodeSync(envelope.nonce)
    if (nonce.length !== NONCE_BYTES || sealed.length <= AUTH_TAG_BYTES) {
      throw new Error('LLM secret envelope is invalid')
    }
    const body: Uint8Array = sealed.slice(0, sealed.length - AUTH_TAG_BYTES)
    const tag: Uint8Array = sealed.slice(sealed.length - AUTH_TAG_BYTES)
    const options: huks.HuksOptions = {
      properties: LlmSourceSecretVault.cryptoProperties(
        huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT,
        nonce,
        tag,
      ),
      inData: body,
    }
    const handle: huks.HuksSessionHandle = await huks.initSession(KEY_ALIAS, options)
    const result: huks.HuksReturnResult = await huks.finishSession(handle.handle, options)
    const plaintext: Uint8Array = result.outData ?? new Uint8Array()
    return util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(plaintext)
  }

  private static cryptoProperties(
    purpose: huks.HuksKeyPurpose,
    nonce: Uint8Array,
    authTag?: Uint8Array,
  ): huks.HuksParam[] {
    const properties: huks.HuksParam[] = [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
      { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
      {
        tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA,
        value: new util.TextEncoder().encodeInto(ASSOCIATED_DATA),
      },
    ]
    if (authTag !== undefined) {
      properties.push({ tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: authTag })
    }
    return properties
  }

  private static async ensureKey(): Promise<void> {
    if (LlmSourceSecretVault.keyReadyTask !== null) {
      await LlmSourceSecretVault.keyReadyTask
      return
    }
    const task: Promise<void> = LlmSourceSecretVault.createKeyIfNeeded()
    LlmSourceSecretVault.keyReadyTask = task
    try {
      await task
    } catch (error) {
      LlmSourceSecretVault.keyReadyTask = null
      throw (error as Error)
    }
  }

  private static async createKeyIfNeeded(): Promise<void> {
    const emptyOptions: huks.HuksOptions = { properties: [] }
    if (await huks.hasKeyItem(KEY_ALIAS, emptyOptions)) {
      return
    }
    const properties: huks.HuksParam[] = [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      {
        tag: huks.HuksTag.HUKS_TAG_PURPOSE,
        value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT |
          huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT,
      },
    ]
    await huks.generateKeyItem(KEY_ALIAS, { properties: properties })
  }

  private static enqueue(operation: () => Promise<void>): Promise<void> {
    const queued: Promise<void> = LlmSourceSecretVault.writeTail.then(
      (): Promise<void> => operation(),
      (): Promise<void> => operation(),
    )
    LlmSourceSecretVault.writeTail = queued.catch((): void => {})
    return queued
  }
}
