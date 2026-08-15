# NextN 开发规范（必读参考）

本文档是 NextN 仓库的强制参考规范。任何新增页面、共享组件、状态、
缓存或 UI 改动之前必须先读本文档，并保证本文档与实现同步更新。

## 1. 仓库结构与依赖方向

```text
entry（shell：HdsNavigation / HdsTabs / NavPathStack / 全部路由）
  -> feature/home, feature/search, feature/gallery, feature/reader,
     feature/user, feature/download, feature/settings
  -> shared（组件、状态、存储、服务、网络、模型、主题 token）
```

规则：

1. `shared` 不得依赖任何 feature；feature 之间不得互相 import，
   跨功能协调只允许通过 `entry` 的路由/意图回调。
2. 新增能力先判断归属：页面在 `feature/*/pages`，可复用 UI 在
   `shared/components`，跨页面状态在 `shared/state`，持久化在
   `shared/storage`，业务服务在 `shared/services`，网络在
   `shared/network`，DTO 在 `shared/model`。
3. feature 只暴露 `Index.ets` barrel；entry 只消费 barrel。

## 2. 共享组件清单与使用边界

新增 UI 前必须先查 `shared/src/main/ets/Index.ets` 的导出清单。已有
共享组件能满足需求时禁止页面手写等价结构或重新复制样式。

### 2.1 画廊列表 / 卡片族

| 组件 | 布局模式 | 标签 | 说明与边界 |
| --- | --- | --- | --- |
| `GalleryCollectionBody` | 所有 | 由卡片决定 | 画廊集合的统一父树：刷新、分页 footer、密度分支、安全区。调用方只传数据、请求代际与回调。当前调用方：Home、Popular、Search、Favorites |
| `GalleryListItem` | `SIMPLE_LIST` | 无 | NextE 紧凑简单行（72×102），元数据行不承载标签 |
| `GalleryMediumCard` | `LIST` | 有（`GalleryTagStrip`） | 中等列表卡，固定/自适应封面高度 |
| `GalleryGridCard` | `COVER_GRID` | 无 | 封面网格卡：语言角标 + 页数覆盖 + 标题 + 上传日期/收藏数（页数只出现在封面右下角，meta 行不重复）。富标签属于瀑布流，不属于网格 |
| `GalleryWaterfallCard` | `WATERFALL` | 有 | 常规瀑布流卡 |
| `GalleryWaterfallCompactCard` | `WATERFALL_COMPACT` | 有 | 紧凑瀑布流卡 |
| `GalleryCoverWallCard` | `COVER_WALL` | 无 | 封面优先的瀑布墙 |
| `GalleryTagStrip` | LIST/瀑布 | — | 标签条组件。`displayName` 为空时回退 `name`；受 `showGalleryTags` 与 `showTranslatedTagLabels` 控制 |
| `GalleryLanguageCornerBadge` | 网格/瀑布 | — | 由 `tagIds` 推导语言角标，不发请求 |

重要事实（2026-08-16 真机 + RDB 验证）：

- 全局浏览布局默认值已改为 `waterfall`（只影响全新/未知持久化值，
  已安装用户的保存值不会被迁移）。收藏页标题栏现在有「列表视图」
  快捷菜单（搜索/列表视图两个动作），选择任意模式即写入全局
  `BrowsePresentationState.mode`，收藏/搜索/历史随之切换。
- 网格卡下方不再显示 `#id`，也不重复封面右下角的页数；优先显示
  列表 JSON 提供的上传日期（`upload_date`），否则显示收藏数
  （`num_favorites`，心形 + 数字）。收藏缓存中 25/25 条画廊都带完整
  `tags` 与 `tagIds`；收藏页显示网格时无标签是设计（同 NextE
  `GalleryGridCard`），不是标签数据丢失。

### 2.1.1 列表顶部间距契约（单点所有者）

- 所有画廊集合页的列表顶部间距只由 `GalleryCollectionBody` 计算：
  `effectiveTopPadding() = 调用方 topPadding + ThemeTokens.GALLERY_LIST_TOP_GAP`。
- 调用方的 `topPadding` 只允许表示本页固定的头部占用（来源选择条、
  搜索框）；不得在页面里写列表顶部魔法值。
- 需要新增画廊集合页时，只传 `topPadding`（无固定头部则传 0），
  共享的 12vp 顶距自动生效，禁止复制样式或手调。

### 2.2 列表 / 设置组语法

| 组件 | 用途 |
| --- | --- |
| `NextNSectionHeader` | 设置组标题，统一左对齐 |
| `NextNGroupedListSection` | 分组卡片容器（圆角、裁剪、内边距） |
| `NextNListRow` | HDS 单行（标题/副标题/后缀/开关/箭头），禁止再包一层 Material 风格图标卡 |
| `NextNModalScaffold` | 半模态/弹层脚手架，标题 + 滚动区 + 关闭 |
| `appSheetOptions` / `appMenuOptions` | `bindSheet` / `bindMenu` 的统一包装；不要页面内自造菜单/弹层锚点 |
| `NextNHdsCapsuleBarButton` / `NextNHdsTitleBar` | HDS 标题栏按钮/标题栏封装 |
| `AppSearchField` / `AppColorPicker` | 搜索输入 / 颜色选择器 |

### 2.3 页面骨架与刷新

| 组件 | 用途 |
| --- | --- |
| `PullRefreshListScaffold` / `PullRefreshGridScaffold` / `PullRefreshWaterFlowScaffold` | 根/停留页面统一滚动 + 下拉刷新 + 分页尾巴 |
| `SecondaryListScaffold` / `SecondaryGridScaffold` / `SecondaryWaterFlowScaffold` | 推入式目的地列表骨架 |
| `RetainedSubtabHost` / `SubTabBar` | 保留式子标签宿主（当前仅 Home 的 最新/热门） |
| `PageLoadingState` / `PageErrorState` / `PageEmptyState` | 三态页面 |
| `LoadingFooter` / `InlineRetryNotice` | 分页 footer / 行内重试 |
| `NhArkWebSessionTransportHost` | 不可见的同源 ArkWeb 宿主，承载鉴权 v2 读取；调用方不能传任意 origin/UA/Cookie |

## 3. 状态与数据链路（唯一所有者）

跨页面状态一律使用 AppStorageV2 连接器（`shared/state`），由单一
`@ObservedV2` 类持有：

- `BrowsePresentationState`：全局浏览布局/标签显示/密度。Home 另有
  `HomeSourceState` 每源覆盖，写入走 `HomeSourcePresentationRepository`。
- `AccountSessionState` / `AccountProfileState`：会话与档案发布。
- `TagTranslationState`：本地词典状态；`NhTagCatalogService` 负责解析
  与重贴标签，页面不得自行维护标签副本。
- `CatalogPreferencesState`、`ContentFilterState`、`DownloadQueueState`、
  `ReadingHistoryState`、`LayoutSafeAreaState` 等按域名各有一个状态类。

### 3.1 标签链路

```text
NhApiClient.parseGalleryPage
  -> parseGallerySummary（只填 tagIds）
  -> NhTagCatalogService.enrich（RDB 目录 + 远程 tagsByIds 批量 + 本地词典）
  -> gallery.tags（name 为规范查询值，displayName 为可选展示值）
  -> GalleryTagStrip / 各卡片渲染（displayName 为空回退 name）
```

缓存恢复的标签**保留** `displayName`，水合必须先用
`NhTagCatalogService.refreshLocalDisplayLabels` 重新贴本地词典再入帧；
词典修订路径会再次贴标签自校正。禁止任何持久缓存清空展示标签后直接上屏。

### 3.2 列表缓存链路

`GalleryListCacheRepository`（`nh_gallery_list_cache`，schema v20）只缓存
首页第一页快照，展示用：

- Home：`loadOnceWithCachedRows()` 先读缓存原位填充，再 `loadFirstPage(keepUsableRows)`。
- Favorites：`applyPublishedAccountSession()` → `loadPublishedAccountPage()`
  → `hydrateCachedFavorites()` 立即用缓存填充 → `loadFirstPage(keepUsableRows)`。
- 有可用快照时不得进入全屏“正在检查账户会话”状态；
  `isResolvingSessionState = !accountSession.initialized`。
- 收藏缓存键 `favorites:v1:default`，登出时 `clearPrefix('favorites:v1:')`。
- 每次成功的第一页响应都会覆盖保存；缓存失败不影响网络结果。

### 3.3 详情/阅读/下载链路

- 详情：`NhGalleryDetailCacheService` 公共 DTO 快照 + 再验证；显式刷新
  绕过两层缓存。
- 阅读：`ReaderImageCacheService` 私有页字节缓存，`*.part` 原子提升。
- 下载：`DownloadQueueRepository` / `DownloadQueueService` 持久队列，
  `context.filesDir` 私有文件。

## 4. 强制规则

1. 新增 UI 前先查 `shared/Index.ets`；已有组件可用就复用，禁止新造。
2. 同一关系出现在多处时，只保留一个状态/服务所有者，所有视图派生。
3. 页面不得复制共享组件的结构或样式；设置列表、半模态、菜单、标题栏
   必须走第 2 节组件。
4. 显示标签的持久缓存不得清空 `displayName`；任何冷启动/水合路径必须先
   `refreshLocalDisplayLabels` 再入帧，禁止用显示层回调掩盖数据源丢失。
5. 首帧/过渡/图片换源改动必须同态真机对照验收；稳定功能退化必须登记
   `docs/qa/nextn-incident-register.md` 后再修链路。
4. 做“相似组件/相似文案”修改时，用 `rg` 按共享组件名扫描全部调用处，
   一次覆盖所有页面，禁止只修单点后宣称完成。
5. 标签相关文案：`displayName` 是可选展示值，`name` 是规范查询值；
   界面文案使用中性中文，不得生造“译名”“翻译数据库”等术语。
6. 可见 UI 改动前先在 `docs/qa/nextn-ui-change-ledger.md` 记录
   用户指令/参考证据、父树边界、改动前后与验证计划；改完必须真机
   同态对比 NextE 参考，构建成功不等于验收。

## 5. 维护约定

- 新增或修改共享组件后，必须同步更新第 2 节清单（用途、边界、调用方）。
- 修改状态/缓存链路后，必须同步更新第 3 节描述。
- 每次“全面检查”先从本文档清单出发，逐项核对调用处，再把结论写回
  本文档或 QA 台账，防止下次重新扫描。
- 本文档与 `docs/architecture.md` 共同构成架构参考；冲突时以
  `docs/controls/nextn-execution-integrity.md` 的行为约束为准。
