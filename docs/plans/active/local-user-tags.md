# NextN 本地用户标签系统开发指南

> 状态：OPEN（调研与产品合同已确定，功能实现尚未开始）
> 目标：在不依赖 NH 上游新增 API 的前提下，提供一套受 EH My Tags
> 启发的本地用户标签系统，并通过现有 WebDAV 在用户设备间同步。
> 本文档是后续设计、实现和验收的权威入口。实现中若要改变本文的
> 用户确认项，必须先取得新的用户决定。

## 1. 用户确认的产品合同

第一版必须同时具备以下能力，不能把其中一项替换成另一项：

- 为单个 NH 标签设置自定义高亮颜色。
- 为单个 NH 标签设置权重。
- 为单个 NH 标签设置显式屏蔽（硬过滤）。
- 设置全局标签过滤阈值，以图库命中标签的**权重总和**执行软过滤。
- 显式屏蔽与权重软过滤并存；权重不是显式屏蔽的另一种写法。
- 全局搜索条件提供“忽略本地标签过滤”开关，用于绕过本地 Hidden 和权重软过滤；
  开关本身与搜索语言、排序同级持久化。
- 自定义 Search Subtab 的编辑条件页面提供同一开关，并按 Subtab 分别持久化。
- 在图库列表的标签展示中，自定义颜色标签排在未设置颜色的标签前面。
- 本地用户标签和阈值通过 WebDAV 跨设备同步。
- 复用 NextE 已有的 My Tags 管理页、编辑 Sheet、颜色选择器和标签着色模式，
  但数据所有者和过滤计算必须是 NextN 本地实现。

以下行为明确不需要：

- 不增加“临时显示本页隐藏项”。
- 不增加“本页结果均被本地标签规则隐藏”之类的特殊空态。
- 不增加 EH 的“本页过滤了多少项”提示。
- 不改变 NH 服务器黑名单现有的刷新、缓存和过滤语义。

“自定义颜色标签优先”只作用于图库**列表卡片**中的标签展示。详情页继续保持
当前 namespace 分组、列表种子顺序和详情独有标签追加顺序；详情标签只接入颜色，
不因为本功能重新排序。

## 2. EH My Tags 参考合同

参考：<https://ehwiki.org/wiki/My_Tags>

EH 的完整标签规则不是一个布尔黑名单：

- 每个 My Tag 有颜色、Watched、Hidden 和权重。
- 权重范围为 `-99..99`，默认值为 `10`。
- Hidden 是硬过滤：图库命中任一 Hidden 标签即被过滤，其他正权重不能抵消。
- 软过滤先求图库命中的全部 My Tags 权重总和，再与 Tag Filtering Threshold
  比较；总和**严格小于**阈值时过滤。
- Tag Filtering Threshold 默认值为 `0`，范围为 `-9999..0`。
- 正权重可以抵消负权重，这是软过滤区别于 Hidden 的核心能力。
- Watched 页面另有 Tag Watching Threshold：总权重达到阈值才进入 Watched
  结果。该能力只有在 NextN 后续决定提供本地关注标签内容源时才进入实现范围。
- EH 的多个已启用 tagset 会合并计算。NextN 第一版没有已确认的本地 tagset
  需求，先使用一个扁平标签集合，不把 tagset 偷渡进第一版。
- EH 在服务器输出图库列表时优先安排用户着色/关注标签。NextN 的规则只存在于
  本地，因此必须在卡片截断标签之前完成本地稳定排序。

### 2.1 NextE/Eros FE 的可复用边界

NextE 的 `EhUsertag`、`MyTagsPage`、`GalleryTagsCard`、`UserTagStore` 和
`AppColorPicker` 可作为 UI、颜色展示和轻量响应信号的参考。

不能直接复用 NextE 当前的过滤实现作为完整业务逻辑：

- NextE/Eros FE 将 weight、Tag Filtering Threshold 和 Tag Watching Threshold
  交给 EH 服务端处理。
- 两个客户端的本地 User Tag 索引主要补充自定义颜色和 Hidden 硬过滤，没有实现
  EH 的图库权重求和。
- NextN 的本地规则不会被 NH 服务端看到，所以必须在本地实现完整求和算法。

## 3. NextN 当前基础与缺口

| 当前所有者 | 当前事实 | 对本功能的意义 |
| --- | --- | --- |
| `shared/src/main/ets/model/NhGallery.ets` | `NhGallerySummary` 同时持有完整 `tagIds` 和已解析的 `tags` | 过滤按 ID 执行，不依赖名称解析；展示按 `NhTag` 执行 |
| `shared/src/main/ets/network/NhApiClient.ets` | 列表解析 `tag_ids`，再批量调用 `/api/v2/tags/ids` 丰富标签 | 不需要为本地过滤增加网络请求 |
| `NhCloudBlacklistService` | NH 账号云端黑名单按相同 tag ID 空间过滤 | 保持独立的上游硬过滤来源 |
| `ContentFilterService.filterGalleries()` | Home、Popular、搜索、收藏、相关图库共用本地过滤入口 | 本地标签硬/软过滤应并入同一结果链 |
| `NhCatalogPreferences` | `searchLanguage`、`searchSort` 由 `catalog_preferences` 持久化，并进入备份/WebDAV `settings-tables` | 全局搜索忽略开关应进入同一所有权链 |
| `SearchPage` | 持有未过滤的 `rawGalleries`、已展示的 `galleries` 和搜索条件 Sheet | 忽略开关变化可在不重新请求网络的情况下重新应用当前结果 |
| `NhHomeSubtabProfile` / `HomeSubtabEditPage` | 自定义 Search Subtab 持有 query、language、sort，并可独立编辑 | Subtab 忽略开关应成为同级 profile 字段和编辑条件 |
| `HomeSearchSubtabPage` | 按 profile 请求、缓存并从 `rawGalleries` 应用过滤 | 按各 Subtab 的忽略开关跳过本地用户标签过滤 |
| `GalleryTagStrip` | 普通列表最多显示 10 个可见标签，按输入顺序先到先得 | 颜色优先排序必须发生在 10 个标签截断之前 |
| `GalleryWaterfallCard` | 最多读取 8 个标签，以索引 `0/2/4/6`、`1/3/5/7` 组成两行 | 先生成统一有序数组，再按现有索引布局显示 |
| `GalleryWaterfallCompactCard` | 最多读取 8 个标签，单行横向显示 | 与普通瀑布流共享同一排序合同 |
| `GalleryDetailPage` | 详情标签按列表种子稳定排序后再按 namespace 分组 | 只着色，不重排 |
| `shared/src/main/ets/sync/` | WebDAV 已有 64 分片、manifest、ETag、LWW 和 tombstone | 新增独立数据集即可复用完整传输链 |
| `shared/src/main/ets/backup/` | 本地数据备份、恢复和运行时 reapply 已存在 | 新表必须进入备份与持久化清单 |

当前缺口是：没有本地用户标签的持久化所有者、运行时索引、权重求和器、颜色优先
排序、管理页面、备份数据段和 WebDAV 数据集。

## 4. 数据所有权

### 4.1 本地标签记录

建议新增 `NhLocalUserTag`（最终命名可按 shared 现有命名统一）：

```text
scopeKey: string             // 第一版固定为 global，结构保留未来作用域能力
tagId: number                // 主身份，必须 > 0
namespaceSnapshot: string    // 仅用于展示/诊断/目录刷新，不参与身份判断
nameSnapshot: string         // 原始 NH 名称快照，不使用翻译名
colorCode: string            // 空串表示默认颜色；否则规范化 #RRGGBB
weight: number               // -99..99，默认 10
hidden: boolean              // 显式硬过滤
updatedAt: number
deletedAt: number
```

约束：

- 唯一键为 `(scope_key, tag_id)`。
- `tagId` 是规则匹配的唯一权威身份。标签翻译、namespace 别名和名称变化不能生成
  第二条规则。
- `namespaceSnapshot`、`nameSnapshot` 可在目录得到更新值时刷新，但不能改变身份。
- weight 对每条有效用户标签记录都存在；不能再设计成 nullable。
- 只设置颜色的标签仍使用默认 weight `10` 并参与图库总权重，与 EH 一致。
- `hidden=true` 不清空 weight 或 color。用户关闭 Hidden 后，原有软过滤和颜色立即恢复。
- 删除写 tombstone，不直接遗忘同步身份。

### 4.2 标签系统设置

建议新增一个按 scope 保存的设置记录：

```text
scopeKey: string
filteringThreshold: number   // -9999..0，默认 0
updatedAt: number
deletedAt: number
```

第一版使用 `scopeKey='global'`：这是用户设备间共享的本地偏好，不绑定 NH 登录状态；
表结构保留 scope 是为了将来可以增加账号配置，而不需要重做同步主键。

### 4.3 搜索条件的持久化所有者

“忽略本地标签过滤”不是本地用户标签规则本身，不能塞进 `local-user-tags` 数据集。
它按现有搜索条件的两级所有权保存：

```text
NhCatalogPreferences.ignoreLocalUserTagFiltering: boolean = false
NhHomeSubtabProfile.ignoreLocalUserTagFiltering: boolean = false
```

- 全局 Search 默认值由 `catalog_preferences` 保存，建议键名为
  `search_ignore_local_user_tag_filtering`；模型、State、Service 和 Repository 与
  `searchLanguage`、`searchSort` 使用同一读写链。
- Repository 沿用设置表布尔值约定写入 `'1'/'0'`，读取时接受现有规范化形式；新增
  `CatalogPreferencesService.setSearchIgnoreLocalUserTagFiltering(...)` 作为唯一 UI 写入口。
- `CatalogPreferencesState.searchRevision` 必须把该字段纳入变化判定，使 Search 页面和
  设置页同时得到更新。
- 每个自定义 Search Subtab 在 `home_subtabs` 中保存自己的值；该字段进入 profile 的
  `copy()`、内容 revision、RDB 读写、备份和 WebDAV 记录。
- `home_subtabs` 新列使用非空布尔整数并以 `0` 为迁移默认值；
  `HomeSubtabEditParams` 增加同级 seed 字段，以便从当前 Search 创建时完整复制条件。
- 内置 Latest/Popular Subtab 固定为 `false`；其身份规范化必须清除旧数据中意外携带的值。
- 从当前 Search 创建 Subtab 时，像 query、language、sort 一样复制当前忽略开关。
- 已有 Subtab 不跟随之后的全局 Search 默认值变化；它使用自己保存的快照。
- 旧数据库、旧备份和旧同步记录缺少字段时规范化为 `false`。

这里“临时禁用”描述的是用户可以用搜索条件暂时绕过规则，而不是开关只在一次请求或
一次页面会话内保存。

### 4.4 不属于本地用户标签的数据

- NH `/api/v2/blacklist/ids` 快照仍是账号派生缓存，不复制为本地规则。
- `nh_tag_catalog` 和 `tag_translations` 仍是可再生成缓存，不进入用户标签同步。
- 翻译后的标签文字不写入用户标签记录。
- 现有标题/评论过滤继续由 `content_filter_rules` 持有，不塞入用户标签表。

## 5. 过滤算法合同

### 5.1 单个图库判定

输入：

- `gallery.tagIds`
- 现有图库标题内容过滤判定
- 当前 NH 云端黑名单 ID 集合
- 本地用户标签 ID 索引
- 本地 `filteringThreshold`
- 调用上下文中的 `ignoreLocalUserTagFiltering`，默认 `false`

算法：

```text
uniqueTagIds = gallery.tagIds 去重

if 图库命中现有标题内容过滤规则:
    return true

if uniqueTagIds 命中 NH 云端黑名单:
    return true

if ignoreLocalUserTagFiltering == true:
    return false

matchedLocalTags = uniqueTagIds 对应的未删除本地标签记录

if matchedLocalTags 中任一 hidden == true:
    return true

score = matchedLocalTags.weight 的总和

if score < filteringThreshold:
    return true

return false
```

硬性边界：

- 权重阈值作用于**图库总权重**，绝不逐标签比较。
- 比较符为 `<`，不是 `<=`。
- 同一 tag ID 最多贡献一次权重。
- 未加入本地标签系统的标签贡献 `0`。
- 命中零条本地标签时总权重为 `0`；默认阈值 `0` 下不过滤。
- Hidden 优先于权重；正权重不能挽救 Hidden。
- 过滤使用 `tagIds`，不等待 `NhTagCatalogService` 丰富名称。
- `ignoreLocalUserTagFiltering=true` 只跳过本地 Hidden 和权重求和；NH 云端黑名单和
  现有图库标题内容过滤仍然执行，独立的评论过滤逻辑也不受影响。

### 5.2 必须锁定的示例

阈值为 `-5`：

| 图库命中 | 总权重 | 结果 |
| --- | ---: | --- |
| A=`-8` | -8 | 软过滤 |
| A=`-8`、B=`+5` | -3 | 保留 |
| A=`-8`、B=`+3` | -5 | 保留（等于阈值） |
| A=`-8`、B=`+2` | -6 | 软过滤 |
| C=`hidden`、D=`+99` | 不重要 | 硬过滤 |
| 无本地标签 | 0 | 保留 |

### 5.3 列表应用范围

本地标签过滤接入当前统一的图库过滤链，保持现有 NH 云端黑名单的页面表现：

- Home 最新列表和 Home 搜索子标签
- Popular
- Search
- Favorites
- Gallery Detail 的相关图库

过滤后继续使用这些页面当前已有的普通空态、分页和缓存表现；不新增临时反过滤、特殊
空态或过滤数量提示。

当前已打开的 Gallery Detail 和 Reader 不因随后修改标签规则而自动退出。规则只影响
后续列表集合的可见性。

### 5.4 全局搜索中的持久化忽略开关

完整 Search 页面在搜索条件 Sheet 中新增一个 Switch 行：

- 标题使用“忽略本地标签过滤”；新安装或旧数据缺少该字段时默认关闭。
- Switch 直接绑定 `CatalogPreferencesState.ignoreLocalUserTagFiltering`，修改后通过
  `CatalogPreferencesService` 写入 `catalog_preferences`，不能由 `SearchPage @Local`
  单独持有。
- 开启后，当前及后续全局 Search 结果跳过本地用户标签的 Hidden 和权重阈值过滤；
  关闭后恢复两种过滤。
- 开关变化立即从已保留的 `rawGalleries` 重新生成 `galleries`，不重复发起网络搜索。
- 刷新、加载下一页和跳页都沿用当前开关值，避免同一搜索结果混用两套过滤条件。
- 退出并重新进入 Search、进程冷启动、备份恢复和 WebDAV 同步后都恢复已保存值。
- 搜索历史和快捷搜索继续只保存 query；点击它们时使用当前持久化的全局搜索条件，
  与现有 language/sort 一致。
- 不作用于内置 Home Latest/Popular、独立 Popular、Favorites 或详情页相关图库；自定义
  Search Subtab 只读取自己的独立开关。
- 不绕过 NH 云端黑名单和现有图库标题内容过滤；评论过滤逻辑也不受影响。
- 不关闭标签颜色与彩色标签优先排序；两者是展示规则，不是过滤规则。

搜索标题栏漏斗图标的激活状态应包含该开关。开关开启时，即使语言和排序仍为默认值，
漏斗也保持当前已有的激活色，避免用户看不到忽略条件仍在生效。

设置页现有 Search defaults 分组也增加同一个 Switch，与 Search 条件 Sheet 绑定同一份
`CatalogPreferencesState`；任一入口修改后，另一入口立即反映。

### 5.5 自定义 Search Subtab 中的独立开关

`HomeSubtabEditPage` 的搜索条件组在 language、sort 同级增加“忽略本地标签过滤”：

- 只对 `NhHomeSubtabKind.SEARCH` 的自定义 Subtab 显示和生效。
- 新建普通 Subtab 时默认关闭；从当前 Search 创建时复制当前全局搜索开关。
- 编辑已有 Subtab 时读写该 profile 自己的值，不读取或覆盖全局 Search 默认值。
- `HomeSearchSubtabPage` 调用过滤链时传入 profile 的值；开关开启只跳过本地用户标签
  Hidden/权重过滤，其他过滤和标签颜色/排序保持不变。
- 该字段必须进入 `contentRevision()`，避免修改后继续复用旧过滤结果或旧缓存身份。
- Home Subtab 的 RDB、备份和 WebDAV 记录都保存该字段；旧记录缺失时按 `false` 恢复。

## 6. 标签颜色与列表优先排序合同

### 6.1 稳定分区

每个图库卡片在截断标签前执行一次稳定分区：

```text
displayable = 原始 gallery.tags 中具有可显示标签文字的项
colored = displayable 中命中本地记录且 colorCode 非空的项
plain = displayable 中其余项
ordered = colored + plain
visible = ordered.take(该卡片现有上限)
```

要求：

- `colored` 内部保持上游原始顺序。
- `plain` 内部保持上游原始顺序。
- 不按颜色值、weight、namespace、翻译名或字母顺序二次排序。
- 颜色优先排序发生在 `take/slice/tagAt` 截断之前，保证原本排在第 9 位之后的彩色标签
  能进入 8 标签瀑布流的可见区域。
- 排序结果只用于渲染，不改写 `NhGallerySummary.tags`，避免污染详情种子顺序、缓存和其他
  消费者。
- 查找按 `tag.id`；翻译开关只改变显示文字，不影响颜色身份或排序。
- 自定义颜色被清空后，该标签立即回到普通分区的原始相对位置。

### 6.2 各展示面的落点

| 展示面 | 颜色行为 | 排序行为 |
| --- | --- | --- |
| `GalleryTagStrip` | 自定义色作为 chip 背景，前景色按可读对比度计算 | 彩色优先，之后最多 10 个 |
| `GalleryWaterfallCard` | 同普通 chip | 彩色优先，之后最多 8 个，保持现有两行索引布局 |
| `GalleryWaterfallCompactCard` | 参考 NextE compact：使用向白色校正后的自定义文本色、Medium 字重和现有阴影，不增加新的 chip 几何 | 彩色优先，之后最多 8 个 |
| `GalleryDetailPage.TagMember` | 自定义色背景和可读前景色 | 不排序；保持现有 namespace 分组和种子顺序 |

不要为实现排序复制三套不同算法。建议在 shared 增加一个纯展示 helper，输入 `NhTag[]`
和只读用户标签索引，返回新的有序数组；三个列表组件共享它，详情页只共享颜色查找。

## 7. 运行时架构

### 7.1 Repository 与 Store

建议新增：

- `NhLocalUserTagRepository`：RDB CRUD、阈值设置、tombstone、批量 export/replace/merge。
- `NhLocalUserTagService`：写入串行化、输入规范化、过滤判定、权重求和、恢复和同步后
  reapply。
- `NhLocalUserTagStore`：普通 `Map<number, NhLocalUserTag>`，为列表过滤和卡片渲染提供
  O(1) 查询。
- `NhLocalUserTagState`：只保存 `isRestored` 和小型 `revision`；不要把完整 Map 放进
  ArkUI 深层观察图。

这沿用 NextE `UserTagStore + UserTagSignal` 的成熟模式，但身份改为 NH 数字 tag ID，
数据来源改为本地 RDB。

### 7.2 生命周期

- EntryAbility 启动恢复本地用户标签和阈值，再发布 `revision`。
- 本地添加、修改、删除和阈值更新必须先完成 RDB 事务，再原子替换内存快照并增加
  `revision`。
- WebDAV merge、备份恢复和冷启动都走同一 `reload/reapply` 入口。
- 规则变化后，当前已挂载的 Home、Popular、Search、Favorites 和相关图库从各自
  `rawGalleries` 重新过滤，不重新请求网络。
- Search 调用过滤服务时传入 `CatalogPreferencesState.ignoreLocalUserTagFiltering`；
  `HomeSearchSubtabPage` 传入当前 profile 的值；其他入口不传或传 `false`。不能为此
  绕过整个 `ContentFilterService`。
- `CatalogPreferencesState.searchRevision` 变化时要区分请求条件与纯本地过滤条件：
  language/sort 变化按现有路径重新请求，只有 ignore 开关变化时只重算 `rawGalleries`，
  不发网络请求。
- 颜色或排序变化必须使已挂载列表卡片重新渲染；不能只更新管理页。
- 每次成功的本地写入调用 `SyncScheduler.requestAfterLocalWrite(...)`。

### 7.3 时间复杂度

- 每个图库先用 `Set<number>` 去重 tag ID。
- 过滤复杂度为 `O(图库标签数)`，不能用“规则数 × 标签数”的嵌套扫描。
- 排序采用两个数组的稳定分区，为 `O(已解析标签数)`，不需要比较排序。

## 8. 管理与编辑 UI

### 8.1 页面结构

建议在设置页与“内容过滤”并列新增“本地标签”，而不是放入账号页面：本地标签在未登录
状态也有效，数据所有者不是 NH 账号。

页面复用 NextE My Tags 的完整父树和行结构：

- 标签列表行：标签名/翻译、颜色预览、Hidden 状态、weight 徽标。
- 添加标签：通过当前 NH 标签建议/目录选择，最终必须得到 `tagId`；不创建只有自由文本、
  无法绑定 NH ID 的规则。
- 编辑 Sheet：Hidden、weight、自定义颜色/默认颜色、删除。
- 阈值设置：在本地标签页面内提供 Tag Filtering Threshold 数字编辑项。
- Search 条件 Sheet 和设置页 Search defaults 分组增加同一个“忽略本地标签过滤”
  Switch，绑定 `NhCatalogPreferences` 的持久化值。
- `HomeSubtabEditPage` 的自定义搜索条件组增加同名 Switch，绑定当前 Subtab profile，
  不绑定全局默认值。

Hidden、weight 和 color 是并列字段：

- 开启 Hidden 不删除 weight/color。
- 设置负 weight 不自动开启 Hidden。
- 设置颜色不自动改变 weight，新增标签沿用默认 `10`。
- 清除颜色只恢复默认展示和列表位置，不删除规则。

### 8.2 标签上的快捷入口

第一版必须先保证管理页面完整可用。详情标签当前单击行为是精确搜索，不能被覆盖。
若实现阶段增加快捷管理入口，应沿用 NextE/Eros FE 已有的标签信息/管理动作边界，并在
UI 变更台账中先记录父树和设备验收方案；不能临时把单击搜索改成编辑。

## 9. WebDAV 与备份合同

### 9.1 独立 WebDAV 数据集

协议上新增 `local-user-tags` 数据集，包含：

```text
localUserTagSettings[]
localUserTags[]
```

独立数据集的原因是旧客户端兼容：现有 `replaceManifestDataset()` 只替换自己认识的
dataset，会保留未知 dataset；如果把新字段塞进现有 `local-block` envelope，旧客户端
重写 `local-block` 时可能丢弃不认识的标签字段。

同步规则：

- 标签分片键：`scopeKey:tagId`。
- 设置分片键：`scopeKey`。
- 同一记录以 `max(updatedAt, deletedAt)` 执行整记录 LWW。
- 删除必须同步 tombstone，不能在另一台设备复活。
- manifest/envelope 的 schema 只有在新增数据集无法保持现有解析兼容时才升级；不能因为
  字段新增机械升级。
- 同步设置页增加明确的“本地标签”数据集开关；默认启用，与用户提出的跨设备同步目标
  一致。

### 9.2 必须覆盖的冲突

- A、B 同时修改同一标签的 color/weight/hidden：较新整记录胜出，不做字段拼接。
- A 删除、B 修改同一标签：较新的 `updatedAt/deletedAt` 胜出。
- A 修改阈值、B 修改标签：两个不同主键都保留。
- 旧客户端同步其他已知数据集：不得删除 `local-user-tags` manifest 项或远端分片。
- 同步后必须重建本地 ID Map、重新过滤当前 `rawGalleries` 并刷新卡片颜色/排序。

### 9.3 备份与持久化清单

- `BackupTypes.localData` 增加可选的 local user tags 和 settings 段，旧备份缺失时不得
  清空当前本地标签。
- `BackupLocalDataAdapter` 增加导出、预览计数、拓扑校验、事务恢复和 reapply。
- 全局 `ignoreLocalUserTagFiltering` 作为 `catalog_preferences` 的新键，自动进入现有
  `settingsTables` 备份和 WebDAV 数据集；不在 `local-user-tags` 中保存第二份。
- 每个自定义 Search Subtab 的值进入 `BackupHomeSubtabEntry` 和
  `SyncHomeSubtabRecord`，随现有 `home-subtabs` 数据集同步；旧记录缺失时取 `false`。
- `docs/plans/active/persistence-dataset-inventory.md` 把新表登记为
  `localData + WebDAV`，并由现有反向扫描合同覆盖。
- 标签目录、翻译缓存和 NH 黑名单快照继续排除。

## 10. 预计代码落点

以下是实现导航，不是强制要求机械创建同名文件；实现前以当前源码再次确认：

| 责任 | 预计落点 |
| --- | --- |
| 模型 | `shared/src/main/ets/model/NhLocalUserTag.ets` |
| RDB 表与版本 | `shared/src/main/ets/storage/LocalDataStore.ets` |
| CRUD/同步导出 | `shared/src/main/ets/storage/NhLocalUserTagRepository.ets` |
| 过滤、求和、写入编排 | `shared/src/main/ets/services/NhLocalUserTagService.ets` |
| ID Map 与响应信号 | `shared/src/main/ets/state/` 或 `services/` 下的 store + state |
| 统一图库过滤 | `shared/src/main/ets/services/ContentFilterService.ets` |
| 全局搜索忽略偏好 | `NhCatalogPreferences.ets`、`CatalogPreferencesState.ets`、`CatalogPreferencesService.ets`、`CatalogPreferencesRepository.ets` |
| 全局搜索开关 UI | `feature/search/src/main/ets/pages/SearchPage.ets`、`SettingsPage.ets` 及资源字符串 |
| Subtab 独立开关 | `NhHomeSubtabProfile.ets`、`LocalDataStore.ets`、`HomeSubtabRepository.ets`、`HomeSubtabEditPage.ets`、`HomeSearchSubtabPage.ets` |
| 列表颜色和稳定分区 | `GalleryTagStrip.ets`、两个 Waterfall 卡片和 shared helper |
| 详情颜色 | `feature/gallery/src/main/ets/pages/GalleryDetailPage.ets` |
| 管理页面 | `feature/settings/src/main/ets/pages/LocalUserTagsPage.ets` |
| 设置入口与路由 | `SettingsPage.ets`、`entry/src/main/ets/pages/Index.ets`、资源字符串 |
| WebDAV | `SyncTypes.ets`、`SyncLocalDataAdapter.ets`、`WebDavSyncService.ets`、同步设置状态/UI |
| 备份 | `BackupTypes.ets`、`BackupLocalDataAdapter.ets`、`BackupService.ets` |
| 持久化合同 | `persistence-dataset-inventory.md` 及现有备份/同步合同脚本 |

## 11. 分阶段实施顺序

### Phase 1：模型、表和纯算法

- 新增本地标签与阈值模型、RDB 表、Repository。
- 实现输入规范化、ID 索引、图库权重求和和硬/软过滤。
- 实现彩色标签稳定分区 helper。
- 用纯数据测试锁定 §5.2 和 §6.1，不涉及 UI 截图验收。

完成边界：数据和算法在源码中可用；不声称页面功能已完成。

### Phase 2：运行时接入

- 启动恢复、写入串行化、revision、当前列表重过滤。
- 接入现有 `ContentFilterService.filterGalleries()` 页面集合。
- 扩展 `catalog_preferences` 全局搜索默认值和 `home_subtabs` profile 字段，并完成旧数据
  默认 `false` 的迁移/规范化。
- 为过滤调用增加窄作用域选项；全局 Search 和自定义 Search Subtab 可按各自持久化值
  跳过本地用户标签过滤，其他调用方保持默认行为。
- 接入写后 WebDAV 调度请求，但此阶段不宣称远端同步完成。

完成边界：源码和构建通过；运行时仍需设备验证。

### Phase 3：管理 UI

- 先在 `nextn-ui-change-ledger.md` 记录 NextE 参考父树、页面入口、Sheet 状态和设备验收计划。
- 复用 NextE My Tags 列表和编辑 Sheet，替换为 NH tag ID/本地 Repository 叶子。
- 增加过滤阈值编辑、添加/编辑/删除流程。
- 在 Search 条件 Sheet 和设置页 Search defaults 增加全局持久化 Switch，并把它纳入
  漏斗激活态。
- 在 `HomeSubtabEditPage` 增加每个自定义 Search Subtab 独立的同名 Switch。

完成边界：页面源码与构建完成；视觉/交互必须经过真实设备验收。

### Phase 4：颜色与列表优先显示

- 三种列表标签展示共享稳定分区结果，先排序再截断。
- 普通/瀑布流使用彩色 chip；紧凑瀑布流保持其现有几何，只应用 NextE compact
  彩色文字语义。
- 详情标签只着色，不重排。
- 标签规则更新后对当前挂载页面即时刷新。

完成边界：必须有同一图库、同一视口、设置颜色前后的真实设备证据，覆盖三种列表展示和
详情页，才能接受可见行为。

### Phase 5：备份与 WebDAV

- 新增 `local-user-tags` 数据集、同步设置开关、LWW/tombstone 和旧客户端保留未知数据集
  合同。
- 让全局开关随现有 `settings-tables/catalog_preferences` 同步，让 Subtab 开关随
  `home-subtabs` 同步，并验证旧记录缺少字段时为 `false`。
- 接入备份导出/恢复/reapply 和持久化清单。
- 完成真实两设备 WebDAV 往返。

完成边界：静态合同或构建不能代替真实跨设备同步与冷启动恢复。

## 12. 验证矩阵

### 12.1 算法与存储

- 默认 weight/threshold 和数值边界。
- 正负权重抵消、严格 `<`、相等不过滤。
- Hidden 覆盖 `+99` 正权重。
- 重复 tag ID 只求和一次。
- 未配置标签不贡献权重。
- 修改 Hidden 不破坏 color/weight。
- 清空 color 恢复普通分区而不删除标签记录。
- 删除墓碑、冷启动恢复、备份恢复后 Store 重建。

### 12.2 排序与展示

- 原始顺序 `[普通A, 彩色B, 普通C, 彩色D]` 输出
  `[彩色B, 彩色D, 普通A, 普通C]`。
- 多个彩色标签之间保持原始顺序；普通标签之间也保持原始顺序。
- 彩色标签原始位置超过第 8/10 项时，排序后进入可见截断区。
- 翻译开关开/关不改变身份、颜色和排序。
- 普通列表、瀑布流、紧凑瀑布流结果一致。
- 详情 namespace 分组和当前标签顺序不因颜色变化而改变。

### 12.3 列表过滤运行时

- Home、Home 搜索子标签、Popular、Search、Favorites、相关图库使用同一判定。
- 编辑 weight、Hidden 或 threshold 后，已挂载列表从 `rawGalleries` 即时重算。
- 过滤后沿用现有普通空态，不出现新增提示或临时反过滤入口。
- 已打开详情/Reader 不自动退出。
- Search 开关打开后，当前 `rawGalleries` 中仅因本地 Hidden/权重被隐藏的项目立即恢复；
  关闭后立即重新隐藏，全程不新增网络请求。
- Search 开关不恢复 NH 云端黑名单结果，也不绕过图库标题内容过滤；评论过滤不受影响。
- 刷新、加载更多和跳页沿用当前开关；离开并重新创建 Search 页面及进程冷启动后仍恢复
  已保存值。
- Search 条件 Sheet 与设置页 Search defaults 任一处修改，另一处立即显示相同状态。
- 从当前 Search 创建 Subtab 时复制开关；之后修改全局值不改变已有 Subtab。
- `HomeSubtabEditPage` 可独立修改每个自定义 Search Subtab；不同 Subtab 的过滤结果互不
  影响，内置 Latest/Popular 始终执行本地标签过滤。
- 开关开启时仍应用标签颜色和列表彩色标签前置排序。

### 12.4 WebDAV 双设备验收

1. 设备 A 添加一个彩色正权重标签、一个负权重标签和一个 Hidden 标签。
2. A 同步后，设备 B 获取相同颜色、顺序、weight、Hidden 和 threshold。
3. B 冷启动后仍保持相同列表过滤与着色结果。
4. A/B 并发修改同一标签，验证整记录 LWW。
5. A 删除标签后同步，B 不得将其复活。
6. 旧版本客户端同步其他数据集，不得移除 `local-user-tags`。
7. A 修改全局 Search 开关和一个自定义 Subtab 的开关，B 同步并冷启动后恢复两个各自的
   值；旧同步记录缺少字段时保持默认关闭。

## 13. 实施停止条件

- 不得因为 NextE 本地 Store 没有权重计算，就省略 EH 的权重求和语义。
- 不得把权重阈值改成“任一单标签低于阈值即过滤”。
- 不得把 Hidden、weight 和 color 压成一个互斥 mode。
- 不得在排序时改写原始 `gallery.tags` 或详情种子顺序。
- 不得先截断再把可见范围内的彩色标签排序。
- 不得用标签翻译文字或 namespace/name 拼接串替代 NH tag ID 作为主身份。
- 不得把 NH 云端黑名单自动复制为本地用户标签。
- 不得把 Search 的持久化忽略开关扩大成 `ContentFilterService` 总开关。
- 不得只保存全局值而省略每个自定义 Search Subtab 的独立字段和编辑入口。
- 不得让全局 Search 默认值在创建完成后继续覆盖已有 Subtab 的保存值。
- 不得用构建、静态测试或单设备截图声称 WebDAV 跨设备同步已验收。

## 14. 当前下一步

本文档完成后，下一项可执行工作是 Phase 1：先实现本地模型、RDB 所有权、纯权重算法和
彩色标签稳定分区 helper。开始任何可见 UI 修改前，必须先按
`docs/controls/nextn-execution-integrity.md` 在 UI 变更台账中记录参考父树与验收边界。
