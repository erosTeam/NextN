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
