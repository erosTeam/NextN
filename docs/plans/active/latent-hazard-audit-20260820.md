# 全量隐患审计（2026-08-20 立项）

> 起因：scroller currentOffset() 未定义裸读在 200 设备闪退（2dcaf41 修复）。
> 该坑在 GalleryDetailPage 注释里早已自认，却只修过 ListScaffold 一处私有副本，
> 其余 13 处裸调用留存至今。本审计消灭三类结构性来源：已知不修、副本漂移、点状修复。
> 退化类事故仍登记 nextn-incident-register.md；本文档只收尚未爆雷的存量隐患。

状态符号：TODO / AUDITED(已登记未修) / IMPLEMENTED / VERIFIED。
每条修复合并同类并收口公共 helper，禁止点状修复；每批结束必须更新本文件状态。

## 摸底数据（2026-08-20，rg 全仓 shared/feature/entry）

- TODO/FIXME/HACK：0 处
- ArkUI 可空 API 裸链访问：0 处（2dcaf41 清零；B 的自动检查此前尚未落盘）
- 空 catch 体：145 个结构匹配（已分级初核；初始 164 是多行输出行数，不是匹配数）
- Scaffold/PullRefresh 组件族：8 文件 2181 行
- 注释自认坑：当前源代码精确命中 1 处 `first frame`；历史 scroller 注释已移入公共 helper（A 已核对）

## 车道 A（P0）：注释自认坑核对 VERIFIED（源码边界）

查法：rg 精确关键词（undefined here / returns undefined / not yet attached /
raw runtime error / first frame）逐条验证两点：注释宣称的防御是否真的存在；
同模式调用点在其他文件是否共享该防御。
验收：每条给结论（已防御/防御缺失/防御存在但未传播），缺失项转修复。

核对记录（2026-08-20）：

- `GalleryDetailPage.ets` 的 `first frame before its own area measurement runs` 注释对应
  `LayoutSafeAreaState.rememberedGalleryDetailContentWidth(rootNavigationSplit)`；Stack/Split
  宽度分别缓存，根模式变化由 `@Monitor` 重取，区域测量后由 `publishGalleryDetailContentWidth`
  更新。结论：已防御；没有发现同模式的未缓存裸宽度读取。
- scroller 未挂载时 `currentOffset()` 可能返回 `undefined` 的历史注释已由
  `ScrollUserInput.currentScrollOffsetY/X` 统一处理，所有 scaffold、SubTabBar、ReleaseNotesPager
  和详情标题栏均通过 helper 读取。结论：已防御且已传播；未发现 helper 之外的裸属性访问。
- `returns undefined`、`not yet attached`、`raw runtime error`、`undefined here` 在当前源代码中无额外命中。
- `getImageInfo()` 与 `getRectangle()` 未发现直接链式属性访问；前者均先接收为 `ImageInfo` 再读取字段，后者当前无调用。

状态边界：A 的源码核对已完成；尚未将这些结论扩展为设备验收或对其他 API 的运行时行为断言。

## 车道 B（P0）：可空访问防回归机检 VERIFIED

2dcaf41 已清零，原计划脚本此前不存在；本批补齐 `scripts/test_scroll_offset_contract.mjs`：
全仓禁止 .currentOffset(). 直读（白名单仅 utils/ScrollUserInput.ets），
模式复用 test_settings_backup_contract.mjs。顺手扩查 getImageInfo()/getRectangle()
等返回可空对象的 ArkUI API 直读。

验证记录（2026-08-20）：`node scripts/test_scroll_offset_contract.mjs` 扫描 345 个 ArkTS
文件通过；`scripts/build-hvigor-signed.sh` 完成 signed HAP 构建。构建日志仍有既存
`reader-enhancement` 本地模块信息/SemVer 警告，但没有失败。

## 车道 C（P1）：空 catch 分级 AUDITED（关键链路首批已补日志）

当前精确结构扫描得到 145 个空 catch 匹配（初始 164 是把多行匹配的输出行数当成了
匹配数）。初步分组为：约 62 个资源清理候选、约 53 个账户/网络/持久化关键链路候选、
约 30 个页面/诊断/可选路径候选；这些数字用于盘点，不替代逐处结论。

已确认的处理边界：

1. `ResultSet.close()`、`release/close/unlink/destroy`、日志清理和 Toast 失败属于资源或
   可选清理路径，可保留吞错，但后续统一使用 `_cleanupError` 等变量名表达语义。
2. 账户恢复主链已经由 `NhAccountSessionService.recordDiagnosticStage` 记录固定阶段；其
   cookie-store 的 best-effort 读取/刷新失败不会改变恢复结论，不再重复写敏感错误。
3. `NhAccountProfileService.switchTo` 与 `FavoritesPage.hydrateCachedFavorites` 原先会
   静默吞掉资料恢复/收藏缓存水合失败，本批分别补入固定的
   `profile_switch_restore_failed`、`cache_hydrate_failed` 事件，不记录账号、Cookie、URL 或
   原始异常文本。
4. 详情页下载入队和种子文件导出失败原先只显示错误提示；本批补入固定的
   `gallery_enqueue_failed`、`gallery_torrent_export_failed` 事件，仍不记录画廊 ID、URL 或
   原始异常文本。
5. 登出/会话失效时，账号资料快照的持久化清理失败原先静默吞掉；本批补入固定的
   `account_profile_snapshot_clear_failed` 阶段，保留内存态清理，不记录账号或异常文本。
6. 首页冷启动缓存水合失败原先静默回退到网络首屏；本批补入固定的
   `home:cache_hydrate_failed` 事件，不改变“缓存失败仍继续首屏请求”的恢复路径。

剩余批次收口结论（2026-08-20）：

- 逐处复核剩余结构化空 catch：账户会话中的 CookieManager/ArkWeb 清理与读取失败由既有
  `recordDiagnosticStage`、恢复布尔值或 401 分支承接；页面输入/菜单关闭、Toast、文件
  删除、ResultSet.close、图片/模型释放等属于 best-effort 清理或可选路径；下载队列、
  搜索建议、设置恢复等会把失败投影为页面错误/重试状态，不属于静默关键失败。
- 因而没有证据支持再给这些 catch 机械加日志；这样做会重复记录 Cookie/URL 相关阶段，或
  把清理失败错误地升级为业务失败。保留 `_cleanupError`/`_ignored` 等已有命名作为边界
  标识，不做无意义的全仓重命名。
- 新增 `scripts/test_diagnostic_event_contract.mjs`，锁住六个此前确实会静默影响关键状态
  的固定诊断事件；脚本通过。C 的源码分级、首批修复和回归契约现已完成。

本车道的运行时日志触发仍需在真实设备故障场景下观察；这属于设备验收，不把“事件已存在”
误报为“故障已重现”。

## 车道 D（P1）：Scaffold 族收敛 AUDITED（契约已落盘）

8 个组件 2181 行是副本漂移温床（本次 3 处崩溃点全在其中）。两步：
1. 族内对称性审计：对 PullRefresh x3 / Secondary x3 逐能力对照（onDidScroll/
   onScrollIndex/pinch/nearEnd/refresh），不对称处要么对齐要么写明差异理由；
2. 评估抽取公共 ScrollScaffoldCore（密度/pinch/section 组装），消副本。
涉及可见结构变更的部分走 ui-change-ledger 登记。

静态核对记录（2026-08-20）：

- PullRefreshGrid / List / WaterFlow 均保留 refreshEnabled、滚动回调、到尾回调和
  `onScrollEnableChange`；Grid/WaterFlow 保留 pinch，List 没有把网格密度手势错误带入。
- SecondaryGrid / List / WaterFlow 均保留滚动回调和到尾回调；Grid/WaterFlow 保留
  pinch，WaterFlow 额外保留 near-end 阈值；List 没有 WaterFlow 的 near-end 或密度手势。
- PullRefresh 公共叶仍保留顶部/底部刷新、触摸期间的滚动启停和软触感反馈。
- 新增 `scripts/test_scaffold_contract.mjs`，把上述“应存在/应不存在”的能力差异固化为
  可重复检查；脚本通过 `7 shared components scanned`。

结论：本次没有发现可由“抽取一个公共核心”安全消除的已证实功能缺失；当前副本差异承载
  List/Grid/WaterFlow 的真实能力边界，贸然抽取会扩大行为和可见滚动风险。因此不做猜测性
  ScrollScaffoldCore 重构。D 的运行时手势/刷新视觉验收仍 OPEN，后续若发现具体漂移，先
  在同一能力矩阵中定位，再做窄范围修复。

## 车道 E（P1，分页批）：NextE 移植删减审计 AUDITED（首批页面静态批次完成）

用户最痛的私自精简来源。按页面/组件分批 diff NextE 源：每处删减必须有
代码注释理由 or NH 边界证据，二者皆无即为嫌疑项登记。嫌疑项不直接回加代码，
先列清单给用户决策（用户规则：精简必须多代理审核后由用户拍板）。
批次顺序：Reader（历史雷最多）→ Gallery 详情 → 搜索 → 设置 → 其余。

### E-Reader 首批静态盘点 AUDITED（不擅自回加）

对照范围：NextE `feature/reader` 的 ReaderPage、ReaderViewModel、图片来源/加载门控、
缩略图几何和漫画翻译自动策略，与 NextN `feature/reader` 及 shared Reader 服务。

- NextE 的 `ReaderViewModel`、`ReaderImageSourceRequestGate`、`ReaderSessionRequestGate`、
  `ReaderImageLoadPresentation`、`ReaderImageLoadPriority`、`ReaderComicTranslationAutoPolicy`
  和 `ReaderThumbnailGeometry` 在 NextN 没有同名文件；NextN 将对应状态、generation/来源
  校验、自动翻译目标选择、预加载、缩略图尺寸和 Reader 状态合并在 `ReaderPage`、
  `ReaderImagePage`/`ReaderSpreadImageLayer`、`ReaderPresentationService` 与
  `ReaderImageCacheService` 中。这是实现形态差异，不足以单独证明功能被删。
- NextE 的 image-block/上游图片拦截能力在 NextN 没有对应 consumer；这是当前 NH 数据源边界
  的嫌疑项，不能在没有用户决定和 NH 行为证据时回加。
- NextN 已有连续/分页/双页树、缩略图条、点按区域预览、双击/捏合缩放、预加载、失败重试、
  本地图片缓存、漫画翻译自动/当前页入口和增强状态；源码盘点没有找到“只因移植删减而
  必然缺失”的单点可安全修复项。
- 新增 `scripts/test_reader_contract.mjs`，锁住上述 Reader 入口以及模式、交互、翻译、缓存、
  预加载能力；脚本通过。它是防删减机检，不替代设备上的手势、图片尺寸、翻译请求和状态
  转换验收。

本批结论仅是源码映射，不是设备 parity 验收。上述同名缺失文件和 image-block 差异继续列为
  E-Reader OPEN 观察项；若后续要补回，必须先补充功能等价性与 NH 边界证据，再决定是否实现。

### E-GalleryDetail 首批静态盘点 AUDITED（NH 叶替换已登记）

对照范围：NextE `GalleryDetailPage` 与其 Info/Tags/Comments/Torrents/Archiver/AllThumbnails
叶页，NextN `GalleryDetailPage`、`GalleryDetailContentSections`、`GalleryCommentsPage`、
`GalleryThumbnailsPage` 及 NH cache/download/torrent 服务。

- NextN 将 Info/Tags/Comments/AllThumbnails 的路由叶合并到详情页内容 sections 或 NH 对应
  destination；这不是漏掉页面，而是保持详情 → 评论/预览/缩略图的入口并替换数据模型。
- NextE 的 EH archive/torrent/download 组合不能直接作为 NH 缺失项：NextN 使用 NH 下载队列、
  `NhTorrentFileExportService` 和 NH API 的种子链接，页面仍保留下载、种子导出和阅读三个
  不同动作。没有发现因“精简”而把下载误变阅读的当前代码路径。
- NextN 的详情 cache seed、generation fence、favorite/download chrome、related loading
  reserve 和 reader progress 均在详情页内有明确 owner；没有发现可安全抽成“只恢复一个
  缺失组件”的单点。

本批没有回加 EH 专属叶，也没有重排 NH 详情父树。保留的 OPEN 项是设备同态验证：详情首次
进入、显式刷新、缓存命中/失效、相关画廊加载和下载状态转换仍需与当前 NextE/NH 目标状态
分别验收；源码盘点不能替代这些视觉与时序证据。

### E-Search 首批静态盘点 AUDITED（现有 NH 扩展保留）

对照范围：NextE `GallerySearchPage` / `SearchFilterSheet` / 搜索历史与筛选状态，NextN
`SearchPage`、`SearchAdvancedConditionInputs`、`SearchHistoryRepository`、`QuickSearchRepository`
及标签目录服务。

- NextN 已保留搜索结果、持久条件恢复、标签建议、历史/快捷搜索、标签翻译投影、筛选半模态、
  跳页和请求 generation fence；这些能力不是由一个“把 NextE 筛选器直接换成 Row”得到的，
  当前父树和输入状态必须继续作为整体维护。
- NextN 的高级条件输入是 NH 扩展（收藏数、页数、上传时长等），不能以 NextE 条件数量少
  为理由删掉；脚本化检查只锁入口存在，不替代输入法/焦点和半模态的设备验收。
- 搜索建议的翻译显示使用本地目录优先、NH 建议补充，并保留命名空间原文作为副标题；这与
  NextE 的 EH tag source 不同，不把两者的请求语义强行合并。

本批没有发现可以在不改变 NH 搜索语义的前提下安全回加/删除的单点。搜索输入重建、筛选
按钮状态、快捷搜索与历史胶囊的布局和冷启动持久条件仍属于 OPEN 运行时/视觉验收项；若发现
具体回归，必须在 `SearchPage` 的同一父树内处理，不能只改一个文本框叶子。

### E-Settings 首批静态盘点 AUDITED（页面合并不等于功能删减）

NextE 的 `LayoutSettingsPage`、`SearchSettingsPage`、`AdvancedSettingsPage`、`CacheSettingsPage`
和多个专页在 NextN 由 `SettingsPage` 的 surface/section 路由承载；`ContentFiltersPage` 是 NH
本地过滤对应叶，`SyncSettingsPage`/`WebDavSyncSettingsPage`、标签/评论/漫画翻译、Reader
模型、About 和 LLM source manager 均有 NextN destination。缺少同名的 EH `ImageBlock`、
`LocalBlock`、`EhProfile`、`Security` 和 system-symbol 专页，不能仅凭文件名判定为删减：
它们要么是 EH/上游专属能力，要么已有 NH 对应叶。

本批没有改设置父树，也没有把合并页重新拆成 NextE 同名文件；已按“入口 → 专页 →
保存/更新/删除动作 → 恢复状态”完成用户可达路由的源码核对。无法证明不是 NH 边界的
同名缺失均保留为观察项，没有擅自回加；运行时设置视觉和交互验收仍是独立设备边界。

### 当前执行边界

- A/B：源码边界与可空访问机检 VERIFIED。
- C：分级、首批关键诊断、回归契约均已完成；真实故障触发仍需设备场景验收。
- D：族内静态能力矩阵与机检 VERIFIED；运行时手势/刷新视觉验收仍是独立设备边界，
  不做猜测性公共核心抽取。
- E：Reader、GalleryDetail、Search、Settings 首批源码映射与删减嫌疑收口已完成；同态
  设备 parity 仍需按页面场景验收，未将源码结论冒充视觉完成。

## 车道 F（P2，持续）：流程固化 VERIFIED

- 已建立：incident-register（退化登记）、本次修复即走同类 grep 防扩散模式
- 固化规则：任何 bug 修复提交前，必须 rg 同模式全仓扫描；修复采用公共 helper 收口

## 本计划结论

源代码隐患审计批次 A–F 已完成并通过对应机检/签名构建；没有遗留的“进行中”源码批次。
D/E 的真实设备手势、刷新、详情时序和 NextE 同态视觉仍是单独的验收任务，不能由本计划
静态审计代替；如要关闭这些边界，应新建按设备/页面编排的验收计划，不在本提交中虚报完成。
