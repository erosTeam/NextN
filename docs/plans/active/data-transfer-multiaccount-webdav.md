# NextN 数据导入导出 / 多账号 / WebDAV 同步 架构设计

> 状态：OPEN（实施中）
> 依据：两个只读子代理审计报告（audit_nextn_state、audit_nexte_reference）+ 主代理对
> NextE 备份链源码的逐文件核对。本文件是后续实施的权威映射，不是实现完成声明。

## 1. 结论与范围

- NextN 当前：数据导入导出未做、多账号未做、WebDAV 同步未做（文件证据见审计报告）。
- NextE 当前：备份/导入导出、WebDAV 同步、多账号均为完整实现，可整体复刻。
- 本任务范围（用户明确）：数据导入导出、多账号、WebDAV 数据同步。同步先做 WebDAV。
- 实施规则（用户明确）：完整移植，不自以为精简；任何删减必须先经多子代理审计验证并交用户决策。
- 本文档中的“NH 边界替换 / 身份替换”均不是功能删减：它们替换的是数据源叶子或应用身份，
  架构、契约、状态机、UI 结构保持不变。

## 2. NextE 参考架构映射（组件级）

### 2.1 备份/导入导出（shared/src/main/ets/backup/）

| NextE 组件 | 职责 | NextN 落点 |
| --- | --- | --- |
| BackupTypes.ets | 信封/加密容器/预览/结果契约 | shared/src/main/ets/backup/BackupTypes.ets |
| BackupCrypto.ets | AES-256-GCM + PBKDF2-SHA256（210000 迭代） | 同路径原样 |
| BackupChecksum.ets | 键排序规范 JSON + SHA-256 | 同路径原样 |
| BackupSecretDenylist.ets | 敏感键脱敏名单 | 同路径，键族改为 NextN 存储键 |
| BackupPreferencesAdapter.ets | Preferences 全量转储/恢复/回滚/重吸水 | 同路径，覆盖 NextN 全部 store |
| BackupLocalDataAdapter.ets | RDB 用户数据导出/拓扑校验/替换恢复 | 同路径，数据集映射见 §3 |
| BackupService.ets | 编排/预览/恢复事务 | 同路径 |
| BackupFilePickerCoordinator.ets | picker 保存/选择桥 | feature/settings/src/main/ets/model/ |
| CacheSettingsPage 内联 UI | 导出/导入/密码/确认 | feature/settings 存储页对应位置 |

### 2.2 WebDAV 同步（shared/src/main/ets/sync/）

| NextE 组件 | 职责 | NextN 落点 |
| --- | --- | --- |
| SyncTypes.ets | SYNC_MAGIC / manifest / envelope / 数据集开关 | 同路径 |
| WebDavSyncService.ets | 64 分片、FNV-1a、manifest、ETag 守卫、single-flight | 同路径 |
| SyncLocalDataAdapter.ets | 按主键合并、新时间戳赢、tombstone | 同路径，SQL/记录类型换 NH |
| SyncService.ets | 传输中立导出/合并/导入 | 同路径 |
| WebDavManifestWriteGuard.ets | If-Match / If-None-Match 冲突重试 | 同路径 |
| WebDavSyncScheduler.ets / SyncScheduler.ets | 15s/3s/45s/60→300s 调度与防抖 | 同路径 |
| SyncSettings / SyncSettingsState | 设置与运行状态 | 同路径 |
| CloudSyncFeatures.ets | 数据集表映射 | 同路径，只保留 WebDAV 数据集 |
| SyncSettingsPage / WebDavSyncSettingsPage | UI | feature/settings 对应页面 |

### 2.3 多账号

| NextE 组件 | 职责 | NextN 落点 |
| --- | --- | --- |
| AccountListSettings.ets | 账号列表/活动账号持久化 | 新增 settings/AccountListSettings.ets |
| CookieJarSettings.ets | cookie jar 保存/切换/登出 | 替换为 NhAccountSessionService 的多会话扩展 |
| AuthState / AccountListState | 反应式账号状态 | state/ 新增对应状态 |
| UserProfileService.ets | 每账号资料快照 | NhAccountProfileService 扩展 |
| AccountPage / AccountLoginPage / AccountCookiePage | 账号管理 UI | feature/settings + feature/user 对应页 |
| EhLoginWebPage / EhPasswordLoginPage | 登录页 | NH 使用现有 BrowserSessionPage（leaf） |

## 3. NH 数据集清单（Backup / Sync / Account 共用）

### 3.1 RDB（NextN.db，SCHEMA_VERSION 20）

| 表 | 归属 | Backup | WebDAV Sync | 账号作用域 |
| --- | --- | --- | --- | --- |
| reading_history | 用户数据 | localData.readProgress + viewedHistory | 分片同步 | 待定（见 §6） |
| search_history | 用户数据 | localData.searchHistory | 分片同步 | 无 |
| search_quick | 用户数据 | localData.quickSearches | 分片同步 | 无 |
| content_filter_rules | 用户数据 | localData.localBlock（NH 映射） | 分片同步 | 无 |
| reader_settings / download_settings / browse_presentation_settings / catalog_preferences | 用户设置 | localData.settingsTables | 分片同步 | 无 |
| account_session / account_profile / account_session_verification | 凭据/资料 | secrets（加密-only，HUKS 重封装后） | 排除 | 每账号独立 |
| tag_translations / tag_translation_meta / nh_tag_catalog | 字典/缓存 | 排除 | 排除 | 无 |
| nh_gallery_detail_cache / nh_gallery_list_cache / comic_translation_document_cache / comment_translation_cache | 缓存 | 排除 | 排除 | 无 |
| download_queue / download_settings | 队列 | 排除（与 NextE 一致） | 排除 | 无 |

### 3.2 Preferences（6 个 store）

| Store | Backup | 说明 |
| --- | --- | --- |
| nextn_layout | plaintext | 布局/外观类设置 |
| nextn_appearance | plaintext | 主题/语言 |
| nextn_settings | plaintext | 翻译等设置 |
| nextn_llm_sources | plaintext | LLM 来源档案（非密钥） |
| nextn_llm_secrets | secrets（加密-only） | HUKS 密文；跨设备恢复需重封装（Phase 1.5） |
| nextn_manga_rendering_service | plaintext | 渲染服务设置 |

Preferences 键在备份中以 `<store>.<key>` 前缀避免跨 store 冲突；恢复按前缀回写对应 store。

## 4. 格式与应用身份（有意的叶子替换，不是精简）

- BACKUP_MAGIC = 'NEXTN_BACKUP'、BACKUP_APP_ID = 'com.erosteam.nextn'
- BACKUP_FILE_SUFFIX = '.nextn-backup.json'
- SYNC_ROOT_DIR = 'nextn-sync-v1'、SYNC_FILE_NAME = 'nextn-sync-v1.json'
- 加密/校验/分片/合并参数与 NextE 完全一致（AES-256-GCM、PBKDF2 210000、SHA-256、
  SHARD_COUNT=64、FNV-1a、ETag 守卫、3 次冲突重试）。
- 原因：NextN 与 NextE 是不同应用，备份/同步文件必须可区分、不可互写；这是应用身份叶子，
  不改变任何协议/架构语义。

## 5. 敏感数据处理

- 明文备份：只含非敏感设置与本地用户数据；WebDAV 凭据组整组、账号会话、LLM 密钥一律排除。
- 加密备份：secrets 段仅存在于 AES-GCM 密码容器内；恢复时 WebDAV 四键整组原子恢复。
- 账号会话与 LLM 密钥在 NextN 中由 HUKS 加密；跨设备恢复必须“解密 → 进入备份密文 →
  目标设备重新封装”。此步骤在 Phase 1.5 实现，是最终能力的组成部分，不是删减。

## 6. 多账号模型（NH 叶子替换）

- NextE 语义：单激活 cookie jar + 已保存 cookie bundle 列表；每账号 scope_key（RDB 列）与
  auth.profile.<memberId> 做数据作用域。
- NextN 等价：单激活 NH 会话（HUKS v3 信封包含完整认证 Cookie 属性快照、
  cookieHeader 与 browserUserAgent；v2 只读兼容但不得用于账号切换）+
  已保存会话列表；每账号独立 session/profile/收藏缓存；活动账号切换时重载会话与收藏门控。
- reading_history 是否按账号作用域：先保持设备级（不加 scope 列），文档标记为 OPEN；
  多账号落地时若 NextE 明确按账号隔离历史，则加 scope_key 列并迁移。

## 7. WebDAV 同步协议（保持 NextE 原样）

- 根目录 nextn-sync-v1/：manifest.json + datasets/<dataset>/<00..3f>.json
- manifest 只含元数据（sha256/recordCount/updatedAt），manifestChanged 仅在分片变化时置位
- 分片按数据集主键稳定哈希到 64 桶；stableGeneratedAt 取桶内最新记录时间，避免无谓上传
- 合并：按主键、max(updatedAt, deletedAt) 赢；浏览历史特例与 tombstone 规则随 SyncLocalDataAdapter 原样迁移
- 传输：OPTIONS 探测 → GET manifest → 增量 GET 分片 → 合并应用 → PUT 变化分片 → ETag 守卫写 manifest
- 调度：自动 15s/3s/45s 防抖与 60s→300s 退避；suspendAutomaticSync 在备份恢复事务中调用

## 8. 实施阶段

1. Phase 1 备份纯链 + 适配器：BackupTypes/Crypto/Checksum/SecretDenylist/PreferencesAdapter/
   LocalDataAdapter/Service + 仓库 export/restore 方法 + shared 导出 + 构建。
2. Phase 1.5 敏感数据跨设备：账号会话与 LLM 密钥的解密→备份→重封装（HUKS 边界）。
3. Phase 2 WebDAV 同步：sync 全链 + SyncScheduler + 恢复事务挂接 + UI。
4. Phase 3 多账号：账号列表/切换/作用域 + UI + 路由。
5. Phase 4 UI 汇总：设置入口/字符串/路由/UI 变更台账（docs/qa/nextn-ui-change-ledger.md）。
6. Phase 5 验证：构建、设备验收（含冷启动恢复、跨设备备份恢复、双向同步冲突）。

## 9. 非精简声明

本设计未删减任何 NextE 能力。差异全部属于：
- 应用身份（magic/appId/文件后缀/同步根目录）；
- NH 数据源叶子（表结构、凭据形态、无本地收藏/图像屏蔽/自定义列表对应的表）；
- 用户明确的范围（先做 WebDAV，华为云 provider 不在本期；备份恢复事务中的同步挂起在
  Phase 2 随 SyncScheduler 一并恢复）。

以上每一项都在本文件记录理由。若实施中需要任何架构/功能删减，必须先经多子代理审计验证，
再交用户决策；本文件会在决策后更新。
