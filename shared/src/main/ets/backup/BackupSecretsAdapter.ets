import { common } from '@kit.AbilityKit'
import { LlmSourceSecretVault } from '../services/LlmSourceSecretVault'
import { NhAccountProfileService } from '../services/NhAccountProfileService'
import { NhAccountSessionService } from '../services/NhAccountSessionService'
import { NhAccountProfile } from '../model/NhAccountProfile'
import {
  AccountProfileBackupEntry,
  AccountProfileRepository,
} from '../storage/AccountProfileRepository'
import { BackupPreferencesAdapter } from './BackupPreferencesAdapter'
import { BackupSettingsValue } from './BackupTypes'

type SettingsMap = Record<string, BackupSettingsValue>

const LLM_SECRET_PREFIX: string = 'nextn_llm_secrets.'
const ACCOUNT_SESSION_KEY: string = 'account.session.primary'
const ACCOUNT_SESSIONS_KEY: string = 'account.sessions.v1'
const ACCOUNT_PROFILES_KEY: string = 'account.profiles.v1'
const MAX_ACCOUNT_PROFILES_BACKUP_CHARS: number = 256 * 1024

class AccountProfilesBackupBundle {
  version: number = 1
  entries: AccountProfileBackupEntry[] = []
}

/**
 * Reads/writes NextN's HUKS-sealed secret families for backup (Phase 1.5 of
 * the ported NextE backup chain).
 *
 * The 'secrets' section only ever rides inside the AES-256-GCM password
 * container. On export, each HUKS envelope is decrypted with the source
 * device's non-exportable key and carried as plaintext inside that container;
 * on restore it is re-wrapped with the target device's own HUKS key. This is
 * the cross-device equivalent of NextE's cookie/API-key credential restore.
 *
 * Restore is additive (overwrites families present in the backup, keeps
 * absent families untouched); replace mode is used only for rollback and
 * returns the target to its exact pre-restore secret state.
 */
export class BackupSecretsAdapter {
  static async exportSecrets(context: common.UIAbilityContext): Promise<SettingsMap> {
    const out: SettingsMap = await BackupPreferencesAdapter.exportSecrets(context)
    const llm: Record<string, string> = await LlmSourceSecretVault.exportPlaintextForBackup(context)
    const llmKeys: string[] = Object.keys(llm)
    for (let i: number = 0; i < llmKeys.length; i++) {
      out[`${LLM_SECRET_PREFIX}${llmKeys[i]}`] = llm[llmKeys[i]]
    }
    const session: string | null = await NhAccountSessionService.exportSealedForBackup(context)
    if (session !== null && session.length > 0) {
      out[ACCOUNT_SESSION_KEY] = session
    }
    out[ACCOUNT_SESSIONS_KEY] = await NhAccountSessionService.exportAllSealedForBackup(context)
    const profileBundle: AccountProfilesBackupBundle = new AccountProfilesBackupBundle()
    profileBundle.entries = await AccountProfileRepository.exportForBackup(context)
    const profileRaw: string = JSON.stringify(profileBundle)
    if (profileRaw.length <= 0 || profileRaw.length > MAX_ACCOUNT_PROFILES_BACKUP_CHARS) {
      throw new Error('account_profile_backup_shape_invalid')
    }
    out[ACCOUNT_PROFILES_KEY] = profileRaw
    return out
  }

  static async reapply(context: common.UIAbilityContext): Promise<void> {
    await NhAccountSessionService.restoreAfterBackup(context)
    await NhAccountProfileService.restore(context)
  }

  static async restoreSecrets(
    context: common.UIAbilityContext,
    map: SettingsMap,
    replace: boolean,
  ): Promise<void> {
    if (replace) {
      await BackupPreferencesAdapter.replace(context, map, true)
    } else {
      await BackupPreferencesAdapter.restore(context, map, true)
    }
    const llmValues: Record<string, string> = {}
    const keys: string[] = Object.keys(map)
    for (let i: number = 0; i < keys.length; i++) {
      const key: string = keys[i]
      if (key.startsWith(LLM_SECRET_PREFIX)) {
        const value = map[key]
        if (typeof value === 'string') {
          llmValues[key.substring(LLM_SECRET_PREFIX.length)] = value
        }
      }
    }
    const llmKeyCount: number = Object.keys(llmValues).length
    const sessionValue: BackupSettingsValue | undefined = map[ACCOUNT_SESSION_KEY]
    const hasSession: boolean = typeof sessionValue === 'string' && (sessionValue as string).length > 0
    const sessionsValue: BackupSettingsValue | undefined = map[ACCOUNT_SESSIONS_KEY]
    const hasSessionBundle: boolean = typeof sessionsValue === 'string'
    const profilesValue: BackupSettingsValue | undefined = map[ACCOUNT_PROFILES_KEY]
    const hasProfileBundle: boolean = typeof profilesValue === 'string'

    // Rollback always rewrites the full previous vault (an empty map clears it).
    // Additive restore merges onto the target vault so keys absent from the
    // backup are preserved, matching NextE's restore semantics.
    if (replace) {
      await LlmSourceSecretVault.restorePlaintextFromBackup(context, llmValues)
    } else if (llmKeyCount > 0) {
      const current: Record<string, string> = await LlmSourceSecretVault.exportPlaintextForBackup(context)
      const merged: Record<string, string> = current
      const llmKeys: string[] = Object.keys(llmValues)
      for (let i: number = 0; i < llmKeys.length; i++) {
        merged[llmKeys[i]] = llmValues[llmKeys[i]]
      }
      await LlmSourceSecretVault.restorePlaintextFromBackup(context, merged)
    }
    if (hasSessionBundle) {
      await NhAccountSessionService.restoreAllSealedFromBackup(
        context,
        sessionsValue as string,
        true,
      )
    } else if (replace) {
      await NhAccountSessionService.restoreAllSealedFromBackup(context, '', true)
    } else if (hasSession) {
      await NhAccountSessionService.restoreSealedFromBackup(context, sessionValue as string)
    }
    if (hasProfileBundle) {
      await AccountProfileRepository.restoreBackup(
        context,
        BackupSecretsAdapter.parseAccountProfiles(profilesValue as string),
        true,
      )
    } else if (replace) {
      await AccountProfileRepository.restoreBackup(context, [], true)
    }
  }

  private static parseAccountProfiles(raw: string): AccountProfileBackupEntry[] {
    if (raw.length <= 0 || raw.length > MAX_ACCOUNT_PROFILES_BACKUP_CHARS) {
      throw new Error('account_profile_backup_shape_invalid')
    }
    let parsed: AccountProfilesBackupBundle
    try {
      parsed = JSON.parse(raw) as AccountProfilesBackupBundle
    } catch (_error) {
      throw new Error('account_profile_backup_shape_invalid')
    }
    if (parsed === null || typeof parsed !== 'object' || parsed.version !== 1 ||
      !Array.isArray(parsed.entries)) {
      throw new Error('account_profile_backup_shape_invalid')
    }
    const entries: AccountProfileBackupEntry[] = []
    const seen: Set<string> = new Set<string>()
    for (let i: number = 0; i < parsed.entries.length; i++) {
      const rawEntry: AccountProfileBackupEntry = parsed.entries[i]
      if (rawEntry === null || typeof rawEntry !== 'object' || typeof rawEntry.key !== 'string' ||
        rawEntry.profile === null || typeof rawEntry.profile !== 'object') {
        throw new Error('account_profile_backup_shape_invalid')
      }
      const key: string = rawEntry.key.trim()
      const rawProfile: NhAccountProfile = rawEntry.profile
      if (key.length === 0 || key !== rawEntry.key || seen.has(key) ||
        typeof rawProfile.username !== 'string' || typeof rawProfile.userUrl !== 'string' ||
        typeof rawProfile.userId !== 'string' || typeof rawProfile.avatarUrl !== 'string') {
        throw new Error('account_profile_backup_shape_invalid')
      }
      const entry: AccountProfileBackupEntry = new AccountProfileBackupEntry()
      entry.key = key
      entry.profile.username = rawProfile.username
      entry.profile.userUrl = rawProfile.userUrl
      entry.profile.userId = rawProfile.userId
      entry.profile.avatarUrl = rawProfile.avatarUrl
      if (!entry.profile.hasIdentity()) {
        throw new Error('account_profile_backup_shape_invalid')
      }
      seen.add(key)
      entries.push(entry)
    }
    return entries
  }
}
