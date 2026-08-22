import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BackupSecretDenylist } from './BackupSecretDenylist'
import { BackupSettingsValue } from './BackupTypes'
import { ActionAlignmentSettings } from '../settings/ActionAlignmentSettings'
import { AccountListSettings } from '../settings/AccountListSettings'
import { AppColorFavoritesSettings } from '../settings/AppColorFavoritesSettings'
import { CommentTranslationSettings } from '../settings/CommentTranslationSettings'
import { ComicVisualProviderSettings } from '../settings/ComicVisualProviderSettings'
import { CoverBackgroundSettings } from '../settings/CoverBackgroundSettings'
import { GalleryTitleSettings } from '../settings/GalleryTitleSettings'
import { HomeTabSettings } from '../settings/HomeTabSettings'
import { ImmersiveMaterialSettings } from '../settings/ImmersiveMaterialSettings'
import { LanguageSettings } from '../settings/LanguageSettings'
import { MangaRenderingServiceSettings } from '../settings/MangaRenderingServiceSettings'
import { NhClipboardLinkSettings } from '../settings/NhClipboardLinkSettings'
import { ReadButtonStyleSettings } from '../settings/ReadButtonStyleSettings'
import { ScreenOrientationSettings } from '../settings/ScreenOrientationSettings'
import { SearchTranslationSettings } from '../settings/SearchTranslationSettings'
import { TabletLayoutSettings } from '../settings/TabletLayoutSettings'
import { TagTranslationSettings } from '../settings/TagTranslationSettings'
import { ReaderImageCacheSettings } from '../settings/ReaderImageCacheSettings'
import { ThemeColorSettings } from '../settings/ThemeColorSettings'
import { SyncSettings } from '../settings/SyncSettings'
import { ThemeSettings } from '../settings/ThemeSettings'
import { BrowsePresentationService } from '../services/BrowsePresentationService'
import { CatalogPreferencesService } from '../services/CatalogPreferencesService'
import { ContentFilterService } from '../services/ContentFilterService'
import { DownloadSettingsService } from '../services/DownloadSettingsService'
import { HomeSourcePresentationService } from '../services/HomeSourcePresentationService'
import { ReaderPresentationService } from '../services/ReaderPresentationService'
import { LlmSourceProfileRepository } from '../storage/LlmSourceProfileRepository'

type SettingsMap = Record<string, BackupSettingsValue>

/** Complete WebDAV configuration restored only from an encrypted backup. */
export class BackupWebDavCredentialGroup {
  url: string = ''
  username: string = ''
  enabled: boolean = false
  password: string = ''
}

/**
 * Reads/writes NextN's six Preferences stores for backup. The envelope key is
 * `<store>.<key>` so the stores cannot collide. Stores are split by the secret
 * denylist: non-secret keys form the plaintext 'preferences' section;
 * credential keys (LLM secret vault and the reserved WebDAV credential group)
 * form the encrypted-only 'secrets' section.
 * Runtime-only status keys never travel in either section. Restore is additive
 * (overwrites present keys, keeps absent ones) and re-applies the written
 * stores into live state via reapply(), matching NextE's SettingsBootstrap
 * re-hydration contract.
 */
export class BackupPreferencesAdapter {
  private static readonly PLAINTEXT_STORES: string[] = [
    'nextn_layout',
    'nextn_appearance',
    'nextn_settings',
    'nextn_llm_sources',
    'nextn_manga_rendering_service',
    'nextn_comic_visual_provider',
  ]

  // Stores that may contain credential-bearing values alongside normal
  // settings. HUKS-backed vaults are exported through BackupSecretsAdapter
  // after decrypting with the source device key, so their raw envelopes are
  // deliberately absent here.
  private static readonly SECRET_STORES: string[] = [
    'nextn_settings',
    'nextn_comic_visual_provider',
  ]

  private static readonly STORE_SEPARATOR: string = '.'

  // Clipboard consent and its deduplication cursor are device-local. Restoring
  // either on another device could bypass that device's explicit opt-in flow
  // or suppress a fresh clipboard value.
  private static readonly VOLATILE_EXCLUDED_KEYS: string[] = [
    // Sync run status is runtime-only and refreshed from the provider.
    'nextn_settings.sync.last_run_at',
    'nextn_settings.sync.last_status',
    'nextn_settings.sync.last_detail',
    'nextn_settings.app.releaseHistoryCache',
    'nextn_settings.cloud_blacklist_ids_v1',
    'nextn_settings.account.session.present',
    'nextn_settings.account.session.authRefreshRetryAt',
    // A restricted-build escape marker is device-local and must never unlock
    // another installation through backup restore.
    'nextn_settings.safeMode.unlocked',
    'nextn_layout.clipboard_link_enabled',
    'nextn_layout.clipboard_link_change_count',
    'nextn_comic_visual_provider.torii_credits_cache',
    'nextn_comic_visual_provider.torii_legacy_billing_mode',
    'nextn_comic_visual_provider.torii_legacy_byok_provider',
    'nextn_comic_visual_provider.torii_legacy_byok_source_profile',
    'nextn_comic_visual_provider.torii_legacy_byok_model',
  ]

  // Non-secret keys → plaintext section.
  static async exportPreferences(context: common.UIAbilityContext): Promise<SettingsMap> {
    return BackupPreferencesAdapter.dump(context, false)
  }

  // Secret keys → encrypted-only section.
  static async exportSecrets(context: common.UIAbilityContext): Promise<SettingsMap> {
    return BackupPreferencesAdapter.dump(context, true)
  }

  private static async dump(
    context: common.UIAbilityContext,
    secret: boolean,
  ): Promise<SettingsMap> {
    const out: SettingsMap = {}
    const stores: string[] = secret ? BackupPreferencesAdapter.SECRET_STORES : BackupPreferencesAdapter.PLAINTEXT_STORES
    for (let i: number = 0; i < stores.length; i++) {
      const storeName: string = stores[i]
      const store: preferences.Preferences = await preferences.getPreferences(context, storeName)
      const all = store.getAllSync() as Record<string, preferences.ValueType>
      const keys: string[] = Object.keys(all)
      for (let j: number = 0; j < keys.length; j++) {
        const rawKey: string = keys[j]
        const key: string = `${storeName}${BackupPreferencesAdapter.STORE_SEPARATOR}${rawKey}`
        if (BackupPreferencesAdapter.isVolatileExcluded(key)) {
          continue
        }
        if (BackupSecretDenylist.isSecret(key) !== secret) {
          continue
        }
        if (!secret && BackupPreferencesAdapter.isPlaintextExcluded(key)) {
          continue
        }
        const value = all[rawKey]
        // The stores only hold string/number/boolean (composite settings are JSON strings).
        if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
          out[key] = value
        }
      }
    }
    return out
  }

  private static isVolatileExcluded(key: string): boolean {
    return BackupPreferencesAdapter.VOLATILE_EXCLUDED_KEYS.indexOf(key) >= 0
  }

  private static isPlaintextExcluded(key: string): boolean {
    // NextN's durable local datasets live in RDB, so no Preferences key needs to
    // be moved into localData. Reserved for future preference-carried datasets.
    return false
  }

  private static acceptsKey(key: string, allowSecret: boolean): boolean {
    if (BackupPreferencesAdapter.isVolatileExcluded(key)) {
      return false
    }
    const secretKey: boolean = BackupSecretDenylist.isSecret(key)
    if (!allowSecret && secretKey) {
      return false
    }
    if (!allowSecret && BackupPreferencesAdapter.isPlaintextExcluded(key)) {
      return false
    }
    if (allowSecret && !secretKey) {
      return false
    }
    const parts: string[] | null = BackupPreferencesAdapter.splitStoreKey(key)
    return parts !== null && BackupPreferencesAdapter.allowedStore(parts[0], allowSecret)
  }

  private static splitStoreKey(key: string): string[] | null {
    const index: number = key.indexOf(BackupPreferencesAdapter.STORE_SEPARATOR)
    if (index <= 0 || index === key.length - 1) {
      return null
    }
    return [key.substring(0, index), key.substring(index + 1)]
  }

  private static allowedStore(storeName: string, allowSecret: boolean): boolean {
    const stores: string[] = allowSecret
      ? BackupPreferencesAdapter.SECRET_STORES
      : BackupPreferencesAdapter.PLAINTEXT_STORES
    return stores.indexOf(storeName) >= 0
  }

  // Write a backed-up map back into its stores. `allowSecret=false` re-checks
  // the denylist so a tampered plaintext backup can never smuggle a credential
  // key in; `allowSecret=true` is used only for the section decrypted from the
  // cipher container.
  static async restore(
    context: common.UIAbilityContext,
    map: SettingsMap,
    allowSecret: boolean,
  ): Promise<void> {
    const grouped: Record<string, SettingsMap> = {}
    const keys: string[] = Object.keys(map)
    for (let i: number = 0; i < keys.length; i++) {
      const key: string = keys[i]
      if (!BackupPreferencesAdapter.acceptsKey(key, allowSecret)) {
        continue
      }
      // Restore this provider configuration only through restoreWebDavCredentialGroup().
      if (BackupSecretDenylist.isWebDavCredentialKey(key)) {
        continue
      }
      const parts: string[] | null = BackupPreferencesAdapter.splitStoreKey(key)
      if (parts === null) {
        continue
      }
      let target: SettingsMap = grouped[parts[0]]
      if (target === undefined) {
        target = {}
        grouped[parts[0]] = target
      }
      target[parts[1]] = map[key]
    }
    const storeNames: string[] = Object.keys(grouped)
    for (let i: number = 0; i < storeNames.length; i++) {
      const storeName: string = storeNames[i]
      const store: preferences.Preferences = await preferences.getPreferences(context, storeName)
      const values: SettingsMap = grouped[storeName]
      const valueKeys: string[] = Object.keys(values)
      for (let j: number = 0; j < valueKeys.length; j++) {
        store.putSync(valueKeys[j], values[valueKeys[j]])
      }
      store.flushSync()
    }
  }

  /**
   * Restore WebDAV as one complete encrypted credential group. New encrypted
   * backups place all four fields in `secrets`; a plaintext backup, or an
   * incomplete encrypted group, intentionally leaves the target's existing
   * provider configuration untouched (Phase 2 lands the real provider; the
   * group contract ships with the backup chain).
   */
  static async restoreWebDavCredentialGroup(
    context: common.UIAbilityContext,
    plaintext: SettingsMap,
    secrets: SettingsMap,
    fromEncrypted: boolean,
  ): Promise<void> {
    const group: BackupWebDavCredentialGroup | null =
      BackupPreferencesAdapter.resolveWebDavCredentialGroup(plaintext, secrets, fromEncrypted)
    if (group === null) {
      return
    }
    const store: preferences.Preferences =
      await preferences.getPreferences(context, 'nextn_settings')
    store.putSync('sync.webdav.url', group.url)
    store.putSync('sync.webdav.username', group.username)
    store.putSync('sync.webdav.enabled', group.enabled)
    store.putSync('sync.webdav.password', group.password)
    store.flushSync()
  }

  /** Pure resolver retained for device tests: plaintext and incomplete encrypted groups must be inert. */
  static resolveWebDavCredentialGroup(
    plaintext: SettingsMap,
    secrets: SettingsMap,
    fromEncrypted: boolean,
  ): BackupWebDavCredentialGroup | null {
    const url: BackupSettingsValue | undefined =
      BackupPreferencesAdapter.webDavCredentialValue(plaintext, secrets, 'nextn_settings.sync.webdav.url')
    const username: BackupSettingsValue | undefined =
      BackupPreferencesAdapter.webDavCredentialValue(plaintext, secrets, 'nextn_settings.sync.webdav.username')
    const enabled: BackupSettingsValue | undefined =
      BackupPreferencesAdapter.webDavCredentialValue(plaintext, secrets, 'nextn_settings.sync.webdav.enabled')
    const password: BackupSettingsValue | undefined =
      BackupPreferencesAdapter.webDavCredentialValue(plaintext, secrets, 'nextn_settings.sync.webdav.password')
    return BackupPreferencesAdapter.resolveWebDavCredentialValues(
      url,
      username,
      enabled,
      password,
      fromEncrypted,
    )
  }

  /** Pure scalar boundary for device tests; map routing stays in resolveWebDavCredentialGroup(). */
  static resolveWebDavCredentialValues(
    url: BackupSettingsValue | undefined,
    username: BackupSettingsValue | undefined,
    enabled: BackupSettingsValue | undefined,
    password: BackupSettingsValue | undefined,
    fromEncrypted: boolean,
  ): BackupWebDavCredentialGroup | null {
    if (!fromEncrypted) {
      return null
    }
    if (
      typeof url !== 'string' ||
      typeof username !== 'string' ||
      typeof enabled !== 'boolean' ||
      typeof password !== 'string'
    ) {
      return null
    }
    const group: BackupWebDavCredentialGroup = new BackupWebDavCredentialGroup()
    group.url = url
    group.username = username
    group.enabled = enabled
    group.password = password
    return group
  }

  private static webDavCredentialValue(
    plaintext: SettingsMap,
    secrets: SettingsMap,
    key: string,
  ): BackupSettingsValue | undefined {
    return secrets[key] !== undefined ? secrets[key] : plaintext[key]
  }

  static async replace(
    context: common.UIAbilityContext,
    map: SettingsMap,
    allowSecret: boolean,
  ): Promise<void> {
    const storeNames: string[] = allowSecret
      ? BackupPreferencesAdapter.SECRET_STORES
      : BackupPreferencesAdapter.PLAINTEXT_STORES
    for (let i: number = 0; i < storeNames.length; i++) {
      const storeName: string = storeNames[i]
      const store: preferences.Preferences = await preferences.getPreferences(context, storeName)
      const all = store.getAllSync() as Record<string, preferences.ValueType>
      const existingKeys: string[] = Object.keys(all)
      for (let j: number = 0; j < existingKeys.length; j++) {
        const rawKey: string = existingKeys[j]
        const key: string = `${storeName}${BackupPreferencesAdapter.STORE_SEPARATOR}${rawKey}`
        if (BackupPreferencesAdapter.acceptsKey(key, allowSecret) && map[key] === undefined) {
          store.deleteSync(rawKey)
        }
      }
      const keys: string[] = Object.keys(map)
      for (let j: number = 0; j < keys.length; j++) {
        const key: string = keys[j]
        if (BackupPreferencesAdapter.acceptsKey(key, allowSecret)) {
          const parts: string[] | null = BackupPreferencesAdapter.splitStoreKey(key)
          if (parts !== null && parts[0] === storeName) {
            store.putSync(parts[1], map[key])
          }
        }
      }
      store.flushSync()
    }
  }

  // Re-run the same restore set as EntryAbility so the freshly written stores
  // re-hydrate AppStorageV2/state holders immediately instead of only on next
  // launch. Guarded services get an explicit backup reapply entry that clears
  // their one-shot startup flag first.
  static async reapply(context: common.UIAbilityContext): Promise<void> {
    await ThemeSettings.restore(context)
    await ThemeColorSettings.restore(context)
    await AppColorFavoritesSettings.restore(context)
    await LanguageSettings.restore(context)
    await ImmersiveMaterialSettings.restore(context)
    await TabletLayoutSettings.restore(context)
    await ScreenOrientationSettings.restore(context)
    await HomeTabSettings.restore(context)
    await CoverBackgroundSettings.restore(context)
    await GalleryTitleSettings.restore(context)
    await ReadButtonStyleSettings.restore(context)
    await ActionAlignmentSettings.restore(context)
    await NhClipboardLinkSettings.restore(context)
    await ContentFilterService.restore(context)
    await BrowsePresentationService.restore(context)
    await HomeSourcePresentationService.restore(context)
    await ReaderPresentationService.restoreFromBackup(context)
    await CatalogPreferencesService.restoreFromBackup(context)
    await DownloadSettingsService.restoreFromBackup(context)
    await LlmSourceProfileRepository.restoreFromBackup(context)
    await MangaRenderingServiceSettings.restore(context)
    await ComicVisualProviderSettings.reapplyAfterBackup(context)
    await CommentTranslationSettings.restore(context)
    await TagTranslationSettings.restore(context)
    await SearchTranslationSettings.restore(context)
    await ReaderImageCacheSettings.restore(context)
    await SyncSettings.restore(context)
    await AccountListSettings.load(context)
  }

  static count(map: SettingsMap): number {
    return Object.keys(map).length
  }
}
