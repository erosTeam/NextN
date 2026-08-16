import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { BackupChecksum } from './BackupChecksum'
import { BackupCrypto, BackupSealResult } from './BackupCrypto'
import { BackupLocalDataAdapter } from './BackupLocalDataAdapter'
import { BackupPreferencesAdapter } from './BackupPreferencesAdapter'
import { BackupSecretsAdapter } from './BackupSecretsAdapter'
import { SyncScheduler } from '../sync/SyncScheduler'
import {
  BackupAppMetadata,
  BackupCipherMeta,
  BackupData,
  BackupEncryptedEnvelope,
  BackupEnvelopeV1,
  BackupExportOptions,
  BackupLocalDataSection,
  BackupParseResult,
  BackupPreview,
  BackupRestoreResult,
  BackupSectionName,
  BackupSettingsValue,
} from './BackupTypes'
import {
  BACKUP_APP_ID,
  BACKUP_MAGIC,
  BACKUP_MIN_SUPPORTED_SCHEMA_VERSION,
  BACKUP_SCHEMA_VERSION,
  MAX_BACKUP_BYTES,
} from './BackupTypes'

type SettingsMap = Record<string, BackupSettingsValue>

/**
 * Orchestrates settings backup/restore (ported from the NextE backup chain).
 * Plaintext export = the non-secret Preferences keys + durable RDB datasets.
 * Encrypted export = plaintext + secret keys, sealed under a password
 * (AES-256-GCM). Import recognizes an encrypted file without the password and
 * asks for one; a wrong password fails GCM auth and surfaces as
 * 'bad_password'. WebDAV automatic-sync suspension is intentionally not wired
 * here yet: NextN's SyncScheduler/WebDAV chain lands in Phase 2, and the
 * restore transaction gains the same suspend/resume guard then.
 */
export class BackupService {
  static async serializeBackup(
    context: common.UIAbilityContext,
    metadata: BackupAppMetadata,
    options: BackupExportOptions,
  ): Promise<string> {
    const envelope: BackupEnvelopeV1 = await BackupService.buildEnvelope(context, metadata, options)
    if (options.includeSecrets) {
      const sealed: BackupSealResult = BackupCrypto.seal(JSON.stringify(envelope), options.password)
      const container: BackupEncryptedEnvelope = {
        magic: BACKUP_MAGIC,
        appId: BACKUP_APP_ID,
        schemaVersion: envelope.schemaVersion,
        minSupportedSchemaVersion: envelope.minSupportedSchemaVersion,
        encrypted: true,
        createdAt: envelope.createdAt,
        appVersion: envelope.appVersion,
        appVersionCode: envelope.appVersionCode,
        cipherMeta: sealed.cipherMeta,
        ciphertext: sealed.ciphertext,
      }
      return JSON.stringify(container, null, 2)
    }
    return JSON.stringify(envelope, null, 2)
  }

  private static async buildEnvelope(
    context: common.UIAbilityContext,
    metadata: BackupAppMetadata,
    options: BackupExportOptions,
  ): Promise<BackupEnvelopeV1> {
    const prefs: SettingsMap = await BackupPreferencesAdapter.exportPreferences(context)
    const localData: BackupLocalDataSection = await BackupLocalDataAdapter.exportSection(context)
    const sections: BackupSectionName[] = ['preferences', 'localData']
    const data: BackupData = { preferences: prefs, localData: localData }
    const envelope: BackupEnvelopeV1 = {
      magic: BACKUP_MAGIC,
      appId: BACKUP_APP_ID,
      schemaVersion: BACKUP_SCHEMA_VERSION,
      minSupportedSchemaVersion: BACKUP_MIN_SUPPORTED_SCHEMA_VERSION,
      createdAt: new Date().toISOString(),
      appVersion: metadata.appVersion,
      appVersionCode: metadata.appVersionCode,
      sections: sections,
      counts: {
        preferences: BackupPreferencesAdapter.count(prefs),
        localData: {
          readProgress: localData.readProgress.length,
          viewedHistory: localData.viewedHistory.length,
          searchHistory: localData.searchHistory.length,
          quickSearches: localData.quickSearches.length,
          localBlockRules: localData.localBlock.rules.length,
          settingsTableGroups: Object.keys(localData.settingsTables).length,
        },
      },
      data: data,
    }
    if (options.includeSecrets) {
      const secrets: SettingsMap = await BackupSecretsAdapter.exportSecrets(context)
      data.secrets = secrets
      envelope.sections = ['preferences', 'localData', 'secrets']
      envelope.counts.secrets = BackupPreferencesAdapter.count(secrets)
    }
    return await BackupChecksum.signEnvelope(envelope)
  }

  // Parse a raw file. A recognized encrypted container returns ok=false + encrypted=true +
  // 'password_required' so the caller prompts for a password.
  static async parseAndPreview(raw: string): Promise<BackupParseResult> {
    return BackupService.parseEnvelope(raw, false)
  }

  static async decryptAndPreview(raw: string, password: string): Promise<BackupParseResult> {
    if (BackupService.isTooLarge(raw)) {
      return { ok: false, code: 'too_large', message: 'backup file is too large' }
    }
    let container: BackupEncryptedEnvelope
    try {
      container = JSON.parse(raw) as BackupEncryptedEnvelope
    } catch (_error) {
      return { ok: false, code: 'not_json', message: 'not a valid JSON file' }
    }
    if (
      !container ||
      container.magic !== BACKUP_MAGIC ||
      container.appId !== BACKUP_APP_ID ||
      container.encrypted !== true
    ) {
      return { ok: false, code: 'foreign_backup', message: 'not a NextN backup' }
    }
    const meta: BackupCipherMeta | undefined = container.cipherMeta
    if (
      meta === undefined ||
      meta === null ||
      typeof meta !== 'object' ||
      Array.isArray(meta) ||
      typeof container.ciphertext !== 'string' ||
      container.ciphertext.length === 0 ||
      !BackupCrypto.isSupportedMeta(meta)
    ) {
      return { ok: false, code: 'malformed', message: 'backup is malformed' }
    }
    let plaintext: string
    try {
      plaintext = BackupCrypto.open(container.ciphertext, password, meta)
    } catch (_error) {
      return { ok: false, code: 'bad_password', message: 'wrong password or damaged backup' }
    }
    return BackupService.parseEnvelope(plaintext, true)
  }

  private static async parseEnvelope(
    raw: string,
    fromEncrypted: boolean,
  ): Promise<BackupParseResult> {
    if (BackupService.isTooLarge(raw)) {
      return { ok: false, code: 'too_large', message: 'backup file is too large' }
    }
    let parsed: Object
    try {
      parsed = JSON.parse(raw) as Object
    } catch (_error) {
      return { ok: false, code: 'not_json', message: 'not a valid JSON file' }
    }
    if (Array.isArray(parsed) || parsed === null || typeof parsed !== 'object') {
      return { ok: false, code: 'not_json', message: 'backup root must be an object' }
    }
    if (!fromEncrypted && BackupService.isEncryptedContainer(parsed)) {
      return {
        ok: false,
        encrypted: true,
        code: 'password_required',
        message: 'backup is encrypted',
      }
    }
    const envelope = parsed as BackupEnvelopeV1
    if (envelope.magic !== BACKUP_MAGIC || envelope.appId !== BACKUP_APP_ID) {
      return { ok: false, code: 'foreign_backup', message: 'not a NextN backup' }
    }
    if (
      envelope.schemaVersion > BACKUP_SCHEMA_VERSION ||
      envelope.minSupportedSchemaVersion > BACKUP_SCHEMA_VERSION
    ) {
      return { ok: false, code: 'unsupported_version', message: 'unsupported backup version' }
    }
    if (
      !Array.isArray(envelope.sections) ||
      !BackupService.hasCompleteLocalDataTopology(envelope)
    ) {
      return { ok: false, code: 'malformed', message: 'backup sections are malformed' }
    }
    // The 'secrets' section is valid ONLY inside a decrypted container; reject it in plaintext so
    // credentials can never ride in cleartext.
    if (!fromEncrypted && envelope.sections.indexOf('secrets') >= 0) {
      return { ok: false, code: 'malformed', message: 'unexpected encrypted section' }
    }
    const checksumOk: boolean = await BackupChecksum.verifyEnvelope(envelope)
    if (!checksumOk) {
      return { ok: false, code: 'bad_checksum', message: 'backup failed integrity check' }
    }
    return { ok: true, envelope: envelope, code: '', message: '' }
  }

  private static isTooLarge(raw: string): boolean {
    return new util.TextEncoder().encodeInto(raw).length > MAX_BACKUP_BYTES
  }

  private static isEncryptedContainer(value: Object): boolean {
    const container = value as BackupEncryptedEnvelope
    return (
      container.magic === BACKUP_MAGIC &&
      container.appId === BACKUP_APP_ID &&
      container.encrypted === true
    )
  }

  /**
   * `localData` replaces durable RDB datasets rather than merging them. Keep
   * old preference-only backups valid, but reject a declared partial snapshot
   * before preview or restore can turn absent arrays into destructive empty
   * replacements.
   */
  private static hasCompleteLocalDataTopology(envelope: BackupEnvelopeV1): boolean {
    const data: BackupData | undefined = envelope.data
    if (data === undefined || data === null || typeof data !== 'object' || Array.isArray(data)) {
      return false
    }
    const declaresLocalData: boolean = envelope.sections.indexOf('localData') >= 0
    const localData: BackupLocalDataSection | undefined = data.localData
    if (declaresLocalData !== (localData !== undefined)) {
      return false
    }
    return localData === undefined || BackupLocalDataAdapter.hasCompleteRestoreShape(localData)
  }

  static preview(envelope: BackupEnvelopeV1): BackupPreview {
    return {
      createdAt: envelope.createdAt,
      appVersion: envelope.appVersion,
      appVersionCode: envelope.appVersionCode,
      sections: envelope.sections,
      counts: envelope.counts,
      hasSecrets: envelope.sections.indexOf('secrets') >= 0,
    }
  }

  static async restoreBackup(
    context: common.UIAbilityContext,
    envelope: BackupEnvelopeV1,
  ): Promise<BackupRestoreResult> {
    if (
      !Array.isArray(envelope.sections) ||
      !BackupService.hasCompleteLocalDataTopology(envelope)
    ) {
      return {
        ok: false,
        restoredSections: [],
        failedSections: ['localData'],
        message: 'backup local data is malformed',
      }
    }
    const fromEncrypted: boolean = envelope.sections.indexOf('secrets') >= 0
    SyncScheduler.suspendAutomaticSync()
    try {
      const rollbackPreferences: SettingsMap = await BackupPreferencesAdapter.exportPreferences(context)
      const rollbackLocalData: BackupLocalDataSection = await BackupLocalDataAdapter.exportSection(context)
      const rollbackSecrets: SettingsMap = await BackupSecretsAdapter.exportSecrets(context)
      let failedSection: BackupSectionName = 'preferences'
      try {
        if (envelope.data.preferences !== undefined) {
          failedSection = 'preferences'
          await BackupPreferencesAdapter.restore(context, envelope.data.preferences, false)
        }
        if (envelope.data.localData !== undefined) {
          failedSection = 'localData'
          await BackupLocalDataAdapter.restoreSection(context, envelope.data.localData)
        } else {
          // Preference-only envelopes carry no RDB datasets in NextN.
          failedSection = 'localData'
          await BackupLocalDataAdapter.restoreLegacyPreferences(context)
        }
        if (fromEncrypted && envelope.data.secrets !== undefined) {
          failedSection = 'secrets'
          await BackupSecretsAdapter.restoreSecrets(context, envelope.data.secrets, false)
        }
        await BackupPreferencesAdapter.restoreWebDavCredentialGroup(
          context,
          envelope.data.preferences === undefined ? {} : envelope.data.preferences,
          envelope.data.secrets === undefined ? {} : envelope.data.secrets,
          fromEncrypted,
        )
        // Re-hydrate live state from the freshly written stores.
        await BackupPreferencesAdapter.reapply(context)
        await BackupSecretsAdapter.reapply(context)
      } catch (error) {
        let message: string = (error as Error).message
        try {
          await BackupPreferencesAdapter.replace(context, rollbackPreferences, false)
          await BackupLocalDataAdapter.restoreSection(context, rollbackLocalData)
          await BackupSecretsAdapter.restoreSecrets(context, rollbackSecrets, true)
          await BackupPreferencesAdapter.reapply(context)
          await BackupSecretsAdapter.reapply(context)
        } catch (rollbackError) {
          message = `${message}; rollback failed: ${(rollbackError as Error).message}`
        }
        return {
          ok: false,
          restoredSections: [],
          failedSections: [failedSection],
          message: message,
        }
      }
      return {
        ok: true,
        restoredSections: envelope.sections,
        failedSections: [],
        message: '',
      }
    } catch (_error) {
      return {
        ok: false,
        restoredSections: [],
        failedSections: ['preferences'],
        message: 'backup rollback snapshot failed',
      }
    } finally {
      SyncScheduler.resumeAutomaticSync()
    }
  }
}
