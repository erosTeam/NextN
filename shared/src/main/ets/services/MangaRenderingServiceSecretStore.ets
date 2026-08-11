import { common } from '@kit.AbilityKit'
import { LlmSourceSecretVault } from './LlmSourceSecretVault'

const SECRET_OWNER_ID: string = 'manga-rendering-service'
const CREDENTIAL_VERSION: number = 1
const MIN_USERNAME_CHARS: number = 2
const MAX_USERNAME_CHARS: number = 50
const MIN_PASSWORD_CHARS: number = 6
const MAX_PASSWORD_CHARS: number = 2048

class StoredMangaRenderingCredential {
  version: number = CREDENTIAL_VERSION
  username: string = ''
  password: string = ''
}

/**
 * Keeps the optional sidecar account in the existing HUKS-backed secret vault.
 * It deliberately has no reactive state and does not retain a service token.
 */
export class MangaRenderingServiceCredential {
  username: string = ''
  password: string = ''

  configured(): boolean {
    return this.username.length > 0 && this.password.length > 0
  }

  copy(): MangaRenderingServiceCredential {
    const result: MangaRenderingServiceCredential = new MangaRenderingServiceCredential()
    result.username = this.username
    result.password = this.password
    return result
  }

  static account(username: string, password: string): MangaRenderingServiceCredential {
    const result: MangaRenderingServiceCredential = new MangaRenderingServiceCredential()
    result.username = username.trim()
    result.password = password
    MangaRenderingServiceCredential.assertValid(result)
    return result
  }

  static parse(raw: string): MangaRenderingServiceCredential {
    if (raw.length === 0) {
      return new MangaRenderingServiceCredential()
    }
    let stored: StoredMangaRenderingCredential
    try {
      stored = JSON.parse(raw) as StoredMangaRenderingCredential
    } catch (_error) {
      throw new Error('Manga rendering service credential is invalid')
    }
    if (stored === null || typeof stored !== 'object' || stored.version !== CREDENTIAL_VERSION ||
      typeof stored.username !== 'string' || typeof stored.password !== 'string') {
      throw new Error('Manga rendering service credential is invalid')
    }
    return MangaRenderingServiceCredential.account(stored.username, stored.password)
  }

  static serialize(value: MangaRenderingServiceCredential): string {
    if (!value.configured()) {
      return ''
    }
    MangaRenderingServiceCredential.assertValid(value)
    const stored: StoredMangaRenderingCredential = new StoredMangaRenderingCredential()
    stored.username = value.username
    stored.password = value.password
    return JSON.stringify(stored)
  }

  private static assertValid(value: MangaRenderingServiceCredential): void {
    if (value.username.length < MIN_USERNAME_CHARS || value.username.length > MAX_USERNAME_CHARS ||
      value.username !== value.username.trim() || /[\r\n\t]/.test(value.username) ||
      value.password.length < MIN_PASSWORD_CHARS || value.password.length > MAX_PASSWORD_CHARS ||
      value.password.includes('\u0000')) {
      throw new Error('Manga rendering service credential is invalid')
    }
  }
}

export class MangaRenderingServiceSecretStore {
  static async read(context: common.UIAbilityContext): Promise<MangaRenderingServiceCredential> {
    return MangaRenderingServiceCredential.parse(
      await LlmSourceSecretVault.readApiKey(context, SECRET_OWNER_ID),
    )
  }

  static async save(
    context: common.UIAbilityContext,
    credential: MangaRenderingServiceCredential,
  ): Promise<void> {
    const value: string = MangaRenderingServiceCredential.serialize(credential)
    if (value.length === 0) {
      await LlmSourceSecretVault.removeApiKey(context, SECRET_OWNER_ID)
      return
    }
    await LlmSourceSecretVault.saveApiKey(context, SECRET_OWNER_ID, value)
  }
}
