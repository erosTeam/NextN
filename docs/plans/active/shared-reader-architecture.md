# NextE / NextN / Koma 共享阅读器设计草案

## 当前目标：逐步具备替代现有阅读器的能力 — 2026-09-06

用户最新要求“继续啊，要慢慢完善，以替代当前阅读器为目标”。因此可选接入是安全实施方式，不是项目终点。最终要由共享实现承接现有阅读器能力，消除三个副本间的功能退化；当前仍不得提前切换默认入口或修改持久设置/进度。

推进顺序沿用原设计：先完成共用布局/输入/失败恢复及锚点行为，再接正式共享chrome与缩略图导航，随后按宿主端口补系统输入、图像处理、下载/分享与Koma章节编排；最后才做显式可回退试用、设置/进度兼容和逐宿主替代验收。每个能力记录真实缺口与设备证据，不能以诊断页、构建或“共用组件”作为替代就绪证明。涉及持久数据/默认切换的实际启用时机单独决策，不在基础组件完善时顺带迁移。

在共享基线4a17aed上补齐连续缩放的旋转保位，68项core测试。237原生04复现清掉约1.8x缩放；候选N06/N09原图普通点与已到达的平移边界、E07b原图/E08精灵图均已检查完整旋转往返截图与native坐标，复位后的新滚动也有N实证。只冻结这些端点，不据此宣称正式横屏布局或完整D3通过。下一切片是正式共享阅读界面的工具栏显隐、页码/跳页，先映射参考完整父树，再可选试接。237主验，197仅补充；Koma生产任务独占197，不重复compile-only，其生产签名构建单独协调clean共享窗口。

## 最新切片：D8 宿主输入端口 — 2026-09-06（限域验收，替代目标 OPEN）

- 中性ReaderInputPort只同步发送逻辑previous/next，不含平台键码、不排队旧命令；连接代次避免旧surface释放新所有者。共享surface按既有视口锁、active、touch、菜单和seek预览仲裁，宿主拥有ReaderVolumeKeys注册/释放。N/E仅显式Debug Want启用，不改正式偏好或默认阅读器，不自动跨章。
- 81项core测试通过；237 N03/E04各1项原生测试通过26s866ms/26s223ms，均实看9张整屏与native根。实际按键1→2、RTL3→2，菜单/缩放时拒绝翻页；TestAbility后台后同窗口/同P2缩放保留，真实双指缩回后新键到P3，连续模式到P4，退出恢复宿主。N01的第二次双击实际12x，测试把双击当复位导致失败，已保留反证并修正测试，不改产品缩放周期。
- 独立N05/E06退出归还测试各1项通过10s336ms/10s156ms，均检查3张整屏及native系统媒体音量条window24。阅读按键不改音量；关闭后系统按键从基线4变5，finally反向键恢复4，窗口385/387恢复普通Browse/Gallery。不是仅凭off日志接受。Nmain2/E main1和最终native3/native2均构建成功；E集成改动继续保留未提交。
- 限域冻结上述端点；按住拖动/seek/旋转组合、注册失败注入及Koma当前输入仍OPEN。下一切片按宿主动作边界推进：先映射参考工具栏/菜单完整父树，区分作品分享、原页图片分享/保存/信息和章节操作，不能做万能回调或在core内放网站/系统分享业务。默认替换与持久迁移仍另行决策。

## D7 缩略图恢复仲裁 — 2026-09-06（历史限域验收）

- 显式 Debug 参数仅让指定缩略图返回一次不存在的本地 URI，触发真实 Image 解码失败；Retry 仍调用真实宿主资源服务。不删缓存、不修改网络、不替换默认阅读器，也不把它称为传输故障验证。
- 237 N04/E03 最终原生测试各1项通过（10s080ms/8s784ms），均检查5张完整截图与同宿主native根。失败P2旁的P1已真实解码，重试后P2恢复而主图保持P1、邻图和chrome保留，再单独点P2才显示原图P2，退出恢复普通宿主。原生子按钮已正确仲裁，没有新增手势拦截或布局补丁。
- E02的Image节点存在但P1精灵图未解码，不能接受为已加载邻图；保留该反证。验证现在等待已有会话由native onComplete(loadingStatus=1)驱动的displayed状态，仅给原页码Text增加诊断id，无新状态或可见节点。原始PNG像素也确认E03的P1/main/header在重试前后完全保留。79项core测试通过，N/E最终签名主包与测试包均成功。
- 下一切片：系统输入端口与音量键翻页。宿主拥有注册/释放，共享surface仲裁active、缩放/拖动和暂态跳页，逻辑前后页不随RTL反向。先核对现有E/N来源与官方系统输入接口；不迁移偏好、不自动跨章。完整Koma chrome、其他宿主动作及最终替代验收继续OPEN。

## D6 暂态跳页预览 — 2026-09-06（历史限域验收）

- 共享三组件只新增暂态预览事件与 unit/navigation 校验，拖动期间定位缩略图，不提前推动主图或阅读观测。End/Click 才提交；Cancel、后台、卸载或旧导航令牌均废弃预览。缩略图可见资源范围由原生 List 管理，松手不再先缩成单页而重新加载可见邻图。
- 237最终 candidate3：N25完整271帧显示预览1→9且主图保持1，253帧才换页，261帧原图就绪，可见缩略图全程保留；N26完整图/root确认9/14。E21完整288帧显示长列表预览117→396实时定位，主图保持117直到释放，未知缩略图仍按真实请求加载。短拖参考E14也延后动画的反证已保留；真正改用直接定位依据是E17持续拖动仍不跟随，不推定内部List故障。
- N23/E22各1项真实后台中断/恢复/RTL新拖动原生测试通过（20s303ms/20s407ms），均检查5张完整图与native根。恢复保持原窗口、RTL、栏和第1页，新拖动分别读到第3/61页，退出回普通宿主。E22导出目录错误已记录并仅取回原缓存文件，没有重跑掩盖。79项core回归通过，N/E签名主包和测试包均已完成。
- 下一未验边界：错误缩略图重试与整个阅读视口点按的仲裁；先核对既有错误动作所有者与参考，再用真实失败注入检查，不改已冻结几何。拖动中旋转/unit替换、Koma完整chrome和宿主端口仍OPEN。默认阅读器与持久设置/进度不变。

## D5 缩略图导航 — 2026-09-06（历史限域验收）

- D4检查点共享5949202 / N771a9fa。D5新增有界辅助缩略图资源窗口，只复用已准备目录，始终独立于主图槽位/阅读观测；79项core测试覆盖释放、迟到、独立比例、精灵裁切、不支持、精确重试、不改阅读页。
- 同一个共享栏按E参考140vp List、118vp缩略图、4vp间隔、18vp页码叠在原底栏上方。N独立缩略图195×354px不套用165×2120px长原图；E源格502×354px与生产参考一致。双页按实际包含的两张源页高亮，与N现有语义一致。
- N05/E06各1项原生测试通过（29s292ms/27s099ms），均已检查8张完整截图及native根：浏览后续缩略图不改当前原图，点选才跳转，RTL/收起/重开保留页码，关闭回原宿主。N09选P3显示P3/P4；E11同P117/P118的主图、轨道、页码、进度栏坐标与当前生产E03相同。N10/E12系统返回也已检查。N截图“区域缺失”的初始判断是agent预览误读，已用原始PNG像素与独立截图否定并撤回，没有改动产品去规避。
- 下一切片：滑块按住期间的暂态预览与缩略图定位联动，不能提前推动主图/进度；验证释放与取消/旧unit迟到提交。缩略图失败按钮、后台/旋转浏览位置、Koma派生缩略图及完整chrome端口仍独立OPEN。不提前启用默认替代或迁移设置/进度。

## D3/D4 earlier slices — 2026-09-06（以下为历史记录，当前以上段为准）

### 新增：D4 正式共享界面第一切片 — 2026-09-06（限域验收，替代目标 OPEN）

- `ReaderSurface` 只组合已有分页/连续视口及会话回调；`ReaderChrome` 独立拥有显隐/滑块预览，发出关闭、运行策略和原始页跳转意图。`ReaderPagedSession.seekSource` 用原始页码和 unit/navigation 防迟到提交，同页重选回到起点，不冒充已显示/已保存。72项core测试通过。
- N/E仅显式Debug Want `readerLabChrome=true` 打开全窗口试用，旧Lab和默认阅读器保持原入口。宿主保有导航、安全区、前后台状态和窗口恢复；暂时不写设置/进度。共享手势新增单/双击互斥及双指/平移尾事件隔离，N06真实失败与N07修正回放均保留。
- 最终候选N mainbuild5/nativebuild3、E mainbuild4/nativebuild2在237各执行2项原生测试，分别30s441ms/30s317ms、0错误。已检查同页缩放复位、LTR→RTL原始页1→2→3→2、浅/深背景描边页码与退出截图及native根。E11与当前生产参考E03同P117/P118、同1320×2120根，两幅原图均为[0,827][660,1294]/[660,827][1320,1294]，进度条与布局动作组位置一致；分享/更多等未接叶子明确缺失，不据此称完整对齐。
- 下一步继续共享缩略图导航：先记录E/N当前缩略图栏完整父树和独立比例/精灵裁切语义，再接有界缩略图资源窗口及原始页跳转。滑块按住期间预览、错误Retry与新增点按竞争、全屏/旋转/后台组合、Koma正式chrome及章节动作仍各自OPEN。不得提前切换默认阅读器或迁移持久设置/进度。

User clarified: use device237 whenever197 is unavailable;197 is supplementary cross-device verification, never a fixed prerequisite. Selected-item D3 is recorded in §11.2 at `07bc120`; `fa1954a` adds zoom/pan (§11.3), `220816c` native paging (§11.4), `c87f1e3` continuous reading/anchors (§11.5), `64a5d1f` per-row failure/retry (§11.6), and `e4be692` late-dimensions diagnostics (§11.7). Current `b603003` adds paged per-pane failure/retry,64 core tests and bounded N/E237 whole/spread/half runtime evidence (§11.8). Both Labs exited and237 lease is released. Koma compiles clean b603003; its prior selected-item197 evidence is not current pager/continuous/failure acceptance and197 belongs to its production task. Next boundary is continuous zoom/scroll arbitration, beginning with source/reference investigation. Production readers/default routes, preferences/progress migration and Koma chapter-state work remain excluded; complete chrome and full migration remain OPEN.

状态：D1 三方限域试接、D2 映射/原图观测切片已有证据，完整迁移仍 OPEN；2026-09-06 用户要求自主判断推进，禁止替换现有阅读器。

核对日期：2026-09-06。设计源码基点：NextN `7f79cb4`、NextE `89532d99`、Koma `2bb00cd`；D1 执行时三个工作区均有其他任务的后续修改。D1 只增加共享库、宿主适配器及独立调试入口，不改动现有阅读器、账户或进度存储实现。

交付范围：三方源码边界、功能归属、接口语义、迁移顺序与 D1 独立调试试接。本文不是“现有功能全部通过”的证明，也不授权替换三个应用的阅读器。

## 1. 建议结论

采用 **两个共享 HAR：`reader-core` + `reader-ui`，三个应用各自提供适配层**。Koma 从接口设计和试接阶段就参与，不作为 NextE/NextN 完成后的附加兼容对象。

- `reader-core`：阅读会话、页面身份与显示映射、导航意图、请求生命周期、预加载计划、设置合成和进度事件。没有 ArkUI 组件、应用数据库、网站 DTO 或路由。
- `reader-ui`：共享的 ArkUI V2 阅读界面与交互实现，包括独立的分页/连续/双页布局、手势、默认工具栏、缩略图和加载失败提示。功能与界面分层，但三个应用不各自重写这套默认界面。
- 应用适配层：网站或文件解析、鉴权、缓存和下载服务、持久化、系统能力调用、路由、分享和章节业务。

共享的是一个实现和明确的行为契约，不是三个复制品，也不是带有 `isNextE/isNextN/isKoma` 分支的巨型页面。能力差异必须能追溯到实际数据源或宿主能力，不能成为隐藏删减阅读功能的开关。

第一轮迁移保留当前已接受的默认交互。Koma 的无缝跨章、无效设置修复、进度存储改造属于独立的产品/数据变更，不在“抽取组件”过程中顺便改变。

## 2. 当前源码告诉我们的边界

以下是架构相关的源码盘点，不是三方完整运行验收表。表中“有实现”不等于已在本轮设备验证。

| 能力/问题 | NextE | NextN | Koma | 共享方式 |
| --- | --- | --- | --- | --- |
| 阅读会话入口 | Reader 自带 `HdsNavDestination` | Index 包装 destination | Index 包装 destination、准备章节 | 路由容器留宿主，共享 ReaderSurface 不再拥有应用路由 |
| 页目录 | 可稀疏加载的 EH 预览、逐页解析 | NH 详情页目录、下载优先 | 章节页列表、来源 hydration | 中性页目录端口，区分页数已知与元数据已加载 |
| 单页与连续阅读 | 独立图片组件 | 单页/连续共用 surface core，外层尺寸分开 | 分页与 webtoon、独立显示页映射 | 保留不同布局所有者，共享页加载状态 |
| 双页拼合、单双页规则 | 已有 | 已有 | 不能仅凭宽页切分认定具备同样双页行为 | 共享 display map；三方逐项声明实际能力并验收 |
| 宽图切成两次翻页 | 不由双页拼合自动等价得到 | 不由双页拼合自动等价得到 | 同一原页映射 left/right 两个显示项 | 原始页与显示片段分离；不能只保存显示数组下标 |
| 缩放、拖动、点击区域 | 有多处图片层实现及 transform helper | surface core 与 spread 分开 | 图片层和点击区模型 | 数学规则入 core；手势与布局反馈统一在 UI |
| 自动翻页、音量键 | 阅读器内部处理 | 阅读器内部处理 | 阅读器和偏好处理 | core 调度/命令，宿主注册系统输入，UI 仲裁手势 |
| 在线/下载/归档 | EH 在线、下载和归档 | NH 在线与下载 | 本地与多源在线/离线 | 资源端口；不把来源数量变成 Reader 的分支 |
| 大图加载 | 解析、缓存队列优先级、进度、解码等多阶段 | 私有文件缓存、请求去重；load 无进度/取消参数 | 多源解析、文件缓存、运行时请求头 | 共用状态机；传输真实性由适配器达标证明 |
| 缩略图内容 | 在线精灵图裁切，或本地图像 | 独立缩略图，可能只是长图局部 | 当前 Reader 从图源生成有界解码缩略图 | 独立缩略图描述，禁止推定与原图等比例 |
| 缩略图栏几何 | 固定图高 118，真实比例宽度 | 固定图高 100，比例/宽度有界 | 自有缩略图宽度和缓存 lease | 当前不是完全相同的 UI；迁移前明确保留项与可见变更 |
| 裁边/超分/翻译 | 含原图变体、屏蔽策略、超分和翻译业务 | 裁边、超分和翻译接入 | 有自己的设置和能力边界 | 共用处理阶段/呈现，具体服务按能力注入，不静默省略 |
| 错误/重试 | 普通与紧凑失败面板 | 普通/双页失败面板 | 自有错误呈现 | 同一默认组件及上下文尺寸规则，动作由可恢复方式驱动 |
| 分享、保存、图片信息 | 网站与图片动作 | 画廊与图片动作 | 书籍/章节业务不同 | 语义化动作；分享当前图片与分享作品不是同一动作 |
| 转场、全屏、系统栏 | 与应用转场状态耦合 | 与 Index、route epoch 耦合 | 路由与页面生命周期耦合 | 共用几何/阶段协议，系统窗口与路由操作由宿主执行 |
| 设置存储 | Preferences，E 自有枚举/键 | RDB，自有枚举/键 | Preferences，按作品接口当前仍落全局 | 中性运行设置 + 宿主映射；不重写既有序列化值 |
| 进度与已读 | 画廊页索引 | 画廊历史页索引 | progressByComicId 与独立章节已读状态 | core 发布锚点；最近阅读、逐章进度、已读由宿主分别存储 |
| 章节切换 | 画廊是单一阅读单元 | 画廊是单一阅读单元 | 显式前后章节回调；普通下一页受当前章节约束 | 中性阅读单元与边界事件；章节列表、排序、路由留 Koma |

两个必须记录的事实：

1. NextN 的单页/连续图层已经局部合并，但双页仍有独立加载逻辑；NextE 也有多处相似图片加载路径。不能把“页面文件搬入 HAR”当作完成统一。
2. Koma 的 `imageFit()` 当前把 `fit_width/fit_height` 都映射为 `Contain`，默认存储值却为 `fit_width`；`loadForComic/saveForComic` 当前明确作为全局设置的兼容别名，不提供逐作品隔离。这些是必须显式处理的兼容现状，不能仅凭方法名推定支持，也不能在迁移时悄悄激活旧设置。

## 3. 模块与状态所有权

```text
NextE 宿主 / NextN 宿主 / Koma 宿主
  ├─ 路由、窗口、业务动作、持久化
  ├─ Catalog / Asset / Settings / Progress 适配器
  └─ Koma ChapterCoordinator（E/N 不需要）
           │ 数据端口、命令与事件
           ▼
      reader-core  ←  reader-ui
      单一会话状态     共享默认界面、布局、手势
           ▲              │
           └── 布局观测 ───┘
```

| 状态 | 唯一所有者 | 禁止的第二份真相 |
| --- | --- | --- |
| 会话、单元、页面目录、导航目标、请求 epoch | core 的 ReaderSession | 宿主用双向绑定另存一套 currentIndex 并相互修正 |
| 已实际显示的页/片段、滚动锚点 | UI 上报观测，core 接收后发布会话快照 | 用“发出跳页命令”直接写成“已显示” |
| Scroller/Swiper、手势序列、实时变换、原生图片资源 | 对应 UI 布局/图片 surface | 每个业务应用再复制缩放和拖动状态；共享全局 PixelMap |
| 持久设置、历史、章节已读 | 宿主存储适配器 | HAR 自建应用无感知的第二套数据库 |
| 鉴权、源运行时、缓存文件、下载任务 | 宿主服务 | core 导入 NH/EH DTO、Koma 全局请求头或账户单例 |
| 章节排序、邻章可用性、目录、跟踪同步 | Koma ChapterCoordinator | core 用 chapterId 字符串猜测下一章 |
| 系统栏、亮屏、输入注册、导航栈 | 宿主平台桥 | Reader 在销毁时写死恢复某个默认窗口配置 |

UI 使用 V2 状态投影。core 的快照对调用方只读，操作走明确命令；高频手势不把每一帧搬进持久会话或应用全局状态。core 保留可测试的计算规则，UI 只持有本布局实际需要的即时状态。

可单独复用的 UI：`ReaderSurface`、默认 chrome、`ReaderThumbnailTile`、缩略图列表、失败面板。详情页可以使用 thumbnail 组件和目录端口，不必启动完整 ReaderSession。详情页横向栏/全部缩略图页的父级布局仍归各自页面，不能借复用 tile 改掉父级结构。

扩展点以语义化 action、主题 token 和少量明确 slot 为主。不开放“任意替换整棵图片/手势树”作为普通接入方式，否则会重新出现三套阅读器。

## 4. 中性数据模型与端口草案

以下是接口语义草案，不是已经编译的 ArkTS SDK；最终命名和类型表达在技术试接中确定。

### 4.1 身份和坐标

- `SourceScopeKey`：来源/账户隔离的非敏感标识，由适配器生成，不包含 cookie、token 或密码。
- `WorkKey`：作品身份；`UnitKey`：本次阅读单元。E/N 的单元是画廊，Koma 是章节或文件。
- `PageKey`：原始页稳定身份；`sourceIndex` 只表示当前单元内的零基顺序。源为一基页号时只在适配器转换。
- `contentRevision`：内容变化版本。临时下载地址、文件路径、签名 URL 不能作为唯一持久页面身份。
- `ReadingAnchor`：单元、原始页、片段与归一化页内位置；可附带用于找不到稳定页 ID 时恢复的索引提示。
- `DisplayItem`：由原始页生成的显示项，可能含单页、同一页的一个片段，或一个双页组合。它的下标随布局变化，不是持久进度。

页目录支持页数已知但部分元数据未解析，及页数尚未确定两种情况。未知尺寸不能默认为缩略图尺寸；元数据迟到引发布局变化时保持当前锚点。

### 4.2 最小端口集合

| 端口 | 关键操作/结果 | 责任边界 |
| --- | --- | --- |
| `ReaderCatalog` | prepareUnit、loadPageRange；返回单元描述、稳定页 ID、页数状态和元数据范围 | 适配 EH 稀疏预览、NH 详情和 Koma hydration；不会下载所有大图 |
| `ReaderAssetProvider` | acquire(request) → ticket；ticket 有结果、进度订阅、提升优先级、cancel；成功结果含可释放 asset lease | 来源解析、缓存读写和传输由宿主完成；取消与释放必须实际接入服务 |
| `ReaderProgressSink` | saveAnchor(event)、flush；结果可观察 | core 不判定整本漫画已读；存储失败不能假称已保存 |
| `ReaderSettingsPort` | 初始有效快照、外部更新订阅、patch 请求及保存结果 | 保留三应用原有键与数据；界面即时状态与持久化结果区分 |
| `ReaderUnitNavigator`（可选） | resolveAdjacent(unit, logicalDirection) | 返回 available / end / failed / cancelled，失败不等于没有下一章 |
| `ReaderProcessingPort`（可选） | 基于源版本和参数快照申请裁边/增强/翻译结果 | 调用权限和服务在宿主；变更参数不要求重新下载原图 |
| `ReaderHostBridge` | 业务动作、窗口策略申请/释放、转场准备、退出请求 | 原生资源/窗口接口放 UI 平台边界，不泄漏进 core |

最小用法形状：

```text
session = ReaderSession(catalog, assets, settings, progress, optionalNavigator)
surface = ReaderSurface(session, hostBridge, presentation, optionalActions)

session.open(unitRequest, entryAnchor)
session.navigate(next | previous | targetAnchor)
session.retry(pageKey, recoveryAction)
session.updateSettings(patch)

surface -> reportVisibleAnchors(...)
surface -> reportImagePresentation(pageKey, requestId, decoded | failed)
session -> positionChanged / boundaryReached / persistenceFailed / closeReady

session.close()   // 有顺序的停止、flush 与释放；宿主仍拥有最终路由退出
```

接口不要求 NextE/NextN 伪造章节，不要求 Koma 伪造 galleryId/token，也不让 UI 直接调用 app 的 ViewModel。

### 4.3 缩略图与原图必须分开

`PageDescriptor` 可以引用 `OriginalAsset` 和独立的 `ThumbnailDescriptor`。缩略图三种来源：

1. 独立图：自己的 asset key、尺寸，可能仅覆盖原图一小块。NH 属于这一类。
2. 精灵图区域：sprite asset key、裁切矩形、区域尺寸。EH 在线缩略图属于这一类；整张 sprite 尺寸不是 tile 比例。
3. 原图派生：源 asset key、有界解码/派生策略和结果尺寸。Koma 当前 Reader、本地文件可用此路径。

比例来源优先取该缩略图实际解码/裁切结果，其次取可信的缩略图元数据；均未知时临时占位，不能回退到原图比例。组件区分“容器尺寸策略”和“内容 fit 策略”，宽度受限不意味着可以拉伸图像。

目录分页和缩略图下载分开：详情栏继续加载后续目录范围，但只为可见和邻近范围申请缩略图。不能为“能看完所有缩略图”一次解码整本原图。

## 5. 页面布局与输入契约

### 5.1 三种布局不是一个尺寸公式

- 分页：外层是固定视口，默认完整容纳图像。长图不能因 `.width('100%')` 与裁切组合而失去上下内容。
- 连续：页面依据实际内容比例决定高度，列表负责滚动和虚拟化。不能照搬分页的固定高度。
- 双页：先按单元、单双页规则形成组合，再计算整体显示与缩放。joined/split 的语义与宽图切分成两个翻页项分开建模。

按宽/高适配若作为显式选项开放，超出视口的内容必须可平移/滚动访问；“适配宽度”不是“裁掉其余部分”。实际裁边是另一个可选的内容处理步骤，保留原始坐标到裁边后坐标的映射。

默认不跨章节配对双页；章节末尾单页不能为了凑双页吞入下一章。宽页拆分后的最后原页必须读到最后一个显示片段，才满足单元末端显示条件。

模式切换、方向变化、横竖屏和窗口变化都从稳定锚点重建 display map。源顺序、RTL 的物理移动、逻辑 next/previous 分开，避免 RTL 时“下一章”反向。

### 5.2 手势只有一个仲裁者

按图片 surface、组合 surface 和阅读视口分层处理输入；缩放图的拖动、翻页手势、点击区、双击、长按、滑块和按钮不能各自抢占同一事件。

- 错误重试按钮与菜单获得可操作命中区，不能被整屏点击层截获。
- 缩放状态与当前模式决定翻页是否可触发；不用业务应用补丁抑制重复触发。
- 自动翻页依据实际可见内容的可展示状态、手势/弹层/前后台状态调度，不把“请求结束”当成“图片可读”。
- 音量键/键盘等系统输入由宿主按当前有效路由注册，统一转成导航命令，离开后释放。
- 点击区配置是阅读设置；应用差异通过完整配置映射表达，不私自减少区域或动作。

## 6. 加载、失败与资源生命周期

加载和呈现使用关联但不同的状态：

```text
资源请求：queued → resolving → transferring → ready
                    └──────────────→ failed / cancelled
图片呈现：placeholder → decoding → displayed
                           └─────→ decodeFailed
```

每次请求携带 session epoch、unit key、page key、content revision、request id；增强请求额外包含参数版本。每个异步提交点检查身份，不能只在最外层 await 后检查。过期结果释放资源，不写回新章节或新账户的页面。

必须具备的语义：

1. 每个 ticket 有且只有一个终态。网络超时、取消、无数据结束、解码失败分别表达；进度未知不是 0%，连接停住不允许无限显示 loading。
2. 会话离开、翻页和重试取消的是本消费者。文件下载与阅读器合用底层任务时，阅读器释放 lease 不能把用户下载任务一起取消；最后消费者释放后的底层处理按缓存服务政策执行。
3. 请求去重、缓存键隔离和优先级提升由持有真实任务队列的服务实现。core 决定可见页/预加载需求，不再另建一个与宿主争抢资源的网络队列。
4. 必须有总时限/无进展时限及清理结果；仅外层 Promise 超时、底层请求仍占队列，不算链路闭合。既有服务不支持取消时，标为适配缺口，不能用忽略返回值伪装达标。
5. 原图、缩略图、派生图分别缓存。派生图键包含处理参数和源版本；改变超分参数尽量复用可用原图，不保留无限份 PixelMap。
6. 已显示的原图在可选增强失败时仍可读；“首次加载失败”和“已有可读图但增强失败”不是同一整页错误。用户显式切换图源时不得让旧图冒充新图成功。
7. 文件就绪不等于解码成功；渲染回调必须带同一次请求身份。长图解码、内存压力及滚动回收由 UI 与资源 lease 配合，不强制每页都转成长期持有的全尺寸 PixelMap。

失败 UI 用共享的可读背景材料与布局，保留已接受的转场透出效果；不改成不透明纯黑底，也不删掉背景回避设计。普通页、双页紧凑区和整页失败分别使用经过页面上下文审查的尺寸变体。后续可见变更需要整卡/整页截图，不用一个孤立按钮裁图验收。

重试动作由错误类型和 provider 能力给出：重试传输、重新解析、切换可用图源、打开宿主设置等。EH 配额/限速和 change source 不能退化成一律“重试”；NH 也不能显示没有实现的切源动作。用户取消不作为错误提示。

### 6.1 三个适配层必须先解决的缺口

| 适配层 | 当前证据 | 试接必须证明 |
| --- | --- | --- |
| NextE | 文件服务有优先级/进度，queued cancellation 不等于所有进行中传输可取消 | 当前可见页优先、旧解析不串页、队列和活动传输各自取消边界 |
| NextN | `ReaderImageCacheService.load` 没有进度/取消入参，force reload 会处理已有 flight | 真正取消/终态和重试去重语义，阅读与下载共存不互相卡死 |
| Koma | 来源适配器已有多源服务，但部分读取使用模块级请求头配置 | 请求开始时绑定来源/账户作用域，跨章或换源的迟到请求不会使用另一作用域 |

这三项不能在“已接上同一个 ReaderSurface”后被标记通过。

## 7. Koma 章节解耦与切换流程

需要共享的是**单元切换能力**，不是 Koma 的整个章节系统。

### 7.1 显式切换与普通翻页边界

章节目录、顺序、可用来源和用户的章节选择由 Koma 决定；Reader 发出逻辑边界意图。宿主提供 `ReaderUnitNavigator` 后，core 才能请求相邻阅读单元。

```text
当前单元 A 仍可读
  → 用户选择章节 / 发出末端继续意图
  → 宿主解析目标 B
  → prepare B（新切换 epoch，A 保留）
  → B 最小可用目录就绪：原子提交 active unit 与入口锚点
  → 加载 B 当前页；A 资源按窗口/预算释放
```

“目录就绪”和“大图已显示”分开；等待目标首图成功后才允许换章，会把图片网络失败变成无法进入章节。提交后若首图失败，应有 B 的明确错误和返回/重试路径，不能把 A 的缩略图当 B 的成功画面。

- prepare 失败：A 不被清空，显示目标切换失败，可重试或继续读 A。
- 快速点 B 再点 C：只有最新有效切换能提交；B 的迟到响应释放。
- next 默认入口、previous 默认入口、目录跳章与恢复阅读各自使用明确的入口策略，不共用含糊的 initialIndex=0。
- 预加载邻章不更新阅读进度、不标已读、不触发跟踪同步。
- 末端事件不是整本已读事件；Koma 自行合并逐章进度、手动已读覆盖和最近阅读指针。

### 7.2 无缝连续跨章作为独立能力

架构保留 `ReaderUnitWindow`：有界的邻近单元目录与资源窗口，每个显示项仍带 unit/page 身份。向前追加或向后插入章节时保存屏幕锚点，回收远端单元时也不能让当前位置跳动。

元数据窗口和图片/解码预算分别有界，不能仅以“最多三章”假定内存安全；单章也可能很长。具体页数、字节和解码预算在真实设备试接中确定。

这与“同一路由内换一章”不同。首轮可以只保留当前显式章节动作，但数据模型从开始就不能假设永远只有一个无身份的 pages 数组。普通翻页自动跨章与连续阅读无缝跨章的默认体验，需要实施到这一阶段时给用户选择，不在抽取中偷偷开启。

## 8. 设置、进度、动作与转场

### 8.1 设置和进度

设置按“库默认 → 应用默认 → 用户全局 → 作品有效覆盖”合成，作品覆盖保存字段补丁，不保存一份会冻结旧默认值的完整设置副本。读取三方原存储时保留其实际默认行为，不机械把 E 的 `ltr`、N 的 `paged` 和 Koma 的值写成新枚举。

Koma 现有无效 fit 设置与逐作品设置必须先定义迁移策略：用户明确选择过的设置与沿用默认但未生效的设置不能简单混同。不会在本文内实施或清除这些值。

core 发布的 `positionChanged` 至少包含 work/unit/page、片段、页内位置、原因和会话版本；只在实际可见观测成立后推进位置。跳到末页、末页图像仍失败、读完末页最后片段是不同事件。宿主定义何时算已读，库不擅自改用户原有规则。

持久化允许合并连续滚动事件，但切章、离开和生命周期边界有明确 flush。异步保存按同一作用域排序；失败可观察、可重试，不能让慢请求把较新位置覆盖掉。Koma 的逐章进度修复需单独数据迁移与冷启动验收，不能以一个新接口名代替修复。

### 8.2 动作与主题

动作区分 `shareDisplayedImage`、`shareWork`、`saveSelectedPages`、`showImageInfo`、`openChapterList` 等语义，带明确目标、可用性与执行状态。双页保存左/右/两页必须携带页集合；不会因为共享一个回调把两种“分享”又显示成难以区分的同名入口。

默认 chrome 和失败面板由共享 UI 提供，颜色、字号、间距、材质通过有边界的 token 输入；默认值参考当前已接受的 NextE 组件树。来源差异只替换对应动作/内容，不随意重排父级工具栏或提示卡。

现有 E/N 缩略图栏尺寸不相同，不能宣称已经同样验收。先记录两套现状；决定统一尺寸时列为可见变更，提交同状态、同视口的参考和候选整页截图，避免抽取时夹带重新设计。

### 8.3 转场和生命周期

共享 UI 报告当前图像的实际显示矩形、裁边/片段映射及可供转场使用的资源 lease；宿主负责目标缩略图是否在有效可见区域、路由身份、系统栏和目标视口。

关闭采用单次事务：停止冲突输入/自动翻页 → 准备系统栏和目标布局 → 测量当前有效目标 → 执行适用转场或普通关闭 → flush/释放 → 宿主完成退出。恢复系统栏后的目标可以不发生几何变化，不能把“必须变化”当作就绪条件；不得复用进入时坐标作为退出目标。

退后台、临时遮挡、弹层打开和会话结束分别处理。结束会话取消订阅与任务、释放 lease；系统资源恢复的是该次申请前的有效策略，而不是假定的固定默认。正在进行的下载属于宿主业务，不随 Reader 销毁。

## 9. 交付形式与迁移顺序

HAR 是编译期被宿主打包复用的代码/资源，不意味着三个已安装应用共享进程、账户、缓存或数据库。Huawei 的 [HAR 文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/har-package) 支持这一用法；依赖不得成环，资源需避免重名，公开类型涉及的 HAR 由消费者显式声明依赖。

共享源码使用独立本地仓库，D1 revision 为 `227ca3a`，三个宿主通过同级目录的两个 HAR 消费同一源码。当前仅本地技术试接：未创建远程仓库、未发布包，也未配置 CI 的共享库 checkout。三方试接补丁不能单独当作可发布生产版本；后续推广需固定共享 revision 并补齐分发/CI。库资源使用专有前缀，不依赖应用 AppScope；`reader-core` 不反向引用 UI 或宿主 shared。

核心/UI 成对发布，三个应用记录实际消费的同一候选版本，完成各自验收后才推广；不要一次升级所有应用来消除版本号差异。允许短期、明确到期的旧路径回退，不允许为每个 app 长期维护私有布局分叉。

| 阶段 | 具体交付 | 进入下一阶段的证据 |
| --- | --- | --- |
| D0，设计基线 | 本设计及源码定位，标明差异、产品决策和适配缺口 | 设计可评审；不声称代码或设备完成 |
| D1，技术试接 | 最小双 HAR 工程、稳定身份/目录/请求接口；三个宿主各接一个真实来源，不替换生产入口 | 三个真实依赖图均能编译；EH 稀疏页、NH 独立缩略图、Koma 章节/片段都不需要 app 特判 |
| D2，核心迁移 | 从现有算法提取 display map、锚点、请求 epoch、预加载和设置映射；完善服务适配缺口 | 行为测试覆盖真实提取逻辑；取消、迟到结果、切章、进度写入有可观察结果 |
| D3，共享 UI 接入 | 以 NextE 已接受父级树为起点，先一条可回退入口；N/K 同步试接验证接口 | 三种布局、完整长图、手势与失败态有设备证据；不能只完成单页就删旧实现 |
| D4，宿主功能补齐 | 原图变体/切源、下载/归档、增强/翻译、保存分享、设置、转场、Koma 显式章节动作 | 对各 app 的现有功能清单逐项映射到新入口；未覆盖项有旧路径且不对用户减配 |
| D5，分应用替换 | E、N、K 各自完成完整相关回归、独立提交和受控版本推广 | 消费同一已验证库版本；旧路径只能在全部对应能力验收后移除 |
| D6，可选产品增强 | Koma 普通翻页跨章/无缝连续跨章，设置有效性及逐章持久化修复 | 用户确认体验或数据策略后，独立实施和验收；不与抽取提交混合 |

D1 必须提前纳入 Koma，而不是把 Koma 留到 D5 才检查。D3 的试点只是缩小一次可见变更范围，不是先为 E 固化一个只能读画廊的 API。

## 10. 回归门槛：把反复出现的问题变成明确案例

不创建 UI 源码正则、组件形状匹配或合成布局脚本来证明“对齐”。纯逻辑测试执行被提取的真实算法/状态代码；视觉和手势通过真实应用、正确设备与页面验证。

| 风险 | 必要案例与观察 |
| --- | --- |
| 长图被按宽裁切 | 超长页在单页模式首次显示完整；主动按宽时上下可到达；连续模式高度正常；横竖屏均保持锚点 |
| NH 局部缩略图被原图比例拉伸 | 同一实际长图的详情栏、全部缩略图和 Reader 栏都使用缩略图自己的内容比例；未知尺寸加载前后也检查 |
| EH sprite 误用 | 多个 sprite 裁切区、边缘区、在线与本地下采样分别检查；不能拿 NH 的独立图片测试替代 |
| 请求/下载同时卡住 | 真实并发、慢响应、无数据结束、超时、离开、重试、恢复；任务确实释放/继续，不以一个下载完成代替原始停滞链路 |
| 错误与转场背景混杂 | 从缩略图进入后制造可恢复大图失败，审查整张提示卡、按钮命中、重试后的原图和返回转场 |
| 手势抢按钮 | 单页、连续、双页的缩放/拖动、点击区、错误按钮、菜单/滑块互不误触；恢复后正常手势仍工作 |
| 跨章串状态 | A→B→C 快速操作、B 慢响应、失败保留 A、逆向入口、无下一章与加载失败区分 |
| 片段进度丢失 | RTL/LTR 宽页两半、最后一页两半、模式切换/旋转/冷启动；进度仍指向正确原页和可恢复片段 |
| Koma 已读串章 | 预加载不写已读；逐章进度不被最近阅读指针覆盖；不因最后章节的一次跳页宣称整本读完 |
| 缓存/账户串源 | 同页标识在不同 source scope/account 下不复用错误资源；阅读器关闭不取消用户下载 |
| 功能静默丢失 | 每一现有菜单动作、设置项和来源恢复方式逐项保留；不支持的项明确说明并回到已有路径 |
| 转场/系统栏回归 | 当前可见目标、不可见目标、旋转后的目标、全屏进出与快速反向；记录有效视口和身份 |

设备计划以最新用户指令为准：237 是主验证及197不可用时的替代设备，197只做补充交叉验证，不作为Koma共享接入的固定前提。具体使用仍需实时目标、内容条件及协议。跨应用参考对照需要同状态、同有效视口；不同设备截图不直接充当像素或几何对齐证据。

最终 UI 结论附已经实际看过的截图/关键帧，标明设备、页面、候选版本和未覆盖项。构建、安装、源码相似和截图存在均不单独称为通过。库变更至少触发三个消费者的编译及受影响行为测试；高风险 UI/生命周期变更追加三方对应实机场景。

## 11. 决策清单与当前下一步

当前不需要用户为包名、接口命名或两层拆分逐项决策，采用本文建议继续细化即可。不会把尚未发生的技术试接写成成功结果。

需要在对应实施阶段取得用户决定的只有实际产品变化：

1. **Koma 的跨章默认体验**：第一轮迁移建议保留当前显式章节切换；普通下一页直接跨章、边界确认、连续阅读无缝衔接作为明确的后续体验选择。接口同时容纳这些策略，不因此阻塞核心设计。
2. **Koma 旧设置与进度的纠正**：让目前无效的适配/逐作品设置生效，以及逐章进度数据迁移，需要单独方案和数据保留规则，不能顺便改。
3. **现有可见差异是否统一**：例如 E/N 缩略图栏尺寸。先保留实测基准，真正要统一时提供整页候选供用户选择，不在本文里拍脑袋确定新的尺寸。

2026-09-06 用户确认进入 D1，限定为可选接入/调试切换。共享源码落在独立本地目录 `/Users/honjow/git/reader-kit`，三方通过同一源码 HAR 消费；正常 Reader 路由和组件保持不变。入口只接收 debug 构建的显式 `readerLabWork/readerLabUnit/readerLabPage` Want，不保存全局开关。NextN 试接在线 NH、NextE 试接在线 EH 稀疏目录/精灵图、Koma 首先试接既有本地/下载章节；实验会话没有进度或设置写入端口。

D1 当前为技术候选，完整迁移仍 OPEN：两个 HAR、三个独立 adapter/page、debug Want 路由均已建立。核心真实行为测试 9/9；三个宿主签名 Debug 构建通过。首次实机发现标题/系统栏遮挡，已标失败并按宿主已有安全区和标题预留方式重建，未改共享图像区域或生产页面。

- NextN / 237：678049 长条原图页 1→2，独立 NH 缩略图及恢复原图均 `displayed`，Back 回到 Browse。缩略图没有套原图比例；原图仅在诊断视口中完整 contain，没有宣称已有缩放/滚动。
- NextE / 237：4152165 原图、两个不同 EH 精灵区域均显示；从第 40 页快速下一页四次，最终第 44 页 `displayed`。退出后普通详情仍显示此前 `继续 P117`，普通按钮打开原有双页 Reader 的 117/398，不使用 lab 页号覆盖原进度。
- Koma / 197：真实 ONE PIECE 00话下载页 1→2 均 displayed；下一章 01卷缺少本地文件，明确失败；上一章恢复 00话第1页；Back 返回书架。普通继续阅读仍打开原 Reader 的 4/23，lab 前后 library 文件完全相同。主控检查了整张原图与恢复截图；197 已交回原 Koma 任务。缺少两章均本地可用的相邻样本，不能据此接受完整跨章成功路径；零页旧元数据但 manifest 完整的兜底、派生缩略图仍未接入。
- 237 证据根：`.hvigor/outputs/device-237__VDE-AL00/unknown/portrait-1320x2120/shared-reader-d1/`；03/04 为 N 修正后原图/缩略图，05/06/08 为 E 原图/精灵图/快速翻页，07 为 E 生产入口。当前只验证 portrait 1320x2120，不作未知折叠状态的几何结论。
- N 普通阅读入口补核在 09/10，仍进入原 Reader 而不是 lab。Koma 证据根为 `/Users/honjow/git/Koma/.hermes-artifacts/device197__ALN-AL80/not-applicable/portrait-1260x2720/20260906-reader-kit-d1/`，03/04/05/06/07/08/09 分别覆盖原图、翻页、缺章、恢复、退出、普通 Reader 和最后书架。

源码检查点：共享库 `227ca3a`；NextN 仅提交本轮入口/adapter/依赖/计划及本节验收记录，其他旧 WIP 保留。E/K 遵守各自提交边界，本轮接线保留独立可审查 diff。公开 build-profile 只应记录两个 module 行，绝不暂存本机整份签名 profile；本地 ignored profile 已同步 module 行。远程分发、CI checkout 和正式依赖锁定在发布前单独处理，不以当前本地目录假装已完成发布集成。

独立 review 指出的本地 URI 排除、逐页整章校验、EH 共享 VM 竞争和重试重复坏缓存四项均修正。消费者取消/底层取消仍显式区分；Koma 派生缩略图暂不启用，不用整张原图冒充派生结果。D2 当前增量见下节，D3 选中显示项增量见 §11.2；D4–D6 未开始，三种布局、手势、设置、进度、下载/处理能力的完整迁移均保留原路径。

### 11.1 D2 映射与原图观测切片（2026-09-06，限域验收）

用户要求普通技术选择自主推进。本切片先落实单元内显示映射和锚点，以及已确认的 Koma 零页目录/本地 manifest 适配缺口；不新增生产入口、UI 开关或持久设置，不替换既有 Reader。

- 参考规则：NextE `ReaderSpreadResolver` 与 NextN 同名 resolver 的源页配对/封面对齐；Koma `buildReaderDisplayPages` 的分页半页展开、`READER_WIDE_RATIO=1.2`。这三个规则不由一个 `isKoma` 分支表达，输入为中性 `ReaderDisplayPolicy`。
- 新增 `ReaderDisplayMap`：同一单元内 single/spread/continuous 拓扑、原页稳定身份、逻辑 next/previous、独立 RTL 左右呈现。spread 和 continuous 不消费分页拆宽设置；完整长图和未知原图尺寸不从缩略图比例推断为宽页。
- `ReaderReadingAnchor` 保存原图归一化位置和物理片段。元数据迟到、配对变化或插入页时优先恢复稳定 ID；完整目录缺 ID 与稀疏目录待补元数据明确区分。索引兜底必须显式允许，不能跨来源/账户/章节。返回映射只是导航目标，不是已显示或已读事件。
- 独立复核发现整页中心点首次拆分后未记选中半页，后续 RTL 会跳半页；已修正返回锚点并补连续恢复测试。映射检查点为共享库 `593b4ba`，当前 16 项映射测试和 15 项会话测试独立重跑 31/31 通过。没有激活旧 fit/逐作品偏好。
- 原图观测与请求/解码分离：`presentedAnchor` 只在宿主前台、当前 destination 可见、图像已解码且完整可见时更新；缩略图、失败和新单元准备不能推进它。观察值保留自身单元身份，不表示已保存进度或已读完。`assetRequestId` 与 command epoch 分开，保留 A 图等待 B 时，A 图不能被标记成 B 请求并用迟到回调确认 B。身份模型移至 `ReaderContent`，避免 Session/DisplayMap 循环依赖；旧导出保持兼容。
- 三宿主只增加 debug 内存前台信号和 lab route shown/hidden 接线，共享 contain 叶负责实际可见事件。当前实现不声称支持缩放/连续页观测，也不检测兄弟遮挡或系统窗口遮挡。独立复核两项 P2（仅解码当可见、旧图继承新 epoch）已关闭，无新增 P1/P2。
- 最终签名 Debug 构建：N `nextn-build-d2-observation-2.log`（10s963ms）、E `/private/tmp/readerk-d2-nexte-observation.log`（13s128ms）、Koma `qa/d2-adapter/build-final.log` 均成功；E V1 inventory 0/561。N 首次观测构建因组件保留名 `visibility` 冲突失败，统一更名 `labVisibility` 后成功；不是已接受候选。共享 HAR 串行构建，未混用中间包。
- 237 本轮：N 2/14 原图 `request=4 accepted=true sourceIndex=1`，Home 后 active=false，恢复后同页同资源 active=true；thumbnail 2→1 不产生新原图观测，恢复 original 1 才产生 request7/sourceIndex0。E 原图 1/398、sprite 2/398、原图 2/398 与前后台恢复均观察到；恢复时 request4/sourceIndex1 accepted=true。两者 Back 均返回各自生产首页并关闭观测。有效 app root 均 `[0,117][1320,2120]`，原始屏幕 1320x2120，fold unknown；主控逐张检查终点截图。证据根 `shared-reader-d2/` 下 02/04/05/06 为 N，07/08/09/10 为 E。最初截图后才读取日志为空，未标通过；后续使用实时采集及恢复后立即读取取得事件。
- Koma 新独立适配 helper 沿用 Index 当前 manifest fallback：正常非空目录不替换，DOWNLOADED/PARTIAL 读取已验证路径，CORRUPT 只保留缺页映射；不写库、不触发远端 hydration。6 组真实生产 fallback 输出对照及 adapter host 路径通过。NAV 的并行类型错误由其负责人修复，本任务未修改其生产代码。
- 197 按交接新租约独立验证最终包：ONE PIECE 00話 2→3/23 原图显示并 accepted，Home→resume 关闭/恢复观测且保留同页资源，Back 恢复三列生产书架与 4/23·17%；前后 library 文件逐字节相同。主控检查实际阅读和恢复截图，设备与共享构建窗口已交回。证据 `/Users/honjow/git/Koma/.hermes-artifacts/device197__ALN-AL80/not-applicable/portrait-1260x2720/20260906-reader-kit-d2-adapter/`；03b 为立即读取日志的恢复证据。
- 精确未验证边界：197 新鲜读取的四个已有 manifest 中，无“现存章节零页目录 + 完整下载”的样本；该新分支只有 host 验证，不能写成设备通过。两章均本地可用的连续切章与派生缩略图也未验。不会制造/改写用户书库样本来掩盖缺口。
- 后续安全步骤：在同一 debug 入口接入实际 display map/模式视口和基于实测位置的锚点恢复，再做三方同场景验证；预加载、设置适配等 D2 余项分别推进。三种布局视觉/手势迁移属于 D3，不因 map 测试通过就宣布完成；生产替换、持久进度迁移及跨章默认策略仍不授权。
- 持久检查点：共享 map `593b4ba`、原图观测与资源身份 `dfbda1f`。NextN 将本节、lab 接线和本轮协议/验收记录独立提交；NextE/Koma 试接继续保留可审查 WIP，未混入各自其他任务提交。共享库无 remote/发布，三方仍依赖本地 sibling 源码，不作为独立可发布构建。

### 11.2 D3 选中显示项视口 — 2026-09-06（限域实现，完整 D3 仍 OPEN）

- 共享检查点 `07bc120`：`ReaderPagedSession` 是唯一显示映射/锚点所有者，最多两个已有 `ReaderSession` 资源槽，单元目录只打开一次。选中项才取页元数据，不预先下载整章。`ReaderPagedViewport` 只负责像素与呈现/可见/失败事件，诊断按钮仍在独立 `ReaderLabSurface`；三个宿主 Lab 只替换会话构造类型，不改生产 ReaderPage。
- 视口输入是 whole、物理 left/right 或 joined spread。共同高度由有效视口和原图比例决定，RTL 只反转视觉左右。原生原图尺寸迟到可重建映射但保留稳定原页/物理半边；缩略图尺寸不进入原图拓扑。NH 独立预览和 EH 精灵图裁切仍走各自缩略图描述，不套原图半片。
- 可见事实采用 selection/slot/asset/fragment 四重身份。非选中双页先解码不能夺取锚点；新半页复用资源时仍可报告失败并强制重试；过期半页/资源不能污染当前页。换章准备失败保留旧像素/观测值及其旧单元身份，普通最后一项翻页不自动跨章。章节读完、历史、tracker、持久进度/偏好全部仍归宿主，Lab 不写入。
- 真实 core 测试40/40（16映射、15旧会话、9分页会话）通过，独立复跑及额外竞态/重入检查通过。初版 `Select.fontSize` 编译失败，按原生 API 改为 `.font({ size: 14 })`。独立预设备审查拒绝 ForEach 闭包绑定旧 snapshot 导致 spinner/比例不更新，以及同资源新半页失败不触发 retry；修正后才安装。首次 Koma 空目录实机又发现 `1 / 0`，明确标失败并改为 `0 / 0` 后复验。编译/测试不作为视觉验收。

237 实测统一身份：VDE-AL00，portrait1320x2120，app root `[0,117][1320,2120]`，fold unknown。证据根为 `.hvigor/outputs/device-237__VDE-AL00/unknown/portrait-1320x2120/shared-reader-d3/`，每一项终点原图由主控实看，N/E主链与Koma空态另有独立整页复核：

| 候选 / 证据 | 当前实际结果 | 不扩大的边界 |
| --- | --- | --- |
| N build4，02–07 | 完整长图；独立缩略图；joined双页、RTL、封面对齐后保留第二原图；single/Home/resume原位置；Back普通Browse。 | 03是菜单打开态，不能拿它证明关闭菜单全图。02模板误写build2，实际build4 HAP06:09:02产出、06:09:34安装；保留原记录和更正说明。 |
| E build2，08–14 | 原图whole→left→right复用slot1/request1；RTL保留right；sprite整区域不再裁半；joined RTL保留第二原图；single/Home同right；Back普通Gallery。 | 不代表动画帧、旋转或手势接受。 |
| Koma旧固定包，15/16 | 保留数据升级后普通启动仍是空书架；显式请求237缺少的真实章节进入failed。 | 16的1/0是失败证据，不计视觉通过。 |
| 最终 Koma build1，17/18 | 新计数0/0；点击Retry后明确failed、无残留spinner；Back空书架。前后library/queue路径均明确不存在，没有制造书库。 | 缺内容不是成功阅读；Retry不可能恢复不存在的目录，不声称图像失败恢复通过。 |
| 最终 N build5，19/20 | 同页NH独立预览在关闭菜单态完整显示，图像447×814px；非空计数正常；Back普通Browse。 | 原图仍是另外一张极长图，不能把预览比例借给它。 |
| 最终 E build3，21/22 | 第二原图在RTL joined左侧，原图1在右侧，共同381px高、相邻边x660；sourceIndex1仍为观测锚点；Back普通Gallery。 | 本次whole锚点没有经历拆分，不倒签为right半页测试。 |

- 最终三端串行签名构建 N5 10s105ms、E3 12s522ms、K1 9s172ms 成功；E V1 inventory0/561。K1构建源包13,407,533bytes、06:32:03，固定副本 `/private/tmp/readerk-d3-koma-final-signed.hap` 复制时间06:33:24；另一任务的 `rdr001-final-signed.hap` 不变。最终计数修正没有改任何非空文本/viewport表达式；旧主链包和最终冒烟包证据分别标注，不倒签。
- 197补充交叉：ALN-AL80，portrait1260x2720，app root `[0,124][1260,2720]`，fold not-applicable。真实ONE PIECE00話2/23经过single→joinedLTR→RTL→封面单/双→single/Home/resume始终保留sourceIndex1/whole；active=false回调被拒、active=true后同selection13/slot1/request1可观测。RTL实际pane为 `[39,1192][810,1781]` 和 `[810,1192][1221,1781]`，不同原图宽度、共同589px高且相邻。主控实看初始、LTR/RTL、恢复及Back书架整图；fresh reader-sessions先与生产任务末次基线相同，最终reader-sessions8,919bytes及library550,852bytes再与测试前逐字节相同。A00話23/23 completed/isRead=true、B01卷3/210 unread未变。证据 `Koma/.hermes-artifacts/device197__ALN-AL80/not-applicable/portrait-1260x2720/20260906-reader-kit-d3-cross/`，10个项目协议归本切片。
- 237租约 `20260905-220032-1008e7a4` 已释放且状态readback为released，三个Lab均退出；197独立QA回grid并释租，生产任务已确认接回并开始下一阶段。197只在可用窗口补交叉，不作为237前置条件，也不混算生产RDR验收；其后安装/页面状态由接续任务拥有，不能宣称仍停在本轮D3候选。
- 发布/范围边界：NextN只提交Lab接线和本切片记录/协议；E/K试接保留各自可审查WIP，未混入其他任务生产提交。共享库仍无remote/发布/CI checkout，三方依赖本地sibling源码；不是可单独发布的正式接入。
- 下一步：D3剩余的实际翻页容器与缩放/拖动输入仲裁、连续阅读/可见锚点、失败/工具栏完整父级树应继续在可选入口分块接入。每块有对照和回归证据后才向前推进；默认替换、设置/进度迁移、Koma无缝跨章策略仍不授权。Koma零页目录manifest fallback、派生缩略图、两章本地可用成功切章仍有独立未验证边界。

### 11.3 D3 选中项缩放/拖动 — 2026-09-06（限域接受，完整 D3 仍 OPEN）

- 共享检查点 `fa1954a`。`ReaderViewportTransform` 只拥有拟合内容几何和焦点/边界数学；`ReaderPagedViewport` 拥有暂态手势/动画，不是第二个阅读会话或持久进度所有者。joined Row 整体变换，手势位于固定 viewport；宿主控件/错误重试保持在变换之外。未修改三个生产 Reader、默认入口、设置或进度。
- 参考既有 E/N 拟合内容边界：双击2×→native→1×，native与2×相同时跳过重复档；pinch最大4–12×动态上限、弹性最小0.8、结束回1；放大后才允许pan。换页/物理半片/资源种类/显示策略重置，同资源状态更新和后台恢复保留；手势失活取消未结束的输入。原图全可见观测在缩放/动画中关闭，不伪造zoomed normalized anchor。
- 实际 core 测试47/47（40已有+7数学）通过，不能作为 UI 接受。N首次编译拒绝ArkTS构造参数属性、ArkUI保留成员名及可空tapLocation，修正后N build2 10s375ms、E build1 12s735ms成功（E V1 inventory0/561）。当前实现未在这些候选生成后改动。测试HAP build6 8s670ms只增加显式选中的手势用例；普通数据suite不会执行UI操作。Koma生产任务的独立构建消费同一源，只计构建、不混算缩放验收。

237实际身份均为VDE-AL00、portrait1320x2120、root `[0,117][1320,2120]`、fold unknown、AWAKE/86400000。证据根 `.hvigor/outputs/device-237__VDE-AL00/unknown/portrait-1320x2120/shared-reader-d3-zoom/`；主控实看以下终点整图及当前layout身份：

| 链 | 当前观察 | 限定 |
| --- | --- | --- |
| N02–06 | 原图1完整contain；2×；top/bottom y±135.67vp且x0；native12×后复位1×。 | 原长图上下两端均可拖到，不借缩略图比例。02日志filter中的管道被shell误解，缺失事件不算通过。 |
| N10/11 | 真实两指轨迹1.796×；另一次1.794×→1.000×，同页不变；各1test/0failure/0error。 | 原生PointerMatrix用当前语义viewport定位；日志及test退出前截图给出实际缩放结果，测试断言仅证明注入/页连续性。 |
| N12–15 | 2×top/Home/resume保留；改NH独立thumbnail恢复447×814px拟合；原图1放大后Next到完整原图2；Back正常Browse。 | 同进程恢复，不冒充冷启动进度恢复；未写阅读进度/偏好。 |
| E16–19 | whole基线；joined2×；两端x±208vp/y0，分别显示完整原图1/2到对应边缘。 | 共用Row和变换，非每页独立缩放；未把手势当成跨页操作。 |
| E20–23 | single/split恢复left `[304,743][1016,1613]`；非中心2× x29.34/y59.33vp（x按实际内容边界夹定）；Next到同原图right恢复拟合、slot1/request1复用；Back正常Gallery。 | sourceIndex0/right原图观测selection10接受；无放大态可见锚点声明。 |

- 自动化反例没有被隐藏：07零用例来自raw `-s class`与Hypium规范化日志混淆；09虽然1test通过，但便捷pinchOut(1.8)到12×，且runner退出后截图已是NextE，被拒绝为NextN证据。改成明确12步/600px/s双指轨迹，并在测试进程退出前保存native layout/screen，10/11才具有正确前台证据。未运行的过时08协议删除，07/09原始证据保留。
- N/E当前未放大whole/half/independent-thumbnail几何保持此前同样本同viewport父级契约，所有控制区原位；接受范围为上述终点。动画逐帧、旋转、pinch松一指后的连续pan、未来pager输入仲裁、zoomed锚点仍未验证或未实现，不扩大为完整手势保真。
- 237租约 `20260905-231641-d40f222c` 已释放并状态readback为released，两端退出Lab。197本缩放切片未操作；Koma真实章节缩放交叉在其生产任务自然空闲时补，不以197不可用阻断237或后续开发。Koma零页manifest fallback/派生缩略图/相邻本地双章成功路径保留各自未验证状态。
- 下一项：保留这份共享视口，在可选入口接入真实分页容器，先明确Swiper页缓存/核心资源槽与zoom手势的父子所有权及当前页锚点，再实现并按237真实手势验证。不得以简单滑动触发按钮冒充正式分页动画；连续阅读/工具栏、持久化迁移和宿主处理能力仍分别推进。

### 11.4 D3 原生横向分页与缩放仲裁 — 2026-09-06（有限路径验收）

- 共享父级：`ReaderPagerSurface` 的原生非循环 Swiper/LazyForEach 包住既有拟合视口；诊断控制、标题、章节路由仍在外面。没有三个宿主分别手写滑动翻页，也没有生产 Reader 替换。
- core 仍是唯一 display map/anchor owner。可选前一项/当前项/后一项窗口，双页最多六个不同原图槽；拆分相邻半页复用同一原图。旧拓扑/被后续命令取代的原生索引会被拒绝，decode 不算看到页面，缓存邻页不能抢原图观测，重试只针对当前显示项。
- UI 的当前项持有缩放锁；非当前缓存项清除缩放，前后台恢复保留选中项已稳定的缩放。Swiper 运动期间关闭观测。原生 onChange 出栈后再反馈，避免递归刷新 LazyForEach。
- 当前源码计算证据：实际 core53项测试通过，包含窗口上限、资源复用/释放、邻页不能观测、旧索引拒绝、迟到尺寸改图谱保持原图、缓存失败身份/当前项重试和副本隔离。N签名build2为11s025ms；E固定签名build1为13s630ms，V1 inventory0/561。构建不是设备验收。
- N237：完整长图基线一致；LTR1→2→1有真实原生index和sourceIndex观测；RTL单页/双页往返保持原图，独立双指约1.8×后新单指横拖不误翻页，缩回1×恢复翻页，2×top/Home/resume再横拖不误翻页。普通无参数启动返回Browse。原图和NH缩略图比例所有权未改。
- E237当前：候选whole原图1与安装前zoom候选同根视口/拟合尺寸；原生LTR从left到right仍是slot1/request1；RTL right1→left1→right2→left1→right1全过程索引与观测对应。16双页RTL next/back回到首组，原图2左/原图1右共同381px高。17双页2×横移/Home/resume后再横拖仍在首组，selection22、x-208/y0；完整截图与实际根视口均已查看。18 Back已核对普通Gallery，237租约释放并读回；197未操作。
- 原始异常保留：N04录制402帧全部查看，1196×1920编码与1320×2120应用截图不等，局部重影只算定性线索、不作精确几何或干净动效验收；原生N09缩放复位成功但布局文件残留旧尾部，原始JSON不冒充有效证据。测试只清理两个自身cache导出后重建8s842ms，09b完整JSON/原图2实图已核对。旧产物均保留。
- 生产构建隔离：LIB006、LIB007分别借用clean `fa1954a`窗口；只把七个本轮共享WIP安全stash，固定测试HAP后继续237物理链。Koma确认固定生产包并释放后自动恢复原WIP，不让生产包隐式消费未完成pager，也不把197作为前置阻塞。
- 下一边界：持久化本切片后，继续可选连续阅读视口及实际可见锚点。干净动效、剩余单指连续接力、旋转、拖动中图谱变化、Koma当前pager及宿主完整工具栏仍有独立未验证项；默认替换、设置/进度迁移仍不授权。

### 11.5 D3 连续视口与真实可见位置 — 2026-09-06（有限路径验收）

当前切片（2026-09-06）：可选连续视口已实现，58项真实core行为测试通过，N/E签名消费者已有237限域运行证据。复用同一session的catalog、display map和资源槽；原生List声明可见区间只驱动按需资源，不直接发布阅读进度。真正的原图观测必须同时满足宿主活跃、原生图片本次解码完成、该图是实际首个可见项、当前拓扑/导航/slot/request匹配，并由ListScroller局部几何换算原图归一化点。保留卸载图片的几何元数据以避免回滚到占位比例；普通翻页和连续滚动不再各自计算原图身份。

连续首批UI保持既有诊断父树，仅增加模式选项；List负责长图完整可滚动高度和当前单元内跳转，不跨章推断完成，不让宽图拆分设置影响连续模式。先接入滚动、模式/资产切换和位置恢复，再分别补连续缩放仲裁与迟到尺寸恢复；现有分页缩放不因新模式而削减。官方maintainVisibleContentPosition仅针对区外插删，不可冒充图片高度变化保位证明。

- NextN：实际16025px长原图从顶部经过39.25%、88.438%、98.295%到相邻原图；在首图尾部仍可见时不让预加载的第二图提前抢走锚点。原图2在NH独立缩略图→原图→单页→连续模式后保留y0.03001；缩略图1248x2271不借用原图1248x17299比例。快速Next/Previous、Home/resume、回普通Browse均有对应端点证据。
- NextE：实际连续行完整原图按762px高度衔接，滚动后的原图3保留y0.07261。首轮精灵图16被白边反例否决：实际画布4000x300被压进解析范围4000x284；对照当前EhSpriteThumbnail补上解码后画布尺寸，保持200x122裁切框/偏移/父行不变。18连续与19分页同裁切端点已查看，20原图4/Home恢复保持y0.03671。不得继续引用16为通过。
- 最后源码复核补上List本地native-ready表的slot/request门禁：旧回调不覆盖/删除新图的解码证明。最终Nbuild4的22保留原图1y0.09801；Ebuild3的24再次确认正确精灵图画布，25保留原图4y0.03524至Home/native onActive之后。23/26分别回普通Browse/Gallery；全页截图和实际根节点已查看，237租约已释放且readback确认。共享源码提交c87f1e3；原始截图留本地，提交仅存可复现manifest和判读记录。
- 未覆盖：连续缩放仲裁、迟到尺寸保位、220vp短行最低高度、旋转/折叠、性能/连续动画、注入迟到原生回调和Koma当前连续实图。Koma章节编排/完成语义/持久化仍由宿主持有；237主验证、197仅补充交叉验证。

### 11.6 D3 连续逐页失败与精确重试 — 2026-09-06（有限路径验收）

- 共享提交64a5d1f，61项真实core测试；retryItem按当前拓扑、可见项、slot及request epoch重试一张失败图，不选中邻页、不重开章节、不重载成功图片。尚未获取URI时assetRequestId可能为0，重试仍使用当前请求epoch，旧/重复/不可见/非活跃请求被拒绝。
- 只在连续行接入共享ReaderFailurePanel：复用NextE失败优先、加载互斥、220vp最低行高和196vp紧凑卡片完整结构，文字动作120x40vp。失败条漫不把小卡片放在万像素行的中间；健康原图/缩略图比例保持原实现。章节目录失败仍由外层处理；分页双图错误布局尚未接入。
- 237真实端点：N03完整P1卡片，04实点重试恢复16025px原图，05新request2/y0.02787前后台保持。E08在P1尾部仍可见时完整显示P2错误卡片；09实点P2重试，P1的[36,208][1284,970]、slot1/request1/y0.70104不变，P2独立恢复。10滚入P2后新slot2/request2/y0.14340前后台保持。全页截图及根节点已查看，N06/E11回普通宿主，237租约释放且readback确认；197未操作。
- Nbuild2为10s833ms，Ebuild1为13s044ms；首轮N构建的保留字段enabled冲突已改成retryEnabled，失败构建未安装。E的Lab新增一行显式探针传参，保留其原有未提交试接工作，未擅自提交E或改Koma宿主。
- readerLabFailPage仅对显式debug Want指定的零基原页注入一次已标注的render failure，再由真实provider forceReload重试。探针不破坏缓存/下载；这是UI与路由恢复证据，不是自然网络超时、配额分类、传输取消或转场背景合成验收。深色/大字体、分页错误、Koma当前故障UI仍OPEN。下一步先复现迟到尺寸保位风险；不引用List的插删保位标志冒充该保证。

### 11.7 D3 迟到原图尺寸的可复现验证 — 2026-09-06（有限路径验收）

- 共享提交e4be692，仅增加显式debug Want参数readerLabDelayMetricsPage、固定释放动作、四语文案和一个实际core行为测试。探针保留原生解码成功，只暂扣指定原图的尺寸通知；按捕获的slot/request释放，不抹除目录已有原图尺寸、不借缩略图补原图比例、不改缓存或List。62项core测试通过，Ebuild1 12s288ms、Nbuild1 10s022ms。
- 237 E03 P2先可见：原图[36,654][1284,1416]、slot2/request1/y0.11650，List[36,743][1284,1457]。04释放先前P1的1280x782通知后，P2这些值完全不变；05 Home后原生onActive10:45:48.268再上报相同点。06返回P1显示762px真实高度，确认通知确实生效，不是忽略了迟到更新。该端点没有漂移，不增加推测性保位代码。
- 237 N09已有720x9245目录原图仍为16025px高，[36,-275][1284,15750]、slot1/request1/y0.06705。10释放相同原生尺寸后画面坐标不变；11 Home后onActive10:51:15.908、观测10:51:15.925同点。两端释放动作前后均[480,1805][840,1925]，只变禁用态，不改变视口。全部整图及真实根节点已查看，E07/N12返回普通宿主，237租约释放且readback确认；197未操作。
- 证据：docs/device-protocols/shared-reader-d3-late-size-01至12及对应本地shared-reader-d3-late-size产物。仅接受受控尺寸通知顺序、已知尺寸对照和上述前台恢复端点；自然网络延迟、旋转/缩放组合、Koma当前实图和完整D3仍未验收。Koma消费同一clean共享点的编译另记，不升级为功能通过。
- Koma在协调窗口内仅构建，消费clean e4be692，hvigorw assembleHap --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon成功9s879ms/exit0；日志/private/tmp/readerk-d3-late-size-koma-build1.log。前后git status一致，无源码/配置改动、固定HAP覆盖、安装或197操作，窗口已释放。此项仅为第三消费者编译兼容，不是其当前连续/错误/迟到尺寸运行验收。

### 11.8 D3 分页逐页失败与精确重试 — 2026-09-06（有限路径验收）

- 共用既有ReaderFailurePanel及核心retryItem，不另造宿主重试状态机。失败单页采用完整视口；双页采用等宽独立恢复区域，正常图各自contain，不让控件继承条漫的63px窄框或横图拼合的127vp矮框。重试中保留恢复区域，全部成功后回到原来的共高拼合；失败重置缩放，卡片不可缩放，原生翻页不被锁死。生产入口、持久设置/进度、核心和连续List均未修改。
- 显式readerLabFailureLayout=single/spread扩展既有零基readerLabFailPage；省略或无效时仍是continuous，不改变原有探针语义。N/E宿主各加一行转发；Koma宿主不变。64项实际core测试覆盖错误半页/旧epoch拒绝及只重试失败邻页；Nbuild3成功9s965ms、Ebuild1成功12s630ms，E V1 inventory0/561。最初两次N编译的Want类型错误已修复，均未安装。
- 237 N02整页实看280vp卡片和120x40vp按钮；03真实Retry slot1/request1→2后原图完整contain至63x814px，无错误/加载圈残留。04恢复图2x/top在Home后保持。05误把三级双击的第二档当复位，只算12x拖图；05b实际复位至1x后原生翻页到P2，slot2/request1观测被接受。06返回普通Browse。
- 237 E08正常P1与失败P2等宽区域，完整196vp卡片/120x40vp按钮；09双击卡片不放大；10 RTL使P2在左，P1在右；10b/10c错误态下真实往返翻页后卡片及P1原生节点975/slot1/request1仍在。11只重试P2为request2，P1原生节点975、原图坐标[660,987][1284,1368]及选中P1不变，恢复为381px共高拼合。12共用2x/x208vp边界及Home保持；13换页复位并原生滑回完整拼页，14返回普通Gallery。
- 15至18宽图失败→拆分左半页→真实滑到右半页→精确0:right Retry也已实看：slot1/request1→2，原图0/right不变，完整右半页[304,743][1016,1613]，不是整图/左半页/下一原图。19回普通Gallery。主控逐一查看上述当前根节点[0,117][1320,2120]及整张截图，证据为22份shared-reader-d3-paged-failure协议和同名本地产物。237租约20260906-031104-c7ec2b7f释放且readback确认，197未操作。
- 共享提交b603003；Koma在协调窗口仅编译消费clean b603003，hvigorw assembleHap --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon成功9s577ms/exit0，日志/private/tmp/readerk-d3-paged-failure-koma-build1.log。其git status前后相同，无源码配置/暂存提交/固定HAP覆盖/安装/197操作，窗口释放。仅记编译兼容，不将自然网络超时、转场背景、深色/大字体、旋转/逐帧或Koma当前设备功能混算通过。
- 下一可执行边界是连续缩放与原生滚动仲裁：先对照NextE连续父树及现有List可见点契约，不能给每行独立缩放却让List继续按旧几何发布观测。普通阅读器/默认入口、设置进度迁移、Koma跨章策略仍保持原边界，完整D3继续OPEN。

### 11.9 D3 连续逐图缩放与原生滚动仲裁 — 2026-09-06（有限路径验收）

- 共享提交4a17aed，仅四个共享文件：新ReaderContinuousZoomImage、既有List接线、两项实际数学回归及README。原生List继续拥有滚动/真实行高，图片层复用ReaderViewportTransform与原图/NH独立缩略图/EH精灵图叶子；只变换图片，不变换错误提示和宿主控件。navigation/slot/request绑定单一缩放锁；放大、双指或动画中关闭List输入和未缩放坐标观测。稳定缩放跨Home保留，换页/资源替换/失败/宽度变化释放复位；核心仍独占阅读事实，三个默认阅读器和持久状态未改。
- 本轮不是全绿：E12实机证明放大后越出原行的可见部分拖不动，原始失败保留；据官方responseRegion契约将手势热区扩到变换后图片范围，13同坐标拖动出现pan且邻行不变。E15证明Next命令后曾接受旧P1坐标，按官方FrameCallback.onIdle等待下一原生布局帧，再解除位置门禁；19最终候选点击Next后只接受P2，不用最终截图掩盖中间错误。宽度/导航/disposal使旧帧回调失效。
- 66项实际core测试通过，包括5342vp长行偏心焦点及220vp最小行内真实图片边界；数学测试不算UI通过。最终Nbuild4成功9s460ms、nativebuild2成功8s253ms、Ebuild3成功11s452ms，E V1 inventory0/561。第一轮保留成员名transform编译错误已改名imageTransform，失败包未安装。
- 237为VDE-AL00、portrait1320x2120、root[0,117][1320,2120]、fold unknown。N23偏心2x及对角pan使图到x208/y2139.60，16025px原行不变且Home恢复；24双击经native1.731回1，再滚动得到slot1/request1/y0.14926。最终原生25双指1.796及新单指panx-165.57期间不发布旧坐标；26双指1.795→1后新List滑动到y0.10176。两类各1test/0failure/0error，退出测试进程前的整图及完整JSON已实看；这不是剩余手指不抬起的接力验收。
- E最终20b错误仍为220vp行、196vp卡片、120x40vp动作，21双击卡片不缩放，真实Retry只让P1 request1→2，健康P2/native918和762px原高保留。28–30在最终布局门禁候选上重放EH精灵图：P2使用实际4000x300画布/200x122裁切，2x及越行panx79跨Home保持，P3/native980原行不缩放且没有精灵图邻块泄漏；切回原图恢复P2完整762px和slot9/request1/y0。
- 本切片32份协议（01至31及20b）和同名本地shared-reader-d3-continuous-zoom产物保留实际失败与重测；主控已逐张查看上述整图及真实根节点。N27回普通Browse，E31回普通Gallery，237租约20260906-035605-fdba0c04释放并读回确认；197未操作，只作为空闲时补充交叉，不能阻塞237推进。
- Koma仅在协调窗口编译消费clean4a17aed：hvigorw assembleHap --mode module -p product=default -p module=entry@default -p buildMode=debug --no-daemon，exit0/9s342ms，日志/private/tmp/readerk-d3-continuous-zoom-koma-build1.log。git status前后相同，无其源码配置/暂存提交/固定HAP覆盖/安装/197操作，窗口释放，RDR003设备记录不变。仅接受第三消费者编译兼容，不冒充其连续缩放实图通过。
- 完整D3仍OPEN，下一未验证边界为宽度/旋转变化时稳定缩放的释放与原图局部锚点保位。剩余手指接力、迟到尺寸与缩放组合、完整工具栏及Koma当前运行路径分别保留；默认替换、设置/进度迁移和Koma自动跨章策略仍不属于本轮授权。不能拿上述端点宣称三个生产阅读器已经完全共享或完全对齐。

## 附录：本次读取的主要源码定位

行号以本次核对版本为准；后续以符号定位为主。

- NextN：[ReaderPage.ets](/Users/honjow/git/NextN/feature/reader/src/main/ets/pages/ReaderPage.ets:752)：`ReaderImageSurfaceCore`、`ReaderImagePage`、`ReaderVerticalImage`、`ReaderSpreadImageLayer`、`scheduleReaderPreload`、`persistProgress`、`ReaderThumbnailTile`。
- NextN：[NhGallery.ets](/Users/honjow/git/NextN/shared/src/main/ets/model/NhGallery.ets:73)、[NhReaderSettings.ets](/Users/honjow/git/NextN/shared/src/main/ets/model/NhReaderSettings.ets)、[ReaderImageCacheService.ets](/Users/honjow/git/NextN/shared/src/main/ets/services/ReaderImageCacheService.ets)、[ReaderSettingsRepository.ets](/Users/honjow/git/NextN/shared/src/main/ets/storage/ReaderSettingsRepository.ets)。
- NextE：[ReaderPage.ets](/Users/honjow/git/NextE/feature/reader/src/main/ets/pages/ReaderPage.ets:419)：destination、`publishReaderProgress`、`ReaderThumbTile`、`ReaderZoomCoordinator`、多个图片层与 `ReaderFailureOverlay`。
- NextE：[ReaderViewModel.ets](/Users/honjow/git/NextE/feature/reader/src/main/ets/viewmodel/ReaderViewModel.ets:81)、[ReaderImageSourceRequestGate.ets](/Users/honjow/git/NextE/feature/reader/src/main/ets/model/ReaderImageSourceRequestGate.ets)、[ReaderThumbnailGeometry.ets](/Users/honjow/git/NextE/feature/reader/src/main/ets/model/ReaderThumbnailGeometry.ets)、[ImagePipelineService.ets](/Users/honjow/git/NextE/shared/src/main/ets/services/ImagePipelineService.ets:65)、[ReaderImageFileCacheService.ets](/Users/honjow/git/NextE/shared/src/main/ets/services/ReaderImageFileCacheService.ets)。
- Koma：[ReaderPage.ets](/Users/honjow/git/Koma/entry/src/main/ets/pages/ReaderPage.ets:110)：`imageFit`、`ReaderThumbnailTile`、`canNext`、`nextPage`、`persistProgress`、显式章节动作；[ReaderChrome.ets](/Users/honjow/git/Koma/entry/src/main/ets/components/ReaderChrome.ets)。
- Koma：[ReaderSessionStore.ets](/Users/honjow/git/Koma/entry/src/main/ets/model/ReaderSessionStore.ets:100)、[ReaderDisplayPageDataSource.ets](/Users/honjow/git/Koma/entry/src/main/ets/model/ReaderDisplayPageDataSource.ets:12)、[ReaderPageSourceAdapter.ets](/Users/honjow/git/Koma/entry/src/main/ets/model/ReaderPageSourceAdapter.ets)、[ReaderPreferencesStore.ets](/Users/honjow/git/Koma/entry/src/main/ets/model/ReaderPreferencesStore.ets:541)、[Index.ets](/Users/honjow/git/Koma/entry/src/main/ets/pages/Index.ets:467)。
- 当前拒绝方案边界：[rejected-approaches.md](../../controls/rejected-approaches.md)，尤其 Reader 退出几何、系统栏时序和不透明错误底色条目。
