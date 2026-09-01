import { common } from '@kit.AbilityKit'
import { taskpool, util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { AxiosHttpClient, AxiosTextResponse } from '../network/AxiosHttpClient'
import { connectSyncSettings } from '../state/SyncSettingsState'
import {
    SYNC_APP_ID,
    SYNC_FILE_NAME,
    SYNC_MAGIC,
    SYNC_MIN_SUPPORTED_SCHEMA_VERSION,
    SYNC_SCHEMA_VERSION,
    SYNC_WEBDAV_MANIFEST_FILE,
    SYNC_WEBDAV_ROOT_DIR,
    SyncDatasetSelection,
    SyncEnvelopeV1,
    SyncHomeSubtabRecord,
    SyncManifestDataset,
    SyncManifestShard,
    SyncManifestV1,
    SyncDatasets,
    SyncLocalBlockRuleRecord,
    SyncLocalBlockSettingsRecord,
    SyncLocalUserTagRecord,
    SyncLocalUserTagSettingsRecord,
    SyncQuickSearchRecord,
    SyncReadProgressRecord,
    SyncSearchHistoryRecord,
    SyncSettingsTableRecord,
    SyncViewedHistoryRecord,
} from './SyncTypes'
import { SyncLocalDataAdapter } from './SyncLocalDataAdapter'
import { SyncService } from './SyncService'
import { WebDavManifestWriteGuard, WebDavRemoteText } from './WebDavManifestWriteGuard'

const CONNECT_TIMEOUT_MS: number = 10000
const READ_TIMEOUT_MS: number = 20000
const SHARD_COUNT: number = 64
const MAX_MANIFEST_SYNC_ATTEMPTS: number = 3

const DATASET_READ_PROGRESS: string = 'read-progress'
const DATASET_VIEWED_HISTORY: string = 'viewed-history'
const DATASET_SEARCH_HISTORY: string = 'search-history'
const DATASET_QUICK_SEARCHES: string = 'quick-searches'
const DATASET_HOME_SUBTABS: string = 'home-subtabs'
const DATASET_LOCAL_USER_TAGS: string = 'local-user-tags'
const DATASET_LOCAL_BLOCK: string = 'local-block'
const DATASET_SETTINGS_TABLES: string = 'settings-tables'
const DATASET_IDS: string[] = [
    DATASET_READ_PROGRESS,
    DATASET_VIEWED_HISTORY,
    DATASET_SEARCH_HISTORY,
    DATASET_QUICK_SEARCHES,
    DATASET_HOME_SUBTABS,
    DATASET_LOCAL_USER_TAGS,
    DATASET_LOCAL_BLOCK,
    DATASET_SETTINGS_TABLES,
]

class WebDavBuiltShard {
    id: string = ''
    path: string = ''
    raw: string = ''
    sha256: string = ''
    recordCount: number = 0
    updatedAt: number = 0
}

@Concurrent
function buildWebDavShardsTask(rawEnvelope: string, datasetId: string): string {
    const shardCount: number = 64
    const datasetReadProgress: string = 'read-progress'
    const datasetViewedHistory: string = 'viewed-history'
    const datasetSearchHistory: string = 'search-history'
    const datasetQuickSearches: string = 'quick-searches'
    const datasetHomeSubtabs: string = 'home-subtabs'
    const datasetLocalUserTags: string = 'local-user-tags'
    const datasetLocalBlock: string = 'local-block'
    const datasetSettingsTables: string = 'settings-tables'

    const compareKey = (a: string, b: string): number => {
        if (a < b) {
            return -1
        }
        if (a > b) {
            return 1
        }
        return 0
    }
    const shardIdForKey = (key: string): string => {
        let hash: number = 2166136261
        for (let i: number = 0; i < key.length; i++) {
            hash ^= key.charCodeAt(i)
            hash = Math.imul(hash, 16777619) >>> 0
        }
        return (hash % shardCount).toString(16).padStart(2, '0')
    }
    const normalizeEnvelope = (envelope: SyncEnvelopeV1): void => {
        if (envelope.datasets === undefined || envelope.datasets === null) {
            envelope.datasets = new SyncDatasets()
        }
        if (!Array.isArray(envelope.datasets.readProgress)) {
            envelope.datasets.readProgress = []
        }
        if (!Array.isArray(envelope.datasets.viewedHistory)) {
            envelope.datasets.viewedHistory = []
        }
        if (!Array.isArray(envelope.datasets.searchHistory)) {
            envelope.datasets.searchHistory = []
        }
        if (!Array.isArray(envelope.datasets.quickSearches)) {
            envelope.datasets.quickSearches = []
        }
        if (!Array.isArray(envelope.datasets.homeSubtabs)) {
            envelope.datasets.homeSubtabs = []
        }
        if (!Array.isArray(envelope.datasets.localUserTags)) {
            envelope.datasets.localUserTags = []
        }
        if (!Array.isArray(envelope.datasets.localUserTagSettings)) {
            envelope.datasets.localUserTagSettings = []
        }
        if (!Array.isArray(envelope.datasets.localBlockSettings)) {
            envelope.datasets.localBlockSettings = []
        }
        if (!Array.isArray(envelope.datasets.localBlockRules)) {
            envelope.datasets.localBlockRules = []
        }
        if (!Array.isArray(envelope.datasets.settingsTables)) {
            envelope.datasets.settingsTables = []
        }
    }
    const bucketForKey = (ids: string[], envelopes: SyncEnvelopeV1[], key: string): SyncEnvelopeV1 => {
        const id: string = shardIdForKey(key)
        for (let i: number = 0; i < ids.length; i++) {
            if (ids[i] === id) {
                return envelopes[i]
            }
        }
        const envelope: SyncEnvelopeV1 = new SyncEnvelopeV1()
        ids.push(id)
        envelopes.push(envelope)
        return envelope
    }
    const sortBuckets = (ids: string[], envelopes: SyncEnvelopeV1[]): void => {
        for (let i: number = 0; i < ids.length; i++) {
            let minIndex: number = i
            for (let j: number = i + 1; j < ids.length; j++) {
                if (compareKey(ids[j], ids[minIndex]) < 0) {
                    minIndex = j
                }
            }
            if (minIndex !== i) {
                const id: string = ids[i]
                const envelope: SyncEnvelopeV1 = envelopes[i]
                ids[i] = ids[minIndex]
                envelopes[i] = envelopes[minIndex]
                ids[minIndex] = id
                envelopes[minIndex] = envelope
            }
        }
    }
    const canonicalReadProgress = (source: SyncReadProgressRecord): SyncReadProgressRecord => {
        const out: SyncReadProgressRecord = new SyncReadProgressRecord()
        out.scopeKey = source.scopeKey
        out.galleryId = source.galleryId
        out.pageIndex = source.pageIndex
        out.updatedAt = source.updatedAt
        out.deletedAt = source.deletedAt
        return out
    }
    const collectShardBuckets = (
        envelope: SyncEnvelopeV1,
        ids: string[],
        envelopes: SyncEnvelopeV1[],
    ): void => {
        if (datasetId === datasetReadProgress) {
            for (let i: number = 0; i < envelope.datasets.readProgress.length; i++) {
                const r: SyncReadProgressRecord = envelope.datasets.readProgress[i]
                bucketForKey(ids, envelopes, r.scopeKey + ':' + r.galleryId).datasets.readProgress.push(
                    canonicalReadProgress(r),
                )
            }
        } else if (datasetId === datasetViewedHistory) {
            for (let i: number = 0; i < envelope.datasets.viewedHistory.length; i++) {
                const r: SyncViewedHistoryRecord = envelope.datasets.viewedHistory[i]
                bucketForKey(ids, envelopes, r.scopeKey + ':' + r.galleryId).datasets.viewedHistory.push(r)
            }
        } else if (datasetId === datasetSearchHistory) {
            for (let i: number = 0; i < envelope.datasets.searchHistory.length; i++) {
                const r: SyncSearchHistoryRecord = envelope.datasets.searchHistory[i]
                bucketForKey(ids, envelopes, r.scopeKey + ':' + r.queryText).datasets.searchHistory.push(r)
            }
        } else if (datasetId === datasetQuickSearches) {
            for (let i: number = 0; i < envelope.datasets.quickSearches.length; i++) {
                const r: SyncQuickSearchRecord = envelope.datasets.quickSearches[i]
                bucketForKey(ids, envelopes, r.scopeKey + ':' + r.queryText).datasets.quickSearches.push(r)
            }
        } else if (datasetId === datasetHomeSubtabs) {
            for (let i: number = 0; i < envelope.datasets.homeSubtabs.length; i++) {
                const r: SyncHomeSubtabRecord = envelope.datasets.homeSubtabs[i]
                bucketForKey(ids, envelopes, r.scopeKey + ':' + r.profileUuid).datasets.homeSubtabs.push(r)
            }
        } else if (datasetId === datasetLocalUserTags) {
            for (let i: number = 0; i < envelope.datasets.localUserTags.length; i++) {
                const r: SyncLocalUserTagRecord = envelope.datasets.localUserTags[i]
                bucketForKey(ids, envelopes, r.scopeKey + ':' + r.tagId).datasets.localUserTags.push(r)
            }
            for (let i: number = 0; i < envelope.datasets.localUserTagSettings.length; i++) {
                const r: SyncLocalUserTagSettingsRecord = envelope.datasets.localUserTagSettings[i]
                bucketForKey(ids, envelopes, r.scopeKey).datasets.localUserTagSettings.push(r)
            }
        } else if (datasetId === datasetLocalBlock) {
            for (let i: number = 0; i < envelope.datasets.localBlockSettings.length; i++) {
                const r: SyncLocalBlockSettingsRecord = envelope.datasets.localBlockSettings[i]
                bucketForKey(ids, envelopes, r.scopeKey).datasets.localBlockSettings.push(r)
            }
            for (let i: number = 0; i < envelope.datasets.localBlockRules.length; i++) {
                const r: SyncLocalBlockRuleRecord = envelope.datasets.localBlockRules[i]
                bucketForKey(ids, envelopes, r.scopeKey + ':' + r.ruleId).datasets.localBlockRules.push(r)
            }
        } else if (datasetId === datasetSettingsTables) {
            for (let i: number = 0; i < envelope.datasets.settingsTables.length; i++) {
                const r: SyncSettingsTableRecord = envelope.datasets.settingsTables[i]
                bucketForKey(ids, envelopes, r.scopeKey + ':' + r.tableName + ':' + r.key)
                    .datasets.settingsTables.push(r)
            }
        }
        sortBuckets(ids, envelopes)
    }
    const datasetRecordCount = (envelope: SyncEnvelopeV1): number => {
        if (datasetId === datasetReadProgress) {
            return envelope.datasets.readProgress.length
        }
        if (datasetId === datasetViewedHistory) {
            return envelope.datasets.viewedHistory.length
        }
        if (datasetId === datasetSearchHistory) {
            return envelope.datasets.searchHistory.length
        }
        if (datasetId === datasetQuickSearches) {
            return envelope.datasets.quickSearches.length
        }
        if (datasetId === datasetHomeSubtabs) {
            return envelope.datasets.homeSubtabs.length
        }
        if (datasetId === datasetLocalUserTags) {
            return envelope.datasets.localUserTags.length + envelope.datasets.localUserTagSettings.length
        }
        if (datasetId === datasetLocalBlock) {
            return envelope.datasets.localBlockSettings.length + envelope.datasets.localBlockRules.length
        }
        if (datasetId === datasetSettingsTables) {
            return envelope.datasets.settingsTables.length
        }
        return 0
    }
    const datasetUpdatedAt = (envelope: SyncEnvelopeV1): number => {
        let out: number = 0
        if (datasetId === datasetReadProgress) {
            for (let i: number = 0; i < envelope.datasets.readProgress.length; i++) {
                out = Math.max(out, envelope.datasets.readProgress[i].updatedAt, envelope.datasets.readProgress[i].deletedAt)
            }
        } else if (datasetId === datasetViewedHistory) {
            for (let i: number = 0; i < envelope.datasets.viewedHistory.length; i++) {
                out = Math.max(out, envelope.datasets.viewedHistory[i].viewedAt, envelope.datasets.viewedHistory[i].deletedAt)
            }
        } else if (datasetId === datasetSearchHistory) {
            for (let i: number = 0; i < envelope.datasets.searchHistory.length; i++) {
                out = Math.max(out, envelope.datasets.searchHistory[i].updatedAt, envelope.datasets.searchHistory[i].deletedAt)
            }
        } else if (datasetId === datasetQuickSearches) {
            for (let i: number = 0; i < envelope.datasets.quickSearches.length; i++) {
                out = Math.max(out, envelope.datasets.quickSearches[i].pinnedAt, envelope.datasets.quickSearches[i].updatedAt, envelope.datasets.quickSearches[i].deletedAt)
            }
        } else if (datasetId === datasetHomeSubtabs) {
            for (let i: number = 0; i < envelope.datasets.homeSubtabs.length; i++) {
                out = Math.max(out, envelope.datasets.homeSubtabs[i].updatedAt, envelope.datasets.homeSubtabs[i].deletedAt)
            }
        } else if (datasetId === datasetLocalUserTags) {
            for (let i: number = 0; i < envelope.datasets.localUserTags.length; i++) {
                out = Math.max(out, envelope.datasets.localUserTags[i].updatedAt, envelope.datasets.localUserTags[i].deletedAt)
            }
            for (let i: number = 0; i < envelope.datasets.localUserTagSettings.length; i++) {
                out = Math.max(out, envelope.datasets.localUserTagSettings[i].updatedAt, envelope.datasets.localUserTagSettings[i].deletedAt)
            }
        } else if (datasetId === datasetLocalBlock) {
            for (let i: number = 0; i < envelope.datasets.localBlockSettings.length; i++) {
                out = Math.max(out, envelope.datasets.localBlockSettings[i].updatedAt, envelope.datasets.localBlockSettings[i].deletedAt)
            }
            for (let i: number = 0; i < envelope.datasets.localBlockRules.length; i++) {
                out = Math.max(out, envelope.datasets.localBlockRules[i].updatedAt, envelope.datasets.localBlockRules[i].deletedAt)
            }
        } else if (datasetId === datasetSettingsTables) {
            for (let i: number = 0; i < envelope.datasets.settingsTables.length; i++) {
                out = Math.max(out, envelope.datasets.settingsTables[i].updatedAt, envelope.datasets.settingsTables[i].deletedAt)
            }
        }
        return out
    }
    const stableGeneratedAt = (envelope: SyncEnvelopeV1): string => {
        const updatedAt: number = datasetUpdatedAt(envelope)
        if (updatedAt <= 0) {
            return ''
        }
        return new Date(updatedAt).toISOString()
    }
    const sortShardEnvelope = (envelope: SyncEnvelopeV1): void => {
        if (datasetId === datasetReadProgress) {
            envelope.datasets.readProgress.sort((a: SyncReadProgressRecord, b: SyncReadProgressRecord): number => {
                return compareKey(a.scopeKey + ':' + a.galleryId, b.scopeKey + ':' + b.galleryId)
            })
        } else if (datasetId === datasetViewedHistory) {
            envelope.datasets.viewedHistory.sort((a: SyncViewedHistoryRecord, b: SyncViewedHistoryRecord): number => {
                return compareKey(a.scopeKey + ':' + a.galleryId, b.scopeKey + ':' + b.galleryId)
            })
        } else if (datasetId === datasetSearchHistory) {
            envelope.datasets.searchHistory.sort((a: SyncSearchHistoryRecord, b: SyncSearchHistoryRecord): number => {
                return compareKey(a.scopeKey + ':' + a.queryText, b.scopeKey + ':' + b.queryText)
            })
        } else if (datasetId === datasetQuickSearches) {
            envelope.datasets.quickSearches.sort((a: SyncQuickSearchRecord, b: SyncQuickSearchRecord): number => {
                return compareKey(a.scopeKey + ':' + a.queryText, b.scopeKey + ':' + b.queryText)
            })
        } else if (datasetId === datasetHomeSubtabs) {
            envelope.datasets.homeSubtabs.sort((a: SyncHomeSubtabRecord, b: SyncHomeSubtabRecord): number => {
                return compareKey(a.scopeKey + ':' + a.profileUuid, b.scopeKey + ':' + b.profileUuid)
            })
        } else if (datasetId === datasetLocalUserTags) {
            envelope.datasets.localUserTags.sort((a: SyncLocalUserTagRecord, b: SyncLocalUserTagRecord): number => {
                return compareKey(a.scopeKey + ':' + a.tagId, b.scopeKey + ':' + b.tagId)
            })
            envelope.datasets.localUserTagSettings.sort((a: SyncLocalUserTagSettingsRecord, b: SyncLocalUserTagSettingsRecord): number => {
                return compareKey(a.scopeKey, b.scopeKey)
            })
        } else if (datasetId === datasetLocalBlock) {
            envelope.datasets.localBlockSettings.sort((a: SyncLocalBlockSettingsRecord, b: SyncLocalBlockSettingsRecord): number => {
                return compareKey(a.scopeKey, b.scopeKey)
            })
            envelope.datasets.localBlockRules.sort((a: SyncLocalBlockRuleRecord, b: SyncLocalBlockRuleRecord): number => {
                return compareKey(a.scopeKey + ':' + a.ruleId, b.scopeKey + ':' + b.ruleId)
            })
        } else if (datasetId === datasetSettingsTables) {
            envelope.datasets.settingsTables.sort((a: SyncSettingsTableRecord, b: SyncSettingsTableRecord): number => {
                return compareKey(a.scopeKey + ':' + a.tableName + ':' + a.key, b.scopeKey + ':' + b.tableName + ':' + b.key)
            })
        }
    }
    const toHex = (bytes: Uint8Array): string => {
        const parts: string[] = []
        for (let i: number = 0; i < bytes.length; i++) {
            parts.push(bytes[i].toString(16).padStart(2, '0'))
        }
        return parts.join('')
    }
    const hashText = (text: string): string => {
        const md = cryptoFramework.createMd('SHA256')
        const bytes: Uint8Array = new util.TextEncoder().encodeInto(text)
        md.updateSync({ data: bytes })
        const digest = md.digestSync()
        return toHex(digest.data)
    }

    const envelope: SyncEnvelopeV1 = JSON.parse(rawEnvelope) as SyncEnvelopeV1
    normalizeEnvelope(envelope)
    const shardIds: string[] = []
    const shardEnvelopes: SyncEnvelopeV1[] = []
    collectShardBuckets(envelope, shardIds, shardEnvelopes)
    const out: Record<string, string | number>[] = []
    for (let i: number = 0; i < shardIds.length; i++) {
        const shardId: string = shardIds[i]
        const shardEnvelope: SyncEnvelopeV1 = shardEnvelopes[i]
        sortShardEnvelope(shardEnvelope)
        shardEnvelope.generatedAt = stableGeneratedAt(shardEnvelope)
        shardEnvelope.datasetId = datasetId
        shardEnvelope.shardId = shardId
        const raw: string = JSON.stringify(shardEnvelope)
        const shard: Record<string, string | number> = {}
        shard['id'] = shardId
        shard['path'] = 'datasets/' + datasetId + '/' + shardId + '.json'
        shard['raw'] = raw
        shard['sha256'] = hashText(raw)
        shard['recordCount'] = datasetRecordCount(shardEnvelope)
        shard['updatedAt'] = datasetUpdatedAt(shardEnvelope)
        out.push(shard)
    }
    return JSON.stringify(out)
}

export class WebDavSyncConfig {
    directoryUrl: string = ''
    username: string = ''
    password: string = ''
    selection: SyncDatasetSelection = new SyncDatasetSelection()
}

export class WebDavSyncService {
    private static activeRuns: Map<string, Promise<void>> = new Map<string, Promise<void>>()

    static syncNow(
        context: common.UIAbilityContext,
        config: WebDavSyncConfig,
        deviceId: string = '',
    ): Promise<void> {
        const runKey: string = WebDavSyncService.syncRunKey(config)
        const active: Promise<void> | undefined = WebDavSyncService.activeRuns.get(runKey)
        if (active !== undefined) {
            DiagnosticLogger.info('sync', 'webdav_sync_joined', 'provider=webdav')
            return active
        }
        const run: Promise<void> = WebDavSyncService.runTracked(runKey, context, config, deviceId)
        WebDavSyncService.activeRuns.set(runKey, run)
        WebDavSyncService.publishActiveRunState()
        return run
    }

    private static async runTracked(
        runKey: string,
        context: common.UIAbilityContext,
        config: WebDavSyncConfig,
        deviceId: string,
    ): Promise<void> {
        try {
            await WebDavSyncService.syncOnce(context, config, deviceId)
        } finally {
            WebDavSyncService.activeRuns.delete(runKey)
            WebDavSyncService.publishActiveRunState()
        }
    }

    private static publishActiveRunState(): void {
        connectSyncSettings().webdavSyncing = WebDavSyncService.activeRuns.size > 0
    }

    private static async syncOnce(
        context: common.UIAbilityContext,
        config: WebDavSyncConfig,
        deviceId: string,
    ): Promise<void> {
        const rootUrl: string = WebDavSyncService.syncRootUrl(config.directoryUrl)
        await WebDavSyncService.probeTransport(rootUrl, config)

        for (let attempt: number = 0; attempt < MAX_MANIFEST_SYNC_ATTEMPTS; attempt++) {
            const manifestStartedAt: number = Date.now()
            DiagnosticLogger.info('sync', 'webdav_manifest_fetch_start', `attempt=${attempt + 1}`)
            const manifestRemote: WebDavRemoteText =
                await WebDavSyncService.readRemoteFile(rootUrl + SYNC_WEBDAV_MANIFEST_FILE, config)
            DiagnosticLogger.info(
                'sync',
                'webdav_manifest_fetch_done',
                `attempt=${attempt + 1},exists=${manifestRemote.exists},durationMs=${Date.now() - manifestStartedAt}`,
            )
            const manifest: SyncManifestV1 = WebDavSyncService.parseManifest(manifestRemote.body)
            await WebDavSyncService.ensureCollections(
                rootUrl,
                config,
                manifestRemote.exists ? manifest : null,
            )
            const legacyRaw: string = manifestRemote.exists ? '' :
                await WebDavSyncService.readRemoteOptional(WebDavSyncService.legacyFileUrl(config.directoryUrl), config)
            let manifestChanged: boolean = false

            for (let i: number = 0; i < DATASET_IDS.length; i++) {
                const datasetId: string = DATASET_IDS[i]
                if (!WebDavSyncService.datasetEnabled(config.selection, datasetId)) {
                    continue
                }
                DiagnosticLogger.info('sync', 'webdav_dataset_start', `dataset=${datasetId}`)
                const one: SyncDatasetSelection = WebDavSyncService.selectionForDataset(datasetId)
                const local: SyncEnvelopeV1 = SyncService.parseRaw(
                    await SyncService.exportRaw(context, deviceId, one),
                )
                const localShards: WebDavBuiltShard[] = await WebDavSyncService.buildShards(local, datasetId)
                let remote: SyncEnvelopeV1 = await WebDavSyncService.readDatasetEnvelope(
                    rootUrl,
                    manifest,
                    datasetId,
                    config,
                    localShards,
                )
                if (WebDavSyncService.datasetRecordCount(remote, datasetId) === 0 && legacyRaw.length > 0) {
                    remote = WebDavSyncService.selectDataset(SyncService.parseRaw(legacyRaw), datasetId)
                }
                const merged: SyncEnvelopeV1 = await SyncService.mergeRemoteEnvelope(context, remote, deviceId, one)
                const shards: WebDavBuiltShard[] = WebDavSyncService.datasetRecordCount(remote, datasetId) === 0 ?
                    localShards :
                    await WebDavSyncService.buildShards(merged, datasetId)
                const prev: SyncManifestDataset | null = WebDavSyncService.findManifestDataset(manifest, datasetId)
                const changed: boolean = await WebDavSyncService.writeChangedShards(rootUrl, config, prev, shards)
                WebDavSyncService.replaceManifestDataset(manifest, datasetId, shards)
                if (changed || WebDavSyncService.manifestDatasetChanged(prev, shards)) {
                    manifestChanged = true
                    manifest.generatedAt = new Date().toISOString()
                }
                DiagnosticLogger.info('sync', 'webdav_dataset_done', `dataset=${datasetId},shards=${shards.length}`)
            }

            if (!manifestChanged) {
                return
            }
            const committed: boolean = await WebDavSyncService.writeManifest(
                rootUrl + SYNC_WEBDAV_MANIFEST_FILE,
                config,
                JSON.stringify(manifest),
                manifestRemote,
            )
            if (committed) {
                return
            }
            if (attempt + 1 < MAX_MANIFEST_SYNC_ATTEMPTS) {
                DiagnosticLogger.warn('sync', 'webdav_manifest_conflict_retry', `attempt=${attempt + 1}`)
            }
        }
        throw new Error('WebDAV manifest changed concurrently; retry later')
    }

    static async readRemote(url: string, config: WebDavSyncConfig): Promise<string> {
        return (await WebDavSyncService.readRemoteFile(url, config)).body
    }

    private static async readRemoteFile(url: string, config: WebDavSyncConfig): Promise<WebDavRemoteText> {
        const out: WebDavRemoteText = new WebDavRemoteText()
        const resp: AxiosTextResponse = await AxiosHttpClient.requestText(
            url,
            'GET',
            WebDavSyncService.headers(config),
            '',
            CONNECT_TIMEOUT_MS,
            READ_TIMEOUT_MS,
        )
        const code: number = resp.statusCode
        if (code === 404) {
            return out
        }
        if (code < 200 || code >= 300) {
            throw new Error(`WebDAV GET failed: HTTP ${code}`)
        }
        out.body = resp.body
        out.exists = true
        out.etag = resp.etag
        return out
    }

    static async writeRemote(url: string, config: WebDavSyncConfig, raw: string): Promise<void> {
        const header: Record<string, string> = WebDavSyncService.headers(config)
        header['Content-Type'] = 'application/json; charset=utf-8'
        const resp: AxiosTextResponse = await AxiosHttpClient.requestText(
            url,
            'PUT',
            header,
            raw,
            CONNECT_TIMEOUT_MS,
            READ_TIMEOUT_MS,
        )
        const code: number = resp.statusCode
        if (code < 200 || code >= 300) {
            throw new Error(`WebDAV PUT failed: HTTP ${code}`)
        }
        DiagnosticLogger.info('sync', 'webdav_sync_uploaded', `url=${url} bytes=${raw.length}`)
    }

    private static async writeManifest(
        url: string,
        config: WebDavSyncConfig,
        raw: string,
        remote: WebDavRemoteText,
    ): Promise<boolean> {
        const header: Record<string, string> = WebDavSyncService.headers(config)
        header['Content-Type'] = 'application/json; charset=utf-8'
        const precondition = WebDavManifestWriteGuard.precondition(remote)
        if (precondition.ifMatch.length > 0) {
            header['If-Match'] = precondition.ifMatch
        }
        if (precondition.ifNoneMatch.length > 0) {
            header['If-None-Match'] = precondition.ifNoneMatch
        }
        const resp: AxiosTextResponse = await AxiosHttpClient.requestText(
            url,
            'PUT',
            header,
            raw,
            CONNECT_TIMEOUT_MS,
            READ_TIMEOUT_MS,
        )
        const code: number = resp.statusCode
        if (WebDavManifestWriteGuard.isConflictStatus(code)) {
            return false
        }
        if (code < 200 || code >= 300) {
            throw new Error(`WebDAV PUT failed: HTTP ${code}`)
        }
        if (remote.exists && remote.etag.length === 0) {
            DiagnosticLogger.warn('sync', 'webdav_manifest_unversioned', 'server did not return ETag')
        }
        DiagnosticLogger.info('sync', 'webdav_sync_uploaded', `url=${url} bytes=${raw.length}`)
        return true
    }

    private static async readRemoteOptional(url: string, config: WebDavSyncConfig): Promise<string> {
        return WebDavSyncService.readRemote(url, config)
    }

    private static async probeTransport(rootUrl: string, config: WebDavSyncConfig): Promise<void> {
        const startedAt: number = Date.now()
        DiagnosticLogger.info('sync', 'webdav_options_probe_start', 'provider=webdav')
        const resp: AxiosTextResponse = await AxiosHttpClient.requestText(
            rootUrl,
            'OPTIONS',
            WebDavSyncService.headers(config),
            '',
            CONNECT_TIMEOUT_MS,
            READ_TIMEOUT_MS,
        )
        const code: number = resp.statusCode
        DiagnosticLogger.info(
            'sync',
            'webdav_options_probe_done',
            `status=${code},durationMs=${Date.now() - startedAt}`,
        )
        if (code === 401 || code === 403) {
            throw new Error(`WebDAV authentication failed: HTTP ${code}`)
        }
        if (code >= 500) {
            throw new Error(`WebDAV OPTIONS failed: HTTP ${code}`)
        }
    }

    private static async ensureCollections(
        rootUrl: string,
        config: WebDavSyncConfig,
        manifest: SyncManifestV1 | null,
    ): Promise<void> {
        if (manifest === null) {
            DiagnosticLogger.info('sync', 'webdav_collection_bootstrap', 'reason=manifest_missing')
            await WebDavSyncService.makeCollection(rootUrl, config, 'root')
            await WebDavSyncService.makeCollection(rootUrl + 'datasets/', config, 'datasets')
        }
        for (let i: number = 0; i < DATASET_IDS.length; i++) {
            if (!WebDavSyncService.datasetEnabled(config.selection, DATASET_IDS[i])) {
                continue
            }
            if (manifest !== null && WebDavSyncService.findManifestDataset(manifest, DATASET_IDS[i]) !== null) {
                continue
            }
            await WebDavSyncService.makeCollection(
                rootUrl + 'datasets/' + DATASET_IDS[i] + '/',
                config,
                'dataset:' + DATASET_IDS[i],
            )
        }
    }

    private static async makeCollection(
        url: string,
        config: WebDavSyncConfig,
        collection: string,
    ): Promise<void> {
        const startedAt: number = Date.now()
        DiagnosticLogger.info('sync', 'webdav_mkcol_start', `collection=${collection}`)
        const resp: AxiosTextResponse = await AxiosHttpClient.requestText(
            url,
            'MKCOL',
            WebDavSyncService.headers(config),
            '',
            CONNECT_TIMEOUT_MS,
            READ_TIMEOUT_MS,
        )
        const code: number = resp.statusCode
        DiagnosticLogger.info(
            'sync',
            'webdav_mkcol_done',
            `collection=${collection},status=${code},durationMs=${Date.now() - startedAt}`,
        )
        if (code === 405 || code === 409 || code === 301 || code === 302) {
            return
        }
        if (code < 200 || code >= 300) {
            throw new Error(`WebDAV MKCOL failed: HTTP ${code}`)
        }
    }

    private static async readDatasetEnvelope(
        rootUrl: string,
        manifest: SyncManifestV1,
        datasetId: string,
        config: WebDavSyncConfig,
        localShards: WebDavBuiltShard[],
    ): Promise<SyncEnvelopeV1> {
        let out: SyncEnvelopeV1 = new SyncEnvelopeV1()
        const entry: SyncManifestDataset | null = WebDavSyncService.findManifestDataset(manifest, datasetId)
        if (entry === null) {
            return out
        }
        for (let i: number = 0; i < entry.shards.length; i++) {
            const shard: SyncManifestShard = entry.shards[i]
            if (WebDavSyncService.localShardMatchesManifest(localShards, shard)) {
                DiagnosticLogger.info(
                    'sync',
                    'webdav_shard_download_skipped',
                    `dataset=${datasetId},shard=${shard.id}`,
                )
                continue
            }
            DiagnosticLogger.info(
                'sync',
                'webdav_shard_download_required',
                `dataset=${datasetId},shard=${shard.id},reason=${
                    WebDavSyncService.localShardMismatchReason(localShards, shard)
                }`,
            )
            const raw: string = await WebDavSyncService.readRemoteOptional(rootUrl + shard.path, config)
            if (raw.length === 0) {
                continue
            }
            out = SyncLocalDataAdapter.mergeEnvelopes(out, SyncService.parseRaw(raw))
        }
        return WebDavSyncService.selectDataset(out, datasetId)
    }

    private static localShardMatchesManifest(
        localShards: WebDavBuiltShard[],
        remote: SyncManifestShard,
    ): boolean {
        if (remote.sha256.length === 0) {
            return false
        }
        for (let i: number = 0; i < localShards.length; i++) {
            const local: WebDavBuiltShard = localShards[i]
            if (local.id === remote.id) {
                return local.path === remote.path &&
                    local.sha256 === remote.sha256 &&
                    local.recordCount === remote.recordCount &&
                    local.updatedAt === remote.updatedAt
            }
        }
        return false
    }

    private static localShardMismatchReason(
        localShards: WebDavBuiltShard[],
        remote: SyncManifestShard,
    ): string {
        if (remote.sha256.length === 0) {
            return 'remote_hash_missing'
        }
        for (let i: number = 0; i < localShards.length; i++) {
            const local: WebDavBuiltShard = localShards[i]
            if (local.id !== remote.id) {
                continue
            }
            const reasons: string[] = []
            if (local.path !== remote.path) reasons.push('path')
            if (local.sha256 !== remote.sha256) reasons.push('hash')
            if (local.recordCount !== remote.recordCount) reasons.push('count')
            if (local.updatedAt !== remote.updatedAt) reasons.push('updated_at')
            return reasons.join('+')
        }
        return 'local_shard_missing'
    }

    private static async writeChangedShards(
        rootUrl: string,
        config: WebDavSyncConfig,
        prev: SyncManifestDataset | null,
        shards: WebDavBuiltShard[],
    ): Promise<boolean> {
        let changed: boolean = false
        for (let i: number = 0; i < shards.length; i++) {
            const shard: WebDavBuiltShard = shards[i]
            if (prev !== null && WebDavSyncService.previousShardHash(prev, shard.id) === shard.sha256) {
                continue
            }
            await WebDavSyncService.writeRemote(rootUrl + shard.path, config, shard.raw)
            changed = true
        }
        return changed
    }

    private static manifestDatasetChanged(prev: SyncManifestDataset | null, shards: WebDavBuiltShard[]): boolean {
        if (prev === null) {
            return shards.length > 0
        }
        if (prev.shards.length !== shards.length) {
            return true
        }
        for (let i: number = 0; i < shards.length; i++) {
            const shard: WebDavBuiltShard = shards[i]
            const old: SyncManifestShard | null = WebDavSyncService.previousShard(prev, shard.id)
            if (old === null ||
                old.path !== shard.path ||
                old.sha256 !== shard.sha256 ||
                old.recordCount !== shard.recordCount ||
                old.updatedAt !== shard.updatedAt) {
                return true
            }
        }
        return false
    }

    private static async buildShards(envelope: SyncEnvelopeV1, datasetId: string): Promise<WebDavBuiltShard[]> {
        const rawEnvelope: string = JSON.stringify(WebDavSyncService.selectDataset(envelope, datasetId))
        let rawShards: string = ''
        try {
            rawShards = await taskpool.execute<[string, string], string>(buildWebDavShardsTask, rawEnvelope, datasetId)
        } catch (_error) {
            rawShards = buildWebDavShardsTask(rawEnvelope, datasetId)
        }
        const parsed: WebDavBuiltShard[] = JSON.parse(rawShards) as WebDavBuiltShard[]
        const out: WebDavBuiltShard[] = []
        for (let i: number = 0; i < parsed.length; i++) {
            const raw: WebDavBuiltShard = parsed[i]
            const shard: WebDavBuiltShard = new WebDavBuiltShard()
            shard.id = raw.id
            shard.path = raw.path
            shard.raw = raw.raw
            shard.sha256 = raw.sha256
            shard.recordCount = raw.recordCount
            shard.updatedAt = raw.updatedAt
            out.push(shard)
        }
        return out
    }

    private static selectDataset(envelope: SyncEnvelopeV1, datasetId: string): SyncEnvelopeV1 {
        const out: SyncEnvelopeV1 = new SyncEnvelopeV1()
        if (datasetId === DATASET_READ_PROGRESS) {
            out.datasets.readProgress = envelope.datasets.readProgress
        } else if (datasetId === DATASET_VIEWED_HISTORY) {
            out.datasets.viewedHistory = envelope.datasets.viewedHistory
        } else if (datasetId === DATASET_SEARCH_HISTORY) {
            out.datasets.searchHistory = envelope.datasets.searchHistory
        } else if (datasetId === DATASET_QUICK_SEARCHES) {
            out.datasets.quickSearches = envelope.datasets.quickSearches
        } else if (datasetId === DATASET_HOME_SUBTABS) {
            out.datasets.homeSubtabs = envelope.datasets.homeSubtabs
        } else if (datasetId === DATASET_LOCAL_USER_TAGS) {
            out.datasets.localUserTags = envelope.datasets.localUserTags
            out.datasets.localUserTagSettings = envelope.datasets.localUserTagSettings
        } else if (datasetId === DATASET_LOCAL_BLOCK) {
            out.datasets.localBlockSettings = envelope.datasets.localBlockSettings
            out.datasets.localBlockRules = envelope.datasets.localBlockRules
        } else if (datasetId === DATASET_SETTINGS_TABLES) {
            out.datasets.settingsTables = envelope.datasets.settingsTables
        }
        return out
    }

    private static datasetRecordCount(envelope: SyncEnvelopeV1, datasetId: string): number {
        if (datasetId === DATASET_READ_PROGRESS) {
            return envelope.datasets.readProgress.length
        }
        if (datasetId === DATASET_VIEWED_HISTORY) {
            return envelope.datasets.viewedHistory.length
        }
        if (datasetId === DATASET_SEARCH_HISTORY) {
            return envelope.datasets.searchHistory.length
        }
        if (datasetId === DATASET_QUICK_SEARCHES) {
            return envelope.datasets.quickSearches.length
        }
        if (datasetId === DATASET_HOME_SUBTABS) {
            return envelope.datasets.homeSubtabs.length
        }
        if (datasetId === DATASET_LOCAL_USER_TAGS) {
            return envelope.datasets.localUserTags.length + envelope.datasets.localUserTagSettings.length
        }
        if (datasetId === DATASET_LOCAL_BLOCK) {
            return envelope.datasets.localBlockSettings.length + envelope.datasets.localBlockRules.length
        }
        if (datasetId === DATASET_SETTINGS_TABLES) {
            return envelope.datasets.settingsTables.length
        }
        return 0
    }

    private static datasetUpdatedAt(envelope: SyncEnvelopeV1, datasetId: string): number {
        let out: number = 0
        if (datasetId === DATASET_READ_PROGRESS) {
            for (let i: number = 0; i < envelope.datasets.readProgress.length; i++) {
                out = Math.max(out, envelope.datasets.readProgress[i].updatedAt, envelope.datasets.readProgress[i].deletedAt)
            }
        } else if (datasetId === DATASET_VIEWED_HISTORY) {
            for (let i: number = 0; i < envelope.datasets.viewedHistory.length; i++) {
                out = Math.max(out, envelope.datasets.viewedHistory[i].viewedAt, envelope.datasets.viewedHistory[i].deletedAt)
            }
        } else if (datasetId === DATASET_SEARCH_HISTORY) {
            for (let i: number = 0; i < envelope.datasets.searchHistory.length; i++) {
                out = Math.max(out, envelope.datasets.searchHistory[i].updatedAt, envelope.datasets.searchHistory[i].deletedAt)
            }
        } else if (datasetId === DATASET_QUICK_SEARCHES) {
            for (let i: number = 0; i < envelope.datasets.quickSearches.length; i++) {
                out = Math.max(out, envelope.datasets.quickSearches[i].pinnedAt, envelope.datasets.quickSearches[i].updatedAt, envelope.datasets.quickSearches[i].deletedAt)
            }
        } else if (datasetId === DATASET_HOME_SUBTABS) {
            for (let i: number = 0; i < envelope.datasets.homeSubtabs.length; i++) {
                out = Math.max(out, envelope.datasets.homeSubtabs[i].updatedAt, envelope.datasets.homeSubtabs[i].deletedAt)
            }
        } else if (datasetId === DATASET_LOCAL_USER_TAGS) {
            for (let i: number = 0; i < envelope.datasets.localUserTags.length; i++) {
                out = Math.max(out, envelope.datasets.localUserTags[i].updatedAt, envelope.datasets.localUserTags[i].deletedAt)
            }
            for (let i: number = 0; i < envelope.datasets.localUserTagSettings.length; i++) {
                out = Math.max(out, envelope.datasets.localUserTagSettings[i].updatedAt, envelope.datasets.localUserTagSettings[i].deletedAt)
            }
        } else if (datasetId === DATASET_LOCAL_BLOCK) {
            for (let i: number = 0; i < envelope.datasets.localBlockSettings.length; i++) {
                out = Math.max(out, envelope.datasets.localBlockSettings[i].updatedAt, envelope.datasets.localBlockSettings[i].deletedAt)
            }
            for (let i: number = 0; i < envelope.datasets.localBlockRules.length; i++) {
                out = Math.max(out, envelope.datasets.localBlockRules[i].updatedAt, envelope.datasets.localBlockRules[i].deletedAt)
            }
        } else if (datasetId === DATASET_SETTINGS_TABLES) {
            for (let i: number = 0; i < envelope.datasets.settingsTables.length; i++) {
                out = Math.max(out, envelope.datasets.settingsTables[i].updatedAt, envelope.datasets.settingsTables[i].deletedAt)
            }
        }
        return out
    }

    private static stableGeneratedAt(envelope: SyncEnvelopeV1, datasetId: string): string {
        const updatedAt: number = WebDavSyncService.datasetUpdatedAt(envelope, datasetId)
        if (updatedAt <= 0) {
            return ''
        }
        return new Date(updatedAt).toISOString()
    }

    private static sortShardEnvelope(envelope: SyncEnvelopeV1, datasetId: string): void {
        if (datasetId === DATASET_READ_PROGRESS) {
            envelope.datasets.readProgress.sort((a: SyncReadProgressRecord, b: SyncReadProgressRecord): number => {
                return WebDavSyncService.compareKey(a.scopeKey + ':' + a.galleryId, b.scopeKey + ':' + b.galleryId)
            })
        } else if (datasetId === DATASET_VIEWED_HISTORY) {
            envelope.datasets.viewedHistory.sort((a: SyncViewedHistoryRecord, b: SyncViewedHistoryRecord): number => {
                return WebDavSyncService.compareKey(a.scopeKey + ':' + a.galleryId, b.scopeKey + ':' + b.galleryId)
            })
        } else if (datasetId === DATASET_SEARCH_HISTORY) {
            envelope.datasets.searchHistory.sort((a: SyncSearchHistoryRecord, b: SyncSearchHistoryRecord): number => {
                return WebDavSyncService.compareKey(a.scopeKey + ':' + a.queryText, b.scopeKey + ':' + b.queryText)
            })
        } else if (datasetId === DATASET_QUICK_SEARCHES) {
            envelope.datasets.quickSearches.sort((a: SyncQuickSearchRecord, b: SyncQuickSearchRecord): number => {
                return WebDavSyncService.compareKey(a.scopeKey + ':' + a.queryText, b.scopeKey + ':' + b.queryText)
            })
        } else if (datasetId === DATASET_HOME_SUBTABS) {
            envelope.datasets.homeSubtabs.sort((a: SyncHomeSubtabRecord, b: SyncHomeSubtabRecord): number => {
                return WebDavSyncService.compareKey(a.scopeKey + ':' + a.profileUuid, b.scopeKey + ':' + b.profileUuid)
            })
        } else if (datasetId === DATASET_LOCAL_USER_TAGS) {
            envelope.datasets.localUserTags.sort((a: SyncLocalUserTagRecord, b: SyncLocalUserTagRecord): number => {
                return WebDavSyncService.compareKey(a.scopeKey + ':' + a.tagId, b.scopeKey + ':' + b.tagId)
            })
            envelope.datasets.localUserTagSettings.sort((a: SyncLocalUserTagSettingsRecord, b: SyncLocalUserTagSettingsRecord): number => {
                return WebDavSyncService.compareKey(a.scopeKey, b.scopeKey)
            })
        } else if (datasetId === DATASET_LOCAL_BLOCK) {
            envelope.datasets.localBlockSettings.sort((a: SyncLocalBlockSettingsRecord, b: SyncLocalBlockSettingsRecord): number => {
                return WebDavSyncService.compareKey(a.scopeKey, b.scopeKey)
            })
            envelope.datasets.localBlockRules.sort((a: SyncLocalBlockRuleRecord, b: SyncLocalBlockRuleRecord): number => {
                return WebDavSyncService.compareKey(a.scopeKey + ':' + a.ruleId, b.scopeKey + ':' + b.ruleId)
            })
        } else if (datasetId === DATASET_SETTINGS_TABLES) {
            envelope.datasets.settingsTables.sort((a: SyncSettingsTableRecord, b: SyncSettingsTableRecord): number => {
                return WebDavSyncService.compareKey(a.scopeKey + ':' + a.tableName + ':' + a.key, b.scopeKey + ':' + b.tableName + ':' + b.key)
            })
        }
    }

    private static compareKey(a: string, b: string): number {
        if (a < b) {
            return -1
        }
        if (a > b) {
            return 1
        }
        return 0
    }

    private static replaceManifestDataset(
        manifest: SyncManifestV1,
        datasetId: string,
        shards: WebDavBuiltShard[],
    ): void {
        const next: SyncManifestDataset = new SyncManifestDataset()
        next.id = datasetId
        for (let i: number = 0; i < shards.length; i++) {
            const s: WebDavBuiltShard = shards[i]
            const m: SyncManifestShard = new SyncManifestShard()
            m.id = s.id
            m.path = s.path
            m.sha256 = s.sha256
            m.recordCount = s.recordCount
            m.updatedAt = s.updatedAt
            next.shards.push(m)
        }
        for (let i: number = 0; i < manifest.datasets.length; i++) {
            if (manifest.datasets[i].id === datasetId) {
                manifest.datasets[i] = next
                return
            }
        }
        manifest.datasets.push(next)
    }

    private static previousShardHash(dataset: SyncManifestDataset, shardId: string): string {
        const shard: SyncManifestShard | null = WebDavSyncService.previousShard(dataset, shardId)
        return shard === null ? '' : shard.sha256
    }

    private static previousShard(dataset: SyncManifestDataset, shardId: string): SyncManifestShard | null {
        for (let i: number = 0; i < dataset.shards.length; i++) {
            if (dataset.shards[i].id === shardId) {
                return dataset.shards[i]
            }
        }
        return null
    }

    private static findManifestDataset(manifest: SyncManifestV1, datasetId: string): SyncManifestDataset | null {
        for (let i: number = 0; i < manifest.datasets.length; i++) {
            if (manifest.datasets[i].id === datasetId) {
                return manifest.datasets[i]
            }
        }
        return null
    }

    private static parseManifest(raw: string): SyncManifestV1 {
        if (raw.trim().length === 0) {
            const empty: SyncManifestV1 = new SyncManifestV1()
            empty.generatedAt = new Date().toISOString()
            return empty
        }
        const parsed: SyncManifestV1 = JSON.parse(raw) as SyncManifestV1
        if (parsed.magic !== SYNC_MAGIC || parsed.appId !== SYNC_APP_ID) {
            throw new Error('Invalid NextN sync manifest')
        }
        if (parsed.schemaVersion !== SYNC_SCHEMA_VERSION ||
            parsed.minSupportedSchemaVersion > SYNC_SCHEMA_VERSION) {
            throw new Error('Unsupported NextN sync manifest schema')
        }
        if (!Array.isArray(parsed.datasets)) {
            parsed.datasets = []
        }
        for (let i: number = 0; i < parsed.datasets.length; i++) {
            if (!Array.isArray(parsed.datasets[i].shards)) {
                parsed.datasets[i].shards = []
            }
        }
        return parsed
    }

    private static selectionForDataset(datasetId: string): SyncDatasetSelection {
        const out: SyncDatasetSelection = new SyncDatasetSelection()
        out.readProgress = datasetId === DATASET_READ_PROGRESS
        out.viewedHistory = datasetId === DATASET_VIEWED_HISTORY
        out.searchHistory = datasetId === DATASET_SEARCH_HISTORY
        out.quickSearches = datasetId === DATASET_QUICK_SEARCHES
        out.homeSubtabs = datasetId === DATASET_HOME_SUBTABS
        out.localUserTags = datasetId === DATASET_LOCAL_USER_TAGS
        out.localBlock = datasetId === DATASET_LOCAL_BLOCK
        out.settingsTables = datasetId === DATASET_SETTINGS_TABLES
        return out
    }

    private static datasetEnabled(selection: SyncDatasetSelection, datasetId: string): boolean {
        if (datasetId === DATASET_READ_PROGRESS) {
            return selection.readProgress
        }
        if (datasetId === DATASET_VIEWED_HISTORY) {
            return selection.viewedHistory
        }
        if (datasetId === DATASET_SEARCH_HISTORY) {
            return selection.searchHistory
        }
        if (datasetId === DATASET_QUICK_SEARCHES) {
            return selection.quickSearches
        }
        if (datasetId === DATASET_HOME_SUBTABS) {
            return selection.homeSubtabs
        }
        if (datasetId === DATASET_LOCAL_USER_TAGS) {
            return selection.localUserTags
        }
        if (datasetId === DATASET_LOCAL_BLOCK) {
            return selection.localBlock
        }
        if (datasetId === DATASET_SETTINGS_TABLES) {
            return selection.settingsTables
        }
        return false
    }

    private static syncRootUrl(directoryUrl: string): string {
        const base: string = WebDavSyncService.baseDirectoryUrl(directoryUrl)
        return base + SYNC_WEBDAV_ROOT_DIR + '/'
    }

    private static syncRunKey(config: WebDavSyncConfig): string {
        return config.username.trim() + '\n' + WebDavSyncService.syncRootUrl(config.directoryUrl)
    }

    private static legacyFileUrl(directoryUrl: string): string {
        return WebDavSyncService.baseDirectoryUrl(directoryUrl) + SYNC_FILE_NAME
    }

    private static baseDirectoryUrl(directoryUrl: string): string {
        const trimmed: string = directoryUrl.trim()
        if (trimmed.endsWith('/')) {
            return trimmed
        }
        return trimmed + '/'
    }

    private static shardId(key: string): string {
        let hash: number = 2166136261
        for (let i: number = 0; i < key.length; i++) {
            hash ^= key.charCodeAt(i)
            hash = Math.imul(hash, 16777619) >>> 0
        }
        return (hash % SHARD_COUNT).toString(16).padStart(2, '0')
    }

    private static headers(config: WebDavSyncConfig): Record<string, string> {
        const header: Record<string, string> = { 'Accept': 'application/json, text/plain, */*' }
        if (config.username.length > 0 || config.password.length > 0) {
            const bytes: Uint8Array = new util.TextEncoder().encodeInto(
                config.username + ':' + config.password,
            )
            header['Authorization'] = 'Basic ' + new util.Base64Helper().encodeToStringSync(bytes)
        }
        return header
    }
}
