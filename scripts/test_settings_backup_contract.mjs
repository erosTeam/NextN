#!/usr/bin/env node
/**
 * Contract for the settings backup/restore (import/export) subsystem.
 *
 * Secrets (NH account session, LLM API key vault, WebDAV credential group) must NEVER appear in a
 * plaintext export; they travel only inside the AES-256-GCM encrypted container, gated by a password.
 * Run: node scripts/test_settings_backup_contract.mjs
 */
import fs from 'fs'

const read = (p) => fs.readFileSync(new URL(`../${p}`, import.meta.url), 'utf8')
let failures = 0
function ok(name, condition) {
  if (!condition) {
    console.error(`[FAIL] ${name}`)
    failures += 1
  }
}

const crypto = read('shared/src/main/ets/backup/BackupCrypto.ets')
ok('crypto is AES-256-GCM with PBKDF2-SHA256 (seal/open)',
  /static seal\(plaintext: string, password: string\)/.test(crypto) &&
    /static open\(/.test(crypto) &&
    /createCipher\('AES256\|GCM\|PKCS7'\)/.test(crypto) &&
    /createKdf\('PBKDF2\|SHA256'\)/.test(crypto))
ok('crypto splits the GCM auth tag off the ciphertext on open',
  /BACKUP_CIPHER_TAG_BYTES/.test(crypto) && /slice\(splitAt/.test(crypto))
ok('crypto fixes schema-v1 KDF work instead of accepting container-selected cost or key size',
  /static isSupportedMeta\(meta: BackupCipherMeta\)[\s\S]*meta\.iterations === BACKUP_KDF_ITERATIONS[\s\S]*meta\.keySize === BACKUP_KDF_KEY_SIZE/.test(crypto) &&
    /if \(!BackupCrypto\.isSupportedMeta\(meta\)\)/.test(crypto) &&
    /iterations: BACKUP_KDF_ITERATIONS[\s\S]*keySize: BACKUP_KDF_KEY_SIZE/.test(crypto) &&
    !/meta\.keySize > 0/.test(crypto) && !/meta\.iterations > 0/.test(crypto))

const types = read('shared/src/main/ets/backup/BackupTypes.ets')
ok('envelope identity + KDF params defined',
  /BACKUP_MAGIC: string = 'NEXTN_BACKUP'/.test(types) &&
    /BACKUP_APP_ID: string = 'com\.erosteam\.nextn'/.test(types) &&
    /BACKUP_KDF_ITERATIONS: number = 210000/.test(types))
ok("'secrets' is encryption-only, localData is plaintext durable data",
  /BACKUP_SECTION_NAMES: BackupSectionName\[\] = \['preferences', 'localData'\]/.test(types) &&
    /BACKUP_ENCRYPTED_ONLY_SECTION_NAMES: BackupSectionName\[\] = \['secrets'\]/.test(types))
ok('localData section carries the six durable NH datasets outside Preferences',
  /BackupSectionName = 'preferences' \| 'localData' \| 'secrets'/.test(types) &&
    /interface BackupLocalDataSection/.test(types) &&
    /readProgress: BackupReadProgressEntry\[\]/.test(types) &&
    /viewedHistory: BackupViewedHistoryEntry\[\]/.test(types) &&
    /searchHistory: string\[\]/.test(types) &&
    /quickSearches: BackupQuickSearchEntry\[\]/.test(types) &&
    /localBlock: BackupLocalBlockSection/.test(types) &&
    /settingsTables: Record<string, Record<string, string>>/.test(types))
ok('settings-table backup counts every durable table group',
  /settingsTableGroups: number/.test(types) &&
    /quickSearches: number/.test(types))

const deny = read('shared/src/main/ets/backup/BackupSecretDenylist.ets')
ok('denylist marks credential-bearing substrings as secret',
  /static isSecret\(key: string\): boolean/.test(deny) &&
    /'cookie'/.test(deny) &&
    /'apikey'/.test(deny) &&
    /'token'/.test(deny) &&
    /'password'/.test(deny))
ok('WebDAV configuration is an encrypted-only atomic credential group',
  /WEBDAV_CREDENTIAL_KEYS/.test(deny) &&
    /'nextn_settings\.sync\.webdav\.url'/.test(deny) &&
    /'nextn_settings\.sync\.webdav\.username'/.test(deny) &&
    /'nextn_settings\.sync\.webdav\.enabled'/.test(deny) &&
    /'nextn_settings\.sync\.webdav\.password'/.test(deny) &&
    /static isWebDavCredentialKey\(key: string\): boolean/.test(deny))
ok('denylist keeps the HUKS LLM vault and account-session family encrypted-only',
  /LLM_SECRET_STORE_PREFIX: string = 'nextn_llm_secrets\.'/.test(deny) &&
    /key\.startsWith\(BackupSecretDenylist\.LLM_SECRET_STORE_PREFIX\)/.test(deny) &&
    /ACCOUNT_SESSION_PREFIX: string = 'account\.session\.'/.test(deny) &&
    /key\.startsWith\(BackupSecretDenylist\.ACCOUNT_SESSION_PREFIX\)/.test(deny))

const adapter = read('shared/src/main/ets/backup/BackupPreferencesAdapter.ets')
ok('adapter splits stores by secret + re-checks denylist on restore + reapplies live state',
  /exportPreferences\(/.test(adapter) &&
    /exportSecrets\(/.test(adapter) &&
    /acceptsKey\(key: string, allowSecret: boolean\)/.test(adapter) &&
    /const secretKey: boolean = BackupSecretDenylist\.isSecret\(key\)/.test(adapter) &&
    /!allowSecret && secretKey/.test(adapter) &&
    /allowSecret && !secretKey/.test(adapter) &&
    /static async reapply\(/.test(adapter) &&
    /SyncSettings\.restore\(context\)/.test(adapter) &&
    /TagTranslationSettings\.restore\(context\)/.test(adapter))
ok('volatile runtime state never travels in either backup section',
  /VOLATILE_EXCLUDED_KEYS/.test(adapter) &&
    /'nextn_settings\.sync\.last_run_at'/.test(adapter) &&
    /'nextn_settings\.sync\.last_status'/.test(adapter) &&
    /'nextn_settings\.sync\.last_detail'/.test(adapter) &&
    /'nextn_layout\.clipboard_link_enabled'/.test(adapter) &&
    /'nextn_layout\.clipboard_link_change_count'/.test(adapter) &&
    /BackupPreferencesAdapter\.isVolatileExcluded\(key\)[\s\S]*continue/.test(adapter) &&
    /if \(BackupPreferencesAdapter\.isVolatileExcluded\(key\)\)[\s\S]*return false/.test(adapter))
ok('Preferences rollback replaces the backup scope and deletes import-added keys',
  /static async replace\(/.test(adapter) &&
    /store\.getAllSync\(\)/.test(adapter) &&
    /store\.deleteSync\(rawKey\)/.test(adapter) &&
    /map\[key\] === undefined/.test(adapter) &&
    /BackupPreferencesAdapter\.acceptsKey\(key, allowSecret\)/.test(adapter))
ok('generic restore never writes the WebDAV credential group directly',
  /BackupSecretDenylist\.isWebDavCredentialKey\(key\)[\s\S]*continue/.test(adapter))
ok('backup restores WebDAV only as one complete encrypted credential group',
  /static async restoreWebDavCredentialGroup\(/.test(adapter) &&
    /static resolveWebDavCredentialGroup\([\s\S]*webDavCredentialValue\(plaintext, secrets/.test(adapter) &&
    /static resolveWebDavCredentialValues\([\s\S]*if \(!fromEncrypted\)[\s\S]*return null/.test(adapter) &&
    /typeof url !== 'string'[\s\S]*typeof username !== 'string'[\s\S]*typeof enabled !== 'boolean'[\s\S]*typeof password !== 'string'/.test(adapter) &&
    /store\.putSync\('sync\.webdav\.url', group\.url\)[\s\S]*store\.putSync\('sync\.webdav\.password', group\.password\)/.test(adapter))

const secretsAdapter = read('shared/src/main/ets/backup/BackupSecretsAdapter.ets')
ok('HUKS secrets ride only in the encrypted container and re-wrap on restore',
  /exportPlaintextForBackup\(context\)/.test(secretsAdapter) &&
    /exportSealedForBackup\(context\)/.test(secretsAdapter) &&
    /restorePlaintextFromBackup\(context, llmValues\)/.test(secretsAdapter) &&
    /restoreSealedFromBackup\(context, sessionValue as string\)/.test(secretsAdapter) &&
    /clearSealedForBackup\(context\)/.test(secretsAdapter))

const svc = read('shared/src/main/ets/backup/BackupService.ets')
ok('service seals into the encrypted container only when includeSecrets',
  /if \(options\.includeSecrets\)[\s\S]*BackupCrypto\.seal\(JSON\.stringify\(envelope\), options\.password\)/.test(svc))
ok('service exports the NH secrets section through the HUKS adapter',
  /BackupSecretsAdapter\.exportSecrets\(context\)/.test(svc) &&
    /envelope\.sections = \['preferences', 'localData', 'secrets'\]/.test(svc))
ok('service exports and restores the localData section with NH counts',
  /BackupLocalDataAdapter\.exportSection\(context\)/.test(svc) &&
    /sections: BackupSectionName\[\] = \['preferences', 'localData'\]/.test(svc) &&
    /BackupLocalDataAdapter\.restoreSection\(context, envelope\.data\.localData\)/.test(svc) &&
    /quickSearches: localData\.quickSearches\.length/.test(svc) &&
    /settingsTableGroups: Object\.keys\(localData\.settingsTables\)\.length/.test(svc))
ok('backup parser and restore boundary reject partial localData replacements',
  /BackupService\.hasCompleteLocalDataTopology\(envelope\)/.test(svc) &&
    /BackupLocalDataAdapter\.hasCompleteRestoreShape\(localData\)/.test(svc) &&
    /static hasCompleteRestoreShape\(/.test(read('shared/src/main/ets/backup/BackupLocalDataAdapter.ets')) &&
    /throw new Error\('backup local data is malformed'\)/.test(read('shared/src/main/ets/backup/BackupLocalDataAdapter.ets')))
ok('a plaintext file declaring a secrets section is rejected',
  /!fromEncrypted && envelope\.sections\.indexOf\('secrets'\) >= 0/.test(svc) &&
    /code: 'malformed'/.test(svc))
ok('an encrypted file without a password surfaces password_required; wrong password -> bad_password',
  /encrypted: true,\s*code: 'password_required'/.test(svc) &&
    /code: 'bad_password'/.test(svc))
ok('encrypted import validates byte size and fixed cipher metadata before decrypting',
  /static async decryptAndPreview\(raw: string, password: string\)[\s\S]*BackupService\.isTooLarge\(raw\)[\s\S]*JSON\.parse\(raw\)/.test(svc) &&
    /typeof container\.ciphertext !== 'string'[\s\S]*!BackupCrypto\.isSupportedMeta\(meta\)[\s\S]*BackupCrypto\.open\(container\.ciphertext, password, meta\)/.test(svc) &&
    /private static isTooLarge\(raw: string\): boolean/.test(svc))
ok('checksum is verified on parse',
  /BackupChecksum\.verifyEnvelope\(envelope\)/.test(svc) && /code: 'bad_checksum'/.test(svc))
ok('restore snapshots durable stores and rolls back on section failure',
  /const rollbackPreferences: SettingsMap = await BackupPreferencesAdapter\.exportPreferences\(context\)/.test(svc) &&
    /const rollbackLocalData: BackupLocalDataSection = await BackupLocalDataAdapter\.exportSection\(context\)/.test(svc) &&
    /const rollbackSecrets: SettingsMap = await BackupSecretsAdapter\.exportSecrets\(context\)/.test(svc) &&
    /await BackupPreferencesAdapter\.replace\(context, rollbackPreferences, false\)/.test(svc) &&
    /await BackupLocalDataAdapter\.restoreSection\(context, rollbackLocalData\)/.test(svc) &&
    /await BackupSecretsAdapter\.restoreSecrets\(context, rollbackSecrets, true\)/.test(svc) &&
    /failedSections: \[failedSection\]/.test(svc))
ok('restore suppresses scheduled provider sync across the whole transaction window',
  /import \{ SyncScheduler \} from '\.\.\/sync\/SyncScheduler'/.test(svc) &&
    /SyncScheduler\.suspendAutomaticSync\(\)[\s\S]*const rollbackPreferences/.test(svc) &&
    /SyncScheduler\.resumeAutomaticSync\(\)/.test(svc) &&
    !/HuaweiCloudSyncService/.test(svc))

const syncScheduler = read('shared/src/main/ets/sync/SyncScheduler.ets')
const webDavScheduler = read('shared/src/main/ets/sync/WebDavSyncScheduler.ets')
ok('scheduled WebDAV provider work is paused and cancelled across the restore window',
  /suspendAutomaticSync\(\)[\s\S]*WebDavSyncScheduler\.suspendAutomaticSync\(\)/.test(syncScheduler) &&
    /automaticSyncSuppressionDepth/.test(webDavScheduler) &&
    /clearTimeout\(WebDavSyncScheduler\.timerId\)/.test(webDavScheduler) &&
    /automaticSyncSuppressed\(\)[\s\S]*webdav_schedule_suppressed/.test(webDavScheduler))

const localDataAdapter = read('shared/src/main/ets/backup/BackupLocalDataAdapter.ets')
ok('local-data restore requires all four durable settings tables and replaces each dataset',
  /'reader_settings'[\s\S]*'download_settings'[\s\S]*'browse_presentation_settings'[\s\S]*'catalog_preferences'/.test(localDataAdapter) &&
    /SearchHistoryRepository\.restoreBackup\(context, section\.searchHistory\)/.test(localDataAdapter) &&
    /QuickSearchRepository\.restoreBackup\(context, quick\)/.test(localDataAdapter) &&
    /ContentFilterRepository\.restoreBackup\(context, rules\)/.test(localDataAdapter) &&
    /ReaderSettingsRepository\.restoreBackup\(context, section\.settingsTables\['reader_settings'\]\)/.test(localDataAdapter) &&
    /DownloadSettingsRepository\.restoreBackup\(context, section\.settingsTables\['download_settings'\]\)/.test(localDataAdapter) &&
    /BrowsePresentationRepository\.restoreBackup\([\s\S]*section\.settingsTables\['browse_presentation_settings'\]/.test(localDataAdapter) &&
    /CatalogPreferencesRepository\.restoreBackup\(context, section\.settingsTables\['catalog_preferences'\]\)/.test(localDataAdapter))

ok('shared exports BackupService + BackupSecretsAdapter + credential group types',
  /export \{ BackupService \}/.test(read('shared/src/main/ets/Index.ets')) &&
    /export \{ BackupSecretsAdapter \}/.test(read('shared/src/main/ets/Index.ets')) &&
    /BackupWebDavCredentialGroup/.test(read('shared/src/main/ets/Index.ets')))

const picker = read('feature/settings/src/main/ets/model/BackupFilePickerCoordinator.ets')
ok('picker rejects oversized files before allocating',
  /const size: number = fileIo\.statSync\(file\.fd\)\.size[\s\S]*size > MAX_BACKUP_BYTES[\s\S]*throw new Error\('backup file is too large'\)[\s\S]*new ArrayBuffer\(size\)/.test(picker))

const webDavCredentialGroupTest = read('entry/src/ohosTest/ets/test/BackupWebDavCredentialGroup.test.ets')
const backupCipherGuardTest = read('entry/src/ohosTest/ets/test/BackupCipherMetadataGuard.test.ets')
const backupLocalDataStructureGuardTest = read('entry/src/ohosTest/ets/test/BackupLocalDataStructureGuard.test.ets')
const testList = read('entry/src/ohosTest/ets/test/List.test.ets')
ok('device test covers legacy/current encrypted groups and rejects plaintext/incomplete input',
  /resolveWebDavCredentialValues\([\s\S]*'legacy-password',[\s\S]*true/.test(webDavCredentialGroupTest) &&
    /resolveWebDavCredentialValues\([\s\S]*'current-password',[\s\S]*true/.test(webDavCredentialGroupTest) &&
    /resolveWebDavCredentialValues\([\s\S]*'legacy-password',[\s\S]*false/.test(webDavCredentialGroupTest) &&
    /backupWebDavCredentialGroupTest\(\)/.test(testList))
ok('device test exercises rejection of untrusted encrypted KDF metadata before decrypt',
  /BackupService\.decryptAndPreview\([\s\S]*encryptedContainer\(210001, 32\)[\s\S]*result\.code\)\.assertEqual\('malformed'\)/.test(backupCipherGuardTest) &&
    /backupCipherMetadataGuardTest\(\)/.test(testList))
ok('device test covers localData structure compatibility and malformed replacement rejection',
  /validLocalData\(\)/.test(backupLocalDataStructureGuardTest) &&
    /parseMalformed\(envelopeWithLocalData\(missingReadProgress, true\)\)/.test(backupLocalDataStructureGuardTest) &&
    /missingSettingsTable/.test(backupLocalDataStructureGuardTest) &&
    /backupLocalDataStructureGuardTest\(\)/.test(testList))

if (failures === 0) {
  console.log('OK settings backup contract passed')
  process.exit(0)
}
console.error(`[FAIL] settings backup contract: ${failures} failure(s)`)
process.exit(1)
