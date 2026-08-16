import { common } from '@kit.AbilityKit'
import { LlmSourceSecretVault } from '../services/LlmSourceSecretVault'
import { NhAccountSessionService } from '../services/NhAccountSessionService'
import { BackupSettingsValue } from './BackupTypes'

type SettingsMap = Record<string, BackupSettingsValue>

const LLM_SECRET_PREFIX: string = 'nextn_llm_secrets.'
const ACCOUNT_SESSION_KEY: string = 'account.session.primary'

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
    const out: SettingsMap = {}
    const llm: Record<string, string> = await LlmSourceSecretVault.exportPlaintextForBackup(context)
    const llmKeys: string[] = Object.keys(llm)
    for (let i: number = 0; i < llmKeys.length; i++) {
      out[`${LLM_SECRET_PREFIX}${llmKeys[i]}`] = llm[llmKeys[i]]
    }
    const session: string | null = await NhAccountSessionService.exportSealedForBackup(context)
    if (session !== null && session.length > 0) {
      out[ACCOUNT_SESSION_KEY] = session
    }
    return out
  }

  static async reapply(context: common.UIAbilityContext): Promise<void> {
    await NhAccountSessionService.restoreAfterBackup(context)
  }

  static async restoreSecrets(
    context: common.UIAbilityContext,
    map: SettingsMap,
    replace: boolean,
  ): Promise<void> {
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
    if (replace) {
      if (hasSession) {
        await NhAccountSessionService.restoreSealedFromBackup(context, sessionValue as string)
      } else {
        await NhAccountSessionService.clearSealedForBackup(context)
      }
    } else if (hasSession) {
      await NhAccountSessionService.restoreSealedFromBackup(context, sessionValue as string)
    }
  }
}
