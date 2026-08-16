import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { NhContentFilterRule, NhContentFilterType } from '../model/NhContentFilter'
import { LocalDataStore } from './LocalDataStore'

const SQL_SELECT_RULES: string =
  'SELECT rule_id, rule_type, rule_text, enabled, is_regex FROM content_filter_rules ORDER BY position_index ASC, rule_id ASC'
const SQL_UPSERT_RULE: string =
  'INSERT INTO content_filter_rules (rule_id, rule_type, rule_text, enabled, is_regex, position_index) VALUES (?, ?, ?, ?, ?, ?) ' +
  'ON CONFLICT(rule_id) DO UPDATE SET rule_type = excluded.rule_type, rule_text = excluded.rule_text, ' +
  'enabled = excluded.enabled, is_regex = excluded.is_regex'
const SQL_DELETE_RULE: string = 'DELETE FROM content_filter_rules WHERE rule_id = ?'
const SQL_MAX_POSITION: string = 'SELECT MAX(position_index) AS max_position FROM content_filter_rules'
const SQL_POSITION_FOR_ID: string = 'SELECT position_index FROM content_filter_rules WHERE rule_id = ? LIMIT 1'

/** Durable RDB store for the intentionally small, local-only rule set. */
export class ContentFilterRepository {
  static async load(context: common.UIAbilityContext): Promise<NhContentFilterRule[]> {
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const result: relationalStore.ResultSet = await store.querySql(SQL_SELECT_RULES)
    const rules: NhContentFilterRule[] = []
    try {
      while (result.goToNextRow()) {
        const rule: NhContentFilterRule = new NhContentFilterRule()
        rule.id = ContentFilterRepository.stringValue(result, 'rule_id')
        rule.type = ContentFilterRepository.normalizeType(ContentFilterRepository.stringValue(result, 'rule_type'))
        rule.text = ContentFilterRepository.stringValue(result, 'rule_text')
        rule.enabled = ContentFilterRepository.numberValue(result, 'enabled') > 0
        rule.isRegex = ContentFilterRepository.numberValue(result, 'is_regex') > 0
        if (rule.id.length > 0 && rule.text.length > 0) {
          rules.push(rule)
        }
      }
    } finally {
      result.close()
    }
    return rules
  }

  static async upsert(context: common.UIAbilityContext, rule: NhContentFilterRule): Promise<void> {
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    const position: number = await ContentFilterRepository.positionForUpsert(store, rule.id)
    await store.executeSql(SQL_UPSERT_RULE, [
      rule.id,
      rule.type,
      rule.text,
      rule.enabled ? 1 : 0,
      rule.isRegex ? 1 : 0,
      position,
    ])
  }

  static async remove(context: common.UIAbilityContext, ruleId: string): Promise<void> {
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    await store.executeSql(SQL_DELETE_RULE, [ruleId])
  }

  private static normalizeType(value: string): NhContentFilterType {
    if (value === NhContentFilterType.COMMENTER || value === NhContentFilterType.COMMENT) {
      return value as NhContentFilterType
    }
    return NhContentFilterType.TITLE
  }

  private static async positionForUpsert(store: relationalStore.RdbStore, ruleId: string): Promise<number> {
    const existing: relationalStore.ResultSet = await store.querySql(SQL_POSITION_FOR_ID, [ruleId])
    try {
      if (existing.goToNextRow()) {
        return ContentFilterRepository.numberValue(existing, 'position_index')
      }
    } finally {
      existing.close()
    }
    const max: relationalStore.ResultSet = await store.querySql(SQL_MAX_POSITION)
    try {
      if (max.goToNextRow() && !max.isColumnNull(max.getColumnIndex('max_position'))) {
        return ContentFilterRepository.numberValue(max, 'max_position') + 1
      }
    } finally {
      max.close()
    }
    return 0
  }

  private static stringValue(result: relationalStore.ResultSet, column: string): string {
    const index: number = result.getColumnIndex(column)
    return result.isColumnNull(index) ? '' : result.getString(index)
  }

  private static numberValue(result: relationalStore.ResultSet, column: string): number {
    const index: number = result.getColumnIndex(column)
    return result.isColumnNull(index) ? 0 : Math.floor(result.getDouble(index))
  }

  /** Backup export: durable filter rules in display order. */
  static async exportForBackup(context: common.UIAbilityContext): Promise<NhContentFilterRule[]> {
    return ContentFilterRepository.load(context)
  }

  /** Backup restore: authoritative replacement of the filter-rule table. */
  static async restoreBackup(context: common.UIAbilityContext, rules: NhContentFilterRule[]): Promise<void> {
    const store: relationalStore.RdbStore = await LocalDataStore.open(context)
    await store.executeSql('DELETE FROM content_filter_rules')
    for (let i: number = 0; i < rules.length; i++) {
      const rule: NhContentFilterRule = rules[i]
      if (rule.id.length === 0 || rule.text.trim().length === 0) {
        continue
      }
      await store.executeSql(SQL_UPSERT_RULE, [
        rule.id,
        rule.type,
        rule.text,
        rule.enabled ? 1 : 0,
        rule.isRegex ? 1 : 0,
        i,
      ])
    }
  }
}
