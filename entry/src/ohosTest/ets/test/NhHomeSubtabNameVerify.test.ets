import { describe, expect, it } from '@ohos/hypium'
import { abilityDelegatorRegistry, Driver } from '@kit.TestKit'
import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'

const RESERVED: string[] = ['builtin-latest', 'builtin-popular', 'starter-language-chinese',
  'starter-highly-favorited']
const KEYS: string[] = ['home_source_latest', 'home_source_popular', 'home_subtab_starter_chinese',
  'home_subtab_starter_favorited']

async function realContext(driver: Driver): Promise<common.UIAbilityContext> {
  const d = abilityDelegatorRegistry.getAbilityDelegator()
  await d.startAbility({ bundleName: 'com.erosteam.nextn', abilityName: 'EntryAbility' })
  for (let i = 0; i < 80; i++) {
    try { const a = await d.getCurrentTopAbility(); if (a.context.abilityInfo.name === 'EntryAbility') return a.context as common.UIAbilityContext } catch (_) {}
    await driver.delayMs(100)
  }
  throw new Error('EntryAbility context unavailable')
}

export default function nhHomeSubtabNameVerifyTrialTest(): void {
  const args = abilityDelegatorRegistry.getArguments().parameters
  if (args['-s class'] !== 'NhHomeSubtabNameVerifyTrial') return
  describe('NhHomeSubtabNameVerifyTrial', (): void => {
    it('noReservedHomeSubtabNameIsAResourceKey', 0, async (): Promise<void> => {
      const d = abilityDelegatorRegistry.getAbilityDelegator()
      const driver = Driver.create()
      const context = await realContext(driver)
      const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context,
        { name: 'NextN.db', securityLevel: relationalStore.SecurityLevel.S3, autoCleanDirtyData: true })
      const rs: relationalStore.ResultSet = await store.querySql(
        'SELECT profile_uuid, name FROM home_subtabs WHERE scope_key=? AND COALESCE(deleted_at,0)=0',
        ['global'])
      let keyNames = 0
      let reservedSeen = 0
      try {
        while (rs.goToNextRow()) {
          const uuid = rs.getString(0)
          const name = rs.getString(1)
          if (RESERVED.indexOf(uuid) < 0) continue
          reservedSeen++
          d.print('[NHV] ' + uuid + '=' + name)
          if (KEYS.indexOf(name) >= 0) keyNames++
        }
      } finally { rs.close() }
      d.print('[NHV] reserved_seen=' + reservedSeen + ' key_names=' + keyNames)
      expect(reservedSeen >= 0).assertTrue()
      expect(keyNames).assertEqual(0)
    })
  })
}
