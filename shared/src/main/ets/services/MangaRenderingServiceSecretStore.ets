import { common } from '@kit.AbilityKit'
import { LlmSourceSecretVault } from './LlmSourceSecretVault'

const SECRET_OWNER_ID: string = 'manga-rendering-service'
const LEGACY_CREDENTIAL_VERSION: number = 1
const CREDENTIAL_VERSION: number = 2
const DEFAULT_CREDENTIAL_REVISION: number = 1
const MIN_USERNAME_CHARS: number = 2
const MAX_USERNAME_CHARS: number = 50
const MIN_PASSWORD_CHARS: number = 6
const MAX_PASSWORD_CHARS: number = 2048

class StoredMangaRenderingCredential {
  version: number = CREDENTIAL_VERSION
  username: string = ''
  password: string = ''
  revision: number = 0
}

/**
 * Keeps the optional sidecar account in the existing HUKS-backed secret vault.
 * It deliberately has no reactive state and does not retain a service token.
 */
export class MangaRenderingServiceCredential {
  username: string = ''
  password: string = ''
  /** Monotonic non-secret generation used only to isolate durable output caches. */
  revision: number = 0

  configured(): boolean {
    return this.username.length > 0 && this.password.length > 0
  }

  copy(): MangaRenderingServiceCredential {
    const result: MangaRenderingServiceCredential = new MangaRenderingServiceCredential()
    result.username = this.username
    result.password = this.password
    result.revision = this.revision
    return result
  }

  static account(
    username: string,
    password: string,
    revision: number = DEFAULT_CREDENTIAL_REVISION,
  ): MangaRenderingServiceCredential {
    const result: MangaRenderingServiceCredential = new MangaRenderingServiceCredential()
    result.username = username.trim()
    result.password = password
    result.revision = revision
    MangaRenderingServiceCredential.assertValid(result)
    return result
  }

  /** A cleared vault record keeps only the non-secret cache generation. */
  static empty(revision: number = 0): MangaRenderingServiceCredential {
    const result: MangaRenderingServiceCredential = new MangaRenderingServiceCredential()
    result.revision = revision
    MangaRenderingServiceCredential.assertValid(result)
    return result
  }

  static withRevision(
    credential: MangaRenderingServiceCredential,
    revision: number,
  ): MangaRenderingServiceCredential {
    return MangaRenderingServiceCredential.account(
      credential.username,
      credential.password,
      revision,
    )
  }

  static nextRevision(current: number): number {
    if (current === 0) {
      return DEFAULT_CREDENTIAL_REVISION
    }
    if (!Number.isFinite(current) || current <= 0 || Math.floor(current) !== current ||
      current >= Number.MAX_SAFE_INTEGER) {
      throw new Error('Manga rendering service credential revision is invalid')
    }
    return current + 1
  }

  static parse(raw: string): MangaRenderingServiceCredential {
    if (raw.length === 0) {
      return MangaRenderingServiceCredential.empty()
    }
    let stored: StoredMangaRenderingCredential
    try {
      stored = JSON.parse(raw) as StoredMangaRenderingCredential
    } catch (_error) {
      throw new Error('Manga rendering service credential is invalid')
    }
    if (stored === null || typeof stored !== 'object' ||
      (stored.version !== LEGACY_CREDENTIAL_VERSION && stored.version !== CREDENTIAL_VERSION) ||
      typeof stored.username !== 'string' || typeof stored.password !== 'string') {
      throw new Error('Manga rendering service credential is invalid')
    }
    if (stored.version === LEGACY_CREDENTIAL_VERSION) {
      return MangaRenderingServiceCredential.account(
        stored.username,
        stored.password,
        DEFAULT_CREDENTIAL_REVISION,
      )
    }
    if (stored.username.length === 0 && stored.password.length === 0) {
      return MangaRenderingServiceCredential.empty(stored.revision)
    }
    return MangaRenderingServiceCredential.account(stored.username, stored.password, stored.revision)
  }

  static serialize(value: MangaRenderingServiceCredential): string {
    MangaRenderingServiceCredential.assertValid(value)
    const stored: StoredMangaRenderingCredential = new StoredMangaRenderingCredential()
    stored.username = value.username
    stored.password = value.password
    stored.revision = value.revision
    return JSON.stringify(stored)
  }

  private static assertValid(value: MangaRenderingServiceCredential): void {
    if (!Number.isFinite(value.revision) || value.revision < 0 ||
      Math.floor(value.revision) !== value.revision || value.revision > Number.MAX_SAFE_INTEGER) {
      throw new Error('Manga rendering service credential is invalid')
    }
    if (!value.configured()) {
      if (value.username.length !== 0 || value.password.length !== 0) {
        throw new Error('Manga rendering service credential is invalid')
      }
      return
    }
    if (value.username.length < MIN_USERNAME_CHARS || value.username.length > MAX_USERNAME_CHARS ||
      value.username !== value.username.trim() || /[\r\n\t]/.test(value.username) ||
      value.password.length < MIN_PASSWORD_CHARS || value.password.length > MAX_PASSWORD_CHARS ||
      value.password.includes('\u0000') || value.revision <= 0) {
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
  ): Promise<MangaRenderingServiceCredential> {
    const previous: MangaRenderingServiceCredential = await MangaRenderingServiceSecretStore.read(context)
    let next: MangaRenderingServiceCredential = credential.copy()
    if (!next.configured()) {
      next = MangaRenderingServiceCredential.empty(Math.max(previous.revision, next.revision))
    } else if (next.revision <= previous.revision) {
      next = MangaRenderingServiceCredential.withRevision(
        next,
        MangaRenderingServiceCredential.nextRevision(previous.revision),
      )
    }
    await LlmSourceSecretVault.saveApiKey(
      context,
      SECRET_OWNER_ID,
      MangaRenderingServiceCredential.serialize(next),
    )
    return next
  }
}
