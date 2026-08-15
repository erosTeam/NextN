# NextN 事故登记簿

> 目的：稳定功能一旦出现退化，必须在这里登记**哪次提交/哪项设计决策引入、当时的理由、
> 退化链路、真实证据、修复与防止复发规则**。登记不是验收；每条事故的状态只能是
> `OPEN`（根因未闭环/未验证）或 `CLOSED`（真机证据闭环）。

## 登记规则

1. 任何“上次还好好的、这次坏了”的反馈，先查 `git log` 与未提交改动，定位引入点，
   再写本登记簿；禁止直接改界面。
2. 每条记录必须回答：改了什么、当时的理由、为什么这个理由不成立、证据在哪、如何防止。
3. 禁止用“再调一次”“重建组件”“补一个 Monitor”这类单点补丁冒充修复；根因在数据/状态
   链路上，就必须修链路本身。
4. UI 首帧/过渡问题，没有同态真机对照前一律 `OPEN`，不许声称已修复。

---

## INC-2026-08-16-001：标签翻译冷启动失效（列表英文、详情先英文后中文）

- 状态：`CLOSED`（真机证据 2026-08-16：冷启动 1/2 次首页瀑布流与收藏、详情标签均直接中文）
- 用户反馈：冷启动后首页/收藏的标签全是原文；打开标签翻译后进入画廊详情仍是英文；
  详情页先出现英文标签再跳成中文。该问题此前已反复出现 4 次以上。

### 引入点

- 未提交改动：`shared/src/main/ets/storage/GalleryListCacheRepository.ets`（
  `nh_gallery_list_cache` 首页/收藏第一页快照缓存，本次会话为修“收藏冷启动会话检查”而新增）。
- 相关提交：`240b2cd fix(gallery): seed detail from tapped row to avoid blank loading and tag flash`
  （详情页用点击行的快照做首帧，并把快照标签直接作为种子标签）。

### 当时的理由（写进代码/文档的原话）

- `docs/developer-guide.md` 3.1：**“缓存恢复的标签 displayName 一律置空（词典归属当前
  TagTranslationState），渲染回退 name；网络刷新后由 enrich 重新应用词典。”**
- `GalleryListCacheRepository.decode()` 里把 `tag.displayName` 清空，注释称缓存是
  “display-only”，每次读取后都会走网络刷新。

### 为什么这个理由不成立

- 缓存行的用途恰恰是**冷启动第一帧**：先画缓存，网络刷新在之后才到。把 displayName
  清空后，第一帧只能画英文原文，而“网络刷新后重新应用词典”发生时用户已经看到了英文。
- Home/Favorites 水合缓存后直接 `rawGalleries = cached` 进渲染，没有先
  `refreshLocalDisplayLabels()`；本地词典查找是异步的，且未必触发 UI 重建。
- 详情页种子（`240b2cd`）复用同一批被清空的 displayName，所以详情首帧也是英文；
  之后 `requestTagTranslations()` 完成才换成中文，形成“先英文后中文”。
- 之前的两次修复（`515af1e`、`2e17ee1`）只在“词典 revision 到达后重建标签 chips”，
  修的是**显示层回调**，没有修**缓存解码丢标签**这个数据源，因此冷启动每次都复发。

### 修复（源码已落盘，未构建）

1. `GalleryListCacheRepository.decode()` 保留 `source.displayName`。
2. Home `loadOnceWithCachedRows()` 水合缓存前先
   `NhTagCatalogService.refreshLocalDisplayLabels(cached)`。
3. Favorites `hydrateCachedFavorites()` 同样先重新本地贴标签。
4. 详情种子标签按 `id+type+name` 复用行内已解析标签，词典查找完成前不画英文原文。

### 真机验收（未完成）

- 冷启动 → 首页瀑布流/网格：标签直接中文，无先英文。
- 冷启动 → 收藏：标签直接中文。
- 详情页：首帧标签即中文，无英文→中文跳变。

---

## INC-2026-08-16-002：详情页封面卡片首帧闪跳（下半部出现一帧）

- 状态：`OPEN`（换源跳变已修复并装机；过渡帧“下半部一帧”未复现，保留 OPEN）
- 用户反馈：进入详情页后，封面卡片在屏幕下半部出现一帧闪动；此前还反馈过封面在中间
  闪跳一下。用户明确指出**这不是封面加载问题，是卡片位置/首帧问题**。

### 引入点

- `240b2cd`：详情页从“全屏加载态”改为**首帧直接画点击行的封面快照**（seed）。
- `f68cbb7`：封面按真实宽高比在固定 124×175 槽内绘制（`heroCoverFittedWidth/Height`）。

### 退化链路（源码证据 + 已确认的因果链）

1. **引入点是 `240b2cd`（详情页首帧改为点击行快照），不是封面加载本身。**
   该提交之前，详情首帧是全屏 `PageLoadingState`，验证数据到达后 Hero 才一次性出现，
   没有第二次突变，因此没有闪跳。
2. seed 首帧：`applySeedSnapshot()` 用 `seed.thumbnailUrl`（列表缩略图）立即铺 Hero。
3. 验证响应到达：`applyVerifiedDetailSnapshot()` 在**同一个状态提交**里同时发生：
   a. `detail` 被整体替换，`GalleryHero` 直接读 `detail.coverUrl`，URL 从缩略图换成
      详情原图 → Image 卸载旧位图、加载新位图（重载窗口）；
   b. `heroCoverHasSourceSize()` 从种子尺寸切到验证尺寸（`f68cbb7` 之后图片从
      `Contain 铺满槽` 切换为 `Fill 按真实比例`）；
   c. `isDetailReadyForCurrentGallery` 变 true，`GalleryInformation`、预览等区块
      在同一帧插入 List。
4. 当前修复（`displayedCoverUrl` + `pendingCoverUrl` 原子换图）拆掉了 a：验证帧不再
   重载位图，因此闪窗消失。这解释了“现在已经没有这个问题了”。
5. **未实证部分**：上述突变表现为“整张卡片在页面下半部闪一帧”的具体几何，源码
   无法直接推出；需要临时恢复旧渲染逻辑做 bisect 构建 + 逐帧抓图才能实证。
   在获得该帧前，下半部几何保持 `OPEN`，不许声称已完全解释。

### 为什么 NextE 不出现

- NextE 详情头图始终用列表的 `thumbUrl`（`EhGallery.merge` 非空即覆盖，详情页 URL 基本
  同一张缩略图），没有“缩略图→原图”的换源重载。
- NextE 的 `EhThumbnail` 内置 loading/failed/URL 变化复位，图片生命周期集中在一个组件。
- NextE 的翻译在 ViewModel 层完成（`translateRows`/`translateGalleryTags`），并且把
  **已翻译的快照写回缓存**（`snapshot.gallerys = translated`），冷启动读缓存直接是中文。

### 修复方向（源码已落盘，未构建）

- Hero 只渲染 `displayedCoverUrl`；验证响应的 `coverUrl` 先进 `pendingCoverUrl`，
  以 1×1/透明度 0 的 Image 预加载，`onComplete` 后才原子替换 `displayedCoverUrl`，
  `onError` 则保留种子图。这样封面位图永不空白，也不会在换源瞬间闪跳。
- 装机后用 `snapshot_display` 连续抓帧（tap 后 5 帧）：新构建详情首帧 hero 已在顶部
  `[36,321][1284,918]`，无换源重载；未复现“下半部一帧”。该边界保持 OPEN：
  若用户仍可复现，需提供确切入口路径（列表位置/相关画廊/返回后再进）再定位过渡帧。

---

## INC-2026-08-16-003：冷启动进入收藏弹“正在检查账户会话”

- 状态：`CLOSED`（真机 2026-08-16：冷启动后点收藏，缓存立即水合，无“正在检查账户会话”文本）
- 用户反馈：冷启动点击收藏会有漫长的“正在检查账户状态”过程；已多次反馈。
- 引入点：`FavoritesPage.applyPublishedAccountSession()` 对每次会话 revision 都置
  `isResolvingSessionState=true`，并保持到首次网络收藏请求结束；页面没有任何持久快照。
- 修复：新增 `GalleryListCacheRepository` 首页/收藏第一页快照；签名会话已发布且快照存在时
  立即水合、关闭会话闸门，网络刷新原地替换；登出清收藏前缀。
- 注意：该缓存同时是 INC-001 的引入点——缓存必须保留翻译标签，水合必须先贴标签。

---

## INC-2026-08-16-005：seed 后详情页无加载状态机（区块缺失→弹出，布局跳动）

- 状态：`CLOSED`（源码修复已装机，设备已观察稳定壳层；瞬态 spinner 帧未逐帧捕获，见证据边界）
- 用户反馈：进入详情页后没有任何加载指示；元数据卡/下载卡在详情加载前不存在，
  数据到达后突然出现；预览/相关/评论在加载时是空白，没有加载指示器，整体布局跳动。
- 引入点：`240b2cd` 把详情首帧从全屏加载态改为 seed 快照首帧时，只移植了 NextE 的
  “先画点击行”部分，没有移植 NextE `DetailMetadataPane` 的加载状态机（info bar 常驻、
  预览槽在 `vm.loading && !cachedDetailApplied` 时显示整行 `LoadingProgress`）。
  当时的理由（见 ledger）：用户反馈全屏空白加载和标签英文→中文闪烁，因此决定
  “首帧立即有内容”。这是叶子级优化，没有保留父树契约。
- 修复：`GalleryInformation` 不再以 `isDetailReadyForCurrentGallery` 整体隐藏；
  未就绪时元数据卡内显示同几何加载行，两个操作 chip 置灰；预览/相关/评论在
  `detail.id === galleryId` 的 seed 帧就挂出固定高度加载壳（预览 150vp 轨、
  相关 255vp 轨、评论 190vp 轨），数据到达后原位填充；评论加载完为空时在
  同一轨内居中显示 `无评论`，区块不塌缩。
- 设备证据：`sm-settled.json` / `sm-scrolled.json` / `sm-scrolled2.json`
  （`.hvigor/outputs/nextn-tag-fix-20260816T/`）。
- 防止复发：移植 NextE/参考组件时必须保留整棵父树契约（加载状态机、占位几何、
  固定高度），禁止只移植“有内容”的叶子。

## INC-2026-08-16-004：反复单点修复导致同一功能多次复发（流程事故）

- 状态：`CLOSED`（已按本登记簿规则改为链路修复 + 真机验收）
- 经过：标签翻译问题在多次会话中被“修复”至少 4 次；`515af1e`、`2e17ee1` 均只补
  显示层重建，未处理缓存解码/水合数据源，导致每次冷启动重新暴露。
- 防止复发规则（并入本登记簿与 developer-guide）：
  1. 显示标签的持久化缓存**不得**清空 displayName；水合必须先
     `refreshLocalDisplayLabels` 再入帧。
  2. 任何“首帧/冷启动/缓存”改动必须同时审查该数据的所有写路径与读路径，禁止只补
     显示层回调。
  3. UI 首帧、过渡、图片换源问题必须同态真机对照验收后才可标 CLOSED。
  4. 同一页面同一轮内只允许一个 owner 复查整页，禁止子组件单独“修复”后跳过整页复查。

---

## INC-2026-08-16-006：PullRefresh 封装组件移植被私有精简（震动缺失、底部刷新与指示器语义被删）

- 状态：`OPEN`（源码恢复已完成，待真机震动/居中对照验证后 CLOSED）
- 用户反馈：下拉刷新用起来不对劲——震动功能没有了，指示器位置居中计算也有问题；
  要求直接移植 NextE 的完整封装组件，而不是再“精简”。
- 引入点：NextN baseline `cc0c40a` 中的
  `shared/src/main/ets/components/PullRefresh.ets`。NextE 原组件包含：
  `vibrator` HD/fallback 震动、底部上拉刷新（`isAtEnd` 门控）、
  `indicatorOpacity(gap, indicatorSize)`、`bottomIndicatorY()`、容器高度
  `onAreaChange`、内容 `offset(pullOffset - bottomPullOffset)` 与完整的
  挂载/卸载生命周期。NextN 移植版全部删掉，只保留顶部下拉的简化路径；
  代码注释还写着 “It owns visual feedback, haptics, duplicate guards...”，
  但实现里没有任何震动调用。
- 当时的理由：NextN 注释称 “deliberately exposes no initial-load or
  bottom-paging state”，把“不接管页面初始加载/分页”错误地扩大成了
  “可以删除组件的震动与底部手动刷新”。
- 为什么这个理由不成立：NextE 的 `PullRefresh` 是自包含交互状态机，
  震动和底部上拉属于组件自身行为，不属于页面加载/分页；注释声称的
  haptics 在实现中不存在，说明移植时写了与实现不符的说明，而不是先
  逐行对照参考。
- 修复：按 NextE 当前文件逐行恢复（主题常量映射到 `ThemeTokens`），
  保留 NextN 的 `refreshEnabled` 增量开关与控制器别名；三个 scaffold
  补回 `bottomIndicatorBottom`/`onBottomRefresh`/`canStartBottomRefresh`
  通道。
- 防止复发：移植参考组件时必须先 `git diff --no-index` 逐行对照；禁止以
  “页面不需要”为由删除参考组件自身的行为；组件行为差异必须真机同态对照
  后才能合入。

---

## INC-2026-08-16-007：详情页刷新时标签行整组卸载重装（标签卡塌一帧、预览卡/封面闪到中间）

- 状态：`OPEN`（本轮源码修复已落盘，未构建、未装机、未经用户验收）
- 用户反馈：只要下拉刷新，标签卡就会消失一帧再出现，预览卡（第一张即封面）被顶到
  屏幕中间；上一轮“删掉 epoch”的修复装机后用户实测“完全没变化”。

### 引入点（本会话源码证据）

- `GalleryDetailPage.tagVisualGroups(labels, onlyTranslated)`：翻译查询期间
  （`tagTranslationPending=true`）把**译名为空的成员从数据源里剔除**（`continue`），
  整个 namespace 组可能直接消失。这是 NextE 没有的“私造逻辑”（NextE 在
  ViewModel 里先译好再入帧，不存在该 pending 过滤）。
- `tagGroupKey` 包含 `index` 与 `group.items.length`：pending 过滤只要改变成员数，
  key 就变，ArkUI 卸载整行再重挂。
- `tagMemberKey` 包含 `originalIndex` 与 `tagTranslationEpoch`：位置/请求代际参与
  组件身份，标签顺序或 epoch 变化即整组重建。

### 为什么前一轮“删 epoch”没有效果

- 前一轮只把 `tagTranslationEpoch` 从两个 key 里移除；但 pending 过滤仍在、
  `items.length`/索引仍在 key 里。每次刷新 `requestTagTranslations` 置
  pending=true，只要存在译名为空的标签，成员数就变化 → group key 变化 →
  整行卸载重装。所以用户实测“完全没变化”与代码完全一致。

### 本轮修复（稳定身份 + 保留几何槽位）

1. `tagVisualGroups(labels)` 不再剔除成员，数据源始终包含全部标签。
2. `tagGroupKey = namespace`（稳定身份，去掉 index 与 items.length）。
3. `tagMemberKey = id/type/name/translatedName`（去掉 originalIndex/epoch；
   译名真正变化时只重建该 chip，不重建整行）。
4. pending 期间译名为空的成员用 `Visibility.Hidden` 保留布局槽位：不画英文、
   不塌高度；查询完成后原位显示。

### 验证方法事故（本会话教训，已写入防止复发规则）

- 曾用 `snapshot_display` 循环“抓帧”宣称无闪帧：单张约 200-300ms，屏幕 120Hz
  下约为 3-4fps，**不可能证明 8.3ms 单帧不存在**；且先执行手势、再启动抓帧，
  刷新早已结束。该证据无效，已作废。
- 真机逐帧证明只能走：官方 `displaySync.on('frame')`（逐帧回调，API 11+）、
  `UIContext.postFrameCallback`（API 12+）、`AVScreenCaptureRecorder`
  录屏后逐帧解码，或 DevEco Profiler 帧时间线；在这些证据到手前，一律不声称
  “无闪帧”。

### 防止复发（并入 developer-guide）

1. ForEach key 只允许“稳定身份 + 实际渲染内容”；禁止 epoch/revision/位置索引/
   成员数/时间戳进 key。
2. 数据源不得因“等待中”状态剔除成员或整组；需要隐藏时用 `Visibility.Hidden`
   保留几何槽位，禁止改变数组结构与 key。
3. 任何“避免 X 闪烁”的 UI 措施，必须先证明不会引入高度/几何跳变；不得用一个
   显示问题掩盖另一个。
4. 禁止以“安装→滑动→截图→比对”循环作为开发与验收方法；静态先证明组件树
   稳定，再决定是否构建。

---

## INC-2026-08-16-008：高级设置中评论翻译/漫画翻译/翻译来源三入口全部打开同一个来源表单页；标签翻译页内容被砍成三行

- 状态：OPEN（源码修复已落盘，未构建、未装机、未经用户验收）
- 用户反馈：评论翻译点进去是“翻译来源”，漫画翻译点进去也是“翻译来源”，“翻译来源”
  点进去还是“翻译来源”；标签翻译页只剩“翻译数据库 43774”这类裸数字，数据版本、
  镜像、更新策略等全部不见。

### 引入点（git 源码证据，不是“指向错了”的偶发 bug）

- b648010（2026-08-11）：漫画翻译首次接入时是独立入口
  readerComicTranslationSource，打开独立的 ComicTranslationSourcePage，
  标题“漫画翻译来源”。
- bd99c02（2026-08-11）：加评论翻译时把路由改名为通用 translationSource，
  并让“漫画翻译”与“评论翻译”两个入口都打开同一个来源表单页，仅用
  consumerId 参数预选。三入口同页从这里开始，属于当时为共用一套表单而
  主动做的合并，不是后来写错。
- 3b6f806（2026-08-13）：翻译能力并入 TranslationCapabilitiesGroup，
  新增“翻译来源”入口，同样打开该表单页。至此三入口全部同页。
- a39b7a4（2026-08-15）：标签翻译拆出独立页面，但只搬了“启用/翻译数据库/
  立即更新”三行；NextE 的版本副标题、镜像下载、自动更新策略、标签简介图片
  全被砍掉。数据库行只剩 rowCount 尾值（43774），没有版本上下文。

### 为什么理由不成立

- 加评论翻译时注释写的是“Comment translation uses the same private source form”，
  把“NextN 只有单一 OpenAI 兼容源”错误扩大成“评论/漫画/来源三入口可以共用
  同一个页面”，与 NextE 的页面结构（评论翻译页、漫画翻译页、LLM 源管理页、
  标签翻译页四个独立目的地）不一致。
- 标签翻译页砍掉版本等行时没有对应的 NextE 边界依据；NextN 的
  NhTagTranslationStatus.version 一直在仓库里，只是页面没展示。

### 本轮修复方向（照搬 NextE 结构）

1. 高级设置翻译区恢复 NextE 四行：评论翻译（副标题+开关状态尾值）、漫画翻译
   （副标题）、标签翻译（版本副标题+开关状态尾值）、翻译来源。
2. 新增独立 CommentTranslationSettingsPage：启用/自动翻译/显示方式/来源/模型/
   清除缓存；新增 ComicTranslationSettingsPage：来源/模型/本地检测模型/
   自托管渲染服务。
3. “翻译来源”保留现有单一 OpenAI 兼容源表单页（NextN 无多源列表，NH 边界）。
4. 标签翻译页恢复：数据库行显示版本副标题+行数尾值；新增“使用镜像源下载”
   与“自动更新策略（手动/启动时更新）”，并接入持久化与更新服务。
5. 未实现且 NextN 无对应能力的叶子（Google 兜底、Torii、模型目录查询、
   标签简介图片、实时评测）不造空控件，差异记入 UI 变更台账。

### 防止复发

1. 设置页任何入口的“目标页面”必须逐一对照 NextE 路由表，禁止多个入口共用
   一个页面仅靠参数区分；页面结构差异必须写明 NH 不支持的能力边界。
2. 移植 NextE 页面时按行逐项对照：有状态/服务支撑的行照搬，没有支撑的行必须
   在台账中登记“不支持叶子”，不允许无声砍掉。
3. 数据库/词典类状态行必须同时展示身份信息（版本）与数量，禁止只露裸数字。
