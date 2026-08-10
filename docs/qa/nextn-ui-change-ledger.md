# NextN UI 变更理由台账

这个台账记录可见 UI 的**理由和可追溯性**，不是静态合同、自动验收或视觉完成声明。
每次改动必须在代码改动前建立一条记录，并与该项 UI 提交一起提交。

## 必填字段

- 触发依据：明确的用户指令，或同状态、同视口的真实参考与设备证据。
- 父树边界：滚动宿主、固定/浮动层、节标题、容器、叶卡和状态转换的完整归属。
- 精确改动：原值/原树与新值/新树；不接受“调整一下”之类描述。
- 最小性理由：为什么不改相邻区域，以及 NH 不同的数据或能力边界。
- 验证计划：所需的当前设备和参考状态；构建或源码检查不能替代它。
- 若被否定：错误假设、忽略的证据、实际影响和禁止复发的约束。

## 当前表面状态（2026-08-11）

这是防止重复检查的工作登记，不是“所有页面都已对齐”的声明。开始任何 UI
工作前，必须从此表选择一个有新触发条件的边界；没有新触发条件就不得重测、
重看、重跑验证或改动该边界。

| 边界 | 状态 | 已确定的约束 | 重新开启的唯一条件 |
| --- | --- | --- | --- |
| `GalleryCommentsPage` 与共享可见宿主 | **FROZEN** | 固定底部 composer；无重复页内评论计数标题；独立圆角 CommentRow；16vp 卡片内容 inset。 | 该可见树有新源码改动、同状态反证，或用户就完整评论页给出新的明确反馈。 |
| Detail compact Preview | **FROZEN** | Preview 高度 `150vp`；它不与 hero 或 Related 等高。 | Preview 本身有新明确用户指令或同状态反证。 |
| 横向 rail 的通用边界规则 | **FROZEN RULE** | 只有横向 `List` 视口可越过二级容器横向 inset；标题、父卡、上下间距保持原位；首尾留白由第一/最后一项拥有。 | 用户改变这条规则，或出现同状态反证。单个 rail 的内容/尺寸问题不允许借此改头部、纵向间距或其他 rail。 |
| Detail 浮动 Read | **FROZEN RULE** | 中途遮挡内容是浮动语义；只判断尾项能否滚到其上方。 | 用户要求改变浮动交互，或尾项实际不可达的同状态证据。 |
| Reader 已观察路径 | **EVIDENCE-ONLY** | 已有本地 Reader 进入、双页、缩略图、设置与返回的设备观察；这些不能拼成完整视觉验收，也不授权再跑同一 Reader 路径。 | Reader 可见源码改动、用户针对 Reader 的新明确反馈，或取得同状态同视口的有效参考条件。 |
| Downloads 完成任务导出后取消 | **EVIDENCE-ONLY** | 已观察到系统 Share UI 前台后取消，任务仍为 Complete；不扩展为目标应用投递或其他任务状态的结论。 | 出现真实下载/暂停状态，或导出源码/Share 边界被改动。 |
| Settings 根入口 | **FROZEN（当前主视口）** | 2026-08-11 同设备、同语言、1320×2120 纵向根页对照后，“界面／阅读”已与参考同级命名一致；其余能力差异不据此改动。 | 该根树有新可见改动、用户就它提出新反馈，或出现同状态反证。 |
| Settings 根页普通重入（生命周期） | **FROZEN SOURCE ASSESSMENT** | 当前 `aboutToAppear` 只同步已发布的登录态并读取本地 Profile 快照；没有 loading 状态、行清空、网络请求或第二次会话恢复。该结论不是设备视觉验收。 | `SettingsPage` 根页生命周期、`NhAccountProfileService.restore` 的可见状态语义发生修改，或真实设备出现根页清空/刷新反证。 |
| Settings Layout 普通重入（生命周期） | **EVIDENCE-ONLY** | 启动期已恢复 Theme/Language/Material/Browse presentation/Home tab/Cover background/Gallery title/Read style/Tablet layout；Layout 的 `aboutToAppear` 仍会重复读取同一组本地偏好。当前未观察到 loading、行清空或错误状态，不能据源码把重复 I/O 宣称为可见缺陷，也不得再重复检查。 | 真实设备出现 Layout 内容清空、加载或错误反证；或该出现期/启动期恢复路径发生改动。 |
| Content Filters 普通重入（生命周期） | **FROZEN** | 首次和返回后二次进入均保留原生内容，无 loading/error；已恢复规则不再重复读取 RDB。 | `ContentFiltersPage` / `ContentFilterService` 的出现期状态语义改变，用户反馈该路径，或真实设备出现加载/清空反证。 |
| History 根页 | **EVIDENCE-ONLY** | 已观察到简单列表树；缺同一批本地记录的参考状态。 | 自然具备同状态参考条件，或用户给出新的根页反馈。 |
| Detail Related rail | **EVIDENCE-ONLY** | 2026-08-11 已以 `471768` 取得当前 Detail 的 Related 终态：标题、真实比例封面、80vp 标题叶与首尾 item 留白均可见；当前画面本身没有给出可安全推导的新尺寸。 | Related 可见源码改动、用户给出新的具体目标，或取得同状态、同视口的有效参考/反证。 |

**执行口令：** 已确认且未发生新变更的边界不再检查。一次观察只记录一次；
后续工作只进入表中因新证据而可行动的单一边界，不能把“还有未对齐页面”
变成对已冻结页面的重复审查。

## OPEN：Settings 根入口的同级文案收敛

- 触发依据：2026-08-11 在唯一选定设备的同一竖屏根窗口（NextN 与 NextE 均为
  `1320×2120`）取得实际设置根页。两页均为“设置 → 账户卡 → 主设置组 → 浮动根 tab”。
  其中 NextN 显示“布局／阅读器”，NextE 在相同的调色板、阅读图标入口显示“界面／阅读”。
  这是已由当前设备画面与四语言资源共同确定的入口命名不一致。
- 父树边界：只限 `Settings root -> RootMainSection -> Layout row / Reader row` 的标题
  资源；滚动宿主 `SecondaryListScaffold`、账户卡、分组容器、分隔线、图标、chevron、
  其他行、根 tab 与所有 destination 的内容树不变。
- 精确改动：四语言的既有资源键 `settings_layout` 从 `Layout/布局/レイアウト` 收敛为
  `Interface/界面/インターフェース`，`settings_reader` 从 `Reader/阅读器/リーダー`
  收敛为 `Reading/阅读/閲覧`；这些键继续被原有 root row 和 destination title 共用。
- 最小性理由：不把 NextE 的 EH、Search、History 或 Storage 行强塞入 NextN；它们分别
  涉及不支持的域能力或已有不同功能边界。“浏览与搜索”和“缓存”保持现值。本次不动行数、
  尺寸、上下留白或任何相邻 UI。
- 验证计划：签名 Debug 构建并仅 `install -r` 到同一设备；回到同一 Settings 根视口一次，
  对照本地保留的 NextE 当前截图，确认只有这两处标题更新且根树/行序未变。构建不代替该
  视觉复核。
- 未决风险：资源键还用于 destination 标题；更名会同步改变该两页的标题。此为参考的
  同级 category 语义，不是页面结构变更；如新页面标题出现语义反证，单独重开该 destination，
  不回改根页或相邻入口。
- 当前设备观察：签名 Debug 构建后仅以 `install -r` 更新唯一选定设备。当前
  `com.erosteam.nextn` 前台、同一 `1320×2120` 设置根页中，两个入口已显示“界面／阅读”；
  其余可见行、行序、卡片边界、根 tab 和账户卡未改变。当前 NextE 参考与改后 NextN 截图、
  布局和前台证据保留在本地
  `.hvigor/outputs/nextn-settings-root-compare-20260811T0246/`，不进入 Git。
- 冻结条件：未出现新的根页可见源码改动、用户没有针对该根页给出新反馈且没有同状态反证时，
  禁止再次截图、源码审查、测试、验收或改动 Settings 根入口；不以“顺便确认”重跑该路径。

## FROZEN：Gallery 外部 Deep Link 直达

- 触发依据：用户明确要求后续验证可直达 Gallery（示例 `471768`），避免每次从 Browse
  重新寻找入口。HarmonyOS 官方 Deep Linking 文档要求独立的 `viewData` skill，并在
  `UIAbility.onCreate/onNewWant` 解析 `Want.uri`。
- 父/路由边界：`implicit Want(uri) -> EntryAbility.onCreate/onNewWant ->
  GalleryDirectLaunchState -> Index.handleGalleryDirectLaunch -> GalleryDetail`。现有内部
  `nextn_gallery_id` 参数路径已处理冷启动根页就绪与热启动投递；不得另建导航栈、坐标路径、
  Clipboard 路径或改变 Detail 可见树。
- 精确改动：由“仅接受内部正整数 `nextn_gallery_id` 参数”扩展为额外接受严格的
  `nextn://gallery/<positive-integer>` URI；在 `module.json5` 以独立 `viewData` skill
  声明该 URI。Harmony 将 `pathRegex` 拼接为完整 URI 正则，故该字段只保留数字 path
  片段；`EntryAbility` 再严格锚定完整 URI。其他 scheme、host、path、零值、负数、
  非整数和 query 一律不路由。
- 最小性理由：复用现有的一次性 `GalleryDirectLaunchState`，不改变 Gallery API、内容数据、
  登录、History、Reader、Comments 或任何页面布局。
- 验证计划：签名 Debug 构建后仅 `install -r` 到 237；对 `nextn://gallery/471768` 各执行
  一次冷启动与热启动，确认原生 Gallery 终态。不写入评论、收藏、下载、历史或偏好；保留
  本地审计证据。构建成功不构成路由验收。
- 未决风险：设备上若有相同 scheme/URI 的其他应用，系统可能出现选择器；该行为不以坐标
  或旧截图绕过，按当前终态记录。
- 当前设备观察：2026-08-11，签名 Debug HAP 以 `install -r` 更新唯一选定设备后，
  `nextn://gallery/471768` 的隐式 `viewData` Want 在冷启动与热启动均进入同一原生
  Gallery Detail。首次系统拒绝被定位为 `pathRegex` 锚点位于完整 URI 中段；按官方
  URI 拼接规则修正后，系统匹配成功。冷启动一度被 USB 系统弹窗覆盖，热启动一度被设备
  锁屏/短超时遮蔽；各自只经系统 Back 或中性解锁恢复，最终 Detail 终态均保留在本地
  `.hvigor/outputs/nextn-gallery-uri-20260811T0232/`，不进入 Git。没有点击 Detail
  控件、写入评论/收藏/下载/历史，或变更账户和偏好。这只接受 URI 路由能力，不是
  Detail 的新视觉验收。
- 冻结条件：`EntryAbility` URI 解析、`module.json5` 的 Gallery skill、或直接路由
  状态交接发生改动；用户给出 URI 路由的新反馈；或出现同一 URI 的真实终态反证。其余
  情况不得再运行此深链作为“顺手验证”。

## 已观察用户路径（只保留边界，不形成重跑队列）

下列条目来自当前活动设备台账的已发生观察。它们不是完整视觉验收，不能被
“默认逐页检查”重新启动；只在对应可见源码改变、用户提出该路径的新问题，或
真实终态与此处记录冲突时重开。

| 用户路径 | 已观察的精确范围 | 不包含的结论 |
| --- | --- | --- |
| Browse 根页普通进入/返回 | 已加载原生 Grid 在普通返回后保留，没有首屏 loading/refresh 表面。 | 不代表 Browse 的空态、错误态、每种密度或全页视觉已验收。 |
| Search 落地页与普通返回 | 已观察原生 Search 落地和返回 Browse 的普通路径；没有通过编辑/删除既有查询来制造状态。 | 不代表任意查询、建议、空态或错误态。 |
| Favorites 会话恢复 | 已在不清数据的冷启动后观察到原生已认证读取；任何新的原生 Account/Favorites 失败仍立即触发独立 P0。 | 不用旧成功结果掩盖新的登录失效。 |
| Gallery Detail → Pages → Thumbnail Grid | 已观察现有 Pages 入口、First/Jump 叶和 Reader 返回后的既有 Detail 路由。 | 不代表宽屏、未知页码、所有加载态或 Detail 全页视觉。 |
| Downloads 根页及完成任务 | 已观察普通根页进入、完成任务进入 Detail/Reader，以及 Export CBZ 后取消仍为 Complete。 | 不代表下载中、暂停、失败或 Share 目标投递。 |
| History 普通根页进入/返回 | 已观察有本地记录时的日组列表保留，没有首屏 loading/refresh 表面。 | 不代表搜索、删除、清除、分页或空态。 |

**重开纪律：** 这些是反复做过的动作清单，不是待办事项。新的执行必须在台账
中写出上述三种重开触发之一；“想再确认一次”“顺便看看”或旧协议存在都不是理由。

## 已实施、已在设备观察：Content Filters 普通重入不重复读取本地规则

- 触发依据：用户明确要求普通页面进入/返回不得表现为重复刷新。当前源码证明
  `EntryAbility` 已在 `loadContent` 前调用 `ContentFilterService.restore()`；成功后
  `ContentFilterState.isRestored=true`。但 `ContentFiltersPage.aboutToAppear()` 仍无条件
  调用同一恢复，重复读取 `content_filter_rules` 并替换当前规则数组。该问题是独立的
  生命周期重复 I/O，不依赖或改动已冻结的 Settings 根页、Detail、Comments 或 Reader。
- 父树边界：`Settings root -> HdsNavDestination -> ContentFiltersPage -> Column ->
  SecondaryListScaffold -> page note + RulesGroup`。只改变该 destination 的出现期状态
  判定；标题栏、List、滚动器、规则行、编辑器 sheet、删除确认与本地规则服务接口
  均不改变。
- 精确改动：原来每次 `aboutToAppear` 都令页面进入 restoring 并调用 RDB restore。
  新行为仅在 `filters.isRestored=false` 时调用 restore；已恢复的 retained state 直接
  保持，并将本组件的 `isRestoring` 归零。首次启动和任何先前 restore 失败时仍会
  走原恢复路径，因此不把失败隐藏为成功。
- 最小性理由：规则的唯一进程内写入口已经由 `ContentFilterService.save/remove/setEnabled`
  同步更新 `ContentFilterState`；普通返回不需要再次读取 RDB。不会增加缓存层、修改
  远端请求、合并其他 Settings 子页或改变空态/错误态的视觉树。
- 验证计划：签名 Debug 构建并以 `install -r` 更新选定设备；在不新增、编辑、删除或
  切换任何规则的前提下，首次进入 Content Filters 后返回 Settings 再进入一次，确认
  已有规则/空态直接保留且不出现首次 loading 表面。若首次 RDB restore 失败，保留
  原错误/重试语义而不伪造失败。
- 未决风险：其他进程直接写同一 RDB 时，已恢复的常驻状态不会在普通返回时重载；当前
  产品没有该写入者，进程重启仍会经过 EntryAbility 的首次恢复。此条只接受所述普通
  重入边界，不泛化为所有 Settings 子页。
- 当前设备观察：2026-08-11，签名 Debug HAP 已仅以 `install -r` 更新唯一选定设备。
  在没有新增、编辑、删除或切换任何规则的前提下，原生 Settings → Advanced →
  Content Filters 首次进入、一次 Back 返回、以及再次进入均稳定显示已有的页面内容，
  没有 loading 或错误表面。本地审计截图和布局保留在命名目录、排除在 Git；远端临时
  文件已仅删除本轮创建的副本。该结果只接受普通重入，不是所有错误/外部写入场景的
  结论。

## 已实施、已在设备观察：Gallery Comments 的零评论首发入口

- 触发依据：当前用户目标要求应用可长期使用、按真实用户路径补齐未完成能力。当前 `GalleryCommentsPage` 的成功零评论分支直接渲染 `PageEmptyState`，而唯一的页面编辑器只在 `comments.length > 0` 时挂载；已登录用户因此无法发布该画廊的第一条评论。NextE 的完整 Comments 父树在空列表分支仍保留其页面编辑器；本轮已在选定设备对照已加载 Comments 页，未以该截图取代零评论状态的后续设备验收。
- 父树边界：`HdsNavDestination -> GalleryCommentsPage -> Column`。初始加载和初始错误继续保留原全页状态；成功已加载的滚动区继续由 `PullRefreshListScaffold` 拥有；现有已评论路径维持 `滚动区 + 固定页面底部 CommentComposer`。本改动只在“成功、当前 gallery、零条可见评论”状态下，把原空态放入可伸缩内容区并保留同一个固定底部编辑器。标题栏、顶层 Compose/Refresh 动作、卡片、List inset、键盘避让、评论提交、过滤、刷新和浮动 Read 均不改。
- 精确改动：原来 `comments.length === 0` 无条件进入没有 composer 的 `PageEmptyState`。改为仅在成功空态包裹 `PageEmptyState` 的可伸缩内容区后追加已有 `CommentComposer()`；首次加载或首次错误仍不显示 composer，避免在未解析当前讨论状态时提供写入入口。
- 最小性理由：不采用 NextE 的悬浮 composer，因为当前 NextN 的固定页面底部编辑器、无重复 in-page 标题均已有用户明确修正并冻结。只复用“讨论为空仍可发第一条”的能力语义，不移动既有编辑器或重组已评论的 List/card 父树。
- 验证计划：签名 Debug 构建后，用一个真实、已登录、成功返回零评论的 Gallery 路由验证：空态与固定编辑器同时可见，聚焦后编辑器仍位于键盘上方；不输入或提交评论。若当前设备没有该状态，不伪造响应、评论或本地数据，记录为未完成设备验收。
- 未决风险：内容过滤可将原始评论过滤为空；该状态不能错误地宣称是“可发表首条”的远端空讨论，因此编辑器只依据已成功加载当前 Gallery 与已发布账号会话，不根据 `rawComments.length` 推断远端数量。

## 回填：Gallery Detail / Comments 当前父树

- 2026-08-10: no same-state NextE Detail reference is retained locally, and
  the installed reference app has no URI launch route to the same Gallery
  ID. Reaching that state would require changing the reference app's visible
  or data state, which is not permitted as a substitute comparison.
  Therefore the whole-page Detail reference comparison remains unavailable;
  current NextN Detail observations are retained without a visual-parity
  claim, and no Detail UI edit is made on the basis of this limitation.

## 已实施、已在设备观察、待同状态参考对照：设置根入口按 NextE 根列表重写

- 触发依据：用户明确要求设置页删掉重写，并指出设置入口文案不知所云。设备
  截图对照显示 NextN 根列表的“布局”行副标题为“跟随系统 · 封面网格”，把
  主题模式混入布局摘要；账户副标题为“账户 ID …”，属重复表述；而 NextE
  参考根列表的每行均为简洁标题行，无此类跨类拼接副标题。
- 父树边界：`SecondaryListScaffold -> RootAccountSection + RootMainSection`。
  仅重写设置根入口的列表行与账户副标题；布局、目录、阅读器、下载、缓存、
  高级、关于等子页面及其能力不变。
- 精确改动：1) 删除“布局”行的 `settings_layout_summary` 副标题与 a11y 中
  的主题模式拼接；2) `account_profile_id` 在 zh/en/ja 中改为
  “ID {0} / ID {0} / ID {0}”；3) 修正
  `settings_catalog_preferences_hint` 断句，改为“浏览和搜索的默认项保存在
  本机。”；4) 修正 `settings_reader_auto_advance_interval_hint` 中无意义的
  “时钟操作”，改为“自动翻页”。
- 最小性理由：根入口的问题集中在文案语义和行摘要拼接，不触碰子页面能力、
  账户会话、布局/阅读器/下载等数据与交互逻辑；不引入参考中 NextN 不具备的
  EH 等入口。
- 验证计划：签名 Debug 构建并以 `install -r` 更新选定设备；打开设置根页，
  确认“布局”行不再出现“跟随系统 · 封面网格”，账户副标题为“ID …”，并
  对照 NextE 根列表检查行层级与文案；不修改任何账户或偏好数据。
- 未决风险：行标题保留 NextN 真实能力命名（布局、浏览与搜索、阅读器、下载、
  缓存、高级、关于），与 NextE 的“界面、阅读、存储”等命名存在产品命名差异；
  该差异属于 NH 能力边界，不视为需要伪造的参考叶。
- 被否定的旧做法：此前把“主题模式 + 封面布局”拼成根入口副标题。两个字段
  虽然真实，却破坏了参考中根功能入口只呈现能力名称的统一层级；审查时错误地
  逐字段判断语义，未以整组行的文案语法和视觉节奏为单位审查。该类状态摘要
  今后只能留在对应子页的设置行，不能回填到根入口。
- 当前设备观察：2026-08-10 20:34 +0800，签名 Debug HAP 以 `install -r`
  覆盖到唯一选定设备后，设置根页实际显示账户 `ID …` 副行和所有单行功能入口；
  原“跟随系统 · 封面网格”文本已不存在。当前同视口截图保留在
  `.hvigor/outputs/nextn-settings-root-copy-20260810T2025+0800/settings-root.png`，
  不进入 Git。此观察仅覆盖根入口文案和层级；NextN 专有入口名称与 NextE 不同，
  不据此宣称整个设置子树已完成视觉验收。

## 已实施、待同状态参考对照：按 NextE 简单列表重写历史根页

- 触发依据：用户明确要求“历史页全删掉重写”。当前真实设备截图
  `.hvigor/outputs/nextn-history-root-20260810T1950+0800/nextn_history_root.png`
  显示了搜索框、本地记录计数、日期标题，以及每行独立的蓝色“继续阅读”动作；
  这些被叠加在本应是紧凑阅读记录的根列表上，形成了不统一的多层视觉语法。
  NextE 的 `ViewedHistoryPage.ets` 使用单一 `PullRefreshListScaffold ->
  ListItemGroup(day) -> GallerySimpleCard` 链，日期由 HDS bottomBuilder 被动镜像，
  每条记录没有第二套卡片或大号尾随动作。
- 父树边界：根 `Index -> HdsNavigation -> HdsTabs(History) -> HistoryPage`；
  HDS 保留标题、清除动作和 `HistoryPinnedDayHeader` bottomBuilder。页面内容为一个
  `PullRefreshListScaffold`，它拥有 top reserve、加载/错误/空态、日期
  `ListItemGroup`、行、footer 和下拉刷新。行内只拥有封面、标题、时间、进度与
  一个紧凑的续读叶动作；长按/左滑删除仍属于对应 `ListItem`。
- 精确改动：删除默认可见的 History 搜索框和“n 条本地记录”计数；删除当前
  `HistoryGalleryCard` 的“详情列 + 独立蓝色继续阅读行”树，换成与 NextE
  `GallerySimpleCard` 同样的 72×102 封面、固定信息列、标题、底部元数据和
  hairline divider。日期普通行与 HDS 镜像改回 NextE 的 body/bold/brand 语法和
  同一高度。标题菜单删除无参考的 Reload；下拉刷新和 root-tab re-tap 仍保留。
- 最小性理由：本轮不改 `HistoryRepository`、RDB cursor、读取记录、进度保存、
  删除确认、Reader 路由或 Gallery 路由。NextN 特有的续读能力作为行内小叶保留，
  但不再把它渲染成第二个高显著性行。不会据此改动 Settings、Detail、Comments 或
  任何其他根页。
- 验证计划：签名 Debug 构建并以 `install -r` 更新 237；在不清本地历史、不点击
  删除或续读的前提下，采集当前已加载多条记录的 History 根页，与 NextE 同一
  simple-list parent-tree 和现有基线截图比较：确认无搜索/计数/大蓝动作，日组和
  行密度一致，浮动根 tab 仍不遮挡可见行。截图保存在本地审计目录，不进入 Git。
- 未决风险：NextN 没有 NextE 的远端 gallery metadata（评分、分类、上传者等），
  因而不能伪造这些叶；行内只显示本地记录可证明的时间、页数与续读动作。
- 当前设备观察：2026-08-10 21:06 +0800，签名 Debug HAP 以 `install -r`
  覆盖到唯一选定设备后，已有本地记录的 History 根页显示单一蓝色日期标题和
  简单行：72×102 封面、标题、时钟时间、页码和小 chevron。搜索框、记录计数、
  Reload 菜单和独立蓝色“继续阅读”行均未出现；标题菜单只剩清除。截图保留在
  `.hvigor/outputs/nextn-history-root-rewrite-20260810T2103+0800/history-root.png`，
  不进入 Git。没有点击记录、Reader、删除或清除。
- 未完成验证：当前没有同一批本地历史记录的 NextE 参考画面；因此这只证明
  NextN 当前设备树和用户指出的可见缺陷已改变，不能替代同状态参考视觉验收。
- 参考复核：2026-08-10 21:10 +0800，仅打开已安装 NextE 后其当前可见状态为
  Settings 根页，不是历史列表；未改变其数据、偏好或路由来伪造可比状态。该
  截图保留在本轮本地审计目录但不作为 History 参考。21:11 已将前台恢复为
  NextN 的已加载 History 根页，未点击记录、续读、删除或清除。

## 已实施、待同状态参考对照：Browse Grid 极端比例封面 letterbox 背景

- 触发依据：2026-08-10 当前 Browse 设备画面中，极宽封面的固定 Grid cover 出现大块浅色空槽。NextE 的同一 `GalleryGridCard` 传入 `letterboxBackground: true`；其 `EhThumbnail` 在默认非模糊模式以封面主色渐变填充 Contain 留白，模糊只是可选替代。
- 父树边界：仅 `GalleryCollectionBody -> GalleryGridCard -> Cover` 的极端比例 Contain 分支。固定 Grid 几何、封面原图、角标、页数、标题、列表/滚动和全局“模糊背景”偏好不改变。
- 精确缺口：NextN 当前只在 `blurLetterboxBackground=true` 时画模糊底层；默认 `false` 时没有任何底层，露出 `COVER_PLACEHOLDER`。这把“背景样式选择”错误实现为“背景是否存在”。
- 最小改动理由：移植 NextE 默认主色渐变背景及现有可选模糊分支，不把 Contain 改为 Cover，不改变卡片尺寸或用户偏好含义。
- 当前设备观察：已构建、以 `install -r` 更新，并在同一 Browse Grid 的极宽封面上观察到 Contain 留白由封面主色背景层填充，不再是裸灰色；固定卡片尺寸、角标、页数和文字区域未变。原始截图保留在本地审计目录、排除在 Git 外。
- 未完成验证：尚缺同状态、同视口 NextE 参考画面对照，因此这不是完整视觉参考对齐声明。风险是主色提取失败时必须保持安全占位而不能阻塞封面或网络。
- 2026-08-10 19:35-19:36 +0800: an attempt to obtain a same-state NextE
  reference was made on the selected device. Launching the installed
  `com.erosteam.nexte` reference resumed its last Comments page; one native
  Back reached its Gallery category list (a different parent tree) rather
  than the same Browse root used by the NextN letterbox observation. No
  same-state extreme-ratio cover was obtainable without changing the
  reference app's visible or data state, and no such change was made.
  Therefore the same-state reference comparison remains unavailable and this
  item stays OPEN; the NextN device observation above is retained as-is.

## 已实施、已在设备观察：Downloads 完成态全局动作可见性

- 触发依据：2026-08-10 当前 NextN Downloads 完成态设备画面显示“全部暂停”和“全部恢复”两个不可用的顶部菜单动作。NextE 的同一根标题菜单树固定保留搜索、排序和回到顶部，但仅当队列存在可恢复任务时插入恢复动作、仅当存在下载中任务时插入暂停动作（`NextE/entry/src/main/ets/pages/Index.ets:1141-1171,1200-1224`）。
- 父树边界：仅根 `Navigation -> HDS title bar -> Downloads title menu` 的菜单叶序列；下载页的 pinned group header、搜索、排序、任务卡、队列状态、批处理逻辑和滚动宿主不变。
- 精确改动：NextN 当前无条件把 Pause/Resume 两个 menu item 放进 `downloadMenuItems`，再以 `isEnabled=false` 表示无资格。改为始终保留 Search/Sort，仅在各自的 `pausableVisibleCount` 或 `resumableVisibleCount` 大于零时插入对应叶子，匹配 NextE 的条件插入树。
- 最小性理由：不改变可暂停/恢复的任务判定、桥接命令或可见任务过滤，只纠正无可执行操作时的标题菜单呈现；不触及下载卡片或导出入口。
- 验证计划：构建、`install -r` 后，在当前“仅完成任务”的同一 Downloads 状态打开菜单，确认无禁用的暂停/恢复项；之后仍需同状态 NextE 画面对照，才可宣称视觉参考对齐。
- 构建证据：2026-08-10 已完成签名 Debug 构建；构建通过不构成视觉验收。
- 未决风险：页面尚未报告最新 eligibility 时菜单必须保守地不显示批处理叶子；需要设备操作后确认正常下载/暂停状态仍会出现各自动作。
- 当前设备观察：已使用现成协作租约工具，仅在 `192.168.50.237:12345` 上 `install -r` 当前签名 Debug HAP。Downloads 完成态的实际 HDS 标题栏保留两个可用动作，未再出现禁用的 Pause/Resume 叶子。原始截图与原生布局保留在本地 `.hvigor/outputs/nextn-download-menu-20260810T1329+0800/`，未加入 Git。
- 未完成验证：尚未取得同状态、同视口的 NextE 画面对照，也没有在“存在可暂停或恢复任务”的真实状态下验证条件叶子重新出现；因此不得将此记录称为完整视觉参考验收。

## 已实施、失败支路待真实设备观察：Downloads 失败 bootstrap 的普通重入

- 触发依据：用户已明确指出普通页面切换不应自动重新加载。当前 `DownloadQueuePage.ensureQueueForAppearance()` 在 `queueBootstrapResolved=false` 时无条件调用 `bootstrapQueue()`；而失败 catch 会持续保留该 false 值，因此一次失败后的隐藏/显示会重复 durable restore。NextE 的 `DownloadQueuePage.aboutToAppear()` 只重建本地 projection，不发起 restore（`NextE/feature/download/src/main/ets/pages/DownloadQueuePage.ets:121-125`）。
- 父树边界：仅 `Root Downloads tab -> DownloadQueuePage` 的出现生命周期与既有错误重试入口。HDS 标题、pinned header、队列 ListItemGroup、任务卡、搜索/排序、导出和队列服务均不改。
- 精确改动：在现有 `resolved/inFlight/generation` 三个 bootstrap 字段之外增加“本页已尝试 bootstrap”状态。普通 `aboutToAppear` 只在从未尝试时启动 restore；失败后保持错误状态。用户显式 Error Retry 仍调用既有 `bootstrapQueue()`，允许一次新的 durable restore 尝试。
- 最小性理由：不改变 `DownloadQueueService.restore`、存储、任务状态或成功后的 projection；只移除普通重入对失败恢复的隐式重试。
- 验证计划：签名构建后，在不清数据的真实设备上制造不了的 queue restore 失败不予伪造；须等待真实失败状态，再验证 Browse→Downloads 普通返回不触发 loading/restore，而 Error Retry 才重试。构建或源码检查不构成该行为验收。
- 未决风险：当前设备有可用队列，不能安全地人为破坏持久化来覆盖失败支路；该边界在真实失败发生前保持未验收。
- 构建证据：2026-08-10 签名 Debug 构建成功，并以 `install -r` 更新唯一选定设备；未清数据。
- 当前设备观察：更新后从 Browse 正常进入原生 Downloads（标题“下载”、一个原生 List）。这仅排除了该更新对当前正常路由的即时破坏；失败 bootstrap 的普通重入边界仍未被真实设备触发。

### 6b816a2 — Detail 与 Comments 初始重组（未验收）

- 改动：引入 Detail 的 Related/评论预览 rail 与全评论页的局部布局重组。
- 当时问题：把“有参考可复用”错误地当作可以自行决定 rail 尺寸、卡片层级和评论呈现的授权；没有先完成每个可见区域的同状态对照。
- 影响：随后出现了 Related 高度、预览比例、评论预览卡与完整评论页多处反复改动。
- 约束：此父树仍为 OPEN；未来只可按单一用户指出区域和完整父树证据窄改，不能再用一项局部观感推导相邻区域的重构。

### 6ffafa3 / 99ca471 — Detail 横向评论预览卡高度

- 改动：6ffafa3 把原固定 `120vp` 改为按“两行文字”计算的 `82vp`；99ca471 已恢复为 `120vp`。
- 错误假设：把详情页外露评论误判为应该仅容纳两行文字的辅助信息，忽略了它仍是可阅读的横向评论卡，也没有对应的用户指令或参考证据。
- 影响：详情页评论预览显得被压扁。
- 防复发：评论 rail 的固定高度、宽度、字体和行数只能作为一个整体由同状态视觉证据调整；不得由文本行数公式单独压缩容器高度。
- 验证状态：99ca471 已构建并安装；当前设备复核仍 OPEN，且不把孤立截图称为参考对齐。

### 4bdd450 — Related rail 尺寸和卡面

- 改动：改变 Related 的 cover/card 尺寸与卡面容器，并让横向 rail 的视口穿过二级容器内部横向 inset。
- 依据与边界：用户明确要求横向 List 的中段延展感，且首尾留白归 List 首末项；标题和垂直间距不得跟随 List 扩展。
- 未完成处：卡片高度、标题可读性与封面比例必须由用户的当前视觉反馈和同状态参考共同决定；不得把“横向延展”误扩展成缩窄标题或压低卡片。
- 验证状态：当前设备已确认中段不被父容器内部横向 inset 裁断；完整视觉对齐仍 OPEN。
- 2026-08-11 当前证据：使用已冻结的 `nextn://gallery/471768` 直达路径，在选定设备取得
  当前 Detail 下半屏。Related 为页面级标题加横向 `List`，三张可见卡都保留“封面 + 标题”
  叶，标题没有被裁成单行；Related 标题与上方 Tags 标题落在同一内容起始线。现行值仍是
  `190vp cover + 80vp title`，而 ErosN 的当前父树为 `280` 高 rail（动态 `200` 高 cover +
  `80` 标题）。两者和此前“标题必须可读、不得把卡片压到极小”反馈相容，却不能从这一张
  当前 NextN 画面推出一个不同的唯一数值。没有同状态 ErosN/NextE 实机画面时，不再以
  “看起来高/低”二次改动该 rail。
- 防重复：本次终态截图、布局与前台证据保留在本地
  `.hvigor/outputs/nextn-detail-related-20260811T0300/`，排除在 Git。Related 现在为
  **EVIDENCE-ONLY**：没有新的明确视觉目标、可见源码改动或同状态反证时，不得再次直达、
  截图、源码审查、测试或调整这一边界；Preview、Comments 和浮动 Read 仍各自冻结且不受
  此记录影响。

### ad136cb / 03ae7f2 — Compact Preview 高度

- 改动：ad136cb 曾把 compact preview 从 `150vp` 改为 `175vp`；03ae7f2 随后恢复 `150vp`。
- 错误假设：把 Related/Preview 的相对协调错误简化为增大 Preview；忽略了用户已经指出 Preview 不应与 hero/Related 同高。
- 防复发：Preview 的 `150vp` 是当前基线。没有新的明确用户指令和同状态对照，不得再修改它。

### 323b227 / f0db93b — Full Comments 卡片重构与回退

- 改动：323b227 对完整评论卡作了泛化重构；f0db93b 已完整回退该重构。
- 错误假设：在 NH DTO 不支持参考中的全部叶信息时，擅自用通用卡片树补齐视觉，而不是保留参考父树并仅替换不支持叶。
- 防复发：完整评论页只能按 NextE 的滚动宿主、标题、独立 CommentRow 和固定 composer 逐层复用；无 DTO 支持的 avatar/vote 等叶不能伪造。

### 14a3970 / f5826ed — Full Comments 内容 inset 与 composer 停靠

- 改动：14a3970 增加 CommentCard 内容 inset；f5826ed 将 composer 固定在 List 之后的页面底部，而非覆盖内容。
- 触发依据：用户明确指出文字贴近圆角；当前设备截图曾显示 composer 覆盖内容风险。
- 父树边界：全评论页为 `Column -> 可滚动评论区 -> 固定不透明 composer`；composer 不属于详情页 Read 浮层，也不改变 Detail 的浮动阅读按钮。
- 验证状态：当前设备已见固定 composer 未覆盖评论，但与 NextE 的同状态视觉对照仍 OPEN。

### 现行约束

- 详情页 Preview、Related、横向评论预览和 Read 浮动按钮视为四个独立边界；任何一项反馈不得顺带改动另外三项。
- 对可横向滚动的 rail：只允许 List 视口跨越二级容器的横向内部 inset；标题、父卡、上下间距、首尾空白不随之移除。首尾空白属于第一/最后一个 ListItem。
- 对浮动 Read：中途内容从下方经过是设计语义；只检查终端内容是否仍可滚到其上方，不得因为正常中途遮挡添加边距、移动或隐藏浮动按钮。
- **冻结：Gallery Comments 全页。** 最近一次同视口审查后，此页没有新的可见源码改动；固定页脚 composer、无重复页内计数标题、独立圆角 CommentRow 与 16vp 卡片内容 inset 均保持不动。除非 `GalleryCommentsPage` 或其共享可见宿主发生新的改动、取得同状态反证，或收到针对该全页的新明确反馈，否则不得重新截图、复查、测试或调整该页。冷启动直达路由的时序修复不属于此页的可见改动。

## 已实施、已在设备观察：Gallery Comments 固定编辑器的键盘态底部 inset

- 触发依据：`61f0c7b` 的零评论首发入口已在选定设备的成功空态显示固定编辑器。随后聚焦该 TextArea 的最新本地证据显示，键盘出现后编辑器与发送按钮的原始底部有 36px 落入键盘：`after-focus.layout.json` 的可见 bounds 高度为 68px、原始高度为 104px。当前 `GalleryCommentsPage.composerBottomPadding()` 在 `KeyboardAvoidMode.RESIZE` 下返回 `0`；NextE 同一方法在键盘态返回 `COMMENT_COMPOSER_OUTER_GAP`，即其 `SPACE_SM`。
- 父树边界：`HdsNavDestination -> GalleryCommentsPage -> Column`。成功空态是一个可伸缩的 `PageEmptyState` 内容区，随后是固定、不透明的 `CommentComposer` 页面页脚；有评论时仍是 `PullRefreshListScaffold` 可滚动区加同一个固定页脚。系统键盘由窗口 `keyboardHeightChange` 发布，`KeyboardAvoidMode.RESIZE` 收缩这一根 Column 的可见高度。标题栏、评论 List、卡片、Detail Preview、Related、横向评论预览、Read 浮层、TextArea、发送动作和提交状态都不变。
- 精确改动：仅将 `composerBottomPadding()` 的键盘态返回值从 `0` 改为 `ThemeTokens.SPACE_SM`；无键盘时继续返回 `bottomAvoidHeight`。不读取或套用整个 `keyboardHeight`，避免在 RESIZE 已收缩窗口时重复避让。
- 最小性理由：36px 的实测截断与本设备 `SPACE_SM` 的物理高度相符，且与 NextE 的同一键盘态外间距一致。它只恢复固定页脚在已收缩可视区内的完整高度，不改变用户已冻结的“固定而非浮动”的 composer 树，也不改任何评论/详情几何。
- 验证计划：签名 Debug 构建并以 `install -r` 更新选定设备后，使用既有零评论直达路由，聚焦一次空 TextArea、不输入、不发送；保留新的本地截图和脱敏 bounds，确认输入与发送控件完整位于键盘上方。构建不构成此视觉验收。
- 未决风险：系统若在不同窗口模式报告不同的键盘缩放比例，`SPACE_SM` 可能不足或过量；该风险只通过同一路径的真实键盘状态判断，不扩展为 `keyboardHeight` 全量 padding 或重组页面树。
- 当前设备观察：签名 Debug 构建后已仅以 `install -r` 更新选定设备。零评论直达页加载完成后，空 TextArea 被聚焦一次；键盘显示时，输入框和发送控件均完整地处于键盘上方，TextArea 的 visible bounds 与 origBounds 均为完整的 104px 高度。没有输入文本、没有提交评论。该结果仅覆盖 NextN 这一个键盘态；同状态 NextE 参考画面尚未取得，因此不作为完整参考视觉对齐声明。

## 已实施、已在设备观察：修复 Gallery Comments 的冷启动直达请求时序

- 触发依据：2026-08-11 00:32 +0800，在唯一选定设备上按既有 `nextn_gallery_id` 加 `nextn_gallery_destination=comments` Want 做了一次冷启动直达。终态经前台 bundle 和根窗口确认是 NextN Browse 根页，而不是 Comments；未输入、提交、修改偏好或账户。
- 父树边界：仅 `EntryAbility(onCreate/onWindowStageCreate/onNewWant) -> GalleryDirectLaunchState -> Index.handleGalleryDirectLaunch() -> 既有 pushComments()` 的一次性路由交接。Comments 页面、Detail 页面、横向 rail、composer、数据请求和视觉几何均不在此改动范围内。
- 精确改动：冷启动暂存的 Gallery Want 不再在 `windowStage.loadContent()` 之前发布；仅在 `loadContent` 成功、根页面具备接收条件后发布一次。已运行态的 `onNewWant` 立即发布分支保持不变。
- 最小性理由：当前失败的真实终态和源码顺序共同表明冷启动请求可早于根导航注册。该改动只修复事件交接，不引入坐标回退、Browse 滚动或另一条 Comments 入口。
- 验证计划：签名 Debug 构建、`install -r`（不清数据），强制停止后对同一 Want 只执行一次冷启动；核验其终态是否为原生 Comments。若终态仍不匹配，保留一次本地诊断证据并停止重试，继续检查 Want 生命周期。
- 未决风险：已运行 Ability 的命令行 Want 交付语义与冷启动不同；本轮只证明或否定冷启动交接，不能据此泛化到所有运行态启动方式。
- 当前设备观察：签名 Debug 构建成功后，已仅以 `install -r` 更新唯一选定设备；一次强制停止后的同一 Comments Want 终态为原生 Comments `NavDestination`，而非 Browse。未输入或发送评论，原始终态证据保留在本地审计目录，不进入 Git。该观察只验证路由时序，不作为 Comments 的视觉验收。
