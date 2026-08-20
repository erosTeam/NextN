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

剩余修复批次仍保持 OPEN：

1. 关键链路吞错（网络请求/持久化/状态迁移/登录会话）必须补 stage 日志（模式照
ReaderSuperResolutionService.recordProcessingFailure：固定阶段名，不泄敏感内容）；
2. 资源清理吞错（release/close/unlink/destroy）可保留，但变量名统一 _cleanupError
 表意，防止与关键吞错混淆。
验收：分类清单 + 关键链路补日志后构建通过；本批仅完成分类初核和两处首批日志，不能
宣称 C 全部完成。

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

## 车道 E（P1，分页批）：NextE 移植删减审计 TODO

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

## 车道 F（P2，持续）：流程固化 VERIFIED

- 已建立：incident-register（退化登记）、本次修复即走同类 grep 防扩散模式
- 固化规则：任何 bug 修复提交前，必须 rg 同模式全仓扫描；修复采用公共 helper 收口

## 执行顺序

A → B → C → D → E（E 分批，可与 C/D 穿插）。每车道完成即更新状态并提交。
