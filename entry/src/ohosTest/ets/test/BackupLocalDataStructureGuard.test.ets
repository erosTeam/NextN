import { describe, expect, it } from '@ohos/hypium'
import { BackupService } from 'shared'

function localData(
  readProgress: string,
  viewedHistory: string,
  searchHistory: string,
  quickSearches: string,
  localBlock: string,
  settingsTables: string,
): string {
  return `{"readProgress":${readProgress},"viewedHistory":${viewedHistory},` +
    `"searchHistory":${searchHistory},"quickSearches":${quickSearches},` +
    `"localBlock":${localBlock},"settingsTables":${settingsTables}}`
}

function fullSettingsTables(): string {
  return '{"reader_settings":{},"download_settings":{},"browse_presentation_settings":{},"catalog_preferences":{}}'
}

function validLocalData(): string {
  return localData(
    '[{"g":"gallery-1","i":3,"t":5}]',
    '[]',
    '["safe query"]',
    '[]',
    '{"rules":[]}',
    fullSettingsTables(),
  )
}

function emptyLocalData(): string {
  return localData(
    '[]',
    '[]',
    '[]',
    '[]',
    '{"rules":[]}',
    fullSettingsTables(),
  )
}

function envelopeWithLocalData(localDataJson: string, declaresLocalData: boolean): string {
  const sections: string = declaresLocalData ? '["preferences","localData"]' : '["preferences"]'
  return `{"magic":"NEXTN_BACKUP","appId":"com.erosteam.nextn","schemaVersion":1,` +
    `"minSupportedSchemaVersion":1,"createdAt":"2026-08-17T00:00:00.000Z",` +
    `"appVersion":"test","appVersionCode":1,"sections":${sections},` +
    `"counts":{"preferences":0},"data":{"preferences":{},"localData":${localDataJson}}}`
}

function envelopeWithoutLocalDataButSection(): string {
  return '{"magic":"NEXTN_BACKUP","appId":"com.erosteam.nextn","schemaVersion":1,' +
    '"minSupportedSchemaVersion":1,"createdAt":"2026-08-17T00:00:00.000Z",' +
    '"appVersion":"test","appVersionCode":1,"sections":["preferences","localData"],' +
    '"counts":{"preferences":0},"data":{"preferences":{}}}'
}

async function parseOk(raw: string): Promise<boolean> {
  const result = await BackupService.parseAndPreview(raw)
  return result.ok
}

async function parseMalformed(raw: string): Promise<boolean> {
  const result = await BackupService.parseAndPreview(raw)
  return !result.ok && result.code === 'malformed'
}

export default function backupLocalDataStructureGuardTest(): void {
  describe('Backup local-data structure guard', () => {
    it('accepts the original local-data shape without optional comment-filter scalars', 0, async (done: Function) => {
      expect(await parseOk(envelopeWithLocalData(validLocalData(), true))).assertEqual(true)
      done()
    })

    it('accepts explicit empty replacement snapshots and empty settings tables', 0, async (done: Function) => {
      expect(await parseOk(envelopeWithLocalData(emptyLocalData(), true))).assertEqual(true)
      done()
    })

    it('rejects a missing or wrongly typed authoritative dataset before preview', 0, async (done: Function) => {
      const missingReadProgress: string =
        '{"viewedHistory":[],"searchHistory":[],"quickSearches":[],' +
        '"localBlock":{"rules":[]},"settingsTables":' + fullSettingsTables() + '}'
      const wrongSearchHistory: string = localData('[]', '[]', '{}', '[]', '{"rules":[]}', fullSettingsTables())
      const wrongProgressEntry: string =
        localData('[{"g":1,"i":3,"t":5}]', '[]', '[]', '[]', '{"rules":[]}', fullSettingsTables())
      const wrongViewedHistoryEntry: string = localData(
        '[]',
        '[{"galleryId":"1","mediaId":"m","title":"t","thumbnailUrl":"u","pageCount":1,' +
          '"lastReadIndex":0,"hasReadProgress":false,"lastOpenedAt":1}]',
        '[]',
        '[]',
        '{"rules":[]}',
        fullSettingsTables(),
      )
      expect(await parseMalformed(envelopeWithLocalData(missingReadProgress, true))).assertEqual(true)
      expect(await parseMalformed(envelopeWithLocalData(wrongSearchHistory, true))).assertEqual(true)
      expect(await parseMalformed(envelopeWithLocalData(wrongProgressEntry, true))).assertEqual(true)
      expect(await parseMalformed(envelopeWithLocalData(wrongViewedHistoryEntry, true))).assertEqual(true)
      done()
    })

    it('rejects malformed nested sections and section-data topology mismatches', 0, async (done: Function) => {
      const malformedLocalBlock: string = localData('[]', '[]', '[]', '[]', '{"rules":{}}', fullSettingsTables())
      const malformedQuickSearch: string =
        localData('[]', '[]', '[]', '[{"q":7,"p":1}]', '{"rules":[]}', fullSettingsTables())
      const missingSettingsTable: string = localData('[]', '[]', '[]', '[]', '{"rules":[]}', '{"reader_settings":{}}')
      expect(await parseMalformed(envelopeWithLocalData(malformedLocalBlock, true))).assertEqual(true)
      expect(await parseMalformed(envelopeWithLocalData(malformedQuickSearch, true))).assertEqual(true)
      expect(await parseMalformed(envelopeWithLocalData(missingSettingsTable, true))).assertEqual(true)
      expect(await parseMalformed(envelopeWithLocalData(validLocalData(), false))).assertEqual(true)
      expect(await parseMalformed(envelopeWithoutLocalDataButSection())).assertEqual(true)
      done()
    })
  })
}
