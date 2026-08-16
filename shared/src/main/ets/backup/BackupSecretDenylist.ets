/**
 * Splits NextN's Preferences stores into plaintext-safe keys and secret keys.
 *
 * The plaintext backup dumps each store wholesale so newly added settings are captured automatically
 * (no per-field allowlist). This denylist is the single guard that keeps credential-bearing keys out
 * of the plaintext envelope; those same keys form the encrypted 'secrets' section instead. Matching is
 * by case-insensitive substring plus explicit NextN key families. Backup keys carry the
 * `<store>.<key>` prefix, so both the prefixed and raw forms are recognized.
 */
export class BackupSecretDenylist {
  // Case-insensitive markers; belt-and-suspenders for any future credential key.
  private static readonly SENSITIVE_SUBSTRINGS: string[] = [
    'cookie',
    'apikey',
    'token',
    'password',
    'secret',
    'credential',
  ]

  // WebDAV's endpoint, username, enable flag, and password are one credential group (landed with
  // the sync phase; listed now so plaintext backups never start carrying them).
  private static readonly WEBDAV_CREDENTIAL_KEYS: string[] = [
    'nextn_settings.sync.webdav.url',
    'nextn_settings.sync.webdav.username',
    'nextn_settings.sync.webdav.enabled',
    'nextn_settings.sync.webdav.password',
  ]

  // NextN keeps HUKS-sealed LLM API keys in the nextn_llm_secrets store. The whole store is
  // encrypted-only; cross-device restore re-wraps values in Phase 1.5.
  private static readonly LLM_SECRET_STORE_PREFIX: string = 'nextn_llm_secrets.'

  // Future account-session family (RDB-backed today; reserved for preference-backed migrations).
  private static readonly ACCOUNT_SESSION_PREFIX: string = 'account.session.'

  static isWebDavCredentialKey(key: string): boolean {
    if (BackupSecretDenylist.WEBDAV_CREDENTIAL_KEYS.indexOf(key) >= 0) {
      return true
    }
    // Raw store keys and any future store placement stay inside the same family.
    return key.indexOf('sync.webdav.') >= 0
  }

  /** True when the key is a secret — excluded from plaintext, included only in the encrypted section. */
  static isSecret(key: string): boolean {
    if (BackupSecretDenylist.isWebDavCredentialKey(key)) {
      return true
    }
    if (key.startsWith(BackupSecretDenylist.LLM_SECRET_STORE_PREFIX)) {
      return true
    }
    if (key.startsWith(BackupSecretDenylist.ACCOUNT_SESSION_PREFIX)) {
      return true
    }
    const lower: string = key.toLowerCase()
    for (let i: number = 0; i < BackupSecretDenylist.SENSITIVE_SUBSTRINGS.length; i++) {
      if (lower.includes(BackupSecretDenylist.SENSITIVE_SUBSTRINGS[i])) {
        return true
      }
    }
    return false
  }
}
